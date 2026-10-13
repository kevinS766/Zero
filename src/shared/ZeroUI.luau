-- ZERO arcade interface. All rewards and purchases remain server-authoritative.
local UI = {}
local C = {ink=Color3.fromRGB(16,28,56),panel=Color3.fromRGB(32,54,94),card=Color3.fromRGB(43,71,117),white=Color3.new(1,1,1),muted=Color3.fromRGB(185,205,236),blue=Color3.fromRGB(70,217,255),pink=Color3.fromRGB(255,76,134),purple=Color3.fromRGB(170,101,255),yellow=Color3.fromRGB(255,210,73),green=Color3.fromRGB(137,239,83),orange=Color3.fromRGB(255,156,65)}
UI.Colors=C
UI.StudTexture='93525206706340'
UI.Icons={vip='121372750120524',coins='118156773428904',gems='140160266592935',xp='131210159798052',coin1k='79648977525959',coin10k='118397196191192',coin100k='131662692839384',gem100='140160266592935',gem200='140160266592935',gem300='140160266592935',crate_common='110614295161773',crate_rare='118032236532957',crate_epic='132865529106248',crate_legendary='102237268781234',crate_secret='94790961838163',group='97134681504354',hunter='125712433050439',key='137520033297018',codes='81715434491963',daily='137581992429825',trap='135857197964778',shop='123138799783136',teleport='134573221399020',spectate='74058419100811',wheel='114964581966348',gift='131090287788942',settings='103600074351298',tracker='95172388130191',time='117983116167209',stats='132994886956732',rescue='79534706214139',pack='78832156311190',dash='80976416319834'}
UI.MenuOrder={'Shop','Daily','Time','Wheel','Codes','Settings','Group','Classes','Stats','Spectate','Gift'}
local function new(class,parent,props)
 local n=Instance.new(class);for k,v in pairs(props or {}) do n[k]=v end;n.Parent=parent;return n
end
local function corner(n,r)
 local c=n:FindFirstChildOfClass('UICorner') or new('UICorner',n)
 c.CornerRadius=UDim.new(0,r or 16)
end
local function stroke(n,color,width,alpha) return new('UIStroke',n,{Color=color or C.ink,Thickness=width or 3,Transparency=alpha or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function gradient(n,color)
 return new('UIGradient',n,{Rotation=90,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,color:Lerp(C.white,.22)),ColorSequenceKeypoint.new(1,color:Lerp(C.ink,.12))})})
end
local function frame(parent,name,x,y,w,h,color)
 local n=new('Frame',parent,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.panel,BorderSizePixel=0});corner(n);return n
end
local function label(parent,name,text,x,y,w,h,size,color,outline)
 local n=new('TextLabel',parent,{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=color or C.white,TextSize=size or 22,Font=Enum.Font.FredokaOne,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center});
 if outline then new('UIStroke',n,{Color=C.ink,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual}) end;return n
end
local function icon(parent,key,x,y,size)
 return new('ImageLabel',parent,{Name='Icon_'..key,Image='rbxassetid://'..assert(UI.Icons[key],key),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit})
end
local function pattern(parent,w,h,transparency)
 if parent:FindFirstChild('StudTexture') then return end
 local n=new('ImageLabel',parent,{Name='StudTexture',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image='rbxassetid://'..UI.StudTexture,ImageTransparency=transparency or .3,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(40,40),Active=false})
 local c=parent:FindFirstChildOfClass('UICorner');new('UICorner',n,{CornerRadius=c and c.CornerRadius or UDim.new(0,12)})
end
local function button(parent,name,text,x,y,w,h,color)
 local shadow=frame(parent,name..'_Shadow',x,y+6,w,h,C.ink);corner(shadow,12);shadow.BackgroundTransparency=.1
 local n=new('TextButton',parent,{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.green,BackgroundTransparency=1,BorderSizePixel=0,TextColor3=C.white,TextTransparency=1,TextSize=23,Font=Enum.Font.FredokaOne,AutoButtonColor=false,Selectable=true,ClipsDescendants=true});corner(n,12);stroke(n,C.ink,3)
 local surface=frame(n,'Surface',0,0,w,h,C.white);corner(surface,12);surface.Size=UDim2.fromScale(1,1);gradient(surface,color or C.green);pattern(n,w,h,.4)
 local inner=frame(n,'Bevel',3,3,w-6,h-6,C.white);inner.BackgroundTransparency=1;stroke(inner,C.white,1.5,.45);corner(inner,9);inner.Size=UDim2.new(1,-6,1,-6)
 local textLayer=label(n,'ButtonText',text,0,0,w,h,23,C.white,true);textLayer.Size=UDim2.fromScale(1,1);textLayer.TextXAlignment=Enum.TextXAlignment.Center
 return n
end
local function card(parent,name,title,key,x,y,w,h,color,subtitle,action)
 local n=frame(parent,name,x,y,w,h,color);stroke(n,C.ink,3);gradient(n,color);n.ClipsDescendants=true;pattern(n,w,h)
 local inner=frame(n,'InnerHighlight',4,4,w-8,h-8,C.white);inner.BackgroundTransparency=1;stroke(inner,C.white,2,.65)
 local glass=new('Frame',n,{Name='Glass',Position=UDim2.fromOffset(6,4),Size=UDim2.new(1,-12,0,8),BackgroundColor3=C.white,BackgroundTransparency=0.75,BorderSizePixel=0});corner(glass,4)
 local t=label(n,'Title',title,10,12,w-20,38,26,C.white,true);t.TextXAlignment=Enum.TextXAlignment.Center
 local size=math.min(132,h-157);icon(n,key,(w-size)/2,52,size)
 if subtitle then local sub=label(n,'Subtitle',subtitle,10,h-99,w-20,31,19,C.white,true);sub.TextXAlignment=Enum.TextXAlignment.Center end
 if action then button(n,'Action',action,13,h-62,w-26,47,C.green) end;return n
end

function UI.build(parent)
 local gui=new('ScreenGui',parent,{Name='ZeroUI',ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=30,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 gui:SetAttribute('DesignVersion','ZERO Arcade 1.1 • STUD')
 local hud=frame(gui,'HUD',0,0,1600,900,C.ink);hud.BackgroundTransparency=1
 new('UIScale',hud,{Name='HUDScale',Scale=1})
 local coins=frame(hud,'Currency',28,810,236,64,C.panel);stroke(coins,C.ink,4);pattern(coins,236,64,.75);icon(coins,'coins',10,7,50);label(coins,'Amount','—',72,7,150,49,33,C.green,true)
 local clock=frame(hud,'RoundStatus',600,18,400,112,C.panel);stroke(clock,C.ink,4);pattern(clock,400,112,.8);local clockInner=frame(clock,'Inner',5,5,390,102,C.panel);clockInner.BackgroundTransparency=1;stroke(clockInner,C.blue,2,.35)
 label(clock,'Phase','ESPERANDO JUGADORES',16,7,368,25,19,C.blue).TextXAlignment=Enum.TextXAlignment.Center
 label(clock,'Timer','ZERO',55,31,290,49,42,C.white,true).TextXAlignment=Enum.TextXAlignment.Center
 label(clock,'Counts','',12,83,376,24,16,C.muted).TextXAlignment=Enum.TextXAlignment.Center
 local role=frame(hud,'Role',550,144,500,47,C.blue);role.Visible=false;stroke(role,C.ink,3);gradient(role,C.blue);pattern(role,500,47,.6);label(role,'RoleText','',12,2,476,42,21,C.white,true).TextXAlignment=Enum.TextXAlignment.Center
 local menu=frame(hud,'Navigation',28,208,236,484,C.ink);menu.BackgroundTransparency=1
 local navs={{'Shop','TIENDA','shop','yellow'},{'Group','REGALOS','gift','green'},{'Daily','DIARIO','daily','pink'},{'Codes','MISIONES','codes','blue'},{'Classes','INVENTARIO','tracker','purple'},{'Stats','STATS','stats','orange'},{'Wheel','RULETA','wheel','purple'},{'Time','TIEMPO','time','pink'}}
 for i,v in ipairs(navs) do local x=((i-1)%2)*124;local y=math.floor((i-1)/2)*124;local b=button(menu,'Open_'..v[1],'',x,y,112,112,C[v[4]]);icon(b,v[3],23,8,66);label(b,'Label',v[2],4,77,104,29,19,C.white,true).TextXAlignment=Enum.TextXAlignment.Center end
 button(hud,'Open_Spectate','ESPECTAR PARTIDA',682,810,236,64,C.blue)
 local setting=button(hud,'Open_Settings','',1500,18,72,72,C.blue);icon(setting,'settings',8,8,56)
 local offers=frame(hud,'Offers',1460,270,112,360,C.ink);offers.BackgroundTransparency=1
 for i,v in ipairs({{'Shop','PACK ZERO','pack','purple'},{'Shop','2× COINS','coins','green'},{'Wheel','×5 GIROS','wheel','yellow'}}) do local b=button(offers,'Offer_'..i,'',0,(i-1)*124,112,112,C[v[4]]);b:SetAttribute('Menu',v[1]);icon(b,v[3],23,8,66);label(b,'Label',v[2],4,77,104,29,19,C.white,true).TextXAlignment=Enum.TextXAlignment.Center end
 local skill=button(hud,'Skill','Q  •  DASH',1336,810,236,64,C.blue);icon(skill,'dash',7,2,60);skill.Visible=false;skill.ButtonText.Position=UDim2.fromOffset(65,0);skill.ButtonText.Size=UDim2.new(1,-70,1,0)
 local frozen=frame(hud,'FrozenState',490,690,620,100,C.panel);stroke(frozen,C.blue,4);pattern(frozen,620,100,.85);frozen.Visible=false
 label(frozen,'State','¡CONGELADO!',18,5,350,39,30,C.blue,true);label(frozen,'Countdown','12s',477,8,120,50,39,C.pink,true)
 label(frozen,'Hint','Un compañero puede rescatarte',18,52,440,29,21,C.white)
 local rescue=frame(hud,'RescueState',540,605,520,62,C.panel);stroke(rescue,C.green,3);pattern(rescue,520,62,.85);rescue.Visible=false
 label(rescue,'Progress','MANTÉN E PARA RESCATAR',12,7,495,28,24,C.white,true);frame(rescue,'Track',14,42,490,9,C.card);frame(rescue,'Fill',14,42,0,9,C.green)
 local toast=frame(gui,'Toast',0,0,610,64,C.panel);toast.AnchorPoint=Vector2.new(.5,0);toast.Position=UDim2.new(.5,0,0,250);toast.Visible=false;stroke(toast,C.blue,3);pattern(toast,610,64,.85);label(toast,'Message','',16,5,578,54,21,C.white)
 local shade=new('TextButton',gui,{Name='Shade',Text='',Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BackgroundTransparency=.28,BorderSizePixel=0,Visible=false,AutoButtonColor=false})
 local modal=frame(gui,'Modal',0,0,920,650,C.panel);modal.AnchorPoint=Vector2.new(.5,.5);modal.Position=UDim2.fromScale(.5,.5);modal.BackgroundTransparency=1;modal.Visible=false;new('UIScale',modal,{Name='ModalScale'})
 local panels={}
 local function panel(name,title,key,color)
  local shadow=frame(modal,name..'_Shadow',0,8,920,650,C.ink);shadow.Visible=false
  local n=frame(modal,name,0,0,920,650,C.panel);corner(n,22);stroke(n,C.ink,4);pattern(n,920,650,.86);n.Visible=false;n:SetAttribute('Accent',color:ToHex())
  local inner=frame(n,'InnerHighlight',5,5,910,640,C.panel);inner.BackgroundTransparency=1;stroke(inner,C.white,2,.5)
  local header=frame(n,'Header',3,3,914,83,color);corner(header,18);gradient(header,color);header.ClipsDescendants=true;pattern(header,914,80);icon(header,key,15,4,73);label(header,'Title',title,99,6,700,69,40,C.white,true)
  local glass=new('Frame',header,{Name='Glass',Position=UDim2.fromOffset(8,4),Size=UDim2.new(1,-16,0,8),BackgroundColor3=C.white,BackgroundTransparency=0.72,BorderSizePixel=0});corner(glass,4)
  button(header,'Close','×',846,13,52,52,C.pink)
  local body=new('ScrollingFrame',n,{Name='Body',Position=UDim2.fromOffset(20,105),Size=UDim2.fromOffset(880,520),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=color,CanvasSize=UDim2.fromOffset(0,520),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y})
  panels[name]=n;return body
 end
 local b=panel('Shop','TIENDA ZERO','shop',C.yellow)
 button(b,'Tab_Passes','PASES',4,0,276,48,C.yellow);button(b,'Tab_Coins','MONEDAS',302,0,276,48,C.blue);button(b,'Tab_Packs','PACKS',600,0,276,48,C.purple)
 for i,v in ipairs({{'VIP','vip','yellow','Tag + efectos exclusivos','R$ 299'},{'2× COINS','coins','green','Doble monedas en partidas','R$ 199'},{'2× GEMS','gems','blue','Doble gemas para habilidades','R$ 249'},{'2× XP','xp','orange','Doble experiencia permanente','R$ 199'}}) do local c=card(b,'Product_'..i,v[1],v[2],4+(i-1)*220,65,214,276,C[v[3]],v[4],v[5]);c.Action:SetAttribute('Action','Purchase');c.Action:SetAttribute('Product',v[1]);local g=button(c,'Gift','',168,47,35,35,C.orange);icon(g,'gift',3,3,29);g:SetAttribute('Menu','Gift') end
 label(b,'Products','PACKS DE MONEDAS',0,352,880,34,25,C.white,true)
 for i,v in ipairs({{'1K','coin1k','30'},{'10K','coin10k','180'},{'100K','coin100k','900'}}) do local c=card(b,'CoinPack_'..i,v[1]..' MONEDAS',v[2],4+(i-1)*298,397,276,225,C.green,'Pack de monedas','R$ '..v[3]);c.Action:SetAttribute('Action','Purchase');c.Action:SetAttribute('Product',v[1]..' coins') end
 label(b,'GemProducts','PACKS DE GEMAS',0,634,880,34,25,C.white,true)
 for i,v in ipairs({{'100','gem100','1'},{'200','gem200','2'},{'300','gem300','3'}}) do local c=card(b,'GemPack_'..i,v[1]..' GEMAS',v[2],4+(i-1)*298,679,276,225,C.blue,'Pack de gemas','R$ '..v[3]);c.Action:SetAttribute('Action','Purchase');c.Action:SetAttribute('Product',v[1]..' gems') end
 local secret=card(b,'SecretPack','PACK SECRETO','crate_secret',4,916,872,270,C.purple,'Contenido cosmético sorpresa','VER PACK');secret.Action:SetAttribute('Action','Purchase');secret.Action:SetAttribute('Product','SecretPack')
 b=panel('Daily','RECOMPENSAS DIARIAS','daily',C.pink)
 label(b,'Streak','7 días. Una gran recompensa.',0,0,880,32,24,C.white)
 local dayRewards={{'coins','300 monedas'},{'wheel','1 giro'},{'coins','600 monedas'},{'wheel','2 giros'},{'coins','1.2K monedas'},{'coins','2.5K monedas'}}
 for i,v in ipairs(dayRewards) do local c=card(b,'Day_'..i,'DÍA '..i,v[1],4+((i-1)%3)*214,47+math.floor((i-1)/3)*229,195,213,C.blue,v[2],'BLOQUEADO');c.Action:SetAttribute('Action','Daily');c.Action:SetAttribute('Index',i) end
 local day=card(b,'Day_7','DÍA 7','key',652,47,224,442,C.purple,'6K + 5 GIROS','BLOQUEADO');day.Icon_key.Position=UDim2.fromOffset(34,105);day.Icon_key.Size=UDim2.fromOffset(156,156);day.Action:SetAttribute('Action','Daily');day.Action:SetAttribute('Index',7)
 b=panel('Time','REGALOS POR TIEMPO','time',C.green)
 label(b,'Hint','Juega, sobrevive y desbloquea regalos.',0,0,880,32,24)
 for i,v in ipairs({'01:00','05:00','15:00','30:00','1:00:00','2:00:00'}) do local c=card(b,'Time_'..i,v,'gift',4+((i-1)%3)*214,47+math.floor((i-1)/3)*229,195,213,C.orange,({'50 monedas','1 giro','200 monedas','400 monedas','2 giros','1.5K monedas'})[i],'BLOQUEADO');c.Action:SetAttribute('Action','Time');c.Action:SetAttribute('Index',i) end
 local mega=card(b,'MegaGift','4:30:00','gift',652,47,224,442,C.purple,'4K + 3 GIROS','BLOQUEADO');mega.Icon_gift.Position=UDim2.fromOffset(32,99);mega.Icon_gift.Size=UDim2.fromOffset(160,160);mega.Action:SetAttribute('Action','Time');mega.Action:SetAttribute('Index',7)
 b=panel('Wheel','RULETA DE LA SUERTE','wheel',C.purple)
 local wheelConfig=require(game.ReplicatedStorage:WaitForChild('ZeroWheelConfig'))
 local wheelPanel=panels.Wheel
 wheelPanel.BackgroundTransparency=1
 wheelPanel.StudTexture:Destroy();wheelPanel.InnerHighlight:Destroy();wheelPanel.UIStroke:Destroy()
 modal.Wheel_Shadow:Destroy()
 wheelPanel.Header.Visible=false
 b.Position=UDim2.fromOffset(20,0);b.Size=UDim2.fromOffset(880,650)
 b.ScrollingEnabled=false;b.ScrollBarThickness=0;b.AutomaticCanvasSize=Enum.AutomaticSize.None;b.CanvasSize=UDim2.fromOffset(880,650);b.ClipsDescendants=false
 label(b,'FreeSpin','PRÓXIMO GIRO GRATIS EN 12:00:00',100,0,680,40,30,C.white,true).TextXAlignment=Enum.TextXAlignment.Center
 label(b,'Odds','50: 45%   •   200: 30%   •   600: 18%   •   3K: 6.98%   •   CERO ABSOLUTO: 0.02%',100,653,680,23,16,C.white,true).TextXAlignment=Enum.TextXAlignment.Center
 local wheel=new('Frame',b,{Name='WheelArt',Position=UDim2.fromOffset(440,278),AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(420,420),BackgroundTransparency=1})
 new('ImageLabel',wheel,{Name='Disc',Image=wheelConfig.Assets.Disc,Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
 for i,reward in ipairs(wheelConfig.Rewards) do
  local angle=(i-1)*72-36
  local radians=math.rad(angle)
  local group=new('Frame',wheel,{Name='Prize_'..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(210+math.sin(radians)*128,210-math.cos(radians)*128),Size=UDim2.fromOffset(118,108),Rotation=angle,BackgroundTransparency=1})
  new('ImageLabel',group,{Name='Cash',Image=reward.Icono or wheelConfig.Assets.Cash,Position=UDim2.fromOffset(16,-5),Size=UDim2.fromOffset(86,86),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit})
  label(group,'Amount',reward.Arma and reward.Label or reward.Label..' CASH',-3,73,124,31,23,C.white,true).TextXAlignment=Enum.TextXAlignment.Center
 end
 new('ImageLabel',b,{Name='Pointer',Image=wheelConfig.Assets.Pointer,Position=UDim2.fromOffset(408,45),Size=UDim2.fromOffset(64,70),BackgroundTransparency=1,ZIndex=5})
 local balance=label(b,'Balance','',0,0,1,1,1,C.muted);balance.Visible=false
 label(b,'Result','¡UN GIRO, UNA NUEVA SORPRESA!',140,490,600,30,22,C.white,true).TextXAlignment=Enum.TextXAlignment.Center
 local spin=button(b,'Spin','GIRAR (×1)',286,530,244,54,C.green);spin:SetAttribute('Action','Spin')
 button(b,'Close','×',548,530,54,54,C.pink).TextSize=35
 for i,count in ipairs({2,5,10}) do
  local n=button(b,'BuySpins_'..i,'×'..count..'  •  PRONTO',162+(i-1)*188,602,180,44,C.yellow)
  n.TextSize=19;n:SetAttribute('Action','WheelPurchase');n:SetAttribute('Index',i)
 end
 b=panel('Codes','CÓDIGOS','codes',C.blue)
 icon(b,'codes',322,4,220);label(b,'Heading','¡Un código, una nueva sorpresa!',70,237,740,48,34,C.white,true).TextXAlignment=Enum.TextXAlignment.Center
 label(b,'Hint','Encuentra códigos en las novedades de ZERO.',65,294,750,38,23,C.muted).TextXAlignment=Enum.TextXAlignment.Center
 local input=new('TextBox',b,{Name='CodeInput',PlaceholderText='ESCRIBE TU CÓDIGO',Text='',ClearTextOnFocus=false,Position=UDim2.fromOffset(27,367),Size=UDim2.fromOffset(542,76),BackgroundColor3=C.ink,TextColor3=C.white,PlaceholderColor3=C.muted,TextSize=26,Font=Enum.Font.FredokaOne});corner(input,14);stroke(input,C.blue,2)
 button(b,'Redeem','CANJEAR',590,367,263,76,C.green):SetAttribute('Action','Redeem')
 label(b,'Result','',28,464,825,42,23,C.blue)
 b=panel('Settings','AJUSTES','settings',C.blue)
 for i,v in ipairs({'MÚSICA','EFECTOS DE SONIDO'}) do local y=20+(i-1)*112;local n=frame(b,i==1 and 'Music' or 'SFX',4,y,872,90,i==1 and C.pink or C.yellow);gradient(n,n.BackgroundColor3);stroke(n);pattern(n,872,90,.4);label(n,'Label',v,20,10,366,64,30,C.white,true);frame(n,'Track',406,38,346,13,C.ink);local fill=frame(n,'Fill',406,38,280,13,C.blue);local knob=button(n,'Volume','',679,24,36,40,C.blue);label(n,'Value','80%',765,12,95,64,26,C.white,true) end
 button(b,'ReduceMotion','EFECTOS: ACTIVADOS',0,269,424,72,C.purple)
 button(b,'CloseHint','SONIDO: ACTIVADO',456,269,424,72,C.green)
 button(b,'AFK','MODO AFK: DESACTIVADO',0,360,880,72,C.orange)
 label(b,'Hint','AFK: te quedas en el lobby y no entras a las partidas. Tu volumen se guarda para la próxima vez.',0,452,880,48,22,C.muted)
 b=panel('Group','REGALO DE COMUNIDAD','group',C.orange)
 card(b,'Reward','REGALO ZERO','gift',0,32,332,385,C.yellow,'Monedas + cosmético',nil)
 label(b,'Heading','¡ÚNETE AL EQUIPO!',367,49,493,100,42,C.white,true)
 label(b,'Copy','Forma parte de la comunidad y consigue un regalo exclusivo.',367,164,485,90,25,C.white)
 button(b,'Join','VER GRUPO',367,293,493,67,C.blue):SetAttribute('Action','Group')
 button(b,'Claim','RECLAMAR',367,381,493,67,C.green):SetAttribute('Action','GroupReward')
 b=panel('Classes','INVENTARIO','tracker',C.pink)
 local classData={{'Rastreador','tracker','blue','PULSO','Revela corredores cercanos','18s'},{'Acechador','dash','pink','EMBESTIDA','Impulso corto hacia delante','12–14s'},{'Trampero','trap','purple','TRAMPA','Ralentiza y marca corredores','15s'}}
 for i,v in ipairs(classData) do local c=card(b,'Class_'..i,string.upper(v[1]),v[2],4+(i-1)*298,16,276,444,C[v[3]],v[4],'ELEGIR');c.Action:SetAttribute('Class',v[1]);label(c,'Description',v[5],16,215,244,67,23,C.white,true).TextXAlignment=Enum.TextXAlignment.Center;label(c,'Cooldown','COOLDOWN '..v[6],12,289,252,39,21,C.white,true).TextXAlignment=Enum.TextXAlignment.Center end
 b=panel('Stats','TUS ESTADÍSTICAS','stats',C.yellow)
 for i,v in ipairs({'Victorias Runner','Victorias Hunter','Congelados','Rescatados','Partidas jugadas','Tiempo jugado'}) do local x=4+((i-1)%2)*448;local y=math.floor((i-1)/2)*146;local n=frame(b,'Stat_'..i,x,y,424,128,C.card);stroke(n,C.ink,3);pattern(n,424,128,.8);icon(n,({'dash','hunter','pack','rescue','stats','time'})[i],15,23,78);label(n,'Title',v,110,17,300,42,24,C.muted);label(n,'Value','—',110,62,300,52,35,C.white,true);n:SetAttribute('StatName',({'RunnerWins','HunterWins','FrozenPlayers','RescuedPlayers','RoundsPlayed','PlayTime'})[i]) end
 b=panel('Spectate','PARTIDA EN CURSO','spectate',C.blue)
 icon(b,'spectate',340,4,190);label(b,'Title','SIGUE LA PERSECUCIÓN',30,200,820,52,36,C.white,true).TextXAlignment=Enum.TextXAlignment.Center
 label(b,'Status','No hay una ronda activa.',40,269,800,50,25,C.muted).TextXAlignment=Enum.TextXAlignment.Center
 button(b,'Observe','ESPECTAR',60,357,360,74,C.blue):SetAttribute('Action','Spectate')
 button(b,'JoinHunters','UNIRME A CAZADORES',460,357,360,74,C.pink):SetAttribute('Action','JoinHunters')
 b=panel('Gift','REGALA UN PASE','gift',C.pink)
 icon(b,'gift',18,7,154);label(b,'Title','Comparte una sorpresa',200,31,655,58,35,C.white,true)
 label(b,'Hint','Elige a alguien que esté en este servidor.',200,96,655,48,23,C.muted)
 new('Frame',b,{Name='Players',Position=UDim2.fromOffset(0,190),Size=UDim2.fromOffset(880,280),BackgroundTransparency=1})
 label(b,'Empty','No hay otros jugadores conectados.',20,215,840,70,27,C.muted).TextXAlignment=Enum.TextXAlignment.Center
 return gui
end

return UI

