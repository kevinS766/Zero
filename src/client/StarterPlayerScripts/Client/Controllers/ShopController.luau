--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local ShopController = {}

local promptPurchaseFunction = NetworkEvents.getRemoteFunction("PromptGamepassPurchase")
local passStatusEvent = NetworkEvents.getRemoteEvent("GamepassStatusUpdated")

-- Muestra un toast visual no intrusivo en pantalla
local function showToast(messageText: string)
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end

	local zeroUI = playerGui:FindFirstChild("ZeroUI")
	if not zeroUI then return end

	local toast = zeroUI:FindFirstChild("Toast") :: Frame?
	if not toast then return end

	local msgLabel = toast:FindFirstChild("Message") :: TextLabel?
	if msgLabel then
		msgLabel.Text = messageText
	end

	toast.Visible = true
	toast.BackgroundTransparency = 0
	task.delay(3, function()
		if toast.Visible then
			local tween = TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Connect(function()
				toast.Visible = false
			end)
		end
	end)
end

-- Actualiza la visualización de un pase en la tienda
local function updatePassCard(card: Frame, passKey: string)
	local info = MonetizationConfig.Passes[passKey]
	if not info then return end

	local titleLabel = card:FindFirstChild("Title") :: TextLabel?
	local subLabel = card:FindFirstChild("Subtitle") :: TextLabel?
	local actionBtn = card:FindFirstChild("Action") :: TextButton?

	if titleLabel then
		titleLabel.Text = info.DisplayName
	end
	if subLabel then
		subLabel.Text = info.Description
	end

	local isOwned = LocalPlayer:GetAttribute("HasPass_" .. passKey) == true or LocalPlayer:GetAttribute("SimulatedPass_" .. passKey) == true
	if actionBtn then
		local btnText = actionBtn:FindFirstChild("ButtonText") :: TextLabel?
		if isOwned then
			actionBtn.Text = "ADQUIRIDO"
			if btnText then
				btnText.Text = "ADQUIRIDO"
			end
			actionBtn.Active = false
		else
			local priceStr = if info.PriceRobux then string.format("R$ %d", info.PriceRobux) else "R$ —"
			actionBtn.Text = priceStr
			if btnText then
				btnText.Text = priceStr
			end
			actionBtn.Active = true
		end
	end
end

-- Actualiza todos los pases del modal de la tienda
local function refreshShopPasses(shopBody: ScrollingFrame)
	local productKeys = {
		Product_1 = "VIP",
		Product_2 = "DOUBLE_COINS",
		Product_3 = "DOUBLE_GEMS",
		Product_4 = "DOUBLE_XP",
	}

	for prodName, passKey in productKeys do
		local card = shopBody:FindFirstChild(prodName) :: Frame?
		if card then
			updatePassCard(card, passKey)
		end
	end
end

-- Actualiza el HUD de moneda (Coins y Gems)
local function refreshCurrencyHUD(hud: Frame)
	local currFrame = hud:FindFirstChild("Currency") :: Frame?
	if not currFrame then return end

	local amountLabel = currFrame:FindFirstChild("Amount") :: TextLabel?
	if amountLabel then
		local coins = LocalPlayer:GetAttribute("Coins") or 0
		local gems = LocalPlayer:GetAttribute("Gems") or 0
		amountLabel.Text = string.format("%d 🪙 | %d 💎", coins, gems)
	end
end

-- Conecta las acciones de compra de pases
local function hookShopButtons(shopBody: ScrollingFrame)
	local productKeys = {
		Product_1 = "VIP",
		Product_2 = "DOUBLE_COINS",
		Product_3 = "DOUBLE_GEMS",
	}

	for prodName, passKey in productKeys do
		local card = shopBody:FindFirstChild(prodName) :: Frame?
		if card then
			local actionBtn = card:FindFirstChild("Action") :: TextButton?
			if actionBtn and not actionBtn:GetAttribute("Hooked") then
				actionBtn:SetAttribute("Hooked", true)
				actionBtn.Activated:Connect(function()
					local isOwned = LocalPlayer:GetAttribute("HasPass_" .. passKey) == true or LocalPlayer:GetAttribute("SimulatedPass_" .. passKey) == true
					if isOwned then
						showToast("¡Ya posees este pase!")
						return
					end

					local res = promptPurchaseFunction:InvokeServer(passKey)
					if res and res.message then
						showToast(res.message)
					end
				end)
			end
		end
	end
end

function ShopController.init()
	local function onPlayerGuiAdded(playerGui: PlayerGui)
		local zeroUI = playerGui:WaitForChild("ZeroUI", 10) :: ScreenGui?
		if not zeroUI then return end

		local hud = zeroUI:WaitForChild("HUD", 5) :: Frame?
		if hud then
			refreshCurrencyHUD(hud)
			LocalPlayer:GetAttributeChangedSignal("Coins"):Connect(function()
				refreshCurrencyHUD(hud)
			end)
			LocalPlayer:GetAttributeChangedSignal("Gems"):Connect(function()
				refreshCurrencyHUD(hud)
			end)
		end

		local modal = zeroUI:WaitForChild("Modal", 5) :: Frame?
		if modal then
			local shopModal = modal:WaitForChild("Shop", 5) :: Frame?
			if shopModal then
				local shopBody = shopModal:WaitForChild("Body", 5) :: ScrollingFrame?
				if shopBody then
					refreshShopPasses(shopBody)
					hookShopButtons(shopBody)

					for _, passKey in { "VIP", "DOUBLE_COINS", "DOUBLE_GEMS", "DOUBLE_XP" } do
						LocalPlayer:GetAttributeChangedSignal("HasPass_" .. passKey):Connect(function()
							refreshShopPasses(shopBody)
						end)
						LocalPlayer:GetAttributeChangedSignal("SimulatedPass_" .. passKey):Connect(function()
							refreshShopPasses(shopBody)
						end)
					end
				end
			end
		end
	end

	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		task.spawn(onPlayerGuiAdded, playerGui)
	end
	LocalPlayer.ChildAdded:Connect(function(child)
		if child:IsA("PlayerGui") then
			onPlayerGuiAdded(child)
		end
	end)

	passStatusEvent.OnClientEvent:Connect(function()
		local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg then
			local zeroUI = pg:FindFirstChild("ZeroUI")
			if zeroUI then
				local shopModal = zeroUI:FindFirstChild("Modal") and zeroUI.Modal:FindFirstChild("Shop")
				if shopModal and shopModal:FindFirstChild("Body") then
					refreshShopPasses(shopModal.Body)
				end
			end
		end
	end)

	print("[ShopController] Inicializado con éxito.")
end

return ShopController
