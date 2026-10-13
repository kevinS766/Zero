-- ZeroArmasServer (Script, ServerScriptService): pone el arma cosmética equipada sobre el cuchillo del cazador.
-- No toca CombatService: el HunterKnife sigue siendo el mismo Tool (misma hitbox y alcance); solo se oculta su
-- Handle y se suelda encima el modelo de ReplicatedStorage.ZeroArmasModelos.<Nombre>.
-- Si el modelo aún no existe (FBX sin importar), el cuchillo se queda como estaba.
-- Quien NO es cazador (corredores, lobby, bots) lleva su arma equipada a la espalda (ZeroArmaEspalda, soldada al
-- Torso); el cazador no, porque la lleva en la mano.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("ZeroArmasConfig"))
local VFX = require(ReplicatedStorage:WaitForChild("ZeroArmasVFX"))

local function ownerOf(tool: Tool): Player?
	return tool:FindFirstAncestorOfClass("Player") or Players:GetPlayerFromCharacter(tool.Parent)
end

-- Suelda todas las piezas de `m` a `part` donde están ahora
local function weldTo(m: Model, part: BasePart)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
			if not p:FindFirstChild("AnimWeld") then           -- piezas Anim_* de los bastones: ya van soldadas al Cuerpo (se mueven)
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = part, p
				w.Parent = p
			end
		end
	end
end

-- Garras tipo Wolverine: salen de los nudillos de cada mano y siguen el antebrazo (la hoja, -Z del modelo, va
-- hacia -Y del brazo; las tres cuchillas se abren a lo ancho de la mano). La izquierda es la misma girada 180º.
local GARRA_DER = CFrame.fromMatrix(Vector3.new(0, -0.95, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0))
local GARRA_IZQ = CFrame.fromMatrix(Vector3.new(0, -0.95, 0), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0))

-- arma de un personaje: la equipada del jugador; los bots, una fija por bot (sin míticas) para que haya variedad
local function armaDe(character: Instance?, player: Player?): string
	if player then return player:GetAttribute("ZeroPruebaArma") or player:GetAttribute("ArmaEquipada") or Config.ArmaInicial end   -- ZeroPruebaArma: arena de pruebas
	local id = character and character:GetAttribute("BotActorId")
	if type(id) == "number" then
		local normales = {}
		for _, a in Config.Armas do if a.rareza ~= "Mitico" and a.rareza ~= "Exclusivo" then table.insert(normales, a.nombre) end end
		return normales[math.abs(id) % #normales + 1]
	end
	return Config.ArmaInicial
end

local function clear(tool: Tool)
	for _, n in { "ZeroArma", "ZeroArmaIzq" } do
		local old = tool:FindFirstChild(n)
		if old then old:Destroy() end
	end
end

local function attach(tool: Tool)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then return end
	local old = tool:FindFirstChild("ZeroArma")
	local player = ownerOf(tool)
	local character = tool.Parent
	local nombre = armaDe(if character and character:IsA("Model") then character else nil, player)
	local enMano = character and character:FindFirstChildOfClass("Humanoid") ~= nil
	local garras = Config.Familias[nombre] == "Garras"
	-- casilla de la mochila: icono del arma en vez del texto "HunterKnife"
	tool.TextureId = Config.Iconos[nombre] or ""
	tool.ToolTip = nombre
	-- las garras van en los brazos: solo existen mientras el arma está en la mano
	if old and old:GetAttribute("Arma") == nombre and (not garras or old:GetAttribute("EnMano") == enMano) then return end
	clear(tool)
	local modelos = ReplicatedStorage:FindFirstChild("ZeroArmasModelos")
	local plantilla = modelos and modelos:FindFirstChild(nombre)
	if not plantilla then handle.Transparency = 0; return end
	handle.Transparency = 1
	if garras then
		local derecho = character and character:FindFirstChild("Right Arm") :: BasePart?
		local izquierdo = character and character:FindFirstChild("Left Arm") :: BasePart?
		local marca = Instance.new("Model"); marca.Name = "ZeroArma"; marca:SetAttribute("Arma", nombre); marca:SetAttribute("EnMano", enMano)
		if not (enMano and derecho and izquierdo) then marca.Parent = tool; return end   -- en la mochila: nada visible
		marca:Destroy()
		for _, lado in { { "ZeroArma", derecho, GARRA_DER }, { "ZeroArmaIzq", izquierdo, GARRA_IZQ } } do
			local m = plantilla:Clone()
			m.Name = lado[1]; m:SetAttribute("Arma", nombre); m:SetAttribute("EnMano", true)
			m:PivotTo(lado[2].CFrame * lado[3])
			weldTo(m, lado[2])
			m.Parent = tool
			VFX.apply(m, nombre)
		end
		return
	end
	local m = plantilla:Clone()
	m.Name = "ZeroArma"
	m:SetAttribute("Arma", nombre)
	-- la punta del modelo apunta a -Z con el pivote en el agarre. Varitas: hacia delante (+Y del Handle). Bastones
	-- (más de 3 studs): en vertical como un báculo (+Z del Handle), 20º hacia delante
	local cuerpo = m:FindFirstChild("Cuerpo")
	local largo = cuerpo and cuerpo:GetAttribute("Largo") or 0
	m:PivotTo(handle.CFrame * CFrame.Angles(math.rad(if largo > 3 then 160 else 90), 0, 0))
	weldTo(m, handle)
	m.Parent = tool
	VFX.apply(m, nombre)
end

local watched: { [Tool]: boolean } = {}
local function watch(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= "HunterKnife" or watched[tool] then return end
	watched[tool] = true
	attach(tool)
	tool.AncestryChanged:Connect(function()
		if not tool.Parent then watched[tool] = nil else attach(tool) end   -- de Backpack al personaje
	end)
end

for _, root in { workspace, Players } do                       -- personajes y Backpacks
	root.DescendantAdded:Connect(watch)
	for _, d in root:GetDescendants() do task.spawn(watch, d) end
end

-- estela en cada golpe: CombatService suma ZeroAtaqueSerial en el personaje (jugadores y bots)
local hooked: { [Model]: boolean } = {}
local function hookCharacter(char: Instance)
	if not char:IsA("Model") or hooked[char] then return end
	hooked[char] = true
	char:GetAttributeChangedSignal("ZeroAtaqueSerial"):Connect(function()
		local tool = char:FindFirstChild("HunterKnife")
		for _, n in { "ZeroArma", "ZeroArmaIzq" } do
			local m = tool and tool:FindFirstChild(n)
			if m then VFX.swing(m) end
		end
	end)
	char.Destroying:Connect(function() hooked[char] = nil end)
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") and d.Parent then hookCharacter(d.Parent) end
end)
for _, d in workspace:GetDescendants() do if d:IsA("Humanoid") and d.Parent then hookCharacter(d.Parent) end end

-- ------------------------------------------------------------------ arma a la espalda
-- En diagonal sobre la espalda (la punta arriba a la derecha), con la cara del concepto hacia atrás y centrada a lo largo.
local DIAGONAL = Vector3.new(0.5, 0.866, 0)
local function espalda(character: Model)
	local old = character:FindFirstChild("ZeroArmaEspalda")
	local player = Players:GetPlayerFromCharacter(character)
	local rol = if player then player:GetAttribute("Role") else character:GetAttribute("Role")
	local torso = (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")) :: BasePart?
	local nombre = armaDe(character, player)
	if rol == "Hunter" or (player and player:GetAttribute("ZeroPruebas")) or not torso then if old then old:Destroy() end; return end
	if old and old:GetAttribute("Arma") == nombre then return end
	if old then old:Destroy() end
	local modelos = ReplicatedStorage:FindFirstChild("ZeroArmasModelos")
	local plantilla = modelos and modelos:FindFirstChild(nombre)
	if not plantilla then return end
	local m = plantilla:Clone()
	m.Name = "ZeroArmaEspalda"
	m:SetAttribute("Arma", nombre)
	local cuerpo = m:FindFirstChild("Cuerpo") :: BasePart?
	local puntaZ = cuerpo and cuerpo:GetAttribute("PuntaZ") or -1
	local largo = cuerpo and cuerpo:GetAttribute("Largo") or 2
	local zMedio = puntaZ + largo / 2                           -- centro del arma a lo largo (-Z = punta)
	local z = -DIAGONAL.Unit                                    -- el eje Z del modelo apunta al revés que la punta
	local x = Vector3.new(0, 0, 1)                              -- la cara (grosor en X) mira hacia atrás
	local giro = CFrame.fromMatrix(Vector3.zero, x, z:Cross(x), z)
	m:PivotTo(torso.CFrame * CFrame.new(0, 0.1, 0.72) * giro * CFrame.new(0, 0, -zMedio))
	weldTo(m, torso)
	m.Parent = character
	VFX.apply(m, nombre)
end

local espaldas: { [Model]: boolean } = {}
local function vigilarEspalda(character: Instance)
	if not character:IsA("Model") or espaldas[character] then return end
	espaldas[character] = true
	task.spawn(function()
		if not character:WaitForChild("Torso", 10) and not character:FindFirstChild("UpperTorso") then return end
		espalda(character)
	end)
	character:GetAttributeChangedSignal("Role"):Connect(function() espalda(character) end)      -- bots
	character.Destroying:Connect(function() espaldas[character] = nil end)
end
for _, p in Players:GetPlayers() do if p.Character then vigilarEspalda(p.Character) end end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(vigilarEspalda) end)
for _, p in Players:GetPlayers() do p.CharacterAdded:Connect(vigilarEspalda) end
local function vigilarBots(folder: Instance)
	folder.ChildAdded:Connect(vigilarEspalda)
	for _, b in folder:GetChildren() do vigilarEspalda(b) end
end
if workspace:FindFirstChild("ZeroBots") then vigilarBots(workspace.ZeroBots) end
workspace.ChildAdded:Connect(function(c) if c.Name == "ZeroBots" then vigilarBots(c) end end)

-- cambiar de arma con el cuchillo ya en la mano
local function onPlayer(player: Player)
	local function cambio()
		for tool in watched do
			if ownerOf(tool) == player then attach(tool) end
		end
		if player.Character then espalda(player.Character) end
	end
	player:GetAttributeChangedSignal("ArmaEquipada"):Connect(cambio)
	player:GetAttributeChangedSignal("ZeroPruebaArma"):Connect(cambio)   -- arena de pruebas
	player:GetAttributeChangedSignal("ZeroPruebas"):Connect(cambio)
	player:GetAttributeChangedSignal("Role"):Connect(function() if player.Character then espalda(player.Character) end end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
