-- Datos (LocalScript, StarterGui.ZeroMisionesUI): rellena el panel de misiones de Codex con las misiones reales.
-- Pestañas DIARIAS / SEMANALES / LOGROS en la sección, tarjetas clonadas de la plantilla de Codex con barra de
-- progreso y botón RECLAMAR, cambio de una diaria al día (↻), bonus en el pie y títulos en LOGROS.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local cards = panel:WaitForChild("Cards")
local section = panel:WaitForChild("Section")
local footer = panel:WaitForChild("Footer")
cards.ScrollBarThickness = 0                                    -- sin barra marrón (se sigue deslizando con rueda/dedo)
local request = ReplicatedStorage:WaitForChild("ZeroMisionesRequest") :: RemoteFunction
local estadoEv = ReplicatedStorage:WaitForChild("ZeroMisionesEstado") :: RemoteEvent
local UI = require(ReplicatedStorage:WaitForChild("ZeroUI"))
local Audio = require(ReplicatedStorage:WaitForChild("ZeroAudio"))
local C = UI.Colors

-- plantilla: la primera tarjeta de Codex (las 3 de ejemplo se sustituyen por las reales)
local template = cards:WaitForChild("Participa"):Clone()
local ACCENT = { Corredor = C.blue, Cazador = C.pink, Cualquiera = C.green, Semanal = C.purple, Logro = C.yellow, Primera = C.orange or C.yellow, Titulo = C.yellow }
local ICON = { Corredor = "dash", Cazador = "hunter", Cualquiera = "stats", Semanal = "daily", Logro = "stats", Primera = "gift", Titulo = "vip" }

local estado, pestana = nil, "Diarias"
local function new(class, parent, props)
	local n = Instance.new(class); for k, v in props or {} do n[k] = v end; n.Parent = parent; return n
end
local function fmt(n) local s = tostring(math.floor(n)); return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")) end
local function notify(msg)
	local ui = player.PlayerGui:FindFirstChild("ZeroUI")
	local t = ui and ui:FindFirstChild("Toast")
	if t then t.Message.Text = msg; t.Visible = true; task.delay(3, function() if t.Message.Text == msg then t.Visible = false end end) end
end
local function relayout() gui:SetAttribute("Relayout", (gui:GetAttribute("Relayout") or 0) + 1) end

-- ------------------------------------------------------------------ pestañas
section.Title.Visible = false
local tabs = {}
for i, name in { "Diarias", "Semanales", "Logros" } do
	local b = new("TextButton", section, { Name = "Tab_" .. name, Text = string.upper(name), Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = C.white, BackgroundColor3 = C.card, AutoButtonColor = true, BorderSizePixel = 0 })
	new("UICorner", b, { CornerRadius = UDim.new(0, 10) }); new("UIStroke", b, { Color = C.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	new("UIPadding", b, { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) })
	tabs[name] = b
end
local function layoutTabs()
	local w = section.AbsoluteSize.X - 150
	if w <= 0 then return end
	local tw = (w - 16) / 3
	local i = 0
	for _, name in { "Diarias", "Semanales", "Logros" } do
		local b = tabs[name]
		b.Position = UDim2.fromOffset(i * (tw + 8), 0); b.Size = UDim2.new(0, tw, 1, 0)
		b.BackgroundColor3 = name == pestana and C.yellow or C.card
		b.TextColor3 = name == pestana and C.ink or C.white
		i += 1
	end
end
section:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTabs)

-- ------------------------------------------------------------------ tarjetas
local function card(order: number, accent: Color3, iconKey: string, tag: string, title: string, desc: string)
	local c = template:Clone()
	c.Name = "M_" .. order
	c:SetAttribute("Order", order); c:SetAttribute("Accent", accent)
	c.Art.BackgroundColor3 = accent
	local icon = c.Art:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") and UI.Icons[iconKey] then icon.Image = "rbxassetid://" .. UI.Icons[iconKey] end
	local tg = c.Art:FindFirstChild("Tag")
	if tg then (tg:IsA("TextLabel") and tg or tg:FindFirstChildWhichIsA("TextLabel", true) or tg).Text = tag end
	c.Title.Text = title
	c.Description.Text = desc
	c.Parent = cards
	return c
end
-- estado de la tarjeta: barra de progreso, texto y (si toca) botón
local function status(c, prog: number, meta: number, label: string, boton: string?, onClick: (() -> ())?, color: Color3?)
	local st = c.Status
	local fill = st:FindFirstChild("Barra") or new("Frame", st, { Name = "Barra", BorderSizePixel = 0, ZIndex = st.ZIndex, BackgroundTransparency = 0.25 })
	if not fill:FindFirstChildOfClass("UICorner") then new("UICorner", fill, { CornerRadius = UDim.new(0, 8) }) end
	fill.BackgroundColor3 = c:GetAttribute("Accent")
	fill.Size = UDim2.fromScale(math.clamp(meta > 0 and prog / meta or 0, 0, 1), 1)
	st.Label.ZIndex = st.ZIndex + 2; if st:FindFirstChild("Icon") then st.Icon.Visible = false end   -- el candado de Codex ya no aplica
	st.Label.Text = label
	if boton then
		local b = new("TextButton", st, { Name = "Accion", Text = boton, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = C.white,
			BackgroundColor3 = color or C.green, Size = UDim2.fromScale(1, 1), ZIndex = st.ZIndex + 3, AutoButtonColor = true, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })   -- centrado: el pulso crece hacia los dos lados
		new("UICorner", b, { CornerRadius = UDim.new(0, 8) }); new("UIStroke", b, { Color = C.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		new("UIPadding", b, { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) })
		if onClick then
			-- respuesta al momento: el botón cambia sin esperar al servidor y vuelve si falla
			b.Activated:Connect(function()
				if not b.Active then return end
				local antes, colorAntes = b.Text, b.BackgroundColor3
				b.Active = false; b.AutoButtonColor = false
				b.Text = "…"; b.BackgroundColor3 = C.muted or Color3.fromRGB(120, 125, 140)
				local ok = onClick()
				if not b.Parent then return end
				if ok then
					b.Text = "✓ ¡LISTO!"; b.BackgroundColor3 = color or C.green
				else
					b.Text = antes; b.BackgroundColor3 = colorAntes; b.Active = true; b.AutoButtonColor = true
				end
			end)
		end
		-- pulso para que se note
		local sc = new("UIScale", b)
		task.spawn(function()
			while b.Parent do
				TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { Scale = 1.06 }):Play(); task.wait(0.45)
				TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { Scale = 1 }):Play(); task.wait(0.45)
			end
		end)
	end
end

local busy = false
local function pedir(accion, payload)
	if busy then return false end
	busy = true
	local ok, res = pcall(function() return request:InvokeServer(accion, payload) end)
	busy = false
	if not ok or not res then notify("No se pudo completar."); return false end
	if not res.success then if res.message then notify(res.message) end; Audio.play("Error"); return false end
	if accion == "Reclamar" and res.premio then
		local p, partes = res.premio, {}
		if (p.monedas or 0) > 0 then table.insert(partes, "+" .. fmt(p.monedas) .. " monedas") end
		if p.giros then table.insert(partes, "+" .. p.giros .. (p.giros == 1 and " giro" or " giros")) end
		if p.caja then table.insert(partes, "¡Caja " .. (p.caja == "Comun" and "Común" or p.caja) .. "!") end
		if p.titulo then table.insert(partes, "Título «" .. p.titulo .. "»") end
		Audio.play("Prize")
		notify("¡Recompensa! " .. table.concat(partes, " · "))
	end
	return true
end

local function premioTexto(m) return m.caja and ("CAJA " .. string.upper(m.caja == "Comun" and "Común" or m.caja)) or ("+" .. fmt(m.monedas or 0)) end

local function render()
	for _, c in cards:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	layoutTabs()
	if not estado then relayout(); return end
	local o = 0
	if pestana == "Diarias" or pestana == "Semanales" then
		local diaria = pestana == "Diarias"
		for _, m in (diaria and estado.diarias or estado.semanales) do
			o += 1
			local rol = diaria and m.rol or "Semanal"
			local c = card(o, ACCENT[rol], ICON[rol], premioTexto(m), m.titulo, m.texto .. (diaria and m.rol ~= "Cualquiera" and (" · " .. string.upper(m.rol)) or ""))
			if m.claimed then status(c, 1, 1, "✓ RECLAMADA", nil)
			elseif m.done then status(c, 1, 1, "", "RECLAMAR", function() return pedir("Reclamar", { tipo = diaria and "diaria" or "semanal", id = m.id }) end)
			else status(c, m.prog, m.meta, string.format("%d / %d", m.prog, m.meta)) end
			if diaria and not estado.cambio and not m.claimed then
				local r = new("TextButton", c, { Name = "Cambiar", Text = "↻", Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = C.white,
					BackgroundColor3 = C.ink, Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), ZIndex = 10 })
				new("UICorner", r, { CornerRadius = UDim.new(1, 0) })
				r.Activated:Connect(function() return pedir("Cambiar", { id = m.id }) end)
			end
		end
		-- pie: bonus por completar todas
		local todas, b = true, diaria and estado.bonusDiario or estado.bonusSemanal
		for _, m in (diaria and estado.diarias or estado.semanales) do if not m.claimed then todas = false end end
		local reclamado = diaria and estado.bonusD or (not diaria and estado.bonusS)
		local partes = {}
		if (b.monedas or 0) > 0 then table.insert(partes, fmt(b.monedas) .. " monedas") end
		if b.giros then table.insert(partes, b.giros .. " giro") end
		if b.caja then table.insert(partes, "Caja " .. (b.caja == "Comun" and "Común" or b.caja)) end
		footer.Message.Text = (reclamado and "✓ Bonus reclamado: " or "Completa y reclama las 3 → ") .. table.concat(partes, " + ")
		local fb = footer:FindFirstChild("Bonus"); if fb then fb:Destroy() end
		if todas and not reclamado then
			local btn = new("TextButton", footer, { Name = "Bonus", Text = "RECLAMAR BONUS", Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = C.white,
				BackgroundColor3 = C.green, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 170, 1, -8), ZIndex = 10 })
			new("UICorner", btn, { CornerRadius = UDim.new(0, 8) })
			btn.Activated:Connect(function() return pedir("Reclamar", { tipo = diaria and "bonusDiario" or "bonusSemanal" }) end)
		end
	else
		footer.Message.Text = "Completa los 3 niveles de un logro para ganar su título."
		local fb = footer:FindFirstChild("Bonus"); if fb then fb:Destroy() end
		for _, t in estado.titulos do                                   -- títulos ganados
			o += 1
			local enUso = estado.titulo == t
			local c = card(o, ACCENT.Titulo, ICON.Titulo, "TÍTULO", "« " .. t .. " »", enUso and "Lo llevas sobre la cabeza." or "Póntelo sobre la cabeza.")
			status(c, 1, 1, "", enUso and "QUITAR" or "USAR", function() return pedir("UsarTitulo", { titulo = (not enUso) and t or nil }) end, enUso and C.pink or C.blue)
		end
		for _, p in estado.primeras do
			if not p.claimed then
				o += 1
				local c = card(o, ACCENT.Primera, ICON.Primera, "+" .. fmt(p.monedas), p.titulo, "Logro de primera vez.")
				if p.hecho then status(c, 1, 1, "", "RECLAMAR", function() return pedir("Reclamar", { tipo = "primera", id = p.id }) end)
				else status(c, 0, 1, "0 / 1") end
			end
		end
		for _, l in estado.logros do
			o += 1
			local completo = l.meta == nil
			local tag = completo and "COMPLETO" or (l.nivel + 1 == l.niveles and ("+" .. fmt(l.monedas) .. " + TÍTULO") or ("+" .. fmt(l.monedas)))
			local c = card(o, ACCENT.Logro, ICON.Logro, tag, string.format("%s  ·  NV %d/%d", l.titulo, l.nivel, l.niveles),
				l.texto .. (l.nombreTitulo and (" · Título: «" .. l.nombreTitulo .. "»") or ""))
			if completo then status(c, 1, 1, "★ COMPLETADO")
			elseif l.valor >= l.meta then status(c, 1, 1, "", "RECLAMAR", function() return pedir("Reclamar", { tipo = "logro", id = l.id }) end)
			else status(c, l.valor, l.meta, string.format("%s / %s", fmt(l.valor), fmt(l.meta))) end
		end
	end
	relayout()
end

for name, b in tabs do b.Activated:Connect(function() pestana = name; Audio.play("Tab"); cards.CanvasPosition = Vector2.zero; render() end) end

-- reloj de renovación en la insignia de la sección
local badge = section:WaitForChild("Badge")
task.spawn(function()
	while gui.Parent do
		if estado then
			local fin = pestana == "Semanales" and estado.finSemana or estado.finDia
			local s = math.max(0, fin - os.time())
			badge.Label.Text = pestana == "Logros" and "PERMANENTES" or (s >= 86400 and string.format("RENUEVA EN %dd %dh", s // 86400, (s // 3600) % 24)
				or string.format("RENUEVA EN %02d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60))
		end
		task.wait(1)
	end
end)

estadoEv.OnClientEvent:Connect(function(e) estado = e; if gui:GetAttribute("Open") then render() end end)
gui:GetAttributeChangedSignal("Open"):Connect(function()
	if not gui:GetAttribute("Open") then return end
	local ok, res = pcall(function() return request:InvokeServer("Estado") end)
	if ok and res and res.success then estado = res.estado end
	render()
end)
panel.Guide.Message.Text = "Completa misiones para ganar monedas, giros, cajas y títulos."
gui:SetAttribute("MissionsActive", true)
