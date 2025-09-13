-- Boost FPS Ultra-Low+ (Detexture) - One-shot, No Restore
-- File: Fish-It/boostfpsFeature.lua
local boostfpsFeature = {}
boostfpsFeature.__index = boostfpsFeature

local Players        = game:GetService("Players")
local Lighting       = game:GetService("Lighting")
local Workspace      = game:GetService("Workspace")
local MaterialService= game:GetService("MaterialService")
local LocalPlayer    = Players.LocalPlayer

-- === toggle opsional: set true kalau mau hapus gambar di Billboard/SurfaceGui juga
local AGGRESSIVE_GUI_IMAGES = false

function boostfpsFeature:Init() return true end

local function isLocalCharDescendant(inst)
    local ch = LocalPlayer and LocalPlayer.Character
    return ch and inst:IsDescendantOf(ch)
end

local function applyLightingUltra()
    pcall(function() Lighting.GlobalShadows = false end)
    pcall(function() Lighting.EnvironmentSpecularScale = 0 end)
    pcall(function() Lighting.EnvironmentDiffuseScale  = 0 end)
    pcall(function() Lighting.Ambient        = Color3.fromRGB(170,170,170) end)
    pcall(function() Lighting.OutdoorAmbient = Color3.fromRGB(170,170,170) end)

    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") then
            pcall(function() child.Enabled = false end)
        elseif child:IsA("Atmosphere") then
            pcall(function()
                child.Density = 0; child.Haze = 0; child.Glare = 0
            end)
        elseif child:IsA("Sky") then
            pcall(function() child:Destroy() end)
        end
    end
end

local function applyTerrainUltra()
    local t = Workspace:FindFirstChildOfClass("Terrain")
    if not t then return end
    pcall(function() t.Decoration        = false end)
    pcall(function() t.WaterWaveSize     = 0     end)
    pcall(function() t.WaterWaveSpeed    = 0     end)
    pcall(function() t.WaterReflectance  = 0     end)
    pcall(function() t.WaterTransparency = 1     end)
end

local function downgradeMaterialService()
    -- Matikan material 2022 & kosongkan peta tekstur MaterialVariant
    pcall(function() MaterialService.Use2022Materials = false end)
    for _, mv in ipairs(MaterialService:GetChildren()) do
        if mv.ClassName == "MaterialVariant" then
            pcall(function()
                mv.ColorMap     = ""
                mv.NormalMap    = ""
                mv.MetalnessMap = ""
                mv.RoughnessMap = ""
            end)
        end
    end
end

local HEAVY_DISABLE = {
    ParticleEmitter = true, Trail = true, Beam = true,
    Fire = true, Smoke = true, Sparkles = true,
    PointLight = true, SpotLight = true, SurfaceLight = true,
    Highlight = true,
}

local HEAVY_DESTROY = {
    SurfaceAppearance = true, -- PBR
    Decal = true, Texture = true, -- surface textures
}

local function detextureCharacter(model)
    -- Skip karakter lokal
    if LocalPlayer and model == LocalPlayer.Character then return end
    -- Hapus face & clothing
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Decal") and d.Name:lower() == "face" then
            pcall(function() d:Destroy() end)
        elseif d:IsA("Shirt") then
            pcall(function() d.ShirtTemplate = "" end)
        elseif d:IsA("Pants") then
            pcall(function() d.PantsTemplate = "" end)
        elseif d:IsA("ShirtGraphic") then
            pcall(function() d.Graphic = "" end)
        end
    end
end

local function nukeWorldUltraDetexture()
    local processed = 0
    for _, inst in ipairs(Workspace:GetDescendants()) do
        processed += 1
        if (processed % 4000) == 0 then task.wait() end

        -- 1) karakter selain kita -> buang tekstur pakaian/face
        if inst:IsA("Model") then
            local hum = inst:FindFirstChildOfClass("Humanoid")
            if hum then detextureCharacter(inst) end
        end

        -- 2) skip semua milik karakter kita
        if isLocalCharDescendant(inst) then
            continue
        end

        local cn = inst.ClassName

        -- 3) disable efek berat
        if HEAVY_DISABLE[cn] then
            if inst:IsA("ParticleEmitter") then
                pcall(function()
                    inst.Enabled = false
                    inst.Rate = 0
                    inst.Lifetime = NumberRange.new(0,0)
                end)
            elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
                pcall(function() inst.Enabled = false; inst.Brightness = 0; inst.Range = 0 end)
            else
                pcall(function() if inst.Enabled ~= nil then inst.Enabled = false end end)
            end

        -- 4) destroy aset tekstur/PBR
        elseif HEAVY_DESTROY[cn] then
            pcall(function() inst:Destroy() end)

        -- 5) sederhanakan semua BasePart
        elseif inst:IsA("BasePart") then
            pcall(function()
                inst.Material    = Enum.Material.Plastic
                inst.Reflectance = 0
                inst.CastShadow  = false
                inst.Color       = Color3.fromRGB(170,170,170) -- seragam, bantu cache
            end)

            if inst:IsA("MeshPart") then
                pcall(function()
                    -- kosongkan semua jejak tekstur
                    inst.TextureID       = ""
                    inst.MaterialVariant = ""
                    inst.UsePartColor    = true
                    inst.DoubleSided     = false
                    inst.RenderFidelity  = Enum.RenderFidelity.Performance
                    -- beberapa aksesori/npc pakai VertexColor untuk tint
                    if inst.VertexColor then inst.VertexColor = Vector3.new(1,1,1) end
                end)
            end

            -- SpecialMesh di dalam Part
            local sm = inst:FindFirstChildOfClass("SpecialMesh")
            if sm then
                pcall(function() sm.TextureId = "" end)
            end
        end

        -- 6) opsional: kosongkan gambar di signage 3D (hemat VRAM)
        if AGGRESSIVE_GUI_IMAGES then
            if inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
                for _, ui in ipairs(inst:GetDescendants()) do
                    if ui:IsA("ImageLabel") or ui:IsA("ImageButton") then
                        pcall(function()
                            ui.Image = ""
                            ui.ImageTransparency = 1
                        end)
                    end
                end
            end
        end
    end
end

function boostfpsFeature:Apply()
    -- Turunin FPS cap kalau tersedia (opsional)
    if typeof(setfpscap) == "function" then pcall(function() setfpscap(60) end) end

    applyLightingUltra()
    applyTerrainUltra()
    downgradeMaterialService()
    nukeWorldUltraDetexture()
end

function boostfpsFeature:Cleanup() end

return boostfpsFeature

