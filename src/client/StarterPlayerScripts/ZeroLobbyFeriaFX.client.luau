-- ZeroLobbyFeriaFX (LocalScript en StarterPlayerScripts): la vida de la feria del lobby, solo en el cliente.
--  * Bombillas: todas las piezas "Bombilla" del lobby (menos las del cartel de la ronda, que ya mueve ZeroTimerLuzFX)
--    "respiran" en una ola lenta que recorre la feria: nunca se apagan, solo bajan un poco el brillo (no distrae).
--    El hielo del copo de nieve del spawn ("Hielo", "HieloCopo") respira igual, y del suelo suben chispitas de escarcha.
--  * El copo gigante del kiosco, la estrella de la aguja y las sillas voladoras del fondo giran (admite giro con sube y
--    baja, vaivén y balanceo). La noria y los banderines los sigue moviendo ZeroLobbyFX.
-- Las piezas animadas no colisionan: solo se mueven en el cliente. Todo se para con la cámara lejos del lobby.
-- Generado por zero-maps/lobby_v2.py a partir de lobby_feria_fx.luau: editar la plantilla, no esta copia.
local RunService = game:GetService("RunService")
if not game:IsLoaded() then game.Loaded:Wait() end

local lobby = workspace:WaitForChild("ZeroLobby")
local LOBBY = Vector3.new(0, 60, 0)
local FAR = 260                                       -- más lejos (jugando en un mapa) no se anima nada
local ANIMS = {{kind = "spin", path = "Feria/Animado/CopoKiosco", pivot = {0.0, 79.2, 2.0}, axis = {0, 1, 0}, period = 16}, {kind = "spin", path = "Feria/Animado/Estrella", pivot = {0.0, 101.8, 2.0}, axis = {0, 1, 0}, period = 6}, {kind = "spin", path = "Fondo/SillasVoladoras/Giro", pivot = {112.0, 58.0, -48.0}, axis = {0, 1, 0}, period = 8}}
local TAU = 2 * math.pi

-- ===================== bombillas =====================
local LOW, SPEED, RATE = 0.72, 1.7, 1 / 12            -- brillo mínimo (72 %), velocidad de la ola y 12 cambios por segundo
local timer = lobby:FindFirstChild("TimerDisplay")
local GLOW = { Bombilla = true, Hielo = true, HieloCopo = true }
local bulbs, baseCol, phase = {}, {}, {}
local function collectBulbs()
	table.clear(bulbs)
	for _, p in lobby:GetDescendants() do
		if p:IsA("BasePart") and GLOW[p.Name] and not (timer and p:IsDescendantOf(timer)) then
			table.insert(bulbs, p)
			if not baseCol[p] then
				baseCol[p] = p.Color
				phase[p] = p.Position.X * 0.11 + p.Position.Z * 0.07 + p.Position.Y * 0.05
			end
		end
	end
end
collectBulbs()

-- ===================== chispitas de escarcha que suben del suelo del spawn =====================
local function chispas()
	local k = lobby:FindFirstChild("SpawnZone") and lobby.SpawnZone:FindFirstChild("Kiosco")
	local base = k and k:FindFirstChild("ChispasHielo")
	if not base or base:FindFirstChildOfClass("ParticleEmitter") then return end
	local e = Instance.new("ParticleEmitter")
	e.Name = "Escarcha"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(215, 248, 255), Color3.fromRGB(125, 215, 255))
	e.LightEmission = 0.7
	e.Rate = 9
	e.Lifetime = NumberRange.new(2.2, 3.6)
	e.Speed = NumberRange.new(1.2, 2.6)
	e.SpreadAngle = Vector2.new(10, 10)
	e.EmissionDirection = Enum.NormalId.Top
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = base
end
chispas()

-- ===================== piezas que se mueven (un solo BulkMoveTo por fotograma) =====================
local function find(path)
	local n = lobby
	for seg in string.gmatch(path, "[^/]+") do n = n and n:FindFirstChild(seg) end
	return n
end
local function vec(t) return Vector3.new(t[1], t[2], t[3]) end
local parts, base, owner, groups = {}, {}, {}, {}
local function collect()
	table.clear(parts); table.clear(base); table.clear(owner); table.clear(groups)
	for gi, a in ANIMS do
		local node = find(a.path)
		if node then
			local ref = if a.pivot then CFrame.new(vec(a.pivot)) else CFrame.new()
			groups[gi] = { a = a, ref = ref, axis = a.axis and vec(a.axis).Unit, dir = if a.dir then vec(a.dir) else Vector3.yAxis }
			for _, p in node:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(parts, p)
					owner[#parts] = gi
					base[#parts] = ref:ToObjectSpace(p.CFrame)
				end
			end
		end
	end
end
collect()

local function groupCF(g, t)
	local a = g.a
	local w = t / a.period * TAU + (a.phase or 0)
	if a.kind == "spin" then
		local cf = g.ref * CFrame.fromAxisAngle(g.axis, w)
		if a.bob then cf += Vector3.yAxis * (a.bob * math.sin(t / a.bob_period * TAU + (a.bob_phase or 0))) end
		return cf
	elseif a.kind == "sway" then
		return g.ref * CFrame.fromAxisAngle(g.axis, math.rad(a.amp) * math.sin(w))
	else -- bob: vaivén en `dir`
		return g.ref + g.dir * (a.amp * math.sin(w))
	end
end

local gcf, cfs = {}, {}
local acc, lastScan = 0, os.clock()
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - LOBBY).Magnitude > FAR then return end
	local t = os.clock()
	if t - lastScan > 5 then                           -- por si el streaming o un cambio en el lobby trae piezas nuevas
		lastScan = t
		if #parts == 0 or (parts[1] and not parts[1]:IsDescendantOf(lobby)) then collect() end
		if #bulbs == 0 or (bulbs[1] and not bulbs[1]:IsDescendantOf(lobby)) then collectBulbs() end
	end
	if #parts > 0 then
		for gi, g in groups do gcf[gi] = groupCF(g, t) end
		for i = 1, #parts do cfs[i] = gcf[owner[i]] * base[i] end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	acc += dt
	if acc < RATE then return end
	acc = 0
	for _, p in bulbs do
		local c = baseCol[p]
		local k = LOW + (1 - LOW) * (0.5 + 0.5 * math.sin(t * SPEED - phase[p]))
		p.Color = Color3.new(c.R * k, c.G * k, c.B * k)
	end
end)
