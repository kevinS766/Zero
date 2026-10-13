--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DashConfig = require(Shared:WaitForChild("Config"):WaitForChild("DashConfig"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local DashController = {}
local localPlayer = Players.LocalPlayer
local dashRequestEvent: RemoteEvent = NetworkEvents.getRemoteEvent("DashRequest")
local dashExecuteEvent: RemoteEvent = NetworkEvents.getRemoteEvent("DashExecute")
local lastClientDashTime: { [string]: number } = {}   -- tipo ("Frente" | "Atras" | "Lados") -> os.clock()
local lastRequestTime = -math.huge

local function executeLocalDash(data: { speed: number, duration: number, cooldown: number, direction: Vector3, character: Model })
	if not (data :: any).extra then lastClientDashTime[(data :: any).tipo or "Frente"] = os.clock() end
	local character = localPlayer.Character
	if not character or character ~= data.character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp or humanoid.Health <= 0 or hrp.Anchored
		or humanoid.WalkSpeed <= 0 or localPlayer:GetAttribute("Status") == "Frozen" then return end

	local dashDirection = data.direction
	local attachment = Instance.new("Attachment")
	attachment.Name = "DashLocalAttachment"
	attachment.Parent = hrp
	character:SetAttribute("ZeroDashDirection", dashDirection)
	character:SetAttribute("ZeroDashSerial", (character:GetAttribute("ZeroDashSerial") or 0) + 1)

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "ActiveDashVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = DashConfig.MAX_FORCE
	linearVelocity.VectorVelocity = dashDirection * data.speed
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent = hrp
	hrp.AssemblyLinearVelocity = Vector3.new(dashDirection.X * data.speed, hrp.AssemblyLinearVelocity.Y, dashDirection.Z * data.speed)
	task.delay(data.duration, function()
		linearVelocity:Destroy()
		attachment:Destroy()
	end)
end

function DashController.request()
	if UserInputService:GetFocusedTextBox() or localPlayer:GetAttribute("Status") == "Frozen" then return end
	local character = localPlayer.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp or humanoid.Health <= 0 or hrp.Anchored or humanoid.WalkSpeed <= 0 then return end
	local direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	if direction.Magnitude <= 0.1 then return end
	local now = os.clock()
	local tipo = (DashConfig :: any).tipo(hrp.CFrame.LookVector, direction.Unit)
	local enRecarga = now - (lastClientDashTime[tipo] or -math.huge) < (DashConfig :: any).COOLDOWNS[tipo]
	if (enRecarga and ((localPlayer:GetAttribute("ZeroDashExtra") or 0) :: number) <= 0) or now - lastRequestTime < 0.15 then return end
	-- La recarga empieza con la autorización; una petición rechazada no la consume.
	lastRequestTime = now
	dashRequestEvent:FireServer(direction.Unit)
end

function DashController.init()
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Q then DashController.request() end
	end)
	dashExecuteEvent.OnClientEvent:Connect(executeLocalDash)
	-- esquiva perfecta: el servidor recarga al momento el dash usado (ServerScriptService.ZeroJugadas)
	task.spawn(function()
		local jugadas = ReplicatedStorage:WaitForChild("ZeroJugadas") :: RemoteEvent
		jugadas.OnClientEvent:Connect(function(d: any)
			if d.kind == "DashReset" then lastClientDashTime[d.tipo] = nil end
		end)
	end)
end

return DashController
