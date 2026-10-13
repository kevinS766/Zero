-- ZeroCalabazaFX (LocalScript en StarterPlayerScripts): ambiente del mapa "Pueblo Calabaza", solo en el cliente.
--  * Atardecer de Halloween (naranja y morado) mientras la cámara está en el pueblo (caja ZonaMin/ZonaMax del modelo); al salir
--    vuelve la luz base (atributos Base_* de Lighting) si nadie más tomó la luz (Lighting.ZeroZona).
--  * Animaciones definidas en pueblo_calabaza.py (lista ANIMS): coches por el anillo, tren entre túneles, agujas del
--    reloj, chorros de la fuente, palomas, globos, columpios, tiovivo, patos, cometa, helado gigante, molinillos,
--    estrella del arcade, pizza, banderas, grúa, globo aerostático y nubes. Un BulkMoveTo por fotograma y solo con
--    la cámara cerca (también desde el lobby). Las piezas animadas no colisionan: solo existen así en el cliente.
-- Generado por zero-maps/pueblo_calabaza.py a partir de calabaza_fx.luau: editar la plantilla, no esta copia.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
if not game:IsLoaded() then game.Loaded:Wait() end

local CENTER = Vector3.new(0, 60.0, 250)              -- origen del generador (suelo) en el mundo
local OFFSET = CENTER - Vector3.new(0, 60.0, 0)    -- coordenadas del generador -> mundo (el mapa no va girado)
local FAR = 360                                   -- el lobby (a ~240 del centro) también ve las animaciones
local RING_R = 8.0
local ANIMS = {{kind = "sway", path = "Animado/Faroles/Farol1", pivot = {16.1124, 101.791, 2.4584}, axis = {-0.1508, 0, 0.9886}, amp = 6, period = 3.2, phase = 0.0}, {kind = "sway", path = "Animado/Faroles/Farol2", pivot = {5.4084, 105.309, 13.7295}, axis = {-0.9304, 0, 0.3665}, amp = 6, period = 3.55, phase = 1.1}, {kind = "sway", path = "Animado/Faroles/Farol4", pivot = {-14.6879, 103.6851, 4.7925}, axis = {-0.3102, 0, -0.9507}, amp = 6, period = 4.25, phase = 3.3}, {kind = "sway", path = "Animado/Faroles/Farol5", pivot = {-12.3079, 106.3445, -10.8986}, axis = {0.6629, 0, -0.7487}, amp = 6, period = 4.6, phase = 4.4}, {kind = "sway", path = "Animado/Faroles/Farol6", pivot = {-0.7291, 109.1251, -15.5431}, axis = {0.9989, 0, -0.0469}, amp = 6, period = 4.95, phase = 5.5}, {kind = "sway", path = "Animado/Faroles/Farol7", pivot = {11.813, 101.0461, -8.8449}, axis = {0.5994, 0, 0.8005}, amp = 6, period = 5.3, phase = 6.6}, {kind = "sway", path = "Animado/Columpio", pivot = {-6.4694, 109.3775, 12.623}, axis = {-0.8899, 0, -0.4561}, amp = 9, period = 4.2, phase = 0}, {kind = "bob", path = "Animado/Luciernagas/Arbol1", amp = 1.4, period = 2.2, phase = 0}, {kind = "bob", path = "Animado/Luciernagas/Arbol2", amp = 1.4, period = 2.7, phase = 1}, {kind = "bob", path = "Animado/Luciernagas/Arbol3", amp = 1.4, period = 3.2, phase = 2}, {kind = "bob", path = "Animado/Luciernagas/Arbol4", amp = 1.4, period = 3.7, phase = 3}, {kind = "bob", path = "Animado/BurbujasFoso/B1", amp = 0.35, period = 1.1, phase = 0}, {kind = "bob", path = "Animado/BurbujasFoso/B2", amp = 0.35, period = 1.4, phase = 2}, {kind = "bob", path = "Animado/BurbujasFoso/B3", amp = 0.35, period = 1.7, phase = 4}, {kind = "spin", path = "Animado/MurcielagosArbol", pivot = {0, 110.0, 0}, axis = {0, 1, 0}, period = 18}, {kind = "bob", path = "Animado/TorreAsientos", amp = 12, period = 7, phase = 0}, {kind = "spin", path = "Animado/Calderos", pivot = {-106, 60.0, -50}, axis = {0, 1, 0}, period = 11}, {kind = "bob", path = "Animado/Globos", amp = 0.6, period = 2.6, phase = 0}, {kind = "sway", path = "Animado/Espantapajaros/Brazos1", pivot = {46.0, 66.2, -140.0}, axis = {0.0, 0, 1.0}, amp = 12, period = 2.8, phase = 0}, {kind = "sway", path = "Animado/Espantapajaros/Brazos2", pivot = {116.0, 66.2, -56.0}, axis = {0.9006, 0, -0.4347}, amp = 12, period = 3.8, phase = 1}, {kind = "spin", path = "Animado/Cuervos", pivot = {88, 78.0, -100}, axis = {0, 1, 0}, period = 13}, {kind = "bob", path = "Animado/Luciernagas/Huerto1", amp = 1.0, period = 2.0, phase = 0}, {kind = "bob", path = "Animado/Luciernagas/Huerto2", amp = 1.0, period = 2.6, phase = 1}, {kind = "bob", path = "Animado/Luciernagas/Huerto3", amp = 1.0, period = 3.2, phase = 2}, {kind = "bob", path = "Animado/Humo/Casa1", amp = 0.8, period = 2.6, phase = 0}, {kind = "bob", path = "Animado/FantasmaVentana", amp = 0.9, period = 3.0, phase = 0.5}, {kind = "bob", path = "Animado/Destellos", amp = 1.2, period = 1.8, phase = 0}, {kind = "bob", path = "Animado/FantasmasCementerio/F1", amp = 1.8, period = 2.6, phase = 0.0}, {kind = "bob", path = "Animado/FantasmasCementerio/F2", amp = 1.8, period = 3.1, phase = 1.4}, {kind = "bob", path = "Animado/FantasmasCementerio/F3", amp = 1.8, period = 3.6, phase = 2.8}, {kind = "bob", path = "Animado/FantasmasCementerio/F4", amp = 1.8, period = 4.1, phase = 4.2}, {kind = "bob", path = "Animado/NieblaCementerio", amp = 0.6, dir = {1, 0, 0.4}, period = 7, phase = 0}, {kind = "bob", path = "Animado/BurbujasPantano/B1", amp = 0.4, period = 1.2, phase = 0}, {kind = "bob", path = "Animado/BurbujasPantano/B2", amp = 0.4, period = 1.6, phase = 2}, {kind = "bob", path = "Animado/BurbujasPantano/B3", amp = 0.4, period = 2.0, phase = 4}, {kind = "bob", path = "Animado/Ranas/Rana1", amp = 0.25, period = 1.6, phase = 0}, {kind = "bob", path = "Animado/Ranas/Rana2", amp = 0.25, period = 2.1, phase = 1}, {kind = "bob", path = "Animado/HumoBruja", amp = 0.7, period = 2.2, phase = 0.7}, {kind = "sway", path = "Animado/FarolesArco/F1", pivot = {12.2873, 78.6131, -152.5}, axis = {1, 0, 0}, amp = 8, period = 2.6, phase = 0}, {kind = "sway", path = "Animado/FarolesArco/F2", pivot = {7.5, 82.3418, -152.5}, axis = {1, 0, 0}, amp = 8, period = 2.9, phase = 1}, {kind = "sway", path = "Animado/FarolesArco/F3", pivot = {-7.5, 82.3418, -152.5}, axis = {1, 0, 0}, amp = 8, period = 3.2, phase = 2}, {kind = "sway", path = "Animado/FarolesArco/F4", pivot = {-12.2873, 78.6131, -152.5}, axis = {1, 0, 0}, amp = 8, period = 3.5, phase = 3}, {kind = "bob", path = "Animado/FuegosFatuos/F1", amp = 2.9036, dir = {0.2304, 0.6, -0.0918}, period = 5.7034, phase = 0}, {kind = "bob", path = "Animado/FuegosFatuos/F2", amp = 2.1015, dir = {-0.9781, 0.6, -0.1585}, period = 5.0413, phase = 1}, {kind = "bob", path = "Animado/FuegosFatuos/F3", amp = 2.8298, dir = {0.9325, 0.6, -0.4277}, period = 5.4251, phase = 2}, {kind = "bob", path = "Animado/FuegosFatuos/F4", amp = 2.9616, dir = {-0.6549, 0.6, 0.3967}, period = 6.0002, phase = 3}, {kind = "bob", path = "Animado/FuegosFatuos/F5", amp = 2.9648, dir = {-0.7354, 0.6, -0.0336}, period = 4.355, phase = 4}, {kind = "bob", path = "Animado/FuegosFatuos/F6", amp = 2.5389, dir = {0.7273, 0.6, 0.427}, period = 5.2514, phase = 5}, {kind = "bob", path = "Animado/FuegosFatuos/F7", amp = 2.2729, dir = {0.1966, 0.6, -0.2413}, period = 6.881, phase = 6}, {kind = "bob", path = "Animado/FuegosFatuos/F8", amp = 1.9861, dir = {-0.3333, 0.6, -0.432}, period = 4.4923, phase = 7}, {kind = "slide", path = "Animado/Linternas/L1", dir = {0, 1, 0}, len = 110, speed = 2.3043, s0 = 85.7756}, {kind = "slide", path = "Animado/Linternas/L2", dir = {0, 1, 0}, len = 110, speed = 2.3017, s0 = 5.1168}, {kind = "slide", path = "Animado/Linternas/L3", dir = {0, 1, 0}, len = 110, speed = 3.0506, s0 = 76.6729}, {kind = "slide", path = "Animado/Linternas/L4", dir = {0, 1, 0}, len = 110, speed = 2.4711, s0 = 102.4178}, {kind = "slide", path = "Animado/Linternas/L5", dir = {0, 1, 0}, len = 110, speed = 2.317, s0 = 82.3684}, {kind = "slide", path = "Animado/Linternas/L6", dir = {0, 1, 0}, len = 110, speed = 2.4179, s0 = 2.709}, {kind = "slide", path = "Animado/Linternas/L7", dir = {0, 1, 0}, len = 110, speed = 3.018, s0 = 72.7906}, {kind = "slide", path = "Animado/Linternas/L8", dir = {0, 1, 0}, len = 110, speed = 3.3801, s0 = 86.4827}, {kind = "slide", path = "Animado/Linternas/L9", dir = {0, 1, 0}, len = 110, speed = 3.368, s0 = 17.0655}, {kind = "slide", path = "Animado/Linternas/L10", dir = {0, 1, 0}, len = 110, speed = 3.3539, s0 = 63.4889}, {kind = "slide", path = "Animado/Linternas/L11", dir = {0, 1, 0}, len = 110, speed = 2.4314, s0 = 90.5414}, {kind = "slide", path = "Animado/Linternas/L12", dir = {0, 1, 0}, len = 110, speed = 2.2347, s0 = 107.4752}, {kind = "slide", path = "Animado/Linternas/L13", dir = {0, 1, 0}, len = 110, speed = 2.3167, s0 = 61.5467}, {kind = "slide", path = "Animado/Linternas/L14", dir = {0, 1, 0}, len = 110, speed = 2.7745, s0 = 60.9242}, {kind = "slide", path = "Animado/Linternas/L15", dir = {0, 1, 0}, len = 110, speed = 2.4409, s0 = 53.1495}, {kind = "slide", path = "Animado/Linternas/L16", dir = {0, 1, 0}, len = 110, speed = 2.9026, s0 = 73.6502}, {kind = "slide", path = "Animado/Linternas/L17", dir = {0, 1, 0}, len = 110, speed = 2.8446, s0 = 47.9817}, {kind = "slide", path = "Animado/Linternas/L18", dir = {0, 1, 0}, len = 110, speed = 3.0699, s0 = 5.2884}, {kind = "slide", path = "Animado/Linternas/L19", dir = {0, 1, 0}, len = 110, speed = 2.3822, s0 = 34.098}, {kind = "slide", path = "Animado/Linternas/L20", dir = {0, 1, 0}, len = 110, speed = 2.5135, s0 = 21.1648}, {kind = "slide", path = "Animado/Linternas/L21", dir = {0, 1, 0}, len = 110, speed = 3.1787, s0 = 40.821}, {kind = "slide", path = "Animado/Linternas/L22", dir = {0, 1, 0}, len = 110, speed = 3.0667, s0 = 6.13}, {kind = "slide", path = "Animado/Linternas/L23", dir = {0, 1, 0}, len = 110, speed = 2.9617, s0 = 63.6672}, {kind = "slide", path = "Animado/Linternas/L24", dir = {0, 1, 0}, len = 110, speed = 3.0669, s0 = 80.955}, {kind = "slide", path = "Animado/Linternas/L25", dir = {0, 1, 0}, len = 110, speed = 2.6305, s0 = 52.9947}, {kind = "slide", path = "Animado/Linternas/L26", dir = {0, 1, 0}, len = 110, speed = 2.9289, s0 = 41.3981}, {kind = "slide", path = "Animado/Linternas/L27", dir = {0, 1, 0}, len = 110, speed = 2.6885, s0 = 73.1649}, {kind = "slide", path = "Animado/Linternas/L28", dir = {0, 1, 0}, len = 110, speed = 2.6356, s0 = 83.2606}, {kind = "spin", path = "Animado/Nubes/Nube1", pivot = {0, 60.0, 0}, axis = {0, 1, 0}, period = 1100, phase = 0}, {kind = "spin", path = "Animado/Nubes/Nube2", pivot = {0, 60.0, 0}, axis = {0, 1, 0}, period = -1500, phase = 0}, {kind = "spin", path = "Animado/Noria/Rueda", pivot = {-186.0, 98.0, -112.0}, axis = {-0.7071, 0, 0.7071}, period = 48}, {kind = "orbit", path = "Animado/Noria/Cabina1", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 0.0}, {kind = "orbit", path = "Animado/Noria/Cabina2", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 0.5236}, {kind = "orbit", path = "Animado/Noria/Cabina3", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 1.0472}, {kind = "orbit", path = "Animado/Noria/Cabina4", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 1.5708}, {kind = "orbit", path = "Animado/Noria/Cabina5", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 2.0944}, {kind = "orbit", path = "Animado/Noria/Cabina6", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 2.618}, {kind = "orbit", path = "Animado/Noria/Cabina7", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 3.1416}, {kind = "orbit", path = "Animado/Noria/Cabina8", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 3.6652}, {kind = "orbit", path = "Animado/Noria/Cabina9", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 4.1888}, {kind = "orbit", path = "Animado/Noria/Cabina10", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 4.7124}, {kind = "orbit", path = "Animado/Noria/Cabina11", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 5.236}, {kind = "orbit", path = "Animado/Noria/Cabina12", u = {0.7071, 0, 0.7071}, v = {0, 1, 0}, r = 30, period = 48, phase = 5.7596}, {kind = "sway", path = "Animado/Rey/BrazoIzq", pivot = {114.3604, 135.0, 242.2419}, axis = {0.4161, 0, 0.9093}, amp = 10, period = 6.5, phase = 0}, {kind = "sway", path = "Animado/Rey/BrazoDer", pivot = {141.6396, 135.0, 229.7581}, axis = {0.4161, 0, 0.9093}, amp = 10, period = 6.5, phase = 3.1416}, {kind = "sway", path = "Animado/Rey/Cabeza", pivot = {128.0, 140.0, 236.0}, axis = {0.9093, 0, -0.4161}, amp = 4, period = 9, phase = 0}, {kind = "spin", path = "Animado/Rey/Cuervos", pivot = {128, 164.0, 236}, axis = {0, 1, 0}, period = 12}, {kind = "spin", path = "Animado/MurcielagosCastillo", pivot = {-330, 156.0, 380}, axis = {0, 1, 0}, period = 16}, {kind = "bob", path = "Animado/Globos/Calabaza", amp = 3.5, period = 10, phase = 0}, {kind = "bob", path = "Animado/Globos/Morado", amp = 3, period = 12, phase = 2}, {kind = "spin", path = "Animado/Molino/Aspas", pivot = {233.4026, 107.857, 7.8455}, axis = {-0.9994, 0, -0.0336}, period = 12}, {kind = "bob", path = "Animado/Islas/Isla1", amp = 3, period = 11, phase = 0}, {kind = "bob", path = "Animado/Islas/Isla2", amp = 3, period = 13, phase = 1}, {kind = "bob", path = "Animado/Islas/Isla3", amp = 3, period = 15, phase = 2}, {kind = "spin", path = "Animado/Bruja", pivot = {0, 160.0, 150}, axis = {0, 1, 0}, period = -46}}

-- ===================== atardecer de Halloween =====================
local function own(class, name, props)
	local inst = Lighting:FindFirstChild(name) or Instance.new(class)
	inst.Name = name
	for k, v in props do inst[k] = v end
	inst.Parent = Lighting
	return inst
end
local cc = own("ColorCorrectionEffect", "ZeroCalabazaColor", { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
local rays = own("SunRaysEffect", "ZeroCalabazaRayos", { Intensity = 0, Spread = 0.7 })
local DAY = {
	[Lighting] = {
		ClockTime = 17.5, Brightness = 2.0, ExposureCompensation = 0,
		Ambient = Color3.fromRGB(104, 86, 126), OutdoorAmbient = Color3.fromRGB(158, 124, 166),
		ColorShift_Top = Color3.fromRGB(255, 205, 170), EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 0.6,
	},
	Atmosphere = { Density = 0.26, Offset = 0.1, Color = Color3.fromRGB(232, 200, 190), Decay = Color3.fromRGB(112, 90, 150), Glare = 0.1, Haze = 1.0 },
	BloomEffect = { Intensity = 0.25, Size = 20, Threshold = 2.2 },
}
local CC_ON = { Saturation = -0.05, Contrast = 0.05, Brightness = 0.01, TintColor = Color3.fromRGB(255, 248, 244) }   -- el mapa ya es naranja: no empujarlo más
local CC_OFF = { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }
local ZONA = "Calabaza"   -- dueña de la luz: al salir solo restaura si nadie más la tomó
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
	elseif a.kind == "orbit" then                         -- vueltas en un círculo SIN girar (cabinas de la noria)
		local a0 = a.phase or 0
		local w = t / a.period * TAU + a0
		return g.ref + (vec(a.u) * (math.cos(w) - math.cos(a0)) + vec(a.v) * (math.sin(w) - math.sin(a0))) * a.r
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
	local current = workspace:FindFirstChild("Map5_PuebloCalabaza")
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
