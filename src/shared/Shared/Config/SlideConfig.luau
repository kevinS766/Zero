--!strict
-- SlideConfig (ModuleScript, ReplicatedStorage.Shared.Config): deslizamiento con la C (ZeroSlideClient / ZeroSlideServer).
local SlideConfig = {
	-- duración del deslizamiento (segundos); la animación Slide de ZeroMovement dura lo mismo que el atributo
	DURATION = 1.0,

	-- recarga entre deslizamientos (segundos)
	COOLDOWN = 1.3,

	-- velocidad mínima (studs/s) para poder deslizarse: hay que ir corriendo
	MIN_SPEED = 9,

	-- arranque: la mayor entre esta velocidad y la actual × BOOST; frena hasta END_FACTOR × WalkSpeed.
	-- Recorrido aprox. (ease-out): v0·t − (v0 − vfin)·t·2/3 → ~26 studs desde andar, ~30 esprintando (antes ~17)
	START_SPEED = 46,
	BOOST = 1.75,
	END_FACTOR = 1.0,

	-- cuánto se puede corregir la dirección mientras se desliza (más alto = más control)
	STEER = 2.5,

	-- fuerza horizontal máxima del LinearVelocity (la vertical queda libre: cae por rampas y bordes)
	MAX_FORCE = 60000,
}

return table.freeze(SlideConfig)
