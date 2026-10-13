--!strict
-- ZeroTimerLuzFX (LocalScript en StarterPlayerScripts)
-- Control visual cliente para las bombillas de TimerDisplay en ZeroLobby.
-- Simula bombillas incandescentes reales alternando entre diferentes patrones clásicos
-- de marquesina (chaser circular, ping-pong alternado, ola centro-afuera, barrido acumulativo,
-- destellos orgánicos y pulsos rítmicos).
-- Se ejecuta en el cliente: 0 tráfico de red y 60 FPS fluidos.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Colores y materiales realistas de bombilla incandescente de feria / marquesina
local COLOR_ON = Color3.fromRGB(255, 244, 176)     -- Tungsteno cálido incandescente
local COLOR_OFF = Color3.fromRGB(48, 45, 40)       -- Vidrio / filamento apagado
local MAT_ON = Enum.Material.Neon
local MAT_OFF = Enum.Material.SmoothPlastic

local LOBBY_CENTER = Vector3.new(0, 83, -52.8)
local MAX_VISIBILITY_DIST = 260                     -- Pausa cuando el jugador está en mapas lejanos

-- Espera segura del modelo de lobby y pantalla
local lobby = Workspace:WaitForChild("ZeroLobby", 15)
if not lobby then return end

local timerDisplay = lobby:WaitForChild("TimerDisplay", 10)
if not timerDisplay then return end

-- Recolección y ordenamiento geométrico de las bombillas
local topBulbs: { BasePart } = {}
local btmBulbs: { BasePart } = {}
local allBulbs: { BasePart } = {}
local bulbStates: { [BasePart]: boolean } = {}

local function collectBulbs()
	table.clear(topBulbs)
	table.clear(btmBulbs)
	table.clear(allBulbs)

	local rawTop = {}
	local rawBtm = {}

	for _, child in ipairs(timerDisplay:GetChildren()) do
		if child.Name == "Bombilla" and child:IsA("BasePart") then
			table.insert(allBulbs, child)
			if child.Position.Y > 83 then
				table.insert(rawTop, child)
			else
				table.insert(rawBtm, child)
			end
		end
	end

	-- Ordenar de izquierda a derecha (X creciente)
	table.sort(rawTop, function(a, b) return a.Position.X < b.Position.X end)
	table.sort(rawBtm, function(a, b) return a.Position.X < b.Position.X end)

	for _, b in ipairs(rawTop) do table.insert(topBulbs, b) end
	for _, b in ipairs(rawBtm) do table.insert(btmBulbs, b) end
end

collectBulbs()
if #allBulbs == 0 then return end

-- Aplica el estado ON / OFF a una bombilla únicamente si cambió
local function setBulb(part: BasePart, on: boolean)
	if bulbStates[part] == on then return end
	bulbStates[part] = on
	part.Material = if on then MAT_ON else MAT_OFF
	part.Color = if on then COLOR_ON else COLOR_OFF
end

local function setAll(on: boolean)
	for _, b in ipairs(allBulbs) do
		setBulb(b, on)
	end
end

-- Comprueba si la cámara está dentro del rango visible del lobby
local function isNearLobby(): boolean
	local cam = Workspace.CurrentCamera
	if not cam then return true end
	return (cam.CFrame.Position - LOBBY_CENTER).Magnitude <= MAX_VISIBILITY_DIST
end

--------------------------------------------------------------------------------
-- DEFINICIÓN DE PATRONES DE MARQUESINA REALISTAS
--------------------------------------------------------------------------------

local patterns = {}

-- 1. MARQUESINA CIRCULAR (Chaser Loop)
-- La hilera superior viaja a la derecha y la inferior a la izquierda,
-- simulando un circuito cerrado continuo como letreros clásicos de teatro.
patterns.marqueeChase = function(duration: number)
	local stepTime = 0.11
	local steps = math.floor(duration / stepTime)
	local nTop = #topBulbs
	local nBtm = #btmBulbs

	for s = 1, steps do
		if not isNearLobby() then
			setAll(true)
			task.wait(1)
			continue
		end

		-- Fila superior: avanza ->
		for i, b in ipairs(topBulbs) do
			local on = ((i - s) % 3 == 0)
			setBulb(b, on)
		end

		-- Fila inferior: avanza <- (en reversa para cerrar el giro circular)
		for i, b in ipairs(btmBulbs) do
			local on = ((i + s) % 3 == 0)
			setBulb(b, on)
		end

		task.wait(stepTime)
	end
end

-- 2. ALTERNANCIA PING-PONG (Pares e Impares rítmico)
-- Clásico de carnaval: parpadeo intercalado rápido y limpio.
patterns.pingPong = function(duration: number)
	local stepTime = 0.32
	local steps = math.floor(duration / stepTime)

	for s = 1, steps do
		if not isNearLobby() then
			setAll(true)
			task.wait(1)
			continue
		end

		local evenState = (s % 2 == 0)
		for i, b in ipairs(topBulbs) do
			setBulb(b, (i % 2 == 0) == evenState)
		end
		for i, b in ipairs(btmBulbs) do
			setBulb(b, (i % 2 == 0) == evenState)
		end

		task.wait(stepTime)
	end
end

-- 3. ONDA EXPANSIVA: CENTRO HACIA LOS EXTREMOS Y RETORNO
-- Las luces nacen en el centro y viajan hacia afuera como alas, luego regresan.
patterns.centerWave = function(duration: number)
	local n = math.max(#topBulbs, #btmBulbs)
	local half = math.ceil(n / 2)
	local stepTime = 0.08
	local cycleSteps = half * 2
	local totalCycles = math.max(1, math.floor(duration / (cycleSteps * stepTime)))

	for _ = 1, totalCycles do
		if not isNearLobby() then
			setAll(true)
			task.wait(1)
			continue
		end

		-- Expansión (centro -> bordes)
		for d = 0, half - 1 do
			for i, b in ipairs(topBulbs) do
				local distFromCenter = math.abs((i - 0.5) - half)
				setBulb(b, math.abs(distFromCenter - d) < 1.2)
			end
			for i, b in ipairs(btmBulbs) do
				local distFromCenter = math.abs((i - 0.5) - half)
				setBulb(b, math.abs(distFromCenter - d) < 1.2)
			end
			task.wait(stepTime)
		end

		-- Contracción (bordes -> centro)
		for d = half - 1, 0, -1 do
			for i, b in ipairs(topBulbs) do
				local distFromCenter = math.abs((i - 0.5) - half)
				setBulb(b, math.abs(distFromCenter - d) < 1.2)
			end
			for i, b in ipairs(btmBulbs) do
				local distFromCenter = math.abs((i - 0.5) - half)
				setBulb(b, math.abs(distFromCenter - d) < 1.2)
			end
			task.wait(stepTime)
		end
	end
end

-- 4. BARRIDO ACUMULATIVO Y DOBLE DESTELLO
-- Se llena progresivamente de izquierda a derecha. Al completarse,
-- hace un doble destello triunfal y luego se limpia.
patterns.wipeAndFlash = function(duration: number)
	local n = math.max(#topBulbs, #btmBulbs)
	local wipeStep = 0.06
	local cycleTime = (n * wipeStep) + 1.2
	local cycles = math.max(1, math.floor(duration / cycleTime))

	for _ = 1, cycles do
		if not isNearLobby() then
			setAll(true)
			task.wait(1)
			continue
		end

		setAll(false)
		task.wait(0.1)

		-- Llenado acumulativo izquierda a derecha
		for step = 1, n do
			if topBulbs[step] then setBulb(topBulbs[step], true) end
			if btmBulbs[step] then setBulb(btmBulbs[step], true) end
			task.wait(wipeStep)
		end

		task.wait(0.2)

		-- Doble destello de confirmación (flash-flash)
		setAll(false); task.wait(0.09)
		setAll(true);  task.wait(0.18)
		setAll(false); task.wait(0.09)
		setAll(true);  task.wait(0.4)
	end
end

-- 5. CHISPORROTEO ORGÁNICO / DESTELLOS INDEPENDIENTES (Twinkle)
-- Titileo pseudoaleatorio que simula bombillas de filamento vintage
-- con pulsaciones individuales en un festival o noche de feria.
patterns.organicTwinkle = function(duration: number)
	local startTime = os.clock()
	local offsets = {}
	for i = 1, #allBulbs do
		offsets[i] = (i * 1.618033) % 10
	end

	while os.clock() - startTime < duration do
		if not isNearLobby() then
			setAll(true)
			task.wait(1)
			continue
		end

		local t = os.clock()
		for i, b in ipairs(allBulbs) do
			-- Combinación de ondas armónicas para sensación viva e impredecible
			local wave = math.sin(t * 7.5 + offsets[i] * 3.1)
				+ math.sin(t * 13.0 + offsets[i] * 5.7)
			setBulb(b, wave > -0.2)
		end

		task.wait(0.05)
	end
end

-- 6. REBOTE EN ESPEJO (Bouncing Beams)
-- Dos paquetes de luz viajan desde los bordes hacia el centro, colisionan y rebotan.
patterns.bounceBeams = function(duration: number)
	local n = math.max(#topBulbs, #btmBulbs)
	local half = math.ceil(n / 2)
	local stepTime = 0.08
	local cycles = math.max(1, math.floor(duration / (half * 2 * stepTime)))

	for _ = 1, cycles do
		if not isNearLobby() then
			setAll(true)
			task.wait(1)
			continue
		end

		-- Viaje hacia el centro
		for pos = 1, half do
			for i, b in ipairs(topBulbs) do
				setBulb(b, i == pos or i == (n - pos + 1))
			end
			for i, b in ipairs(btmBulbs) do
				setBulb(b, i == pos or i == (n - pos + 1))
			end
			task.wait(stepTime)
		end

		-- Rebote hacia los extremos
		for pos = half, 1, -1 do
			for i, b in ipairs(topBulbs) do
				setBulb(b, i == pos or i == (n - pos + 1))
			end
			for i, b in ipairs(btmBulbs) do
				setBulb(b, i == pos or i == (n - pos + 1))
			end
			task.wait(stepTime)
		end
	end
end

-- 7. PULSO RÍTMICO DE MARQUESINA (Strobe Pulse & Breathe)
-- Todas encendidas -> 3 pulsos breves sincronizados -> pausa encendido.
patterns.strobePulse = function(duration: number)
	local elapsed = 0
	while elapsed < duration do
		if not isNearLobby() then
			setAll(true)
			task.wait(1)
			elapsed += 1
			continue
		end

		-- Encendido continuo 1.2s
		setAll(true)
		task.wait(1.2)
		elapsed += 1.2

		-- Tres pulsos rápidos
		for _ = 1, 3 do
			setAll(false)
			task.wait(0.1)
			setAll(true)
			task.wait(0.12)
			elapsed += 0.22
		end
	end
end

--------------------------------------------------------------------------------
-- CICLO MAESTRO: SECUENCIA CONTINUA DE PATRONES
--------------------------------------------------------------------------------

local patternList = {
	{ name = "MarqueeChase",   fn = patterns.marqueeChase,   duration = 8.0 },
	{ name = "PingPong",       fn = patterns.pingPong,       duration = 6.5 },
	{ name = "CenterWave",     fn = patterns.centerWave,     duration = 7.5 },
	{ name = "WipeAndFlash",   fn = patterns.wipeAndFlash,   duration = 7.5 },
	{ name = "OrganicTwinkle", fn = patterns.organicTwinkle, duration = 6.0 },
	{ name = "BounceBeams",    fn = patterns.bounceBeams,    duration = 6.5 },
	{ name = "StrobePulse",    fn = patterns.strobePulse,    duration = 6.0 },
}

task.spawn(function()
	local patternIndex = 1

	while true do
		-- Re-recolectar bombillas si es necesario por StreamingEnabled
		if #allBulbs == 0 then
			collectBulbs()
			task.wait(1)
			continue
		end

		local current = patternList[patternIndex]
		local success, err = pcall(function()
			current.fn(current.duration)
		end)

		if not success then
			warn("[ZeroTimerLuzFX] Error ejecutando patrón " .. current.name .. ":", err)
			task.wait(1)
		end

		-- Avanza al siguiente patrón en bucle infinito
		patternIndex = (patternIndex % #patternList) + 1
	end
end)
