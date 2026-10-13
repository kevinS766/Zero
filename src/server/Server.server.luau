--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local RoundService = require(Server:WaitForChild("Services"):WaitForChild("RoundService"))
local PlayerStateService = require(Server:WaitForChild("Services"):WaitForChild("PlayerStateService"))
local CombatService = require(Server:WaitForChild("Services"):WaitForChild("CombatService"))
local DashService = require(Server:WaitForChild("Services"):WaitForChild("DashService"))
local HunterClassService = require(Server:WaitForChild("Services"):WaitForChild("HunterClassService"))
local MapService = require(Server:WaitForChild("Services"):WaitForChild("MapService"))
local DebugCommandService = require(Server:WaitForChild("Services"):WaitForChild("DebugCommandService"))

-- Inicializar servicios en orden de dependencia cruzada
MapService.init()
CombatService.init(PlayerStateService, RoundService)
PlayerStateService.init(RoundService, CombatService)
DashService.init(RoundService, PlayerStateService, HunterClassService)
HunterClassService.init(RoundService, PlayerStateService)
local DataService = require(Server.Services.DataService)
local LeaderboardService = require(Server.Services.LeaderboardService)
require(Server.Services.BotGameplayAdapter)
local BotService = require(Server.Services.BotService)
RoundService.init(PlayerStateService, HunterClassService, BotService, MapService)
DebugCommandService.init(RoundService, PlayerStateService, HunterClassService)
LeaderboardService.init(DataService)

print("[Server] Servidor de Zero iniciado con éxito (Fases 1 a 8 activas con MapService, bots y Leaderboards).")

