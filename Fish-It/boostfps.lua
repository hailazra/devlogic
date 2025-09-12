-- Boost FPS Ultra Low - One-shot, No Restore, Aggressive
-- File: Fish-It/boostfpsFeature.lua
local boostfpsFeature = {}
boostfpsFeature.__index = boostfpsFeature

local Players    = game:GetService("Players")
local Lighting   = game:GetService("Lighting")
local Workspace  = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

function boostfpsFeature:Init()
    return true
end

local function isCharDescendant(inst)
    local ch = LocalPlayer and LocalPlayer.Character
    return ch and inst:IsDescendantOf(ch)
end

local function applyLightingUltra()
    pcall(function() Lighting.GlobalShadows = false end)
    pcall(function() Lighting.EnvironmentSpecularScale = 0 end)
    pcall(function() Lighting.EnvironmentDiffuseScale  = 0 end)
    -- Biar ga gelap setelah lights dimatiin:
    pcall(function() Lighting.Ambient         = Color3.fromRGB(170,170,170) end)
    pcall(function() Lighting.OutdoorAmbient  = Color3.fromRGB(170,170,170) end)
    -- Matikan seluruh post-effects
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") then
            pcall(function() child.Enabled = false end)
        elseif child:IsA("Atmosphere") then
            pcall(function()
                child.Density = 0
                child.Haze    = 0
                child.Glare   = 0
            end)
        elseif child:IsA("Sky") then
            pcall(function() child:Destroy() end) -- remove skybox (VRAM)
        end
    end
end

local function applyTerrainUltra()
    local t = Workspace:FindFirstChildOfClass("Terrain")
    if not t then return end
    pcall(function() t.Decoration       = false end)
    pcall(function() t.WaterWaveSize    = 0     end)
    pcall(function() t.WaterWaveSpeed   = 0     end)
    pcall(function() t.WaterReflectance = 0     end)
    pcall(function() t.WaterTransparency= 1     end)
end

local HEAVY_CLASSES_DISABLE = {
    ParticleEmitter = true,
    Trail           = true,
    Beam            = true,
    Fire            = true,
    Smoke           = true,
    Sparkles        = true,
    Highlight       = true,
    PointLight      = true,
    SpotLight       = true,
    SurfaceLight    = true,
}

local HEAVY_CLASSES_DESTROY = {
    SurfaceAppearance = true, -- PBR
    Decal             = true,
    Texture           = true, -- surface texture (bukan UI)
}

local function nukeWorldUltra()
    local processed = 0
    for _, inst in ipairs(Workspace:GetDescendants()) do
        processed += 1
        if (processed % 3000) == 0 then task.wait() end -- biar ga freeze

        -- Skip karakter player sendiri
        if isCharDescendant(inst) then
            continue
        end

        local cn = inst.ClassName
        -- 1) disable efek berat
        if HEAVY_CLASSES_DISABLE[cn] then
            if inst:IsA("ParticleEmitter") then
                pcall(function()
                    inst.Enabled = false
                    inst.Rate    = 0
                    inst.Lifetime = NumberRange.new(0,0)
                end)
            elseif inst:IsA("Beam") or inst:IsA("Trail") then
                pcall(function() inst.Enabled = false end)
            elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
                pcall(function()
                    inst.Enabled   = false
                    inst.Brightness= 0
                    inst.Range     = 0
                end)
            else
                pcall(function()
                    if inst.Enabled ~= nil then inst.Enabled = false end
                end)
            end

        -- 2) destroy aset tekstur/PBR
        elseif HEAVY_CLASSES_DESTROY[cn] then
            pcall(function() inst:Destroy() end)

        -- 3) sederhanakan part
        elseif inst:IsA("BasePart") then
            -- Kecualikan part di karakter lain? Ultra: tetap hajar (kecuali karakter kita)
            pcall(function()
                inst.Material     = Enum.Material.Plastic
                inst.Reflectance  = 0
                inst.CastShadow   = false
            end)
            -- MeshPart: pakai fidelity performa
            if inst:IsA("MeshPart") then
                pcall(function() inst.RenderFidelity = Enum.RenderFidelity.Performance end)
            end
        end
    end
end

function boostfpsFeature:Apply(config)
    -- optional: batasi FPS biar CPU nge-drop (kalau executor lo support)
    if typeof(getfenv) == "function" and typeof(setfpscap) == "function" then
        pcall(function() setfpscap(60) end) -- feel free 30–60
    end

    applyLightingUltra()
    applyTerrainUltra()
    nukeWorldUltra()

    -- NOTE: one-shot, no listeners; efek baru yang muncul setelah ini mungkin tetap tampil.
end

function boostfpsFeature:Cleanup() end

return boostfpsFeature
