local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local Config = require(ReplicatedStorage:WaitForChild("ZeroWheelConfig"))
local remote = ReplicatedStorage:WaitForChild("ZeroWheelRequest")
local Audio=require(ReplicatedStorage:WaitForChild('ZeroAudio'))
local MarketplaceService = game:GetService("MarketplaceService")
local SpinPacks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MonetizationConfig")).SpinPacks or {}
local Controller = {}

function Controller.new(gui, notify)
	local player = Players.LocalPlayer
	local body = gui.Modal.Wheel.Body
	local rotor = body.WheelArt
	local busy = false
	local blur = Instance.new("BlurEffect")
	blur.Name = "ZeroWheelBlur"; blur.Size = 0; blur.Parent = Lighting
	local function update()
		local ready = player:GetAttribute("WheelReady") == true
		local nextFree = player:GetAttribute("NextFreeSpinAt")
		local remaining = nextFree and math.max(0, math.ceil(nextFree-workspace:GetServerTimeNow())) or nil
		local spins = (player:GetAttribute("Spins") or 0) + (remaining == 0 and 1 or 0)
		if not ready then
			body.FreeSpin.Text = player:GetAttribute("WheelLoadFailed") and "NO SE PUDO CARGAR TU SALDO" or "CARGANDO TUS GIROS…"
		else
			body.FreeSpin.Text = remaining == 0 and "¡TU GIRO GRATIS ESTÁ LISTO!" or (remaining >= 3600 and string.format("PRÓXIMO GIRO GRATIS EN %d:%02d:%02d", remaining//3600, (remaining//60)%60, remaining%60) or string.format("PRÓXIMO GIRO GRATIS EN %02d:%02d", math.floor(remaining/60), remaining%60))
		end
		-- compra de giros: escondida donde la ley no deja vender premios aleatorios (PolicyService, ZeroWheelServer)
		local puedeComprar = player:GetAttribute("PagoAleatorioRestringido") == false
		local hayPacks = false
		for i, sp in SpinPacks do
			local b = body:FindFirstChild("BuySpins_"..i)
			if b then
				b.Visible = puedeComprar
				local sh = body:FindFirstChild("BuySpins_"..i.."_Shadow"); if sh then sh.Visible = puedeComprar end
				b.Text = "×"..sp.Giros.."  •  "..(sp.Id ~= 0 and ("R$ "..sp.PriceRobux) or "PRONTO")
			end
			if sp.Id ~= 0 then hayPacks = true end
		end
		local comprar = ready and not busy and spins <= 0 and puedeComprar and hayPacks
		body.Spin.Text = busy and "GIRANDO…" or comprar and "COMPRAR GIROS" or ("GIRAR (×"..spins..")")
		body.Spin.Active = ready and not busy and (spins > 0 or comprar)
		body.Spin:SetAttribute("AvailableSpins", spins)
		gui:SetAttribute("WheelSpinning",busy)
	end
	local object = {}
	-- compra de un pack de giros (botones ×2/×5/×10 y GIRAR con 0 giros)
	function object.comprar(index)
		local sp = SpinPacks[tonumber(index) or 0]
		if player:GetAttribute("PagoAleatorioRestringido") ~= false then notify("La compra de giros no está disponible en tu región.","Error");return false end
		if not sp or sp.Id == 0 then notify("Los paquetes de giros estarán disponibles muy pronto.");return false end
		MarketplaceService:PromptProductPurchase(player, sp.Id)
		return true
	end
	function object.spin()
		if busy then return false end
		if not player:GetAttribute("WheelReady") then notify("Tus giros aún se están cargando.");return false end
		if (body.Spin:GetAttribute("AvailableSpins") or 0) <= 0 then
			if body.Spin.Text == "COMPRAR GIROS" then return object.comprar(2) end   -- sin giros: el pack ×5
			notify("Espera tu próximo giro gratis.","Error");return false
		end
		busy = true; update()
		body.Result.Text = "¿QUÉ PREMIO TE TOCARÁ?"
		local ok, result = pcall(function() return remote:InvokeServer("Spin") end)
		if not ok or type(result) ~= "table" or not result.success then
			busy = false; update()
			body.Result.Text = "¡TU PRÓXIMA SORPRESA TE ESPERA!"
			notify(ok and type(result)=="table" and result.message or "No se pudo completar el giro.","Error")
			return false
		end
		local reward = Config.Rewards[result.index]
		if not reward or result.coins ~= reward.Coins then
			busy=false;update();notify("No se pudo mostrar el resultado.","Error");return false
		end
		local target = (36-(result.index-1)*72)%360
		local rotation = rotor.Rotation%360
		local duration = gui:GetAttribute("ReducedMotion") and .25 or Config.SpinDuration
		local extraTurns = gui:GetAttribute("ReducedMotion") and 0 or 360*5
		local tween = TweenService:Create(rotor,TweenInfo.new(duration,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Rotation=rotation+extraTurns+(target-rotation)%360})
		Audio.play("WheelStart")
		local lastSector=math.floor(rotation/72)
		local tick=rotor:GetPropertyChangedSignal("Rotation"):Connect(function()
			local sector=math.floor(rotor.Rotation/72)
			if sector~=lastSector then Audio.play("WheelTick");lastSector=sector end
		end)
		tween:Play()
		tween.Completed:Wait()
		tick:Disconnect()
		rotor.Rotation = target
		gui:SetAttribute("LastWheelReward",result.index)
		local texto = reward.Arma and ("¡GANASTE EL "..string.upper(reward.Arma).."!") or ("¡GANASTE +"..reward.Label.." MONEDAS!")
		body.Result.Text = texto
		body.Result.TextColor3 = reward.Arma and Color3.fromRGB(127,216,255) or Color3.fromRGB(150,255,83)
		Audio.play("Prize");Audio.play("Coin")
		notify(reward.Arma and ("¡Te tocó el "..reward.Arma.."!") or ("¡Ganaste +"..reward.Label.." monedas!"),"Silent")
		-- La recarga del servidor sigue vigente aunque se reduzca la animación.
		task.wait(math.max(0,Config.SpinCooldown-duration))
		busy=false;update()
		return true
	end
	local original = {}
	for _, node in ipairs(body:GetDescendants()) do
		if node:IsA("GuiObject") then
			original[node] = {Position=node.Position,Size=node.Size}
			if node:IsA("TextLabel") or node:IsA("TextButton") then original[node].TextSize=node.TextSize end
		end
	end
	local rotorScale = Instance.new("UIScale");rotorScale.Name="WheelScale";rotorScale.Parent=rotor
	local function layoutButton(node,x,y,w,h,font)
		node.Position=UDim2.fromOffset(x,y);node.Size=UDim2.fromOffset(w,h);node.TextSize=font
		local shadow=body:FindFirstChild(node.Name.."_Shadow")
		if shadow then shadow.Position=UDim2.fromOffset(x,y+6);shadow.Size=node.Size end
	end
	function object.resize(viewport)
		for node,props in pairs(original) do for key,value in pairs(props) do node[key]=value end end
		rotorScale.Scale=1
		local width,height,cap=920,650,1.35
		body.Position=UDim2.fromOffset(20,0);body.Size=UDim2.fromOffset(880,650)
		if viewport.X < 1100 or viewport.Y < 600 then
			cap=1
			body.Position=UDim2.fromOffset(0,0)
			if viewport.X > viewport.Y then
				width,height=760,350
				body.FreeSpin.Position=UDim2.fromOffset(12,0);body.FreeSpin.Size=UDim2.fromOffset(736,36);body.FreeSpin.TextSize=24
				rotor.Position=UDim2.fromOffset(190,196);rotorScale.Scale=286/420
				body.Pointer.Position=UDim2.fromOffset(167,38);body.Pointer.Size=UDim2.fromOffset(46,50)
				body.Result.Position=UDim2.fromOffset(374,62);body.Result.Size=UDim2.fromOffset(360,55);body.Result.TextSize=23
				layoutButton(body.Spin,384,133,262,62,25)
				layoutButton(body.Close,663,133,60,62,34)
				for i=1,3 do layoutButton(body["BuySpins_"..i],374+(i-1)*118,218,110,50,18) end
				body.Odds.Position=UDim2.fromOffset(374,282);body.Odds.Size=UDim2.fromOffset(348,54);body.Odds.TextSize=16
			else
				width,height=400,720
				body.FreeSpin.Position=UDim2.fromOffset(6,0);body.FreeSpin.Size=UDim2.fromOffset(388,58);body.FreeSpin.TextSize=25
				rotor.Position=UDim2.fromOffset(200,274);rotorScale.Scale=360/420
				body.Pointer.Position=UDim2.fromOffset(173,62);body.Pointer.Size=UDim2.fromOffset(54,59)
				body.Result.Position=UDim2.fromOffset(10,465);body.Result.Size=UDim2.fromOffset(380,42);body.Result.TextSize=22
				layoutButton(body.Spin,51,527,228,62,25)
				layoutButton(body.Close,295,527,54,62,34)
				for i=1,3 do layoutButton(body["BuySpins_"..i],12+(i-1)*129,618,118,54,18) end
				body.Odds.Position=UDim2.fromOffset(10,676);body.Odds.Size=UDim2.fromOffset(380,40);body.Odds.TextSize=15
			end
			body.Size=UDim2.fromOffset(width,height)
		end
		gui.Modal.Size=UDim2.fromOffset(width,height)
		gui.Modal.Wheel.Size=UDim2.fromOffset(width,height)
		gui.Modal.ModalScale.Scale=math.min(cap,(viewport.X-28)/width,(viewport.Y-40)/(height==650 and 680 or height))
	end
	local function updateBlur()
		local size = gui:GetAttribute("CurrentMenu")=="Wheel" and not gui:GetAttribute("ReducedMotion") and 12 or 0
		TweenService:Create(blur,TweenInfo.new(.2),{Size=size}):Play()
	end
	gui:GetAttributeChangedSignal("CurrentMenu"):Connect(updateBlur)
	gui:GetAttributeChangedSignal("ReducedMotion"):Connect(updateBlur)
	local elapsed = 0
	local connection = RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt
		if elapsed>=.2 then elapsed=0;update() end
	end)
	gui.Destroying:Connect(function()connection:Disconnect();blur:Destroy()end)
	task.spawn(function()
		local ok, err = pcall(function() ContentProvider:PreloadAsync({Config.Assets.Disc,Config.Assets.Cash,Config.Assets.Pointer}) end)
		if not ok then warn("[ZeroWheel] Precarga: "..tostring(err)) end
	end)
	update()
	return object
end
return Controller
