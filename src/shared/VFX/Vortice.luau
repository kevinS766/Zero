-- Vortice (ModuleScript, ReplicatedStorage.VFX): habilidad de rareza ÉPICO de ZERO (tecla E, cazador). Misma secuencia para las
-- tres armas épicas, cada una con su skin (referencia: vídeo del sello que lanza un orbe y deja tentáculos en el suelo):
--   un sello mágico vertical se abre detrás del cazador (y otro pequeño a sus pies); del sello sale el proyectil, se carga
--   y vuela en parábola con estela y anillos; al caer: destello en estrella, onda, cúpula y la erupción de la skin; queda
--   una ZONA con el sello girando en el suelo y 6 lazos/cadenas/llamas que se enroscan hacia el centro. Mientras dura, los
--   corredores que estén dentro o entren quedan CEGADOS (lo decide el servidor): su pantalla se oscurece del color de la
--   skin y solo ven un círculo a su alrededor (Vortice.cegado); los demás ven una nube oscura sobre su cabeza.
--   Lunar     (Cetro Lunar Kawaii)  luna creciente con corazón; lazos rosas, corazones y destellos
--   Sellos    (Varita de Sellos)    talismán ofuda; cadenas rojas y talismanes que orbitan
--   Espiritual (Linterna Espiritual) farol de papel; llamas de espíritu azules y manos espectrales que salen del suelo
-- Modelos: ReplicatedStorage.ZeroHabilidades.Proyectiles.<Luna|Ofuda|Farol> (zero-habilidades/epico/scripts/proyectiles_epico.py).
-- Texturas: zero-habilidades/epico/blender/texturas_epico.py (concepto de ChatGPT "Generar hoja VFX").
--
--   Vortice.Play(personaje, objetivo, inicio?, origen?, skin?, duracion?)   cliente
--   Vortice.impacto(origen, objetivo)                                    segundos hasta que cae (empieza la zona)
--   Vortice.cegado(personaje, skin, duracion, soyYo)                      ceguera (pantalla si soyYo) y nube en la cabeza
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rafaga = require(script.Parent:WaitForChild("Rafaga"))
local U = Rafaga.U
local T = Rafaga.TEX

local Vortice = {}

local TEX = {
	sello_lunar = "rbxassetid://84968724196027", sello_sellos = "rbxassetid://118176599281104", sello_espiritual = "rbxassetid://132076311095238",
	cinta = "rbxassetid://76437467197223", cadena = "rbxassetid://123769989595948", estela_llama = "rbxassetid://139973871409146",
	corazon = "rbxassetid://140101576708564", ofuda = "rbxassetid://79611231132793", llama = "rbxassetid://74665856288354",
	mano = "rbxassetid://140562667830695", vineta = "rbxassetid://138718536747604",
}
Vortice.TEX = TEX

-- ------------------------------------------------------------------ ajustes
local SELLO, CARGA, LANZA = 0.45, 0.45, 0.68     -- sello abierto, aparece el proyectil, sale disparado
local VEL = 50                                  -- studs/s horizontales (parábola)
local RADIO_SELLO = 3.6
Vortice.RADIO = 10
Vortice.DURACION = 2.5
Vortice.ESCALA = 1

local BLANCO = Color3.new(1, 1, 1)
local SKINS = {
	Lunar = { modelo = "Luna", escala = 1.1, sello = TEX.sello_lunar, tendril = TEX.cinta, ancho = 0.9, sprite = TEX.corazon,
		c1 = Color3.fromHex("#FFE6F6"), c2 = Color3.fromHex("#FF5FB8"), c3 = Color3.fromHex("#B05CFF"), frente = true, gira = 3 },
	Sellos = { modelo = "Ofuda", escala = 1.0, sello = TEX.sello_sellos, tendril = TEX.cadena, ancho = 0.75, sprite = TEX.ofuda,
		c1 = Color3.fromHex("#FFF1D6"), c2 = Color3.fromHex("#FF2A2A"), c3 = Color3.fromHex("#8A0F1F"), frente = true, gira = 7 },
	Espiritual = { modelo = "Farol", escala = 1.0, sello = TEX.sello_espiritual, tendril = TEX.estela_llama, ancho = 1.1, sprite = TEX.llama,
		c1 = Color3.fromHex("#E6F6FF"), c2 = Color3.fromHex("#4FB8FF"), c3 = Color3.fromHex("#2A5BFF"), erguido = true },
}
for n, s in SKINS do s.nombre = n end
Vortice.SKINS = SKINS

local function vuelo(origen: Vector3, objetivo: Vector3): number
	local d = objetivo - origen
	return math.clamp(Vector2.new(d.X, d.Z).Magnitude / VEL, 0.45, 0.85)
end
function Vortice.impacto(origen: Vector3, objetivo: Vector3): number
	return LANZA + vuelo(origen, objetivo)
end

-- ------------------------------------------------------------------ piezas
local function proyectil(skin, carpeta: Instance)
	local raiz = ReplicatedStorage:FindFirstChild("ZeroHabilidades")
	local plantilla = raiz and raiz:FindFirstChild("Proyectiles") and raiz.Proyectiles:FindFirstChild(skin.modelo)
	local m: Model
	if plantilla then
		m = plantilla:Clone()
	else
		m = Instance.new("Model")
		local p = U.parte("Part", { Name = "Cuerpo", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, Material = Enum.Material.Neon, Color = skin.c2 })
		p.Parent = m; m.PrimaryPart = p
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false end
	end
	m.Parent = carpeta
	local nucleo = U.parte("Part", { Size = Vector3.one * 0.2, Transparency = 1 })
	local centro = Instance.new("Attachment"); centro.Parent = nucleo
	local e0 = Instance.new("Attachment"); e0.Position = Vector3.new(-0.5, 0, 0); e0.Parent = nucleo
	local e1 = Instance.new("Attachment"); e1.Position = Vector3.new(0.5, 0, 0); e1.Parent = nucleo
	local estelas = {}
	for _, cfg in { { 0.7, 0.16, ColorSequence.new(BLANCO), 0 }, { 2.6, 0.35, ColorSequence.new(skin.c2, skin.c3), 0.3 } } do
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = e0, e1; tr.Texture = T.estela; tr.TextureMode = Enum.TextureMode.Stretch
		tr.Lifetime = cfg[2]; tr.MinLength = 0.05; tr.FaceCamera = true; tr.LightEmission = 1; tr.LightInfluence = 0; tr.Color = cfg[3]
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, cfg[4]), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, cfg[1]), NumberSequenceKeypoint.new(1, cfg[1] * 0.2) })
		tr.Enabled = false; tr.Parent = nucleo
		table.insert(estelas, tr)
	end
	-- anillos que deja al volar (como el orbe del vídeo) y chispas de la skin
	local anillos = U.emisor(centro, T.anillo, { Rate = 14, Lifetime = NumberRange.new(0.25), Size = U.seq(1.6, 3.4), Transparency = U.seq(0.2, 1),
		Color = ColorSequence.new(skin.c1, skin.c2), LockedToPart = false, ZOffset = 1 })
	local chispas = U.emisor(centro, skin.sprite, { Rate = 22, Lifetime = NumberRange.new(0.35, 0.6), Size = U.seq(0.8, 0.1), Transparency = U.seq(0, 1),
		Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(-30, 30),
		Color = ColorSequence.new(skin.nombre == "Sellos" and BLANCO or skin.c2), LightEmission = skin.nombre == "Sellos" and 0 or 1,
		LightInfluence = skin.nombre == "Sellos" and 1 or 0 })
	anillos.Enabled, chispas.Enabled = false, false
	nucleo.Parent = carpeta
	return { m = m, base = m:GetScale(), nucleo = nucleo, centro = centro, estelas = estelas, emisores = { anillos, chispas } }
end

local function disco(carpeta: Instance, tex: string, color: Color3, cf: CFrame, cara: Enum.NormalId)
	local p = U.parte("Part", { Size = Vector3.new(0.1, 0.05, 0.1), Transparency = 1, CFrame = cf })
	local d = Instance.new("Decal"); d.Face = cara; d.Texture = tex; d.Color3 = color; d.Transparency = 1; d.Parent = p
	p.Parent = carpeta
	return p, d
end

-- erupción al caer
local ERUPCION = {}
function ERUPCION.Lunar(skin, a: Attachment)
	U.soltar(a, 14, TEX.corazon, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.2, 1.3), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = U.seq(0, 1), Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(12, 24), SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, -14, 0), Drag = 1.2, Rotation = NumberRange.new(-25, 25), Color = ColorSequence.new(skin.c2, skin.c1),
		EmissionDirection = Enum.NormalId.Top })
	U.soltar(a, 20, T.purpurina, { Size = U.seq(1.6, 0.2), Transparency = U.seq(0, 1), Lifetime = NumberRange.new(0.7, 1.2),
		Speed = NumberRange.new(6, 18), SpreadAngle = Vector2.new(70, 70), Drag = 2, Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(skin.c1, skin.c2), EmissionDirection = Enum.NormalId.Top })
end
function ERUPCION.Sellos(skin, a: Attachment)
	U.soltar(a, 16, TEX.ofuda, { Size = U.seq(1.3, 0.9), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(0.9, 1.4), Speed = NumberRange.new(14, 26), SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -12, 0), Drag = 1.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-260, 260),
		LightEmission = 0, LightInfluence = 1, EmissionDirection = Enum.NormalId.Top })
	U.soltar(a, 30, T.destello, { Size = U.seq(0.6, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(20, 40), SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, -40, 0), Drag = 2, Color = ColorSequence.new(skin.c2), EmissionDirection = Enum.NormalId.Top })
end
function ERUPCION.Espiritual(skin, a: Attachment)
	U.soltar(a, 18, TEX.llama, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(0.3, 3.2), NumberSequenceKeypoint.new(1, 0.4) }),
		Transparency = U.seq(0.05, 1), Lifetime = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 6, 0), Rotation = NumberRange.new(-12, 12), Color = ColorSequence.new(skin.c1, skin.c2), EmissionDirection = Enum.NormalId.Top })
	U.soltar(a, 10, T.vapor, { Size = U.seq(3, 7), Transparency = U.seq(0.45, 1), Lifetime = NumberRange.new(1, 1.5), Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(60, 60), Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c2), LightEmission = 0.6,
		EmissionDirection = Enum.NormalId.Top })
end
local SFX_FIN = { Lunar = Rafaga.SFX.campanaFin, Sellos = Rafaga.SFX.zapFuerte, Espiritual = Rafaga.SFX.chofFin }

-- ------------------------------------------------------------------ secuencia
function Vortice.Play(personaje: Model, objetivo: Vector3, inicio: number?, origen: Vector3?, nombreSkin: string?, duracion: number?): number
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return 0 end
	local skin = SKINS[nombreSkin or ""] or SKINS.Lunar
	local dur = duracion or Vortice.DURACION
	local R = Vortice.RADIO
	local raiz = workspace:FindFirstChild("ZeroVFX") or Instance.new("Folder")
	raiz.Name = "ZeroVFX"; raiz.Parent = workspace
	local carpeta = Instance.new("Folder"); carpeta.Name = "Vortice"; carpeta.Parent = raiz
	local ignorar = { personaje, raiz }
	local base = origen or hrp.Position
	local tVuelo = vuelo(base, objetivo)
	local tCae = LANZA + tVuelo
	local tFin = tCae + dur
	local escala = Vortice.ESCALA
	Rafaga.ESCALA = escala                                               -- (las partículas de U usan su TimeScale)
	local t0 = os.clock() - (if inicio then math.max(0, workspace:GetServerTimeNow() - inicio) else 0) / escala
	local cam = workspace.CurrentCamera
	local centroSuelo, normalSuelo = U.suelo(objetivo, ignorar)

	-- sello vertical detrás del cazador y sello pequeño en el suelo
	local sello, dSello = disco(carpeta, skin.sello, BLANCO, CFrame.identity, Enum.NormalId.Back)
	local pie, dPie = disco(carpeta, skin.sello, BLANCO, CFrame.identity, Enum.NormalId.Top)
	U.sonido(hrp, Rafaga.SFX.aparece, 0.9, 0.85)
	local quitarPose = U.hechizo(personaje, "HechizoEpico")   -- animación de la E (ZeroMovement)

	local p = proyectil(skin, carpeta)
	local p0: Vector3? = nil
	local caido, fin = false, false
	local zona: { [string]: any }? = nil

	local function deFrente(pos: Vector3, cara: Vector3, giro: number): CFrame
		local x = cara:Cross(Vector3.yAxis)
		if x.Magnitude < 1e-3 then x = cara:Cross(Vector3.xAxis) end
		return CFrame.fromMatrix(pos, x.Unit, cara) * CFrame.Angles(0, giro, 0)
	end
	local function orientar(pos: Vector3, t: number, dir: Vector3?): CFrame
		if skin.erguido then                                                 -- farol de pie (LookVector arriba), girando y balanceándose
			return CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, 0, t * 1.5) * CFrame.Angles(math.sin(t * 5) * 0.15, 0, 0)
		end
		local cara = (cam.CFrame.Position - pos).Unit
		return deFrente(pos, cara, t * (skin.gira or 0))
	end
	local function colocar(cf: CFrame, s: number)
		if math.abs((p.s or -1) - s) > 1e-3 then p.s = s; p.m:ScaleTo(p.base * skin.escala * math.max(s, 0.02)) end
		p.m:PivotTo(cf); p.nucleo.CFrame = cf
	end

	local function crearZona()
		local z = {}
		local cfSuelo = CFrame.lookAt(centroSuelo, centroSuelo + normalSuelo) * CFrame.Angles(-math.pi / 2, 0, 0)
		z.cf = cfSuelo
		z.sello, z.dSello = disco(carpeta, skin.sello, BLANCO, cfSuelo + normalSuelo * 0.06, Enum.NormalId.Top)
		z.centro = select(2, U.ancla(carpeta, centroSuelo + normalSuelo * 2.2))
		z.centro.WorldAxis = Vector3.yAxis
		-- 6 lazos/cadenas/llamas del borde al centro que se enroscan
		z.bordes, z.beams = {}, {}
		for i = 1, 6 do
			local _, a = U.ancla(carpeta, centroSuelo)
			a.WorldAxis = Vector3.yAxis                                          -- la curva sube desde el borde y cae al centro
			local b = U.beam(carpeta, a, z.centro, skin.tendril, skin.ancho, skin.nombre == "Sellos" and Color3.fromHex("#FF5A5A") or skin.c2)
			b.TextureMode = Enum.TextureMode.Wrap; b.TextureLength = if skin.nombre == "Sellos" then 2.2 else 4
			b.TextureSpeed = if skin.nombre == "Sellos" then -1.2 else -2.2   -- el dibujo corre hacia el centro
			b.LightEmission = skin.nombre == "Sellos" and 0.4 or 1; b.Segments = 12
			b.CurveSize0, b.CurveSize1 = 6, -4.5
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(1, 0.25) })
			z.bordes[i], z.beams[i] = a, b
		end
		-- partículas que giran hacia dentro sobre todo el disco
		local discoP = U.parte("Part", { Size = Vector3.new(R * 2, 0.2, R * 2), Transparency = 1, CFrame = cfSuelo + normalSuelo * 0.3 })
		discoP.Parent = carpeta
		z.emisores = {
			U.emisor(discoP, skin.sprite, { Shape = Enum.ParticleEmitterShape.Cylinder, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 16, Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(9, 14),
				Size = U.seq(skin.nombre == "Sellos" and 1.1 or 0.9, 0.3), Transparency = U.seq(0.05, 1), Rotation = NumberRange.new(-40, 40),
				RotSpeed = NumberRange.new(-120, 120), Color = ColorSequence.new(skin.nombre == "Sellos" and BLANCO or skin.c2),
				LightEmission = skin.nombre == "Sellos" and 0 or 1, LightInfluence = skin.nombre == "Sellos" and 1 or 0 }),
			U.emisor(discoP, T.purpurina, { Shape = Enum.ParticleEmitterShape.Cylinder, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = 24, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(8, 12), Size = U.seq(1, 0.1), Transparency = U.seq(0, 1),
				Color = ColorSequence.new(skin.c1, skin.c2) }),
		}
		if skin.nombre == "Espiritual" then                                   -- manos espectrales que salen del suelo
			table.insert(z.emisores, U.emisor(discoP, TEX.mano, { Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				Rate = 7, Lifetime = NumberRange.new(0.7, 1.0), Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Top,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.3, 2.6), NumberSequenceKeypoint.new(1, 2.2) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.15), NumberSequenceKeypoint.new(1, 1) }),
				Color = ColorSequence.new(skin.c1, skin.c2) }))
		elseif skin.nombre == "Sellos" then                                    -- talismanes que orbitan
			z.orbita = {}
			for i = 1, 5 do
				local pp = U.parte("Part", { Size = Vector3.new(0.9, 1.8, 0.05), Transparency = 1 })
				for _, cara in { Enum.NormalId.Front, Enum.NormalId.Back } do
					local d = Instance.new("Decal"); d.Face = cara; d.Texture = TEX.ofuda; d.Parent = pp
				end
				pp.Parent = carpeta
				z.orbita[i] = pp
			end
		end
		z.luz = Instance.new("PointLight"); z.luz.Color = skin.c2; z.luz.Brightness = 2.5; z.luz.Range = R * 1.6; z.luz.Shadows = false; z.luz.Parent = discoP
		return z
	end

	local conexion: RBXScriptConnection
	conexion = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) * escala
		if not hrp.Parent or not carpeta.Parent then conexion:Disconnect(); quitarPose(); carpeta:Destroy(); return end
		-- sellos del cazador: se abren, giran y se cierran tras lanzar
		local abre = U.suave(t / SELLO) * (1 - U.suave((t - LANZA - 0.15) / 0.35))
		local tam = RADIO_SELLO * 2 * U.rebote(math.min(t / SELLO, 1)) * (0.7 + 0.3 * abre)
		sello.Size = Vector3.new(math.max(tam, 0.1), math.max(tam, 0.1), 0.05)
		sello.CFrame = hrp.CFrame * CFrame.new(0, 1.9, 1.6) * CFrame.Angles(0, 0, t * 1.4)
		dSello.Transparency = 1 - abre
		pie.Size = Vector3.new(math.max(tam * 0.9, 0.1), 0.05, math.max(tam * 0.9, 0.1))
		pie.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.95, 0)) * CFrame.Angles(0, -t * 1.1, 0)
		dPie.Transparency = 1 - abre * 0.7

		-- proyectil
		local salida = hrp.CFrame * Vector3.new(0, 1.9, 1.2)
		if t < CARGA then
			colocar(orientar(salida, t), 0)
		elseif t < LANZA then
			if not p.visto then
				p.visto = true
				U.destello(p.centro, 4, skin.c1, 0.3); U.anilloLuz(p.centro, 0.5, 4.5, 0.3, skin.c2); U.luz(p.nucleo, skin.c2, 3, 12, 0.5)
			end
			colocar(orientar(salida, t), U.rebote((t - CARGA) / (LANZA - CARGA)))
		elseif t < tCae then
			if not p0 then
				p0 = salida
				for _, e in p.estelas do e.Enabled = true end
				for _, e in p.emisores do e.Enabled = true end
				U.sonido(p.nucleo, Rafaga.SFX.disparo, 0.6, 0.8)
				colocar(orientar(salida, t), 1)
			end
			local f = (t - LANZA) / tVuelo
			local pa = (p0 :: Vector3)
			local alto = 3 + (centroSuelo - pa).Magnitude * 0.22
			local pos = pa:Lerp(centroSuelo + normalSuelo * 0.8, f) + Vector3.new(0, alto * 4 * f * (1 - f), 0)
			local dir = (centroSuelo - pa) + Vector3.new(0, alto * 4 * (1 - 2 * f), 0)
			colocar(orientar(pos, t, dir.Unit), 1)
		elseif not caido then
			caido = true
			for _, e in p.estelas do e.Enabled = false end
			for _, e in p.emisores do e.Enabled = false end
			p.m:Destroy(); Debris:AddItem(p.nucleo, 1)
			local pa, a = U.ancla(carpeta, centroSuelo + normalSuelo * 1.2)
			U.destello(a, 14, skin.c1, 0.4); U.anilloLuz(a, 2, 20, 0.5, skin.c2); U.luz(pa, skin.c2, 9, 36, 0.8)
			local aro = U.parte("Part", { Size = Vector3.new(2, 0.05, 2), CFrame = CFrame.new(centroSuelo + normalSuelo * 0.1), Transparency = 1 })
			local d = Instance.new("Decal"); d.Face = Enum.NormalId.Top; d.Texture = T.anillo; d.Color3 = skin.c2; d.Parent = aro
			aro.Parent = carpeta
			TweenService:Create(aro, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(R * 3.4, 0.05, R * 3.4) }):Play()
			TweenService:Create(d, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			local cupula = U.parte("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(centroSuelo),
				Material = Enum.Material.ForceField, Color = skin.c2, Transparency = 0.05 })
			cupula.Parent = carpeta
			TweenService:Create(cupula, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.one * R * 1.9 }):Play()
			TweenService:Create(cupula, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			ERUPCION[skin.nombre](skin, a)
			U.sonido(a, SFX_FIN[skin.nombre], 1.4, 0.9)
			zona = crearZona()
		end

		-- zona: el sello del suelo crece y gira; los lazos se enroscan hacia el centro
		if zona then
			local z = zona
			local tz = t - tCae
			local vis = U.suave(tz / 0.3) * (1 - U.suave((t - tFin) / 0.4))
			local diam = R * 2.15 * (0.6 + 0.4 * U.suave(tz / 0.35))
			z.sello.Size = Vector3.new(diam, 0.05, diam)
			z.sello.CFrame = z.cf * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, -tz * 0.9, 0)
			z.dSello.Transparency = 1 - vis * 0.95
			for i, a in z.bordes do
				local ang = i * math.pi / 3 + tz * 1.6
				local r = R * (0.95 - 0.08 * math.sin(tz * 3 + i))
				a.WorldPosition = (z.cf * CFrame.new(math.cos(ang) * r, 0.3, math.sin(ang) * r)).Position
				z.beams[i].Enabled = vis > 0.05
				z.beams[i].Width0 = skin.ancho * 1.5 * vis; z.beams[i].Width1 = skin.ancho * 0.6 * vis
			end
			if z.orbita then
				for i, pp in z.orbita do
					local ang = i * 2 * math.pi / 5 + tz * 2.2
					local pos = (z.cf * CFrame.new(math.cos(ang) * R * 0.6, 1.6 + math.sin(tz * 3 + i) * 0.3, math.sin(ang) * R * 0.6)).Position
					pp.CFrame = CFrame.lookAt(pos, (z.cf * CFrame.new(0, 1.6, 0)).Position) * CFrame.Angles(0, math.pi / 2, 0)
					for _, d in pp:GetChildren() do if d:IsA("Decal") then d.Transparency = 1 - vis end end
				end
			end
			z.luz.Brightness = 2.5 * vis
			if t >= tFin and not fin then
				fin = true
				for _, e in z.emisores do e.Enabled = false end
				U.soltar(z.centro, 1, T.destello, { Size = U.seq(8, 1), Transparency = U.seq(0.1, 1), Lifetime = NumberRange.new(0.3), Color = ColorSequence.new(skin.c1) })
			end
			if t >= tFin + 0.45 then
				conexion:Disconnect(); quitarPose(); carpeta:Destroy()
			end
		end
	end)
	task.delay((tFin + 1.5) / escala, function()                           -- seguridad
		if conexion.Connected then conexion:Disconnect() end
		quitarPose()
		if carpeta.Parent then carpeta:Destroy() end
	end)
	return tFin
end

-- ------------------------------------------------------------------ ceguera
function Vortice.cegado(personaje: Model, nombreSkin: string?, dura: number, soyYo: boolean)
	local skin = SKINS[nombreSkin or ""] or SKINS.Lunar
	local cabeza = personaje:FindFirstChild("Head") :: BasePart?
	if cabeza then                                                        -- nube oscura con chispas de la skin sobre la cabeza
		local a = Instance.new("Attachment"); a.Position = Vector3.new(0, 0.9, 0); a.Parent = cabeza
		local humo = U.emisor(a, T.vapor, { Rate = 10, Lifetime = NumberRange.new(0.6, 0.9), Size = U.seq(1.6, 2.6), Transparency = U.seq(0.25, 1),
			Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
			Color = ColorSequence.new(Color3.fromRGB(25, 20, 35)), LightEmission = 0, LightInfluence = 0 })
		local chispas = U.emisor(a, skin.sprite, { Rate = 6, Lifetime = NumberRange.new(0.4, 0.7), Size = U.seq(0.6, 0.1), Transparency = U.seq(0, 1),
			Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(skin.nombre == "Sellos" and BLANCO or skin.c2),
			LightEmission = skin.nombre == "Sellos" and 0 or 1, LightInfluence = skin.nombre == "Sellos" and 1 or 0 })
		task.delay(dura, function() humo.Enabled = false; chispas.Enabled = false; Debris:AddItem(a, 1) end)
	end
	if not soyYo then return end
	-- mi pantalla: viñeta negra con un hueco alrededor del personaje, tinte de la skin, desenfoque y menos color
	local gui = Instance.new("ScreenGui"); gui.Name = "ZeroCeguera"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 50; gui.ResetOnSpawn = false
	local vineta = Instance.new("ImageLabel"); vineta.BackgroundTransparency = 1; vineta.Image = TEX.vineta; vineta.ImageColor3 = Color3.new(0, 0, 0)
	vineta.AnchorPoint = Vector2.new(0.5, 0.5); vineta.Position = UDim2.fromScale(0.5, 0.5); vineta.Size = UDim2.fromScale(1.5, 1.5)
	vineta.SizeConstraint = Enum.SizeConstraint.RelativeXX           -- cuadrada y del ancho de la pantalla: cubre también los lados
	vineta.ImageTransparency = 1; vineta.Parent = gui
	local bandas = {}                                                    -- negro a los lados de la viñeta (pantallas anchas)
	for _, x in { -1, 1 } do
		local f = Instance.new("Frame"); f.BackgroundColor3 = Color3.new(0, 0, 0); f.BorderSizePixel = 0; f.BackgroundTransparency = 1
		f.Position = UDim2.fromScale(x, 0); f.Size = UDim2.fromScale(1, 1); f.Parent = vineta
		table.insert(bandas, f)
	end
	local tinte = Instance.new("Frame"); tinte.BackgroundColor3 = skin.c3; tinte.Size = UDim2.fromScale(1, 1); tinte.BackgroundTransparency = 1; tinte.Parent = gui
	gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local Lighting = game:GetService("Lighting")
	local cc = Instance.new("ColorCorrectionEffect"); cc.Name = "ZeroCeguera"; cc.Parent = Lighting
	local blur = Instance.new("BlurEffect"); blur.Name = "ZeroCeguera"; blur.Size = 0; blur.Parent = Lighting
	local entra, sale = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(vineta, entra, { ImageTransparency = 0, Size = UDim2.fromScale(0.75, 0.75) }):Play()
	TweenService:Create(tinte, entra, { BackgroundTransparency = 0.82 }):Play()
	for _, f in bandas do TweenService:Create(f, entra, { BackgroundTransparency = 0.03 }):Play() end
	TweenService:Create(cc, entra, { Brightness = -0.25, Saturation = -0.6, TintColor = skin.c1 }):Play()
	TweenService:Create(blur, entra, { Size = 10 }):Play()
	task.delay(math.max(dura - 0.6, 0), function()
		TweenService:Create(vineta, sale, { ImageTransparency = 1, Size = UDim2.fromScale(1.5, 1.5) }):Play()
		TweenService:Create(tinte, sale, { BackgroundTransparency = 1 }):Play()
		for _, f in bandas do TweenService:Create(f, sale, { BackgroundTransparency = 1 }):Play() end
		TweenService:Create(cc, sale, { Brightness = 0, Saturation = 0, TintColor = BLANCO }):Play()
		TweenService:Create(blur, sale, { Size = 0 }):Play()
		task.delay(0.65, function() gui:Destroy(); cc:Destroy(); blur:Destroy() end)
	end)
end

return Vortice
