--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerRoles = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerRoles"))
local PlayerStatus = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStatus"))
local HunterClassConfig = require(Shared:WaitForChild("Config"):WaitForChild("HunterClassConfig"))

local NetworkEvents=require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))
local rescueFeedbackEvent=NetworkEvents.getRemoteEvent("RescueFeedback")
local PlayerStateService = {}
local RunService = game:GetService("RunService")
local DataService = require(script.Parent.DataService)
local bots, leaving, rescueHolds, freezes = {}, {}, {}, {}
local freezeSerial = 0
local FREEZE_DURATION = 12
local RESCUE_DURATION, RESCUE_RANGE = 2.5, 10
local CONVERSION_PROTECTION = 2

function PlayerStateService.isHuman(actor)
	return typeof(actor) == "Instance" and actor:IsA("Player") and actor.Parent == Players
end

function PlayerStateService.isRegistered(actor)
	return actor ~= nil and not leaving[actor] and
		(PlayerStateService.isHuman(actor) or bots[actor] == true)
end

function PlayerStateService.getActors()
	local roster = {}
	for _, actor in Players:GetPlayers() do
		if not leaving[actor] then table.insert(roster, actor) end
	end
	for actor in pairs(bots) do
		if actor.Character and actor.Character.Parent then table.insert(roster, actor) end
	end
	return roster
end

function PlayerStateService.getActorFromCharacter(character)
	local human = Players:GetPlayerFromCharacter(character)
	if human and not leaving[human] then return human end
	for actor in pairs(bots) do
		if actor.Character == character then return actor end
	end
	return nil
end

function PlayerStateService.registerBot(actor)
	if type(actor) ~= "table" or actor.IsBot ~= true or type(actor.UserId) ~= "number"
		or actor.UserId >= 0 or not actor.Character or not actor.Character:FindFirstChildOfClass("Humanoid")
		or not actor.Character:FindFirstChild("HumanoidRootPart") then return false end
	for other in pairs(bots) do
		if other ~= actor and other.UserId == actor.UserId then return false end
	end
	bots[actor] = true
	PlayerStateService.setRole(actor, PlayerRoles.LOBBY)
	return true
end

function PlayerStateService.unregisterBot(actor)
	bots[actor] = nil
	freezes[actor] = nil
	rescueHolds[actor] = nil
	for rescuer, hold in pairs(rescueHolds) do
		if hold.victim == actor then rescueHolds[rescuer] = nil end
	end
end

local function aliveRoot(actor)
	if not PlayerStateService.isRegistered(actor) then return nil end
	local character = actor.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid and humanoid.Health > 0 and root or nil
end

-- Referencias a servicios inyectadas en init()
local roundServiceRef: any = nil
local combatServiceRef: any = nil

-- Configuración de colores visuales para roles
local ROLE_COLORS = {
	Hunter = {
		Fill = Color3.fromRGB(255, 45, 65),
		Outline = Color3.fromRGB(255, 180, 180),
	},
	Runner = {
		Fill = Color3.fromRGB(45, 140, 255),
		Outline = Color3.fromRGB(180, 220, 255),
	},
	Frozen = {
		Fill = Color3.fromRGB(0, 220, 255),
		Outline = Color3.fromRGB(255, 255, 255),
	},
}

-- Remueve el Highlight, Tag y ProximityPrompt de un personaje
local function removeVisualsAndPrompt(character: Model)
	local hl = character:FindFirstChild("RoleHighlight")
	if hl then
		hl:Destroy()
	end

	local head = character:FindFirstChild("Head")
	if head then
		local tag = head:FindFirstChild("RoleBillboard")
		if tag then
			tag:Destroy()
		end
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local prompt = hrp:FindFirstChild("RescuePrompt")
		if prompt then
			prompt:Destroy()
		end
	end
end

-- Actualiza o crea el BillboardGui sobre la cabeza
local function setOverheadTag(character: Model, text: string, color: Color3)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then return end

	local billboard = head:FindFirstChild("RoleBillboard") :: BillboardGui?
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "RoleBillboard"
		billboard.Size = UDim2.new(0, 180, 0, 40)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 60
		billboard.Parent = head

		local label = Instance.new("TextLabel")
		label.Name = "RoleTitle"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 16
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.Parent = billboard
	end

	local roleTitle = billboard:FindFirstChild("RoleTitle") :: TextLabel?
	if roleTitle then
		roleTitle.Text = text
		roleTitle.TextColor3 = color
	end
end

-- Aplica o actualiza el Highlight
local function setHighlight(character: Model, fill: Color3, outline: Color3)
	local highlight = character:FindFirstChild("RoleHighlight") :: Highlight?
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "RoleHighlight"
		highlight.FillTransparency = 0.4
		highlight.OutlineTransparency = 0.1
		highlight.Adornee = character
		highlight.Parent = character
	end

	highlight.FillColor = fill
	highlight.OutlineColor = outline
end

-- Asigna un rol a un jugador y actualiza su visual y equipamiento
function PlayerStateService.setRole(player: any, role: string)
	rescueHolds[player] = nil
	for rescuer, hold in pairs(rescueHolds) do
		if hold.victim == player then rescueHolds[rescuer] = nil end
	end
	freezes[player] = nil
	player:SetAttribute("FreezeTimeLeft", nil)
	player:SetAttribute("FreezePaused", nil)
	player:SetAttribute("Role", role)
	player:SetAttribute("Status", PlayerStatus.ACTIVE)

	local character = player.Character
	if character then
		character:SetAttribute("FreezeTimeLeft", nil)
		character:SetAttribute("FreezePaused", nil)
		character:SetAttribute("Role", role)
		character:SetAttribute("Status", PlayerStatus.ACTIVE)

		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.Anchored = false
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
			humanoid.JumpHeight = 7.2
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end

		if role == PlayerRoles.LOBBY then
			removeVisualsAndPrompt(character)
		elseif role == PlayerRoles.HUNTER then
			removeVisualsAndPrompt(character)
			if HunterClassConfig.DEBUG_ROLE_VISUALS then
				setHighlight(character, ROLE_COLORS.Hunter.Fill, ROLE_COLORS.Hunter.Outline)
				setOverheadTag(character, "[HUNTER]", ROLE_COLORS.Hunter.Fill)
			end
		elseif role == PlayerRoles.RUNNER then
			removeVisualsAndPrompt(character)
			if HunterClassConfig.DEBUG_ROLE_VISUALS then
				setHighlight(character, ROLE_COLORS.Runner.Fill, ROLE_COLORS.Runner.Outline)
				setOverheadTag(character, "[RUNNER]", ROLE_COLORS.Runner.Fill)
			end
		end
	end

	-- Gestión del arma según el rol
	if combatServiceRef then
		if role == PlayerRoles.HUNTER then
			combatServiceRef.giveKnife(player)
		else
			combatServiceRef.removeKnife(player)
		end
	end

	print(string.format("[PlayerStateService] %s asignado como %s", player.Name, role))
end

function PlayerStateService.getRole(player: any): string
	return player:GetAttribute("Role") or PlayerRoles.LOBBY
end

function PlayerStateService.getStatus(player: any): string
	return player:GetAttribute("Status") or PlayerStatus.ACTIVE
end

function PlayerStateService.isPlayerFrozen(player: any): boolean
	return PlayerStateService.getStatus(player) == PlayerStatus.FROZEN
end

-- Resetea a todos los jugadores al rol Lobby
function PlayerStateService.resetAllToLobby()
	for _, player in PlayerStateService.getActors() do
		PlayerStateService.setRole(player, PlayerRoles.LOBBY)
	end
end

-- Distribuye roles para una ronda activa (1 Hunter, el resto Runners)
function PlayerStateService.assignRoundRoles(preselectedHunter: any, roundActors: any?)
	local activePlayers = roundActors or PlayerStateService.getActors()
	if #activePlayers == 0 then return end

	local hunterIndex: number? = nil
	if preselectedHunter then
		hunterIndex = table.find(activePlayers, preselectedHunter)
	end
	if hunterIndex and not PlayerStateService.isHuman(activePlayers[hunterIndex]) then hunterIndex = nil end
	if not hunterIndex then
		local humanIndices = {}
		for i,actor in activePlayers do if PlayerStateService.isHuman(actor) then table.insert(humanIndices,i) end end
		if #humanIndices==0 then return end
		hunterIndex = humanIndices[math.random(1,#humanIndices)]
	end

	local hunterPlayer = activePlayers[hunterIndex]

	for i, player in activePlayers do
		if i == hunterIndex then
			PlayerStateService.setRole(player, PlayerRoles.HUNTER)
		else
			PlayerStateService.setRole(player, PlayerRoles.RUNNER)
		end
	end

	print(string.format("[PlayerStateService] Roles asignados. Hunter: %s | Total: %d", hunterPlayer.Name, #activePlayers))
end

-- Cuenta cuántos Runners activos (libres, no congelados) quedan en la partida
function PlayerStateService.getActiveRunnersCount(): number
	local count = 0
	for _, player in PlayerStateService.getActors() do
		local role = PlayerStateService.getRole(player)
		local status = PlayerStateService.getStatus(player)
		if role == PlayerRoles.RUNNER and status == PlayerStatus.ACTIVE and aliveRoot(player) then
			count += 1
		end
	end
	return count
end

-- Verifica si queda algún Hunter activo
function PlayerStateService.hasActiveHunter(): boolean
	for _, player in PlayerStateService.getActors() do
		if PlayerStateService.getRole(player) == PlayerRoles.HUNTER and aliveRoot(player) then
			return true
		end
	end
	return false
end

-- Shared server hold validation for prompts and NPCs.
local function canRescue(rescuer, victim)
	if not roundServiceRef or roundServiceRef.getState() ~= "ROUND_ACTIVE" or rescuer == victim then return false end
	local root, target = aliveRoot(rescuer), aliveRoot(victim)
	return root and target and PlayerStateService.getRole(rescuer) == PlayerRoles.RUNNER
		and PlayerStateService.getStatus(rescuer) == PlayerStatus.ACTIVE
		and PlayerStateService.getRole(victim) == PlayerRoles.RUNNER
		and PlayerStateService.isPlayerFrozen(victim) and (root.Position - target.Position).Magnitude <= RESCUE_RANGE
end

function PlayerStateService.requestRescue(rescuer, victim)
	if not canRescue(rescuer, victim) then rescueHolds[rescuer] = nil; return false end
	local hold = rescueHolds[rescuer]
	if not hold or hold.victim ~= victim or hold.serial ~= victim:GetAttribute("FreezeSerial") then
		rescueHolds[rescuer] = { victim = victim, serial = victim:GetAttribute("FreezeSerial"), began = os.clock(), lastRequest = os.clock() }
		return false
	end
	hold.lastRequest = os.clock()
	if os.clock() - hold.began < RESCUE_DURATION then return false end
	rescueHolds[rescuer] = nil
	freezes[victim] = nil
	victim:SetAttribute("FreezeTimeLeft", nil)
	victim:SetAttribute("FreezePaused", nil)
	victim.Character:SetAttribute("FreezeTimeLeft", nil)
	victim.Character:SetAttribute("FreezePaused", nil)
	local character, root = victim.Character, aliveRoot(victim)
	root.Anchored = false
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 16, 50, 7.2
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	victim:SetAttribute("Status", PlayerStatus.ACTIVE)
	character:SetAttribute("Status", PlayerStatus.ACTIVE)
	removeVisualsAndPrompt(character)
	if HunterClassConfig.DEBUG_ROLE_VISUALS then
		setHighlight(character, ROLE_COLORS.Runner.Fill, ROLE_COLORS.Runner.Outline)
		setOverheadTag(character, "[RUNNER]", ROLE_COLORS.Runner.Fill)
	end
	if PlayerStateService.isHuman(rescuer) then
		DataService.incrementStat(rescuer, "rescues", 1)
		rescueFeedbackEvent:FireClient(rescuer)
	end
	if PlayerStateService.isHuman(victim) then rescueFeedbackEvent:FireClient(victim) end
	return true
end

-- Kept for existing callers; never bypasses the authoritative hold.
PlayerStateService.rescueRunner = PlayerStateService.requestRescue

-- Every participant uses the same rescue window and infection transition.
local function convertFrozen(actor, record)
	if freezes[actor] ~= record or record.remaining > 0 or not aliveRoot(actor)
		or PlayerStateService.getStatus(actor) ~= PlayerStatus.FROZEN then return false end
	local character, roundId = actor.Character, record.roundId
	PlayerStateService.setRole(actor, PlayerRoles.HUNTER)
	local class = actor:GetAttribute("HunterClass") or HunterClassConfig.DEFAULT_CLASS
	actor:SetAttribute("HunterClass", class)
	character:SetAttribute("HunterClass", class)
	actor:SetAttribute("Status", "HunterTransition")
	character:SetAttribute("Status", "HunterTransition")
	character:SetAttribute("ZeroSprinting", false)
	local humanoid, root = character:FindFirstChildOfClass("Humanoid"), aliveRoot(actor)
	humanoid.WalkSpeed = 0
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	task.delay(CONVERSION_PROTECTION, function()
		if PlayerStateService.isRegistered(actor) and actor.Character == character
			and roundServiceRef.getState() == "ROUND_ACTIVE" and ReplicatedStorage:GetAttribute("RoundId") == roundId
			and PlayerStateService.getStatus(actor) == "HunterTransition" then
			PlayerStateService.setRole(actor, PlayerRoles.HUNTER)
		end
	end)
	roundServiceRef.checkWinCondition()
	return true
end

-- Compatibility entry point cannot skip freezing or its countdown.
function PlayerStateService.convertBotToHunter(actor)
	local record = freezes[actor]
	return not PlayerStateService.isHuman(actor) and record ~= nil and convertFrozen(actor, record) or false
end

RunService.Heartbeat:Connect(function(dt)
	local paused = {}
	for rescuer, hold in pairs(rescueHolds) do
		if not canRescue(rescuer, hold.victim) or hold.serial ~= hold.victim:GetAttribute("FreezeSerial")
			or (not PlayerStateService.isHuman(rescuer) and os.clock() - hold.lastRequest > .75) then
			rescueHolds[rescuer] = nil
		else paused[hold.victim] = true end
	end
	for actor, record in pairs(freezes) do
		if not aliveRoot(actor) or actor.Character ~= record.character
			or not roundServiceRef or roundServiceRef.getState() ~= "ROUND_ACTIVE"
			or ReplicatedStorage:GetAttribute("RoundId") ~= record.roundId
			or PlayerStateService.getStatus(actor) ~= PlayerStatus.FROZEN then
			freezes[actor] = nil
		else
			if not paused[actor] then record.remaining = math.max(0, record.remaining - dt) end
			local remaining = math.ceil(record.remaining)
			actor:SetAttribute("FreezeTimeLeft", remaining)
			actor:SetAttribute("FreezePaused", paused[actor] == true)
			record.character:SetAttribute("FreezeTimeLeft", remaining)
			record.character:SetAttribute("FreezePaused", paused[actor] == true)
			if remaining ~= record.displayed then
				record.displayed = remaining
				setOverheadTag(record.character, "[CONGELADO] " .. remaining .. "s", ROLE_COLORS.Frozen.Fill)
			end
			if record.remaining <= 0 then convertFrozen(actor, record) end
		end
	end
end)

-- Congela a un Runner impactado por el cuchillo
local function jugadas() return require(game:GetService("ServerScriptService"):WaitForChild("ZeroJugadas")) end   -- esquivas, rachas y power-ups
-- cazador (opcional): quién congela, para las rachas (DOBLE, TRIPLE, MEGA FREEZE)
function PlayerStateService.freezeRunner(victimPlayer: any, cazador: any?)
	if not roundServiceRef or roundServiceRef.getState() ~= "ROUND_ACTIVE"
		or not aliveRoot(victimPlayer) or PlayerStateService.getRole(victimPlayer) ~= PlayerRoles.RUNNER
		or PlayerStateService.isPlayerFrozen(victimPlayer) then return false end
	if jugadas().escudo(victimPlayer) then return false end   -- power-up ESCUDO: aguanta un impacto
	local character = victimPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp then return end

	-- Inmovilizar completamente físicas y salto
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	-- Bloqueo total de inercia y movimiento
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.Anchored = true

	freezeSerial += 1
	freezes[victimPlayer] = { character = character, roundId = ReplicatedStorage:GetAttribute("RoundId"), remaining = FREEZE_DURATION }
	victimPlayer:SetAttribute("FreezeSerial", freezeSerial)
	character:SetAttribute("FreezeSerial", freezeSerial)
	victimPlayer:SetAttribute("FreezeTimeLeft", FREEZE_DURATION)
	character:SetAttribute("FreezeTimeLeft", FREEZE_DURATION)
	character:SetAttribute("ZeroSprinting", false)

	-- Atributo Frozen
	victimPlayer:SetAttribute("Status", PlayerStatus.FROZEN)
	character:SetAttribute("Status", PlayerStatus.FROZEN)

	-- Visuales congeladas (Cian/Blanco)
	setHighlight(character, ROLE_COLORS.Frozen.Fill, ROLE_COLORS.Frozen.Outline)
	setOverheadTag(character, "[CONGELADO]", ROLE_COLORS.Frozen.Fill)

	-- ProximityPrompt de rescate
	local existingPrompt = hrp:FindFirstChild("RescuePrompt")
	if existingPrompt then
		existingPrompt:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RescuePrompt"
	prompt.ActionText = "Rescatar"
	prompt.ObjectText = "Compañero"
	prompt.HoldDuration = RESCUE_DURATION
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = RESCUE_RANGE
	prompt.Parent = hrp

	prompt.PromptButtonHoldBegan:Connect(function(rescuer)
		PlayerStateService.requestRescue(rescuer, victimPlayer)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(rescuer)
		local hold = rescueHolds[rescuer]
		task.delay(.1, function()
			if rescueHolds[rescuer] == hold then rescueHolds[rescuer] = nil end
		end)
	end)
	prompt.Triggered:Connect(function(rescuer)
		PlayerStateService.requestRescue(rescuer, victimPlayer)
	end)
	if PlayerStateService.isHuman(victimPlayer) then DataService.incrementStat(victimPlayer, "times_frozen", 1) end

	-- Comprobar condición de victoria inmediata
	pcall(function() jugadas().congelado(victimPlayer, cazador) end)
	if roundServiceRef then
		roundServiceRef.checkWinCondition()
	end
	return true
end

-- Inicialización
function PlayerStateService.init(roundService: any, combatService: any?)
	roundServiceRef = roundService
	combatServiceRef = combatService

	local function setupPlayer(player: any)
		if not player:GetAttribute("Role") then
			player:SetAttribute("Role", PlayerRoles.LOBBY)
		end
		if not player:GetAttribute("Status") then
			player:SetAttribute("Status", PlayerStatus.ACTIVE)
		end

		local function onCharacterAdded(character: Model)
			local currentRole = PlayerStateService.getRole(player)
			character:SetAttribute("Role", currentRole)
			character:SetAttribute("Status", PlayerStatus.ACTIVE)

			if currentRole ~= PlayerRoles.LOBBY then
				PlayerStateService.setRole(player, currentRole)
			end

			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				removeVisualsAndPrompt(character)
				if combatServiceRef then
					combatServiceRef.removeKnife(player)
				end
				if roundServiceRef then
					roundServiceRef.checkWinCondition()
				end
			end)
		end

		if player.Character then
			task.spawn(onCharacterAdded, player.Character)
		end
		player.CharacterAdded:Connect(onCharacterAdded)
	end

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerAdded:Connect(setupPlayer)

	Players.PlayerRemoving:Connect(function(player)
		leaving[player] = true
		freezes[player] = nil
		task.delay(1, function() leaving[player] = nil end)
		rescueHolds[player] = nil
		local role = PlayerStateService.getRole(player)

		if role == PlayerRoles.HUNTER and roundServiceRef then
			task.defer(function()
				if not PlayerStateService.hasActiveHunter() then
					print("[PlayerStateService] El Hunter se desconectó. Terminando ronda...")
					roundServiceRef.setState("ROUND_END", "El Hunter abandonó la partida.")
				end
			end)
		elseif role == PlayerRoles.RUNNER and roundServiceRef then
			task.defer(function()
				roundServiceRef.checkWinCondition()
			end)
		end
	end)

	print("[PlayerStateService] Inicializado con sistema de congelamiento, rescate e interacción.")
end

return PlayerStateService

