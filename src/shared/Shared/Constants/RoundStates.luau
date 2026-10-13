--!strict
local RoundStates = {
	WAITING_FOR_PLAYERS = "WAITING_FOR_PLAYERS",
	INTERMISSION = "INTERMISSION",
	ROUND_ACTIVE = "ROUND_ACTIVE",
	ROUND_END = "ROUND_END",
}

export type RoundState = "WAITING_FOR_PLAYERS" | "INTERMISSION" | "ROUND_ACTIVE" | "ROUND_END"

return table.freeze(RoundStates)
