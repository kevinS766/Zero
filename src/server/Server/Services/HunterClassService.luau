--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HunterClasses = require(Shared:WaitForChild("Constants"):WaitForChild("HunterClasses"))
local PlayerRoles = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerRoles"))
local PlayerStatus = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStatus"))
local RoundStates = require(Shared:WaitForChild("Constants"):WaitForChild("RoundStates"))
local HunterClassConfig = require(Shared:WaitForChild("Config"):WaitForChild("HunterClassConfig"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local HunterClassService = {}
local DataService = require(script.Parent.DataService)
-- Remote feedback is only meaningful for real clients; authority accepts registered NPCs separately.
local function feedback(remote, actor, payload)
	if typeof(actor) == "Instance" and actor:IsA("Player") and actor.Parent == Players then
		remote:FireClient(actor, payload)
	end
end

-- Referencias a servicios inyectadas en init()
local roundServiceRef: any = nil
local playerStateServiceRef: any = nil

-- RemoteEvents de Hunter Classes
local classSelectionPromptEvent: RemoteEvent = NetworkEvents.getRemoteEvent("ClassSelectionPrompt")
local classSelectionRequestEvent: RemoteEvent = NetworkEvents.getRemoteEvent("ClassSelectionRequest")
local classSelectionConfirmedEvent: RemoteEvent = NetworkEvents.getRemoteEvent("ClassSelectionConfirmed")
local abilityRequestEvent: RemoteEvent = NetworkEvents.getRemoteEvent("AbilityRequest")
local hunterAbilityFeedbackEvent: RemoteEvent = NetworkEvents.getRemoteEvent("HunterAbilityFeedback")
local abilityEffectEvent: RemoteEvent = NetworkEvents.getRemoteEvent("AbilityEffect")
local attackHitFeedbackEvent: RemoteEvent = NetworkEvents.getRemoteEvent("AttackHitFeedback")

-- Estado de selección en Intermission
local upcomingHunter: any = nil
local isSelectionOpen: boolean = false
local pendingClassByUserId: { [number]: string } = {}

-- Estado de Cooldown por jugador (UserId -> os.clock())
local lastAbilityTimestamps: { [number]: number } = {}

-- Estado de Stalker
type StalkerSession = {
	generation: number,
	savedTransparencies: { [Instance]: number },
	originalWalkSpeed: number,
}
local activeStalkers: { [number]: StalkerSession } = {}

-- Estado de Trapper
type ActiveTrap = {
	part: BasePart,
	ownerUserId: number,
	spawnTime: number,
}
local activeTraps: { ActiveTrap } = {}
local trapsFolder: Folder? = nil
local trapCheckConnection: RBXScriptConnection? = nil
local lastTrapCheckTime: number = 0

-- Carpeta contenedora en Workspace para trampas en runtime
local function getTrapsFolder(): Folder
	if trapsFolder and trapsFolder.Parent then
		return trapsFolder
	end

	local runtimeFolder = Workspace:FindFirstChild("ZeroRuntime") :: Folder?
	if not runtimeFolder then
		runtimeFolder = Instance.new("Folder")
		runtimeFolder.Name = "ZeroRuntime"
		runtimeFolder.Parent = Workspace
	end

	local folder = runtimeFolder:FindFirstChild("Traps") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Traps"
		folder.Parent = runtimeFolder
	end

	trapsFolder = folder
	return folder
end

-- Limpieza y restauración de efectos Stalker
local function restoreStalker(player: Player)
	local session = activeStalkers[player.UserId]
	if not session then return end
	activeStalkers[player.UserId] = nil

	player:SetAttribute("StalkerStealth", nil)
	if player.Character then
		player.Character:SetAttribute("StalkerStealth", nil)
	end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = HunterClassConfig.BASE_WALK_SPEED
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end

	for instance, originalTransparency in session.savedTransparencies do
		if instance and instance.Parent then
			if instance:IsA("BasePart") then
				instance.Transparency = originalTransparency
			elseif instance:IsA("Decal") then
				instance.Transparency = originalTransparency
			end
		end
	end
end

-- Destruye una trampa específica
local function destroyTrapAtIndex(index: number)
	local trap = activeTraps[index]
	if not trap then return end

	if trap.part and trap.part.Parent then
		trap.part:Destroy()
	end
	table.remove(activeTraps, index)

	if #activeTraps == 0 and trapCheckConnection then
		trapCheckConnection:Disconnect()
		trapCheckConnection = nil
	end
end

-- Limpia todas las trampas de un usuario o del mapa completo
local function clearTraps(ownerUserId: number?)
	local i = #activeTraps
	while i >= 1 do
		local trap = activeTraps[i]
		if not ownerUserId or trap.ownerUserId == ownerUserId then
			destroyTrapAtIndex(i)
		end
		i -= 1
	end
end

-- Loop de comprobación de proximidad de trampas (~10Hz)
local function ensureTrapChecking()
	if trapCheckConnection then return end

	trapCheckConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTrapCheckTime < 0.1 then return end
		lastTrapCheckTime = now

		if #activeTraps == 0 then
			if trapCheckConnection then
				trapCheckConnection:Disconnect()
				trapCheckConnection = nil
			end
			return
		end

		local trapIndex = 1
		while trapIndex <= #activeTraps do
			local trap = activeTraps[trapIndex]
			local trapConfig = HunterClassConfig.Classes[HunterClasses.TRAPPER]
			local lifetime = if trapConfig and trapConfig.Lifetime then trapConfig.Lifetime else 45.0
			local triggerRadius = if trapConfig and trapConfig.TriggerRadius then trapConfig.TriggerRadius else 4.0

			-- Expiración por tiempo
			if now - trap.spawnTime >= lifetime or not trap.part or not trap.part.Parent then
				destroyTrapAtIndex(trapIndex)
				continue
			end

			local trapPos = trap.part.Position
			local triggered = false

			for _, candidate in playerStateServiceRef.getActors() do
				if playerStateServiceRef then
					local role = playerStateServiceRef.getRole(candidate)
					local isFrozen = playerStateServiceRef.isPlayerFrozen(candidate)

					if role == PlayerRoles.RUNNER and not isFrozen then
						local char = candidate.Character
						local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
						if hrp then
							local diff = hrp.Position - trapPos
							local horizontalDist = Vector2.new(diff.X, diff.Z).Magnitude
							local verticalDist = math.abs(diff.Y)

							if horizontalDist <= triggerRadius and verticalDist <= 4.0 then
								-- Trampa activada: Congelar al Runner
								print(string.format("[HunterClassService] ¡%s pisó una trampa congeladora!", candidate.Name))
								playerStateServiceRef.freezeRunner(candidate, Players:GetPlayerByUserId(trap.ownerUserId))

								-- Feedback de impacto al atacante y a la víctima
								local ownerPlayer = Players:GetPlayerByUserId(trap.ownerUserId)
								if ownerPlayer then
									feedback(attackHitFeedbackEvent, ownerPlayer, {
										role = "Attacker",
										targetName = candidate.Name,
									})
								end
								feedback(attackHitFeedbackEvent, candidate, {
									role = "Victim",
									attackerName = if ownerPlayer then ownerPlayer.Name else "Trapper",
								})

								destroyTrapAtIndex(trapIndex)
								triggered = true
								break
							end
						end
					end
				end
			end

			if not triggered then
				trapIndex += 1
			end
		end
	end)
end

-- Limpieza integral de habilidades activas
local function cancelPlayerEffects(player: Player)
	restoreStalker(player)
	clearTraps(player.UserId)
end

-- HABILIDAD: Tracker
local function executeTracker(hunterPlayer: Player): boolean
	local config = HunterClassConfig.Classes[HunterClasses.TRACKER]
	local duration = if config and config.RevealDuration then config.RevealDuration else 4.0

	local targetIds: { number } = {}
	local targetCharacters = {}
	for _, p in playerStateServiceRef.getActors() do
		if playerStateServiceRef then
			local role = playerStateServiceRef.getRole(p)
			local isFrozen = playerStateServiceRef.isPlayerFrozen(p)
			if role == PlayerRoles.RUNNER and not isFrozen then
				if playerStateServiceRef.isHuman(p) then table.insert(targetIds, p.UserId)
				elseif p.Character then table.insert(targetCharacters,p.Character) end
			end
		end
	end

	feedback(abilityEffectEvent, hunterPlayer, {
		kind = "TrackerReveal",
		duration = duration,
		targetUserIds = targetIds,
		targetCharacters = targetCharacters,
	})

	print(string.format("[HunterClassService] Tracker activado por %s (%d Runners detectados)", hunterPlayer.Name, #targetIds + #targetCharacters))
	return true
end

-- HABILIDAD: Stalker
local function executeStalker(hunterPlayer: Player): boolean
	local config = HunterClassConfig.Classes[HunterClasses.STALKER]
	local duration = if config and config.Duration then config.Duration else 5.0
	local stalkerSpeed = if config and config.WalkSpeed then config.WalkSpeed else 24.0

	local character = hunterPlayer.Character
	if not character then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	-- Restaurar sesión previa si existía
	restoreStalker(hunterPlayer)

	hunterPlayer:SetAttribute("StalkerStealth", true)
	character:SetAttribute("StalkerStealth", true)

	local savedTransparencies: { [Instance]: number } = {}

	local function hideInstance(inst: Instance)
		if inst:IsA("BasePart") then
			savedTransparencies[inst] = inst.Transparency
			inst.Transparency = 1
		elseif inst:IsA("Decal") then
			savedTransparencies[inst] = inst.Transparency
			inst.Transparency = 1
		end
	end

	for _, descendant in character:GetDescendants() do
		hideInstance(descendant)
	end

	-- Ocultar nombres / tags provisionales
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = stalkerSpeed

	local generation = (activeStalkers[hunterPlayer.UserId] and activeStalkers[hunterPlayer.UserId].generation or 0) + 1
	activeStalkers[hunterPlayer.UserId] = {
		generation = generation,
		savedTransparencies = savedTransparencies,
		originalWalkSpeed = HunterClassConfig.BASE_WALK_SPEED,
	}

	-- Ocultar herramientas que se equipen durante el sigilo
	local descendantConn: RBXScriptConnection? = nil
	descendantConn = character.DescendantAdded:Connect(function(descendant)
		local currentSession = activeStalkers[hunterPlayer.UserId]
		if currentSession and currentSession.generation == generation then
			hideInstance(descendant)
		elseif descendantConn then
			descendantConn:Disconnect()
		end
	end)

	print(string.format("[HunterClassService] Stalker activado por %s (Invisibilidad + Velocidad %d por %.1fs)", 
		hunterPlayer.Name, stalkerSpeed, duration))

	task.delay(duration, function()
		if descendantConn then
			descendantConn:Disconnect()
		end
		local currentSession = activeStalkers[hunterPlayer.UserId]
		if currentSession and currentSession.generation == generation then
			restoreStalker(hunterPlayer)
			print(string.format("[HunterClassService] Stalker finalizado para %s", hunterPlayer.Name))
		end
	end)

	return true
end

-- HABILIDAD: Trapper
local function executeTrapper(hunterPlayer: Player): boolean
	local character = hunterPlayer.Character
	if not character then return false end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end

	local config = HunterClassConfig.Classes[HunterClasses.TRAPPER]
	local maxDrop = if config and config.PlaceMaxDrop then config.PlaceMaxDrop else 8.0
	local maxTraps = if config and config.MaxTraps then config.MaxTraps else 2

	-- Raycast hacia el suelo para colocar la trampa sólidamente
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character, getTrapsFolder() }

	local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -maxDrop, 0), raycastParams)
	if not rayResult then
		warn("[HunterClassService] Trapper falló: No se detectó suelo cercano.")
		return false
	end

	-- Limitar máximo de trampas activas del jugador
	local userTrapCount = 0
	local oldestTrapIndex: number? = nil
	for idx, trap in activeTraps do
		if trap.ownerUserId == hunterPlayer.UserId then
			userTrapCount += 1
			if not oldestTrapIndex then
				oldestTrapIndex = idx
			end
		end
	end

	if userTrapCount >= maxTraps and oldestTrapIndex then
		destroyTrapAtIndex(oldestTrapIndex)
	end

	-- Crear disco de trampa visual ligero
	local trapPart = Instance.new("Part")
	trapPart.Name = "HunterTrap"
	trapPart.Shape = Enum.PartType.Cylinder
	trapPart.Size = Vector3.new(0.2, 5.0, 5.0) -- En cilindro de Roblox X es altura
	trapPart.CFrame = CFrame.new(rayResult.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trapPart.Anchored = true
	trapPart.CanCollide = false
	trapPart.CanTouch = false
	trapPart.CanQuery = false
	trapPart.Material = Enum.Material.Neon
	trapPart.Color = Color3.fromRGB(0, 230, 255)
	trapPart.Transparency = 0.6
	trapPart:SetAttribute("OwnerUserId", hunterPlayer.UserId)
	trapPart.Parent = getTrapsFolder()

	table.insert(activeTraps, {
		part = trapPart,
		ownerUserId = hunterPlayer.UserId,
		spawnTime = os.clock(),
	})

	ensureTrapChecking()

	print(string.format("[HunterClassService] Trampa colocada por %s en (%.1f, %.1f, %.1f)", 
		hunterPlayer.Name, trapPart.Position.X, trapPart.Position.Y, trapPart.Position.Z))
	return true
end

-- Ejecuta la habilidad correspondiente
local function handleAbilityRequest(player: Player, payload: any?)
	local isStudio = RunService:IsStudio()
	local roundState = if roundServiceRef then roundServiceRef.getState() else "UNKNOWN"
	if not isStudio and roundState ~= RoundStates.ROUND_ACTIVE then
		warn(string.format("[HunterClassService:DEBUG] Habilidad rechazada: La ronda no está activa (Estado: %s)", roundState))
		return
	end

	local currentRole = if playerStateServiceRef then playerStateServiceRef.getRole(player) else player:GetAttribute("Role")
	if currentRole ~= PlayerRoles.HUNTER then
		warn(string.format("[HunterClassService:DEBUG] Habilidad rechazada: El rol de %s no es Hunter (Actual: %s)", player.Name, tostring(currentRole)))
		return
	end

	if playerStateServiceRef and playerStateServiceRef.isPlayerFrozen(player) then
		warn(string.format("[HunterClassService:DEBUG] Habilidad rechazada: %s está congelado", player.Name))
		return
	end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not hrp then return end

	local classId = player:GetAttribute("HunterClass") :: string?
	if not classId or not HunterClassConfig.Classes[classId] then
		classId = HunterClassConfig.DEFAULT_CLASS
		player:SetAttribute("HunterClass", classId)
	end

	-- Cancelación manual anticipada de Stalker si ya está activo
	if classId == HunterClasses.STALKER and activeStalkers[player.UserId] ~= nil then
		restoreStalker(player)
		local elapsed = os.clock() - (lastAbilityTimestamps[player.UserId] or os.clock())
		local remCooldown = math.max(0, HunterClassConfig.Classes[HunterClasses.STALKER].Cooldown - elapsed)
		print(string.format("[HunterClassService] Stalker cancelado manualmente por %s (Cooldown restante: %.1fs)", player.Name, remCooldown))
		feedback(hunterAbilityFeedbackEvent, player, {
			success = true,
			classId = classId,
			canceled = true,
			cooldown = remCooldown,
		})
		return
	end

	local config = HunterClassConfig.Classes[classId]
	local cooldown = config.Cooldown

	local now = os.clock()
	local lastTime = lastAbilityTimestamps[player.UserId] or 0
	if now - lastTime < (cooldown - HunterClassConfig.COOLDOWN_LATENCY_TOLERANCE) then
		return
	end

	local success = false
	if classId == HunterClasses.TRACKER then
		success = executeTracker(player)
	elseif classId == HunterClasses.STALKER then
		success = executeStalker(player)
	elseif classId == HunterClasses.TRAPPER then
		success = executeTrapper(player)
	end

	if success then
		lastAbilityTimestamps[player.UserId] = now
		if typeof(player) == "Instance" then player:SetAttribute("ZeroHabilidadSerial", (player:GetAttribute("ZeroHabilidadSerial") or 0) + 1) end   -- misiones
		feedback(hunterAbilityFeedbackEvent, player, {
			success = true,
			classId = classId,
			cooldown = cooldown,
		})
	else
		feedback(hunterAbilityFeedbackEvent, player, {
			success = false,
			classId = classId,
			cooldown = 0,
			reason = "PLACEMENT_FAILED",
		})
	end
end

-- Inicia la ventana de selección interactiva durante INTERMISSION
function HunterClassService.beginSelection()
	if isSelectionOpen then return end

	local allPlayers = {}
	for _, p in Players:GetPlayers() do if p:GetAttribute("AFK") ~= true then table.insert(allPlayers, p) end end   -- los AFK no son cazador
	if #allPlayers == 0 then return end

	-- Pre-seleccionar al Hunter para esta ronda
	upcomingHunter = allPlayers[math.random(1, #allPlayers)]
	isSelectionOpen = true

	playerStateServiceRef.setRole(upcomingHunter, PlayerRoles.LOBBY)
	upcomingHunter:SetAttribute("ChoosingHunterClass", true)
	pendingClassByUserId[upcomingHunter.UserId] = nil
	local duration = if roundServiceRef then roundServiceRef.getTimer() else 15
	if duration <= 0 then
		duration = 15
	end

	local classesList = {}
	for _, id in HunterClassConfig.ORDER do
		local c = HunterClassConfig.Classes[id]
		table.insert(classesList, {
			id = id,
			name = c.DisplayName,
			description = c.Description,
			cooldown = c.Cooldown,
		})
	end

	if upcomingHunter then
		feedback(classSelectionPromptEvent, upcomingHunter, {
			classes = classesList,
			duration = duration,
			endsAt = ReplicatedStorage:GetAttribute("RoundEndsAt"),
			defaultClass = HunterClassConfig.DEFAULT_CLASS,
		})
		print(string.format("[HunterClassService] Prompt de selección enviado a %s (Duración: %ds)", 
			upcomingHunter.Name, duration))
	end
end

-- Cancela la ventana de selección si se cancela la Intermission
function HunterClassService.cancelSelection()
	if upcomingHunter and isSelectionOpen then
		feedback(classSelectionConfirmedEvent, upcomingHunter, {
			success = false,
			final = true,
			reason = "SELECTION_CANCELLED",
		})
	end

	if upcomingHunter then upcomingHunter:SetAttribute("ChoosingHunterClass", nil) end
	table.clear(pendingClassByUserId)
	isSelectionOpen = false
	upcomingHunter = nil
end

-- Elige otro cazador si el pre-seleccionado se va o pasa a AFK durante la elección de clase (nunca un AFK). Si no hay
-- nadie más, cancela la elección (RoundService no arranca la ronda sin cazador).
function HunterClassService.reelegir(saliente: Player?)
	if not isSelectionOpen then return end
	if upcomingHunter and upcomingHunter.Parent then
		feedback(classSelectionConfirmedEvent, upcomingHunter, { success = false, final = true, reason = "SELECTION_CANCELLED" })
		upcomingHunter:SetAttribute("ChoosingHunterClass", nil)
	end
	upcomingHunter = nil
	local remainingTimer = if roundServiceRef then roundServiceRef.getTimer() else 0
	local candidatos = {}
	for _, p in Players:GetPlayers() do
		if p ~= saliente and p:GetAttribute("AFK") ~= true then table.insert(candidatos, p) end
	end
	if remainingTimer <= 0 or #candidatos == 0 then
		HunterClassService.cancelSelection()
		return
	end
	upcomingHunter = candidatos[math.random(1, #candidatos)]
	upcomingHunter:SetAttribute("ChoosingHunterClass", true)
	pendingClassByUserId[upcomingHunter.UserId] = nil
	if playerStateServiceRef then playerStateServiceRef.setRole(upcomingHunter, PlayerRoles.LOBBY) end
	local classesList = {}
	for _, id in HunterClassConfig.ORDER do
		local c = HunterClassConfig.Classes[id]
		table.insert(classesList, { id = id, name = c.DisplayName, description = c.Description, cooldown = c.Cooldown })
	end
	feedback(classSelectionPromptEvent, upcomingHunter, {
		classes = classesList,
		duration = remainingTimer,
		endsAt = ReplicatedStorage:GetAttribute("RoundEndsAt"),
		defaultClass = HunterClassConfig.DEFAULT_CLASS,
	})
	if roundServiceRef and roundServiceRef.sendToHunterPlatform then roundServiceRef.sendToHunterPlatform(upcomingHunter) end
end

-- Consulta el Hunter pre-seleccionado sin consumirlo
function HunterClassService.getUpcomingHunter(): Player?
	return upcomingHunter
end

-- Extrae el Hunter pre-seleccionado al entrar en ROUND_ACTIVE
function HunterClassService.consumeUpcomingHunter(): Player?
 isSelectionOpen = false
 local selected = upcomingHunter
 upcomingHunter = nil
 if selected and playerStateServiceRef.isHuman(selected) and playerStateServiceRef.isRegistered(selected) then
  local chosen = pendingClassByUserId[selected.UserId] or HunterClassConfig.DEFAULT_CLASS
  pendingClassByUserId[selected.UserId] = chosen
  selected:SetAttribute("ChoosingHunterClass", nil)
  selected:SetAttribute("HunterClass", chosen)
  if selected.Character then selected.Character:SetAttribute("HunterClass", chosen) end
  feedback(classSelectionConfirmedEvent, selected, {success=true, classId=chosen, final=true})
  return selected
 end
 return nil
end

-- Asigna o fuerza una clase directamente a un jugador
function HunterClassService.setClass(player: Player, classId: string)
	if not HunterClassConfig.Classes[classId] then
		warn(string.format("[HunterClassService] Clase inválida: %s", tostring(classId)))
		return
	end

	pendingClassByUserId[player.UserId] = classId
	player:SetAttribute("HunterClass", classId)
	if player.Character then
		player.Character:SetAttribute("HunterClass", classId)
	end

	-- Si el jugador aún no tiene el rol Hunter (ej. está en Lobby durante pruebas), asignárselo
	if playerStateServiceRef and playerStateServiceRef.getRole(player) ~= PlayerRoles.HUNTER then
		playerStateServiceRef.setRole(player, PlayerRoles.HUNTER)
	end

	cancelPlayerEffects(player)
	lastAbilityTimestamps[player.UserId] = 0
	print(string.format("[HunterClassService] Clase de %s establecida a %s (Rol asegurado como Hunter)", player.Name, classId))
end

function HunterClassService.isStalkerActive(player: Player): boolean
	return activeStalkers[player.UserId] ~= nil
end

function HunterClassService.forgetActor(actor)
	cancelPlayerEffects(actor)
	pendingClassByUserId[actor.UserId] = nil
	lastAbilityTimestamps[actor.UserId] = nil
	if upcomingHunter == actor then HunterClassService.cancelSelection() end
end

function HunterClassService.init(roundService: any, playerStateService: any)
	roundServiceRef = roundService
	playerStateServiceRef = playerStateService

	-- Escuchar solicitudes de selección de clase desde el cliente
	classSelectionRequestEvent.OnServerEvent:Connect(function(player, requestedClass)
		if typeof(requestedClass) ~= "string" or not HunterClassConfig.Classes[requestedClass] then
			return
		end

		if not isSelectionOpen or player ~= upcomingHunter
			or roundServiceRef.getState() ~= RoundStates.INTERMISSION
			or Workspace:GetServerTimeNow() >= (ReplicatedStorage:GetAttribute("RoundEndsAt") or 0) then
			return
		end

		pendingClassByUserId[player.UserId] = requestedClass
		DataService.incrementStat(player, "favorite_class", requestedClass)
		feedback(classSelectionConfirmedEvent, player, {
			success = true,
			classId = requestedClass,
			final = false,
		})
		print(string.format("[HunterClassService] %s seleccionó la clase: %s", player.Name, requestedClass))
	end)

	-- Escuchar solicitudes de activación de habilidad (F)
	abilityRequestEvent.OnServerEvent:Connect(function(player, payload)
		handleAbilityRequest(player, payload)
	end)

	-- Supervisar asignación de roles para aplicar clase Hunter y limpiar al salir
	local function trackPlayer(player: Player)
		player:GetAttributeChangedSignal("Role"):Connect(function()
			local currentRole = player:GetAttribute("Role")
			if currentRole == PlayerRoles.HUNTER then
				local assignedClass = pendingClassByUserId[player.UserId] or player:GetAttribute("HunterClass") or HunterClassConfig.DEFAULT_CLASS
				pendingClassByUserId[player.UserId] = nil
				player:SetAttribute("HunterClass", assignedClass)
				if player.Character then
					player.Character:SetAttribute("HunterClass", assignedClass)
				end
				print(string.format("[HunterClassService] %s ingresó como Hunter con clase %s", player.Name, assignedClass))
			else
				cancelPlayerEffects(player)
				player:SetAttribute("HunterClass", nil)
				if player.Character then
					player.Character:SetAttribute("HunterClass", nil)
				end
			end
		end)

		player.CharacterAdded:Connect(function(character)
			cancelPlayerEffects(player)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				cancelPlayerEffects(player)
			end)
		end)
	end

	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
	Players.PlayerAdded:Connect(trackPlayer)

	-- Limpieza cuando un jugador sale del servidor
	Players.PlayerRemoving:Connect(function(player)
		cancelPlayerEffects(player)
		pendingClassByUserId[player.UserId] = nil
		lastAbilityTimestamps[player.UserId] = nil

		if isSelectionOpen and player == upcomingHunter then
			print("[HunterClassService] El Hunter pre-seleccionado salió. Re-seleccionando candidato...")
			HunterClassService.reelegir(player)
		end
	end)

	print("[HunterClassService] Inicializado correctamente (Tracker, Stalker, Trapper).")
end

return HunterClassService
