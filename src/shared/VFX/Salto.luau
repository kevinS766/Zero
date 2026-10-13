-- Salto (ModuleScript, ReplicatedStorage.VFX): habilidad de rareza LEGENDARIO de ZERO (tecla E, cazador): teletransporte.
-- Referencias: C:/Users/Joshua/Downloads/tp.mp4 y el concepto de ChatGPT "Generar hoja VFX teleportación". Secuencia:
--   AVISO (Salto.AVISO s): el cazador alza el brazo, un hechizo sale de su mano hasta el destino; allí se abre el sello en
--   el suelo, sube un pilar de luz y aparece el detalle de la skin (los corredores lo ven venir).
--   SALTO: en el origen la silueta del cazador se deshace en cuadritos oscuros con tajos; entre los dos puntos pasa una
--   estela de cometa con siluetas y líneas de velocidad; llega con fogonazo del pilar, tajos grandes, onda, destello y el
--   estallido de la skin; la cámara de quien está cerca tiembla. El servidor lo mueve y aturde a los corredores del radio.
--   Para el cazador: líneas de velocidad en pantalla y un instante de "tiempo congelado" teñido de la skin.
--   Reloj     (Bastón Reloj de Arena)  esfera de reloj dorada, manecillas que giran, engranajes y arena
--   Grimorio  (Bastón del Grimorio)    círculo de runas con libro abierto, páginas en espiral, runas y cristales cian
--   Dominio   (Bastón de Dominio)      portal del vacío morado y negro, orbe oscuro, rayos y fragmentos negros
-- Texturas: zero-habilidades/legendario/blender/texturas_legendario.py.
--
--   Salto.destino(personaje, objetivo) -> pies del destino (Vector3) o nil   lo usan servidor y cliente: hay que ver el destino
--                                                                           (no atraviesa paredes), tener suelo y caber
--   Salto.Play(personaje, destino, inicio?, origen?, skin?)                  cliente
--   Salto.aturdido(personaje, skin, duracion)                               sello pequeño girando sobre la cabeza
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Rafaga = require(script.Parent:WaitForChild("Rafaga"))
local U = Rafaga.U
local T = Rafaga.TEX

local Salto = {}

local TEX = {
	sello_reloj = "rbxassetid://126966992469392", sello_grimorio = "rbxassetid://108288397400154", sello_dominio = "rbxassetid://80858106066169",
	tajo = "rbxassetid://77429528312875", arena = "rbxassetid://125030412416478", engranaje = "rbxassetid://90723518207137",
	pagina = "rbxassetid://109949652251358", runa = "rbxassetid://79883310690942", cuadritos = "rbxassetid://90932578005687",
	lineas = "rbxassetid://110590022158296", fragmento = "rbxassetid://112705478562091",
}
Salto.TEX = TEX
Salto.AVISO = 0.3                               -- segundos entre lanzar y saltar
Salto.ESCALA = 1

local BLANCO = Color3.new(1, 1, 1)
local SKINS = {
	Reloj = { sello = TEX.sello_reloj, sprite = TEX.engranaje, c1 = Color3.fromHex("#FFF2C2"), c2 = Color3.fromHex("#FFC93A"),
		c3 = Color3.fromHex("#B8741A"), oscuro = Color3.fromHex("#3A2408"), tinte = Color3.fromHex("#FFF0C8") },
	Grimorio = { sello = TEX.sello_grimorio, sprite = TEX.runa, c1 = Color3.fromHex("#E6FBFF"), c2 = Color3.fromHex("#3FD0FF"),
		c3 = Color3.fromHex("#0E5A8A"), oscuro = Color3.fromHex("#0B2A40"), tinte = Color3.fromHex("#D2F4FF") },
	Dominio = { sello = TEX.sello_dominio, sprite = TEX.fragmento, c1 = Color3.fromHex("#E3C2FF"), c2 = Color3.fromHex("#B05CFF"),
		c3 = Color3.fromHex("#4A1580"), oscuro = Color3.fromHex("#0A0414"), tinte = Color3.fromHex("#D8B8FF") },
}
for n, s in SKINS do s.nombre = n end
Salto.SKINS = SKINS

-- ------------------------------------------------------------------ destino válido
local function ignorarTodo(personaje: Model): { Instance }
	local l: { Instance } = { personaje }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(l, p.Character) end end
	for _, n in { "ZeroBots", "ZeroVFX" } do local f = workspace:FindFirstChild(n); if f then table.insert(l, f) end end
	return l
end
function Salto.destino(personaje: Model, objetivo: Vector3): Vector3?
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = ignorarTodo(personaje)
	local ojo = hrp.Position + Vector3.new(0, 1.5, 0)
	local meta = objetivo + Vector3.new(0, 3, 0)
	local dir = meta - ojo
	if dir.Magnitude < 1 then return nil end
	local muro = workspace:Raycast(ojo, dir, rp)
	if muro then meta = muro.Position - dir.Unit * 2.5 end                -- se queda delante de la pared
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = ignorarTodo(personaje)
	op.RespectCanCollide = true
	for _ = 1, 6 do
		local suelo = workspace:Raycast(meta + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), rp)
		if suelo then
			local hueco = workspace:GetPartBoundsInBox(CFrame.new(suelo.Position + Vector3.new(0, 3, 0)), Vector3.new(2.4, 4.6, 2.4), op)
			if #hueco == 0 then return suelo.Position end
		end
		meta -= dir.Unit * 2                                                  -- no cabe: un poco más cerca
		if (meta - ojo):Dot(dir) <= 0 then break end
	end
	return nil
end

-- ------------------------------------------------------------------ piezas sueltas
local function seg(x: number): number return x / Salto.ESCALA end           -- duraciones reales (cámara lenta de pruebas)

local function fantasma(personaje: Model, carpeta: Instance, cf: CFrame, color: Color3, dura: number, transp0: number)
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	for _, p in personaje:GetDescendants() do
		if p:IsA("BasePart") and p ~= hrp and p.Transparency < 1 then
			local g = p:Clone()
			g:ClearAllChildren()
			g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
			g.Material = Enum.Material.Neon; g.Color = color; g.Transparency = transp0
			if g:IsA("MeshPart") then pcall(function() (g :: any).TextureID = "" end) end
			g.CFrame = cf * hrp.CFrame:ToObjectSpace(p.CFrame)
			g.Parent = carpeta
			TweenService:Create(g, TweenInfo.new(seg(dura), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			Debris:AddItem(g, seg(dura) + 0.1)
		end
	end
end

local function tajos(a: Attachment, skin, n: number, tam: number)
	U.soltar(a, n, TEX.tajo, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, tam * 0.5), NumberSequenceKeypoint.new(0.3, tam),
		NumberSequenceKeypoint.new(1, tam * 1.15) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(0.22, 0.32), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-500, 500),
		Speed = NumberRange.new(0, 3), SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(skin.c1, skin.c2), ZOffset = 2 })
end

local function chispas(a: Attachment, tex: string, color: ColorSequence, n: number, fuerza: number, tam: number, luz: boolean?)
	U.soltar(a, n, tex, { Size = U.seq(tam, tam * 0.25), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(fuerza * 0.4, fuerza), SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -25, 0), Drag = 1.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), Color = color,
		LightEmission = if luz == false then 0 else 0.8, LightInfluence = if luz == false then 1 else 0 })
end

-- la silueta se deshace en cuadritos oscuros y de color (caja del tamaño del personaje)
local function deshacer(carpeta: Instance, cf: CFrame, skin)
	local caja = U.parte("Part", { Size = Vector3.new(2.2, 5, 1.2), Transparency = 1, CFrame = cf })
	caja.Parent = carpeta
	for _, c in { { skin.oscuro, 26, 0 }, { skin.c2, 14, 1 } } do
		U.soltar(caja, c[2], TEX.cuadritos, { Shape = Enum.ParticleEmitterShape.Box, Size = U.seq(0.9, 0.2), Transparency = U.seq(0, 1),
			Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(2, 7), SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 4, 0), Drag = 2, Rotation = NumberRange.new(0, 90), Color = ColorSequence.new(c[1]), LightEmission = c[3],
			LightInfluence = 1 - c[3] })
	end
	Debris:AddItem(caja, seg(1.2))
end

-- temblor de cámara breve (para quien está cerca de la llegada)
local function temblor(fuerza: number, dura: number)
	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	local nombre = "ZeroSaltoTemblor" .. tostring(t0)
	RunService:BindToRenderStep(nombre, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - t0
		if t > dura then RunService:UnbindFromRenderStep(nombre); return end
		local k = fuerza * (1 - t / dura)
		cam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
	end)
end

-- pantalla de quien salta: líneas de velocidad, golpe de FOV y "tiempo congelado" teñido de la skin
local function pantallaSalto(skin)
	local cam = workspace.CurrentCamera
	local gui = Instance.new("ScreenGui"); gui.Name = "ZeroSalto"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 40; gui.ResetOnSpawn = false
	local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Image = TEX.lineas; im.ImageColor3 = skin.c1; im.ImageTransparency = 0.05
	im.AnchorPoint = Vector2.new(0.5, 0.5); im.Position = UDim2.fromScale(0.5, 0.5); im.Size = UDim2.fromScale(1.2, 1.2)
	im.SizeConstraint = Enum.SizeConstraint.RelativeXX; im.Parent = gui
	local flash = Instance.new("Frame"); flash.BackgroundColor3 = skin.c1; flash.BackgroundTransparency = 0.55; flash.Size = UDim2.fromScale(1, 1)
	flash.BorderSizePixel = 0; flash.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	TweenService:Create(im, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { ImageTransparency = 1, Size = UDim2.fromScale(1.6, 1.6) }):Play()
	TweenService:Create(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(gui, 0.4)
	local cc = Instance.new("ColorCorrectionEffect"); cc.Name = "ZeroSalto"; cc.Parent = game:GetService("Lighting")
	TweenService:Create(cc, TweenInfo.new(0.06), { Saturation = -0.85, Contrast = 0.25, TintColor = skin.tinte }):Play()
	local fov = cam.FieldOfView
	TweenService:Create(cam, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov + 14 }):Play()
	task.delay(0.12, function()
		TweenService:Create(cc, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Saturation = 0, Contrast = 0, TintColor = BLANCO }):Play()
		TweenService:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov }):Play()
		Debris:AddItem(cc, 0.5)
	end)
end

-- ------------------------------------------------------------------ detalles de cada skin
-- aviso(skin, carpeta, destino) -> function(t, fin): se llama cada fotograma hasta el salto (fin = true una vez, al saltar)
-- llegada(skin, carpeta, destino, a)                 estallido al llegar (a = Attachment a media altura)
local DETALLE = {}

DETALLE.Reloj = {
	aviso = function(skin, carpeta: Instance, destino: Vector3)
		-- dos manecillas de luz girando sobre la esfera y engranajes que suben
		local larga = U.parte("Part", { Size = Vector3.new(0.18, 0.05, 3.6), Material = Enum.Material.Neon, Color = skin.c1, Transparency = 1 })
		local corta = U.parte("Part", { Size = Vector3.new(0.26, 0.05, 2.4), Material = Enum.Material.Neon, Color = skin.c2, Transparency = 1 })
		larga.Parent = carpeta; corta.Parent = carpeta
		local _, a = U.ancla(carpeta, destino + Vector3.new(0, 0.4, 0))
		local eng = U.emisor(a, TEX.engranaje, { Rate = 14, Lifetime = NumberRange.new(0.6, 0.9), Size = U.seq(1.2, 0.4), Transparency = U.seq(0.05, 1),
			Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top, RotSpeed = NumberRange.new(-200, 200),
			Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c2, skin.c3) })
		return function(t: number, fin: boolean)
			if fin then larga:Destroy(); corta:Destroy(); eng.Enabled = false; return end
			local vis = U.suave(t / 0.15)
			for i, m in { larga, corta } do
				local ang = -t * (i == 1 and 22 or 9)
				m.CFrame = CFrame.new(destino + Vector3.new(0, 0.12 + i * 0.02, 0)) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -m.Size.Z / 2)
				m.Transparency = 1 - vis * 0.9
			end
		end
	end,
	llegada = function(skin, carpeta: Instance, destino: Vector3, a: Attachment)
		chispas(a, TEX.engranaje, ColorSequence.new(skin.c2, skin.c3), 10, 22, 1.6)
		chispas(a, TEX.arena, ColorSequence.new(skin.c2, skin.c3), 30, 24, 0.8)
		U.anilloLuz(a, 14, 2, 0.3, skin.c1)                                   -- "tic": anillo que se cierra
	end,
}

DETALLE.Grimorio = {
	aviso = function(skin, carpeta: Instance, destino: Vector3)
		-- páginas girando en espiral alrededor del destino y runas que suben
		local orbita = {}
		for i = 1, 3 do
			local _, a = U.ancla(carpeta, destino)
			local e = U.emisor(a, TEX.pagina, { Rate = 12, Lifetime = NumberRange.new(0.5, 0.7), Size = U.seq(1.1, 0.7), Transparency = U.seq(0, 1),
				Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-260, 260),
				Color = ColorSequence.new(BLANCO), LightEmission = 0.2, LightInfluence = 0.6 })
			orbita[i] = { a = a, e = e }
		end
		local _, ar = U.ancla(carpeta, destino + Vector3.new(0, 0.4, 0))
		local runas = U.emisor(ar, TEX.runa, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 20, Lifetime = NumberRange.new(0.5, 0.8), Size = U.seq(0.9, 0.3),
			Transparency = U.seq(0, 1), Speed = NumberRange.new(5, 9), EmissionDirection = Enum.NormalId.Top, Color = ColorSequence.new(skin.c1, skin.c2) })
		return function(t: number, fin: boolean)
			for i, o in orbita do
				if fin then o.e.Enabled = false; continue end
				local ang = t * 9 + i * 2 * math.pi / 3
				o.a.WorldPosition = destino + Vector3.new(math.cos(ang) * 3, 0.6 + t * 6, math.sin(ang) * 3)
			end
			if fin then runas.Enabled = false end
		end
	end,
	llegada = function(skin, carpeta: Instance, destino: Vector3, a: Attachment)
		chispas(a, TEX.pagina, ColorSequence.new(BLANCO), 16, 22, 1.4, false)
		chispas(a, TEX.runa, ColorSequence.new(skin.c1, skin.c2), 14, 18, 1.1)
		chispas(a, TEX.fragmento, ColorSequence.new(skin.c1, skin.c2), 18, 26, 0.8)
	end,
}

DETALLE.Dominio = {
	aviso = function(skin, carpeta: Instance, destino: Vector3)
		-- orbe del vacío que crece sobre el portal, con una capa morada y rayos que chisporrotean
		local orbe = U.parte("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, Material = Enum.Material.Neon, Color = skin.oscuro,
			CFrame = CFrame.new(destino + Vector3.new(0, 2.6, 0)) })
		local capa = U.parte("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, Material = Enum.Material.ForceField, Color = skin.c2,
			CFrame = orbe.CFrame })
		orbe.Parent = carpeta; capa.Parent = carpeta
		local a = Instance.new("Attachment"); a.Parent = orbe
		local rayos = U.emisor(a, T.rayo, { Rate = 22, Lifetime = NumberRange.new(0.08, 0.14), Size = U.seq(2.6, 1.6), Transparency = U.seq(0, 0.4),
			Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(skin.c1, skin.c2), Speed = NumberRange.new(0), ZOffset = 1 })
		local humo = U.emisor(a, T.vapor, { Rate = 12, Lifetime = NumberRange.new(0.5, 0.8), Size = U.seq(2, 4), Transparency = U.seq(0.35, 1),
			Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(skin.oscuro), LightEmission = 0, LightInfluence = 0 })
		return function(t: number, fin: boolean)
			if fin then
				-- se encoge de golpe (implosión) antes del estallido
				TweenService:Create(orbe, TweenInfo.new(seg(0.08)), { Size = Vector3.one * 0.1 }):Play()
				TweenService:Create(capa, TweenInfo.new(seg(0.08)), { Size = Vector3.one * 0.1 }):Play()
				rayos.Enabled = false; humo.Enabled = false
				Debris:AddItem(orbe, seg(0.1)); Debris:AddItem(capa, seg(0.1))
				return
			end
			local s = 0.2 + 2.6 * U.rebote(math.min(t / 0.25, 1))
			orbe.Size = Vector3.one * s * 0.7; capa.Size = Vector3.one * s * (1.05 + 0.08 * math.sin(t * 40))
		end
	end,
	llegada = function(skin, carpeta: Instance, destino: Vector3, a: Attachment)
		chispas(a, TEX.fragmento, ColorSequence.new(skin.oscuro), 26, 30, 1.1, false)
		chispas(a, TEX.fragmento, ColorSequence.new(skin.c2, skin.c1), 12, 24, 0.8)
		U.soltar(a, 6, T.rayo, { Size = U.seq(5, 3), Transparency = U.seq(0, 1), Lifetime = NumberRange.new(0.12, 0.2), Rotation = NumberRange.new(0, 360),
			Speed = NumberRange.new(6, 14), SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top, Color = ColorSequence.new(skin.c1, skin.c2) })
		U.soltar(a, 4, T.vapor, { Size = U.seq(4, 9), Transparency = U.seq(0.3, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(90, 90), Color = ColorSequence.new(skin.oscuro), LightEmission = 0, LightInfluence = 0, Rotation = NumberRange.new(0, 360) })
	end,
}

-- ------------------------------------------------------------------ secuencia
function Salto.Play(personaje: Model, destino: Vector3, inicio: number?, origen: Vector3?, nombreSkin: string?): number
	local hrp = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return 0 end
	local skin = SKINS[nombreSkin or ""] or SKINS.Reloj
	local detalle = DETALLE[skin.nombre]
	local raiz = workspace:FindFirstChild("ZeroVFX") or Instance.new("Folder")
	raiz.Name = "ZeroVFX"; raiz.Parent = workspace
	local carpeta = Instance.new("Folder"); carpeta.Name = "Salto"; carpeta.Parent = raiz
	local escala = Salto.ESCALA
	Rafaga.ESCALA = escala
	local t0 = os.clock() - (if inicio then math.max(0, workspace:GetServerTimeNow() - inicio) else 0) / escala
	local AV = Salto.AVISO
	local soyYo = personaje == (Players.LocalPlayer and Players.LocalPlayer.Character)

	-- sellos: en el destino y uno pequeño a los pies del cazador
	local function sello(pos: Vector3, tam: number)
		local p = U.parte("Part", { Size = Vector3.new(0.1, 0.05, 0.1), Transparency = 1, CFrame = CFrame.new(pos + Vector3.new(0, 0.07, 0)) })
		local d = Instance.new("Decal"); d.Face = Enum.NormalId.Top; d.Texture = skin.sello; d.Transparency = 1; d.Parent = p
		p.Parent = carpeta
		return { p = p, d = d, tam = tam, pos = pos }
	end
	local selloDestino = sello(destino, 10)
	local base = origen or hrp.Position
	local pies = U.suelo(base, { personaje, raiz })
	local selloPies = sello(pies, 5.5)

	local quitarPose = U.hechizo(personaje, "HechizoLegendario")   -- animación de la E (ZeroMovement)
	U.sonido(hrp, Rafaga.SFX.aparece, 0.8, 1.3)

	-- hechizo: rayo de la mano al destino
	local mano = personaje:FindFirstChild("Right Arm") :: BasePart?
	local _, aMano = U.ancla(carpeta, mano and (mano.CFrame * Vector3.new(0, -1, 0)) or hrp.Position)
	local _, aPunta = U.ancla(carpeta, aMano.WorldPosition)
	local rayo = U.beam(carpeta, aMano, aPunta, T.estela, 0.6, skin.c2)
	rayo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	local brillo = U.emisor(aPunta, TEX.arena, { Rate = 60, Lifetime = NumberRange.new(0.25, 0.4), Size = U.seq(0.6, 0.1), Transparency = U.seq(0, 1),
		Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(skin.c1, skin.c2) })

	-- pilar de luz en el destino (crece durante el aviso; fogonazo al llegar)
	local _, pBase = U.ancla(carpeta, destino + Vector3.new(0, 0.2, 0))
	local _, pTope = U.ancla(carpeta, destino + Vector3.new(0, 24, 0))
	local pilar = U.beam(carpeta, pBase, pTope, T.estela, 0.1, skin.c2)
	pilar.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	local pilar2 = U.beam(carpeta, pBase, pTope, T.estela, 0.1, skin.c1)
	pilar2.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	local sube = U.emisor(pBase, skin.sprite, { Shape = Enum.ParticleEmitterShape.Disc, Rate = 18, Lifetime = NumberRange.new(0.5, 0.8),
		Size = U.seq(0.9, 0.2), Transparency = U.seq(0, 1), Speed = NumberRange.new(6, 11), EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200), Color = ColorSequence.new(skin.c1, skin.c2) })
	local avisoDetalle = detalle.aviso(skin, carpeta, destino)

	local saltado = false
	local tSalto = 0
	local conexion: RBXScriptConnection
	conexion = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) * escala
		if not carpeta.Parent then conexion:Disconnect(); quitarPose(); return end
		for _, s in { selloDestino, selloPies } do
			local abre = U.rebote(math.min(t / 0.22, 1)) * (1 - U.suave((t - AV - 0.5) / 0.45))
			local tam = math.max(s.tam * abre, 0.1)
			s.p.Size = Vector3.new(tam, 0.05, tam)
			s.p.CFrame = CFrame.new(s.pos + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, t * 2.5, 0)
			s.d.Transparency = 1 - math.clamp(abre, 0, 1) * 0.95
		end
		if mano and mano.Parent then aMano.WorldPosition = mano.CFrame * Vector3.new(0, -1, 0) end
		aPunta.WorldPosition = aMano.WorldPosition:Lerp(destino + Vector3.new(0, 2.5, 0), U.suave(t / 0.15))
		local apaga = 1 - U.suave((t - AV + 0.05) / 0.1)
		rayo.Width0 = 0.6 * apaga; rayo.Width1 = 0.9 * apaga
		-- pilar: crece hasta el salto, fogonazo ancho y se apaga
		local w = if not saltado then 0.3 + 1.6 * U.suave(t / AV) else 6 * (1 - U.suave((t - tSalto) / 0.35))
		pilar.Width0, pilar.Width1 = w, w * 0.6
		pilar2.Width0, pilar2.Width1 = w * 0.4, w * 0.25
		if not saltado then avisoDetalle(t, false) end

		if not saltado and t >= AV then
			saltado = true; tSalto = t
			brillo.Enabled = false; sube.Enabled = false
			avisoDetalle(t, true)
			local cfOrigen = hrp.CFrame
			local plano = Vector3.new(destino.X - cfOrigen.Position.X, 0, destino.Z - cfOrigen.Position.Z)
			local mira = if plano.Magnitude > 0.1 then plano.Unit else cfOrigen.LookVector
			local alto = cfOrigen.Position.Y - pies.Y
			local cfDestino = CFrame.lookAt(destino + Vector3.new(0, alto, 0), destino + Vector3.new(0, alto, 0) + mira)
			-- origen: silueta oscura que se deshace, tajos
			fantasma(personaje, carpeta, cfOrigen, skin.oscuro, 0.5, 0.15)
			deshacer(carpeta, cfOrigen, skin)
			local _, aO = U.ancla(carpeta, cfOrigen.Position)
			tajos(aO, skin, 5, 6); U.destello(aO, 7, skin.c1, 0.25)
			U.sonido(aO, Rafaga.SFX.disparo, 0.9, 1.25)
			-- camino: estela de cometa, siluetas y líneas de velocidad
			local dir = cfDestino.Position - cfOrigen.Position
			local _, c0 = U.ancla(carpeta, cfOrigen.Position)
			local _, c1 = U.ancla(carpeta, cfDestino.Position)
			local cometa = U.beam(carpeta, c0, c1, T.estela, 3.2, skin.c2)
			cometa.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) })
			local nucleo = U.beam(carpeta, c0, c1, T.estela, 1.1, skin.c1)
			TweenService:Create(cometa, TweenInfo.new(seg(0.3), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Width0 = 0, Width1 = 0 }):Play()
			TweenService:Create(nucleo, TweenInfo.new(seg(0.22), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Width0 = 0, Width1 = 0 }):Play()
			for i = 1, 3 do
				fantasma(personaje, carpeta, cfOrigen:Lerp(cfDestino, i / 4), skin.c1, 0.3 + 0.1 * i, 0.5 + 0.1 * i)
			end
			local lado = if dir.Magnitude > 0.1 then dir.Unit:Cross(Vector3.yAxis).Unit else Vector3.xAxis
			for _ = 1, 9 do
				local off = lado * math.random(-40, 40) / 10 + Vector3.new(0, math.random(-10, 40) / 10, 0)
				local _, a0 = U.ancla(carpeta, cfOrigen.Position + off - dir * 0.5)
				local _, a1 = U.ancla(carpeta, cfDestino.Position + off + dir * 0.5)
				local b = U.beam(carpeta, a0, a1, T.estela, 0.1 + math.random() * 0.2, skin.c1)
				b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.05), NumberSequenceKeypoint.new(1, 1) })
				task.delay(seg(0.1 + math.random() * 0.15), function() if b.Parent then b:Destroy() end end)
			end
			-- llegada: tajos grandes, onda, destello, luz, estallido de la skin y temblor
			local pD, aD = U.ancla(carpeta, cfDestino.Position)
			tajos(aD, skin, 4, 10); tajos(aD, skin, 6, 6)
			U.destello(aD, 12, skin.c1, 0.3); U.anilloLuz(aD, 1.5, 16, 0.4, skin.c2); U.luz(pD, skin.c2, 7, 28, 0.7)
			local aro = U.parte("Part", { Size = Vector3.new(2, 0.05, 2), CFrame = CFrame.new(destino + Vector3.new(0, 0.1, 0)), Transparency = 1 })
			local d = Instance.new("Decal"); d.Face = Enum.NormalId.Top; d.Texture = T.anillo; d.Color3 = skin.c2; d.Parent = aro
			aro.Parent = carpeta
			TweenService:Create(aro, TweenInfo.new(seg(0.45), Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(20, 0.05, 20) }):Play()
			TweenService:Create(d, TweenInfo.new(seg(0.55), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			detalle.llegada(skin, carpeta, destino, aD)
			U.sonido(aD, Rafaga.SFX.campanaFin, 1.1, 0.8)
			fantasma(personaje, carpeta, cfDestino, skin.c1, 0.3, 0.2)
			local yo = Players.LocalPlayer and Players.LocalPlayer.Character
			local raizYo = yo and yo:FindFirstChild("HumanoidRootPart") :: BasePart?
			if soyYo then
				personaje:PivotTo(cfDestino)                                 -- se ve al instante en mi pantalla; el servidor lo confirma
				hrp.AssemblyLinearVelocity = Vector3.zero
				pantallaSalto(skin)
				temblor(1.2, 0.25)
			elseif raizYo and (raizYo.Position - destino).Magnitude < 30 then
				temblor(1.6 * (1 - (raizYo.Position - destino).Magnitude / 30), 0.3)
			end
		end
		if t >= AV + 1.0 then conexion:Disconnect(); quitarPose(); carpeta:Destroy() end
	end)
	task.delay((AV + 2.2) / escala, function()
		if conexion.Connected then conexion:Disconnect() end
		quitarPose()
		if carpeta.Parent then carpeta:Destroy() end
	end)
	return AV + 1.0
end

-- ------------------------------------------------------------------ aturdido (0,5 s): sello pequeño girando y chispas
function Salto.aturdido(personaje: Model, nombreSkin: string?, dura: number)
	local skin = SKINS[nombreSkin or ""] or SKINS.Reloj
	local cabeza = personaje:FindFirstChild("Head") :: BasePart?
	if not cabeza then return end
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromScale(2.4, 2.4); bb.StudsOffset = Vector3.new(0, 2, 0); bb.LightInfluence = 0
	bb.Adornee = cabeza; bb.Parent = cabeza
	local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Image = skin.sello; im.Size = UDim2.fromScale(1, 1); im.Parent = bb
	local a = Instance.new("Attachment"); a.Parent = cabeza
	chispas(a, skin.sprite, ColorSequence.new(skin.c1, skin.c2), 10, 6, 0.7)
	local t0 = os.clock()
	local c: RBXScriptConnection
	c = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > dura or not bb.Parent then c:Disconnect(); bb:Destroy(); Debris:AddItem(a, 1); return end
		im.Rotation = -t * 720
		im.ImageTransparency = math.clamp((t - dura + 0.15) / 0.15, 0, 1)
	end)
end

return Salto
