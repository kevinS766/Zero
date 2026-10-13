-- El StarterCharacter R6 sale negro: le aplica el avatar del jugador sin tocar el Animate del juego.
local Players = game:GetService("Players")

local ANIM_FIELDS = {"IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation", "MoodAnimation"}

local function dress(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, player.UserId)
	if not ok then warn("[AvatarAppearance]", player.Name, desc) return end
	for _, field in ANIM_FIELDS do desc[field] = 0 end
	if not character:IsDescendantOf(workspace) then return end
	local applied, err = pcall(humanoid.ApplyDescription, humanoid, desc)
	if not applied then warn("[AvatarAppearance]", player.Name, err) end
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(character) dress(player, character) end)
	if player.Character then task.spawn(dress, player, player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do task.spawn(onPlayer, player) end
