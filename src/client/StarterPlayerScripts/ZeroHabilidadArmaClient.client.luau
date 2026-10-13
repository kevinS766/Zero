-- ZeroHabilidadArmaClient (LocalScript, StarterPlayerScripts): tecla E (mando: Y; móvil: botón) del cazador = habilidad
-- de la rareza del arma equipada (ZeroHabilidadesConfig). Pide el ataque apuntando al ratón (centro de la pantalla en
-- móvil/mando), pone el botón en el HUD encima del de la clase con su cuenta atrás y reproduce los efectos que manda
-- ZeroHabilidadArmaServer para todos (ataque y mareo de los aturdidos).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("ZeroHabilidadArma") :: RemoteEvent
local Habilidades = require(ReplicatedStorage:WaitForChild("ZeroHabilidadesConfig"))
local VFX = ReplicatedStorage:WaitForChild("VFX")

-- precarga texturas y sonidos de todas las habilidades (si no, la primera vez salen sellos vacíos y beams macizos)
task.spawn(function()
	local ids = {}
	for _, m in VFX:GetChildren() do
		local ok, M = pcall(require, m)
		if ok and type(M) == "table" then
			for _, tabla in { M.TEX, M.SFX } do
				if type(tabla) == "table" then for _, id in tabla do table.insert(ids, id) end end
			end
		end
	end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
end)

local listoEn = 0
local cooldownTotal = 1

local function modulo(nombre: string): any
	local m = VFX:FindFirstChild(nombre)
	return m and require(m)
end

local function puede(): (any, string?)
	local prueba = player:GetAttribute("ZeroPruebas") == true          -- arena de pruebas de admins: vale sin ser cazador
	if (player:GetAttribute("Role") ~= "Hunter" and not prueba) or player:GetAttribute("Status") == "Frozen" then return nil, nil end
	return Habilidades.de(Habilidades.armaDe(player))
end

local function apuntado(): Vector3
	local cam = workspace.CurrentCamera
	local pos = UserInputService:GetMouseLocation()
	if UserInputService.TouchEnabled or UserInputService.GamepadEnabled or not UserInputService.MouseEnabled then pos = cam.ViewportSize / 2 end
	local rayo = cam:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(rayo.Origin, rayo.Direction * 300, params)
	return if hit then hit.Position else rayo.Origin + rayo.Direction * 60
end

-- Común (Bola): pulsar empieza a cargar, soltar lanza
local cargando = false
local function pulsar()
	local hab = puede()
	if not hab or os.clock() < listoEn then return end
	if hab.modulo == "Bola" then
		if cargando then return end
		cargando = true
		remote:FireServer({ accion = "cargar" })
		return
	end
	remote:FireServer({ objetivo = apuntado() })
end
local function soltar()
	if not cargando then return end
	cargando = false
	remote:FireServer({ accion = "soltar", objetivo = apuntado() })
end

UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonY then pulsar() end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonY then soltar() end
end)

remote.OnClientEvent:Connect(function(d)
	if d.kind == "BolaCarga" then
		local m = modulo("Bola")
		if m and d.caster and d.caster.Parent then m.cargar(d.caster, d.skin, d.inicio, d.carga) end
		return
	end
	if d.kind == "BolaCancelar" then
		local m = modulo("Bola")
		if m and d.caster then m.cancelar(d.caster) end
		if d.caster == player.Character then cargando = false end
		return
	end
	if d.kind == "Lentos" then
		local m = modulo(d.modulo)
		for _, v in d.victimas do if v.Parent then m.lento(v, d.skin, d.dur) end end
		if d.caster == player.Character and m.acierto then m.acierto(#d.victimas, d.skin) end
		return
	end
	if d.kind == "Cegados" then
		local m = modulo(d.modulo)
		for _, v in d.victimas do if v.Parent then m.cegado(v, d.skin, d.dur, v == player.Character) end end
		return
	end
	if d.kind == "Aturdidos" then
		local m = modulo(d.modulo)
		for _, v in d.victimas do if v.Parent then m.aturdido(v, d.skin, d.dur) end end
		return
	end
	local m = modulo(d.kind)
	if not m or not d.caster or not d.caster.Parent then return end
	if d.caster == player.Character then listoEn = os.clock() + d.cooldown; cooldownTotal = d.cooldown end
	if d.caster == player.Character then cargando = false end
	m.Play(d.caster, d.objetivo, d.inicio, d.origen, d.skin, d.duracion, d)
end)

-- ------------------------------------------------------------------ botón en el HUD (copia del de la clase)
local ICONO = { Tormenta = "rayo", Estelar = "estrella", Te = "gota" }   -- Ráfaga (el Vórtice usa skin.sprite)
task.spawn(function()
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("ZeroUI"):WaitForChild("HUD")
	local skill = hud:WaitForChild("Skill") :: GuiButton
	local b = skill:Clone() :: any
	b.Name = "SkillArma"; b.Visible = false
	for _, c in b:GetDescendants() do if c:IsA("LuaSourceContainer") then c:Destroy() end end
	local carga = Instance.new("Frame")
	carga.Name = "Carga"; carga.BackgroundColor3 = Color3.new(0, 0, 0); carga.BackgroundTransparency = 0.45; carga.BorderSizePixel = 0
	carga.ZIndex = 20; carga.Parent = b
	local esquina = skill:FindFirstChildOfClass("UICorner"); if esquina then esquina:Clone().Parent = carga end
	b.Parent = hud
	-- el botón se mantiene pulsado para cargar la Bola (Común); para el resto basta con tocarlo
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then pulsar() end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then soltar() end
	end)
	local texto = b:FindFirstChild("ButtonText")
	local icono = b:FindFirstChild("Icon_dash")
	RunService.RenderStepped:Connect(function()
		local hab, skin = puede()
		b.Visible = hab ~= nil and (skill.Visible or player:GetAttribute("ZeroPruebas") == true)
		if not b.Visible then return end
		b.Size = skill.Size
		b.Position = skill.Position - UDim2.fromOffset(0, skill.AbsoluteSize.Y + 10)
		local falta = listoEn - os.clock()
		local t = if falta > 0 then string.format("E  •  %ds", math.ceil(falta)) elseif cargando then "E  •  ¡SUELTA!" else "E  •  " .. hab.nombre
		b.Text = t; if texto then texto.Text = t end
		carga.Size = UDim2.fromScale(math.clamp(falta / cooldownTotal, 0, 1), 1)
		carga.Visible = falta > 0
		if icono then
			local M = modulo(hab.modulo)
			local s = M and M.SKINS and M.SKINS[skin]
			if s then
				icono.Image = s.sello or s.sprite or M.TEX[ICONO[skin]] or icono.Image
				icono.ImageColor3 = if s.sello then Color3.new(1, 1, 1) else s.c2   -- los sellos ya van en color
			end
		end
	end)
end)
