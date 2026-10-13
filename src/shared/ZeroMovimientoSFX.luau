-- ZeroMovimientoSFX: sonidos 3D de movimiento y golpes, colgados del HumanoidRootPart de cada personaje para que
-- también los oigan los jugadores cercanos. Los dispara ZeroMovement (que ya sabe en cada cliente cuándo salta,
-- aterriza, se desliza, hace dash, golpea o pisa cada personaje), así que no hay red de por medio.
-- Cada sonido tiene variantes y un poco de tono al azar para que no suene repetido. Pasan por el grupo ZeroSFX
-- (volumen de efectos de los ajustes).
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local ALCANCE = 60                       -- studs: a partir de aquí ya no se oye
-- cue = { variantes { id, inicio (s, salta el silencio del principio), ganancia (iguala la sonoridad) }, volumen, tono,
--         variación de tono }. Generada por zero-anims/scripts/elegir_sfx.py: los audios se eligen allí.
local CUES = {
	Salto = { { { 117021636310112, 0.00, 1.02 }, { 132163823091536, 0.01, 0.85 }, { 73544689711793, 0.00, 1.05 }, { 77878671889615, 0.00, 1.00 } }, 0.45, 1, 0.06 },
	Aterrizaje = { { { 9113524237, 0.02, 1.00 }, { 9113480915, 0.07, 2.00 } }, 0.55, 1, 0.08 },
	Voltereta = { { { 9113475819, 0.00, 1.00 }, { 9113481839, 0.09, 1.36 } }, 0.5, 1, 0.05 },
	Deslizar = { { { 134781979035978, 0.02, 2.00 }, { 105967658654276, 0.09, 1.00 } }, 0.6, 1, 0.05 },
	Dash = { { { 137322083927464, 0.03, 1.11 }, { 79833203443837, 0.10, 1.00 } }, 0.5, 1, 0.06 },
	DashMortal = { { { 138269694368715, 0.17, 1.58 }, { 9126229255, 0.09, 1.00 } }, 0.5, 1, 0.04 },
	PasoDuro = { { { 133325104274958, 0.02, 0.82 }, { 140594308250996, 0.06, 0.73 }, { 80346333847986, 0.05, 1.11 }, { 82615619091463, 0.02, 1.00 }, { 85682518019906, 0.06, 1.82 }, { 93803555891980, 0.03, 1.22 } }, 0.4, 1, 0.08 },
	PasoPasto = { { { 129956418693357, 0.00, 0.72 }, { 78534941650081, 0.00, 1.00 }, { 110522236020035, 0.00, 1.19 }, { 135037154891351, 0.00, 1.01 } }, 0.45, 1, 0.08 },
	PasoMadera = { { { 121617932377026, 0.03, 0.78 }, { 115817643566886, 0.06, 1.05 }, { 83590661139010, 0.05, 1.20 }, { 81644808425479, 0.07, 1.00 } }, 0.4, 1, 0.08 },
	GolpeCorte = { { { 109999522248865, 0.04, 0.50 }, { 5789211405, 0.05, 1.00 }, { 132132172209744, 0.04, 1.05 } }, 0.5, 1, 0.07 },
	GolpePesado = { { { 101266427032050, 0.10, 0.92 }, { 125914564702009, 0.07, 1.00 }, { 84894992438545, 0.09, 1.00 } }, 0.55, 1, 0.05 },
	GolpeLanza = { { { 107180316607501, 0.11, 1.00 }, { 111254855668531, 0.09, 1.70 } }, 0.5, 1, 0.06 },
	GolpeGarras = { { { 116381638709798, 0.07, 0.79 }, { 132696939822714, 0.10, 1.00 }, { 106456870308007, 0.03, 1.26 } }, 0.45, 1.05, 0.1 },
	Impacto = { { { 9117969687, 0.01, 1.35 }, { 9117969717, 0.04, 1.00 }, { 9117970193, 0.01, 0.97 } }, 0.4, 1, 0.06 },
}
local GOLPE = { Espada = "GolpeCorte", Estoque = "GolpeCorte", Daga = "GolpeCorte", Hacha = "GolpePesado",
	Guadana = "GolpePesado", Lanza = "GolpeLanza", Garras = "GolpeGarras" }
local PASTO = { Grass = true, LeafyGrass = true, Ground = true, Mud = true, Sand = true, Snow = true, Fabric = true }
local MADERA = { Wood = true, WoodPlanks = true }

local Sfx = {}
local sfxGroup = SoundService:FindFirstChild("ZeroSFX")
local rng = Random.new()

local function voice(root: BasePart, cue: string, index: number): Sound
	local name = "ZS_" .. cue .. index
	local sound = root:FindFirstChild(name) :: Sound
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name; sound.SoundId = "rbxassetid://" .. CUES[cue][1][index][1]
		sound.RollOffMode = Enum.RollOffMode.InverseTapered; sound.RollOffMinDistance = 8; sound.RollOffMaxDistance = ALCANCE
		sfxGroup = sfxGroup or SoundService:FindFirstChild("ZeroSFX"); sound.SoundGroup = sfxGroup
		sound.Parent = root
	end
	return sound
end

-- un sonido en el personaje; gain multiplica el volumen y pitch el tono del cue
function Sfx.play(root: BasePart?, cue: string, gain: number?, pitch: number?)
	local c = CUES[cue]
	if not root or not c then return end
	local index = rng:NextInteger(1, #c[1])
	local v, sound = c[1][index], voice(root, cue, index)
	sound.Volume = c[2] * v[3] * (gain or 1)
	sound.PlaybackSpeed = c[3] * (pitch or 1) * (1 + rng:NextNumber(-c[4], c[4]))
	sound.TimePosition = v[2]; sound:Play()
end

-- corta lo que esté sonando de un cue (el deslizamiento al levantarse)
function Sfx.stop(root: BasePart?, cue: string)
	if not root or not CUES[cue] then return end
	for i in CUES[cue][1] do
		local sound = root:FindFirstChild("ZS_" .. cue .. i) :: Sound
		if sound then sound:Stop() end
	end
end

function Sfx.golpe(root: BasePart?, familia: string, pitch: number?)
	Sfx.play(root, GOLPE[familia] or "GolpeCorte", 1, pitch)
end

function Sfx.paso(root: BasePart?, material: Enum.Material, gain: number, pitch: number)
	Sfx.play(root, PASTO[material.Name] and "PasoPasto" or MADERA[material.Name] and "PasoMadera" or "PasoDuro", gain, pitch)
end

-- los sonidos genéricos de Roblox (RbxCharacterSounds) que ahora hacemos nosotros: se silencian
local DEFAULT = { Jumping = true, Landing = true, Running = true }
function Sfx.silenciarRoblox(root: BasePart): RBXScriptConnection
	local function mute(child)
		if child:IsA("Sound") and DEFAULT[child.Name] then child.Volume = 0 end
	end
	for _, child in root:GetChildren() do mute(child) end
	return root.ChildAdded:Connect(mute)
end

task.spawn(function()
	local all = {}
	for _, c in CUES do
		for _, v in c[1] do
			local s = Instance.new("Sound"); s.SoundId = "rbxassetid://" .. v[1]; table.insert(all, s)
		end
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, all)
end)

return Sfx
