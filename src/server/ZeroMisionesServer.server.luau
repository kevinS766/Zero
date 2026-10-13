-- ZeroMisionesServer (Script, ServerScriptService): misiones diarias, semanales y logros de ZERO.
--  · Guarda en su propio DataStore (ZeroMisiones_v1); los premios (monedas, giros, cajas) los cobra ZeroWheelServer
--    con ServerStorage.ZeroEconomia, en la misma escritura que sus monedas.
--  · Cuenta el progreso escuchando lo que el juego ya hace: DataService.incrementStat (congelados, rescates,
--    victorias, dashes, partidas, tiempo), los estados de ronda y de los jugadores, el voto de mapa, la habilidad del
--    cazador y ServerStorage.ZeroMisionesProgreso (ruleta, cajas y armas, desde ZeroWheelServer).
--  · Interfaz: ReplicatedStorage.ZeroMisionesRequest (RemoteFunction) y ZeroMisionesEstado (RemoteEvent).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("ZeroMisionesConfig"))
local Rules = require(script.Parent:WaitForChild("ZeroMisionesRules"))
local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MapConfig"))

local studio = RunService:IsStudio()
local store = DataStoreService:GetDataStore("ZeroMisiones_v1")
local rng = Random.new()
local sessions: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local mapIds = {}
for _, id in MapConfig.SlotMapOrder do table.insert(mapIds, id) end

local function ensure(class: string, name: string, parent: Instance)
	local o = parent:FindFirstChild(name) or Instance.new(class)
	o.Name = name; o.Parent = parent
	return o
end
local request = ensure("RemoteFunction", "ZeroMisionesRequest", ReplicatedStorage) :: RemoteFunction
local estado = ensure("RemoteEvent", "ZeroMisionesEstado", ReplicatedStorage) :: RemoteEvent
local progresoExterno = ensure("BindableEvent", "ZeroMisionesProgreso", ServerStorage) :: BindableEvent
local economia = ServerStorage:WaitForChild("ZeroEconomia", 30) :: BindableFunction?

-- ------------------------------------------------------------------ títulos sobre la cabeza
-- El servidor solo publica el atributo ZeroTitulo; cada cliente dibuja la placa animada (ZeroTitulosClient).
local function ponerTitulo(player: Player)
	local m = sessions[player]
	player:SetAttribute("ZeroTitulo", m and m.titulo or nil)
end
-- requisitos de título que viven en atributos del jugador (los pone MonetizationService / ZeroWheelServer)
local function extras(player: Player)
	return { HasPass_VIP = player:GetAttribute("HasPass_VIP") == true, PackInicio = player:GetAttribute("PackInicio") == true }
end

-- ------------------------------------------------------------------ emblemas de Roblox (BadgeService)
-- Bienvenida al entrar; los otros 4, la primera vez que el contador de misiones llega a 1 (también a quien ya lo tenía).
local BadgeService = game:GetService("BadgeService")
local EMBLEMA_BIENVENIDA = 3783831735535406
local EMBLEMAS = { partidas = 3164032220610853, rescates = 3600469172549073, congelados = 899481529720859, victorias = 63837360084899 }
local emblemasDados: { [Player]: { [number]: boolean } } = {}
local function darEmblema(player: Player, id: number)
	local dados = emblemasDados[player] or {}; emblemasDados[player] = dados
	if dados[id] then return end
	dados[id] = true
	task.spawn(function()
		local ok, tiene = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and tiene then return end
		local okDar, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		if not okDar then dados[id] = nil; warn("[ZeroEmblemas] No se pudo dar el emblema " .. id .. ": " .. tostring(err)) end
	end)
end
local function revisarEmblemas(player: Player)
	local m = sessions[player]
	if not m then return end
	darEmblema(player, EMBLEMA_BIENVENIDA)
	for clave, id in EMBLEMAS do if (m.total[clave] or 0) >= 1 then darEmblema(player, id) end end
end

-- ------------------------------------------------------------------ estado al cliente (agrupado)
local pendientes: { [Player]: boolean } = {}
local function empujar(player: Player)
	if pendientes[player] then return end
	pendientes[player] = true
	task.delay(0.4, function()
		pendientes[player] = nil
		local m = sessions[player]
		if m and player.Parent == Players then
			estado:FireClient(player, Rules.vista(m, os.time(), extras(player)))
			local listas = 0
			for _, l in { m.diarias, m.semanales } do for _, s in l do if s.done and not s.claimed then listas += 1 end end end
			player:SetAttribute("MisionesListas", listas)              -- para avisos ("!" del NPC, botón del HUD)
		end
	end)
end

local function sumar(player: any, clave: string, amount: number?, extra: string?)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end   -- solo jugadores reales completan misiones
	local m = sessions[player]
	if not m then return end
	if Rules.normalizar(m, os.time(), rng) then dirty[player] = true end
	Rules.progreso(m, clave, amount or 1, extra, mapIds)
	revisarEmblemas(player)
	dirty[player] = true
	empujar(player)
end
progresoExterno.Event:Connect(sumar)

-- ------------------------------------------------------------------ carga y guardado
local function cargar(player: Player)
	local data
	if studio then
		data = Rules.nuevo()
	else
		local ok, value = pcall(function() return store:GetAsync(tostring(player.UserId)) end)
		if not ok then warn("[ZeroMisiones] No se pudieron cargar las misiones: " .. tostring(value)); return end
		data = type(value) == "table" and value or Rules.nuevo()
	end
	if player.Parent ~= Players then return end
	Rules.normalizar(data, os.time(), rng)
	sessions[player] = data
	dirty[player] = true
	revisarEmblemas(player)
	-- logros de valor que ya tienes desde antes
	task.spawn(function()
		local ok, DataService = pcall(require, ServerScriptService.Server.Services.DataService)
		if ok then
			local racha = DataService.getStat(player, "best_win_streak")
			if type(racha) == "number" then Rules.progreso(data, "valor:mejor_racha", racha) end
		end
		local armas = player:GetAttribute("Armas")
		if type(armas) == "string" then local n = 0; for _ in armas:gmatch("[^,]+") do n += 1 end; Rules.progreso(data, "valor:armas", n) end
		empujar(player)
	end)
	ponerTitulo(player)
	empujar(player)
end

local function guardar(player: Player)
	local m = sessions[player]
	if studio or not m or not dirty[player] then return true end
	local copia = HttpService:JSONDecode(HttpService:JSONEncode(m))
	local ok, err = pcall(function() store:SetAsync(tostring(player.UserId), copia) end)
	if ok then dirty[player] = nil else warn("[ZeroMisiones] Sin guardar: " .. tostring(err)) end
	return ok
end

-- ------------------------------------------------------------------ peticiones de la interfaz
local ocupado: { [Player]: boolean } = {}
request.OnServerInvoke = function(player: Player, accion: string, payload)
	local m = sessions[player]
	if not m then return { success = false, message = "Cargando tus misiones…" } end
	if Rules.normalizar(m, os.time(), rng) then dirty[player] = true end
	if accion == "Estado" then return { success = true, estado = Rules.vista(m, os.time(), extras(player)) } end
	if type(payload) ~= "table" then return { success = false } end
	if ocupado[player] then return { success = false, message = "Espera un momento." } end
	if accion == "Reclamar" then
		local tipo, id = payload.tipo, payload.id
		if type(tipo) ~= "string" or (id ~= nil and type(id) ~= "string") then return { success = false } end
		local copia = HttpService:JSONDecode(HttpService:JSONEncode(m))   -- se aplica sobre una copia hasta cobrar
		local premio, motivo = Rules.reclamar(copia, tipo, id)
		if not premio then return { success = false, message = motivo } end
		ocupado[player] = true
		local cobro = { success = true }
		if economia and ((premio.monedas or 0) > 0 or premio.giros or premio.caja) then
			local ok, res = pcall(function()
				return economia:Invoke(player, { monedas = premio.monedas, giros = premio.giros, caja = premio.caja }, HttpService:GenerateGUID(false))
			end)
			cobro = ok and res or { success = false, message = "No se pudo cobrar el premio." }
		end
		ocupado[player] = nil
		if not cobro.success then return { success = false, message = cobro.message or "No se pudo cobrar el premio." } end
		sessions[player] = copia; m = copia
		dirty[player] = true
		guardar(player)                                             -- lo reclamado se guarda en seguida
		if premio.titulo then m.titulo = premio.titulo; ponerTitulo(player) end
		empujar(player)
		return { success = true, premio = premio, caja = cobro.caja }
	elseif accion == "Cambiar" and type(payload.id) == "string" then
		local ok, motivo = Rules.cambiar(m, payload.id, rng)
		if ok then dirty[player] = true; empujar(player) end
		return { success = ok, message = motivo }
	elseif accion == "ReclamarTitulo" then
		if type(payload.titulo) ~= "string" then return { success = false } end
		local ok, motivo = Rules.reclamarTitulo(m, payload.titulo, extras(player))
		if not ok then return { success = false, message = motivo } end
		m.titulo = payload.titulo                                   -- se lo pone al reclamarlo
		dirty[player] = true; guardar(player)
		ponerTitulo(player); empujar(player)
		return { success = true, message = "¡Título «" .. payload.titulo .. "» desbloqueado!" }
	elseif accion == "UsarTitulo" then
		local t = payload.titulo
		if t ~= nil and (type(t) ~= "string" or not table.find(m.titulos, t)) then return { success = false } end
		m.titulo = t; dirty[player] = true
		ponerTitulo(player); empujar(player)
		return { success = true }
	end
	return { success = false }
end

-- ------------------------------------------------------------------ progreso: estadísticas del juego
-- Se envuelve DataService.incrementStat (todos los servicios lo llaman por la tabla del módulo).
local DataService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("DataService"))
local conocidosCongelados: { [any]: boolean } = {}       -- actores congelados ya vistos (para saber quién acaba de caer)
local ultimoTiempo: { [any]: number } = {}               -- FreezeTimeLeft del último fotograma (rescate al límite)
local botsRonda: { [Player]: { congelados: number, rescates: number } } = {}
local combos: { [Player]: { number } } = {}
local restoSegundos: { [Player]: number } = {}

local function esBot(actor): boolean return not (typeof(actor) == "Instance" and actor:IsA("Player")) end
local function actores()
	local out = {}
	for _, p in Players:GetPlayers() do table.insert(out, p) end
	local bots = workspace:FindFirstChild("ZeroBots")
	if bots then for _, b in bots:GetChildren() do table.insert(out, b) end end
	return out
end
local function estadoDe(actor) return actor:GetAttribute("Status") end
local function topeBot(player: Player, tipo: string): boolean   -- true si ya llegó al tope de bots de esta ronda
	local t = botsRonda[player]; if not t then t = { congelados = 0, rescates = 0 }; botsRonda[player] = t end
	if t[tipo] >= Config.TopeBotsPorRonda then return true end
	t[tipo] += 1
	return false
end

local original = DataService.incrementStat
DataService.incrementStat = function(player, statName, amount, ...)
	local r = original(player, statName, amount, ...)
	task.spawn(function()
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
		local n = typeof(amount) == "number" and amount or 1
		if statName == "hunter_tags" then
			-- la víctima: un congelado que aún no estaba en la lista
			local victima
			for _, a in actores() do if estadoDe(a) == "Frozen" and not conocidosCongelados[a] then victima = a; break end end
			if victima and esBot(Players:GetPlayerFromCharacter(victima) or victima) and topeBot(player, "congelados") then return end
			sumar(player, "congelados", 1)
			local lista = combos[player] or {}; combos[player] = lista
			table.insert(lista, os.clock())
			while #lista > 0 and os.clock() - lista[1] > 20 do table.remove(lista, 1) end
			if #lista >= 3 then sumar(player, "combo", 1); table.clear(lista) end
		elseif statName == "rescues" then
			local rescatado, limite = nil, false
			for a in conocidosCongelados do
				if estadoDe(a) ~= "Frozen" then rescatado = a; limite = (ultimoTiempo[a] or 99) <= 3; break end
			end
			if rescatado and esBot(Players:GetPlayerFromCharacter(rescatado) or rescatado) and topeBot(player, "rescates") then return end
			sumar(player, "rescates", 1)
			if limite then sumar(player, "rescate_limite", 1) end
		elseif statName == "wins" and n > 0 then
			sumar(player, "victorias", n)
			local racha = DataService.getStat(player, "best_win_streak")
			if type(racha) == "number" then sumar(player, "valor:mejor_racha", racha) end
		elseif statName == "hunter_wins" and n > 0 then sumar(player, "victorias_cazador", n)
		elseif statName == "dashes_used" and n > 0 then sumar(player, "dashes", n)
		elseif statName == "matches_played" and n > 0 then sumar(player, "partidas", n)
		elseif statName == "total_playtime_seconds" and n > 0 then
			local s = (restoSegundos[player] or 0) + n
			local minutos = s // 60
			restoSegundos[player] = s % 60
			if minutos > 0 then sumar(player, "minutos", minutos) end
		end
	end)
	return r
end

-- ------------------------------------------------------------------ progreso: rondas
local ronda = { activa = false, part = {}, congelado = {}, vivoDesde = {}, hecho90 = {}, ultimo = {} }
local function inicioRonda()
	ronda.activa = true
	table.clear(ronda.part); table.clear(ronda.congelado); table.clear(ronda.vivoDesde); table.clear(ronda.hecho90); table.clear(ronda.ultimo)
	table.clear(botsRonda); table.clear(combos)
	local mapa = ReplicatedStorage:GetAttribute("CurrentMap")
	for _, p in Players:GetPlayers() do
		local rol = p:GetAttribute("Role")
		if rol == "Runner" or rol == "Hunter" then
			ronda.part[p] = rol
			ronda.vivoDesde[p] = rol == "Runner" and os.clock() or nil
			if mapa then sumar(p, "mapa", 1, mapa) end
		end
		if p:GetAttribute("ZeroVotoMapa") ~= nil and p:GetAttribute("ZeroVotoMapa") == mapa then sumar(p, "voto_ganador", 1) end
	end
end
local function finRonda()
	if not ronda.activa then return end
	ronda.activa = false
	for p, rol in ronda.part do
		if p.Parent == Players and rol == "Runner" and not ronda.congelado[p] and p:GetAttribute("Role") == "Runner" then
			sumar(p, "sobrevive_ronda", 1)
		end
	end
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
	local s = ReplicatedStorage:GetAttribute("RoundState")
	if s == "ROUND_ACTIVE" then inicioRonda() elseif ronda.activa then finRonda() end
end)

RunService.Heartbeat:Connect(function()
	-- congelados conocidos y tiempo restante (para identificar víctimas y rescates al límite)
	local vivos, unicoVivo = 0, nil
	for _, a in actores() do
		local st = estadoDe(a)
		if st == "Frozen" then
			ultimoTiempo[a] = a:GetAttribute("FreezeTimeLeft") or ultimoTiempo[a]
		end
		if ronda.activa and a:GetAttribute("Role") == "Runner" and st ~= "Frozen" then vivos += 1; unicoVivo = a end
	end
	task.defer(function()   -- se actualiza después de que los envoltorios de este fotograma hayan mirado la lista
		for a in conocidosCongelados do if not a.Parent or estadoDe(a) ~= "Frozen" then conocidosCongelados[a] = nil; ultimoTiempo[a] = nil end end
		for _, a in actores() do if estadoDe(a) == "Frozen" then conocidosCongelados[a] = true end end
	end)
	if not ronda.activa then return end
	local now = os.clock()
	for p in ronda.part do
		if p.Parent == Players then
			if estadoDe(p) == "Frozen" or p:GetAttribute("Role") ~= "Runner" then
				ronda.congelado[p] = ronda.congelado[p] or estadoDe(p) == "Frozen"
				ronda.vivoDesde[p] = nil
			else
				ronda.vivoDesde[p] = ronda.vivoDesde[p] or now
				if not ronda.hecho90[p] and now - ronda.vivoDesde[p] >= 90 then ronda.hecho90[p] = true; sumar(p, "sobrevive90", 1) end
			end
		end
	end
	if vivos == 1 and unicoVivo and typeof(unicoVivo) == "Instance" and unicoVivo:IsA("Player") and not ronda.ultimo[unicoVivo] then
		ronda.ultimo[unicoVivo] = true
		sumar(unicoVivo, "ultimo_en_pie", 1)
	end
end)

-- habilidad del cazador (HunterClassService sube ZeroHabilidadSerial al usarla con éxito)
local function vigilar(player: Player)
	player:GetAttributeChangedSignal("ZeroHabilidadSerial"):Connect(function() sumar(player, "habilidad", 1) end)
	for _, a in { "HasPass_VIP", "PackInicio" } do player:GetAttributeChangedSignal(a):Connect(function() empujar(player) end) end
	player:GetAttributeChangedSignal("Armas"):Connect(function()
		local n = 0; for _ in (player:GetAttribute("Armas") or ""):gmatch("[^,]+") do n += 1 end
		sumar(player, "valor:armas", n)
	end)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Head", 10)
		ponerTitulo(player)
	end)
	task.spawn(cargar, player)
end
Players.PlayerAdded:Connect(vigilar)
for _, p in Players:GetPlayers() do vigilar(p) end
Players.PlayerRemoving:Connect(function(p)
	guardar(p)
	sessions[p] = nil; dirty[p] = nil; emblemasDados[p] = nil; botsRonda[p] = nil; combos[p] = nil; restoSegundos[p] = nil; ocupado[p] = nil
end)
task.spawn(function()
	while true do
		task.wait(60)
		for p in dirty do if p.Parent == Players then guardar(p) end end
		for p, m in sessions do                                       -- renovar al cambiar de día con el servidor abierto
			if Rules.normalizar(m, os.time(), rng) then dirty[p] = true; empujar(p) end
		end
	end
end)
game:BindToClose(function()
	for p in sessions do guardar(p) end
end)
