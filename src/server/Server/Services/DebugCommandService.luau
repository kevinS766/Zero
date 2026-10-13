--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoundStates = require(Shared:WaitForChild("Constants"):WaitForChild("RoundStates"))
local RoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("RoundConfig"))

local DebugCommandService = {}

-- RoundService, PlayerStateService y HunterClassService inyectados en init()
local roundServiceRef: any = nil
local playerStateServiceRef: any = nil
local hunterClassServiceRef: any = nil

-- Verifica si el jugador tiene permisos de debug
local function isAuthorized(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end

	for _, adminId in RoundConfig.ADMIN_USER_IDS do
		if player.UserId == adminId then
			return true
		end
	end

	return false
end

-- Ejecuta la lógica del comando
local function executeCommand(player: Player, message: string): boolean
	if not isAuthorized(player) then
		return false
	end

	local parts = string.split(string.gsub(message, "^%s+", ""), " ")
	local command = string.lower(parts[1] or "")
	local arg1 = parts[2]
	local arg2 = parts[3]

	if command == "/startround" then
		print(string.format("[DebugCommand] %s ejecutó /startround", player.Name))
		roundServiceRef.setState(RoundStates.ROUND_ACTIVE, "Ronda forzada por admin")
		return true

	elseif command == "/endround" then
		print(string.format("[DebugCommand] %s ejecutó /endround", player.Name))
		roundServiceRef.setState(RoundStates.ROUND_END, "Fin de ronda forzado por admin")
		return true

	elseif command == "/settimer" or command == "/settime" or command == "/time" then
		if not arg1 then
			warn("[DebugCommand] Uso: /settimer [segundos]")
			return true
		end

		local secs = tonumber(arg1)
		if secs and roundServiceRef and roundServiceRef.setRemainingTime then
			roundServiceRef.setRemainingTime(secs)
			print(string.format("[DebugCommand] %s ajustó el tiempo del reloj a %d segundos", player.Name, secs))
		else
			warn(string.format("[DebugCommand] Cantidad de segundos inválida: '%s'", tostring(arg1)))
		end
		return true

	elseif command == "/setstate" then
		if not arg1 then
			warn("[DebugCommand] /setstate requiere un estado válido. (Ej: /setstate ROUND_ACTIVE)")
			return true
		end

		local upperArg = string.upper(arg1)
		if RoundStates[upperArg] then
			print(string.format("[DebugCommand] %s cambió el estado a %s", player.Name, upperArg))
			roundServiceRef.setState(RoundStates[upperArg], "Estado forzado: " .. upperArg)
		else
			warn(string.format("[DebugCommand] Estado '%s' no reconocido.", upperArg))
		end
		return true

	elseif command == "/setrole" then
		if not arg1 or not arg2 then
			warn("[DebugCommand] Uso: /setrole [PlayerName] [hunter/runner/lobby]")
			return true
		end

		local targetPlayer: Player? = nil
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name) == string.lower(arg1) or string.lower(p.DisplayName) == string.lower(arg1) then
				targetPlayer = p
				break
			end
		end

		if not targetPlayer then
			warn(string.format("[DebugCommand] Jugador '%s' no encontrado.", arg1))
			return true
		end

		local formattedRole = string.upper(string.sub(arg2, 1, 1)) .. string.lower(string.sub(arg2, 2))
		if formattedRole == "Hunter" or formattedRole == "Runner" or formattedRole == "Lobby" then
			if playerStateServiceRef then
				playerStateServiceRef.setRole(targetPlayer, formattedRole)
				print(string.format("[DebugCommand] %s cambió el rol de %s a %s", player.Name, targetPlayer.Name, formattedRole))
			end
		else
			warn(string.format("[DebugCommand] Rol '%s' no válido. Usa hunter, runner o lobby.", arg2))
		end
		return true

	elseif command == "/freeze" then   -- /freeze [jugador]: congela (por defecto a ti)
		local objetivo = player
		for _, p in Players:GetPlayers() do
			if arg1 and (string.lower(p.Name) == string.lower(arg1) or string.lower(p.DisplayName) == string.lower(arg1)) then objetivo = p end
		end
		if playerStateServiceRef then playerStateServiceRef.freezeRunner(objetivo, nil) end
		return true

	elseif command == "/powerup" then  -- /powerup Velocidad|Salto|Escudo|Dash: te da ese power-up
		local ok = pcall(function()
			require(game:GetService("ServerScriptService"):WaitForChild("ZeroJugadas")).darPowerUp(player.Character, arg1 or "Velocidad")
		end)
		if not ok then warn("[DebugCommand] /powerup falló") end
		return true

	elseif command == "/setclass" then
		if not arg1 then
			warn("[DebugCommand] Uso: /setclass [tracker/stalker/trapper]")
			return true
		end

		local formattedClass = string.upper(string.sub(arg1, 1, 1)) .. string.lower(string.sub(arg1, 2))
		if formattedClass == "Tracker" or formattedClass == "Stalker" or formattedClass == "Trapper" then
			if hunterClassServiceRef then
				hunterClassServiceRef.setClass(player, formattedClass)
				print(string.format("[DebugCommand] %s estableció su clase a %s", player.Name, formattedClass))
			end
		else
			warn(string.format("[DebugCommand] Clase '%s' no válida. Usa tracker, stalker o trapper.", arg1))
		end
		return true
	end

	return false
end

-- Configura comandos usando TextChatService (Sistema moderno) y Legacy Chat como fallback
function DebugCommandService.init(roundService: any, playerStateService: any?, hunterClassService: any?)
	roundServiceRef = roundService
	playerStateServiceRef = playerStateService
	hunterClassServiceRef = hunterClassService

	-- pruebas desde Studio (el chat no envía comandos por MCP): ServerStorage.ZeroDebugComando:Fire(player, "/endround")
	if game:GetService("RunService"):IsStudio() then
		local b = Instance.new("BindableEvent"); b.Name = "ZeroDebugComando"; b.Parent = game:GetService("ServerStorage")
		b.Event:Connect(function(player, mensaje) executeCommand(player, mensaje) end)
	end

	-- 1. TextChatService Moderno
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local textCommandsFolder = TextChatService:FindFirstChild("TextChatCommands")
		if not textCommandsFolder then
			textCommandsFolder = Instance.new("Folder")
			textCommandsFolder.Name = "TextChatCommands"
			textCommandsFolder.Parent = TextChatService
		end

		local function registerTextCommand(name: string, primaryAlias: string)
			local cmd = textCommandsFolder:FindFirstChild(name) :: TextChatCommand?
			if not cmd then
				cmd = Instance.new("TextChatCommand")
				cmd.Name = name
				cmd.PrimaryAlias = primaryAlias
				cmd.Parent = textCommandsFolder
			end

			cmd.Triggered:Connect(function(textSource, rawText)
				local player = Players:GetPlayerByUserId(textSource.UserId)
				if player then
					executeCommand(player, rawText)
				end
			end)
		end

		registerTextCommand("DebugStartRound", "/startround")
		registerTextCommand("DebugEndRound", "/endround")
		registerTextCommand("DebugSetState", "/setstate")
		registerTextCommand("DebugSetRole", "/setrole")
		registerTextCommand("DebugSetClass", "/setclass")
		registerTextCommand("DebugSetTimer", "/settimer")
		registerTextCommand("DebugSetTime", "/settime")
		registerTextCommand("DebugTime", "/time")
	end

	-- 2. Legacy Chat fallback (Player.Chatted)
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			executeCommand(player, message)
		end)
	end)

	print("[DebugCommandService] Inicializado correctamente con comandos de temporizador y protección de permisos.")
end

return DebugCommandService
