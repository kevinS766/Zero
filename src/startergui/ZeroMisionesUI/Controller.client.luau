local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = script.Parent
local panel, backdrop = gui.Panel, gui.Backdrop
panel.Header.Close.NextSelectionDown = panel.Cards
panel.Cards.NextSelectionUp = panel.Header.Close
local Audio = require(ReplicatedStorage:WaitForChild("ZeroAudio"))
local signal = ReplicatedStorage:FindFirstChild("ZeroMisionesAbrir")
if not signal then
	signal = Instance.new("BindableEvent")
	signal.Name = "ZeroMisionesAbrir"
	signal.Parent = ReplicatedStorage
end
assert(signal:IsA("BindableEvent"), "ZeroMisionesAbrir must be a BindableEvent")
-- solo se bloquea a quien está jugando la ronda (AFK y espectadores pueden usar el panel)
local function enJuego()
	local r = player:GetAttribute("Role")
	return ReplicatedStorage:GetAttribute("RoundState") == "ROUND_ACTIVE" and (r == "Runner" or r == "Hunter")
end
local previousSelection, isOpen, openingTween
local avatarId, portraitRequest = nil, 0
local function rect(n, x, y, w, h)
	n.Position = UDim2.fromOffset(x, y); n.Size = UDim2.fromOffset(w, h)
end
local function layout()
	local size = gui:GetAttribute("PreviewViewport") or gui.AbsoluteSize
	local w, h = math.min(840, size.X - 24), math.min(640, size.Y - 24)
	local portrait = w < 600
	local landscape = not portrait and h < 480
	panel.Size = UDim2.fromOffset(w, h)
	local header = panel.Header
	local hh = landscape and 64 or 80
	rect(header, 8, 8, w - 16, hh)
	rect(header.Icon, 10, 6, landscape and 50 or 64, landscape and 50 or 64)
	local tx = landscape and 72 or 88
	rect(header.Title, tx, 5, w - tx - 90, 43)
	header.Title.TextSize = portrait and 28 or 34
	rect(header.Subtitle, tx, 46, w - tx - 90, 20)
	header.Subtitle.Visible = not landscape
	header.Subtitle.TextSize = portrait and 9 or 12
	rect(header.Close, w - 80, (hh - 48) / 2, 48, 48)
	local guide, section, list, footer = panel.Guide, panel.Section, panel.Cards, panel.Footer
	local gy = hh + 24
	if landscape then
		rect(guide, 20, gy, 194, h - gy - 72)
		rect(guide.Portrait, 65, 10, 64, 64)
		rect(guide.GuideName, 12, 80, 170, 24)
		rect(guide.Greeting, 12, 108, 170, math.max(28, guide.Size.Y.Offset - 116))
		guide.Greeting.Text = "¡Nuevos retos!"; guide.Greeting.TextSize = 18; guide.Message.Visible = false
		guide.GuideName.TextXAlignment = Enum.TextXAlignment.Center
		guide.Greeting.TextXAlignment = Enum.TextXAlignment.Center
		rect(section, 232, gy, w - 252, 34)
		rect(list, 232, gy + 42, w - 252, h - gy - 120)
	else
		local gh = portrait and 128 or 110
		rect(guide, 20, gy, w - 40, gh)
		rect(guide.Portrait, 12, (gh - 80) / 2, 80, 80)
		rect(guide.GuideName, 108, 12, w - 172, 24)
		rect(guide.Greeting, 108, 38, w - 172, portrait and 44 or 32)
		guide.Greeting.Text = "¿Listo para un nuevo reto?"; guide.Greeting.TextSize = portrait and 19 or 24
		rect(guide.Message, 108, portrait and 87 or 73, w - 172, portrait and 30 or 26)
		guide.Message.TextSize = portrait and 12 or 14; guide.Message.Visible = true
		guide.GuideName.TextXAlignment = Enum.TextXAlignment.Left
		guide.Greeting.TextXAlignment = Enum.TextXAlignment.Left
		rect(section, 20, gy + gh + 14, w - 40, 38)
		local ly = gy + gh + 64
		rect(list, 20, ly, w - 40, h - ly - 80)
	end
	local sw = section.Size.X.Offset
	rect(section.Title, 0, 0, sw - 144, 34)
	section.Title.TextSize = portrait and 16 or 22
	rect(section.Badge, sw - 136, 5, 136, 24)
	local cw = (list.Size.X.Offset - 32) / 3
	local vertical = portrait or landscape
	local cardH = vertical and 148 or 268
	local count = 0
	for _, card in list:GetChildren() do
		if not card:IsA("Frame") then continue end
		local index = card:GetAttribute("Order")
		count += 1
		if vertical then
			cw = list.Size.X.Offset - 8
			rect(card, 4, 4 + (index - 1) * (cardH + 14), cw, cardH)
			rect(card.Art, 10, 10, 90, 128)
			rect(card.Art.Icon, 10, 17, 70, 70)
			rect(card.Art.Tag, 4, 94, 82, 24)
			rect(card.Title, 114, 10, cw - 126, 35)
			card.Title.TextSize = portrait and 17 or 20
			rect(card.Description, 114, 47, cw - 128, 46)
			card.Description.TextSize = portrait and 12 or 14
			rect(card.Status, 114, 106, cw - 126, 30)
		else
			rect(card, 4 + ((index - 1) % 3) * (cw + 12), 4 + ((index - 1) // 3) * (cardH + 12), cw, cardH)   -- filas de 3
			rect(card.Art, 10, 10, cw - 20, 110)
			rect(card.Art.Icon, (cw - 20 - 76) / 2, 7, 76, 76)
			rect(card.Art.Tag, 8, 83, cw - 36, 24)
			rect(card.Title, 14, 130, cw - 28, 35)
			rect(card.Description, 14, 174, cw - 28, 42)
			card.Title.TextSize = 21; card.Description.TextSize = 14
			rect(card.Status, 12, 226, cw - 24, 30)
		end
		rect(card.Status.Icon, 7, 4, 22, 22)
		rect(card.Status.Label, 34, 0, card.Status.Size.X.Offset - 38, 30)
		card.Status.Label.TextSize = portrait and 9 or 11
	end
	list.CanvasSize = UDim2.fromOffset(0, vertical and count * (cardH + 14) or math.ceil(count / 3) * (cardH + 12) + 4)
	rect(footer, 20, h - 64, w - 40, 44)
	rect(footer.Icon, 8, 5, 34, 34)
	rect(footer.Message, 50, 4, w - 104, 36)
	footer.Message.TextSize = portrait and 11 or 13
	gui:SetAttribute("Layout", landscape and "Landscape" or portrait and "Portrait" or "Desktop")
end
local function updateGuide()
	local lobby = workspace:FindFirstChild("ZeroLobby")
	local zone = lobby and lobby:FindFirstChild("Misiones")
	local npc = zone and zone:FindFirstChild("NPC_Misiones")
	local folder = ReplicatedStorage:FindFirstChild("ZeroMisioneros")
	local source = npc or (folder and folder:FindFirstChild(tostring(player.UserId)))
	local name = source and source:GetAttribute("NombreAmigo")
	panel.Guide.GuideName.Text = name and (name .. " · TU GUÍA") or "TU GUÍA DE MISIONES"
	local id = source and source:GetAttribute("AmigoId")
	if not id or id == avatarId then return end
	avatarId = id; portraitRequest += 1
	local request = portraitRequest
	panel.Guide.Portrait.Avatar.Image = ""
	panel.Guide.Portrait.Fallback.Visible = true
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if ok and request == portraitRequest and gui.Parent then
			panel.Guide.Portrait.Avatar.Image = content
			local deadline = os.clock() + 5
			while not panel.Guide.Portrait.Avatar.IsLoaded and os.clock() < deadline and gui.Parent do task.wait(.1) end
			if request == portraitRequest and gui.Parent then
				panel.Guide.Portrait.Fallback.Visible = not panel.Guide.Portrait.Avatar.IsLoaded
			end
		end
	end)
end
local function close()
	if not isOpen then return end
	isOpen = false
	if openingTween then openingTween:Cancel() end
	panel.Visible = false; backdrop.Visible = false
	gui:SetAttribute("Open", false)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
	end
	Audio.play("Close")
end
local function open()
	if enJuego() then return end
	if player:GetAttribute("ZeroLoadingActive") then return end
	if isOpen then updateGuide(); return end
	local ui = player.PlayerGui:FindFirstChild("ZeroUI")
	local action = ui and ui:FindFirstChild("UIAction")
	if action then pcall(function() action:Invoke("Close") end) end
	previousSelection = GuiService.SelectedObject
	isOpen = true; gui:SetAttribute("Open", true)
	updateGuide(); layout(); panel.Cards.CanvasPosition = Vector2.zero
	panel.Visible = true; backdrop.Visible = true
	panel.Position = UDim2.new(.5, 0, .5, 12)
	openingTween = TweenService:Create(panel, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromScale(.5, .5)})
	openingTween:Play(); Audio.play("Open")
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = panel.Header.Close end
end
signal.Event:Connect(open)
panel.Header.Close.Activated:Connect(close)
backdrop.Activated:Connect(close)
UserInputService.InputBegan:Connect(function(input)
	if isOpen and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then close() end
end)
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function() if enJuego() then close() end end)
player:GetAttributeChangedSignal("Role"):Connect(function() if enJuego() then close() end end)
gui:GetAttributeChangedSignal("CerrarPedido"):Connect(close)   -- al salir de la zona de Misiones del lobby
local ui = player.PlayerGui:WaitForChild("ZeroUI", 10)
if ui then ui:GetAttributeChangedSignal("CurrentMenu"):Connect(function()
	if ui:GetAttribute("CurrentMenu") ~= "" then close() end
end) end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
gui:GetAttributeChangedSignal("PreviewViewport"):Connect(layout)
gui:GetAttributeChangedSignal("Relayout"):Connect(layout)   -- el script Datos lo pide al rellenar las tarjetas
layout(); gui:SetAttribute("Open", false); gui:SetAttribute("ControllerReady", true)