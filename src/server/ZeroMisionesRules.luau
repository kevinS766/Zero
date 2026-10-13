--!strict
-- ZeroMisionesRules (ModuleScript, ServerScriptService): lógica pura de las misiones sobre la tabla de un jugador.
-- No toca DataStores ni monedas: devuelve qué premio dar y ZeroMisionesServer lo cobra.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("ZeroMisionesConfig"))
local Titulos = require(ReplicatedStorage:WaitForChild("ZeroTitulosConfig"))
local Rules = {}

local function sorteo(lista, n: number, rng: Random, exigeCualquiera: boolean?)
	for _ = 1, 50 do
		local pool = table.clone(lista)
		local out = {}
		while #out < n and #pool > 0 do table.insert(out, table.remove(pool, rng:NextInteger(1, #pool))) end
		if not exigeCualquiera then return out end
		for _, m in out do if m.rol == "Cualquiera" then return out end end
	end
	return { lista[1], lista[2], lista[3] }
end
local function slot(def) return { id = def.id, prog = 0, done = false, claimed = false } end

function Rules.nuevo()
	return { v = 1, dia = -1, semana = -1, diarias = {}, semanales = {}, cambio = false, bonusD = false, bonusS = false,
		total = {}, valores = {}, logros = {}, primeras = {}, dias = 0, mapas = {}, mapasSemana = {}, titulos = {}, titulo = nil }
end

-- Renueva diarias/semanales si cambió el día o la semana. Devuelve true si cambió algo.
function Rules.normalizar(m, now: number, rng: Random): boolean
	local cambio = false
	for k, v in Rules.nuevo() do if m[k] == nil then m[k] = v end end
	local dia, semana = Config.dia(now), Config.semana(now)
	if m.dia ~= dia then
		m.dia = dia; m.cambio = false; m.bonusD = false
		m.diarias = {}
		for _, d in sorteo(Config.Diarias, Config.DiariasPorDia, rng, true) do table.insert(m.diarias, slot(d)) end
		m.dias += 1
		cambio = true
	end
	if m.semana ~= semana then
		m.semana = semana; m.bonusS = false; m.mapasSemana = {}
		m.semanales = {}
		for _, d in sorteo(Config.Semanales, Config.SemanalesPorSemana, rng) do table.insert(m.semanales, slot(d)) end
		cambio = true
	end
	return cambio
end

local function avanzar(lista, clave: string, amount: number, onDone)
	for _, s in lista do
		local def = Config.PorId[s.id]
		if def and def.clave == clave and not s.done then
			s.prog = math.min(def.meta, s.prog + amount)
			if s.prog >= def.meta then s.done = true; if onDone then onDone() end end
		end
	end
end

-- Suma progreso. clave especiales: "mapa" (extra = id del mapa), "valor:<clave>" (amount = valor actual)
function Rules.progreso(m, clave: string, amount: number, extra: string?, mapIds: { string }?)
	if amount <= 0 then return end
	local valor = string.match(clave, "^valor:(.+)")
	if valor then m.valores[valor] = math.max(m.valores[valor] or 0, amount); return end
	if clave == "mapa" and extra then
		m.mapas[extra] = (m.mapas[extra] or 0) + 1
		m.mapasSemana[extra] = true
		local n = 0; for _ in m.mapasSemana do n += 1 end
		for _, s in m.semanales do
			local def = Config.PorId[s.id]
			if def and def.clave == "mapas_distintos" and not s.done then s.prog = math.min(def.meta, n); s.done = n >= def.meta end
		end
		if mapIds then
			local minimo = math.huge
			for _, id in mapIds do minimo = math.min(minimo, m.mapas[id] or 0) end
			m.valores.mapas_min = minimo
		end
		return
	end
	m.total[clave] = (m.total[clave] or 0) + amount
	avanzar(m.diarias, clave, amount, function()
		Rules.progreso(m, "diarias_completadas", 1)
	end)
	avanzar(m.semanales, clave, amount)
end

local function valorLogro(m, def): number
	if def.clave == "dias" then return m.dias end
	if def.valor then return m.valores[def.clave] or 0 end
	return m.total[def.clave] or 0
end

-- Reclamar. tipo: "diaria" | "semanal" | "logro" | "primera" | "bonusDiario" | "bonusSemanal"
-- Devuelve { monedas, giros, caja, titulo } o nil, motivo. Modifica m solo si se puede reclamar.
function Rules.reclamar(m, tipo: string, id: string?)
	if tipo == "diaria" or tipo == "semanal" then
		for _, s in (tipo == "diaria" and m.diarias or m.semanales) do
			if s.id == id then
				if not s.done then return nil, "Aún no la has completado." end
				if s.claimed then return nil, "Ya la reclamaste." end
				s.claimed = true
				local def = Config.PorId[id]
				return { monedas = def.monedas or 0, caja = def.caja }
			end
		end
		return nil, "Esa misión ya no está disponible."
	elseif tipo == "bonusDiario" or tipo == "bonusSemanal" then
		local diario = tipo == "bonusDiario"
		if m[diario and "bonusD" or "bonusS"] then return nil, "Ya lo reclamaste." end
		for _, s in (diario and m.diarias or m.semanales) do if not s.claimed then return nil, "Reclama antes todas las misiones." end end
		m[diario and "bonusD" or "bonusS"] = true
		local b = diario and Config.BonusDiario or Config.BonusSemanal
		return { monedas = b.monedas or 0, giros = b.giros, caja = b.caja }
	elseif tipo == "logro" then
		local def = Config.PorId[id]
		if not def or not def.metas then return nil, "Logro inválido." end
		local nivel = (m.logros[id] or 0) + 1
		if nivel > #def.metas then return nil, "Ya lo completaste." end
		if valorLogro(m, def) < def.metas[nivel] then return nil, "Aún no llegas." end
		m.logros[id] = nivel
		local titulo = nivel == #def.metas and def.nombreTitulo or nil
		if titulo and not table.find(m.titulos, titulo) then table.insert(m.titulos, titulo) end
		return { monedas = def.monedas[nivel], titulo = titulo }
	elseif tipo == "primera" then
		local def = Config.PorId[id]
		if not def or def.metas or def.meta then return nil, "Logro inválido." end
		if m.primeras[id] then return nil, "Ya lo reclamaste." end
		if (m.total[def.clave] or 0) < 1 then return nil, "Aún no lo has conseguido." end
		m.primeras[id] = true
		return { monedas = def.monedas }
	end
	return nil, "Tipo inválido."
end

-- ------------------------------------------------------------------ títulos (ZeroTitulosConfig)
-- extras: atributos del jugador que no están en la tabla (pase VIP, Pack de Inicio), p. ej. { HasPass_VIP = true }
local function progresoTitulo(m, def, extras): (number, number)
	local r = def.req
	if r.clave then return m.total[r.clave] or 0, r.meta end
	if r.dias then return m.dias or 0, r.dias end
	if r.logro then
		local l = Config.PorId[r.logro]
		return l and valorLogro(m, l) or 0, l and l.metas[#l.metas] or math.huge
	end
	if r.atributo then return (extras and extras[r.atributo]) and 1 or 0, 1 end
	return 0, 1
end

function Rules.reclamarTitulo(m, nombre: string, extras): (boolean, string?)
	local def = Titulos.PorNombre[nombre]
	if not def then return false, "Título inválido." end
	if table.find(m.titulos, nombre) then return false, "Ya lo tienes." end
	local v, meta = progresoTitulo(m, def, extras)
	if v < meta then return false, "Aún no cumples el objetivo." end
	table.insert(m.titulos, nombre)
	return true
end

function Rules.titulos(m, extras)
	local out = {}
	for _, def in Titulos.Lista do
		local v, meta = progresoTitulo(m, def, extras)
		table.insert(out, { nombre = def.nombre, valor = math.min(v, meta), meta = meta, tiene = table.find(m.titulos, def.nombre) ~= nil })
	end
	return out
end

-- Cambia una diaria sin reclamar por otra que no esté ya (una vez al día)
function Rules.cambiar(m, id: string, rng: Random): (boolean, string?)
	if m.cambio then return false, "Ya usaste tu cambio de hoy." end
	for i, s in m.diarias do
		if s.id == id then
			if s.claimed then return false, "Esa ya la reclamaste." end
			local usadas = {}
			for _, x in m.diarias do usadas[x.id] = true end
			local pool = {}
			for _, d in Config.Diarias do if not usadas[d.id] then table.insert(pool, d) end end
			if #pool == 0 then return false, "No hay otras misiones." end
			m.diarias[i] = slot(pool[rng:NextInteger(1, #pool)])
			m.cambio = true
			return true
		end
	end
	return false, "Esa misión ya no está disponible."
end

-- Lo que ve el cliente
function Rules.vista(m, now: number, extras: any?)
	local function lista(slots)
		local out = {}
		for _, s in slots do
			local d = Config.PorId[s.id]
			table.insert(out, { id = s.id, titulo = d.titulo, texto = d.texto, rol = d.rol, prog = s.prog, meta = d.meta, done = s.done,
				claimed = s.claimed, monedas = d.monedas, caja = d.caja })
		end
		return out
	end
	local logros = {}
	for _, d in Config.Logros do
		local nivel = m.logros[d.id] or 0
		local sig = d.metas[nivel + 1]
		table.insert(logros, { id = d.id, titulo = d.titulo, texto = d.texto, nivel = nivel, niveles = #d.metas, valor = valorLogro(m, d),
			meta = sig, monedas = sig and d.monedas[nivel + 1] or nil, nombreTitulo = d.nombreTitulo })
	end
	local primeras = {}
	for _, d in Config.Primeras do
		table.insert(primeras, { id = d.id, titulo = d.titulo, monedas = d.monedas, hecho = (m.total[d.clave] or 0) >= 1, claimed = m.primeras[d.id] == true })
	end
	local finDia = (m.dia + 1) * 86400
	local finSemana = ((m.semana + 1) * 7 - 3) * 86400
	return { diarias = lista(m.diarias), semanales = lista(m.semanales), bonusD = m.bonusD, bonusS = m.bonusS, cambio = m.cambio,
		logros = logros, primeras = primeras, titulos = m.titulos, titulo = m.titulo, titulosInfo = Rules.titulos(m, extras),
		finDia = finDia, finSemana = finSemana, bonusDiario = Config.BonusDiario, bonusSemanal = Config.BonusSemanal }
end

return Rules
