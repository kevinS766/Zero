--!strict
-- ZeroTitulosConfig (ModuleScript, ReplicatedStorage): los títulos que se ven sobre la cabeza (ZeroTitulosClient).
-- Se reclaman en el menú TÍTULOS al cumplir el objetivo y se guardan con las misiones (ZeroMisiones_v1, m.titulos:
-- lista de nombres; m.titulo: el que se lleva). Los de logro (nivel 3 en ZeroMisionesConfig.Logros) también se dan al
-- cobrar ese logro.
--
-- req: lo que hay que cumplir
--   { clave = "...", meta = n }   contador de misiones (m.total): partidas, victorias, rescates, congelados, dashes,
--                                 minutos, sobrevive_ronda, ruleta, cajas, combo, ultimo_en_pie, victorias_cazador
--   { dias = n }                  días distintos jugados
--   { logro = "L_xxx" }           valor del logro ≥ su meta de nivel 3
--   { atributo = "HasPass_VIP" }  atributo del jugador (pase VIP, Pack de Inicio…)
-- estilo: colores del texto (degradado), placa (fondo y borde), fuente, icono (UI.Icons), animación y destellos
--   anim: nil | "brillo" (barrido de luz) | "pulso" (el borde respira) | "fuego" | "sombra" | "arcoiris" | "aurora"
local C3 = Color3.fromRGB
local Config = {}

Config.Rarezas = {
	Comun      = { nombre = "COMÚN",      color = C3(170, 184, 204), orden = 1 },
	Raro       = { nombre = "RARO",       color = C3(70, 170, 255),  orden = 2 },
	Epico      = { nombre = "ÉPICO",      color = C3(176, 104, 255), orden = 3 },
	Legendario = { nombre = "LEGENDARIO", color = C3(255, 196, 64),  orden = 4 },
	Mitico     = { nombre = "MÍTICO",     color = C3(255, 92, 170),  orden = 5 },
	Exclusivo  = { nombre = "EXCLUSIVO",  color = C3(64, 235, 200),  orden = 6 },
}

Config.Lista = {
	-- ---------------------------------------------------------------- comunes
	{ nombre = "Novato", rareza = "Comun", texto = "Juega tu primera partida", req = { clave = "partidas", meta = 1 },
		estilo = { texto = { C3(235, 242, 255), C3(185, 200, 225) }, placa = { C3(74, 92, 124), C3(44, 58, 86) }, borde = C3(150, 170, 205),
			fuente = "FredokaOne", icono = "stats" } },
	{ nombre = "Explorador", rareza = "Comun", texto = "Juega 15 partidas", req = { clave = "partidas", meta = 15 },
		estilo = { texto = { C3(225, 255, 210), C3(160, 225, 140) }, placa = { C3(62, 110, 72), C3(34, 70, 44) }, borde = C3(140, 210, 130),
			fuente = "DenkOne", icono = "teleport" } },
	-- ---------------------------------------------------------------- raros
	{ nombre = "Velocista", rareza = "Raro", texto = "Usa el dash 100 veces", req = { clave = "dashes", meta = 100 },
		estilo = { texto = { C3(255, 255, 255), C3(110, 230, 255) }, placa = { C3(20, 150, 220), C3(10, 70, 140) }, borde = C3(130, 235, 255),
			fuente = "Sarpanch", icono = "dash", anim = "brillo" } },
	{ nombre = "Rescatista", rareza = "Raro", texto = "Rescata a 25 compañeros", req = { clave = "rescates", meta = 25 },
		estilo = { texto = { C3(240, 255, 225), C3(140, 245, 120) }, placa = { C3(40, 165, 95), C3(16, 90, 60) }, borde = C3(160, 255, 150),
			fuente = "DenkOne", icono = "rescue", anim = "brillo" } },
	{ nombre = "Cazador", rareza = "Raro", texto = "Congela a 25 corredores", req = { clave = "congelados", meta = 25 },
		estilo = { texto = { C3(255, 235, 240), C3(255, 120, 150) }, placa = { C3(200, 40, 80), C3(110, 16, 48) }, borde = C3(255, 140, 170),
			fuente = "Bangers", icono = "hunter", anim = "brillo" } },
	{ nombre = "Fiel", rareza = "Raro", texto = "Juega 7 días distintos", req = { dias = 7 },
		estilo = { texto = { C3(255, 255, 255), C3(170, 215, 255) }, placa = { C3(70, 120, 230), C3(36, 60, 150) }, borde = C3(180, 215, 255),
			fuente = "Fondamento", icono = "daily", anim = "brillo" } },
	-- ---------------------------------------------------------------- épicos
	{ nombre = "Afortunado", rareza = "Epico", texto = "Gira la ruleta 30 veces", req = { clave = "ruleta", meta = 30 },
		estilo = { texto = { C3(255, 250, 190), C3(255, 205, 60) }, placa = { C3(30, 170, 90), C3(12, 90, 50) }, borde = C3(255, 220, 90),
			fuente = "LuckiestGuy", icono = "wheel", anim = "brillo", destellos = C3(255, 235, 140) } },
	{ nombre = "Abrecajas", rareza = "Epico", texto = "Abre 25 cajas de armas", req = { clave = "cajas", meta = 25 },
		estilo = { texto = { C3(255, 230, 190), C3(255, 150, 70) }, placa = { C3(150, 70, 230), C3(80, 30, 140) }, borde = C3(255, 170, 90),
			fuente = "LuckiestGuy", icono = "crate_epic", anim = "pulso" } },
	{ nombre = "Maratonista", rareza = "Epico", texto = "Juega 10 horas", req = { clave = "minutos", meta = 600 },
		estilo = { texto = { C3(240, 225, 255), C3(185, 140, 255) }, placa = { C3(70, 40, 160), C3(30, 16, 90) }, borde = C3(200, 160, 255),
			fuente = "Michroma", icono = "time", anim = "pulso" } },
	{ nombre = "Ganador Nato", rareza = "Epico", texto = "Gana 50 rondas", req = { clave = "victorias", meta = 50 },
		estilo = { texto = { C3(255, 250, 220), C3(255, 190, 60) }, placa = { C3(235, 120, 30), C3(150, 50, 16) }, borde = C3(255, 220, 120),
			fuente = "LuckiestGuy", icono = "crate_legendary", anim = "brillo", destellos = C3(255, 220, 120) } },
	-- ---------------------------------------------------------------- legendarios
	{ nombre = "Sombra", rareza = "Legendario", texto = "Sobrevive 50 rondas sin que te congelen", req = { clave = "sobrevive_ronda", meta = 50 },
		estilo = { texto = { C3(225, 200, 255), C3(140, 60, 255) }, placa = { C3(30, 10, 50), C3(6, 2, 14) }, borde = C3(160, 80, 255),
			fuente = "Creepster", icono = "spectate", anim = "sombra", destellos = C3(190, 120, 255) } },
	{ nombre = "Rey del Caos", rareza = "Legendario", texto = "Congela a 3 corredores en 20 s, 10 veces", req = { clave = "combo", meta = 10 },
		estilo = { texto = { C3(255, 250, 200), C3(255, 120, 30) }, placa = { C3(200, 40, 10), C3(90, 10, 0) }, borde = C3(255, 170, 40),
			fuente = "Bangers", icono = "hunter", anim = "fuego", destellos = C3(255, 200, 80) } },
	{ nombre = "Héroe", rareza = "Legendario", texto = "Sé el último corredor en pie 10 veces", req = { clave = "ultimo_en_pie", meta = 10 },
		estilo = { texto = { C3(255, 255, 255), C3(255, 215, 110) }, placa = { C3(30, 70, 160), C3(10, 26, 70) }, borde = C3(255, 220, 120),
			fuente = "GrenzeGotisch", icono = "rescue", anim = "brillo", destellos = C3(255, 240, 180) } },
	-- ---------------------------------------------------------------- mítico
	{ nombre = "Leyenda Viva", rareza = "Mitico", texto = "Gana 300 rondas", req = { clave = "victorias", meta = 300 },
		estilo = { texto = { C3(255, 255, 255), C3(255, 255, 255) }, placa = { C3(40, 20, 70), C3(14, 6, 30) }, borde = C3(255, 255, 255),
			fuente = "LuckiestGuy", icono = "vip", anim = "arcoiris", destellos = C3(255, 255, 255) } },
	-- ---------------------------------------------------------------- exclusivos
	{ nombre = "VIP", rareza = "Exclusivo", texto = "Incluido en el pase VIP", req = { atributo = "HasPass_VIP" },
		estilo = { texto = { C3(255, 252, 215), C3(255, 190, 40) }, placa = { C3(60, 40, 10), C3(24, 14, 2) }, borde = C3(255, 205, 70),
			fuente = "Michroma", icono = "vip", anim = "brillo", destellos = C3(255, 225, 120) } },
	{ nombre = "Pionero", rareza = "Exclusivo", texto = "Incluido en el Pack de Inicio", req = { atributo = "PackInicio" },
		estilo = { texto = { C3(255, 255, 255), C3(255, 255, 255) }, placa = { C3(20, 50, 80), C3(8, 18, 40) }, borde = C3(120, 255, 230),
			fuente = "LuckiestGuy", icono = "pack", anim = "aurora", destellos = C3(160, 255, 235) } },
	-- ---------------------------------------------------------------- de logros (nivel 3)
	{ nombre = "Intocable", rareza = "Legendario", texto = "Logro SUPERVIVIENTE nivel 3", req = { logro = "L_SUP" },
		estilo = { texto = { C3(235, 255, 255), C3(120, 230, 255) }, placa = { C3(10, 80, 110), C3(4, 30, 50) }, borde = C3(150, 240, 255),
			fuente = "Sarpanch", icono = "dash", anim = "brillo", destellos = C3(180, 245, 255) } },
	{ nombre = "Ángel de la Guarda", rareza = "Legendario", texto = "Logro ÁNGEL DE LA GUARDA nivel 3", req = { logro = "L_ANG" },
		estilo = { texto = { C3(255, 255, 255), C3(255, 235, 170) }, placa = { C3(140, 170, 220), C3(70, 90, 150) }, borde = C3(255, 245, 200),
			fuente = "Fondamento", icono = "rescue", anim = "brillo", destellos = C3(255, 250, 220) } },
	{ nombre = "Depredador", rareza = "Legendario", texto = "Logro DEPREDADOR nivel 3", req = { logro = "L_DEP" },
		estilo = { texto = { C3(255, 220, 220), C3(255, 50, 60) }, placa = { C3(50, 6, 10), C3(16, 0, 2) }, borde = C3(255, 60, 70),
			fuente = "Creepster", icono = "hunter", anim = "pulso", destellos = C3(255, 90, 90) } },
	{ nombre = "Campeón de ZERO", rareza = "Legendario", texto = "Logro CAMPEÓN nivel 3", req = { logro = "L_CAM" },
		estilo = { texto = { C3(255, 255, 230), C3(255, 200, 50) }, placa = { C3(190, 120, 10), C3(110, 50, 0) }, borde = C3(255, 235, 130),
			fuente = "LuckiestGuy", icono = "vip", anim = "brillo", destellos = C3(255, 230, 120) } },
	{ nombre = "Implacable", rareza = "Legendario", texto = "Logro CAZADOR IMPLACABLE nivel 3", req = { logro = "L_IMP" },
		estilo = { texto = { C3(255, 240, 255), C3(255, 80, 200) }, placa = { C3(90, 10, 70), C3(30, 0, 24) }, borde = C3(255, 110, 220),
			fuente = "Bangers", icono = "hunter", anim = "fuego", destellos = C3(255, 140, 230) } },
	{ nombre = "Veterano", rareza = "Legendario", texto = "Logro VETERANO nivel 3", req = { logro = "L_VET" },
		estilo = { texto = { C3(255, 245, 225), C3(220, 175, 120) }, placa = { C3(100, 70, 40), C3(46, 30, 14) }, borde = C3(235, 195, 140),
			fuente = "GrenzeGotisch", icono = "stats", anim = "pulso" } },
	{ nombre = "Imparable", rareza = "Legendario", texto = "Logro RACHA nivel 3", req = { logro = "L_RAC" },
		estilo = { texto = { C3(255, 255, 210), C3(255, 140, 20) }, placa = { C3(170, 30, 20), C3(80, 6, 4) }, borde = C3(255, 200, 60),
			fuente = "Bangers", icono = "dash", anim = "fuego", destellos = C3(255, 210, 90) } },
	{ nombre = "Último Héroe", rareza = "Legendario", texto = "Logro ÚLTIMO EN PIE nivel 3", req = { logro = "L_ULT" },
		estilo = { texto = { C3(255, 255, 255), C3(200, 225, 255) }, placa = { C3(20, 30, 60), C3(4, 8, 22) }, borde = C3(210, 230, 255),
			fuente = "GrenzeGotisch", icono = "rescue", anim = "sombra", destellos = C3(220, 235, 255) } },
	{ nombre = "Coleccionista", rareza = "Legendario", texto = "Logro COLECCIONISTA nivel 3", req = { logro = "L_COL" },
		estilo = { texto = { C3(255, 240, 255), C3(220, 150, 255) }, placa = { C3(110, 40, 170), C3(46, 12, 90) }, borde = C3(255, 200, 90),
			fuente = "LuckiestGuy", icono = "crate_legendary", anim = "brillo", destellos = C3(255, 220, 120) } },
	{ nombre = "Trotamundos", rareza = "Legendario", texto = "Logro VIAJERO nivel 3", req = { logro = "L_VIA" },
		estilo = { texto = { C3(240, 255, 245), C3(110, 255, 190) }, placa = { C3(10, 110, 110), C3(4, 46, 60) }, borde = C3(140, 255, 210),
			fuente = "DenkOne", icono = "teleport", anim = "aurora" } },
	{ nombre = "Leyenda de ZERO", rareza = "Mitico", texto = "Logro CONSTANCIA nivel 3", req = { logro = "L_CON" },
		estilo = { texto = { C3(255, 255, 255), C3(255, 255, 255) }, placa = { C3(10, 10, 20), C3(0, 0, 0) }, borde = C3(255, 255, 255),
			fuente = "Michroma", icono = "key", anim = "arcoiris", destellos = C3(255, 255, 255) } },
}

Config.PorNombre = {}
for i, t in Config.Lista do t.orden = i; Config.PorNombre[t.nombre] = t end

-- Fuente con respaldo (por si alguna no existe en el cliente)
function Config.fuente(nombre: string?): Enum.Font
	local ok, f = pcall(function() return (Enum.Font :: any)[nombre or "FredokaOne"] end)
	return ok and f or Enum.Font.FredokaOne
end

return Config
