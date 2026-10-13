--!strict
-- ZeroExclusivosConfig (ModuleScript, ReplicatedStorage): lo que enseña la vitrina de Exclusivos del lobby.
-- Los objetos aún no están diseñados: cuando lo estén, rellenar nombre, subtitulo, precio y (opcional) termina,
-- y poner su modelo en ReplicatedStorage.ZeroArmasModelos.<modelo> para que el maniquí lo sostenga.
return {
	{
		tipo = "Robux",                        -- etiqueta "EXCLUSIVO DE ROBUX"
		nombre = "ORIGAMI CELESTIAL",
		subtitulo = "Bastón exclusivo · Exclusivo de la tienda",
		precio = 399 :: number?,               -- Robux (Game Pass ORIGAMI, MonetizationConfig.Exclusivos)
		termina = nil :: number?,              -- os.time() en que acaba la oferta (muestra "TERMINA EN"); nil = sin límite
		modelo = "Origami Celestial" :: string?,      -- se compra con Config.Obtencion[modelo] (pase o producto)
	},
	{
		tipo = "VIP",                          -- etiqueta "EXCLUSIVO VIP"
		nombre = "CORONA DEL BUFÓN",
		subtitulo = "Bastón exclusivo · Incluido en el pase VIP",
		precio = 299 :: number?,               -- precio del pase VIP (MonetizationConfig.Passes.VIP)
		termina = nil :: number?,
		modelo = "Corona del Bufón" :: string?,
	},
}
