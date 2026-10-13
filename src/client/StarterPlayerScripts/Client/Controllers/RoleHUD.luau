--!strict
local Players = game:GetService("Players")

local RoleHUD = {}

function RoleHUD.init()
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	-- Crear ScreenGui si no existe
	local screenGui = playerGui:FindFirstChild("RoleHUD") :: ScreenGui?
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "RoleHUD"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.Parent = playerGui
	end

	-- Contenedor del banner en la parte superior central
	local banner = screenGui:FindFirstChild("Banner") :: Frame?
	if not banner then
		banner = Instance.new("Frame")
		banner.Name = "Banner"
		banner.AnchorPoint = Vector2.new(0.5, 0)
		banner.Position = UDim2.new(0.5, 0, 0, 16)
		banner.Size = UDim2.new(0, 320, 0, 48)
		banner.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
		banner.BackgroundTransparency = 0.25
		banner.BorderSizePixel = 0
		banner.Visible = false
		banner.Parent = screenGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = banner

		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Thickness = 1.5
		stroke.Color = Color3.fromRGB(60, 60, 75)
		stroke.Parent = banner
	end

	-- Etiqueta de texto de rol
	local roleLabel = banner:FindFirstChild("RoleLabel") :: TextLabel?
	if not roleLabel then
		roleLabel = Instance.new("TextLabel")
		roleLabel.Name = "RoleLabel"
		roleLabel.Size = UDim2.new(1, 0, 1, 0)
		roleLabel.BackgroundTransparency = 1
		roleLabel.Font = Enum.Font.GothamBold
		roleLabel.TextSize = 20
		roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		roleLabel.Text = ""
		roleLabel.Parent = banner
	end

	local stroke = banner:FindFirstChild("Stroke") :: UIStroke?

	-- Actualizar visual del HUD ante cambios en el Attribute
	local function updateHUD(role: any)
		if role == "Hunter" then
			banner.Visible = true
			roleLabel.Text = "ERES EL HUNTER"
			roleLabel.TextColor3 = Color3.fromRGB(255, 60, 75)
			if stroke then stroke.Color = Color3.fromRGB(255, 60, 75) end

		elseif role == "Runner" then
			banner.Visible = true
			roleLabel.Text = "ERES UN RUNNER"
			roleLabel.TextColor3 = Color3.fromRGB(80, 165, 255)
			if stroke then stroke.Color = Color3.fromRGB(80, 165, 255) end

		else
			-- Lobby u otro estado
			banner.Visible = false
			roleLabel.Text = ""
		end
	end

	-- Escuchar cambios en el atributo Role
	localPlayer:GetAttributeChangedSignal("Role"):Connect(function()
		updateHUD(localPlayer:GetAttribute("Role"))
	end)

	-- Estado inicial
	updateHUD(localPlayer:GetAttribute("Role"))
	print("[RoleHUD] Inicializado en el cliente.")
end

return RoleHUD
