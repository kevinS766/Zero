local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local library=RS:WaitForChild("ZeroAnimations")
local ids={}
if RunService:IsStudio() then
 local preview=RS:WaitForChild("ZeroAnimationPreview",15)
 if preview then
  for _,seq in preview:GetChildren() do
   local ok,id=pcall(function() return game:GetService("AnimationClipProvider"):RegisterAnimationClip(seq) end)
   if ok then ids[seq.Name]=id else warn("[ZeroAnimations] Preview failed",seq.Name,id) end
  end
 end
end
for _,a in library:GetChildren() do if a:IsA("Animation") and a.AnimationId~="" then ids[a.Name]=a.AnimationId end end
local dashTracks={};local currentCharacter=nil;local dashConfig=require(RS.Shared.Config.DashConfig)
local function configure(character)
 currentCharacter=character;dashTracks={}
 local h=character:WaitForChild("Humanoid")
 if h.RigType~=Enum.HumanoidRigType.R15 then warn("[ZeroAnimations] R15 rig required");return end
 local animate=character:WaitForChild("Animate",10);if not animate then return end
 local animator=h:WaitForChild("Animator")
 local assignments={idle="Idle",walk="Walk",run="Run",jump="Jump"}
 local applied=0
 for state,name in assignments do
  if ids[name] then
   local set=animate:WaitForChild(state,5)
   if set then for _,a in set:GetDescendants() do if a:IsA("Animation") then a.AnimationId=ids[name];applied+=1 end end end
  end
 end
 for _,name in {"DashFront","DashBack","DashLeft","DashRight"} do if ids[name] then
  local a=Instance.new("Animation");a.AnimationId=ids[name]
  local t=animator:LoadAnimation(a);t.Priority=Enum.AnimationPriority.Action;t.Looped=false;dashTracks[name]=t;a:Destroy()
 end end
 -- Restart default locomotion once after replacing IDs, keeping its built-in state handling.
 for _,t in animator:GetPlayingAnimationTracks() do if t.Priority==Enum.AnimationPriority.Core or t.Priority==Enum.AnimationPriority.Idle or t.Priority==Enum.AnimationPriority.Movement then t:Stop(.1) end end
 character:SetAttribute("ZeroAnimationsApplied",applied)
 character:SetAttribute("ZeroAnimationRig","R15")
 local connection
 connection=player:GetAttributeChangedSignal("Status"):Connect(function()
  if character~=currentCharacter then connection:Disconnect();return end
  if player:GetAttribute("Status")=="Frozen" then for _,t in dashTracks do t:Stop(.05) end end
 end)
 h.Died:Once(function() connection:Disconnect();for _,t in dashTracks do t:Stop(0) end end)
end
RS:WaitForChild("NetworkEvents"):WaitForChild("DashFeedback").OnClientEvent:Connect(function(data)
 if not data.success or player:GetAttribute("Status")=="Frozen" then return end
 local char=player.Character;local h=char and char:FindFirstChildOfClass("Humanoid");local root=char and char:FindFirstChild("HumanoidRootPart")
 if not h or not root then return end
 local d=root.CFrame:VectorToObjectSpace(h.MoveDirection)
 local name=math.abs(d.X)>math.abs(d.Z) and (d.X>0 and "DashRight" or "DashLeft") or (d.Z>0.1 and "DashBack" or "DashFront")
 local track=dashTracks[name];if not track then return end
 for _,t in dashTracks do t:Stop(.04) end
 local speed=track.Length>0 and track.Length/dashConfig.DURATION or 1
 track:Play(.04,1,speed)
end)
player.CharacterAdded:Connect(configure)
if player.Character then task.spawn(configure,player.Character) end

