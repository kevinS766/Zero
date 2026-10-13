-- ZeroLobbyZonasClient (LocalScript, StarterPlayerScripts): parte dinámica de las zonas nuevas del lobby.
--  · Ruleta: la cara de la rueda se dibuja con ZeroWheelConfig (los mismos premios, imágenes y probabilidades del
--    menú RULETA), gira despacio y "E · Girar ruleta" abre el menú.
--  · Exclusivos: dos maniquíes con TU avatar y sus carteles (ZeroExclusivosConfig) haciendo una coreografía épica
--    propia (carga, mortal, aterrizaje de superhéroe, combo). "E · Ver" abre la Tienda.
--  · Misiones: un amigo tuyo (ZeroTendero lo prepara en ReplicatedStorage.ZeroMisioneros) delante del tablón,
--    con "!" encima. "E · Misiones" dispara ReplicatedStorage.ZeroMisionesAbrir (BindableEvent) cuando exista el
--    sistema de misiones; mientras tanto avisa de que llegan pronto.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local lobby = workspace:WaitForChild("ZeroLobby")
local UI = require(ReplicatedStorage:WaitForChild("ZeroUI"))
local C = UI.Colors
local WheelConfig = require(ReplicatedStorage:WaitForChild("ZeroWheelConfig"))
local Exclusivos = require(ReplicatedStorage:WaitForChild("ZeroExclusivosConfig"))
local ArmasConfig = require(ReplicatedStorage:WaitForChild("ZeroArmasConfig"))
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MonetizationConfig"))

local function new(class, parent, props)
	local n = Instance.new(class)
	for k, v in props or {} do n[k] = v end
	n.Parent = parent
	return n
end
local function txt(parent, text, size, color, props)
	local l = new("TextLabel", parent, { BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, Text = text, TextColor3 = color or C.white,
		TextScaled = true, Size = size })
	for k, v in props or {} do l[k] = v end
	new("UIStroke", l, { Color = C.ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	return l
end
local function uiAction(name, payload)
	local ui = player.PlayerGui:FindFirstChild("ZeroUI")
	local f = ui and ui:FindFirstChild("UIAction")
	if f then pcall(function() f:Invoke(name, payload) end) end
end
local function toast(msg)
	local ui = player.PlayerGui:FindFirstChild("ZeroUI")
	local t = ui and ui:FindFirstChild("Toast")
	if not t then return end
	t.Message.Text = msg; t.Visible = true
	task.delay(3, function() if t.Message.Text == msg then t.Visible = false end end)
end
-- Apoya un personaje R6 sobre `floorY`: mide dónde quedan de verdad sus pies (las skins no miden todas igual)
local function standOn(model: Model, floorY: number?)
	if not floorY then return end
	local lowest = math.huge
	for _, n in { "Left Leg", "Right Leg" } do
		local leg = model:FindFirstChild(n)
		if leg and leg:IsA("BasePart") then lowest = math.min(lowest, leg.Position.Y - leg.Size.Y / 2) end
	end
	if lowest < math.huge then model:PivotTo(model:GetPivot() + Vector3.new(0, floorY - lowest + 0.02, 0)) end
end
-- ===================================================================== coreografías (animación propia R6)
-- Las animaciones de catálogo épicas son R15; en R6 se hacen a mano moviendo cada Motor6D.Transform entre poses
-- clave con curvas (anticipación, golpe rápido, rebote) + respiración + efectos. Valores "intuitivos" por articulación:
--   brazos/piernas {adelante, afuera, giro} · torso {inclinar adelante, ladear, girar izq} · cabeza {mirar abajo, -, girar izq}
-- raíz {x, y, z, rx, ry, rz} relativa a donde está apoyado (−z = hacia delante, rx+ = mortal hacia atrás).
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local A = CFrame.Angles
local PARTE = { ra = "Right Arm", la = "Left Arm", rl = "Right Leg", ll = "Left Leg", to = "Torso", he = "Head" }
local function jointCF(j: string, v): CFrame
	local a, b, c = v[1] or 0, v[2] or 0, v[3] or 0
	if j == "ra" then return A(-b, c, a)
	elseif j == "la" then return A(-b, -c, -a)
	elseif j == "rl" then return A(-b, 0, a)
	elseif j == "ll" then return A(-b, 0, -a)
	elseif j == "to" then return A(a, b, c) end
	return A(a, 0, c)
end
local EASE = {
	lin = function(x) return x end,
	out = function(x) return 1 - (1 - x) ^ 3 end,
	inq = function(x) return x ^ 3 end,
	io = function(x) return x < 0.5 and 4 * x ^ 3 or 1 - (-2 * x + 2) ^ 3 / 2 end,
	back = function(x) local c = 1.9; return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2 end,
}
local CERO = { 0, 0, 0 }

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	for k, v in props do p[k] = v end
	p.Parent = workspace
	return p
end
local function chispas(at: BasePart | Attachment, color: Color3, n: number, speed: number?, tex: string?)
	local att = at:IsA("Attachment") and at or new("Attachment", at)
	local pe = new("ParticleEmitter", att, { Texture = tex or "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(color),
		LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.35, 0.8), Speed = NumberRange.new((speed or 10) * 0.6, speed or 10), SpreadAngle = Vector2.new(180, 180),
		Drag = 4, Rate = 0 })
	pe:Emit(n)
	task.delay(1.2, function() if att ~= at then att:Destroy() else pe:Destroy() end end)
end
-- onda expansiva en el suelo + polvo
local function onda(pos: Vector3, color: Color3, size: number)
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color, Transparency = 0.15,
		Size = Vector3.new(0.12, 1, 1), CFrame = CFrame.new(pos) * A(0, 0, math.pi / 2) })
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.12, size, size), Transparency = 1 }):Play()
	local dust = fxPart({ Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(pos) })
	local att = new("Attachment", dust)
	new("ParticleEmitter", att, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(225, 215, 200)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) }), Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(9, 14), SpreadAngle = Vector2.new(180, 8), EmissionDirection = Enum.NormalId.Top, Drag = 5, Rate = 0 }):Emit(18)
	chispas(att, color, 22, 16)
	Debris:AddItem(ring, 0.55); Debris:AddItem(dust, 1.3)
end

-- Prepara un personaje para coreografías. Devuelve el "rig" con su pose actual.
local function rig(model: Model, color: Color3)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = model:FindFirstChildOfClass("Humanoid")
	local an = hum and hum:FindFirstChildOfClass("Animator")
	if an then an:Destroy() end                                      -- nada de pistas que pisen nuestras poses
	local r = { model = model, root = root, base = root.CFrame, color = color, motors = {}, pose = {}, raiz = { 0, 0, 0, 0, 0, 0 },
		mirar = nil :: BasePart?, yaw = 0, temblor = 0 }
	for _, j in model:GetDescendants() do if j:IsA("Motor6D") and j.Part1 then r.motors[j.Part1.Name] = j end end
	for j in PARTE do r.pose[j] = CERO end
	-- estela del arma (mano derecha → punta), apagada salvo en los tajos
	local arm = model:FindFirstChild("Right Arm")
	if arm then
		local a0 = new("Attachment", arm, { Position = Vector3.new(0, -1, 0) })
		local a1 = new("Attachment", arm, { Position = Vector3.new(0, -1.1, -2.6) })
		r.estela = new("Trail", arm, { Attachment0 = a0, Attachment1 = a1, Color = ColorSequence.new(Color3.new(1, 1, 1), color), LightEmission = 1,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }), Lifetime = 0.2,
			FaceCamera = true, Enabled = false })
		r.mano = a0; r.punta = a1
	end
	r.luz = new("PointLight", root, { Color = color, Brightness = 0, Range = 14, Shadows = false })
	return r
end

local function aplicar(r, pose, raiz)
	local t = os.clock()
	local resp = math.sin(t * 2.4)                                 -- respiración: nunca está del todo quieto
	-- mirar al jugador (cabeza y un poco el torso), suavizado
	local want = 0
	if r.mirar and r.mirar.Parent then
		local d = r.base:PointToObjectSpace(r.mirar.Position)
		want = math.clamp(math.atan2(-d.X, -d.Z), -0.9, 0.9)
	end
	r.yaw += (want - r.yaw) * 0.08
	for j, name in PARTE do
		local m = r.motors[name]
		if m then
			local v = pose[j] or CERO
			local cf = jointCF(j, v)
			if j == "to" then cf = cf * A(resp * 0.025, 0, r.yaw * 0.25)
			elseif j == "he" then cf = cf * A(-resp * 0.02, 0, r.yaw * 0.6)
			elseif j == "ra" or j == "la" then cf = cf * A(-resp * 0.03, 0, 0) end
			m.Transform = cf
		end
	end
	local sh = r.temblor > 0 and Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * r.temblor or Vector3.zero
	r.root.CFrame = r.base * CFrame.new(raiz[1] + sh.X, raiz[2] + sh.Y + resp * 0.03, raiz[3] + sh.Z) * A(raiz[4], raiz[5], raiz[6])
end

-- Reproduce una lista de claves: { d = duración, e = curva, p = pose, r = raíz, fx = función al empezar, hold = mantener }
local function bailar(r, claves)
	for _, k in claves do
		if not r.model.Parent then return end
		local desde, raizDesde = r.pose, r.raiz
		local hacia, raizHacia = desde, raizDesde
		if not k.hold then
			hacia = {}
			for j in PARTE do hacia[j] = (k.p and k.p[j]) or CERO end
			local rr = k.r or {}
			raizHacia = { rr[1] or 0, rr[2] or 0, rr[3] or 0, rr[4] or 0, rr[5] or 0, rr[6] or 0 }
		end
		if k.fx then task.spawn(k.fx, r) end
		local ease = EASE[k.e or "io"]
		local t0, d = os.clock(), k.d
		repeat
			local x = math.min(1, (os.clock() - t0) / d)
			local e = ease(x)
			local pose = {}
			for j in PARTE do
				local a, b = desde[j], hacia[j]
				local a1, a2, a3, b1, b2, b3 = a[1] or 0, a[2] or 0, a[3] or 0, b[1] or 0, b[2] or 0, b[3] or 0
				pose[j] = { a1 + (b1 - a1) * e, a2 + (b2 - a2) * e, a3 + (b3 - a3) * e }
			end
			local raiz = {}
			for i = 1, 6 do raiz[i] = raizDesde[i] + (raizHacia[i] - raizDesde[i]) * e end
			aplicar(r, pose, raiz)
			RunService.RenderStepped:Wait()
		until x >= 1 or not r.model.Parent
		for i = 4, 6 do raizHacia[i] = math.atan2(math.sin(raizHacia[i]), math.cos(raizHacia[i])) end   -- 360º = 0º
		r.pose, r.raiz = hacia, raizHacia
	end
end
-- salto: altura en parábola sobre una clave (para mortales y giros en el aire)
local function salto(k, alto: number)
	k.e = "lin"
	local fx = k.fx
	k.fx = function(r)
		if fx then task.spawn(fx, r) end
		local t0 = os.clock()
		while os.clock() - t0 < k.d and r.model.Parent do
			local x = (os.clock() - t0) / k.d
			r.base = r.base0 * CFrame.new(0, 4 * alto * x * (1 - x), 0)
			RunService.RenderStepped:Wait()
		end
		r.base = r.base0
	end
	return k
end
local function luz(r, brillo: number, dur: number)
	TweenService:Create(r.luz, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = brillo }):Play()
end
local function aura(r, on: boolean)
	if on then
		r.auraPE = new("ParticleEmitter", r.root, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(r.color),
			LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 14, 0), Rate = 60 })
	elseif r.auraPE then
		r.auraPE.Enabled = false; Debris:AddItem(r.auraPE, 1); r.auraPE = nil
	end
end
-- solo se anima con la cámara cerca del lobby
local function cerca(): boolean
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - Vector3.new(-40, 70, 0)).Magnitude <= 220
end

local function hookPrompt(prompt, fn)
	if prompt then prompt.Triggered:Connect(function(who) if who == player then fn() end end) end
end

-- ===================================================================== RULETA
local ruleta = lobby:WaitForChild("RuletaNueva", 30)
local rotor
if ruleta then
	local disco = ruleta:WaitForChild("Disco")
	local sg = new("SurfaceGui", disco, { Name = "CaraRueda", Face = Enum.NormalId.Right, CanvasSize = Vector2.new(840, 840), LightInfluence = 0.15,
		ZOffset = 1 })
	rotor = new("Frame", sg, { Name = "Rotor", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1 })
	new("ImageLabel", rotor, { Name = "Disc", Image = WheelConfig.Assets.Disc, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local total = 0
	for _, r in WheelConfig.Rewards do total += r.Weight end
	for i, reward in WheelConfig.Rewards do                 -- misma colocación que el menú (ZeroUI), escalada a 840 px
		local angle = (i - 1) * 72 - 36
		local rad = math.rad(angle)
		local g = new("Frame", rotor, { Name = "Premio_" .. i, AnchorPoint = Vector2.new(.5, .5), BackgroundTransparency = 1,
			Position = UDim2.fromOffset(420 + math.sin(rad) * 250, 420 - math.cos(rad) * 250), Size = UDim2.fromOffset(240, 250), Rotation = angle })
		new("ImageLabel", g, { Image = reward.Icono or WheelConfig.Assets.Cash, Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(160, 140),
			BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit })
		txt(g, reward.Label, UDim2.fromOffset(240, 56), reward.Arma and Color3.fromRGB(127, 216, 255) or C.white, { Position = UDim2.fromOffset(0, 140) })
		local pct = reward.Weight / total * 100
		txt(g, (pct < 0.1 and string.format("%.2f%%", pct) or pct % 1 == 0 and string.format("%d%%", pct) or string.format("%.1f%%", pct)), UDim2.fromOffset(240, 44),
			pct <= 7 and C.yellow or C.muted, { Position = UDim2.fromOffset(0, 196) })
	end
	local boton = ruleta:FindFirstChild("BotonGirar")
	hookPrompt(boton and boton:FindFirstChild("Girar"), function() uiAction("Open", "Wheel") end)
end

-- ===================================================================== EXCLUSIVOS
local vitrina = lobby:WaitForChild("Exclusivos", 30)
local TAG = { Robux = { "EXCLUSIVO DE ROBUX", C.purple }, VIP = { "EXCLUSIVO VIP", C.yellow } }
local maniquies = {}
local function fmtTime(s)
	s = math.max(0, math.floor(s))
	return string.format("TERMINA EN %02d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
end
local function cartelExclusivo(punto, info)
	local tag = TAG[info.tipo] or TAG.Robux
	local bb = new("BillboardGui", punto, { Name = "Cartel", Size = UDim2.fromScale(9, 4.6), StudsOffsetWorldSpace = Vector3.new(0, 8.4, 0),
		MaxDistance = 90, LightInfluence = 0, AlwaysOnTop = false })
	local pill = new("Frame", bb, { Position = UDim2.fromScale(.17, 0), Size = UDim2.fromScale(.66, .17), BackgroundColor3 = tag[2] })
	new("UICorner", pill, { CornerRadius = UDim.new(1, 0) }); new("UIStroke", pill, { Color = C.ink, Thickness = 2 })
	txt(pill, tag[1], UDim2.fromScale(1, 1), info.tipo == "VIP" and C.ink or C.white)
	local box = new("Frame", bb, { Position = UDim2.fromScale(.03, .21), Size = UDim2.fromScale(.94, .48), BackgroundColor3 = info.tipo == "VIP" and C.ink or C.panel })
	new("UICorner", box, { CornerRadius = UDim.new(0, 14) }); new("UIStroke", box, { Color = tag[2], Thickness = 3 })
	txt(box, info.nombre, UDim2.fromScale(.94, .56), C.white, { Position = UDim2.fromScale(.03, .06) })
	txt(box, info.subtitulo, UDim2.fromScale(.94, .28), C.muted, { Position = UDim2.fromScale(.03, .64) })
	local timer
	if info.termina then
		local tp = new("Frame", bb, { Position = UDim2.fromScale(.21, .74), Size = UDim2.fromScale(.58, .16), BackgroundColor3 = C.ink })
		new("UICorner", tp, { CornerRadius = UDim.new(1, 0) }); new("UIStroke", tp, { Color = tag[2], Thickness = 2 })
		timer = txt(tp, "", UDim2.fromScale(1, 1), C.white)
	end
	-- precio + VER, a los pies del maniquí
	local ancla = punto.Parent:FindFirstChild("Precio" .. string.match(punto.Name, "%d+")) or punto
	local pb = new("BillboardGui", ancla, { Name = "Precio", Size = UDim2.fromScale(5, 1.2),
		MaxDistance = 60, LightInfluence = 0 })
	local pf = new("Frame", pb, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = info.tipo == "VIP" and Color3.fromHex("#3B2A12") or C.purple })
	new("UICorner", pf, { CornerRadius = UDim.new(1, 0) }); new("UIStroke", pf, { Color = tag[2], Thickness = 3 })
	txt(pf, (info.precio and ("R$ " .. tostring(info.precio)) or "R$ —") .. "  •  VER", UDim2.fromScale(.9, .78), C.white,
		{ Position = UDim2.fromScale(.05, .11) })
	return timer
end
local function vestir(punto)
	-- clon de TU personaje sobre el pedestal (solo lo ves tú)
	local old = punto:FindFirstChild("Maniqui")
	if old then old:Destroy() end
	local char = player.Character
	if not char then return end
	char.Archivable = true
	local ok, m = pcall(function() return char:Clone() end)
	char.Archivable = false
	if not ok or not m then return end
	m.Name = "Maniqui"
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Highlight") then d:Destroy()
		elseif d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.Anchored = false end
	end
	local root = m:FindFirstChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not root or not hum then m:Destroy(); return end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.PlatformStand = true
	root.Anchored = true
	m:PivotTo(punto.CFrame * CFrame.new(0, 3.1, 0))
	m.Parent = punto
	standOn(m, punto:GetAttribute("Suelo"))
	-- el exclusivo en la mano derecha (cuando exista su modelo en ZeroArmasModelos)
	local info = Exclusivos[tonumber(string.match(punto.Name, "%d+")) or 0]
	local modelos = ReplicatedStorage:FindFirstChild("ZeroArmasModelos")
	local plantilla = info and info.modelo and modelos and modelos:FindFirstChild(info.modelo)
	local arm = m:FindFirstChild("Right Arm")
	if plantilla and arm then
		local item = plantilla:Clone()
		item:PivotTo(arm.CFrame * CFrame.new(0, -1, 0))        -- mismo agarre que el cuchillo (hoja hacia delante)
		for _, p in item:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide, p.Massless = false, false, true
				if not p:FindFirstChild("AnimWeld") then   -- piezas Anim_* de los bastones: ya van soldadas al Cuerpo
					local w = Instance.new("WeldConstraint"); w.Part0, w.Part1 = arm, p; w.Parent = p
				end
			end
		end
		item.Parent = m
	end
	-- exhibición épica (coreografía propia, ~15 s): carga de poder → mortal → aterrizaje de superhéroe → combo de
	-- tajos con giro y estocada (estela en el arma) → pose final con el arma al cielo.
	local color = info and info.tipo == "VIP" and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(190, 140, 255)
	local r = rig(m, color)
	r.base0 = r.base
	r.suelo = punto:GetAttribute("Suelo")
	local TAU = math.pi * 2
	local GUARDIA = { ra = { 0.9, 0.25 }, la = { 0.6, -0.15 }, to = { 0.12, 0, -0.25 }, he = { 0, 0, 0.2 }, rl = { -0.2, 0.3 }, ll = { 0.35, 0.3 } }
	local HEROE = { ra = { -0.1, 1.3 }, la = { 0.8, 0.1 }, to = { 0.5 }, he = { 0.45 }, rl = { -0.75, 0.1 }, ll = { 1.7, 0.1 } }
	local HEROE_MIRA = table.clone(HEROE); HEROE_MIRA.he = { -0.25 }
	local function estela(on) return function(rr) if rr.estela then rr.estela.Enabled = on end end end
	local function golpe(n) return function(rr) if rr.punta then chispas(rr.punta, color, n, 18) end end end
	local SHOW = {
		{ d = 0.5, p = GUARDIA, r = { 0, -0.15 } },
		{ d = 1.0, hold = true },
		-- 1. carga de poder: se agacha, tiembla, aura y luz creciendo…
		{ d = 0.6, e = "out", p = { ra = { -0.35, 0.45 }, la = { -0.35, 0.45 }, to = { 0.4 }, he = { 0.35 }, rl = { 0.4, 0.6 }, ll = { 0.4, 0.6 } }, r = { 0, -0.35 },
			fx = function(rr) aura(rr, true); luz(rr, 3, 1.4); rr.temblor = 0.07 end },
		{ d = 1.0, hold = true },
		-- …y estalla
		{ d = 0.16, e = "out", p = { ra = { 1.2, 1.6 }, la = { 1.2, 1.6 }, to = { -0.35 }, he = { -0.5 }, rl = { -0.35, 0.35 }, ll = { -0.35, 0.35 } }, r = { 0, 0.15 },
			fx = function(rr)
				rr.temblor = 0; aura(rr, false); chispas(rr.root, color, 45, 22); onda(Vector3.new(rr.base0.X, rr.suelo or rr.base0.Y - 3, rr.base0.Z), color, 18)
				luz(rr, 7, 0.08); task.wait(0.15); luz(rr, 0, 0.8)
			end },
		{ d = 0.45, hold = true },
		-- 2. mortal hacia atrás
		{ d = 0.18, e = "out", p = { ra = { -0.9, 0.3 }, la = { -0.9, 0.3 }, to = { 0.35 }, he = { 0.1 }, rl = { 0.35, 0.5 }, ll = { 0.35, 0.5 } }, r = { 0, -0.4 } },
		salto({ d = 0.85, p = { ra = { 2.6, 0.4 }, la = { 2.6, 0.4 }, to = { 0.2 }, he = { 0.3 }, rl = { 1.5 }, ll = { 1.5 } }, r = { 0, 0, 0, TAU } }, 5.5),
		-- 3. aterrizaje de superhéroe: rodilla al suelo, onda expansiva, levanta la mirada
		{ d = 0.12, e = "out", p = HEROE, r = { 0, -1.3 },
			fx = function(rr) onda(Vector3.new(rr.base0.X, rr.suelo or rr.base0.Y - 3, rr.base0.Z), color, 16); luz(rr, 4, 0.05); task.wait(0.1); luz(rr, 0, 0.6) end },
		{ d = 0.8, hold = true },
		{ d = 0.35, e = "back", p = HEROE_MIRA, r = { 0, -1.3 } },
		{ d = 0.3, hold = true },
		{ d = 0.45, p = GUARDIA, r = { 0, -0.15 } },
		{ d = 0.4, hold = true },
		-- 4. combo: tajo diagonal, revés, giro de 360º y estocada
		{ d = 0.28, e = "out", p = { ra = { 2.7, 0.7, 0.3 }, la = { 0.7, -0.2 }, to = { 0.05, 0, -0.55 }, he = { 0, 0, 0.45 }, rl = { -0.3, 0.3 }, ll = { 0.4, 0.3 } }, r = { 0, -0.15, 0.2 }, fx = estela(true) },
		{ d = 0.12, e = "out", p = { ra = { 0.5, -0.7 }, la = { -0.4, 0.3 }, to = { 0.25, 0, 0.6 }, he = { 0.1, 0, -0.4 }, rl = { -0.45, 0.3 }, ll = { 0.5, 0.3 } }, r = { 0, -0.3, -0.7 }, fx = golpe(18) },
		{ d = 0.12, hold = true },
		{ d = 0.14, e = "out", p = { ra = { 1.7, 1.5 }, la = { 0.4, -0.3 }, to = { 0.2, 0, -0.6 }, he = { 0, 0, 0.5 }, rl = { -0.35, 0.3 }, ll = { 0.45, 0.3 } }, r = { 0, -0.3, -1.1 }, fx = golpe(18) },
		{ d = 0.1, hold = true },
		salto({ d = 0.45, p = { ra = { 1.5, 1.5 }, la = { 0.3, 1.2 }, to = { 0.1 }, rl = { -0.2, 0.35 }, ll = { 0.2, 0.35 } }, r = { 0, 0, -1.3, 0, -TAU }, fx = golpe(14) }, 1.2),
		{ d = 0.22, e = "out", p = { ra = { 0.2, 0.3 }, la = { 1.0, -0.1 }, to = { -0.05, 0, -0.7 }, he = { 0, 0, 0.6 }, rl = { -0.3, 0.3 }, ll = { 0.4, 0.3 } }, r = { 0, -0.2, -1.1 } },
		{ d = 0.11, e = "out", p = { ra = { 1.57, 0 }, la = { -0.9, 0.2 }, to = { 0.3, 0, 0.45 }, he = { -0.15, 0, -0.3 }, rl = { -0.95, 0.15 }, ll = { 1.2, 0.15 } }, r = { 0, -0.75, -2.3 },
			fx = function(rr) golpe(35)(rr); onda(Vector3.new(rr.base0.X, rr.suelo or rr.base0.Y - 3, rr.base0.Z), color, 9) end },
		{ d = 0.5, hold = true, fx = function(rr) task.wait(0.3); estela(false)(rr) end },
		-- 5. pose final: arma al cielo
		{ d = 0.5, e = "back", p = { ra = { 2.95, 0.15 }, la = { -0.15, 0.55 }, to = { -0.15 }, he = { -0.4 }, rl = { -0.15, 0.25 }, ll = { -0.15, 0.25 } }, r = { 0, 0, -1.0 },
			fx = function(rr) task.wait(0.25); if rr.punta then chispas(rr.punta, color, 40, 12) end; luz(rr, 4, 0.1); task.wait(0.2); luz(rr, 1.2, 1) end },
		{ d = 1.6, hold = true },
		{ d = 0.6, p = GUARDIA, r = { 0, -0.15 }, fx = function(rr) luz(rr, 0, 0.6) end },
		{ d = 1.5, hold = true },
	}
	task.spawn(function()
		local two = string.match(punto.Name, "%d+") == "2"
		bailar(r, { { d = 0.4, p = GUARDIA, r = { 0, -0.15 } }, { d = two and 7 or 0.5, hold = true } })   -- los dos no hacen lo mismo a la vez
		while m.Parent do
			if cerca() then bailar(r, SHOW) else task.wait(1) end
		end
	end)
end
if vitrina then
	for i, info in Exclusivos do
		local punto = vitrina:FindFirstChild("Maniqui" .. i)
		if punto then
			local timer = cartelExclusivo(punto, info)
			if timer then table.insert(maniquies, { timer = timer, termina = info.termina }) end
			local ver = punto:FindFirstChild("Ver") :: ProximityPrompt?
			if ver then
				ver:SetAttribute("ZeroActivo", true)            -- no lo apaga el bloque de zonas
				ver.ActionText = "Comprar"; ver.ObjectText = info.nombre; ver.HoldDuration = 0; ver.RequiresLineOfSight = false
				ver.Enabled = true
			end
			hookPrompt(ver, function()
				local ob = info.modelo and ArmasConfig.Obtencion[info.modelo]
				local pase = ob and ob.pase and (MonetizationConfig.Passes[ob.pase] or (MonetizationConfig.Exclusivos or {})[ob.pase])
				if info.modelo and string.find("," .. (player:GetAttribute("Armas") or "") .. ",", "," .. info.modelo .. ",", 1, true) then
					toast("¡Ya tienes " .. info.nombre .. "! Equípalo en el INVENTARIO.")
				elseif pase and pase.Id > 0 then
					game:GetService("MarketplaceService"):PromptGamePassPurchase(player, pase.Id)
				else
					uiAction("Open", "Shop")
				end
			end)
			-- tu avatar tarda en ponerse (AvatarAppearance): se viste 3 s después de cada personaje nuevo, y cada 2 s se
			-- comprueba que el maniquí exista (por si el personaje ya estaba listo antes de que este script empezara)
			local vestidoPara
			task.spawn(function()
				while punto.Parent do
					local char = player.Character
					if char and char:FindFirstChild("HumanoidRootPart") and (vestidoPara ~= char or not punto:FindFirstChild("Maniqui")) then
						task.wait(3)
						if player.Character == char then vestir(punto); vestidoPara = char end
					end
					task.wait(2)
				end
			end)
		end
	end
end

-- ===================================================================== MISIONES
local zonaMis = lobby:WaitForChild("Misiones", 30)
local marca, marcaTxt
local function spawnMisionero()
	local punto = zonaMis and zonaMis:FindFirstChild("PuntoNPC")
	local src = ReplicatedStorage:WaitForChild("ZeroMisioneros", 30)
	src = src and src:WaitForChild(tostring(player.UserId), 60)
	if not punto or not src then return end
	local npc = src:Clone()
	npc.Name = "NPC_Misiones"
	local root, hum = npc:FindFirstChild("HumanoidRootPart"), npc:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	for _, p in npc:GetDescendants() do
		if p:IsA("BasePart") then p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Anchored = false end
	end
	root.Anchored = true
	npc:PivotTo(punto.CFrame * CFrame.new(0, 3.1, 0))
	npc.Parent = zonaMis
	standOn(npc, punto:GetAttribute("Suelo"))
	local head = npc:FindFirstChild("Head")
	if head then
		local bb = new("BillboardGui", head, { Size = UDim2.fromScale(6, 1.3), StudsOffset = Vector3.new(0, 1.9, 0), MaxDistance = 70, LightInfluence = 0 })
		txt(bb, (npc:GetAttribute("NombreAmigo") or "Guía") .. "\nMISIONES", UDim2.fromScale(1, 1), C.white)
		marca = new("BillboardGui", head, { Size = UDim2.fromScale(1.6, 2.2), StudsOffset = Vector3.new(0, 3.4, 0), MaxDistance = 120, LightInfluence = 0 })
		marcaTxt = txt(marca, "!", UDim2.fromScale(1, 1), C.yellow)
	end
	-- coreografía propia: te sigue con la mirada, te saluda con todo al acercarte y cada pocos segundos presenta el
	-- tablón, celebra con un salto con giro o se marca un mortal.
	local amarillo = Color3.fromRGB(255, 210, 73)
	local r = rig(npc, amarillo)
	r.base0 = r.base
	r.suelo = punto:GetAttribute("Suelo")
	local TAU = math.pi * 2
	local function suelo(rr) return Vector3.new(rr.base0.X, rr.suelo or rr.base0.Y - 3, rr.base0.Z) end
	local function confeti(rr)
		for _, c in { C.pink, C.blue, C.green, C.yellow, C.purple } do chispas(rr.root, c, 10, 16, "rbxasset://textures/particles/fire_sparks_main.dds") end
	end
	local REPOSO = { ra = { 0.05, 0.12 }, la = { 0.05, 0.12 }, rl = { 0, 0.06 }, ll = { 0, 0.06 } }
	local function brazoDer(rr) return rr.model:FindFirstChild("Right Arm") end
	local SALUDO = {
		{ d = 0.25, e = "back", p = { ra = { 2.85, 0.6 }, la = { -0.2, 0.45 }, to = { -0.1, 0.08 }, he = { -0.15 }, rl = { 0, 0.1 }, ll = { 0, 0.1 } }, r = { 0, 0.2 } },
		{ d = 0.2, p = { ra = { 2.7, 1.0 }, la = { -0.2, 0.45 }, to = { -0.1, 0.12 }, he = { -0.15 }, rl = { 0, 0.1 }, ll = { 0, 0.1 } } },
		{ d = 0.2, p = { ra = { 2.8, 0.2 }, la = { -0.2, 0.45 }, to = { -0.1, 0.04 }, he = { -0.15 }, rl = { 0, 0.1 }, ll = { 0, 0.1 } } },
		{ d = 0.2, p = { ra = { 2.7, 1.0 }, la = { -0.2, 0.45 }, to = { -0.1, 0.12 }, he = { -0.15 }, rl = { 0, 0.1 }, ll = { 0, 0.1 } } },
		{ d = 0.2, p = { ra = { 2.8, 0.2 }, la = { -0.2, 0.45 }, to = { -0.1, 0.04 }, he = { -0.15 }, rl = { 0, 0.1 }, ll = { 0, 0.1 } } },
		-- "¡ven!": brazo al frente y gesto de llamar
		{ d = 0.25, e = "out", p = { ra = { 1.5, 0.1 }, la = { 0, 0.15 }, to = { 0.15 }, he = { 0 }, rl = { -0.15, 0.06 }, ll = { 0.15, 0.06 } } },
		{ d = 0.16, p = { ra = { 2.1, 0.1 }, la = { 0, 0.15 }, to = { 0.15 }, rl = { -0.15, 0.06 }, ll = { 0.15, 0.06 } } },
		{ d = 0.16, p = { ra = { 1.5, 0.1 }, la = { 0, 0.15 }, to = { 0.15 }, rl = { -0.15, 0.06 }, ll = { 0.15, 0.06 } } },
		{ d = 0.16, p = { ra = { 2.1, 0.1 }, la = { 0, 0.15 }, to = { 0.15 }, rl = { -0.15, 0.06 }, ll = { 0.15, 0.06 } } },
		{ d = 0.4, p = REPOSO },
	}
	local PRESENTA = {   -- gira hacia el tablón y lo presenta con un barrido del brazo
		{ d = 0.3, e = "out", p = { ra = { 1.1, -0.6 }, la = { 0.1, 0.3 }, to = { 0.05, 0, 0.6 }, he = { 0, 0, -0.2 }, rl = { 0, 0.1 }, ll = { 0, 0.1 } } },
		{ d = 0.45, e = "back", p = { ra = { 1.4, 1.7 }, la = { 0.1, 0.3 }, to = { -0.05, 0, 0.75 }, he = { -0.1, 0, -0.4 }, rl = { 0, 0.1 }, ll = { 0, 0.1 } },
			fx = function(rr) task.wait(0.2); local a = brazoDer(rr); if a then chispas(a, amarillo, 25, 10) end end },
		{ d = 0.9, hold = true },
		{ d = 0.35, e = "back", p = { ra = { 0.9, 1.3 }, la = { 0.9, 1.3 }, to = { -0.12 }, he = { -0.15 }, rl = { 0, 0.18 }, ll = { 0, 0.18 } }, r = { 0, 0.1 },
			fx = function(rr) task.wait(0.2); confeti(rr) end },
		{ d = 0.8, hold = true },
		{ d = 0.45, p = REPOSO },
	}
	local CELEBRA = {    -- salto con giro completo y puños arriba
		{ d = 0.18, e = "out", p = { ra = { -0.6, 0.3 }, la = { -0.6, 0.3 }, to = { 0.3 }, he = { 0.2 }, rl = { 0.3, 0.45 }, ll = { 0.3, 0.45 } }, r = { 0, -0.35 } },
		salto({ d = 0.7, p = { ra = { 3.0, 0.3 }, la = { 3.0, 0.3 }, to = { -0.15 }, he = { -0.3 }, rl = { 0.6, 0.15 }, ll = { -0.4, 0.15 } }, r = { 0, 0, 0, 0, TAU }, fx = confeti }, 3.5),
		{ d = 0.12, e = "out", p = { ra = { 1.2, 0.8 }, la = { 1.2, 0.8 }, to = { 0.3 }, he = { 0.1 }, rl = { 0.3, 0.45 }, ll = { 0.3, 0.45 } }, r = { 0, -0.35 },
			fx = function(rr) onda(suelo(rr), amarillo, 10) end },
		{ d = 0.15, e = "out", p = { ra = { 2.9, 0.2 }, la = { 0.3, 0.3 }, to = { -0.1 }, he = { -0.3 }, rl = { 0, 0.15 }, ll = { 0, 0.15 } }, r = { 0, 0.1 } },
		{ d = 0.15, p = { ra = { 2.1, 0.3 }, la = { 0.3, 0.3 }, to = { -0.05 }, he = { -0.2 }, rl = { 0, 0.15 }, ll = { 0, 0.15 } } },
		{ d = 0.15, e = "out", p = { ra = { 2.9, 0.2 }, la = { 0.3, 0.3 }, to = { -0.1 }, he = { -0.3 }, rl = { 0, 0.15 }, ll = { 0, 0.15 } }, r = { 0, 0.1 } },
		{ d = 0.15, p = { ra = { 2.1, 0.3 }, la = { 0.3, 0.3 }, to = { -0.05 }, he = { -0.2 }, rl = { 0, 0.15 }, ll = { 0, 0.15 } } },
		{ d = 0.45, p = REPOSO },
	}
	local MORTAL = {     -- mortal hacia atrás y "¡tachán!"
		{ d = 0.2, e = "out", p = { ra = { -0.9, 0.3 }, la = { -0.9, 0.3 }, to = { 0.35 }, he = { 0.1 }, rl = { 0.35, 0.5 }, ll = { 0.35, 0.5 } }, r = { 0, -0.4 } },
		salto({ d = 0.8, p = { ra = { 2.6, 0.4 }, la = { 2.6, 0.4 }, to = { 0.2 }, he = { 0.3 }, rl = { 1.5 }, ll = { 1.5 } }, r = { 0, 0, 0, TAU } }, 5),
		{ d = 0.12, e = "out", p = { ra = { 0.4, 0.5 }, la = { 0.4, 0.5 }, to = { 0.35 }, he = { 0.2 }, rl = { 0.35, 0.5 }, ll = { 0.35, 0.5 } }, r = { 0, -0.4 },
			fx = function(rr) onda(suelo(rr), amarillo, 11) end },
		{ d = 0.3, e = "back", p = { ra = { 0.8, 1.4 }, la = { 0.8, 1.4 }, to = { -0.15 }, he = { -0.2 }, rl = { -0.15, 0.2 }, ll = { -0.15, 0.2 } }, r = { 0, 0.05 },
			fx = function(rr) task.wait(0.15); confeti(rr) end },
		{ d = 0.9, hold = true },
		{ d = 0.45, p = REPOSO },
	}
	local EXTRAS = { PRESENTA, CELEBRA, MORTAL }
	bailar(r, { { d = 0.4, p = REPOSO } })
	local lastWave, nextExtra = 0, os.clock() + 3
	while npc.Parent do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		r.mirar = hrp
		local now = os.clock()
		if not cerca() then task.wait(1)
		elseif hrp and (hrp.Position - r.base0.Position).Magnitude < 16 and now - lastWave > 12 then
			lastWave = now; nextExtra = now + 5; bailar(r, SALUDO)
		elseif now > nextExtra then
			nextExtra = now + math.random(6, 9); bailar(r, EXTRAS[math.random(1, #EXTRAS)])
		else
			bailar(r, { { d = 0.25, hold = true } })
		end
	end
end
if zonaMis then
	task.spawn(spawnMisionero)
	local punto = zonaMis:FindFirstChild("PuntoNPC")
	hookPrompt(punto and punto:FindFirstChild("Misiones"), function()
		local ev = ReplicatedStorage:FindFirstChild("ZeroMisionesAbrir")
		if ev and ev:IsA("BindableEvent") then ev:Fire() else toast("¡Las misiones llegan muy pronto!") end
	end)
end

-- ===================================================================== ZONAS DE MENÚ
-- Pisar una zona del suelo (ZeroLobby.ZonasMenu, ver lobby_zonas_menu.luau) abre su menú; al salir se cierra si sigue
-- abierto. Sustituyen a los ProximityPrompts del lobby, que se desactivan.
local function apagarPrompt(d) if d:IsA("ProximityPrompt") and not d:GetAttribute("ZeroActivo") then d.Enabled = false end end
for _, d in lobby:GetDescendants() do apagarPrompt(d) end
lobby.DescendantAdded:Connect(apagarPrompt)
local zonasMenu = lobby:WaitForChild("ZonasMenu", 30)
local dentro: { [Instance]: boolean } = {}
local function abrirZona(menu: string)
	if menu == "Misiones" then
		local ev = ReplicatedStorage:FindFirstChild("ZeroMisionesAbrir")
		if ev and ev:IsA("BindableEvent") then ev:Fire() end
	else
		uiAction("Open", menu)
	end
end
local function cerrarZona(menu: string)
	if menu == "Misiones" then
		local g = player.PlayerGui:FindFirstChild("ZeroMisionesUI")
		if g and g:GetAttribute("Open") then g:SetAttribute("CerrarPedido", (g:GetAttribute("CerrarPedido") or 0) + 1) end
	else
		local ui = player.PlayerGui:FindFirstChild("ZeroUI")
		if ui and ui:GetAttribute("CurrentMenu") == menu then uiAction("Close") end
	end
end
if zonasMenu then
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.12 then return end
		acc = 0
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		for _, z in zonasMenu:GetChildren() do
			local base = z:IsA("Model") and z.PrimaryPart
			local menu = z:GetAttribute("Menu")
			if base and menu then
				local d = hrp and base.CFrame:PointToObjectSpace(hrp.Position)          -- área cuadrada (sigue el giro de la zona)
				local inside = d ~= nil and hum ~= nil and hum.Health > 0 and math.abs(d.X) <= base.Size.X / 2 + 0.3
					and math.abs(d.Z) <= base.Size.Z / 2 + 0.3 and d.Y > -2 and d.Y < 8
				if inside and not dentro[z] then
					dentro[z] = true; abrirZona(menu)
				elseif not inside and dentro[z] then
					dentro[z] = nil; cerrarZona(menu)
				end
			end
		end
	end)
end

-- dentro de una zona con su menú cerrado: "Abrir Tienda" / "Abrir Ruleta"… para volver a abrirlo sin salir y entrar
if zonasMenu then
	local NOMBRE = { Shop = "Tienda", Wheel = "Ruleta", Misiones = "Misiones" }
	local avisos: { [Instance]: ProximityPrompt } = {}
	local function abierto(menu: string): boolean
		if menu == "Misiones" then
			local g = player.PlayerGui:FindFirstChild("ZeroMisionesUI")
			return g ~= nil and g:GetAttribute("Open") == true
		end
		local ui = player.PlayerGui:FindFirstChild("ZeroUI")
		return ui ~= nil and ui:GetAttribute("CurrentMenu") == menu
	end
	RunService.Heartbeat:Connect(function()
		for _, z in zonasMenu:GetChildren() do
			local base = z:IsA("Model") and z.PrimaryPart
			local menu = z:GetAttribute("Menu")
			if base and menu then
				local p = avisos[z]
				if not p then
					p = Instance.new("ProximityPrompt")
					p:SetAttribute("ZeroActivo", true)
					p.Name = "AbrirZona"; p.ActionText = "Abrir " .. (NOMBRE[menu] or menu); p.ObjectText = ""
					p.HoldDuration = 0; p.RequiresLineOfSight = false; p.KeyboardKeyCode = Enum.KeyCode.E
					p.MaxActivationDistance = math.max(base.Size.X, base.Size.Z); p.Enabled = false
					p.Parent = base
					p.Triggered:Connect(function(who) if who == player then abrirZona(menu) end end)
					avisos[z] = p
				end
				local quiere = dentro[z] == true and not abierto(menu)
				if p.Enabled ~= quiere then p.Enabled = quiere end
			end
		end
	end)
end

-- ===================================================================== animación (solo cerca)
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - Vector3.new(-40, 70, 0)).Magnitude > 220 then return end
	if rotor then rotor.Rotation = (rotor.Rotation + dt * 9) % 360 end         -- giro lento de exhibición
	if marca then
		local listas = (player:GetAttribute("MisionesListas") or 0) > 0          -- premios por reclamar: "!" verde y saltón
		marca.StudsOffset = Vector3.new(0, 3.4 + math.sin(os.clock() * (listas and 7 or 3)) * (listas and 0.45 or 0.3), 0)
		if marcaTxt then marcaTxt.TextColor3 = listas and C.green or C.yellow end
	end
	for _, m in maniquies do m.timer.Text = fmtTime(m.termina - os.time()) end
	if zonasMenu then                                                          -- la luz de cada zona respira; se enciende si estás dentro
		local t = os.clock()
		for _, z in zonasMenu:GetChildren() do
			local on = dentro[z]
			local pulso = math.sin(t * 2.2 + z.Name:len())
			local base = z:FindFirstChild("Base")
			if base then base.Transparency = on and 0.38 or 0.55 + pulso * 0.06 end
			for _, muroP in z:GetChildren() do
				if muroP.Name:sub(1, 4) == "Muro" then
					for _, sg in muroP:GetChildren() do
						if sg:IsA("SurfaceGui") then sg.Brightness = on and 3.4 or 2.2 + pulso * 0.5 end
					end
				end
			end
		end
	end
end)
