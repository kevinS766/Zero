-- Rafaga (ModuleScript, ReplicatedStorage.VFX): habilidad de rareza RARO de ZERO (tecla E, cazador). Misma secuencia para
-- las tres varitas raras, cada una con su skin (referencia: "mirror shard barrage"):
--   el cazador alza el brazo; detrás de él se abre un círculo mágico y aparecen 6 proyectiles en abanico con un destello;
--   flotan, se giran hacia el objetivo, salen uno tras otro con estela, se clavan alrededor del punto y, cuando cae el
--   sexto, estalla todo: destello, onda en el suelo, cúpula y el remate de cada skin. Los corredores del radio quedan
--   aturdidos (lo decide el servidor) y llevan encima un efecto de mareo de la skin.
--   Tormenta (Batuta de Tormenta)  rayos azul eléctrico, arcos entre ellos, quemaduras y un rayo del cielo al final
--   Estelar  (Varita Estelar)      estrellas doradas que giran, purpurina, huellas de estrella y lluvia de estrellas
--   Te       (Varita de Té)        tazas de porcelana con té mágico, salpicaduras, vapor y remolino de té
-- Modelos: ReplicatedStorage.ZeroHabilidades.Proyectiles.<Rayo|Estrella|Taza> (zero-habilidades/scripts/proyectiles.py;
-- pivote: LookVector = punta, UpVector = cara). Si falta el modelo sale una esfera de neón.
-- Texturas: zero-habilidades/blender/texturas.py (+ destello y anillo de zero-hielo).
--
--   Rafaga.Play(personaje, objetivo, inicio?, origen?, skin?)   cliente; inicio = workspace:GetServerTimeNow() del servidor
--   Rafaga.estallido(origen, objetivo)                          segundos hasta el estallido (el servidor aturde entonces)
--   Rafaga.aturdido(personaje, skin, duracion)                   mareo sobre la cabeza
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rafaga = {}

local TEX = {
	destello = "rbxassetid://90451150464733", anillo = "rbxassetid://86746617876623",
	estela = "rbxassetid://72562914511283", rayo = "rbxassetid://132551873884005", rayoBeam = "rbxassetid://76401236415244",
	quemadura = "rbxassetid://73392397317182", estrella = "rbxassetid://138457464720704", purpurina = "rbxassetid://99088718736800",
	huella = "rbxassetid://118216510034314", porcelana = "rbxassetid://84941526390495", gota = "rbxassetid://110421037903366",
	vapor = "rbxassetid://94254886771653", salpicadura = "rbxassetid://72224902881481", remolino = "rbxassetid://107279489304762",
}
local SFX = {
	aparece = "rbxassetid://9116394545", disparo = "rbxassetid://9125648149",
	zap = "rbxassetid://9114277757", zapFuerte = "rbxassetid://9114277402",
	campana = "rbxassetid://9116394876", campanaFin = "rbxassetid://9116395179",
	chof = "rbxassetid://9114190682", chofFin = "rbxassetid://9119478389", cristal = "rbxassetid://9114591515",
}
Rafaga.TEX, Rafaga.SFX = TEX, SFX

-- ------------------------------------------------------------------ ajustes
local N = 6
local APARECE, ESCALON = 0.10, 0.07
local APUNTA0, APUNTA1 = 0.80, 1.10
local DISPARO, CADENCIA = 1.18, 0.08
local VEL = 165
local RADIO_FAN, ALTO_FAN, ATRAS_FAN = 2.3, 1.8, 1.4
local RADIO_IMPACTO = 2.4
Rafaga.RADIO = 8
Rafaga.ESCALA = 1                  -- velocidad del tiempo (pruebas a cámara lenta)

local BLANCO = Color3.new(1, 1, 1)
local SKINS = {
	Tormenta = { modelo = "Rayo", escala = 0.65, largo = 1.6, c1 = Color3.fromHex("#FFF8D6"), c2 = Color3.fromHex("#FFD84A"), c3 = Color3.fromHex("#FF9A1F") },
	Estelar = { modelo = "Estrella", escala = 0.85, largo = 1.0, gira = 9, frente = true, c1 = Color3.fromHex("#FFF6D6"), c2 = Color3.fromHex("#FFC845"), c3 = Color3.fromHex("#FF5FB8") },
	Te = { modelo = "Taza", escala = 1.05, largo = 0.6, erguido = true, c1 = Color3.fromHex("#F3F6FF"), c2 = Color3.fromHex("#6FD3FF"), c3 = Color3.fromHex("#E2B25E") },
}
Rafaga.SKINS = SKINS

local function vuelo(origen: Vector3, objetivo: Vector3): number
	return math.clamp((objetivo - origen).Magnitude / VEL, 0.12, 0.38)
end
function Rafaga.estallido(origen: Vector3, objetivo: Vector3): number
	return DISPARO + (N - 1) * CADENCIA + vuelo(origen, objetivo) + 0.08
end

local function suave(x: number): number x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function rebote(x: number): number          -- sale pasándose un poco (Back out)
	x = math.clamp(x, 0, 1); local s = 1.9
	return 1 + (s + 1) * (x - 1) ^ 3 + s * (x - 1) ^ 2
end

-- ------------------------------------------------------------------ piezas y efectos sueltos
local function parte(clase: string, props): BasePart
	local p = Instance.new(clase) :: BasePart
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	for k, v in props do (p :: any)[k] = v end
	return p
end
local function seq(a: number, b: number) return NumberSequence.new(a, b) end
local function emisor(padre: Instance, tex: string, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex; e.Rate = 0; e.LightEmission = 1; e.LightInfluence = 0
	e.Speed = NumberRange.new(0); e.Lifetime = NumberRange.new(0.2)
	for k, v in props do (e :: any)[k] = v end
	e.TimeScale = math.min(Rafaga.ESCALA, 1)                             -- cámara lenta de pruebas
	e.Parent = padre
	return e
end
local function soltar(padre: Instance, n: number, tex: string, props)
	local e = emisor(padre, tex, props)
	e:Emit(n)
	Debris:AddItem(e, (e.Lifetime.Max + 0.1) / e.TimeScale)
	return e
end
local function destello(padre: Instance, tam: number, color: Color3?, vida: number?)
	soltar(padre, 1, TEX.destello, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, tam * 0.3), NumberSequenceKeypoint.new(0.25, tam),
		NumberSequenceKeypoint.new(1, tam * 0.2) }), Transparency = seq(0, 1), Lifetime = NumberRange.new(vida or 0.22),
		Color = ColorSequence.new(color or BLANCO), ZOffset = 2 })
end
local function anilloLuz(padre: Instance, de: number, a: number, vida: number, color: Color3)
	soltar(padre, 1, TEX.anillo, { Size = seq(de, a), Transparency = seq(0.05, 1), Lifetime = NumberRange.new(vida),
		Color = ColorSequence.new(color), ZOffset = 1 })
end
local function luz(padre: Instance, color: Color3, brillo: number, rango: number, vida: number)
	local l = Instance.new("PointLight"); l.Color = color; l.Brightness = brillo; l.Range = rango; l.Shadows = false; l.Parent = padre
	TweenService:Create(l, TweenInfo.new(vida, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(l, vida + 0.1)
end
local function sonido(padre: Instance, id: string, vol: number, tono: number?)
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = vol; s.PlaybackSpeed = (tono or 1) * (0.94 + math.random() * 0.12)
	s.RollOffMaxDistance = 140; s.RollOffMinDistance = 12; s.Parent = padre
	s:Play(); Debris:AddItem(s, 5)
end
local function suelo(pos: Vector3, ignorar: { Instance }): (Vector3, Vector3)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = ignorar
	local hit = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rp)
	if hit then return hit.Position, hit.Normal end
	return pos, Vector3.yAxis
end
-- marca en el suelo (pieza invisible con Decal arriba); crece desde 0,4 del tamaño y se borra con retraso
local function marca(carpeta: Instance, pos: Vector3, normal: Vector3, tex: string, color: Color3, tam: number, dura: number)
	local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(-math.pi / 2, 0, math.random() * math.pi * 2)
	local p = parte("Part", { Size = Vector3.new(tam * 0.4, 0.05, tam * 0.4), CFrame = cf + normal * 0.04, Transparency = 1 })
	local d = Instance.new("Decal"); d.Face = Enum.NormalId.Top; d.Texture = tex; d.Color3 = color; d.Transparency = 0.05; d.Parent = p
	p.Parent = carpeta
	TweenService:Create(p, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(tam, 0.05, tam) }):Play()
	TweenService:Create(d, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, dura), { Transparency = 1 }):Play()
	return p
end
local function ancla(carpeta: Instance, pos: Vector3): (BasePart, Attachment)
	local p = parte("Part", { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos) })
	p.Parent = carpeta
	local a = Instance.new("Attachment"); a.Parent = p
	return p, a
end
local function beam(padre: Instance, a0: Attachment, a1: Attachment, tex: string, ancho: number, color: Color3): Beam
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1; b.Texture = tex; b.TextureMode = Enum.TextureMode.Stretch
	b.Width0, b.Width1 = ancho, ancho; b.FaceCamera = true; b.LightEmission = 1; b.LightInfluence = 0; b.Segments = 1
	b.Color = ColorSequence.new(color); b.Transparency = NumberSequence.new(0); b.Parent = padre
	return b
end

-- ------------------------------------------------------------------ proyectil
local function proyectil(skin, carpeta: Instance)
	local raiz = ReplicatedStorage:FindFirstChild("ZeroHabilidades")
	local plantilla = raiz and raiz:FindFirstChild("Proyectiles") and raiz.Proyectiles:FindFirstChild(skin.modelo)
	local m: Model
	if plantilla then
		m = plantilla:Clone()
	else                                                                   -- sin modelo importado: esfera de neón
		m = Instance.new("Model")
		local p = parte("Part", { Name = "Cuerpo", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, Material = Enum.Material.Neon, Color = skin.c2 })
		p.Parent = m; m.PrimaryPart = p
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false end
	end
	m.Parent = carpeta
	-- núcleo aparte (no escala con el modelo): estela, chispas del vuelo y destellos
	local nucleo = parte("Part", { Size = Vector3.one * 0.2, Transparency = 1 })
	local punta = Instance.new("Attachment"); punta.Name = "Punta"; punta.Position = Vector3.new(0, 0, -skin.largo); punta.Parent = nucleo
	local centro = Instance.new("Attachment"); centro.Name = "Centro"; centro.Parent = nucleo
	local e0 = Instance.new("Attachment"); e0.Position = Vector3.new(-0.35, 0, 0); e0.Parent = nucleo
	local e1 = Instance.new("Attachment"); e1.Position = Vector3.new(0.35, 0, 0); e1.Parent = nucleo
	local function estela(ancho: number, vida: number, color: ColorSequence, transp: number)
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = e0, e1; tr.Texture = TEX.estela; tr.TextureMode = Enum.TextureMode.Stretch
		tr.Lifetime = vida; tr.MinLength = 0.05; tr.FaceCamera = true; tr.LightEmission = 1; tr.LightInfluence = 0
		tr.Color = color; tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transp), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, ancho), NumberSequenceKeypoint.new(1, ancho * 0.2) })
		tr.Enabled = false; tr.Parent = nucleo
		return tr
	end
	-- dos capas: núcleo blanco fino y halo de color ancho
	local estelas = { estela(0.6, 0.14, ColorSequence.new(BLANCO), 0), estela(2.2, 0.3, ColorSequence.new(skin.c2, skin.c3), 0.35) }
	-- chispas que deja al volar (textura de la skin)
	local chispa = ({ Tormenta = TEX.rayo, Estelar = TEX.purpurina, Te = TEX.gota })[skin.nombre]
	local vuela = emisor(centro, chispa, { Rate = 40, Lifetime = NumberRange.new(0.25, 0.45), Size = seq(0.7, 0.1),
		Transparency = seq(0, 1), Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(skin.c1, skin.c2), Acceleration = skin.nombre == "Te" and Vector3.new(0, -30, 0) or Vector3.zero })
	vuela.Enabled = false
	-- Tormenta: dos arcos eléctricos que recorren el rayo (como el "Thunderbolt of Zeus"); se encienden al aparecer
	local arcos = {}
	if skin.nombre == "Tormenta" then
		local p = {}
		for i, z in { -0.95, -0.35, 0.3, 0.95 } do
			local at = Instance.new("Attachment"); at.Position = Vector3.new(i % 2 == 0 and 0.35 or -0.35, 0, z * skin.largo); at.Parent = nucleo
			p[i] = at
		end
		for _, par in { { 1, 3 }, { 2, 4 } } do
			local b = beam(nucleo, p[par[1]], p[par[2]], TEX.rayoBeam, 0.22, skin.c2)
			b.TextureMode = Enum.TextureMode.Wrap; b.TextureLength = 3; b.TextureSpeed = 5 + math.random() * 3
			b.CurveSize0 = 0.3; b.CurveSize1 = -0.3; b.Transparency = NumberSequence.new(0.15); b.Enabled = false
			table.insert(arcos, b)
		end
	end
	nucleo.Parent = carpeta
	local base = m:GetScale()
	return { m = m, base = base, nucleo = nucleo, punta = punta, centro = centro, estelas = estelas, vuela = vuela, arcos = arcos }
end

-- ------------------------------------------------------------------ remates por skin
local REMATE = {}
function REMATE.Tormenta(skin, carpeta, centro: Vector3, a: Attachment, ignorar)
	-- rayo del cielo: dos beams que parpadean tres veces
	local _, alto = ancla(carpeta, centro + Vector3.new(math.random(-4, 4), 70, math.random(-4, 4)))
	local _, bajo = ancla(carpeta, centro)
	local b1 = beam(carpeta, alto, bajo, TEX.rayoBeam, 5, skin.c1)
	local b2 = beam(carpeta, alto, bajo, TEX.rayoBeam, 9, skin.c2)
	b2.Transparency = NumberSequence.new(0.4)
	task.spawn(function()
		for i = 1, 5 do
			b1.Enabled, b2.Enabled = i % 2 == 1, i % 2 == 1
			b1.Width0 = 5 + math.random() * 2; b2.Width1 = 7 + math.random() * 4
			task.wait(0.06)
		end
		b1:Destroy(); b2:Destroy()
	end)
	soltar(a, 8, TEX.rayo, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 1.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(80, 80),
		Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), EmissionDirection = Enum.NormalId.Top })
	soltar(a, 30, TEX.destello, { Size = seq(0.5, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(25, 45),
		SpreadAngle = Vector2.new(85, 85), Acceleration = Vector3.new(0, -60, 0), Drag = 2, Color = ColorSequence.new(skin.c2),
		EmissionDirection = Enum.NormalId.Top })
	local _, n = suelo(centro, ignorar)
	marca(carpeta, centro, n, TEX.quemadura, Color3.fromHex("#5A6890"), Rafaga.RADIO * 1.6, 1.4)
	sonido(a, SFX.zapFuerte, 1.6, 0.7)
end
function REMATE.Estelar(skin, carpeta, centro: Vector3, a: Attachment, ignorar)
	soltar(a, 16, TEX.estrella, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.2, 1.6),
		NumberSequenceKeypoint.new(1, 0.2) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(18, 34), SpreadAngle = Vector2.new(75, 75),
		Acceleration = Vector3.new(0, -35, 0), Drag = 1.2, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300),
		Color = ColorSequence.new(skin.c2, skin.c3), EmissionDirection = Enum.NormalId.Top })
	soltar(a, 24, TEX.purpurina, { Size = seq(1.4, 0.2), Transparency = seq(0, 1), Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(6, 16), SpreadAngle = Vector2.new(180, 180), Drag = 2, Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(skin.c1, skin.c2) })
	local _, n = suelo(centro, ignorar)
	marca(carpeta, centro, n, TEX.huella, skin.c2, Rafaga.RADIO * 1.5, 1.1)
	sonido(a, SFX.campanaFin, 1.4)
end
function REMATE.Te(skin, carpeta, centro: Vector3, a: Attachment, ignorar)
	soltar(a, 30, TEX.gota, { Size = seq(0.9, 0.4), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(20, 36), SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -70, 0), Orientation = Enum.ParticleOrientation.VelocityParallel, Color = ColorSequence.new(skin.c2),
		LightEmission = 0.5, EmissionDirection = Enum.NormalId.Top })
	soltar(a, 12, TEX.porcelana, { Size = seq(0.7, 0.4), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(16, 28), SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -60, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-500, 500), LightEmission = 0,
		LightInfluence = 1, EmissionDirection = Enum.NormalId.Top })
	soltar(a, 7, TEX.vapor, { Size = seq(3, 7), Transparency = seq(0.35, 1), Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(50, 50), Acceleration = Vector3.new(0, 4, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
		Color = ColorSequence.new(BLANCO), LightEmission = 0.2, EmissionDirection = Enum.NormalId.Top })
	local _, n = suelo(centro, ignorar)
	local giro = marca(carpeta, centro, n, TEX.remolino, skin.c2, Rafaga.RADIO * 1.7, 1.0)
	TweenService:Create(giro, TweenInfo.new(1.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = giro.CFrame * CFrame.Angles(0, math.pi * 2.5, 0) }):Play()
	marca(carpeta, centro, n, TEX.salpicadura, skin.c2, Rafaga.RADIO * 1.2, 1.2)
	sonido(a, SFX.chofFin, 1.4); sonido(a, SFX.cristal, 0.9, 1.2)
end

-- impacto de cada proyectil al clavarse
local function impacto(skin, carpeta, q: Vector3, normal: Vector3)
	local _, a = ancla(carpeta, q + normal * 0.3)
	if skin.nombre == "Tormenta" then
		marca(carpeta, q, normal, TEX.quemadura, Color3.fromHex("#4A5578"), 4.5, 0.6)
		soltar(a, 3, TEX.rayo, { Size = seq(2.2, 1), Transparency = seq(0, 1), Lifetime = NumberRange.new(0.12, 0.2),
			Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(60, 60) })
		sonido(a, SFX.zap, 0.7)
	elseif skin.nombre == "Estelar" then
		marca(carpeta, q, normal, TEX.huella, skin.c2, 4, 0.6)
		soltar(a, 5, TEX.estrella, { Size = seq(0.8, 0.1), Transparency = seq(0, 1), Lifetime = NumberRange.new(0.35, 0.55),
			Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -30, 0), Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-300, 300), Color = ColorSequence.new(skin.c2, skin.c3), EmissionDirection = Enum.NormalId.Top })
		sonido(a, SFX.campana, 0.6, 1.1)
	else
		marca(carpeta, q, normal, TEX.salpicadura, skin.c2, 4.2, 0.6)
		soltar(a, 8, TEX.gota, { Size = seq(0.6, 0.3), Transparency = seq(0, 1), Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(10, 16), SpreadAngle = Vector2.new(55, 55), Acceleration = Vector3.new(0, -60, 0),
			Orientation = Enum.ParticleOrientation.VelocityParallel, Color = ColorSequence.new(skin.c2), EmissionDirection = Enum.NormalId.Top })
		sonido(a, SFX.chof, 0.7)
	end
	destello(a, 2.6, skin.c1, 0.16)
end

-- ------------------------------------------------------------------ brazo alzado (ZeroMovement mezcla la pose con ZeroBrazoHechizo)
local function pose(personaje: Model, peso: () -> number)
	local c = RunService.Heartbeat:Connect(function()
		personaje:SetAttribute("ZeroBrazoHechizo", math.clamp(peso(), 0, 1))
	end)
	return function()
		if c.Connected then c:Disconnect(); personaje:SetAttribute("ZeroBrazoHechizo", nil) end
	end
end

-- animación del hechizo: ZeroMovement reproduce el clip mientras el atributo ZeroHechizo = "<clip>:<n>" (cada cliente lo pone
-- en el personaje que lanza). Devuelve con qué quitarlo (los clips sin bucle acaban solos aunque se quite antes).
local nHechizo = 0
local function hechizo(personaje: Model, clip: string)
	nHechizo += 1
	local valor = clip .. ":" .. nHechizo
	personaje:SetAttribute("ZeroHechizo", valor)
	return function()
		if personaje:GetAttribute("ZeroHechizo") == valor then personaje:SetAttribute("ZeroHechizo", nil) end
	end
end

-- ------------------------------------------------------------------ secuencia
function Rafaga.Play(personaje: Model, objetivo: Vector3, inicio: number?, origen: Vector3?, nombreSkin: string?): number
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return 0 end
	local skin = SKINS[nombreSkin or "Tormenta"] or SKINS.Tormenta
	local raiz = workspace:FindFirstChild("ZeroVFX") or Instance.new("Folder")
	raiz.Name = "ZeroVFX"; raiz.Parent = workspace
	local carpeta = Instance.new("Folder"); carpeta.Name = "Rafaga"; carpeta.Parent = raiz
	local ignorar = { personaje, raiz }
	local base = origen or hrp.Position
	local tVuelo = vuelo(base, objetivo)
	local tEstallido = Rafaga.estallido(base, objetivo)
	local escala = Rafaga.ESCALA
	local t0 = os.clock() - (if inicio then math.max(0, workspace:GetServerTimeNow() - inicio) else 0) / escala
	local cam = workspace.CurrentCamera

	local ps = {}
	for i = 1, N do
		local c = proyectil(skin, carpeta)
		c.ang = math.rad(18 + (i - 1) * (144 / (N - 1)))
		local a = (i - 1) * (2 * math.pi / N) + 0.4
		c.q, c.normal = suelo(objetivo + Vector3.new(math.cos(a), 0, math.sin(a)) * RADIO_IMPACTO * (i % 2 == 0 and 1 or 0.6), ignorar)
		c.aparece = APARECE + (i - 1) * ESCALON
		c.dispara = DISPARO + (i - 1) * CADENCIA
		c.fase = math.random() * 6
		ps[i] = c
	end

	-- orientación: punta hacia dir y la cara hacia la cámara (rayo y estrella son planos)
	local function orientar(pos: Vector3, dir: Vector3): CFrame
		local hacia = cam.CFrame.Position - pos
		local up = hacia - dir * hacia:Dot(dir)
		if up.Magnitude < 1e-3 then up = Vector3.yAxis end
		return CFrame.lookAt(pos, pos + dir, up.Unit)
	end
	-- cara mirando a 'cara' (la estrella se ve siempre de frente desde atrás) y girando como un shuriken
	local function deFrente(pos: Vector3, cara: Vector3, giro: number): CFrame
		local x = cara:Cross(Vector3.yAxis)
		if x.Magnitude < 1e-3 then x = cara:Cross(Vector3.xAxis) end
		return CFrame.fromMatrix(pos, x.Unit, cara) * CFrame.Angles(0, giro, 0)
	end
	local function abanico(c, t: number): CFrame
		local cf = hrp.CFrame
		local centro = cf * Vector3.new(0, ALTO_FAN, ATRAS_FAN)
		local radial = cf.RightVector * math.cos(c.ang) + cf.UpVector * math.sin(c.ang)
		local sale = suave((t - c.aparece) / 0.22)
		local pos = centro + radial * (0.6 + (RADIO_FAN - 0.6) * sale) + Vector3.new(0, math.sin(t * 3.2 + c.fase) * 0.09, 0)
		local apunta = (objetivo - pos).Unit
		local w = suave((t - APUNTA0) / (APUNTA1 - APUNTA0))
		local fuera = if skin.erguido then Vector3.yAxis else (radial - cf.LookVector * 0.35).Unit
		local dir = fuera:Lerp(apunta, if skin.erguido then w * 0.55 else w)
		dir = if dir.Magnitude > 1e-3 then dir.Unit else apunta
		if skin.frente then
			local cara = (-hrp.CFrame.LookVector):Lerp(-apunta, w)
			return deFrente(pos, cara.Unit, t * skin.gira + c.fase)
		end
		local o = orientar(pos, dir)
		if skin.gira then o *= CFrame.Angles(0, t * skin.gira + c.fase, 0) end
		if skin.erguido then o *= CFrame.Angles(math.sin(t * 4 + c.fase) * 0.25, 0, 0) end   -- la taza se balancea
		return o
	end
	local function colocar(c, cf: CFrame)
		c.m:PivotTo(cf)
		c.nucleo.CFrame = cf
	end
	local function visible(c, f: number)      -- 0..1: crece con rebote
		local s = math.max(rebote(f), 0.02)
		if math.abs((c.s or -1) - s) > 1e-3 then c.s = s; c.m:ScaleTo(c.base * skin.escala * s) end
	end

	-- círculo mágico detrás del cazador
	-- (dos piezas: dos Decals en la misma cara se pisan)
	local circulo = parte("Part", { Size = Vector3.new(0.1, 0.1, 0.05), Transparency = 1 })
	local dc = Instance.new("Decal"); dc.Face = Enum.NormalId.Back; dc.Texture = TEX.remolino; dc.Color3 = skin.c2; dc.Transparency = 0.15; dc.Parent = circulo
	circulo.Parent = carpeta
	local aroC = parte("Part", { Size = Vector3.new(0.1, 0.1, 0.05), Transparency = 1 })
	local da = Instance.new("Decal"); da.Face = Enum.NormalId.Back; da.Texture = TEX.anillo; da.Color3 = skin.c1; da.Transparency = 0.1; da.Parent = aroC
	aroC.Parent = carpeta

	local bajar = DISPARO + (N - 1) * CADENCIA + 0.15
	local quitarPose = hechizo(personaje, "HechizoRaro")   -- animación de la E (ZeroMovement)
	local mano = personaje:FindFirstChild("Right Arm") :: BasePart?
	if mano then
		local a = Instance.new("Attachment"); a.Position = Vector3.new(0, -1, 0); a.Parent = mano
		task.delay(0.15, function() destello(a, 2.4, skin.c2, 0.3); luz(a, skin.c2, 3, 10, 0.4) end)
		Debris:AddItem(a, 1)
	end
	sonido(hrp, SFX.aparece, 0.9)

	-- arcos eléctricos entre rayos vecinos (Tormenta)
	local arcos = {}
	if skin.nombre == "Tormenta" then
		for i = 1, N - 1 do
			local b = beam(carpeta, ps[i].centro, ps[i + 1].centro, TEX.rayoBeam, 0.9, skin.c2)
			-- arcos cortos: con Stretch los 22 quiebros de la textura se aprietan en 2 studs y se ve una banda maciza
			b.TextureMode = Enum.TextureMode.Wrap; b.TextureLength = 12; b.TextureSpeed = 3 + math.random() * 4
			b.Enabled = false
			arcos[i] = b
		end
	end

	local clavados = {}
	local estallado = false
	local conexion: RBXScriptConnection
	conexion = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) * escala
		if not hrp.Parent or not carpeta.Parent then conexion:Disconnect(); quitarPose(); carpeta:Destroy(); return end
		-- círculo: se abre, gira y se cierra al disparar el último
		local abre = suave(t / 0.3) * (1 - suave((t - bajar) / 0.25))
		local tam = 6.2 * abre
		circulo.Size = Vector3.new(math.max(tam, 0.1), math.max(tam, 0.1), 0.05)
		circulo.CFrame = hrp.CFrame * CFrame.new(0, ALTO_FAN, ATRAS_FAN + 0.4) * CFrame.Angles(0, 0, t * 2.2)
		aroC.Size = circulo.Size * Vector3.new(1.15, 1.15, 1)
		aroC.CFrame = hrp.CFrame * CFrame.new(0, ALTO_FAN, ATRAS_FAN + 0.45) * CFrame.Angles(0, 0, -t * 1.3)
		dc.Transparency = 1 - 0.85 * abre; da.Transparency = 1 - 0.9 * abre
		for i, c in ps do
			if c.roto then continue end
			if t < c.aparece then
				visible(c, 0); colocar(c, abanico(c, t))
			elseif t < c.dispara then
				visible(c, (t - c.aparece) / 0.2)
				colocar(c, abanico(c, t))
				if not c.visto then
					c.visto = true
					for _, b in c.arcos do b.Enabled = true end
					destello(c.centro, 3.4, skin.c1, 0.24); anilloLuz(c.centro, 0.4, 2.6, 0.22, skin.c2)
				end
			elseif t < c.dispara + tVuelo then
				if not c.p0 then
					visible(c, 1)
					local cf = abanico(c, t)
					c.p0 = cf.Position
					c.dir = (c.q - c.p0).Unit
					for _, e in c.estelas do e.Enabled = true end
					c.vuela.Enabled = true
					anilloLuz(c.centro, 0.5, 3.4, 0.25, skin.c2)
					destello(c.punta, 2.6, skin.c1, 0.15)
					sonido(c.nucleo, SFX.disparo, 0.45, 1 + i * 0.03)
				end
				local f = (t - c.dispara) / tVuelo
				local p = c.p0:Lerp(c.q - c.dir * skin.largo * 0.5, f * f * (2 - f))
				local o = if skin.frente then deFrente(p, -c.dir, t * skin.gira * 2.5) else orientar(p, c.dir)
				if skin.gira and not skin.frente then o *= CFrame.Angles(0, t * skin.gira * 2.5, 0) end
				if skin.erguido then o *= CFrame.Angles(0, 0, t * 14) end
				colocar(c, o)
			elseif not c.clavado then
				c.clavado = true
				if not c.dir then c.dir = (c.q - abanico(c, t).Position).Unit; visible(c, 1) end   -- llegó tarde (lag)
				local p = c.q - c.dir * skin.largo * 0.5
				colocar(c, if skin.frente then deFrente(p, (-c.dir + Vector3.yAxis).Unit, 0) else orientar(p, c.dir))
				for _, e in c.estelas do e.Enabled = false end
				c.vuela.Enabled = false
				for _, b in c.arcos do b.Enabled = false end
				impacto(skin, carpeta, c.q, c.normal)
				table.insert(clavados, c)
			end
		end
		-- arcos: parpadean entre los rayos que siguen en el abanico
		for i, b in arcos do
			local a, z = ps[i], ps[i + 1]
			local vivos = a.visto and z.visto and not a.p0 and not z.p0
			b.Enabled = vivos and math.random() < 0.6
			if b.Enabled then b.Width0 = 0.5 + math.random() * 0.8; b.Width1 = 0.5 + math.random() * 0.8 end
		end
		if not estallado and t >= tEstallido then
			estallado = true
			for _, c in ps do
				local _, a = ancla(carpeta, c.q + Vector3.new(0, 0.6, 0))
				soltar(a, 6, ({ Tormenta = TEX.rayo, Estelar = TEX.estrella, Te = TEX.porcelana })[skin.nombre], { Size = seq(0.9, 0.2),
					Transparency = seq(0, 1), Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(10, 20), SpreadAngle = Vector2.new(70, 70),
					Acceleration = Vector3.new(0, -45, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-400, 400),
					Color = ColorSequence.new(skin.c1, skin.c2), LightEmission = skin.nombre == "Te" and 0 or 1, LightInfluence = skin.nombre == "Te" and 1 or 0,
					EmissionDirection = Enum.NormalId.Top })
				c.roto = true
				c.m:Destroy()
				Debris:AddItem(c.nucleo, 1)
			end
			local centro = suelo(objetivo, ignorar)
			local pa, a = ancla(carpeta, centro + Vector3.new(0, 1.2, 0))
			destello(a, 13, skin.c1, 0.35); anilloLuz(a, 2, 18, 0.45, skin.c2); luz(pa, skin.c2, 9, 36, 0.7)
			-- onda en el suelo
			local aro = parte("Part", { Size = Vector3.new(2, 0.05, 2), CFrame = CFrame.new(centro + Vector3.new(0, 0.08, 0)), Transparency = 1 })
			local d = Instance.new("Decal"); d.Face = Enum.NormalId.Top; d.Texture = TEX.anillo; d.Color3 = skin.c2; d.Parent = aro
			aro.Parent = carpeta
			local ti = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			TweenService:Create(aro, ti, { Size = Vector3.new(Rafaga.RADIO * 3.6, 0.05, Rafaga.RADIO * 3.6) }):Play()
			TweenService:Create(d, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			-- cúpula
			local cupula = parte("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(centro),
				Material = Enum.Material.ForceField, Color = skin.c2, Transparency = 0.05 })
			cupula.Parent = carpeta
			TweenService:Create(cupula, ti, { Size = Vector3.one * Rafaga.RADIO * 2.3 }):Play()
			TweenService:Create(cupula, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			REMATE[skin.nombre](skin, carpeta, centro, a, ignorar)
			task.delay(2.6 / escala, function()
				if conexion.Connected then conexion:Disconnect() end
				carpeta:Destroy()
			end)
		end
	end)
	task.delay((tEstallido + 3.2) / escala, function()
		if conexion.Connected then conexion:Disconnect() end
		quitarPose()
		if carpeta.Parent then carpeta:Destroy() end
	end)
	task.delay((bajar + 0.4) / escala, quitarPose)
	return tEstallido + 2.6
end

-- ------------------------------------------------------------------ mareo del aturdido
local MAREO = { Tormenta = TEX.rayo, Estelar = TEX.estrella, Te = TEX.gota }
function Rafaga.aturdido(personaje: Model, nombreSkin: string?, dura: number)
	local cabeza = personaje:FindFirstChild("Head") :: BasePart?
	if not cabeza then return end
	local skin = SKINS[nombreSkin or ""] or SKINS.Tormenta
	local nombre = if SKINS[nombreSkin or ""] then nombreSkin :: string else "Tormenta"
	-- iconos que giran alrededor de la cabeza
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(4, 2); bb.StudsOffset = Vector3.new(0, 1.6, 0); bb.LightInfluence = 0; bb.AlwaysOnTop = false
	bb.Adornee = cabeza; bb.Parent = cabeza
	local iconos = {}
	for i = 1, 3 do
		local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Image = MAREO[nombre]; im.ImageColor3 = skin.c2
		im.AnchorPoint = Vector2.new(0.5, 0.5); im.Size = UDim2.fromScale(0.26, 0.52); im.Parent = bb
		iconos[i] = im
	end
	local a = Instance.new("Attachment"); a.Position = Vector3.new(0, 0.2, 0); a.Parent = cabeza
	local e = emisor(a, ({ Tormenta = TEX.rayo, Estelar = TEX.purpurina, Te = TEX.vapor })[nombre], {
		Rate = nombre == "Te" and 6 or 14, Lifetime = NumberRange.new(0.3, 0.6), Size = seq(nombre == "Te" and 1.5 or 0.9, nombre == "Te" and 3 or 0.2),
		Transparency = seq(nombre == "Te" and 0.4 or 0, 1), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), LightEmission = nombre == "Te" and 0.2 or 1 })
	local t0 = os.clock()
	local c: RBXScriptConnection
	c = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > dura or not bb.Parent then
			c:Disconnect(); bb:Destroy(); e.Enabled = false; Debris:AddItem(a, 1); return
		end
		local fuera = math.min(1, (dura - t) / 0.2)
		for i, im in iconos do
			local ang = t * 7 + i * (2 * math.pi / 3)
			im.Position = UDim2.fromScale(0.5 + math.cos(ang) * 0.32, 0.5 + math.sin(ang) * 0.16)
			im.ZIndex = if math.sin(ang) > 0 then 2 else 1
			im.ImageTransparency = 1 - fuera * (0.7 + 0.3 * math.sin(ang))
			im.Rotation = t * 200
		end
	end)
end

for nombre, s in SKINS do s.nombre = nombre end
-- utilidades que reutilizan las demás habilidades (VFX.Vortice...)
Rafaga.U = { parte = parte, seq = seq, emisor = emisor, soltar = soltar, destello = destello, anilloLuz = anilloLuz, luz = luz,
	sonido = sonido, suelo = suelo, marca = marca, ancla = ancla, beam = beam, pose = pose, hechizo = hechizo, suave = suave, rebote = rebote }
return Rafaga
