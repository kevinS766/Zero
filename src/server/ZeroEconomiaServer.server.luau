-- ZeroEconomiaServer (Script, ServerScriptService): paga las monedas de las PARTIDAS y de SUBIR DE NIVEL (antes no se
-- ganaba nada jugando). Valores en ReplicatedStorage.ZeroEconomiaConfig.
--   · Durante la ronda apunta rescates y congelados (envoltorio de DataService.incrementStat, como ZeroMisionesServer)
--     y el rol/estado de cada jugador (para saber al final quién participó y quién sobrevivió).
--   · Al acabar la ronda (RoundState = ROUND_END) paga a cada uno en UNA escritura con el saldo (ZeroEconomia de
--     ZeroWheelServer) y le manda el desglose a ZeroEconomiaClient.
--   · Cuando sube el atributo Level, paga el premio de cada nivel nuevo (y un giro cada 5 niveles).
-- Multiplicadores: bono de novato por nivel, pase 2× MONEDAS y VIP +20 %.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("ZeroEconomiaConfig"))
local DataService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("DataService"))
local economia = ServerStorage:WaitForChild("ZeroEconomia") :: BindableFunction   -- de ZeroWheelServer

local aviso = Instance.new("RemoteEvent")
aviso.Name = "ZeroEconomiaAviso"
aviso.Parent = ReplicatedStorage

local ronda: { [Player]: { rol: string?, estado: string?, rescates: number, congelados: number } } = {}

local function tienePase(p: Player, clave: string): boolean
	return p:GetAttribute("HasPass_" .. clave) == true or p:GetAttribute("SimulatedPass_" .. clave) == true
end

-- monedas finales y texto de multiplicadores
local function aplicar(p: Player, base: number): (number, string)
	local mult, notas = 1, {}
	local nov = Config.multNovato(p:GetAttribute("Level") or 1)
	if nov > 1 then mult *= nov; table.insert(notas, "×" .. nov .. " NOVATO") end
	if tienePase(p, "DOUBLE_COINS") then mult *= Config.PaseMonedas; table.insert(notas, "×2 PASE") end
	if tienePase(p, "VIP") then mult *= 1 + Config.BonoVIP; table.insert(notas, "+20% VIP") end
	return math.floor(base * mult + 0.5), table.concat(notas, " · ")
end

local function pagar(p: Player, monedas: number, giros: number, motivo: string, detalle: { any }?, notas: string?)
	if monedas <= 0 and giros <= 0 then return end
	task.spawn(function()
		local ok, res = pcall(function()
			return economia:Invoke(p, { monedas = monedas, giros = giros }, motivo .. HttpService:GenerateGUID(false))
		end)
		if ok and res and res.success and p.Parent == Players then
			aviso:FireClient(p, { motivo = motivo, monedas = monedas, giros = giros, detalle = detalle, notas = notas })
		elseif not ok or not (res and res.success) then
			warn("[ZeroEconomia] No se pudo pagar " .. motivo .. " a " .. p.Name .. ": " .. tostring(ok and res and res.message or res))
		end
	end)
end

-- ------------------------------------------------------------------ durante la ronda
local original = DataService.incrementStat
DataService.incrementStat = function(player, statName, amount, ...)
	local r = typeof(player) == "Instance" and player:IsA("Player") and ronda[player]
	if r and (amount or 1) > 0 then
		if statName == "rescues" then r.rescates += amount or 1
		elseif statName == "hunter_tags" then r.congelados += amount or 1 end
	end
	return original(player, statName, amount, ...)
end

-- foto del rol y estado de cada jugador mientras dura la ronda (al acabar, RoundService los pasa a Lobby)
task.spawn(function()
	while true do
		task.wait(0.25)
		if ReplicatedStorage:GetAttribute("RoundState") == "ROUND_ACTIVE" then
			for _, p in Players:GetPlayers() do
				local rol = p:GetAttribute("Role")
				if rol == "Runner" or rol == "Hunter" then
					local r = ronda[p] or { rescates = 0, congelados = 0 }
					r.rol, r.estado = rol, p:GetAttribute("Status")
					ronda[p] = r
				end
			end
		end
	end
end)

local function finRonda()
	task.wait(0.3)                                        -- que RoundService publique RoundWinner
	local ganador = ReplicatedStorage:GetAttribute("RoundWinner")
	local C = Config.Ronda
	for p, r in ronda do
		if p.Parent ~= Players or not r.rol then continue end
		local det = { { "Partida", C.participar } }
		local base = C.participar
		if r.rol == "Hunter" then
			local n = math.min(r.congelados, C.topeCongelados)
			if n > 0 then base += n * C.congelar; table.insert(det, { "Congelados ×" .. n, n * C.congelar }) end
			if ganador == "Hunter" then base += C.ganarCazador; table.insert(det, { "Victoria", C.ganarCazador }) end
		else
			local n = math.min(r.rescates, C.topeRescates)
			if n > 0 then base += n * C.rescate; table.insert(det, { "Rescates ×" .. n, n * C.rescate }) end
			if ganador == "Runner" then base += C.ganarCorredor; table.insert(det, { "Victoria", C.ganarCorredor }) end
			if r.estado ~= "Frozen" then base += C.sobrevivir; table.insert(det, { "Sobreviviste", C.sobrevivir }) end
		end
		local total, notas = aplicar(p, base)
		pagar(p, total, 0, "ronda", det, notas)
	end
	table.clear(ronda)
end

ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
	local s = ReplicatedStorage:GetAttribute("RoundState")
	if s == "ROUND_END" then task.spawn(finRonda)
	elseif s == "ROUND_ACTIVE" then table.clear(ronda) end
end)

-- ------------------------------------------------------------------ subir de nivel
local nivelVisto: { [Player]: number } = {}
local function vigilarNivel(p: Player)
	local function tomar()
		if p:GetAttribute("StatsLoaded") and nivelVisto[p] == nil then nivelVisto[p] = p:GetAttribute("Level") or 1 end
	end
	tomar()
	p:GetAttributeChangedSignal("StatsLoaded"):Connect(tomar)
	p:GetAttributeChangedSignal("Level"):Connect(function()
		local antes, ahora = nivelVisto[p], p:GetAttribute("Level") or 1
		if antes == nil then return end                       -- aún cargando: no es una subida
		if ahora <= antes then return end
		nivelVisto[p] = ahora
		local monedas, giros = 0, 0
		for L = antes + 1, ahora do
			local m, g = Config.premioNivel(L)
			monedas += m; giros += g
		end
		local total = aplicar(p, monedas)
		pagar(p, total, giros, "nivel", { { "Nivel " .. ahora, total } })
	end)
end
Players.PlayerAdded:Connect(vigilarNivel)
for _, p in Players:GetPlayers() do vigilarNivel(p) end
Players.PlayerRemoving:Connect(function(p) ronda[p] = nil; nivelVisto[p] = nil end)
