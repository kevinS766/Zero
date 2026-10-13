--!strict
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local MonetizationService = {}

-- Cache de pases en memoria: UserId -> { [string]: boolean }
local playerPassCache: { [number]: { [string]: boolean } } = {}

-- Referencia diferida a DataService
local dataServiceRef: any = nil
local function getDataService()
	if not dataServiceRef then
		local ok, mod = pcall(function()
			return require(script.Parent:WaitForChild("DataService"))
		end)
		if ok and mod then
			dataServiceRef = mod
		end
	end
	return dataServiceRef
end

-- Eventos de Red
local promptPurchaseFunction = NetworkEvents.getRemoteFunction("PromptGamepassPurchase")
local passStatusEvent = NetworkEvents.getRemoteEvent("GamepassStatusUpdated")

-- Verifica si un jugador posee un pase específico
function MonetizationService.ownsPass(player: Player, passKey: string): boolean
	local info = MonetizationConfig.Passes[passKey] or (MonetizationConfig.Exclusivos or {})[passKey]   -- también armas exclusivas
	if not info then return false end

	-- 1. Comprobar simulación por atributos (Studio o Testing)
	local simulated = player:GetAttribute("SimulatedPass_" .. passKey)
	if simulated == true then
		return true
	end

	-- 2. Comprobar cache en memoria
	local userCache = playerPassCache[player.UserId]
	if userCache and userCache[passKey] ~= nil then
		return userCache[passKey]
	end

	-- 3. Si el ID no está configurado (0), no lo posee a menos que esté simulado
	if info.Id <= 0 then
		return false
	end

	-- 4. Consulta a Roblox MarketplaceService
	local owns = false
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.Id)
	end)
	if ok then
		owns = result == true
	else
		warn(string.format("[MonetizationService] Error consultando pase %s para %s: %s", passKey, player.Name, tostring(result)))
	end

	if not playerPassCache[player.UserId] then
		playerPassCache[player.UserId] = {}
	end
	playerPassCache[player.UserId][passKey] = owns
	return owns
end

-- Sincroniza atributos de pases del jugador
local function syncPlayerPassAttributes(player: Player)
	for passKey, _ in MonetizationConfig.Passes do
		local owned = MonetizationService.ownsPass(player, passKey)
		player:SetAttribute("HasPass_" .. passKey, owned)
	end
	for passKey, _ in MonetizationConfig.Exclusivos or {} do   -- armas exclusivas vendidas como pase (ORIGAMI…)
		player:SetAttribute("HasPass_" .. passKey, MonetizationService.ownsPass(player, passKey))
	end
	passStatusEvent:FireClient(player, {
		VIP = MonetizationService.ownsPass(player, "VIP"),
		DOUBLE_COINS = MonetizationService.ownsPass(player, "DOUBLE_COINS"),
		DOUBLE_GEMS = MonetizationService.ownsPass(player, "DOUBLE_GEMS"),
		DOUBLE_XP = MonetizationService.ownsPass(player, "DOUBLE_XP"),
	})
end

-- Aplica cosméticos VIP en el personaje
local function applyVIPVisuals(player: Player)
	if not MonetizationService.ownsPass(player, "VIP") then return end

	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	-- Rastro visual VIP dorado
	local existingTrail = hrp:FindFirstChild("VIPTrail")
	if not existingTrail then
		local att0 = hrp:FindFirstChild("VIPAttachment0") :: Attachment?
		local att1 = hrp:FindFirstChild("VIPAttachment1") :: Attachment?

		if not att0 then
			att0 = Instance.new("Attachment")
			att0.Name = "VIPAttachment0"
			att0.Position = Vector3.new(0, 0.5, 0)
			att0.Parent = hrp
		end

		if not att1 then
			att1 = Instance.new("Attachment")
			att1.Name = "VIPAttachment1"
			att1.Position = Vector3.new(0, -0.5, 0)
			att1.Parent = hrp
		end

		local trail = Instance.new("Trail")
		trail.Name = "VIPTrail"
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 20)),
		})
		trail.Lifetime = 0.4
		trail.MinLength = 0.1
		trail.LightEmission = 0.8
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Parent = hrp
	end
end

-- Simula posesión de un pase para pruebas en Studio
function MonetizationService.simulatePass(player: Player, passKey: string, state: boolean)
	if not MonetizationConfig.Passes[passKey] then return end
	player:SetAttribute("SimulatedPass_" .. passKey, state)

	if not playerPassCache[player.UserId] then
		playerPassCache[player.UserId] = {}
	end
	playerPassCache[player.UserId][passKey] = state

	syncPlayerPassAttributes(player)
	if passKey == "VIP" and state then
		applyVIPVisuals(player)
	end
	print(string.format("[MonetizationService] Pase %s para %s simulado como: %s", passKey, player.Name, tostring(state)))
end

-- Calcula y aplica recompensas con multiplicadores de pases
function MonetizationService.calculateRewards(player: Player, baseCoins: number, baseGems: number): (number, number)
	local finalCoins = baseCoins
	local finalGems = baseGems

	-- Multiplicador 2x Coins
	if MonetizationService.ownsPass(player, "DOUBLE_COINS") then
		finalCoins *= MonetizationConfig.Multipliers.CoinsPass
	end

	-- Multiplicador 2x Gems
	if MonetizationService.ownsPass(player, "DOUBLE_GEMS") then
		finalGems *= MonetizationConfig.Multipliers.GemsPass
	end

	-- Bonus pasivo VIP (+20%)
	if MonetizationService.ownsPass(player, "VIP") then
		finalCoins = math.round(finalCoins * (1 + MonetizationConfig.Multipliers.VIPBonusPercent))
		finalGems = math.round(finalGems * (1 + MonetizationConfig.Multipliers.VIPBonusPercent))
	end

	return finalCoins, finalGems
end

-- Entrega recompensas calculadas directamente al perfil del jugador
function MonetizationService.awardCalculated(player: Player, baseCoins: number, baseGems: number, reason: string): (number, number)
	local coins, gems = MonetizationService.calculateRewards(player, baseCoins, baseGems)
	local ds = getDataService()
	if ds then
		if coins > 0 then
			ds.addCurrency(player, "Coins", coins)
		end
		if gems > 0 then
			ds.addCurrency(player, "Gems", gems)
		end
		print(string.format("[MonetizationService] Recompensas entregadas a %s (%s): +%d Monedas, +%d Gemas", 
			player.Name, reason, coins, gems))
	end
	return coins, gems
end

function MonetizationService.init()
	-- Manejador de invocación para solicitar compra de pase desde la UI
	promptPurchaseFunction.OnServerInvoke = function(player: Player, passKey: any)
		if typeof(passKey) ~= "string" or not MonetizationConfig.Passes[passKey] then
			return { success = false, message = "Pase desconocido." }
		end

		local info = MonetizationConfig.Passes[passKey]
		if MonetizationService.ownsPass(player, passKey) then
			return { success = false, message = "¡Ya posees este pase!" }
		end

		if info.Id <= 0 then
			-- Pase en borrador / desarrollo
			return {
				success = false,
				message = string.format("El pase %s estará disponible muy pronto.", info.DisplayName),
				isDraft = true,
			}
		end

		-- Abrir prompt de compra oficial de Roblox
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, info.Id)
		end)

		if not ok then
			warn(string.format("[MonetizationService] Error abriendo prompt de pase: %s", tostring(err)))
			return { success = false, message = "No se pudo abrir el menú de compra." }
		end

		return { success = true }
	end

	-- Escuchar compra confirmada de Gamepass
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased or not player or not player.Parent then return end

		local todos = table.clone(MonetizationConfig.Passes)
		for k, v in MonetizationConfig.Exclusivos or {} do todos[k] = v end
		for passKey, info in todos do
			if info.Id == passId then
				if not playerPassCache[player.UserId] then
					playerPassCache[player.UserId] = {}
				end
				playerPassCache[player.UserId][passKey] = true
				syncPlayerPassAttributes(player)

				if passKey == "VIP" then
					applyVIPVisuals(player)
				end

				print(string.format("[MonetizationService] ¡%s compró el pase %s!", player.Name, info.DisplayName))
				break
			end
		end
	end)

	-- Configurar tag de Chat para VIP mediante TextChatService
	pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage)
			local properties = Instance.new("TextChatMessageProperties")
			if message.TextSource then
				local player = Players:GetPlayerByUserId(message.TextSource.UserId)
				if player and MonetizationService.ownsPass(player, "VIP") then
					properties.PrefixText = string.format("<font color='#FFD700'><b>[VIP]</b></font> %s", message.PrefixText)
				end
			end
			return properties
		end
	end)

	-- Eventos de jugadores
	local function onPlayerAdded(player: Player)
		task.spawn(function()
			task.wait(1)
			if player.Parent == Players then
				syncPlayerPassAttributes(player)
			end
		end)

		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if player.Parent == Players then
				applyVIPVisuals(player)
			end
		end)
	end

	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		playerPassCache[player.UserId] = nil
	end)

	print("[MonetizationService] Inicializado correctamente (VIP, 2x Coins, 2x Gems, 2x XP).")
end

return MonetizationService
