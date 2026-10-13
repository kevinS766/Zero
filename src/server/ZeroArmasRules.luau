--!strict
-- ZeroArmasRules (ModuleScript, ServerScriptService): lógica pura de cajas e inventario sobre el registro de
-- ZeroWheel_v1 (el mismo que guarda las monedas), para que pagar y recibir el arma sean UNA escritura atómica.
--   abrir(previo, cajaId, r1, r2, token, pagoRobux) -> (nuevo, resultado) | (nil, motivo)
--   equipar(previo, nombre) -> nuevo | (nil, motivo)
-- Todas devuelven copias; nunca modifican `previo` (UpdateAsync puede reintentar la función).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("ZeroArmasConfig"))

local Rules = {}

-- armas guardadas antes del cambio a las mágicas -> sus reemplazos (Config.Reemplazo); las desconocidas se ignoran
function Rules.migrar(armas: { [string]: boolean }?): { [string]: boolean }
	local t = {}
	for nombre, v in armas or {} do
		local n = if Config.PorNombre[nombre] then nombre else Config.Reemplazo[nombre]
		if v and n then t[n] = true end
	end
	return t
end

local function copia(previo)
	local data = table.clone(previo)
	data.Armas = Rules.migrar(previo.Armas)
	data.Armas[Config.ArmaInicial] = true                  -- todos tienen la Varita de Rama
	if data.Equipada and not Config.PorNombre[data.Equipada] then data.Equipada = Config.Reemplazo[data.Equipada] end
	data.Recibos = table.clone(previo.Recibos or {})
	return data
end

-- pases: { [clave de MonetizationConfig.Passes] = true } con los pases del jugador (armas que vienen con un pase)
function Rules.armas(data, userId: number?, pases: { [string]: boolean }?): { [string]: boolean }
	local t = Rules.migrar(data and data.Armas)
	t[Config.ArmaInicial] = true
	for nombre, o in Config.Obtencion do if o.pase and pases and pases[o.pase] then t[nombre] = true end end
	if userId and Config.Probadores[userId] then for _, a in Config.Armas do t[a.nombre] = true end end
	return t
end

function Rules.equipada(data, userId: number?, pases: { [string]: boolean }?): string
	local e = data and data.Equipada
	if e and not Config.PorNombre[e] then e = Config.Reemplazo[e] end
	if e and Config.PorNombre[e] and Rules.armas(data, userId, pases)[e] then return e end
	return Config.ArmaInicial
end

function Rules.abrir(previo, cajaId: string, r1: number, r2: number, token: string, pagoRobux: boolean?)
	local caja = Config.CajaPorId[cajaId]
	if not caja then return nil, "Caja inválida." end
	local data = copia(previo)
	-- idempotencia: si este token (o recibo de Robux) ya se procesó, devolver el mismo resultado
	if data.UltimaCaja and data.UltimaCaja.token == token then return data, data.UltimaCaja end
	if pagoRobux and table.find(data.Recibos, token) then return data, data.UltimaCaja end
	if not pagoRobux then
		if (data.Coins or 0) < caja.monedas then return nil, "No tienes suficientes monedas." end
		data.Coins -= caja.monedas
	end
	local arma = Config.tirar(caja, r1, r2)
	local rareza = Config.PorNombre[arma].rareza
	local resultado = { token = token, caja = cajaId, arma = arma, rareza = rareza, nueva = not data.Armas[arma], devolucion = 0 }
	if resultado.nueva then
		data.Armas[arma] = true
	else
		resultado.devolucion = Config.Rarezas[rareza].devolucion
		data.Coins = (data.Coins or 0) + resultado.devolucion
	end
	if pagoRobux then
		table.insert(data.Recibos, token)
		while #data.Recibos > 50 do table.remove(data.Recibos, 1) end
	end
	data.UltimaCaja = resultado
	return data, resultado
end

function Rules.equipar(previo, nombre: string, userId: number?, pases: { [string]: boolean }?)
	if not Config.PorNombre[nombre] then return nil, "Arma inválida." end
	local data = copia(previo)
	if not Rules.armas(data, userId, pases)[nombre] then return nil, "Aún no tienes esa arma." end
	data.Equipada = nombre
	return data
end

-- Compra con monedas (míticos de Config.Obtencion con `monedas`); respeta el tiempo limitado
function Rules.comprar(previo, nombre: string, ahora: number)
	local o = Config.Obtencion[nombre]
	if not (o and o.monedas) then return nil, "Esta arma no se compra con monedas." end
	if not Config.disponible(o, ahora) then return nil, "Esta arma ya no está disponible." end
	local data = copia(previo)
	if data.Armas[nombre] then return nil, "Ya tienes esta arma." end
	if (data.Coins or 0) < o.monedas then return nil, "No tienes suficientes monedas." end
	data.Coins -= o.monedas
	data.Armas[nombre] = true
	data.Equipada = nombre                  -- recién comprada: se equipa sola
	return data
end

-- Regala un arma (compra con Robux, invitación, ruleta). El token evita darla dos veces si UpdateAsync o el recibo se repiten.
function Rules.dar(previo, nombre: string, token: string)
	if not Config.PorNombre[nombre] then return nil, "Arma inválida." end
	local data = copia(previo)
	if table.find(data.Recibos, token) then return data, false end
	local nueva = not data.Armas[nombre]
	data.Armas[nombre] = true
	if nueva then data.Equipada = nombre end   -- arma nueva (Robux, invitación, ruleta): se equipa sola
	table.insert(data.Recibos, token)
	while #data.Recibos > 50 do table.remove(data.Recibos, 1) end
	return data, nueva
end

return Rules
