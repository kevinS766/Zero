--!strict
-- ZeroArmasConfig (ModuleScript, ReplicatedStorage): armas cosméticas y cajas de ZERO.
-- Lo leen el servidor (ZeroWheelServer/ZeroArmasRules) y el cliente (ZeroArmasClient).
-- 2026-10-11: las armas son las 16 mágicas de zero-magicas (scripts/gen_armas.py genera este archivo).
local Config = {}

-- Las 16 armas mágicas (varitas y bastones). Todas comparten hitbox y alcance: son solo cosméticas.
-- Las exclusivas no salen en las cajas. Los míticos sí, solo en la Épica y la Legendaria y con poca probabilidad (Config.enCajas:
-- únicamente los que se compran con monedas; los de tiempo limitado o de ruleta no). Ver Config.Obtencion.
-- Exclusivo = solo por Robux, pase o evento; se irán sacando poco a poco, cada una con su propia habilidad.
Config.Armas = {
	{ nombre = "Varita de Rama", rareza = "Comun", color = Color3.fromHex("#5eb8ff") },
	{ nombre = "Varita de Tiza", rareza = "Comun", color = Color3.fromHex("#f2f2ee") },
	{ nombre = "Lápiz Mágico", rareza = "Comun", color = Color3.fromHex("#ffd34d") },
	{ nombre = "Varita Estelar", rareza = "Raro", color = Color3.fromHex("#ff6fc8") },
	{ nombre = "Batuta de Tormenta", rareza = "Raro", color = Color3.fromHex("#7fd8ff") },
	{ nombre = "Varita de Té", rareza = "Raro", color = Color3.fromHex("#6fc3ff") },
	{ nombre = "Cetro Lunar Kawaii", rareza = "Especial", color = Color3.fromHex("#ff7ac8") },
	{ nombre = "Varita de Sellos", rareza = "Especial", color = Color3.fromHex("#ff3b3b") },
	{ nombre = "Linterna Espiritual", rareza = "Especial", color = Color3.fromHex("#4fb8ff") },
	{ nombre = "Bastón del Grimorio", rareza = "Legendario", color = Color3.fromHex("#7fe0ff") },
	{ nombre = "Bastón Reloj de Arena", rareza = "Legendario", color = Color3.fromHex("#ffc93a") },
	{ nombre = "Bastón de Dominio", rareza = "Legendario", color = Color3.fromHex("#b05cff") },
	{ nombre = "Bastón Galaxia", rareza = "Mitico", color = Color3.fromHex("#ffc857") },
	{ nombre = "Bastón del Dragón Celestial", rareza = "Mitico", color = Color3.fromHex("#5fe8c8") },
	{ nombre = "Bastón Cero Absoluto", rareza = "Mitico", color = Color3.fromHex("#7fd8ff") },
	{ nombre = "Bastón de Halloween", rareza = "Mitico", color = Color3.fromHex("#b05cff") },
	-- 8 bastones EXCLUSIVOS (solo Robux / pase / evento; zero-bastones; modelos con piezas Anim_* que mueve ZeroBastonesAnim)
	{ nombre = "Cetro del Vacío Estelar", rareza = "Exclusivo", color = Color3.fromHex("#b65cff") },
	{ nombre = "Linterna del Dragón", rareza = "Exclusivo", color = Color3.fromHex("#ff7a2e") },
	{ nombre = "Corazón del Lago", rareza = "Exclusivo", color = Color3.fromHex("#2e7bff") },
	{ nombre = "Gatito Hechicero", rareza = "Mitico", color = Color3.fromHex("#ffd34d") },
	{ nombre = "Origami Celestial", rareza = "Exclusivo", color = Color3.fromHex("#ffe6a8") },
	{ nombre = "Arcade Retro", rareza = "Exclusivo", color = Color3.fromHex("#3fe6ff") },
	{ nombre = "Corona del Bufón", rareza = "Exclusivo", color = Color3.fromHex("#b04cff") },
	{ nombre = "Espejo del Alma", rareza = "Exclusivo", color = Color3.fromHex("#ff4f7a") },
}

Config.Rarezas = {
	Comun = { orden = 1, nombre = "COMÚN", color = Color3.fromRGB(176, 186, 200), devolucion = 100 },
	Raro = { orden = 2, nombre = "RARO", color = Color3.fromRGB(70, 160, 255), devolucion = 400 },
	Especial = { orden = 3, nombre = "ÉPICO", color = Color3.fromRGB(170, 101, 255), devolucion = 1000 },
	Legendario = { orden = 4, nombre = "LEGENDARIO", color = Color3.fromRGB(255, 196, 64), devolucion = 3000 },
	Mitico = { orden = 5, nombre = "MÍTICO", color = Color3.fromRGB(255, 70, 140), devolucion = 15000 },
	Exclusivo = { orden = 6, nombre = "EXCLUSIVO", color = Color3.fromRGB(255, 84, 46), devolucion = 15000 },
}

-- Cajas: precio en monedas, producto de Robux (Developer Product; 0 = sin compra con Robux todavía)
-- y probabilidad (%) de cada rareza. Dentro de una rareza todas las armas tienen la misma probabilidad.
Config.Cajas = {
	{ id = "Comun", nombre = "CAJA COMÚN", monedas = 600, producto = 3717525574, robux = 25, color = Color3.fromRGB(150, 165, 185),
	  icono = "rbxassetid://110614295161773",
	  prob = { Comun = 70, Raro = 25, Especial = 4.5, Legendario = 0.5 } },
	{ id = "Rara", nombre = "CAJA RARA", monedas = 2500, producto = 3717525639, robux = 99, color = Color3.fromRGB(70, 160, 255),
	  icono = "rbxassetid://118032236532957",
	  prob = { Comun = 15, Raro = 50, Especial = 28, Legendario = 7 } },
	{ id = "Epica", nombre = "CAJA ÉPICA", monedas = 7000, producto = 3717562012, robux = 149, color = Color3.fromRGB(170, 101, 255),
	  icono = "rbxassetid://132865529106248",
	  prob = { Raro = 35, Especial = 50, Legendario = 14, Mitico = 1 } },
	{ id = "Legendaria", nombre = "CAJA LEGENDARIA", monedas = 15000, producto = 3717525682, robux = 199, color = Color3.fromRGB(255, 196, 64),
	  icono = "rbxassetid://102237268781234",
	  prob = { Especial = 60, Legendario = 37, Mitico = 3 } },
}

Config.ArmaInicial = "Varita de Rama"

-- Icono de cada arma para la casilla de la mochila (Tool.TextureId): zero-magicas/scripts/hacer_iconos.py
Config.Iconos = {
	["Varita de Rama"] = "rbxassetid://82310758601995",
	["Varita de Tiza"] = "rbxassetid://109495868667564",
	["Lápiz Mágico"] = "rbxassetid://71785987339472",
	["Varita Estelar"] = "rbxassetid://107035844593386",
	["Batuta de Tormenta"] = "rbxassetid://100242375655903",
	["Varita de Té"] = "rbxassetid://136356716507733",
	["Cetro Lunar Kawaii"] = "rbxassetid://114386199077846",
	["Varita de Sellos"] = "rbxassetid://83469251263320",
	["Linterna Espiritual"] = "rbxassetid://123516392886598",
	["Bastón del Grimorio"] = "rbxassetid://100442398115415",
	["Bastón Reloj de Arena"] = "rbxassetid://103275106620407",
	["Bastón de Dominio"] = "rbxassetid://125014978646571",
	["Bastón Galaxia"] = "rbxassetid://120632265164528",
	["Bastón del Dragón Celestial"] = "rbxassetid://76908423407922",
	["Bastón Cero Absoluto"] = "rbxassetid://84763014357839",
	["Bastón de Halloween"] = "rbxassetid://122956244042483",
}

-- Probadores: tienen TODAS las armas mientras estén en esta lista (no se guarda en sus datos; quitar el ID lo revierte)
Config.Probadores = {
	[121517633] = true,   -- KaiBit23
}

-- Familia de ataque de cada arma (la animación de golpe la elige ZeroMovement según la familia)
Config.Familias = {
	["Varita de Rama"] = "Daga",
	["Varita de Tiza"] = "Estoque",
	["Lápiz Mágico"] = "Daga",
	["Varita Estelar"] = "Estoque",
	["Batuta de Tormenta"] = "Estoque",
	["Varita de Té"] = "Daga",
	["Cetro Lunar Kawaii"] = "Espada",
	["Varita de Sellos"] = "Daga",
	["Linterna Espiritual"] = "Hacha",
	["Bastón del Grimorio"] = "Lanza",
	["Bastón Reloj de Arena"] = "Hacha",
	["Bastón de Dominio"] = "Guadana",
	["Bastón Galaxia"] = "Espada",
	["Bastón del Dragón Celestial"] = "Lanza",
	["Bastón Cero Absoluto"] = "Guadana",
	["Bastón de Halloween"] = "Hacha",
	["Cetro del Vacío Estelar"] = "Espada",
	["Linterna del Dragón"] = "Hacha",
	["Corazón del Lago"] = "Lanza",
	["Gatito Hechicero"] = "Espada",
	["Origami Celestial"] = "Lanza",
	["Arcade Retro"] = "Hacha",
	["Corona del Bufón"] = "Hacha",
	["Espejo del Alma"] = "Espada",
}

-- Armas antiguas (antes del 2026-10-11) -> la nueva que reciben quienes las tenían (ZeroArmasRules.migrar)
Config.Reemplazo = {
	["Aguijón"] = "Cetro Lunar Kawaii",
	["Bestia"] = "Bastón del Grimorio",
	["Bifaz"] = "Linterna Espiritual",
	["Bokken"] = "Varita de Tiza",
	["Cero Absoluto"] = "Bastón del Grimorio",
	["Cimitarra"] = "Varita de Té",
	["Cortaalmas"] = "Bastón Galaxia",
	["Depredador"] = "Linterna Espiritual",
	["Eclipse"] = "Bastón Reloj de Arena",
	["Florete"] = "Lápiz Mágico",
	["Gemelas"] = "Batuta de Tormenta",
	["Hacha Globo"] = "Bastón de Halloween",
	["Hachuela"] = "Varita de Tiza",
	["Karambit"] = "Varita de Sellos",
	["Katana"] = "Varita Estelar",
	["Katana Sakura"] = "Bastón del Dragón Celestial",
	["Media Luna"] = "Cetro Lunar Kawaii",
	["Naginata"] = "Varita Estelar",
	["Navaja"] = "Varita de Rama",
	["Pica"] = "Varita de Rama",
	["Relámpago"] = "Bastón de Dominio",
	["Rompeescudos"] = "Batuta de Tormenta",
	["Segadora"] = "Varita de Sellos",
	["Segadora Lunar"] = "Bastón Cero Absoluto",
	["Zarpas"] = "Varita de Té",
}

-- Índices rápidos
Config.PorNombre = {}
for i, a in Config.Armas do a.indice = i; Config.PorNombre[a.nombre] = a end
Config.CajaPorId = {}
for _, c in Config.Cajas do Config.CajaPorId[c.id] = c end
-- Cómo se consigue cada mítica fuera de las cajas (lo aplican ZeroArmasRules/ZeroWheelServer; el inventario enseña `texto`)
--   pase: la tienes mientras tengas ese pase (MonetizationConfig.Passes)   producto: Developer Product de compra única
--   invitar: la gana quien invita cuando su amigo entra por la invitación   ruleta: probabilidad extra en cada giro
Config.Obtencion = {
	-- MÍTICOS: se consiguen jugando (monedas, ruleta) o en eventos de tiempo limitado
	["Bastón Galaxia"] = { monedas = 100000, texto = "100K MONEDAS" },
	["Gatito Hechicero"] = { monedas = 140000, texto = "140K MONEDAS" },
	["Bastón del Dragón Celestial"] = { monedas = 200000, texto = "200K MONEDAS" },
	["Bastón de Halloween"] = { invitar = true, hasta = 1793682000, texto = "INVITA AMIGOS" },   -- hasta el 2 nov 2026, 23:00 CDMX
	["Bastón Cero Absoluto"] = { ruleta = 0.0002, limitado = true, texto = "RULETA 0,02%" },  -- casilla de ZeroWheelConfig; sin fecha aún
	-- EXCLUSIVOS: solo Robux, pase o evento (se irán sacando poco a poco)
	["Corona del Bufón"] = { pase = "VIP", texto = "PASE VIP" },
	["Origami Celestial"] = { pase = "ORIGAMI", texto = "R$ 399" },        -- Game Pass 2025927075
}
-- ¿Se puede conseguir ahora? (las de tiempo limitado con fecha dejan de salir al pasar `hasta`; quien la tiene se la queda)
function Config.disponible(o, ahora: number?): boolean
	return o ~= nil and (o.hasta == nil or (ahora or os.time()) < o.hasta)
end
Config.ArmaPorProducto = {}
for nombre, o in Config.Obtencion do if o.producto and o.producto ~= 0 then Config.ArmaPorProducto[o.producto] = nombre end end
Config.CajaPorProducto = {}
for _, c in Config.Cajas do if c.producto ~= 0 then Config.CajaPorProducto[c.producto] = c end end

-- Elige un arma de la caja con dos números aleatorios en [0, 1): uno para la rareza y otro para el arma.
-- ¿Puede salir en una caja? Exclusivos nunca; míticos solo los que se compran con monedas
function Config.enCajas(nombre: string): boolean
	local a = Config.PorNombre[nombre]
	if not a or a.rareza == "Exclusivo" then return false end
	if a.rareza == "Mitico" then
		local o = Config.Obtencion[nombre]
		return o ~= nil and o.monedas ~= nil and Config.disponible(o)
	end
	return true
end

function Config.tirar(caja, r1: number, r2: number): string
	local total = 0
	for _, p in caja.prob do total += p end
	local x, acumulado, rareza = r1 * total, 0, nil
	for _, nombreRareza in { "Comun", "Raro", "Especial", "Legendario", "Mitico" } do
		local p = caja.prob[nombreRareza] or 0
		if p > 0 then
			acumulado += p
			rareza = nombreRareza
			if x < acumulado then break end
		end
	end
	local opciones = {}
	for _, a in Config.Armas do if a.rareza == rareza and Config.enCajas(a.nombre) then table.insert(opciones, a.nombre) end end
	return opciones[math.clamp(math.floor(r2 * #opciones) + 1, 1, #opciones)]
end

return Config
