-- ZeroHabilidadArmaServer (Script, ServerScriptService): habilidad de la tecla E del cazador según la rareza del arma
-- equipada (ReplicatedStorage.ZeroHabilidadesConfig). Valida (cazador, no congelado, ronda activa salvo en Studio,
-- cooldown), limita el objetivo al alcance, avisa a todos los clientes con la hora del servidor (efecto sincronizado) y,
-- cuando estalla, aturde a los corredores del radio: HumanoidRootPart anclado, igual que el congelamiento (vale para
-- jugadores y bots, y Dash/Slide ya miran Anchored).
-- En la ARENA DE PRUEBAS (ServerScriptService.ZeroPruebas, solo admins) no hace falta ronda ni ser cazador, no hay cooldown,
-- no cuenta para las misiones y los dummies de la arena hacen de corredores.
-- RemoteEvent ReplicatedStorage.ZeroHabilidadArma:
--   cliente -> servidor  { objetivo = Vector3 }
--   servidor -> todos    { kind = "Rafaga", skin, caster, origen, objetivo, inicio, cooldown }
--                        { kind = "Aturdidos", modulo, skin, victimas = { Model }, dur }
--                        { kind = "Vortice", skin, caster, origen, objetivo, inicio, cooldown, duracion }
--                        { kind = "Cegados", modulo, skin, victimas = { Model }, dur }
--                        { kind = "Salto", skin, caster, origen, objetivo (= pies del destino), inicio, cooldown }
--                        { kind = "Dragon", skin, caster, origen, objetivo (solo da la dirección), inicio, cooldown }
--   Común (Bola): cliente -> { accion = "cargar" } al pulsar y { accion = "soltar", objetivo } al soltar
--                        { kind = "BolaCarga", skin, caster, inicio, carga } / { kind = "BolaCancelar", caster }
--                        { kind = "Bola", skin, caster, origen, objetivo, inicio, cooldown, carga (0..1), radio }
--                        { kind = "Lentos", modulo, skin, victimas = { Model }, dur }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerRoles = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerRoles"))
local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local PlayerState = require(Services:WaitForChild("PlayerStateService"))
local Habilidades = require(ReplicatedStorage:WaitForChild("ZeroHabilidadesConfig"))
local VFX = ReplicatedStorage:WaitForChild("VFX")
local Pruebas = require(ServerScriptService:WaitForChild("ZeroPruebas"))

local remote = Instance.new("RemoteEvent")
remote.Name = "ZeroHabilidadArma"
remote.Parent = ReplicatedStorage

local ultimo: { [Player]: number } = {}
local aturdidos: { [any]: number } = {}

local function rondaActiva(player: Player?): boolean
	return RunService:IsStudio() or ReplicatedStorage:GetAttribute("RoundState") == "ROUND_ACTIVE"   -- lo publica RoundService
		or (player ~= nil and Pruebas.activo(player))
end

-- posibles víctimas: corredores sin congelar (jugadores y bots) y, en la arena de pruebas, los dummies
local function corredores(player: Player): { any }
	local l = {}
	for _, actor in PlayerState.getActors() do
		if actor ~= player and PlayerState.getRole(actor) == PlayerRoles.RUNNER and not PlayerState.isPlayerFrozen(actor) then table.insert(l, actor) end
	end
	if Pruebas.activo(player) then for _, d in Pruebas.corredores() do table.insert(l, d) end end
	return l
end

local function aturdir(actor: any, dur: number): Model?
	if actor.ZeroDummy then return Pruebas.aturdir(actor, dur) end
	local char = actor.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end
	local serial = (aturdidos[actor] or 0) + 1
	aturdidos[actor] = serial
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.Anchored = true
	char:SetAttribute("ZeroSprinting", false)
	char:SetAttribute("ZeroAturdido", true)
	task.delay(dur, function()
		if aturdidos[actor] ~= serial then return end
		aturdidos[actor] = nil
		char:SetAttribute("ZeroAturdido", nil)
		-- si lo congelaron mientras tanto, el congelamiento manda
		if hrp.Parent and actor.Character == char and not PlayerState.isPlayerFrozen(actor) then hrp.Anchored = false end
	end)
	return char
end

-- ralentizado: multiplicador de velocidad en el atributo ZeroLento (jugador y personaje); lo aplican ZeroSprint (jugadores)
-- y BotService (bots). En la arena, los dummies.
local lentos: { [any]: number } = {}
local function ralentizar(actor: any, factor: number, dur: number): Model?
	if actor.ZeroDummy then return Pruebas.ralentizar(actor, factor, dur) end
	local char = actor.Character
	if not char then return nil end
	local serial = (lentos[actor] or 0) + 1
	lentos[actor] = serial
	char:SetAttribute("ZeroLento", factor)
	if typeof(actor) == "Instance" then actor:SetAttribute("ZeroLento", factor) end
	task.delay(dur, function()
		if lentos[actor] ~= serial then return end
		lentos[actor] = nil
		char:SetAttribute("ZeroLento", nil)
		if typeof(actor) == "Instance" then actor:SetAttribute("ZeroLento", nil) end
	end)
	return char
end

local function objetivoEn(char: Model, origen: Vector3, frente: Vector3, apuntado: any, alcance: number): Vector3
	local objetivo = origen + frente * alcance * 0.75
	if typeof(apuntado) == "Vector3" then
		local d = apuntado - origen
		local plano = Vector3.new(d.X, 0, d.Z)
		if plano.Magnitude >= 4 then
			objetivo = origen + plano.Unit * math.min(plano.Magnitude, alcance) + Vector3.new(0, math.clamp(d.Y, -20, 20), 0)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignorar = { char }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignorar, p.Character) end end
	for _, n in { "ZeroBots", "ZeroVFX" } do local f = workspace:FindFirstChild(n); if f then table.insert(ignorar, f) end end
	params.FilterDescendantsInstances = ignorar
	local hit = workspace:Raycast(objetivo + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position else Vector3.new(objetivo.X, origen.Y - 3, objetivo.Z)
end

-- efecto en el servidor de cada mecánica (lo visual lo hacen los clientes)
local EFECTO = {}
function EFECTO.Rafaga(player: Player, hab, skin: string?, modulo, origen: Vector3, objetivo: Vector3)
	task.delay(modulo.estallido(origen, objetivo), function()
		if not rondaActiva(player) then return end
		local victimas = {}
		for _, actor in corredores(player) do
			local root = actor.Character and actor.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local d = root.Position - objetivo
				if Vector2.new(d.X, d.Z).Magnitude <= hab.radio and math.abs(d.Y) <= 7 then
					local c = aturdir(actor, hab.aturdir)
					if c then table.insert(victimas, c) end
				end
			end
		end
		if #victimas > 0 then remote:FireAllClients({ kind = "Aturdidos", modulo = hab.modulo, skin = skin, victimas = victimas, dur = hab.aturdir }) end
	end)
end
-- Vórtice (Épico): mientras dura la zona, todo corredor que esté dentro (jugador o bot) queda cegado una vez; cada
-- cliente cegado oscurece su propia pantalla (VFX.Vortice.cegado). Los bots no "ven": solo llevan la nube encima.
function EFECTO.Vortice(player: Player, hab, skin: string?, modulo, origen: Vector3, objetivo: Vector3)
	task.delay(modulo.impacto(origen, objetivo), function()
		local hasta = os.clock() + hab.duracion
		local ya = {}
		while os.clock() < hasta and rondaActiva(player) do
			local nuevos = {}
			for _, actor in corredores(player) do
				if ya[actor] then continue end
				local root = actor.Character and actor.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local d = root.Position - objetivo
					if Vector2.new(d.X, d.Z).Magnitude <= hab.radio and math.abs(d.Y) <= 8 then
						ya[actor] = true
						table.insert(nuevos, actor.Character)
					end
				end
			end
			if #nuevos > 0 then
				remote:FireAllClients({ kind = "Cegados", modulo = hab.modulo, skin = skin, victimas = nuevos, dur = hab.cegar })
			end
			task.wait(0.1)
		end
	end)
end

-- Salto (Legendario): tras el aviso mueve al cazador al destino (ya validado) y aturde a los corredores de alrededor
function EFECTO.Salto(player: Player, hab, skin: string?, modulo, origen: Vector3, destino: Vector3)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	local suelo = workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), (function()
		local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = { char }; return rp end)())
	local alto = if suelo then hrp.Position.Y - suelo.Position.Y else 3
	task.delay(modulo.AVISO, function()
		if not rondaActiva(player) or char.Parent == nil or hrp.Anchored or PlayerState.isPlayerFrozen(player) then return end
		local plano = Vector3.new(destino.X - hrp.Position.X, 0, destino.Z - hrp.Position.Z)
		local mira = if plano.Magnitude > 0.1 then plano.Unit else hrp.CFrame.LookVector
		local pos = destino + Vector3.new(0, alto, 0)
		char:PivotTo(CFrame.lookAt(pos, pos + mira))
		hrp.AssemblyLinearVelocity = Vector3.zero
		local victimas = {}
		for _, actor in corredores(player) do
			local root = actor.Character and actor.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local d = root.Position - destino
				if Vector2.new(d.X, d.Z).Magnitude <= hab.radio and math.abs(d.Y) <= 7 then
					local c = aturdir(actor, hab.aturdir)
					if c then table.insert(victimas, c) end
				end
			end
		end
		if #victimas > 0 then remote:FireAllClients({ kind = "Aturdidos", modulo = hab.modulo, skin = skin, victimas = victimas, dur = hab.aturdir }) end
	end)
end

-- Dragón (Mítico): sigue el mismo camino que dibujan los clientes (VFX.Dragon.ruta); cuando la cabeza pasa por donde está
-- un corredor dentro de la franja (o está junto al pilar final cuando estalla) lo CONGELA, igual que el cuchillo
-- (PlayerStateService.freezeRunner: 12 s, rescatable, cuenta para ganar), y lo lanza hacia arriba antes de dejarlo quieto
-- (el HRP congelado va anclado: lo movemos a mano y vuelve a su sitio)
local DataService = require(Services:WaitForChild("DataService"))
local function lanzar(char: Model, hrp: BasePart)
	local base = hrp.CFrame
	local t0 = os.clock()
	local c: RBXScriptConnection
	c = RunService.Heartbeat:Connect(function()
		local f = (os.clock() - t0) / 0.8
		if f >= 1 or not hrp.Parent or not hrp.Anchored or char:GetAttribute("Status") ~= "Frozen" then
			c:Disconnect()
			if hrp.Parent and hrp.Anchored then hrp.CFrame = base end
			return
		end
		hrp.CFrame = base * CFrame.new(0, 8 * math.sin(math.pi * f) * (1 - f * 0.25), 0) * CFrame.Angles(0, f * math.pi * 2, 0)
	end)
end
function EFECTO.Dragon(player: Player, hab, skin: string?, modulo, origen: Vector3, objetivo: Vector3)
	local ruta = modulo.ruta(origen, objetivo, hab.alcance, player.Character, skin)   -- el largo de la criatura decide cuándo estalla el pilar
	local t0 = os.clock()
	local posFinal, tFinal = modulo.final(ruta)
	local fin = tFinal
	local ya = {}
	task.spawn(function()
		while os.clock() - t0 < fin + 0.6 and rondaActiva(player) do
			local t = os.clock() - t0
			local victimas = {}
			for _, actor in corredores(player) do
				if ya[actor] then continue end
				local root = actor.Character and actor.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root then continue end
				local d = root.Position - ruta.portal
				local a = d:Dot(ruta.dir)
				local lado = math.abs(d:Dot(ruta.lado))
				local enFranja = a >= -3 and a <= hab.alcance + 2 and lado <= hab.ancho / 2 and d.Y >= -6 and d.Y <= ruta.alto + 7 and t >= modulo.cuando(ruta, a)
				local f = root.Position - posFinal
				local enPilar = t >= tFinal and Vector2.new(f.X, f.Z).Magnitude <= hab.radioFinal and math.abs(f.Y) <= 10
				if enFranja or enPilar then
					ya[actor] = true
					local c = actor.Character
					if actor.ZeroDummy then
						if Pruebas.congelar(actor, player) then table.insert(victimas, c); lanzar(c, root) end
					elseif PlayerState.freezeRunner(actor, player) then   -- player: para las rachas (ZeroJugadas)
						table.insert(victimas, c); lanzar(c, root)
						if PlayerState.isHuman(player) then DataService.incrementStat(player, "hunter_tags", 1) end
					end
				end
			end
			if #victimas > 0 then remote:FireAllClients({ kind = "Aturdidos", modulo = hab.modulo, skin = skin, victimas = victimas, dur = 1.2 }) end
			task.wait(0.05)
		end
	end)
end

-- Bola (Común): tras el vuelo, ralentiza a los corredores del área (más grande y más largo cuanto más cargada)
function EFECTO.Bola(player: Player, hab, skin: string?, modulo, origen: Vector3, objetivo: Vector3, f: number)
	task.delay(modulo.vuelo(origen, objetivo), function()
		if not rondaActiva(player) then return end
		local radio, dur = modulo.radio(hab, f), modulo.lentoDura(hab, f)
		local victimas = {}
		for _, actor in corredores(player) do
			local root = actor.Character and actor.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local d = root.Position - objetivo
				if Vector2.new(d.X, d.Z).Magnitude <= radio and math.abs(d.Y) <= 8 then
					local c = ralentizar(actor, hab.lento, dur)
					if c then table.insert(victimas, c) end
				end
			end
		end
		if #victimas > 0 then remote:FireAllClients({ kind = "Lentos", modulo = hab.modulo, skin = skin, victimas = victimas, dur = dur, caster = player.Character }) end
	end)
end

local cargando: { [Player]: any } = {}

-- valida que el jugador puede usar ahora la habilidad (rol, ronda, cooldown, vivo, no anclado); devuelve hab, skin, char, hrp
local function puede(player: Player)
	local prueba = Pruebas.activo(player)
	if not rondaActiva(player) then return nil end
	if (not prueba and PlayerState.getRole(player) ~= PlayerRoles.HUNTER) or PlayerState.isPlayerFrozen(player) then return nil end
	local hab, skin = Habilidades.de(Habilidades.armaDe(player))
	if not hab then return nil end
	if not prueba and os.clock() - (ultimo[player] or -math.huge) < hab.cooldown - 0.5 then return nil end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not hrp or hrp.Anchored then return nil end
	return hab, skin, char, hrp, prueba
end

local function soltarBola(player: Player, apuntado: any)
	local c = cargando[player]
	if not c then return end
	cargando[player] = nil
	local hab, skin, char, hrp, prueba = puede(player)
	if not hab or hab.modulo ~= "Bola" then                               -- lo congelaron/aturdieron cargando: se pierde
		remote:FireAllClients({ kind = "BolaCancelar", caster = c.char })
		return
	end
	local modulo = require(VFX:WaitForChild("Bola")) :: any
	local f = modulo.fraccion(os.clock() - c.t0, hab)
	ultimo[player] = os.clock()
	local origen = hrp.Position + Vector3.new(0, 3, 0)
	local look = hrp.CFrame.LookVector
	local objetivo = objetivoEn(char, hrp.Position, Vector3.new(look.X, 0, look.Z).Unit, apuntado, hab.alcance)
	remote:FireAllClients({ kind = "Bola", skin = skin, caster = char, origen = origen, objetivo = objetivo, inicio = workspace:GetServerTimeNow(),
		cooldown = if prueba then 0 else hab.cooldown, carga = f, radio = modulo.radio(hab, f) })
	if not prueba then player:SetAttribute("ZeroHabilidadSerial", (player:GetAttribute("ZeroHabilidadSerial") or 0) + 1) end   -- misiones
	EFECTO.Bola(player, hab, skin, modulo, origen, objetivo, f)
end

remote.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then return end
	-- Común: cargar al pulsar, lanzar al soltar (si no suelta en carga + 3 s, sale sola a tope)
	if payload.accion == "cargar" then
		local hab, skin, char = puede(player)
		if not hab or hab.modulo ~= "Bola" or cargando[player] then return end
		local c = { t0 = os.clock(), char = char }
		cargando[player] = c
		remote:FireAllClients({ kind = "BolaCarga", skin = skin, caster = char, inicio = workspace:GetServerTimeNow(), carga = hab.carga })
		task.delay(hab.carga + 3, function() if cargando[player] == c then soltarBola(player, nil) end end)
		return
	elseif payload.accion == "soltar" then
		soltarBola(player, payload.objetivo)
		return
	end
	local prueba = Pruebas.activo(player)                                  -- arena de pruebas: sin ronda, sin rol y sin cooldown
	if typeof(payload) ~= "table" or not rondaActiva(player) then return end
	if (not prueba and PlayerState.getRole(player) ~= PlayerRoles.HUNTER) or PlayerState.isPlayerFrozen(player) then return end
	local hab, skin = Habilidades.de(Habilidades.armaDe(player))
	if not hab or hab.modulo == "Bola" then return end                    -- la Bola va por cargar/soltar
	local ahora = os.clock()
	if not prueba and ahora - (ultimo[player] or -math.huge) < hab.cooldown - 0.5 then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not hrp or hrp.Anchored then return end   -- anclado: aturdido o retenido al empezar la ronda
	local modulo = require(VFX:WaitForChild(hab.modulo)) :: any

	ultimo[player] = ahora
	local origen = hrp.Position
	local look = hrp.CFrame.LookVector
	local objetivo = objetivoEn(char, origen, Vector3.new(look.X, 0, look.Z).Unit, payload.objetivo, hab.alcance)
	if modulo.destino then                                                -- Salto: hay que ver el destino, tener suelo y caber
		local d = modulo.destino(char, objetivo)
		if not d then ultimo[player] = nil; return end
		objetivo = d
	end
	remote:FireAllClients({ kind = hab.modulo, skin = skin, caster = char, origen = origen, objetivo = objetivo,
		inicio = workspace:GetServerTimeNow(), cooldown = if prueba then 0 else hab.cooldown, duracion = hab.duracion })
	if not prueba then player:SetAttribute("ZeroHabilidadSerial", (player:GetAttribute("ZeroHabilidadSerial") or 0) + 1) end   -- misiones
	EFECTO[hab.modulo](player, hab, skin, modulo, origen, objetivo)
end)

Players.PlayerRemoving:Connect(function(p) ultimo[p] = nil; aturdidos[p] = nil; cargando[p] = nil; lentos[p] = nil end)

