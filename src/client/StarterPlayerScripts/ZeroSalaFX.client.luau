-- ZeroSalaFX (LocalScript en StarterPlayerScripts): ambiente de la "Sala del Cazador", solo en el cliente.
--  * Luz de laboratorio frío mientras la cámara está en la sala; al salir devuelve la luz del juego.
--  * Animaciones definidas en sala_cazador.py (lista ANIMS): ventiladores, radar, holograma y anillo de escaneo.
--    Un BulkMoveTo por fotograma y solo con la cámara cerca. Las piezas animadas no colisionan.
-- Generado por zero-maps/sala_cazador.py a partir de sala_fx.luau: editar la plantilla, no esta copia.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
if not game:IsLoaded() then game.Loaded:Wait() end

local CENTER = Vector3.new(6000, 60.0, 6000)              -- centro de la sala (suelo) en el mundo
local OFFSET = CENTER - Vector3.new(0, 60.0, 0)    -- coordenadas del generador -> mundo
local NEAR, FAR = 34, 60                          -- la sala mide 56 x 38: dentro = a menos de NEAR del centro (en X/Z)
local ANIMS = {{kind = "spin", path = "Animado/VentiladorTecho1", pivot = {-10, 91.1, 11}, axis = {0, 1, 0}, period = 1.6}, {kind = "spin", path = "Animado/VentiladorTecho2", pivot = {10, 91.1, 11}, axis = {0, 1, 0}, period = 1.6}, {kind = "spin", path = "Animado/AnilloEscaneo", pivot = {0, 66.2, -12}, axis = {0, 1, 0}, period = 6}, {kind = "spin", path = "Animado/Holograma", pivot = {24.6, 69.6, 6.0}, axis = {0, 1, 0}, period = 8}, {kind = "spin", path = "Animado/VentiladorPared1", pivot = {-14, 84.0, 18.4}, axis = {0, 0, 1}, period = -1.2}, {kind = "spin", path = "Animado/VentiladorPared2", pivot = {14, 84.0, 18.4}, axis = {0, 0, 1}, period = -1.2}}

-- ===================== luz de laboratorio =====================
local function own(class, name, props)
	local inst = Lighting:FindFirstChild(name) or Instance.new(class)
	inst.Name = name
	for k, v in props do inst[k] = v end
	inst.Parent = Lighting
	return inst
end
local cc = own("ColorCorrectionEffect", "ZeroSalaColor", { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
local LAB = {
	[Lighting] = {
		Ambient = Color3.fromRGB(92, 104, 122), OutdoorAmbient = Color3.fromRGB(110, 122, 140),
		EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.5, ExposureCompensation = 0.1,
	},
	BloomEffect = { Intensity = 0.25, Size = 22, Threshold = 2.2 },
}
local CC_ON = { Saturation = 0.02, Contrast = 0.05, Brightness = 0.01, TintColor = Color3.fromRGB(240, 248, 255) }
local CC_OFF = { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }
local saved, inRoom = {}, nil
local function setLab(on)
	if on == inRoom then return end
	inRoom = on
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Sine)
	for key, props in LAB do
		local inst = if typeof(key) == "Instance" then key else Lighting:FindFirstChildOfClass(key)
		if inst then
			if on then
				saved[inst] = {}
				for k in props do saved[inst][k] = inst[k] end
				TweenService:Create(inst, info, props):Play()
			elseif saved[inst] then
				TweenService:Create(inst, info, saved[inst]):Play()
			end
		end
	end
	TweenService:Create(cc, info, if on then CC_ON else CC_OFF):Play()
end

-- ===================== animaciones =====================
local parts, cfs, owner, base = {}, {}, {}, {}
local groups = {}

local function find(root, path)
	local node = root
	for seg in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(seg)
	end
	return node
end

local function collect(root)
	table.clear(parts); table.clear(owner); table.clear(base); table.clear(groups)
	for gi, a in ANIMS do
		local node = find(root, a.path)
		if node then
			local ref = if a.pivot then CFrame.new(Vector3.new(a.pivot[1], a.pivot[2], a.pivot[3]) + OFFSET) else CFrame.new()
			groups[gi] = { a = a, ref = ref, axis = a.axis and Vector3.new(a.axis[1], a.axis[2], a.axis[3]).Unit }
			for _, p in node:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(parts, p)
					owner[#parts] = gi
					base[#parts] = ref:ToObjectSpace(p.CFrame)
				end
			end
		end
	end
	table.clear(cfs)
end

local function groupCF(g, t)
	local a = g.a
	if a.kind == "spin" then
		return g.ref * CFrame.fromAxisAngle(g.axis, t / a.period * 2 * math.pi)
	elseif a.kind == "sway" then
		return g.ref * CFrame.fromAxisAngle(g.axis, math.rad(a.amp) * math.sin(t / a.period * 2 * math.pi + (a.phase or 0)))
	else -- bob
		return g.ref + Vector3.new(0, a.amp * math.sin(t / a.period * 2 * math.pi + (a.phase or 0)), 0)
	end
end

local ready, lastScan, room = false, 0, nil
local gcf = {}
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local pos = cam.CFrame.Position
	local d = math.max(math.abs(pos.X - CENTER.X), math.abs(pos.Z - CENTER.Z))
	setLab(d < NEAR and math.abs(pos.Y - CENTER.Y) < 40)
	if d > FAR then return end
	local t = os.clock()
	if t - lastScan > 2 then                               -- si la sala se recarga (streaming), volver a localizar las piezas
		lastScan = t
		local current = workspace:FindFirstChild("ZeroSalaCazador")
		if current ~= room or (ready and parts[1] and not parts[1]:IsDescendantOf(workspace)) then
			room, ready = current, false
			if room then collect(room); ready = #parts > 0 end
		end
	end
	if not ready then return end
	for gi, g in groups do gcf[gi] = groupCF(g, t) end
	for i = 1, #parts do cfs[i] = gcf[owner[i]] * base[i] end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
