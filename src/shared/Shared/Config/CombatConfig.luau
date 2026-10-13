--!strict
local CombatConfig = {
	-- Tiempo mínimo entre ataques (segundos)
	ATTACK_COOLDOWN = 1.2,

	-- Rango máximo de impacto en studs (de centro a centro; antes 6, se quedaba corto con armas largas)
	ATTACK_RANGE = 8.5,

	-- Ángulo frontal máximo en radianes (math.rad(80) da un cono frontal de 160 grados)
	ATTACK_MAX_ANGLE_RAD = math.rad(80),

	-- Diferencia de altura máxima entre Hunter y objetivo
	ATTACK_HEIGHT = 7,

	-- Studs extra que se aceptan cuando el cliente señala al objetivo (compensa el lag de posiciones)
	LAG_TOLERANCE = 4,

	-- Dimensiones de la caja de Spatial Query (X, Y, Z) centrada al frente del Hunter
	ATTACK_BOX_SIZE = Vector3.new(6, 6, 6),
}

return table.freeze(CombatConfig)
