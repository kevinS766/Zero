--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("Config"):WaitForChild("CombatConfig"))
local PlayerRoles = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerRoles"))
local RoundStates = require(Shared:WaitForChild("Constants"):WaitForChild("RoundStates"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local CombatService = {}

-- Referencias a servicios inyectadas en init()
local playerStateServiceRef: any = nil
local roundServiceRef: any = nil

-- RemoteEvents de combate
local attackRequestEvent: RemoteEvent = NetworkEvents.getRemoteEvent("AttackRequest")
local attackHitFeedbackEvent: RemoteEvent = NetworkEvents.getRemoteEvent("AttackHitFeedback")

-- Registro de tiempos de ataque por jugador (UserId -> os.clock())
local lastAttackTimestamps: { [number]: number } = {}

-- Plantilla del cuchillo genérico
local knifeTemplate: Tool? = nil

-- Genera un Tool básico genérico sin dependencias de IDs externas
local function getOrCreateKnifeTemplate(): Tool
	if knifeTemplate then
		return knifeTemplate
	end

	local tool = Instance.new("Tool")
	tool.Name = "HunterKnife"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 2.2, 0.4)
	handle.BrickColor = BrickColor.new("Crimson")
	handle.Material = Enum.Material.SmoothPlastic
	handle.Massless = true
	handle.CanCollide = false
	handle.Parent = tool

	-- Script de cliente del tool
	local assetsFolder = Shared:WaitForChild("Assets")
	local clientScript = assetsFolder:WaitForChild("HunterKnifeClient") :: LocalScript
	local clonedScript = clientScript:Clone()
	clonedScript.Parent = tool

	knifeTemplate = tool
	return knifeTemplate
end

-- Equipa el cuchillo a un jugador
function CombatService.giveKnife(player: any)
	if not playerStateServiceRef.isRegistered(player) then return end
	local character = player.Character
	if not playerStateServiceRef.isHuman(player) then
		if not character then return end
		CombatService.removeKnife(player)
		local knife=getOrCreateKnifeTemplate():Clone()
		for _,child in knife:GetDescendants() do if child:IsA("LuaSourceContainer") then child:Destroy() end end
		knife.Parent=character
		local humanoid=character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:EquipTool(knife) end
		return
	end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	CombatService.removeKnife(player)

	local template = getOrCreateKnifeTemplate()
	local knife = template:Clone()
	knife.Parent = backpack

	if character and character:FindFirstChildOfClass("Humanoid") then
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid:EquipTool(knife)
	end

	print(string.format("[CombatService] Cuchillo equipado a %s", player.Name))
end

-- Retira el cuchillo del jugador (de Backpack y de Character)
function CombatService.removeKnife(player: any)
	local backpack = playerStateServiceRef and playerStateServiceRef.isHuman(player) and player:FindFirstChild("Backpack")
	if backpack then
		local tool = backpack:FindFirstChild("HunterKnife")
		if tool then
			tool:Destroy()
		end
	end

	local character = player.Character
	if character then
		local tool = character:FindFirstChild("HunterKnife")
		if tool then
			tool:Destroy()
		end
	end
end

-- Línea de visión desde el Hunter a un personaje: solo bloquean piezas con colisión que no sean de personajes
-- (otros jugadores, decoración sin colisión o barreras invisibles no tapan el golpe). Se prueba a dos alturas.
local function hasLineOfSight(hunterCharacter: Model, hunterHRP: BasePart, char: Model, targetHRP: BasePart): boolean
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { hunterCharacter, char }
	rayParams.RespectCanCollide = true
	for _, h in { 0, 1.4 } do
		local from = hunterHRP.Position + Vector3.new(0, h, 0)
		local hit = Workspace:Raycast(from, targetHRP.Position + Vector3.new(0, h, 0) - from, rayParams)
		local blocker = hit and hit.Instance:FindFirstAncestorOfClass("Model")
		if not hit or (blocker and blocker:FindFirstChildOfClass("Humanoid")) then return true end
	end
	return false
end

-- ¿Este personaje es un Runner activo al que el Hunter puede golpear? range = alcance máximo permitido.
local function validTarget(hunterCharacter: Model, hunterHRP: BasePart, char: Model, range: number, maxAngle: number): (Player?, number?)
	if char == hunterCharacter then return nil end
	local targetPlayer = playerStateServiceRef.getActorFromCharacter(char)
	if not targetPlayer then return nil end
	if playerStateServiceRef.getRole(targetPlayer) ~= PlayerRoles.RUNNER or playerStateServiceRef.isPlayerFrozen(targetPlayer) then return nil end
	local targetHRP = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetHum = char:FindFirstChildOfClass("Humanoid")
	if not targetHRP or not targetHum or targetHum.Health <= 0 then return nil end
	local offset = targetHRP.Position - hunterHRP.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if offset.Magnitude > range or math.abs(offset.Y) > CombatConfig.ATTACK_HEIGHT then return nil end
	-- a quemarropa el ángulo no importa (el corredor puede estar pegado o rodeando al Hunter)
	if flat.Magnitude > 2.5 then
		local angle = math.acos(math.clamp(hunterHRP.CFrame.LookVector:Dot(flat.Unit), -1, 1))
		if angle > maxAngle then return nil end
	end
	if not hasLineOfSight(hunterCharacter, hunterHRP, char, targetHRP) then return nil end
	return targetPlayer, offset.Magnitude
end

-- Busca el Runner válido MÁS CERCANO frente al Hunter (antes se quedaba con el primero que encontraba)
local function findTargetRunner(hunterCharacter: Model, hunterHRP: BasePart): (Player?, Model?)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { hunterCharacter }
	local nearbyParts = Workspace:GetPartBoundsInRadius(hunterHRP.Position, CombatConfig.ATTACK_RANGE + 2, overlapParams)
	local checked: { [Model]: boolean } = {}
	local bestPlayer, bestChar, bestDist = nil, nil, math.huge
	for _, part in nearbyParts do
		local char = part:FindFirstAncestorOfClass("Model")
		if char and not checked[char] then
			checked[char] = true
			local targetPlayer, dist = validTarget(hunterCharacter, hunterHRP, char, CombatConfig.ATTACK_RANGE, CombatConfig.ATTACK_MAX_ANGLE_RAD)
			if targetPlayer and dist and dist < bestDist then bestPlayer, bestChar, bestDist = targetPlayer, char, dist end
		end
	end
	return bestPlayer, bestChar
end

-- Procesa la solicitud de ataque emitida por el cliente
function CombatService.requestAttack(hunterPlayer: any, hint: Instance?)
	if roundServiceRef and roundServiceRef.getState() ~= RoundStates.ROUND_ACTIVE then
		return
	end

	if not playerStateServiceRef or not playerStateServiceRef.isRegistered(hunterPlayer)
		or playerStateServiceRef.getStatus(hunterPlayer) ~= "Active" or playerStateServiceRef.getRole(hunterPlayer) ~= PlayerRoles.HUNTER then
		return
	end

	-- Desactivar ataque mientras la invisibilidad de Stalker esté activa
	if hunterPlayer:GetAttribute("StalkerStealth") == true then
		return
	end

	local character = hunterPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not hrp then
		return
	end

	local now = os.clock()
	local lastTime = lastAttackTimestamps[hunterPlayer.UserId] or -math.huge
	if now - lastTime < CombatConfig.ATTACK_COOLDOWN then
		return
	end
	lastAttackTimestamps[hunterPlayer.UserId] = now
	-- avisa a todos los clientes del golpe (ZeroMovement anima el arma y ZeroArmasServer enciende la estela)
	character:SetAttribute("ZeroAtaqueSerial", ((character:GetAttribute("ZeroAtaqueSerial") or 0) :: number) + 1)

	-- 1) el objetivo que el cliente vio en su pantalla, con tolerancia por la latencia (el servidor ve a los
	--    corredores un poco atrasados); 2) si no vale, la búsqueda normal del servidor
	local targetPlayer, targetCharacter
	if typeof(hint) == "Instance" and hint:IsA("Model") and hint:IsDescendantOf(Workspace) then
		local p = validTarget(character, hrp, hint, CombatConfig.ATTACK_RANGE + CombatConfig.LAG_TOLERANCE, CombatConfig.ATTACK_MAX_ANGLE_RAD + math.rad(25))
		if p then targetPlayer, targetCharacter = p, hint end
	end
	if not targetPlayer then targetPlayer, targetCharacter = findTargetRunner(character, hrp) end
	-- esquiva perfecta: los corredores a los que el golpe pasó rozando (ServerScriptService.ZeroJugadas)
	pcall(function() require(game:GetService("ServerScriptService"):WaitForChild("ZeroJugadas")).ataque(character, hrp, targetCharacter) end)
	if targetPlayer and targetCharacter then
		print(string.format("[COMBAT] %s ha sido congelado.", targetPlayer.Name))

		-- Congelar mediante PlayerStateService
		if not playerStateServiceRef.freezeRunner(targetPlayer, hunterPlayer) then return false end
		if playerStateServiceRef.isHuman(hunterPlayer) then
			local DataService = require(script.Parent.DataService)
			DataService.incrementStat(hunterPlayer, "hunter_tags", 1)
		end

		-- Feedback a clientes
		if playerStateServiceRef.isHuman(hunterPlayer) then attackHitFeedbackEvent:FireClient(hunterPlayer, {
			role = "Attacker",
			targetName = targetPlayer.Name,
		}) end
		if playerStateServiceRef.isHuman(targetPlayer) then attackHitFeedbackEvent:FireClient(targetPlayer, {
			role = "Victim",
			attackerName = hunterPlayer.Name,
		}) end
		return true
	end
end

function CombatService.forgetActor(actor)
	lastAttackTimestamps[actor.UserId] = nil
end

function CombatService.init(playerStateService: any, roundService: any?)
	playerStateServiceRef = playerStateService
	roundServiceRef = roundService

	attackRequestEvent.OnServerEvent:Connect(function(player, hint)
		CombatService.requestAttack(player, hint)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAttackTimestamps[player.UserId] = nil
	end)

	print("[CombatService] Inicializado con herramienta básica genérica y congelamiento estricto.")
end

return CombatService

