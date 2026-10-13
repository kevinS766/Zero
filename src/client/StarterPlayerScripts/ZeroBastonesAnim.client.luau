-- ZeroBastonesAnim (LocalScript, StarterPlayerScripts): anima las piezas móviles de los bastones míticos (etiqueta
-- "ZeroAnimPieza", ver preparar_bastones.luau) igual que en Blender:
--   girar      -> AnimValor grados por ciclo alrededor del eje
--   balancear  -> ±AnimValor grados (seno) alrededor del eje
--   flotar     -> ±AnimValor studs a lo largo del eje
-- El eje y el pivote salen de los Attachments Pivote_<X> / PivoteEje_<X> del Cuerpo, así siguen al bastón esté donde
-- esté (en la mano, en una vitrina). Si la pieza está soldada (no anclada) se mueve su AnimWeld; si está anclada, su
-- CFrame. Solo se anima lo que está cerca de la cámara.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TAG, CERCA = "ZeroAnimPieza", 150

local function pose(part: BasePart, t: number)
	local cuerpo = part.Parent and part.Parent:FindFirstChild("Cuerpo")
	local nombre = part:GetAttribute("AnimNombre")
	local reposo = part:GetAttribute("AnimReposo")
	if not cuerpo or not nombre or typeof(reposo) ~= "CFrame" then return end
	local a0, a1 = cuerpo:FindFirstChild("Pivote_" .. nombre), cuerpo:FindFirstChild("PivoteEje_" .. nombre)
	if not a0 or not a1 then return end
	local P, eje = a0.Position, (a1.Position - a0.Position).Unit
	local f = (t / (part:GetAttribute("AnimCiclo") or 4) + (part:GetAttribute("AnimFase") or 0)) % 1
	local v, tipo = part:GetAttribute("AnimValor") or 0, part:GetAttribute("AnimTipo")
	local d
	if tipo == "girar" then
		d = CFrame.new(P) * CFrame.fromAxisAngle(eje, math.rad(v) * f) * CFrame.new(-P)
	elseif tipo == "balancear" then
		d = CFrame.new(P) * CFrame.fromAxisAngle(eje, math.rad(v) * math.sin(2 * math.pi * f)) * CFrame.new(-P)
	else
		d = CFrame.new(eje * v * math.sin(2 * math.pi * f))
	end
	return cuerpo, d * reposo
end

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local t = os.clock()
	for _, part in CollectionService:GetTagged(TAG) do
		if part:IsDescendantOf(workspace) and (part.Position - cam.CFrame.Position).Magnitude < CERCA then
			local cuerpo, rel = pose(part, t)
			if cuerpo then
				local w = part:FindFirstChild("AnimWeld")
				if w and w:IsA("Weld") and not part.Anchored then w.C0 = rel else part.CFrame = cuerpo.CFrame * rel end
			end
		end
	end
end)
