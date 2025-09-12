-- Boost FPS (Reduce Graphics) - Safe & Reversible
-- File: Fish-It/boostfpsFeature.lua
local boostfpsFeature = {}
boostfpsFeature.__index = boostfpsFeature

--// Services
local Lighting  = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

--// State
local inited  = false
local running = false

-- snapshot untuk restore
local _snap = {
    lighting = {},
    terrain  = {},
    effects  = {},   -- {inst -> {Enabled = bool}}
    particles = {},  -- {inst -> {Enabled = bool, Rate = number?}}
    conns    = {},   -- koneksi ChildAdded/DescendantAdded untuk matiin efek baru
}

--// Helpers
local function safeSet(inst, prop, val, bucket)
    local ok, old = pcall(function() return inst[prop] end)
    if ok then
        if bucket and _snap[bucket] and _snap[bucket][prop] == nil then
            _snap[bucket][prop] = old
        end
        pcall(function() inst[prop] = val end)
    end
end

local function snapshotProp(inst, prop, bag, key)
    local ok, old = pcall(function() return inst[prop] end)
    if ok then
        bag[key or prop] = old
    end
end

local function isPostEffect(inst)
    -- PostEffect adalah base class untuk Blur, Bloom, ColorCorrection, SunRays, DOF
    return inst:IsA("PostEffect")
end

local function disableLightingEffects()
    -- Simpan properti Lighting penting lalu turunkan kualitas
    local L = _snap.lighting
    snapshotProp(Lighting, "GlobalShadows", L)
    snapshotProp(Lighting, "EnvironmentSpecularScale", L)
    snapshotProp(Lighting, "EnvironmentDiffuseScale", L)
    snapshotProp(Lighting, "Brightness", L)

    safeSet(Lighting, "GlobalShadows", false, "lighting")
    safeSet(Lighting, "EnvironmentSpecularScale", 0, "lighting")
    safeSet(Lighting, "EnvironmentDiffuseScale", 0, "lighting")
    -- Biarkan Brightness apa adanya untuk keterbacaan; kalau mau makin redup:
    -- safeSet(Lighting, "Brightness", 1, "lighting")

    -- Matikan semua post-effect yang ada di Lighting sekarang
    for _, child in ipairs(Lighting:GetChildren()) do
        if isPostEffect(child) then
            _snap.effects[child] = { Enabled = child.Enabled }
            pcall(function() child.Enabled = false end)
        end
    end

    -- Jika ada efekt baru setelah start, auto-disable (disimpan di conns)
    table.insert(_snap.conns, Lighting.ChildAdded:Connect(function(child)
        if running and isPostEffect(child) then
            _snap.effects[child] = { Enabled = child.Enabled }
            pcall(function() child.Enabled = false end)
        end
    end))

    -- Atmosphere cenderung sensitif; default ga diutak-atik. Kalau mau agresif:
    -- local atm = Lighting:FindFirstChildOfClass("Atmosphere")
    -- if atm then
    --     _snap.effects[atm] = { Density = atm.Density }
    --     pcall(function() atm.Density = 0 end)
    -- end
end

local function simplifyTerrain()
    local t = Workspace:FindFirstChildOfClass("Terrain")
    if not t then return end
    local T = _snap.terrain
    snapshotProp(t, "Decoration", T)
    snapshotProp(t, "WaterWaveSize", T)
    snapshotProp(t, "WaterWaveSpeed", T)
    snapshotProp(t, "WaterReflectance", T)
    -- WaterTransparency sering diatur game; biarkan default

    safeSet(t, "Decoration", false, "terrain")
    safeSet(t, "WaterWaveSize", 0, "terrain")
    safeSet(t, "WaterWaveSpeed", 0, "terrain")
    safeSet(t, "WaterReflectance", 0, "terrain")
end

local function killParticlesOnce()
    -- Matikan ParticleEmitter/Trail (umum boros) secara agresif
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("ParticleEmitter") then
            _snap.particles[inst] = { Enabled = inst.Enabled, Rate = inst.Rate }
            pcall(function()
                inst.Enabled = false
                inst.Rate = 0
            end)
        elseif inst:IsA("Trail") then
            _snap.particles[inst] = { Enabled = inst.Enabled }
            pcall(function() inst.Enabled = false end)
        end
    end

    -- Jika ada particles baru, langsung matiin
    table.insert(_snap.conns, Workspace.DescendantAdded:Connect(function(inst)
        if not running then return end
        if inst:IsA("ParticleEmitter") then
            _snap.particles[inst] = { Enabled = inst.Enabled, Rate = inst.Rate }
            pcall(function()
                inst.Enabled = false
                inst.Rate = 0
            end)
        elseif inst:IsA("Trail") then
            _snap.particles[inst] = { Enabled = inst.Enabled }
            pcall(function() inst.Enabled = false end)
        end
    end))
end

local function restoreAll()
    -- Restore Lighting props
    for prop, old in pairs(_snap.lighting) do
        pcall(function() Lighting[prop] = old end)
    end

    -- Restore Terrain props
    local t = Workspace:FindFirstChildOfClass("Terrain")
    if t then
        for prop, old in pairs(_snap.terrain) do
            pcall(function() t[prop] = old end)
        end
    end

    -- Restore effects
    for inst, data in pairs(_snap.effects) do
        if inst and inst.Parent then
            for k, v in pairs(data) do
                pcall(function() inst[k] = v end)
            end
        end
    end

    -- Restore particles
    for inst, data in pairs(_snap.particles) do
        if inst and inst.Parent then
            for k, v in pairs(data) do
                pcall(function() inst[k] = v end)
            end
        end
    end

    -- Disconnect signals
    for _, c in ipairs(_snap.conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(_snap.conns)

    -- Bersihkan snapshot
    table.clear(_snap.lighting)
    table.clear(_snap.terrain)
    table.clear(_snap.effects)
    table.clear(_snap.particles)
end

-- === lifecycle ===
function boostfpsFeature:Init(guiControls)
    if inited then return true end
    -- Tidak butuh dependency khusus; cukup tandai siap
    inited = true
    return true
end

-- config.preset: "Low" | "UltraLow"
function boostfpsFeature:Start(config)
    if running then return end
    if not inited then
        local ok = self:Init()
        if not ok then return end
    end
    running = true

    local preset = (type(config) == "table" and config.preset) or "Low"

    -- baseline reduce
    disableLightingEffects()
    simplifyTerrain()

    if preset == "UltraLow" then
        -- agresif: matikan particle/trail dan cegah yang baru
        killParticlesOnce()
    end
end

function boostfpsFeature:Stop()
    if not running then return end
    running = false
    restoreAll()
end

function boostfpsFeature:Cleanup()
    self:Stop()
end

return boostfpsFeature
