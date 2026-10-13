local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Audio=require(game.ReplicatedStorage:WaitForChild("ZeroAudio"))
local player=Players.LocalPlayer
local sprint=game.ReplicatedStorage:WaitForChild("ZeroSprintRequest")
local held=false
local function setSprint(value)
 if held==value then return end;held=value;sprint:FireServer(value)
end
local function isShift(key) return key==Enum.KeyCode.LeftShift or key==Enum.KeyCode.RightShift end
UIS.InputBegan:Connect(function(input,processed)
 if processed or UIS:GetFocusedTextBox() then return end
 if isShift(input.KeyCode) then setSprint(true) end
end)
UIS.InputEnded:Connect(function(input)
 if isShift(input.KeyCode) then
  setSprint(UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift))
 end
end)
UIS.WindowFocusReleased:Connect(function()setSprint(false)end)
UIS.TextBoxFocused:Connect(function()setSprint(false)end)
player.CharacterAdded:Connect(function()held=false;sprint:FireServer(false)end)
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local mouse=player:GetMouse()
-- rescate con shift-lock: mientras se ve el aviso "Rescatar" el cursor bloqueado se esconde (se rescata con E)
local PPS=game:GetService("ProximityPromptService")
local rescates=0
PPS.PromptShown:Connect(function(p) if p.Name=="RescuePrompt" then rescates+=1 end end)
PPS.PromptHidden:Connect(function(p) if p.Name=="RescuePrompt" then rescates=math.max(0,rescates-1) end end)
local iconoOculto=false
local enabled=false
local applied=nil
UIS.InputBegan:Connect(function(input,processed)
 if processed or UIS:GetFocusedTextBox() then return end
 if input.KeyCode==Enum.KeyCode.LeftControl or input.KeyCode==Enum.KeyCode.RightControl then enabled=not enabled;Audio.play("Toggle") end
end)
-- Use the public mouse API; current Roblox clients no longer expose PlayerModule.
RunService:BindToRenderStep("ZeroCtrlLock",Enum.RenderPriority.Camera.Value+1,function()
 local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
 local root=c and c:FindFirstChild("HumanoidRootPart")
 local gui=player.PlayerGui:FindFirstChild("ZeroUI");local modal=gui and gui:FindFirstChild("Modal")
 local active=enabled and h and h.Health>0 and root and not UIS:GetFocusedTextBox() and not GuiService.MenuIsOpen and not (modal and modal.Visible)
 if active then
  if not applied or applied.h~=h then applied={h=h,offset=h.CameraOffset,rotate=h.AutoRotate,icon=mouse.Icon} end
  UIS.MouseBehavior=Enum.MouseBehavior.LockCenter;mouse.Icon="rbxasset://textures/MouseLockedCursor.png"
  h.AutoRotate=false;h.CameraOffset=Vector3.new(1.75,0,0)
  local camera=workspace.CurrentCamera
  if camera and not root.Anchored then
   local look=camera.CFrame.LookVector;local flat=Vector3.new(look.X,0,look.Z)
   if flat.Magnitude>.001 then root.CFrame=CFrame.lookAt(root.Position,root.Position+flat) end
  end
 elseif applied then
  applied.h.AutoRotate=applied.rotate;applied.h.CameraOffset=applied.offset;mouse.Icon=applied.icon
  UIS.MouseBehavior=Enum.MouseBehavior.Default;applied=nil
 end
 local ocultar=active and rescates>0 or false
 if ocultar~=iconoOculto then iconoOculto=ocultar;UIS.MouseIconEnabled=not ocultar end
 player:SetAttribute("ZeroMouseLocked",active and true or false)
end)
player:SetAttribute("ZeroControlsReady",true)

