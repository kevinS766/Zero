-- ZeroTitulosEstilo (ModuleScript, ReplicatedStorage): dibuja un título de ZeroTitulosConfig como una placa con su
-- estilo (degradados de texto y fondo, textura, borde, icono, fuente) y lo anima en el cliente: barrido de luz,
-- borde que respira, fuego, sombra, arcoíris, aurora y destellos. Lo usan el menú TÍTULOS y la placa sobre la cabeza.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("ZeroTitulosConfig"))
local UI = require(ReplicatedStorage:WaitForChild("ZeroUI"))

local Estilo = {}
local vivos = setmetatable({}, { __mode = "k" })     -- placa -> datos de su animación

local function new(class, parent, props)
	local n = Instance.new(class)
	for k, v in props or {} do n[k] = v end
	n.Parent = parent
	return n
end
local function seq(a: Color3, b: Color3) return ColorSequence.new(a, b) end
local function arcoiris(t: number, sat: number?)
	local k = {}
	for i = 0, 6 do k[i + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((t + i / 6) % 1, sat or 0.75, 1)) end
	return ColorSequence.new(k)
end

-- Placa del título. opts: Size, Position, AnchorPoint, ZIndex, sinDestellos. Devuelve el contenedor (Frame).
function Estilo.placa(parent: Instance, def, opts)
	opts = opts or {}
	local e = def.estilo
	local cont = new("Frame", nil, { Name = "Titulo_" .. def.nombre, BackgroundTransparency = 1, Size = opts.Size or UDim2.fromOffset(240, 48),
		Position = opts.Position or UDim2.new(), AnchorPoint = opts.AnchorPoint or Vector2.zero, ZIndex = opts.ZIndex or 1 })
	local z = cont.ZIndex
	local placa = new("Frame", cont, { Name = "Placa", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ClipsDescendants = true, ZIndex = z })
	new("UICorner", placa, { CornerRadius = UDim.new(0.3, 0) })
	local fondo = new("UIGradient", placa, { Rotation = 90, Color = seq(e.placa[1], e.placa[2]) })
	local borde = new("UIStroke", placa, { Color = e.borde, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local textura = new("ImageLabel", placa, { Name = "Textura", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z,
		Image = "rbxassetid://" .. UI.StudTexture, ImageTransparency = 0.82, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(26, 26) })
	new("UICorner", textura, { CornerRadius = UDim.new(0.3, 0) })
	-- reflejo fijo arriba (cristal) y barrido de luz animado
	local reflejo = new("Frame", placa, { Name = "Reflejo", Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = z })
	new("UICorner", reflejo, { CornerRadius = UDim.new(0.5, 0) })
	new("UIGradient", reflejo, { Rotation = 90, Transparency = NumberSequence.new(0.2, 1) })
	local barrido
	if e.anim == "brillo" or def.rareza == "Mitico" or def.rareza == "Exclusivo" then
		barrido = new("Frame", placa, { Name = "Barrido", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = z + 1 })
		barrido = new("UIGradient", barrido, { Rotation = 18, Offset = Vector2.new(-1.5, 0), Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }) })
	end
	-- icono + nombre
	local icono = e.icono and UI.Icons[e.icono]
	if icono then
		new("ImageLabel", placa, { Name = "Icono", Image = "rbxassetid://" .. icono, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.new(0.8, 0, 0.8, 0), ZIndex = z + 2,
			SizeConstraint = Enum.SizeConstraint.RelativeYY })
	end
	local nombre = new("TextLabel", placa, { Name = "Nombre", Text = def.nombre, BackgroundTransparency = 1, TextScaled = true,
		Font = Config.fuente(e.fuente), TextColor3 = Color3.new(1, 1, 1), ZIndex = z + 2,
		Position = icono and UDim2.new(0.12, 6, 0.12, 0) or UDim2.fromScale(0.06, 0.12), Size = icono and UDim2.new(0.84, -8, 0.76, 0) or UDim2.fromScale(0.88, 0.76) })
	local colTexto = new("UIGradient", nombre, { Rotation = 90, Color = seq(e.texto[1], e.texto[2]) })
	new("UIStroke", nombre, { Color = e.placa[2]:Lerp(Color3.new(0, 0, 0), 0.55), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	-- destellos alrededor (fuera de la placa, que recorta)
	local estrellas = {}
	if e.destellos and not opts.sinDestellos then
		for i, p in { { 0.02, 0.05, 0.42 }, { 0.97, 0.15, 0.32 }, { 0.82, 0.98, 0.36 }, { 0.2, 1.0, 0.28 } } do
			local s = new("TextLabel", cont, { Name = "Destello" .. i, Text = "✦", BackgroundTransparency = 1, TextScaled = true,
				TextColor3 = e.destellos, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(p[1], p[2]),
				Size = UDim2.fromScale(p[3], p[3]), SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = z + 3, TextTransparency = 1 })
			table.insert(estrellas, { s, i * 1.7 })
		end
	end
	vivos[cont] = { def = def, fondo = fondo, borde = borde, texto = colTexto, nombre = nombre, barrido = barrido, estrellas = estrellas,
		fase = math.random() * 10 }
	cont.Parent = parent
	return cont
end

-- ------------------------------------------------------------------ animación (un solo bucle para todas las placas)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for cont, a in vivos do
		if not cont.Parent then continue end
		if not cont.Visible then continue end
		local e, tt = a.def.estilo, t + a.fase
		if a.barrido then                               -- barrido de luz cada 3 s
			local k = (tt % 3) / 1.3
			a.barrido.Offset = Vector2.new(k <= 1 and (-1.5 + 3 * k) or 1.5, 0)
		end
		if e.anim == "pulso" then
			local s = 0.5 + 0.5 * math.sin(tt * 3)
			a.borde.Thickness = 2 + 1.6 * s; a.borde.Transparency = 0.35 * (1 - s)
		elseif e.anim == "fuego" then
			a.fondo.Offset = Vector2.new(0, 0.18 * math.sin(tt * 4.2) + 0.06 * math.sin(tt * 11))
			a.texto.Offset = Vector2.new(0, 0.12 * math.sin(tt * 5.1))
			a.borde.Color = e.borde:Lerp(Color3.fromRGB(255, 240, 120), 0.5 + 0.5 * math.sin(tt * 7))
		elseif e.anim == "sombra" then
			a.fondo.Offset = Vector2.new(0, 0.25 * math.sin(tt * 1.3))
			a.texto.Rotation = 90 + 25 * math.sin(tt * 0.9)
			a.borde.Transparency = 0.25 + 0.25 * math.sin(tt * 2.3)
		elseif e.anim == "arcoiris" then
			a.texto.Color = arcoiris(tt * 0.25, 0.55)
			a.texto.Rotation = 0
			a.borde.Color = Color3.fromHSV((tt * 0.25) % 1, 0.6, 1)
		elseif e.anim == "aurora" then
			local k = 0.5 + 0.5 * math.sin(tt * 1.4)
			local c1 = Color3.fromRGB(110, 255, 225):Lerp(Color3.fromRGB(255, 120, 230), k)
			local c2 = Color3.fromRGB(150, 120, 255):Lerp(Color3.fromRGB(110, 255, 225), k)
			a.texto.Color = seq(c1, c2); a.borde.Color = c1
		end
		for _, s in a.estrellas do                     -- destellos: parpadeo con giro
			local v = math.max(0, math.sin(tt * 2.2 + s[2])) ^ 3
			s[1].TextTransparency = 1 - v; s[1].Rotation = (tt * 90 + s[2] * 40) % 360
		end
	end
end)

return Estilo
