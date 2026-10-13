-- ZeroUIExtrasClient (LocalScript, StarterPlayerScripts): retoques de ZeroUI en tiempo de ejecución (zero-todo):
--   3.2 los paneles con scroll dejan sitio a su barra (VerticalScrollBarInset): nada queda cortado por la derecha
--   3.4 REGALA UN PASE: botón "◀ VOLVER" que regresa a la Tienda (la X también vuelve, ZeroUIClient)
--   4.1 el aviso (Toast) va por encima de los menús: el premio de la ruleta salía detrás del disco
--   5.2 los paneles capturan el clic: pulsar dentro de un menú ya no lo cierra (el clic caía al fondo Shade)
--   6.3 barra de espectador con el estilo de ZeroUI (bordes redondeados, FredokaOne, color del rol)
--   6.5 los menús entran con un pequeño salto (escala + giro, EasingStyle.Back); Misiones también
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local gui = pg:WaitForChild("ZeroUI")
gui:WaitForChild("UIAction")
local UI = require(ReplicatedStorage:WaitForChild("ZeroUI"))
local C = UI.Colors
local modal = gui:WaitForChild("Modal")
local hud = gui:WaitForChild("HUD")

local function new(class, parent, props)
	local n = Instance.new(class)
	for k, v in props or {} do (n :: any)[k] = v end
	n.Parent = parent
	return n
end
local function tw(o, t, props, estilo, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, estilo or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end
local function reducido(): boolean return gui:GetAttribute("ReducedMotion") == true end

-- ------------------------------------------------------------------ 4.1 aviso por encima de todo
local toast = gui:FindFirstChild("Toast")
if toast and toast:IsA("GuiObject") then toast.ZIndex = 20 end

-- ------------------------------------------------------------------ 3.2 + 5.2 paneles
local function prepararPanel(p: Instance)
	if not p:IsA("Frame") or p.Name:sub(-7) == "_Shadow" then return end
	p.Active = true                                          -- el clic se queda en el panel (no llega al Shade)
	local body = p:FindFirstChild("Body")
	if body and body:IsA("ScrollingFrame") and p.Name ~= "Wheel" and not body:GetAttribute("ZeroInset") then
		body:SetAttribute("ZeroInset", true)
		body.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
		body.ScrollBarThickness = 6
		body.Position = UDim2.fromOffset(body.Position.X.Offset - 6, body.Position.Y.Offset)
		body.Size = UDim2.fromOffset(body.Size.X.Offset + 14, body.Size.Y.Offset)   -- 880 + 14 - 6 de barra = 888 útiles
	end
end
for _, p in modal:GetChildren() do prepararPanel(p) end
modal.ChildAdded:Connect(prepararPanel)

-- ------------------------------------------------------------------ 3.4 VOLVER en Regalar
task.spawn(function()
	local gift = modal:WaitForChild("Gift", 30)
	local header = gift and gift:WaitForChild("Header", 10)
	local cerrar = header and header:FindFirstChild("Close")
	if not cerrar or header:FindFirstChild("Volver") then return end
	local v = cerrar:Clone()
	v.Name = "Volver"
	v.Size = UDim2.fromOffset(150, cerrar.Size.Y.Offset)
	v.Position = UDim2.fromOffset(cerrar.Position.X.Offset - 162, cerrar.Position.Y.Offset)
	v.BackgroundColor3 = C.blue
	v:SetAttribute("BaseColor", C.blue)
	v.Text = "◀ VOLVER"; v.TextSize = 24
	local bt = v:FindFirstChild("ButtonText"); if bt then bt.Text = "◀ VOLVER"; bt.TextSize = 24 end
	local sf = v:FindFirstChild("Surface")
	local g = sf and sf:FindFirstChildOfClass("UIGradient")
	if g then g.Color = ColorSequence.new(C.blue:Lerp(C.white, .22), C.blue:Lerp(C.ink, .12)) end
	v.Parent = header
	v.Activated:Connect(function() gui.UIAction:Invoke("Open", "Shop") end)
end)

-- ------------------------------------------------------------------ 6.5 entrada de los menús
local function entrar(panel: GuiObject?, sombra: GuiObject?)
	if not panel or reducido() then return end
	for _, o in { panel, sombra } do
		if o then
			local s = o:FindFirstChild("ZeroPop") or new("UIScale", o, { Name = "ZeroPop" })
			s.Scale = 0.86; o.Rotation = -3
			tw(s, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
			tw(o, 0.3, { Rotation = 0 })
		end
	end
end
gui:GetAttributeChangedSignal("CurrentMenu"):Connect(function()
	local nombre = gui:GetAttribute("CurrentMenu")
	if type(nombre) ~= "string" or nombre == "" then return end
	local p = modal:FindFirstChild(nombre)
	if p then prepararPanel(p) end
	entrar(p, modal:FindFirstChild(nombre .. "_Shadow"))
end)
task.spawn(function()                                       -- Misiones (su propio ScreenGui)
	local mis = pg:WaitForChild("ZeroMisionesUI", 60)
	local panel = mis and mis:WaitForChild("Panel", 10)
	if not panel then return end
	mis:GetAttributeChangedSignal("Open"):Connect(function() if mis:GetAttribute("Open") then entrar(panel, nil) end end)
end)

-- ------------------------------------------------------------------ 6.3 barra de espectador
task.spawn(function()
	local bar = hud:WaitForChild("SpectateBar", 30)
	if not bar then return end
	bar.BackgroundColor3 = C.panel; bar.BackgroundTransparency = 0.05; bar.BorderSizePixel = 0
	for _, c in bar:GetChildren() do if c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient") then c:Destroy() end end
	new("UICorner", bar, { CornerRadius = UDim.new(0, 18) })
	new("UIStroke", bar, { Color = C.ink, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	new("UIGradient", bar, { Rotation = 90, Color = ColorSequence.new(C.panel:Lerp(C.white, .08), C.panel:Lerp(C.ink, .35)) })
	local function estiloBoton(b: GuiObject?, color: Color3, texto: string?)
		if not b then return end
		b.BackgroundColor3 = color; b.BackgroundTransparency = 0; b.BorderSizePixel = 0
		for _, c in b:GetChildren() do if c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient") then c:Destroy() end end
		new("UICorner", b, { CornerRadius = UDim.new(0, 12) })
		new("UIStroke", b, { Color = C.ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		-- sin UIGradient: en un TextButton también tiñe el texto y lo apagaba
		if b:IsA("TextButton") then
			b.Font = Enum.Font.FredokaOne; b.TextColor3 = C.white; b.TextStrokeColor3 = C.ink; b.TextStrokeTransparency = 0.3
			if texto then b.Text = texto end
			local bt = b:FindFirstChild("ButtonText")
			if bt and bt:IsA("TextLabel") then bt.Font = Enum.Font.FredokaOne; if texto then bt.Text = texto end end
		end
	end
	estiloBoton(bar:FindFirstChild("Prev") :: GuiObject?, C.blue, "◀")
	estiloBoton(bar:FindFirstChild("Next") :: GuiObject?, C.blue, "▶")
	estiloBoton(bar:FindFirstChild("Exit") :: GuiObject?, C.pink, "SALIR")
	local objetivo = bar:FindFirstChild("Target") :: TextLabel?
	local pista = bar:FindFirstChild("Hint") :: TextLabel?
	for _, l in { objetivo, pista } do
		if l then
			l.Font = Enum.Font.FredokaOne; l.TextColor3 = C.white
			if not l:FindFirstChildOfClass("UIStroke") then new("UIStroke", l, { Color = C.ink, Thickness = 2 }) end
		end
	end
	-- "ESPECTANDO" encima y el rol del que miras con su color
	new("TextLabel", bar, { Name = "Titulo", Text = "👁  ESPECTANDO", Font = Enum.Font.FredokaOne, TextSize = 16, TextColor3 = C.white,
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(200, 20) })
	if pista then
		pista:GetPropertyChangedSignal("Text"):Connect(function()
			local t = pista.Text
			pista.TextColor3 = if t == "CONGELADO" then Color3.fromRGB(120, 220, 255) elseif t == "CAZADOR" then C.pink else C.green
		end)
	end
end)
