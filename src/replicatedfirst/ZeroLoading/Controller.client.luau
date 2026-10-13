local Players=game:GetService("Players")
local ReplicatedFirst=game:GetService("ReplicatedFirst")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ContentProvider=game:GetService("ContentProvider")
local TweenService=game:GetService("TweenService")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("ZeroLoading") or player:GetAttribute("ZeroLoadingComplete") then return end
local gui=script.Parent.Screen:Clone()
gui.Name="ZeroLoading"
local root=gui.Background
local content=root.Content
local spinner,skip,bar=content.Spinner,content.Skip,content.Progress
local started=os.clock()
local minimum=math.max(0,gui:GetAttribute("MinimumDisplaySeconds") or 2.5)
local closed=false
local completed,total,failures=0,0,0
local fillTween
gui.Parent=playerGui
player:SetAttribute("ZeroLoadingActive",true)
ReplicatedFirst:RemoveDefaultLoadingScreen()

local function layout()
	local width,height=root.AbsoluteSize.X,root.AbsoluteSize.Y
	local compact=height<600
	local panelWidth=math.min(560,math.max(260,width-40))
	local panelHeight=compact and math.max(280,height-56) or math.min(720,height-90)
	content.Size=UDim2.fromOffset(panelWidth,panelHeight)
	content.Brand.Visible=not compact
	content.Hint.Visible=not compact
	local scale=panelHeight/720
	local size=compact and math.min(150,(panelHeight-178)/math.sqrt(2)) or math.min(300*scale,panelWidth*.68)
	local compactSpan=size*math.sqrt(2)
	spinner.Size=UDim2.fromOffset(size,size)
	spinner.Position=UDim2.new(.5,0,0,compact and compactSpan/2 or 252*scale)
	content.Title.Position=UDim2.new(.5,0,0,compact and compactSpan+8 or 480*scale)
	content.Title.Size=UDim2.new(1,0,0,compact and 34 or 44)
	content.Status.Position=UDim2.new(.5,0,0,compact and compactSpan+48 or 528*scale)
	content.Status.Size=UDim2.new(1,0,0,20)
	bar.Position=UDim2.new(.5,0,0,compact and compactSpan+78 or 562*scale)
	bar.Size=UDim2.new(.9,0,0,compact and 36 or 44)
	skip.Position=UDim2.new(.5,0,0,compact and compactSpan+132 or 626*scale)
	skip.Size=UDim2.fromOffset(math.min(230,panelWidth*.7),compact and 48 or 58)
	content.Hint.Position=UDim2.new(.5,0,0,694*scale)
	content.Hint.Size=UDim2.new(1,0,0,20)
end
layout()
local resize=root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
local spin=TweenService:Create(spinner,TweenInfo.new(6,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1),{Rotation=360})
spin:Play()
local previousSelection=GuiService.SelectedObject
if UserInputService.GamepadEnabled then GuiService.SelectedObject=skip end

local function close(reason)
	if closed then return end
	closed=true
	player:SetAttribute("ZeroLoadingActive",false)
	player:SetAttribute("ZeroLoadingComplete",true)
	player:SetAttribute("ZeroLoadingResult",reason)
	player:SetAttribute("ZeroLoadingFailures",failures)
	script:SetAttribute("Result",reason)
	spin:Cancel()
	if fillTween then fillTween:Cancel() end
	resize:Disconnect()
	if GuiService.SelectedObject==skip then
		GuiService.SelectedObject=previousSelection and previousSelection.Parent and previousSelection or nil
	end
	skip.Active=false
	skip.Selectable=false
	skip.Modal=false
	-- Fade native UI elements without flattening the whole screen into a low-resolution texture.
	local fadeInfo=TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	for _,object in ipairs(gui:GetDescendants()) do
		local properties={}
		if object:IsA("GuiObject") then properties.BackgroundTransparency=1 end
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			properties.TextTransparency=1;properties.TextStrokeTransparency=1
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
			properties.ImageTransparency=1
		elseif object:IsA("UIStroke") then properties.Transparency=1 end
		if next(properties) then TweenService:Create(object,fadeInfo,properties):Play() end
	end
	task.delay(.35,function() gui:Destroy() end)
end
skip.Activated:Connect(function() close("Skipped") end)
skip.MouseEnter:Connect(function()
	if not closed then TweenService:Create(skip,TweenInfo.new(.12),{BackgroundColor3=Color3.fromRGB(178,255,112)}):Play() end
end)
skip.MouseLeave:Connect(function()
	if not closed then TweenService:Create(skip,TweenInfo.new(.12),{BackgroundColor3=Color3.fromRGB(135,236,70)}):Play() end
end)

local function progress()
	if closed then return end
	local ratio=total>0 and completed/total or 0
	gui:SetAttribute("ProcessedAssets",completed)
	gui:SetAttribute("TotalAssets",total)
	gui:SetAttribute("FailedAssets",failures)
	if fillTween then fillTween:Cancel() end
	fillTween=TweenService:Create(bar.Fill,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(ratio,1)})
	fillTween:Play()
	bar.Percentage.Text=math.floor(ratio*100+.5).."%"
	content.Status.Text=string.format("Cargando recursos · %d / %d",completed,total)
end

-- Load a finite set of interface, audio and asset resources; never use RequestQueueSize.
task.spawn(function()
	while not game:IsLoaded() and not closed do task.wait(.05) end
	if closed then return end
	local assets,seen={},{}
	local function add(id,object)
		if type(id)=="string" and id~="" and not seen[id] then
			seen[id]=true;table.insert(assets,{id=id,object=object})
		end
	end
	local function collect(container)
		if not container then return end
		for _,object in ipairs(container:GetDescendants()) do
			if object:IsA("ImageLabel") or object:IsA("ImageButton") then add(object.Image,object)
			elseif object:IsA("Sound") then add(object.SoundId,object)
			elseif object:IsA("Animation") then add(object.AnimationId,object)
			elseif object:IsA("Decal") or object:IsA("Texture") then add(object.Texture,object)
			elseif object:IsA("MeshPart") then add(object.MeshId,object);add(object.TextureID,object)
			elseif object:IsA("SpecialMesh") then add(object.MeshId,object);add(object.TextureId,object) end
		end
	end
	collect(gui)
	collect(game:GetService("StarterGui"):FindFirstChild("ZeroUI"))
	collect(ReplicatedStorage:FindFirstChild("Assets"))
	collect(game:GetService("SoundService"))
	total=#assets
	progress()
	local nextIndex,workers=1,math.min(4,total)
	local function worker()
		while not closed do
			local index=nextIndex;nextIndex+=1
			local asset=assets[index]
			if not asset then break end
			local status
			local ok=pcall(function()
				ContentProvider:PreloadAsync({asset.object},function(_,result)
					if result~=Enum.AssetFetchStatus.Success then status=result
					elseif not status then status=result end
				end)
			end)
			if closed then break end
			completed+=1
			if not ok or status~=Enum.AssetFetchStatus.Success then failures+=1 end
			progress()
		end
		workers-=1
	end
	for _=1,workers do task.spawn(worker) end
	while workers>0 and not closed do task.wait(.05) end
	if closed then return end
	if total==0 then bar.Percentage.Text="100%";bar.Fill.Size=UDim2.fromScale(1,1) end
	content.Title.Text=failures==0 and "¡ZERO ESTÁ LISTO!" or "ENTRANDO A ZERO..."
	content.Status.Text=failures==0 and "Carga inicial completada" or "Los recursos restantes cargarán al jugar"
	while os.clock()-started<minimum and not closed do task.wait(.05) end
	close("Completed")
end)
-- Roblox requests may keep running in the background; never trap the player on this overlay.
task.delay(25,function() close("Timeout") end)
