--!strict
-- Configuración de rankings y carteles de líderes en el Lobby

local LeaderboardConfig = {
	REFRESH_INTERVAL = 60, -- Segundos entre actualizaciones del ranking global
	MAX_ENTRIES = 10,       -- Cantidad de jugadores a mostrar en el top
	
	-- DataStores ordenados para consultas rápidas de Top
	STORES = {
		TOP_WINS = "Zero_LB_Wins_v1",
		TOP_HUNTERS = "Zero_LB_Hunters_v1",
	},
	
	-- Colores temáticos de podio
	COLORS = {
		RANK_1 = Color3.fromRGB(255, 215, 0),   -- Oro
		RANK_2 = Color3.fromRGB(192, 192, 192), -- Plata
		RANK_3 = Color3.fromRGB(205, 127, 50),  -- Bronce
		RANK_DEFAULT = Color3.fromRGB(220, 220, 225),
		BACKGROUND_EVEN = Color3.fromRGB(35, 35, 42),
		BACKGROUND_ODD = Color3.fromRGB(25, 25, 30),
		BACKGROUND_STROKE = Color3.fromRGB(50, 50, 60),
	},
}

return LeaderboardConfig
