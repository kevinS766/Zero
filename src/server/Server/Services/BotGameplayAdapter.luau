local Services = script.Parent
local PlayerState = require(Services.PlayerStateService)
local Combat = require(Services.CombatService)
local Dash = require(Services.DashService)
local Classes = require(Services.HunterClassService)
local Round = require(Services.RoundService)
local Adapter = {}

function Adapter.register(actor)
	return PlayerState.registerBot(actor)
end
function Adapter.unregister(actor)
	PlayerState.unregisterBot(actor)
	Combat.forgetActor(actor)
	Dash.forgetActor(actor)
	Classes.forgetActor(actor)
	Round.onActorRemoved(actor)
end
function Adapter.spawnRunner(actor)
	PlayerState.setRole(actor,"Runner")
	Round.sendToMap(actor,"RUNNER")
	return true
end
function Adapter.getActors() return PlayerState.getActors() end
function Adapter.requestAttack(actor, _target) return Combat.requestAttack(actor) == true end
function Adapter.requestRescue(actor, target) return PlayerState.requestRescue(actor, target) == true end
function Adapter.requestDash(actor, direction) return Dash.requestDash(actor, direction) == true end

return Adapter
