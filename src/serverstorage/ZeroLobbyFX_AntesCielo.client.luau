-- ZeroLobbyFX (LocalScript en StarterPlayerScripts): efectos del lobby "Feria" en cada cliente, sin red.
--  * Atardecer solo en el lobby: al acercarse la cámara guarda la iluminación del juego y la pasa a tarde dorada;
--    al irse a un mapa la devuelve tal cual estaba.
--  * La noria gira (una vuelta cada 40 s) con las góndolas siempre derechas.
--  * Los banderines ondean como una ola sobre su cuerda.
-- Las animaciones se paran con la cámara lejos del lobby (jugando en un mapa).
-- Generado por zero-maps/lobby_feria.py a partir de lobby_fx.luau: editar la plantilla, no esta copia.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
if not game:IsLoaded() then game.Loaded:Wait() end

local lobby = workspace:WaitForChild("ZeroLobby")
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

local LOBBY = Vector3.new(0, 60.0, 0)
local NEAR, FAR = 110, 180                       -- atardecer dentro de NEAR studs; animaciones dentro de FAR

-- ===== atardecer =====
local SUNSET = {
	[Lighting] = { ClockTime = 17.6, Brightness = 2.0, OutdoorAmbient = Color3.fromRGB(150, 120, 140), ExposureCompensation = 0 },
	Atmosphere = { Density = 0.3, Color = Color3.fromRGB(255, 205, 170), Decay = Color3.fromRGB(150, 110, 180), Glare = 0.2, Haze = 1.4 },
	BloomEffect = { Intensity = 0.4, Size = 24, Threshold = 2.1 },          -- antes 0.7 / 1.5: casi todo el neón hacía halo
}
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "ZeroLobbyAtardecer"
cc.Parent = Lighting
local CC_ON = { Saturation = 0.04, Contrast = 0.05, TintColor = Color3.fromRGB(255, 244, 234) }
local CC_OFF = { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }

local saved = {}                                       -- [instancia] = valores originales del juego
local inLobby
local ZONA = "Lobby"   -- dueña de la luz: al salir solo restaura si nadie más la tomó
local function setSunset(on)
	if on == inLobby then return end
	inLobby = on
	local owner = Lighting:GetAttribute("ZeroZona")
	if on then Lighting:SetAttribute("ZeroZona", ZONA) elseif owner == ZONA then Lighting:SetAttribute("ZeroZona", nil) end
	local restore = not on and owner == ZONA
	local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
	for key, props in SUNSET do
		local inst = if typeof(key) == "Instance" then key else Lighting:FindFirstChildOfClass(key)
		if inst then
			if on then
				if not saved[inst] then                -- se guarda una vez: lo que el juego tenía antes del lobby
					saved[inst] = {}
					for k in props do saved[inst][k] = inst[k] end
				end
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
end

-- ===== piezas animadas (un solo BulkMoveTo por fotograma) =====
local parts, base, hang, hinge, phase = {}, {}, {}, {}, {}
local NORIA = CFrame.new(-38, 94.0, -100)
local PERIOD, AMP, SPEED = 40, math.rad(18), 2.2

local noria = lobby:WaitForChild("Fondo"):WaitForChild("Noria")
for _, p in noria:WaitForChild("Rueda"):GetDescendants() do
	if p:IsA("BasePart") then
		table.insert(parts, p)
		base[#parts] = NORIA:ToObjectSpace(p.CFrame)
	end
end
for _, g in noria:WaitForChild("Gondolas"):GetChildren() do
	local hook = g:FindFirstChild("Enganche")
	if hook then
		local rel = NORIA:PointToObjectSpace(hook.Position)
		for _, p in g:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(parts, p)
				base[#parts] = p.CFrame - hook.Position        -- la góndola solo se traslada: cuelga derecha
				hang[#parts] = rel
			end
		end
	end
end
for _, p in lobby:WaitForChild("Decor"):WaitForChild("Banderines"):GetDescendants() do
	if p:IsA("BasePart") and p.Name == "Banderin" then
		local h = p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)   -- bisagra en el borde de arriba (la cuerda)
		table.insert(parts, p)
		hinge[#parts] = h
		base[#parts] = h:ToObjectSpace(p.CFrame)
		phase[#parts] = (p.Position.X + p.Position.Z) * 0.15 + math.random() * 0.6
	end
end

local cfs = table.create(#parts)
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local d = (cam.CFrame.Position - LOBBY).Magnitude
	local inside = inZone(lobby, cam.CFrame.Position, 25)
	setSunset(inside)
	if not inside and d > FAR then return end
	local t = os.clock()
	local spin = NORIA * CFrame.Angles(0, 0, -t / PERIOD * 2 * math.pi)
	for i = 1, #parts do
		if hinge[i] then
			cfs[i] = hinge[i] * CFrame.Angles(AMP * math.sin(t * SPEED + phase[i]), 0, 0) * base[i]
		elseif hang[i] then
			cfs[i] = base[i] + spin:PointToWorldSpace(hang[i])
		else
			cfs[i] = spin * base[i]
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
