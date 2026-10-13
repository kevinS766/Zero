-- ZeroEconomiaClient (LocalScript, StarterPlayerScripts): aviso de lo ganado al acabar cada ronda y al subir de nivel
-- (lo manda ZeroEconomiaServer): tarjeta abajo en el centro con el total, el desglose y los multiplicadores.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local aviso = ReplicatedStorage:WaitForChild("ZeroEconomiaAviso") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "ZeroEconomiaAviso"; gui.ResetOnSpawn = false; gui.DisplayOrder = 30; gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
end

local cola, mostrando = {}, false
local function mostrar(d)
	mostrando = true
	local alto = 64 + (d.detalle and #d.detalle * 22 or 0) + (d.notas and d.notas ~= "" and 22 or 0)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 1); f.Position = UDim2.new(0.5, 0, 1, alto + 20); f.Size = UDim2.fromOffset(330, alto)
	f.BackgroundColor3 = Color3.fromRGB(24, 28, 52); f.BackgroundTransparency = 0.1; f.Parent = gui
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
	local st = Instance.new("UIStroke", f); st.Color = Color3.fromRGB(255, 214, 74); st.Thickness = 3
	local function linea(texto: string, y: number, tam: number, color: Color3, alin)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1; l.Font = Enum.Font.FredokaOne; l.Text = texto; l.TextSize = tam; l.TextColor3 = color
		l.Position = UDim2.fromOffset(14, y); l.Size = UDim2.new(1, -28, 0, tam + 4); l.TextXAlignment = alin or Enum.TextXAlignment.Center
		l.Parent = f
		return l
	end
	local titulo = if d.motivo == "nivel" then "¡SUBISTE DE NIVEL!" else "RONDA TERMINADA"
	linea(titulo, 8, 18, Color3.fromRGB(200, 210, 255))
	local giros = if d.giros and d.giros > 0 then "  +" .. d.giros .. (d.giros == 1 and " GIRO" or " GIROS") else ""
	linea("+" .. fmt(d.monedas) .. " MONEDAS" .. giros, 30, 26, Color3.fromRGB(150, 255, 83))
	local y = 64
	for _, p in d.detalle or {} do
		if d.motivo == "nivel" then break end
		local l = linea(p[1], y, 16, Color3.fromRGB(230, 234, 255), Enum.TextXAlignment.Left)
		local v = linea("+" .. fmt(p[2]), y, 16, Color3.fromRGB(255, 214, 74), Enum.TextXAlignment.Right)
		y += 22
		_ = l; _ = v
	end
	if d.notas and d.notas ~= "" then linea(d.notas, y, 15, Color3.fromRGB(255, 160, 220)) end
	TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -110) }):Play()
	task.delay(3.6, function()
		local t = TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 1, alto + 20) })
		t:Play(); t.Completed:Wait(); f:Destroy()
		mostrando = false
		local sig = table.remove(cola, 1)
		if sig then mostrar(sig) end
	end)
end

aviso.OnClientEvent:Connect(function(d)
	if mostrando then table.insert(cola, d) else mostrar(d) end
end)
