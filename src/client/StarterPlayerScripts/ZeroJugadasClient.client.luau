-- ZeroJugadasClient (LocalScript, StarterPlayerScripts): efectos de ServerScriptService.ZeroJugadas (RemoteEvent
-- ReplicatedStorage.ZeroJugadas). Diseños hechos con ChatGPT (zero-jugabilidad/ref) y subidos como imágenes.
--   PerfectDodge: tú -> "PERFECT / DODGE" con el mismo estilo que el combo, fantasma y sonido; los demás -> "PERFECT!"
--   Racha: el cazador -> medidor de combo (x1, x2... con título de elogio y barra de tiempo, estilo Arkham Knight),
--          un poco por encima del centro; los demás -> aviso pequeño cuando sube de título.
--   PowerUp / PowerUpRecogido / EscudoRoto: objetos que flotan con columna de luz, marcador con distancia para los
--          corredores, aviso al aparecer, iconos de los efectos activos y burbuja del escudo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("ZeroJugadas") :: RemoteEvent

local IMG = {
	atlas = "rbxassetid://84239323042542", aura = "rbxassetid://91402442429342", remolino = "rbxassetid://139028654618935",   -- glifos del combo y del PERFECT (zero-jugabilidad/combo/gen_atlas.py)
	Salto = "rbxassetid://128675149440488", Velocidad = "rbxassetid://80817962065387", Escudo = "rbxassetid://73248159637423",
	Dash = "rbxassetid://111887489860353",
}
local SFX = {   -- elegidos con zero-jugabilidad/tonal_sfx.py (muestras tonales que se pueden afinar)
	nota = { 97005650217537, 0.5, 1 },     -- marimba Do5: el combo sube por la escala pentatónica
	acento = { 95997307202734, 0.28, 1 },  -- campana brillante (Do7) al cambiar de título y en el PERFECT
	tap = { 122966251252708, 0.45, 1 },    -- golpecito seco que da cuerpo a cada golpe
	-- racha: los sonidos del usuario (recortes de su referencia, zero-jugabilidad/ref_sonido; subidos al grupo Kaisitos)
	tink = { 122783970121544, 0.6, 1 }, final = { 121627766499611, 0.6, 1 },
	whoosh = { 128831960761599, 0.6, 1 },  -- esquiva
	sale = { 114909571211051, 0.7, 1 }, coge = { 3406813517, 0.6, 1.1 }, escudo = { 128337509633706, 0.8, 1 },
}
local POWER = {
	Salto = { nombre = "SALTO GIGANTE", texto = "Saltas el doble", color = Color3.fromRGB(120, 255, 140) },
	Velocidad = { nombre = "VELOCIDAD", texto = "+35% de velocidad", color = Color3.fromRGB(255, 214, 70) },
	Escudo = { nombre = "ESCUDO", texto = "Aguanta un golpe", color = Color3.fromRGB(110, 200, 255) },
	Dash = { nombre = "DASH EXTRA", texto = "Un dash más, aunque esté en recarga", color = Color3.fromRGB(255, 120, 220) },
}
local TINTA = Color3.fromRGB(18, 26, 58)

-- precarga: si no, la primera vez el logotipo sale vacío (la imagen aún no ha llegado)
task.spawn(function()
	local ids = {}
	for _, v in IMG do table.insert(ids, v) end
	for _, v in SFX do table.insert(ids, "rbxassetid://" .. v[1]) end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
end)

-- ------------------------------------------------------------------ utilidades
local function sonar(def, donde: Instance?, vol: number?)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. def[1]; s.Volume = def[2] * (vol or 1); s.PlaybackSpeed = def[3]
	if donde then   -- 3D: se oye cerca y se apaga del todo a 90 studs
		s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = 12; s.RollOffMaxDistance = 90
		s.Parent = donde; s:Play(); Debris:AddItem(s, 6)
	else SoundService:PlayLocalSound(s) end
end
local function tw(o: Instance, t: number, props, estilo: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local x = TweenService:Create(o, TweenInfo.new(t, estilo or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local gui = Instance.new("ScreenGui")
gui.Name = "ZeroJugadasUI"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

-- sacudida de cámara (después de la cámara del juego y de ZeroControls)
local sacudida = { fuerza = 0, fin = 0 }
RunService:BindToRenderStep("ZeroJugadasSacudida", Enum.RenderPriority.Camera.Value + 2, function()
	local cam = workspace.CurrentCamera
	local resto = sacudida.fin - os.clock()
	if not cam or resto <= 0 then return end
	local f = sacudida.fuerza * math.clamp(resto / 0.3, 0, 1)
	cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * f), math.rad((math.random() - 0.5) * f), 0)
end)
local function sacudir(fuerza: number, dura: number)
	sacudida.fuerza = math.max(fuerza, if os.clock() < sacudida.fin then sacudida.fuerza else 0)
	sacudida.fin = os.clock() + dura
end
local function golpeFOV(extra: number)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local base = cam.FieldOfView
	cam.FieldOfView = base + extra
	tw(cam, 0.35, { FieldOfView = base }, Enum.EasingStyle.Quad)
end

-- anillo de choque y esquirlas que salen del logotipo
local function estallido(centro: UDim2, color: Color3, n: number, tam: number)
	local anillo = Instance.new("Frame")
	anillo.AnchorPoint = Vector2.new(0.5, 0.5); anillo.Position = centro; anillo.Size = UDim2.fromOffset(20, 20)
	anillo.BackgroundTransparency = 1
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = anillo
	local st = Instance.new("UIStroke"); st.Color = color; st.Thickness = 6; st.Parent = anillo
	anillo.Parent = gui
	tw(anillo, 0.45, { Size = UDim2.fromOffset(tam, tam) }, Enum.EasingStyle.Quart)
	tw(st, 0.45, { Transparency = 1, Thickness = 1 })
	Debris:AddItem(anillo, 0.5)
	for k = 1, n do
		local a = (k / n) * math.pi * 2 + math.random() * 0.4
		local e = Instance.new("Frame")
		e.AnchorPoint = Vector2.new(0.5, 0.5); e.Position = centro; e.Size = UDim2.fromOffset(6, 18 + math.random(0, 14))
		e.Rotation = math.deg(a) + 90; e.BackgroundColor3 = if k % 3 == 0 then Color3.new(1, 1, 1) else color; e.BorderSizePixel = 0
		local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(1, 0); ec.Parent = e
		e.Parent = gui
		local d = tam * (0.45 + math.random() * 0.3)
		tw(e, 0.5, { Position = centro + UDim2.fromOffset(math.cos(a) * d, math.sin(a) * d), BackgroundTransparency = 1, Rotation = e.Rotation + math.random(-60, 60) },
			Enum.EasingStyle.Quart)
		Debris:AddItem(e, 0.55)
	end
end

-- cartel pequeño encima de un personaje (lo ven todos)
-- avisos de lo que hacen otros: solo si ocurre cerca de ti
local function cerca(char: Model?): boolean
	local a = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local b = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return a ~= nil and b ~= nil and (a.Position - b.Position).Magnitude < 120
end
local function cartel3D(char: Model, imagen: string?, texto: string?, color: Color3, dura: number)
	local cabeza = char:FindFirstChild("Head") :: BasePart?
	if not cabeza then return end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 50); bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0); bb.AlwaysOnTop = true; bb.MaxDistance = 70
	bb.LightInfluence = 0; bb.Adornee = cabeza
	local cont: GuiObject
	if imagen then
		local i = Instance.new("ImageLabel"); i.Size = UDim2.fromScale(1, 1); i.BackgroundTransparency = 1; i.Image = imagen
		i.ScaleType = Enum.ScaleType.Fit; cont = i
	else
		local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Font = Enum.Font.FredokaOne
		t.TextScaled = true; t.Text = texto or ""; t.TextColor3 = color
		local s = Instance.new("UIStroke"); s.Thickness = 3; s.Color = TINTA; s.Parent = t
		cont = t
	end
	local esc = Instance.new("UIScale"); esc.Scale = 0.2; esc.Parent = cont
	cont.Parent = bb
	bb.Parent = gui
	tw(esc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tw(bb, dura, { StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0) }, Enum.EasingStyle.Sine)
	task.delay(dura - 0.3, function()
		if cont:IsA("ImageLabel") then tw(cont, 0.3, { ImageTransparency = 1 }) else tw(cont :: TextLabel, 0.3, { TextTransparency = 1 }) end
	end)
	Debris:AddItem(bb, dura)
end

-- fantasma del personaje que se queda atrás y se desvanece (afterimage de la esquiva)
local function fantasma(char: Model, color: Color3)
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
			local g = Instance.new("Part")
			g.Size = p.Size; g.CFrame = p.CFrame; g.Anchored = true; g.CanCollide = false; g.CanQuery = false; g.CastShadow = false
			g.Material = Enum.Material.Neon; g.Color = color; g.Transparency = 0.45
			if p.Name == "Head" then local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Head; m.Scale = Vector3.new(1.25, 1.25, 1.25); m.Parent = g end
			g.Parent = workspace
			tw(g, 0.45, { Transparency = 1, Size = g.Size * 1.15 })
			Debris:AddItem(g, 0.5)
		end
	end
end

local function avisoPequeno(texto: string, color: Color3, icono: string?)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0); f.Position = UDim2.new(0.5, 0, 0.1, 0); f.Size = UDim2.new()   -- debajo del objetivo de la ronda
	f.AutomaticSize = Enum.AutomaticSize.XY; f.BackgroundColor3 = TINTA; f.BackgroundTransparency = 0.25
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = f
	local st = Instance.new("UIStroke"); st.Color = color; st.Thickness = 2; st.Parent = f
	local l = Instance.new("UIListLayout"); l.FillDirection = Enum.FillDirection.Horizontal; l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 6); l.Parent = f
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 3); pad.PaddingBottom = UDim.new(0, 3); pad.Parent = f
	if icono then
		local i = Instance.new("ImageLabel"); i.Size = UDim2.fromOffset(28, 28); i.BackgroundTransparency = 1; i.Image = icono; i.Parent = f
	end
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromOffset(0, 28); t.AutomaticSize = Enum.AutomaticSize.X; t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne; t.TextSize = 20; t.TextColor3 = Color3.new(1, 1, 1); t.Text = texto; t.Parent = f
	-- los avisos se apilan hacia abajo
	for _, o in gui:GetChildren() do
		if o:GetAttribute("Aviso") then o.Position += UDim2.fromOffset(0, 40) end
	end
	f:SetAttribute("Aviso", true)
	f.Parent = gui
	task.delay(2.6, function()
		tw(f, 0.3, { BackgroundTransparency = 1 }); tw(t, 0.3, { TextTransparency = 1 }); tw(st, 0.3, { Transparency = 1 })
		Debris:AddItem(f, 0.35)
	end)
end

-- ================================================================== MARCADOR (motor común del combo y del PERFECT)
-- Texto hecho con glifos de un atlas (IMG.atlas, Sarpanch Bold en cursiva: zero-jugabilidad/combo/gen_atlas.py) porque
-- el texto de Roblox no se puede estirar solo en vertical. Cuatro capas: aberración roja y cian (detrás), principal
-- (con contorno; color o degradado de fuego) y brillo (franja que cruza todo el texto). Al golpear: cae desde arriba y
-- rebota en un suelo invisible (Y x1,15 -> aplasta -> vuelve), pop seco, ondas finas, chispas mínimas y brillo.
local GLIFO_ALTO = 140
local GLIFOS = { ["0"] = { 0, 0, 138 }, ["1"] = { 138, 0, 72 }, ["2"] = { 210, 0, 134 }, ["3"] = { 344, 0, 136 }, ["4"] = { 480, 0, 143 },
	["5"] = { 623, 0, 131 }, ["6"] = { 754, 0, 133 }, ["7"] = { 887, 0, 108 }, ["8"] = { 0, 140, 134 }, ["9"] = { 134, 140, 133 },
	["x"] = { 267, 140, 134 }, ["P"] = { 401, 140, 137 }, ["E"] = { 538, 140, 122 }, ["R"] = { 660, 140, 140 }, ["F"] = { 800, 140, 118 },
	["C"] = { 0, 280, 133 }, ["T"] = { 133, 280, 112 }, ["D"] = { 245, 280, 142 }, ["O"] = { 387, 280, 137 }, ["G"] = { 524, 280, 136 },
	["!"] = { 660, 280, 69 } }
local JUNTAR = 0.2            -- solape entre celdas (fracción del alto): la cursiva encaja una letra con la siguiente
local SARPANCH = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold)
local FUEGO_COLOR = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 120)), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 150, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 52, 30)) })
local BRILLO_T = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.2),
	NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) })
local DURA_BRILLO = 0.4

-- sonido afinado: semitonos sobre la nota de la muestra
local function sonarNota(def, semitonos: number, vol: number, cortar: number?)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. def[1]; s.Volume = def[2] * vol; s.PlaybackSpeed = def[3] * 2 ^ (semitonos / 12)
	if cortar then                                   -- muestras largas: se apagan solas
		s.Parent = gui; s:Play()
		task.delay(cortar, function() tw(s, 0.35, { Volume = 0 }) end)
		Debris:AddItem(s, cortar + 0.4)
	else
		SoundService:PlayLocalSound(s)
	end
end

local function crearMarcador(pos: UDim2)
	local m = { alfa = 1, kick = 0, brillo = -1, alto = 0, ancho = 0, serie = 0, fuego = false, cifras = {}, tweens = {} }
	local raiz = Instance.new("Frame")
	raiz.AnchorPoint = Vector2.new(0.5, 0.5); raiz.Position = pos; raiz.Size = UDim2.fromOffset(0, 0)
	raiz.BackgroundTransparency = 1; raiz.Visible = false; raiz.Parent = gui
	local numero = Instance.new("Frame")                 -- base en el suelo invisible: se estira hacia arriba
	numero.AnchorPoint = Vector2.new(0.5, 1); numero.BackgroundTransparency = 1; numero.Parent = raiz
	local esc = Instance.new("UIScale"); esc.Parent = numero
	local function capa(z: number): Frame
		local c = Instance.new("Frame"); c.Size = UDim2.fromScale(1, 1); c.BackgroundTransparency = 1; c.ZIndex = z; c.Parent = numero
		return c
	end
	-- detrás: aura y dos remolinos de energía que giran (centrados en el texto)
	local function fondo(img: string, z: number): ImageLabel
		local i = Instance.new("ImageLabel")
		i.AnchorPoint = Vector2.new(0.5, 0.5); i.BackgroundTransparency = 1; i.Image = img; i.ZIndex = z; i.Parent = raiz
		local e = Instance.new("UIScale"); e.Parent = i
		return i
	end
	m.sombra = fondo(IMG.aura, 0)                       -- sombra oscura difusa: da contraste en mapas claros y profundidad
	m.sombra.ImageColor3 = Color3.fromRGB(6, 10, 26)
	m.aura, m.remA, m.remB = fondo(IMG.aura, 0), fondo(IMG.remolino, 0), fondo(IMG.remolino, 0)
	m.giroA, m.giroB, m.empuje, m.flash, m.tinte = 0, 120, 0, 0, Color3.new(1, 1, 1)
	m.raiz, m.numero, m.esc = raiz, numero, esc
	-- extrusión (relieve 3D): copias oscuras desplazadas abajo a la derecha
	m.extrusion = { capa(1), capa(1), capa(1), capa(1) }
	m.cromaR, m.cromaC, m.principal, m.brilloC = capa(2), capa(2), capa(3), capa(4)
	-- etiqueta (título del combo / "DODGE")
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1; t.FontFace = SARPANCH; t.TextColor3 = Color3.new(1, 1, 1); t.Size = UDim2.fromOffset(700, 40)
	t.ZIndex = 6; t.Parent = raiz
	local tt = Instance.new("UIStroke"); tt.Thickness = 2.2; tt.Color = Color3.fromRGB(10, 14, 30); tt.Parent = t
	local te = Instance.new("UIScale"); te.Parent = t
	local tg = Instance.new("UIGradient"); tg.Rotation = 90; tg.Parent = t       -- título con degradado (blanco -> color)
	m.rotBase = 0
	m.titulo, m.tituloTrazo, m.tituloEscala = t, tt, te

	function m.montar(texto: string): number
		local total = 0
		for k = 1, #texto do total += GLIFOS[texto:sub(k, k)][3] - (if k > 1 then JUNTAR * GLIFO_ALTO else 0) end
		local capas = { m.cromaR, m.cromaC, m.principal, m.brilloC }
		for _, e in m.extrusion do table.insert(capas, e) end
		for _, c in capas do
			for _, h in c:GetChildren() do h:Destroy() end
			m.cifras[c] = {}
			local x = 0
			for k = 1, #texto do
				local g = GLIFOS[texto:sub(k, k)]
				if k > 1 then x -= JUNTAR * GLIFO_ALTO end
				local i = Instance.new("ImageLabel")
				i.BackgroundTransparency = 1; i.Image = IMG.atlas; i.ScaleType = Enum.ScaleType.Stretch; i.ZIndex = c.ZIndex
				local conContorno = c == m.principal or table.find(m.extrusion, c) ~= nil
				i.ImageRectOffset = Vector2.new(g[1], g[2] + (if conContorno then 0 else 512)); i.ImageRectSize = Vector2.new(g[3], GLIFO_ALTO)
				i.Position = UDim2.fromScale(x / total, 0); i.Size = UDim2.fromScale(g[3] / total, 1)
				local k = table.find(m.extrusion, c)
				i.ImageColor3 = if c == m.cromaR then Color3.fromRGB(255, 40, 70) elseif c == m.cromaC then Color3.fromRGB(40, 220, 255)
					elseif k then Color3.fromRGB(16, 22, 44):Lerp(Color3.fromRGB(4, 6, 14), k / #m.extrusion) else Color3.new(1, 1, 1)
				local grad: UIGradient? = nil
				if c == m.principal or c == m.brilloC then
					grad = Instance.new("UIGradient")
					if c == m.principal then grad.Rotation = 90; grad.Color = FUEGO_COLOR else grad.Rotation = 18; grad.Transparency = BRILLO_T end
					grad.Parent = i
				end
				i.Parent = c
				table.insert(m.cifras[c], { i = i, x0 = x / total, w = g[3] / total, g = grad })
				x += g[3]
			end
		end
		return total / GLIFO_ALTO
	end

	-- relleno metálico: claro arriba, el color en medio y oscuro abajo (o fuego); tinte = color del aura y los remolinos
	function m.color(c: Color3?, fuego: boolean, tinte: Color3?)
		m.fuego = fuego
		local base = c or Color3.new(1, 1, 1)
		local metal = if fuego then FUEGO_COLOR else ColorSequence.new({ ColorSequenceKeypoint.new(0, base:Lerp(Color3.new(1, 1, 1), 0.65)),
			ColorSequenceKeypoint.new(0.55, base), ColorSequenceKeypoint.new(1, base:Lerp(Color3.fromRGB(30, 40, 70), 0.45)) })
		for _, d in m.cifras[m.principal] or {} do
			d.i.ImageColor3 = Color3.new(1, 1, 1)
			if d.g then d.g.Color = metal end
		end
		m.tinte = tinte or base
		for _, i in { m.aura, m.remA, m.remB } do i.ImageColor3 = m.tinte:Lerp(Color3.new(1, 1, 1), 0.25) end
		tg.Color = ColorSequence.new(Color3.new(1, 1, 1), base:Lerp(m.tinte, 0.5))
	end

	local function animar(o: Instance, dura: number, props, estilo, dir)
		local x = tw(o, dura, props, estilo, dir); table.insert(m.tweens, x); return x
	end

	local function ondas()
		for k = 0, 1 do
			local o = Instance.new("Frame")
			o.AnchorPoint = Vector2.new(0.5, 0.5); o.Position = UDim2.fromOffset(0, m.alto / 2); o.Size = UDim2.fromOffset(m.ancho * 0.25, m.alto * 0.03)
			o.BackgroundTransparency = 1; o.Parent = raiz
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = o
			local st = Instance.new("UIStroke"); st.Color = Color3.new(1, 1, 1); st.Thickness = 1.2; st.Transparency = 0.5 + k * 0.15; st.Parent = o
			task.delay(k * 0.09, function()
				tw(o, 0.55, { Size = UDim2.fromOffset(m.ancho * (1.25 - k * 0.3), m.alto * (0.16 - k * 0.04)) }, Enum.EasingStyle.Quart)
				tw(st, 0.55, { Transparency = 1 })
			end)
			Debris:AddItem(o, 0.7)
		end
	end
	local function chispas()
		for _ = 1, 6 do
			local p = Instance.new("Frame")
			local s = math.random(2, 3)
			p.AnchorPoint = Vector2.new(0.5, 0.5); p.Size = UDim2.fromOffset(s, s); p.BorderSizePixel = 0; p.Rotation = 45
			p.BackgroundColor3 = Color3.new(1, 1, 1); p.BackgroundTransparency = 0.35
			local x = (math.random() - 0.5) * m.ancho
			p.Position = UDim2.fromOffset(x, -m.alto * (0.1 + math.random() * 0.35))
			p.Parent = raiz
			tw(p, 0.45, { Position = p.Position + UDim2.fromOffset(x * 0.25, -m.alto * (0.15 + math.random() * 0.25)), BackgroundTransparency = 1 })
			Debris:AddItem(p, 0.5)
		end
	end

	-- golpe: monta el texto, lo deja caer y rebotar; alto = alto de las letras en píxeles. Devuelve el ancho.
	function m.golpe(texto: string, alto: number): number
		for _, x in m.tweens do x:Cancel() end
		table.clear(m.tweens)
		m.serie += 1
		local serie = m.serie
		local ancho = m.montar(texto) * alto
		m.ancho, m.alto, m.alfa, m.kick = ancho, alto, 0, 1
		raiz.Visible = true
		local lado = math.max(ancho, alto * 1.4)
		m.sombra.Size = UDim2.fromOffset(lado * 2.6, lado * 2.1)
		m.aura.Size = UDim2.fromOffset(lado * 1.9, lado * 1.9)
		m.remA.Size = UDim2.fromOffset(lado * 2.2, lado * 1.65); m.remB.Size = UDim2.fromOffset(lado * 1.8, lado * 2)
		for _, e in m.extrusion do e.Visible = true end
		numero.Size = UDim2.fromOffset(ancho, alto * 1.15)                   -- cae estirado
		numero.Position = UDim2.fromOffset(0, alto / 2 - alto * 0.55)
		esc.Scale = 1
		animar(numero, 0.09, { Position = UDim2.fromOffset(0, alto / 2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.09, function()
			if m.serie ~= serie then return end
			numero.Size = UDim2.fromOffset(ancho * 1.03, alto * 0.9)           -- aplasta al tocar el suelo
			animar(numero, 0.22, { Size = UDim2.fromOffset(ancho, alto) }, Enum.EasingStyle.Back)
			esc.Scale = 1.12                                                -- pop seco
			animar(esc, 0.1, { Scale = 1 }, Enum.EasingStyle.Quad)
			ondas(); chispas()
			m.brillo = os.clock(); m.kick = 1.6
			m.empuje = 1; m.flash = 1                                       -- los remolinos aceleran y el aura destella
			for _, i in { m.remA, m.remB } do
				local e = i:FindFirstChildOfClass("UIScale") :: UIScale
				e.Scale = 0.72; animar(e, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
		return ancho
	end

	-- título con impacto (nuevo) o con un toque (el mismo)
	function m.etiqueta(texto: string, nuevo: boolean, girar: number)
		local serie = m.serie
		if nuevo then
			t.Text = texto; te.Scale = 1.45; t.Rotation = m.rotBase + girar
			m.flash = 1.4
			task.delay(0.09, function()
				if m.serie ~= serie then return end
				animar(te, 0.22, { Scale = 1 }, Enum.EasingStyle.Back); animar(t, 0.22, { Rotation = m.rotBase }, Enum.EasingStyle.Back)
			end)
		else
			te.Scale = 1.06; animar(te, 0.12, { Scale = 1 })
		end
	end

	-- fundido suave
	function m.fundir(dura: number)
		local serie = m.serie
		local t0 = os.clock()
		task.spawn(function()
			while m.serie == serie and os.clock() - t0 < dura do m.alfa = (os.clock() - t0) / dura; task.wait() end
			if m.serie == serie then m.alfa = 1; raiz.Visible = false end
		end)
	end

	-- cada fotograma: aberración (tension 0..1, ritmo 0..1), fuego, brillo y transparencias
	function m.pintar(dt: number, tension: number, ritmo: number)
		local ahora = os.clock()
		m.kick *= math.exp(-dt * 7)
		local px = m.alto / 90
		local dx = px * (0.7 + 0.5 * ritmo + 2.2 * tension + 2.5 * m.kick)
		local dy = if tension > 0.7 then px * (math.random() - 0.5) * 1.6 else 0
		m.cromaR.Position = UDim2.fromOffset(-dx, dy); m.cromaC.Position = UDim2.fromOffset(dx, -dy)
		local a = m.alfa
		local llama = math.sin(ahora * 9) * 0.06 + math.sin(ahora * 23) * 0.03
		for _, d in m.cifras[m.principal] or {} do
			d.i.ImageTransparency = a
			if m.fuego and d.g then d.g.Offset = Vector2.new(0, llama) end
		end
		local tb = if m.brillo > 0 then (ahora - m.brillo) / DURA_BRILLO else 2
		local banda = -0.25 + 1.5 * math.clamp(tb, 0, 1)
		for _, d in m.cifras[m.brilloC] or {} do
			d.i.ImageTransparency = if tb >= 1 then 1 else a
			if d.g and tb < 1 then d.g.Offset = Vector2.new((banda - d.x0) / d.w - 0.5, 0) end
		end
		-- fondo: los remolinos giran (más rápido tras cada golpe) y el aura late
		m.empuje *= math.exp(-dt * 3); m.flash *= math.exp(-dt * 5)
		m.giroA += dt * (22 + 260 * m.empuje); m.giroB -= dt * (16 + 200 * m.empuje)
		m.remA.Rotation = m.giroA; m.remB.Rotation = m.giroB
		local vis = 1 - a
		m.sombra.ImageTransparency = 1 - vis * 0.55
		m.remA.ImageTransparency = 1 - vis * math.clamp(0.85 + 0.15 * m.flash, 0, 1)
		m.remB.ImageTransparency = 1 - vis * math.clamp(0.6 + 0.3 * m.flash, 0, 1)
		m.aura.ImageTransparency = 1 - vis * math.clamp(0.22 + 0.08 * ritmo + 0.5 * m.flash, 0, 1)
		local px2 = m.alto / 70
		for k, e in m.extrusion do
			e.Position = UDim2.fromOffset(px2 * k, px2 * k * 1.2)
			for _, d in m.cifras[e] or {} do d.i.ImageTransparency = a end
		end
		local tc = 1 - (1 - (0.74 - 0.12 * tension)) * (1 - a)
		for _, c in { m.cromaR, m.cromaC } do
			for _, d in m.cifras[c] or {} do d.i.ImageTransparency = tc end
		end
		t.TextTransparency = a
		tt.Transparency = 0.3 + 0.7 * a
	end
	return m
end

local function altoPantalla(): number
	return (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y) or 720
end

-- ================================================================== ESQUIVA PERFECTA
-- tú -> "PERFECT" con "DODGE" debajo (mismo estilo que el combo), whoosh y dos notas que suben; los demás -> "PERFECT!"
local perfect = crearMarcador(UDim2.fromScale(0.5, 0.3))
local CIAN = Color3.fromRGB(150, 236, 255)

local function perfectDodge(char: Model)
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	fantasma(char, Color3.fromRGB(110, 230, 255))
	if char ~= player.Character then
		if hrp then sonar(SFX.nota, hrp, 0.5) end
		cartel3D(char, nil, "PERFECT!", Color3.fromRGB(120, 235, 255), 1.4)
		return
	end
	local H = altoPantalla()
	local alto = math.floor(H * 0.075)
	perfect.golpe("PERFECT", alto)
	perfect.color(CIAN, false)
	perfect.titulo.TextSize = math.floor(H * 0.03); perfect.titulo.TextColor3 = Color3.fromRGB(205, 245, 255)
	perfect.titulo.AnchorPoint = Vector2.new(0.5, 0); perfect.titulo.Position = UDim2.fromOffset(alto * 0.15, alto / 2 + H * 0.004)
	perfect.etiqueta("D O D G E", true, -3)
	golpeFOV(5)
	sonarNota(SFX.whoosh, 0, 1)
	task.delay(0.07, function() sonarNota(SFX.nota, 7, 1) end)               -- Sol
	task.delay(0.15, function() sonarNota(SFX.nota, 12, 1); sonarNota(SFX.acento, 0, 1, 0.5) end)   -- Do agudo + brillo
	local serie = perfect.serie
	task.delay(1.15, function() if perfect.serie == serie then perfect.fundir(0.35) end end)
end

-- ================================================================== COMBO (rachas del cazador)
-- "x12" con título de elogio encima y barra fina a la izquierda que se vacía de arriba abajo (verde -> rojo). Un poco
-- por encima del centro y a la derecha. Cada congelado: marimba que sube por la escala pentatónica + golpecito; al
-- cambiar de título, campana brillante una octava arriba. Si se acaba el tiempo, fundido suave.
local TITULOS = {   -- cambian en cada golpe hasta x10 y luego cada dos (en 25 jugadores el máximo es x24)
	{ 1, "BUEN GOLPE" }, { 2, "ESCALOFRÍO" }, { 3, "EN RACHA" }, { 4, "CAZADOR NATO" }, { 5, "TORMENTA HELADA" },
	{ 6, "IMPARABLE" }, { 7, "SIN PIEDAD" }, { 8, "VENTISCA" }, { 9, "ESCARCHA LETAL" }, { 10, "IMPLACABLE" },
	{ 12, "ERA DE HIELO" }, { 14, "LEYENDA DEL FRÍO" }, { 16, "DEPREDADOR ÁRTICO" }, { 18, "CERO ABSOLUTO" },
	{ 20, "INVIERNO ETERNO" }, { 22, "DIOS DEL HIELO" }, { 24, "¡CONGELACIÓN TOTAL!" },
}
local COLORES = {   -- blanco -> amarillo -> naranja; desde FUEGO, degradado de fuego que parpadea
	{ 1, Color3.fromRGB(255, 255, 255) }, { 3, Color3.fromRGB(255, 247, 200) }, { 5, Color3.fromRGB(255, 226, 105) },
	{ 8, Color3.fromRGB(255, 182, 58) }, { 11, Color3.fromRGB(255, 132, 38) },
}
local FUEGO = 14
-- sonido (referencia del usuario: Downloads/Frozen_Wands_Yaz_x1_a_x24_Separacion_1s.wav): un "tink" helado corto con un
-- golpe grave debajo que sube poco a poco en cada golpe (x1 2850 Hz -> x23 4580 Hz: ~1/3 de semitono por golpe) y un
-- remate distinto en x24
local SUBIDA = 4583 / 2850

local function tituloDe(n: number): string
	local t = TITULOS[1][2]
	for _, e in TITULOS do if n >= e[1] then t = e[2] end end
	return t
end
local function colorDe(n: number): Color3
	local prev = COLORES[1]
	for _, k in COLORES do
		if n <= k[1] then
			if k == prev then return k[2] end
			return prev[2]:Lerp(k[2], (n - prev[1]) / (k[1] - prev[1]))
		end
		prev = k
	end
	return prev[2]
end

local combo = crearMarcador(UDim2.fromScale(0.58, 0.295))   -- el título queda justo debajo del objetivo de la ronda
local estado = { n = 0, fin = 0, dura = 6, activo = false, titulo = "" }
local barra = Instance.new("Frame")
barra.AnchorPoint = Vector2.new(1, 0.5); barra.BackgroundColor3 = Color3.fromRGB(10, 14, 30); barra.BorderSizePixel = 0; barra.Parent = combo.raiz
local barraC = Instance.new("UICorner"); barraC.CornerRadius = UDim.new(1, 0); barraC.Parent = barra
local relleno = Instance.new("Frame")
relleno.AnchorPoint = Vector2.new(0, 1); relleno.Position = UDim2.fromScale(0, 1); relleno.Size = UDim2.fromScale(1, 1)
relleno.BorderSizePixel = 0; relleno.Parent = barra
local rellenoC = Instance.new("UICorner"); rellenoC.CornerRadius = UDim.new(1, 0); rellenoC.Parent = relleno

local function golpeCombo(n: number, dura: number)
	local H = altoPantalla()
	local alto = math.floor(H * 0.068)
	estado.n, estado.dura, estado.fin, estado.activo = n, dura, os.clock() + dura, true
	local ancho = combo.golpe("x" .. n, alto)
	local tinte = if n >= FUEGO then Color3.fromRGB(255, 150, 50) elseif n < 3 then Color3.fromRGB(150, 225, 255) else colorDe(n)
	combo.color(colorDe(n), n >= FUEGO, tinte)
	barra.Size = UDim2.fromOffset(math.max(4, math.floor(H * 0.006)), alto * 0.86)
	barra.Position = UDim2.fromOffset(-ancho / 2 - alto * 0.1, alto * 0.02)
	relleno.Size = UDim2.fromScale(1, 1)
	local t = combo.titulo
	-- título inclinado debajo, montado sobre la parte de abajo del número (como el rango del ejemplo)
	combo.rotBase = -6
	t.TextSize = math.floor(H * 0.032); t.AnchorPoint = Vector2.new(0.5, 0); t.Position = UDim2.fromOffset(ancho * 0.2, alto * 0.3)
	t.TextColor3 = if n >= FUEGO then Color3.fromRGB(255, 214, 120) else Color3.new(1, 1, 1):Lerp(colorDe(n), 0.55)
	local nuevo = tituloDe(n)
	local cambia = nuevo ~= estado.titulo
	estado.titulo = nuevo
	combo.etiqueta(nuevo, cambia, if n % 2 == 0 then 3 else -3)
	-- sonido: el tink del usuario sube un poco en cada golpe; en x24 (todos congelados) su remate
	if n >= 24 then
		sonarNota(SFX.final, 0, 1)
	else
		sonarNota(SFX.tink, 12 * math.log(SUBIDA ^ ((n - 1) / 22), 2), 1)   -- el tink ya trae su golpe grave
	end
end

RunService.RenderStepped:Connect(function(dt)
	if perfect.raiz.Visible then perfect.pintar(dt, 0, 0.5 + 0.5 * math.sin(os.clock() * 6)) end
	if not combo.raiz.Visible then return end
	local ahora = os.clock()
	local frac = math.clamp((estado.fin - ahora) / estado.dura, 0, 1)
	if estado.activo and frac <= 0 then
		estado.activo = false; estado.titulo = ""; estado.n = 0
		combo.fundir(0.5)
	end
	relleno.Size = UDim2.fromScale(1, frac)
	relleno.BackgroundColor3 = if frac > 0.5 then Color3.fromRGB(255, 220, 60):Lerp(Color3.fromRGB(70, 230, 110), (frac - 0.5) * 2)
		else Color3.fromRGB(255, 60, 50):Lerp(Color3.fromRGB(255, 220, 60), frac * 2)
	barra.BackgroundTransparency = 1 - 0.55 * (1 - combo.alfa)
	relleno.BackgroundTransparency = combo.alfa
	local ritmo = 0.5 + 0.5 * math.sin(ahora * (5 + math.min(estado.n, 24) * 0.35))
	combo.pintar(dt, (1 - frac) ^ 1.5, ritmo)
end)

local function racha(n: number, cazador: Model, dura: number?)
	if cazador == player.Character then
		golpeCombo(n, dura or 6)
	elseif n >= 3 and tituloDe(n) ~= tituloDe(n - 1) and cerca(cazador) then   -- los demás (si están cerca): aviso pequeño al subir de título
		local nombre = cazador:GetAttribute("IsBot") and (cazador.Name:gsub(" %[BOT%]", "")) or cazador.Name
		avisoPequeno(nombre .. "  ·  x" .. n .. "  " .. tituloDe(n), colorDe(math.min(n, 13)))
	end
end

-- ================================================================== POWER-UPS
local visuales: { [Model]: any } = {}
local function esCorredor(): boolean return player:GetAttribute("Role") == "Runner" end

local function montarPowerUp(m: Model)
	local base = m:WaitForChild("Base", 5) :: BasePart?
	local tipo = m:GetAttribute("Tipo")
	local info = POWER[tipo]
	if not base or not info or visuales[m] then return end
	local carpeta = Instance.new("Folder"); carpeta.Name = "Visual"; carpeta.Parent = m
	local orbe = Instance.new("Part")
	orbe.Shape = Enum.PartType.Ball; orbe.Size = Vector3.new(2.6, 2.6, 2.6); orbe.Material = Enum.Material.Neon; orbe.Color = info.color
	orbe.Transparency = 0.35; orbe.Anchored = true; orbe.CanCollide = false; orbe.CanQuery = false; orbe.CastShadow = false; orbe.Parent = carpeta
	local aro = Instance.new("Part")
	aro.Shape = Enum.PartType.Cylinder; aro.Size = Vector3.new(0.25, 4.4, 4.4); aro.Material = Enum.Material.Neon; aro.Color = Color3.new(1, 1, 1)
	aro.Transparency = 0.3; aro.Anchored = true; aro.CanCollide = false; aro.CanQuery = false; aro.CastShadow = false; aro.Parent = carpeta
	local luz = Instance.new("PointLight"); luz.Color = info.color; luz.Range = 14; luz.Brightness = 2.5; luz.Parent = orbe
	local icono = Instance.new("BillboardGui")
	icono.Size = UDim2.fromScale(3.4, 3.4); icono.LightInfluence = 0; icono.MaxDistance = 220; icono.Adornee = orbe
	local ii = Instance.new("ImageLabel"); ii.Size = UDim2.fromScale(1, 1); ii.BackgroundTransparency = 1; ii.Image = IMG[tipo]; ii.Parent = icono
	icono.Parent = carpeta
	local brillo = Instance.new("ParticleEmitter")
	brillo.Texture = "rbxasset://textures/particles/sparkles_main.dds"; brillo.Color = ColorSequence.new(info.color, Color3.new(1, 1, 1))
	brillo.Rate = 12; brillo.Lifetime = NumberRange.new(0.6, 1.1); brillo.Speed = NumberRange.new(1, 3); brillo.SpreadAngle = Vector2.new(180, 180)
	brillo.Size = NumberSequence.new(0.5, 0); brillo.LightEmission = 1; brillo.Parent = orbe
	-- columna de luz: se ve desde lejos
	local a0 = Instance.new("Attachment"); a0.WorldPosition = base.Position - Vector3.new(0, 2.8, 0); a0.Parent = workspace.Terrain
	local a1 = Instance.new("Attachment"); a1.WorldPosition = base.Position + Vector3.new(0, 45, 0); a1.Parent = workspace.Terrain
	local columna = Instance.new("Beam")
	columna.Attachment0 = a0; columna.Attachment1 = a1; columna.Width0 = 2.2; columna.Width1 = 0.4; columna.FaceCamera = true
	columna.LightEmission = 1; columna.Color = ColorSequence.new(info.color)
	columna.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	columna.Parent = a0
	-- marcador (solo corredores): icono + distancia, se ve a través de las paredes
	local marca = Instance.new("BillboardGui")
	marca.Size = UDim2.fromOffset(56, 70); marca.AlwaysOnTop = true; marca.LightInfluence = 0; marca.Adornee = base
	marca.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	local mi = Instance.new("ImageLabel"); mi.Size = UDim2.fromOffset(56, 56); mi.BackgroundTransparency = 1; mi.Image = IMG[tipo]; mi.Parent = marca
	local md = Instance.new("TextLabel"); md.Position = UDim2.fromOffset(0, 54); md.Size = UDim2.fromOffset(56, 16); md.BackgroundTransparency = 1
	md.Font = Enum.Font.FredokaOne; md.TextSize = 14; md.TextColor3 = Color3.new(1, 1, 1); md.Parent = marca
	local ms = Instance.new("UIStroke"); ms.Thickness = 2; ms.Color = TINTA; ms.Parent = md
	marca.Parent = gui
	local t0 = os.clock()
	local con = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local c = base.CFrame * CFrame.new(0, math.sin(t * 2.2) * 0.5, 0)
		orbe.CFrame = c
		aro.CFrame = c * CFrame.Angles(0, t * 2, 0) * CFrame.Angles(0.5 + math.sin(t) * 0.2, 0, math.rad(90))
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		marca.Enabled = esCorredor()
		if hrp then md.Text = math.floor((hrp.Position - base.Position).Magnitude / 3.57 + 0.5) .. " m" end
	end)
	visuales[m] = { con = con, marca = marca, a0 = a0, a1 = a1 }
	m.Destroying:Connect(function()
		local v = visuales[m]
		if not v then return end
		visuales[m] = nil
		v.con:Disconnect(); v.marca:Destroy(); v.a0:Destroy(); v.a1:Destroy()
	end)
end

task.spawn(function()
	local carpeta = workspace:WaitForChild("ZeroPowerUps")
	for _, m in carpeta:GetChildren() do task.spawn(montarPowerUp, m) end
	carpeta.ChildAdded:Connect(function(m) if m:IsA("Model") then task.spawn(montarPowerUp, m) end end)
end)

-- efectos activos (encima de las recargas del dash): icono + lo que le queda
local fila = Instance.new("Frame")
fila.AnchorPoint = Vector2.new(0.5, 1); fila.Position = UDim2.new(0.5, 0, 1, -92); fila.Size = UDim2.fromOffset(0, 48)
fila.AutomaticSize = Enum.AutomaticSize.X; fila.BackgroundTransparency = 1; fila.Parent = gui
local filaL = Instance.new("UIListLayout"); filaL.FillDirection = Enum.FillDirection.Horizontal; filaL.Padding = UDim.new(0, 8)
filaL.HorizontalAlignment = Enum.HorizontalAlignment.Center; filaL.Parent = fila
local chips: { [string]: any } = {}
local function chip(tipo: string)
	local fin = player:GetAttribute("ZeroPowerFin_" .. tipo)
	local c = chips[tipo]
	if type(fin) ~= "number" then
		if c then c.f:Destroy(); chips[tipo] = nil end
		return
	end
	if not c then
		local f = Instance.new("Frame"); f.Size = UDim2.fromOffset(48, 48); f.BackgroundColor3 = TINTA; f.BackgroundTransparency = 0.2
		local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 10); cc.Parent = f
		local st = Instance.new("UIStroke"); st.Color = POWER[tipo].color; st.Thickness = 2; st.Parent = f
		local i = Instance.new("ImageLabel"); i.Size = UDim2.new(1, -8, 1, -8); i.Position = UDim2.fromOffset(4, 4); i.BackgroundTransparency = 1
		i.Image = IMG[tipo]; i.Parent = f
		local barra = Instance.new("Frame"); barra.AnchorPoint = Vector2.new(0, 1); barra.Position = UDim2.new(0, 4, 1, -3)
		barra.Size = UDim2.new(1, -8, 0, 4); barra.BackgroundColor3 = POWER[tipo].color; barra.BorderSizePixel = 0; barra.Parent = f
		f.Parent = fila
		c = { f = f, barra = barra, total = fin - workspace:GetServerTimeNow() }
		chips[tipo] = c
	end
	c.fin = fin
	c.total = math.max(c.total, fin - workspace:GetServerTimeNow())
end
for tipo in POWER do
	player:GetAttributeChangedSignal("ZeroPowerFin_" .. tipo):Connect(function() if chips[tipo] then chips[tipo].total = 0 end; chip(tipo) end)
	chip(tipo)
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
	if ReplicatedStorage:GetAttribute("RoundState") == "ROUND_ACTIVE" then return end
	for tipo, c in chips do c.f:Destroy(); chips[tipo] = nil end
end)
RunService.Heartbeat:Connect(function()
	for _, c in chips do
		local resto = math.max(0, c.fin - workspace:GetServerTimeNow())
		c.barra.Size = UDim2.new(math.clamp(resto / math.max(c.total, 0.1), 0, 1), -8, 0, 4)
	end
end)

-- burbuja del escudo (cualquiera que lo lleve)
local burbujas: { [Model]: BasePart } = {}
RunService.RenderStepped:Connect(function()
	local vistos = {}
	local function ver(char: Model?)
		if not char or not char:GetAttribute("ZeroEscudo") then return end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then return end
		vistos[char] = true
		local b = burbujas[char]
		if not b then
			b = Instance.new("Part")
			b.Shape = Enum.PartType.Ball; b.Size = Vector3.new(7, 7, 7); b.Material = Enum.Material.ForceField; b.Color = POWER.Escudo.color
			b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.CastShadow = false; b.Parent = workspace
			burbujas[char] = b
		end
		b.CFrame = hrp.CFrame
	end
	for _, p in Players:GetPlayers() do ver(p.Character) end
	local bots = workspace:FindFirstChild("ZeroBots")
	if bots then for _, c in bots:GetChildren() do if c:IsA("Model") then ver(c) end end end
	for char, b in burbujas do if not vistos[char] then b:Destroy(); burbujas[char] = nil end end
end)

local function powerUp(d)
	local info = POWER[d.tipo]
	if not info then return end
	sonar(SFX.sale, nil, 0.7)
	avisoPequeno("¡" .. info.nombre .. " apareció!" .. (if esCorredor() then "  Sigue el marcador" else ""), info.color, IMG[d.tipo])
end

local function recogido(d)
	local info = POWER[d.tipo]
	local char = d.personaje :: Model?
	if not info or not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if char == player.Character then
		sonar(SFX.coge)
		local i = Instance.new("ImageLabel")
		i.AnchorPoint = Vector2.new(0.5, 0.5); i.Position = UDim2.fromScale(0.5, 0.3); i.Size = UDim2.fromScale(0.1, 0.1)
		i.BackgroundTransparency = 1; i.Image = IMG[d.tipo]
		local r = Instance.new("UIAspectRatioConstraint"); r.Parent = i
		local esc = Instance.new("UIScale"); esc.Scale = 0.3; esc.Parent = i
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 0); t.Position = UDim2.fromScale(0.5, 1.02); t.Size = UDim2.fromScale(4, 0.42); t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne; t.TextScaled = true; t.RichText = true; t.TextColor3 = info.color
		t.Text = info.nombre .. '\n<font color="#ffffff" size="14">' .. info.texto .. "</font>"
		local s = Instance.new("UIStroke"); s.Thickness = 3; s.Color = TINTA; s.Parent = t
		t.Parent = i
		i.Parent = gui
		tw(esc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		estallido(UDim2.fromScale(0.5, 0.3), info.color, 10, 180)
		task.delay(1.4, function()
			tw(i, 0.3, { ImageTransparency = 1, Position = UDim2.fromScale(0.5, 0.27) }); tw(t, 0.3, { TextTransparency = 1 }); tw(s, 0.3, { Transparency = 1 })
			Debris:AddItem(i, 0.35)
		end)
	else
		if hrp then sonar(SFX.coge, hrp, 0.5) end
		if esCorredor() and cerca(char) then
			local nombre = char:GetAttribute("IsBot") and (char.Name:gsub(" %[BOT%]", "")) or char.Name
			avisoPequeno(nombre .. " cogió " .. info.nombre, info.color, IMG[d.tipo])
		end
	end
end

local function escudoRoto(char: Model)
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	sonar(SFX.escudo, hrp)
	for k = 1, 14 do
		local e = Instance.new("Part")
		e.Size = Vector3.new(0.6, 0.6, 0.15) * (0.6 + math.random()); e.Material = Enum.Material.Glass; e.Color = POWER.Escudo.color
		e.Transparency = 0.2; e.CanCollide = false; e.CanQuery = false; e.CastShadow = false
		e.CFrame = hrp.CFrame * CFrame.new(math.random(-3, 3), math.random(-2, 3), math.random(-3, 3))
		e.AssemblyLinearVelocity = (e.Position - hrp.Position).Unit * (14 + math.random() * 10) + Vector3.new(0, 10, 0)
		e.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		e.Parent = workspace
		tw(e, 0.9, { Transparency = 1 }); Debris:AddItem(e, 1)
	end
	if char == player.Character then
		sacudir(1.2, 0.25)
		avisoPequeno("¡Tu ESCUDO te salvó!", POWER.Escudo.color, IMG.Escudo)
	else
		cartel3D(char, nil, "¡ESCUDO!", POWER.Escudo.color, 1.2)
	end
end

remote.OnClientEvent:Connect(function(d)
	if type(d) ~= "table" then return end
	if d.kind == "PerfectDodge" and d.personaje then perfectDodge(d.personaje)
	elseif d.kind == "Racha" and d.cazador then racha(d.n, d.cazador, d.dura)
	elseif d.kind == "PowerUp" then powerUp(d)
	elseif d.kind == "PowerUpRecogido" then recogido(d)
	elseif d.kind == "EscudoRoto" and d.personaje then escudoRoto(d.personaje) end
end)
