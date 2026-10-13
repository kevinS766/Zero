-- ZeroCiudadFX (LocalScript en StarterPlayerScripts): ambiente del mapa "Ciudad Pastel", solo en el cliente.
--  * Luz de mediodía soleado mientras la cámara está en el mapa; al salir devuelve la luz del juego.
--  * Animaciones definidas en plaza_ciudad.py (lista ANIMS): coches por el anillo, grúa, agujas del reloj,
--    chorros de la fuente, tiovivo y columpios del parque, palomas y globos. Un BulkMoveTo por fotograma y solo
--    con la cámara cerca. Las piezas animadas no colisionan (solo existen así en el cliente).
-- Generado por zero-maps/plaza_ciudad.py a partir de ciudad_fx.luau: editar la plantilla, no esta copia.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
if not game:IsLoaded() then game.Loaded:Wait() end

local CENTER = Vector3.new(0, 60.0, 520)              -- centro del mapa (suelo) en el mundo
local OFFSET = CENTER - Vector3.new(0, 60.0, 0)    -- coordenadas del generador -> mundo
local ROT = CFrame.Angles(0, math.pi, 0)            -- el mapa está girado 180º para mirar al lobby
local MAPCF = CFrame.new(OFFSET) * ROT
local function W(v: Vector3): Vector3 return MAPCF:PointToWorldSpace(v) end
local function D(v: Vector3): Vector3 return ROT:VectorToWorldSpace(v) end
local NEAR, FAR = 190, 260
local RING_R = 8.0
local ANIMS = {{kind = "spin", path = "Animado/Agujas/Minutero1", pivot = {0.0, 81.0, -3.45}, axis = {0.0, 0, -1.0}, period = 60}, {kind = "spin", path = "Animado/Agujas/Horario1", pivot = {0.0, 81.0, -3.45}, axis = {0.0, 0, -1.0}, period = 720}, {kind = "spin", path = "Animado/Agujas/Minutero2", pivot = {-3.45, 81.0, -0.0}, axis = {-1.0, 0, -0.0}, period = 60}, {kind = "spin", path = "Animado/Agujas/Horario2", pivot = {-3.45, 81.0, -0.0}, axis = {-1.0, 0, -0.0}, period = 720}, {kind = "spin", path = "Animado/Agujas/Minutero3", pivot = {-0.0, 81.0, 3.45}, axis = {-0.0, 0, 1.0}, period = 60}, {kind = "spin", path = "Animado/Agujas/Horario3", pivot = {-0.0, 81.0, 3.45}, axis = {-0.0, 0, 1.0}, period = 720}, {kind = "spin", path = "Animado/Agujas/Minutero4", pivot = {3.45, 81.0, 0.0}, axis = {1.0, 0, 0.0}, period = 60}, {kind = "spin", path = "Animado/Agujas/Horario4", pivot = {3.45, 81.0, 0.0}, axis = {1.0, 0, 0.0}, period = 720}, {kind = "bob", path = "Animado/Chorros", amp = 0.35, period = 1.1, phase = 0}, {kind = "spin", path = "Animado/Palomas", pivot = {0, 78.0, 0}, axis = {0, 1, 0}, period = -24}, {kind = "bob", path = "Animado/Globos", amp = 0.6, period = 3.2, phase = 0.5}, {kind = "sway", path = "Animado/Columpio1", pivot = {-72, 67.4, -27}, axis = {1, 0, 0}, amp = 22, period = 2.6, phase = 0.0}, {kind = "sway", path = "Animado/Columpio2", pivot = {-72, 67.4, -27}, axis = {1, 0, 0}, amp = 22, period = 2.6, phase = 1.3}, {kind = "spin", path = "Animado/TiovivoParque", pivot = {-72, 60.0, -37}, axis = {0, 1, 0}, period = 7}, {kind = "sway", path = "Animado/GiroGrua", pivot = {-84, 60.0, 68}, axis = {0, 1, 0}, amp = 55, period = 30, phase = 0}, {kind = "ring", path = "Animado/CochesRonda/Coche1", lane = 105, dir = 1, s0 = 0.0, speed = 14, start = {105.0, -97.0, 0, 1}}, {kind = "ring", path = "Animado/CochesRonda/Coche2", lane = 105, dir = 1, s0 = 413.1327, speed = 14, start = {-105.0, 97.0, 0, -1}}, {kind = "ring", path = "Animado/CochesRonda/Coche3", lane = 99, dir = -1, s0 = 194.5664, speed = 14, start = {-91.0, -99.0, -1, 0}}, {kind = "ring", path = "Animado/CochesRonda/Coche4", lane = 99, dir = -1, s0 = 583.6991, speed = 14, start = {91.0, 99.0, 1.0, -0.0}}}

-- ===================== luz de mediodía =====================
local function own(class, name, props)
	local inst = Lighting:FindFirstChild(name) or Instance.new(class)
	inst.Name = name
	for k, v in props do inst[k] = v end
	inst.Parent = Lighting
	return inst
end
local cc = own("ColorCorrectionEffect", "ZeroCiudadColor", { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
local rays = own("SunRaysEffect", "ZeroCiudadRayos", { Intensity = 0, Spread = 0.7 })
local DAY = {
	[Lighting] = {
		ClockTime = 13.2, Brightness = 3.2, ExposureCompensation = 0.15,
		Ambient = Color3.fromRGB(96, 98, 110), OutdoorAmbient = Color3.fromRGB(160, 160, 172),
		ColorShift_Top = Color3.fromRGB(255, 244, 222), EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 0.6,
	},
	Atmosphere = { Density = 0.22, Offset = 0.15, Color = Color3.fromRGB(205, 228, 255), Decay = Color3.fromRGB(120, 160, 205), Glare = 0.15, Haze = 1.1 },
	BloomEffect = { Intensity = 0.35, Size = 24, Threshold = 1.9 },
}
local CC_ON = { Saturation = 0.18, Contrast = 0.07, Brightness = 0.02, TintColor = Color3.fromRGB(255, 251, 242) }
local CC_OFF = { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }
local saved, inMap = {}, nil
local ZONA = "Ciudad"   -- dueña de la luz: al salir solo restaura si nadie más la tomó
local function setDay(on)
	if on == inMap then return end
	inMap = on
	local owner = Lighting:GetAttribute("ZeroZona")
	if on then Lighting:SetAttribute("ZeroZona", ZONA) elseif owner == ZONA then Lighting:SetAttribute("ZeroZona", nil) end
	local restore = not on and owner == ZONA
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine)
	for key, props in DAY do
		local inst = if typeof(key) == "Instance" then key else Lighting:FindFirstChildOfClass(key)
		if inst then
			if on then
				saved[inst] = {}
				for k in props do saved[inst][k] = inst[k] end
				TweenService:Create(inst, info, props):Play()
			elseif restore then                   -- vuelve a los valores base de Studio (atributos Base_* de Lighting)
				local back = {}
				for k in props do
					local v = Lighting:GetAttribute("Base_" .. inst.ClassName .. "_" .. k)
					if v == nil and saved[inst] then v = saved[inst][k] end
					if v ~= nil then back[k] = v end
				end
				TweenService:Create(inst, info, back):Play()
			end
		end
	end
	TweenService:Create(cc, info, if on then CC_ON else CC_OFF):Play()
	TweenService:Create(rays, info, { Intensity = if on then 0.06 else 0 }):Play()
end

-- ===================== recorrido del anillo (mismo cálculo que ring_point en Python) =====================
local function ringPoint(s, L)
	local r = RING_R
	local straight, arc = 2 * (L - r), math.pi * r / 2
	local P = 4 * (straight + arc)
	s %= P
	local corners = { { L - r, L - r, 0 }, { -(L - r), L - r, 90 }, { -(L - r), -(L - r), 180 }, { L - r, -(L - r), 270 } }
	local starts = { { L, -(L - r), 0, 1 }, { L - r, L, -1, 0 }, { -L, L - r, 0, -1 }, { -(L - r), -L, 1, 0 } }
	for k = 1, 4 do
		local st = starts[k]
		if s < straight then return st[1] + st[3] * s, st[2] + st[4] * s, st[3], st[4] end
		s -= straight
		local c = corners[k]
		if s < arc then
			local a = math.rad(c[3]) + s / r
			return c[1] + r * math.cos(a), c[2] + r * math.sin(a), -math.sin(a), math.cos(a)
		end
		s -= arc
	end
	return L, -(L - r), 0, 1
end
local function ringLength(L) return 4 * (2 * (L - RING_R) + math.pi * RING_R / 2) end

-- ===================== animaciones =====================
local parts, cfs, owner, base = {}, {}, {}, {}
local groups = {}

local function find(map, path)
	local node = map
	for seg in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(seg)
	end
	return node
end

local function collect(map)
	table.clear(parts); table.clear(owner); table.clear(base); table.clear(groups)
	for gi, a in ANIMS do
		local node = find(map, a.path)
		if node then
			local ref
			if a.kind == "ring" then
				local st = a.start                       -- posición y dirección del coche cuando se generó
				local p = W(Vector3.new(st[1], 0, st[2]))
				ref = CFrame.lookAt(p, p + D(Vector3.new(st[3], 0, st[4])))
			elseif a.pivot then
				ref = CFrame.new(W(Vector3.new(a.pivot[1], a.pivot[2], a.pivot[3])))
			else
				ref = CFrame.new()
			end
			groups[gi] = { a = a, ref = ref, axis = a.axis and D(Vector3.new(a.axis[1], a.axis[2], a.axis[3])).Unit }
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
	elseif a.kind == "bob" then
		return g.ref + Vector3.new(0, a.amp * math.sin(t / a.period * 2 * math.pi + (a.phase or 0)), 0)
	else -- ring
		local P = ringLength(a.lane)
		local s = a.s0 + a.speed * t
		if a.dir < 0 then s = P - (s % P) end
		local x, z, dx, dz = ringPoint(s, a.lane)
		if a.dir < 0 then dx, dz = -dx, -dz end
		local p = W(Vector3.new(x, 0, z))
		return CFrame.lookAt(p, p + D(Vector3.new(dx, 0, dz)))      -- igual que `ref` en su punto de salida
	end
end

-- Zona horaria = el rectángulo real del modelo (X/Z, con margen), no un radio fijo desde el centro: los mapas
-- miden 500-800 studs y con el radio antiguo sus bordes "salían" del mapa y volvía la luz por defecto.
-- La caja va en los atributos ZonaMin/ZonaMax del modelo (calculados con el modelo completo en Studio): con
-- StreamingEnabled el cliente solo tiene las piezas cercanas y GetBoundingBox saldría más pequeña.
local function inZone(model: Instance?, pos: Vector3, margin: number): boolean
	if not model or not model:IsDescendantOf(workspace) then return false end
	local lo, hi = model:GetAttribute("ZonaMin"), model:GetAttribute("ZonaMax")
	if typeof(lo) ~= "Vector3" or typeof(hi) ~= "Vector3" then return false end
	return pos.X >= lo.X - margin and pos.X <= hi.X + margin and pos.Z >= lo.Z - margin and pos.Z <= hi.Z + margin
		and pos.Y < hi.Y + 120
end

local ready, lastScan, map = false, 0, nil
local gcf = {}
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local pos = cam.CFrame.Position
	local d = math.max(math.abs(pos.X - CENTER.X), math.abs(pos.Z - CENTER.Z))
	local inside = inZone(workspace:FindFirstChild("Map4_CiudadPastel"), pos, 25)
	setDay(inside)
	if not inside and d > FAR then return end
	local t = os.clock()
	if t - lastScan > 2 then                               -- el mapa entra y sale del Workspace según la votación:
		lastScan = t                                       -- si cambia (o se descargó), volver a localizar las piezas
		local current = workspace:FindFirstChild("Map4_CiudadPastel")
		if current ~= map or (ready and parts[1] and not parts[1]:IsDescendantOf(workspace)) then
			map, ready = current, false
			if map then collect(map); ready = #parts > 0 end
		end
	end
	if not ready then return end
	for gi, g in groups do gcf[gi] = groupCF(g, t) end
	for i = 1, #parts do cfs[i] = gcf[owner[i]] * base[i] end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
