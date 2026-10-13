--!strict

export type GamepassInfo = {
	Id: number,
	Name: string,
	DisplayName: string,
	Description: string,
	PriceRobux: number?,
	Icon: string?,
}

export type ProductInfo = {
	Key: string,
	Name: string,
	Amount: number,
	PriceRobux: number,
	Icon: string,
	Type: "Coins" | "Gems",
}

local MonetizationConfig = {
	-- IDs oficiales de Gamepass de Roblox
	Passes = {
		VIP = {
			Id = 2025170299,
			Name = "VIP",
			DisplayName = "VIP",
			Description = "Tag exclusivo en Chat y Overhead, rastro estético único y +1 tiro gratis en la ruleta.",
			PriceRobux = 299,
			Icon = "rbxassetid://89526354558521",
		},
		DOUBLE_COINS = {
			Id = 2026664283,
			Name = "2xCoins",
			DisplayName = "2× COINS",
			Description = "Duplica permanentemente todas las monedas obtenidas al jugar, rescatar y ganar rondas.",
			PriceRobux = 199,
			Icon = "rbxassetid://108573978429532",
		},
		DOUBLE_GEMS = {
			Id = 2025602282,
			Name = "2xGems",
			DisplayName = "2× GEMS",
			Description = "Duplica permanentemente todas las gemas obtenidas por victorias y metas.",
			PriceRobux = 249,
			Icon = "rbxassetid://89061393862937",
		},
		DOUBLE_XP = {
			Id = 2026748305,
			Name = "2xXP",
			DisplayName = "2× XP",
			Description = "Duplica permanentemente toda la experiencia (XP) obtenida para subir de nivel el doble de rápido.",
			PriceRobux = 199,
			Icon = "rbxassetid://120406576274077",
		},
	},

	-- Armas exclusivas que se venden como pase (ZeroArmasConfig.Obtencion[arma].pase = clave)
	Exclusivos = {
		ORIGAMI = {
			Id = 2025927075,
			Name = "OrigamiCelestial",
			DisplayName = "ORIGAMI CELESTIAL",
			Description = "Bastón exclusivo Origami Celestial.",
			PriceRobux = 399,
			Icon = "",
		},
	},

	-- Developer Products (Consumibles de Robux)
	Products = {
		CoinPacks = {
			[3717562334] = { Key = "CoinPack_1", Name = "1,000 MONEDAS", Amount = 1000, PriceRobux = 30, Icon = "rbxassetid://113427826866582", Type = "Coins" },
			[3717562596] = { Key = "CoinPack_2", Name = "10,000 MONEDAS", Amount = 10000, PriceRobux = 180, Icon = "rbxassetid://95811928451273", Type = "Coins" },
			[3717562754] = { Key = "CoinPack_3", Name = "100,000 MONEDAS", Amount = 100000, PriceRobux = 900, Icon = "rbxassetid://121411394632169", Type = "Coins" },
		} :: { [number]: ProductInfo },

		GemPacks = {
			[3717565388] = { Key = "GemPack_1", Name = "100 GEMAS", Amount = 100, PriceRobux = 1, Icon = "rbxassetid://140160266592935", Type = "Gems" },
			[3717565549] = { Key = "GemPack_2", Name = "200 GEMAS", Amount = 200, PriceRobux = 2, Icon = "rbxassetid://140160266592935", Type = "Gems" },
			[3717565572] = { Key = "GemPack_3", Name = "300 GEMAS", Amount = 300, PriceRobux = 3, Icon = "rbxassetid://140160266592935", Type = "Gems" },
		} :: { [number]: ProductInfo },
	},

	-- Pack de Inicio: compra única (Developer Product "Pack de Inicio" en el Creator Hub; 0 = desactivado).
	-- 1.000 monedas (R$ 30) + Caja Rara (R$ 99) + 2 giros + título exclusivo. ValorRobux = 88 para que la tienda
	-- anuncie -67 % (lo pidió el usuario; el valor real ronda R$ 129).
	-- Packs de giros de la ruleta (Developer Products). Id = 0: aún sin crear (el botón dice PRONTO).
	-- Son compras de premio aleatorio: no se venden donde PolicyService.ArePaidRandomItemsRestricted (ZeroWheelServer).
	SpinPacks = {
		{ Id = 0, Giros = 2, PriceRobux = 49 },
		{ Id = 0, Giros = 5, PriceRobux = 99 },
		{ Id = 0, Giros = 10, PriceRobux = 179 },
	},

	StarterPack = {
		Id = 3717870346,
		PriceRobux = 29,
		ValorRobux = 88,
		Coins = 1000,
		Spins = 2,
		Caja = "Rara",
		Titulo = "Pionero",
	},

	-- Recompensas base por partida
	Rewards = {
		-- Victoria de ronda
		RoundWin = {
			Hunter = { Coins = 60, Gems = 10 },
			Runner = { Coins = 50, Gems = 8 },
		},
		-- Participación / Derrota
		RoundParticipation = {
			Coins = 15,
			Gems = 1,
		},
		-- Acciones de combate durante la partida
		Combat = {
			HunterTag = { Coins = 15, Gems = 1 },
			RunnerRescue = { Coins = 20, Gems = 2 },
		},
	},

	-- Multiplicadores
	Multipliers = {
		CoinsPass = 2,
		GemsPass = 2,
		XpPass = 2,
		VIPBonusPercent = 0.2, -- +20% extra si tiene VIP
	},

	-- Beneficios VIP
	VIP = {
		ChatTag = "[VIP]",
		ChatColor = Color3.fromRGB(255, 215, 0), -- Dorado
		BonusDailySpins = 1,
		BonusDailyGems = 5,
	},
}

for clave, info in MonetizationConfig.Exclusivos do MonetizationConfig.Passes[clave] = info end
return table.freeze(MonetizationConfig)
