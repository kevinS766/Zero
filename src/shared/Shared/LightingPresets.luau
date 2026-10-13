--!strict
--[[
    LightingPresets.lua
    Catálogo de perfiles de iluminación para Zero.
    Permite alternar y ajustar la atmósfera visual sin sobreexponer ni quemar colores.
]]

local Lighting = game:GetService("Lighting")

export type PresetData = {
    Name: string,
    Description: string,
    Brightness: number,
    ClockTime: number,
    ExposureCompensation: number,
    Ambient: Color3,
    OutdoorAmbient: Color3,
    ColorShift_Top: Color3,
    ColorShift_Bottom: Color3,
    EnvironmentDiffuseScale: number,
    EnvironmentSpecularScale: number,
    ShadowSoftness: number,
    ColorCorrection: {
        Brightness: number,
        Contrast: number,
        Saturation: number,
        TintColor: Color3,
    },
    Bloom: {
        Intensity: number,
        Size: number,
        Threshold: number,
    },
    Atmosphere: {
        Density: number,
        Offset: number,
        Haze: number,
        Glare: number,
        Color: Color3,
        Decay: Color3,
    },
}

local LightingPresets = {}

LightingPresets.Presets = {
    [1] = {
        Name = "Toon Arcade Suave (Cel-Shaded)",
        Description = "Equilibrado, vibrante y limpio. Sombras nítidas y colores ricos sin quemar blancos (ideal con OutlinePlayer).",
        Brightness = 2.0,
        ClockTime = 14.5,
        ExposureCompensation = 0,
        Ambient = Color3.fromRGB(75, 80, 90),
        OutdoorAmbient = Color3.fromRGB(115, 125, 140),
        ColorShift_Top = Color3.fromRGB(255, 248, 240),
        ColorShift_Bottom = Color3.fromRGB(180, 195, 215),
        EnvironmentDiffuseScale = 0.5,
        EnvironmentSpecularScale = 0.5,
        ShadowSoftness = 0.7,
        ColorCorrection = {
            Brightness = 0.02,
            Contrast = 0.08,
            Saturation = 0.12,
            TintColor = Color3.fromRGB(255, 255, 255),
        },
        Bloom = {
            Intensity = 0.12,
            Size = 18,
            Threshold = 1.4,
        },
        Atmosphere = {
            Density = 0.30,
            Offset = 0.25,
            Haze = 0.50,
            Glare = 0.10,
            Color = Color3.fromRGB(210, 230, 255),
            Decay = Color3.fromRGB(110, 150, 200),
        },
    },

    [2] = {
        Name = "Frost Zero (Brisa Glacial)",
        Description = "Tema helado 'Below Zero'. Matices cian fríos, sol blanco puro, sombras azuladas profundas y aire cristalino.",
        Brightness = 1.85,
        ClockTime = 14.0,
        ExposureCompensation = 0,
        Ambient = Color3.fromRGB(60, 75, 95),
        OutdoorAmbient = Color3.fromRGB(90, 120, 155),
        ColorShift_Top = Color3.fromRGB(235, 248, 255),
        ColorShift_Bottom = Color3.fromRGB(170, 205, 240),
        EnvironmentDiffuseScale = 0.6,
        EnvironmentSpecularScale = 0.6,
        ShadowSoftness = 0.6,
        ColorCorrection = {
            Brightness = 0.01,
            Contrast = 0.10,
            Saturation = 0.05,
            TintColor = Color3.fromRGB(242, 248, 255),
        },
        Bloom = {
            Intensity = 0.15,
            Size = 22,
            Threshold = 1.3,
        },
        Atmosphere = {
            Density = 0.35,
            Offset = 0.20,
            Haze = 0.70,
            Glare = 0.15,
            Color = Color3.fromRGB(185, 220, 255),
            Decay = Color3.fromRGB(80, 125, 185),
        },
    },

    [3] = {
        Name = "Golden Hour (Atardecer Festivo)",
        Description = "Sol bajo y dorado en el horizonte, sombras largas y tonos cálidos acogedores para la feria.",
        Brightness = 2.1,
        ClockTime = 17.2,
        ExposureCompensation = 0,
        Ambient = Color3.fromRGB(85, 65, 75),
        OutdoorAmbient = Color3.fromRGB(130, 95, 95),
        ColorShift_Top = Color3.fromRGB(255, 200, 140),
        ColorShift_Bottom = Color3.fromRGB(130, 110, 145),
        EnvironmentDiffuseScale = 0.6,
        EnvironmentSpecularScale = 0.5,
        ShadowSoftness = 0.8,
        ColorCorrection = {
            Brightness = 0.01,
            Contrast = 0.12,
            Saturation = 0.15,
            TintColor = Color3.fromRGB(255, 248, 240),
        },
        Bloom = {
            Intensity = 0.18,
            Size = 24,
            Threshold = 1.2,
        },
        Atmosphere = {
            Density = 0.38,
            Offset = 0.30,
            Haze = 0.90,
            Glare = 0.25,
            Color = Color3.fromRGB(255, 195, 160),
            Decay = Color3.fromRGB(180, 85, 60),
        },
    },

    [4] = {
        Name = "Pastel Party (Soft Pop)",
        Description = "Estilo party game cremoso (Fall Guys). Sombras muy suaves, contraste bajo y cero fatiga visual.",
        Brightness = 1.65,
        ClockTime = 13.5,
        ExposureCompensation = 0.05,
        Ambient = Color3.fromRGB(105, 110, 120),
        OutdoorAmbient = Color3.fromRGB(140, 145, 160),
        ColorShift_Top = Color3.fromRGB(255, 250, 245),
        ColorShift_Bottom = Color3.fromRGB(210, 215, 225),
        EnvironmentDiffuseScale = 0.4,
        EnvironmentSpecularScale = 0.3,
        ShadowSoftness = 1.0,
        ColorCorrection = {
            Brightness = 0.02,
            Contrast = -0.04,
            Saturation = 0.02,
            TintColor = Color3.fromRGB(255, 255, 255),
        },
        Bloom = {
            Intensity = 0.08,
            Size = 15,
            Threshold = 1.6,
        },
        Atmosphere = {
            Density = 0.22,
            Offset = 0.15,
            Haze = 0.25,
            Glare = 0.05,
            Color = Color3.fromRGB(225, 235, 245),
            Decay = Color3.fromRGB(150, 180, 220),
        },
    },

    [5] = {
        Name = "Competitivo High-Clarity",
        Description = "Máxima visibilidad táctica, balance de blancos natural y sombras precisas sin distracciones cromáticas.",
        Brightness = 2.0,
        ClockTime = 14.0,
        ExposureCompensation = 0,
        Ambient = Color3.fromRGB(75, 75, 75),
        OutdoorAmbient = Color3.fromRGB(105, 105, 105),
        ColorShift_Top = Color3.fromRGB(255, 255, 255),
        ColorShift_Bottom = Color3.fromRGB(190, 190, 190),
        EnvironmentDiffuseScale = 0.8,
        EnvironmentSpecularScale = 0.7,
        ShadowSoftness = 0.5,
        ColorCorrection = {
            Brightness = 0,
            Contrast = 0.06,
            Saturation = 0.05,
            TintColor = Color3.fromRGB(255, 255, 255),
        },
        Bloom = {
            Intensity = 0.10,
            Size = 14,
            Threshold = 1.8,
        },
        Atmosphere = {
            Density = 0.25,
            Offset = 0.10,
            Haze = 0.30,
            Glare = 0.05,
            Color = Color3.fromRGB(205, 220, 240),
            Decay = Color3.fromRGB(120, 150, 190),
        },
    },
}

function LightingPresets.apply(presetId: number)
    local preset = LightingPresets.Presets[presetId]
    if not preset then
        warn(string.format("[LightingPresets] Preset %d no encontrado", presetId))
        return
    end

    -- Propiedades base de Lighting
    Lighting.Brightness = preset.Brightness
    Lighting.ClockTime = preset.ClockTime
    Lighting.ExposureCompensation = preset.ExposureCompensation
    Lighting.Ambient = preset.Ambient
    Lighting.OutdoorAmbient = preset.OutdoorAmbient
    Lighting.ColorShift_Top = preset.ColorShift_Top
    Lighting.ColorShift_Bottom = preset.ColorShift_Bottom
    Lighting.EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale
    Lighting.EnvironmentSpecularScale = preset.EnvironmentSpecularScale
    Lighting.ShadowSoftness = preset.ShadowSoftness

    -- Asegurar un único ColorCorrectionEffect
    local colorCorrections = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("ColorCorrectionEffect") then
            table.insert(colorCorrections, child)
        end
    end

    local cc = colorCorrections[1]
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "ColorCorrection"
        cc.Parent = Lighting
    end
    for i = 2, #colorCorrections do
        colorCorrections[i]:Destroy()
    end

    cc.Enabled = true
    cc.Brightness = preset.ColorCorrection.Brightness
    cc.Contrast = preset.ColorCorrection.Contrast
    cc.Saturation = preset.ColorCorrection.Saturation
    cc.TintColor = preset.ColorCorrection.TintColor

    -- BloomEffect
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "Bloom"
        bloom.Parent = Lighting
    end
    bloom.Enabled = true
    bloom.Intensity = preset.Bloom.Intensity
    bloom.Size = preset.Bloom.Size
    bloom.Threshold = preset.Bloom.Threshold

    -- Atmosphere
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere then
        atmosphere.Density = preset.Atmosphere.Density
        atmosphere.Offset = preset.Atmosphere.Offset
        atmosphere.Haze = preset.Atmosphere.Haze
        atmosphere.Glare = preset.Atmosphere.Glare
        atmosphere.Color = preset.Atmosphere.Color
        atmosphere.Decay = preset.Atmosphere.Decay
    end

    print(string.format("[LightingPresets] Aplicado preset #%d: %s", presetId, preset.Name))
end

return LightingPresets
