--!strict
local PlayerStatus = {
	ACTIVE = "Active",
	FROZEN = "Frozen",
}

export type PlayerStatus = "Active" | "Frozen"

return table.freeze(PlayerStatus)
