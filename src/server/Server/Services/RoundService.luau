local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoundStates = require(Shared:WaitForChild("Constants"):WaitForChild("RoundStates"))
local PlayerRoles = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerRoles"))
local RoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("RoundConfig"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local RoundService = {}
local DataService = require(script.Parent.DataService)
local roundRoster, resultResolved = {}, false
local roundId = 0
local CELEBRACION = 5   -- segundos de clímax al acabar la ronda antes de volver al lobby (ZeroVictoriaClient)

-- Referencias a servicios inyectadas en init()
local playerStateServiceRef: any = nil
local hunterClassServiceRef: any = nil
local botServiceRef: any = nil
local mapServiceRef: any = nil
local mapReady = false   -- false durante la votación: el mapa aún no está en el Workspace

local function getActors()
	return playerStateServiceRef and playerStateServiceRef.getActors() or Players:GetPlayers()
end

-- Jugadores en modo AFK (botón de Ajustes): no entran a las rondas, se quedan en el lobby
local function isAFK(actor): boolean
	return typeof(actor) == "Instance" and actor:IsA("Player") and actor:GetAttribute("AFK") == true
end
local function activeActors()
	local result = {}
	for _, actor in getActors() do if not isAFK(actor) then table.insert(result, actor) end end
	return result
end

local function canStart()
	local activos = 0
	for _, p in Players:GetPlayers() do if p:GetAttribute("AFK") ~= true then activos += 1 end end   -- los AFK no cuentan
	return activos > 0 and (activos >= RoundConfig.MIN_PLAYERS or botServiceRef ~= nil)
end

local function eligibleRoster()
	local result = {}
	for _, actor in roundRoster do
		if playerStateServiceRef.isRegistered(actor) then table.insert(result, actor) end
	end
	return result
end

-- Estado interno
local currentState: string = RoundStates.WAITING_FOR_PLAYERS
local currentTimer: number = 0
local currentDeadline: number = 0
local stateVersion: number = 0
local statusMessage: string = "Esperando jugadores..."
local isLoopRunning: boolean = false
local stateSkipRequested: boolean = false
local wasForcedByDebug: boolean = false

-- Registro de jugadores ya posicionados en el mapa
local onMap: { [number]: boolean } = {}
local hunterPlatform: Part? = nil

-- RemoteEvent para sincronizar UI de los clientes
local roundStatusEvent: RemoteEvent = NetworkEvents.getRemoteEvent("RoundStatusUpdate")

-- Carpeta ZeroRuntime para instancias temporales del servidor
local function getRuntimeFolder(): Folder
	local runtimeFolder = Workspace:FindFirstChild("ZeroRuntime") :: Folder?
	if not runtimeFolder then
		runtimeFolder = Instance.new("Folder")
		runtimeFolder.Name = "ZeroRuntime"
		runtimeFolder.Parent = Workspace
	end
	return runtimeFolder
end

-- Asegura la existencia de la plataforma de espera del Hunter
local function ensureHunterPlatform(): Part
	if hunterPlatform and hunterPlatform.Parent then
		return hunterPlatform
	end

	local part = Instance.new("Part")
	part.Name = "HunterPlatform"
	part.Size = RoundConfig.HUNTER_PLATFORM_SIZE or Vector3.new(64, 2, 64)
	part.Position = RoundConfig.HUNTER_PLATFORM_POSITION or Vector3.new(0, 300, 600)
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(255, 255, 255)
	part.Parent = getRuntimeFolder()

	hunterPlatform = part
	return part
end

-- Destruye la plataforma de espera del Hunter
local function destroyHunterPlatform()
	if hunterPlatform and hunterPlatform.Parent then
		hunterPlatform:Destroy()
	end
	hunterPlatform = nil
end

-- Helper: Busca puntos de spawn compatibles (Part, Model, Folder o SpawnLocation)
-- Soporta nombres directos o variantes (LobbySpawns / ZeroLobby, MapSpawns / Map1_PlazaUrbana)
-- Opcionalmente filtra por rol: "RUNNER" o "HUNTER" dentro de Map.SpawnPoints
local function getSpawns(locationType: "LOBBY" | "MAP", roleKind: ("RUNNER" | "HUNTER")?): { CFrame }
	if locationType == "MAP" and mapServiceRef then
		local mapSpawns = mapServiceRef.getSpawnsForCurrentMap(roleKind)
		if #mapSpawns > 0 then return mapSpawns end
	end
	local candidateNames = if locationType == "LOBBY"
		then { "ZeroLobby", "LobbySpawns", "Lobby", "SpawnLocation" }
		else { "Map3_IslaTiki", "Map4_CiudadPastel", "Map5_PuebloCalabaza", "MapSpawns", "Map", "ArenaSpawns" }

	local cframes: { CFrame } = {}

	for _, name in candidateNames do
		local obj = Workspace:FindFirstChild(name)
		if obj then
			-- Si es mapa y tiene carpeta de SpawnPoints estructurada por KaiBit23
			if locationType == "MAP" and (obj:IsA("Model") or obj:IsA("Folder")) then
				local spawnPointsFolder = obj:FindFirstChild("SpawnPoints")
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
						if #cframes > 0 then
							return cframes
						end
					end
				end
			end

			if obj:IsA("BasePart") then
				-- Es una plataforma o SpawnLocation directamente
				table.insert(cframes, obj.CFrame + Vector3.new(0, (obj.Size.Y / 2) + 3, 0))
			elseif obj:IsA("Model") then
				-- Es un modelo fallback: si tiene PrimaryPart lo usamos, si no su Pivot CFrame
				local pivot = if obj.PrimaryPart then obj.PrimaryPart.CFrame else obj:GetPivot()
				table.insert(cframes, pivot + Vector3.new(0, 4, 0))
			elseif obj:IsA("Folder") then
				-- Es una carpeta contenedora de puntos
				for _, child in obj:GetChildren() do
					if child:IsA("BasePart") then
						table.insert(cframes, child.CFrame + Vector3.new(0, (child.Size.Y / 2) + 3, 0))
					elseif child:IsA("Model") then
						table.insert(cframes, child:GetPivot() + Vector3.new(0, 4, 0))
					end
				end
			end

			-- Si encontramos spawns válidos bajo este candidato, los usamos
			if #cframes > 0 then
				break
			end
		end
	end

	return cframes
end

-- Quien está sentado (bancos del lobby) se levanta antes de moverlo: si no, la SeatWeld arrastra el asiento anclado
local function levantar(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local weld = humanoid and humanoid.SeatPart and humanoid.SeatPart:FindFirstChild("SeatWeld")
	if weld then weld:Destroy(); humanoid.Sit = false; task.wait(0.1) end   -- sin esperar, el cliente (dueño del personaje) lo devuelve al banco
end

-- Teletransporta un jugador a una posición de spawn aleatoria
-- Retorna true si el jugador fue teletransportado con éxito
local function teleportPlayer(player: Player, spawnPositions: { CFrame }): boolean
	local character = player.Character
	if not character then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return false end
	levantar(character)

	if #spawnPositions > 0 then
		local selectedCFrame = spawnPositions[math.random(1, #spawnPositions)]
		rootPart.CFrame = selectedCFrame
		return true
	else
		-- Fallback a (0, 10, 0) si no se encontró plataforma en Workspace
		rootPart.CFrame = CFrame.new(0, 10, 0)
		return true
	end
end

-- Teletransporta al Hunter a la Sala del Cazador mientras elige clase (Workspace.ZeroSalaCazador, pieza
-- HunterSpawn: aparece mirando al mosaico). Si la sala no está en el Workspace, usa la plataforma provisional blanca.
function RoundService.sendToHunterPlatform(player: Player)
	onMap[player.UserId] = nil
	local character = player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not hrp then return end
	levantar(character :: Model)

	local sala = Workspace:FindFirstChild("ZeroSalaCazador")
	local salaSpawn = sala and sala:FindFirstChild("HunterSpawn", true) :: BasePart?
	if salaSpawn then
		hrp.CFrame = salaSpawn.CFrame + Vector3.new(0, (salaSpawn.Size.Y / 2) + 3, 0)
	else
		local platform = ensureHunterPlatform()
		hrp.CFrame = platform.CFrame + Vector3.new(0, (platform.Size.Y / 2) + 3, 0)
	end
end

-- Teletransporta a un jugador al mapa y lo registra en onMap si tiene éxito
local spawnTurno = 0
function RoundService.sendToMap(player: Player, roleKind: ("RUNNER" | "HUNTER")?)
	-- Durante la votación no hay mapa cargado: quien entra o reaparece se queda en el lobby (antes caía desde y=96)
	if mapServiceRef and not mapReady then
		teleportPlayer(player, getSpawns("LOBBY"))
		return
	end
	local spawns = getSpawns("MAP", roleKind)
	if #spawns == 0 then
		if teleportPlayer(player, spawns) then onMap[player.UserId] = true end
		return
	end
	-- salidas repartidas en orden (al azar, dos podían caer en el mismo punto y chocar)
	spawnTurno += 1
	local cf = spawns[(spawnTurno - 1) % #spawns + 1]
	onMap[player.UserId] = true
	if typeof(player) == "Instance" and player:IsA("Player") then
		-- el mapa acaba de entrar al Workspace: se espera a que llegue a su cliente (StreamingEnabled) antes de aparecer,
		-- si no aparecía sin suelo y se caía
		task.spawn(function()
			pcall(function() player:RequestStreamAroundAsync(cf.Position, 6) end)
			if onMap[player.UserId] and player.Parent then teleportPlayer(player, { cf }) end
		end)
	else
		teleportPlayer(player, { cf })
	end
end

-- Teletransporta a todos los jugadores pendientes que no estén en el mapa todavía (Hunter y rezagados)
function RoundService.teleportPendingToMap()
	for _, player in eligibleRoster() do
		if not onMap[player.UserId] then
			local roleKind: ("RUNNER" | "HUNTER") = "RUNNER"
			if playerStateServiceRef and playerStateServiceRef.getRole(player) == "Hunter" then
				roleKind = "HUNTER"
			end
			RoundService.sendToMap(player, roleKind)
		end
	end
	destroyHunterPlatform()
end

-- Teletransporta a todos los jugadores activos al destino ("LOBBY" o "MAP")
function RoundService.teleportAllTo(locationType: "LOBBY" | "MAP")
	if locationType == "LOBBY" then
		table.clear(onMap)
		destroyHunterPlatform()
		local spawns = getSpawns("LOBBY")
		for _, player in getActors() do
			-- solo quien jugó la ronda (en el mapa, en la sala del cazador o con rol): los del lobby se quedan donde están
			local rol = if playerStateServiceRef then playerStateServiceRef.getRole(player) else nil
			if onMap[player.UserId] or rol == "Hunter" or rol == "Runner" then
				teleportPlayer(player, spawns)
			end
		end
	else
		RoundService.teleportPendingToMap()
	end
end

-- Emite actualización de estado y tiempo a todos los clientes
local function broadcastStatus()
 local count = #Players:GetPlayers()
 ReplicatedStorage:SetAttribute("RoundState", currentState)
 ReplicatedStorage:SetAttribute("RoundTimeLeft", currentTimer)
 ReplicatedStorage:SetAttribute("RoundEndsAt", currentDeadline)
 ReplicatedStorage:SetAttribute("RoundMessage", statusMessage)
 ReplicatedStorage:SetAttribute("RoundPlayerCount", count)
 ReplicatedStorage:SetAttribute("RoundMinPlayers", RoundConfig.MIN_PLAYERS)
 ReplicatedStorage:SetAttribute("RoundParticipantCount", currentState == RoundStates.ROUND_ACTIVE and #eligibleRoster() or #getActors())
 ReplicatedStorage:SetAttribute("RoundId", roundId)
 local lobby = Workspace:FindFirstChild("ZeroLobby")
 local display = lobby and lobby:FindFirstChild("TimerDisplay")
 local screen = display and display:FindFirstChild("Screen")
 local sign = screen and screen:FindFirstChild("TimerGui")
 if sign then
  local header, timer, status = sign:FindFirstChild("Header"), sign:FindFirstChild("TimerText"), sign:FindFirstChild("Status")
  local waiting = currentState == RoundStates.WAITING_FOR_PLAYERS
  if header then header.Text = ({
   WAITING_FOR_PLAYERS="ESPERANDO JUGADORES", INTERMISSION="SIGUIENTE RONDA EN",
   ROUND_ACTIVE="TIEMPO DE RONDA", ROUND_END="PRÓXIMA RONDA EN",
  })[currentState] or "ZERO" end
  if timer then timer.Text = waiting and string.format("%d / %d", count, RoundConfig.MIN_PLAYERS)
   or string.format("%02d:%02d", math.floor(currentTimer / 60), currentTimer % 60) end
  if status then status.Text = statusMessage end
 end
 roundStatusEvent:FireAllClients({
  state=currentState, timer=currentTimer, endsAt=currentDeadline,
  message=statusMessage, playerCount=count, minPlayers=RoundConfig.MIN_PLAYERS,
  map=if mapServiceRef then mapServiceRef.getSelectedMapId() else "Map3_IslaTiki",
 })
end

-- Cambia el estado actual y reinicia el flag de salto
function RoundService.setState(newState: string, customMessage: string?)
	assert(RoundStates[newState], "Estado de ronda inválido")
	wasForcedByDebug = newState == RoundStates.INTERMISSION
	stateVersion += 1
	currentState = newState
	statusMessage = customMessage or ""
	stateSkipRequested = true
	currentTimer = ({INTERMISSION=RoundConfig.INTERMISSION_DURATION, ROUND_ACTIVE=RoundConfig.ROUND_DURATION, ROUND_END=RoundConfig.ROUND_END_DURATION})[newState] or 0
	currentDeadline = currentTimer > 0 and Workspace:GetServerTimeNow() + currentTimer or 0

	if newState == RoundStates.INTERMISSION then
		resultResolved = false
	elseif newState == RoundStates.ROUND_END and not resultResolved then
		ReplicatedStorage:SetAttribute("RoundWinner", nil)
	end
	-- ROUND_END no devuelve al lobby al momento: lo hace el bucle tras la celebración (CELEBRACION)
	if newState == RoundStates.ROUND_END and hunterClassServiceRef then
		hunterClassServiceRef.cancelSelection()
	end
	if newState == RoundStates.WAITING_FOR_PLAYERS then
		RoundService.teleportAllTo("LOBBY")
		if playerStateServiceRef then
			playerStateServiceRef.resetAllToLobby()
		end
		if hunterClassServiceRef then
			hunterClassServiceRef.cancelSelection()
		end
	end

	broadcastStatus()
	print(string.format("[RoundService] Estado cambiado a: %s", newState))
end

function RoundService.getState(): string
	return currentState
end

function RoundService.getTimer(): number
	return currentTimer
end


-- Permite ajustar el tiempo restante del reloj actual en tiempo real (por comando admin/debug)
function RoundService.setRemainingTime(seconds: number)
	local s = math.max(0, math.floor(seconds))
	currentDeadline = Workspace:GetServerTimeNow() + s
	currentTimer = s
	broadcastStatus()
	print(string.format("[RoundService] Temporizador ajustado por comando a %d segundos.", s))
end
-- Comprueba la condición de victoria para finalizar la ronda anticipadamente si todos los Runners están congelados
-- Result is committed once, before resetting roles or announcing ROUND_END.
function RoundService.resolveResult(winningRole, message)
	if currentState ~= RoundStates.ROUND_ACTIVE or resultResolved then return false end
	resultResolved = true
	for _, actor in eligibleRoster() do
		if playerStateServiceRef.isHuman(actor) then
			if playerStateServiceRef.getRole(actor) == winningRole then
				DataService.incrementStat(actor, "wins", 1)
				if winningRole == PlayerRoles.HUNTER then DataService.incrementStat(actor, "hunter_wins", 1) end
			else
				local streak = DataService.getStat(actor, "current_win_streak") or 0
				if streak > 0 then DataService.incrementStat(actor, "current_win_streak", -streak) end
			end
		end
	end
	-- personaje que enfoca la cámara de la celebración (ZeroVictoriaClient): el cazador o un corredor que siga libre
	local foco = nil
	local libres = {}
	for _, actor in eligibleRoster() do
		local char = actor.Character
		if char and char.Parent and playerStateServiceRef.getRole(actor) == winningRole then
			if winningRole == PlayerRoles.HUNTER then foco = char; break end
			if char:GetAttribute("Status") ~= "Frozen" then table.insert(libres, char) end
		end
	end
	if not foco and #libres > 0 then foco = libres[math.random(1, #libres)] end
	local focoV = ReplicatedStorage:FindFirstChild("ZeroRondaFoco") or Instance.new("ObjectValue")
	focoV.Name = "ZeroRondaFoco"; (focoV :: ObjectValue).Value = foco; focoV.Parent = ReplicatedStorage
	ReplicatedStorage:SetAttribute("RoundWinner", winningRole)
	RoundService.setState(RoundStates.ROUND_END, message)
	return true
end

function RoundService.checkWinCondition(): boolean
	if currentState ~= RoundStates.ROUND_ACTIVE then
		return false
	end

	if not playerStateServiceRef then
		return false
	end

	local activeRunners = playerStateServiceRef.getActiveRunnersCount()

	if activeRunners == 0 then
		print("[ROUND] ¡Victoria del Hunter! Todos los Runners congelados.")
		RoundService.resolveResult(PlayerRoles.HUNTER, "¡Victoria del Hunter! Todos los Runners congelados.")
		return true
	end

	return false
end

-- Espera pasiva de temporizador que permite interrupción inmediata por comandos de debug o fin anticipado
local function runTimer(duration: number, updateMessage: (remaining: number) -> string, allowSolo: boolean?)
 local expectedState, version = currentState, stateVersion
 currentDeadline = Workspace:GetServerTimeNow() + math.max(0, duration)
 stateSkipRequested = false
 while currentState == expectedState and stateVersion == version and not stateSkipRequested do
  if expectedState == RoundStates.INTERMISSION and not allowSolo and not canStart() then
   RoundService.setState(RoundStates.WAITING_FOR_PLAYERS, "Faltan jugadores para iniciar.")
   return
  end
  currentTimer = math.max(0, math.ceil(currentDeadline - Workspace:GetServerTimeNow()))
  statusMessage = updateMessage(currentTimer)
  broadcastStatus()
  if currentTimer == 0 then break end
  task.wait(math.min(1, math.max(.05, currentDeadline - Workspace:GetServerTimeNow())))
 end
end

-- Ciclo principal del juego (State Machine)
local function startLoop()
	if isLoopRunning then return end
	isLoopRunning = true

	task.spawn(function()
		while true do
			local playerCount = #Players:GetPlayers()

			if currentState == RoundStates.WAITING_FOR_PLAYERS then
				currentTimer = 0
				currentDeadline = 0
				if canStart() then
					currentState = RoundStates.INTERMISSION
				else
					statusMessage = string.format("Esperando jugadores (%d/%d)...", playerCount, RoundConfig.MIN_PLAYERS)
					broadcastStatus()
					task.wait(1)
				end

			elseif currentState == RoundStates.INTERMISSION then
				local allowSoloIntermission = wasForcedByDebug and RunService:IsStudio()
				if not canStart() and not allowSoloIntermission then
					if hunterClassServiceRef then
						hunterClassServiceRef.cancelSelection()
					end
					RoundService.teleportAllTo("LOBBY")
					if playerStateServiceRef then
						playerStateServiceRef.resetAllToLobby()
					end
					currentState = RoundStates.WAITING_FOR_PLAYERS
				else
					wasForcedByDebug = false
					-- Votación de mapa en el lobby antes de cada ronda (también al abrir un servidor nuevo)
					mapReady = false
					if mapServiceRef and mapServiceRef.getVoteDuration then
						runTimer(mapServiceRef.getVoteDuration(), function(rem)
							return string.format("¡Vota el mapa! %ds", rem)
						end, allowSoloIntermission)
						if currentState ~= RoundStates.INTERMISSION then continue end
					end
					if mapServiceRef then mapServiceRef.finalizeChosenMap() end
					mapReady = true
					roundRoster = activeActors()
					resultResolved = false
					roundId += 1
					ReplicatedStorage:SetAttribute("RoundWinner", nil)
					currentTimer = RoundConfig.INTERMISSION_DURATION
					currentDeadline = Workspace:GetServerTimeNow() + currentTimer
					statusMessage = string.format("Iniciando ronda en: %ds", currentTimer)
					broadcastStatus()
					if hunterClassServiceRef then
						hunterClassServiceRef.beginSelection()
					end

					-- Teletransportar Runners al mapa inmediatamente y al Hunter a la plataforma blanca
					local currentUpcomingHunter = if hunterClassServiceRef then hunterClassServiceRef.getUpcomingHunter() else nil
					for _, player in activeActors() do
						if player == currentUpcomingHunter then
							RoundService.sendToHunterPlatform(player)
						else
							if playerStateServiceRef then
								playerStateServiceRef.setRole(player, PlayerRoles.RUNNER)
							end
							RoundService.sendToMap(player, "RUNNER")
						end
					end

					runTimer(RoundConfig.INTERMISSION_DURATION, function(rem)
						return string.format("Iniciando ronda en: %ds", rem)
					end, allowSoloIntermission)

					if currentState == RoundStates.INTERMISSION then
						currentState = RoundStates.ROUND_ACTIVE
					end
				end

			elseif currentState == RoundStates.ROUND_ACTIVE then
				resultResolved = false   -- también si se llegó sin INTERMISSION (/startround): si no, la ronda se repetía sin fin
				roundRoster = activeActors()
				currentTimer = RoundConfig.ROUND_DURATION
				currentDeadline = Workspace:GetServerTimeNow() + currentTimer
				broadcastStatus()
				if botServiceRef then
					botServiceRef.fillLobby()
					roundRoster = activeActors()
				end
				if playerStateServiceRef then
					local preselectedHunter = if hunterClassServiceRef then hunterClassServiceRef.consumeUpcomingHunter() else nil
					playerStateServiceRef.assignRoundRoles(preselectedHunter, eligibleRoster())
				end
				if playerStateServiceRef and playerStateServiceRef.hasActiveHunter and not playerStateServiceRef.hasActiveHunter() then
					RoundService.setState(RoundStates.WAITING_FOR_PLAYERS, "Faltan jugadores para iniciar.")
					continue
				end
				RoundService.teleportPendingToMap()

				runTimer(RoundConfig.ROUND_DURATION, function(rem)
					local mins = math.floor(rem / 60)
					local secs = rem % 60
					return string.format("Tiempo restante: %02d:%02d", mins, secs)
				end)

				-- Si el temporizador expira de forma natural y aún no se forzó otro estado
				if currentState == RoundStates.ROUND_ACTIVE then
					local activeRunners = if playerStateServiceRef then playerStateServiceRef.getActiveRunnersCount() else 0
					if activeRunners > 0 then
						print("[ROUND] ¡Victoria de los Runners! Se acabó el tiempo.")
						statusMessage = "¡Victoria de los Runners! Sobrevivieron al tiempo."
					else
						print("[ROUND] ¡Victoria del Hunter! Todos los Runners congelados.")
						statusMessage = "¡Victoria del Hunter! Todos los Runners congelados."
					end
					RoundService.resolveResult(activeRunners > 0 and PlayerRoles.RUNNER or PlayerRoles.HUNTER, statusMessage)
				end

			elseif currentState == RoundStates.ROUND_END then
				if statusMessage == "" then
					statusMessage = "¡Ronda finalizada! Regresando al Lobby..."
				end
				currentTimer = RoundConfig.ROUND_END_DURATION
				currentDeadline = Workspace:GetServerTimeNow() + currentTimer
				broadcastStatus()
				local endingVersion = stateVersion

				-- Celebración (ZeroVictoriaClient: banner, cámara y fanfarria) y después de vuelta al lobby
				task.wait(CELEBRACION)
				if currentState ~= RoundStates.ROUND_END or stateVersion ~= endingVersion then continue end
				RoundService.teleportAllTo("LOBBY")
				if playerStateServiceRef then
					playerStateServiceRef.resetAllToLobby()
				end

				if mapServiceRef then mapServiceRef.resetVotes() end
				runTimer(math.max(1, RoundConfig.ROUND_END_DURATION - CELEBRACION), function(rem)
					return string.format("Próxima partida en: %ds", rem)
				end)

				if currentState == RoundStates.ROUND_END then
					currentState = RoundStates.WAITING_FOR_PLAYERS
				end
			end
		end
	end)
end

function RoundService.onActorRemoved(actor)
	onMap[actor.UserId] = nil
	task.defer(function()
		if #Players:GetPlayers() == 0 and currentState ~= RoundStates.WAITING_FOR_PLAYERS then
			RoundService.setState(RoundStates.WAITING_FOR_PLAYERS, "Esperando jugadores...")
		elseif currentState == RoundStates.ROUND_ACTIVE then
			if not playerStateServiceRef.hasActiveHunter() then
				RoundService.setState(RoundStates.ROUND_END, "El Hunter abandonó la partida.")
			else RoundService.checkWinCondition() end
		end
	end)
end

function RoundService.init(playerStateService: any?, hunterClassService: any?, botService: any?, mapService: any?)
	playerStateServiceRef = playerStateService
	hunterClassServiceRef = hunterClassService
	botServiceRef = botService
	mapServiceRef = mapService

	-- Conectar nuevos jugadores para que reciban el estado inmediatamente al entrar
	-- activar AFK durante la espera (ya enviado al mapa) lo devuelve al lobby; en plena ronda, sale en la siguiente
	local function watchAFK(player)
		player:GetAttributeChangedSignal("AFK"):Connect(function()
			if not isAFK(player) or currentState ~= RoundStates.INTERMISSION then return end
			local idx = table.find(roundRoster, player)
			if idx then table.remove(roundRoster, idx) end
			onMap[player.UserId] = nil
			if hunterClassServiceRef and hunterClassServiceRef.getUpcomingHunter() == player and hunterClassServiceRef.reelegir then
				hunterClassServiceRef.reelegir(player)   -- el cazador elegido pasó a AFK en su sala: otro (o nadie)
			end
			if playerStateServiceRef then playerStateServiceRef.setRole(player, PlayerRoles.LOBBY) end
			teleportPlayer(player, getSpawns("LOBBY"))
		end)
	end
	for _, p in Players:GetPlayers() do watchAFK(p) end
	Players.PlayerAdded:Connect(watchAFK)

	Players.PlayerAdded:Connect(function(player)
		roundStatusEvent:FireClient(player, {
			state = currentState,
			timer = currentTimer,
			message = statusMessage,
		})

		-- Teletransportar según el estado actual cuando cargue su personaje
		player.CharacterAdded:Connect(function()
			onMap[player.UserId] = nil
			task.wait(0.2)
			if currentState == RoundStates.WAITING_FOR_PLAYERS or currentState == RoundStates.ROUND_END then
				local spawns = getSpawns("LOBBY")
				teleportPlayer(player, spawns)
			elseif currentState == RoundStates.INTERMISSION then
				local upcomingHunter = if hunterClassServiceRef then hunterClassServiceRef.getUpcomingHunter() else nil
				if isAFK(player) then
					teleportPlayer(player, getSpawns("LOBBY"))
				elseif player == upcomingHunter then
					RoundService.sendToHunterPlatform(player)
				else
					if playerStateServiceRef then playerStateServiceRef.setRole(player, PlayerRoles.RUNNER) end
					RoundService.sendToMap(player, "RUNNER")
				end
			elseif currentState == RoundStates.ROUND_ACTIVE then
				local role = if playerStateServiceRef then playerStateServiceRef.getRole(player) else "Lobby"
				if role == "Hunter" then
					RoundService.sendToMap(player, "HUNTER")
				elseif role == "Runner" then
					RoundService.sendToMap(player, "RUNNER")
				else
					local spawns = getSpawns("LOBBY")
					teleportPlayer(player, spawns)
				end
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		RoundService.onActorRemoved(player)
	end)

	startLoop()
	print("[RoundService] Inicializado correctamente.")
end

return RoundService

