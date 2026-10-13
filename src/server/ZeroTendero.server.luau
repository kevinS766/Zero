-- ZeroTendero (Script, ServerScriptService): prepara para cada jugador un tendero con la skin de uno de sus amigos.
-- Crear el modelo desde una HumanoidDescription solo se puede en el servidor, así que aquí se crea en
-- ReplicatedStorage.ZeroTenderos.<UserId> y el cliente de ese jugador lo clona tras el mostrador (solo lo ve él).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensure(name: string): Folder
	local f = ReplicatedStorage:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name; f.Parent = ReplicatedStorage
	return f :: Folder
end
local folder = ensure("ZeroTenderos")          -- tendero de la tienda
local misioneros = ensure("ZeroMisioneros")    -- NPC de misiones (otro amigo distinto)

local DEFAULT_ID = 156          -- si el jugador no tiene amigos: avatar clásico de Roblox

-- Amigos candidatos (conectados primero, luego el resto, cada grupo al azar), sin cuentas eliminadas
local function candidates(player: Player, exclude: number?): { { id: number, name: string } }
	local ok, pages = pcall(function() return Players:GetFriendsAsync(player.UserId) end)
	local online, rest = {}, {}
	local okPage, items = pcall(function() return ok and pages and pages:GetCurrentPage() or {} end)
	for _, f in (okPage and items or {}) do
		local name = (f.DisplayName ~= "" and f.DisplayName) or f.Username or ""
		local lower = string.lower((f.Username or "") .. " " .. name)
		local deleted = lower:find("deleted") or lower:find("eliminad") or lower:find("^%[")
		if f.Id ~= exclude and not deleted then
			table.insert(f.IsOnline and online or rest, { id = f.Id, name = name })
		end
	end
	local function shuffle(t) for k = #t, 2, -1 do local r = math.random(1, k); t[k], t[r] = t[r], t[k] end end
	shuffle(online); shuffle(rest)
	for _, f in rest do table.insert(online, f) end
	return online
end

-- Avatar vacío (cuenta borrada o moderada): sin ropa, cara ni accesorios
local function vacio(desc: HumanoidDescription): boolean
	return desc.Shirt == 0 and desc.Pants == 0 and desc.GraphicTShirt == 0 and desc.Face == 0 and #desc:GetAccessories(true) == 0
end

local function build(player: Player, dest: Folder, exclude: number?): number?
	local list = candidates(player, exclude)
	table.insert(list, { id = DEFAULT_ID, name = "Tendero" })            -- último recurso: avatar clásico
	local friendId, friendName, desc
	for k = 1, math.min(#list, 6) do                                     -- prueba hasta 6 amigos
		local c = list[k]
		local okDesc, d = pcall(function() return Players:GetHumanoidDescriptionFromUserId(c.id) end)
		if okDesc and d and (c.id == DEFAULT_ID or not vacio(d)) then friendId, friendName, desc = c.id, c.name, d; break end
	end
	if not desc then return nil end
	for _, field in { "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation", "MoodAnimation" } do
		desc[field] = 0
	end
	local okModel, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6) end)
	if not okModel or not model or player.Parent ~= Players then return nil end
	model.Name = tostring(player.UserId)
	model:SetAttribute("NombreAmigo", friendName)
	model:SetAttribute("AmigoId", friendId)
	for _, sc in model:GetDescendants() do if sc:IsA("LuaSourceContainer") then sc:Destroy() end end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = hum end
	end
	local old = dest:FindFirstChild(model.Name)
	if old then old:Destroy() end
	model.Parent = dest
	return friendId
end

local function buildAll(player: Player)
	local tendero = build(player, folder)
	build(player, misioneros, tendero)        -- el de misiones es otro amigo (si hay más de uno)
end

Players.PlayerAdded:Connect(function(p) task.spawn(buildAll, p) end)
Players.PlayerRemoving:Connect(function(p)
	for _, f in { folder, misioneros } do
		local m = f:FindFirstChild(tostring(p.UserId))
		if m then m:Destroy() end
	end
end)
for _, p in Players:GetPlayers() do task.spawn(buildAll, p) end
