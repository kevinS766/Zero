--!strict
local HunterClasses = require(script.Parent.Parent.Constants.HunterClasses)

export type HunterClassConfigEntry = {
	DisplayName: string,
	Description: string,
	Cooldown: number,
	RevealDuration: number?,
	Duration: number?,
	WalkSpeed: number?,
	MaxTraps: number?,
	Lifetime: number?,
	TriggerRadius: number?,
	PlaceMaxDrop: number?,
	Range: number?,
	Radius: number?,
}

local HunterClassConfig = {
	DEFAULT_CLASS = HunterClasses.TRACKER :: string,
	ORDER = { HunterClasses.TRACKER, HunterClasses.STALKER, HunterClasses.TRAPPER } :: { string },
	BASE_WALK_SPEED = 16,
	COOLDOWN_LATENCY_TOLERANCE = 0.25,
	DEBUG_ROLE_VISUALS = false,

	Classes = {
		[HunterClasses.TRACKER] = {
			DisplayName = "Tracker",
			Description = "Revela siluetas de Runners durante 4s",
			Cooldown = 25.0,
			RevealDuration = 4.0,
		},
		[HunterClasses.STALKER] = {
			DisplayName = "Stalker",
			Description = "Invisibilidad total y velocidad aumentada durante 5s",
			Cooldown = 20.0,
			Duration = 5.0,
			WalkSpeed = 24.0,
		},
		[HunterClasses.TRAPPER] = {
			DisplayName = "Trapper",
			Description = "Coloca una trampa en el suelo que congela al activarse",
			Cooldown = 15.0,
			MaxTraps = 2,
			Lifetime = 45.0,
			TriggerRadius = 4.0,
			PlaceMaxDrop = 8.0,
		},
	} :: { [string]: HunterClassConfigEntry },
}

return table.freeze(HunterClassConfig)
