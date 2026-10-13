-- ZeroVictoriaClient (LocalScript, StarterPlayerScripts): clímax de fin de ronda (zero-todo, punto 1.5).
-- Al pasar a ROUND_END (RoundService publica RoundWinner y el ObjectValue ReplicatedStorage.ZeroRondaFoco con el personaje
-- a enfocar) se ven ~4,5 s de: franjas de cine, banner "¡GANA EL CAZADOR!" / "¡GANAN LOS CORREDORES!", tu resultado
-- (VICTORIA / DERROTA), cámara que gira despacio alrededor del ganador y fanfarria. El servidor espera CELEBRACION
-- segundos antes de devolver a los jugadores al lobby. La cámara solo se mueve a quien jugó la ronda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local DURA = 4.6
local FUENTE = Enum.Font.FredokaOne
local TINTA = Color3.fromRGB(20, 14, 34)
local COLOR = { Hunter = Color3.fromRGB(255, 70, 90), Runner = Color3.fromRGB(80, 210, 255) }
local SFX = { victoria = { "rbxassetid://1836473422", 0.7 }, derrota = { "rbxassetid://9045918379", 0.5 }, golpe = { "rbxassetid://128831960761599", 0.6 } }

local gui = Instance.new("ScreenGui")
gui.Name = "ZeroVictoria"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 50; gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function tw(o: Instance, t: number, props: { [string]: any }, estilo: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local x = TweenService:Create(o, TweenInfo.new(t, estilo or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local function sonar(s: { any })
	local snd = Instance.new("Sound"); snd.SoundId = s[1]; snd.Volume = s[2]; snd.Parent = gui
	snd:Play(); snd.Ended:Once(function() snd:Destroy() end)
	task.delay(12, function() if snd.Parent then snd:Destroy() end end)
end

local function texto(padre: Instance, t: string, pos: UDim2, alto: number, color: Color3, grosor: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5); l.Position = pos; l.Size = UDim2.new(0.9, 0, alto, 0); l.BackgroundTransparency = 1
	l.Font = FUENTE; l.Text = t; l.TextScaled = true; l.TextColor3 = color
	local s = Instance.new("UIStroke"); s.Thickness = grosor; s.Color = TINTA; s.Parent = l
	l.Parent = padre
	return l
end

local function nombreDe(char: Instance?): string
	if not char then return "" end
	local p = Players:GetPlayerFromCharacter(char)
	if p then return p.DisplayName end
	return (string.gsub(char.Name, " %[BOT%]", ""))
end

local enCurso = 0
local function celebrar()
	enCurso += 1
	local mio = enCurso
	-- RoundWinner y el foco llegan con el cambio de estado; se esperan un momento por si van detrás
	local ganador, t0 = nil, os.clock()
	repeat
		ganador = ReplicatedStorage:GetAttribute("RoundWinner")
		if ganador then break end
		task.wait(0.05)
	until os.clock() - t0 > 0.6
	if not ganador or enCurso ~= mio then return end
	local focoV = ReplicatedStorage:FindFirstChild("ZeroRondaFoco") :: ObjectValue?
	local foco = focoV and focoV.Value :: Model?
	local miRol = player:GetAttribute("Role")
	local jugo = miRol == "Hunter" or miRol == "Runner"
	local color = COLOR[ganador] or Color3.new(1, 1, 1)

	gui:ClearAllChildren()
	gui.Enabled = true
	local hud = player.PlayerGui:FindFirstChild("ZeroUI") :: ScreenGui?   -- el HUD de botones se esconde durante el clímax
	if hud then hud.Enabled = false end
	-- franjas de cine
	local barras = {}
	for i, y in { 0, 1 } do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, y); b.Position = UDim2.fromScale(0, y); b.Size = UDim2.new(1, 0, 0, 0)
		b.BackgroundColor3 = Color3.new(0, 0, 0); b.BorderSizePixel = 0; b.Parent = gui
		tw(b, 0.45, { Size = UDim2.fromScale(1, 0.11) })
		barras[i] = b
	end
	-- destello del color del ganador
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1); flash.BackgroundColor3 = color; flash.BackgroundTransparency = 0.55; flash.BorderSizePixel = 0; flash.Parent = gui
	tw(flash, 0.6, { BackgroundTransparency = 1 })
	-- banner
	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0.5); banner.Position = UDim2.fromScale(0.5, 0.3); banner.Size = UDim2.fromScale(1, 0.26)
	banner.BackgroundTransparency = 1; banner.Parent = gui
	local escala = Instance.new("UIScale"); escala.Scale = 2.2; escala.Parent = banner
	local cinta = Instance.new("Frame")
	cinta.AnchorPoint = Vector2.new(0.5, 0.5); cinta.Position = UDim2.fromScale(0.5, 0.5); cinta.Size = UDim2.fromScale(0, 0.62)
	cinta.BackgroundColor3 = color; cinta.BorderSizePixel = 0; cinta.Rotation = -2; cinta.Parent = banner
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = cinta
	tw(cinta, 0.35, { Size = UDim2.fromScale(1, 0.62) }, Enum.EasingStyle.Quart)
	local titulo = texto(banner, if ganador == "Hunter" then "¡GANA EL CAZADOR!" else "¡GANAN LOS CORREDORES!", UDim2.fromScale(0.5, 0.45), 0.62, Color3.new(1, 1, 1), 5)
	titulo.Rotation = -2
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(Color3.new(1, 1, 1), color:Lerp(Color3.new(1, 1, 1), 0.55)); tg.Rotation = 90; tg.Parent = titulo
	local sub = ""
	if ganador == "Hunter" and foco then sub = nombreDe(foco) .. " congeló a todos"
	elseif ganador == "Runner" then sub = "¡Sobrevivieron hasta el final!" end
	local subt = texto(banner, sub, UDim2.fromScale(0.5, 0.92), 0.2, Color3.new(1, 1, 1), 3)
	escala.Scale = 2.2
	tw(escala, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	-- tu resultado
	local res: TextLabel? = nil
	if jugo then
		local gane = miRol == ganador
		res = texto(gui, if gane then "VICTORIA" else "DERROTA", UDim2.fromScale(0.5, 0.135), 0.07,
			if gane then Color3.fromRGB(255, 214, 74) else Color3.fromRGB(190, 190, 205), 4)
		res.TextTransparency = 1
		task.delay(0.35, function() if res then tw(res, 0.3, { TextTransparency = 0 }) end end)
		sonar(if gane then SFX.victoria else SFX.derrota)
	else
		sonar(SFX.victoria)
	end
	sonar(SFX.golpe)

	-- cámara: gira despacio alrededor del ganador (solo a quien jugó la ronda)
	local cam = workspace.CurrentCamera
	local raiz = foco and foco:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camara = jugo and raiz ~= nil
	if camara then
		local angulo0 = math.atan2(raiz.CFrame.LookVector.X, raiz.CFrame.LookVector.Z)
		local inicio = os.clock()
		RunService:BindToRenderStep("ZeroVictoriaCam", Enum.RenderPriority.Camera.Value + 10, function()
			if not raiz.Parent then return end
			local t = os.clock() - inicio
			local a = angulo0 + 0.5 + t * 0.35
			local dist = 13 - math.min(t, 3) * 1.2
			local centro = raiz.Position + Vector3.new(0, 1.5, 0)
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(centro + Vector3.new(math.sin(a) * dist, 3.5 - t * 0.3, math.cos(a) * dist), centro)
		end)
	end

	task.wait(DURA)
	if enCurso ~= mio then if hud then hud.Enabled = true end; return end
	-- salida
	tw(escala, 0.3, { Scale = 0.8 }); tw(titulo, 0.3, { TextTransparency = 1 }); tw(subt, 0.3, { TextTransparency = 1 })
	tw(cinta, 0.3, { BackgroundTransparency = 1 })
	if res then tw(res, 0.3, { TextTransparency = 1 }) end
	for _, b in barras do tw(b, 0.4, { Size = UDim2.new(1, 0, 0, 0) }) end
	if camara then
		RunService:UnbindFromRenderStep("ZeroVictoriaCam")
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		cam.CameraType = Enum.CameraType.Custom
		if h then cam.CameraSubject = h end
	end
	if hud then hud.Enabled = true end
	task.wait(0.45)
	if enCurso == mio then gui.Enabled = false; gui:ClearAllChildren() end
end

local function estado()
	if ReplicatedStorage:GetAttribute("RoundState") == "ROUND_END" then task.spawn(celebrar) end
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(estado)
