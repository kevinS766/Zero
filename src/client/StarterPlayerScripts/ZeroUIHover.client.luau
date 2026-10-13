-- ZeroUIHover (LocalScript, StarterPlayerScripts): vida para TODOS los botones de la interfaz (ZeroUI, Misiones,
-- Armas…, también los que se crean después). Al pasar el cursor el botón crece un poco con rebote y se inclina un
-- pelín; al pulsar se hunde; al soltar rebota. Mando: lo mismo al seleccionarlo. Respeta "Reducir movimiento".
-- Un botón con el atributo SinHover = true se queda quieto.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local HOVER, PRESS, TILT = 1.06, 0.93, 2
local hooked = setmetatable({}, { __mode = "k" })

local function tween(obj, t, props, style)
	TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Back, Enum.EasingDirection.Out), props):Play()
end

local function hook(b: GuiButton)
	if hooked[b] or b:GetAttribute("SinHover") then return end
	-- fondos que tapan la pantalla (sombra/backdrop): sin animación
	if b.Size.X.Scale >= 0.9 and b.Size.Y.Scale >= 0.9 then return end
	if b:FindFirstChildOfClass("UIScale") then return end            -- ya tiene su propia animación de escala
	hooked[b] = true
	local scale = Instance.new("UIScale"); scale.Name = "HoverScale"; scale.Parent = b
	local stroke = b:FindFirstChildOfClass("UIStroke")
	local thick0 = stroke and stroke.Thickness
	local rot0 = b.Rotation
	-- los botones anchos solo crecen un poco (crecen desde su esquina y se notaría el desplazamiento)
	local big = false
	local over = false
	local function calm() return GuiService.ReducedMotionEnabled end
	local function enter()
		over = true
		big = b.AbsoluteSize.X > 260
		if calm() then return end
		tween(scale, 0.22, { Scale = big and 1.025 or HOVER })
		if not big then tween(b, 0.22, { Rotation = rot0 - TILT }) end
		if stroke then tween(stroke, 0.15, { Thickness = thick0 + 1 }, Enum.EasingStyle.Quad) end
	end
	local function leave()
		over = false
		tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Quad)
		tween(b, 0.18, { Rotation = rot0 }, Enum.EasingStyle.Quad)
		if stroke then tween(stroke, 0.15, { Thickness = thick0 }, Enum.EasingStyle.Quad) end
	end
	b.MouseEnter:Connect(enter)
	b.MouseLeave:Connect(leave)
	b.SelectionGained:Connect(enter)
	b.SelectionLost:Connect(leave)
	b.MouseButton1Down:Connect(function()
		if not calm() then tween(scale, 0.07, { Scale = PRESS }, Enum.EasingStyle.Quad) end
	end)
	b.MouseButton1Up:Connect(function()
		if not calm() then tween(scale, 0.3, { Scale = over and (big and 1.025 or HOVER) or 1 }) end
	end)
	-- si el botón se oculta con el cursor encima, que no se quede "inflado" al volver
	b:GetPropertyChangedSignal("Visible"):Connect(function() if not b.Visible then over = false; scale.Scale = 1; b.Rotation = rot0 end end)
end

local function try(d)
	if d:IsA("GuiButton") then
		-- se espera un fotograma: el script que crea el botón termina de montarlo (tamaño, UIScale propio…)
		task.defer(function() if d.Parent then hook(d) end end)
	end
end
for _, d in playerGui:GetDescendants() do try(d) end
playerGui.DescendantAdded:Connect(try)
