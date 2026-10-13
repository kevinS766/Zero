local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local event=Instance.new("RemoteEvent");event.Name="ZeroSprintRequest";event.Parent=RS
local states={}
local MAX_SPEED=40   -- tope de seguridad (cazador con sprint y power-up incluidos)
-- WalkSpeed se guarda con menos precisión que un número de Luau: 21.6*1.35 no vuelve igual. Con ~= se tomaba la propia
-- velocidad como "cambio de otro script" y se volvía a multiplicar en bucle (power-up VELOCIDAD hasta 2.5e12)
local function igual(a,b) return math.abs(a-b)<0.05 end
local function refresh(player)
 local s=states[player];if not s or not s.h.Parent then return end
 -- Si otro servicio cambió WalkSpeed y su señal aún no llegó (p. ej. setRole pone Status antes que WalkSpeed al
 -- convertir en Hunter), esa velocidad es la nueva base: no pisarla con la base antigua (dejaba al Hunter a 0).
 if not igual(s.h.WalkSpeed,s.applied) then s.base=s.h.WalkSpeed end
 local blocked=player:GetAttribute("Status")=="Frozen" or s.h.Health<=0
 local speed=blocked and 0 or s.base
 if not blocked and speed>0 and s.held then speed+=6 end
 -- ralentizado de la habilidad Común (ZeroHabilidadArmaServer pone ZeroLento = multiplicador mientras dura)
 local lento=player:GetAttribute("ZeroLento")
 if type(lento)=="number" and speed>0 then speed*=lento end
 -- power-up VELOCIDAD (ServerScriptService.ZeroJugadas pone ZeroVeloz = multiplicador mientras dura)
 local veloz=player:GetAttribute("ZeroVeloz")
 if type(veloz)=="number" and speed>0 then speed*=veloz end
 speed=math.min(speed,MAX_SPEED)
 s.applied=speed;s.h.WalkSpeed=speed
 if player.Character then player.Character:SetAttribute("ZeroSprinting",s.held and not blocked and s.base>0) end
end
local function watch(player)
 player:GetAttributeChangedSignal("Status"):Connect(function()refresh(player)end)
 player:GetAttributeChangedSignal("ZeroLento"):Connect(function()refresh(player)end)
 player:GetAttributeChangedSignal("ZeroVeloz"):Connect(function()refresh(player)end)
 local function characterAdded(character)
  local old=states[player]
  if old then old.changed:Disconnect() end
  local h=character:WaitForChild("Humanoid")
  if player.Character~=character then return end
  local s={h=h,base=h.WalkSpeed,applied=h.WalkSpeed,held=false};states[player]=s
  s.changed=h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
   -- Preserve speed changes from class abilities, freeze and rescue services.
   if not igual(h.WalkSpeed,s.applied) then s.base=h.WalkSpeed;refresh(player) end
  end)
  refresh(player)
 end
 player.CharacterAdded:Connect(characterAdded)
 if player.Character then task.spawn(characterAdded,player.Character) end
end
event.OnServerEvent:Connect(function(player,held)
 if typeof(held)~="boolean" then return end
 local s=states[player];if not s then return end
 s.held=held and player:GetAttribute("Status")~="Frozen" and s.h.Health>0
 refresh(player)
end)
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player)
 local s=states[player];if s then s.changed:Disconnect() end;states[player]=nil
end)
for _,player in Players:GetPlayers() do watch(player) end

