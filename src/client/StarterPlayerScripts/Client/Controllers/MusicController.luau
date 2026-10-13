--!strict
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MusicConfig = require(Shared:WaitForChild("Config"):WaitForChild("MusicConfig"))
local NetworkEvents = require(Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))

local MusicController = {}

-- Contenedor de voces de música
local musicFolder = SoundService:FindFirstChild("ZeroMusicVoices")
if not musicFolder then
	musicFolder = Instance.new("Folder")
	musicFolder.Name = "ZeroMusicVoices"
	musicFolder.Parent = SoundService
end

-- Asegura el SoundGroup ZeroMusic
local musicGroup = SoundService:FindFirstChild("ZeroMusic") :: SoundGroup?
if not musicGroup then
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "ZeroMusic"
	musicGroup.Volume = 0.8
	musicGroup.Parent = SoundService
end

-- Canales A y B para Crossfade
local voiceA = musicFolder:FindFirstChild("MusicVoice_A") :: Sound?
if not voiceA then
	voiceA = Instance.new("Sound")
	voiceA.Name = "MusicVoice_A"
	voiceA.Parent = musicFolder
end
voiceA.SoundGroup = musicGroup
voiceA.Volume = 0
voiceA.Looped = false

local voiceB = musicFolder:FindFirstChild("MusicVoice_B") :: Sound?
if not voiceB then
	voiceB = Instance.new("Sound")
	voiceB.Name = "MusicVoice_B"
	voiceB.Parent = musicFolder
end
voiceB.SoundGroup = musicGroup
voiceB.Volume = 0
voiceB.Looped = false

local activeVoice: Sound = voiceA
local activeTrackTitle: string = ""
local currentTheme: string = ""

-- Estado persistente de listas por tema (para orden preestablecido 1->2->3... entre rondas)
type ThemeState = {
	currentIndex: number,
	tracks: { MusicConfig.TrackInfo },
}
local themeStates: { [string]: ThemeState } = {}

local currentTweenIn: Tween? = nil
local currentTweenOut: Tween? = nil
local currentSerial: number = 0
local isTenseActive: boolean = false

local function normalizeName(str: string): string
	return (str:gsub("%.mp3$", ""):gsub("%.ogg$", ""):gsub("%.wav$", "")):lower()
end

-- Helper: Resuelve el SoundId ya sea desde la config o buscando una instancia importada por nombre
local function resolveSoundId(track: MusicConfig.TrackInfo): string
	if track.Id and track.Id ~= "" and track.Id ~= "rbxassetid://" then
		return track.Id
	end

	local targetNorm = normalizeName(track.Title)

	-- Buscar en ReplicatedStorage
	for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
		if desc:IsA("Sound") and desc.SoundId ~= "" and normalizeName(desc.Name) == targetNorm then
			return desc.SoundId
		end
	end

	-- Buscar en SoundService
	for _, desc in ipairs(SoundService:GetDescendants()) do
		if desc:IsA("Sound") and desc.SoundId ~= "" and normalizeName(desc.Name) == targetNorm then
			return desc.SoundId
		end
	end

	return track.Id
end

local rng = Random.new()

-- Baraja una lista de pistas (Fisher-Yates) solo si Shuffle == true
local function shuffleList(original: { MusicConfig.TrackInfo }): { MusicConfig.TrackInfo }
	local list = table.clone(original)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Obtiene o inicializa el estado persistente de un tema
local function getOrCreateThemeState(themeName: string, themeData: MusicConfig.MusicTheme): ThemeState
	local state = themeStates[themeName]
	if not state then
		state = {
			currentIndex = 0,
			tracks = if themeData.Shuffle then shuffleList(themeData.Tracks) else table.clone(themeData.Tracks),
		}
		themeStates[themeName] = state
	end
	return state
end

-- Obtiene la siguiente pista jugable en orden preestablecido (1 -> 2 -> 3... cíclico)
local function getNextPlayableTrack(themeName: string, themeData: MusicConfig.MusicTheme): (MusicConfig.TrackInfo?, string)
	local state = getOrCreateThemeState(themeName, themeData)
	local total = #state.tracks
	if total == 0 then return nil, "" end

	-- Recorrer en orden estricto buscando una pista disponible
	for _ = 1, total do
		state.currentIndex = (state.currentIndex % total) + 1
		local candidate = state.tracks[state.currentIndex]
		local soundId = resolveSoundId(candidate)
		if soundId and soundId ~= "" and soundId ~= "rbxassetid://" then
			return candidate, soundId
		else
			print(string.format("ℹ️ [MusicController] Pista '%s' (#%d) pendiente de audio en '%s'. Avanzando a la siguiente.", candidate.Title, state.currentIndex, themeName))
		end
	end

	return nil, ""
end

-- Ejecuta la transición de crossfade entre voces
local function crossfadeToTrack(themeName: string, track: MusicConfig.TrackInfo, soundId: string, fadeDuration: number)
	currentSerial += 1
	local thisSerial = currentSerial

	local outgoingVoice = activeVoice
	local incomingVoice = if activeVoice == voiceA then voiceB else voiceA

	-- Preparar voz entrante
	incomingVoice.SoundId = soundId
	incomingVoice.TimePosition = 0
	incomingVoice.Volume = 0
	incomingVoice:Play()

	local targetVolume = math.clamp(track.Volume or MusicConfig.DEFAULT_VOLUME, 0, 1)

	-- Cancelar tweens previos si los hay
	if currentTweenIn then currentTweenIn:Cancel() end
	if currentTweenOut then currentTweenOut:Cancel() end

	local tweenInfoIn = TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenInfoOut = TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	currentTweenIn = TweenService:Create(incomingVoice, tweenInfoIn, { Volume = targetVolume })
	currentTweenOut = TweenService:Create(outgoingVoice, tweenInfoOut, { Volume = 0 })

	currentTweenIn:Play()
	currentTweenOut:Play()

	activeVoice = incomingVoice
	activeTrackTitle = track.Title
	currentTheme = themeName

	print(string.format("🎵 [ORDEN PREESTABLECIDO] Reproduciendo: '%s' | Tema: %s | Vol: %.2f", track.Title, themeName, targetVolume))

	task.spawn(function()
		task.wait(fadeDuration)
		if thisSerial == currentSerial then
			outgoingVoice:Stop()
			outgoingVoice.SoundId = ""
		end
	end)
end

-- Dispara la fase de música tensa: entrada inmediata (Overlap) mientras la canción anterior va bajando a 0
-- De esta forma se elimina la zona muerta perceptual de decibeles (percepción de Leibniz / Weber-Fechner)
function MusicController.triggerTensePhase()
	if isTenseActive then return end
	isTenseActive = true

	local tenseTheme = MusicConfig.Themes["TENSE"]
	if not tenseTheme or #tenseTheme.Tracks == 0 then return end

	-- Obtener siguiente pista tensa en orden preestablecido (1, 2, 3...)
	local candidateTrack, candidateSoundId = getNextPlayableTrack("TENSE", tenseTheme)
	if not candidateTrack or candidateSoundId == "" then
		local fallbackId = "rbxassetid://102003917818708" -- 10_Pixel Panic
		candidateTrack = { Id = fallbackId, Title = "10_Pixel Panic", Volume = 0.50 }
		candidateSoundId = fallbackId
	end

	currentSerial += 1
	local thisSerial = currentSerial

	local outgoingVoice = activeVoice
	local incomingVoice = if activeVoice == voiceA then voiceB else voiceA
	local fadeOutDuration = MusicConfig.TENSE_FADE_OUT_DURATION or 1.0
	local targetVolume = math.clamp(candidateTrack.Volume or MusicConfig.DEFAULT_VOLUME, 0, 1)

	-- Cancelar tweens activos previos
	if currentTweenIn then currentTweenIn:Cancel() end
	if currentTweenOut then currentTweenOut:Cancel() end

	-- 1. Iniciar de inmediato la canción tensa (sin esperar a que la anterior muera por completo)
	incomingVoice.SoundId = candidateSoundId
	incomingVoice.TimePosition = 0
	incomingVoice.Volume = targetVolume
	incomingVoice:Play()

	-- 2. Al mismo tiempo, desvanecer suavemente la anterior hacia cero en 1.0s
	if outgoingVoice.IsPlaying and outgoingVoice.Volume > 0.05 then
		local tweenInfoOut = TweenInfo.new(fadeOutDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		currentTweenOut = TweenService:Create(outgoingVoice, tweenInfoOut, { Volume = 0 })
		currentTweenOut:Play()

		task.spawn(function()
			task.wait(fadeOutDuration)
			if thisSerial == currentSerial then
				outgoingVoice:Stop()
				outgoingVoice.SoundId = ""
				outgoingVoice.Volume = 0
			end
		end)
	else
		outgoingVoice:Stop()
		outgoingVoice.SoundId = ""
		outgoingVoice.Volume = 0
	end

	activeVoice = incomingVoice
	activeTrackTitle = candidateTrack.Title
	currentTheme = "TENSE"

	print(string.format("⚡ [TENSE OVERLAP] ¡Canción tensa iniciada de inmediato mientras la anterior se desvanece! Título: '%s' | ID: %s | Vol: %.2f", candidateTrack.Title, candidateSoundId, targetVolume))
end

-- Cambia de tema (Lobby o Mapa) con crossfade suave respetando el orden preestablecido continuo
function MusicController.transitionTo(themeName: string, force: boolean?)
	local themeData = MusicConfig.Themes[themeName]
	if not themeData or #themeData.Tracks == 0 then
		if themeName ~= "LOBBY" and MusicConfig.Themes["Map3_IslaTiki"] then
			themeData = MusicConfig.Themes["Map3_IslaTiki"]
			themeName = "Map3_IslaTiki"
		else
			themeData = MusicConfig.Themes["LOBBY"]
			themeName = "LOBBY"
		end
	end

	-- Si ya estamos en ese tema y la canción sigue sonando, ignorar cambio a menos que se fuerce
	if not force and currentTheme == themeName and activeVoice.IsPlaying then
		return
	end

	-- Obtener la siguiente pista en orden preestablecido rotativo para este tema
	local candidateTrack, candidateSoundId = getNextPlayableTrack(themeName, themeData)

	-- Fallback a Isla Tiki si no hay pistas disponibles en el mapa
	if not candidateTrack or candidateSoundId == "" then
		if themeName ~= "LOBBY" and MusicConfig.Themes["Map3_IslaTiki"] then
			themeData = MusicConfig.Themes["Map3_IslaTiki"]
			themeName = "Map3_IslaTiki"
			candidateTrack, candidateSoundId = getNextPlayableTrack(themeName, themeData)
		end
	end

	if not candidateTrack or candidateSoundId == "" then
		print(string.format("⚠️ [MusicController] No hay canciones con audio disponible para '%s'.", themeName))
		return
	end

	local fade = themeData.FadeDuration or MusicConfig.DEFAULT_FADE_DURATION
	crossfadeToTrack(themeName, candidateTrack, candidateSoundId, fade)
end

-- Salta a la siguiente pista disponible del tema actual en orden
function MusicController.skipTrack()
	local themeData = MusicConfig.Themes[currentTheme]
	if not themeData then return end
	local track, soundId = getNextPlayableTrack(currentTheme, themeData)
	if track and soundId ~= "" then
		crossfadeToTrack(currentTheme, track, soundId, 1.0)
	end
end

-- Devuelve la pista actual que se está reproduciendo
function MusicController.getCurrentTrack(): { Title: string, SoundId: string, Theme: string, Volume: number }?
	if not activeVoice or not activeVoice.IsPlaying then return nil end
	return {
		Title = activeTrackTitle,
		SoundId = activeVoice.SoundId,
		Theme = currentTheme,
		Volume = activeVoice.Volume,
	}
end

-- Maneja el fin natural de una canción para pasar en orden a la siguiente
local function onSongEnded(voice: Sound)
	if voice ~= activeVoice then return end
	local themeData = MusicConfig.Themes[currentTheme]
	if not themeData then return end

	local track, soundId = getNextPlayableTrack(currentTheme, themeData)
	if track and soundId ~= "" then
		crossfadeToTrack(currentTheme, track, soundId, 1.5)
	end
end

voiceA.Ended:Connect(function() onSongEnded(voiceA) end)
voiceB.Ended:Connect(function() onSongEnded(voiceB) end)

function MusicController.init()
	-- Música del mapa solo para quien juega la ronda (o va a jugarla: mapa elegido en el intermedio y sin AFK);
	-- el resto (AFK, espectadores, recién llegados) sigue con la del lobby.
	local player = game:GetService("Players").LocalPlayer
	local mapaElegido = false

	local function refrescar()
		local state = ReplicatedStorage:GetAttribute("RoundState")
		local mapName = ReplicatedStorage:GetAttribute("CurrentMap")
		local role = player:GetAttribute("Role")
		local juega = state == "ROUND_ACTIVE" and (role == "Runner" or role == "Hunter")
			or state == "INTERMISSION" and mapaElegido and not player:GetAttribute("AFK")

		if state ~= "ROUND_ACTIVE" then
			isTenseActive = false
		end

		-- Si la fase tensa ya está activa en plena ronda activa, mantenerla hasta el fin de ronda
		if isTenseActive and state == "ROUND_ACTIVE" and juega then
			return
		end

		if juega and mapName and mapName ~= "" then
			MusicController.transitionTo(tostring(mapName))
		else
			MusicController.transitionTo("LOBBY")
		end
	end

	local roundStatusEvent = NetworkEvents.getRemoteEvent("RoundStatusUpdate")
	roundStatusEvent.OnClientEvent:Connect(function(statusData)
		if statusData then
			local state = statusData.state
			local timer = statusData.timer or 0
			local role = player:GetAttribute("Role")
			local juega = state == "ROUND_ACTIVE" and (role == "Runner" or role == "Hunter")

			if state ~= "ROUND_ACTIVE" then
				isTenseActive = false
			elseif juega and state == "ROUND_ACTIVE" then
				local threshold = MusicConfig.TENSE_THRESHOLD or 45
				if timer <= threshold and not isTenseActive then
					MusicController.triggerTensePhase()
				elseif timer > threshold and isTenseActive then
					-- Si el tiempo del reloj fue restablecido por encima del umbral (p. ej. comando admin /settimer)
					isTenseActive = false
					local mapName = ReplicatedStorage:GetAttribute("CurrentMap")
					if mapName and mapName ~= "" then
						MusicController.transitionTo(tostring(mapName), true)
					end
				end
			end
		end

		task.defer(refrescar)
	end)

	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
		mapaElegido = false
		local state = ReplicatedStorage:GetAttribute("RoundState")
		if state ~= "ROUND_ACTIVE" then
			isTenseActive = false
		end
		refrescar()
	end)

	ReplicatedStorage:GetAttributeChangedSignal("CurrentMap"):Connect(function()
		if ReplicatedStorage:GetAttribute("RoundState") == "INTERMISSION" then mapaElegido = true end
		refrescar()
	end)

	player:GetAttributeChangedSignal("Role"):Connect(refrescar)
	player:GetAttributeChangedSignal("AFK"):Connect(refrescar)

	-- Sincronizar y monitorear el SoundGroup ZeroMusic (controlado por el slider de Settings en ZeroUI)
	local function updateSoundGroupRouting()
		local activeGroup = SoundService:FindFirstChild("ZeroMusic") :: SoundGroup?
		if activeGroup then
			voiceA.SoundGroup = activeGroup
			voiceB.SoundGroup = activeGroup
		end
	end
	updateSoundGroupRouting()

	local activeGroup = SoundService:FindFirstChild("ZeroMusic") :: SoundGroup?
	if activeGroup then
		activeGroup:GetPropertyChangedSignal("Volume"):Connect(function()
			print(string.format("🔊 [UI AUDIO] Ganancia exponencial aplicada a ZeroMusic: %.3f", activeGroup.Volume))
		end)
	end

	-- Iniciar en Lobby por defecto con la primera pista (1_Warm Haven)
	task.spawn(function()
		task.wait(0.5)
		MusicController.transitionTo("LOBBY")
	end)

	print("[MusicController] Inicializado con éxito con Orden Preestablecido Rotativo y Tense Overlap.")
end

return MusicController
