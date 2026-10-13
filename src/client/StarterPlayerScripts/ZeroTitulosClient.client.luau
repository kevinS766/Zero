-- ZeroTitulosClient (LocalScript, StarterPlayerScripts): títulos de ZERO en el cliente.
--  · Placa sobre la cabeza de cada personaje (jugadores y bots): el título animado (atributo ZeroTitulo del jugador,
--    lo pone ZeroMisionesServer) encima del nombre. Sustituye al nombre de Roblox en este cliente.
--  · Menú TÍTULOS (panel "Titulos" de ZeroUI, se abre desde la pestaña TÍTULOS del Inventario): todos los títulos con su
--    objetivo y progreso; RECLAMAR, USAR y QUITAR van a ZeroMisionesRequest (ReclamarTitulo / UsarTitulo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("ZeroTitulosConfig"))
local Estilo = require(ReplicatedStorage:WaitForChild("ZeroTitulosEstilo"))
local UI = require(ReplicatedStorage:WaitForChild("ZeroUI"))
local C = UI.Colors

local function new(class, parent, props)
	local n = Instance.new(class)
	for k, v in props or {} do n[k] = v end
	n.Parent = parent
	return n
end
local function label(parent, name, text, pos, size, ts, color)
	local l = new("TextLabel", parent, { Name = name, Text = text, Position = pos, Size = size, BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne, TextSize = ts, TextColor3 = color or C.white, TextWrapped = true })
	new("UIStroke", l, { Color = C.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	return l
end

-- ================================================================== placas sobre la cabeza
local placas = setmetatable({}, { __mode = "k" })     -- personaje -> BillboardGui
local function nombreDe(character: Model, h: Humanoid): string
	local p = Players:GetPlayerFromCharacter(character)
	return p and p.DisplayName or h.DisplayName
end
local function pintarTitulo(bb: BillboardGui, titulo: string?)
	local old = bb:FindFirstChild("Titulo_" .. (bb:GetAttribute("Titulo") or ""))
	if bb:GetAttribute("Titulo") == (titulo or "") and (old or not titulo) then return end
	for _, c in bb:GetChildren() do if c.Name:sub(1, 7) == "Titulo_" then c:Destroy() end end
	bb:SetAttribute("Titulo", titulo or "")
	local def = titulo and Config.PorNombre[titulo]
	if def then Estilo.placa(bb, def, { Size = UDim2.fromScale(0.72, 0.5), Position = UDim2.fromScale(0.5, 0.02), AnchorPoint = Vector2.new(0.5, 0), sinDestellos = true }) end
end
local function montar(character: Model)
	local h = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not h or not head or placas[character] then return end
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None       -- el nombre lo pone la placa
	-- tamaño en studs (encoge con la distancia); la de tu propio personaje, más pequeña para no tapar la vista
	local propio = character == player.Character
	local bb = new("BillboardGui", nil, { Name = "ZeroPlaca", Size = propio and UDim2.fromScale(3.4, 1) or UDim2.fromScale(4.4, 1.3),
		StudsOffset = Vector3.new(0, propio and 1.9 or 2.15, 0),
		MaxDistance = 90, LightInfluence = 0, ResetOnSpawn = false })
	local n = new("TextLabel", bb, { Name = "Nombre", Text = nombreDe(character, h), BackgroundTransparency = 1, TextScaled = true,
		Font = Enum.Font.FredokaOne, TextColor3 = C.white, Position = UDim2.fromScale(0.05, 0.56), Size = UDim2.fromScale(0.9, 0.4) })
	new("UIStroke", n, { Color = C.ink, Thickness = 2 })
	bb.Adornee = head; bb.Parent = head
	placas[character] = bb
	local p = Players:GetPlayerFromCharacter(character)
	if p then
		pintarTitulo(bb, p:GetAttribute("ZeroTitulo"))
		local con = p:GetAttributeChangedSignal("ZeroTitulo"):Connect(function() pintarTitulo(bb, p:GetAttribute("ZeroTitulo")) end)
		bb.Destroying:Connect(function() con:Disconnect() end)
		p:GetPropertyChangedSignal("DisplayName"):Connect(function() n.Text = p.DisplayName end)
	end
	-- la etiqueta de rol de las rondas ([HUNTER], [CONGELADO]…) sube por encima de la placa
	local function subirRol(c) if c:IsA("BillboardGui") and c.Name == "RoleBillboard" then c.StudsOffset = Vector3.new(0, 4.6, 0) end end
	for _, c in head:GetChildren() do subirRol(c) end
	head.ChildAdded:Connect(subirRol)
end
local function vigilarJugador(p: Player)
	p.CharacterAdded:Connect(function(ch) task.spawn(montar, ch) end)
	if p.Character then task.spawn(montar, p.Character) end
end
for _, p in Players:GetPlayers() do vigilarJugador(p) end
Players.PlayerAdded:Connect(vigilarJugador)

-- primera persona: tus etiquetas sobre la cabeza (placa, [ROL]…) se esconden para ti y no tapan la vista
local ocultasPP: { [BillboardGui]: boolean } = {}
game:GetService("RunService").RenderStepped:Connect(function()
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head then return end
	local primera = (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude < 1.6
	for _, bb in head:GetChildren() do
		if bb:IsA("BillboardGui") then
			if primera and bb.Enabled then bb.Enabled = false; ocultasPP[bb] = true
			elseif not primera and ocultasPP[bb] then bb.Enabled = true; ocultasPP[bb] = nil end
		end
	end
end)
local function vigilarBots(folder)
	folder.ChildAdded:Connect(function(ch) if ch:IsA("Model") then task.spawn(montar, ch) end end)
	for _, ch in folder:GetChildren() do if ch:IsA("Model") then task.spawn(montar, ch) end end
end
if workspace:FindFirstChild("ZeroBots") then vigilarBots(workspace.ZeroBots) end
workspace.ChildAdded:Connect(function(c) if c.Name == "ZeroBots" then vigilarBots(c) end end)

-- ================================================================== menú TÍTULOS
local request = ReplicatedStorage:WaitForChild("ZeroMisionesRequest") :: RemoteFunction
local estadoEv = ReplicatedStorage:WaitForChild("ZeroMisionesEstado") :: RemoteEvent
local gui = player:WaitForChild("PlayerGui"):WaitForChild("ZeroUI")
gui:WaitForChild("UIAction")
local modal = gui.Modal
local function action(name, payload) pcall(function() gui.UIAction:Invoke(name, payload) end) end
local function notify(msg)
	local t = gui:FindFirstChild("Toast")
	if t then t.Message.Text = msg; t.Visible = true; task.delay(3.5, function() if t.Message.Text == msg then t.Visible = false end end) end
end

-- panel: copia del de STATS con otra cabecera
local base = modal:WaitForChild("Stats")
local panel = base:Clone(); panel.Name = "Titulos"; panel.Visible = false; panel.Parent = modal
local baseSombra = modal:FindFirstChild("Stats_Shadow")
if baseSombra then local sh = baseSombra:Clone(); sh.Name = "Titulos_Shadow"; sh.Visible = false; sh.ZIndex = 0; sh.Parent = modal end   -- detrás del panel
if not table.find(UI.MenuOrder, "Titulos") then table.insert(UI.MenuOrder, "Titulos") end
local header = panel.Header
header.BackgroundColor3 = C.purple
local hg = header:FindFirstChildOfClass("UIGradient"); if hg then hg.Color = ColorSequence.new(C.purple:Lerp(C.white, .22), C.purple:Lerp(C.ink, .12)) end
header.Title.Text = "TÍTULOS"
for _, c in header:GetChildren() do if c:IsA("ImageLabel") and c.Name:sub(1, 5) == "Icon_" then c.Image = "rbxassetid://" .. UI.Icons.vip end end
header.Close.Activated:Connect(function() action("Close") end)
local body = panel.Body
for _, c in body:GetChildren() do if not c:IsA("UIBase") then c:Destroy() end end
body.CanvasSize = UDim2.new(); body.AutomaticCanvasSize = Enum.AutomaticSize.Y

-- cabecera del cuerpo: tu placa tal como la ven los demás
local top = new("Frame", body, { Name = "TuPlaca", Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(872, 128), BackgroundColor3 = C.card, BorderSizePixel = 0 })
new("UICorner", top, { CornerRadius = UDim.new(0, 14) }); new("UIStroke", top, { Color = C.ink, Thickness = 3 })
label(top, "Etiqueta", "ASÍ TE VEN LOS DEMÁS", UDim2.fromOffset(18, 10), UDim2.fromOffset(330, 26), 20, C.muted).TextXAlignment = Enum.TextXAlignment.Left
local vista = new("Frame", top, { Name = "Vista", Position = UDim2.fromOffset(18, 40), Size = UDim2.fromOffset(330, 80), BackgroundTransparency = 1 })
local vistaNombre = label(vista, "Nombre", player.DisplayName, UDim2.fromOffset(0, 50), UDim2.fromOffset(330, 30), 26)
local contador = label(top, "Contador", "", UDim2.fromOffset(380, 18), UDim2.fromOffset(250, 40), 30, C.yellow)
label(top, "ContadorTexto", "títulos conseguidos", UDim2.fromOffset(380, 56), UDim2.fromOffset(250, 26), 19, C.muted)
local quitar = new("TextButton", top, { Name = "Quitar", Text = "QUITAR TÍTULO", Font = Enum.Font.FredokaOne, TextSize = 22, TextColor3 = C.white,
	Position = UDim2.fromOffset(660, 36), Size = UDim2.fromOffset(196, 56), BackgroundColor3 = C.pink, AutoButtonColor = true })
new("UICorner", quitar, { CornerRadius = UDim.new(0, 12) }); new("UIStroke", quitar, { Color = C.ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
new("UIStroke", quitar, { Color = C.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
local grid = new("Frame", body, { Name = "Lista", Position = UDim2.fromOffset(0, 142), Size = UDim2.fromOffset(880, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
new("UIGridLayout", grid, { CellSize = UDim2.fromOffset(282, 196), CellPadding = UDim2.fromOffset(13, 14), SortOrder = Enum.SortOrder.LayoutOrder })
new("UIPadding", grid, { PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 16) })

local estado: any = nil
local ocupado = false
local function pedir(accion, payload)
	if ocupado then return end
	ocupado = true
	local ok, res = pcall(function() return request:InvokeServer(accion, payload) end)
	ocupado = false
	if ok and type(res) == "table" and res.message then notify(res.message) end
end
quitar.Activated:Connect(function() pedir("UsarTitulo", {}) end)

local function boton(parent, texto, color, activo, fn)
	local b = new("TextButton", parent, { Name = "Accion", Text = texto, Font = Enum.Font.FredokaOne, TextSize = 21, TextColor3 = C.white,
		Position = UDim2.new(0, 12, 1, -50), Size = UDim2.new(1, -24, 0, 40), BackgroundColor3 = color, AutoButtonColor = activo, Active = activo })
	new("UICorner", b, { CornerRadius = UDim.new(0, 10) }); new("UIStroke", b, { Color = C.ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	new("UIStroke", b, { Color = C.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	new("UIGradient", b, { Rotation = 90, Color = ColorSequence.new(color:Lerp(C.white, .2), color:Lerp(C.ink, .15)) })
	if activo and fn then b.Activated:Connect(fn) end
	return b
end

local function fmt(n) local x = tostring(math.floor(n)); return (x:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")) end
local function tarjeta(def, info, puesto: boolean, orden: number)
	local rar = Config.Rarezas[def.rareza]
	local listo = not info.tiene and info.valor >= info.meta
	local c = new("Frame", grid, { Name = def.nombre, LayoutOrder = orden, BackgroundColor3 = C.card, BorderSizePixel = 0, ClipsDescendants = true })
	new("UICorner", c, { CornerRadius = UDim.new(0, 14) })
	new("UIStroke", c, { Color = puesto and C.yellow or listo and C.green or rar.color:Lerp(C.ink, .35), Thickness = puesto and 4 or 3 })
	new("UIGradient", c, { Rotation = 90, Color = ColorSequence.new(rar.color:Lerp(C.card, .72), C.card:Lerp(C.ink, .35)) })
	-- rareza
	local r = new("Frame", c, { Name = "Rareza", Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(112, 22), BackgroundColor3 = rar.color, BorderSizePixel = 0 })
	new("UICorner", r, { CornerRadius = UDim.new(0, 7) })
	label(r, "Texto", rar.nombre, UDim2.new(), UDim2.fromScale(1, 1), 15)
	if puesto then label(c, "EnUso", "EN USO", UDim2.new(1, -100, 0, 9), UDim2.fromOffset(90, 22), 17, C.yellow) end
	-- la placa (apagada mientras no es tuya)
	local placa = Estilo.placa(c, def, { Size = UDim2.fromOffset(236, 48), Position = UDim2.fromOffset(23, 40) })
	if not info.tiene then
		local velo = new("Frame", c, { Name = "Velo", Position = placa.Position, Size = placa.Size, BackgroundColor3 = C.ink, BackgroundTransparency = listo and 1 or .45, ZIndex = 5 })
		new("UICorner", velo, { CornerRadius = UDim.new(0.3, 0) })
		if not listo then label(velo, "Candado", "🔒", UDim2.new(1, -34, 0, -10), UDim2.fromOffset(30, 30), 22).ZIndex = 6 end
	end
	label(c, "Objetivo", def.texto, UDim2.fromOffset(10, 94), UDim2.new(1, -20, 0, 24), 17, C.muted)
	-- progreso
	local track = new("Frame", c, { Name = "Barra", Position = UDim2.fromOffset(14, 122), Size = UDim2.new(1, -28, 0, 14), BackgroundColor3 = C.ink, BorderSizePixel = 0 })
	new("UICorner", track, { CornerRadius = UDim.new(1, 0) })
	local k = math.clamp(info.valor / math.max(info.meta, 1), 0, 1)
	local fill = new("Frame", track, { Name = "Fill", Size = UDim2.fromScale(k, 1), BackgroundColor3 = info.tiene and C.yellow or rar.color, BorderSizePixel = 0 })
	new("UICorner", fill, { CornerRadius = UDim.new(1, 0) })
	local txt = def.req.atributo and (info.tiene and "CONSEGUIDO" or (info.valor >= 1 and "LISTO" or "EN LA TIENDA"))
		or (fmt(info.valor) .. " / " .. fmt(info.meta))
	label(track, "Texto", txt, UDim2.fromOffset(0, -1), UDim2.fromScale(1, 1), 13).ZIndex = 3
	-- acción
	if puesto then boton(c, "QUITAR", C.pink, true, function() pedir("UsarTitulo", {}) end)
	elseif info.tiene then boton(c, "USAR", C.blue, true, function() pedir("UsarTitulo", { titulo = def.nombre }) end)
	elseif listo then boton(c, "¡RECLAMAR!", C.green, true, function() pedir("ReclamarTitulo", { titulo = def.nombre }) end)
	elseif def.req.atributo then boton(c, "VER EN TIENDA", C.purple, true, function() action("Open", "Shop") end)
	else boton(c, "BLOQUEADO", Color3.fromRGB(70, 82, 110), false) end
end

-- aviso "!" en el botón del Inventario y en la pestaña TÍTULOS
local function chapa(parent: GuiObject?, n: number)
	if not parent then return end
	local b = parent:FindFirstChild("ChapaTitulos")
	if n <= 0 then if b then b:Destroy() end; return end
	if not b then
		b = new("Frame", parent, { Name = "ChapaTitulos", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = C.pink, ZIndex = 20 })
		new("UICorner", b, { CornerRadius = UDim.new(1, 0) }); new("UIStroke", b, { Color = C.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		label(b, "N", "", UDim2.new(), UDim2.fromScale(1, 1), 17).ZIndex = 21
		parent.ClipsDescendants = false
	end
	b.N.Text = tostring(n)
end

local tabTitulos: GuiObject? = nil
local listosAntes = nil
local function pintar()
	if not estado or not estado.titulosInfo then return end
	for _, c in grid:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	local puesto = estado.titulo
	local tiene, listos = 0, 0
	local filas = {}
	for _, info in estado.titulosInfo do
		local def = Config.PorNombre[info.nombre]
		if def then
			if info.tiene then tiene += 1 elseif info.valor >= info.meta then listos += 1 end
			table.insert(filas, { def = def, info = info })
		end
	end
	-- orden: puesto, para reclamar, tuyos, y el resto por rareza
	local function peso(f)
		if f.def.nombre == puesto then return 0 end
		if not f.info.tiene and f.info.valor >= f.info.meta then return 1 end
		if f.info.tiene then return 2 end
		return 3
	end
	table.sort(filas, function(a, b)
		local pa, pb = peso(a), peso(b)
		if pa ~= pb then return pa < pb end
		local ra, rb = Config.Rarezas[a.def.rareza].orden, Config.Rarezas[b.def.rareza].orden
		if ra ~= rb then return ra < rb end
		return a.def.orden < b.def.orden
	end)
	for i, f in filas do tarjeta(f.def, f.info, f.def.nombre == puesto, i) end
	contador.Text = tiene .. " / " .. #filas
	for _, c in vista:GetChildren() do if c.Name:sub(1, 7) == "Titulo_" then c:Destroy() end end
	local def = puesto and Config.PorNombre[puesto]
	if def then Estilo.placa(vista, def, { Size = UDim2.fromOffset(250, 46), Position = UDim2.fromOffset(40, 0) })
	else
		local nada = vista:FindFirstChild("SinTitulo") or label(vista, "SinTitulo", "(sin título)", UDim2.fromOffset(40, 6), UDim2.fromOffset(250, 36), 20, C.muted)
		nada.Visible = true
	end
	if vista:FindFirstChild("SinTitulo") then vista.SinTitulo.Visible = def == nil end
	quitar.Visible = def ~= nil
	-- avisos
	local nav = gui.HUD:FindFirstChild("Navigation")
	chapa(nav and nav:FindFirstChild("Open_Classes"), listos)
	chapa(tabTitulos, listos)
	if listosAntes and listos > listosAntes then notify("¡Tienes un título nuevo para reclamar! Inventario → TÍTULOS") end
	listosAntes = listos
end
vistaNombre.Text = player.DisplayName
estadoEv.OnClientEvent:Connect(function(e) estado = e; pintar() end)
task.spawn(function()
	for _ = 1, 20 do
		local ok, res = pcall(function() return request:InvokeServer("Estado", {}) end)
		if ok and type(res) == "table" and res.estado then estado = res.estado; pintar(); return end
		task.wait(1.5)
	end
end)

-- pestaña TÍTULOS en el Inventario (junto a CLASES y ARMAS de ZeroArmasClient)
task.spawn(function()
	local inv = modal:WaitForChild("Classes"):WaitForChild("Body")
	local armas = inv:WaitForChild("Tab_MisArmas", 30)
	if not armas then return end
	local W = 430                                          -- ARMAS y TÍTULOS (la pestaña CLASES ya no existe)
	for i, name in { "Tab_MisArmas" } do
		for _, o in { inv:FindFirstChild(name), inv:FindFirstChild(name .. "_Shadow") } do
			if o then o.Size = UDim2.fromOffset(W, o.Size.Y.Offset); o.Position = UDim2.fromOffset(4 + (i - 1) * (W + 9), o.Position.Y.Offset) end
		end
	end
	local t = armas:Clone(); t.Name = "Tab_Titulos"; t.Parent = inv
	t.Position = UDim2.fromOffset(4 + (W + 12), armas.Position.Y.Offset); t.Size = UDim2.fromOffset(W, armas.Size.Y.Offset)
	t.BackgroundColor3 = C.yellow
	local g = t:FindFirstChildOfClass("UIGradient"); if g then g.Color = ColorSequence.new(C.yellow:Lerp(C.white, .22), C.yellow:Lerp(C.ink, .12)) end
	local l = t:FindFirstChild("Label"); if l then l.Text = "TÍTULOS" end
	t.Activated:Connect(function() action("Open", "Titulos") end)
	tabTitulos = t
	pintar()
end)
