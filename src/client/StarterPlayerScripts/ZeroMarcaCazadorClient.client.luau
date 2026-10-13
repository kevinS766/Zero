-- ZeroMarcaCazadorClient (LocalScript, StarterPlayerScripts): los cazadores (jugadores y bots con Role = "Hunter")
-- se ven marcados con un contorno rojo a través de las paredes, para quien no es cazador. Solo en este cliente.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local MARCA = "ZeroMarcaCazador"
local function rolDe(character: Model): string?
	local p = Players:GetPlayerFromCharacter(character)
	return if p then p:GetAttribute("Role") else character:GetAttribute("Role")
end

local function actualizar()
	local soyCazador = player:GetAttribute("Role") == "Hunter"
	local personajes = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(personajes, p.Character) end end
	local bots = workspace:FindFirstChild("ZeroBots")
	if bots then for _, b in bots:GetChildren() do if b:IsA("Model") then table.insert(personajes, b) end end end
	for _, ch in personajes do
		local marcar = not soyCazador and ch ~= player.Character and rolDe(ch) == "Hunter"
		local h = ch:FindFirstChild(MARCA) :: Highlight?
		if marcar and not h then
			h = Instance.new("Highlight")
			h.Name = MARCA
			h.FillColor = Color3.fromRGB(255, 40, 60); h.FillTransparency = 0.75
			h.OutlineColor = Color3.fromRGB(255, 70, 80); h.OutlineTransparency = 0
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop          -- se ve a través de las paredes
			h.Adornee = ch
			h.Parent = ch
		elseif not marcar and h then
			h:Destroy()
		end
	end
end

-- ponytail: sondeo cada 0,5 s en vez de escuchar roles, personajes y bots por separado; barato con ≤ 30 personajes
local t = 0
RunService.Heartbeat:Connect(function(dt)
	t += dt
	if t >= 0.5 then t = 0; actualizar() end
end)
