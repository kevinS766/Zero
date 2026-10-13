--!strict
local PlayerRoles = {
	LOBBY = "Lobby",
	HUNTER = "Hunter",
	RUNNER = "Runner",
}

export type PlayerRole = "Lobby" | "Hunter" | "Runner"

return table.freeze(PlayerRoles)
