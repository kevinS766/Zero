-- Editable sequences only replicate in Studio for local Animator previews.
local RunService=game:GetService("RunService")
if RunService:IsStudio() then
 local sources=game.ServerStorage:WaitForChild("ZeroParkourR15"):Clone()
 sources.Name="ZeroAnimationPreview";sources.Parent=game.ReplicatedStorage
end

