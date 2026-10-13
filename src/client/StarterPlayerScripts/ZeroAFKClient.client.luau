-- ZeroAFKClient (LocalScript, StarterPlayerScripts): AFK automático e insignia "AFK" (zero-todo, punto 2.4).
--   · Si no tocas nada (teclado, ratón, toque, mando) en INACTIVO segundos, pide al servidor el modo AFK (mismo
--     "SetAFK" del botón de Ajustes): no entras a las rondas y no puedes votar mapa (MapService). Al volver a moverte
--     se quita solo; si lo activaste tú desde Ajustes, se respeta.
--   · Encima de cada jugador en AFK (atributo AFK) se dibuja una insignia que late suave; la tuya también.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local INACTIVO = 150
local ultimo = os.clock()
local autoPuesto = false

local function pedir(on: boolean)
	task.spawn(function()
		local ok, res = pcall(function() return ReplicatedStorage:WaitForChild("ZeroUIRequest"):InvokeServer("SetAFK", { on = on }) end)
		if not (ok and res and res.success) and on then autoPuesto = false end
	end)
end

local function actividad()
	ultimo = os.clock()
	if autoPuesto then
		autoPuesto = false
		if player:GetAttribute("AFK") then pedir(false) end
	end
end
UserInputService.InputBegan:Connect(actividad)
UserInputService.InputChanged:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
		or i.UserInputType == Enum.UserInputType.Gamepad1 then actividad() end
end)
task.spawn(function()
	while true do
		task.wait(5)
		if not autoPuesto and not player:GetAttribute("AFK") and os.clock() - ultimo > INACTIVO then
			autoPuesto = true
			pedir(true)
		end
	end
end)
-- si lo desactivan desde Ajustes, ya no es "automático"
player:GetAttributeChangedSignal("AFK"):Connect(function() if not player:GetAttribute("AFK") then autoPuesto = false end end)

-- ------------------------------------------------------------------ insignias
local insignias: { [Player]: { bb: BillboardGui, escala: UIScale } } = {}
local function insignia(p: Player)
	local head = p.Character and p.Character:FindFirstChild("Head") :: BasePart?
	local quiere = p:GetAttribute("AFK") == true and head ~= nil
	local i = insignias[p]
	if i and (not quiere or i.bb.Adornee ~= head) then i.bb:Destroy(); insignias[p] = nil; i = nil end
	if not quiere or i then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "ZeroAFK"; bb.Size = UDim2.fromOffset(84, 34); bb.StudsOffsetWorldSpace = Vector3.new(0, 5.6, 0)
	bb.MaxDistance = 120; bb.LightInfluence = 0; bb.Adornee = head
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromScale(0.5, 0.5); f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(255, 160, 40); f.Parent = bb
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
	local s = Instance.new("UIStroke"); s.Thickness = 3; s.Color = Color3.fromRGB(20, 14, 34); s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = f
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Font = Enum.Font.FredokaOne; t.TextScaled = true
	t.Text = "💤 AFK"; t.TextColor3 = Color3.new(1, 1, 1); t.Parent = f
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4); pad.Parent = f
	local ts = Instance.new("UIStroke"); ts.Thickness = 2; ts.Color = Color3.fromRGB(20, 14, 34); ts.Parent = t
	local escala = Instance.new("UIScale"); escala.Parent = f
	bb.Parent = player:WaitForChild("PlayerGui")
	insignias[p] = { bb = bb, escala = escala }
end
local function vigilar(p: Player)
	p:GetAttributeChangedSignal("AFK"):Connect(function() insignia(p) end)
	p.CharacterAdded:Connect(function(ch) ch:WaitForChild("Head", 10); insignia(p) end)
	insignia(p)
end
for _, p in Players:GetPlayers() do vigilar(p) end
Players.PlayerAdded:Connect(vigilar)
Players.PlayerRemoving:Connect(function(p) local i = insignias[p]; if i then i.bb:Destroy(); insignias[p] = nil end end)
RunService.Heartbeat:Connect(function()
	local k = 1 + 0.08 * math.sin(os.clock() * 3)      -- latido suave
	for _, i in insignias do i.escala.Scale = k end
end)
