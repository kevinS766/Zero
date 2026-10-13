-- ZeroMovement: animación R6 de todos los personajes (jugadores y bots), calculada en cada cliente.
-- Base: las secuencias R6 de ReplicatedStorage.ZeroAnimations.Sources (hechas en Blender: zero-anims), reproducidas
-- directamente: locomoción, salto/caída, voltereta, deslizamiento, dashes y un golpe por familia de arma
-- (Ataque<Familia>, ZeroArmasConfig.Familias). Encima, capas procedurales: inclinación al correr y al girar,
-- amortiguación al aterrizar y pose de sujetar el arma. El golpe lo dispara el atributo ZeroAtaqueSerial que pone
-- CombatService en el personaje; el del jugador local se adelanta al pulsar para que no haya retraso. El
-- deslizamiento lo marca el atributo ZeroDeslizando (ZeroSlideClient / ZeroSlideServer).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sources = ReplicatedStorage:WaitForChild("ZeroAnimations"):WaitForChild("Sources")
local ArmasConfig = require(ReplicatedStorage:WaitForChild("ZeroArmasConfig"))
local CombatConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CombatConfig"))
local Sfx = require(ReplicatedStorage:WaitForChild("ZeroMovimientoSFX"))
local localPlayer = Players.LocalPlayer

local movementClips = {
	Runner = { Walk = "Walk", Run = "Run", Jump = "Jump" },
	Hunter = { Walk = "HunterWalk", Run = "HunterRun", Jump = "HunterJump" },
}
local clips = {}
for _, sequence in sources:GetChildren() do
	local clip = { frames = {}, duration = 0, loop = sequence.Loop, originalName = sequence:GetAttribute("OriginalName") or sequence.Name }
	for _, key in sequence:GetKeyframes() do
		local frame = { time = key.Time, poses = {} }
		for _, pose in key:GetDescendants() do
			if pose:IsA("Pose") and pose.Weight > 0 then
				frame.poses[pose.Name] = { cf = pose.CFrame, weight = pose.Weight, style = pose.EasingStyle.Name, direction = pose.EasingDirection.Name }
			end
		end
		table.insert(clip.frames, frame); clip.duration = math.max(clip.duration, key.Time)
	end
	table.sort(clip.frames, function(a, b) return a.time < b.time end); clips[sequence.Name] = clip
	clip.tracks = {}
	for _, frame in clip.frames do
		for part, pose in frame.poses do
			clip.tracks[part] = clip.tracks[part] or {}
			table.insert(clip.tracks[part], { time = frame.time, pose = pose })
		end
	end
end

-- ------------------------------------------------------------------ golpes y dashes: clips de Blender
local A = CFrame.Angles

local HOLD = A(0, 0, 0.45)                 -- brazo con el arma un poco adelantado, sin bambolear el arma
-- bastón (> 3 studs) del cazador: brazo adelantado y la muñeca a 135º para llevarlo de pie delante del brazo (con el
-- agarre del servidor, 160º, iría metido a lo largo del brazo). Brazo = RA (45, -22, 0) de zero-anims/scripts/magia.py
local BASTON_HOLD = CFrame.new(0, 0, 0, -0.17628, 0.07302, 0.37565, 0.90691)
local BASTON_MUNECA = 135
local HOLD_GARRAS = { ["Right Arm"] = A(-0.15, 0, 0.75), ["Left Arm"] = A(-0.15, 0, -0.75) }   -- guardia con las dos manos

local DashConfig = require(ReplicatedStorage.Shared.Config.DashConfig)

local function smooth(x: number): number x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end


local function familyOf(character: Model): string
	local tool = character:FindFirstChildOfClass("Tool")
	local arma = tool and tool:FindFirstChild("ZeroArma")
	return arma and ArmasConfig.Familias[arma:GetAttribute("Arma")] or "Daga"
end

-- varitas y bastones: un golpe por rareza del arma (zero-anims/scripts/magia.py); si falta el clip, el de su familia
local RAREZA = {}
for _, a in ArmasConfig.Armas do RAREZA[a.nombre] = a.rareza end
local CLIP_RAREZA = { Comun = "AtaqueComun", Raro = "AtaqueRaro", Especial = "AtaqueEpico", Legendario = "AtaqueLegendario",
	Mitico = "AtaqueMitico", Exclusivo = "AtaqueMitico" }
local GOLPES_MAGIA = { AtaqueComun = { 0.17 }, AtaqueRaro = { 0.13, 0.3 }, AtaqueEpico = { 0.27 }, AtaqueLegendario = { 0.27 }, AtaqueMitico = { 0.3 } }
local function attackClipOf(character: Model): string
	local tool = character:FindFirstChildOfClass("Tool")
	local arma = tool and tool:FindFirstChild("ZeroArma")
	local nombre = arma and CLIP_RAREZA[RAREZA[arma:GetAttribute("Arma")] or ""]
	return if nombre and clips[nombre] then nombre else "Ataque" .. familyOf(character)
end
-- en la arena de pruebas (ServerScriptService.ZeroPruebas) se te anima como cazador
local function esCazador(player): boolean
	return player:GetAttribute("Role") == "Hunter" or player:GetAttribute("ZeroPruebas") == true
end

-- ------------------------------------------------------------------ estado por personaje
local states = {}
local function startAttack(state, character)
	local nombre = attackClipOf(character)
	state.attack = { clip = clips[nombre] or clips.AtaqueDaga, t = 0, nombre = nombre }
end

local function attach(character, player)
	if states[character] then return end
	local h = character:WaitForChild("Humanoid", 10); local root = character:WaitForChild("HumanoidRootPart", 10)
	if not h or not root or h.RigType ~= Enum.HumanoidRigType.R6 then return end
	local animate = character:FindFirstChild("Animate"); if animate then animate.Disabled = true end
	local animator = h:FindFirstChildOfClass("Animator")
	if animator then for _, track in animator:GetPlayingAnimationTracks() do track:Stop(0) end end
	local motors = {}
	for _, motor in character:GetDescendants() do if motor:IsA("Motor6D") and motor.Part1 then motors[motor.Part1.Name] = motor end end
	local state = { player = player, clipName = "Idle", h = h, root = root, motors = motors, name = "Idle", time = 0, previous = {}, blend = 1,
		blendTime = 0.2, wasAir = false, fallSpeed = 0, actionEnd = 0, dashSerial = character:GetAttribute("ZeroDashSerial"),
		attackSerial = character:GetAttribute("ZeroAtaqueSerial"), localAttackAt = -math.huge, lean = 0, roll = 0, land = 0,
		lastVel = Vector3.zero, moving = false, running = false, phase = 0, idleTime = 0, moveW = 0, runW = 0, connections = {} }
	if animator then table.insert(state.connections, animator.AnimationPlayed:Connect(function(track) track:Stop(0) end)) end
	-- golpe del jugador local: se anima al pulsar, sin esperar al servidor
	-- chocar a toda velocidad no lo tira al suelo; también en los bots, por si su física la simula este cliente
	h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	if player == localPlayer then
		table.insert(state.connections, character.ChildAdded:Connect(function(tool)
			if not tool:IsA("Tool") or tool.Name ~= "HunterKnife" then return end
			table.insert(state.connections, tool.Activated:Connect(function()
				if player:GetAttribute("StalkerStealth") == true then return end
				if os.clock() - state.localAttackAt < CombatConfig.ATTACK_COOLDOWN then return end
				state.localAttackAt = os.clock()
				startAttack(state, character)
			end))
		end))
	end
	table.insert(state.connections, Sfx.silenciarRoblox(root))      -- salto/aterrizaje/pasos genéricos de Roblox fuera
	states[character] = state; character:SetAttribute("ZeroAnimationControllerReady", true)
end
local function watch(player)
	player.CharacterAdded:Connect(function(character) task.spawn(attach, character, player) end)
	if player.Character then task.spawn(attach, player.Character, player) end
end
for _, player in Players:GetPlayers() do watch(player) end
Players.PlayerAdded:Connect(watch)
local function watchBots(folder)
	local function added(character)
		if character:IsA("Model") and character:GetAttribute("IsBot") then task.spawn(attach, character, character) end
	end
	for _, character in folder:GetChildren() do added(character) end
	folder.ChildAdded:Connect(added)
end
local bots = workspace:FindFirstChild("ZeroBots")
if bots then watchBots(bots) end
workspace.ChildAdded:Connect(function(folder) if folder.Name == "ZeroBots" then watchBots(folder) end end)

local function switch(state, name, blendTime)
	local profile = esCazador(state.player) and "Hunter" or "Runner"
	local clipName = movementClips[profile][name] or name
	if name == state.name and clipName == state.clipName then return end
	-- caminar <-> correr conservan la fase del paso para que los pies no salten
	local oldClip, newClip = clips[state.clipName], clips[clipName]
	local keepPhase = (name == "Walk" or name == "Run") and (state.name == "Walk" or state.name == "Run") and oldClip and newClip
	local phase = keepPhase and (state.time % oldClip.duration) / oldClip.duration or 0
	state.previous = {}; for part, motor in state.motors do state.previous[part] = motor.Transform end
	state.name = name; state.clipName = clipName; state.blend = 0; state.blendTime = blendTime or 0.2
	state.time = keepPhase and phase * newClip.duration or 0
end
local function sample(clip, t, name)
	-- Sparse pose tracks keep their previous key rather than resetting to identity.
	local track = clip.tracks[name]
	if not track then return CFrame.identity end
	local n = #track
	local lo, hi = 1, n                       -- última clave con time <= t
	if track[1].time > t then lo = 0 else
		while lo < hi do local mid = (lo + hi + 1) // 2; if track[mid].time <= t then lo = mid else hi = mid - 1 end end
	end
	local before, after = track[math.max(lo, 1)], track[math.min(lo + 1, n)]
	if lo == 0 then after = before end
	local a, b = before.pose, after.pose
	local alpha = after.time > before.time and math.clamp((t - before.time) / (after.time - before.time), 0, 1) or 0
	local style = a.style == "Constant" and nil or Enum.EasingStyle[a.style == "Cubic" and "Cubic" or a.style]
	if a.style == "Constant" then alpha = 0
	elseif style then alpha = TweenService:GetValue(alpha, style, Enum.EasingDirection[a.direction] or Enum.EasingDirection.InOut) end
	return CFrame.identity:Lerp(a.cf:Lerp(b.cf, alpha), a.weight + (b.weight - a.weight) * alpha)
end

-- ------------------------------------------------------------------ locomoción continua (quieto · andar · correr)
-- En vez de cambiar de clip, se mezclan los tres según la velocidad real del personaje. Andar y correr comparten
-- la fase de la zancada (con el desfase medido entre los clips para que el mismo pie pise a la vez), así que la
-- transición no tiene saltos: al acelerar la zancada se alarga y se acelera sola.
local RUN_OFFSET = { Runner = 0.775, Hunter = 0.897 }   -- desfase medido de Run respecto a Walk (pie derecho más adelantado)
local function locoPose(state, name: string, profile: string): CFrame
	local walk, run = clips[movementClips[profile].Walk], clips[movementClips[profile].Run]
	local moving
	local w = sample(walk, state.phase * walk.duration, name)
	if state.runW > 0.001 then
		local r = sample(run, ((state.phase + RUN_OFFSET[profile]) % 1) * run.duration, name)
		moving = w:Lerp(r, state.runW)
	else
		moving = w
	end
	if state.moveW >= 0.999 then return moving end
	local idle = profile == "Hunter" and clips.HunterIdle or clips.Idle      -- el cazador espera agazapado
	return sample(idle, state.idleTime % idle.duration, name):Lerp(moving, state.moveW)
end

-- pasos: fase del ciclo en que el pie derecho está más adelantado (al pisar); el izquierdo, media vuelta después
local RIGHT_HIP_C0 = CFrame.new(1, -1, 0) * A(0, math.pi / 2, 0)
local RIGHT_HIP_C1 = CFrame.new(0.5, 1, 0) * A(0, math.pi / 2, 0)
local stepCache = {}
local function stepPhase(clip): number
	if not stepCache[clip] then
		local best, bestZ = 0, math.huge
		for i = 0, 63 do
			local foot = RIGHT_HIP_C0 * sample(clip, i / 64 * clip.duration, "Right Leg") * RIGHT_HIP_C1:Inverse() * Vector3.new(0, -1, 0)
			if foot.Z < bestZ then best, bestZ = i / 64, foot.Z end
		end
		stepCache[clip] = best
	end
	return stepCache[clip]
end
-- golpes: segundos del clip en que arranca cada tajo (fotograma / 60 de los Ataque* de anims.py: el tramo out:expo
-- del golpe). La Daga, las Garras, el Estoque y la Lanza encadenan varios
local GOLPES = { Espada = { 0.18 }, Daga = { 0.05, 0.18, 0.32 }, Estoque = { 0.2, 0.4 }, Garras = { 0.05, 0.13, 0.23 },
	Guadana = { 0.17 }, Hacha = { 0.27 }, Lanza = { 0.22, 0.38 } }

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

RunService.PreSimulation:Connect(function(dt)
	local camPos = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.zero
	for character, state in states do
		if not character.Parent or state.h.Health <= 0 then
			for _, connection in state.connections do connection:Disconnect() end; states[character] = nil
		elseif (state.root.Position - camPos).Magnitude > 260 then
			-- ponytail: lejos de la cámara no se anima; si hiciera falta, bajar la frecuencia en vez de saltarlo
		else
			local status = character:GetAttribute("Status")
			local frozen = status == "Frozen" or status == "HunterTransition"
			if not frozen then
				-- golpe (servidor) — el del jugador local ya se disparó al pulsar
				local aSerial = character:GetAttribute("ZeroAtaqueSerial")
				if aSerial and aSerial ~= state.attackSerial then
					state.attackSerial = aSerial
					if os.clock() - state.localAttackAt > 0.6 then startAttack(state, character) end
				end
				local serial = character:GetAttribute("ZeroDashSerial")
				if serial and serial ~= state.dashSerial then
					state.dashSerial = serial
					local direction = character:GetAttribute("ZeroDashDirection") or state.root.CFrame.LookVector
					local localDir = state.root.CFrame:VectorToObjectSpace(direction)
					local name = math.abs(localDir.X) > math.abs(localDir.Z) and (localDir.X > 0 and "DashRight" or "DashLeft") or (localDir.Z > 0 and "DashBack" or "DashFront")
					Sfx.play(state.root, name == "DashBack" and "DashMortal" or "Dash")
					state.dash = { clip = clips[name], t = 0, dur = math.max(DashConfig.DURATION + 0.18, (clips[name] and clips[name].duration or 0) * 0.85) }   -- a casi su velocidad real (el mortal atrás dura más que el impulso)
				end
				local air = state.h.FloorMaterial == Enum.Material.Air
				local velocity = state.root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if air then state.fallSpeed = math.min(state.fallSpeed, velocity.Y); state.apexY = math.max(state.apexY or state.root.Position.Y, state.root.Position.Y) end
				local sliding = character:GetAttribute("ZeroDeslizando") == true
				if sliding ~= state.wasSliding then
					if sliding then Sfx.play(state.root, "Deslizar") else Sfx.stop(state.root, "Deslizar") end
					state.wasSliding = sliding
				end
				if state.wasAir and not air and not sliding then
					state.land = math.clamp(-state.fallSpeed / 60, 0.15, 0.6)          -- amortiguación al aterrizar
					if state.fallSpeed < -12 then Sfx.play(state.root, "Aterrizaje", math.clamp(-state.fallSpeed / 60, 0.4, 1.3)) end
					if state.fallSpeed < -35 and (state.apexY or 0) - state.root.Position.Y > 12 and os.clock() >= state.actionEnd then   -- caída de más de 12 studs
						switch(state, "LandRoll", 0.08); state.actionEnd = os.clock() + clips.LandRoll.duration
						Sfx.play(state.root, "Voltereta")
					end
				end
				if not air then state.fallSpeed = 0; state.apexY = nil end; state.wasAir = air
				-- histéresis: no parpadea entre quieto/andar ni entre andar/correr cerca de los umbrales
				local walkSpeed = math.max(state.h.WalkSpeed, 1)
				state.moving = if state.moving then speed > 0.8 else speed > 2
				state.running = if state.running then speed > walkSpeed * 0.55 else speed > walkSpeed * 0.7
				-- sentado: la pose la pone el asiento (un Seat que se llame como un clip de Sources, p. ej. los bancos del
				-- lobby: SentadoRelajado, SentadoCruzado, SentadoCasual); en cualquier otro asiento, la de Roblox (SentadoRoblox)
				local seat = state.h.SeatPart
				if sliding then switch(state, "Slide", 0.06)
				elseif seat and clips.SentadoRoblox then switch(state, clips[seat.Name] and seat.Name or "SentadoRoblox", 0.2)
				elseif os.clock() >= state.actionEnd then
					if air then
						-- al despegar: salto si sube, caída si se cae de un borde; el salto pasa a caída al bajar
						if state.name ~= "Jump" and state.name ~= "Fall" then
							switch(state, velocity.Y > 2 and "Jump" or "Fall", 0.12)
							if velocity.Y > 2 then   -- el cazador salta más grave; el súper salto del corredor, más fuerte
								local hunter = esCazador(state.player)
								Sfx.play(state.root, "Salto", hunter and 1 or 1.15, hunter and 0.85 or 1)
							end
						elseif state.name == "Jump" and state.time >= clips[state.clipName].duration then switch(state, "Fall", 0.3) end
					else switch(state, "Loco", 0.16) end
				end
				-- pesos de la mezcla: suavizados para que una velocidad que oscila no haga temblar la pose
				local profile = esCazador(state.player) and "Hunter" or "Runner"
				local sprint = character:GetAttribute("ZeroSprinting") and 1 or 0
				-- la mezcla sigue a la velocidad real casi sin retraso: como ZeroInercia acelera con ease-in cúbica, la
				-- animación gana velocidad con esa misma curva (el esprint entra según se alcanza su velocidad)
				state.moveW = approach(state.moveW, air and state.moveW or smooth((speed - 0.3) / 3.2), 30, dt)
				state.runW = approach(state.runW, sprint * smooth((speed - walkSpeed * 0.5) / (walkSpeed * 0.3)), 24, dt)
				local walkClip, runClip = clips[movementClips[profile].Walk], clips[movementClips[profile].Run]
				local fw = math.clamp(speed / 8, .5, 2.1) / walkClip.duration          -- zancadas por segundo andando
				local fr = math.clamp(speed / 16, .6, 1.8) / runClip.duration         -- y corriendo
				local lastPhase = state.phase
				state.phase = (state.phase + dt * (fw + (fr - fw) * state.runW) * math.min(1, state.moveW * 3)) % 1
				-- pasos al pisar en el ciclo que se ve (andar o correr): más fuertes esprintando; el cazador, más pesado
				if state.name == "Loco" and not air and not sliding and state.moveW > 0.6 then
					local run = state.runW > 0.5
					local contact = run and (stepPhase(runClip) - RUN_OFFSET[profile]) % 1 or stepPhase(walkClip)
					local moved = (state.phase - lastPhase) % 1
					for _, c in { contact, (contact + 0.5) % 1 } do
						if moved > 0 and (c - lastPhase) % 1 < moved then
							local hunter = profile == "Hunter"
							Sfx.paso(state.root, state.h.FloorMaterial, (run and 1.3 or 0.85) * (hunter and 1.25 or 1), hunter and 0.85 or 1)
						end
					end
				end
				state.idleTime += dt
				local clip = clips[state.clipName] or walkClip
				state.time += dt; state.blend = math.min(1, state.blend + dt / state.blendTime)
				local t = clip.loop and state.time % clip.duration or math.min(state.time, clip.duration)
				local blend = smooth(state.blend)
				-- capas procedurales: inclinación adelante por velocidad/aceleración y hacia el giro
				local accel = (velocity - state.lastVel) / math.max(dt, 1 / 240); state.lastVel = velocity
				local forwardAccel = state.root.CFrame.LookVector:Dot(Vector3.new(accel.X, 0, accel.Z))
				local turn = state.root.AssemblyAngularVelocity.Y
				state.lean = approach(state.lean, ((air or sliding) and 0 or math.clamp(speed / walkSpeed, 0, 1.3) * 0.10) + math.clamp(forwardAccel * 0.004, -0.06, 0.08), 8, dt)
				state.roll = approach(state.roll, air and 0 or math.clamp(turn * 0.035 * math.clamp(speed / walkSpeed, 0, 1), -0.16, 0.16), 6, dt)
				state.land = approach(state.land, 0, 7, dt)
				local attack = state.attack
				local tn, w = 0, 0
				if attack then
					attack.t += dt * ((localPlayer:GetAttribute("ZeroAtaqueLento") or 1) :: number)   -- solo para pruebas
					attack.swings = attack.swings or GOLPES_MAGIA[attack.nombre] or GOLPES[familyOf(character)] or GOLPES.Daga; attack.k = attack.k or 1
					local swing = attack.swings[attack.k]
					if swing and attack.t >= swing - 0.02 then attack.k += 1; Sfx.golpe(state.root, familyOf(character)) end
					tn = attack.t / attack.clip.duration
					if tn >= 1 then state.attack = nil; attack = nil
					else w = smooth(tn / 0.08) * smooth((1 - tn) / 0.12) end   -- la pista ya acaba en la guardia
				end
				local holding = character:FindFirstChildOfClass("Tool") ~= nil
				local garras = holding and familyOf(character) == "Garras" and not sliding
				local dash, dw = state.dash, 0
				if dash then
					dash.t += dt * ((localPlayer:GetAttribute("ZeroAtaqueLento") or 1) :: number)   -- solo para pruebas
					local dn = dash.t / dash.dur
					if dn >= 1 then state.dash = nil; dash = nil
					else dw = smooth(dn / 0.06) * smooth((1 - dn) / 0.12) end   -- entrada y salida cortas: los clips ya empiezan y acaban de pie
				end
				local hz = character:GetAttribute("ZeroHechizo")
				if hz ~= state.hzAttr then
					state.hzAttr = hz
					local nombre = if type(hz) == "string" then string.match(hz, "^[^:]+") else nil
					if nombre and clips[nombre] then
						-- encadenado (carga -> lanzar): entra sin fundido porque el clip nuevo empieza en la pose del anterior
						state.hechizo = { clip = clips[nombre], nombre = nombre, t = 0, directo = state.hechizo ~= nil }
					elseif state.hechizo and state.hechizo.clip.loop then state.hechizo.fin = state.hechizo.t end
				end
				local hech, hw, ht = state.hechizo, 0, 0
				if hech then
					hech.t += dt * ((localPlayer:GetAttribute("ZeroAtaqueLento") or 1) :: number)
					local dur = hech.clip.duration
					if hech.clip.loop then
						ht = hech.t % dur
						hw = (if hech.directo then 1 else smooth(hech.t / 0.15)) * (if hech.fin then 1 - smooth((hech.t - hech.fin) / 0.2) else 1)
						if hech.fin and hech.t - hech.fin >= 0.2 then state.hechizo = nil; hech = nil end
					elseif hech.t >= dur then state.hechizo = nil; hech = nil
					else
						ht = hech.t
						hw = (if hech.directo then 1 else smooth(hech.t / dur / 0.08)) * smooth((1 - hech.t / dur) / 0.12)
					end
				end
				local armaM = if holding then character:FindFirstChildOfClass("Tool"):FindFirstChild("ZeroArma") else nil
				local cuerpoM = if armaM then armaM:FindFirstChild("Cuerpo") else nil
				local baston = cuerpoM ~= nil and (cuerpoM:GetAttribute("Largo") or 0) > 3 and profile == "Hunter" and not sliding
				local hechizo = character:GetAttribute("ZeroBrazoHechizo")   -- habilidades que alzan el brazo (ReplicatedStorage.VFX.CristalesHielo)
				for name, motor in state.motors do
					local base = state.name == "Loco" and locoPose(state, name, profile) or sample(clip, t, name)
					local pose = (state.previous[name] or CFrame.identity):Lerp(base, blend)
					if garras and HOLD_GARRAS[name] then pose = pose:Lerp(HOLD_GARRAS[name], 0.75)
					elseif name == "Right Arm" and holding and not sliding and profile ~= "Hunter" then pose = pose:Lerp(HOLD, 0.7)
					elseif name == "Right Arm" and baston then pose = pose:Lerp(BASTON_HOLD, 0.85) end
					if dash and dash.clip and dash.clip.tracks[name] then
						local d = sample(dash.clip, math.min(dash.t / dash.dur, 1) * dash.clip.duration, name)
						if name == "Torso" or name == "Head" then pose = pose * CFrame.identity:Lerp(d, dw)
						else pose = pose:Lerp(d, dw) end
					end
					if attack and attack.clip.tracks[name] then
						local a = sample(attack.clip, tn * attack.clip.duration, name)
						do
							if name == "Torso" and not attack.clip.tracks["Right Leg"] then pose = pose:Lerp(CFrame.identity, w * 0.6) * CFrame.identity:Lerp(a, w)
							elseif name == "Torso" then pose = pose * CFrame.identity:Lerp(a, w)   -- el torso se suma al paso
							else pose = pose:Lerp(a, w) end
						end
					end
					if hech and hech.clip.tracks[name] then
						local a = sample(hech.clip, ht, name)
						if name == "Torso" then pose = pose:Lerp(CFrame.identity, hw * 0.6) * CFrame.identity:Lerp(a, hw) else pose = pose:Lerp(a, hw) end
					end
					if name == "Torso" then pose = pose * A(state.lean + state.land * 0.5, state.roll, 0)
					elseif name == "Head" then pose = pose * A(-(state.lean + state.land * 0.5) * 0.6, 0, 0)  -- la mirada sigue al frente
					elseif name == "Right Leg" then pose = pose * A(0, 0, state.land * 0.6)
					elseif name == "Left Leg" then pose = pose * A(0, 0, -state.land * 0.6) end
					if hechizo and hechizo > 0 then
						if name == "Right Arm" then pose = pose:Lerp(A(0.35, 0, math.rad(125)), hechizo)
						elseif name == "Head" then pose = pose:Lerp(A(-0.22, 0, 0), hechizo * 0.7) end
					end
					motor.Transform = pose
					state.ultima = state.ultima or {}; state.ultima[name] = pose   -- para el congelado
				end
				local brazo = character:FindFirstChild("Right Arm")
				local grip = brazo and brazo:FindFirstChild("RightGrip")
				if grip and grip:IsA("Weld") then
					if state.gripWeld ~= grip then state.gripWeld = grip; state.gripBase = grip.C0 end
					local giro, gw = nil, 0
					if hech and hech.clip.tracks.Grip then giro, gw = sample(hech.clip, ht, "Grip"), hw
					elseif attack and attack.clip.tracks.Grip then giro, gw = sample(attack.clip, tn * attack.clip.duration, "Grip"), w end
					if giro and gw > 0 then
						local tool = grip.Part1 and grip.Part1.Parent
						local cuerpo = tool and tool:FindFirstChild("ZeroArma") and tool.ZeroArma:FindFirstChild("Cuerpo")
						local reposo = if cuerpo and (cuerpo:GetAttribute("Largo") or 0) > 3 then 160 else 90   -- como ZeroArmasServer
						grip.C0 = state.gripBase * (if baston then A(math.rad(BASTON_MUNECA - 160), 0, 0) else CFrame.identity):Lerp(giro * A(-math.rad(reposo), 0, 0), gw)
					else
						local c0 = if baston then state.gripBase * A(math.rad(BASTON_MUNECA - 160), 0, 0) else state.gripBase
						if grip.C0 ~= c0 then grip.C0 = c0 end
					end
				end
				local locoName = state.moveW < 0.5 and "Idle" or state.runW > 0.5 and "Run" or "Walk"
				character:SetAttribute("ZeroAnimationState", state.hechizo and state.hechizo.nombre or attack and attack.nombre or (state.name == "Loco" and locoName or state.name))
				character:SetAttribute("ZeroAnimationClip", state.clipName)
				character:SetAttribute("ZeroAnimationProfile", esCazador(state.player) and "Hunter" or "Runner")
				character:SetAttribute("ZeroAnimationSource", clip.originalName)
			else
				-- congelado: estatua con la pose del instante del golpe, igual en todos los clientes (con la raíz anclada el
				-- Animator no reproduce nada en los demás y se veía tieso; el propio jugador veía su Animate)
				for name, motor in state.motors do motor.Transform = state.ultima and state.ultima[name] or CFrame.identity end
			end
		end
	end
end)

