-- Dragon (ModuleScript, ReplicatedStorage.VFX): habilidad de rareza MÍTICO de ZERO (tecla E, cazador): dragón en línea recta.
-- Referencia: C:/Users/Joshua/Downloads/VFX SHOWCASE Thunder Dragon.mp4 y el concepto de ChatGPT "Genera hoja diseño dragón".
--   AVISO (Dragon.AVISO s): el cazador alza el brazo y delante de él se abre un portal en el suelo que se agrieta, con rayos
--   y piedras que tiemblan (los corredores lo ven venir).
--   RECORRIDO: el dragón revienta el suelo y avanza en línea recta "como un delfín": sale en arco, se zambulle en el suelo,
--   corre por debajo levantando grietas y vuelve a salir (3 arcos). Cada vez que entra o sale: cráter con losas de roca que
--   se levantan, rocas por el aire, polvo, rayos y un BOOM con temblor. Va envuelto en rayos y nubes, con una perla de luz
--   delante de la boca.
--   FINAL: tras la última zambullida, fogonazo en pantalla y un pilar de energía gigante que cambia de color, con zarcillos
--   oscuros, rayos, anillos y una onda; la pantalla de quien está cerca se oscurece un momento.
--   Los corredores que alcanza la cabeza (franja de 'ancho') salen lanzados y quedan CONGELADOS, y también los que estén en
--   el radio del pilar final (lo decide el servidor con PlayerStateService.freezeRunner).
--   Mismo ataque para los 5 bastones míticos; cada skin trae su criatura, sus efectos, sus colores y sus sonidos:
--   Celestial  (Bastón del Dragón Celestial)  dragón de jade con cuernos de oro, melena blanca, rayos cian y nubes
--   Cosmica    (Bastón Galaxia)               ballena cósmica de nebulosa con estrellas; aletas que reman
--   Fenix      (Bastón Cero Absoluto)         fénix de cristal de hielo que aletea; copos, escarcha y losas de hielo
--   Ciempies   (Bastón de Halloween)          ciempiés gigante de huesos con fuego morado; murciélagos y niebla verde
--   GatoAstral (Gatito Hechicero)             espíritu de gato gigante con sombrero de bruja que corre a saltos
-- Modelos: ReplicatedStorage.ZeroHabilidades.Proyectiles.<Dragon*|Ballena*|Fenix*|Jinete*|Gato*> (zero-habilidades/mitico/
-- scripts/dragon.py y criaturas.py; pivote: LookVector = hacia la cabeza, UpVector = lomo). Texturas: mitico/texturas*.py.
-- Versión anterior (sale una vez y sube al cielo): zero-habilidades/roblox/antes/Dragon_v1.luau.
--
--   Dragon.ruta(origen, objetivo, alcance, personaje, skin) -> ruta  camino (servidor y cliente calculan el mismo)
--   Dragon.cuando(ruta, a) -> s                                    cuándo pasa la cabeza a 'a' studs del portal por la recta
--   Dragon.final(ruta) -> (posición, s)                            dónde y cuándo estalla el pilar final
--   Dragon.Play(personaje, objetivo, inicio?, origen?, skin?)      cliente
--   Dragon.aturdido(personaje, skin, duracion)                    impacto al congelar: nube de jade sobre la cabeza y chispazos
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Rafaga = require(script.Parent:WaitForChild("Rafaga"))
local U = Rafaga.U
local T = Rafaga.TEX

local Dragon = {}

local TEX = {
	roca = "rbxassetid://121613260302777", nube = "rbxassetid://114113378299931",
	grieta = "rbxassetid://75415991164651", portal = "rbxassetid://136145156848869", chorro = "rbxassetid://138312569092787",
	copo = "rbxassetid://119079964682493", murcielago = "rbxassetid://103413504217388", huella = "rbxassetid://84952068563536",
	llama = "rbxassetid://74665856288354", calabaza = "rbxassetid://133298053102463", fantasma = "rbxassetid://95187442525009",
	portal_galaxia = "rbxassetid://85013632371324", portal_hielo = "rbxassetid://98922563033522",
	portal_halloween = "rbxassetid://90593676819376", portal_gato = "rbxassetid://99070915982374",
}
local SFX = {
	rugido = "rbxassetid://9113985604", trueno = "rbxassetid://9126082854", truenoGrande = "rbxassetid://9120016037",
	retumbe = "rbxassetid://9112775181", rocas = "rbxassetid://9118691819",
	boom = "rbxassetid://9114224721", boom2 = "rbxassetid://9114224354", avalancha = "rbxassetid://9113217388",
	subBoom = "rbxassetid://9119661511", boomFinal = "rbxassetid://1843025832",
	ballena = "rbxassetid://123987752396522", campanillas = "rbxassetid://9119447936", ave = "rbxassetid://9117889959",
	hielo = "rbxassetid://9114858583", risa = "rbxassetid://112900106445164", espiritu = "rbxassetid://9125988961",
	galope = "rbxassetid://159005189", maullido = "rbxassetid://113569616857675", chillido = "rbxassetid://9125474505",
	coroFantasmas = "rbxassetid://9125440141", murcielagos = "rbxassetid://9125386815", aullido = "rbxassetid://9120790529",
	campana = "rbxassetid://9113804436", cadenas = "rbxassetid://9113763589", bruja = "rbxassetid://130665625557386",
}
Dragon.TEX, Dragon.SFX = TEX, SFX

-- ------------------------------------------------------------------ ajustes
Dragon.ESCALA = 1                 -- velocidad del tiempo (pruebas a cámara lenta)
Dragon.AVISO = 0.55               -- portal abierto antes de que salga la cabeza
Dragon.VEL = 50                   -- studs/s de la cabeza
local PORTAL = 6                  -- el portal está a 6 studs delante del cazador
-- arcos sobre el suelo, en fracciones del alcance: { sale, entra, altura }
local ARCOS = { { 0, 0.3, 11 }, { 0.44, 0.68, 10 }, { 0.8, 1, 14 } }
local HONDO = 9                   -- profundidad bajo tierra entre arcos
local PILAR = 1.6                 -- duración del pilar final
local BLANCO = Color3.new(1, 1, 1)
local function C(h: string): Color3 return Color3.fromHex(h) end
local function B(x: number, y: number, z: number): Vector3 return Vector3.new(x, z, -y) end   -- Blender (x, y, z) -> local de Roblox

-- piezas que siguen el camino: { modelo, s = distancia a la cabeza, k = escala, dy = altura sobre el eje } (unidades de Blender;
-- se multiplican por skin.tam). adjuntos: piezas pegadas a un tramo con articulación animada (alas, aletas, patas):
-- { modelo, base = tramo, junta = articulación respecto al centro del tramo, desde = centro de la pieza respecto a la junta,
--   anim = "aleteo" | "aleta" | "galope", espejo (el lado izquierdo: misma pieza girada 180° sobre el eje de avance), fase }
local function piezasDragon()
	local nombres = { "Cabeza", "Cuerpo", "Pata", "Cuerpo", "Cuerpo", "Cuerpo", "Cuerpo", "Pata", "Cuerpo", "Cuerpo", "Cuerpo", "Cuerpo", "Cuerpo", "Cola" }
	local l, s = {}, 0
	for i, n in nombres do
		local k = if i <= 2 then 1 else 1 - 0.42 * (i - 2) / (#nombres - 2)
		l[i] = { modelo = "Dragon" .. n, s = s, k = k }
		s += if i == 1 then 3.3 else 2.2 * k
	end
	return l
end
-- ciempiés: cráneo, 10 vértebras con las patas alternadas (adelante/atrás, parece que camina) y la cola con aguijón
local function piezasCiempies()
	local l = { { modelo = "CiempiesCabeza", s = 0, k = 1, dy = -1.15 } }
	local s = 3.65
	for i = 1, 10 do
		local k = 1 - 0.3 * (i - 1) / 9
		table.insert(l, { modelo = if i % 2 == 1 then "CiempiesTramoA" else "CiempiesTramoB", s = s, k = k })
		s += 1.95 * k
	end
	table.insert(l, { modelo = "CiempiesCola", s = s + 0.4, k = 0.7, dy = 0.2 })
	return l
end
local function patas(modelo: string, juntas: { Vector3 }, desde: Vector3)
	local l = {}
	for i, j in juntas do table.insert(l, { modelo = modelo, base = 1, junta = j, desde = desde, anim = "galope", fase = ({ 0, 0.5, math.pi, math.pi + 0.5 })[i] }) end
	return l
end

local SKINS = {
	-- Bastón del Dragón Celestial: dragón de jade con cuernos de oro, rayos cian y nubes
	Celestial = { tam = 2, piezas = piezasDragon(), adjuntos = {}, onda = { lat = 1.2, ver = 0.35 }, bote = 0,
		perla = true, arcos = true, zap = true, portal = TEX.portal, grieta = BLANCO, chispa = T.rayo, sprite = TEX.nube,
		c1 = C("#E8FFFA"), c2 = C("#5FE8C8"), c3 = C("#1E8F78"), oro = C("#FFC84A"), polvo = C("#8C919B"), oscuro = C("#04100E"),
		losas = { Enum.Material.Slate, { "#4A4239", "#5C534A", "#615548" } },
		pilar = { C("#FFFFFF"), C("#FFE08A"), C("#5FE8C8"), C("#2FB8FF"), C("#123C66") },
		voz = { SFX.rugido, 1.2, 0.85 } },
	-- Bastón Galaxia: ballena cósmica de nebulosa y estrellas
	Cosmica = { tam = 1.6, onda = { lat = 0.25, ver = 0.4 }, bote = 0, portal = TEX.portal_galaxia, grieta = C("#C9A0FF"),
		chispa = T.estrella, sprite = T.estrella,
		-- tramos muy solapados (2,3 de separación para 3,2 de largo) para que el cuerpo no se abra al doblarse en los arcos
		piezas = { { modelo = "BallenaCabeza", s = 0, k = 1 }, { modelo = "BallenaCuerpo", s = 3.5, k = 1 }, { modelo = "BallenaCuerpo", s = 5.8, k = 0.95 },
			{ modelo = "BallenaCuerpo", s = 8.0, k = 0.88 }, { modelo = "BallenaCuerpo", s = 10.0, k = 0.8 }, { modelo = "BallenaCola", s = 12.4, k = 0.75, dy = 0.3 } },
		adjuntos = { { modelo = "BallenaAleta", base = 2, junta = B(1.05, 0.55, -0.4473), desde = B(1.0816, -0.425, -0.5751), anim = "aleta" },
			{ modelo = "BallenaAleta", base = 2, junta = B(-1.05, 0.55, -0.4473), desde = B(1.0816, -0.425, -0.5751), anim = "aleta", espejo = true } },
		c1 = C("#FFF1C4"), c2 = C("#8A5CFF"), c3 = C("#FF7AD9"), oro = C("#FFC857"), polvo = C("#7C7A9A"), oscuro = C("#0A0820"),
		losas = { Enum.Material.Slate, { "#3A3550", "#4A4466", "#2E2A44" } },
		pilar = { C("#FFFFFF"), C("#FFE08A"), C("#FF9A3C"), C("#D26BFF"), C("#1A1650") },
		voz = { SFX.ballena, 1.5, 1 }, acento = { SFX.campanillas, 0.7, 1.1 } },
	-- Bastón Cero Absoluto: fénix de cristal de hielo
	Fenix = { tam = 1.8, onda = { lat = 0.25, ver = 0.2 }, bote = 0.12, portal = TEX.portal_hielo, grieta = C("#BFF4FF"),
		chispa = TEX.copo, sprite = TEX.copo,
		piezas = { { modelo = "FenixCuerpo", s = 0, k = 1 }, { modelo = "FenixCola", s = 3.17, k = 1 }, { modelo = "FenixCola", s = 5.17, k = 0.85 },
			{ modelo = "FenixCola", s = 6.87, k = 0.7 } },
		adjuntos = { { modelo = "FenixAla", base = 1, junta = B(0.55, -0.0204, 0.3334), desde = B(2.5909, -1.0626, 0.1062), anim = "aleteo" },
			{ modelo = "FenixAla", base = 1, junta = B(-0.55, -0.0204, 0.3334), desde = B(2.5909, -1.0626, 0.1062), anim = "aleteo", espejo = true } },
		c1 = C("#E8FBFF"), c2 = C("#6FD6FF"), c3 = C("#2E7BD6"), oro = C("#BFF4FF"), polvo = C("#B8D8E8"), oscuro = C("#06142A"),
		losas = { Enum.Material.Ice, { "#BFEFFF", "#8FDFFF", "#DFF8FF" }, 0.1 },
		pilar = { C("#FFFFFF"), C("#CFF8FF"), C("#6FD6FF"), C("#2F7BFF"), C("#0B1F4A") },
		voz = { SFX.ave, 1.3, 1.15 }, acento = { SFX.hielo, 1.1, 1 } },
	-- Bastón de Halloween: ciempiés gigante de huesos con fuego morado dentro de las costillas y ojos de fuego verde
	Ciempies = { tam = 1.8, onda = { lat = 1.0, ver = 0.3 }, bote = 0, portal = TEX.portal_halloween, grieta = C("#D08AFF"),
		chispa = TEX.llama, sprite = TEX.murcielago, colaTex = TEX.llama, piezas = piezasCiempies(), adjuntos = {},
		c1 = C("#E9D2FF"), c2 = C("#B05CFF"), c3 = C("#5FE07A"), oro = C("#FF8A1F"), polvo = C("#6A5A7A"), oscuro = C("#0A0612"),
		losas = { Enum.Material.Slate, { "#2E2633", "#3D3344", "#4A3E52" } },
		pilar = { C("#FFFFFF"), C("#9CFF9C"), C("#5FE07A"), C("#B05CFF"), C("#1C0E2C") },
		voz = { SFX.chillido, 1.4, 0.8 }, acento = { SFX.espiritu, 1, 1 }, bucle = { SFX.rocas, 0.7, 1.4 }, halloween = true },
	-- Gatito Hechicero: espíritu de gato gigante con sombrero de bruja
	GatoAstral = { tam = 2, onda = { lat = 0.3, ver = 0.15 }, bote = 0.3, transparencia = 0.15, portal = TEX.portal_gato, grieta = C("#FFD6F0"),
		chispa = T.estrella, sprite = TEX.huella,
		piezas = { { modelo = "GatoCuerpo", s = 0, k = 1 }, { modelo = "GatoCola", s = 3.27, k = 1, dy = -1.04 }, { modelo = "GatoCola", s = 5.27, k = 0.9, dy = -0.84 },
			{ modelo = "GatoCola", s = 7.07, k = 0.8, dy = -0.64 } },
		adjuntos = patas("GatoPata", { B(0.45, 0.235, -1.5484), B(-0.45, 0.235, -1.5484), B(0.48, -1.815, -1.5984), B(-0.48, -1.815, -1.5984) },
			B(0.0108, 0.1132, -0.6274)),
		c1 = C("#FFF4C2"), c2 = C("#B48CFF"), c3 = C("#FF9AD5"), oro = C("#FFC93A"), polvo = C("#8A7AA8"), oscuro = C("#12062A"),
		losas = { Enum.Material.Slate, { "#5B4A80", "#6E5C99", "#4A3B6B" } },
		pilar = { C("#FFFFFF"), C("#FFE27A"), C("#FF9AD5"), C("#B48CFF"), C("#2A1060") },
		voz = { SFX.maullido, 1.5, 0.75 }, acento = { SFX.campanillas, 0.8, 1.3 } },
}
for n, s in SKINS do
	s.nombre = n
	s.largo = s.piezas[#s.piezas].s * s.tam                       -- de la cabeza a la cola (studs)
end
Dragon.SKINS = SKINS

-- efectos pegados al cuerpo de cada skin: chispas en unos tramos, rastro que se queda atrás y algo en la cola
local function efectosCuerpo(skin, i: number, sg, n: number): { { tex: string, props: any } }
	local TAM = skin.tam
	local l = {}
	local function chispas(rate: number, tam: number)
		table.insert(l, { tex = skin.chispa, props = { Rate = rate, Lifetime = NumberRange.new(0.08, 0.16), Size = U.seq(tam, tam * 0.6), Transparency = U.seq(0, 0.5),
			Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), LockedToPart = true, ZOffset = 1 } })
	end
	local nombre = skin.nombre
	if nombre == "Celestial" then
		if i % 2 == 0 then chispas(9, 3.2 * sg.k * TAM / 2) end
		if i % 3 == 1 and i > 1 then
			table.insert(l, { tex = TEX.nube, props = { Rate = 5, Lifetime = NumberRange.new(0.7, 1.1), Size = U.seq(1.3 * TAM, 2.6 * TAM), Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.5), NumberSequenceKeypoint.new(1, 1) }), Speed = NumberRange.new(1, 3),
				SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(-20, 20), RotSpeed = NumberRange.new(-20, 20),
				Color = ColorSequence.new(BLANCO, skin.c2), LightEmission = 0.25, LightInfluence = 0.5 } })
		end
	elseif nombre == "Cosmica" then
		table.insert(l, { tex = T.estrella, props = { Rate = 5, Lifetime = NumberRange.new(0.3, 0.5), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 1.3), NumberSequenceKeypoint.new(1, 0) }), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
			Color = ColorSequence.new(skin.c1, skin.oro), LockedToPart = true, ZOffset = 1 } })
		table.insert(l, { tex = T.vapor, props = { Rate = 7, Lifetime = NumberRange.new(0.9, 1.3), Size = U.seq(1.6 * TAM, 3.2 * TAM), Transparency = U.seq(0.45, 1),
			Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
			Color = ColorSequence.new(skin.c2, skin.c3), LightEmission = 0.8, LightInfluence = 0 } })
		if i % 2 == 1 then
			table.insert(l, { tex = T.purpurina, props = { Rate = 14, Lifetime = NumberRange.new(0.8, 1.3), Size = U.seq(0.7, 0.1), Transparency = U.seq(0, 1),
				Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -4, 0), Color = ColorSequence.new(skin.c1, skin.oro) } })
		end
	elseif nombre == "Fenix" then
		chispas(5, 1.4)
		table.insert(l, { tex = TEX.copo, props = { Rate = 12, Lifetime = NumberRange.new(1, 1.5), Size = U.seq(0.8, 0.3), Transparency = U.seq(0, 1),
			Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -6, 0), Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120), Color = ColorSequence.new(BLANCO, skin.c2) } })
		table.insert(l, { tex = T.vapor, props = { Rate = 6, Lifetime = NumberRange.new(0.8, 1.2), Size = U.seq(1.5 * TAM, 3 * TAM), Transparency = U.seq(0.55, 1),
			Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2),
			LightEmission = 0.3, LightInfluence = 0.5 } })
	elseif nombre == "Ciempies" then
		if i % 2 == 0 then chispas(8, 2.4 * sg.k) end
		if i % 3 == 1 then                                         -- fuegos fatuos verdes que se quedan flotando
			table.insert(l, { tex = TEX.llama, props = { Rate = 6, Lifetime = NumberRange.new(1, 1.6), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.2, 1.6), NumberSequenceKeypoint.new(1, 0) }), Transparency = U.seq(0.1, 1), Speed = NumberRange.new(1, 3),
				SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 3, 0), Color = ColorSequence.new(skin.c3, C("#C8FFB0")) } })
		end
		if i % 3 == 0 then
			table.insert(l, { tex = T.vapor, props = { Rate = 5, Lifetime = NumberRange.new(0.9, 1.3), Size = U.seq(1.3 * TAM, 2.8 * TAM), Transparency = U.seq(0.5, 1),
				Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c3, skin.c2),
				LightEmission = 0.6, LightInfluence = 0 } })
		end
		if i == 1 then
			table.insert(l, { tex = TEX.murcielago, props = { Rate = 5, Lifetime = NumberRange.new(1, 1.5), Size = U.seq(1.6, 1.2), Transparency = U.seq(0, 1),
				Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(-20, 20),
				RotSpeed = NumberRange.new(-40, 40), Color = ColorSequence.new(BLANCO), LightEmission = 0, LightInfluence = 0.3 } })
		end
	elseif nombre == "GatoAstral" then
		chispas(6, 1.5)
		table.insert(l, { tex = T.estrella, props = { Rate = 10, Lifetime = NumberRange.new(0.8, 1.2), Size = U.seq(0.9, 0.2), Transparency = U.seq(0, 1),
			Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -5, 0), Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120), Color = ColorSequence.new(skin.oro, skin.c3) } })
		table.insert(l, { tex = T.vapor, props = { Rate = 5, Lifetime = NumberRange.new(0.8, 1.2), Size = U.seq(1.3 * TAM, 2.6 * TAM), Transparency = U.seq(0.55, 1),
			Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c2, skin.c3),
			LightEmission = 0.7, LightInfluence = 0 } })
	end
	if i == n then                                                     -- cola
		table.insert(l, { tex = skin.colaTex or T.purpurina, props = { Rate = 30, Lifetime = NumberRange.new(0.3, 0.6),
			Size = U.seq(if skin.colaTex then 1.8 else 0.9, 0.1), Transparency = U.seq(0, 1), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180),
			Color = ColorSequence.new(skin.c1, skin.c2) } })
	end
	return l
end

-- animación de las piezas articuladas
local ANIM = {
	aleteo = function(t: number, d) local a = math.rad(12 + 40 * math.sin(t * 7)); return CFrame.Angles(0, 0, if d.espejo then math.pi - a else a) end,
	aleta = function(t: number, d) local a = math.rad(16 * math.sin(t * 3)); return CFrame.Angles(0, 0, if d.espejo then math.pi - a else a) end,
	galope = function(t: number, d) return CFrame.Angles(math.rad(38) * math.sin(t * 13 + d.fase), 0, 0) end,
}

local function seg(x: number): number return x / Dragon.ESCALA end

-- largo de la recta: el 'alcance' de Rarezas.Mitico (el servidor lo lee de la misma tabla)
local function alcanceConfig(): number
	local ok, C = pcall(function() return require(ReplicatedStorage:WaitForChild("ZeroHabilidadesConfig", 2) :: ModuleScript) end)
	return ok and C.Rarezas.Mitico and C.Rarezas.Mitico.alcance or 70
end


-- ------------------------------------------------------------------ camino
local function ignorarTodo(personaje: Model?): { Instance }
	local l: { Instance } = {}
	if personaje then table.insert(l, personaje) end
	for _, p in Players:GetPlayers() do if p.Character then table.insert(l, p.Character) end end
	for _, n in { "ZeroBots", "ZeroVFX" } do local f = workspace:FindFirstChild(n); if f then table.insert(l, f) end end
	return l
end

-- Catmull-Rom por puntos de control (x a lo largo de la recta, y sobre el suelo)
local function spline(ctrl: { Vector2 }, n: number): { Vector2 }
	local out = { ctrl[1] }
	for i = 1, #ctrl - 1 do
		local p0, p1, p2, p3 = ctrl[math.max(i - 1, 1)], ctrl[i], ctrl[i + 1], ctrl[math.min(i + 2, #ctrl)]
		for j = 1, n do
			local u = j / n
			local u2, u3 = u * u, u * u * u
			table.insert(out, 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3))
		end
	end
	return out
end

-- sube desde bajo tierra por el portal y hace los ARCOS (sale, se zambulle, corre por debajo, vuelve a salir); acaba bajo tierra
function Dragon.ruta(origen: Vector3, objetivo: Vector3, alcance: number, personaje: Model?, skin: string?)
	local plano = Vector3.new(objetivo.X - origen.X, 0, objetivo.Z - origen.Z)
	local dir = if plano.Magnitude > 0.5 then plano.Unit else Vector3.new(0, 0, -1)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = ignorarTodo(personaje)
	local hit = workspace:Raycast(origen, Vector3.new(0, -20, 0), rp)
	local sueloY = if hit then hit.Position.Y else origen.Y - 3
	local P0 = Vector3.new(origen.X, sueloY, origen.Z) + dir * PORTAL
	local L = alcance
	local ctrl = { Vector2.new(0, -26), Vector2.new(0, -12), Vector2.new(0.4, -2) }
	for i, a in ARCOS do
		local x0, x1, h = a[1] * L, a[2] * L, a[3]
		if i > 1 then
			local xp = ARCOS[i - 1][2] * L
			table.insert(ctrl, Vector2.new(xp + 3, -6))
			table.insert(ctrl, Vector2.new((xp + x0) / 2, -HONDO))
			table.insert(ctrl, Vector2.new(x0 - 3, -6))
		end
		if i > 1 then table.insert(ctrl, Vector2.new(x0, 0)) end
		table.insert(ctrl, Vector2.new(x0 + (x1 - x0) * 0.22, h * 0.8))
		table.insert(ctrl, Vector2.new(x0 + (x1 - x0) * 0.5, h))
		table.insert(ctrl, Vector2.new(x0 + (x1 - x0) * 0.8, h * 0.7))
		table.insert(ctrl, Vector2.new(x1, 0))
	end
	table.insert(ctrl, Vector2.new(L + 2.5, -8)); table.insert(ctrl, Vector2.new(L + 4, -22)); table.insert(ctrl, Vector2.new(L + 4.5, -60))
	local xy = spline(ctrl, 8)
	local up = Vector3.yAxis
	local pts, acum = {}, { 0 }
	for i, v in xy do
		pts[i] = P0 + dir * v.X + up * v.Y
		if i > 1 then acum[i] = acum[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
	end
	-- cruces con el suelo (sale = de abajo arriba)
	local cruces = {}
	for i = 2, #xy do
		local a, b = xy[i - 1].Y, xy[i].Y
		if (a < 0) ~= (b < 0) then
			local f = a / (a - b)
			table.insert(cruces, { d = acum[i - 1] + (acum[i] - acum[i - 1]) * f, x = xy[i - 1].X + (xy[i].X - xy[i - 1].X) * f, sale = a < 0 })
		end
	end
	local r = { pts = pts, acum = acum, xy = xy, dir = dir, lado = dir:Cross(up).Unit, portal = P0, sueloY = sueloY, alcance = alcance,
		cruces = cruces, total = acum[#acum], alto = 15, largo = (SKINS[skin or ""] or SKINS.Celestial).largo }
	r.dSuelo = cruces[1].d                                          -- la cabeza asoma por el portal
	r.dFin = cruces[#cruces].d                                      -- última zambullida
	r.fin = P0 + dir * cruces[#cruces].x
	for _, c in cruces do c.pos = P0 + dir * c.x end
	return r
end

-- punto y tangente a 'd' studs del principio del camino
local function en(r, d: number): (Vector3, Vector3)
	local pts, acum = r.pts, r.acum
	if d <= 0 then local t = (pts[2] - pts[1]).Unit; return pts[1] + t * d, t end
	if d >= r.total then local n = #pts; local t = (pts[n] - pts[n - 1]).Unit; return pts[n] + t * (d - r.total), t end
	local lo, hi = 1, #acum
	while hi - lo > 1 do
		local m = (lo + hi) // 2
		if acum[m] <= d then lo = m else hi = m end
	end
	local t = (pts[hi] - pts[lo])
	return pts[lo] + t * ((d - acum[lo]) / (acum[hi] - acum[lo])), t.Unit
end

local function dCabeza(r, t: number): number return r.dSuelo + (t - Dragon.AVISO) * Dragon.VEL end
local function tEn(r, d: number): number return Dragon.AVISO + (d - r.dSuelo) / Dragon.VEL end
function Dragon.cuando(r, a: number): number
	for i, v in r.xy do
		if v.X >= a and r.acum[i] >= r.dSuelo - 1 then return tEn(r, r.acum[i]) end
	end
	return tEn(r, r.total)
end
-- el pilar estalla cuando la cola termina de zambullirse
function Dragon.final(r): (Vector3, number)
	return Vector3.new(r.fin.X, r.sueloY, r.fin.Z), tEn(r, r.dFin + r.largo) + 0.15
end

-- ------------------------------------------------------------------ piezas sueltas
local function sonidoLargo(padre: Instance, id: string, vol: number, tono: number, dura: number, alcance: number?)
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = vol; s.PlaybackSpeed = tono
	s.RollOffMaxDistance = alcance or 220; s.RollOffMinDistance = 20; s.Parent = padre; s:Play()
	task.delay(seg(dura), function()
		TweenService:Create(s, TweenInfo.new(0.6), { Volume = 0 }):Play()
		Debris:AddItem(s, 0.7)
	end)
end

local function temblor(fuerza: number, dura: number)
	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	local nombre = "ZeroDragonTemblor" .. tostring(t0) .. math.random()
	RunService:BindToRenderStep(nombre, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - t0
		if t > dura then RunService:UnbindFromRenderStep(nombre); return end
		local k = fuerza * (1 - t / dura)
		cam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
	end)
end
local function distanciaYo(pos: Vector3): number
	local yo = Players.LocalPlayer and Players.LocalPlayer.Character
	local raiz = yo and yo:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if raiz then (raiz.Position - pos).Magnitude else math.huge
end
local function temblorCerca(pos: Vector3, radio: number, fuerza: number, dura: number)
	local d = distanciaYo(pos)
	if d < radio then temblor(fuerza * (1 - d / radio), dura) end
end

-- rocas 3D que saltan del suelo (tiro parabólico; las mueve el bucle de Play)
local function rocas(carpeta: Instance, trozos: { any }, pos: Vector3, n: number, fuerza: number, tam: number)
	for _ = 1, n do
		local s = tam * (0.5 + math.random() * 0.7)
		local p = U.parte(if math.random() < 0.5 then "WedgePart" else "Part", { Size = Vector3.new(s, s * (0.6 + math.random() * 0.5), s * (0.7 + math.random() * 0.5)),
			Material = Enum.Material.Slate, Color = Color3.fromHex(({ "#4A4239", "#5C534A", "#6E665C" })[math.random(1, 3)]), CFrame = CFrame.new(pos) })
		p.Parent = carpeta
		local a = math.random() * math.pi * 2
		local v = Vector3.new(math.cos(a), 0, math.sin(a)) * fuerza * (0.2 + math.random() * 0.35) + Vector3.new(0, fuerza * (0.7 + math.random() * 0.5), 0)
		table.insert(trozos, { p = p, p0 = pos, v = v, t0 = nil, giro = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14,
			rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6) })
	end
end

-- golpe en el suelo: grieta, rocas (partículas y 3D) y polvo
local function golpe(carpeta: Instance, trozos, skin, pos: Vector3, normal: Vector3, tam: number)
	U.marca(carpeta, pos, normal, TEX.grieta, skin.grieta, tam, 1.6)
	local _, a = U.ancla(carpeta, pos + normal * 0.5)
	U.soltar(a, math.floor(tam * 0.9), TEX.roca, { Size = NumberSequence.new(tam * 0.09, tam * 0.06), Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(tam * 1.6, tam * 3), SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -75, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-400, 400), LightEmission = 0, LightInfluence = 1, Color = ColorSequence.new(BLANCO) })
	U.soltar(a, 4, T.vapor, { Size = U.seq(tam * 0.35, tam * 0.9), Transparency = U.seq(0.35, 1), Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(3, 8), SpreadAngle = Vector2.new(80, 80), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(skin.polvo), LightEmission = 0, LightInfluence = 1 })
	U.soltar(a, 3, skin.chispa, { Size = U.seq(tam * 0.4, tam * 0.25), Transparency = U.seq(0, 0.6), Lifetime = NumberRange.new(0.08, 0.14),
		Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2) })
	rocas(carpeta, trozos, pos + normal * 0.6, math.max(2, math.floor(tam / 3)), tam * 3.2, tam * 0.1)
end

-- cráter: anillo de losas de roca que se levantan inclinadas hacia fuera y se hunden pasado 'dura'
local function crater(carpeta: Instance, skin, pos: Vector3, radio: number, n: number, dura: number)
	local material, colores, transp = skin.losas[1], skin.losas[2], skin.losas[3] or 0
	for i = 1, n do
		local a = (i + math.random() * 0.5) / n * math.pi * 2
		local ancho, alto = radio * (0.45 + math.random() * 0.25), radio * (0.5 + math.random() * 0.35)
		local p = U.parte("Part", { Size = Vector3.new(ancho, alto, radio * 0.16), Material = material, Transparency = transp,
			Color = Color3.fromHex(colores[math.random(1, #colores)]) })
		p.CastShadow = true
		local fuera = Vector3.new(math.cos(a), 0, math.sin(a))
		local base = pos + fuera * radio * (0.85 + math.random() * 0.25)
		local cf = CFrame.lookAt(base, base + fuera) * CFrame.Angles(-math.rad(35 + math.random() * 30), 0, math.rad((math.random() - 0.5) * 30))
			* CFrame.new(0, alto * 0.25, 0)
		p.CFrame = cf - Vector3.new(0, alto, 0)
		p.Parent = carpeta
		TweenService:Create(p, TweenInfo.new(seg(0.16), Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = cf }):Play()
		task.delay(seg(dura), function()
			if not p.Parent then return end
			TweenService:Create(p, TweenInfo.new(seg(0.6), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = cf - Vector3.new(0, alto * 1.2, 0), Transparency = 1 }):Play()
			Debris:AddItem(p, seg(0.7))
		end)
	end
	-- hoyo oscuro en el centro
	local hoyo = U.parte("Part", { Size = Vector3.new(radio * 1.7, 0.05, radio * 1.7), Transparency = 1, CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0)) })
	local d = Instance.new("Decal"); d.Face = Enum.NormalId.Top; d.Texture = TEX.grieta; d.Color3 = Color3.new(0.25, 0.25, 0.25); d.Parent = hoyo
	hoyo.Parent = carpeta
	TweenService:Create(d, TweenInfo.new(seg(0.8), Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, seg(dura)), { Transparency = 1 }):Play()
	Debris:AddItem(hoyo, seg(dura + 1))
end

-- lápidas (Halloween): se levantan inclinadas alrededor de un cráter y se hunden pasado 'dura'
local function lapidas(carpeta: Instance, pos: Vector3, radio: number, n: number, dura: number)
	for i = 1, n do
		local a = (i + math.random() * 0.6) / n * math.pi * 2
		local base = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * radio * (1.15 + math.random() * 0.25)
		local alto, ancho = 2.2 + math.random() * 0.8, 1.5 + math.random() * 0.4
		local giro = CFrame.lookAt(base, pos) * CFrame.Angles(math.rad((math.random() - 0.5) * 24), 0, math.rad((math.random() - 0.5) * 24))
		local color = Color3.fromHex(({ "#6E6A78", "#5D5966", "#7C7887" })[math.random(1, 3)])
		local cuerpo = U.parte("Part", { Size = Vector3.new(ancho, alto, 0.45), Material = Enum.Material.Slate, Color = color })
		local tapa = U.parte("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, ancho, ancho), Material = Enum.Material.Slate, Color = color })
		local cruz = U.parte("Part", { Size = Vector3.new(0.18, 0.9, 0.08), Material = Enum.Material.SmoothPlastic, Color = Color3.fromHex("#3A3642") })
		local cruz2 = U.parte("Part", { Size = Vector3.new(0.6, 0.18, 0.08), Material = Enum.Material.SmoothPlastic, Color = Color3.fromHex("#3A3642") })
		local piezas = { { cuerpo, CFrame.new(0, alto / 2, 0) }, { tapa, CFrame.new(0, alto, 0) * CFrame.Angles(0, math.pi / 2, 0) },
			{ cruz, CFrame.new(0, alto * 0.62, -0.25) }, { cruz2, CFrame.new(0, alto * 0.7, -0.25) } }
		for _, pz in piezas do pz[1].CastShadow = true; pz[1].Parent = carpeta end
		local abajo = giro * CFrame.new(0, -alto - 1, 0)
		local t0 = os.clock()
		local c: RBXScriptConnection
		c = RunService.Heartbeat:Connect(function()
			local t = (os.clock() - t0) * Dragon.ESCALA
			local sube = U.rebote(math.min(t / 0.25, 1)) * (1 - U.suave((t - dura) / 0.6))
			if t > dura + 0.7 or not cuerpo.Parent then
				c:Disconnect(); for _, pz in piezas do pz[1]:Destroy() end; return
			end
			local cf = abajo:Lerp(giro, math.clamp(sube, 0, 1.1))
			for _, pz in piezas do pz[1].CFrame = cf * pz[2] end
		end)
	end
end

-- Halloween: fantasmas que suben, calabacitas que saltan y una nube de murciélagos
local function sustos(a: Attachment, skin, fuerza: number)
	U.soltar(a, math.floor(3 * fuerza), TEX.fantasma, { Size = U.seq(2.4, 3.4), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.15), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(1.4, 2), Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 2, 0), Rotation = NumberRange.new(-15, 15),
		RotSpeed = NumberRange.new(-25, 25), Color = ColorSequence.new(BLANCO, C("#C8FFD0")), LightEmission = 0.3, LightInfluence = 0 })
	U.soltar(a, math.floor(4 * fuerza), TEX.calabaza, { Size = U.seq(1.4, 1.0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(1, 1.4), Speed = NumberRange.new(18, 28),
		SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -50, 0), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-220, 220), Color = ColorSequence.new(BLANCO), LightEmission = 0.3, LightInfluence = 0.4 })
	U.soltar(a, math.floor(8 * fuerza), TEX.murcielago, { Size = U.seq(1.8, 1.3), Transparency = U.seq(0, 1), Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(12, 22), SpreadAngle = Vector2.new(65, 65), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(-20, 20),
		RotSpeed = NumberRange.new(-60, 60), Color = ColorSequence.new(BLANCO), LightEmission = 0, LightInfluence = 0.3 })
end

-- ------------------------------------------------------------------ la criatura
local function clonar(skin, nombre: string, escala: number, carpeta: Instance)
	local raiz = ReplicatedStorage:FindFirstChild("ZeroHabilidades")
	local P = raiz and raiz:FindFirstChild("Proyectiles")
	local plantilla = P and P:FindFirstChild(nombre)
	local m: Model
	if plantilla then
		m = plantilla:Clone()
		m:ScaleTo(escala)
	else                                                                  -- sin modelo importado: esfera de neón
		m = Instance.new("Model")
		local p = U.parte("Part", { Name = "Cuerpo", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4 * escala, Material = Enum.Material.Neon, Color = skin.c2 })
		p.Parent = m; m.PrimaryPart = p
	end
	local piv = m:GetPivot()
	local partes = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			d.CastShadow = d.Name == "Cuerpo"
			local base = if d.Name == "Cuerpo" and skin.transparencia then skin.transparencia else d.Transparency
			table.insert(partes, { p = d, off = piv:ToObjectSpace(d.CFrame), base = base })
		end
	end
	m.Parent = carpeta
	return m, partes
end

local function crearCriatura(skin, carpeta: Instance)
	local modelo = Instance.new("Model"); modelo.Name = skin.nombre
	local segs, adjs = {}, {}
	for _, pz in skin.piezas do
		local m, partes = clonar(skin, pz.modelo, skin.tam * pz.k, modelo)
		table.insert(segs, { m = m, nombre = pz.modelo, k = pz.k, s = pz.s * skin.tam, dy = (pz.dy or 0) * skin.tam * pz.k, partes = partes, vis = -1, emisores = {} })
	end
	for _, ad in skin.adjuntos do
		local base = segs[ad.base]
		local m, partes = clonar(skin, ad.modelo, skin.tam * base.k, modelo)
		local S = skin.tam * base.k
		table.insert(adjs, { m = m, base = base, junta = CFrame.new(ad.junta * S), desde = CFrame.new(ad.desde * S), anim = ANIM[ad.anim], dato = ad,
			partes = partes, vis = -1 })
	end
	modelo.Parent = carpeta
	-- aura: contorno de luz alrededor de todo el cuerpo
	local aura = Instance.new("Highlight")
	aura.FillColor = skin.c2; aura.FillTransparency = if skin.transparencia then 0.75 else 1; aura.OutlineColor = skin.c2; aura.OutlineTransparency = 0.45
	aura.DepthMode = Enum.HighlightDepthMode.Occluded; aura.Adornee = modelo; aura.Parent = modelo
	-- luces pegadas (la calabaza del jinete)
	for _, l in skin.luces or {} do
		local c = segs[l.base].partes[1]
		if c then
			local a = Instance.new("Attachment"); a.Position = l.pos * skin.tam; a.Parent = c.p
			local pl = Instance.new("PointLight"); pl.Color = l.color; pl.Range = l.rango; pl.Brightness = l.brillo; pl.Shadows = false; pl.Parent = a
		end
	end
	return modelo, segs, adjs, aura
end

-- ------------------------------------------------------------------ pilar final
local function pilarFinal(carpeta: Instance, trozos, skin, base: Vector3)
	local ALTO = 80
	local up = Vector3.yAxis
	-- núcleo de neón y capa de campo de fuerza (cilindros verticales que se abren de golpe)
	local vertical = CFrame.Angles(0, 0, math.pi / 2)
	local nucleo = U.parte("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(ALTO, 0.5, 0.5), Material = Enum.Material.Neon, Color = skin.pilar[1],
		Transparency = 0.45, CFrame = CFrame.new(base + up * ALTO / 2) * vertical })
	local capa = U.parte("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(ALTO, 0.5, 0.5), Material = Enum.Material.ForceField, Color = skin.pilar[3],
		Transparency = 0, CFrame = nucleo.CFrame })
	nucleo.Parent = carpeta; capa.Parent = carpeta
	TweenService:Create(nucleo, TweenInfo.new(seg(0.22), Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(ALTO, 9, 9) }):Play()
	TweenService:Create(capa, TweenInfo.new(seg(0.3), Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(ALTO, 15, 15) }):Play()
	-- el color recorre blanco -> oro -> jade -> cian -> azul profundo
	task.spawn(function()
		for i = 2, #skin.pilar do
			local paso = PILAR / (#skin.pilar - 1)
			TweenService:Create(nucleo, TweenInfo.new(seg(paso), Enum.EasingStyle.Sine), { Color = skin.pilar[i] }):Play()
			TweenService:Create(capa, TweenInfo.new(seg(paso), Enum.EasingStyle.Sine), { Color = skin.pilar[math.min(i + 1, #skin.pilar)] }):Play()
			task.wait(seg(paso))
		end
		if not nucleo.Parent then return end
		TweenService:Create(nucleo, TweenInfo.new(seg(0.45), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(ALTO, 0.2, 0.2), Transparency = 1 }):Play()
		TweenService:Create(capa, TweenInfo.new(seg(0.5), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(ALTO, 0.2, 0.2), Transparency = 1 }):Play()
		Debris:AddItem(nucleo, seg(0.6)); Debris:AddItem(capa, seg(0.6))
	end)
	local pB, aB = U.ancla(carpeta, base + up * 0.5)
	pB.Size = Vector3.new(8, 0.2, 8)                                   -- los emisores de disco usan el tamaño de la pieza
	-- cortinas de energía que suben fluyendo (textura de rayas) y cambian de color con el pilar
	local _, aTope = U.ancla(carpeta, base + up * ALTO)
	local cortinas = {}
	for i, ancho in { 16, 11, 6 } do
		local b = U.beam(carpeta, aB, aTope, TEX.chorro, 0, BLANCO)
		b.TextureMode = Enum.TextureMode.Wrap; b.TextureLength = 26 + i * 6; b.TextureSpeed = -(1.6 + i * 0.5)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.15), NumberSequenceKeypoint.new(1, 1) })
		b.ZOffset = i
		cortinas[i] = { b = b, ancho = ancho }
	end
	local tP = os.clock()
	local cP: RBXScriptConnection
	cP = RunService.RenderStepped:Connect(function()
		local f = (os.clock() - tP) * Dragon.ESCALA / PILAR                     -- 0..1 durante el pilar
		if f > 1.35 then cP:Disconnect(); for _, c in cortinas do c.b:Destroy() end; return end
		local abre = U.rebote(math.min(f / 0.14, 1)) * (1 - U.suave((f - 1) / 0.3))
		local k = math.clamp(f, 0, 0.999) * (#skin.pilar - 1)
		local i0 = math.floor(k)
		local col = skin.pilar[i0 + 1]:Lerp(skin.pilar[math.min(i0 + 2, #skin.pilar)], k - i0)
		for i, c in cortinas do
			c.b.Width0 = c.ancho * abre; c.b.Width1 = c.ancho * abre * 1.15
			c.b.Color = ColorSequence.new(if i == 3 then BLANCO:Lerp(col, 0.4) else col)
		end
	end)
	local emisores = {
		-- chorros de luz que suben por el pilar
		U.emisor(pB, T.estela, { Shape = Enum.ParticleEmitterShape.Disc, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Rate = 90,
			Lifetime = NumberRange.new(0.5, 0.8), Size = U.seq(1.4, 0.6), Transparency = U.seq(0, 1), Speed = NumberRange.new(70, 110),
			EmissionDirection = Enum.NormalId.Top, Orientation = Enum.ParticleOrientation.VelocityParallel, Color = ColorSequence.new(BLANCO, skin.c2) }),
		-- rayas que salen disparadas hacia fuera
		U.emisor(aB, T.estela, { Rate = 45, Lifetime = NumberRange.new(0.25, 0.4), Size = U.seq(0.8, 0.2), Transparency = U.seq(0, 1),
			Speed = NumberRange.new(60, 95), SpreadAngle = Vector2.new(82, 82), EmissionDirection = Enum.NormalId.Top,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Color = ColorSequence.new(skin.oro, skin.c2) }),
		-- zarcillos oscuros que se arrastran por el suelo
		U.emisor(aB, T.vapor, { Rate = 26, Lifetime = NumberRange.new(1, 1.4), Size = U.seq(5, 15), Transparency = U.seq(0.25, 1),
			Speed = NumberRange.new(22, 36), SpreadAngle = Vector2.new(88, 88), EmissionDirection = Enum.NormalId.Top, Drag = 2.5,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60), Color = ColorSequence.new(skin.oscuro), LightEmission = 0, LightInfluence = 0 }),
		-- rayos alrededor de la base
		U.emisor(pB, T.rayo, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 24, Lifetime = NumberRange.new(0.08, 0.14), Size = U.seq(9, 6),
			Transparency = U.seq(0, 0.4), Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), ZOffset = 2 }),
	}
	task.delay(seg(PILAR), function() for _, e in emisores do e.Enabled = false end end)
	Debris:AddItem(pB, seg(PILAR + 1.6))
	U.luz(pB, skin.c2, 7, 70, PILAR + 0.4)
	-- anillos de luz horizontales que suben girando por el pilar
	for i, h in { 3, 12, 24 } do
		local aro = U.parte("Part", { Size = Vector3.new(4, 0.05, 4), Transparency = 1, CFrame = CFrame.new(base + up * h) })
		for _, cara in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
			local d = Instance.new("Decal"); d.Face = cara; d.Texture = T.anillo; d.Color3 = if i == 2 then skin.oro else skin.c2; d.Parent = aro
			TweenService:Create(d, TweenInfo.new(seg(PILAR), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
		aro.Parent = carpeta
		TweenService:Create(aro, TweenInfo.new(seg(PILAR), Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Size = Vector3.new(26 - i * 4, 0.05, 26 - i * 4), CFrame = CFrame.new(base + up * (h + 14)) * CFrame.Angles(0, math.pi * (i % 2 == 0 and -2 or 2), 0) }):Play()
		Debris:AddItem(aro, seg(PILAR + 0.1))
	end
	-- onda en el suelo, rocas y polvo a lo grande
	local onda = U.parte("Part", { Size = Vector3.new(4, 0.05, 4), Transparency = 1, CFrame = CFrame.new(base + up * 0.15) })
	local d = Instance.new("Decal"); d.Face = Enum.NormalId.Top; d.Texture = T.anillo; d.Color3 = skin.c1; d.Parent = onda
	onda.Parent = carpeta
	TweenService:Create(onda, TweenInfo.new(seg(0.7), Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(60, 0.05, 60) }):Play()
	TweenService:Create(d, TweenInfo.new(seg(0.8), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(onda, seg(0.9))
	golpe(carpeta, trozos, skin, base, up, 22)
	rocas(carpeta, trozos, base + up, 12, 55, 1.5)
	crater(carpeta, skin, base, 7, 12, PILAR + 1)
	U.destello(aB, 40, skin.c1, 0.4); U.anilloLuz(aB, 4, 50, 0.6, skin.c2)
end

-- pantalla de quien está cerca del final: negativo de un instante, fogonazo blanco y oscurecimiento durante el pilar
local function pantallaFinal(skin, cerca: number)
	local gui = Instance.new("ScreenGui"); gui.Name = "ZeroDragonFinal"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 40; gui.ResetOnSpawn = false
	local f = Instance.new("Frame"); f.Size = UDim2.fromScale(1, 1); f.BorderSizePixel = 0; f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 0.15 + 0.5 * (1 - cerca); f.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local cc = Instance.new("ColorCorrectionEffect"); cc.Name = "ZeroDragonFinal"; cc.Parent = Lighting
	cc.Saturation = -1; cc.Contrast = 0.6
	task.delay(0.06, function()
		f.BackgroundColor3 = BLANCO; f.BackgroundTransparency = 0.05 + 0.5 * (1 - cerca)
		TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cc, TweenInfo.new(0.3), { Saturation = 0.15, Contrast = 0.25, Brightness = -0.12 * cerca, TintColor = skin.c1 }):Play()
		Debris:AddItem(gui, 0.6)
	end)
	task.delay(seg(PILAR), function()
		TweenService:Create(cc, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = BLANCO }):Play()
		Debris:AddItem(cc, 0.7)
	end)
end

-- ------------------------------------------------------------------ secuencia
function Dragon.Play(personaje: Model, objetivo: Vector3, inicio: number?, origen: Vector3?, nombreSkin: string?): number
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return 0 end
	local skin = SKINS[nombreSkin or ""] or SKINS.Celestial
	local raizVFX = workspace:FindFirstChild("ZeroVFX") or Instance.new("Folder")
	raizVFX.Name = "ZeroVFX"; raizVFX.Parent = workspace
	local carpeta = Instance.new("Folder"); carpeta.Name = "Dragon"; carpeta.Parent = raizVFX
	local escala = Dragon.ESCALA
	Rafaga.ESCALA = escala
	local t0 = os.clock() - (if inicio then math.max(0, workspace:GetServerTimeNow() - inicio) else 0) / escala
	local AV = Dragon.AVISO
	local alcance = alcanceConfig()
	local r = Dragon.ruta(origen or hrp.Position, objetivo, alcance, personaje, skin.nombre)
	local TAM = skin.tam
	local posFinal, tFinal = Dragon.final(r)
	local trozos = {}

	-- brazo del cazador en alto
	local quitarPose = U.hechizo(personaje, "HechizoMitico")   -- animación de la E (ZeroMovement)
	sonidoLargo(hrp, SFX.retumbe, 0.9, 1.2, tFinal + PILAR)
	U.sonido(hrp, Rafaga.SFX.aparece, 0.7, 0.8)
	if skin.halloween then
		U.sonido(hrp, SFX.aullido, 1, 1)
		sonidoLargo(hrp, SFX.coroFantasmas, 0.8, 1, tFinal + PILAR, 200)
	end

	-- portal en el suelo con grietas, rayos, piedras que tiemblan y luz que crece
	local suelo = Vector3.new(r.portal.X, r.sueloY, r.portal.Z)
	local portal = U.parte("Part", { Size = Vector3.new(0.1, 0.05, 0.1), Transparency = 1, CFrame = CFrame.new(suelo + Vector3.new(0, 0.08, 0)) })
	local dp = Instance.new("Decal"); dp.Face = Enum.NormalId.Top; dp.Texture = skin.portal; dp.Transparency = 1; dp.Parent = portal
	portal.Parent = carpeta
	U.marca(carpeta, suelo, Vector3.yAxis, TEX.grieta, skin.grieta, 13, AV + 1)
	local pP, aP = U.ancla(carpeta, suelo + Vector3.new(0, 0.6, 0))
	pP.Size = Vector3.new(9, 0.2, 9)
	local chisporroteo = U.emisor(pP, skin.chispa, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 26, Lifetime = NumberRange.new(0.06, 0.12),
		Size = U.seq(3.2, 2), Transparency = U.seq(0, 0.5), Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), ZOffset = 1 })
	local brincan = U.emisor(pP, TEX.roca, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 24, Lifetime = NumberRange.new(0.3, 0.45),
		Size = U.seq(0.6, 0.5), Speed = NumberRange.new(5, 9), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -60, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), LightEmission = 0, LightInfluence = 1, Color = ColorSequence.new(BLANCO) })
	local sube = U.emisor(pP, T.purpurina, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 30, Lifetime = NumberRange.new(0.5, 0.8),
		Size = U.seq(0.7, 0.1), Transparency = U.seq(0, 1), Speed = NumberRange.new(5, 10), EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(skin.c1, skin.c2) })
	local luzPortal = Instance.new("PointLight"); luzPortal.Color = skin.c2; luzPortal.Range = 22; luzPortal.Brightness = 0; luzPortal.Shadows = false
	luzPortal.Parent = pP

	-- la criatura (empieza bajo tierra)
	local modelo, segs, adjs, aura = crearCriatura(skin, carpeta)
	local cabeza, cola = segs[1], segs[#segs]
	-- perla de luz delante de la boca
	local perla = U.parte("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.95 * TAM, Material = Enum.Material.Neon, Color = BLANCO,
		Transparency = 1, CFrame = CFrame.new(suelo - Vector3.new(0, 6, 0)) })
	perla.Parent = carpeta
	local aPerla = Instance.new("Attachment"); aPerla.Parent = perla
	local luzPerla = Instance.new("PointLight"); luzPerla.Color = skin.c1; luzPerla.Range = 12; luzPerla.Brightness = 0; luzPerla.Shadows = false; luzPerla.Parent = perla
	local rayosPerla = U.emisor(aPerla, T.rayo, { Rate = 18, Lifetime = NumberRange.new(0.06, 0.1), Size = U.seq(3.4, 2.4), Transparency = U.seq(0, 0.4),
		Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), LockedToPart = true, ZOffset = 1 })
	local brilloPerla = U.emisor(aPerla, T.destello, { Rate = 10, Lifetime = NumberRange.new(0.12), Size = U.seq(4.5, 3), Transparency = U.seq(0.2, 1),
		Color = ColorSequence.new(skin.c1), LockedToPart = true })
	-- estela de la cabeza
	local cab0 = Instance.new("Attachment"); cab0.Position = Vector3.new(0, 0.5, 0); cab0.Parent = perla
	local cab1 = Instance.new("Attachment"); cab1.Position = Vector3.new(0, -0.5, 0); cab1.Parent = perla
	local estela = Instance.new("Trail")
	estela.Attachment0, estela.Attachment1 = cab0, cab1; estela.Texture = T.estela; estela.TextureMode = Enum.TextureMode.Stretch
	estela.Lifetime = 0.35; estela.FaceCamera = true; estela.LightEmission = 1; estela.LightInfluence = 0; estela.MinLength = 0.1
	estela.Color = ColorSequence.new(skin.c1, skin.c2); estela.Transparency = NumberSequence.new(0.2, 1); estela.Enabled = false; estela.Parent = perla
	if not skin.perla then perla.Parent = nil end
	-- efectos pegados al cuerpo (chispas, rastro, cola) según la skin; se apagan bajo tierra
	local arcos = {}
	for i, sg in segs do
		local c = sg.partes[1] and sg.partes[1].p
		if not c then continue end
		local a = Instance.new("Attachment"); a.Parent = c
		sg.a = a
		for _, ef in efectosCuerpo(skin, i, sg, #segs) do table.insert(sg.emisores, U.emisor(a, ef.tex, ef.props)) end
		for _, e in sg.emisores do e.Enabled = false end
	end
	-- arcos eléctricos que saltan entre tramos del cuerpo (se recolocan al azar; solo el dragón)
	for _ = 1, if skin.arcos then 4 else 0 do
		local b = Instance.new("Beam")
		b.Texture = T.rayoBeam; b.TextureMode = Enum.TextureMode.Wrap; b.TextureLength = 4; b.TextureSpeed = 6; b.FaceCamera = true
		b.LightEmission = 1; b.LightInfluence = 0; b.Segments = 8; b.Width0 = 0.5; b.Width1 = 0.5; b.Color = ColorSequence.new(skin.c1, skin.c2)
		b.Transparency = NumberSequence.new(0.05); b.Enabled = false; b.Parent = carpeta
		table.insert(arcos, b)
	end
	rayosPerla.Enabled = false; brilloPerla.Enabled = false
	for _, sg in segs do for _, pt in sg.partes do pt.p.Transparency = 1 end end
	for _, ad in adjs do for _, pt in ad.partes do pt.p.Transparency = 1 end end
	aura.Enabled = false
	-- sonido en bucle mientras corre (galope del jinete)
	local bucle: Sound? = nil
	if skin.bucle then
		bucle = Instance.new("Sound"); bucle.SoundId = skin.bucle[1]; bucle.Volume = 0; bucle.PlaybackSpeed = skin.bucle[3]; bucle.Looped = true
		bucle.RollOffMaxDistance = 160; bucle.RollOffMinDistance = 15
		bucle.Parent = segs[1].partes[1] and segs[1].partes[1].p or carpeta
	end

	-- cada cruce con el suelo: polvo, piedras y rayos que siguen saliendo mientras el cuerpo pasa por el agujero
	for _, c in r.cruces do
		local pos = Vector3.new(c.pos.X, r.sueloY, c.pos.Z)
		local pC, a = U.ancla(carpeta, pos + Vector3.new(0, 0.5, 0))
		pC.Size = Vector3.new(6, 0.2, 6)
		c.suelo = pos; c.a = a
		c.emisores = {
			U.emisor(pC, T.vapor, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 10, Lifetime = NumberRange.new(0.8, 1.2), Size = U.seq(3, 7),
				Transparency = U.seq(0.4, 1), Speed = NumberRange.new(3, 7), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
				Color = ColorSequence.new(skin.polvo), LightEmission = 0, LightInfluence = 1 }),
			U.emisor(pC, TEX.roca, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 18, Lifetime = NumberRange.new(0.5, 0.8), Size = U.seq(0.9, 0.6),
				Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -70, 0),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), LightEmission = 0, LightInfluence = 1, Color = ColorSequence.new(BLANCO) }),
			U.emisor(pC, skin.chispa, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 12, Lifetime = NumberRange.new(0.06, 0.12), Size = U.seq(4, 2.5),
				Transparency = U.seq(0, 0.5), Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), ZOffset = 1 }),
		}
		if skin.halloween then                                    -- fuegos fatuos verdes saliendo del agujero
			table.insert(c.emisores, U.emisor(pC, TEX.llama, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 14, Lifetime = NumberRange.new(0.8, 1.3),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 2), NumberSequenceKeypoint.new(1, 0) }),
				Transparency = U.seq(0.05, 1), Speed = NumberRange.new(3, 7), EmissionDirection = Enum.NormalId.Top, Color = ColorSequence.new(skin.c3, C("#C8FFB0")) }))
		end
		for _, e in c.emisores do e.Enabled = false end
	end

	local salido, finalHecho = false, false
	local iCruce = 1
	local proximoBajo = 0                    -- grietas mientras corre bajo tierra (x a lo largo de la recta)
	local proximoArco, proximoZap = 0, 0

	-- posición del eje del cuerpo a 's' studs detrás de la cabeza (onda lateral que corre hacia la cola)
	local onda = skin.onda
	local function eje(dHead: number, s: number, t: number): (Vector3, Vector3)
		local p, tg = en(r, dHead - s)
		local amp = U.suave(s / (5 * TAM))
		local n = r.lado:Cross(tg)
		return p + r.lado * (onda.lat * TAM * amp * math.sin(s * 0.15 - t * 7)) + n * (onda.ver * TAM * amp * math.sin(s * 0.12 - t * 5.5)), n
	end

	local function cruce(c, i: number)
		local pos = c.suelo
		local primero = i == 1
		local ultimo = i == #r.cruces
		local tCola = tEn(r, c.d + cola.s)
		local quedan = tCola - (os.clock() - t0) * escala
		golpe(carpeta, trozos, skin, pos, Vector3.yAxis, if primero then 16 else 12)
		rocas(carpeta, trozos, pos + Vector3.new(0, 0.6, 0), if primero then 7 else 5, 40, 0.9)
		crater(carpeta, skin, pos, if primero then 6 else 5, if primero then 10 else 8, quedan + 1)
		U.destello(c.a, if primero then 22 else 16, skin.c1, 0.3); U.anilloLuz(c.a, 2, if primero then 26 else 20, 0.45, skin.c2)
		U.luz(c.a.Parent :: BasePart, skin.c1, 4, 28, 0.5)
		for _, e in c.emisores do e.Enabled = true end
		task.delay(seg(quedan + 0.2), function() for _, e in c.emisores do e.Enabled = false end end)
		-- BOOM: impacto de roca y graves (más fuerte al salir del portal y en la última zambullida)
		sonidoLargo(c.a, if c.sale then SFX.boom else SFX.boom2, 1.3, 0.95 + math.random() * 0.15, 2.2)
		sonidoLargo(c.a, SFX.subBoom, if c.sale then 0.8 else 1.1, 1, 1.6)
		if c.sale then U.sonido(c.a, SFX.avalancha, 0.8, 1.1) end
		if skin.acento then U.sonido(c.a, skin.acento[1], skin.acento[2], skin.acento[3]) end
		if skin.halloween then
			sustos(c.a, skin, if primero then 1.6 else 1)
			lapidas(carpeta, pos, if primero then 6 else 5, if primero then 4 else 3, quedan + 1)
			U.sonido(c.a, SFX.murcielagos, 0.9, 1)
			U.sonido(c.a, SFX.cadenas, 0.7, 0.9)
			if primero then U.sonido(c.a, SFX.bruja, 1.2, 1) end
		end
		if primero then
			U.sonido(c.a, SFX.truenoGrande, 1, 1.05)
			U.sonido(c.a, skin.voz[1], skin.voz[2], skin.voz[3])
		elseif not ultimo and c.sale then
			U.sonido(c.a, skin.voz[1], skin.voz[2] * 0.6, skin.voz[3] * 1.1)
		end
		temblorCerca(pos, if primero or ultimo then 55 else 45, if primero then 2.4 else 1.8, 0.45)
	end

	local conexion: RBXScriptConnection
	conexion = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) * escala
		if not carpeta.Parent then conexion:Disconnect(); quitarPose(); return end
		local dH = dCabeza(r, t)

		-- portal: se abre con rebote, gira, y se cierra cuando la cola sale
		local colaFuera = dH - cola.s - r.dSuelo
		local abre = U.rebote(math.min(t / 0.3, 1)) * (1 - U.suave((colaFuera - 2) / 10))
		local tam = math.max(17 * abre, 0.1)
		portal.Size = Vector3.new(tam, 0.05, tam)
		portal.CFrame = CFrame.new(suelo + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, -t * 3, 0)
		dp.Transparency = 1 - math.clamp(abre, 0, 1) * 0.95
		luzPortal.Brightness = if salido then 1.5 * math.clamp(abre, 0, 1) else 0.5 + 2.5 * U.suave(t / AV)
		chisporroteo.Enabled = colaFuera < 8

		if not salido and t >= AV then
			salido = true
			brincan.Enabled = false; sube.Enabled = false
			aura.Enabled = true
			rayosPerla.Enabled = true; brilloPerla.Enabled = true
			-- pilar de luz corto en la salida
			local _, b0 = U.ancla(carpeta, suelo)
			local _, b1 = U.ancla(carpeta, suelo + Vector3.new(0, 34, 0))
			local pilar = U.beam(carpeta, b0, b1, T.estela, 9, skin.c2)
			pilar.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			local pilar2 = U.beam(carpeta, b0, b1, T.estela, 4, skin.c1)
			pilar2.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
			for _, b in { pilar, pilar2 } do
				TweenService:Create(b, TweenInfo.new(seg(0.5), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Width0 = 0, Width1 = 0 }):Play()
			end
		end

		-- cruces con el suelo: la cabeza entra o sale
		while iCruce <= #r.cruces and dH >= r.cruces[iCruce].d do
			cruce(r.cruces[iCruce], iCruce)
			iCruce += 1
		end

		-- cuerpo: cada tramo sigue el camino con su retraso; oculto mientras está bajo tierra
		if salido then
			local partes, cfs = {}, {}
			for _, sg in segs do
				local pos, n = eje(dH, sg.s, t)
				local delante = eje(dH, sg.s - 0.8, t)
				local detras = eje(dH, sg.s + 0.8, t)
				local fwd = (delante - detras)
				fwd = if fwd.Magnitude > 1e-3 then fwd.Unit else r.dir
				if sg.dy ~= 0 then pos += n * sg.dy end
				if sg == cabeza and skin.bote > 0 then pos += n * skin.bote * TAM * math.abs(math.sin(t * 6.5)) end
				local cf = CFrame.lookAt(pos, pos + fwd, n)
				sg.cf = cf
				local vis = if pos.Y < r.sueloY - 1.2 * TAM * sg.k then 1 else 0
				for _, pt in sg.partes do
					table.insert(partes, pt.p); table.insert(cfs, cf * pt.off)
					if sg.vis ~= vis then pt.p.Transparency = math.max(pt.base, vis) end
				end
				if sg.vis ~= vis then for _, e in sg.emisores do e.Enabled = vis == 0 end end
				sg.vis = vis
			end
			-- piezas articuladas: alas, aletas y patas
			for _, ad in adjs do
				local cf = ad.base.cf * ad.junta * ad.anim(t, ad.dato) * ad.desde
				local vis = ad.base.vis
				for _, pt in ad.partes do
					table.insert(partes, pt.p); table.insert(cfs, cf * pt.off)
					if ad.vis ~= vis then pt.p.Transparency = math.max(pt.base, vis) end
				end
				ad.vis = vis
			end
			workspace:BulkMoveTo(partes, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			if bucle then
				local fuera = cabeza.vis == 0 and dH < r.dFin
				if fuera and not bucle.IsPlaying then bucle:Play() end
				bucle.Volume += ((if fuera then skin.bucle[2] else 0) - bucle.Volume) * 0.15
			end
			-- perla delante de la boca, girando un poco
			perla.CFrame = cabeza.cf * CFrame.new(math.sin(t * 9) * 0.25, -0.15 * TAM + math.cos(t * 9) * 0.25, -3.9 * TAM)
			local perlaFuera = skin.perla == true and perla.Position.Y > r.sueloY - 0.5
			perla.Transparency = if perlaFuera then 0 else 1
			estela.Enabled = perlaFuera
			rayosPerla.Enabled = perlaFuera; brilloPerla.Enabled = perlaFuera
			luzPerla.Brightness = if perlaFuera then 1.5 else 0
			aura.Enabled = dH - cola.s < r.dFin

			-- arcos eléctricos entre tramos visibles
			if t >= proximoArco then
				proximoArco = t + 0.06
				for _, b in arcos do
					local i = math.random(2, #segs - 2)
					local A, B = segs[i], segs[i + math.random(1, 2)]
					if A.a and B.a and math.random() < 0.7 and A.vis < 0.5 and B.vis < 0.5 then
						b.Attachment0, b.Attachment1 = A.a, B.a
						b.CurveSize0, b.CurveSize1 = (math.random() - 0.5) * 6, (math.random() - 0.5) * 6
						b.Enabled = true
					else
						b.Enabled = false
					end
				end
			end
			if skin.zap and t >= proximoZap and dH < r.dFin and perlaFuera then
				proximoZap = t + 0.22
				U.sonido(perla, Rafaga.SFX.zap, 0.45, 0.8 + math.random() * 0.3)
			end

			-- bajo tierra: el suelo se agrieta y saltan piedras sobre la cabeza
			local pc = cabeza.cf.Position
			local x = (pc - r.portal):Dot(r.dir)
			if pc.Y < r.sueloY - 1 and x >= proximoBajo and x <= alcance then
				proximoBajo = x + 4
				local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = { carpeta, personaje }
				local o = Vector3.new(pc.X, r.sueloY + 4, pc.Z)
				local hit = workspace:Raycast(o, Vector3.new(0, -10, 0), rp)
				if hit then golpe(carpeta, trozos, skin, hit.Position, hit.Normal, 7 + math.random() * 2) end
				temblorCerca(o, 18, 1, 0.2)
			end
		end

		-- FINAL: la cola terminó de zambullirse -> pilar de energía
		if not finalHecho and t >= tFinal then
			finalHecho = true
			pilarFinal(carpeta, trozos, skin, posFinal)
			local _, aF = U.ancla(carpeta, posFinal + Vector3.new(0, 2, 0))
			if skin.halloween then
				sustos(aF, skin, 3)
				lapidas(carpeta, posFinal, 8, 6, PILAR + 1)
				sonidoLargo(aF, SFX.campana, 1.3, 1, 3.5, 300)
				U.sonido(aF, SFX.bruja, 1.4, 0.95)
				U.sonido(aF, SFX.murcielagos, 1.1, 0.9)
			end
			sonidoLargo(aF, SFX.boomFinal, 1.4, 1, PILAR + 1.5, 400)
			sonidoLargo(aF, SFX.subBoom, 1.5, 0.85, 2.5, 400)
			sonidoLargo(aF, SFX.boom2, 1.2, 0.8, 2.5, 300)
			U.sonido(aF, SFX.truenoGrande, 1.1, 0.95)
			local d = distanciaYo(posFinal)
			if d < 90 then pantallaFinal(skin, 1 - d / 90) end
			temblorCerca(posFinal, 80, 3.2, 0.8)
		end

		-- rocas 3D en vuelo
		for i = #trozos, 1, -1 do
			local tr = trozos[i]
			tr.t0 = tr.t0 or t
			local tt = t - tr.t0
			local pos = tr.p0 + tr.v * tt + Vector3.new(0, -80, 0) * tt * tt * 0.5
			if tt > 1.4 or not tr.p.Parent then
				tr.p:Destroy(); table.remove(trozos, i)
			else
				tr.p.CFrame = CFrame.new(pos) * tr.rot * CFrame.Angles(tr.giro.X * tt, tr.giro.Y * tt, tr.giro.Z * tt)
				if tt > 1.1 then tr.p.Transparency = (tt - 1.1) / 0.3 end
			end
		end

		if finalHecho and t > tFinal + PILAR + 0.3 and #trozos == 0 then
			conexion:Disconnect(); quitarPose()
			task.delay(seg(1.5), function() carpeta:Destroy() end)
		end
	end)
	local total = tFinal + PILAR + 0.5
	task.delay((total + 3) / escala, function()
		if conexion.Connected then conexion:Disconnect() end
		quitarPose()
		if carpeta.Parent then carpeta:Destroy() end
	end)
	return total
end

-- ------------------------------------------------------------------ aturdido: nube de jade girando y chispazos de rayo
function Dragon.aturdido(personaje: Model, nombreSkin: string?, dura: number)
	local skin = SKINS[nombreSkin or ""] or SKINS.Celestial
	local cabeza = personaje:FindFirstChild("Head") :: BasePart?
	local torso = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cabeza or not torso then return end
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromScale(3.2, 3.2); bb.StudsOffset = Vector3.new(0, 2.2, 0); bb.LightInfluence = 0
	bb.Adornee = cabeza; bb.Parent = cabeza
	local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Image = skin.sprite; im.ImageColor3 = if skin.sprite == TEX.murcielago then BLANCO else skin.c2
	im.Size = UDim2.fromScale(1, 1); im.Parent = bb
	local a = Instance.new("Attachment"); a.Parent = torso
	local rayos = U.emisor(a, skin.chispa, { Rate = 14, Lifetime = NumberRange.new(0.06, 0.12), Size = U.seq(4, 3), Transparency = U.seq(0, 0.5),
		Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), LockedToPart = true, ZOffset = 1 })
	U.soltar(a, 16, T.purpurina, { Size = U.seq(0.8, 0.1), Transparency = U.seq(0, 1), Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(skin.c1, skin.c2) })
	local t0 = os.clock()
	local c: RBXScriptConnection
	c = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > dura or not bb.Parent then c:Disconnect(); bb:Destroy(); rayos.Enabled = false; Debris:AddItem(a, 0.3); return end
		im.Rotation = math.sin(t * 6) * 15
		bb.StudsOffset = Vector3.new(math.cos(t * 5) * 0.4, 2.2 + math.sin(t * 7) * 0.15, math.sin(t * 5) * 0.4)
		im.ImageTransparency = math.clamp((t - dura + 0.2) / 0.2, 0, 1)
	end)
end

return Dragon
