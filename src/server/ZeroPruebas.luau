-- ZeroPruebas (ModuleScript, ServerScriptService): ARENA DE PRUEBAS para KaiBit23 y admins. Un botón (ZeroPruebasClient)
-- te lleva a una baseplate lejos del mapa con marcas de distancia y dummies (quietos y moviéndose). Dentro:
--   · las habilidades de arma (tecla E) funcionan sin ronda, sin ser cazador y SIN COOLDOWN (ZeroHabilidadArmaServer);
--   · eliges con qué arma probar aunque no la tengas (atributo ZeroPruebaArma, no toca tu inventario): te da el arma en
--     la mano (Tool HunterKnife, como el cazador) con su animación de clic, y el clic congela al dummy de delante;
--   · los dummies cuentan como corredores: se aturden, se ciegan y el dragón los congela; se recuperan solos en 6 s;
--   · estás en modo AFK: RoundService no te mete en partidas hasta que vuelves.
-- Admins: KaiBit23, RoundConfig.ADMIN_USER_IDS y rango >= RANGO_ADMIN en el grupo del juego. En Studio, todos.
-- RemoteFunction ReplicatedStorage.ZeroPruebas:InvokeServer(accion, dato) -> { ok, msg }
--   "ir" | "volver" | "arma" (dato = nombre del arma) | "revivir"
-- La usa también ZeroHabilidadArmaServer: Pruebas.activo(player), Pruebas.corredores(), Pruebas.aturdir(d, s), Pruebas.congelar(d)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RoundConfig"))
local CombatConfig = require(ReplicatedStorage.Shared.Config:WaitForChild("CombatConfig"))
local NetworkEvents = require(ReplicatedStorage.Shared:WaitForChild("Network"):WaitForChild("NetworkEvents"))
local ArmasConfig = require(ReplicatedStorage:WaitForChild("ZeroArmasConfig"))
local Habilidades = require(ReplicatedStorage:WaitForChild("ZeroHabilidadesConfig"))

local Pruebas = {}

local ADMINS = { [121517633] = true }            -- KaiBit23
local GRUPO, RANGO_ADMIN = 13912900, 254
local CENTRO = Vector3.new(0, 1500, -8000)       -- lejos de los mapas y del lobby
local SALIDA = CENTRO + Vector3.new(0, 4, 60)    -- donde apareces, mirando hacia -Z (hacia los dummies)
local RECUPERA = 6                               -- segundos que tarda un dummy en descongelarse

local dentro: { [Player]: { vuelta: CFrame, afk: any } } = {}
local dummies = {}
local arena: Folder? = nil

-- ------------------------------------------------------------------ admins
local function esAdmin(p: Player): boolean
	if RunService:IsStudio() or ADMINS[p.UserId] or table.find(RoundConfig.ADMIN_USER_IDS, p.UserId) then return true end
	local ok, rango = pcall(p.GetRankInGroup, p, GRUPO)
	return ok and rango >= RANGO_ADMIN
end

-- ------------------------------------------------------------------ arena
local function parte(props): Part
	local p = Instance.new("Part")
	p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do (p :: any)[k] = v end
	return p
end

local function cartel(padre: Instance, pos: Vector3, tam: Vector2, texto: string, color: Color3, caraArriba: boolean)
	local p = parte({ Size = Vector3.new(tam.X, 0.1, tam.Y), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = CFrame.new(pos) })
	if not caraArriba then p.Size = Vector3.new(tam.X, tam.Y, 0.2); p.CFrame = CFrame.new(pos) end
	local g = Instance.new("SurfaceGui"); g.Face = if caraArriba then Enum.NormalId.Top else Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 40; g.LightInfluence = 0; g.Parent = p
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = texto; t.TextScaled = true
	t.Font = Enum.Font.FredokaOne; t.TextColor3 = color; t.Parent = g
	local s = Instance.new("UIStroke"); s.Thickness = 3; s.Color = Color3.fromRGB(18, 26, 58); s.Parent = t
	p.Parent = padre
end

local function crearDummy(i: number, pos: Vector3, mueve: boolean)
	local m = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	m.Name = "Dummy" .. i
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Color = if mueve then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(205, 210, 220) end
	end
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.MaxHealth = math.huge; hum.Health = math.huge; hum.WalkSpeed = 0; hum.JumpPower = 0
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart
	hrp.Anchored = true
	local base = CFrame.lookAt(pos, pos + Vector3.zAxis)          -- miran hacia la salida
	m:PivotTo(base)
	-- etiqueta sobre la cabeza
	local bb = Instance.new("BillboardGui"); bb.Name = "Etiqueta"; bb.Size = UDim2.fromOffset(160, 34); bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true; bb.MaxDistance = 140; bb.Parent = m:FindFirstChild("Head")
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Font = Enum.Font.FredokaOne; t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1); t.Text = if mueve then "DUMMY (se mueve)" else "DUMMY"; t.Parent = bb
	local s = Instance.new("UIStroke"); s.Thickness = 2; s.Color = Color3.fromRGB(18, 26, 58); s.Parent = t
	local brillo = Instance.new("Highlight"); brillo.Name = "Congelado"; brillo.FillColor = Color3.fromRGB(120, 230, 255); brillo.FillTransparency = 0.35
	brillo.OutlineColor = Color3.new(1, 1, 1); brillo.Enabled = false; brillo.Parent = m
	m:SetAttribute("Role", "Runner"); m:SetAttribute("Status", "Active")
	m.Parent = arena
	local d = { Character = m, Name = m.Name, ZeroDummy = true, congelado = false, serial = 0, base = base, mueve = mueve, fase = i,
		etiqueta = t, brillo = brillo, texto = t.Text }
	table.insert(dummies, d)
end

local function crearArena()
	if arena then return end
	local f = Instance.new("Folder"); f.Name = "ZeroArenaPruebas"; f.Parent = workspace
	arena = f
	parte({ Name = "Baseplate", Size = Vector3.new(400, 4, 400), CFrame = CFrame.new(CENTRO - Vector3.new(0, 2, 0)), Color = Color3.fromRGB(96, 104, 120),
		Material = Enum.Material.SmoothPlastic, Parent = f })
	-- pasillo de tiro con marcas cada 10 studs desde la salida
	parte({ Size = Vector3.new(26, 0.1, 100), CFrame = CFrame.new(CENTRO + Vector3.new(0, 0.05, 8)), Color = Color3.fromRGB(78, 86, 104),
		Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = f })
	for d = 10, 90, 10 do
		local z = SALIDA.Z - d
		parte({ Size = Vector3.new(26, 0.12, 0.35), CFrame = CFrame.new(CENTRO.X, CENTRO.Y + 0.06, z), Color = Color3.new(1, 1, 1), Transparency = 0.35,
			Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		cartel(f, Vector3.new(CENTRO.X + 16, CENTRO.Y + 0.1, z), Vector2.new(6, 3), tostring(d), Color3.fromRGB(255, 220, 90), true)
	end
	cartel(f, CENTRO + Vector3.new(0, 14, -60), Vector2.new(46, 8), "ARENA DE PRUEBAS", Color3.fromRGB(120, 230, 255), false)
	parte({ Size = Vector3.new(8, 0.2, 8), CFrame = CFrame.new(SALIDA - Vector3.new(0, 3.9, 0)), Color = Color3.fromRGB(120, 230, 255),
		Material = Enum.Material.Neon, Transparency = 0.85, CanCollide = false, Parent = f })
	-- dummies: quietos a 15, 25, 35, 50 y 70 studs (algunos a los lados) y dos que van de lado a lado
	local quietos = { Vector3.new(0, 0, 15), Vector3.new(-7, 0, 25), Vector3.new(7, 0, 25), Vector3.new(0, 0, 35), Vector3.new(-4, 0, 50),
		Vector3.new(4, 0, 50), Vector3.new(0, 0, 70) }
	for i, o in quietos do crearDummy(i, SALIDA + Vector3.new(o.X, -1, -o.Z), false) end
	crearDummy(#quietos + 1, SALIDA + Vector3.new(0, -1, -30), true)
	crearDummy(#quietos + 2, SALIDA + Vector3.new(0, -1, -60), true)
	-- los que se mueven van de lado a lado (salvo si están aturdidos o congelados)
	RunService.Heartbeat:Connect(function(dt)
		for _, d in dummies do
			local hrp = d.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not d.mueve or not hrp or d.congelado or d.Character:GetAttribute("ZeroAturdido") then continue end
			d.fase += dt * 0.9 * (d.Character:GetAttribute("ZeroLento") or 1)
			local x = math.sin(d.fase) * 11
			local v = math.cos(d.fase)
			local pos = d.base.Position + Vector3.new(x, 0, 0)
			hrp.CFrame = CFrame.lookAt(pos, pos + Vector3.new(if v >= 0 then 1 else -1, 0, 0))
		end
	end)
end

-- ------------------------------------------------------------------ dummies como corredores
function Pruebas.activo(p: Player): boolean
	return dentro[p] ~= nil
end

function Pruebas.corredores(): { any }
	local l = {}
	for _, d in dummies do if not d.congelado and d.Character.Parent then table.insert(l, d) end end
	return l
end

function Pruebas.ralentizar(d, factor: number, dur: number): Model
	d.serial += 1
	local s = d.serial
	d.Character:SetAttribute("ZeroLento", factor)
	task.delay(dur, function() if d.serial == s then d.Character:SetAttribute("ZeroLento", nil) end end)
	return d.Character
end

function Pruebas.aturdir(d, dur: number): Model
	d.serial += 1
	local s = d.serial
	d.Character:SetAttribute("ZeroAturdido", true)
	task.delay(dur, function() if d.serial == s then d.Character:SetAttribute("ZeroAturdido", nil) end end)
	return d.Character
end

local function descongelar(d)
	d.congelado = false
	d.brillo.Enabled = false
	d.etiqueta.Text = d.texto; d.etiqueta.TextColor3 = Color3.new(1, 1, 1)
	d.Character:SetAttribute("Status", "Active")
	local hrp = d.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and not d.mueve then hrp.CFrame = d.base end
end

function Pruebas.congelar(d, por: Player?): boolean
	if d.congelado then return false end
	if por then pcall(function() require(script.Parent:WaitForChild("ZeroJugadas")).congelado(d, por) end) end   -- rachas
	d.congelado = true
	d.serial += 1
	local s = d.serial
	d.brillo.Enabled = true
	d.etiqueta.Text = "[CONGELADO]"; d.etiqueta.TextColor3 = Color3.fromRGB(120, 230, 255)
	d.Character:SetAttribute("Status", "Frozen")
	task.delay(RECUPERA, function() if d.serial == s and d.congelado then descongelar(d) end end)
	return true
end

-- ------------------------------------------------------------------ arma en la mano y clic
local function esArma(nombre: any): boolean
	if type(nombre) ~= "string" then return false end
	for _, a in ArmasConfig.Armas do if a.nombre == nombre then return true end end
	return false
end

-- la misma Tool que da CombatService al cazador (ZeroArmasServer le pone el modelo de ZeroPruebaArma)
local function darArma(p: Player)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or char:FindFirstChild("HunterKnife") then return end
	local guardada = p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("HunterKnife")
	if guardada then hum:EquipTool(guardada); return end
	local tool = Instance.new("Tool"); tool.Name = "HunterKnife"; tool.CanBeDropped = false; tool.RequiresHandle = true
	tool:SetAttribute("ZeroPrueba", true)
	local h = Instance.new("Part"); h.Name = "Handle"; h.Size = Vector3.new(0.5, 2.2, 0.4); h.Massless = true; h.CanCollide = false
	h.Parent = tool
	local cliente = ReplicatedStorage.Shared:FindFirstChild("Assets") and ReplicatedStorage.Shared.Assets:FindFirstChild("HunterKnifeClient")
	if cliente then cliente:Clone().Parent = tool end
	tool.Parent = p:FindFirstChild("Backpack") or char
	hum:EquipTool(tool)
end

local function quitarArma(p: Player)
	for _, c in { p.Character, p:FindFirstChild("Backpack") } do
		for _, t in c and c:GetChildren() or {} do if t:IsA("Tool") and t:GetAttribute("ZeroPrueba") then t:Destroy() end end
	end
end

-- clic: CombatService no hace nada fuera de partida; aquí se anima el golpe y se congela al dummy más cercano delante
local ultimoGolpe: { [Player]: number } = {}
NetworkEvents.getRemoteEvent("AttackRequest").OnServerEvent:Connect(function(p: Player)
	if not dentro[p] then return end
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or os.clock() - (ultimoGolpe[p] or 0) < CombatConfig.ATTACK_COOLDOWN then return end
	ultimoGolpe[p] = os.clock()
	char:SetAttribute("ZeroAtaqueSerial", ((char:GetAttribute("ZeroAtaqueSerial") or 0) :: number) + 1)
	local mejor, dist = nil, CombatConfig.ATTACK_RANGE + CombatConfig.LAG_TOLERANCE
	for _, d in dummies do
		local dh = d.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if dh and not d.congelado then
			local off = dh.Position - hrp.Position
			local plano = Vector3.new(off.X, 0, off.Z)
			local delante = plano.Magnitude < 2.5
				or math.acos(math.clamp(hrp.CFrame.LookVector:Dot(plano.Unit), -1, 1)) <= CombatConfig.ATTACK_MAX_ANGLE_RAD + math.rad(15)
			if delante and off.Magnitude < dist then mejor, dist = d, off.Magnitude end
		end
	end
	if mejor then Pruebas.congelar(mejor, p) end
end)

-- ------------------------------------------------------------------ entrar / salir
local function salir(p: Player, mover: boolean)
	local info = dentro[p]
	if not info then return end
	dentro[p] = nil
	quitarArma(p)
	p:SetAttribute("ZeroPruebas", nil); p:SetAttribute("ZeroPruebaArma", nil)
	p:SetAttribute("AFK", info.afk)
	local char = p.Character
	if mover and char then
		pcall(p.RequestStreamAroundAsync, p, info.vuelta.Position, 5)
		char:PivotTo(info.vuelta)
	end
end

local remote = Instance.new("RemoteFunction")
remote.Name = "ZeroPruebas"
remote.Parent = ReplicatedStorage

remote.OnServerInvoke = function(p: Player, accion: any, dato: any)
	if not esAdmin(p) then return { ok = false, msg = "Solo para admins." } end
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if accion == "ir" then
		if dentro[p] then return { ok = true } end
		if not hrp then return { ok = false, msg = "Espera a reaparecer." } end
		local rol = p:GetAttribute("Role")
		if rol ~= nil and rol ~= "Lobby" then return { ok = false, msg = "No puedes ir en mitad de una partida." } end
		crearArena()
		dentro[p] = { vuelta = hrp.CFrame, afk = p:GetAttribute("AFK") }
		p:SetAttribute("AFK", true)                                  -- RoundService no te mete en partidas
		p:SetAttribute("ZeroPruebas", true)
		local arma = p:GetAttribute("ArmaEquipada")
		if not esArma(arma) then arma = "Bastón del Dragón Celestial" end
		p:SetAttribute("ZeroPruebaArma", arma)
		-- con StreamingEnabled, primero se carga la zona en tu cliente; luego te movemos y comprobamos que llegaste
		pcall(p.RequestStreamAroundAsync, p, SALIDA, 5)
		local hum = char:FindFirstChildOfClass("Humanoid")           -- sentado en un banco: levantarlo (si no, se lleva el asiento)
		local sw = hum and hum.SeatPart and hum.SeatPart:FindFirstChild("SeatWeld")
		if sw then sw:Destroy(); hum.Sit = false end
		local destino = CFrame.lookAt(SALIDA, SALIDA - Vector3.zAxis)
		for _ = 1, 4 do
			if not hrp.Parent or not dentro[p] then break end
			hrp.AssemblyLinearVelocity = Vector3.zero
			char:PivotTo(destino)
			task.wait(0.35)
			if (hrp.Position - SALIDA).Magnitude < 25 then break end
		end
		if dentro[p] then darArma(p) end
		return { ok = true }
	elseif accion == "volver" then
		salir(p, true)
		return { ok = true }
	elseif accion == "arma" then
		if not dentro[p] or not esArma(dato) then return { ok = false, msg = "Esa arma no existe." } end
		p:SetAttribute("ZeroPruebaArma", dato)
		darArma(p)                                                   -- y a la mano, por si la guardaste
		return { ok = true, msg = if Habilidades.Skins[dato] then nil else "Esta arma no tiene habilidad (E): solo clic." }
	elseif accion == "revivir" then
		for _, d in dummies do d.serial += 1; descongelar(d); d.Character:SetAttribute("ZeroAturdido", nil); d.Character:SetAttribute("ZeroLento", nil) end
		return { ok = true }
	end
	return { ok = false }
end

local function alUnirse(p: Player)
	if esAdmin(p) then p:SetAttribute("ZeroAdmin", true) end
	p.CharacterAdded:Connect(function() salir(p, false) end)        -- si mueres o reapareces, vuelves al lobby normal
end
for _, p in Players:GetPlayers() do task.spawn(alUnirse, p) end
Players.PlayerAdded:Connect(alUnirse)
Players.PlayerRemoving:Connect(function(p) dentro[p] = nil; ultimoGolpe[p] = nil end)

return Pruebas
