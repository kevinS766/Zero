--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

-- Controllers
local Controllers = script:WaitForChild("Controllers")
local RoleHUD = require(Controllers:WaitForChild("RoleHUD"))
local CooldownHUD = require(Controllers:WaitForChild("CooldownHUD"))
local DashController = require(Controllers:WaitForChild("DashController"))
local ClassSelectionController = require(Controllers:WaitForChild("ClassSelectionController"))
local HunterAbilityController = require(Controllers:WaitForChild("HunterAbilityController"))
local MusicController = require(Controllers:WaitForChild("MusicController"))
local ShopController = require(Controllers:WaitForChild("ShopController"))

-- Desactivar Reset Character (Anti-suicidio tactico)
task.spawn(function()
	local maxAttempts = 25
	for attempt = 1, maxAttempts do
		local success = pcall(function()
			game:GetService("StarterGui"):SetCore("ResetButtonCallback", false)
		end)
		if success then break end
		task.wait(0.5)
	end
end)

-- Inicializar Controladores de Cliente
if not game:GetService("StarterGui"):FindFirstChild("ZeroUI") then RoleHUD.init() end
CooldownHUD.init()
DashController.init()
ClassSelectionController.init()
HunterAbilityController.init(CooldownHUD)
MusicController.init()
ShopController.init()

-- Escuchar feedback de combate (ataques e impactos)
local attackHitFeedbackEvent: RemoteEvent = NetworkEvents.getRemoteEvent("AttackHitFeedback")
attackHitFeedbackEvent.OnClientEvent:Connect(function(data: { role: string, targetName: string?, attackerName: string? })
	if data.role == "Attacker" then
		print(string.format("[Combat UI] ¡Golpeaste a %s!", data.targetName or "Runner"))
	elseif data.role == "Victim" then
		print(string.format("[Combat UI] ¡Fuiste golpeado por %s!", data.attackerName or "Hunter"))
	end
end)

print("[Client] Cliente de Zero iniciado con éxito (RoleHUD, CooldownHUD, Dash, ClassSelection, HunterAbilities, Music y Shop activos).")
