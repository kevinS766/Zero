--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerRoles = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerRoles"))
local PlayerStatus = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStatus"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local HunterAbilityController = {}

local localPlayer = Players.LocalPlayer
local abilityRequestEvent: RemoteEvent = NetworkEvents.getRemoteEvent("AbilityRequest")
local abilityEffectEvent: RemoteEvent = NetworkEvents.getRemoteEvent("AbilityEffect")

-- Referencia a CooldownHUD (se obtiene dinámicamente)
local CooldownHUD: any = nil

-- Manejo visual de siluetas de Tracker en el cliente del Hunter
local activeRevealHighlights: { [Instance]: Highlight } = {}

local function applyTrackerReveal(targetUserIds: { number }, duration: number, npcCharacters: any?)
	local characters={}
	for _,userId in targetUserIds do
		local player=Players:GetPlayerByUserId(userId)
		if player and player.Character then table.insert(characters,player.Character) end
	end
	for _,character in npcCharacters or {} do
		if typeof(character)=="Instance" and character:IsA("Model") and character:IsDescendantOf(workspace) then table.insert(characters,character) end
	end
	for _,char in characters do
		if char.Parent then
			local existing = char:FindFirstChild("TrackerRevealHighlight") :: Highlight?
			if existing then
				existing:Destroy()
			end

			local highlight = Instance.new("Highlight")
			highlight.Name = "TrackerRevealHighlight"
			highlight.FillColor = Color3.fromRGB(255, 50, 65)
			highlight.FillTransparency = 0.3
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.OutlineTransparency = 0.0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = char
			highlight.Parent = char

			activeRevealHighlights[char] = highlight

			task.delay(duration, function()
				if highlight and highlight.Parent then
					highlight:Destroy()
				end
				activeRevealHighlights[char] = nil
			end)
		end
	end
end

-- Intento de activar habilidad al presionar F
local function tryActivateAbility()
	local role = localPlayer:GetAttribute("Role")
	local status = localPlayer:GetAttribute("Status")
	local hunterClass = localPlayer:GetAttribute("HunterClass")
	local isStalking = localPlayer:GetAttribute("StalkerStealth") == true

	print(string.format("[HunterAbilityController:DEBUG] Tecla F presionada. Rol='%s', Status='%s', Clase='%s', Stalking=%s", 
		tostring(role), tostring(status), tostring(hunterClass), tostring(isStalking)))

	if role ~= PlayerRoles.HUNTER then
		print(string.format("[HunterAbilityController:DEBUG] Cancelado: El rol no es Hunter (Actual: %s)", tostring(role)))
		return
	end

	if status == PlayerStatus.FROZEN then
		print("[HunterAbilityController:DEBUG] Cancelado: Estás congelado.")
		return
	end

	-- Si no está en sigilo activo de Stalker, verificar cooldown local. Si YA está en sigilo, permitir cancelar inmediatamente.
	if not isStalking and CooldownHUD and not CooldownHUD.isReady() then
		print("[HunterAbilityController:DEBUG] Cancelado: Habilidad en cooldown local.")
		return
	end

	print("[HunterAbilityController:DEBUG] Petición válida emitida hacia el servidor.")
	abilityRequestEvent:FireServer()
end

function HunterAbilityController.request()
	tryActivateAbility()
end

function HunterAbilityController.init(cooldownHUDRef: any?)
	CooldownHUD = cooldownHUDRef

	-- Entrada de teclado: Tecla F
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed and input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		if input.KeyCode == Enum.KeyCode.F then
			tryActivateAbility()
		end
	end)

	-- Efectos visuales exclusivos recibidos desde el servidor
	abilityEffectEvent.OnClientEvent:Connect(function(data: { kind: string, duration: number, targetUserIds: { number } })
		if data.kind == "TrackerReveal" then
			applyTrackerReveal(data.targetUserIds or {}, data.duration or 4.0, data.targetCharacters)
		end
	end)

	print("[HunterAbilityController] Inicializado en el cliente (Tecla F configurada).")
end

return HunterAbilityController
