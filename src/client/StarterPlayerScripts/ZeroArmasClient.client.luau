-- ZeroArmasClient (LocalScript, StarterPlayerScripts): botón ARMAS, tienda de cajas, inventario y animación de apertura.
-- Toda la lógica de premios está en el servidor (ZeroWheelServer + ZeroArmasRules); aquí solo se pide y se enseña.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local SocialService = game:GetService("SocialService")
local Monet = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Passes = table.clone(Monet.Passes)                       -- + armas exclusivas vendidas como pase (ORIGAMI…)
for k, v in Monet.Exclusivos or {} do Passes[k] = v end
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("ZeroArmasConfig"))
local UIRemote = ReplicatedStorage:WaitForChild("ZeroUIRequest") :: RemoteFunction
local Resultado = ReplicatedStorage:WaitForChild("ZeroArmasResultado") :: RemoteEvent
local UI = require(ReplicatedStorage:WaitForChild("ZeroUI"))
local C = UI.Colors
local STUD = "rbxassetid://" .. UI.StudTexture

-- ------------------------------------------------------------------ helpers de estilo (mismo look que ZeroUI)
local function new(class, parent, props)
	local n = Instance.new(class)
	for k, v in props or {} do n[k] = v end
	n.Parent = parent
	return n
end
local function box(parent, name, pos, size, color, radius)
	local f = new("Frame", parent, { Name = name, Position = pos, Size = size, BackgroundColor3 = color or C.panel, BorderSizePixel = 0 })
	new("UICorner", f, { CornerRadius = UDim.new(0, radius or 14) })
	return f
end
local function stroke(n, color, w) return new("UIStroke", n, { Color = color or C.ink, Thickness = w or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function studs(n, t)
	new("ImageLabel", n, { Name = "Studs", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = STUD, ImageTransparency = t or .85,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(40, 40), ZIndex = n.ZIndex })
end
local function text(parent, name, str, pos, size, ts, color)
	local l = new("TextLabel", parent, { Name = name, Text = str, Position = pos, Size = size, BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
		TextSize = ts or 22, TextColor3 = color or C.white, TextWrapped = true })
	new("UIStroke", l, { Color = C.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	return l
end
local function btn(parent, name, str, pos, size, color, ts)
	local shadow = new("Frame", parent, { Name = name .. "_Shadow", Position = pos + UDim2.fromOffset(0, 4), Size = size, BackgroundColor3 = C.ink, BorderSizePixel = 0, ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) })
	new("UICorner", shadow, { CornerRadius = UDim.new(0, 12) }); shadow.BackgroundTransparency = 0.2
	local b = new("TextButton", parent, { Name = name, Text = "", Position = pos, Size = size, BackgroundColor3 = color, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = shadow.ZIndex + 1 })
	new("UICorner", b, { CornerRadius = UDim.new(0, 12) }); stroke(b)
	new("UIGradient", b, { Rotation = 90, Color = ColorSequence.new(color:Lerp(C.white, .25), color:Lerp(C.ink, .15)) })
	b.ClipsDescendants = true; studs(b, .55)
	local bevel = box(b, "Bevel", UDim2.fromOffset(2, 2), UDim2.new(1, -4, 0, 10), C.white, 6)
	bevel.BackgroundTransparency = 0.72; bevel.ZIndex = b.ZIndex + 1
	text(b, "Label", str, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), ts or 22).ZIndex = b.ZIndex + 2
	local origPos = pos
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = origPos - UDim2.fromOffset(0, 2) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = origPos }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = origPos + UDim2.fromOffset(0, 3) }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = origPos - UDim2.fromOffset(0, 2) }):Play()
	end)
	return b
end
local ACENTOS = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ" }
local function upper(str: string): string                 -- string.upper no conoce las tildes
	return (string.upper(str):gsub(utf8.charpattern, function(c) return ACENTOS[c] or c end))
end
local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
end

-- ------------------------------------------------------------------ vitrina 3D
-- texto que encoge hasta caber (como mucho a `max` px): para nombres largos
local function ajustar(l: TextLabel, max: number): TextLabel
	l.TextScaled = true
	new("UITextSizeConstraint", l, { MaxTextSize = max, MinTextSize = 8 })
	return l
end

local function coin(parent, x: number, size: number)
	return new("ImageLabel", parent, { Name = "Moneda", Image = "rbxassetid://" .. UI.Icons.coins, BackgroundTransparency = 1,
		Position = UDim2.new(0, x, 0.5, -size / 2), Size = UDim2.fromOffset(size, size), ZIndex = 3 })
end
local RunService = game:GetService("RunService")
local seVe -- se define abajo (antes de preview)
local Audio = require(ReplicatedStorage:WaitForChild("ZeroAudio"))
local TILT = math.rad(32)                -- el arma en diagonal, punta arriba a la derecha (como en el diseño)

-- Fondo de rareza: degradado vertical + halo suave del color detrás del arma
local function backdrop(parent, color: Color3, z: number, oscuro: boolean?)
	local f = box(parent, "Fondo", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), oscuro and C.ink or color, 10)
	f.ZIndex = z
	new("UIGradient", f, { Rotation = 90, Color = ColorSequence.new(oscuro and C.ink or color:Lerp(C.white, 0.1), Color3.fromRGB(12, 18, 36)) })
	if not oscuro then
		for _, rot in { 0, 90 } do
			local halo = new("Frame", f, { Name = "Halo", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
				Size = UDim2.fromScale(.9, .9), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = color:Lerp(C.white, 0.35), ZIndex = z })
			new("UICorner", halo, { CornerRadius = UDim.new(1, 0) })
			new("UIGradient", halo, { Rotation = rot, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }) })
		end
	end
	return f
end

-- ¿Está en pantalla? (él y todos sus padres visibles hasta el ScreenGui)
function seVe(o: Instance): boolean
	while o and not o:IsA("LayerCollector") do
		if o:IsA("GuiObject") and not o.Visible then return false end
		o = o.Parent
	end
	return o ~= nil and (o :: LayerCollector).Enabled
end

-- Vista 3D encuadrada con el tamaño real del arma. opts.spin: balanceo lento · opts.silueta: arma bloqueada en negro
-- Devuelve (ViewportFrame, modelo, centro) para poder girarlo desde fuera (tarjetas del inventario).
local function preview(parent, nombre: string, zindex: number?, opts)
	opts = opts or {}
	local z = zindex or 1
	local modelos = ReplicatedStorage:FindFirstChild("ZeroArmasModelos")
	local plantilla = modelos and modelos:FindFirstChild(nombre)
	if not plantilla then
		local a = Config.PorNombre[nombre]
		text(parent, "Silueta", opts.silueta and "?" or "⚔", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 44, Config.Rarezas[a.rareza].color).ZIndex = z + 1
		return
	end
	local vf = new("ViewportFrame", parent, { Name = "Vista", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z + 1,
		Ambient = Color3.fromRGB(215, 220, 235), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.3, -0.9, -0.7) })
	if opts.silueta then vf.ImageColor3 = Color3.fromRGB(15, 18, 30); vf.ImageTransparency = 0.1 end
	local m = plantilla:Clone()
	m:PivotTo(CFrame.identity)
	m.Parent = vf
	local cf, size = m:GetBoundingBox()
	local center = cf.Position
	local L, H, T = size.Z, size.Y, size.X        -- largo (hoja a -Z), alto, grosor
	local ps = parent.AbsoluteSize
	local aspect = ps.Y > 0 and ps.X / ps.Y or (parent.Size.X.Offset / math.max(parent.Size.Y.Offset, 1))
	if aspect <= 0 or aspect ~= aspect then aspect = 1.5 end
	local tanV = math.tan(math.rad(15)); local tanH = tanV * aspect
	local w = L * math.cos(TILT) + H * math.sin(TILT)
	local h = L * math.sin(TILT) + H * math.cos(TILT)
	local dist = math.max(w / (2 * tanH), h / (2 * tanV)) * (opts.margen or 1.12) + T
	local cam = new("Camera", vf, { FieldOfView = 30 })
	cam.CFrame = CFrame.lookAt(center + Vector3.new(dist, 0, 0), center) * CFrame.Angles(0, 0, -TILT)
	vf.CurrentCamera = cam
	if opts.spin then
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not vf.Parent then conn:Disconnect(); return end
			if not seVe(vf) then return end                    -- menú cerrado: no mover el modelo
			local t = os.clock() - t0
			m:PivotTo(CFrame.new(center) * CFrame.Angles(0, math.sin(t * 1.4) * 0.55, 0) * CFrame.new(-center))
		end)
	end
	return vf, m, center
end

-- ------------------------------------------------------------------ interfaz
-- Las armas viven dentro de los menús de ZeroUI: las CAJAS en la Tienda (pestaña ARMAS) y MIS ARMAS en el Inventario
-- (antes "Clases", pestañas CLASES / ARMAS). Este ScreenGui solo guarda la animación de apertura y los avisos.
local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "ZeroArmasUI", ResetOnSpawn = false, DisplayOrder = 34,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true })
local zeroUI = player.PlayerGui:WaitForChild("ZeroUI")
local modal = zeroUI:WaitForChild("Modal")
local shopBody = modal:WaitForChild("Shop"):WaitForChild("Body")
local invPanel = modal:WaitForChild("Classes")
local invBody = invPanel:WaitForChild("Body")
local function uiAction(name: string, payload)
	local f = zeroUI:FindFirstChild("UIAction")
	if f then pcall(function() f:Invoke(name, payload) end) end
end

-- Tienda: 4.ª pestaña "ARMAS" que baja a la sección de cajas (debajo del pack secreto y gemas)
local CAJAS_Y = 1260
local EXCL_Y = 925                -- exclusivos: debajo del pack secreto, en la zona de PACKS
local function retab(name: string, x: number)
	local b, sh = shopBody:FindFirstChild(name), shopBody:FindFirstChild(name .. "_Shadow")
	for _, o in { b, sh } do
		if o then o.Size = UDim2.fromOffset(208, o.Size.Y.Offset); o.Position = UDim2.fromOffset(x, o.Position.Y.Offset) end
	end
end
retab("Tab_Passes", 4); retab("Tab_Coins", 226); retab("Tab_Packs", 448)
local tabArmasShop = btn(shopBody, "Tab_Armas", "ARMAS", UDim2.fromOffset(670, 0), UDim2.fromOffset(206, 48), C.pink, 23)
tabArmasShop.Activated:Connect(function() shopBody.CanvasPosition = Vector2.new(0, CAJAS_Y) end)
local cajasTitle = text(shopBody, "CajasTitulo", "CAJAS DE ARMAS", UDim2.fromOffset(0, CAJAS_Y), UDim2.fromOffset(880, 34), 25)
local cajasPage = new("Frame", shopBody, { Name = "CajasArmas", Position = UDim2.fromOffset(0, CAJAS_Y + 44), Size = UDim2.fromOffset(880, 466), BackgroundTransparency = 1 })
new("Frame", shopBody, { Name = "FinCajas", Position = UDim2.fromOffset(0, CAJAS_Y + 520), Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1 })   -- alarga el lienzo

-- Inventario: pestañas CLASES / ARMAS; las tarjetas de clase bajan 64 y debajo va la cuadrícula de armas
local function navLabel()
	local nav = zeroUI:FindFirstChild("HUD") and zeroUI.HUD:FindFirstChild("Navigation")
	local b = nav and nav:FindFirstChild("Open_Classes")
	if b and b:FindFirstChild("Label") then b.Label.TextScaled = true end           -- "INVENTARIO" es más largo que "CLASES"
end
navLabel()
for _, c in invBody:GetChildren() do
	if c:IsA("GuiObject") and c.Name:match("^Class_") then c.Position += UDim2.fromOffset(0, 64) end
end
local ARMAS_Y = 64                -- la pestaña CLASES ya no existe: la clase se elige en la sala del cazador
local tabClases = btn(invBody, "Tab_Clases", "CLASES", UDim2.fromOffset(4, 0), UDim2.fromOffset(430, 48), C.purple, 23)
local tabArmasInv = btn(invBody, "Tab_MisArmas", "ARMAS", UDim2.fromOffset(446, 0), UDim2.fromOffset(430, 48), C.pink, 23)
tabClases.Activated:Connect(function() invBody.CanvasPosition = Vector2.zero end)
tabClases.Visible = false
for _, c in invBody:GetChildren() do
	if c:IsA("GuiObject") and (c.Name:match("^Class_") or c.Name == "Tab_Clases_Shadow") then c.Visible = false end
end
tabArmasInv.Activated:Connect(function() invBody.CanvasPosition = Vector2.new(0, ARMAS_Y - 10) end)
text(invBody, "ArmasTitulo", "MIS ARMAS", UDim2.fromOffset(0, ARMAS_Y), UDim2.fromOffset(880, 34), 25)
local armasPage = new("Frame", invBody, { Name = "MisArmas", Position = UDim2.fromOffset(0, ARMAS_Y + 44), Size = UDim2.fromOffset(880, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
new("UIGridLayout", armasPage, { CellSize = UDim2.fromOffset(160, 200), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder })
new("UIPadding", armasPage, { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 20) })

local busy = false
local playOpening -- se define abajo

local function notifyLocal(msg: string)
	local t = text(gui, "Aviso", msg, UDim2.new(.5, -300, 0, 90), UDim2.fromOffset(600, 50), 24)
	t.BackgroundTransparency = .1; t.BackgroundColor3 = C.panel; t.ZIndex = 50
	new("UICorner", t, { CornerRadius = UDim.new(0, 12) })
	task.delay(3, function() t:Destroy() end)
end

-- Exclusivos (ZeroExclusivosConfig): una tarjeta por objeto con vista 3D, etiqueta, precio y cuenta atrás
local Exclusivos = require(ReplicatedStorage:WaitForChild("ZeroExclusivosConfig"))
local EXCL_TAG = { Robux = { "EXCLUSIVO DE ROBUX", C.purple }, VIP = { "EXCLUSIVO VIP", C.yellow } }
text(shopBody, "ExclusivosTitulo", "EXCLUSIVOS", UDim2.fromOffset(0, EXCL_Y), UDim2.fromOffset(880, 34), 25)
local exclTimers = {}
for i, info in Exclusivos do
	local tag = EXCL_TAG[info.tipo] or EXCL_TAG.Robux
	local w = 430
	local card = box(shopBody, "Exclusivo_" .. i, UDim2.fromOffset(4 + (i - 1) * (w + 8), EXCL_Y + 44), UDim2.fromOffset(w, 270), tag[2])
	card.ClipsDescendants = true
	stroke(card, C.ink, 3)
	new("UIGradient", card, { Rotation = 90, Color = ColorSequence.new(tag[2]:Lerp(C.white, .12), tag[2]:Lerp(C.ink, .5)) })
	studs(card, .7)
	-- vista del objeto (o interrogante mientras no exista su modelo)
	local vista = box(card, "Vista", UDim2.fromOffset(14, 50), UDim2.fromOffset(170, 170), C.ink, 12)
	vista.BackgroundTransparency = .45; stroke(vista, tag[2]:Lerp(C.white, .3), 2)
	local modelos = ReplicatedStorage:FindFirstChild("ZeroArmasModelos")
	if info.modelo and modelos and modelos:FindFirstChild(info.modelo) then preview(vista, info.modelo, 3, { spin = true })
	else text(vista, "Signo", "?", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 96, tag[2]:Lerp(C.white, .4)).ZIndex = 3 end
	local pill = box(card, "Etiqueta", UDim2.fromOffset(14, 12), UDim2.fromOffset(w - 28, 30), C.ink, 15)
	pill.BackgroundTransparency = .25
	text(pill, "Texto", tag[1], UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18, info.tipo == "VIP" and C.yellow or C.white)
	local nombre = text(card, "Nombre", info.nombre, UDim2.fromOffset(196, 52), UDim2.fromOffset(w - 210, 60), 30)
	nombre.TextXAlignment = Enum.TextXAlignment.Left; nombre.TextScaled = true
	local sub = text(card, "Subtitulo", info.subtitulo or "", UDim2.fromOffset(196, 112), UDim2.fromOffset(w - 210, 40), 17, C.white)
	sub.TextXAlignment = Enum.TextXAlignment.Left; sub.TextScaled = true
	new("UITextSizeConstraint", sub, { MaxTextSize = 17 })
	if info.termina then
		local tl = text(card, "Termina", "", UDim2.fromOffset(196, 142), UDim2.fromOffset(w - 210, 24), 16, C.yellow)
		tl.TextXAlignment = Enum.TextXAlignment.Left
		table.insert(exclTimers, { label = tl, termina = info.termina })
	end
	local comprar = btn(card, "Comprar", info.precio and ("R$ " .. info.precio) or "PRÓXIMAMENTE", UDim2.fromOffset(196, 174), UDim2.fromOffset(w - 210, 50),
		info.precio and C.green or C.muted, 22)
	comprar.Activated:Connect(function()
		local ob = info.modelo and Config.Obtencion[info.modelo]
		if ob and ob.pase and Passes[ob.pase] then MarketplaceService:PromptGamePassPurchase(player, Passes[ob.pase].Id)
		elseif ob and ob.producto and ob.producto ~= 0 then MarketplaceService:PromptProductPurchase(player, ob.producto)
		elseif info.producto then MarketplaceService:PromptProductPurchase(player, info.producto)
		else notifyLocal("¡Este exclusivo llega muy pronto!") end
	end)
end
if #exclTimers > 0 then
	task.spawn(function()
		while true do
			for _, t in exclTimers do
				local r = math.max(0, t.termina - os.time())
				t.label.Text = string.format("TERMINA EN %02d:%02d:%02d", r // 3600, (r // 60) % 60, r % 60)
			end
			task.wait(1)
		end
	end)
end

-- tarjetas de cajas
local rayosCajas = {}
RunService.RenderStepped:Connect(function()
	if not seVe(cajasPage) then return end
	local r = (os.clock() * 18) % 360
	for i, im in rayosCajas do im.Rotation = if i % 2 == 0 then -r else r end
end)
local cardW = 210                 -- 4 × 210 + 3 × 8 + 4 = 872 (con 214 la Caja Legendaria salía cortada)
local cardGap = 8
for i, caja in Config.Cajas do
	local card = box(cajasPage, "Caja_" .. caja.id, UDim2.fromOffset(4 + (i - 1) * (cardW + cardGap), 0), UDim2.fromOffset(cardW, 456), caja.color)
	stroke(card, C.ink, 3); studs(card, .7)
	new("UIGradient", card, { Rotation = 90, Color = ColorSequence.new(caja.color:Lerp(C.white, .15), caja.color:Lerp(C.ink, .45)) })
	text(card, "Nombre", caja.nombre, UDim2.fromOffset(6, 10), UDim2.fromOffset(cardW - 12, 36), 22)
	-- rayos de luz que giran detrás del cofre
	local rayos = new("ImageLabel", card, { Name = "Rayos", Image = "rbxassetid://102415336729512", BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromOffset(cardW / 2, 103), Size = UDim2.fromOffset(190, 190), ImageColor3 = caja.color:Lerp(C.white, .55), ImageTransparency = .25 })
	table.insert(rayosCajas, rayos)
	if caja.icono then
		new("ImageLabel", card, {
			Name = "Icono",
			Image = caja.icono,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(math.floor((cardW - 110) / 2), 48),
			Size = UDim2.fromOffset(110, 110),
			ScaleType = Enum.ScaleType.Fit,
		})
	else
		text(card, "Icono", "📦", UDim2.fromOffset(47, 50), UDim2.fromOffset(120, 110), 80)
	end
	local y = 168
	for _, r in { "Comun", "Raro", "Especial", "Legendario", "Mitico" } do
		local p = caja.prob[r]
		if p and p > 0 then
			local rr = Config.Rarezas[r]
			local row = box(card, "Prob_" .. r, UDim2.fromOffset(10, y), UDim2.fromOffset(cardW - 20, 30), C.ink, 8)
			row.BackgroundTransparency = .35
			box(row, "Color", UDim2.fromOffset(6, 7), UDim2.fromOffset(16, 16), rr.color, 4)
			local a = text(row, "Rareza", rr.nombre, UDim2.fromOffset(28, 0), UDim2.fromOffset(110, 30), 16, rr.color)
			a.TextXAlignment = Enum.TextXAlignment.Left
			local b = text(row, "Pct", tostring(p) .. "%", UDim2.fromOffset(cardW - 74, 0), UDim2.fromOffset(50, 30), 16)
			b.TextXAlignment = Enum.TextXAlignment.Right
			y += 36
		end
	end
	local buyCoins = btn(card, "Comprar", "    " .. fmt(caja.monedas), UDim2.fromOffset(10, 336), UDim2.fromOffset(cardW - 20, 50), C.green, 22)
	coin(buyCoins, 32, 30)
	local buyRobux = btn(card, "Robux", "R$ " .. caja.robux, UDim2.fromOffset(10, 394), UDim2.fromOffset(cardW - 20, 46), C.blue, 20)
	buyCoins.Activated:Connect(function()
		if busy then return end
		busy = true
		local ok, res = pcall(function() return UIRemote:InvokeServer("OpenBox", { caja = caja.id }) end)
		if ok and res and res.success then playOpening(res) else busy = false; notifyLocal(ok and res and res.message or "No se pudo abrir la caja.") end
	end)
	buyRobux.Activated:Connect(function()
		if caja.producto == 0 then notifyLocal("La compra con Robux llegará pronto."); return end
		-- PolicyService.ArePaidRandomItemsRestricted (lo pone ZeroWheelServer): sin cajas con Robux en esa región
		if player:GetAttribute("PagoAleatorioRestringido") ~= false then notifyLocal("Las cajas con Robux no están disponibles en tu región."); return end
		MarketplaceService:PromptProductPurchase(player, caja.producto)
	end)
end

-- inventario
local function owned(): { [string]: boolean }
	local t = {}
	for nombre in string.gmatch(player:GetAttribute("Armas") or Config.ArmaInicial, "[^,]+") do t[nombre] = true end
	return t
end
-- ------------------------------------------------------------------ tarjeta del inventario
-- Lo que se anima (bordes, destellos, giro al pasar el ratón) va en `animados` y lo mueve un único bucle que solo corre
-- con el inventario abierto.
local animados = {}
local girando = nil :: { m: Model, c: Vector3, t0: number }?
local ESPECIAL = {
	Exclusivo = { Color3.fromRGB(255, 84, 46), Color3.fromRGB(255, 214, 74), Color3.fromRGB(255, 70, 160) },
	Mitico = { Color3.fromRGB(255, 70, 140), Color3.fromRGB(255, 190, 235), Color3.fromRGB(170, 101, 255) },
}
local function tarjeta(a, rr, has: boolean, equipada: boolean)
	local esp = ESPECIAL[a.rareza]
	local card = box(armasPage, a.nombre, UDim2.new(), UDim2.new(), C.ink, 14)
	card.ClipsDescendants = true
	local oscuro = Color3.fromRGB(14, 18, 34)
	new("UIGradient", card, { Rotation = 90, Color = ColorSequence.new(has and rr.color:Lerp(oscuro, 0.45) or Color3.fromRGB(30, 34, 54), oscuro) })
	-- borde: color de la rareza; en especiales, degradado que gira
	local st = stroke(card, has and rr.color or (esp and rr.color:Lerp(C.ink, .35) or C.panel), equipada and 5 or 3)
	if esp then
		st.Color = Color3.new(1, 1, 1); st.Thickness = equipada and 5 or 4
		local gr = new("UIGradient", st, { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, esp[1]), ColorSequenceKeypoint.new(0.5, esp[2]),
			ColorSequenceKeypoint.new(1, esp[3]) }) })
		table.insert(animados, { tipo = "borde", g = gr, v = a.rareza == "Exclusivo" and 120 or 70 })
	end
	-- foco de luz detrás del arma y sombra en el suelo
	local zona = new("Frame", card, { Name = "Zona", Position = UDim2.fromOffset(4, 20), Size = UDim2.fromOffset(152, 112), BackgroundTransparency = 1 })
	if has or esp then                                    -- resplandor radial del color de la rareza
		new("ImageLabel", zona, { Name = "Luz", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .48), Size = UDim2.fromOffset(150, 150),
			BackgroundTransparency = 1, Image = "rbxassetid://138167561126452", ImageColor3 = rr.color:Lerp(C.white, .35),
			ImageTransparency = has and 0 or .15 })
	end
	local sombra = new("Frame", zona, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, 0, 1, -8), Size = UDim2.fromOffset(96, 14),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = .55, BorderSizePixel = 0 })
	new("UICorner", sombra, { CornerRadius = UDim.new(1, 0) })
	local vf, m, centro = preview(zona, a.nombre, 3, { silueta = false, margen = 0.92 })
	if vf and not has and esp then vf.ImageTransparency = 0 end
	-- etiqueta de rareza (arriba a la izquierda)
	local pill = box(card, "Rareza", UDim2.fromOffset(6, 6), UDim2.fromOffset(0, 18), rr.color, 9)
	pill.AutomaticSize = Enum.AutomaticSize.X; pill.ZIndex = 6
	new("UIPadding", pill, { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) })
	local pt = new("TextLabel", pill, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = rr.nombre,
		Font = Enum.Font.FredokaOne, TextSize = 12, TextColor3 = C.white, ZIndex = 7 })
	new("UIStroke", pt, { Color = C.ink, Thickness = 1.5 })
	if equipada then
		local ok = box(card, "Equipada", UDim2.new(1, -26, 0, 6), UDim2.fromOffset(20, 20), C.green, 10); ok.ZIndex = 6
		text(ok, "V", "✓", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 14).ZIndex = 7
	end
	-- cinta EXCLUSIVO en diagonal y destello que cruza la tarjeta
	if esp then
		if a.rareza == "Exclusivo" then
			local cinta = new("Frame", card, { Name = "Cinta", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(1, -24, 0, 24), Size = UDim2.fromOffset(120, 18),
				Rotation = 45, BackgroundColor3 = esp[1], BorderSizePixel = 0, ZIndex = 8 })
			new("UIGradient", cinta, { Color = ColorSequence.new(esp[1], esp[2]) })
			local ct = text(cinta, "T", "EXCLUSIVO", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 11); ct.ZIndex = 9
			if equipada then cinta.Visible = false end
		end
		local brillo = new("Frame", card, { Name = "Destello", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(-.5, .5), Size = UDim2.new(0, 46, 1.6, 0),
			Rotation = 20, BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 5 })
		new("UIGradient", brillo, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.5, has and .55 or .75),
			NumberSequenceKeypoint.new(1, 1) }) })
		table.insert(animados, { tipo = "destello", f = brillo, fase = math.random() * 3, ciclo = a.rareza == "Exclusivo" and 2.6 or 3.6 })
		for k = 1, (a.rareza == "Exclusivo" and 4 or 2) do
			local s = text(card, "Chispa", "✦", UDim2.fromOffset(math.random(10, 130), math.random(24, 110)), UDim2.fromOffset(18, 18), math.random(10, 16), esp[2])
			s.ZIndex = 6
			table.insert(animados, { tipo = "chispa", l = s, fase = k * 0.9 + math.random() })
		end
	end
	-- nombre (los bloqueados de caja salen "???"; míticos y exclusivos enseñan su nombre)
	ajustar(text(card, "Nombre", (has or esp) and upper(a.nombre) or "???", UDim2.fromOffset(6, 128), UDim2.fromOffset(148, 28), 18), 18)
	-- al pasar el ratón: crece y su arma gira
	local escala = new("UIScale", card)
	card.MouseEnter:Connect(function()
		TweenService:Create(escala, TweenInfo.new(.15), { Scale = 1.05 }):Play()
		if m then girando = { m = m, c = centro, t0 = os.clock() } end
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(escala, TweenInfo.new(.15), { Scale = 1 }):Play()
		if girando and girando.m == m then m:PivotTo(CFrame.identity); girando = nil end
	end)
	return card
end
RunService.RenderStepped:Connect(function()
	if not invPanel.Visible then return end
	local t = os.clock()
	for _, x in animados do
		if x.tipo == "borde" then x.g.Rotation = (t * x.v) % 360
		elseif x.tipo == "destello" then
			local f = ((t + x.fase) % x.ciclo) / x.ciclo                    -- cruza en el primer 35 % del ciclo
			x.f.Position = UDim2.fromScale(-.4 + math.min(f / .35, 1) * 1.8, .5)
		else
			x.l.TextTransparency = .25 + .75 * (0.5 + 0.5 * math.sin(t * 3 + x.fase)) ^ 3
		end
	end
	local g = girando
	if g and g.m.Parent then
		g.m:PivotTo(CFrame.new(g.c) * CFrame.Angles(0, (t - g.t0) * 2.2, 0) * CFrame.new(-g.c))
	end
end)

-- 100000 -> "100K", 1500 -> "1.5K"
local function corto(n: number): string
	if n >= 1000 then
		local k = n / 1000
		return (k % 1 == 0 and string.format("%d", k) or string.format("%.1f", k)) .. "K"
	end
	return tostring(n)
end
-- cuentas atrás de las armas de tiempo limitado (se rellenan al refrescar el inventario)
local limTimers = {}
task.spawn(function()
	while true do
		for _, t in limTimers do
			if t.label.Parent then
				local r = math.max(0, t.hasta - os.time())
				t.label.Text = if r <= 0 then "AGOTADA" elseif r >= 86400 then string.format("TERMINA EN %dD %02dH", r // 86400, (r // 3600) % 24)
					else string.format("TERMINA EN %02d:%02d:%02d", r // 3600, (r // 60) % 60, r % 60)
			end
		end
		task.wait(1)
	end
end)
local inspeccionar -- se define abajo (VER ARMA)
local firmaInventario = nil
local function refreshInventory()
	local mine, equipped = owned(), player:GetAttribute("ArmaEquipada") or Config.ArmaInicial
	local firma = tostring(player:GetAttribute("Armas")) .. "|" .. equipped
	if firma == firmaInventario then return end       -- igual que la última vez: no se rehace nada
	firmaInventario = firma
	table.clear(limTimers); table.clear(animados)
	for _, c in armasPage:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	local list = table.clone(Config.Armas)
	table.sort(list, function(a, b)       -- primero las tuyas; luego de menos a más rareza (Común … Exclusivo)
		if (mine[a.nombre] or false) ~= (mine[b.nombre] or false) then return mine[a.nombre] == true end
		local ra, rb = Config.Rarezas[a.rareza].orden, Config.Rarezas[b.rareza].orden
		if ra ~= rb then return ra < rb end
		return a.indice < b.indice
	end)
	for i, a in list do
		local rr = Config.Rarezas[a.rareza]
		local has = mine[a.nombre]
		local card = tarjeta(a, rr, has, a.nombre == equipped)
		card.LayoutOrder = i
		local ver = new("TextButton", card, { Name = "Ver", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, AutoButtonColor = false })
		ver.Activated:Connect(function() inspeccionar(a, has == true, a.nombre == equipped) end)
		if has then
			local eq = a.nombre == equipped
			local b = btn(card, "Equipar", eq and "EQUIPADA" or "EQUIPAR", UDim2.fromOffset(12, 160), UDim2.fromOffset(136, 32), eq and C.green or C.blue, 17)
			b.Active = not eq
			b.Activated:Connect(function()
				if eq or busy then return end
				busy = true
				local ok, res = pcall(function() return UIRemote:InvokeServer("EquipArma", { arma = a.nombre }) end)
				busy = false
				if not (ok and res and res.success) then notifyLocal(ok and res and res.message or "No se pudo equipar.") end
			end)
		elseif Config.Obtencion[a.nombre] then          -- mítica/exclusiva bloqueada: cómo se consigue
			local ob = Config.Obtencion[a.nombre]
			local abierta = Config.disponible(ob)
			local texto = if not abierta then "AGOTADA" elseif ob.monedas then ("COMPRAR " .. corto(ob.monedas)) else ob.texto
			local b = btn(card, "Conseguir", texto, UDim2.fromOffset(12, 160), UDim2.fromOffset(136, 32), abierta and (ob.monedas and C.green or rr.color) or C.muted, 15)
			if ob.hasta or ob.limitado then                  -- etiqueta de tiempo limitado (con cuenta atrás si tiene fecha)
				local l = text(card, "Limitado", ob.hasta and "" or "TIEMPO LIMITADO", UDim2.fromOffset(6, 108), UDim2.fromOffset(148, 20), 13, C.yellow)
				l.ZIndex = 5
				if ob.hasta then table.insert(limTimers, { label = l, hasta = ob.hasta }) end
			end
			b.Activated:Connect(function()
				if not abierta then notifyLocal("Esta arma era de tiempo limitado y ya no está disponible.")
				elseif ob.monedas then
					if busy then return end
					busy = true
					local ok, res = pcall(function() return UIRemote:InvokeServer("ComprarArma", { arma = a.nombre }) end)
					busy = false
					if not (ok and res and res.success) then notifyLocal(ok and res and res.message or "No se pudo comprar.") end
				elseif ob.pase and Passes[ob.pase] then MarketplaceService:PromptGamePassPurchase(player, Passes[ob.pase].Id)
				elseif ob.producto and ob.producto ~= 0 then MarketplaceService:PromptProductPurchase(player, ob.producto)
				elseif ob.invitar then
					local ok = pcall(function() SocialService:PromptGameInvite(player) end)
					notifyLocal(ok and "¡Gánala cuando un amigo entre por tu invitación!" or "No se pudo abrir la invitación.")
				elseif ob.ruleta then notifyLocal("Cada giro de la RULETA tiene un " .. (ob.ruleta * 100) .. "% de darte esta arma.")
				else notifyLocal("¡Llega muy pronto!") end
			end)
		end
	end
end

-- 5.4: las vistas 3D de MIS ARMAS solo se dibujan si su tarjeta está dentro del scroll (en móvil eran decenas a la vez)
local acumVis = 0
RunService.Heartbeat:Connect(function(dt)
	acumVis += dt
	if acumVis < 0.15 or not invPanel.Visible then return end
	acumVis = 0
	local arriba = invBody.AbsolutePosition.Y
	local abajo = arriba + invBody.AbsoluteSize.Y
	for _, card in armasPage:GetChildren() do
		local zona = card:IsA("Frame") and card:FindFirstChild("Zona")
		local vf = zona and zona:FindFirstChild("Vista")
		if vf then
			local y = card.AbsolutePosition.Y
			vf.Visible = y + card.AbsoluteSize.Y > arriba and y < abajo
		end
	end
end)

-- ------------------------------------------------------------------ VER ARMA (5.2)
do
-- Se abre al pulsar una tarjeta de MIS ARMAS, encima del inventario (no lo cierra). Vista 3D grande que gira sola y
-- se arrastra con el ratón o el dedo; "VER EN TU PERSONAJE" la pone en tu mano (copia de tu avatar).
local UserInputService = game:GetService("UserInputService")
local insp = new("Frame", invPanel, { Name = "VerArma", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 9, 22),
	BackgroundTransparency = .2, Visible = false, ZIndex = 30, Active = true })
new("UICorner", insp, { CornerRadius = UDim.new(0, 22) })
local inspCaja = box(insp, "Caja", UDim2.fromOffset(30, 26), UDim2.fromOffset(860, 598), C.panel, 20)
inspCaja.ZIndex = 31; inspCaja.Active = true; stroke(inspCaja, C.ink, 4); studs(inspCaja, .88)
local inspEscala = new("UIScale", inspCaja)
local vista = box(inspCaja, "Vista", UDim2.fromOffset(24, 24), UDim2.fromOffset(450, 550), C.ink, 16)
vista.ZIndex = 32; vista.BackgroundTransparency = .3; vista.Active = true
local inspFondo = new("UIGradient", vista, { Rotation = 90 })
local inspNombre = text(inspCaja, "Nombre", "", UDim2.fromOffset(494, 30), UDim2.fromOffset(340, 80), 34); inspNombre.ZIndex = 33
inspNombre.TextScaled = true; new("UITextSizeConstraint", inspNombre, { MaxTextSize = 38 })
local inspRareza = box(inspCaja, "Rareza", UDim2.fromOffset(494, 118), UDim2.fromOffset(160, 32), C.blue, 16); inspRareza.ZIndex = 33
local inspRarezaT = text(inspRareza, "T", "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18); inspRarezaT.ZIndex = 34
local inspInfo = text(inspCaja, "Info", "", UDim2.fromOffset(494, 162), UDim2.fromOffset(340, 120), 20, Color3.fromRGB(200, 210, 235))
inspInfo.ZIndex = 33; inspInfo.TextYAlignment = Enum.TextYAlignment.Top; inspInfo.TextXAlignment = Enum.TextXAlignment.Left
local inspModo = btn(inspCaja, "Modo", "VER EN TU PERSONAJE", UDim2.fromOffset(494, 380), UDim2.fromOffset(340, 56), C.purple, 20); inspModo.ZIndex = 33
local inspAccion = btn(inspCaja, "Accion", "EQUIPAR", UDim2.fromOffset(494, 450), UDim2.fromOffset(340, 64), C.green, 24); inspAccion.ZIndex = 33
local inspCerrar = btn(inspCaja, "Cerrar", "×", UDim2.fromOffset(790, 14), UDim2.fromOffset(54, 54), C.pink, 34); inspCerrar.ZIndex = 35
local inspPista = text(inspCaja, "Pista", "Arrastra para girar", UDim2.fromOffset(24, 540), UDim2.fromOffset(450, 30), 16, Color3.fromRGB(170, 180, 210))
inspPista.ZIndex = 34
for _, d in inspCaja:GetDescendants() do if d:IsA("GuiObject") and d.ZIndex < 32 then d.ZIndex = 33 end end

local actual = nil        -- { a, has, eq, personaje: boolean }
local giro, arrastre, ultimoX = 0, nil, 0
local objeto, centro, pivote0 = nil, Vector3.zero, CFrame.identity   -- lo que gira (arma sola o copia del personaje)
local function limpiarVista()
	for _, c in vista:GetChildren() do if c:IsA("ViewportFrame") or c.Name == "Silueta" then c:Destroy() end end
	objeto = nil
end
local function montarSola(a)
	local vf, m, c = preview(vista, a.nombre, 33, { margen = 1.0, silueta = not actual.has })
	if vf then vf.ZIndex = 33 end
	objeto, centro, pivote0 = m, c or Vector3.zero, CFrame.identity
end
local function montarPersonaje(a)
	local char = player.Character
	local modelos = ReplicatedStorage:FindFirstChild("ZeroArmasModelos")
	local plantilla = modelos and modelos:FindFirstChild(a.nombre)
	if not char or not plantilla then montarSola(a); return end
	local vf = new("ViewportFrame", vista, { Name = "Vista", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 33,
		Ambient = Color3.fromRGB(150, 155, 175), LightColor = Color3.fromRGB(255, 248, 235), LightDirection = Vector3.new(-0.4, -1, -0.6) })
	local wm = new("WorldModel", vf)
	local antes = char.Archivable
	char.Archivable = true
	local copia = char:Clone()
	char.Archivable = antes
	if not copia then montarSola(a); return end
	for _, d in copia:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Tool") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("Sound")
			or d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("ForceField") then d:Destroy() end
	end
	for _, c in copia:GetChildren() do if c:IsA("Model") then c:Destroy() end end   -- el arma de la espalda
	copia.Parent = wm
	local raiz = copia:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz then raiz.Anchored = true end
	copia:PivotTo(CFrame.new(0, 3, 0))
	-- el arma en la mano derecha: la punta hacia delante (bastones en vertical, agarrados a 1/3)
	local arma = plantilla:Clone()
	arma:PivotTo(CFrame.identity)
	local cf, size = arma:GetBoundingBox()
	local L = size.Z
	local largo = L > 3                                     -- bastones (como ZeroArmasServer): agarre a 1/3
	local agarre = cf.Position + Vector3.new(0, 0, L / 2 - (if largo then L / 3 else math.min(0.7, L * 0.2)))
	local brazo = copia:FindFirstChild("Right Arm") :: BasePart?
	local mano = (if brazo then brazo.CFrame else CFrame.new(1.5, 3, 0)) * CFrame.new(0.15, -0.9, -0.85)   -- delante del puño: no la tapa el brazo
	local giroArma = CFrame.Angles(math.rad(70), 0, 0)      -- la punta (-Z) arriba y un poco hacia delante
	arma:PivotTo(CFrame.new(mano.Position) * giroArma * CFrame.new(-agarre))
	arma.Parent = copia
	-- encuadre con la caja real de la copia (el pivote del personaje no siempre es su centro)
	local bcf, bsize = copia:GetBoundingBox()
	local mitad = bsize.Y / 2 * 1.12
	local dist = mitad / math.tan(math.rad(17)) + bsize.Z / 2
	local cam = new("Camera", vf, { FieldOfView = 34 })
	cam.CFrame = CFrame.lookAt(bcf.Position + Vector3.new(-0.45, 0.12, -1).Unit * dist, bcf.Position)
	vf.CurrentCamera = cam
	objeto, centro, pivote0 = copia, Vector3.new(bcf.Position.X, 0, bcf.Position.Z), copia:GetPivot()
end
local function pintar()
	if not actual then return end
	local a, has = actual.a, actual.has
	local rr = Config.Rarezas[a.rareza]
	limpiarVista()
	inspFondo.Color = ColorSequence.new(rr.color:Lerp(C.ink, .45), Color3.fromRGB(10, 14, 30))
	if actual.personaje and has then montarPersonaje(a) else montarSola(a) end
	inspNombre.Text = upper(a.nombre)
	inspRareza.BackgroundColor3 = rr.color; inspRarezaT.Text = rr.nombre
	local ob = Config.Obtencion[a.nombre]
	inspInfo.Text = if has then (if actual.eq then "La llevas equipada." else "Es tuya: equípala para cazar con ella.")
		elseif ob then ("Cómo se consigue: " .. (if ob.monedas then ("comprándola por " .. fmt(ob.monedas) .. " monedas") else (ob.texto or "muy pronto")) .. ".")
		else "Sale en las CAJAS DE ARMAS de la Tienda."
	inspModo.Visible = has
	inspModo.Label.Text = actual.personaje and "VER EL ARMA SOLA" or "VER EN TU PERSONAJE"
	if has then
		inspAccion.Label.Text = actual.eq and "EQUIPADA" or "EQUIPAR"
		inspAccion.BackgroundColor3 = actual.eq and C.green or C.blue
	else
		inspAccion.Label.Text = if ob then "CONSEGUIR" else "IR A LAS CAJAS"
		inspAccion.BackgroundColor3 = C.yellow
	end
end
function inspeccionar(a, has: boolean, eq: boolean, personaje: boolean?)
	actual = { a = a, has = has, eq = eq, personaje = personaje == true }
	giro = 0
	pintar()
	insp.Visible = true
	inspEscala.Scale = 0.85
	TweenService:Create(inspEscala, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Audio.play("Open")
end
local function cerrarInsp() if insp.Visible then insp.Visible = false; limpiarVista(); actual = nil; Audio.play("Close") end end
inspCerrar.Activated:Connect(cerrarInsp)
insp.InputBegan:Connect(function(i)          -- tocar fuera de la caja cierra solo esta ventana
	if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
		local p, s = inspCaja.AbsolutePosition, inspCaja.AbsoluteSize
		if i.Position.X < p.X or i.Position.X > p.X + s.X or i.Position.Y < p.Y or i.Position.Y > p.Y + s.Y then cerrarInsp() end
	end
end)
invPanel:GetPropertyChangedSignal("Visible"):Connect(function() if not invPanel.Visible then cerrarInsp() end end)
inspModo.Activated:Connect(function() if actual then actual.personaje = not actual.personaje; pintar() end end)
inspAccion.Activated:Connect(function()
	if not actual then return end
	local a = actual.a
	if actual.has then
		if actual.eq or busy then return end
		busy = true
		local ok, res = pcall(function() return UIRemote:InvokeServer("EquipArma", { arma = a.nombre }) end)
		busy = false
		if ok and res and res.success then actual.eq = true; pintar() else notifyLocal(ok and res and res.message or "No se pudo equipar.") end
	else                                       -- mismo camino que el botón CONSEGUIR de la tarjeta
		local ob = Config.Obtencion[a.nombre]
		if ob and ob.monedas and Config.disponible(ob) then
			if busy then return end
			busy = true
			local ok, res = pcall(function() return UIRemote:InvokeServer("ComprarArma", { arma = a.nombre }) end)
			busy = false
			if ok and res and res.success then cerrarInsp() else notifyLocal(ok and res and res.message or "No se pudo comprar.") end
		elseif ob and ob.pase and Passes[ob.pase] then MarketplaceService:PromptGamePassPurchase(player, Passes[ob.pase].Id)
		elseif ob and ob.producto and ob.producto ~= 0 then MarketplaceService:PromptProductPurchase(player, ob.producto)
		elseif ob then notifyLocal(ob.ruleta and ("Cada giro de la RULETA tiene un " .. (ob.ruleta * 100) .. "% de darte esta arma.") or "¡Llega muy pronto!")
		else
			cerrarInsp()
			uiAction("Open", "Shop")
			task.defer(function() shopBody.CanvasPosition = Vector2.new(0, CAJAS_Y) end)
		end
	end
end)
vista.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then arrastre = i; ultimoX = i.Position.X end
end)
UserInputService.InputChanged:Connect(function(i)
	if arrastre and (i.UserInputType == Enum.UserInputType.MouseMovement or i == arrastre) then
		giro += (i.Position.X - ultimoX) * 0.012; ultimoX = i.Position.X
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if arrastre and (i == arrastre or i.UserInputType == Enum.UserInputType.MouseButton1) then arrastre = nil end
end)
RunService.RenderStepped:Connect(function(dt)
	if not insp.Visible or not objeto or not objeto.Parent then return end
	if not arrastre then giro += dt * 0.6 end
	if objeto:FindFirstChildOfClass("Humanoid") then
		objeto:PivotTo(CFrame.new(centro) * CFrame.Angles(0, giro, 0) * CFrame.new(-centro) * pivote0)
	else
		objeto:PivotTo(CFrame.new(centro) * CFrame.Angles(0, 0, giro) * CFrame.new(-centro) * pivote0)   -- eje largo = Z del modelo
	end
end)
end

-- abrir VER ARMA desde fuera (pruebas, otros menús): ZeroArmasUI.VerArma:Fire("Nombre del arma")
new("BindableEvent", gui, { Name = "VerArma" }).Event:Connect(function(nombre, personaje)
	local a = Config.PorNombre[nombre]
	if a then inspeccionar(a, owned()[nombre] == true, nombre == (player:GetAttribute("ArmaEquipada") or Config.ArmaInicial), personaje) end
end)

-- refrescar MIS ARMAS al abrir el Inventario y cuando cambian tus armas o la equipada
local function refreshIfOpen() if invPanel.Visible then refreshInventory() end end
invPanel:GetPropertyChangedSignal("Visible"):Connect(refreshIfOpen)
for _, a in { "Armas", "ArmaEquipada" } do player:GetAttributeChangedSignal(a):Connect(refreshIfOpen) end

-- ------------------------------------------------------------------ animación de apertura (ruleta horizontal)
local overlay = new("Frame", gui, { Name = "Apertura", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 9, 22),
	BackgroundTransparency = .08, Visible = false, ZIndex = 20 })
local CARD_W, CARD_H, GAP, N = 168, 196, 12, 44
local WIN_W = 900
local window = new("Frame", overlay, { Name = "Ventana", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .45),
	Size = UDim2.fromOffset(WIN_W, CARD_H + 30), BackgroundColor3 = Color3.fromRGB(12, 18, 38), ClipsDescendants = true, ZIndex = 21 })
new("UICorner", window, { CornerRadius = UDim.new(0, 18) }); stroke(window, C.yellow, 3); studs(window, .9)
local overlayScale = new("UIScale", window)
local strip = new("Frame", window, { Name = "Tira", BackgroundTransparency = 1, Size = UDim2.fromOffset(N * (CARD_W + GAP), CARD_H),
	Position = UDim2.fromOffset(0, 15), ZIndex = 22 })
-- bordes que se desvanecen para que las cartas entren y salgan suaves
for _, lado in { { 0, 0 }, { 1, 180 } } do
	local f = new("Frame", window, { Name = "Borde", AnchorPoint = Vector2.new(lado[1], 0), Position = UDim2.fromScale(lado[1], 0),
		Size = UDim2.new(0, 170, 1, 0), BackgroundColor3 = Color3.fromRGB(12, 18, 38), BorderSizePixel = 0, ZIndex = 26 })
	new("UIGradient", f, { Rotation = lado[2], Transparency = NumberSequence.new(0, 1) })
end
-- puntero: línea y dos rombos arriba y abajo
new("Frame", window, { Name = "Marcador", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 0),
	Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = C.yellow, BorderSizePixel = 0, ZIndex = 27 })
for _, y in { 0, 1 } do
	local d = new("Frame", window, { Name = "Punta", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, y), Size = UDim2.fromOffset(26, 26),
		Rotation = 45, BackgroundColor3 = C.yellow, BorderSizePixel = 0, ZIndex = 27 })
	stroke(d, C.ink, 3)
end
-- destellos giratorios detrás del premio
local rays = new("Frame", overlay, { Name = "Rayos", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .43), Size = UDim2.fromOffset(620, 620),
	BackgroundTransparency = 1, Visible = false, ZIndex = 28 })
for k = 0, 5 do
	local r = new("Frame", rays, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.new(1, 0, 0, 70),
		Rotation = k * 30, BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 28 })
	new("UIGradient", r, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1) }) })
end
local raysScale = new("UIScale", rays)
local reveal = box(overlay, "Premio", UDim2.fromScale(.5, .43), UDim2.fromOffset(460, 420), C.panel, 24)
reveal.AnchorPoint = Vector2.new(.5, .5); reveal.Visible = false; reveal.ZIndex = 30
local revealScale = new("UIScale", reveal)
local okBtn = btn(overlay, "Ok", "¡GENIAL!", UDim2.new(.5, -130, .43, 238), UDim2.fromOffset(260, 58), C.green, 27)
okBtn.Visible = false; okBtn.ZIndex = 31; okBtn.Label.ZIndex = 32
local flash = new("Frame", overlay, { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 40 })

local function reelCard(parent, nombre: string, x: number)
	local a = Config.PorNombre[nombre]
	local rr = Config.Rarezas[a.rareza]
	local c = box(parent, "C", UDim2.fromOffset(x, 0), UDim2.fromOffset(CARD_W, CARD_H), C.card, 14)
	c.ZIndex = 22; stroke(c, rr.color, 3)
	local v = new("Frame", c, { Name = "V", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(CARD_W - 12, 124), BackgroundTransparency = 1, ZIndex = 22 })
	backdrop(v, rr.color, 22)
	preview(v, nombre, 23)
	box(c, "Barra", UDim2.new(0, 0, 1, -8), UDim2.new(1, 0, 0, 8), rr.color, 6).ZIndex = 23
	local t = ajustar(text(c, "N", upper(nombre), UDim2.fromOffset(4, 132), UDim2.fromOffset(CARD_W - 8, 30), 18), 18); t.ZIndex = 24
	local r = text(c, "R", rr.nombre, UDim2.fromOffset(4, 160), UDim2.fromOffset(CARD_W - 8, 20), 14, rr.color); r.ZIndex = 24
	return c
end

local raysConn
function playOpening(res)
	uiAction("Close")
	local caja = Config.CajaPorId[res.caja]
	local a = Config.PorNombre[res.arma]
	local rr = Config.Rarezas[a.rareza]
	local fit = math.min(1, (gui.AbsoluteSize.Y - 160) / 420)
	if caja then                                       -- sin caja (arma regalada): directo a la revelación
		for _, c in strip:GetChildren() do c:Destroy() end
		local WIN = N - 6                                  -- tarjeta ganadora
		local winner
		for i = 1, N do
			local nombre = i == WIN and res.arma or Config.tirar(caja, math.random(), math.random())
			local c = reelCard(strip, nombre, (i - 1) * (CARD_W + GAP))
			if i == WIN then winner = c end
		end
		overlayScale.Scale = math.min(1, (gui.AbsoluteSize.X - 30) / WIN_W)
		reveal.Visible = false; okBtn.Visible = false; rays.Visible = false; window.Visible = true; overlay.Visible = true
		strip.Position = UDim2.fromOffset(0, 15)
		local mid = WIN_W / 2
		local stop = mid - ((WIN - 1) * (CARD_W + GAP) + CARD_W / 2) + math.random(-CARD_W * 0.38, CARD_W * 0.38)
		Audio.play("WheelStart")
		local tw = TweenService:Create(strip, TweenInfo.new(5.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(stop, 15) })
		local lastIndex = -1
		local tick = RunService.RenderStepped:Connect(function()           -- "tic" cada vez que una carta cruza el puntero
			local idx = math.floor((mid - strip.Position.X.Offset) / (CARD_W + GAP))
			if idx ~= lastIndex then lastIndex = idx; Audio.play("WheelTick") end
		end)
		tw:Play()
		tw.Completed:Wait()
		tick:Disconnect()
		-- la ganadora se ilumina
		local ws = new("UIScale", winner)
		local st = winner:FindFirstChildOfClass("UIStroke")
		if st then st.Thickness = 6; st.Color = rr.color:Lerp(C.white, .3) end
		TweenService:Create(ws, TweenInfo.new(.25, Enum.EasingStyle.Back), { Scale = 1.08 }):Play()
		task.wait(0.6)
	else
		overlayScale.Scale = math.min(1, (gui.AbsoluteSize.X - 30) / WIN_W)
		window.Visible = false; overlay.Visible = true
	end
	-- premio
	if a.rareza == "Legendario" or a.rareza == "Especial" or a.rareza == "Mitico" or a.rareza == "Exclusivo" then
		flash.BackgroundColor3 = rr.color:Lerp(C.white, .5); flash.BackgroundTransparency = 0.25
		TweenService:Create(flash, TweenInfo.new(.6), { BackgroundTransparency = 1 }):Play()
	end
	Audio.play("Prize")
	for _, c in reveal:GetChildren() do if not c:IsA("UICorner") then c:Destroy() end end
	reveal.BackgroundColor3 = C.panel
	stroke(reveal, rr.color, 5); studs(reveal, .88)
	local v = new("Frame", reveal, { Name = "V", Size = UDim2.fromOffset(420, 240), Position = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ZIndex = 30 })
	backdrop(v, rr.color, 30)
	preview(v, res.arma, 31, { spin = true, margen = 1.05 })
	text(reveal, "Rareza", rr.nombre, UDim2.fromOffset(10, 266), UDim2.fromOffset(440, 30), 24, rr.color).ZIndex = 32
	ajustar(text(reveal, "Nombre", upper(res.arma), UDim2.fromOffset(10, 296), UDim2.fromOffset(440, 54), 44), 44).ZIndex = 32
	local info = res.nueva and "¡NUEVA ARMA! Equípala en INVENTARIO." or ("Repetida  •  +" .. fmt(res.devolucion) .. " monedas")
	text(reveal, "Info", info, UDim2.fromOffset(10, 354), UDim2.fromOffset(440, 50), 21, res.nueva and C.green or C.yellow).ZIndex = 32
	for _, r in rays:GetChildren() do if r:IsA("Frame") then r.BackgroundColor3 = rr.color:Lerp(C.white, .25) end end
	window.Visible = false
	rays.Visible = true; reveal.Visible = true; okBtn.Visible = true
	revealScale.Scale = fit * 0.55; raysScale.Scale = fit * 0.4
	TweenService:Create(revealScale, TweenInfo.new(.45, Enum.EasingStyle.Back), { Scale = fit }):Play()
	TweenService:Create(raysScale, TweenInfo.new(.6, Enum.EasingStyle.Quint), { Scale = fit }):Play()
	if raysConn then raysConn:Disconnect() end
	raysConn = RunService.RenderStepped:Connect(function(dt) rays.Rotation += dt * 18 end)
end

okBtn.Activated:Connect(function()
	overlay.Visible = false
	if raysConn then raysConn:Disconnect(); raysConn = nil end
	busy = false
	uiAction("Open", "Classes")                     -- directo al Inventario para equipar lo que salió
	task.defer(function() invBody.CanvasPosition = Vector2.new(0, ARMAS_Y - 10) end)
end)

-- cajas pagadas con Robux: el servidor manda el resultado al confirmar la compra
Resultado.OnClientEvent:Connect(function(res)
	busy = true
	playOpening(res)
end)
