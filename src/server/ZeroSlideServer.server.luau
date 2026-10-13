-- ZeroSlideServer (Script, ServerScriptService): valida el deslizamiento y pone ZeroDeslizando en el personaje para
-- que todos los clientes lo animen (ZeroMovement). El impulso lo aplica el propio cliente (ZeroSlideClient).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlideConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SlideConfig"))

local remote = ReplicatedStorage:FindFirstChild("ZeroSlideRequest") or Instance.new("RemoteEvent")
remote.Name = "ZeroSlideRequest"
remote.Parent = ReplicatedStorage

local last: { [Player]: number } = {}
local serial: { [Player]: number } = {}

remote.OnServerEvent:Connect(function(player, dir)
	if typeof(dir) ~= "Vector3" or dir ~= dir or math.abs(dir.Magnitude - 1) > 0.05 then return end
	local now = os.clock()
	if now - (last[player] or -math.huge) < SlideConfig.COOLDOWN - 0.2 then return end   -- margen por el ping
	if player:GetAttribute("Status") == "Frozen" then return end
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end
	last[player] = now
	local n = (serial[player] or 0) + 1
	serial[player] = n
	character:SetAttribute("ZeroDeslizando", true)
	task.delay(SlideConfig.DURATION, function()
		if serial[player] == n and character.Parent then character:SetAttribute("ZeroDeslizando", false) end
	end)
end)

Players.PlayerRemoving:Connect(function(player) last[player] = nil; serial[player] = nil end)
