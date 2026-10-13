--!strict
-- ZeroMisionesConfig (ModuleScript, ReplicatedStorage): definición de las misiones de ZERO. La usan el servidor
-- (ZeroMisionesServer) y la interfaz (ZeroMisionesUI). Se reclaman a mano; los bots cuentan (con tope por ronda).
local Config = {}

-- clave = qué cuenta (la suma ZeroMisionesServer cuando pasa) · rol = "Corredor" | "Cazador" | "Cualquiera"
Config.Diarias = {
	{ id = "D1", titulo = "A LA PARTIDA", texto = "Juega 3 partidas", clave = "partidas", meta = 3, monedas = 300, rol = "Cualquiera" },
	{ id = "D2", titulo = "INTOCABLE", texto = "Sobrevive una ronda entera sin que te congelen", clave = "sobrevive_ronda", meta = 1, monedas = 500, rol = "Corredor" },
	{ id = "D3", titulo = "AYUDA AL EQUIPO", texto = "Rescata a 5 compañeros", clave = "rescates", meta = 5, monedas = 400, rol = "Corredor" },
	{ id = "D4", titulo = "CAZADOR", texto = "Congela a 8 corredores", clave = "congelados", meta = 8, monedas = 400, rol = "Cazador" },
	{ id = "D5", titulo = "GANADOR", texto = "Gana 2 rondas", clave = "victorias", meta = 2, monedas = 500, rol = "Cualquiera" },
	{ id = "D6", titulo = "VELOZ", texto = "Usa el dash 15 veces", clave = "dashes", meta = 15, monedas = 300, rol = "Corredor" },
	{ id = "D7", titulo = "AGUANTE", texto = "Sobrevive 90 s seguidos en una ronda", clave = "sobrevive90", meta = 1, monedas = 400, rol = "Corredor" },
	{ id = "D8", titulo = "HABILIDOSO", texto = "Usa tu habilidad de cazador 5 veces", clave = "habilidad", meta = 5, monedas = 300, rol = "Cazador" },
	{ id = "D9", titulo = "CONSTANTE", texto = "Juega 20 minutos", clave = "minutos", meta = 20, monedas = 400, rol = "Cualquiera" },
	{ id = "D10", titulo = "A LA SUERTE", texto = "Gira la ruleta 1 vez", clave = "ruleta", meta = 1, monedas = 200, rol = "Cualquiera" },
	{ id = "D11", titulo = "AL LÍMITE", texto = "Rescata a alguien al que le quedaban 3 s o menos", clave = "rescate_limite", meta = 1, monedas = 500, rol = "Corredor" },
	{ id = "D12", titulo = "BUEN OJO", texto = "Vota 2 veces el mapa que acabe ganando", clave = "voto_ganador", meta = 2, monedas = 300, rol = "Cualquiera" },
}
Config.BonusDiario = { titulo = "¡LAS 3 DEL DÍA!", giros = 1, monedas = 500 }

Config.Semanales = {
	{ id = "S1", titulo = "CAMPEÓN SEMANAL", texto = "Gana 15 rondas", clave = "victorias", meta = 15, monedas = 3000 },
	{ id = "S2", titulo = "SALVAVIDAS", texto = "Rescata a 40 compañeros", clave = "rescates", meta = 40, monedas = 2500 },
	{ id = "S3", titulo = "TEMPORADA DE CAZA", texto = "Congela a 60 corredores", clave = "congelados", meta = 60, monedas = 2500 },
	{ id = "S4", titulo = "SUPERVIVIENTE", texto = "Sobrevive 8 rondas enteras sin que te congelen", clave = "sobrevive_ronda", meta = 8, monedas = 3000 },
	{ id = "S5", titulo = "TROTAMUNDOS", texto = "Juega en los 3 mapas", clave = "mapas_distintos", meta = 3, monedas = 1500 },
	{ id = "S6", titulo = "SIN PARAR", texto = "Juega 30 partidas", clave = "partidas", meta = 30, monedas = 2000 },
	{ id = "S7", titulo = "COMBO", texto = "Congela a 3 corredores en menos de 20 s (3 veces)", clave = "combo", meta = 3, monedas = 3000 },
	{ id = "S8", titulo = "ÚLTIMO EN PIE", texto = "Sé el último corredor en pie 3 veces", clave = "ultimo_en_pie", meta = 3, monedas = 3000 },
	{ id = "S9", titulo = "DISCIPLINA", texto = "Completa 12 misiones diarias", clave = "diarias_completadas", meta = 12, caja = "Rara" },
}
Config.BonusSemanal = { titulo = "¡SEMANA COMPLETA!", caja = "Comun", monedas = 2000 }

-- Logros: 3 niveles; el 3.º da un título. "valor" = se compara un valor actual (no se suma).
Config.Logros = {
	{ id = "L_SUP", titulo = "SUPERVIVIENTE", texto = "Rondas sobrevividas sin ser congelado", clave = "sobrevive_ronda", metas = { 5, 25, 100 }, monedas = { 500, 2000, 8000 }, nombreTitulo = "Intocable" },
	{ id = "L_ANG", titulo = "ÁNGEL DE LA GUARDA", texto = "Rescates", clave = "rescates", metas = { 25, 150, 500 }, monedas = { 500, 2500, 10000 }, nombreTitulo = "Ángel de la Guarda" },
	{ id = "L_DEP", titulo = "DEPREDADOR", texto = "Congelados como cazador", clave = "congelados", metas = { 50, 300, 1000 }, monedas = { 500, 2500, 10000 }, nombreTitulo = "Depredador" },
	{ id = "L_CAM", titulo = "CAMPEÓN", texto = "Victorias", clave = "victorias", metas = { 10, 75, 250 }, monedas = { 800, 3000, 12000 }, nombreTitulo = "Campeón de ZERO" },
	{ id = "L_IMP", titulo = "CAZADOR IMPLACABLE", texto = "Victorias como cazador", clave = "victorias_cazador", metas = { 3, 20, 75 }, monedas = { 500, 2500, 10000 }, nombreTitulo = "Implacable" },
	{ id = "L_VET", titulo = "VETERANO", texto = "Partidas jugadas", clave = "partidas", metas = { 25, 150, 500 }, monedas = { 500, 2000, 8000 }, nombreTitulo = "Veterano" },
	{ id = "L_RAC", titulo = "RACHA", texto = "Mejor racha de victorias", clave = "mejor_racha", valor = true, metas = { 3, 7, 15 }, monedas = { 600, 2500, 10000 }, nombreTitulo = "Imparable" },
	{ id = "L_ULT", titulo = "ÚLTIMO EN PIE", texto = "Veces último corredor en pie", clave = "ultimo_en_pie", metas = { 3, 15, 50 }, monedas = { 600, 2500, 10000 }, nombreTitulo = "Último Héroe" },
	{ id = "L_COL", titulo = "COLECCIONISTA", texto = "Armas distintas conseguidas", clave = "armas", valor = true, metas = { 4, 9, 16 }, monedas = { 1000, 4000, 15000 }, nombreTitulo = "Coleccionista" },
	{ id = "L_VIA", titulo = "VIAJERO", texto = "Rondas en cada uno de los mapas", clave = "mapas_min", valor = true, metas = { 5, 25, 75 }, monedas = { 800, 3000, 8000 }, nombreTitulo = "Trotamundos" },
	{ id = "L_CON", titulo = "CONSTANCIA", texto = "Días distintos jugados", clave = "dias", valor = true, metas = { 3, 14, 30 }, monedas = { 500, 3000, 10000 }, nombreTitulo = "Leyenda de ZERO" },
}

-- Logros de primera vez (una sola recompensa)
Config.Primeras = {
	{ id = "P_PAR", titulo = "PRIMERA PARTIDA", clave = "partidas", monedas = 200 },
	{ id = "P_RES", titulo = "PRIMER RESCATE", clave = "rescates", monedas = 200 },
	{ id = "P_CON", titulo = "PRIMER CONGELADO", clave = "congelados", monedas = 200 },
	{ id = "P_VIC", titulo = "PRIMERA VICTORIA", clave = "victorias", monedas = 300 },
	{ id = "P_CAJ", titulo = "PRIMERA CAJA", clave = "cajas", monedas = 300 },
}

Config.DiariasPorDia = 3
Config.SemanalesPorSemana = 3
Config.TopeBotsPorRonda = 8         -- congelados y rescates de bots que cuentan por ronda

function Config.dia(t: number?): number return (t or os.time()) // 86400 end
function Config.semana(t: number?): number return (Config.dia(t) + 3) // 7 end   -- semanas de lunes a domingo (UTC)

Config.PorId = {}
for _, lista in { Config.Diarias, Config.Semanales, Config.Logros, Config.Primeras } do
	for _, m in lista do Config.PorId[m.id] = m end
end

return Config
