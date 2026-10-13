-- ZeroTenderoClient (LocalScript, StarterPlayerScripts): la tienda del lobby funciona y la atiende uno de tus amigos.
--  · "E · Comprar" en el mostrador (ProximityPrompt "Comprar" de ZeroLobby.Tienda.Mostrador) abre la Tienda de ZeroUI.
--  · El tendero lo prepara ZeroTendero en el servidor con la skin de un amigo; aquí se clona tras el mostrador
--    (solo lo ve este jugador), respira, mira hacia la entrada y saluda cuando te acercas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local tienda = workspace:WaitForChild("ZeroLobby"):WaitForChild("Tienda")
local mostrador = tienda:WaitForChild("Mostrador")

-- abrir la tienda desde el mostrador
local prompt = mostrador:WaitForChild("Comprar", 10)
if prompt then
	prompt.Triggered:Connect(function(who)
		if who ~= player then return end
		local ui = player.PlayerGui:FindFirstChild("ZeroUI")
		local action = ui and ui:FindFirstChild("UIAction")
		if action then pcall(function() action:Invoke("Open", "Shop") end) end
	end)
end

-- tendero: detrás del mostrador, mirando a la entrada (la entrada está hacia -X)
local tarima = tienda:FindFirstChild("TarimaTendero")                  -- escalón tras el mostrador para que asome
local floorY = tarima and (tarima.Position.Y + tarima.Size.Y / 2) or (mostrador.Position.Y - mostrador.Size.Y / 2)
local spot = Vector3.new(mostrador.Position.X + 3.2, floorY + 3, mostrador.Position.Z)
local IDLE, WAVE = "rbxassetid://180435571", "rbxassetid://128777973"   -- reposo y saludo R6 de Roblox

local function spawnKeeper()
	local source = ReplicatedStorage:WaitForChild("ZeroTenderos", 30)
	source = source and source:WaitForChild(tostring(player.UserId), 60)
	if not source then return end
	local npc = source:Clone()
	npc.Name = "Tendero"
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	for _, p in npc:GetDescendants() do
		if p:IsA("BasePart") then p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Anchored = false end
	end
	root.Anchored = true
	npc:PivotTo(CFrame.lookAt(spot, spot + Vector3.new(-1, 0, 0)))
	npc.Parent = workspace
	-- nombre encima de la cabeza
	local head = npc:FindFirstChild("Head")
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Name = "Nombre"; bb.Size = UDim2.fromOffset(220, 50); bb.StudsOffset = Vector3.new(0, 2.6, 0); bb.MaxDistance = 60; bb.AlwaysOnTop = false
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Font = Enum.Font.FredokaOne; t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1); t.TextStrokeTransparency = 0.2
		t.Text = (npc:GetAttribute("NombreAmigo") or "Tendero") .. "\nTIENDA ZERO"
		t.Parent = bb
		bb.Parent = head
	end
	-- animaciones locales (el modelo solo existe en este cliente)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local function load(id: string, looped: boolean)
		local a = Instance.new("Animation"); a.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(a) end)
		if ok and track then track.Looped = looped end
		return ok and track or nil
	end
	local idle, wave = load(IDLE, true), load(WAVE, false)
	if idle then idle:Play(0.3) end
	local lastWave = 0
	RunService.Heartbeat:Connect(function()
		if not npc.Parent then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local d = (hrp.Position - root.Position).Magnitude
		if d < 16 and os.clock() - lastWave > 8 and wave then      -- saluda al acercarte (cada 8 s como mucho)
			lastWave = os.clock(); wave:Play(0.2)
		end
		if d < 30 then                                              -- te sigue con la mirada, solo girando el cuerpo
			local flat = Vector3.new(hrp.Position.X, root.Position.Y, hrp.Position.Z)
			local look = (flat - root.Position)
			if look.Magnitude > 0.5 and look.Unit.X < 0.2 then         -- solo hacia delante del mostrador
				root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, flat), 0.08)
			end
		end
	end)
end
task.spawn(spawnKeeper)
