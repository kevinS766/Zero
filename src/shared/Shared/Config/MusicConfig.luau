--!strict
export type TrackInfo = {
	Id: string,
	Title: string,
	Volume: number,
}

export type MusicTheme = {
	FadeDuration: number,
	Shuffle: boolean,
	Tracks: { TrackInfo },
}

local MusicConfig = {
	DEFAULT_FADE_DURATION = 2.0,
	DEFAULT_VOLUME = 0.45,
	TENSE_THRESHOLD = 45, -- Segundos restantes para activar el set de música tensa
	TENSE_FADE_OUT_DURATION = 1.0, -- Duración del fade out mientras la tensa ya está sonando

	Themes = {
		["LOBBY"] = {
			FadeDuration = 2.0,
			Shuffle = false, -- Orden preestablecido rotativo (1, 2, 3...) sin repeticiones A-B-A
			Tracks = {
				{ Id = "rbxassetid://71979748575104", Title = "1_Warm Haven", Volume = 0.45 },
				{ Id = "rbxassetid://109328803698100", Title = "2_Quiet Drift", Volume = 0.45 },
				{ Id = "rbxassetid://94332909461426", Title = "3_Warm Haven", Volume = 0.45 },
				{ Id = "rbxassetid://85616824044595", Title = "4_Soft Drift", Volume = 0.40 },
				{ Id = "rbxassetid://133528326839307", Title = "5_Soft Drift", Volume = 0.40 },
				{ Id = "rbxassetid://97708876434820", Title = "6_Soft Drift", Volume = 0.40 },
			},
		},

		["TENSE"] = {
			FadeDuration = 1.0,
			Shuffle = false, -- Orden preestablecido rotativo (1, 2, 3...) para cada clímax
			Tracks = {
				{ Id = "rbxassetid://102003917818708", Title = "10_Pixel Panic", Volume = 0.50 },
				{ Id = "rbxassetid://120730958092945", Title = "11_Overclock", Volume = 0.50 },
				{ Id = "rbxassetid://88804150738397", Title = "3_Faster Tempo Version", Volume = 0.50 },
				{ Id = "rbxassetid://85721262755472", Title = "6_Overclocked", Volume = 0.50 },
				{ Id = "rbxassetid://81094735643394", Title = "7_Overclock (Dark & Tense Cover)", Volume = 0.50 },
				{ Id = "rbxassetid://111631551095926", Title = "8_Pixel Panic", Volume = 0.50 },
				{ Id = "rbxassetid://126360204647995", Title = "9_DarkAndFast", Volume = 0.50 },
			},
		},

		["Map3_IslaTiki"] = {
			FadeDuration = 2.0,
			Shuffle = false, -- Orden preestablecido rotativo (1, 2, 3...)
			Tracks = {
				{ Id = "rbxassetid://104393454130886", Title = "1_Upbeat EDM Tropical Cover", Volume = 0.45 },
				{ Id = "rbxassetid://137237382034430", Title = "2_Pixel Paradise", Volume = 0.45 },
				{ Id = "rbxassetid://136734098271327", Title = "3_Pixel Paradise", Volume = 0.45 },
			},
		},

		["Map4_CiudadPastel"] = {
			FadeDuration = 2.0,
			Shuffle = false, -- Orden preestablecido rotativo (1, 2, 3...)
			Tracks = {
				{ Id = "rbxassetid://138938383991101", Title = "1_Pastel Plaza", Volume = 0.45 },
				{ Id = "rbxassetid://72762338561296", Title = "2_Pixel Highway", Volume = 0.45 },
				{ Id = "rbxassetid://77881556051756", Title = "3_Pixel Highway", Volume = 0.45 },
				{ Id = "rbxassetid://88438436601230", Title = "4_Pixel Joyride", Volume = 0.45 },
				{ Id = "rbxassetid://116463805685315", Title = "5_Pixel Joyride", Volume = 0.45 },
			},
		},

		["Map5_PuebloCalabaza"] = {
			FadeDuration = 2.0,
			Shuffle = false, -- Orden preestablecido rotativo (1, 2, 3...)
			Tracks = {
				{ Id = "rbxassetid://133149194582037", Title = "1_Pixel Ghoul", Volume = 0.45 },
				{ Id = "rbxassetid://78303972893660", Title = "2_Bone Boogie", Volume = 0.45 },
				{ Id = "rbxassetid://81781976314298", Title = "3_SpookySpooky", Volume = 0.45 },
				{ Id = "rbxassetid://98827897399908", Title = "4_Spooky Night Festival", Volume = 0.45 },
			},
		},

		["Map1_PlazaUrbana"] = {
			FadeDuration = 2.0,
			Shuffle = false,
			Tracks = {
				{ Id = "", Title = "Plaza Urbana Theme", Volume = 0.60 },
			},
		},

		["Map2_PatioDeCarga"] = {
			FadeDuration = 2.0,
			Shuffle = false,
			Tracks = {
				{ Id = "", Title = "Patio De Carga Theme", Volume = 0.60 },
			},
		},
	} :: { [string]: MusicTheme },
}

return table.freeze(MusicConfig)
