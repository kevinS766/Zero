-- ZeroJugadas (ModuleScript, ServerScriptService): jugadas que premian la habilidad. Los efectos los pinta
-- StarterPlayerScripts.ZeroJugadasClient; todo viaja por el RemoteEvent ReplicatedStorage.ZeroJugadas ({ kind = ... }).
--   · ESQUIVA PERFECTA: un corredor que estaba al alcance del golpe del cazador y hace dash justo antes (0,4 s) o justo
--     después de que el golpe falle (0,3 s, lo que tarda en verlo) consigue PERFECT DODGE: efecto, sonido y su dash
--     recargado al momento. Lo llaman CombatService (Jugadas.ataque) y DashService (Jugadas.dash).
--   · RACHAS: congelar seguido (cada congelado a menos de VENTANA_RACHA s del anterior) suma al combo del cazador (x1, x2...).
--     Lo llama PlayerStateService.freezeRunner(victima, cazador) (cuchillo, trampas y habilidades).
--   · POWER-UPS: durante la ronda aparecen objetos que solo recogen los corredores: salto gigante, velocidad, escudo
--     contra un impacto y dash extra. Se anuncian a todos y se marcan en pantalla para que la competencia sea justa.
-- ZeroJugadasServer (Script) llama a Jugadas.iniciar().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PathfindingService = game:GetService("PathfindingService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config:WaitForChild("CombatConfig"))
local MapConfig = require(Shared.Config:WaitForChild("MapConfig"))

local Jugadas = {}

local remote = ReplicatedStorage:FindFirstChild("ZeroJugadas") :: RemoteEvent?
if not remote then
	local r = Instance.new("RemoteEvent"); r.Name = "ZeroJugadas"; r.Parent = ReplicatedStorage
	remote = r
end
local evento = remote :: RemoteEvent

-- los servicios se piden al usarlos (PlayerStateService/CombatService/DashService requieren este módulo: sin ciclos)
local function servicio(nombre: string): any
	return require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild(nombre))
end
local function rondaActiva(): boolean
	local ok, estado = pcall(function() return servicio("RoundService").getState() end)
	return ok and estado == "ROUND_ACTIVE"
end

-- ------------------------------------------------------------------ corredores (jugadores y bots)
local function corredores(): { Model }
	local l = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Runner" and p:GetAttribute("Status") == "Active" and p.Character then table.insert(l, p.Character) end
	end
	local bots = workspace:FindFirstChild("ZeroBots")
	if bots then
		for _, b in bots:GetChildren() do
			if b:IsA("Model") and b:GetAttribute("Role") == "Runner" and b:GetAttribute("Status") == "Active" then table.insert(l, b) end
		end
	end
	return l
end

local function jugadorDe(char: Model): Player?
	return Players:GetPlayerFromCharacter(char)
end

-- ================================================================== ESQUIVA PERFECTA
local ANTES, DESPUES = 0.4, 0.3        -- dash hasta 0,4 s antes del golpe, o hasta 0,3 s después de que falle
local MARGEN = 4                       -- studs de más sobre el alcance del golpe
local peligro: { [Model]: number } = {}   -- corredor -> instante del golpe que le pasó rozando

local function alAlcance(hunterHRP: BasePart, pos: Vector3): boolean
	local off = pos - hunterHRP.Position
	if off.Magnitude > CombatConfig.ATTACK_RANGE + MARGEN or math.abs(off.Y) > CombatConfig.ATTACK_HEIGHT + 2 then return false end
	local plano = Vector3.new(off.X, 0, off.Z)
	if plano.Magnitude < 3 then return true end
	local ang = math.acos(math.clamp(hunterHRP.CFrame.LookVector:Dot(plano.Unit), -1, 1))
	return ang <= CombatConfig.ATTACK_MAX_ANGLE_RAD + math.rad(20)
end

local function perfecta(char: Model)
	local t = char:GetAttribute("ZeroDashT")
	if char:GetAttribute("ZeroDodgeT") == t then return end   -- una por dash
	char:SetAttribute("ZeroDodgeT", t)
	peligro[char] = nil
	local tipo = char:GetAttribute("ZeroDashTipo") or "Frente"
	local p = jugadorDe(char)
	local id = if p then p.UserId else char:GetAttribute("BotActorId")
	if id then pcall(function() servicio("DashService").resetear({ UserId = id }, tipo) end) end
	if p then
		evento:FireClient(p, { kind = "DashReset", tipo = tipo })
		p:SetAttribute("ZeroEsquivasPerfectas", ((p:GetAttribute("ZeroEsquivasPerfectas") or 0) :: number) + 1)
	end
	evento:FireAllClients({ kind = "PerfectDodge", personaje = char })
end

-- CombatService: el cazador acaba de golpear (objetivo = a quién congela, o nil si falla)
function Jugadas.ataque(hunterChar: Model, hunterHRP: BasePart, objetivo: Model?)
	local ahora = workspace:GetServerTimeNow()
	for _, c in corredores() do
		if c ~= objetivo and c ~= hunterChar then
			local hrp = c:FindFirstChild("HumanoidRootPart") :: BasePart?
			local t = c:GetAttribute("ZeroDashT")
			local desde = c:GetAttribute("ZeroDashPos")
			if type(t) == "number" and ahora - t <= ANTES and typeof(desde) == "Vector3" and alAlcance(hunterHRP, desde) then
				perfecta(c)                                            -- se fue justo antes del golpe
			elseif hrp and alAlcance(hunterHRP, hrp.Position) then
				peligro[c] = ahora                                     -- le pasó rozando: si hace dash ya, cuenta
			end
		end
	end
end

-- DashService: este personaje acaba de hacer dash
function Jugadas.dash(char: Model)
	local t = peligro[char]
	if t and workspace:GetServerTimeNow() - t <= DESPUES and char:GetAttribute("Role") ~= "Hunter" then perfecta(char) end
end

-- ================================================================== RACHAS (combo)
local VENTANA_RACHA = 6          -- s para conectar el siguiente congelado (la barra del medidor de combo)
local rachas: { [any]: { n: number, t: number } } = {}

-- PlayerStateService.freezeRunner (y la arena de pruebas): `cazador` congeló a `victima`
function Jugadas.congelado(victima: any, cazador: any)
	if not cazador then return end
	local char = cazador.Character
	if not char then return end
	local ahora = os.clock()
	local r = rachas[cazador]
	if r and ahora - r.t <= VENTANA_RACHA then r.n += 1 else r = { n = 1, t = ahora }; rachas[cazador] = r end
	r.t = ahora
	evento:FireAllClients({ kind = "Racha", n = r.n, dura = VENTANA_RACHA, cazador = char, victima = victima and victima.Character })
end

-- ================================================================== ESCUDO (power-up)
-- PlayerStateService.freezeRunner: si la víctima lleva escudo, lo rompe y no la congela
function Jugadas.escudo(victima: any): boolean
	local char = victima.Character
	if not (char and char:GetAttribute("ZeroEscudo")) then return false end
	char:SetAttribute("ZeroEscudo", nil)
	if typeof(victima) == "Instance" then victima:SetAttribute("ZeroEscudo", nil) end
	evento:FireAllClients({ kind = "EscudoRoto", personaje = char })
	return true
end

-- ================================================================== POWER-UPS
local TIPOS = {
	Salto = { nombre = "SALTO GIGANTE", dura = 9 },
	Velocidad = { nombre = "VELOCIDAD", dura = 7, factor = 1.35 },
	Escudo = { nombre = "ESCUDO", dura = 25 },        -- hasta que lo golpean (o 25 s)
	Dash = { nombre = "DASH EXTRA", dura = 30 },      -- un dash más aunque esté en recarga (o 30 s)
}
local ORDEN = { "Salto", "Velocidad", "Escudo", "Dash" }
local MAX_ACTIVOS, PRIMERO, CADA_MIN, CADA_MAX, VIDA = 3, 12, 16, 24, 35
local SALTO_POWER, SALTO_HEIGHT = 75, 16                     -- normal: 50 / 7,2 (PlayerStateService)

local carpeta: Folder? = nil
local activos: { [BasePart]: { tipo: string, fin: number } } = {}
local efectos: { [Model]: { [string]: number } } = {}        -- personaje -> tipo -> serie (para quitar solo el último)

local function mapaActual(): Model?
	local ok, id = pcall(function() return servicio("MapService").getSelectedMapId() end)
	local entrada = ok and MapConfig.Maps[id]
	return entrada and workspace:FindFirstChild(entrada.WorkspaceName) :: Model?
end

local function limpiarEfectos(char: Model)
	local p = jugadorDe(char)
	for _, a in { "ZeroVeloz", "ZeroEscudo", "ZeroDashExtra", "ZeroSaltoGigante" } do
		char:SetAttribute(a, nil)
		if p then p:SetAttribute(a, nil) end
	end
	for tipo in TIPOS do                                        -- iconos del HUD (si no, el del escudo se quedaba)
		char:SetAttribute("ZeroPowerFin_" .. tipo, nil)
		if p then p:SetAttribute("ZeroPowerFin_" .. tipo, nil) end
	end
	efectos[char] = nil
end

-- un sitio alcanzable a pie desde la salida de los corredores, en el suelo, lejos de los otros power-ups
local function lugar(mapa: Model): Vector3?
	local cf, tam = mapa:GetBoundingBox()
	local salidas = {}
	pcall(function() salidas = servicio("MapService").getSpawnsForCurrentMap("RUNNER") end)
	if #salidas == 0 then return nil end
	local alturaBase = 0
	for _, s in salidas do alturaBase += s.Position.Y end
	alturaBase = alturaBase / #salidas - 3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mapa, workspace.Terrain }
	for _ = 1, 30 do
		local x = cf.Position.X + (math.random() - 0.5) * tam.X * 0.85
		local z = cf.Position.Z + (math.random() - 0.5) * tam.Z * 0.85
		local arriba = cf.Position.Y + tam.Y / 2 + 5
		local hit = workspace:Raycast(Vector3.new(x, arriba, z), Vector3.new(0, -(tam.Y + 40), 0), params)
		if hit and hit.Normal.Y > 0.85 and math.abs(hit.Position.Y - alturaBase) < 14 and hit.Material ~= Enum.Material.Water
			and not hit.Instance:IsA("TrussPart") then
			local pos = hit.Position
			local lejos = true
			for p in activos do if (p.Position - pos).Magnitude < 35 then lejos = false end end
			local libre = not workspace:Raycast(pos + Vector3.new(0, 0.5, 0), Vector3.new(0, 7, 0), params)
			if lejos and libre then
				local camino = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
				local origen = salidas[math.random(1, #salidas)].Position
				local ok = pcall(function() camino:ComputeAsync(origen, pos + Vector3.new(0, 2, 0)) end)
				if ok and camino.Status == Enum.PathStatus.Success then return pos end
			end
		end
	end
	return nil
end

local function aplicar(char: Model, tipo: string)
	local p = jugadorDe(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local info = TIPOS[tipo]
	efectos[char] = efectos[char] or {}
	local serie = (efectos[char][tipo] or 0) + 1
	efectos[char][tipo] = serie
	local function poner(a: string, v: any)
		char:SetAttribute(a, v)
		if p then p:SetAttribute(a, v) end
	end
	local quitar: () -> ()
	if tipo == "Velocidad" then
		poner("ZeroVeloz", info.factor); quitar = function() poner("ZeroVeloz", nil) end
	elseif tipo == "Salto" then
		poner("ZeroSaltoGigante", true)
		if hum and hum.WalkSpeed > 0 then hum.JumpPower = SALTO_POWER; hum.JumpHeight = SALTO_HEIGHT end
		quitar = function()
			poner("ZeroSaltoGigante", nil)
			if hum and hum.Parent and char:GetAttribute("Status") ~= "Frozen" and hum.JumpPower == SALTO_POWER then
				hum.JumpPower = 50; hum.JumpHeight = 7.2
			end
		end
	elseif tipo == "Escudo" then
		poner("ZeroEscudo", true); quitar = function() poner("ZeroEscudo", nil) end
	else
		poner("ZeroDashExtra", 1); quitar = function() poner("ZeroDashExtra", nil) end
	end
	poner("ZeroPowerFin_" .. tipo, workspace:GetServerTimeNow() + info.dura)   -- para la barra del HUD
	task.delay(info.dura, function()
		if efectos[char] and efectos[char][tipo] == serie then
			quitar(); poner("ZeroPowerFin_" .. tipo, nil); efectos[char][tipo] = nil
		end
	end)
end

local function recoger(base: BasePart, char: Model)
	local a = activos[base]
	if not a or char:GetAttribute("Role") ~= "Runner" or char:GetAttribute("Status") ~= "Active" then return end
	local p = jugadorDe(char)
	if p and (p:GetAttribute("Role") ~= "Runner" or p:GetAttribute("Status") ~= "Active") then return end
	activos[base] = nil
	aplicar(char, a.tipo)
	evento:FireAllClients({ kind = "PowerUpRecogido", tipo = a.tipo, personaje = char, pos = base.Position })
	base.Parent:Destroy()
end

local function crear(mapa: Model)
	local pos = lugar(mapa)
	if not pos then return end
	local tipo = ORDEN[math.random(1, #ORDEN)]
	local m = Instance.new("Model"); m.Name = "PowerUp_" .. tipo
	m:SetAttribute("Tipo", tipo)
	local base = Instance.new("Part")
	base.Name = "Base"; base.Size = Vector3.new(5, 6, 5); base.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	base.Anchored = true; base.CanCollide = false; base.CanQuery = false; base.Transparency = 1
	base.Parent = m
	m.PrimaryPart = base
	m.Parent = carpeta
	activos[base] = { tipo = tipo, fin = os.clock() + VIDA }
	base.Touched:Connect(function(hit)
		local char = hit:FindFirstAncestorOfClass("Model")
		if char and char:FindFirstChildOfClass("Humanoid") then recoger(base, char) end
	end)
	evento:FireAllClients({ kind = "PowerUp", tipo = tipo, pos = pos })
end

-- pruebas (DebugCommandService /powerup): aplica un power-up como si lo hubiera recogido
function Jugadas.darPowerUp(char: Model, tipo: string): boolean
	if not TIPOS[tipo] then return false end
	aplicar(char, tipo)
	return true
end

function Jugadas.iniciar()
	local f = workspace:FindFirstChild("ZeroPowerUps") or Instance.new("Folder")
	f.Name = "ZeroPowerUps"; f.Parent = workspace
	carpeta = f :: Folder
	task.spawn(function()
		local proximo = os.clock() + PRIMERO
		local enRonda = false
		while true do
			task.wait(1)
			local activa = rondaActiva()
			if not activa then
				if enRonda then                                         -- fin de ronda: fuera objetos y efectos
					for b in activos do if b.Parent then b.Parent:Destroy() end end
					table.clear(activos)
					for char in efectos do limpiarEfectos(char) end
					table.clear(rachas); table.clear(peligro)
				end
				proximo = os.clock() + PRIMERO
			else
				for b, a in activos do                                  -- caducan si nadie los coge
					if os.clock() > a.fin then activos[b] = nil; if b.Parent then b.Parent:Destroy() end end
				end
				local n = 0
				for _ in activos do n += 1 end
				local mapa = mapaActual()
				if mapa and os.clock() >= proximo and n < MAX_ACTIVOS then
					proximo = os.clock() + math.random(CADA_MIN, CADA_MAX)
					local ok, err = pcall(crear, mapa)
					if not ok then warn("[ZeroJugadas] power-up: " .. tostring(err)) end
				end
			end
			enRonda = activa
		end
	end)
	-- al congelar o morir se pierden los efectos temporales (el escudo ya se gastó si salvó)
	local function vigilar(char: Model)
		char:GetAttributeChangedSignal("Status"):Connect(function()
			if char:GetAttribute("Status") == "Frozen" and efectos[char] then limpiarEfectos(char) end
		end)
		char.Destroying:Connect(function() efectos[char] = nil; peligro[char] = nil end)
	end
	Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(vigilar) end)
	for _, p in Players:GetPlayers() do
		p.CharacterAdded:Connect(vigilar)
		if p.Character then vigilar(p.Character) end
	end
	local function bots(folder: Instance)
		folder.ChildAdded:Connect(function(c) if c:IsA("Model") then vigilar(c) end end)
		for _, c in folder:GetChildren() do if c:IsA("Model") then vigilar(c) end end
	end
	if workspace:FindFirstChild("ZeroBots") then bots(workspace.ZeroBots) end
	workspace.ChildAdded:Connect(function(c) if c.Name == "ZeroBots" then bots(c) end end)
	Players.PlayerRemoving:Connect(function(p) rachas[p] = nil end)
end

return Jugadas
