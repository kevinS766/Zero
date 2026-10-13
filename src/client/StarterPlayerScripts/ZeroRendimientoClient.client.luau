-- ZeroRendimientoClient (LocalScript, StarterPlayerScripts): MODO RENDIMIENTO de Ajustes (botón Settings.Body.Rendimiento).
-- Solo afecta a la pantalla de quien lo activa y se guarda con sus ajustes (atributo AjusteRendimiento, ZeroWheelServer):
--   · sombras globales apagadas (lo que más pesa en GPU);
--   · Bloom, SunRays, Blur y DepthOfField apagados (la corrección de color se queda: el juego mantiene su tono);
--   · luces de decoración (PointLight/SpotLight/SurfaceLight) apagadas: el lobby y los mapas traen ~90;
--   · carteles 3D (SurfaceGui) solo se dibujan a menos de 80 studs: hay más de 100 entre lobby y mapas
--     (los BillboardGui no: marcadores de power-ups y demás tienen que verse de lejos);
--   · partículas al 25 %, sin olas en el agua y sin nubes (también lo que aparece después: mapas nuevos, VFX).
-- Al desactivarlo se restaura todo tal cual estaba.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local ui = player:WaitForChild("PlayerGui"):WaitForChild("ZeroUI")
local boton = ui:WaitForChild("Modal"):WaitForChild("Settings"):WaitForChild("Body"):WaitForChild("Rendimiento") :: TextButton

local PARTICULAS = 0.25
local DISTANCIA_CARTELES = 80
local activo = false
local antes: { [Instance]: { [string]: any } } = {}   -- valor original de cada propiedad tocada (no usar claves débiles: Roblox suelta las Instance)
local conexiones: { RBXScriptConnection } = {}

local function poner(i: Instance, prop: string, valor: any)
	local t = antes[i]
	if not t then t = {}; antes[i] = t end
	if t[prop] == nil then t[prop] = (i :: any)[prop] end
	(i :: any)[prop] = valor
end

local function esPost(e: Instance): boolean
	return e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect")
end

local function reducir(e: Instance)
	if e:IsA("ParticleEmitter") then
		if not (antes[e] and antes[e].Rate) then poner(e, "Rate", e.Rate * PARTICULAS) end
	elseif e:IsA("Light") then
		poner(e, "Enabled", false)
	elseif e:IsA("SurfaceGui") then
		if e.MaxDistance == 0 or e.MaxDistance > DISTANCIA_CARTELES then poner(e, "MaxDistance", DISTANCIA_CARTELES) end
	elseif e:IsA("Clouds") then
		poner(e, "Enabled", false)
	end
end

local function aplicar(on: boolean)
	if on == activo then return end
	activo = on
	if on then
		poner(Lighting, "GlobalShadows", false)
		for _, e in Lighting:GetChildren() do if esPost(e) then poner(e, "Enabled", false) end end
		poner(workspace.Terrain, "WaterWaveSize", 0)
		for _, d in workspace:GetDescendants() do reducir(d) end
		table.insert(conexiones, workspace.DescendantAdded:Connect(reducir))
		-- los scripts de mapa encienden Bloom/SunRays/luces al cambiar de zona: con el modo activo se vuelven a apagar
		table.insert(conexiones, Lighting.DescendantAdded:Connect(function(e) if esPost(e) then poner(e, "Enabled", false) end end))
		-- los VFX se crean y destruyen todo el rato: se olvidan los que ya no existen
		task.spawn(function()
			while activo do
				task.wait(30)
				for i in antes do if not i.Parent and i ~= Lighting then antes[i] = nil end end
			end
		end)
	else
		for _, c in conexiones do c:Disconnect() end
		table.clear(conexiones)
		for i, props in antes do
			if i.Parent or i == Lighting then
				for prop, v in props do pcall(function() (i :: any)[prop] = v end) end
			end
		end
		table.clear(antes)
	end
	boton.Text = on and "MODO RENDIMIENTO: ACTIVADO" or "MODO RENDIMIENTO: DESACTIVADO"
	local label = boton:FindFirstChild("ButtonText"); if label then label.Text = boton.Text end
end

-- si un script de mapa vuelve a encender sombras o efectos con el modo activo, se apagan otra vez
for _, e in Lighting:GetChildren() do
	if esPost(e) then
		local fx = e :: any
		fx:GetPropertyChangedSignal("Enabled"):Connect(function()
			if activo and fx.Enabled then
				antes[fx] = antes[fx] or {}
				antes[fx].Enabled = true   -- el mapa lo quiere encendido: así queda al desactivar el modo
				fx.Enabled = false
			end
		end)
	end
end
Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function() if activo and Lighting.GlobalShadows then Lighting.GlobalShadows = false end end)

boton.Activated:Connect(function()
	local quiere = not activo
	aplicar(quiere)
	pcall(function() ReplicatedStorage:WaitForChild("ZeroUIRequest"):InvokeServer("GuardarAjustes", { rendimiento = quiere }) end)
end)

aplicar(player:GetAttribute("AjusteRendimiento") == true)
player:GetAttributeChangedSignal("AjusteRendimiento"):Connect(function() aplicar(player:GetAttribute("AjusteRendimiento") == true) end)
