-- ZeroLobbySpawnClient (LocalScript, StarterPlayerScripts): al aparecer en el lobby el personaje no cae.
-- El personaje llega al cliente en (0, 96, 0) antes de que llegue la posición real del aparecedor; como el cliente
-- manda en la física de su personaje, caía ~30 studs desde ahí. Durante el primer segundo, si está flotando sobre
-- el lobby, se coloca sobre el suelo del spawn (el servidor hace lo mismo en ZeroLobbySpawn).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local function onCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local h = character:WaitForChild("Humanoid", 5) :: Humanoid?
	local zone = workspace:FindFirstChild("ZeroLobby") and workspace.ZeroLobby:FindFirstChild("SpawnZone")
	local pad = zone and zone:WaitForChild("LobbySpawnPlano", 5) :: BasePart?
	if not root or not h or not pad then return end
	local top = pad.Position.Y + pad.Size.Y / 2
	local height = if h.RigType == Enum.HumanoidRigType.R6 then 3 else h.HipHeight + root.Size.Y / 2
	local spread = Vector3.new(math.random(-40, 40) / 10, 0, math.random(-40, 40) / 10)
	local t0 = os.clock()
	while os.clock() - t0 < 1 and character.Parent do
		local flat = Vector3.new(root.Position.X - pad.Position.X, 0, root.Position.Z - pad.Position.Z)
		if flat.Magnitude < 25 and root.Position.Y > top + height + 3 then
			local _, yaw = root.CFrame:ToOrientation()
			character:PivotTo(CFrame.new(pad.Position.X + spread.X, top + height, pad.Position.Z + spread.Z) * CFrame.Angles(0, yaw, 0))
			root.AssemblyLinearVelocity = Vector3.zero
		end
		RunService.Heartbeat:Wait()
	end
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then task.spawn(onCharacter, player.Character) end
