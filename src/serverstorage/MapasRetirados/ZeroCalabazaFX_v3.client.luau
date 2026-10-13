-- ZeroCalabazaFX (LocalScript en StarterPlayerScripts): ambiente del mapa "Pueblo Calabaza", solo en el cliente.
--  * Atardecer de Halloween (naranja y morado) mientras la cámara está en el mapa; al salir devuelve la luz del juego.
--  * El tiovivo gira y sus jinetes suben y bajan; la bruja vuela en círculo sobre la plaza; los murciélagos
--    rondan; los fantasmas flotan; las burbujas del caldero suben; la calabaza gigante parpadea como una vela.
--  * Las animaciones solo corren con la cámara cerca (un BulkMoveTo por fotograma).
-- Generado por zero-maps/pueblo_calabaza.py a partir de calabaza_fx.luau: editar la plantilla, no esta copia.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
if not game:IsLoaded() then game.Loaded:Wait() end

local CENTER = Vector3.new(0, 60.0, 450)              -- centro del mapa (suelo); mapa girado 180º              -- centro del mapa (suelo)
local TIOVIVO = CENTER + Vector3.new(58, 0, -56)      -- eje del tiovivo
local TORRE = CENTER + Vector3.new(-14.0, 74.0, 208.0)          -- punta de la torre de la mansión (murciélagos)
local NEAR, FAR = 170, 330                       -- FAR alcanza a ver la mansión desde el pueblo

-- ===================== luz =====================
local function own(class, name, props)
	local inst = Lighting:FindFirstChild(name) or Instance.new(class)
	inst.Name = name
	for k, v in props do inst[k] = v end
	inst.Parent = Lighting
	return inst
end
local cc = own("ColorCorrectionEffect", "ZeroCalabazaColor", { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
local rays = own("SunRaysEffect", "ZeroCalabazaRayos", { Intensity = 0, Spread = 0.7 })
local DUSK = {
	[Lighting] = {
		ClockTime = 18.1, Brightness = 2.0, ExposureCompensation = 0,
		Ambient = Color3.fromRGB(104, 86, 126), OutdoorAmbient = Color3.fromRGB(158, 124, 166),
		ColorShift_Top = Color3.fromRGB(255, 160, 90), EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 0.6,
	},
	Atmosphere = { Density = 0.3, Offset = 0.1, Color = Color3.fromRGB(255, 180, 130), Decay = Color3.fromRGB(112, 72, 160), Glare = 0.12, Haze = 1.6 },
	BloomEffect = { Intensity = 0.25, Size = 20, Threshold = 2.2 },                   -- casi sin halo: luz natural
}
local CC_ON = { Saturation = 0.15, Contrast = 0.08, Brightness = 0, TintColor = Color3.fromRGB(255, 236, 224) }
local CC_OFF = { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }
local saved, inMap = {}, nil
local ZONA = "Pueblo"   -- dueña de la luz: al salir solo restaura si nadie más la tomó
local function setDusk(on)
	if on == inMap then return end
	inMap = on
	local owner = Lighting:GetAttribute("ZeroZona")
	if on then Lighting:SetAttribute("ZeroZona", ZONA) elseif owner == ZONA then Lighting:SetAttribute("ZeroZona", nil) end
	local restore = not on and owner == ZONA
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine)
	for key, props in DUSK do
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
	TweenService:Create(rays, info, { Intensity = if on then 0.05 else 0 }):Play()
end

-- ===================== animaciones =====================
local parts, cfs, kind, base, extra = {}, {}, {}, {}, {}
local glow, glowBase
local C_TIO = CFrame.new(TIOVIVO)
local C_PLAZA = CFrame.new(CENTER)
local C_TORRE = CFrame.new(TORRE)

local function add(p, k, ref, ex)
	table.insert(parts, p)
	kind[#parts] = k
	base[#parts] = ref:ToObjectSpace(p.CFrame)
	extra[#parts] = ex
end

local function collect(map)
	table.clear(parts); table.clear(kind); table.clear(base); table.clear(extra)
	local feria = map:FindFirstChild("FeriaFantasma")
	local giro = feria and feria:FindFirstChild("Tiovivo") and feria.Tiovivo:FindFirstChild("Giro")
	if giro then
		for _, p in giro:GetDescendants() do
			if p:IsA("BasePart") then
				local j = p.Parent.Name:match("^Jinete(%d+)$")
				add(p, "tio", C_TIO, j and tonumber(j) or false)
			end
		end
	end
	local anim = map:FindFirstChild("Animado")
	if anim then
		for _, p in (anim:FindFirstChild("Bruja") or Instance.new("Folder")):GetDescendants() do
			if p:IsA("BasePart") then add(p, "bruja", C_PLAZA) end
		end
		for _, p in (anim:FindFirstChild("Murcielagos") or Instance.new("Folder")):GetDescendants() do
			if p:IsA("BasePart") then add(p, "bat", C_PLAZA) end
		end
		for _, p in (anim:FindFirstChild("MurcielagosMansion") or Instance.new("Folder")):GetDescendants() do
			if p:IsA("BasePart") then add(p, "batm", C_TORRE) end
		end
		for _, g in (anim:FindFirstChild("Fantasmas") or Instance.new("Folder")):GetChildren() do
			local n = tonumber(g.Name:match("(%d+)$")) or 1
			for _, p in g:GetDescendants() do
				if p:IsA("BasePart") then add(p, "ghost", CFrame.new(), n) end
			end
		end
	end
	local burb = map:FindFirstChild("MercadoDulces") and map.MercadoDulces:FindFirstChild("Burbujas")
	if burb then
		for i, p in burb:GetChildren() do
			if p:IsA("BasePart") then add(p, "bubble", CFrame.new(), i * 0.37) end
		end
	end
	local plaza = map:FindFirstChild("PlazaCalabaza")
	local b = plaza and plaza:FindFirstChild("Brillo")
	glow = b and b:FindFirstChildOfClass("PointLight")
	glowBase = glow and glow.Brightness
	table.clear(cfs)
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

local map
local ready, lastScan = false, 0
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local pos = cam.CFrame.Position
	local d = math.max(math.abs(pos.X - CENTER.X), math.abs(pos.Z - CENTER.Z))
	local inside = inZone(workspace:FindFirstChild("Map5_PuebloCalabaza"), pos, 25)
	setDusk(inside)
	if not inside and d > FAR then return end
	local t = os.clock()
	if t - lastScan > 2 then                               -- el mapa entra y sale del Workspace según la votación:
		lastScan = t                                       -- si cambia (o se descargó), volver a localizar las piezas
		local current = workspace:FindFirstChild("Map5_PuebloCalabaza")
		if current ~= map or (ready and parts[1] and not parts[1]:IsDescendantOf(workspace)) then
			map, ready = current, false
			if map then collect(map); ready = #parts > 0 end
		end
	end
	if not ready then return end
	local spinTio = C_TIO * CFrame.Angles(0, t / 14 * 2 * math.pi, 0)
	local spinBruja = C_PLAZA * CFrame.Angles(0, -t / 26 * 2 * math.pi, 0) + Vector3.new(0, math.sin(t * 1.3) * 1.2, 0)
	local spinBats = C_PLAZA * CFrame.Angles(0, -t / 40 * 2 * math.pi, 0)
	local spinTorre = C_TORRE * CFrame.Angles(0, t / 12 * 2 * math.pi, 0)
	for i = 1, #parts do
		local k = kind[i]
		if k == "tio" then
			local cf = spinTio * base[i]
			if extra[i] then cf += Vector3.new(0, math.sin(t * 2.2 + extra[i] * 0.8) * 0.8, 0) end
			cfs[i] = cf
		elseif k == "bruja" then
			cfs[i] = spinBruja * base[i]
		elseif k == "bat" then
			cfs[i] = spinBats * base[i] + Vector3.new(0, math.sin(t * 3 + i) * 0.6, 0)
		elseif k == "batm" then
			cfs[i] = spinTorre * base[i] + Vector3.new(0, math.sin(t * 2.4 + i) * 1.2, 0)
		elseif k == "ghost" then
			cfs[i] = base[i] + Vector3.new(math.sin(t * 0.7 + extra[i]) * 0.8, math.sin(t * 1.4 + extra[i] * 2) * 1.2, 0)
		else -- bubble: sube 4 studs y vuelve a empezar
			local h = (t * 1.1 + extra[i] * 3) % 4
			cfs[i] = base[i] + Vector3.new(0, h - 1.5, 0)
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if glow then glow.Brightness = glowBase * (0.85 + 0.15 * math.noise(t * 2.5, 0.3)) + 0.2 * math.sin(t * 9) end
end)
