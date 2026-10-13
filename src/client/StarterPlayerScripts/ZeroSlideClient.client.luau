-- ZeroSlideClient (LocalScript, StarterPlayerScripts): deslizarse por el suelo con la C (botón DESLIZAR en móvil).
-- El impulso es local (sin esperar al servidor, como el dash): LinearVelocity solo en horizontal, que arranca fuerte y
-- frena con ease-out hasta casi la velocidad de andar; se puede corregir un poco la dirección y saltar lo cancela
-- conservando la inercia. El atributo ZeroDeslizando lo lee ZeroMovement (animación Slide); el servidor lo vuelve a
-- poner para que el resto de jugadores también vea el deslizamiento.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlideConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SlideConfig"))
local remote = ReplicatedStorage:WaitForChild("ZeroSlideRequest") :: RemoteEvent
local player = Players.LocalPlayer

local lastSlide = -math.huge
local sliding = false

local function slide()
	if sliding or os.clock() - lastSlide < SlideConfig.COOLDOWN then return end
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not h or not root or h.Health <= 0 or root.Anchored or h.WalkSpeed <= 0 then return end
	if player:GetAttribute("Status") == "Frozen" or h.FloorMaterial == Enum.Material.Air then return end
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < SlideConfig.MIN_SPEED then return end

	sliding, lastSlide = true, os.clock()
	local dir = flat.Unit
	local startSpeed = math.min(math.max(SlideConfig.START_SPEED, flat.Magnitude * SlideConfig.BOOST), SlideConfig.START_SPEED * 1.15)
	local endSpeed = h.WalkSpeed * SlideConfig.END_FACTOR
	character:SetAttribute("ZeroDeslizando", true)
	remote:FireServer(dir)

	local att = Instance.new("Attachment"); att.Name = "ZeroSlideAttachment"; att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ZeroSlideVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(SlideConfig.MAX_FORCE, 0, SlideConfig.MAX_FORCE)
	lv.VectorVelocity = dir * startSpeed
	lv.Parent = root
	h.AutoRotate = false
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)

	local t = 0
	local conn
	local function finish()
		if not sliding then return end
		sliding = false
		conn:Disconnect()
		lv:Destroy(); att:Destroy()
		if h.Parent then h.AutoRotate = true end
		if character.Parent then character:SetAttribute("ZeroDeslizando", false) end
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		local k = math.min(t / SlideConfig.DURATION, 1)
		if k >= 1 or h.Health <= 0 or not root.Parent or player:GetAttribute("Status") == "Frozen" then finish(); return end
		if h.Jump or h:GetState() == Enum.HumanoidStateType.Jumping then finish(); return end   -- salto: conserva la inercia
		-- corrección suave hacia donde se pulsa (nunca media vuelta)
		local want = Vector3.new(h.MoveDirection.X, 0, h.MoveDirection.Z)
		if want.Magnitude > 0.1 and want.Unit:Dot(dir) > -0.2 then
			local d = dir:Lerp(want.Unit, math.min(1, SlideConfig.STEER * dt))
			if d.Magnitude > 1e-3 then dir = d.Unit end
		end
		local ease = 1 - (1 - k) ^ 2                        -- ease-out: frena más al final
		lv.VectorVelocity = dir * (startSpeed + (endSpeed - startSpeed) * ease)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end)
	h.Died:Once(finish)
end

ContextActionService:BindAction("ZeroDeslizar", function(_, state)
	if state == Enum.UserInputState.Begin then slide() end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.C, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("ZeroDeslizar", "DESLIZAR")
ContextActionService:SetPosition("ZeroDeslizar", UDim2.new(1, -170, 1, -150))
