--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LeaderboardConfig = require(Shared:WaitForChild("Config"):WaitForChild("LeaderboardConfig"))

local LeaderboardService = {}

-- Tipos internos
type LeaderboardEntry = {
	userId: number,
	value: number,
	name: string?,
}

-- Referencia a DataService
local dataServiceRef: any = nil

-- DataStores ordenados para clasificaciones
local winsOrderedStore: any = nil
local huntersOrderedStore: any = nil

-- Memoria caché de nombres para no agotar peticiones de Players
local playerNameCache: { [number]: string } = {}

-- Memoria caché de entradas Top en ejecución
local cachedWinsTop: { LeaderboardEntry } = {}
local cachedHuntersTop: { LeaderboardEntry } = {}

-- Función segura para resolver nombres de usuario
local function getPlayerName(userId: number): string
	if playerNameCache[userId] then
		return playerNameCache[userId]
	end

	-- Buscar jugador en la sesión activa primero
	local activePlayer = Players:GetPlayerByUserId(userId)
	if activePlayer then
		local displayName = activePlayer.DisplayName
		playerNameCache[userId] = displayName
		return displayName
	end

	-- Resolver vía API con pcall y timeout de seguridad
	local success, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if success and name then
		playerNameCache[userId] = name
		return name
	end

	return "Jugador_" .. tostring(userId)
end

-- Renderiza un ranking dentro del SurfaceGui del Stand (zero-jugabilidad/tableros/tablero.luau):
-- podio con el top 3 (cartas oro/plata/bronce, avatar grande, corona al #1) y debajo filas 4-10 con avatar y aro.
local FUENTE = Enum.Font.FredokaOne
local METAL = { LeaderboardConfig.COLORS.RANK_1, LeaderboardConfig.COLORS.RANK_2, LeaderboardConfig.COLORS.RANK_3 }

local function crear(clase: string, props: { [string]: any }, padre: Instance?): any
	local i = Instance.new(clase)
	for k, v in props do (i :: any)[k] = v end
	i.Parent = padre
	return i
end

local function redondo(padre: Instance, radio: UDim)
	crear("UICorner", { CornerRadius = radio }, padre)
end

local function miles(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local r, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then return s end
	end
end

local function texto(padre: Instance, t: string, pos: UDim2, size: UDim2, color: Color3, props: { [string]: any }?): TextLabel
	local l = crear("TextLabel", {
		BackgroundTransparency = 1, Position = pos, Size = size, Font = FUENTE, Text = t, TextColor3 = color,
		TextScaled = true, TextTruncate = Enum.TextTruncate.AtEnd,
	}, padre)
	crear("UIStroke", { Thickness = 2, Color = Color3.fromRGB(20, 12, 30), Transparency = 0.2 }, l)
	for k, v in props or {} do (l :: any)[k] = v end
	return l
end

-- avatar redondo con aro de color (y halo detrás si lleva brillo)
local function avatar(padre: Instance, userId: number?, lado: number, pos: UDim2, color: Color3, aro: number, halo: boolean?): Frame
	local caja = crear("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = pos, Size = UDim2.fromOffset(lado, lado) }, padre)
	if halo then
		local h = crear("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.3, 1.3),
			BackgroundColor3 = color, BackgroundTransparency = 0.55, ZIndex = 1 }, caja)
		redondo(h, UDim.new(1, 0))
		crear("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90 }, h)
	end
	local img = crear("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(60, 45, 85), ZIndex = 2,
		Image = if userId then "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150" else "" }, caja)
	redondo(img, UDim.new(1, 0))
	crear("UIStroke", { Thickness = aro, Color = color }, img)
	if not userId then texto(img, "?", UDim2.fromScale(0.25, 0.2), UDim2.fromScale(0.5, 0.6), Color3.fromRGB(120, 105, 150), { ZIndex = 3 }) end
	return caja
end

local function cartaPodio(lista: Frame, puesto: number, entry: LeaderboardEntry?)
	local color = METAL[puesto]
	local x = ({ 0.5, 0.165, 0.835 })[puesto]
	local ancho = if puesto == 1 then 0.35 else 0.295
	local bajada = if puesto == 1 then 0 else 34
	local carta = crear("Frame", { Name = "Podio_" .. puesto, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x, 0, 0, bajada),
		Size = UDim2.new(ancho, 0, 0, 262 - bajada), BackgroundColor3 = color, BackgroundTransparency = if entry then 0.15 else 0.6, LayoutOrder = puesto }, lista)
	redondo(carta, UDim.new(0, 16))
	crear("UIStroke", { Thickness = if puesto == 1 then 4 else 3, Color = color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, carta)
	-- metal oscurecido hacia abajo, con un brillo diagonal arriba
	crear("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.25)),
		ColorSequenceKeypoint.new(0.35, color:Lerp(Color3.fromRGB(40, 25, 60), 0.55)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 20, 45)) }) }, carta)

	local lado = if puesto == 1 then 116 else 88
	avatar(carta, entry and entry.userId, lado, UDim2.new(0.5, 0, 0, if puesto == 1 then 30 else 18), color, if puesto == 1 then 5 else 4, entry ~= nil)
	if puesto == 1 then
		local corona = texto(carta, "👑", UDim2.new(0.5, -34, 0, -40), UDim2.fromOffset(68, 68), Color3.new(1, 1, 1), { ZIndex = 5, Rotation = -12 })
		corona:FindFirstChildOfClass("UIStroke"):Destroy()
	end
	-- medalla con el puesto, pegada al avatar
	local medalla = crear("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, lado * 0.36, 0, (if puesto == 1 then 30 else 18) + lado * 0.86),
		Size = UDim2.fromOffset(38, 38), BackgroundColor3 = color, ZIndex = 4 }, carta)
	redondo(medalla, UDim.new(1, 0))
	crear("UIStroke", { Thickness = 3, Color = Color3.fromRGB(30, 20, 45) }, medalla)
	texto(medalla, tostring(puesto), UDim2.fromScale(0.15, 0.1), UDim2.fromScale(0.7, 0.8), Color3.new(1, 1, 1), { ZIndex = 5 })

	local yNombre = (if puesto == 1 then 30 else 18) + lado + 14
	texto(carta, if entry then (entry.name or getPlayerName(entry.userId)) else "—", UDim2.new(0.06, 0, 0, yNombre), UDim2.new(0.88, 0, 0, if puesto == 1 then 34 else 28),
		Color3.new(1, 1, 1))
	local pastilla = crear("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, yNombre + (if puesto == 1 then 40 else 33)),
		Size = UDim2.new(0.78, 0, 0, if puesto == 1 then 40 else 34), BackgroundColor3 = Color3.fromRGB(25, 15, 38), BackgroundTransparency = 0.15 }, carta)
	redondo(pastilla, UDim.new(1, 0))
	crear("UIStroke", { Thickness = 2, Color = color }, pastilla)
	texto(pastilla, if entry then miles(entry.value) else "-", UDim2.fromScale(0.08, 0.12), UDim2.fromScale(0.84, 0.76), color)
end

local function fila(lista: Frame, puesto: number, entry: LeaderboardEntry)
	local f = crear("Frame", { Name = string.format("Row_%02d", puesto), LayoutOrder = puesto, Size = UDim2.new(1, 0, 0, 39),
		BackgroundColor3 = if puesto % 2 == 0 then Color3.fromRGB(70, 50, 100) else Color3.fromRGB(55, 38, 80), BackgroundTransparency = 0.1 }, lista)
	redondo(f, UDim.new(0, 10))
	crear("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(120, 95, 160), Transparency = 0.4 }, f)
	texto(f, tostring(puesto), UDim2.new(0, 6, 0.15, 0), UDim2.new(0, 34, 0.7, 0), Color3.fromRGB(200, 185, 230))
	avatar(f, entry.userId, 31, UDim2.new(0, 64, 0, 4), Color3.fromRGB(150, 125, 200), 2)
	texto(f, entry.name or getPlayerName(entry.userId), UDim2.new(0, 88, 0.17, 0), UDim2.new(0.6, -88, 0.66, 0), Color3.new(1, 1, 1),
		{ TextXAlignment = Enum.TextXAlignment.Left })
	texto(f, miles(entry.value), UDim2.new(0.6, 0, 0.17, 0), UDim2.new(0.4, -14, 0.66, 0), LeaderboardConfig.COLORS.RANK_1,
		{ TextXAlignment = Enum.TextXAlignment.Right })
end

local function renderBoard(boardModel: Instance?, titleText: string, entries: { LeaderboardEntry })
	if not boardModel then return end
	local screenPart = boardModel:FindFirstChild("Screen") :: BasePart?
	local boardGui = screenPart and screenPart:FindFirstChild("BoardGui") :: SurfaceGui?
	if not boardGui then return end

	local titleLabel = boardGui:FindFirstChild("Title") :: TextLabel?
	if titleLabel then titleLabel.Text = titleText end
	local listFrame = boardGui:FindFirstChild("List") :: Frame?
	if not listFrame then return end
	for _, child in listFrame:GetChildren() do child:Destroy() end
	listFrame.ClipsDescendants = false

	if #entries == 0 then
		texto(listFrame, "¡Juega para salir aquí!", UDim2.fromScale(0, 0.4), UDim2.new(1, 0, 0, 40), Color3.fromRGB(200, 185, 230), { Name = "EmptyNotice" })
		return
	end

	-- podio (262 px) y debajo las filas 4-10 (39 px + 4 de hueco) en su propio contenedor con UIListLayout
	local podio = crear("Frame", { Name = "Podio", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 262) }, listFrame)
	for puesto = 1, 3 do cartaPodio(podio, puesto, entries[puesto]) end
	local resto = crear("Frame", { Name = "Resto", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 270), Size = UDim2.new(1, 0, 1, -270) }, listFrame)
	crear("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, resto)
	for index = 4, math.min(#entries, LeaderboardConfig.MAX_ENTRIES) do fila(resto, index, entries[index]) end
	if #entries <= 3 then
		texto(resto, "¡Juega para salir aquí!", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 36), Color3.fromRGB(200, 185, 230), { LayoutOrder = 99 })
	end
end

-- Lee los datos del OrderedDataStore correspondiente
local function fetchSortedTop(store: any): { LeaderboardEntry }
	local result: { LeaderboardEntry } = {}
	if not store then return result end

	local success, pages = pcall(function()
		return store:GetSortedAsync(false, LeaderboardConfig.MAX_ENTRIES, 1)
	end)

	if success and pages then
		local currentData = pages:GetCurrentPage()
		for _, dataItem in ipairs(currentData) do
			local uid = tonumber(dataItem.key) or 0
			local score = tonumber(dataItem.value) or 0
			if uid > 0 then
				table.insert(result, {
					userId = uid,
					value = score,
					name = getPlayerName(uid),
				})
			end
		end
	end

	return result
end

-- Sube las estadísticas actuales de un jugador al OrderedDataStore
function LeaderboardService.syncPlayerStats(player: Player)
	if not dataServiceRef or player.UserId <= 0 then return end

	local wins = dataServiceRef.getStat(player, "wins") or 0
	local hunterTags = dataServiceRef.getStat(player, "hunter_tags") or 0

	task.spawn(function()
		if winsOrderedStore and wins > 0 then
			pcall(function()
				winsOrderedStore:SetAsync(tostring(player.UserId), math.floor(wins))
			end)
		end
		if huntersOrderedStore and hunterTags > 0 then
			pcall(function()
				huntersOrderedStore:SetAsync(tostring(player.UserId), math.floor(hunterTags))
			end)
		end
	end)
end

-- Actualiza y renderiza ambos tableros del Lobby
function LeaderboardService.refreshBoards()
	local lobby = Workspace:FindFirstChild("ZeroLobby")
	if not lobby then return end

	local leaderboardsFolder = lobby:FindFirstChild("Leaderboards")
	if not leaderboardsFolder then return end

	local board1 = leaderboardsFolder:FindFirstChild("Board1")
	local board2 = leaderboardsFolder:FindFirstChild("Board2")

	-- 1. Actualizar Top Wins (Board1)
	if winsOrderedStore then
		local topWins = fetchSortedTop(winsOrderedStore)
		if #topWins > 0 then
			cachedWinsTop = topWins
		end
	end
	renderBoard(board1, "VICTORIAS", cachedWinsTop)

	-- 2. Actualizar Top Hunters (Board2)
	if huntersOrderedStore then
		local topHunters = fetchSortedTop(huntersOrderedStore)
		if #topHunters > 0 then
			cachedHuntersTop = topHunters
		end
	end
	renderBoard(board2, "CONGELADOS", cachedHuntersTop)
end

-- Inicialización del servicio
function LeaderboardService.init(dataService: any?)
	dataServiceRef = dataService or require(script.Parent.DataService)

	-- Inicializar DataStores ordenados con protección pcall
	local successStore, storeErr = pcall(function()
		winsOrderedStore = DataStoreService:GetOrderedDataStore(LeaderboardConfig.STORES.TOP_WINS)
		huntersOrderedStore = DataStoreService:GetOrderedDataStore(LeaderboardConfig.STORES.TOP_HUNTERS)
	end)

	if not successStore then
		warn("[LeaderboardService] Error al conectar con OrderedDataStore:", tostring(storeErr))
	end

	-- Sincronizar stats cuando un jugador sale del servidor
	Players.PlayerRemoving:Connect(function(player)
		LeaderboardService.syncPlayerStats(player)
	end)

	-- Bucle periódico de refresco visual de carteles
	task.spawn(function()
		-- Esperar a que el Lobby cargue
		task.wait(2)
		LeaderboardService.refreshBoards()

		while true do
			task.wait(LeaderboardConfig.REFRESH_INTERVAL)
			-- Sincronizar todos los jugadores activos antes de actualizar
			for _, player in Players:GetPlayers() do
				LeaderboardService.syncPlayerStats(player)
			end
			task.wait(2)
			LeaderboardService.refreshBoards()
		end
	end)

	print("[LeaderboardService] Inicializado correctamente con TOP WINS y TOP HUNTERS.")
end

return LeaderboardService
