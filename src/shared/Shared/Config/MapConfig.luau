--!strict
export type MapEntry = {
	Id: string,
	DisplayName: string,
	WorkspaceName: string,
	PreviewAssetId: string,
	Icon: string,          -- emoji del panel de votación (mientras no haya imagen de vista previa)
	Color: Color3,         -- color de fondo del panel
}

local MapConfig = {
	-- Mapas en rotación. Se guardan en ServerStorage.Mapas y MapService mete en Workspace solo el votado.
	Maps = {
		["Map3_IslaTiki"] = {
			Id = "Map3_IslaTiki",
			DisplayName = "ISLA TIKI",
			WorkspaceName = "Map3_IslaTiki",
			PreviewAssetId = "rbxassetid://89327240395573",
			Icon = "🏝️",
			Color = Color3.fromRGB(0, 170, 190),
		},
		["Map4_CiudadPastel"] = {
			Id = "Map4_CiudadPastel",
			DisplayName = "CIUDAD PASTEL",
			WorkspaceName = "Map4_CiudadPastel",
			PreviewAssetId = "rbxassetid://96759620528629",
			Icon = "🏙️",
			Color = Color3.fromRGB(232, 120, 170),
		},
		["Map5_PuebloCalabaza"] = {
			Id = "Map5_PuebloCalabaza",
			DisplayName = "PUEBLO CALABAZA",
			WorkspaceName = "Map5_PuebloCalabaza",
			PreviewAssetId = "rbxassetid://85917226265760",
			Icon = "🎃",
			Color = Color3.fromRGB(235, 120, 30),
		},
	} :: { [string]: MapEntry },

	-- Orden de los pedestales de votación del lobby (HunterClasses.Slot1..3)
	SlotMapOrder = {
		[1] = "Map3_IslaTiki",
		[2] = "Map4_CiudadPastel",
		[3] = "Map5_PuebloCalabaza",
	},

	-- Segundos de votación en el lobby antes de cada ronda (también al abrir un servidor nuevo)
	VOTE_DURATION = 15,

	-- Mapa predeterminado en caso de fallback
	DEFAULT_MAP = "Map3_IslaTiki",
}

return table.freeze(MapConfig)
