--!strict
-- MapService: votación de mapa con los pedestales del lobby y carga del mapa elegido.
--  * Los mapas viven en ServerStorage.Mapas; solo el mapa votado está en Workspace (los demás no existen en el
--    cliente: menos memoria y nada que ver por accidente).
--  * Los pedestales HunterClasses.Slot1..3 siguen MapConfig.SlotMapOrder; los paneles muestran nombre, icono y votos.
--  * Empate o cero votos: se elige al azar entre los empatados (o entre todos).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("Config"):WaitForChild("MapConfig"))

local MapService = {}

local currentVotes: { [string]: number } = {}
local playerVoteMap: { [number]: string } = {} -- UserId -> MapId
local selectedMapId: string = MapConfig.DEFAULT_MAP
local lastStepTimeByUserId: { [number]: number } = {}

local function storage(): Folder
	local f = ServerStorage:FindFirstChild("Mapas") :: Folder?
	if not f then
		f = Instance.new("Folder")
		f.Name = "Mapas"
		f.Parent = ServerStorage
	end
	return f :: Folder
end

local function mapIds(): { string }
	local ids = {}
	for _, id in MapConfig.SlotMapOrder do table.insert(ids, id) end
	return ids
end

local function resetCounts()
	table.clear(currentVotes)
	for _, id in mapIds() do currentVotes[id] = 0 end
end

local function slotModel(index: number): Instance?
	local lobby = Workspace:FindFirstChild("ZeroLobby")
	local hc = lobby and lobby:FindFirstChild("HunterClasses")
	return hc and hc:FindFirstChild("Slot" .. index)
end

-- Paneles físicos del lobby: nombre, icono, color y votos
local function updateLobbyDisplays()
	for index, id in MapConfig.SlotMapOrder do
		local slot = slotModel(index)
		local panel = slot and slot:FindFirstChild("Panel")
		local gui = panel and panel:FindFirstChild("PanelGui")
		local entry = MapConfig.Maps[id]
		if gui and entry then
			local nameLabel = gui:FindFirstChild("ClassName") :: TextLabel?
			if nameLabel then nameLabel.Text = entry.DisplayName end
			local preview = gui:FindFirstChild("MapPreview") :: ImageLabel?
			if preview then
				preview.Image = entry.PreviewAssetId
				preview.BackgroundColor3 = entry.Color
				preview.BackgroundTransparency = if entry.PreviewAssetId == "" then 0 else 1
				local icon = preview:FindFirstChild("Icono") :: TextLabel?
				if not icon then
					icon = Instance.new("TextLabel")
					icon.Name = "Icono"
					icon.Size = UDim2.fromScale(1, 1)
					icon.BackgroundTransparency = 1
					icon.TextScaled = true
					icon.Parent = preview
				end
				(icon :: TextLabel).Text = if entry.PreviewAssetId == "" then entry.Icon else ""
			end
			local voteLabel = gui:FindFirstChild("VoteCount") :: TextLabel?
			if voteLabel then
				local count = currentVotes[id] or 0
				voteLabel.Text = string.format("%d VOTO%s", count, if count == 1 then "" else "S")
			end
		end
	end
end

function MapService.castVote(player: Player, mapId: string)
	if currentVotes[mapId] == nil then return end
	if player:GetAttribute("AFK") then return end   -- los AFK no votan (ZeroAFKClient / Ajustes)
	local previousVote = playerVoteMap[player.UserId]
	if previousVote == mapId then return end
	if previousVote and currentVotes[previousVote] then
		currentVotes[previousVote] = math.max(0, currentVotes[previousVote] - 1)
	end
	playerVoteMap[player.UserId] = mapId
	player:SetAttribute("ZeroVotoMapa", mapId)       -- para la misión "vota el mapa ganador"
	currentVotes[mapId] += 1
	print(string.format("[MapService] %s votó por el mapa: %s", player.Name, mapId))
	updateLobbyDisplays()
end

function MapService.resetVotes()
	table.clear(playerVoteMap)
	for _, p in Players:GetPlayers() do p:SetAttribute("ZeroVotoMapa", nil) end
	resetCounts()
	updateLobbyDisplays()
end

function MapService.getVoteDuration(): number
	return MapConfig.VOTE_DURATION
end

-- Mete en Workspace solo el mapa indicado; los demás vuelven a ServerStorage.Mapas
function MapService.loadMap(mapId: string)
	local store = storage()
	for _, id in mapIds() do
		local name = MapConfig.Maps[id].WorkspaceName
		local inWorld = Workspace:FindFirstChild(name)
		local stored = store:FindFirstChild(name)
		if id == mapId then
			if not inWorld and stored then stored.Parent = Workspace end
		elseif inWorld then
			inWorld.Parent = store
		end
	end
end

-- Mapa ganador por mayoría; empate o sin votos: azar entre los empatados (o entre todos). Lo deja cargado.
function MapService.finalizeChosenMap(): string
	local best, winners = -1, {}
	for _, id in mapIds() do
		local v = currentVotes[id] or 0
		if v > best then best, winners = v, { id }
		elseif v == best then table.insert(winners, id) end
	end
	selectedMapId = winners[math.random(1, #winners)]
	MapService.loadMap(selectedMapId)

	local parts = {}
	for _, id in mapIds() do table.insert(parts, string.format("%s=%d", MapConfig.Maps[id].DisplayName, currentVotes[id] or 0)) end
	print(string.format("[MapService] Mapa seleccionado: %s (%s)", selectedMapId, table.concat(parts, ", ")))
	ReplicatedStorage:SetAttribute("CurrentMap", selectedMapId)
	return selectedMapId
end

function MapService.getSelectedMapId(): string
	return selectedMapId
end

-- SpawnPoints CFrame del mapa cargado y rol
function MapService.getSpawnsForCurrentMap(roleKind: ("RUNNER" | "HUNTER")?): { CFrame }
	local entry = MapConfig.Maps[selectedMapId]
	local mapModel = entry and Workspace:FindFirstChild(entry.WorkspaceName)
	local cframes: { CFrame } = {}
	local spawnPointsFolder = mapModel and mapModel:FindFirstChild("SpawnPoints")
	if spawnPointsFolder then
		local targetSubFolder: Instance? = nil
		if roleKind == "HUNTER" then
			targetSubFolder = spawnPointsFolder:FindFirstChild("Hunters") or spawnPointsFolder:FindFirstChild("Hunter")
		elseif roleKind == "RUNNER" then
			targetSubFolder = spawnPointsFolder:FindFirstChild("Runners") or spawnPointsFolder:FindFirstChild("Runner")
		end
		if targetSubFolder then
			for _, child in targetSubFolder:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(cframes, child.CFrame + Vector3.new(0, (child.Size.Y / 2) + 3, 0))
				elseif child:IsA("Model") then
					table.insert(cframes, child:GetPivot() + Vector3.new(0, 4, 0))
				end
			end
		end
		if #cframes == 0 then
			for _, desc in spawnPointsFolder:GetDescendants() do
				if desc:IsA("BasePart") then
					table.insert(cframes, desc.CFrame + Vector3.new(0, (desc.Size.Y / 2) + 3, 0))
				end
			end
		end
	end
	if #cframes == 0 then
		warn("[MapService] Sin spawns para " .. tostring(selectedMapId) .. "; usando el centro del mapa")
		local pivot = if mapModel and mapModel:IsA("Model") then mapModel:GetPivot().Position else Vector3.new(0, 90, 0)
		table.insert(cframes, CFrame.new(pivot + Vector3.new(0, 6, 0)))
	end
	return cframes
end

-- Pedestales: pisar uno vota por su mapa
local function bindPads()
	for index, id in MapConfig.SlotMapOrder do
		local slot = slotModel(index)
		local pad = slot and slot:FindFirstChild("Pad") :: BasePart?
		if pad then
			pad.Touched:Connect(function(hit)
				local character = hit.Parent
				if not character then return end
				local player = Players:GetPlayerFromCharacter(character)
				if not player then return end
				local now = os.clock()
				if now - (lastStepTimeByUserId[player.UserId] or 0) < 0.5 then return end
				lastStepTimeByUserId[player.UserId] = now
				MapService.castVote(player, id)
			end)
		end
	end
end

function MapService.init()
	resetCounts()
	-- Todos los mapas de la rotación a ServerStorage.Mapas: ninguno en Workspace hasta que se vote
	local store = storage()
	for _, id in mapIds() do
		local m = Workspace:FindFirstChild(MapConfig.Maps[id].WorkspaceName)
		if m then m.Parent = store end
	end
	bindPads()
	updateLobbyDisplays()
	ReplicatedStorage:SetAttribute("CurrentMap", selectedMapId)

	-- quien pasa a AFK pierde su voto
	local function quitarVoto(player: Player)
		local vote = playerVoteMap[player.UserId]
		if vote and currentVotes[vote] then
			currentVotes[vote] = math.max(0, currentVotes[vote] - 1)
			playerVoteMap[player.UserId] = nil
			updateLobbyDisplays()
		end
	end
	local function vigilarAFK(player: Player)
		player:GetAttributeChangedSignal("AFK"):Connect(function() if player:GetAttribute("AFK") then quitarVoto(player) end end)
	end
	for _, p in Players:GetPlayers() do vigilarAFK(p) end
	Players.PlayerAdded:Connect(vigilarAFK)

	Players.PlayerRemoving:Connect(function(player)
		local vote = playerVoteMap[player.UserId]
		if vote and currentVotes[vote] then
			currentVotes[vote] = math.max(0, currentVotes[vote] - 1)
			playerVoteMap[player.UserId] = nil
			updateLobbyDisplays()
		end
		lastStepTimeByUserId[player.UserId] = nil
	end)

	print("[MapService] Votación lista: " .. table.concat(mapIds(), ", "))
end

return MapService
