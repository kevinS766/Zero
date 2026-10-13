-- ZeroHabilidadesConfig (ModuleScript, ReplicatedStorage): habilidad de la tecla E del cazador según la RAREZA del arma
-- equipada (ZeroArmasConfig). Cada rareza tiene su mecánica (módulo en ReplicatedStorage.VFX) y cada arma de esa rareza
-- su propia skin del mismo ataque. Lo leen ZeroHabilidadArmaServer y ZeroHabilidadArmaClient.
-- Se irán añadiendo rarezas (Común, Especial, Legendario) y la categoría de exclusivos, una a una.
local ArmasConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("ZeroArmasConfig"))

local Config = {}

Config.Rarezas = {
	-- Común: mantener la E carga una bola en la varita (hasta 'carga' s); al soltar sale en arco y en el impacto ralentiza a
	-- los corredores del área (radioMin..radioMax según la carga) a 'lento' de su velocidad durante lentoMin..lentoMax s
	Comun = { modulo = "Bola", nombre = "BOLA", cooldown = 9, alcance = 55, carga = 1.4, radioMin = 4, radioMax = 10,
		lento = 0.5, lentoMin = 2, lentoMax = 3.5 },
	Raro = { modulo = "Rafaga", nombre = "RÁFAGA", cooldown = 20, alcance = 40, radio = 8, aturdir = 1.5 },
	-- Épico (clave "Especial"): zona de 'duracion' s; quien esté dentro o entre queda cegado 'cegar' s
	Especial = { modulo = "Vortice", nombre = "CEGUERA", cooldown = 22, alcance = 45, radio = 10, duracion = 2.5, cegar = 3 },
	-- Legendario: teletransporte al punto apuntado (hay que verlo) tras un aviso; aturde 'aturdir' s en 'radio' al llegar
	Legendario = { modulo = "Salto", nombre = "SALTO", cooldown = 25, alcance = 45, radio = 6, aturdir = 0.5 },
	-- Mítico: un dragón sale del suelo delante del cazador y recorre una recta de 'alcance' studs hacia donde apunta, entrando
	-- y saliendo del suelo; los corredores que toca (franja de 'ancho') y los que estén a 'radioFinal' del pilar final salen
	-- lanzados y quedan CONGELADOS (como con el cuchillo)
	Mitico = { modulo = "Dragon", nombre = "DRAGÓN", cooldown = 30, alcance = 70, ancho = 8, radioFinal = 12 },
}

-- arma -> skin del módulo de su rareza
Config.Skins = {
	["Varita de Rama"] = "Nieve",
	["Varita de Tiza"] = "Tiza",
	["Lápiz Mágico"] = "Lapiz",
	["Batuta de Tormenta"] = "Tormenta",
	["Varita Estelar"] = "Estelar",
	["Varita de Té"] = "Te",
	["Cetro Lunar Kawaii"] = "Lunar",
	["Varita de Sellos"] = "Sellos",
	["Linterna Espiritual"] = "Espiritual",
	["Bastón Reloj de Arena"] = "Reloj",
	["Bastón del Grimorio"] = "Grimorio",
	["Bastón de Dominio"] = "Dominio",
	["Bastón del Dragón Celestial"] = "Celestial",
	["Bastón Galaxia"] = "Cosmica",
	["Bastón Cero Absoluto"] = "Fenix",
	["Bastón de Halloween"] = "Ciempies",
	["Gatito Hechicero"] = "GatoAstral",
}

local rareza = {}
for _, a in ArmasConfig.Armas do rareza[a.nombre] = a.rareza end

-- habilidad y skin del arma (nil si su rareza aún no tiene habilidad o el arma aún no tiene skin)
function Config.de(arma: string?)
	local hab = arma and Config.Rarezas[rareza[arma]]
	if not hab or not Config.Skins[arma :: string] then return nil, nil end
	return hab, Config.Skins[arma :: string]
end

-- en la arena de pruebas (ServerScriptService.ZeroPruebas) se usa el arma elegida en su panel, la tengas o no
function Config.armaDe(player: Player): string
	if player:GetAttribute("ZeroPruebas") then return player:GetAttribute("ZeroPruebaArma") or player:GetAttribute("ArmaEquipada") or ArmasConfig.ArmaInicial end
	return player:GetAttribute("ArmaEquipada") or ArmasConfig.ArmaInicial
end

return Config
