-- Bola (ModuleScript, ReplicatedStorage.VFX): habilidad de rareza COMÚN de ZERO (tecla E, cazador): CARGAR Y LANZAR.
-- Referencia: storyboards de ChatGPT en zero-habilidades/comun/ref (quieto, inicio, cargando, máximo, lanzamiento, impacto).
--   CARGA: mientras se mantiene pulsada la E, el cazador alza la varita y en la punta crece la bola (hasta Comun.carga s),
--   con partículas girando a su alrededor y un sonido que sube; todos lo ven.
--   LANZAMIENTO: al soltar sale en arco hacia donde apunta, girando, con estela.
--   IMPACTO: estalla y deja en el suelo una marca del tamaño del área; cuanto más cargada, más grande la bola y el área
--   (radioMin..radioMax) y más dura el ralentizado. Los corredores del área van más lentos (lo decide el servidor).
--   Nieve (Varita de Rama)   bola de nieve: copos, escarcha en el suelo, hielo en los pies del ralentizado
--   Tiza  (Varita de Tiza)   bola de polvo de tiza: garabatos pastel, dibujos de tiza en el suelo, nube de polvo
--   Lapiz (Lápiz Mágico)     ovillo de garabatos de grafito: virutas, rayas de lápiz en el suelo, enredado en garabatos
-- Modelos: ReplicatedStorage.ZeroHabilidades.Proyectiles.Bola<Nieve|Tiza|Lapiz> (zero-habilidades/comun/scripts/bolas.py).
--
--   Bola.fraccion(segundos, hab) -> 0..1          cuánto se cargó
--   Bola.radio(hab, f) / Bola.lentoDura(hab, f)    área y duración del ralentizado según la carga
--   Bola.vuelo(origen, objetivo) -> s              tiempo de vuelo (el servidor espera eso para aplicar el impacto)
--   Bola.cargar(personaje, skin, inicio, cargaMax) cliente: la bola crece en la varita
--   Bola.cancelar(personaje)                       cliente: quita la carga sin lanzar
--   Bola.Play(personaje, objetivo, inicio, origen, skin, _, datos)   cliente: lanzamiento e impacto (datos.carga = 0..1)
--   Bola.lento(personaje, skin, duracion)          cliente: efecto sobre el ralentizado
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rafaga = require(script.Parent:WaitForChild("Rafaga"))
local U = Rafaga.U
local T = Rafaga.TEX

local Bola = {}

local TEX = {
	copo = "rbxassetid://119079964682493", escarcha = "rbxassetid://76327663518009", tiza_suelo = "rbxassetid://137669547339021",
	grafito_suelo = "rbxassetid://119289460849345", garabato = "rbxassetid://80352333166901", viruta = "rbxassetid://125426086081712",
}
local SFX = {
	cargaNieve = "rbxassetid://9126236071", cargaTiza = "rbxassetid://9113781416", cargaLapiz = "rbxassetid://9117277530",
	lanzar = "rbxassetid://9126229255", nieve = "rbxassetid://9119316414", tiza = "rbxassetid://9113781594", lapiz = "rbxassetid://9117277763",
}
Bola.TEX, Bola.SFX = TEX, SFX
Bola.ESCALA = 1
Bola.VEL = 75

local BLANCO = Color3.new(1, 1, 1)
local function C(h: string): Color3 return Color3.fromHex(h) end
local SKINS = {
	Nieve = { modelo = "BolaNieve", c1 = BLANCO, c2 = C("#9FE4FF"), c3 = C("#4FB8FF"), particula = TEX.copo, chispa = TEX.copo, suelo = TEX.escarcha,
		polvo = C("#EAF6FF"), carga = SFX.cargaNieve, impacto = SFX.nieve, sprite = TEX.copo },
	Tiza = { modelo = "BolaTiza", c1 = BLANCO, c2 = C("#FF9ACB"), c3 = C("#8FD3FF"), oro = C("#FFE27A"), particula = TEX.garabato, chispa = T.estrella,
		suelo = TEX.tiza_suelo, polvo = C("#F4F2EA"), carga = SFX.cargaTiza, impacto = SFX.tiza, sprite = TEX.garabato },
	Lapiz = { modelo = "BolaLapiz", c1 = C("#4A4E58"), c2 = C("#F2C230"), c3 = C("#FF8FA8"), particula = TEX.viruta, chispa = TEX.garabato,
		suelo = TEX.grafito_suelo, polvo = C("#9A9DA6"), carga = SFX.cargaLapiz, impacto = SFX.lapiz, sprite = TEX.garabato },
}
for n, s in SKINS do s.nombre = n end
Bola.SKINS = SKINS

-- ------------------------------------------------------------------ números compartidos con el servidor
function Bola.fraccion(seg: number, hab): number return math.clamp(seg / hab.carga, 0, 1) end
function Bola.radio(hab, f: number): number return hab.radioMin + (hab.radioMax - hab.radioMin) * f end
function Bola.lentoDura(hab, f: number): number return hab.lentoMin + (hab.lentoMax - hab.lentoMin) * f end
function Bola.vuelo(origen: Vector3, objetivo: Vector3): number return math.clamp((objetivo - origen).Magnitude / Bola.VEL, 0.15, 1.1) end
local function tamBola(f: number): number return 0.7 + 1.5 * f end      -- radio de la bola (studs)

local function seg(x: number): number return x / Bola.ESCALA end
local function carpetaVFX(nombre: string): Folder
	local raiz = workspace:FindFirstChild("ZeroVFX") or Instance.new("Folder")
	raiz.Name = "ZeroVFX"; raiz.Parent = workspace
	local f = Instance.new("Folder"); f.Name = nombre; f.Parent = raiz
	return f
end

-- punta de la varita: en la animación de carga la varita sigue la línea del brazo (punta a ~1,9 studs de la mano)
local function punta(personaje: Model, r: number): Vector3
	local mano = personaje:FindFirstChild("Right Arm") or personaje:FindFirstChild("RightHand")
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if mano and mano:IsA("BasePart") then return (mano.CFrame * CFrame.new(0, -2.6 - r, 0)).Position end
	return if hrp then hrp.Position + Vector3.new(0, 3 + r, 0) else Vector3.zero
end

local function modeloBola(skin, carpeta: Instance): Model
	local raiz = ReplicatedStorage:FindFirstChild("ZeroHabilidades")
	local P = raiz and raiz:FindFirstChild("Proyectiles")
	local plantilla = P and P:FindFirstChild(skin.modelo)
	local m: Model
	if plantilla then
		m = plantilla:Clone()
	else                                                                   -- sin modelo importado: esfera
		m = Instance.new("Model")
		local p = U.parte("Part", { Name = "Cuerpo", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Material = Enum.Material.SmoothPlastic, Color = skin.c2 })
		p.Parent = m; m.PrimaryPart = p
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false end
	end
	m.Parent = carpeta
	return m
end

-- ------------------------------------------------------------------ carga
local cargas: { [Model]: any } = {}

function Bola.cancelar(personaje: Model)
	local c = cargas[personaje]
	if not c then return end
	cargas[personaje] = nil
	c.fin()
end

function Bola.cargar(personaje: Model, nombreSkin: string?, inicio: number?, cargaMax: number)
	Bola.cancelar(personaje)
	local skin = SKINS[nombreSkin or ""] or SKINS.Nieve
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	local carpeta = carpetaVFX("BolaCarga")
	local t0 = os.clock() - (if inicio then math.max(0, workspace:GetServerTimeNow() - inicio) else 0) / Bola.ESCALA
	local m = modeloBola(skin, carpeta)
	local base = m:GetScale()
	-- partículas que giran alrededor de la bola y polvo/brillo que sale de ella
	local orbita = {}
	for i = 1, 3 do
		local _, a = U.ancla(carpeta, hrp.Position)
		local e = U.emisor(a, skin.particula, { Rate = 14, Lifetime = NumberRange.new(0.35, 0.55), Size = U.seq(0.7, 0.2), Transparency = U.seq(0, 1),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200), Color = ColorSequence.new(skin.c1, if i == 2 then skin.c3 else skin.c2),
			LightEmission = if skin.nombre == "Lapiz" then 0 else 0.6, LightInfluence = if skin.nombre == "Lapiz" then 0.6 else 0 })
		orbita[i] = { a = a, e = e }
	end
	local _, aC = U.ancla(carpeta, hrp.Position)
	local brillo = U.emisor(aC, T.purpurina, { Rate = 22, Lifetime = NumberRange.new(0.4, 0.7), Size = U.seq(0.5, 0.1), Transparency = U.seq(0, 1),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(skin.c1, skin.c2) })
	local luz = Instance.new("PointLight"); luz.Color = skin.c2; luz.Range = 10; luz.Brightness = 1; luz.Shadows = false; luz.Parent = aC
	local sonido = Instance.new("Sound"); sonido.SoundId = skin.carga; sonido.Volume = 0.7; sonido.Looped = true; sonido.PlaybackSpeed = 0.8
	sonido.RollOffMaxDistance = 90; sonido.Parent = hrp; sonido:Play()
	local quitarPose = U.hechizo(personaje, "HechizoComunCarga")   -- varita en alto mientras carga (ZeroMovement)
	local lleno = false
	local con = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) * Bola.ESCALA
		local f = math.clamp(t / cargaMax, 0, 1)
		local r = tamBola(f)
		local p = punta(personaje, r)
		m:ScaleTo(base * r)
		m:PivotTo(CFrame.new(p) * CFrame.Angles(t * 1.5, t * 2.3, 0))
		aC.WorldPosition = p
		for i, o in orbita do
			local ang = t * (6 + i) + i * 2.1
			o.a.WorldPosition = p + Vector3.new(math.cos(ang) * (r + 0.9), math.sin(ang * 0.7 + i) * r * 0.6, math.sin(ang) * (r + 0.9))
			o.e.Rate = 10 + 20 * f
		end
		luz.Brightness = 0.5 + 2 * f; luz.Range = 8 + 8 * f
		sonido.PlaybackSpeed = 0.8 + 0.5 * f
		if f >= 1 and not lleno then                                      -- carga máxima: destello y anillo
			lleno = true
			U.destello(aC, r * 4, skin.c1, 0.25); U.anilloLuz(aC, r, r * 4, 0.35, skin.c2)
			U.sonido(aC, Rafaga.SFX.campana, 0.6, 1.4)
		end
		if lleno and math.floor(t * 4) ~= math.floor((t - 0.016) * 4) then U.anilloLuz(aC, r * 1.2, r * 2.6, 0.3, skin.c2) end
	end)
	cargas[personaje] = {
		modelo = m, carpeta = carpeta,
		fin = function()
			con:Disconnect(); quitarPose()
			for _, o in orbita do o.e.Enabled = false end
			brillo.Enabled = false
			TweenService:Create(sonido, TweenInfo.new(0.2), { Volume = 0 }):Play(); Debris:AddItem(sonido, 0.3)
			Debris:AddItem(carpeta, 0.8)
		end,
	}
end

-- ------------------------------------------------------------------ lanzamiento e impacto
function Bola.Play(personaje: Model, objetivo: Vector3, inicio: number?, origen: Vector3?, nombreSkin: string?, _: any, datos: any): number
	local skin = SKINS[nombreSkin or ""] or SKINS.Nieve
	local f = (datos and datos.carga) or 0
	local radio = (datos and datos.radio) or 6
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	local carga = cargas[personaje]
	cargas[personaje] = nil
	if carga then carga.fin() end
	U.hechizo(personaje, "HechizoComun")                               -- lanzamiento (enlaza con la pose de carga)
	local carpeta = carpetaVFX("Bola")
	local r = tamBola(f)
	local desde = if hrp then punta(personaje, r) else (origen or objetivo)
	local t0 = os.clock() - (if inicio then math.max(0, workspace:GetServerTimeNow() - inicio) else 0) / Bola.ESCALA
	local vuelo = Bola.vuelo(origen or desde, objetivo)
	local m = modeloBola(skin, carpeta)
	m:ScaleTo(m:GetScale() * r)
	-- estela y partículas del vuelo
	local nucleo = U.parte("Part", { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(desde) })
	nucleo.Parent = carpeta
	local e0 = Instance.new("Attachment"); e0.Position = Vector3.new(0, r * 0.6, 0); e0.Parent = nucleo
	local e1 = Instance.new("Attachment"); e1.Position = Vector3.new(0, -r * 0.6, 0); e1.Parent = nucleo
	local estela = Instance.new("Trail")
	estela.Attachment0, estela.Attachment1 = e0, e1; estela.Texture = T.estela; estela.TextureMode = Enum.TextureMode.Stretch
	estela.Lifetime = 0.3; estela.FaceCamera = true; estela.LightEmission = if skin.nombre == "Lapiz" then 0 else 1; estela.LightInfluence = if skin.nombre == "Lapiz" then 1 else 0
	estela.Color = ColorSequence.new(skin.c1, skin.c2); estela.Transparency = NumberSequence.new(0.2, 1); estela.Parent = nucleo
	local aN = Instance.new("Attachment"); aN.Parent = nucleo
	local rastro = U.emisor(aN, skin.particula, { Rate = 40, Lifetime = NumberRange.new(0.35, 0.6), Size = U.seq(0.6 + r * 0.3, 0.1), Transparency = U.seq(0, 1),
		Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200),
		Color = ColorSequence.new(skin.c1, skin.c2), LightEmission = if skin.nombre == "Lapiz" then 0 else 0.5, LightInfluence = if skin.nombre == "Lapiz" then 0.7 else 0 })
	if hrp then U.sonido(hrp, SFX.lanzar, 0.8, 1.1 - 0.2 * f) end
	local alto = (objetivo - desde).Magnitude * 0.12
	local hecho = false
	local con: RBXScriptConnection
	con = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) * Bola.ESCALA
		local u = math.clamp(t / vuelo, 0, 1)
		local p = desde:Lerp(objetivo + Vector3.new(0, r * 0.5, 0), u) + Vector3.new(0, alto * 4 * u * (1 - u), 0)
		nucleo.CFrame = CFrame.lookAt(p, p + (objetivo - desde).Unit)
		m:PivotTo(CFrame.new(p) * CFrame.Angles(-t * 14, t * 3, 0))
		if u >= 1 and not hecho then
			hecho = true
			con:Disconnect()
			rastro.Enabled = false; estela.Enabled = false
			for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Transparency = 1 end end
			-- IMPACTO: marca en el suelo del tamaño del área, estallido de la skin, polvo y sonido
			local suelo, normal = objetivo, Vector3.yAxis                   -- el servidor ya da el punto del suelo (no buscarlo: chocaría con alguien)
			local _, a = U.ancla(carpeta, suelo + normal * 0.6)
			U.marca(carpeta, suelo, normal, skin.suelo, BLANCO, radio * 2.1, 1.6 + f * 1.4)
			U.destello(a, r * 6, skin.c1, 0.25)
			U.anilloLuz(a, 1, radio * 1.2, 0.35, skin.c2)
			U.soltar(a, math.floor(12 + 18 * f), skin.particula, { Size = U.seq(0.9 + f * 0.6, 0.2), Transparency = U.seq(0, 1), Lifetime = NumberRange.new(0.6, 1.1),
				Speed = NumberRange.new(10 + f * 10, 22 + f * 14), SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, -35, 0), Drag = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300),
				Color = ColorSequence.new(skin.c1, skin.c2), LightEmission = if skin.nombre == "Lapiz" then 0 else 0.5, LightInfluence = if skin.nombre == "Lapiz" then 0.8 else 0 })
			U.soltar(a, math.floor(5 + 6 * f), T.vapor, { Size = U.seq(radio * 0.4, radio * 1.1), Transparency = U.seq(0.3, 1), Lifetime = NumberRange.new(0.8, 1.3),
				Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(85, 85), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
				Color = ColorSequence.new(skin.polvo), LightEmission = 0, LightInfluence = 1 })
			U.soltar(a, math.floor(6 + 8 * f), skin.chispa, { Size = U.seq(0.8, 0.1), Transparency = U.seq(0, 1), Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(8, 18), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200),
				Color = ColorSequence.new(if skin.oro then skin.oro else skin.c2, skin.c3) })
			if skin.nombre == "Nieve" then                                   -- trocitos de hielo que salen rodando por el suelo
				U.soltar(a, math.floor(8 + 10 * f), T.estela, { Size = U.seq(0.5, 0.1), Transparency = U.seq(0, 1), Lifetime = NumberRange.new(0.3, 0.5),
					Speed = NumberRange.new(20, 34), SpreadAngle = Vector2.new(90, 5), EmissionDirection = Enum.NormalId.Top,
					Orientation = Enum.ParticleOrientation.VelocityParallel, Color = ColorSequence.new(BLANCO, skin.c2) })
			end
			U.sonido(a, skin.impacto, 1, 1.05 - 0.15 * f)
			U.sonido(a, Rafaga.SFX.chof, 0.6 + 0.4 * f, 1.1 - 0.2 * f)
			local yo = Players.LocalPlayer and Players.LocalPlayer.Character
			local raiz = yo and yo:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raiz and (raiz.Position - suelo).Magnitude < radio * 2.5 then
				local cam = workspace.CurrentCamera
				local tt = os.clock()
				local nombre = "ZeroBolaTemblor" .. tt
				RunService:BindToRenderStep(nombre, Enum.RenderPriority.Camera.Value + 1, function()
					local k = (os.clock() - tt) / 0.25
					if k > 1 then RunService:UnbindFromRenderStep(nombre) return end
					cam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * (1 - k) * (0.8 + f)), math.rad((math.random() - 0.5) * (1 - k) * (0.8 + f)), 0)
				end)
			end
			task.delay(seg(3.5), function() carpeta:Destroy() end)
		end
	end)
	task.delay(seg(vuelo + 4), function() if con.Connected then con:Disconnect() end; if carpeta.Parent then carpeta:Destroy() end end)
	return vuelo
end

-- ------------------------------------------------------------------ acierto (solo quien lanzó la bola)
-- marcador en el centro de la pantalla: aspa que se cierra + "¡IMPACTO!" (x N si dio a varios) y un tic seco
function Bola.acierto(n: number, nombreSkin: string?)
	local skin = SKINS[nombreSkin or ""] or SKINS.Nieve
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	local g = pg:FindFirstChild("ZeroBolaAcierto") or Instance.new("ScreenGui")
	g.Name = "ZeroBolaAcierto"; (g :: ScreenGui).ResetOnSpawn = false; (g :: ScreenGui).IgnoreGuiInset = true; g.Parent = pg
	g:ClearAllChildren()
	local caja = Instance.new("Frame"); caja.AnchorPoint = Vector2.new(0.5, 0.5); caja.Position = UDim2.fromScale(0.5, 0.5)
	caja.Size = UDim2.fromOffset(64, 64); caja.BackgroundTransparency = 1; caja.Parent = g
	for i = 0, 3 do
		local r = Instance.new("Frame"); r.AnchorPoint = Vector2.new(0.5, 0.5); r.Size = UDim2.fromOffset(16, 4); r.BorderSizePixel = 0
		r.BackgroundColor3 = Color3.new(1, 1, 1); r.Rotation = 45 + i * 90
		local ang = math.rad(45 + i * 90)
		r.Position = UDim2.new(0.5, math.cos(ang) * 30, 0.5, math.sin(ang) * 30)
		local st = Instance.new("UIStroke"); st.Color = skin.c2; st.Thickness = 1.5; st.Parent = r
		r.Parent = caja
		TweenService:Create(r, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, math.cos(ang) * 14, 0.5, math.sin(ang) * 14) }):Play()
	end
	local t = Instance.new("TextLabel"); t.AnchorPoint = Vector2.new(0.5, 0); t.Position = UDim2.new(0.5, 0, 0.5, 40)
	t.Size = UDim2.fromOffset(240, 30); t.BackgroundTransparency = 1; t.Font = Enum.Font.FredokaOne; t.TextSize = 26
	t.TextColor3 = Color3.new(1, 1, 1); t.Text = if n > 1 then "¡IMPACTO! x" .. n else "¡IMPACTO!"
	local ts = Instance.new("UIStroke"); ts.Thickness = 3; ts.Color = Color3.fromRGB(20, 40, 70); ts.Parent = t
	local sc = Instance.new("UIScale"); sc.Scale = 1.6; sc.Parent = t
	t.Parent = g
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local tic = Instance.new("Sound"); tic.SoundId = "rbxassetid://138148057831879"; tic.Volume = 0.7; tic.Parent = g; tic:Play()
	task.delay(0.6, function()
		for _, d in caja:GetChildren() do
			if d:IsA("Frame") then TweenService:Create(d, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play() end
		end
		TweenService:Create(t, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		TweenService:Create(ts, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(caja, 1); Debris:AddItem(t, 1); Debris:AddItem(tic, 2)
end

-- ------------------------------------------------------------------ ralentizado
function Bola.lento(personaje: Model, nombreSkin: string?, dura: number)
	local skin = SKINS[nombreSkin or ""] or SKINS.Nieve
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cabeza = personaje:FindFirstChild("Head") :: BasePart?
	if not hrp then return end
	local carpeta = carpetaVFX("BolaLento")
	local a = Instance.new("Attachment"); a.Position = Vector3.new(0, -2.4, 0); a.Parent = hrp
	-- impacto en el cuerpo: estallido de nieve y golpe con sonido 3D (se oye cerca, se apaga con la distancia)
	local golpe = Instance.new("Attachment"); golpe.Parent = hrp
	U.soltar(golpe, 26, skin.particula, { Size = U.seq(1.1, 0.2), Transparency = U.seq(0, 1), Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(14, 26), SpreadAngle = Vector2.new(180, 180), Drag = 3, Acceleration = Vector3.new(0, -20, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), Color = ColorSequence.new(skin.c1, skin.c2),
		LightEmission = if skin.nombre == "Lapiz" then 0 else 0.4, LightInfluence = if skin.nombre == "Lapiz" then 0.8 else 0 })
	U.soltar(golpe, 8, T.vapor, { Size = U.seq(2, 5), Transparency = U.seq(0.25, 1), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180), Drag = 4, Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.polvo), LightEmission = 0, LightInfluence = 1 })
	U.destello(golpe, 7, skin.c1, 0.2)
	local s = Instance.new("Sound"); s.SoundId = skin.impacto; s.Volume = 1.2; s.PlaybackSpeed = 1.15
	s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = 10; s.RollOffMaxDistance = 90; s.Parent = golpe
	s:Play()
	Debris:AddItem(golpe, 3)
	local emis = {}
	if skin.nombre == "Nieve" then
		-- bloque de hielo en los pies y copos
		local hielo = U.parte("Part", { Size = Vector3.new(2.6, 1.3, 1.9), Material = Enum.Material.Ice, Color = skin.c2, Transparency = 0.25 })
		hielo.Parent = carpeta
		local c: RBXScriptConnection
		c = RunService.RenderStepped:Connect(function()
			if not hielo.Parent or not hrp.Parent then c:Disconnect() return end
			hielo.CFrame = hrp.CFrame * CFrame.new(0, -2.55, 0)
		end)
		table.insert(emis, U.emisor(a, TEX.copo, { Rate = 8, Lifetime = NumberRange.new(0.8, 1.2), Size = U.seq(0.5, 0.2), Transparency = U.seq(0, 1),
			Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -3, 0), Color = ColorSequence.new(BLANCO, skin.c2) }))
		if cabeza then                                                     -- aliento frío
			local ab = Instance.new("Attachment"); ab.Position = Vector3.new(0, -0.1, -0.7); ab.Parent = cabeza
			table.insert(emis, U.emisor(ab, T.vapor, { Rate = 4, Lifetime = NumberRange.new(0.6, 0.9), Size = U.seq(0.4, 1.4), Transparency = U.seq(0.4, 1),
				Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Front, Color = ColorSequence.new(BLANCO), LightEmission = 0, LightInfluence = 1 }))
			Debris:AddItem(ab, dura + 1.2)
		end
		task.delay(dura, function()
			if hielo.Parent then TweenService:Create(hielo, TweenInfo.new(0.3), { Transparency = 1, Size = hielo.Size * 1.2 }):Play() end
		end)
	else
		-- polvo de tiza encima / garabatos de grafito enredando las piernas
		table.insert(emis, U.emisor(a, skin.particula, { Rate = 12, Lifetime = NumberRange.new(0.5, 0.8), Size = U.seq(1.2, 0.4), Transparency = U.seq(0, 1),
			Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-260, 260),
			Color = ColorSequence.new(skin.c1, skin.c2), LockedToPart = true, LightEmission = if skin.nombre == "Lapiz" then 0 else 0.4,
			LightInfluence = if skin.nombre == "Lapiz" then 0.8 else 0 }))
		table.insert(emis, U.emisor(a, T.vapor, { Rate = 5, Lifetime = NumberRange.new(0.7, 1), Size = U.seq(1.2, 2.6), Transparency = U.seq(0.45, 1),
			Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(skin.polvo), LightEmission = 0, LightInfluence = 1 }))
	end
	if cabeza then                                                         -- icono girando sobre la cabeza
		local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromScale(1.8, 1.8); bb.StudsOffset = Vector3.new(0, 2, 0); bb.LightInfluence = 0
		bb.Adornee = cabeza; bb.Parent = carpeta
		local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Image = skin.sprite; im.ImageColor3 = skin.c2; im.Size = UDim2.fromScale(1, 1); im.Parent = bb
		local t0 = os.clock()
		local c: RBXScriptConnection
		c = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t > dura or not bb.Parent then c:Disconnect() return end
			im.Rotation = t * 90
			im.ImageTransparency = math.clamp((t - dura + 0.25) / 0.25, 0, 1)
		end)
	end
	task.delay(dura, function() for _, e in emis do e.Enabled = false end end)
	Debris:AddItem(a, dura + 1.2)
	Debris:AddItem(carpeta, dura + 0.6)
end

return Bola
