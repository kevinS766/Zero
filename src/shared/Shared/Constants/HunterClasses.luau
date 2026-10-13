--!strict
local HunterClasses = {
	TRACKER = "Tracker",
	STALKER = "Stalker",
	TRAPPER = "Trapper",
}

export type HunterClass = "Tracker" | "Stalker" | "Trapper"

return table.freeze(HunterClasses)
