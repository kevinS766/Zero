-- ZeroCiudadFX (LocalScript en StarterPlayerScripts): ambiente del mapa "Ciudad Pastel", solo en el cliente.
--  * Luz de mediodía soleado mientras la cámara está en la ciudad (caja ZonaMin/ZonaMax del modelo); al salir
--    vuelve la luz base (atributos Base_* de Lighting) si nadie más tomó la luz (Lighting.ZeroZona).
--  * Animaciones definidas en plaza_ciudad.py (lista ANIMS): coches por el anillo, tren entre túneles, agujas del
--    reloj, chorros de la fuente, palomas, globos, columpios, tiovivo, patos, cometa, helado gigante, molinillos,
--    estrella del arcade, pizza, banderas, grúa, globo aerostático y nubes. Un BulkMoveTo por fotograma y solo con
--    la cámara cerca (también desde el lobby). Las piezas animadas no colisionan: solo existen así en el cliente.
-- Generado por zero-maps/plaza_ciudad.py a partir de ciudad_fx.luau: editar la plantilla, no esta copia.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
if not game:IsLoaded() then game.Loaded:Wait() end

local CENTER = Vector3.new(0, 60.0, 235)              -- origen del generador (suelo) en el mundo
local OFFSET = CENTER - Vector3.new(0, 60.0, 0)    -- coordenadas del generador -> mundo (el mapa no va girado)
local FAR = 360                                   -- el lobby (a ~240 del centro) también ve las animaciones
local RING_R = 8.0
local ANIMS = {{kind = "spin", path = "Animado/Agujas/Minutero1", pivot = {0.0, 81.0, -3.45}, axis = {0.0, 0, -1.0}, period = 60}, {kind = "spin", path = "Animado/Agujas/Horario1", pivot = {0.0, 81.0, -3.45}, axis = {0.0, 0, -1.0}, period = 720}, {kind = "spin", path = "Animado/Agujas/Minutero2", pivot = {-3.45, 81.0, -0.0}, axis = {-1.0, 0, -0.0}, period = 60}, {kind = "spin", path = "Animado/Agujas/Horario2", pivot = {-3.45, 81.0, -0.0}, axis = {-1.0, 0, -0.0}, period = 720}, {kind = "spin", path = "Animado/Agujas/Minutero3", pivot = {-0.0, 81.0, 3.45}, axis = {-0.0, 0, 1.0}, period = 60}, {kind = "spin", path = "Animado/Agujas/Horario3", pivot = {-0.0, 81.0, 3.45}, axis = {-0.0, 0, 1.0}, period = 720}, {kind = "spin", path = "Animado/Agujas/Minutero4", pivot = {3.45, 81.0, 0.0}, axis = {1.0, 0, 0.0}, period = 60}, {kind = "spin", path = "Animado/Agujas/Horario4", pivot = {3.45, 81.0, 0.0}, axis = {1.0, 0, 0.0}, period = 720}, {kind = "bob", path = "Animado/Chorros", amp = 0.35, period = 1.1, phase = 0}, {kind = "sway", path = "Animado/Banderolas/Reloj", pivot = {0, 95.0, 0}, axis = {0, 1, 0}, amp = 20, period = 1.8, phase = 0}, {kind = "spin", path = "Animado/Palomas", pivot = {0, 78.0, 0}, axis = {0, 1, 0}, period = -24}, {kind = "bob", path = "Animado/Globos", amp = 0.6, period = 3.2, phase = 0.5}, {kind = "sway", path = "Animado/Banderolas/Kiosko", pivot = {-61.5, 78.3, -61.5}, axis = {0, 1, 0}, amp = 22, period = 1.7, phase = 1}, {kind = "spin", path = "Animado/Patos", pivot = {-37, 60.0, -86}, axis = {0, 1, 0}, period = 18}, {kind = "sway", path = "Animado/Columpio1", pivot = {-82, 67.4, -31}, axis = {1, 0, 0}, amp = 22, period = 2.6, phase = 0.0}, {kind = "sway", path = "Animado/Columpio2", pivot = {-82, 67.4, -31}, axis = {1, 0, 0}, amp = 22, period = 2.6, phase = 1.3}, {kind = "spin", path = "Animado/TiovivoParque", pivot = {-82, 60.0, -41}, axis = {0, 1, 0}, period = 7}, {kind = "sway", path = "Animado/Cometa", pivot = {-40, 61.5, -40}, axis = {1, 0, 1}, amp = 8, period = 4.2, phase = 0}, {kind = "sway", path = "Animado/Banderas/Bandera1", pivot = {36.5, 71.2, -46}, axis = {0, 1, 0}, amp = 18, period = 1.6, phase = 0}, {kind = "sway", path = "Animado/Banderas/Bandera2", pivot = {41.5, 71.2, -46}, axis = {0, 1, 0}, amp = 18, period = 1.8, phase = 1}, {kind = "sway", path = "Animado/Banderas/Bandera3", pivot = {46.5, 71.2, -46}, axis = {0, 1, 0}, amp = 18, period = 2.0, phase = 2}, {kind = "sway", path = "Animado/Banderas/Bandera4", pivot = {51.5, 71.2, -46}, axis = {0, 1, 0}, amp = 18, period = 2.2, phase = 3}, {kind = "spin", path = "Animado/EstrellaArcade", pivot = {84.0, 84.5, 28.0}, axis = {0, 1, 0}, period = 6}, {kind = "spin", path = "Animado/Pizza", pivot = {24.0, 80.0, 66.0}, axis = {0, 1, 0}, period = 8}, {kind = "spin", path = "Animado/HeladoGigante", pivot = {-58, 60.0, 72}, axis = {0, 1, 0}, period = 40}, {kind = "spin", path = "Animado/Molinillos/Molinillo1", pivot = {-14.8, 74.1, 61.0}, axis = {1.0, 0, -0.0}, period = -2.5}, {kind = "spin", path = "Animado/Molinillos/Molinillo2", pivot = {-14.8, 74.1, 79.0}, axis = {1.0, 0, -0.0}, period = 2.5}, {kind = "ring", path = "Animado/CochesRonda/Coche1", lane = 119, dir = 1, s0 = 0.0, speed = 14, start = {119.0, -111.0, 0, 1}}, {kind = "ring", path = "Animado/CochesRonda/Coche2", lane = 119, dir = 1, s0 = 469.1327, speed = 14, start = {-119.0, 111.0, 0, -1}}, {kind = "ring", path = "Animado/CochesRonda/Coche3", lane = 113, dir = -1, s0 = 222.5664, speed = 14, start = {-105.0, -113.0, -1, 0}}, {kind = "ring", path = "Animado/CochesRonda/Coche4", lane = 113, dir = -1, s0 = 667.6991, speed = 14, start = {105.0, 113.0, 1.0, -0.0}}, {kind = "slide", path = "Animado/Tren", dir = {1, 0, 0}, len = 510, speed = 26, s0 = 120}, {kind = "sway", path = "Animado/Grua", pivot = {136, 60.0, 200}, axis = {0, 1, 0}, amp = 55, period = 30, phase = 0}, {kind = "spin", path = "Animado/GloboAerostatico", pivot = {0, 60.0, 0}, axis = {0, 1, 0}, period = 160}, {kind = "spin", path = "Animado/Nubes/Nube1", pivot = {0, 60.0, 0}, axis = {0, 1, 0}, period = 900, phase = 0}, {kind = "spin", path = "Animado/Nubes/Nube2", pivot = {0, 60.0, 0}, axis = {0, 1, 0}, period = -1200, phase = 0}, {kind = "spin", path = "Animado/Nubes/Nube3", pivot = {0, 60.0, 0}, axis = {0, 1, 0}, period = 1500, phase = 0}}

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
	BloomEffect = { Intensity = 0.3, Size = 22, Threshold = 2.1 },
}
local CC_ON = { Saturation = 0.05, Contrast = 0.05, Brightness = 0.02, TintColor = Color3.fromRGB(255, 252, 246) }
local CC_OFF = { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }
local ZONA = "Ciudad"   -- dueña de la luz: al salir solo restaura si nadie más la tomó
local saved, inMap = {}, nil
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
local TAU = 2 * math.pi

local function find(map, path)
	local node = map
	for seg in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(seg)
	end
	return node
end

local function vec(t) return Vector3.new(t[1], t[2], t[3]) end

local function collect(map)
	table.clear(parts); table.clear(owner); table.clear(base); table.clear(groups)
	for gi, a in ANIMS do
		local node = find(map, a.path)
		if node then
			local ref
			if a.kind == "ring" then
				local st = a.start                       -- posición y dirección del coche cuando se generó
				local p = Vector3.new(st[1], 0, st[2]) + OFFSET
				ref = CFrame.lookAt(p, p + Vector3.new(st[3], 0, st[4]))
			elseif a.pivot then
				ref = CFrame.new(vec(a.pivot) + OFFSET)
			else
				ref = CFrame.new()
			end
			groups[gi] = { a = a, ref = ref, axis = a.axis and vec(a.axis).Unit, dir = if a.dir and type(a.dir) == "table" then vec(a.dir) else Vector3.yAxis }
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
	if a.kind == "slide" then                              -- avanza `len` studs en `dir` y vuelve a empezar (tren)
		return g.ref + g.dir * ((a.s0 + a.speed * t) % a.len)
	elseif a.kind == "ring" then
		local P = ringLength(a.lane)
		local s = a.s0 + a.speed * t
		if a.dir < 0 then s = P - (s % P) end
		local x, z, dx, dz = ringPoint(s, a.lane)
		if a.dir < 0 then dx, dz = -dx, -dz end
		local p = Vector3.new(x, 0, z) + OFFSET
		return CFrame.lookAt(p, p + Vector3.new(dx, 0, dz))
	end
	local w = t / a.period * TAU + (a.phase or 0)
	if a.kind == "spin" then
		return g.ref * CFrame.fromAxisAngle(g.axis, w)
	elseif a.kind == "sway" then
		return g.ref * CFrame.fromAxisAngle(g.axis, math.rad(a.amp) * math.sin(w))
	else -- bob: vaivén en `dir` (por defecto, arriba y abajo)
		return g.ref + g.dir * (a.amp * math.sin(w))
	end
end

-- Zona horaria = caja del modelo en sus atributos ZonaMin/ZonaMax (solo la ciudad, no el parque del lobby)
local function inZone(model: Instance?, pos: Vector3, margin: number): boolean
	if not model or not model:IsDescendantOf(workspace) then return false end
	local lo, hi = model:GetAttribute("ZonaMin"), model:GetAttribute("ZonaMax")
	if typeof(lo) ~= "Vector3" or typeof(hi) ~= "Vector3" then
		return math.max(math.abs(pos.X - CENTER.X), math.abs(pos.Z - CENTER.Z)) < 150
	end
	return pos.X >= lo.X - margin and pos.X <= hi.X + margin and pos.Z >= lo.Z - margin and pos.Z <= hi.Z + margin
		and pos.Y < hi.Y + 120
end

local ready, lastScan, map, skip = false, 0, nil, false
local gcf = {}
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local pos = cam.CFrame.Position
	local d = math.max(math.abs(pos.X - CENTER.X), math.abs(pos.Z - CENTER.Z))
	local current = workspace:FindFirstChild("Map4_CiudadPastel")
	local inside = inZone(current, pos, 25)
	setDay(inside)
	if not inside and d > FAR then return end
	local t = os.clock()
	if t - lastScan > 2 then                               -- el mapa entra y sale del Workspace según la votación:
		lastScan = t                                       -- si cambia (o se descargó), volver a localizar las piezas
		if current ~= map or (ready and parts[1] and not parts[1]:IsDescendantOf(workspace)) then
			map, ready = current, false
			if map then collect(map); ready = #parts > 0 end
		end
	end
	if not ready then return end
	if not inside then                                     -- vista desde fuera (lobby): 30 movimientos por segundo bastan
		skip = not skip
		if skip then return end
	end
	for gi, g in groups do gcf[gi] = groupCF(g, t) end
	for i = 1, #parts do cfs[i] = gcf[owner[i]] * base[i] end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
