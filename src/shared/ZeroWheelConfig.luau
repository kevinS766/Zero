local Config = {
	FreeInterval = 43200,               -- un giro gratis cada 12 h (más giros: diario, regalos por tiempo, niveles y misiones)
	InitialSpins = 1,
	SpinDuration = 4.6,
	SpinCooldown = 5,
	Assets = {
		Disc = "rbxassetid://71101684061249",
		Cash = "rbxassetid://77365292256801",
		Pointer = "rbxassetid://111651617783602",
	},
	Rewards = {
		{Coins=50, Label="50", Weight=45},
		{Coins=200, Label="200", Weight=30},
		{Coins=600, Label="600", Weight=18},
		{Coins=3000, Label="3K", Weight=6.98},
		-- mítico de tiempo limitado (ZeroArmasConfig.Obtencion); si ya lo tienes da Compensa monedas
		{Arma="Bastón Cero Absoluto", Label="CERO ABS.", Icono="rbxassetid://84763014357839", Compensa=3000, Weight=0.02},   -- 1 de cada 5.000 giros
	},
	-- Los productos de Robux se conectarán cuando Joshua proporcione sus IDs.
}
return table.freeze(Config)
