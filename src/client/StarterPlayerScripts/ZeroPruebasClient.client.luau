-- ZeroPruebasClient (LocalScript, StarterPlayerScripts): botón PRUEBAS solo para admins (atributo ZeroAdmin que pone
-- ServerScriptService.ZeroPruebas). Te lleva a la ARENA DE PRUEBAS y, dentro, muestra un panel para elegir con qué arma
-- probar la habilidad E (sin cooldown), revivir los dummies y volver al lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if not player:GetAttribute("ZeroAdmin") then player:GetAttributeChangedSignal("ZeroAdmin"):Wait() end

local remote = ReplicatedStorage:WaitForChild("ZeroPruebas") :: RemoteFunction
local Habilidades = require(ReplicatedStorage:WaitForChild("ZeroHabilidadesConfig"))
local ArmasConfig = require(ReplicatedStorage:WaitForChild("ZeroArmasConfig"))

local FONDO, BORDE, TEXTO = Color3.fromRGB(22, 30, 58), Color3.fromRGB(90, 220, 255), Color3.new(1, 1, 1)
local TINTA = Color3.fromRGB(12, 18, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "ZeroPruebas"; gui.ResetOnSpawn = false; gui.DisplayOrder = 30; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function caja(padre: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = FONDO; f.BorderSizePixel = 0
	for k, v in props do (f :: any)[k] = v end
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = f
	local s = Instance.new("UIStroke"); s.Color = BORDE; s.Thickness = 2; s.Parent = f
	f.Parent = padre
	return f
end

local function boton(padre: Instance, texto: string, color: Color3, props): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color; b.AutoButtonColor = true; b.Text = texto; b.TextColor3 = TEXTO; b.TextScaled = true
	b.Font = Enum.Font.FredokaOne; b.BorderSizePixel = 0
	for k, v in props do (b :: any)[k] = v end
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = b
	local s = Instance.new("UIStroke"); s.Color = TINTA; s.Thickness = 2; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = b
	local st = Instance.new("UIStroke"); st.Color = TINTA; st.Thickness = 1.5; st.Parent = b
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 5); pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = b
	b.Parent = padre
	return b
end

-- aviso corto en la parte de arriba
local aviso = Instance.new("TextLabel")
aviso.AnchorPoint = Vector2.new(0.5, 0); aviso.Position = UDim2.new(0.5, 0, 0, 120); aviso.Size = UDim2.fromOffset(420, 34)
aviso.BackgroundTransparency = 1; aviso.Font = Enum.Font.FredokaOne; aviso.TextScaled = true; aviso.TextColor3 = Color3.fromRGB(255, 220, 90)
aviso.Visible = false; aviso.Parent = gui
local st = Instance.new("UIStroke"); st.Thickness = 2; st.Color = TINTA; st.Parent = aviso
local function avisar(msg: string)
	aviso.Text = msg; aviso.Visible = true
	task.delay(2.5, function() if aviso.Text == msg then aviso.Visible = false end end)
end

local function pedir(accion: string, dato: any?)
	local ok, res = pcall(function() return remote:InvokeServer(accion, dato) end)
	if not ok or type(res) ~= "table" then avisar("No se pudo conectar."); return false end
	if res.msg then avisar(res.msg) end
	return res.ok
end

-- botón principal (arriba a la derecha, debajo de Ajustes)
local principal = boton(gui, "PRUEBAS", Color3.fromRGB(46, 160, 220), {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 96), Size = UDim2.fromOffset(132, 44) })

-- panel de la arena (a la derecha de la columna de botones del HUD, centrado en vertical)
local panel = caja(gui, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.115, 0, 0.5, 0), Size = UDim2.fromOffset(270, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Visible = false })
local lista = Instance.new("UIListLayout"); lista.Padding = UDim.new(0, 6); lista.SortOrder = Enum.SortOrder.LayoutOrder; lista.Parent = panel
local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 10)
pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10); pad.Parent = panel
local orden = 0
local function siguiente() orden += 1; return orden end
local function etiqueta(texto: string, color: Color3, alto: number, padre: Instance?)
	local t = Instance.new("TextLabel"); t.LayoutOrder = siguiente(); t.Size = UDim2.new(1, 0, 0, alto); t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne; t.TextScaled = true; t.Text = texto; t.TextColor3 = color; t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = padre or panel
	local s = Instance.new("UIStroke"); s.Thickness = 1.5; s.Color = TINTA; s.Parent = t
end
etiqueta("ARENA DE PRUEBAS", BORDE, 26)
etiqueta("Clic = golpe · E = habilidad · sin cooldown", Color3.fromRGB(200, 210, 230), 18)

-- todas las armas (las que no tienen habilidad, solo clic), agrupadas por rareza, en una lista con scroll
local porRareza = {}
for _, a in ArmasConfig.Armas do
	porRareza[a.rareza] = porRareza[a.rareza] or {}
	table.insert(porRareza[a.rareza], a.nombre)
end
local listaArmas = Instance.new("ScrollingFrame"); listaArmas.LayoutOrder = siguiente(); listaArmas.Size = UDim2.new(1, 0, 0, 380)
listaArmas.BackgroundTransparency = 1; listaArmas.BorderSizePixel = 0; listaArmas.ScrollBarThickness = 6
listaArmas.CanvasSize = UDim2.new(); listaArmas.AutomaticCanvasSize = Enum.AutomaticSize.Y; listaArmas.Parent = panel
local listaL = Instance.new("UIListLayout"); listaL.Padding = UDim.new(0, 5); listaL.SortOrder = Enum.SortOrder.LayoutOrder; listaL.Parent = listaArmas
local listaP = Instance.new("UIPadding"); listaP.PaddingRight = UDim.new(0, 10); listaP.Parent = listaArmas
local rarezas = {}
for clave in porRareza do table.insert(rarezas, clave) end
table.sort(rarezas, function(x, y) return (ArmasConfig.Rarezas[x] and ArmasConfig.Rarezas[x].orden or 0) < (ArmasConfig.Rarezas[y] and ArmasConfig.Rarezas[y].orden or 0) end)
local botonesArma: { [string]: TextButton } = {}
for _, clave in rarezas do
	local r = ArmasConfig.Rarezas[clave]
	etiqueta(r and r.nombre or clave, r and r.color or TEXTO, 20, listaArmas)
	for _, nombre in porRareza[clave] do
		local b = boton(listaArmas, nombre, Color3.fromRGB(40, 52, 92), { LayoutOrder = siguiente(), Size = UDim2.new(1, 0, 0, 30) })
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Activated:Connect(function() pedir("arma", nombre) end)
		botonesArma[nombre] = b
	end
end
local revivir = boton(panel, "REVIVIR DUMMIES", Color3.fromRGB(70, 190, 120), { LayoutOrder = siguiente(), Size = UDim2.new(1, 0, 0, 36) })
local volver = boton(panel, "VOLVER AL LOBBY", Color3.fromRGB(230, 90, 90), { LayoutOrder = siguiente(), Size = UDim2.new(1, 0, 0, 36) })
revivir.Activated:Connect(function() if pedir("revivir") then avisar("Dummies listos.") end end)
volver.Activated:Connect(function() pedir("volver") end)

local function pintar()
	local dentro = player:GetAttribute("ZeroPruebas") == true
	panel.Visible = dentro
	principal.Text = if dentro then "SALIR" else "PRUEBAS"
	principal.BackgroundColor3 = if dentro then Color3.fromRGB(230, 90, 90) else Color3.fromRGB(46, 160, 220)
	local elegida = player:GetAttribute("ZeroPruebaArma")
	for nombre, b in botonesArma do
		local si = nombre == elegida
		b.BackgroundColor3 = if si then Color3.fromRGB(46, 160, 220) else Color3.fromRGB(40, 52, 92)
		b.Text = (if si then "▶ " else "") .. nombre .. (if Habilidades.Skins[nombre] then "" else " (solo clic)")
	end
end
principal.Activated:Connect(function()
	pedir(if player:GetAttribute("ZeroPruebas") then "volver" else "ir")
end)
-- el panel va pegado a la derecha de la columna de botones del HUD (ZeroUI.HUD.Navigation), que escala según la pantalla
task.spawn(function()
	local nav = player.PlayerGui:WaitForChild("ZeroUI"):WaitForChild("HUD"):WaitForChild("Navigation") :: GuiObject
	local function colocar()
		panel.Position = UDim2.new(0, nav.AbsolutePosition.X + nav.AbsoluteSize.X + 14, 0.5, 0)
	end
	nav:GetPropertyChangedSignal("AbsoluteSize"):Connect(colocar)
	nav:GetPropertyChangedSignal("AbsolutePosition"):Connect(colocar)
	colocar()
end)
player:GetAttributeChangedSignal("ZeroPruebas"):Connect(pintar)
player:GetAttributeChangedSignal("ZeroPruebaArma"):Connect(pintar)
pintar()
