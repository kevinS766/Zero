local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("ZeroWheelConfig"))
local Rules = require(script.Parent:WaitForChild("ZeroWheelRules"))
local ArmasConfig = require(ReplicatedStorage:WaitForChild("ZeroArmasConfig"))
local ArmasRules = require(script.Parent:WaitForChild("ZeroArmasRules"))
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local remote = ReplicatedStorage:WaitForChild("ZeroWheelRequest")
local store = DataStoreService:GetDataStore("ZeroWheel_v1")
local sessions, busy, lastRequest = {}, {}, {}
local joinedAt, timeClaimed = {}, {}
-- Recompensas: deben coincidir con los textos de StarterGui.ZeroUI.Modal.Daily/Time.
-- Economía (zero-economia/simular.py): se reparten poco a poco; lo grande está en las partidas, misiones y logros
local DAILY = {{Coins=300},{Spins=1},{Coins=600},{Spins=2},{Coins=1200},{Coins=2500},{Coins=6000,Spins=5}}
local TIMED = {{After=60,Coins=50},{After=300,Spins=1},{After=900,Coins=200},{After=1800,Coins=400},{After=3600,Spins=2},{After=7200,Coins=1500},{After=16200,Coins=4000,Spins=3}}

-- Día de racha que toca hoy (1..7) o nil si ya se reclamó hoy. Racha rota => vuelve al día 1.
local function dailyNext(data, now)
	local today, last = now // 86400, data.LastDailyDay or -2
	if today == last then return nil end
	return today == last + 1 and (data.DailyStreak or 0) % 7 + 1 or 1
end

local function grant(previous, now, reward, token, daily)
	local data = table.clone(previous or Rules.new(now))
	if data.LastToken == token then return data end
	if daily then
		if dailyNext(data, now) ~= daily then return nil, "Esa recompensa diaria no está disponible." end
		data.DailyStreak, data.LastDailyDay = daily, now // 86400
	end
	data.Coins += reward.Coins or 0
	data.Spins += reward.Spins or 0
	data.LastToken = token
	return data
end

local function rewardStates(player)
	local data = sessions[player]
	if not data then return end
	local now = os.time()
	local nextDay = dailyNext(data, now)
	local streak = nextDay and (nextDay - 1) or data.DailyStreak or 0
	for i = 1, #DAILY do
		player:SetAttribute("Daily"..i, i == nextDay and "Ready" or i <= streak and "Claimed" or nil)
	end
	local played = now - (joinedAt[player] or now)
	for i, reward in ipairs(TIMED) do
		player:SetAttribute("Time"..i, timeClaimed[player] and timeClaimed[player][i] and "Claimed" or played >= reward.After and "Ready" or nil)
	end
end
local random = Random.new()
local studio = RunService:IsStudio()

-- pases de Robux del jugador (los pone MonetizationService) para las armas que vienen con un pase
local function pases(player)
	local t = {}
	for clave in MonetizationConfig.Passes do t[clave] = player:GetAttribute("HasPass_" .. clave) == true end
	for clave in MonetizationConfig.Exclusivos or {} do t[clave] = player:GetAttribute("HasPass_" .. clave) == true end
	return t
end

local function sync(player, data)
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Spins", data.Spins)
	player:SetAttribute("NextFreeSpinAt", data.NextFreeAt)
	player:SetAttribute("WheelReady", true)
	player:SetAttribute("PackInicio", data.PackInicio == true or nil)   -- da el título Pionero (ZeroTitulosConfig)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then stats=Instance.new("Folder"); stats.Name="leaderstats"; stats.Parent=player end
	local coins = stats:FindFirstChild("Coins")
	if not coins then coins=Instance.new("IntValue"); coins.Name="Coins"; coins.Parent=stats end
	coins.Value = data.Coins
	-- armas cosméticas (se guardan en el mismo registro que las monedas)
	local lista = {}
	local p = pases(player)
	for nombre in ArmasRules.armas(data, player.UserId, p) do table.insert(lista, nombre) end
	player:SetAttribute("Armas", table.concat(lista, ","))
	player:SetAttribute("ArmaEquipada", ArmasRules.equipada(data, player.UserId, p))
	-- volumen guardado por jugador (50 % si nunca lo cambió)
	local ajustes = type(data.Ajustes) == "table" and data.Ajustes or {}
	player:SetAttribute("AjusteMusica", type(ajustes.Musica) == "number" and ajustes.Musica or 0.5)
	player:SetAttribute("AjusteSFX", type(ajustes.SFX) == "number" and ajustes.SFX or 0.5)
	player:SetAttribute("AjusteRendimiento", ajustes.Rendimiento == true)
end

local function loadPlayer(player)
	local data
	if studio then
		-- Las pruebas de Studio no escriben en la economía del juego publicado.
		data = Rules.new(os.time())
		data.Coins = script:GetAttribute("StudioCoins") or 0      -- solo para probar cajas en Studio
	else
		local ok, value = pcall(function()
			return store:UpdateAsync(tostring(player.UserId), function(previous)
				return previous or Rules.new(os.time())
			end)
		end)
		if not ok then
			warn("[ZeroWheel] No se pudo cargar el saldo: "..tostring(value))
			player:SetAttribute("WheelLoadFailed", true)
			return
		end
		data = value
	end
	if player.Parent ~= Players then return end
	sessions[player] = data
	sync(player, data)
	rewardStates(player)
end

local function claim(player, kind, index)
	local reward = (kind == "Daily" and DAILY or TIMED)[index]
	if not reward then return {success=false,message="Recompensa inválida."} end
	if not sessions[player] then return {success=false,message="Cargando tus datos…"} end
	if player:GetAttribute(kind..index) ~= "Ready" then return {success=false,message="Esa recompensa aún no está lista."} end
	if busy[player] then return {success=false,message="Espera un momento."} end
	busy[player] = true
	local now, token, result, reason = os.time(), HttpService:GenerateGUID(false)
	local daily = kind == "Daily" and index or nil
	if kind == "Time" then timeClaimed[player] = timeClaimed[player] or {}; timeClaimed[player][index] = true end
	local ok, err = pcall(function()
		if studio then
			result, reason = grant(sessions[player], now, reward, token, daily)
		else
			result = store:UpdateAsync(tostring(player.UserId), function(previous)
				local nextData, rejection = grant(previous, now, reward, token, daily)
				reason = rejection
				return nextData
			end)
		end
	end)
	busy[player] = nil
	if not ok or not result then
		if kind == "Time" then timeClaimed[player][index] = nil end
		if not ok then warn("[ZeroWheel] Recompensa sin confirmar: "..tostring(err)) end
		return {success=false,message=reason or "No se pudo reclamar. Inténtalo de nuevo."}
	end
	if player.Parent == Players then sessions[player]=result; sync(player,result); rewardStates(player) end
	local parts = {}
	if reward.Coins then table.insert(parts, reward.Coins.." monedas") end
	if reward.Spins then table.insert(parts, reward.Spins..(reward.Spins == 1 and " giro" or " giros")) end
	return {success=true,message="¡Recibiste "..table.concat(parts, " + ").."!"}
end

-- Aplica fn(registro) -> (nuevo, extra) de forma atómica (UpdateAsync) y sincroniza. Devuelve (nuevo, extra) o (nil, motivo).
local function armasAction(player, fn)
	if not sessions[player] then return nil, "Cargando tus datos…" end
	if busy[player] then return nil, "Espera un momento." end
	busy[player] = true
	local result, extra
	local ok, err = pcall(function()
		if studio then
			result, extra = fn(sessions[player])
		else
			result = store:UpdateAsync(tostring(player.UserId), function(previous)
				local nextData, e = fn(previous or Rules.new(os.time()))
				extra = e
				return nextData
			end)
		end
	end)
	busy[player] = nil
	if not ok then
		warn("[ZeroArmas] Operación sin confirmar: "..tostring(err))
		return nil, "No se pudo confirmar. Inténtalo de nuevo."
	end
	if not result then return nil, extra end
	if player.Parent == Players then sessions[player]=result; sync(player,result) end
	return result, extra
end

-- avisos para ZeroMisionesServer (ruleta, cajas)
local misionesProgreso = game:GetService("ServerStorage"):FindFirstChild("ZeroMisionesProgreso") or Instance.new("BindableEvent")
misionesProgreso.Name = "ZeroMisionesProgreso"
misionesProgreso.Parent = game:GetService("ServerStorage")

local function openBox(player, cajaId, token, robux)
	local r1, r2 = random:NextNumber(), random:NextNumber()
	local data, res = armasAction(player, function(previous)
		return ArmasRules.abrir(previous, cajaId, r1, r2, token, robux)
	end)
	if not data then return {success=false,message=res or "No se pudo abrir la caja."} end
	misionesProgreso:Fire(player, "cajas", 1)
	return {success=true,caja=res.caja,arma=res.arma,rareza=res.rareza,nueva=res.nueva,devolucion=res.devolucion}
end

local resultadoCaja = ReplicatedStorage:FindFirstChild("ZeroArmasResultado") or Instance.new("RemoteEvent")
resultadoCaja.Name = "ZeroArmasResultado"
resultadoCaja.Parent = ReplicatedStorage

-- Regala un arma (Robux, invitación, ruleta) y enseña la revelación al jugador si es nueva (tras `retraso` s)
local function darArma(player, nombre, token, retraso)
	local t = os.clock()
	while busy[player] and os.clock() - t < 10 do task.wait(0.1) end
	local data, nueva = armasAction(player, function(previous) return ArmasRules.dar(previous, nombre, token) end)
	if not data then return false end
	if nueva == true then
		task.delay(retraso or 0, function()
			if player.Parent == Players then
				resultadoCaja:FireClient(player, {success=true, arma=nombre, rareza=ArmasConfig.PorNombre[nombre].rareza, nueva=true, devolucion=0})
			end
		end)
	end
	return true
end

-- Premios de misiones (ZeroMisionesServer): monedas, giros y cajas gratis en una sola escritura con el saldo
local economia = game:GetService("ServerStorage"):FindFirstChild("ZeroEconomia") or Instance.new("BindableFunction")
economia.Name = "ZeroEconomia"
economia.Parent = game:GetService("ServerStorage")
economia.OnInvoke = function(player, premio, token)
	if type(premio) ~= "table" then return {success=false} end
	local t = os.clock()
	while busy[player] and os.clock() - t < 5 do task.wait(0.1) end
	local r1, r2 = random:NextNumber(), random:NextNumber()
	local data, extra = armasAction(player, function(previous)
		local d = table.clone(previous)
		d.Coins = (d.Coins or 0) + math.max(0, math.floor(premio.monedas or 0))
		d.Spins = (d.Spins or 0) + math.max(0, math.floor(premio.giros or 0))
		if premio.caja then return ArmasRules.abrir(d, premio.caja, r1, r2, token, true) end   -- caja gratis (sin cobrar monedas)
		return d
	end)
	if not data then return {success=false,message=extra or "No se pudo cobrar el premio."} end
	local caja
	if premio.caja and type(extra) == "table" then
		caja = {success=true,caja=extra.caja,arma=extra.arma,rareza=extra.rareza,nueva=extra.nueva,devolucion=extra.devolucion}
		resultadoCaja:FireClient(player, caja)                 -- la ruleta de la caja se anima como una compra
		misionesProgreso:Fire(player, "cajas", 1)
	end
	return {success=true,caja=caja}
end

-- Cajas, Monedas y Gemas pagadas con Robux (Developer Products)
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	-- 0. Armas exclusivas de compra única
	local armaProducto = ArmasConfig.ArmaPorProducto[info.ProductId]
	if armaProducto then
		if not sessions[player] then return Enum.ProductPurchaseDecision.NotProcessedYet end
		return darArma(player, armaProducto, info.PurchaseId) and Enum.ProductPurchaseDecision.PurchaseGranted
			or Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 0b. Pack de Inicio (compra única): monedas, giros y una caja abierta al momento; el título lo da PackInicio
	local pack = MonetizationConfig.StarterPack
	if pack and pack.Id ~= 0 and info.ProductId == pack.Id then
		if not sessions[player] then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local t = os.clock()
		while busy[player] and os.clock() - t < 10 do task.wait(0.1) end
		local r1, r2 = random:NextNumber(), random:NextNumber()
		local data, res = armasAction(player, function(previous)
			if type(previous.Recibos) == "table" and table.find(previous.Recibos, info.PurchaseId) then return previous, nil end   -- recibo repetido
			local d = table.clone(previous)
			d.Coins = (d.Coins or 0) + pack.Coins
			d.Spins = (d.Spins or 0) + pack.Spins
			d.PackInicio = true
			return ArmasRules.abrir(d, pack.Caja, r1, r2, info.PurchaseId, true)
		end)
		if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end
		if type(res) == "table" then
			resultadoCaja:FireClient(player, {success=true,caja=res.caja,arma=res.arma,rareza=res.rareza,nueva=res.nueva,devolucion=res.devolucion})
			misionesProgreso:Fire(player, "cajas", 1)
		end
		print(string.format("[ZeroWheelServer] %s compró el Pack de Inicio", player.Name))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 0c. Packs de giros de la ruleta (el recibo ya está cobrado: se da aunque la región haya cambiado)
	for _, sp in MonetizationConfig.SpinPacks or {} do
		if sp.Id ~= 0 and info.ProductId == sp.Id then
			if not sessions[player] then return Enum.ProductPurchaseDecision.NotProcessedYet end
			local data = armasAction(player, function(previous)
				if type(previous.Recibos) == "table" and table.find(previous.Recibos, info.PurchaseId) then return previous end   -- recibo repetido
				local d = table.clone(previous)
				d.Spins = (d.Spins or 0) + sp.Giros
				d.Recibos = table.clone(type(d.Recibos) == "table" and d.Recibos or {})
				table.insert(d.Recibos, info.PurchaseId)
				while #d.Recibos > 50 do table.remove(d.Recibos, 1) end
				return d
			end)
			if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end
			print(string.format("[ZeroWheelServer] %s compró %d giros", player.Name, sp.Giros))
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	-- 1. Cajas de Armas
	local caja = ArmasConfig.CajaPorProducto[info.ProductId]
	if caja then
		if not sessions[player] then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local t = os.clock()
		while busy[player] and os.clock() - t < 10 do task.wait(0.1) end
		local res = openBox(player, caja.id, info.PurchaseId, true)
		if not res.success then return Enum.ProductPurchaseDecision.NotProcessedYet end
		resultadoCaja:FireClient(player, res)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 2. Packs de Monedas
	local coinPack = MonetizationConfig.Products and MonetizationConfig.Products.CoinPacks and MonetizationConfig.Products.CoinPacks[info.ProductId]
	if coinPack then
		local data = armasAction(player, function(previous)
			local d = table.clone(previous)
			d.Coins = (d.Coins or 0) + coinPack.Amount
			return d
		end)
		if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local okData, DataService = pcall(function() return require(game:GetService("ServerScriptService").Server.Services.DataService) end)
		if okData and DataService then
			DataService.addCurrency(player, "Coins", coinPack.Amount)
		end
		print(string.format("[ZeroWheelServer] %s compró %s (+%d Monedas)", player.Name, coinPack.Name, coinPack.Amount))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 3. Packs de Gemas
	local gemPack = MonetizationConfig.Products and MonetizationConfig.Products.GemPacks and MonetizationConfig.Products.GemPacks[info.ProductId]
	if gemPack then
		local okData, DataService = pcall(function() return require(game:GetService("ServerScriptService").Server.Services.DataService) end)
		if okData and DataService then
			DataService.addCurrency(player, "Gems", gemPack.Amount)
		end
		player:SetAttribute("Gems", (player:GetAttribute("Gems") or 0) + gemPack.Amount)
		print(string.format("[ZeroWheelServer] %s compró %s (+%d Gemas)", player.Name, gemPack.Name, gemPack.Amount))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end
-- Ajustes de sonido: se aplican al momento en la sesión y se escriben en el DataStore como mucho cada 3 s
local ajustesPendientes = {}
local function guardarAjustes(player, payload)
	local data = sessions[player]
	if not data then return {success=false} end
	local function nivel(v) return type(v) == "number" and v == v and math.clamp(math.floor(v * 100 + 0.5) / 100, 0, 1) or nil end
	local actual = type(data.Ajustes) == "table" and data.Ajustes or {}
	local musica = nivel(payload.music) or actual.Musica or 0.5
	local sfx = nivel(payload.sfx) or actual.SFX or 0.5
	local rend = if type(payload.rendimiento) == "boolean" then payload.rendimiento else actual.Rendimiento == true
	data.Ajustes = {Musica = musica, SFX = sfx, Rendimiento = rend}
	player:SetAttribute("AjusteMusica", musica); player:SetAttribute("AjusteSFX", sfx); player:SetAttribute("AjusteRendimiento", rend)
	if studio or ajustesPendientes[player] then return {success=true} end
	ajustesPendientes[player] = true
	task.delay(3, function()
		ajustesPendientes[player] = nil
		local current = sessions[player]
		if not current then return end
		local ajustes = table.clone(current.Ajustes)
		local ok, err = pcall(function()
			store:UpdateAsync(tostring(player.UserId), function(previous)
				if not previous then return nil end
				local nextData = table.clone(previous); nextData.Ajustes = ajustes
				return nextData
			end)
		end)
		if not ok then warn("[ZeroWheel] Ajustes sin guardar: "..tostring(err)) end
	end)
	return {success=true}
end

local uiRemote = ReplicatedStorage:FindFirstChild("ZeroUIRequest") or Instance.new("RemoteFunction")
uiRemote.Name = "ZeroUIRequest"
uiRemote.Parent = ReplicatedStorage
uiRemote.OnServerInvoke = function(player, action, payload)
	local index = type(payload) == "table" and tonumber(payload.index)
	if (action == "Daily" or action == "Time") and index then return claim(player, action, index) end
	if action == "OpenBox" and type(payload) == "table" and type(payload.caja) == "string" then
		return openBox(player, payload.caja, HttpService:GenerateGUID(false), false)
	end
	if action == "ComprarArma" and type(payload) == "table" and type(payload.arma) == "string" then
		local data, res = armasAction(player, function(previous) return ArmasRules.comprar(previous, payload.arma, os.time()) end)
		if not data then return {success=false,message=res or "No se pudo comprar."} end
		resultadoCaja:FireClient(player, {success=true, arma=payload.arma, rareza=ArmasConfig.PorNombre[payload.arma].rareza, nueva=true, devolucion=0})
		return {success=true,message="¡Compraste "..payload.arma.."!"}
	end
	if action == "EquipArma" and type(payload) == "table" and type(payload.arma) == "string" then
		local p = pases(player)
		local data, reason = armasAction(player, function(previous) return ArmasRules.equipar(previous, payload.arma, player.UserId, p) end)
		return data and {success=true,message="Equipaste "..payload.arma.."."} or {success=false,message=reason or "No se pudo equipar."}
	end
	if action == "SetAFK" and type(payload) == "table" and type(payload.on) == "boolean" then
		player:SetAttribute("AFK", payload.on)            -- RoundService no lo mete en las rondas mientras esté activo
		return {success=true, afk=payload.on}
	end
	if action == "GuardarAjustes" and type(payload) == "table" then
		return guardarAjustes(player, payload)
	end
	if action == "JoinHunters" then return {success=false,message="Entrarás a jugar en la próxima ronda."} end
	if action == "Purchase" then
		local prod = type(payload) == "table" and payload.product
		if prod == "StarterPack" then
			local pack = MonetizationConfig.StarterPack
			if player:GetAttribute("PackInicio") then return {success=false, message="Ya tienes el Pack de Inicio."} end
			if not pack or pack.Id == 0 then return {success=false, message="El Pack de Inicio estará disponible muy pronto."} end
			if player:GetAttribute("PagoAleatorioRestringido") ~= false then return {success=false, message="El Pack de Inicio no está disponible en tu región."} end
			MarketplaceService:PromptProductPurchase(player, pack.Id)
			return {success=true, message="Abriendo la compra…"}
		end
		local passKey = if prod == "VIP" then "VIP"
			elseif prod == "2xCoins" or prod == "2× COINS" or prod == "TELEPORTER" then "DOUBLE_COINS"
			elseif prod == "2xGems" or prod == "2× GEMS" or prod == "×2 SPEED" then "DOUBLE_GEMS"
			elseif prod == "2xXP" or prod == "2× XP" or prod == "2x XP" then "DOUBLE_XP"
			else nil
		if passKey then
			local okMon, MonetizationService = pcall(function() return require(game:GetService("ServerScriptService").Server.Services.MonetizationService) end)
			if okMon and MonetizationService then
				if MonetizationService.ownsPass(player, passKey) then
					return {success=false, message="¡Ya posees este pase!"}
				end
				local info = MonetizationConfig.Passes[passKey]
				if info and info.Id > 0 then
					game:GetService("MarketplaceService"):PromptGamePassPurchase(player, info.Id)
					return {success=true}
				else
					return {success=false, message="El pase " .. (info and info.DisplayName or passKey) .. " estará disponible muy pronto."}
				end
			end
		end

		if type(prod) == "string" and MonetizationConfig.Products then
			local n, k, tipo = string.match(prod, "^(%d+)(K?)%s+(%a+)")
			local cantidad = n and tonumber(n) * (if k == "K" then 1000 else 1)
			local tabla = if tipo == "coins" then MonetizationConfig.Products.CoinPacks elseif tipo == "gems" then MonetizationConfig.Products.GemPacks else nil
			for prodId, pack in tabla or {} do
				if pack.Amount == cantidad then
					MarketplaceService:PromptProductPurchase(player, prodId)
					return {success=true}
				end
			end
		end
		if type(prod) == "string" then
			if MonetizationConfig.Products then
				for prodId, pack in MonetizationConfig.Products.CoinPacks or {} do
					if pack.Key == prod or pack.Name == prod then
						MarketplaceService:PromptProductPurchase(player, prodId)
						return {success=true}
					end
				end
				for prodId, pack in MonetizationConfig.Products.GemPacks or {} do
					if pack.Key == prod or pack.Name == prod then
						MarketplaceService:PromptProductPurchase(player, prodId)
						return {success=true}
					end
				end
			end
		end

		return {success=false,message="Este paquete estará disponible pronto."}
	end
	return {success=false,message="Esta función estará disponible pronto."}
end

remote.OnServerInvoke = function(player, action)
	if action ~= "Spin" then return {success=false,message="Acción inválida."} end
	local nowClock = os.clock()
	if busy[player] or nowClock-(lastRequest[player] or -math.huge) < .5 then
		return {success=false,message="Espera a que termine el giro."}
	end
	lastRequest[player] = nowClock
	if not sessions[player] then
		return {success=false,message=player:GetAttribute("WheelLoadFailed") and "No se pudo cargar tu saldo. Vuelve a entrar para intentarlo." or "Cargando tus giros…"}
	end
	busy[player] = true
	local now, token = os.time(), HttpService:GenerateGUID(false)
	local index = Rules.pick(random:NextNumber(0,100))
	local result, reason
	local ok, err = pcall(function()
		if studio then
			result, reason = Rules.spin(sessions[player], now, index, token)
		else
			result = store:UpdateAsync(tostring(player.UserId), function(previous)
				local nextData, rejection = Rules.spin(previous, now, index, token)
				reason = rejection
				return nextData
			end)
		end
	end)
	busy[player] = nil
	if not ok then
		warn("[ZeroWheel] Giro sin confirmar: "..tostring(err))
		return {success=false,message="No se pudo confirmar el giro. Inténtalo de nuevo."}
	end
	if not result then return {success=false,message=reason or "Giro no disponible."} end
	if player.Parent == Players then sessions[player]=result; sync(player,result) end
	misionesProgreso:Fire(player, "ruleta", 1)
	local premio = Config.Rewards[result.LastReward]
	if premio.Arma then                                      -- casilla de arma (Cero Absoluto): si ya la tienes, monedas
		task.spawn(function()
			local t = os.clock()
			while busy[player] and os.clock() - t < 10 do task.wait(0.1) end
			local tk = token .. "ruleta"
			local disponible = ArmasConfig.disponible(ArmasConfig.Obtencion[premio.Arma])
			local _, nueva = armasAction(player, function(previous)
				local ya = type(previous.Recibos) == "table" and table.find(previous.Recibos, tk)
				local d, n = ArmasRules.dar(previous, premio.Arma, tk)
				if d and not ya and (n == false or not disponible) then d.Coins = (d.Coins or 0) + (premio.Compensa or 0) end
				return d, n
			end)
			if nueva == true then
				task.delay(Config.SpinDuration + 0.4, function()
					if player.Parent == Players then
						resultadoCaja:FireClient(player, {success=true, arma=premio.Arma, rareza=ArmasConfig.PorNombre[premio.Arma].rareza, nueva=true, devolucion=0})
					end
				end)
			end
		end)
	end
	return {success=true,index=result.LastReward,coins=premio.Coins,arma=premio.Arma,duration=Config.SpinDuration}
end

-- quien invita gana las armas de "invitar" cuando su amigo entra por la invitación (ReferredByPlayerId)
-- ponytail: solo si el que invitó está en el mismo servidor; guardar invitaciones pendientes si hace falta
local function premiarInvitacion(player)
	local ok, join = pcall(function() return player:GetJoinData() end)
	local ref = ok and join and join.ReferredByPlayerId
	if not ref or ref == 0 or ref == player.UserId then return end
	local inviter = Players:GetPlayerByUserId(ref)
	local t = os.clock()
	while inviter and inviter.Parent == Players and not sessions[inviter] and os.clock() - t < 30 do task.wait(1) end
	if not (inviter and sessions[inviter]) then return end
	for nombre, o in ArmasConfig.Obtencion do
		if o.invitar and ArmasConfig.disponible(o) then darArma(inviter, nombre, "invita" .. player.UserId) end   -- tiempo limitado
	end
end

-- PolicyService: donde la ley lo prohíbe no se venden con Robux cosas con premio aleatorio (cajas, Pack de Inicio).
-- Si la consulta falla se bloquea, que es lo seguro. Lo leen este script y ZeroArmasClient.
local function politica(player)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	player:SetAttribute("PagoAleatorioRestringido", not ok or info.ArePaidRandomItemsRestricted == true)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(politica, player)
	joinedAt[player] = os.time(); loadPlayer(player)
	-- para la cuenta atrás de REGALOS POR TIEMPO en el cliente
	player:SetAttribute("TiempoInicio", joinedAt[player])
	local metas = {} for _, r in ipairs(TIMED) do table.insert(metas, r.After) end
	player:SetAttribute("TiempoMetas", table.concat(metas, ","))
	for _, tabla in { MonetizationConfig.Passes, MonetizationConfig.Exclusivos or {} } do
		for clave in tabla do
			player:GetAttributeChangedSignal("HasPass_" .. clave):Connect(function() if sessions[player] then sync(player, sessions[player]) end end)
		end
	end
	premiarInvitacion(player)
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, comprado)
	if not comprado then return end
	local clave
	for _, tabla in { MonetizationConfig.Passes, MonetizationConfig.Exclusivos or {} } do
		for k, info in tabla do if info.Id == passId then clave = k end end
	end
	if not clave then return end
	local t = os.clock()
	while player.Parent and player:GetAttribute("HasPass_" .. clave) ~= true and os.clock() - t < 10 do task.wait(0.2) end   -- MonetizationService
	if not sessions[player] or player:GetAttribute("HasPass_" .. clave) ~= true then return end
	for nombre, ob in ArmasConfig.Obtencion do
		if ob.pase == clave then
			local p = pases(player)
			local data = armasAction(player, function(previous) return ArmasRules.equipar(previous, nombre, player.UserId, p) end)
			if data then resultadoCaja:FireClient(player, {success=true, arma=nombre, rareza=ArmasConfig.PorNombre[nombre].rareza, nueva=true, devolucion=0}) end
			break
		end
	end
end)
Players.PlayerRemoving:Connect(function(player)
	sessions[player]=nil; busy[player]=nil; lastRequest[player]=nil; joinedAt[player]=nil; timeClaimed[player]=nil
end)
for _, player in ipairs(Players:GetPlayers()) do joinedAt[player] = os.time(); task.spawn(politica, player); task.spawn(loadPlayer,player) end
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do rewardStates(player) end
	end
end)
