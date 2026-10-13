local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ProximityPromptService=game:GetService("ProximityPromptService")
local Audio=require(ReplicatedStorage:WaitForChild("ZeroAudio"))
local Sfx=require(ReplicatedStorage:WaitForChild("ZeroMovimientoSFX"))
local player=Players.LocalPlayer
local network=ReplicatedStorage:WaitForChild("NetworkEvents")
local lastStatus=player:GetAttribute("Status")
player:GetAttributeChangedSignal("Status"):Connect(function()
	local status=player:GetAttribute("Status")
	if status=="Frozen" and lastStatus~="Frozen" then Audio.play("Freeze") end
	lastStatus=status
end)
local lastCoins=player:GetAttribute("Coins")
player:GetAttributeChangedSignal("Coins"):Connect(function()
	local coins=player:GetAttribute("Coins")
	local gui=player.PlayerGui:FindFirstChild("ZeroUI")
	if lastCoins and coins and coins>lastCoins and not (gui and gui:GetAttribute("WheelSpinning")) then Audio.play("Coin") end
	lastCoins=coins
end)
network:WaitForChild("AttackHitFeedback").OnClientEvent:Connect(function(data)
	if data.role=="Attacker" then
		local character=player.Character
		Sfx.play(character and character:FindFirstChild("HumanoidRootPart"),"Impacto")
	end
end)
network:WaitForChild("HunterAbilityFeedback").OnClientEvent:Connect(function(data)
	Audio.play(data.success and "Ability" or "Error")
end)
network:WaitForChild("ClassSelectionConfirmed").OnClientEvent:Connect(function(data)
	if data.success then Audio.play("Class") end
end)
network:WaitForChild("RescueFeedback").OnClientEvent:Connect(function()Audio.play("Rescue")end)
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if prompt.Name=="RescuePrompt" then Audio.play("Notify") end
end)
local lastState,lastCountdown
network:WaitForChild("RoundStatusUpdate").OnClientEvent:Connect(function(data)
	if lastState and data.state~=lastState then
		if data.state=="ROUND_ACTIVE" then Audio.play("RoundStart")
		elseif data.state=="ROUND_END" then Audio.play("RoundEnd") end
	end
	if data.state=="INTERMISSION" and data.timer and data.timer>0 and data.timer<=3 and data.timer~=lastCountdown then
		Audio.play("Countdown");lastCountdown=data.timer
	elseif data.state~="INTERMISSION" then lastCountdown=nil end
	lastState=data.state
end)
player:SetAttribute("ZeroSoundClientReady",true)

