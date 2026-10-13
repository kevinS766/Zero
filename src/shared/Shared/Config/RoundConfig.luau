--!strict
local RoundConfig = {
	-- Jugadores mínimos requeridos para pasar de WAITING a INTERMISSION
	MIN_PLAYERS = 2,

	-- Duración en segundos de la cuenta regresiva antes de la ronda
	INTERMISSION_DURATION = 15,

	-- Duración fija de la ronda activa (en segundos)
	ROUND_DURATION = 180,

	-- Tiempo de celebración/reinicio en ROUND_END antes de volver al lobby
	ROUND_END_DURATION = 8,

	-- UserIds autorizados a ejecutar comandos de debug en servidores live (además de Studio)
	ADMIN_USER_IDS = {
		-- Añade aquí tu UserId si quieres probar en juego publicado
	} :: { number },

	-- Plataforma provisional de espera para el Hunter durante INTERMISSION
	HUNTER_PLATFORM_POSITION = Vector3.new(0, 300, 600),
	HUNTER_PLATFORM_SIZE = Vector3.new(64, 2, 64),
}

return table.freeze(RoundConfig)
