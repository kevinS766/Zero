-- CristalesHielo (ModuleScript, ReplicatedStorage.VFX): habilidad del cazador GÉLIDO de ZERO — lluvia de cristales de hielo.
-- Adaptado del "mirror shard barrage": el cazador alza el brazo derecho (pose procedural sobre ZeroMovement), seis
-- cristales angulares aparecen en abanico detrás de sus hombros con un destello duro, flotan y se giran hacia el
-- objetivo (~40 studs), salen disparados uno tras otro con una estela fina de bordes cian/lila, se clavan en el suelo
-- abriendo una grieta en telaraña y, cuando cae el sexto, todos estallan a la vez en fragmentos, una cúpula y un anillo
-- de luz refractada. Paleta fría: blanco, hielo pálido, azul hielo y sombras azul pizarra dentro de los cristales.
-- Texturas dibujadas en Blender: zero-hielo/blender/texturas.py.
--
-- Uso (cliente):
--   local Hielo = require(ReplicatedStorage.VFX.CristalesHielo)
--   Hielo.Play(personaje, objetivo)                      -- prueba local: dispara ya
--   Hielo.Play(personaje, objetivo, inicio, origen)       -- sincronizado: inicio = workspace:GetServerTimeNow() del servidor
-- Servidor: Hielo.estallido(origen, objetivo) = segundos desde el lanzamiento hasta que estallan (para congelar a la vez).
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Hielo = {}

local TEX = {
	destello = "rbxassetid://90451150464733", grieta = "rbxassetid://79098871767624", anillo = "rbxassetid://86746617876623",
	fragmento = "rbxassetid://112705478562091", estela = "rbxassetid://78171566933199",
}
Hielo.TEX = TEX

-- ------------------------------------------------------------------ ajustes
local N = 6                        -- cristales
local APARECE, ESCALON = 0.10, 0.07 -- cuándo aparece el primero y separación entre ellos
local APUNTA0, APUNTA1 = 0.80, 1.10 -- giro hacia el objetivo
local DISPARO, CADENCIA = 1.18, 0.08
local VEL = 165                    -- studs/s en vuelo
local RADIO_FAN, ALTO_FAN, ATRAS_FAN = 2.1, 1.7, 1.3
local LARGO, BASE, ANCHO, GROSOR = 2.7, 0.9, 1.05, 0.2
local RADIO_IMPACTO = 2.4          -- los cristales se clavan en un círculo alrededor del objetivo
Hielo.RADIO = 8                    -- radio de congelación (lo usa el servidor)
Hielo.ALCANCE = 40
Hielo.ESCALA = 1                   -- velocidad del tiempo del efecto (pruebas a cámara lenta: 0.1)

local BLANCO = Color3.fromRGB(255, 255, 255)
local PALIDO = Color3.fromHex("#D6F1FF")
local HIELO = Color3.fromHex("#86C8F5")
local AZUL = Color3.fromHex("#3B6FC4")
local PIZARRA = Color3.fromHex("#1D2F57")

local function vuelo(origen: Vector3, objetivo: Vector3): number
	return math.clamp((objetivo - origen).Magnitude / VEL, 0.12, 0.38)
end
function Hielo.estallido(origen: Vector3, objetivo: Vector3): number
	return DISPARO + (N - 1) * CADENCIA + vuelo(origen, objetivo) + 0.08
end

local function suave(x: number): number x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

-- ------------------------------------------------------------------ geometría: triángulos con WedgeParts
local function parte(clase: string, props): BasePart
	local p = Instance.new(clase) :: BasePart
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do (p :: any)[k] = v end
	return p
end
-- triángulo a,b,c (espacio local) -> dos cuñas con su CFrame local
local function triangulo(a: Vector3, b: Vector3, c: Vector3, color: Color3, lista)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then c, a = a, c
	elseif acd > bcd and acd > abd then a, b = b, a end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local h = math.abs(ab:Dot(up))
	for _, w in { { (a + b) / 2, right, back, math.abs(ab:Dot(back)) }, { (a + c) / 2, -right, -back, math.abs(ac:Dot(back)) } } do
		local p = parte("WedgePart", { Size = Vector3.new(0.04, h, w[4]), Color = color, Material = Enum.Material.Glass,
			Reflectance = 0.35, Transparency = 1 })
		table.insert(lista, { p = p, cf = CFrame.fromMatrix(w[1], w[2], up, w[3]), t = 0.08 })
	end
end
-- cristal facetado: punta hacia -Z, plano en XZ, caras abombadas en ±Y
local function cristal(padre: Instance)
	local T, B = Vector3.new(0, 0, -LARGO), Vector3.new(0, 0, BASE)
	local R, L = Vector3.new(ANCHO / 2, 0, 0), Vector3.new(-ANCHO / 2, 0, 0)
	local C1, C2 = Vector3.new(0.05, GROSOR, -0.35), Vector3.new(-0.05, -GROSOR, -0.35)
	local piezas = {}
	-- cara de delante: una faceta clara (reflejo) y el resto en azul / pizarra (sombra dentro del cristal)
	triangulo(T, R, C1, PALIDO, piezas); triangulo(R, B, C1, AZUL, piezas)
	triangulo(B, L, C1, PIZARRA, piezas); triangulo(L, T, C1, HIELO, piezas)
	triangulo(T, R, C2, HIELO, piezas); triangulo(R, B, C2, PIZARRA, piezas)
	triangulo(B, L, C2, AZUL, piezas); triangulo(L, T, C2, PALIDO, piezas)
	-- borde de luz (Neon) a lo largo del contorno
	for _, e in { { T, R }, { R, B }, { B, L }, { L, T } } do
		local a, b = e[1], e[2]
		local p = parte("Part", { Size = Vector3.new(0.06, 0.06, (b - a).Magnitude), Color = PALIDO, Material = Enum.Material.Neon,
			Transparency = 1 })
		table.insert(piezas, { p = p, cf = CFrame.lookAt((a + b) / 2, b), t = 0.35 })
	end
	-- núcleo invisible con los Attachments (punta, estela y destellos)
	local nucleo = parte("Part", { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
	local punta = Instance.new("Attachment"); punta.Name = "Punta"; punta.Position = T; punta.Parent = nucleo
	local e0 = Instance.new("Attachment"); e0.Position = Vector3.new(-0.32, 0, -0.6); e0.Parent = nucleo
	local e1 = Instance.new("Attachment"); e1.Position = Vector3.new(0.32, 0, -0.6); e1.Parent = nucleo
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = e0, e1
	tr.Texture = TEX.estela; tr.TextureMode = Enum.TextureMode.Stretch
	tr.Lifetime = 0.22; tr.MinLength = 0.05; tr.FaceCamera = true; tr.LightEmission = 1; tr.LightInfluence = 0
	tr.Color = ColorSequence.new(BLANCO); tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25) })
	tr.Enabled = false; tr.Parent = nucleo
	table.insert(piezas, { p = nucleo, cf = CFrame.identity, t = 1 })
	for _, x in piezas do x.p.Parent = padre end
	return { piezas = piezas, nucleo = nucleo, punta = punta, estela = tr }
end

-- ------------------------------------------------------------------ efectos sueltos
local function emisor(padre: Instance, tex: string, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex; e.Rate = 0; e.LightEmission = 1; e.LightInfluence = 0
	e.Speed = NumberRange.new(0); e.Lifetime = NumberRange.new(0.2)
	for k, v in props do (e :: any)[k] = v end
	e.Parent = padre
	return e
end
local function seq(a: number, b: number) return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }) end

local function destello(padre: Instance, tam: number, vida: number?)
	local e = emisor(padre, TEX.destello, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, tam * 0.3), NumberSequenceKeypoint.new(0.25, tam),
		NumberSequenceKeypoint.new(1, tam * 0.2) }), Transparency = seq(0, 1), Lifetime = NumberRange.new(vida or 0.22),
		Rotation = NumberRange.new(0, 0), Color = ColorSequence.new(BLANCO), ZOffset = 2 })
	e:Emit(1)
	Debris:AddItem(e, (vida or 0.22) + 0.1)
end
local function anilloLuz(padre: Instance, de: number, a: number, vida: number)
	local e = emisor(padre, TEX.anillo, { Size = seq(de, a), Transparency = seq(0.05, 1), Lifetime = NumberRange.new(vida),
		Color = ColorSequence.new(PALIDO), ZOffset = 1 })
	e:Emit(1)
	Debris:AddItem(e, vida + 0.1)
end
local function fragmentos(padre: Instance, n: number, fuerza: number)
	local e = emisor(padre, TEX.fragmento, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.15) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(fuerza * 0.5, fuerza), SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -45, 0), Drag = 1.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-400, 400),
		Color = ColorSequence.new(BLANCO, HIELO), LightEmission = 0.4, EmissionDirection = Enum.NormalId.Top })
	e:Emit(n)
	Debris:AddItem(e, 1.3)
end
local function luz(padre: Instance, brillo: number, rango: number, vida: number)
	local l = Instance.new("PointLight"); l.Color = PALIDO; l.Brightness = brillo; l.Range = rango; l.Shadows = false; l.Parent = padre
	TweenService:Create(l, TweenInfo.new(vida, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(l, vida + 0.1)
end

local function suelo(pos: Vector3, ignorar: { Instance }): (Vector3, Vector3)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = ignorar
	local hit = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rp)
	if hit then return hit.Position, hit.Normal end
	return pos, Vector3.yAxis
end

-- grieta en telaraña sobre el suelo (pieza invisible con Decal arriba)
local function grieta(carpeta: Instance, pos: Vector3, normal: Vector3, tam: number)
	local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(-math.pi / 2, 0, math.random() * math.pi * 2)
	local p = parte("Part", { Size = Vector3.new(tam, 0.05, tam), CFrame = cf + normal * 0.03, Transparency = 1 })
	local d = Instance.new("Decal"); d.Face = Enum.NormalId.Top; d.Texture = TEX.grieta; d.Color3 = PALIDO; d.Transparency = 1; d.Parent = p
	p.Parent = carpeta
	TweenService:Create(d, TweenInfo.new(0.08), { Transparency = 0.1 }):Play()
	return p, d
end

-- ------------------------------------------------------------------ brazo alzado
-- ZeroMovement mezcla la pose del hechizo (brazo derecho arriba, cabeza alzada) con el peso del atributo
-- ZeroBrazoHechizo del personaje (0..1). Se pone en este cliente cada fotograma mientras dura el lanzamiento.
local function pose(personaje: Model, peso: () -> number)
	local c = RunService.Heartbeat:Connect(function()
		personaje:SetAttribute("ZeroBrazoHechizo", math.clamp(peso(), 0, 1))
	end)
	return { Disconnect = function() c:Disconnect(); personaje:SetAttribute("ZeroBrazoHechizo", nil) end }
end

-- ------------------------------------------------------------------ secuencia
function Hielo.Play(personaje: Model, objetivo: Vector3, inicio: number?, origen: Vector3?): number
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return 0 end
	local raiz = workspace:FindFirstChild("ZeroVFX") or Instance.new("Folder")
	raiz.Name = "ZeroVFX"; raiz.Parent = workspace
	local carpeta = Instance.new("Folder"); carpeta.Name = "CristalesHielo"; carpeta.Parent = raiz
	local ignorar = { personaje, raiz }
	local base = origen or hrp.Position
	local tVuelo = vuelo(base, objetivo)
	local tEstallido = Hielo.estallido(base, objetivo)
	local escala = Hielo.ESCALA
	local t0 = os.clock() - (if inicio then math.max(0, workspace:GetServerTimeNow() - inicio) else 0) / escala

	-- cristales y su sitio en el abanico (ángulos en el plano de la espalda: 0 = derecha, 90 = arriba)
	local cristales = {}
	for i = 1, N do
		local c = cristal(carpeta)
		local ang = math.rad(18 + (i - 1) * (144 / (N - 1)))
		local a = (i - 1) * (2 * math.pi / N) + 0.4
		local q, normal = suelo(objetivo + Vector3.new(math.cos(a), 0, math.sin(a)) * RADIO_IMPACTO * (i % 2 == 0 and 1 or 0.6), ignorar)
		c.ang, c.q, c.normal = ang, q, normal
		c.aparece = APARECE + (i - 1) * ESCALON
		c.dispara = DISPARO + (i - 1) * CADENCIA
		c.fase = math.random() * 6
		cristales[i] = c
	end

	local function abanico(c, t: number): CFrame
		local cf = hrp.CFrame
		local centro = cf * Vector3.new(0, ALTO_FAN, ATRAS_FAN)
		local radial = cf.RightVector * math.cos(c.ang) + cf.UpVector * math.sin(c.ang)
		local sale = suave((t - c.aparece) / 0.2)                         -- se despliega desde el centro
		local pos = centro + radial * (0.5 + (RADIO_FAN - 0.5) * sale) + Vector3.new(0, math.sin(t * 3 + c.fase) * 0.06, 0)
		local fuera = (radial - cf.LookVector * 0.35).Unit                -- la punta hacia fuera y un poco atrás
		local apunta = (objetivo - pos).Unit
		local w = suave((t - APUNTA0) / (APUNTA1 - APUNTA0))
		local dir = fuera:Lerp(apunta, w)
		dir = if dir.Magnitude > 1e-3 then dir.Unit else apunta
		return CFrame.lookAt(pos, pos + dir, -cf.LookVector)               -- la cara mira hacia atrás (a la cámara)
	end
	local function colocar(c, cf: CFrame, transp: number?)
		for _, x in c.piezas do
			x.p.CFrame = cf * x.cf
			if transp then x.p.Transparency = if x.t >= 1 then 1 else x.t + (1 - x.t) * transp end
		end
	end

	-- brazo: sube en 0,25 s, se mantiene hasta disparar el último y baja en 0,3 s
	local bajar = DISPARO + (N - 1) * CADENCIA + 0.15
	local conPose = pose(personaje, function()
		local t = (os.clock() - t0) * escala
		return suave(t / 0.25) * (1 - suave((t - bajar) / 0.3))
	end)
	local mano = personaje:FindFirstChild("Right Arm") :: BasePart?
	if mano then
		local a = Instance.new("Attachment"); a.Position = Vector3.new(0, -1, 0); a.Parent = mano
		task.delay(0.18, function() destello(a, 2.2, 0.3); luz(a, 3, 10, 0.4) end)
		Debris:AddItem(a, 1)
	end

	local grietas = {}
	local estallado = false
	local conexion: RBXScriptConnection
	conexion = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) * escala
		if not hrp.Parent then conexion:Disconnect(); carpeta:Destroy(); return end
		for _, c in cristales do
			if c.roto then continue end
			if t < c.aparece then
				colocar(c, abanico(c, t), 1)
			elseif t < c.dispara then
				local f = math.clamp((t - c.aparece) / 0.15, 0, 1)
				colocar(c, abanico(c, t), 1 - f)
				if not c.visto then c.visto = true; destello(c.punta, 3.2, 0.22); luz(c.nucleo, 2, 8, 0.3) end
			elseif t < c.dispara + tVuelo then
				if not c.p0 then                                              -- sale disparado
					local cf = abanico(c, t)
					c.p0 = cf.Position
					c.dir = (c.q - c.p0).Unit
					c.estela.Enabled = true
					anilloLuz(c.nucleo, 0.5, 3.2, 0.25)
					destello(c.punta, 2.4, 0.15)
				end
				local f = (t - c.dispara) / tVuelo
				local p = c.p0:Lerp(c.q - c.dir * (LARGO * 0.65), f * f * (2 - f))  -- acelera al principio
				colocar(c, CFrame.lookAt(p, p + c.dir), 0)
			elseif not c.clavado then                                          -- se clava en el suelo
				c.clavado = true
				if not c.dir then c.dir = (c.q - abanico(c, t).Position).Unit end   -- llegó tarde (lag): se salta el vuelo
				local p = c.q - c.dir * (LARGO * 0.65)
				colocar(c, CFrame.lookAt(p, p + c.dir), 0)
				c.estela.Enabled = false
				local g = grieta(carpeta, c.q, c.normal, 5.5)
				table.insert(grietas, g)
				local a = Instance.new("Attachment"); a.Parent = g
				fragmentos(a, 6, 14); destello(a, 2.6, 0.18)
			end
		end
		if not estallado and t >= tEstallido then                              -- el sexto llegó: estallan todos
			estallado = true
			for _, c in cristales do
				local a = Instance.new("Attachment"); a.Parent = c.nucleo
				fragmentos(a, 16, 26)
				c.roto = true
				for _, x in c.piezas do if x.p ~= c.nucleo then x.p:Destroy() end end
				task.delay(1.3, function() c.nucleo:Destroy() end)
			end
			local centro = suelo(objetivo, ignorar)
			local ancla = parte("Part", { Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(centro + Vector3.new(0, 1, 0)) })
			ancla.Parent = carpeta
			local a = Instance.new("Attachment"); a.Parent = ancla
			destello(a, 11, 0.35); anilloLuz(a, 2, 16, 0.45); luz(ancla, 9, 34, 0.6)
			-- anillo en el suelo
			local aro = parte("Part", { Size = Vector3.new(2, 0.05, 2), CFrame = CFrame.new(centro + Vector3.new(0, 0.08, 0)), Transparency = 1 })
			local d = Instance.new("Decal"); d.Face = Enum.NormalId.Top; d.Texture = TEX.anillo; d.Color3 = BLANCO; d.Parent = aro
			aro.Parent = carpeta
			local ti = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			TweenService:Create(aro, ti, { Size = Vector3.new(Hielo.RADIO * 3.6, 0.05, Hielo.RADIO * 3.6) }):Play()
			TweenService:Create(d, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			-- cúpula de luz refractada
			local cupula = parte("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(centro),
				Material = Enum.Material.ForceField, Color = PALIDO, Transparency = 0.1 })
			cupula.Parent = carpeta
			TweenService:Create(cupula, ti, { Size = Vector3.one * Hielo.RADIO * 2.3 }):Play()
			TweenService:Create(cupula, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			-- las grietas se desvanecen
			for _, g in grietas do
				local dec = g:FindFirstChildOfClass("Decal")
				if dec then TweenService:Create(dec, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), { Transparency = 1 }):Play() end
			end
			task.delay(2.2 / escala, function()
				if conexion.Connected then conexion:Disconnect() end
				carpeta:Destroy()
			end)
		end
	end)
	task.delay((tEstallido + 3) / escala, function()                               -- seguridad
		if conexion.Connected then conexion:Disconnect() end
		if conPose then conPose:Disconnect() end
		if carpeta.Parent then carpeta:Destroy() end
	end)
	task.delay((bajar + 0.4) / escala, function() if conPose then conPose:Disconnect() end end)
	return tEstallido + 2.2
end

return Hielo
