-- ZeroTiendaClient (LocalScript, StarterPlayerScripts): retoques de la Tienda de ZeroUI.
--  · PASES: los 4 pases del juego (faltaba 2× XP) con el icono que tiene cada uno en Roblox (MonetizationConfig).
--  · Cintas sobre las tarjetas: DESTACADO, MÁS POPULAR, MEJOR PRECIO, OFERTA…
--  · MONEDAS: precio e icono reales de cada Developer Product.
--  · PACKS: el Pack de Inicio (compra única, MonetizationConfig.StarterPack) en lugar del Pack Secreto, y la oferta
--    "PACK ZERO" del HUD pasa a ser "PACK INICIO". La compra la valida ZeroWheelServer (acción Purchase "StarterPack").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local UI = require(ReplicatedStorage:WaitForChild("ZeroUI"))
local Monet = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local TitulosConfig = require(ReplicatedStorage:WaitForChild("ZeroTitulosConfig"))
local Estilo = require(ReplicatedStorage:WaitForChild("ZeroTitulosEstilo"))
local C = UI.Colors

local gui = player:WaitForChild("PlayerGui"):WaitForChild("ZeroUI")
gui:WaitForChild("UIAction")
local shop = gui.Modal:WaitForChild("Shop")
local body = shop:WaitForChild("Body")
task.wait()                                   -- deja que ZeroArmasClient y ShopController monten lo suyo primero

local function new(class, parent, props)
	local n = Instance.new(class)
	for k, v in props or {} do n[k] = v end
	n.Parent = parent
	return n
end
local function action(name, payload) pcall(function() gui.UIAction:Invoke(name, payload) end) end
local function grad(color: Color3) return ColorSequence.new(color:Lerp(C.white, .22), color:Lerp(C.ink, .12)) end
local function label(parent, name, text, pos, size, ts, color)
	local l = new("TextLabel", parent, { Name = name, Text = text, Position = pos, Size = size, BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne, TextSize = ts, TextColor3 = color or C.white, TextWrapped = true })
	new("UIStroke", l, { Color = C.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	return l
end
local function studs(n, t)
	local s = new("ImageLabel", n, { Name = "Studs", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxassetid://" .. UI.StudTexture,
		ImageTransparency = t, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(40, 40) })
	new("UICorner", s, { CornerRadius = UDim.new(0, 14) })
end
local function boton(parent, name, text, pos, size, color, ts)
	local sombra = new("Frame", parent, { Name = name .. "_Shadow", Position = pos + UDim2.fromOffset(0, 6), Size = size, BackgroundColor3 = C.ink,
		BackgroundTransparency = .1, BorderSizePixel = 0 })
	new("UICorner", sombra, { CornerRadius = UDim.new(0, 12) })
	local b = new("TextButton", parent, { Name = name, Text = "", Position = pos, Size = size, BackgroundColor3 = color, AutoButtonColor = true,
		BorderSizePixel = 0, ClipsDescendants = true })
	new("UICorner", b, { CornerRadius = UDim.new(0, 12) })
	new("UIStroke", b, { Color = C.ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	new("UIGradient", b, { Rotation = 90, Color = grad(color) })
	studs(b, .55)
	label(b, "Label", text, UDim2.new(), UDim2.fromScale(1, 1), ts or 24)
	return b, sombra
end

-- ------------------------------------------------------------------ cintas (como las de "DESTACADO" / "MÁS POPULAR")
local brillos = {}
local function cinta(parent, texto: string, color: Color3, centro: Vector2, ancho: number, rot: number?)
	local f = new("Frame", parent, { Name = "Cinta", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(centro.X, centro.Y),
		Size = UDim2.fromOffset(ancho, 30), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 6, Rotation = rot or 0, ClipsDescendants = true })
	new("UICorner", f, { CornerRadius = UDim.new(0, 10) })
	new("UIStroke", f, { Color = C.ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	new("UIGradient", f, { Rotation = 90, Color = ColorSequence.new(color:Lerp(C.white, .3), color:Lerp(C.ink, .15)) })
	local b = new("Frame", f, { Name = "Brillo", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 7 })
	table.insert(brillos, new("UIGradient", b, { Rotation = 20, Offset = Vector2.new(-1.5, 0), Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.4, 1), NumberSequenceKeypoint.new(.5, .45),
		NumberSequenceKeypoint.new(.6, 1), NumberSequenceKeypoint.new(1, 1) }) }))
	local l = label(f, "Texto", texto, UDim2.new(), UDim2.fromScale(1, 1), 19)
	l.ZIndex = 8
	return f
end
RunService.RenderStepped:Connect(function()
	if not shop.Visible and not gui.HUD.Visible then return end
	local k = (os.clock() % 2.6) / 1.1
	local off = Vector2.new(k <= 1 and (-1.5 + 3 * k) or 1.5, 0)
	for _, g in brillos do g.Offset = off end
end)
local function cintaSobre(card: GuiObject, texto: string, color: Color3)
	local p, s = card.Position, card.Size
	return cinta(body, texto, color, Vector2.new(p.X.Offset + s.X.Offset / 2, p.Y.Offset - 3), math.min(s.X.Offset - 30, 190))
end

-- ------------------------------------------------------------------ PASES: 4 tarjetas con el icono de cada pase
local PASES = {
	{ card = "Product_1", clave = "VIP", producto = "VIP", color = C.yellow, sub = "Tag, rastro y título VIP", cinta = { "DESTACADO", C.pink } },
	{ card = "Product_2", clave = "DOUBLE_COINS", producto = "2× COINS", color = C.purple, sub = "Doble de monedas", cinta = { "MÁS POPULAR", C.green } },
	{ card = "Product_3", clave = "DOUBLE_GEMS", producto = "2× GEMS", color = C.blue, sub = "Doble de gemas" },
	{ card = "Product_4", clave = "DOUBLE_XP", producto = "2× XP", color = C.orange, sub = "Doble de experiencia" },
}
local W, H, Y = 214, 266, 76
for i, p in PASES do
	local card = body:FindFirstChild(p.card)
	if not card then                                           -- 2× XP no estaba: copia de la tercera
		local base = body:FindFirstChild("Product_3")
		if not base then continue end
		card = base:Clone(); card.Name = p.card; card.Parent = body
		card.Action.Activated:Connect(function() action("Purchase", { product = p.producto }) end)
		local gift = card:FindFirstChild("Gift")
		if gift then gift.Activated:Connect(function() action("Open", "Gift") end) end
		card.Action:SetAttribute("Product", p.producto)
	end
	local info = Monet.Passes[p.clave]
	card.Position = UDim2.fromOffset(4 + (i - 1) * (W + 8), Y); card.Size = UDim2.fromOffset(W, H)
	card.BackgroundColor3 = p.color
	local g = card:FindFirstChildOfClass("UIGradient"); if g then g.Color = grad(p.color) end
	for _, c in card:GetChildren() do
		if c.Name == "Title" then c.Position = UDim2.fromOffset(10, 12); c.Size = UDim2.fromOffset(W - 20, 38); c.Text = info.DisplayName
		elseif c.Name:sub(1, 5) == "Icon_" then
			c.Image = info.Icon; c.Position = UDim2.fromOffset((W - 118) / 2, 48); c.Size = UDim2.fromOffset(118, 118)
		elseif c.Name == "Subtitle" then c.Visible = false                          -- ShopController le pone la descripción larga
		elseif c.Name == "InnerHighlight" then c.Size = UDim2.fromOffset(W - 8, H - 8)
		elseif c.Name == "Action" then c.Position = UDim2.fromOffset(13, H - 60); c.Size = UDim2.fromOffset(W - 26, 46)
		elseif c.Name == "Action_Shadow" then c.Position = UDim2.fromOffset(13, H - 54); c.Size = UDim2.fromOffset(W - 26, 46)
		elseif c.Name == "Gift" then c.Position = UDim2.fromOffset(W - 44, 46)
		elseif c.Name == "Gift_Shadow" then c.Position = UDim2.fromOffset(W - 44, 52) end
	end
	local sub = card:FindFirstChild("SubCorto") or label(card, "SubCorto", p.sub, UDim2.fromOffset(8, H - 96), UDim2.fromOffset(W - 16, 30), 19)
	sub.Text = p.sub
	-- precio (ShopController lo pone al cargar; el de la copia nueva, aquí)
	local owned = player:GetAttribute("HasPass_" .. p.clave) == true
	local txt = owned and "ADQUIRIDO" or ("R$ " .. info.PriceRobux)
	card.Action.Text = txt
	if card.Action:FindFirstChild("ButtonText") then card.Action.ButtonText.Text = txt end
	if p.cinta then cintaSobre(card, p.cinta[1], p.cinta[2]) end
end

-- ------------------------------------------------------------------ MONEDAS: precio e icono de cada producto
local packs = {}
for id, pack in Monet.Products.CoinPacks do packs[pack.Key] = pack end
local CINTAS_MONEDAS = { CoinPack_2 = { "MÁS POPULAR", C.pink }, CoinPack_3 = { "MEJOR PRECIO", C.orange } }
for key, pack in packs do
	local card = body:FindFirstChild(key)
	if not card then continue end
	local precio = "R$ " .. pack.PriceRobux
	if card:FindFirstChild("Action") then
		card.Action.Text = precio
		if card.Action:FindFirstChild("ButtonText") then card.Action.ButtonText.Text = precio end
	end
	for _, c in card:GetChildren() do if c.Name:sub(1, 5) == "Icon_" then c.Image = pack.Icon end end
	if CINTAS_MONEDAS[key] then cintaSobre(card, CINTAS_MONEDAS[key][1], CINTAS_MONEDAS[key][2]) end
end
local mejor = body:FindFirstChild("CoinPack_3")
if mejor and mejor:FindFirstChild("Subtitle") then mejor.Subtitle.Text = "¡×3 monedas por Robux!" end

-- ------------------------------------------------------------------ PACKS: Pack de Inicio
local SP = Monet.StarterPack
local secreto = body:FindFirstChild("SecretPack")
local rect = secreto and { secreto.Position, secreto.Size } or { UDim2.fromOffset(4, 639), UDim2.fromOffset(872, 270) }
if secreto then secreto.Visible = false end
local PW, PH = rect[2].X.Offset, rect[2].Y.Offset
local TEAL, VIOLETA = Color3.fromRGB(28, 190, 196), Color3.fromRGB(122, 64, 230)
local pack = new("Frame", body, { Name = "PackInicio", Position = rect[1], Size = rect[2], BackgroundColor3 = C.white, BorderSizePixel = 0, ClipsDescendants = true })
new("UICorner", pack, { CornerRadius = UDim.new(0, 16) })
new("UIStroke", pack, { Color = C.ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
new("UIGradient", pack, { Rotation = 25, Color = ColorSequence.new(TEAL, VIOLETA) })
studs(pack, .8)
local inner = new("Frame", pack, { Name = "InnerHighlight", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1 })
new("UICorner", inner, { CornerRadius = UDim.new(0, 13) }); new("UIStroke", inner, { Color = C.white, Thickness = 2, Transparency = .6 })
local t = label(pack, "Title", "PACK DE INICIO", UDim2.fromOffset(22, 18), UDim2.fromOffset(560, 44), 40)
t.TextXAlignment = Enum.TextXAlignment.Left
local s = label(pack, "Subtitle", "Empieza fuerte en ZERO · solo se puede comprar una vez", UDim2.fromOffset(22, 60), UDim2.fromOffset(560, 24), 19, Color3.fromRGB(220, 245, 255))
s.TextXAlignment = Enum.TextXAlignment.Left
-- icono grande con halo
local halo = new("Frame", pack, { Name = "Halo", Position = UDim2.fromOffset(20, 92), Size = UDim2.fromOffset(160, 160), BackgroundColor3 = C.white, BackgroundTransparency = .1 })
new("UICorner", halo, { CornerRadius = UDim.new(1, 0) })
new("UIGradient", halo, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .55), NumberSequenceKeypoint.new(.7, .9), NumberSequenceKeypoint.new(1, 1) }) })
new("ImageLabel", pack, { Name = "Icono", Image = "rbxassetid://" .. UI.Icons.pack, BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 96),
	Size = UDim2.fromOffset(146, 146), ScaleType = Enum.ScaleType.Fit })
-- contenido
local function fmt(n) local x = tostring(n); return (x:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")) end
local filas = {
	{ packs.CoinPack_1 and packs.CoinPack_1.Icon or "rbxassetid://" .. UI.Icons.coin1k, fmt(SP.Coins) .. " MONEDAS" },
	{ "rbxassetid://" .. (UI.Icons["crate_" .. ({ Comun = "common", Rara = "rare", Epica = "epic", Legendaria = "legendary" })[SP.Caja]] or UI.Icons.crate_common),
		({ Comun = "CAJA COMÚN", Rara = "CAJA RARA", Epica = "CAJA ÉPICA", Legendaria = "CAJA LEGENDARIA" })[SP.Caja] .. " (se abre al momento)" },
	{ "rbxassetid://" .. UI.Icons.wheel, SP.Spins .. " GIROS DE RULETA" },
}
for i, f in filas do
	local y = 90 + (i - 1) * 42
	new("ImageLabel", pack, { Name = "IconoFila" .. i, Image = f[1], BackgroundTransparency = 1, Position = UDim2.fromOffset(196, y),
		Size = UDim2.fromOffset(36, 36), ScaleType = Enum.ScaleType.Fit })
	local l = label(pack, "Fila" .. i, f[2], UDim2.fromOffset(240, y), UDim2.fromOffset(350, 36), 23)
	l.TextXAlignment = Enum.TextXAlignment.Left
end
local filaTitulo = label(pack, "FilaTitulo", "+ TÍTULO EXCLUSIVO", UDim2.fromOffset(196, 218), UDim2.fromOffset(210, 36), 21, Color3.fromRGB(170, 255, 235))
filaTitulo.TextXAlignment = Enum.TextXAlignment.Left
local defPionero = TitulosConfig.PorNombre[SP.Titulo]
if defPionero then Estilo.placa(pack, defPionero, { Size = UDim2.fromOffset(178, 40), Position = UDim2.fromOffset(404, 216), ZIndex = 3 }) end
-- precio
local panelPrecio = new("Frame", pack, { Name = "Precio", Position = UDim2.fromOffset(PW - 262, 70), Size = UDim2.fromOffset(240, 182),
	BackgroundColor3 = C.ink, BackgroundTransparency = .35, BorderSizePixel = 0 })
new("UICorner", panelPrecio, { CornerRadius = UDim.new(0, 14) })
new("UIStroke", panelPrecio, { Color = C.white, Thickness = 2, Transparency = .6 })
local valor = label(panelPrecio, "Valor", "VALOR R$ " .. SP.ValorRobux, UDim2.fromOffset(0, 12), UDim2.new(1, 0, 0, 28), 22, Color3.fromRGB(200, 210, 230))
new("Frame", valor, { Name = "Tachado", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.new(0, 150, 0, 3),
	BackgroundColor3 = C.pink, BorderSizePixel = 0, Rotation = -6 })
label(panelPrecio, "Unica", "COMPRA ÚNICA", UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 22), 18, C.yellow)
local comprar = boton(panelPrecio, "Comprar", "R$ " .. SP.PriceRobux, UDim2.fromOffset(14, 82), UDim2.fromOffset(212, 70), C.green, 34)
comprar.Activated:Connect(function() action("Purchase", { product = "StarterPack" }) end)
-- descuento y cinta
local pct = math.floor((1 - SP.PriceRobux / SP.ValorRobux) * 100 + .5)
local desc = new("Frame", pack, { Name = "Descuento", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(PW - 52, 56), Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = C.pink, Rotation = 12, ZIndex = 4 })
new("UICorner", desc, { CornerRadius = UDim.new(1, 0) })
new("UIStroke", desc, { Color = C.ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
new("UIGradient", desc, { Rotation = 90, Color = grad(C.pink) })
label(desc, "Texto", "-" .. pct .. "%", UDim2.new(), UDim2.fromScale(1, 1), 26).ZIndex = 5
cinta(body, "¡OFERTA DE BIENVENIDA!", C.pink, Vector2.new(rect[1].X.Offset + PW / 2, rect[1].Y.Offset - 3), 260)

local function estadoPack()
	local tiene = player:GetAttribute("PackInicio") == true
	comprar.Label.Text = tiene and "¡YA ES TUYO!" or ("R$ " .. SP.PriceRobux)
	comprar.Active = not tiene; comprar.AutoButtonColor = not tiene
	comprar.BackgroundColor3 = tiene and C.card or C.green
	comprar.UIGradient.Color = grad(comprar.BackgroundColor3)
	desc.Visible = not tiene
	local oferta = gui.HUD:FindFirstChild("Offers") and gui.HUD.Offers:FindFirstChild("Offer_1")
	if oferta then oferta.Visible = not tiene; local sh = oferta.Parent:FindFirstChild("Offer_1_Shadow"); if sh then sh.Visible = not tiene end end
end
player:GetAttributeChangedSignal("PackInicio"):Connect(estadoPack)

-- la pestaña PACKS y la oferta del HUD llevan al pack (un poco por encima, para que se vea la cinta)
local PACK_Y = rect[1].Y.Offset - 22
local tabPacks = body:FindFirstChild("Tab_Packs")
if tabPacks then tabPacks.Activated:Connect(function() task.defer(function() body.CanvasPosition = Vector2.new(0, PACK_Y) end) end) end
local oferta = gui.HUD:FindFirstChild("Offers") and gui.HUD.Offers:FindFirstChild("Offer_1")
if oferta then
	if oferta:FindFirstChild("Label") then oferta.Label.Text = "PACK INICIO" end
	oferta.Activated:Connect(function() task.defer(function() body.CanvasPosition = Vector2.new(0, PACK_Y) end) end)
	local chapa = new("Frame", oferta, { Name = "Chapa", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(98, 10), Size = UDim2.fromOffset(52, 26),
		BackgroundColor3 = C.pink, Rotation = 10, ZIndex = 6 })
	new("UICorner", chapa, { CornerRadius = UDim.new(0, 8) })
	new("UIStroke", chapa, { Color = C.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	label(chapa, "Texto", "-" .. pct .. "%", UDim2.new(), UDim2.fromScale(1, 1), 17).ZIndex = 7
	oferta.ClipsDescendants = false
end
estadoPack()
