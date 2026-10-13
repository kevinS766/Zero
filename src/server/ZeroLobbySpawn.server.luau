-- ZeroLobbySpawn (Script, ServerScriptService): al aparecer en el lobby, el personaje queda de pie sobre el suelo.
-- El aparecedor de Roblox sube al personaje hasta que no toca nada, y sobre el spawn cuelgan banderines y la luz del
-- aro: aparecía ~30 studs arriba y caía. Aquí se recoloca a ras del suelo en cuanto aparece (solo en el lobby).
local Players = game:GetService("Players")
local pad = workspace:WaitForChild("ZeroLobby"):WaitForChild("SpawnZone"):WaitForChild("LobbySpawnPlano")

local function onCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local h = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not root or not h then return end
	task.wait()                                              -- dejar que Roblox lo coloque primero
	local top = pad.Position.Y + pad.Size.Y / 2
	local flat = Vector3.new(root.Position.X - pad.Position.X, 0, root.Position.Z - pad.Position.Z)
	if flat.Magnitude > pad.Size.X / 2 + 4 or root.Position.Y < top + 6 then return end   -- no es el spawn del lobby, o ya está bien
	local height = if h.RigType == Enum.HumanoidRigType.R6 then 3 else h.HipHeight + root.Size.Y / 2
	local _, yaw = root.CFrame:ToOrientation()
	-- un poco de dispersión para que varios jugadores no aparezcan unos dentro de otros
	local spread = Vector3.new(math.random(-40, 40) / 10, 0, math.random(-40, 40) / 10)
	character:PivotTo(CFrame.new(pad.Position.X + spread.X, top + height, pad.Position.Z + spread.Z) * CFrame.Angles(0, yaw, 0))
	root.AssemblyLinearVelocity = Vector3.zero
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
