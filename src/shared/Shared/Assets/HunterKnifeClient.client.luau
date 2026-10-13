--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("Config"):WaitForChild("CombatConfig"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local tool = script.Parent :: Tool
local attackRequestEvent: RemoteEvent = NetworkEvents.getRemoteEvent("AttackRequest")

local lastAttackTime = 0
local isEquipped = false

-- Personaje no congelado más cercano dentro del alcance y del cono frontal (solo es una pista para el servidor)
local function findHint(): Model?
	local character = tool.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local best, bestDist = nil, CombatConfig.ATTACK_RANGE + 1.5
	local candidates = {}
	for _, p in Players:GetPlayers() do if p.Character and p.Character ~= character then table.insert(candidates, p.Character) end end
	local bots = workspace:FindFirstChild("ZeroBots")
	if bots then for _, b in bots:GetChildren() do table.insert(candidates, b) end end
	for _, char in candidates do
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local owner = Players:GetPlayerFromCharacter(char) or char
		if hrp and char:GetAttribute("Status") ~= "Frozen" and owner:GetAttribute("Role") ~= "Hunter" then
			local offset = hrp.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local inFront = flat.Magnitude < 2.5 or root.CFrame.LookVector:Dot(flat.Unit) > math.cos(CombatConfig.ATTACK_MAX_ANGLE_RAD)
			if inFront and offset.Magnitude < bestDist then best, bestDist = char, offset.Magnitude end
		end
	end
	return best
end

tool.Equipped:Connect(function()
	isEquipped = true
end)

tool.Unequipped:Connect(function()
	isEquipped = false
end)

tool.Activated:Connect(function()
	if not isEquipped then return end

	if Players.LocalPlayer:GetAttribute("StalkerStealth") == true then
		return
	end

	local now = os.clock()
	if now - lastAttackTime < CombatConfig.ATTACK_COOLDOWN then
		return
	end

	lastAttackTime = now

	-- El objetivo que este cliente ve delante (posiciones al día en su pantalla). El servidor lo valida con su
	-- propia comprobación y una tolerancia de lag; si no vale, hace su búsqueda normal.
	attackRequestEvent:FireServer(findHint())
end)
