-- ZeroInercia (LocalScript, StarterPlayerScripts): peso al moverse sin perder control.
--
-- 1) Aceleración: el control de Roblox escribe cada fotograma la intención en Humanoid.MoveDirection (prioridad
--    Input); justo después la leemos, la suavizamos y la volvemos a escribir con Humanoid:Move (la velocidad escala
--    con la magnitud). Los clientes actuales no exponen PlayerModule, por eso no se usa GetControls(). Números elegidos para un juego de pilla-pilla, donde esquivar manda:
--      · arranque: curva EASE-IN CÚBICA (v = vmax·p³) en 0,32 s: empieza suave y va ganando velocidad; también al
--        pasar de andar a esprintar (la curva sigue desde la velocidad actual). La animación sale de esa misma
--        velocidad (ZeroMovement), así que acelera con la misma curva
--      · frenada: algo más rápida, ~0,13 s (pararse en seco para esquivar sigue funcionando)
--      · giros normales: la dirección gira rápido sin perder velocidad (no hay "tanque")
--      · media vuelta (> 120º): se planta el pie y se invierte pasando por casi cero, ~0,1 s
-- 2) Cámara: balanceo muy leve con la zancada, hundimiento al aterrizar y unos grados más de FOV a toda velocidad.
--    Se aplica después de la cámara de Roblox y de ZeroControls, sin tocar CameraOffset ni la dirección de mirada.
--    El FOV extra (alejarse) entra con curva EASE-OUT QUAD, nunca de golpe. Intensidad del balanceo: SHAKE.
--    Si el jugador activa "Reducir movimiento" en Ajustes, la cámara queda quieta (la aceleración se mantiene).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local ACCEL_TIME = 0.32      -- de parado a velocidad máxima con ease-in cúbica
local STOP_RATE = 17.5       -- ~0,13 s
local TURN_RATE = 16         -- giro de la dirección
local REVERSE_DOT = -0.5     -- más de 120º: media vuelta

local moveDir = Vector3.zero  -- dirección suavizada (unitaria o cero)
local moveSpeed = 0           -- velocidad suavizada (studs/s)
local SUBIDA_MAX = 14         -- studs/s hacia arriba sin haber saltado (rampas y escaleras van por debajo)
local ultimoSalto = 0

local function approach(a: number, b: number, k: number, dt: number): number
	return a + (b - a) * (1 - math.exp(-k * dt))
end

RunService:BindToRenderStep("ZeroInercia", Enum.RenderPriority.Input.Value + 1, function(dt)
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then moveDir, moveSpeed = Vector3.zero, 0; return end
	local walk = h.WalkSpeed
	local raw = h.MoveDirection                          -- intención de este fotograma (mundo, plana)
	local target = Vector3.new(raw.X, 0, raw.Z)
	local targetMag = math.min(target.Magnitude, 1)
	local targetDir = targetMag > 1e-3 and target.Unit or moveDir
	local targetSpeed = targetMag * walk
	if targetMag > 1e-3 then
		if moveSpeed < 0.05 * walk or moveDir.Magnitude < 0.5 then
			moveDir = targetDir                                       -- desde parado: sale ya hacia donde pulsas
		elseif moveDir:Dot(targetDir) < REVERSE_DOT then
			moveSpeed = approach(moveSpeed, 0, STOP_RATE * 1.6, dt)   -- media vuelta: frena y se gira al llegar abajo
			if moveSpeed < 0.2 * walk then moveDir = targetDir end
		else
			local blended = moveDir:Lerp(targetDir, 1 - math.exp(-TURN_RATE * dt))
			moveDir = blended.Magnitude > 1e-3 and blended.Unit or targetDir
		end
		if moveDir:Dot(targetDir) >= REVERSE_DOT then
			if targetSpeed > moveSpeed then
				-- ease-in cúbica: se recupera el punto p de la curva desde la velocidad actual y se avanza en el tiempo
				local p = (moveSpeed / targetSpeed) ^ (1 / 3)
				p = math.min(1, p + dt / ACCEL_TIME)
				moveSpeed = targetSpeed * p * p * p
			else
				moveSpeed = approach(moveSpeed, targetSpeed, STOP_RATE, dt)
			end
		end
	else
		moveSpeed = approach(moveSpeed, 0, STOP_RATE, dt)
		if moveSpeed < 0.3 then moveSpeed = 0 end
	end
	if walk > 0 then h:Move(moveDir * math.min(moveSpeed / walk, 1), false) end
	-- sin despegar: a mucha velocidad (power-up VELOCIDAD, dash, deslizar) una rampa o un escalón lanzaba al jugador
	-- por los aires. Si no ha saltado hace poco, la velocidad hacia arriba se limita a la de subir una rampa.
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local st = h:GetState()
	if st == Enum.HumanoidStateType.Jumping then ultimoSalto = os.clock() end
	if root and not root.Anchored and os.clock() - ultimoSalto > 0.9 and st ~= Enum.HumanoidStateType.Climbing
		and st ~= Enum.HumanoidStateType.Swimming then
		local v = root.AssemblyLinearVelocity
		local tope = math.max(SUBIDA_MAX, walk * 0.6)            -- a más velocidad, las rampas suben más rápido
		if v.Y > tope then root.AssemblyLinearVelocity = Vector3.new(v.X, tope, v.Z) end
	end
end)

-- ------------------------------------------------------------------ cámara
local lastFovKick, lastCam = 0, nil
local stride = 0
local wasAir, fallSpeed = false, 0
local landT, landAmp = 1, 0
local dashKick, dashSerial, dashAge = 0, nil, 1
local SHAKE = 1.15            -- intensidad del balanceo/hundimiento de cámara (antes 1.0 = 100, ahora 115)
local FOV_TIME = 0.45         -- duración de la curva ease-out quad al alejar/acercar la cámara
local fovFrom, fovTo, fovT, fovNow = 0, 0, 1, 0
local function easeOutQuad(x: number): number return 1 - (1 - x) * (1 - x) end

local function reducedMotion(): boolean
	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("ZeroUI")
	return gui and gui:GetAttribute("ReducedMotion") == true or false
end

RunService:BindToRenderStep("ZeroCamaraPeso", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local cam = workspace.CurrentCamera
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- quitar el FOV extra del fotograma anterior (así nunca se acumula ni pisa a otros scripts)
	if cam == lastCam then cam.FieldOfView -= lastFovKick end
	lastFovKick = 0; lastCam = cam
	if not h or not root or cam.CameraType ~= Enum.CameraType.Custom or cam.CameraSubject ~= h or reducedMotion() then return end
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local air = h.FloorMaterial == Enum.Material.Air
	-- zancada: ~9 studs por ciclo (dos pasos), igual que la animación
	if not air then stride = (stride + speed * dt / 9) % 1 end
	local k = math.clamp(speed / 16, 0, 1.3)
	local bob = (math.abs(math.sin(stride * math.pi * 2)) * 0.06 * k - 0.03 * k) * SHAKE     -- sube en cada paso
	local roll = math.sin(stride * math.pi * 2) * math.rad(0.3) * k * SHAKE
	-- aterrizaje: pequeño hundimiento proporcional a la caída, ~0,3 s
	if air then fallSpeed = math.min(fallSpeed, v.Y) end
	if wasAir and not air and fallSpeed < -12 then landT, landAmp = 0, math.clamp(-fallSpeed / 90, 0.05, 0.35) end
	if not air then fallSpeed = 0 end
	wasAir = air
	landT = math.min(landT + dt / 0.3, 1)
	local land = -landAmp * math.sin(math.pi * landT) * (1 - landT * 0.3) * SHAKE
	-- FOV: +3,5º a velocidad de corredor, algo más a velocidad de cazador; +5º un instante en el dash
	local serial = character:GetAttribute("ZeroDashSerial")
	if serial ~= dashSerial then
		if dashSerial ~= nil then dashAge = 0 end
		dashSerial = serial
	end
	-- dash: +5 grados que entran con ease-out quad en 0,2 s y luego se van despacio
	dashAge += dt
	if dashAge < 0.2 then dashKick = 5 * easeOutQuad(dashAge / 0.2) else dashKick = approach(dashKick, 0, 5, dt) end
	-- velocidad: el objetivo de FOV se persigue con ease-out quad (se reinicia la curva si el objetivo cambia)
	local fovTarget = math.clamp((speed - 6) / 14, 0, 1.4) * 3.5
	if math.abs(fovTarget - fovTo) > 0.15 then fovFrom, fovTo, fovT = fovNow, fovTarget, 0 end
	fovT = math.min(1, fovT + dt / FOV_TIME)
	fovNow = fovFrom + (fovTo - fovFrom) * easeOutQuad(fovT)
	local kick = fovNow + dashKick
	lastFovKick = kick
	cam.FieldOfView += kick
	cam.CFrame = cam.CFrame * CFrame.new(0, bob + land, 0) * CFrame.Angles(0, 0, roll)
end)
