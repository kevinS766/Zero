--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkEvents = {}

-- Obtiene o crea la carpeta NetworkEvents en ReplicatedStorage para asegurar sincronización
local function getNetworkFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("NetworkEvents")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "NetworkEvents"
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

-- Obtiene o crea un RemoteEvent por nombre
function NetworkEvents.getRemoteEvent(name: string): RemoteEvent
	local folder = getNetworkFolder()
	local event = folder:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	return event :: RemoteEvent
end

-- Obtiene o crea un RemoteFunction por nombre
function NetworkEvents.getRemoteFunction(name: string): RemoteFunction
	local folder = getNetworkFolder()
	local fn = folder:FindFirstChild(name)
	if not fn then
		fn = Instance.new("RemoteFunction")
		fn.Name = name
		fn.Parent = folder
	end
	return fn :: RemoteFunction
end

return NetworkEvents
