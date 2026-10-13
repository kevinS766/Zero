--!strict
-- ZeroArmasVFX (ModuleScript, ReplicatedStorage): efectos de las 21 armas cosméticas de ZERO, las 8 míticas y las 16
-- mágicas (varitas y bastones de zero-magicas; ver el bloque MÁGICAS).
-- Escala por rareza, de menos a más y sin saturar:
--   Comun      estela gris muy fina y corta al atacar. Nada en reposo.
--   Raro       estela clara con el color de su detalle. Nada en reposo.
--   Especial   pieza Brillo en Neon + chispitas suaves de su color + luz tenue; estela de su color.
--   Legendario partículas temáticas en reposo + luz; estela de su color con brillo.
-- Uso:
--   local VFX = require(ReplicatedStorage.ZeroArmasVFX)
--   VFX.apply(model, "Eclipse")     -- una vez al equipar (Model con Cuerpo y, si tiene, Brillo)
--   VFX.swing(model)                -- en cada ataque: enciende la estela 0.25 s
--   VFX.setIdle(model, false)       -- p. ej. al congelarse o en móviles de gama baja
-- Generado por zero-maps/armas: editar ZeroArmasVFX.template.luau, no esta copia.
local ZeroArmasVFX = {}

local ARMAS = {
	["Navaja"] = { rareza = "Comun", detalle = Color3.fromHex("#8b929c"), filo = Color3.fromHex("#d9dde3") },
	["Hachuela"] = { rareza = "Comun", detalle = Color3.fromHex("#5c626b"), filo = Color3.fromHex("#d5d9df") },
	["Florete"] = { rareza = "Comun", detalle = Color3.fromHex("#7b828c"), filo = Color3.fromHex("#e8eaee") },
	["Pica"] = { rareza = "Comun", detalle = Color3.fromHex("#5c626b"), filo = Color3.fromHex("#e0e3e8") },
	["Bokken"] = { rareza = "Comun", detalle = Color3.fromHex("#e4dece"), filo = Color3.fromHex("#d9b384") },
	["Katana"] = { rareza = "Raro", detalle = Color3.fromHex("#c23a4a"), filo = Color3.fromHex("#eceef2") },
	["Rompeescudos"] = { rareza = "Raro", detalle = Color3.fromHex("#b07a3a"), filo = Color3.fromHex("#d5d9df") },
	["Cimitarra"] = { rareza = "Raro", detalle = Color3.fromHex("#c9a24a"), filo = Color3.fromHex("#e4e8ee") },
	["Naginata"] = { rareza = "Raro", detalle = Color3.fromHex("#c23a4a"), filo = Color3.fromHex("#eceef2") },
	["Gemelas"] = { rareza = "Raro", detalle = Color3.fromHex("#4da3ff"), filo = Color3.fromHex("#eceef2") },
	["Aguijón"] = { rareza = "Especial", detalle = Color3.fromHex("#66d17a"), filo = Color3.fromHex("#eef4ee") },
	["Segadora"] = { rareza = "Especial", detalle = Color3.fromHex("#b072ff"), filo = Color3.fromHex("#9a9aab") },
	["Bifaz"] = { rareza = "Especial", detalle = Color3.fromHex("#4da3ff"), filo = Color3.fromHex("#dfe3e8") },
	["Media Luna"] = { rareza = "Especial", detalle = Color3.fromHex("#a8e2ff"), filo = Color3.fromHex("#f2f5ff") },
	["Karambit"] = { rareza = "Especial", detalle = Color3.fromHex("#ff4d5f"), filo = Color3.fromHex("#9a9aab") },
	["Cero Absoluto"] = { rareza = "Legendario", detalle = Color3.fromHex("#3fc4ff"), filo = Color3.fromHex("#eefaff") },
	["Eclipse"] = { rareza = "Legendario", detalle = Color3.fromHex("#ffc857"), filo = Color3.fromHex("#55556b") },
	["Relámpago"] = { rareza = "Legendario", detalle = Color3.fromHex("#ffe14d"), filo = Color3.fromHex("#ffffff") },
	["Zarpas"] = { rareza = "Raro", detalle = Color3.fromHex("#c9a24a"), filo = Color3.fromHex("#eceef2") },
	["Depredador"] = { rareza = "Especial", detalle = Color3.fromHex("#b072ff"), filo = Color3.fromHex("#9a9aab") },
	["Bestia"] = { rareza = "Legendario", detalle = Color3.fromHex("#ff6a2a"), filo = Color3.fromHex("#5a464d") },
}
ZeroArmasVFX.ARMAS = ARMAS

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function seq(...) return NumberSequence.new({ ... }) end
local function nk(t, v) return NumberSequenceKeypoint.new(t, v) end

-- estela por rareza: (ancho al inicio, vida, transparencia inicial, brillo)
local TRAIL = {
	Comun = { life = 0.10, t0 = 0.65, light = 0, color = function(_) return Color3.fromRGB(220, 224, 230) end },
	Raro = { life = 0.14, t0 = 0.45, light = 0.2, color = function(a) return Color3.new(1, 1, 1):Lerp(a.detalle, 0.35) end },
	Especial = { life = 0.18, t0 = 0.45, light = 0.6, color = function(a) return a.detalle end },
	Legendario = { life = 0.22, t0 = 0.38, light = 1, color = function(a) return a.detalle end },
}

-- partículas temáticas de las legendarias (y de las especiales, genéricas)
local function themed(name: string, a, host: BasePart)
	local p = Instance.new("ParticleEmitter")
	p.Name = "ZeroIdle"
	p.LightEmission = 0.6
	p.LockedToPart = false
	p.Texture = SPARK
	p.Color = ColorSequence.new(a.detalle)
	if name == "Cero Absoluto" then                    -- escarcha que cae despacio
		p.Rate = 4; p.Lifetime = NumberRange.new(1.2, 1.8); p.Speed = NumberRange.new(0.2, 0.5)
		p.Acceleration = Vector3.new(0, -0.6, 0); p.Size = seq(nk(0, 0.2), nk(1, 0))
		p.Transparency = seq(nk(0, 0.3), nk(1, 1)); p.Rotation = NumberRange.new(0, 360); p.RotSpeed = NumberRange.new(-40, 40)
		p.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255), a.detalle)
	elseif name == "Eclipse" then                      -- brasas doradas que flotan
		p.Rate = 4; p.Lifetime = NumberRange.new(1, 1.6); p.Speed = NumberRange.new(0.3, 0.7)
		p.Acceleration = Vector3.new(0, 0.5, 0); p.Size = seq(nk(0, 0.16), nk(0.5, 0.22), nk(1, 0))
		p.Transparency = seq(nk(0, 0.2), nk(1, 1)); p.SpreadAngle = Vector2.new(30, 30)
	elseif name == "Relámpago" then                    -- chispazos cortos a ráfagas (ver loop abajo)
		p.Rate = 0; p.Lifetime = NumberRange.new(0.15, 0.3); p.Speed = NumberRange.new(4, 7)
		p.Size = seq(nk(0, 0.24), nk(1, 0)); p.Transparency = seq(nk(0, 0), nk(1, 1)); p.SpreadAngle = Vector2.new(180, 180)
		p.LightEmission = 1
	elseif name == "Bestia" then                       -- brasas de magma que suben
		p.Texture = FIRE
		p.Rate = 5; p.Lifetime = NumberRange.new(0.6, 1); p.Speed = NumberRange.new(0.4, 0.9)
		p.Acceleration = Vector3.new(0, 1.2, 0); p.Size = seq(nk(0, 0.2), nk(1, 0))
		p.Transparency = seq(nk(0, 0.25), nk(1, 1)); p.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), a.detalle)
	else                                               -- especiales: chispitas suaves de su color
		p.Rate = 2; p.Lifetime = NumberRange.new(0.6, 1); p.Speed = NumberRange.new(0.1, 0.3)
		p.Size = seq(nk(0, 0.12), nk(0.5, 0.15), nk(1, 0)); p.Transparency = seq(nk(0, 0.35), nk(1, 1))
		p.LightEmission = 0.5
	end
	p.Parent = host
	return p
end

-- ===================== MÍTICAS (8 armas de zero-miticas) =====================
-- Cada mítica trae en su Cuerpo los Attachments VFX_Idle, Trail_A, Trail_B y VFX_Hit (los pone preparar_miticas).
-- Reposo: sus partículas temáticas + luz. Ataque: estela ancha entre Trail_A y Trail_B y, al golpear, una ráfaga en
-- VFX_Hit. Extras: parpadeo de vela (Calabaza), parpadeo de plasma (Sable), latido del aura (Katana) e inflado al equipar
-- (armas de globos).
local TEX = {
	alma = "rbxassetid://99806097052699", anillo = "rbxassetid://76773782998070", confeti = "rbxassetid://76533484555188",
	copo = "rbxassetid://90409960624684", esquirla = "rbxassetid://129305573747727", petalo = "rbxassetid://89198430491211",
	chispa = SPARK, fuego = FIRE, humo = "rbxasset://textures/particles/smoke_main.dds",
}
local function hex(h) return Color3.fromHex(h) end
-- e = { tex, c = {colorInicio, colorFin}, rate, life = {min, max}, speed = {min, max}, accel = Vector3, size = {inicio, fin},
--       t0 (transparencia inicial), spread, rot (velocidad de giro), drag, luz, n (ráfaga al golpear) }
local MITICAS = {
	["Segadora Lunar"] = { brillo = hex("#5EE8FF"), estela = hex("#7FE9FF"),
		idle = {
			{ tex = "alma", c = { "#FFFFFF", "#5EE8FF" }, rate = 2.5, life = { 1.4, 2 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, 1.1, 0), size = { 0.35, 0 }, t0 = 0.25, spread = 40 },
			{ tex = "copo", c = { "#E8FBFF", "#9FE4FF" }, rate = 3, life = { 2, 3 }, speed = { 0.2, 0.5 }, accel = Vector3.new(0, -0.7, 0), size = { 0.16, 0.1 }, t0 = 0.2, spread = 180, rot = 60 },
			{ tex = "chispa", c = { "#FFFFFF", "#5EE8FF" }, rate = 3, life = { 0.3, 0.5 }, speed = { 0, 0.1 }, size = { 0.25, 0 }, t0 = 0.1, spread = 180 },
		},
		golpe = {
			{ tex = "esquirla", c = { "#FFFFFF", "#5EE8FF" }, n = 14, life = { 0.35, 0.55 }, speed = { 8, 12 }, size = { 0.35, 0.1 }, spread = 180, drag = 6, rot = 300 },
			{ tex = "anillo", c = { "#BFF6FF", "#5EE8FF" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 4.5 }, t0 = 0.1 },
		} },
	["Calabaza Infernal"] = { brillo = hex("#FF7A1A"), estela = hex("#FF8A2A"), vela = true,
		idle = {
			{ tex = "chispa", c = { "#FFD27A", "#FF5A10" }, rate = 4, life = { 0.8, 1.3 }, speed = { 0.4, 0.8 }, accel = Vector3.new(0, 1.4, 0), size = { 0.18, 0 }, t0 = 0.1, spread = 35 },
			{ tex = "humo", c = { "#8A3FB0", "#3A1550" }, rate = 2, life = { 1.5, 2.5 }, speed = { 0.2, 0.4 }, accel = Vector3.new(0, 0.6, 0), size = { 0.4, 1.1 }, t0 = 0.55, spread = 25, luz = 0 },
		},
		golpe = {
			{ tex = "fuego", c = { "#FFB03A", "#FF4A10" }, n = 16, life = { 0.3, 0.5 }, speed = { 4, 7 }, size = { 0.6, 0 }, spread = 180, drag = 4 },
			{ tex = "fuego", c = { "#C46BFF", "#5A1A8A" }, n = 10, life = { 0.3, 0.5 }, speed = { 3, 6 }, size = { 0.5, 0 }, spread = 180, drag = 4 },
			{ tex = "esquirla", c = { "#F5E6B0", "#D9C27A" }, n = 8, life = { 0.5, 0.8 }, speed = { 4, 6 }, accel = Vector3.new(0, -12, 0), size = { 0.15, 0.15 }, spread = 180, rot = 200, luz = 0 },
		} },
	["Hacha Globo"] = { estela = hex("#FF7AB8"), inflar = true,
		idle = {
			{ tex = "confeti", c = { "#F0458F", "#F0458F" }, rate = 1.2, life = { 1.6, 2.4 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, -1.5, 0), size = { 0.14, 0.14 }, spread = 180, rot = 240, luz = 0 },
			{ tex = "confeti", c = { "#FFD23A", "#FFD23A" }, rate = 1.2, life = { 1.6, 2.4 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, -1.5, 0), size = { 0.14, 0.14 }, spread = 180, rot = 240, luz = 0 },
			{ tex = "confeti", c = { "#18B6C4", "#18B6C4" }, rate = 1.2, life = { 1.6, 2.4 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, -1.5, 0), size = { 0.14, 0.14 }, spread = 180, rot = 240, luz = 0 },
		},
		golpe = {
			{ tex = "confeti", c = { "#F0458F", "#F0458F" }, n = 10, life = { 0.8, 1.2 }, speed = { 6, 9 }, accel = Vector3.new(0, -10, 0), size = { 0.2, 0.2 }, spread = 180, rot = 400, drag = 3, luz = 0 },
			{ tex = "confeti", c = { "#FFD23A", "#FFD23A" }, n = 10, life = { 0.8, 1.2 }, speed = { 6, 9 }, accel = Vector3.new(0, -10, 0), size = { 0.2, 0.2 }, spread = 180, rot = 400, drag = 3, luz = 0 },
			{ tex = "confeti", c = { "#18B6C4", "#18B6C4" }, n = 10, life = { 0.8, 1.2 }, speed = { 6, 9 }, accel = Vector3.new(0, -10, 0), size = { 0.2, 0.2 }, spread = 180, rot = 400, drag = 3, luz = 0 },
			{ tex = "anillo", c = { "#FF9AC6", "#F0458F" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 4 }, t0 = 0.1 },
		} },
	["Garras del Vacío"] = { brillo = hex("#B05CFF"), estela = hex("#B05CFF"), vacio = true,
		idle = {},                                       -- las partículas absorbidas van en una esfera invisible (ver vacio)
		golpe = {
			{ tex = "chispa", c = { "#E2C2FF", "#7A2AD9" }, n = 18, life = { 0.25, 0.4 }, speed = { 7, 11 }, size = { 0.3, 0 }, spread = 180, drag = 5 },
			{ tex = "anillo", c = { "#D9A8FF", "#7A2AD9" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 4, 0.2 }, t0 = 0.1 },   -- implosión
		} },
	["Sable de Plasma"] = { brillo = hex("#8FF0FF"), estela = hex("#B8F7FF"), plasma = true,
		idle = {
			{ tex = "chispa", c = { "#FFF4B0", "#8FF0FF" }, rate = 5, life = { 0.2, 0.4 }, speed = { 1, 2 }, size = { 0.12, 0 }, t0 = 0, spread = 70 },
		},
		golpe = {
			{ tex = "chispa", c = { "#FFFFFF", "#8FF0FF" }, n = 22, life = { 0.4, 0.7 }, speed = { 5, 9 }, accel = Vector3.new(0, -14, 0), size = { 0.18, 0 }, spread = 180, drag = 2 },
			{ tex = "anillo", c = { "#FFFFFF", "#8FF0FF" }, n = 1, life = { 0.2, 0.2 }, speed = { 0, 0 }, size = { 0.3, 3 }, t0 = 0 },
		} },
	["Cortaalmas"] = { brillo = hex("#FF1218"), estela = hex("#2A0A0C"), estelaLuz = 0.2,
		idle = {
			{ tex = "chispa", c = { "#FF7A6A", "#FF1218" }, rate = 3, life = { 0.8, 1.4 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, 1.2, 0), size = { 0.16, 0 }, t0 = 0.1, spread = 40 },
			{ tex = "humo", c = { "#2A2228", "#0E0B0D" }, rate = 2, life = { 1.4, 2.2 }, speed = { 0.2, 0.4 }, accel = Vector3.new(0, 0.5, 0), size = { 0.4, 1 }, t0 = 0.5, spread = 30, luz = 0 },
		},
		golpe = {
			{ tex = "anillo", c = { "#FF1218", "#1A0607" }, n = 1, life = { 0.3, 0.3 }, speed = { 0, 0 }, size = { 0.6, 5 }, t0 = 0, luz = 0.6 },   -- tajo en media luna
			{ tex = "chispa", c = { "#FF5040", "#7A0608" }, n = 16, life = { 0.3, 0.5 }, speed = { 6, 9 }, size = { 0.25, 0 }, spread = 180, drag = 4 },
		} },
	["Globotajo"] = { estela = hex("#FFD85A"), inflar = true,
		idle = {
			{ tex = "confeti", c = { "#FFC21F", "#FFC21F" }, rate = 1, life = { 1.6, 2.2 }, speed = { 0.2, 0.5 }, accel = Vector3.new(0, -1.5, 0), size = { 0.1, 0.1 }, spread = 180, rot = 240, luz = 0 },
			{ tex = "confeti", c = { "#F0458F", "#F0458F" }, rate = 1, life = { 1.6, 2.2 }, speed = { 0.2, 0.5 }, accel = Vector3.new(0, -1.5, 0), size = { 0.1, 0.1 }, spread = 180, rot = 240, luz = 0 },
			{ tex = "confeti", c = { "#2F7BFF", "#2F7BFF" }, rate = 1, life = { 1.6, 2.2 }, speed = { 0.2, 0.5 }, accel = Vector3.new(0, -1.5, 0), size = { 0.1, 0.1 }, spread = 180, rot = 240, luz = 0 },
		},
		golpe = {
			{ tex = "confeti", c = { "#FFC21F", "#FFC21F" }, n = 10, life = { 0.8, 1.2 }, speed = { 6, 9 }, accel = Vector3.new(0, -10, 0), size = { 0.18, 0.18 }, spread = 180, rot = 400, drag = 3, luz = 0 },
			{ tex = "confeti", c = { "#F0458F", "#F0458F" }, n = 10, life = { 0.8, 1.2 }, speed = { 6, 9 }, accel = Vector3.new(0, -10, 0), size = { 0.18, 0.18 }, spread = 180, rot = 400, drag = 3, luz = 0 },
			{ tex = "confeti", c = { "#2F7BFF", "#2F7BFF" }, n = 10, life = { 0.8, 1.2 }, speed = { 6, 9 }, accel = Vector3.new(0, -10, 0), size = { 0.18, 0.18 }, spread = 180, rot = 400, drag = 3, luz = 0 },
		} },
	["Katana Sakura"] = { brillo = hex("#FF3D9A"), estela = hex("#FF7AB8"), latido = true,
		idle = {
			{ tex = "petalo", c = { "#FFC2DD", "#FF7AB8" }, rate = 3, life = { 2.5, 3.5 }, speed = { 0.4, 0.8 }, accel = Vector3.new(0.3, -0.5, 0), size = { 0.2, 0.16 }, t0 = 0.1, spread = 180, rot = 120, luz = 0.2 },
		},
		golpe = {
			{ tex = "petalo", c = { "#FFC2DD", "#FF3D9A" }, n = 24, life = { 0.8, 1.3 }, speed = { 5, 8 }, accel = Vector3.new(0, -3, 0), size = { 0.28, 0.2 }, spread = 180, rot = 300, drag = 3, luz = 0.2 },
			{ tex = "anillo", c = { "#FFFFFF", "#FF3D9A" }, n = 1, life = { 0.25, 0.25 }, speed = { 0, 0 }, size = { 0.4, 3.5 }, t0 = 0 },
		} },
}
ZeroArmasVFX.MITICAS = MITICAS

-- multiplicadores de todos los efectos de las míticas (bajar si pesan demasiado en móvil)
local REFUERZO = { rate = 2, size = 1.5, rafaga = 1.6 }

local function emisor(e, host: Instance, nombre: string, rafaga: boolean, esc: { rate: number, size: number, rafaga: number }?): ParticleEmitter
	local ref = esc or REFUERZO
	local p = Instance.new("ParticleEmitter")
	p.Name = nombre
	p.Texture = TEX[e.tex]
	p.Color = ColorSequence.new(hex(e.c[1]), hex(e.c[2]))
	p.Rate = if rafaga then 0 else e.rate * ref.rate
	p.Lifetime = NumberRange.new(e.life[1], e.life[2])
	p.Speed = NumberRange.new(e.speed[1], e.speed[2])
	p.Acceleration = e.accel or Vector3.zero
	p.Size = seq(nk(0, e.size[1] * ref.size), nk(1, e.size[2] * ref.size))
	p.Transparency = seq(nk(0, e.t0 or 0.15), nk(1, 1))
	p.SpreadAngle = Vector2.new(e.spread or 0, e.spread or 0)
	p.Drag = e.drag or 0
	p.LightEmission = e.luz or 0.7
	if e.rot then p.Rotation = NumberRange.new(0, 360); p.RotSpeed = NumberRange.new(-e.rot, e.rot) end
	if e.rotFija then p.Rotation = NumberRange.new(0, 360); p.RotSpeed = NumberRange.new(e.rotFija) end   -- gira siempre hacia el mismo lado
	if e.retraso then p:SetAttribute("Retraso", e.retraso) end                                          -- ráfaga en dos tiempos
	if e.inward and host:IsA("BasePart") then                                                            -- nace en la esfera y va hacia dentro
		p.Shape = Enum.ParticleEmitterShape.Sphere; p.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		p.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	end
	p.LockedToPart = e.fijo == true
	p:SetAttribute("Rafaga", if rafaga then math.ceil((e.n or 10) * ref.rafaga) else nil)
	p.Parent = host
	return p
end

local function bucle(model: Instance, fn: () -> ())   -- repite fn mientras el modelo exista
	task.spawn(function()
		while model.Parent do fn() end
	end)
end

local function applyMitica(model: Instance, name: string, cuerpo: BasePart)
	local m = MITICAS[name]
	local brillo = model:FindFirstChild("Brillo") :: BasePart?
	if brillo and m.brillo then brillo.Material = Enum.Material.Neon; brillo.Color = m.brillo end
	local function att(n: string, fallback: Vector3): Attachment
		local a = cuerpo:FindFirstChild(n) :: Attachment?
		if a then return a end
		a = Instance.new("Attachment"); a.Name = n; a.Position = fallback; a.Parent = cuerpo
		return a
	end
	local idle = att("VFX_Idle", Vector3.zero)
	local hit = att("VFX_Hit", Vector3.new(0, 0, -cuerpo.Size.Z * 0.4))
	local a0 = att("Trail_A", Vector3.new(0, 0, -cuerpo.Size.Z * 0.2))
	local a1 = att("Trail_B", Vector3.new(0, 0, -cuerpo.Size.Z * 0.5))
	-- estela ancha de su color
	local tr = Instance.new("Trail")
	tr.Name = "ZeroEstela"
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.38; tr.MinLength = 0.05; tr.FaceCamera = false
	tr.LightEmission = m.estelaLuz or 1
	tr.Color = ColorSequence.new(m.estela)
	tr.Transparency = seq(nk(0, 0.08), nk(1, 1))
	tr.WidthScale = seq(nk(0, 1), nk(1, 0.3))
	tr.Enabled = false
	tr.Parent = cuerpo
	-- núcleo: estela blanca más estrecha y corta en medio de la anterior
	local n0 = Instance.new("Attachment"); n0.Name = "ZeroNucleoA"; n0.Position = a0.Position:Lerp(a1.Position, 0.3); n0.Parent = cuerpo
	local n1 = Instance.new("Attachment"); n1.Name = "ZeroNucleoB"; n1.Position = a0.Position:Lerp(a1.Position, 0.9); n1.Parent = cuerpo
	local nucleo = tr:Clone()
	nucleo.Name = "ZeroEstelaNucleo"; nucleo.Attachment0, nucleo.Attachment1 = n0, n1
	nucleo.Lifetime = 0.18; nucleo.LightEmission = 1
	nucleo.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(m.estela, 0.25))
	nucleo.Parent = cuerpo
	-- reposo
	for i, e in m.idle do emisor(e, idle, "ZeroIdle", false) end
	for i, e in m.golpe do emisor(e, hit, "ZeroGolpe", true) end
	local color = m.brillo or m.estela
	local luz = Instance.new("PointLight")
	luz.Name = "ZeroLuz"; luz.Color = color; luz.Range = 10; luz.Brightness = 1.6; luz.Shadows = false
	luz.Parent = brillo or cuerpo
	-- aura: destellos que salen de toda la pieza brillante (o del cuerpo en las de globos) y se quedan atrás al moverla
	local aura = emisor({ tex = "chispa", c = { "#FFFFFF", color:ToHex() }, rate = 7, life = { 0.4, 0.7 }, speed = { 0, 0.3 },
		size = { 0.16, 0 }, t0 = 0.05, spread = 180, luz = 1 }, brillo or cuerpo, "ZeroIdle", false)
	aura:SetAttribute("Aura", true)
	-- destello de luz al golpear
	local flash = Instance.new("PointLight")
	flash.Name = "ZeroDestello"; flash.Color = color; flash.Range = 14; flash.Brightness = 0; flash.Shadows = false
	flash.Parent = hit
	-- extras
	if m.vacio then                                    -- partículas que el agujero negro absorbe desde una esfera
		local esfera = Instance.new("Part")
		esfera.Name = "ZeroVacio"; esfera.Shape = Enum.PartType.Ball; esfera.Size = Vector3.new(1.6, 1.6, 1.6)
		esfera.Transparency = 1; esfera.CanCollide = false; esfera.CanTouch = false; esfera.CanQuery = false; esfera.Massless = true
		esfera.CFrame = idle.WorldCFrame
		local w = Instance.new("WeldConstraint"); w.Part0, w.Part1 = cuerpo, esfera; w.Parent = esfera
		esfera.Parent = model
		local p = emisor({ tex = "chispa", c = { "#E2C2FF", "#7A2AD9" }, rate = 8, life = { 0.5, 0.7 }, speed = { 1.2, 1.6 }, size = { 0.18, 0.04 }, t0 = 0.2 }, esfera, "ZeroIdle", false)
		p.Shape = Enum.ParticleEmitterShape.Sphere; p.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		p.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	end
	if m.vela and brillo then                          -- la cara parpadea como una vela
		bucle(model, function() brillo.Transparency = math.random() * 0.25; task.wait(0.06 + math.random() * 0.12) end)
	end
	if m.plasma and brillo then                        -- parpadeo rápido del plasma de vez en cuando
		bucle(model, function()
			task.wait(1.5 + math.random() * 2.5)
			for _ = 1, 3 do brillo.Transparency = 0.35; task.wait(0.04); brillo.Transparency = 0; task.wait(0.05) end
		end)
	end
	if m.latido and brillo then                        -- el aura de la hoja late
		local t0 = os.clock()
		bucle(model, function() brillo.Transparency = 0.15 + 0.15 * math.sin((os.clock() - t0) * 4); task.wait(0.05) end)
	end
	if m.inflar then                                   -- se infla al equiparla (crece desde un 30 % de su tamaño)
		local full = cuerpo.Size
		cuerpo.Size = full * 0.3
		local tw = game:GetService("TweenService"):Create(cuerpo, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full })
		tw:Play()
	end
end

local function golpeMitica(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Name == "ZeroGolpe" then
			local n, r = (d:GetAttribute("Rafaga") :: number?) or 10, d:GetAttribute("Retraso") :: number?
			if r then task.delay(r, function() if d.Parent then d:Emit(n) end end) else d:Emit(n) end
		elseif d:IsA("ParticleEmitter") and d.Name == "ZeroZzz" and d.Enabled then      -- el gatito se despierta un rato
			d.Enabled = false
			task.delay(3, function() if d.Parent then d.Enabled = true end end)
		elseif d:IsA("ParticleEmitter") and d:GetAttribute("Aura") then d:Emit(16)
		elseif d:IsA("PointLight") and d.Name == "ZeroDestello" then
			d.Brightness = 5
			game:GetService("TweenService"):Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		end
	end
end

-- ===================== MÁGICAS (16 varitas y bastones de zero-magicas) =====================
-- Cada arma es un Cuerpo + un Brillo (Neon) con los Attachments VFX_Idle (cabeza), VFX_Hit, Trail_A (agarre) y
-- Trail_B (punta). Las piezas que "se mueven" en la descripción (planetas, páginas, engranes, tetera…) van fundidas
-- en la malla, así que el movimiento lo dan los efectos: anillos de Beams cuya textura corre alrededor de la cabeza
-- (órbitas, runas que giran), latido o parpadeo del Brillo, ráfagas de rayos y partículas temáticas.
-- Escala por rareza (ESCALA): Común discreta → Mítica espectacular.
-- Texturas propias (blancas, se tiñen): zero-magicas/vfx_tex/hacer_texturas.py
local TEXM = { corazon = "rbxassetid://131594537415454", destello = "rbxassetid://135714183751513", engrane = "rbxassetid://81883825778889", esfera_reloj = "rbxassetid://106163108931469", grano = "rbxassetid://104584642098305", llama = "rbxassetid://123557515982610", nota = "rbxassetid://93345412584945", nube = "rbxassetid://79819780145091", orbe = "rbxassetid://131618340990800", pagina = "rbxassetid://86998905419633", polvo = "rbxassetid://108745022188177", rayo = "rbxassetid://128673267263260", runas = "rbxassetid://136267637166044", talisman = "rbxassetid://109621465350868" }
for k, v in TEXM do TEX[k] = v end
local TEXB = { z = "rbxassetid://128572440871088", pixel = "rbxassetid://80691550162299", moneda_pixel = "rbxassetid://105218274909900", naipe = "rbxassetid://125987240131886", espiral = "rbxassetid://129997920031523" }   -- zero-bastones/vfx_tex
for k, v in TEXB do TEX[k] = v end

local ESCALA = {
	Comun = { rate = 0.8, size = 1, rafaga = 0.8, luz = { 4, 0.5 } },
	Raro = { rate = 1, size = 1.1, rafaga = 1, luz = { 5, 0.7 } },
	Especial = { rate = 1.3, size = 1.2, rafaga = 1.2, luz = { 6, 0.9 } },
	Legendario = { rate = 1.6, size = 1.35, rafaga = 1.4, luz = { 8, 1.2 } },
	Mitico = { rate = 2, size = 1.5, rafaga = 1.6, luz = { 10, 1.6 } },
	Exclusivo = { rate = 2, size = 1.5, rafaga = 1.6, luz = { 10, 1.6 } },
}
-- campos: rareza, luz (color), estela, idle/golpe (como en las míticas; fijo = partículas pegadas a la pieza),
--   anillos = { { tex, c, r, ancho, vel (vueltas de textura/s), largo (de textura), t0, inclina (grados), alto, camara } },
--   latido = amplitud del pulso del Brillo, vela = parpadeo, rayos = { cada mín, cada máx } (ráfagas del emisor ZeroRayo)
local MAGICAS = {
	["Varita de Rama"] = { rareza = "Comun", luz = hex("#5EB8FF"), estela = hex("#A8D8FF"), latido = 0.12,
		idle = { { tex = "chispa", c = { "#FFFFFF", "#5EB8FF" }, rate = 2.5, life = { 0.6, 1 }, speed = { 0.2, 0.5 }, accel = Vector3.new(0, 0.6, 0), size = { 0.14, 0 }, t0 = 0.15, spread = 60 } },
		golpe = { { tex = "chispa", c = { "#FFFFFF", "#5EB8FF" }, n = 10, life = { 0.3, 0.5 }, speed = { 4, 7 }, size = { 0.2, 0 }, spread = 180, drag = 4 } } },
	["Varita de Tiza"] = { rareza = "Comun", luz = hex("#F2F2EE"), estela = hex("#F4F4F0"), estelaLuz = 0,
		idle = { { tex = "polvo", c = { "#FFFFFF", "#D8D8D2" }, rate = 2, life = { 0.8, 1.3 }, speed = { 0.1, 0.3 }, accel = Vector3.new(0, -0.5, 0), size = { 0.12, 0.3 }, t0 = 0.45, spread = 50, luz = 0 } },
		golpe = { { tex = "polvo", c = { "#FFFFFF", "#D8D8D2" }, n = 12, life = { 0.5, 0.9 }, speed = { 2, 4 }, size = { 0.25, 0.6 }, t0 = 0.3, spread = 180, drag = 3, luz = 0 } } },
	["Lápiz Mágico"] = { rareza = "Comun", luz = hex("#FFD34D"), estela = hex("#FFE28A"),
		idle = { { tex = "destello", c = { "#FFF6C8", "#FFC21F" }, rate = 1.5, life = { 0.4, 0.7 }, speed = { 0, 0.15 }, size = { 0.18, 0 }, t0 = 0.05, spread = 180, rot = 90 } },
		golpe = { { tex = "grano", c = { "#B9B9B9", "#8A8A8A" }, n = 14, life = { 0.5, 0.8 }, speed = { 4, 6 }, accel = Vector3.new(0, -14, 0), size = { 0.14, 0.12 }, spread = 180, luz = 0 },
			{ tex = "chispa", c = { "#FFF6C8", "#FFC21F" }, n = 6, life = { 0.25, 0.4 }, speed = { 4, 6 }, size = { 0.2, 0 }, spread = 180, drag = 4 } } },
	["Varita Estelar"] = { rareza = "Raro", luz = hex("#FF6FC8"), estela = hex("#FF9AD6"), latido = 0.2,
		idle = { { tex = "destello", c = { "#FFFFFF", "#FF6FC8" }, rate = 2.5, life = { 0.6, 1 }, speed = { 0.1, 0.4 }, accel = Vector3.new(0, -0.4, 0), size = { 0.2, 0 }, t0 = 0.1, spread = 180, rot = 120 } },
		golpe = { { tex = "destello", c = { "#FFFFFF", "#FF6FC8" }, n = 14, life = { 0.4, 0.6 }, speed = { 5, 8 }, size = { 0.3, 0 }, spread = 180, drag = 4, rot = 300 },
			{ tex = "anillo", c = { "#FFD0EC", "#FF6FC8" }, n = 1, life = { 0.3, 0.3 }, speed = { 0, 0 }, size = { 0.4, 3 }, t0 = 0.1 } } },
	["Batuta de Tormenta"] = { rareza = "Raro", luz = hex("#7FD8FF"), estela = hex("#BFEFFF"), rayos = { 0.8, 2.2 },
		idle = { { tex = "nota", c = { "#FFFFFF", "#9FD8FF" }, rate = 1.2, life = { 1.4, 2 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, 0.5, 0), size = { 0.22, 0.18 }, t0 = 0.1, spread = 70, rot = 30 },
			{ tex = "rayo", nombre = "ZeroRayo", c = { "#FFFFFF", "#7FD8FF" }, rate = 0, life = { 0.08, 0.16 }, speed = { 0, 0 }, size = { 0.25, 0.2 }, t0 = 0, spread = 0, rot = 0, fijo = true, luz = 1 } },
		golpe = { { tex = "rayo", c = { "#FFFFFF", "#7FD8FF" }, n = 6, life = { 0.12, 0.2 }, speed = { 3, 6 }, size = { 0.45, 0.3 }, t0 = 0, spread = 180, luz = 1 },
			{ tex = "nota", c = { "#FFFFFF", "#9FD8FF" }, n = 6, life = { 0.6, 0.9 }, speed = { 3, 5 }, size = { 0.3, 0.2 }, spread = 180, drag = 3, rot = 120 } } },
	["Varita de Té"] = { rareza = "Raro", luz = hex("#6FC3FF"), estela = hex("#A8DCFF"),
		anillos = { { tex = "runas", c = "#7FCBFF", r = 0.42, ancho = 0.12, vel = 0.5, largo = 0.9, t0 = 0.25 } },
		idle = { { tex = "polvo", c = { "#FFFFFF", "#DDEFFF" }, rate = 2.5, life = { 1, 1.6 }, speed = { 0.2, 0.4 }, accel = Vector3.new(0, 0.9, 0), size = { 0.12, 0.45 }, t0 = 0.5, spread = 25, luz = 0 } },
		golpe = { { tex = "polvo", c = { "#FFFFFF", "#DDEFFF" }, n = 10, life = { 0.6, 0.9 }, speed = { 2, 4 }, size = { 0.3, 0.8 }, t0 = 0.4, spread = 180, drag = 3, luz = 0 },
			{ tex = "chispa", c = { "#FFFFFF", "#6FC3FF" }, n = 8, life = { 0.3, 0.5 }, speed = { 4, 7 }, size = { 0.2, 0 }, spread = 180, drag = 4 } } },
	["Cetro Lunar Kawaii"] = { rareza = "Especial", luz = hex("#FF7AC8"), estela = hex("#FFA8DA"), latido = 0.25,
		idle = { { tex = "destello", c = { "#FFFFFF", "#FF8AD0" }, rate = 3, life = { 1, 1.5 }, speed = { 0.1, 0.3 }, accel = Vector3.new(0, -0.8, 0), size = { 0.14, 0 }, t0 = 0.1, spread = 180, rot = 120 },
			{ tex = "corazon", c = { "#FFD0EC", "#FF5FB8" }, rate = 0.8, life = { 1.2, 1.8 }, speed = { 0.2, 0.4 }, accel = Vector3.new(0, 0.4, 0), size = { 0.18, 0.1 }, t0 = 0.1, spread = 60, rot = 20 } },
		golpe = { { tex = "corazon", c = { "#FFD0EC", "#FF5FB8" }, n = 12, life = { 0.5, 0.8 }, speed = { 5, 8 }, size = { 0.3, 0.15 }, spread = 180, drag = 4, rot = 120 },
			{ tex = "anillo", c = { "#FFFFFF", "#FF7AC8" }, n = 1, life = { 0.3, 0.3 }, speed = { 0, 0 }, size = { 0.4, 3.2 }, t0 = 0.05 } } },
	["Varita de Sellos"] = { rareza = "Especial", luz = hex("#FF3B3B"), estela = hex("#FF6A5A"), latido = 0.2,
		idle = { { tex = "talisman", c = { "#FFF2D8", "#FF4A3A" }, rate = 0.8, life = { 1.4, 2 }, speed = { 0.2, 0.4 }, accel = Vector3.new(0, -0.3, 0), size = { 0.22, 0.2 }, t0 = 0.1, spread = 120, rot = 90, luz = 0.4 },
			{ tex = "chispa", c = { "#FFD2C8", "#FF3B3B" }, rate = 2, life = { 0.5, 0.9 }, speed = { 0.2, 0.4 }, accel = Vector3.new(0, 0.6, 0), size = { 0.12, 0 }, t0 = 0.1, spread = 60 } },
		golpe = { { tex = "talisman", c = { "#FFF2D8", "#FF4A3A" }, n = 8, life = { 0.6, 0.9 }, speed = { 5, 7 }, accel = Vector3.new(0, -6, 0), size = { 0.3, 0.25 }, spread = 180, drag = 3, rot = 300, luz = 0.4 },
			{ tex = "anillo", c = { "#FFB0A0", "#FF3B3B" }, n = 1, life = { 0.3, 0.3 }, speed = { 0, 0 }, size = { 0.4, 3.2 }, t0 = 0.05 } } },
	["Linterna Espiritual"] = { rareza = "Especial", luz = hex("#4FB8FF"), estela = hex("#8FD3FF"), vela = true,
		idle = { { tex = "llama", c = { "#E8F8FF", "#3A9CFF" }, rate = 4, life = { 0.9, 1.4 }, speed = { 0.4, 0.8 }, accel = Vector3.new(0, 0.5, 0), size = { 0.2, 0 }, t0 = 0.1, spread = 180, drag = 1.5 } },
		golpe = { { tex = "llama", c = { "#E8F8FF", "#3A9CFF" }, n = 16, life = { 0.4, 0.7 }, speed = { 5, 8 }, size = { 0.3, 0 }, spread = 180, drag = 4 },
			{ tex = "anillo", c = { "#BFE6FF", "#3A9CFF" }, n = 1, life = { 0.3, 0.3 }, speed = { 0, 0 }, size = { 0.4, 3.5 }, t0 = 0.05 } } },
	["Bastón del Grimorio"] = { rareza = "Legendario", luz = hex("#7FE0FF"), estela = hex("#A8ECFF"), latido = 0.2,
		anillos = { { tex = "pagina", c = "#F4FBFF", r = 1.05, ancho = 0.32, vel = 0.25, largo = 1.6, t0 = 0, camara = true, inclina = 15 } },
		idle = { { tex = "chispa", c = { "#FFFFFF", "#7FE0FF" }, rate = 3, life = { 0.6, 1 }, speed = { 0.2, 0.5 }, accel = Vector3.new(0, 0.7, 0), size = { 0.16, 0 }, t0 = 0.1, spread = 90 } },
		golpe = { { tex = "pagina", c = { "#FFFFFF", "#BFEFFF" }, n = 12, life = { 0.6, 0.9 }, speed = { 6, 9 }, accel = Vector3.new(0, -4, 0), size = { 0.35, 0.3 }, spread = 180, drag = 3, rot = 300, luz = 0.3 },
			{ tex = "anillo", c = { "#E0F8FF", "#7FE0FF" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 4 }, t0 = 0.05 } } },
	["Bastón Reloj de Arena"] = { rareza = "Legendario", luz = hex("#FFC93A"), estela = hex("#FFDA6A"),
		anillos = { { tex = "engrane", c = "#FFD25A", r = 0.95, ancho = 0.3, vel = 0.2, largo = 0.75, t0 = 0, camara = true } },
		idle = { { tex = "grano", c = { "#FFF0B0", "#FFB81F" }, rate = 9, life = { 0.5, 0.8 }, speed = { 0, 0.1 }, accel = Vector3.new(0, -3, 0), size = { 0.07, 0.05 }, t0 = 0, spread = 15, luz = 0.8 } },
		golpe = { { tex = "grano", c = { "#FFF0B0", "#FFB81F" }, n = 22, life = { 0.5, 0.8 }, speed = { 5, 8 }, accel = Vector3.new(0, -12, 0), size = { 0.12, 0.08 }, spread = 180, luz = 0.8 },
			{ tex = "engrane", c = { "#FFE08A", "#FFB81F" }, n = 4, life = { 0.5, 0.7 }, speed = { 4, 6 }, size = { 0.4, 0.3 }, spread = 180, drag = 3, rot = 360 },
			{ tex = "anillo", c = { "#FFF0B0", "#FFC93A" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 4 }, t0 = 0.05 } } },
	["Bastón de Dominio"] = { rareza = "Legendario", luz = hex("#B05CFF"), estela = hex("#C88AFF"),
		anillos = { { tex = "runas", c = "#C07AFF", r = 0.95, ancho = 0.22, vel = 0.35, largo = 1.4, t0 = 0.1, camara = false },
			{ tex = "runas", c = "#E0B8FF", r = 0.75, ancho = 0.16, vel = -0.5, largo = 1.1, t0 = 0.15, inclina = 60, camara = false } },
		idle = { { tex = "humo", c = { "#9A4AE0", "#3A1060" }, rate = 2, life = { 1.4, 2.2 }, speed = { 0.2, 0.4 }, accel = Vector3.new(0, 0.6, 0), size = { 0.4, 1.1 }, t0 = 0.5, spread = 30, luz = 0.2 } },
		golpe = { { tex = "chispa", c = { "#E2C2FF", "#7A2AD9" }, n = 16, life = { 0.3, 0.5 }, speed = { 6, 10 }, size = { 0.28, 0 }, spread = 180, drag = 5 },
			{ tex = "humo", c = { "#9A4AE0", "#3A1060" }, n = 6, life = { 0.6, 1 }, speed = { 2, 4 }, size = { 0.6, 1.4 }, t0 = 0.4, spread = 180, drag = 3, luz = 0.2 },
			{ tex = "anillo", c = { "#D9A8FF", "#7A2AD9" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 4.5 }, t0 = 0.05 } } },
	["Bastón Galaxia"] = { rareza = "Mitico", luz = hex("#FFC857"), estela = hex("#8FA8FF"), latido = 0.3,
		anillos = { { tex = "orbe", c = "#FF9A4A", r = 1.05, ancho = 0.22, vel = 0.22, largo = 2.2, t0 = 0, camara = true, inclina = 12 },
			{ tex = "orbe", c = "#5EC8FF", r = 0.72, ancho = 0.18, vel = 0.4, largo = 1.5, t0 = 0, camara = true, inclina = -8 } },
		idle = { { tex = "destello", c = { "#FFFFFF", "#9FB8FF" }, rate = 3, life = { 0.8, 1.3 }, speed = { 0.3, 0.7 }, size = { 0.14, 0 }, t0 = 0.05, spread = 180, rot = 90 } },
		golpe = { { tex = "destello", c = { "#FFFFFF", "#9FB8FF" }, n = 20, life = { 0.4, 0.7 }, speed = { 6, 10 }, size = { 0.3, 0 }, spread = 180, drag = 4, rot = 300 },
			{ tex = "orbe", c = { "#FFD27A", "#FF9A4A" }, n = 6, life = { 0.5, 0.7 }, speed = { 4, 7 }, size = { 0.3, 0.1 }, spread = 180, drag = 4 },
			{ tex = "anillo", c = { "#FFF0C0", "#FFC857" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 5 }, t0 = 0.05 } } },
	["Bastón del Dragón Celestial"] = { rareza = "Mitico", luz = hex("#BFFFF0"), estela = hex("#5FE8C8"), latido = 0.25,
		idle = { { tex = "nube", c = { "#FFFFFF", "#D8FFF6" }, rate = 1.5, life = { 2, 3 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, 0.15, 0), size = { 0.35, 0.55 }, t0 = 0.35, spread = 180, drag = 0.8, luz = 0.2 },
			{ tex = "chispa", c = { "#FFFFFF", "#5FE8C8" }, rate = 3, life = { 0.6, 1 }, speed = { 0.2, 0.5 }, size = { 0.14, 0 }, t0 = 0.1, spread = 180 } },
		golpe = { { tex = "nube", c = { "#FFFFFF", "#D8FFF6" }, n = 8, life = { 0.7, 1.1 }, speed = { 3, 5 }, size = { 0.5, 1 }, t0 = 0.3, spread = 180, drag = 3, luz = 0.2 },
			{ tex = "chispa", c = { "#FFFFFF", "#5FE8C8" }, n = 16, life = { 0.3, 0.5 }, speed = { 6, 9 }, size = { 0.25, 0 }, spread = 180, drag = 4 },
			{ tex = "anillo", c = { "#E8FFF8", "#5FE8C8" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 5 }, t0 = 0.05 } } },
	["Bastón Cero Absoluto"] = { rareza = "Mitico", luz = hex("#7FD8FF"), estela = hex("#BFF0FF"),
		anillos = { { tex = "engrane", c = "#BFF0FF", r = 1.0, ancho = 0.26, vel = 0.3, largo = 0.8, t0 = 0.05, camara = true, inclina = 10 },
			{ tex = "esfera_reloj", c = "#E8FAFF", r = 0.62, ancho = 0.08, vel = -0.6, largo = 0.9, t0 = 0.2, camara = false } },
		idle = { { tex = "copo", c = { "#FFFFFF", "#9FE4FF" }, rate = 3, life = { 1.6, 2.4 }, speed = { 0.2, 0.5 }, accel = Vector3.new(0, -0.9, 0), size = { 0.15, 0.1 }, t0 = 0.15, spread = 180, rot = 60 },
			{ tex = "esquirla", c = { "#FFFFFF", "#7FD8FF" }, rate = 1.5, life = { 0.8, 1.2 }, speed = { 0.1, 0.3 }, accel = Vector3.new(0, -2, 0), size = { 0.12, 0.08 }, t0 = 0.1, spread = 90, rot = 120 } },
		golpe = { { tex = "esquirla", c = { "#FFFFFF", "#7FD8FF" }, n = 18, life = { 0.4, 0.6 }, speed = { 8, 12 }, size = { 0.35, 0.1 }, spread = 180, drag = 6, rot = 300 },
			{ tex = "copo", c = { "#FFFFFF", "#9FE4FF" }, n = 10, life = { 0.8, 1.2 }, speed = { 3, 5 }, accel = Vector3.new(0, -4, 0), size = { 0.25, 0.15 }, spread = 180, drag = 2, rot = 200 },
			{ tex = "anillo", c = { "#E8FAFF", "#7FD8FF" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 5 }, t0 = 0.05 } } },
	["Bastón de Halloween"] = { rareza = "Mitico", luz = hex("#FF8A2A"), estela = hex("#B05CFF"), vela = true,
		idle = { { tex = "fuego", c = { "#D9A0FF", "#6A1AB0" }, rate = 4, life = { 0.6, 1 }, speed = { 0.4, 0.8 }, accel = Vector3.new(0, 1.4, 0), size = { 0.3, 0 }, t0 = 0.1, spread = 40 },
			{ tex = "chispa", c = { "#FFD27A", "#FF6A10" }, rate = 2, life = { 0.6, 1 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, 1, 0), size = { 0.14, 0 }, t0 = 0.1, spread = 50 },
			{ tex = "humo", c = { "#7A3AB0", "#2A1040" }, rate = 1.5, life = { 1.4, 2.2 }, speed = { 0.2, 0.4 }, accel = Vector3.new(0, 0.5, 0), size = { 0.4, 1 }, t0 = 0.55, spread = 30, luz = 0 } },
		golpe = { { tex = "fuego", c = { "#D9A0FF", "#6A1AB0" }, n = 16, life = { 0.3, 0.5 }, speed = { 4, 7 }, size = { 0.6, 0 }, spread = 180, drag = 4 },
			{ tex = "fuego", c = { "#FFB03A", "#FF4A10" }, n = 10, life = { 0.3, 0.5 }, speed = { 3, 6 }, size = { 0.5, 0 }, spread = 180, drag = 4 },
			{ tex = "anillo", c = { "#D9A0FF", "#6A1AB0" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 5 }, t0 = 0.05 } } },
}

-- ===================== BASTONES MÍTICOS (8 de zero-bastones, se compran con Robux) =====================
-- Modelos en ReplicatedStorage.ZeroBastonesMiticos: Cuerpo + Brillo + piezas Anim_* que mueve ZeroBastonesAnim.
-- Extras: en = dónde nace el emisor ("vacio", "boca" o una pieza Anim_*), retraso (ráfaga en dos tiempos), vacio,
-- vela = pieza que parpadea, parpadeo = pantalla, nombre "ZeroZzz" = se apaga 3 s al golpear.
MAGICAS["Cetro del Vacío Estelar"] = { rareza = "Exclusivo", luz = hex("#B65CFF"), estela = hex("#C88AFF"), latido = 0.2, vacio = 1.9,
	idle = { { tex = "chispa", en = "vacio", inward = true, c = { "#F0D8FF", "#8A2BE2" }, rate = 6, life = { 0.5, 0.7 }, speed = { 1.4, 1.8 }, size = { 0.14, 0.03 }, t0 = 0.15 },
		{ tex = "destello", c = { "#FFF2C8", "#FFB43A" }, rate = 1.5, life = { 0.8, 1.2 }, speed = { 0.1, 0.3 }, size = { 0.14, 0 }, t0 = 0.1, spread = 180, rot = 90 } },
	golpe = { { tex = "chispa", en = "vacio", inward = true, c = { "#FFFFFF", "#8A2BE2" }, n = 30, life = { 0.25, 0.32 }, speed = { 3, 4 }, size = { 0.3, 0.05 }, t0 = 0 },
		{ tex = "chispa", retraso = 0.3, c = { "#FFFFFF", "#B65CFF" }, n = 24, life = { 0.35, 0.6 }, speed = { 8, 12 }, size = { 0.35, 0 }, spread = 180, drag = 5 },
		{ tex = "destello", retraso = 0.3, c = { "#FFF2C8", "#FFB43A" }, n = 12, life = { 0.5, 0.8 }, speed = { 5, 8 }, size = { 0.3, 0 }, spread = 180, drag = 4, rot = 300 },
		{ tex = "humo", retraso = 0.3, c = { "#6A2AB0", "#1A0830" }, n = 6, life = { 0.6, 1 }, speed = { 2, 4 }, size = { 0.6, 1.5 }, t0 = 0.4, spread = 180, drag = 3, luz = 0.2 },
		{ tex = "anillo", retraso = 0.3, c = { "#E0C0FF", "#8A2BE2" }, n = 1, life = { 0.4, 0.4 }, speed = { 0, 0 }, size = { 0.5, 6 }, t0 = 0.05 } } }
MAGICAS["Linterna del Dragón"] = { rareza = "Exclusivo", luz = hex("#FF7A2E"), estela = hex("#FFB04A"), vela = "Anim_Linterna_Brillo",
	idle = { { tex = "chispa", en = "Anim_Linterna_Brillo", c = { "#FFE08A", "#FF4A10" }, rate = 4, life = { 0.6, 1 }, speed = { 0.4, 0.8 }, accel = Vector3.new(0, 1.2, 0), size = { 0.12, 0 }, t0 = 0.1, spread = 60 },
		{ tex = "fuego", en = "Anim_Linterna_Brillo", c = { "#FFD27A", "#FF5A1A" }, rate = 1.5, life = { 0.4, 0.7 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, 1, 0), size = { 0.25, 0 }, t0 = 0.3, spread = 40 } },
	golpe = { { tex = "fuego", en = "boca", c = { "#FFE6A0", "#FF3A10" }, n = 26, life = { 0.35, 0.55 }, speed = { 9, 13 }, size = { 0.4, 1.3 }, t0 = 0.05, spread = 12, drag = 2 },
		{ tex = "chispa", en = "boca", c = { "#FFF0B0", "#FF6A10" }, n = 14, life = { 0.3, 0.5 }, speed = { 8, 12 }, size = { 0.2, 0 }, spread = 20, drag = 3 },
		{ tex = "anillo", c = { "#FFD27A", "#FF5A1A" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 4.5 }, t0 = 0.05 } } }
MAGICAS["Corazón del Lago"] = { rareza = "Exclusivo", luz = hex("#2E7BFF"), estela = hex("#7FD0FF"), latido = 0.2, rayos = { 0.4, 1.2 },
	idle = { { tex = "chispa", c = { "#FFFFFF", "#3A8BFF" }, rate = 3, life = { 0.5, 0.8 }, speed = { 0.2, 0.5 }, size = { 0.14, 0 }, t0 = 0.1, spread = 180 },
		{ tex = "rayo", nombre = "ZeroRayo", c = { "#FFFFFF", "#5FB8FF" }, rate = 0, life = { 0.08, 0.16 }, speed = { 0, 0 }, size = { 0.45, 0.4 }, t0 = 0, spread = 0, rot = 1, fijo = true, luz = 1 } },
	golpe = { { tex = "rayo", c = { "#FFFFFF", "#5FB8FF" }, n = 10, life = { 0.12, 0.22 }, speed = { 5, 9 }, size = { 0.6, 0.45 }, t0 = 0, spread = 180, luz = 1 },
		{ tex = "chispa", c = { "#FFFFFF", "#3A8BFF" }, n = 16, life = { 0.3, 0.5 }, speed = { 6, 10 }, size = { 0.25, 0 }, spread = 180, drag = 5 },
		{ tex = "anillo", c = { "#BFE0FF", "#2E7BFF" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 5 }, t0 = 0.05 } } }
MAGICAS["Gatito Hechicero"] = { rareza = "Mitico", luz = hex("#FFD34D"), estela = hex("#FFE28A"), latido = 0.15,
	idle = { { tex = "z", nombre = "ZeroZzz", en = "VFX_Hit", c = { "#FFFFFF", "#C9B8FF" }, rate = 0.5, life = { 2, 2.6 }, speed = { 0.3, 0.5 }, accel = Vector3.new(0.15, 0.3, 0), size = { 0.12, 0.24 }, t0 = 0.1, spread = 20, rot = 20, luz = 0.3 },
		{ tex = "destello", c = { "#FFF6C8", "#FFC21F" }, rate = 2.5, life = { 1.2, 1.8 }, speed = { 0.1, 0.3 }, accel = Vector3.new(0, -0.8, 0), size = { 0.14, 0 }, t0 = 0.1, spread = 180, rot = 90 } },
	golpe = { { tex = "destello", en = "VFX_Hit", c = { "#FFFFFF", "#FFC21F" }, n = 20, life = { 0.4, 0.7 }, speed = { 5, 8 }, size = { 0.3, 0 }, spread = 180, drag = 4, rot = 300 },
		{ tex = "anillo", en = "VFX_Hit", c = { "#FFF2C0", "#FFD34D" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.4, 4 }, t0 = 0.05 } } }
MAGICAS["Origami Celestial"] = { rareza = "Exclusivo", luz = hex("#FFE6A8"), estela = hex("#FFD27A"), latido = 0.15,
	idle = { { tex = "destello", c = { "#FFFFFF", "#FFD27A" }, rate = 3, life = { 0.8, 1.3 }, speed = { 0.1, 0.4 }, size = { 0.14, 0 }, t0 = 0.05, spread = 180, rot = 90 },
		{ tex = "talisman", c = { "#FFF6E0", "#F3E7D2" }, rate = 0.6, life = { 1.6, 2.4 }, speed = { 0.2, 0.4 }, accel = Vector3.new(0, -0.3, 0), size = { 0.2, 0.18 }, t0 = 0.1, spread = 180, rot = 60, luz = 0.2 } },
	golpe = { { tex = "talisman", c = { "#FFF6E0", "#E9B23E" }, n = 10, life = { 0.6, 0.9 }, speed = { 6, 9 }, accel = Vector3.new(0, -5, 0), size = { 0.3, 0.25 }, spread = 180, drag = 3, rot = 360, luz = 0.2 },
		{ tex = "destello", c = { "#FFFFFF", "#FFD27A" }, n = 16, life = { 0.4, 0.6 }, speed = { 6, 9 }, size = { 0.3, 0 }, spread = 180, drag = 4, rot = 300 },
		{ tex = "anillo", c = { "#FFF6E0", "#E9B23E" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 5 }, t0 = 0.05 } } }
MAGICAS["Arcade Retro"] = { rareza = "Exclusivo", luz = hex("#3FE6FF"), estela = hex("#FF4FD8"), parpadeo = { 0.8, 2.2 },
	idle = { { tex = "pixel", c = { "#3FE6FF", "#FF4FD8" }, rate = 4, life = { 0.6, 1 }, speed = { 0.5, 1 }, accel = Vector3.new(0, 0.4, 0), size = { 0.08, 0.06 }, t0 = 0, spread = 70, drag = 1 } },
	golpe = { { tex = "moneda_pixel", c = { "#FFF0A0", "#FFD23A" }, n = 14, life = { 0.6, 0.9 }, speed = { 5, 8 }, accel = Vector3.new(0, -14, 0), size = { 0.22, 0.22 }, t0 = 0, spread = 180, rot = 0, luz = 0.6 },
		{ tex = "pixel", c = { "#FF4FD8", "#3FE6FF" }, n = 16, life = { 0.4, 0.6 }, speed = { 6, 9 }, size = { 0.12, 0.06 }, t0 = 0, spread = 180, drag = 3 },
		{ tex = "anillo", c = { "#BFF8FF", "#3FE6FF" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 5 }, t0 = 0.05 } } }
MAGICAS["Corona del Bufón"] = { rareza = "Exclusivo", luz = hex("#B04CFF"), estela = hex("#C88AFF"),
	idle = { { tex = "destello", c = { "#FFF2C8", "#F0B23A" }, rate = 2, life = { 0.8, 1.2 }, speed = { 0.1, 0.3 }, size = { 0.14, 0 }, t0 = 0.05, spread = 180, rot = 90 },
		{ tex = "chispa", c = { "#E8C8FF", "#B04CFF" }, rate = 2, life = { 0.5, 0.8 }, speed = { 0.2, 0.4 }, size = { 0.12, 0 }, t0 = 0.1, spread = 180 } },
	golpe = { { tex = "naipe", c = { "#FFFFFF", "#F1E6D2" }, n = 10, life = { 0.7, 1 }, speed = { 6, 9 }, accel = Vector3.new(0, -5, 0), size = { 0.3, 0.3 }, t0 = 0, spread = 180, drag = 2, rot = 420, luz = 0.1 },
		{ tex = "destello", c = { "#FFF2C8", "#F0B23A" }, n = 10, life = { 0.4, 0.6 }, speed = { 5, 8 }, size = { 0.28, 0 }, spread = 180, drag = 4, rot = 300 },
		{ tex = "anillo", c = { "#E0B8FF", "#B04CFF" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 5 }, t0 = 0.05 } } }
MAGICAS["Espejo del Alma"] = { rareza = "Exclusivo", luz = hex("#7A4CFF"), estela = hex("#FF4F7A"),
	idle = { { tex = "espiral", c = { "#F0D8FF", "#8A5CFF" }, rate = 0.5, life = { 4, 4 }, speed = { 0, 0 }, size = { 0.9, 0.9 }, t0 = 0.25, rotFija = 50, fijo = true, luz = 1 },
		{ tex = "petalo", c = { "#FF5A74", "#B0172E" }, rate = 2, life = { 1.6, 2.4 }, speed = { 0.3, 0.6 }, accel = Vector3.new(0, -1, 0), size = { 0.14, 0.12 }, t0 = 0.05, spread = 180, rot = 120, luz = 0.2 } },
	golpe = { { tex = "petalo", c = { "#FF5A74", "#B0172E" }, n = 20, life = { 0.6, 0.9 }, speed = { 5, 8 }, accel = Vector3.new(0, -4, 0), size = { 0.22, 0.18 }, spread = 180, drag = 3, rot = 300, luz = 0.2 },
		{ tex = "espiral", c = { "#FFFFFF", "#8A5CFF" }, n = 1, life = { 0.5, 0.5 }, speed = { 0, 0 }, size = { 0.5, 2.5 }, t0 = 0, rotFija = 400 },
		{ tex = "anillo", c = { "#FFC0D0", "#FF4F7A" }, n = 1, life = { 0.35, 0.35 }, speed = { 0, 0 }, size = { 0.5, 5 }, t0 = 0.05 } } }
ZeroArmasVFX.MAGICAS = MAGICAS

-- anillo de dos Beams en semicírculo alrededor de `centro`, perpendicular a `eje` (inclinado `e.inclina` grados);
-- la textura corre a lo largo (TextureSpeed), así parece que lo que hay en él gira
local function anilloBeams(cuerpo: BasePart, centro: Vector3, eje: Vector3, e, i: number)
	local u = eje:Cross(if math.abs(eje.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
	local w = eje:Cross(u).Unit
	local inc = math.rad(e.inclina or 0)
	w = (w * math.cos(inc) + eje * math.sin(inc)).Unit
	local c = centro + eje * (e.alto or 0)
	local r = e.r
	local function att(n: string, p: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Name = "ZeroAnillo" .. i .. n
		a.CFrame = CFrame.fromMatrix(p, w, u:Cross(w))          -- eje X (Axis) = w: hacia donde se curva el Beam
		a.Parent = cuerpo
		return a
	end
	local a0, a1 = att("A", c + u * r), att("B", c - u * r)
	local k = r * 4 / 3                                       -- asas de Bézier de un semicírculo
	for j, curva in { { a0, a1, k, -k }, { a1, a0, -k, k } } do
		local b = Instance.new("Beam")
		b.Name = "ZeroAnillo"
		b.Attachment0, b.Attachment1 = curva[1], curva[2]
		b.CurveSize0, b.CurveSize1 = curva[3], curva[4]
		b.Texture = TEX[e.tex]
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = e.largo or 1
		b.TextureSpeed = e.vel or 0.3
		b.Width0, b.Width1 = e.ancho, e.ancho
		b.FaceCamera = e.camara ~= false
		b.Segments = 24
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = ColorSequence.new(hex(e.c))
		b.Transparency = NumberSequence.new(e.t0 or 0.1)
		b.Parent = cuerpo
	end
end

local function applyMagica(model: Instance, name: string, cuerpo: BasePart)
	local m = MAGICAS[name]
	local esc = ESCALA[m.rareza]
	local brillo = model:FindFirstChild("Brillo") :: BasePart?
	local function att(n: string, fallback: Vector3): Attachment
		local a = cuerpo:FindFirstChild(n) :: Attachment?
		if a then return a end
		a = Instance.new("Attachment"); a.Name = n; a.Position = fallback; a.Parent = cuerpo
		return a
	end
	local idle = att("VFX_Idle", Vector3.zero)
	local hit = att("VFX_Hit", idle.Position)
	local ta, tb = att("Trail_A", Vector3.zero), att("Trail_B", idle.Position)
	local eje = (tb.Position - ta.Position).Unit                 -- del agarre a la punta (en el espacio del Cuerpo)
	-- estela: en los bastones solo la mitad alta (la vara entera sería un abanico)
	local largo = (tb.Position - ta.Position).Magnitude
	local e0 = Instance.new("Attachment"); e0.Name = "ZeroEstelaBase"; e0.Position = ta.Position + eje * (if largo > 3 then largo * 0.45 else largo * 0.2); e0.Parent = cuerpo
	local tr = Instance.new("Trail")
	tr.Name = "ZeroEstela"
	tr.Attachment0, tr.Attachment1 = e0, tb
	tr.Lifetime = if m.rareza == "Comun" then 0.18 elseif m.rareza == "Raro" then 0.24 else 0.32
	tr.MinLength = 0.05; tr.FaceCamera = false
	tr.LightEmission = m.estelaLuz or 0.8
	tr.Color = ColorSequence.new(m.estela)
	tr.Transparency = seq(nk(0, if m.rareza == "Comun" then 0.35 else 0.12), nk(1, 1))
	tr.WidthScale = seq(nk(0, 1), nk(1, 0.3))
	tr.Enabled = false
	tr.Parent = cuerpo
	-- dónde nace cada emisor (e.en): esfera de vacío, boca orientada (de VFX_Hit hacia VFX_Idle) o una pieza Anim_*
	local sitios = { VFX_Hit = hit, VFX_Idle = idle }
	if m.vacio then
		local esfera = Instance.new("Part")
		esfera.Name = "ZeroVacio"; esfera.Shape = Enum.PartType.Ball; esfera.Size = Vector3.one * m.vacio
		esfera.Transparency = 1; esfera.CanCollide = false; esfera.CanTouch = false; esfera.CanQuery = false; esfera.Massless = true
		esfera.Anchored = cuerpo.Anchored; esfera.CFrame = idle.WorldCFrame
		local w = Instance.new("WeldConstraint"); w.Part0, w.Part1 = cuerpo, esfera; w.Parent = esfera
		esfera.Parent = model
		sitios.vacio = esfera
	end
	local dirBoca = idle.Position - hit.Position
	if dirBoca.Magnitude > 1e-3 then
		local boca = Instance.new("Attachment"); boca.Name = "ZeroBoca"
		boca.CFrame = CFrame.lookAt(hit.Position, hit.Position + dirBoca) * CFrame.Angles(-math.pi / 2, 0, 0)   -- +Y = hacia donde escupe
		boca.Parent = cuerpo
		sitios.boca = boca
	end
	local function sitio(e)
		if not e.en then return nil end
		if sitios[e.en] then return sitios[e.en] end
		local pieza = model:FindFirstChild(e.en) :: BasePart?
		if pieza then
			local a = Instance.new("Attachment"); a.Name = "ZeroSitio"; a.Parent = pieza   -- centro de la pieza: la sigue al moverse
			sitios[e.en] = a
			return a
		end
		return nil
	end
	-- partículas de reposo y de golpe
	for _, e in m.idle do emisor(e, sitio(e) or idle, e.nombre or "ZeroIdle", false, esc) end
	for _, e in m.golpe do emisor(e, sitio(e) or hit, "ZeroGolpe", true, esc) end
	for i, e in m.anillos or {} do anilloBeams(cuerpo, idle.Position, eje, e, i) end
	-- luz y destello de golpe
	local luz = Instance.new("PointLight")
	luz.Name = "ZeroLuz"; luz.Color = m.luz; luz.Range = esc.luz[1]; luz.Brightness = esc.luz[2]; luz.Shadows = false
	luz.Parent = idle
	local flash = Instance.new("PointLight")
	flash.Name = "ZeroDestello"; flash.Color = m.luz; flash.Range = esc.luz[1] + 4; flash.Brightness = 0; flash.Shadows = false
	flash.Parent = hit
	-- aura de destellos en la pieza brillante (legendarias y míticas)
	if brillo and (m.rareza == "Legendario" or m.rareza == "Mitico" or m.rareza == "Exclusivo") then
		local aura = emisor({ tex = "chispa", c = { "#FFFFFF", m.luz:ToHex() }, rate = if m.rareza == "Mitico" or m.rareza == "Exclusivo" then 6 else 4, life = { 0.4, 0.7 },
			speed = { 0, 0.3 }, size = { 0.14, 0 }, t0 = 0.05, spread = 180, luz = 1 }, brillo, "ZeroIdle", false, { rate = 1, size = 1, rafaga = 1 })
		aura:SetAttribute("Aura", true)
	end
	-- extras
	if m.latido and brillo then                                -- el Brillo late
		local t0 = os.clock()
		bucle(model, function() brillo.Transparency = m.latido * (0.5 + 0.5 * math.sin((os.clock() - t0) * 4)); task.wait(0.05) end)
	end
	local llama = if type(m.vela) == "string" then model:FindFirstChild(m.vela) :: BasePart? else brillo
	if m.vela and llama then                                   -- parpadeo de llama (en el Brillo o en la pieza indicada)
		bucle(model, function() llama.Transparency = math.random() * 0.3; task.wait(0.06 + math.random() * 0.12) end)
	end
	if m.parpadeo and brillo then                              -- pantalla que parpadea de vez en cuando
		bucle(model, function()
			task.wait(m.parpadeo[1] + math.random() * (m.parpadeo[2] - m.parpadeo[1]))
			for _ = 1, math.random(2, 4) do brillo.Transparency = 0.45; task.wait(0.04); brillo.Transparency = 0; task.wait(0.06) end
		end)
	end
	if m.rayos then                                            -- rayos dentro del orbe a ráfagas
		local rayo = idle:FindFirstChild("ZeroRayo") :: ParticleEmitter?
		bucle(model, function()
			task.wait(m.rayos[1] + math.random() * (m.rayos[2] - m.rayos[1]))
			if rayo and rayo.Parent and rayo.Enabled then rayo:Emit(math.random(1, 3)) end
		end)
	end
end

local function cuerpoOf(model: Instance): BasePart?
	return (model:FindFirstChild("Cuerpo") or model:FindFirstChildWhichIsA("BasePart")) :: BasePart?
end

function ZeroArmasVFX.apply(model: Instance, name: string)
	local a = ARMAS[name]
	local cuerpo = cuerpoOf(model)
	if MITICAS[name] then
		if cuerpo then applyMitica(model, name, cuerpo) end
		return
	end
	if MAGICAS[name] then
		if cuerpo then applyMagica(model, name, cuerpo) end
		return
	end
	if not a or not cuerpo then return end
	local brillo = model:FindFirstChild("Brillo") :: BasePart?
	if brillo then
		brillo.Material = Enum.Material.Neon
		brillo.Color = a.detalle
	end
	-- estela en el tramo final de la hoja: el origen de la malla es el centro del mango y la hoja apunta a -Z.
	-- PuntaZ/Largo los pone el importador; si faltan, se estiman con el tamaño de la pieza.
	local puntaZ = (cuerpo:GetAttribute("PuntaZ") :: number?) or -cuerpo.Size.Z * 0.75
	local largo = (cuerpo:GetAttribute("Largo") :: number?) or cuerpo.Size.Z
	local tramo = math.min(1.6, largo * 0.4)
	local tip = Instance.new("Attachment"); tip.Name = "ZeroEstelaPunta"; tip.Position = Vector3.new(0, 0, puntaZ + 0.08); tip.Parent = cuerpo
	local mid = Instance.new("Attachment"); mid.Name = "ZeroEstelaBase"; mid.Position = Vector3.new(0, 0, puntaZ + tramo); mid.Parent = cuerpo
	local cfg = TRAIL[a.rareza]
	local tr = Instance.new("Trail")
	tr.Name = "ZeroEstela"
	tr.Attachment0, tr.Attachment1 = mid, tip
	tr.Lifetime = cfg.life
	tr.MinLength = 0.05
	tr.FaceCamera = false
	tr.LightEmission = cfg.light
	tr.Color = ColorSequence.new(cfg.color(a))
	tr.Transparency = seq(nk(0, cfg.t0), nk(1, 1))
	tr.WidthScale = seq(nk(0, 1), nk(1, 0.4))
	tr.Enabled = false
	tr.Parent = cuerpo
	-- reposo: solo Especial y Legendario
	if a.rareza == "Especial" or a.rareza == "Legendario" then
		themed(name, a, brillo or cuerpo)
		local light = Instance.new("PointLight")
		light.Name = "ZeroLuz"
		light.Color = a.detalle
		light.Range = if a.rareza == "Legendario" then 6 else 4
		light.Brightness = if a.rareza == "Legendario" then 0.8 else 0.5
		light.Shadows = false
		light.Parent = brillo or cuerpo
	end
	if name == "Relámpago" then                         -- ráfaga de chispas cada 1.5–3.5 s mientras exista
		local emitter = (brillo or cuerpo):FindFirstChild("ZeroIdle") :: ParticleEmitter?
		task.spawn(function()
			while emitter and emitter.Parent do
				task.wait(1.5 + math.random() * 2)
				if emitter.Parent and emitter.Enabled then emitter:Emit(math.random(4, 7)) end
			end
		end)
	end
end

function ZeroArmasVFX.swing(model: Instance, duration: number?)
	local cuerpo = cuerpoOf(model)
	local tr = cuerpo and cuerpo:FindFirstChild("ZeroEstela") :: Trail?
	if not tr then return end
	local nucleo = cuerpo:FindFirstChild("ZeroEstelaNucleo") :: Trail?
	tr.Enabled = true
	if nucleo then nucleo.Enabled = true end
	task.delay(duration or 0.25, function()
		if tr.Parent then tr.Enabled = false end
		if nucleo and nucleo.Parent then nucleo.Enabled = false end
	end)
	local n = model:GetAttribute("Arma")
	if n and (MITICAS[n] or MAGICAS[n]) then task.delay(0.12, golpeMitica, model) end      -- ráfaga de golpe (míticas y mágicas)
end

function ZeroArmasVFX.setIdle(model: Instance, on: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Name == "ZeroIdle" then d.Enabled = on end
		if d:IsA("PointLight") and d.Name == "ZeroLuz" then d.Enabled = on end
	end
end

return ZeroArmasVFX
