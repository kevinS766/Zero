local Player = game.Players.LocalPlayer

Player.CharacterAdded:Connect(function(Character)
	local Highlight = Instance.new("Highlight")
	Highlight.Parent = Character
	Highlight.FillTransparency = 1 -- 100% transparente: no oscurece, ensucia ni pone gris la ropa/piel del personaje
	Highlight.OutlineColor = Color3.fromRGB(15, 15, 20)
	Highlight.OutlineTransparency = 0.15
	Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	Highlight.Enabled = true
	Highlight.Adornee = Character
end)