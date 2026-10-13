--!strict
-- CooldownHUD: recargas del corredor. El dash tiene TRES recargas (DashConfig.COOLDOWNS): a los lados (la más corta),
-- atrás y adelante (la más larga); cada una con su barra. Una esquiva perfecta recarga al momento el dash usado.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))
local DashConfig = require(Shared:WaitForChild("Config"):WaitForChild("DashConfig")) :: any

local CooldownHUD = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local dashFeedbackEvent: RemoteEvent = NetworkEvents.getRemoteEvent("DashExecute")
local hunterAbilityFeedbackEvent: RemoteEvent = NetworkEvents.getRemoteEvent("HunterAbilityFeedback")
local cazadorListo = 0                 -- habilidad F del cazador (HunterAbilityController pregunta isReady)

local TIPOS = { { clave = "Lados", texto = "◀▶ LADOS" }, { clave = "Frente", texto = "▲ FRENTE" }, { clave = "Atras", texto = "▼ ATRÁS" } }
local COLOR = Color3.fromRGB(0, 195, 255)
local LISTO = Color3.fromRGB(90, 225, 120)

local screenGui: ScreenGui
local mainContainer: Frame
local barras: { [string]: { fill: Frame, estado: TextLabel, tween: Tween?, hilo: thread?, activo: boolean } } = {}

local function buildInterface()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CooldownHUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui

	mainContainer = Instance.new("Frame")
	mainContainer.Name = "MainContainer"
	mainContainer.AnchorPoint = Vector2.new(0.5, 1)
	mainContainer.Position = UDim2.new(0.5, 0, 1, -30)
	mainContainer.Size = UDim2.new(0, 360, 0, 50)
	mainContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	mainContainer.BackgroundTransparency = 0.25
	mainContainer.BorderSizePixel = 0
	mainContainer.Visible = false
	mainContainer.Parent = screenGui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = mainContainer
	local stroke = Instance.new("UIStroke"); stroke.Thickness = 1.5; stroke.Color = Color3.fromRGB(50, 50, 65); stroke.Parent = mainContainer

	local titulo = Instance.new("TextLabel")
	titulo.Position = UDim2.new(0, 10, 0, 0); titulo.Size = UDim2.new(0, 54, 1, 0); titulo.BackgroundTransparency = 1
	titulo.Font = Enum.Font.GothamBold; titulo.TextSize = 13; titulo.TextColor3 = Color3.fromRGB(240, 240, 245)
	titulo.Text = "DASH\n[Q]"; titulo.TextXAlignment = Enum.TextXAlignment.Left; titulo.Parent = mainContainer

	for i, t in TIPOS do
		local col = Instance.new("Frame")
		col.BackgroundTransparency = 1; col.Position = UDim2.new(0, 64 + (i - 1) * 96, 0, 6); col.Size = UDim2.new(0, 88, 1, -12)
		col.Parent = mainContainer
		local nombre = Instance.new("TextLabel")
		nombre.Size = UDim2.new(0.62, 0, 0, 16); nombre.BackgroundTransparency = 1; nombre.Font = Enum.Font.GothamBold; nombre.TextSize = 11
		nombre.TextColor3 = Color3.fromRGB(210, 215, 230); nombre.TextXAlignment = Enum.TextXAlignment.Left; nombre.Text = t.texto; nombre.Parent = col
		local estado = Instance.new("TextLabel")
		estado.Position = UDim2.new(0.62, 0, 0, 0); estado.Size = UDim2.new(0.38, 0, 0, 16); estado.BackgroundTransparency = 1
		estado.Font = Enum.Font.GothamBold; estado.TextSize = 11; estado.TextColor3 = LISTO; estado.TextXAlignment = Enum.TextXAlignment.Right
		estado.Text = "LISTO"; estado.Parent = col
		local fondo = Instance.new("Frame")
		fondo.Position = UDim2.new(0, 0, 0, 22); fondo.Size = UDim2.new(1, 0, 0, 10); fondo.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		fondo.BorderSizePixel = 0; fondo.ClipsDescendants = true; fondo.Parent = col
		local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0, 5); c1.Parent = fondo
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(1, 0, 1, 0); fill.BackgroundColor3 = COLOR; fill.BorderSizePixel = 0; fill.Parent = fondo
		local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0, 5); c2.Parent = fill
		barras[t.clave] = { fill = fill, estado = estado, activo = false }
	end
end

local function parar(b)
	if b.tween then b.tween:Cancel(); b.tween = nil end
	if b.hilo then task.cancel(b.hilo); b.hilo = nil end
	b.activo = false
end

local function listo(b)
	parar(b)
	b.fill.Size = UDim2.new(1, 0, 1, 0)
	b.estado.Text = "LISTO"; b.estado.TextColor3 = LISTO
end

-- tipo: "Lados" | "Frente" | "Atras" (sin tipo: el de adelante)
function CooldownHUD.startCooldown(duration: number, tipo: string?)
	local b = barras[tipo or "Frente"]
	if not b then return end
	parar(b)
	b.activo = true
	b.fill.Size = UDim2.new(0, 0, 1, 0)
	b.estado.TextColor3 = Color3.fromRGB(255, 180, 60)
	b.tween = TweenService:Create(b.fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 1, 0) })
	b.tween:Play()
	b.hilo = task.spawn(function()
		local fin = os.clock() + duration
		while os.clock() < fin do
			b.estado.Text = string.format("%.1fs", fin - os.clock())
			task.wait(0.1)
		end
		b.hilo = nil
		listo(b)
	end)
end

-- esquiva perfecta: ese dash vuelve a estar listo
function CooldownHUD.reset(tipo: string)
	local b = barras[tipo]
	if b then listo(b) end
end

function CooldownHUD.isReady(): boolean
	if localPlayer:GetAttribute("Role") == "Hunter" then return os.clock() >= cazadorListo end
	for _, b in barras do if not b.activo then return true end end
	return false
end

local function updateRoleDisplay(role: string?)
	for _, b in barras do listo(b) end
	mainContainer.Visible = role == "Runner"   -- el Hunter ya tiene el botón de habilidad de la derecha (F • CLASE)
end

function CooldownHUD.init()
	buildInterface()
	dashFeedbackEvent.OnClientEvent:Connect(function(data: any)
		if localPlayer:GetAttribute("Role") == "Runner" and not data.extra then
			CooldownHUD.startCooldown(data.cooldown, data.tipo)
		end
	end)
	task.spawn(function()
		local jugadas = ReplicatedStorage:WaitForChild("ZeroJugadas") :: RemoteEvent
		jugadas.OnClientEvent:Connect(function(d: any)
			if d.kind == "DashReset" then CooldownHUD.reset(d.tipo) end
		end)
	end)
	hunterAbilityFeedbackEvent.OnClientEvent:Connect(function(data: any)
		if data.success then cazadorListo = os.clock() + (data.cooldown or 0) end
	end)
	localPlayer:GetAttributeChangedSignal("Role"):Connect(function()
		updateRoleDisplay(localPlayer:GetAttribute("Role"))
	end)
	updateRoleDisplay(localPlayer:GetAttribute("Role"))
end

return CooldownHUD
