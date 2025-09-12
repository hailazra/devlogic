-- Boost FPS (Reduce Graphics) - One-shot, No Restore
-- File: Fish-It/boostfpsFeature.lua
local boostfpsFeature = {}
boostfpsFeature.__index = boostfpsFeature

--// Services
local Lighting   = game:GetService("Lighting")
local Workspace  = game:GetService("Workspace")

--// No state / no snapshot: sekali jalan, selesai
function boostfpsFeature:Init()
    return true
end

local function applyLighting()
    -- Turunin kualitas pencahayaan & matiin post-effects yang ada sekarang
    pcall(function() Lighting.GlobalShadows = false end)
    pcall(function() Lighting.EnvironmentSpecularScale = 0 end)
    pcall(function() Lighting.EnvironmentDiffuseScale = 0 end)
    -- pcall(function() Lighting.Brightness = 1 end) -- opsional

    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") then
            pcall(function() child.Enabled = false end)
        end
    end
    -- Atmosphere biasanya sensitif. Kalau mau agresif:
    -- local atm = Lighting:FindFirstChildOfClass("Atmosphere")
    -- if atm then pcall(function() atm.Density = 0 end) end
end

local function applyTerrain()
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    pcall(function() terrain.Decoration      = false end)
    pcall(function() terrain.WaterWaveSize   = 0     end)
    pcall(function() terrain.WaterWaveSpeed  = 0     end)
    pcall(function() terrain.WaterReflectance= 0     end)
end

local function killVFX()
    -- Matikan particle/trail yang SUDAH ada sekarang (tanpa listener)
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("ParticleEmitter") then
            pcall(function()
                inst.Enabled = false
                inst.Rate    = 0
            end)
        elseif inst:IsA("Trail") then
            pcall(function() inst.Enabled = false end)
        end
    end
end

-- API one-time
function boostfpsFeature:Apply(config)
    applyLighting()
    applyTerrain()
    killVFX()

    -- OPTIONAL AGGRESSIVE (berat di game besar; komentarin kalau ga perlu):
    -- for _, part in ipairs(Workspace:GetDescendants()) do
    --     if part:IsA("BasePart") then
    --         pcall(function()
    --             part.CastShadow = false
    --             part.Reflectance = 0
    --             -- part.Material = Enum.Material.Plastic
    --         end)
    --     end
    -- end
end

-- Dipanggil FeatureManager saat UI ditutup — tidak perlu apa-apa.
function boostfpsFeature:Cleanup() end

return boostfpsFeature
