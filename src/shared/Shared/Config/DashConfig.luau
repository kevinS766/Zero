--!strict
local DashConfig = {
	-- Recarga por dirección (segundos): adelante es el que más ayuda a huir (el más largo); a los lados, el de esquivar
	COOLDOWNS = { Frente = 7.0, Atras = 5.0, Lados = 3.5 },
	COOLDOWN = 7.0,   -- la más larga (compatibilidad)

	-- Duración activa del impulso físico (segundos)
	DURATION = 0.2,

	-- Velocidad del impulso en studs/segundo
	SPEED = 65,

	-- Fuerza máxima aplicada por el LinearVelocity
	MAX_FORCE = 100000,
}

-- "Frente" | "Atras" | "Lados" según hacia dónde va el dash respecto a donde mira el personaje (la misma regla que
-- ZeroMovement usa para elegir la animación DashFront/DashBack/DashLeft/DashRight)
function DashConfig.tipo(look: Vector3, dir: Vector3): string
	local f = Vector3.new(look.X, 0, look.Z)
	if f.Magnitude < 1e-3 then return "Frente" end
	f = f.Unit
	local delante, lado = f:Dot(dir), f:Cross(Vector3.yAxis):Dot(dir)
	if math.abs(lado) > math.abs(delante) then return "Lados" end
	return if delante >= 0 then "Frente" else "Atras"
end

return table.freeze(DashConfig)
