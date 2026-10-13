local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local UserInputService=game:GetService('UserInputService')
local GuiService=game:GetService('GuiService')
local TweenService=game:GetService('TweenService')
local RunService=game:GetService('RunService')
local player=Players.LocalPlayer
local DashController=require(player:WaitForChild('PlayerScripts'):WaitForChild('Client'):WaitForChild('Controllers'):WaitForChild('DashController'))
local HunterAbilityController=require(player:WaitForChild('PlayerScripts'):WaitForChild('Client'):WaitForChild('Controllers'):WaitForChild('HunterAbilityController'))
local UI=require(ReplicatedStorage:WaitForChild('ZeroUI'))
local playerGui=player:WaitForChild('PlayerGui')
local gui=playerGui:WaitForChild('ZeroUI',10)
if not gui then gui=UI.build(playerGui) end
local hud,modal,shade=gui.HUD,gui.Modal,gui.Shade
local currentMenu=nil
local giftDesde=nil   -- REGALA UN PASE abierto desde la Tienda: la X vuelve a ella
local roundPhase=nil
local roundTime=nil
local roundEndsAt=0
local roundPhases={WAITING_FOR_PLAYERS='Lobby',INTERMISSION='Intermission',ROUND_ACTIVE='Playing',ROUND_END='Ending'}
local volumes={Music=.5,SFX=.5}   -- 50 % por defecto; luego se carga lo que guardó el jugador
local Audio=require(ReplicatedStorage:WaitForChild('ZeroAudio'))
local muted=false
local reducedMotion=false
local noticeId=0
-- Solo quien está DENTRO de la ronda (corredor/cazador) pierde los menús; AFK, espectadores y recién llegados los conservan
local function enJuego() local r=player:GetAttribute('Role');return roundPhase=='Playing' and (r=='Runner' or r=='Hunter') end
local function notify(message,kind)
 if enJuego() and currentMenu~='Settings' then return end
 if gui:GetAttribute('ControllerReady') and kind~='Silent' then Audio.play(kind or 'Notify') end
 noticeId+=1;local id=noticeId;gui.Toast.Message.Text=message;gui.Toast.Visible=true
 task.delay(4,function() if noticeId==id then gui.Toast.Visible=false end end)
end
local wheelController=require(ReplicatedStorage:WaitForChild('ZeroWheelController')).new(gui,notify)
local function openMenu(name)
 local role=player:GetAttribute('Role')
 if name and enJuego() and name~='Settings' then return false end
 if name and not table.find(UI.MenuOrder,name) then return false end
 if name=='Gift' then giftDesde=(currentMenu=='Shop' or currentMenu=='Gift') and (giftDesde or 'Shop') or nil elseif name~=nil then giftDesde=nil end
 if currentMenu~=name then Audio.play(name and 'Open' or 'Close') end
 currentMenu=name
 modal.Visible=name~=nil;shade.Visible=name~=nil
 for _,n in ipairs(modal:GetChildren()) do if n:IsA('Frame') then n.Visible=n.Name==name or n.Name==(name or '')..'_Shadow' end end
 gui:SetAttribute('CurrentMenu',name or '')
 modal.ModalScale.Scale=math.min(name=='Wheel' and 1.35 or 1,(gui.AbsoluteSize.X-36)/920,(gui.AbsoluteSize.Y-74)/680)
 if UserInputService.GamepadEnabled and name then GuiService.SelectedObject=name=='Wheel' and modal.Wheel.Body.Close or modal[name].Header.Close end
 return true
end
local function remoteRequest(action,payload)
 local remote=ReplicatedStorage:FindFirstChild('ZeroUIRequest')
 if not remote or not remote:IsA('RemoteFunction') then
  notify('Esta función estará disponible cuando se active en ZERO.','Error');return false
 end
 local ok,result=pcall(function() return remote:InvokeServer(action,payload) end)
 if not ok or type(result)~='table' then notify('No se pudo completar. Inténtalo de nuevo.','Error');return false end
 notify(result.message or (result.success and '¡Listo!' or 'No disponible.'),result.success and 'Success' or 'Error')
 return result.success==true
end
local function chooseClass(name)
 if not table.find({'Rastreador','Acechador','Trampero'},name) then return false end
 gui:SetAttribute('SelectedClass',name)
 for _,c in ipairs(modal.Classes.Body:GetChildren()) do if c:IsA('Frame') and c:FindFirstChild('Action') then c.Action.Text=c.Action:GetAttribute('Class')==name and 'ELEGIDA' or 'ELEGIR' end end
 notify(name..' seleccionado para esta sesión.')
 return true
end
-- Espectador: solo cámara local; sigue a humanos y bots con rol Runner/Hunter.
local spectating=nil
local spectateBar=hud.SpectateBar
local function spectateTargets()
 local list={}
 for _,p in ipairs(Players:GetPlayers()) do local r=p:GetAttribute('Role');local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid');if p~=player and (r=='Runner' or r=='Hunter') and h and h.Health>0 then table.insert(list,{name=p.DisplayName,hum=h,model=p.Character}) end end
 local bots=workspace:FindFirstChild('ZeroBots')
 if bots then for _,m in ipairs(bots:GetChildren()) do local r=m:GetAttribute('Role');local h=m:FindFirstChildOfClass('Humanoid');if (r=='Runner' or r=='Hunter') and h and h.Health>0 then table.insert(list,{name=h.DisplayName,hum=h,model=m}) end end end
 return list
end
local function stopSpectating()
 if not spectating then return end
 spectating=nil;spectateBar.Visible=false
 local h=player.Character and player.Character:FindFirstChildOfClass('Humanoid');if h then workspace.CurrentCamera.CameraSubject=h end
end
local function spectateStep(dir)
 local list=spectateTargets()
 if #list==0 then stopSpectating();notify('No hay nadie jugando ahora.','Error');return false end
 local i=1
 for k,t in ipairs(list) do if spectating and t.hum==spectating.hum then i=k+dir end end
 spectating=list[(i-1)%#list+1]
 workspace.CurrentCamera.CameraSubject=spectating.hum;spectateBar.Visible=true
 return true
end
spectateBar.Prev.Activated:Connect(function() spectateStep(-1) end)
spectateBar.Next.Activated:Connect(function() spectateStep(1) end)
spectateBar.Exit.Activated:Connect(stopSpectating)
local function action(name,payload)
 if name=='Spectate' then if roundPhase~='Playing' then notify('No hay una ronda activa.','Error');return false end;openMenu(nil);return spectateStep(0) end
 if name=='Spin' then return wheelController.spin() end
 if name=='WheelPurchase' then return wheelController.comprar(payload and payload.index) end
 if name=='Ability' then if player:GetAttribute('Role')=='Runner' then return DashController.request() elseif player:GetAttribute('Role')=='Hunter' then return HunterAbilityController.request() end end
 if name=='Open' then return openMenu(payload) end
 if name=='Close' then return openMenu(nil) end
 if name=='SelectClass' then return chooseClass(payload) end
 if name=='Redeem' then
  local code=modal.Settings.Body.CodeInput.Text:match('^%s*(.-)%s*$')
  if #code<1 or #code>64 then modal.Settings.Body.Result.Text='Escribe un código válido.';Audio.play('Error');return false end
  return remoteRequest(name,{code=code})
 end
 return remoteRequest(name,payload or {})
end
local dispatch=Instance.new('BindableFunction');dispatch.Name='UIAction';dispatch.Parent=gui;dispatch.OnInvoke=action
for _,n in ipairs(gui:GetDescendants()) do if n:IsA('TextButton') then
 n.Activated:Connect(function()
  if n.Name=='Close' and currentMenu=='Gift' and giftDesde then openMenu(giftDesde)
  elseif n==shade or n.Name=='Close' then openMenu(nil)
  elseif n.Name=='Open_Spectate' then action('Spectate')   -- directo al espectador (sin el panel PARTIDA EN CURSO)
  elseif n.Name=='Open_Codes' then openMenu(nil);local s=ReplicatedStorage:FindFirstChild('ZeroMisionesAbrir');if s then s:Fire() end   -- botón MISIONES
  elseif n.Name:sub(1,5)=='Open_' then local name=n.Name:sub(6);openMenu(currentMenu==name and nil or name)
  elseif n:GetAttribute('Menu') then openMenu(n:GetAttribute('Menu'))
  elseif n:GetAttribute('Class') then chooseClass(n:GetAttribute('Class'))
  elseif n:GetAttribute('Action') then action(n:GetAttribute('Action'),{product=n:GetAttribute('Product'),index=n:GetAttribute('Index')})
  end
 end)
 n:SetAttribute('BaseColor',n.BackgroundColor3)
 local origPos=n.Position
 if n:FindFirstChild('Surface') then
  n:GetPropertyChangedSignal('Text'):Connect(function() n.ButtonText.Text=n.Text end)
  n:GetPropertyChangedSignal('TextSize'):Connect(function() n.ButtonText.TextSize=n.TextSize end)
  n:GetPropertyChangedSignal('BackgroundColor3'):Connect(function() local color=n.BackgroundColor3;n.Surface.UIGradient.Color=ColorSequence.new(color:Lerp(UI.Colors.white,.22),color:Lerp(UI.Colors.ink,.12)) end)
  n.MouseEnter:Connect(function()
   if not reducedMotion then
    TweenService:Create(n,TweenInfo.new(.1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=n:GetAttribute('BaseColor'):Lerp(UI.Colors.white,.18),Position=UDim2.new(origPos.X.Scale,origPos.X.Offset,origPos.Y.Scale,origPos.Y.Offset-2)}):Play()
   end
  end)
  n.MouseLeave:Connect(function()
   TweenService:Create(n,TweenInfo.new(.1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=n:GetAttribute('BaseColor'),Position=origPos}):Play()
  end)
  n.MouseButton1Down:Connect(function()
   TweenService:Create(n,TweenInfo.new(.05,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(origPos.X.Scale,origPos.X.Offset,origPos.Y.Scale,origPos.Y.Offset+4)}):Play()
  end)
  n.MouseButton1Up:Connect(function()
   TweenService:Create(n,TweenInfo.new(.1,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(origPos.X.Scale,origPos.X.Offset,origPos.Y.Scale,origPos.Y.Offset-2)}):Play()
  end)
 end
end end
for name,y in pairs({Tab_Passes=0,Tab_Coins=352,Tab_Packs=639}) do modal.Shop.Body[name].Activated:Connect(function() modal.Shop.Body.CanvasPosition=Vector2.new(0,y) end) end
local function applyAudio() Audio.setLevels(volumes.Music,volumes.SFX,muted) end
applyAudio()
local dragging=nil
local function paintVolume(key)
 local n=modal.Settings.Body[key];local value=volumes[key]
 n.Fill.Size=UDim2.fromOffset(346*value,13);n.Volume.Position=UDim2.fromOffset(388+346*value,24);n.Value.Text=math.floor(value*100+.5)..'%'
 local sh=n:FindFirstChild('Volume_Shadow');if sh then sh.Position=UDim2.fromOffset(388+346*value,30) end   -- la sombra sigue al tirador
end
local function setVolume(key,position)
 local n=modal.Settings.Body[key];local track=n.Track
 local value=math.clamp((position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
 local previous=volumes[key]
 volumes[key]=value;paintVolume(key);applyAudio();if math.floor(previous*10)~=math.floor(value*10) then Audio.play('Hover') end
end
-- Volumen guardado por jugador: ZeroWheelServer lo publica en AjusteMusica/AjusteSFX y lo guarda al soltar el deslizador
local function loadVolumes()
 if dragging then return end
 local m,s=player:GetAttribute('AjusteMusica'),player:GetAttribute('AjusteSFX')
 if type(m)=='number' then volumes.Music=math.clamp(m,0,1) end
 if type(s)=='number' then volumes.SFX=math.clamp(s,0,1) end
 paintVolume('Music');paintVolume('SFX');applyAudio()
end
local function saveVolumes()
 task.spawn(function() pcall(function() ReplicatedStorage:WaitForChild('ZeroUIRequest'):InvokeServer('GuardarAjustes',{music=volumes.Music,sfx=volumes.SFX}) end) end)
end
loadVolumes()
player:GetAttributeChangedSignal('AjusteMusica'):Connect(loadVolumes)
player:GetAttributeChangedSignal('AjusteSFX'):Connect(loadVolumes)
for _,key in ipairs({'Music','SFX'}) do
 local n=modal.Settings.Body[key];n.Track.Active=true
 for _,surface in ipairs({n.Track,n.Volume}) do surface.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging={key=key,input=input};setVolume(key,input.Position) end end) end
end
UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input==dragging.input) then setVolume(dragging.key,input.Position) end end)
UserInputService.InputEnded:Connect(function(input) if dragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or input==dragging.input) then dragging=nil;saveVolumes() end end)
-- Modo AFK: el servidor (ZeroWheelServer → atributo AFK) hace que RoundService no te meta en las partidas
local afkBtn=modal.Settings.Body:FindFirstChild('AFK')
local function paintAFK() if afkBtn then afkBtn.Text=player:GetAttribute('AFK') and 'AFK: ACTIVADO' or 'AFK: DESACTIVADO' end end
if afkBtn then
 afkBtn.Activated:Connect(function()
  local want=not player:GetAttribute('AFK')
  local ok,res=pcall(function() return ReplicatedStorage:WaitForChild('ZeroUIRequest'):InvokeServer('SetAFK',{on=want}) end)
  if ok and res and res.success then Audio.play('Toggle');notify(want and 'Modo AFK activado: no entrarás a las partidas.' or 'Modo AFK desactivado: entrarás en la próxima partida.','Silent') else notify('No se pudo cambiar el modo AFK.','Error') end
 end)
 player:GetAttributeChangedSignal('AFK'):Connect(paintAFK);paintAFK()
end
modal.Settings.Body.ReduceMotion.Activated:Connect(function() reducedMotion=not reducedMotion;gui:SetAttribute('ReducedMotion',reducedMotion);modal.Settings.Body.ReduceMotion.Text=reducedMotion and 'EFECTOS: REDUCIDOS' or 'EFECTOS: ACTIVADOS' end)
modal.Settings.Body.CloseHint.Activated:Connect(function() muted=not muted;modal.Settings.Body.CloseHint.Text=muted and 'SONIDO: SILENCIADO' or 'SONIDO: ACTIVADO';applyAudio();if not muted then Audio.play('Toggle') end end)
UserInputService.InputBegan:Connect(function(input,processed)
 if processed then return end
 if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then openMenu(nil)
 elseif input.KeyCode==Enum.KeyCode.ButtonX then if hud.Skill.Visible then action('Ability',{class=gui:GetAttribute('SelectedClass')}) end end
end)
hud.Skill.Activated:Connect(function() action('Ability',{class=gui:GetAttribute('SelectedClass')}) end)
local function refreshPlayers()
 local b=modal.Gift.Body
 for _,n in ipairs(b.Players:GetChildren()) do n:Destroy() end
 local i=0
 for _,p in ipairs(Players:GetPlayers()) do if p~=player then
  local n=Instance.new('TextButton');n.Name='GiftTo_'..p.UserId;n.Position=UDim2.fromOffset(0,i*72);n.Size=UDim2.fromOffset(880,62);n.BackgroundColor3=UI.Colors.card;n.TextColor3=UI.Colors.white;n.TextSize=25;n.Font=Enum.Font.FredokaOne;n.Text=p.DisplayName..'  →  REGALAR';n.Parent=b.Players;n.Activated:Connect(function() action('Gift',{recipientUserId=p.UserId}) end);i+=1
 end end
 b.Empty.Visible=i==0;b.Players.Size=UDim2.fromOffset(880,math.max(280,i*72))
end
Players.PlayerAdded:Connect(refreshPlayers);Players.PlayerRemoving:Connect(function() task.defer(refreshPlayers) end);refreshPlayers()
local function attr(name,default) local v=player:GetAttribute(name);if v==nil then v=ReplicatedStorage:GetAttribute(name) end;if v==nil then return default end;return v end
-- tiempo que falta para el regalo por tiempo nº i (TiempoInicio/TiempoMetas los pone ZeroWheelServer)
local function faltaRegalo(i)
 local inicio,metas=player:GetAttribute('TiempoInicio'),player:GetAttribute('TiempoMetas')
 if type(inicio)~='number' or type(metas)~='string' or not i then return nil end
 local meta=tonumber((string.split(metas,','))[i]);if not meta then return nil end
 local r=math.max(0,math.ceil(inicio+meta-workspace:GetServerTimeNow()))
 return r>=3600 and string.format('⏳ %d:%02d:%02d',r//3600,(r//60)%60,r%60) or string.format('⏳ %02d:%02d',r//60,r%60)
end
local function update()
 hud.Visible=currentMenu~='Wheel'
 local state=player:GetAttribute('Status')=='Frozen' and 'Frozen' or player:GetAttribute('Role') or attr('ZeroState','Lobby')
 local phase=roundPhase or attr('ZeroPhase','Lobby');local playing=phase=='Playing';local jugando=enJuego()
 -- Sala del Cazador (RoundService.sendToHunterPlatform): solo Inventario y Ajustes; el resto de menús se cierra
 local sala=workspace:FindFirstChild('ZeroSalaCazador');local spawnSala=sala and sala:FindFirstChild('HunterSpawn',true)
 local raiz=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local enSala=(spawnSala and raiz and (raiz.Position-spawnSala.Position).Magnitude<60) and not jugando or false
 gui:SetAttribute('EnSalaCazador',enSala)
 if enSala and currentMenu and not table.find({'Classes','Settings','Titulos'},currentMenu) then openMenu(nil) end
 if jugando and currentMenu and currentMenu~='Settings' and currentMenu~='Spectate' then openMenu(nil) end
 hud.RoundStatus.Phase.Text=({Lobby='ESPERANDO JUGADORES',Intermission='SIGUIENTE RONDA',Starting='PREPÁRATE',Playing='TIEMPO RESTANTE',Ending='RONDA TERMINADA'})[phase] or string.upper(phase)
 local remaining=roundEndsAt>0 and math.max(0,math.ceil(roundEndsAt-workspace:GetServerTimeNow())) or roundTime or tonumber(attr('RoundTimeLeft',nil))
 hud.RoundStatus.Timer.Text=phase=='Lobby' and string.format('%d / %d',#Players:GetPlayers(),ReplicatedStorage:GetAttribute('RoundMinPlayers') or 2) or remaining and string.format('%02d:%02d',math.floor(math.max(remaining,0)/60),math.floor(math.max(remaining,0)%60)) or 'ZERO'
 local lobby=workspace:FindFirstChild('ZeroLobby')
 local display=lobby and lobby:FindFirstChild('TimerDisplay')
 local screen=display and display:FindFirstChild('Screen')
 local sign=screen and screen:FindFirstChild('TimerGui')
 if sign and sign:FindFirstChild('TimerText') then sign.TimerText.Text=hud.RoundStatus.Timer.Text end
 local runners=attr('RunnerCount',nil);local count=#Players:GetPlayers();hud.RoundStatus.Counts.Text=runners and tostring(runners)..' CORREDORES RESTANTES' or playing and 'PERSECUCIÓN EN CURSO' or tostring(count)..(count==1 and ' JUGADOR CONECTADO' or ' JUGADORES CONECTADOS')
 if gui:GetAttribute('RolMostrado')~=state then gui:SetAttribute('RolMostrado',state);gui:SetAttribute('RolDesde',os.clock()) end
 hud.Role.Visible=playing and state~='Lobby' and not (state=='Hunter' and os.clock()-(gui:GetAttribute('RolDesde') or 0)>4)   -- cazador: el aviso solo 4 s (estorbaba al combo)
 hud.Currency.Visible=not jugando and not enSala
 local legacyRole=playerGui:FindFirstChild('RoleHUD');if legacyRole then legacyRole.Enabled=false end
 hud.Role.RoleText.Text=({Lobby='',Runner='CORREDOR  •  ESCAPA Y RESCATA',Frozen='CONGELADO  •  ESPERA UN RESCATE',HunterTransition='INFECCIÓN  •  PREPÁRATE',Hunter='CONGELA A TODOS',Spectator='ESPECTADOR'})[state] or tostring(state)
 hud.Role.BackgroundColor3=(state=='Hunter' or state=='HunterTransition') and UI.Colors.pink or UI.Colors.blue
 hud.Offers.Visible=not jugando and not enSala and not gui:GetAttribute('CompactLayout');hud.Navigation.Visible=not jugando
 for _,b in ipairs(hud.Navigation:GetChildren()) do if b:IsA('GuiObject') then b.Visible=not enSala or b.Name=='Open_Classes' or (b.Name=='Open_Classes_Shadow' and not gui:GetAttribute('CompactLayout')) end end
 hud.Open_Spectate.Visible=(state=='Lobby' or state=='Spectator') and not spectating and not enSala
 hud.Skill.Visible=playing and (state=='Runner' or state=='Hunter')
 for _,n in ipairs(hud:GetChildren()) do if n:IsA('TextButton') then local shadow=hud:FindFirstChild(n.Name..'_Shadow');if shadow then shadow.Visible=n.Visible and not gui:GetAttribute('CompactLayout') end end end
 local isStalking=player:GetAttribute('StalkerStealth')==true
 hud.Skill.Text=state=='Hunter' and (isStalking and 'F  •  CANCELAR' or ('F  •  '..string.upper(({Tracker='RASTREADOR',Stalker='ACECHADOR',Trapper='TRAMPERO'})[player:GetAttribute('HunterClass')] or gui:GetAttribute('SelectedClass') or 'PULSO'))) or 'Q  •  DASH'
 hud.Skill.Icon_dash.Image='rbxassetid://'..UI.Icons[state=='Hunter' and 'hunter' or 'dash']
 hud.FrozenState.Visible=playing and state=='Frozen';local freeze=tonumber(attr('InfectionTimeLeft',nil));hud.FrozenState.Countdown.Text=freeze and tostring(math.ceil(freeze))..'s' or '—'
 local progress=tonumber(attr('RescueProgress',0)) or 0;hud.RescueState.Visible=playing and progress>0;hud.RescueState.Fill.Size=UDim2.fromOffset((gui:GetAttribute('CompactLayout') and 320 or 490)*math.clamp(progress,0,1),9)
 local ls=player:FindFirstChild('leaderstats');local money=ls and (ls:FindFirstChild('Coins') or ls:FindFirstChild('Cash'));local gems=ls and ls:FindFirstChild('Gems');local cVal=money and money.Value or attr('Coins',0);local gVal=gems and gems.Value or attr('Gems',0);hud.Currency.Amount.Text=string.format('%s 🪙 | %s 💎',tostring(cVal),tostring(gVal));for _,pd in ipairs({{n='Product_1',p='VIP'},{n='Product_2',p='DOUBLE_COINS'},{n='Product_3',p='DOUBLE_GEMS'},{n='Product_4',p='DOUBLE_XP'}}) do local pf=modal.Shop.Body:FindFirstChild(pd.n);if pf and pf:FindFirstChild('Action') then local owned=player:GetAttribute('HasPass_'..pd.p)==true or player:GetAttribute('SimulatedPass_'..pd.p)==true;if owned then pf.Action.Text='ADQUIRIDO';if pf.Action:FindFirstChild('ButtonText') then pf.Action.ButtonText.Text='ADQUIRIDO' end end end end
 for _,n in ipairs(modal.Stats.Body:GetChildren()) do if n:IsA('Frame') and n:GetAttribute('StatName') then local value=ls and ls:FindFirstChild(n:GetAttribute('StatName'));n.Value.Text=tostring(value and value.Value or attr(n:GetAttribute('StatName'),'—')) end end
 modal.Spectate.Body.Status.Text=playing and 'Hay una persecución en curso.' or 'No hay una ronda activa.'
 local spins=attr('Spins',nil);modal.Wheel.Body.Balance.Text='Giros disponibles: '..tostring(spins or '—')
 local rewardState=player
 local lv=hud.Level;lv.Visible=not jugando and not enSala
 local level,xp,need=player:GetAttribute('Level') or 1,player:GetAttribute('XP') or 0,player:GetAttribute('XPNext') or 100
 lv.LevelText.Text=gui:GetAttribute('CompactLayout') and ('NV '..level..'  '..xp..'/'..need) or ('NIVEL '..level..'  •  '..xp..'/'..need..' XP')
 lv.Track.Fill.Size=UDim2.fromScale(math.clamp(xp/need,0,1),1)
 if spectating then
  local role=player:GetAttribute('Role')
  if not playing or role=='Runner' or role=='Hunter' then stopSpectating()
  elseif not spectating.hum.Parent or spectating.hum.Health<=0 or not table.find({'Runner','Hunter'},spectating.model:GetAttribute('Role') or (Players:GetPlayerFromCharacter(spectating.model) and Players:GetPlayerFromCharacter(spectating.model):GetAttribute('Role'))) then spectateStep(1) end
  if spectating then
   local p=Players:GetPlayerFromCharacter(spectating.model);local r=(p or spectating.model):GetAttribute('Role');local frozen=(p or spectating.model):GetAttribute('Status')=='Frozen'
   spectateBar.Target.Text=string.upper(spectating.name);spectateBar.Hint.Text=frozen and 'CONGELADO' or r=='Hunter' and 'CAZADOR' or 'CORREDOR'
  end
 end
 for _,panelName in ipairs({'Daily','Time'}) do for _,n in ipairs(modal[panelName].Body:GetChildren()) do if n:IsA('Frame') and n:FindFirstChild('Action') then
  local flag=rewardState and rewardState:GetAttribute(panelName..tostring(n.Action:GetAttribute('Index')))
  n.Action.Text=flag=='Ready' and 'RECLAMAR' or flag=='Claimed' and 'OBTENIDO' or (panelName=='Time' and faltaRegalo(n.Action:GetAttribute('Index'))) or 'BLOQUEADO'
  local color=flag=='Ready' and UI.Colors.green or flag=='Claimed' and UI.Colors.blue or UI.Colors.card
  n.Action.BackgroundColor3=color;n.Action:SetAttribute('BaseColor',color);n.Action.Surface.UIGradient.Color=ColorSequence.new(color:Lerp(UI.Colors.white,.15),color:Lerp(UI.Colors.ink,.15))
 end end end
end
local defaults={}
for _,n in ipairs(hud:GetDescendants()) do if n:IsA('GuiObject') then defaults[n]={Position=n.Position,Size=n.Size};if n:IsA('TextLabel') or n:IsA('TextButton') then defaults[n].TextSize=n.TextSize end end end
local lastSize=nil
local lastMenuSize=nil
local function resize()
 local camera=workspace.CurrentCamera;if not camera then return end
 local size=gui:GetAttribute('PreviewViewport') or gui.AbsoluteSize;if size==lastSize and currentMenu==lastMenuSize then return end;lastSize=size;lastMenuSize=currentMenu
 for n,props in pairs(defaults) do for key,value in pairs(props) do n[key]=value end end
 local mobile=size.X<1100 or size.Y<600
 local scale=math.min(size.X/1600,(size.Y-8)/900)
 hud.HUDScale.Scale=scale
 hud.Position=UDim2.fromOffset((size.X-1600*scale)/2,(size.Y-900*scale)/2)
 modal.Size=UDim2.fromOffset(920,650)
 modal.ModalScale.Scale=math.min(currentMenu=='Wheel' and 1.35 or 1,(size.X-36)/920,(size.Y-74)/(currentMenu=='Wheel' and 680 or 650))
 if currentMenu=='Wheel' then wheelController.resize(size) end
 gui.Toast.Size=UDim2.fromOffset(math.min(610,size.X-30),64)
 gui.Toast.Message.Size=UDim2.new(1,-32,1,-10)
 gui.Toast.Position=UDim2.new(.5,0,0,mobile and size.Y-76 or 250)
 gui:SetAttribute('CompactLayout',mobile)
 if mobile then
  hud.HUDScale.Scale=1;hud.Position=UDim2.fromOffset(0,0);hud.Size=UDim2.fromOffset(size.X,size.Y)
  hud.Currency.Position=UDim2.fromOffset(12,12);hud.Currency.Size=UDim2.fromOffset(145,48)
  hud.Currency.Icon_coins.Position=UDim2.fromOffset(6,6);hud.Currency.Icon_coins.Size=UDim2.fromOffset(36,36)
  hud.Currency.Amount.Position=UDim2.fromOffset(50,3);hud.Currency.Amount.Size=UDim2.fromOffset(89,40);hud.Currency.Amount.TextSize=23
  hud.RoundStatus.Position=UDim2.fromOffset((size.X-270)/2,7);hud.RoundStatus.Size=UDim2.fromOffset(270,77);hud.RoundStatus.Inner.Size=UDim2.fromOffset(260,67)
  hud.RoundStatus.Phase.Position=UDim2.fromOffset(8,4);hud.RoundStatus.Phase.Size=UDim2.fromOffset(254,21);hud.RoundStatus.Phase.TextSize=15
  hud.RoundStatus.Timer.Position=UDim2.fromOffset(35,23);hud.RoundStatus.Timer.Size=UDim2.fromOffset(200,39);hud.RoundStatus.Timer.TextSize=31
  hud.RoundStatus.Counts.Position=UDim2.fromOffset(8,57);hud.RoundStatus.Counts.Size=UDim2.fromOffset(254,18);hud.RoundStatus.Counts.TextSize=12
  hud.Role.Position=UDim2.fromOffset((size.X-270)/2,99);hud.Role.Size=UDim2.fromOffset(270,34);hud.Role.RoleText.Size=UDim2.fromOffset(246,30);hud.Role.RoleText.TextSize=14
  hud.Open_Settings.Position=UDim2.fromOffset(size.X-64,12);hud.Open_Settings.Size=UDim2.fromOffset(50,50);hud.Open_Settings.Icon_settings.Size=UDim2.fromOffset(36,36)
  hud.Navigation.Position=UDim2.fromOffset(12,78)
  for i,v in ipairs({'Shop','Group','Daily','Codes','Classes','Stats','Wheel','Time'}) do local n=hud.Navigation['Open_'..v];n.Position=UDim2.fromOffset(((i-1)%2)*78,math.floor((i-1)/2)*73);n.Size=UDim2.fromOffset(70,66);n.Label.Position=UDim2.fromOffset(1,44);n.Label.Size=UDim2.fromOffset(68,20);n.Label.TextSize=14;for _,child in ipairs(n:GetChildren()) do if child:IsA('ImageLabel') and child.Name:sub(1,5)=='Icon_' then child.Position=UDim2.fromOffset(15,2);child.Size=UDim2.fromOffset(40,40) end end;local s=hud.Navigation:FindFirstChild(n.Name..'_Shadow');if s then s.Visible=false end end
  hud.Skill.Position=UDim2.fromOffset(size.X-200,size.Y-77);hud.Skill.Size=UDim2.fromOffset(184,61);hud.Skill.TextSize=19;hud.Skill.Icon_dash.Size=UDim2.fromOffset(55,55)
  hud.FrozenState.Position=UDim2.fromOffset((size.X-350)/2,size.Y-99);hud.FrozenState.Size=UDim2.fromOffset(350,84);hud.FrozenState.State.Size=UDim2.fromOffset(237,34);hud.FrozenState.State.TextSize=25;hud.FrozenState.Countdown.Position=UDim2.fromOffset(270,7);hud.FrozenState.Countdown.Size=UDim2.fromOffset(72,38);hud.FrozenState.Countdown.TextSize=29;hud.FrozenState.Hint.Position=UDim2.fromOffset(14,44);hud.FrozenState.Hint.Size=UDim2.fromOffset(320,27);hud.FrozenState.Hint.TextSize=17
  hud.RescueState.Position=UDim2.fromOffset((size.X-350)/2,size.Y-163);hud.RescueState.Size=UDim2.fromOffset(350,58);hud.RescueState.Progress.Size=UDim2.fromOffset(326,28);hud.RescueState.Progress.TextSize=19;hud.RescueState.Track.Size=UDim2.fromOffset(320,9)
  hud.Level.Position=UDim2.fromOffset(12,62);hud.Level.Size=UDim2.fromOffset(145,14);hud.Level.Track.Position=UDim2.fromOffset(0,0);hud.Level.Track.Size=UDim2.fromOffset(145,14);hud.Level.LevelText.Position=UDim2.fromOffset(0,-1);hud.Level.LevelText.Size=UDim2.fromOffset(145,16);hud.Level.LevelText.TextSize=12;hud.Level.LevelText.ZIndex=3
  hud.SpectateBar.Position=UDim2.fromOffset((size.X-430)/2,size.Y-70);hud.SpectateBar.Size=UDim2.fromOffset(430,60);hud.SpectateBar.Prev.Size=UDim2.fromOffset(48,44);hud.SpectateBar.Prev.Position=UDim2.fromOffset(6,8);hud.SpectateBar.Target.Position=UDim2.fromOffset(58,4);hud.SpectateBar.Target.Size=UDim2.fromOffset(200,30);hud.SpectateBar.Target.TextSize=20;hud.SpectateBar.Hint.Position=UDim2.fromOffset(58,32);hud.SpectateBar.Hint.Size=UDim2.fromOffset(200,22);hud.SpectateBar.Hint.TextSize=14;hud.SpectateBar.Next.Size=UDim2.fromOffset(48,44);hud.SpectateBar.Next.Position=UDim2.fromOffset(264,8);hud.SpectateBar.Exit.Size=UDim2.fromOffset(104,44);hud.SpectateBar.Exit.Position=UDim2.fromOffset(318,8);hud.SpectateBar.Exit.TextSize=18
  hud.Open_Spectate.Position=UDim2.fromOffset((size.X-210)/2,142);hud.Open_Spectate.Size=UDim2.fromOffset(210,44);hud.Open_Spectate.TextSize=18
  for _,n in ipairs(hud:GetDescendants()) do if n:IsA('GuiObject') and n.Name:sub(-7)=='_Shadow' then n.Visible=false end end
 else
  hud.Size=UDim2.fromOffset(1600,900)
  for _,n in ipairs(hud:GetDescendants()) do if n:IsA('GuiObject') and n.Name:sub(-7)=='_Shadow' then local owner=n.Parent:FindFirstChild(n.Name:sub(1,-8));n.Visible=owner and owner:IsA('GuiObject') and owner.Visible or false
   elseif n:IsA('GuiObject') and n.Name=='Stud' then n.Visible=true end end
 end
end
local camera=workspace.CurrentCamera
if camera then camera:GetPropertyChangedSignal('ViewportSize'):Connect(resize) end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(resize)
local roundRemote=ReplicatedStorage:WaitForChild('NetworkEvents'):WaitForChild('RoundStatusUpdate')
local function receiveRoundStatus(data)
 local previous=roundPhase
 roundPhase=roundPhases[data.state] or roundPhase
 roundTime=tonumber(data.timer)
 roundEndsAt=tonumber(data.endsAt) or 0
 if enJuego() and previous~='Playing' then
  openMenu(nil);noticeId+=1;gui.Toast.Visible=false
 end
 update();resize()
end
roundRemote.OnClientEvent:Connect(receiveRoundStatus)
receiveRoundStatus({state=ReplicatedStorage:GetAttribute('RoundState'),timer=ReplicatedStorage:GetAttribute('RoundTimeLeft'),endsAt=ReplicatedStorage:GetAttribute('RoundEndsAt')})
chooseClass('Rastreador');openMenu(nil);resize();update();gui.Toast.Visible=false
local elapsed=0;RunService.Heartbeat:Connect(function(dt) elapsed+=dt;if elapsed>.25 then elapsed=0;update();resize() end end)
local lastLevel=player:GetAttribute('Level')
-- Al entrar, Level pasa de 1 (datos aún sin cargar) a tu nivel guardado: eso no es subir de nivel.
-- Solo se anuncia cuando los datos ya están cargados (StatsLoaded) y ha pasado un segundo.
local levelReady=false
local function armLevel() if player:GetAttribute('StatsLoaded') then task.delay(1,function() lastLevel=player:GetAttribute('Level');levelReady=true end) end end
player:GetAttributeChangedSignal('StatsLoaded'):Connect(armLevel);armLevel()
player:GetAttributeChangedSignal('Level'):Connect(function() local l=player:GetAttribute('Level');if levelReady and lastLevel and l and l>lastLevel then notify('¡Subiste a NIVEL '..l..'!','Success') end;lastLevel=l end)
gui:SetAttribute('ControllerReady',true)

