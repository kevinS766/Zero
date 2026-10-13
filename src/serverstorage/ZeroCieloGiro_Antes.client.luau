-- ZeroCieloGiro (LocalScript en StarterPlayerScripts): el cielo (Lighting.Sky) gira muy despacio sobre el eje vertical
-- para que las nubes pintadas se muevan. Solo en el cliente y sobre el Sky que haya en cada momento (si un mapa pone el
-- suyo, también gira). El sol de Roblox no se mueve con él. Cielos hechos en zero-maps/cielos (cielo.py).
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local VUELTA = 1200                                    -- segundos por vuelta (20 min)

RunService.Heartbeat:Connect(function()
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then sky.SkyboxOrientation = Vector3.new(0, (os.clock() * 360 / VUELTA) % 360, 0) end
end)
