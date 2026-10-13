--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DashConfig = require(Shared:WaitForChild("Config"):WaitForChild("DashConfig"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local DashService = {}
local playerStateServiceRef: any = nil
local roundServiceRef: any = nil
local DataService = require(script.Parent.DataService)
local Debris = game:GetService("Debris")
local dashRequestEvent: RemoteEvent = NetworkEvents.getRemoteEvent("DashRequest")
local dashExecuteEvent: RemoteEvent = NetworkEvents.getRemoteEvent("DashExecute")
local lastDashTimestamps: { [number]: { [string]: number } } = {}   -- UserId -> tipo -> os.clock()

function DashService.requestDash(player: any, direction: any)
	if not playerStateServiceRef or not playerStateServiceRef.isRegistered(player) then return false end
	if typeof(direction) ~= "Vector3" then return end
	local magnitude = direction.Magnitude
	if magnitude ~= magnitude or magnitude <= 0.1 or magnitude > 1.01 or math.abs(direction.Y) > 0.01 then return end
	if player:GetAttribute("Status") ~= "Active"
		or (playerStateServiceRef and playerStateServiceRef.isPlayerFrozen(player)) then return end
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp or humanoid.Health <= 0 or hrp.Anchored or humanoid.WalkSpeed <= 0 then return end
	-- MoveDirection se envía desde el cliente para no depender del retraso de la física replicada.
	local now = os.clock()
	local tipo = DashConfig.tipo(hrp.CFrame.LookVector, direction.Unit)
	local ultimos = lastDashTimestamps[player.UserId] or {}
	lastDashTimestamps[player.UserId] = ultimos
	local extra = false
	if now - (ultimos[tipo] or -math.huge) < DashConfig.COOLDOWNS[tipo] then
		if ((player:GetAttribute("ZeroDashExtra") or 0) :: number) <= 0 then return end   -- power-up: un dash más
		extra = true
	end
	if not playerStateServiceRef.isHuman(player) then
		if not roundServiceRef or roundServiceRef.getState() ~= "ROUND_ACTIVE"
			or (playerStateServiceRef.getRole(player) ~= "Runner" and playerStateServiceRef.getRole(player) ~= "Hunter")
			or (humanoid.MoveDirection.Magnitude < .1 and Vector3.new(hrp.AssemblyLinearVelocity.X,0,hrp.AssemblyLinearVelocity.Z).Magnitude < 1) then return false end
		local attachment = Instance.new("Attachment")
		attachment.Name = "ZeroBotDash"
		attachment.Parent = hrp
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.MaxForce = math.huge
		velocity.VectorVelocity = direction.Unit * DashConfig.SPEED + Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
		velocity.Parent = hrp
		Debris:AddItem(velocity, DashConfig.DURATION)
		Debris:AddItem(attachment, DashConfig.DURATION)
		character:SetAttribute("ZeroDashDirection",direction.Unit)
		character:SetAttribute("ZeroDashSerial", (character:GetAttribute("ZeroDashSerial") or 0) + 1)
	else
		dashExecuteEvent:FireClient(player, {
		speed = DashConfig.SPEED,
		duration = DashConfig.DURATION,
		cooldown = DashConfig.COOLDOWNS[tipo],
		tipo = tipo,
		extra = extra,
		direction = direction.Unit,
		character = character,
		})
		if roundServiceRef and roundServiceRef.getState() == "ROUND_ACTIVE" then
			DataService.incrementStat(player, "dashes_used", 1)
		end
	end
	if extra then player:SetAttribute("ZeroDashExtra", nil) else ultimos[tipo] = now end
	-- para la esquiva perfecta (ServerScriptService.ZeroJugadas): cuándo, desde dónde y qué dash
	character:SetAttribute("ZeroDashT", workspace:GetServerTimeNow())
	character:SetAttribute("ZeroDashPos", hrp.Position)
	character:SetAttribute("ZeroDashTipo", tipo)
	pcall(function() require(game:GetService("ServerScriptService"):WaitForChild("ZeroJugadas")).dash(character) end)   -- esquiva perfecta
	return true
end

-- esquiva perfecta: ese dash vuelve a estar listo
function DashService.resetear(actor: any, tipo: string)
	local ultimos = lastDashTimestamps[actor.UserId]
	if ultimos then ultimos[tipo] = nil end
end

function DashService.forgetActor(actor)
	lastDashTimestamps[actor.UserId] = nil
end

function DashService.init(roundService: any, playerStateService: any)
	roundServiceRef = roundService
	playerStateServiceRef = playerStateService
	dashRequestEvent.OnServerEvent:Connect(DashService.requestDash)
	Players.PlayerRemoving:Connect(function(player)
		lastDashTimestamps[player.UserId] = nil
	end)
end

return DashService


