local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local templates = ReplicatedStorage:WaitForChild("ZeroSoundAssets")
local Audio = {}
local function group(name)
	local value = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
	value.Name=name;value.Volume=.8;value.Parent=SoundService
	return value
end
local sfx, music = group("ZeroSFX"), group("ZeroMusic")
local voices = Instance.new("Folder");voices.Name="ZeroSFXVoices";voices.Parent=SoundService
local cues = {
	Hover={"Hover",.10,1,.09}, Click={"Click",.24,1,.06},
	Open={"Open",.32,1,.10}, Close={"Close",.28,1,.10},
	Tab={"Tab",.22,1,.08}, Toggle={"Toggle",.25,1,.10},
	Notify={"Notify",.25,1,.25}, Success={"Success",.40,1,.25},
	Error={"Error",.27,1,.25}, Coin={"Coin",.34,1,.18},
	WheelStart={"Whoosh",.28,1.1,1}, WheelTick={"Click",.17,1.4,.035},
	Prize={"Success",.48,1.05,1}, Dash={"Whoosh",.38,1.3,.15},
	Freeze={"Error",.38,.8,.5}, Rescue={"Success",.42,1.15,.5},
	Hit={"Click",.34,.7,.15}, Ability={"Whoosh",.38,.9,.3},
	Class={"Success",.28,1.15,.35}, RoundStart={"Open",.46,.95,1},
	RoundEnd={"Notify",.40,.9,1}, Countdown={"Countdown",.26,1,.5},
	Swing={"Whoosh",.30,1.4,1.2},
}
local pool, lastPlayed, nextVoice = {}, {}, {}
for key, config in pairs(cues) do
	pool[key] = {}
	for i=1,2 do
		local sound = templates:WaitForChild(config[1]):Clone()
		sound.Name=key.."_"..i;sound.Volume=config[2];sound.PlaybackSpeed=config[3]
		sound.Looped=false;sound.PlayOnRemove=false;sound.SoundGroup=sfx;sound.Parent=voices
		pool[key][i]=sound
	end
end
function Audio.play(key)
	local config=cues[key]
	if not config or sfx.Volume<=0 then return false end
	local now=os.clock()
	if now-(lastPlayed[key] or -math.huge)<config[4] then return false end
	lastPlayed[key]=now
	local index=(nextVoice[key] or 0)%2+1;nextVoice[key]=index
	local sound=pool[key][index]
	sound:Stop();sound.TimePosition=0;sound:Play()
	return true
end
local function toPerceptualGain(linearLevel: number, exponent: number?): number
	local clamped = math.clamp(linearLevel, 0, 1)
	return clamped ^ (exponent or 2.2)
end

function Audio.setLevels(musicLevel,sfxLevel,muted)
	music.Volume=muted and 0 or toPerceptualGain(musicLevel, 2.2)
	sfx.Volume=muted and 0 or toPerceptualGain(sfxLevel, 2.0)
	if sfx.Volume==0 then
		for _,sound in ipairs(voices:GetChildren()) do sound:Stop() end
	end
end
local function routeSound(sound)
	if not sound:IsA("Sound") then return end
	local current=sound.SoundGroup
	if current==sfx or current==music then return end
	local category=sound:GetAttribute("AudioCategory") or ""
	local name=(sound.Name.." "..(current and current.Name or "").." "..category):lower()
	sound.SoundGroup=(name:find("music") or name:find("bgm")) and music or sfx
end
game.DescendantAdded:Connect(routeSound)
for i,node in ipairs(game:GetDescendants()) do
	routeSound(node)
	if i%1000==0 then task.wait() end
end
local buttons=setmetatable({},{__mode="k"})
local function bind(node)
	if not node:IsA("GuiButton") or buttons[node] then return end
	buttons[node]=true
	node.MouseEnter:Connect(function()if node.Active then Audio.play("Hover") end end)
	node.SelectionGained:Connect(function()if node.Active then Audio.play("Hover") end end)
	node.Activated:Connect(function()
		local special=node.Name=="ReduceMotion" or node.Name=="CloseHint"
		Audio.play(special and "Toggle" or node.Name:sub(1,4)=="Tab_" and "Tab" or "Click")
	end)
end
function Audio.bindUI(root)
	for _,node in ipairs(root:GetDescendants()) do bind(node) end
	root.DescendantAdded:Connect(bind)
end
Audio.bindUI(Players.LocalPlayer:WaitForChild("PlayerGui"))
task.spawn(function()
	local failed=0
	local ok,err=pcall(function()
		ContentProvider:PreloadAsync(templates:GetChildren(),function(asset,status)
			if status~=Enum.AssetFetchStatus.Success then failed+=1;warn("[ZeroAudio] No se cargó: "..asset) end
		end)
	end)
	if not ok then failed+=1;warn("[ZeroAudio] Precarga: "..tostring(err)) end
	voices:SetAttribute("PreloadFailures",failed);voices:SetAttribute("PreloadComplete",true)
end)
return Audio
