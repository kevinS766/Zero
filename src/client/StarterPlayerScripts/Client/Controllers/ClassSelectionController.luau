local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkEvents = require(Shared.Network.NetworkEvents)
local Config = require(Shared.Config.HunterClassConfig)
local UI = require(ReplicatedStorage:WaitForChild("ZeroUI"))
local C = UI.Colors
local ClassSelectionController = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local promptEvent = NetworkEvents.getRemoteEvent("ClassSelectionPrompt")
local requestEvent = NetworkEvents.getRemoteEvent("ClassSelectionRequest")
local confirmedEvent = NetworkEvents.getRemoteEvent("ClassSelectionConfirmed")
local statusEvent = NetworkEvents.getRemoteEvent("RoundStatusUpdate")
local gui, panel, scale, timerLabel, progress, footer
local cards = {}
local endsAt, duration = 0, 15
local selectedClass = Config.DEFAULT_CLASS
local confirmed = false
local initialized = false
local meta = {
 Tracker={title="RASTREADOR", subtitle="Encuentra a quien se esconde",
  description=string.format("Revela las siluetas de los corredores durante %ds.", Config.Classes.Tracker.RevealDuration), icon="tracker", color=C.yellow},
 Stalker={title="ACECHADOR", subtitle="Acércate sin ser visto",
  description=string.format("Invisibilidad y velocidad aumentada durante %ds.", Config.Classes.Stalker.Duration), icon="hunter", color=C.purple},
 Trapper={title="TRAMPERO", subtitle="Controla las rutas de escape",
  description=string.format("Coloca hasta %d trampas que congelan a los corredores.", Config.Classes.Trapper.MaxTraps), icon="trap", color=C.blue},
}
local function new(class, parent, props)
 local object=Instance.new(class)
 for key,value in pairs(props) do object[key]=value end
 object.Parent=parent
 return object
end
local function corner(object,radius)
 new("UICorner",object,{CornerRadius=UDim.new(0,radius)})
end
local function stroke(object,color,width)
 return new("UIStroke",object,{Name="Outline",Color=color,Thickness=width,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function frame(parent,name,x,y,w,h,color)
 local object=new("Frame",parent,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color,BorderSizePixel=0})
 corner(object,14)
 return object
end
local function text(parent,name,value,x,y,w,h,size,color)
 return new("TextLabel",parent,{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
  BackgroundTransparency=1,Font=Enum.Font.FredokaOne,TextSize=size,TextColor3=color,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center})
end
local function texture(object,alpha)
 local image=new("ImageLabel",object,{Name="StudTexture",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
  Image="rbxassetid://"..UI.StudTexture,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(36,36),ImageTransparency=alpha})
 corner(image,14)
end
local function hide()
 if gui then gui.Enabled=false end
end
local function updateSelection()
 for id,card in pairs(cards) do
  local selected=id==selectedClass
  card.Outline.Color=selected and C.green or C.ink
  card.Outline.Thickness=selected and 4 or 3
  card.Action.BackgroundColor3=selected and C.green or meta[id].color
  card.Action.Label.Text=selected and "✓  ELEGIDA" or "ELEGIR"
  card:SetAttribute("Selected",selected)
 end
 if footer then
  footer.Text=confirmed and (meta[selectedClass].title.." CONFIRMADO • Puedes cambiar hasta que empiece la ronda.")
   or "Si no eliges, serás RASTREADOR. Tu habilidad se activa con F."
  footer.TextColor3=confirmed and C.green or C.muted
 end
end
local function resize()
 local size=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
 local portrait=size.X<600 and size.Y>size.X
 local count=#Config.ORDER
 local width,height=portrait and 360 or 40+count*278-14,portrait and 230+count*158 or 510   -- se adapta al número de clases
 panel.Size=UDim2.fromOffset(width,height)
 scale.Scale=math.min(1,(size.X-32)/width,(size.Y-40)/height)
 panel.Header.Size=UDim2.new(1,-12,0,84)
 panel.Header.Title.Size=UDim2.new(1,-80,0,38)
 panel.Header.Subtitle.Size=UDim2.new(1,-80,0,26)
 timerLabel.Size=UDim2.new(1,-40,0,27)
 panel.Track.Size=UDim2.new(1,-40,0,9)
 footer.Position=UDim2.fromOffset(20,height-57)
 footer.Size=UDim2.new(1,-40,0,43)
 local close=panel.Header:FindFirstChild("Close"); if close then close.Position=UDim2.fromOffset(width-74,15) end
 for i,id in ipairs(Config.ORDER) do
  local card=cards[id]
  card.Position=UDim2.fromOffset(portrait and 20 or 20+(i-1)*278,portrait and 158+(i-1)*158 or 158)
  card.Size=UDim2.fromOffset(portrait and 320 or 264,portrait and 148 or 288)
  card.Title.Position=UDim2.fromOffset(portrait and 111 or 8,portrait and 10 or 12)
  card.Title.Size=UDim2.fromOffset(portrait and 198 or 248,27)
  card.Title.TextSize=portrait and 20 or 23
  card.Icon.Position=UDim2.fromOffset(portrait and 11 or 84,portrait and 15 or 48)
  card.Icon.Size=UDim2.fromOffset(portrait and 88 or 96,portrait and 88 or 96)
  card.Description.Position=UDim2.fromOffset(portrait and 112 or 13,portrait and 41 or 153)
  card.Description.Size=UDim2.fromOffset(portrait and 193 or 238,portrait and 51 or 57)
  card.Description.TextSize=portrait and 16 or 18
  card.Cooldown.Position=UDim2.fromOffset(portrait and 9 or 10,portrait and 108 or 215)
  card.Cooldown.Size=UDim2.fromOffset(portrait and 96 or 244,22)
  card.Cooldown.TextSize=portrait and 13 or 17
  card.Action.Position=UDim2.fromOffset(portrait and 113 or 15,portrait and 103 or 244)
  card.Action.Size=UDim2.fromOffset(portrait and 193 or 234,33)
 end
end
local function refreshTimer()
 if not gui.Enabled then return end
 local remaining=math.max(0,math.ceil(endsAt-Workspace:GetServerTimeNow()))
 timerLabel.Text=string.format("LA RONDA COMIENZA EN  %02d:%02d", math.floor(remaining/60),remaining%60)
 progress.Size=UDim2.fromScale(math.clamp(remaining/duration,0,1),1)
 if remaining==0 then hide() end
end
local function build()
 local old=playerGui:FindFirstChild("HunterClassSelect")
 if old then old:Destroy() end
 gui=new("ScreenGui",playerGui,{Name="HunterClassSelect",ResetOnSpawn=false,DisplayOrder=100,IgnoreGuiInset=true,Enabled=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 new("Frame",gui,{Name="Shade",Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BackgroundTransparency=.32,BorderSizePixel=0,Active=true})
 panel=frame(gui,"MainContainer",0,0,860,510,C.panel)
 panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
 stroke(panel,C.ink,4);texture(panel,.91)
 scale=new("UIScale",panel,{Name="ResponsiveScale",Scale=1})
 local header=frame(panel,"Header",6,6,848,84,C.pink)
 texture(header,.65)
 new("UIGradient",header,{Rotation=90,Color=ColorSequence.new(C.pink:Lerp(C.white,.18),C.pink:Lerp(C.ink,.2))})
 new("ImageLabel",header,{Name="HunterIcon",Position=UDim2.fromOffset(13,12),Size=UDim2.fromOffset(57,57),BackgroundTransparency=1,Image="rbxassetid://"..UI.Icons.hunter})
 local title=text(header,"Title","ERES EL CAZADOR",76,10,756,38,29,C.white);title.TextXAlignment=Enum.TextXAlignment.Left
 local sub=text(header,"Subtitle","Elige tu estilo de caza",76,49,756,26,18,C.white);sub.TextXAlignment=Enum.TextXAlignment.Left
 -- cerrar sin elegir: se queda la clase marcada (o la de por defecto)
 local close=new("TextButton",header,{Name="Close",Text="×",Position=UDim2.fromOffset(786,15),Size=UDim2.fromOffset(52,52),BackgroundColor3=C.ink,
  TextColor3=C.white,Font=Enum.Font.FredokaOne,TextSize=34,AutoButtonColor=true,BorderSizePixel=0})
 corner(close,12);stroke(close,C.white,2)
 close.Activated:Connect(hide)
 timerLabel=text(panel,"TimerLabel","",20,107,820,27,21,C.yellow)
 local track=frame(panel,"Track",20,141,820,9,C.ink);track.ClipsDescendants=true
 progress=frame(track,"Progress",0,0,820,9,C.yellow);progress.Size=UDim2.fromScale(1,1)
 for _,id in ipairs(Config.ORDER) do
  local info=meta[id]
  local card=new("TextButton",panel,{Name="Button_"..id,Size=UDim2.fromOffset(264,288),Text="",AutoButtonColor=false,BackgroundColor3=C.card,BorderSizePixel=0})
  corner(card,14);stroke(card,C.ink,3);texture(card,.87)
  local top=frame(card,"Accent",0,0,264,6,info.color);top.Size=UDim2.new(1,0,0,6)
  text(card,"Title",info.title,8,12,248,27,23,info.color)
  new("ImageLabel",card,{Name="Icon",BackgroundTransparency=1,Image=info.image or ("rbxassetid://"..UI.Icons[info.icon]),ScaleType=Enum.ScaleType.Fit})
  text(card,"Description",info.description,13,153,238,57,18,C.white)
  text(card,"Cooldown",string.format("F  •  Recarga %ds",Config.Classes[id].Cooldown),10,215,244,22,17,C.muted)
  local action=frame(card,"Action",15,244,234,33,info.color)
  corner(action,9);texture(action,.7)
  local label=text(action,"Label","ELEGIR",0,0,234,33,19,C.ink);label.Size=UDim2.fromScale(1,1)
  card.Activated:Connect(function()
   if gui.Enabled and Workspace:GetServerTimeNow()<endsAt then requestEvent:FireServer(id) end
  end)
  cards[id]=card
 end
 footer=text(panel,"Footer","",20,453,820,43,17,C.muted)
 updateSelection();resize()
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
 if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
end
function ClassSelectionController.init()
 if initialized then return end
 initialized=true
 build()
 promptEvent.OnClientEvent:Connect(function(data)
  duration=math.max(1,tonumber(data.duration) or 15)
  endsAt=tonumber(data.endsAt) or Workspace:GetServerTimeNow()+duration
  selectedClass=meta[data.defaultClass] and data.defaultClass or Config.DEFAULT_CLASS
  confirmed=false
  updateSelection()
  local zeroUI=playerGui:FindFirstChild("ZeroUI")
  if zeroUI and zeroUI:FindFirstChild("UIAction") then zeroUI.UIAction:Invoke("Open",nil) end
  gui.Enabled=true;resize();refreshTimer()
 end)
 confirmedEvent.OnClientEvent:Connect(function(data)
  if data.success and meta[data.classId] then
   selectedClass=data.classId;confirmed=true;updateSelection()
  end
  if data.final then hide() end
 end)
 statusEvent.OnClientEvent:Connect(function(data)
  if data.state~="INTERMISSION" then hide()
  elseif gui.Enabled then endsAt=tonumber(data.endsAt) or endsAt;refreshTimer() end
 end)
 local elapsed=0
 RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt
  if elapsed>=.1 then elapsed=0;refreshTimer() end
 end)
 gui:SetAttribute("ControllerReady",true)
 print("[ClassSelectionController] Selección sincronizada con la ronda.")
end
return ClassSelectionController
