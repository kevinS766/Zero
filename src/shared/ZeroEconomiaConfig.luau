--!strict
-- ZeroEconomiaConfig (ModuleScript, ReplicatedStorage): cuánto dan las partidas y los niveles en ZERO.
-- Diseño (zero-economia/simular.py): ~1.200 monedas/h jugando a nivel 15+, el doble al empezar (bono de novato) para
-- que las primeras cajas lleguen en minutos; los míticos (100K-200K) son metas de semanas. El resto de fuentes:
-- ruleta (ZeroWheelConfig), diario y por tiempo (ZeroWheelServer), misiones y logros (ZeroMisionesConfig).
-- Lo usan ZeroEconomiaServer (paga) y ZeroEconomiaClient (aviso en pantalla).
local Config = {}

-- Monedas por ronda (se pagan juntas al acabar la ronda, en una sola escritura)
Config.Ronda = {
	participar = 20,        -- jugar la ronda entera (corredor o cazador)
	sobrevivir = 40,        -- acabar la ronda sin estar congelado
	ganarCorredor = 30,     -- los corredores ganan la ronda
	ganarCazador = 70,      -- el cazador congela a todos
	rescate = 12,           -- por cada compañero rescatado
	congelar = 10,          -- por cada corredor congelado (cazador)
	topeRescates = 6,       -- máximo de rescates que cuentan por ronda
	topeCongelados = 10,    -- máximo de congelados que cuentan por ronda
}

-- Bono de novato: progreso rápido al principio, se apaga al subir de nivel
Config.Novato = {
	{ hasta = 5, mult = 2 },        -- niveles 1-4: ×2
	{ hasta = 10, mult = 1.5 },     -- niveles 5-9: ×1,5
	{ hasta = 15, mult = 1.25 },    -- niveles 10-14: ×1,25
}
function Config.multNovato(nivel: number): number
	for _, n in Config.Novato do
		if nivel < n.hasta then return n.mult end
	end
	return 1
end

-- Al subir de nivel
function Config.premioNivel(nivel: number): (number, number)
	local monedas = 75 + 25 * nivel
	local giros = if nivel % 5 == 0 then 1 else 0
	return monedas, giros
end

-- Pases (los mismos de MonetizationConfig): 2× MONEDAS dobla lo de partidas y niveles; VIP +20 %
Config.PaseMonedas = 2
Config.BonoVIP = 0.2

return Config
