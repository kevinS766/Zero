-- VFX de gameplay. Solo escucha señales que el servidor ya replica (atributos, la carpeta de trampas, AbilityEffect),
-- así que no toca ningún servicio. Efectos en ReplicatedStorage.Assets.VFX (ver VFX_CATALOG.md).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX")
local NetworkEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"):WaitForChild("NetworkEvents"))

local ICE = ColorSequence.new(Color3.fromRGB(170, 240, 255), Color3.fromRGB(0, 200, 255))
local SHADOW = ColorSequence.new(Color3.fromRGB(40, 20, 60), Color3.fromRGB(0, 0, 0))

local folder = Instance.new("Folder")
folder.Name = "ZeroVFX"
folder.Parent = workspace

local function asset(path)
	local inst = VFX
	for seg in path:gmatch("[^/]+") do
		inst = inst:FindFirstChild(seg)
		if not inst then warn("[ZeroVFX] Falta", path) return nil end
	end
	return inst
end

-- Efecto de partículas del pack: emite una ráfaga según los atributos EmitCount/EmitDelay/EmitDuration.
local function burst(path, cframe, opts)
	local source = asset(path)
	if not source then return end
	opts = opts or {}
	local part = source:Clone()
	part.Transparency, part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = 1, true, false, false, false
	part.CFrame = cframe
	local longest = 0
	for _, e in part:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			e.Enabled = false
			if opts.color then e.Color = opts.color end
			if opts.scale then
				local k = {}
				for _, kp in e.Size.Keypoints do table.insert(k, NumberSequenceKeypoint.new(kp.Time, kp.Value * opts.scale, kp.Envelope * opts.scale)) end
				e.Size = NumberSequence.new(k)
			end
			local delay = e:GetAttribute("EmitDelay") or 0
			local count = e:GetAttribute("EmitCount") or math.ceil(e.Rate * (e:GetAttribute("EmitDuration") or 0.2))
			longest = math.max(longest, delay + e.Lifetime.Max)
			task.delay(delay, function() if e.Parent then e:Emit(math.max(count, 1)) end end)
		end
	end
	part.Parent = folder
	Debris:AddItem(part, longest + 0.5)
end

-- Textura suelta del pack (aro/vórtice) como onda plana que se expande y desaparece.
local function ring(path, position, fromSize, toSize, duration, color)
	local source = asset(path)
	local decal = source and source:FindFirstChildOfClass("Decal")
	if not decal then return end
	local part = Instance.new("Part")
	part.Transparency, part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = 1, true, false, false, false
	part.Size = Vector3.new(fromSize, 0.05, fromSize)
	part.CFrame = CFrame.new(position)
	local d = decal:Clone()
	d.Face = Enum.NormalId.Top
	if color then d.Color3 = color end
	d.Parent = part
	part.Parent = folder
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, info, { Size = Vector3.new(toSize, 0.05, toSize) }):Play()
	TweenService:Create(d, info, { Transparency = 1 }):Play()
	Debris:AddItem(part, duration + 0.1)
end

local function feet(root) return root.Position - Vector3.new(0, 2.9, 0) end

local function onFrozen(character, root)
	burst("Anime/Slash-Impact-01", root.CFrame)
	burst("Anime/Splash-01", root.CFrame, { color = ICE })
	burst("Anime/Crack-01", CFrame.new(feet(root)), { color = ICE })
	-- Trampa que acaba de desaparecer debajo del jugador: activada, no caducada.
	character:SetAttribute("ZeroVFXFrozenAt", os.clock())
end

local function onRescued(root)
	burst("Anime/Shield-Break-01", root.CFrame, { color = ICE })
	ring("light ring", feet(root) + Vector3.new(0, 0.2, 0), 2, 14, 0.5, Color3.fromRGB(150, 235, 255))
end

local hooked = setmetatable({}, { __mode = "k" })
local function hookCharacter(character)
	if hooked[character] then return end
	hooked[character] = true
	local status = character:GetAttribute("Status")
	local lastDash = 0

	character:GetAttributeChangedSignal("Status"):Connect(function()
		local new = character:GetAttribute("Status")
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and new == "Frozen" and status ~= "Frozen" then onFrozen(character, root)
		elseif root and new == "Active" and status == "Frozen" then onRescued(root) end
		status = new
	end)

	-- El servidor sube ZeroDashSerial para todos; el dueño lo sube otra vez en local, de ahí el debounce.
	character:GetAttributeChangedSignal("ZeroDashSerial"):Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		local dir = character:GetAttribute("ZeroDashDirection")
		if not root or typeof(dir) ~= "Vector3" or dir.Magnitude < 0.1 or os.clock() - lastDash < 0.3 then return end
		lastDash = os.clock()
		local pos = root.Position
		burst("Anime/Wind-01", CFrame.lookAt(pos, pos - dir))
		burst("Anime/Smoke-01", CFrame.new(feet(root)), { scale = 0.6 })
	end)

	-- Acechador: el servidor pone el cuerpo a Transparency 1 y luego lo restaura.
	local head = character:WaitForChild("Head", 10)
	if head then
		local hidden = head.Transparency >= 1
		head:GetPropertyChangedSignal("Transparency"):Connect(function()
			local now = head.Transparency >= 1
			if now == hidden then return end
			hidden = now
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and character:GetAttribute("Role") == "Hunter" then
				burst("Anime/Smoke-01", root.CFrame, { color = SHADOW, scale = 1.4 })
			end
		end)
	end
end

-- Trampas del Trampero (Workspace.ZeroRuntime.Traps).
local function onTrap(trap)
	local pos = trap.Position
	ring("circle thing", pos + Vector3.new(0, 0.1, 0), 1, 7, 0.6, Color3.fromRGB(0, 230, 255))
	trap.AncestryChanged:Connect(function(_, parent)
		if parent then return end
		-- Solo estalla si alguien se congeló justo encima en este instante.
		for character in hooked do
			local root = character.Parent and character:FindFirstChild("HumanoidRootPart")
			local at = character:GetAttribute("ZeroVFXFrozenAt")
			if root and at and os.clock() - at < 0.5 and (root.Position - pos).Magnitude < 8 then
				burst("Big/Big-Crack-01", CFrame.new(pos), { color = ICE })
				return
			end
		end
	end)
end

local function onDescendant(d)
	if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.spawn(hookCharacter, d.Parent)
	elseif d:IsA("BasePart") and d.Parent and d.Parent.Name == "Traps" and d.Parent.Parent and d.Parent.Parent.Name == "ZeroRuntime" then onTrap(d) end
end
workspace.DescendantAdded:Connect(onDescendant)
for _, d in workspace:GetDescendants() do onDescendant(d) end

-- Rastreador: solo el cazador recibe AbilityEffect, así que la onda la ve él.
NetworkEvents.getRemoteEvent("AbilityEffect").OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or data.kind ~= "TrackerReveal" then return end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	ring("vortex", feet(root) + Vector3.new(0, 0.2, 0), 2, 60, 0.9, Color3.fromRGB(255, 200, 80))
	ring("light ring", feet(root) + Vector3.new(0, 0.3, 0), 2, 40, 0.7, Color3.fromRGB(255, 230, 150))
end)
