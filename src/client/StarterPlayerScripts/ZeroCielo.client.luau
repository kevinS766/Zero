-- ZeroCielo (LocalScript en StarterPlayerScripts): el cielo de cada zona y su giro lento, solo en el cliente.
--  * Cada script de mapa (ZeroLobbyFX, ZeroIslaFX, ZeroCiudadFX, ZeroCalabazaFX) pone Lighting.ZeroZona cuando su zona
--    toma la luz; aquí se cambian las 6 caras del Sky según esa zona. Sin zona (o Lobby) = el Sky de Studio (lobby_dia).
--  * Los cielos con gira = true giran sobre el eje vertical (una vuelta cada 20 min); los demás se quedan quietos para
--    que lo que hay en el horizonte (islotes, colinas, castillo) no se deslice. El sol de Roblox no se mueve con el cielo.
-- Cielos hechos en zero-maps/cielos (cielo.py); esta tabla la genera cielos/roblox/gen_zerocielo.py desde los ids.json.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local VUELTA = 1200                                    -- segundos por vuelta
local CARAS = { "SkyboxFt", "SkyboxBk", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SkyboxDn" }
local CIELOS = {
	Isla = { gira = false, SkyboxFt = "rbxassetid://123889658345377", SkyboxBk = "rbxassetid://108271291945613", SkyboxLf = "rbxassetid://130152633783488", SkyboxRt = "rbxassetid://131830928242620", SkyboxUp = "rbxassetid://86096440142753", SkyboxDn = "rbxassetid://112475757816320" },   -- isla_tropical
	Ciudad = { gira = true, SkyboxFt = "rbxassetid://94579479256398", SkyboxBk = "rbxassetid://102336592942699", SkyboxLf = "rbxassetid://118282045406038", SkyboxRt = "rbxassetid://77253286246794", SkyboxUp = "rbxassetid://108264510225514", SkyboxDn = "rbxassetid://101062350130547" },   -- ciudad_pastel
	Calabaza = { gira = false, SkyboxFt = "rbxassetid://127540863665720", SkyboxBk = "rbxassetid://121993629481848", SkyboxLf = "rbxassetid://136487067258137", SkyboxRt = "rbxassetid://90219868136691", SkyboxUp = "rbxassetid://111403828005703", SkyboxDn = "rbxassetid://108846354110512" },   -- calabaza_halloween
}

local sky = Lighting:FindFirstChildOfClass("Sky") or Lighting:WaitForChild("Sky")
local base = { gira = true }
for _, k in CARAS do base[k] = sky[k] end
local actual
local function poner(zona)
	local c = CIELOS[zona or ""] or base
	if c == actual then return end
	actual = c
	for _, k in CARAS do sky[k] = c[k] end
	if not c.gira then sky.SkyboxOrientation = Vector3.zero end
end
task.spawn(function()                                  -- precarga: al entrar en un mapa el cielo cambia al instante
	local ids = {}
	for _, c in CIELOS do for _, k in CARAS do table.insert(ids, c[k]) end end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
end)
poner(Lighting:GetAttribute("ZeroZona"))
Lighting:GetAttributeChangedSignal("ZeroZona"):Connect(function() poner(Lighting:GetAttribute("ZeroZona")) end)

RunService.Heartbeat:Connect(function()
	if actual.gira then sky.SkyboxOrientation = Vector3.new(0, (os.clock() * 360 / VUELTA) % 360, 0) end
end)
