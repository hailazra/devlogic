--========================================================
-- autofavoritefish.lua
--========================================================
-- Fitur:
--  - Ambil daftar Tier dari ReplicatedStorage.Tiers
--  - Scan inventory kategori Fishes (via watcher kamu / fallback Replion)
--  - Favorite ikan sesuai tier pilihan user, hanya jika belum Favorited
--  - Batch + delay, bisa stop/resume
-- Interface wajib: :Init, :Start, :Stop, :Cleanup
-- Setter/helper:   :GetTierNames(), :SetDesiredTiersByNames(tbl)
--========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- ---------- Util: find sleitnick net ----------
local function findNetRoot()
    local Packages = ReplicatedStorage:FindFirstChild("Packages")
    if not Packages then return end
    local _Index = Packages:FindFirstChild("_Index")
    if not _Index then return end
    for _, pkg in ipairs(_Index:GetChildren()) do
        if pkg:IsA("Folder") and pkg.Name:match("^sleitnick_net@") then
            local net = pkg:FindFirstChild("net")
            if net then return net end
        end
    end
end

local function getRemote(name)
    local net = findNetRoot()
    if net then
        local r = net:FindFirstChild(name)
        if r then return r end
    end
    return ReplicatedStorage:FindFirstChild(name, true)
end

-- ---------- Dep libs ----------
local ItemUtility = nil
pcall(function() ItemUtility = require(ReplicatedStorage.Shared.ItemUtility) end)

local TierUtility = nil
pcall(function() TierUtility = require(ReplicatedStorage.Shared.TierUtility) end)

-- ---------- Build tier maps ----------
local function buildTierMaps()
    local list = {}
    local byNum = {}
    local byName = {}

    local Tiers = ReplicatedStorage:FindFirstChild("Tiers")
    if Tiers and Tiers:IsA("ModuleScript") then
        local ok, arr = pcall(require, Tiers)
        if ok and type(arr) == "table" then
            for _, t in ipairs(arr) do
                if type(t) == "table" and t.Name and t.Tier then
                    byNum[tonumber(t.Tier)] = tostring(t.Name)
                    byName[tostring(t.Name)] = tonumber(t.Tier)
                    table.insert(list, tostring(t.Name))
                end
            end
        end
    end
    -- urutkan (opsional): SECRET/Mythic/Legendary dsb sesuai Tier desc
    table.sort(list, function(a,b) return (byName[a] or 0) > (byName[b] or 0) end)
    return list, byNum, byName
end

-- ---------- Watcher helper (inject dari kamu kalau ada) ----------
local function tryGetWatcherFromGlobal()
    -- kalau kamu expose watcher di _G, ambil dari sana
    local w = rawget(_G, "InventoryWatcherInstance") or rawget(_G, "invWatcher") or rawget(_G, "INV_WATCHER")
    if w and type(w) == "table" and w.getSnapshot then return w end
    return nil
end

local function tryAutoLoadWatcher()
    -- fallback: load watcher kamu dari repo kalau kamu publish. Atau langsung Replion mini-watcher.
    local Replion = nil
    local Constants = nil
    pcall(function() Replion   = require(ReplicatedStorage.Packages.Replion) end)
    pcall(function() Constants = require(ReplicatedStorage.Shared.Constants) end)
    if not Replion then return nil end

    local W = {}
    W._data = nil
    function W:getSnapshot(typeName)
        if not self._data then return {} end
        local path = {"Inventory", typeName or "Fishes"}
        local ok, arr = pcall(function() return self._data:Get(path) end)
        return (ok and type(arr)=="table") and arr or {}
    end
    function W:getSnapshotTyped(typeName) return self:getSnapshot(typeName) end

    Replion.Client:AwaitReplion("Data", function(data)
        W._data = data
    end)
    return W
end

-- ---------- Core feature ----------
local Feature = {
    _running      = false,
    _enabled      = false,
    _delay        = 0.10,
    _maxPerTick   = 15,
    _targetsSet   = {},     -- set by tier name: e.g., ["SECRET"]=true
    _tierNames    = {},     -- array
    _tierNameByNo = {},     -- num -> name
    _tierNoByName = {},     -- name -> num
    _watcher      = nil,
    _conns        = {},
    _ui           = { dropdown=nil, toggle=nil },
}

local REMOTE_FAVORITE = "RE/FavoriteItem"

-- Resolve tier number for a fish Id using ItemUtility (prefer .Data.Tier; fallback Probability -> TierUtility)
function Feature:_resolveFishTierNumber(fishId)
    if not ItemUtility then return nil end
    local ok, data = pcall(function()
        if ItemUtility.GetItemDataFromItemType then
            return ItemUtility:GetItemDataFromItemType("Fishes", fishId)
        end
        return nil
    end)
    if ok and data and data.Data then
        if data.Data.Tier then
            return tonumber(data.Data.Tier)
        end
        if TierUtility and data.Probability and data.Probability.Chance then
            local num = TierUtility:GetTierFromRarity(data.Probability.Chance)
            return tonumber(num)
        end
    end
    return nil
end

function Feature:_favoriteOne(uuid)
    local ev = getRemote(REMOTE_FAVORITE)
    if not ev or not ev:IsA("RemoteEvent") then
        warn("[autofavoritefish] FavoriteItem remote not found")
        return false
    end
    local ok = pcall(function()
        ev:FireServer(uuid)
    end)
    if not ok then
        warn("[autofavoritefish] FavoriteItem FireServer failed for", uuid)
    end
    return ok
end

function Feature:_runTick()
    -- ambil snapshot Fishes
    local fishes
    if self._watcher and self._watcher.getSnapshotTyped then
        fishes = self._watcher:getSnapshotTyped("Fishes")
    elseif self._watcher then
        fishes = self._watcher:getSnapshot("Fishes")
    else
        fishes = {}
    end

    local done = 0
    for _, entry in ipairs(fishes) do
        if not self._enabled then break end
        if type(entry) == "table" then
            local uuid = entry.UUID or entry.Uuid or entry.uuid
            local id   = entry.Id
            local alreadyFav = (entry.Favorited == true) -- penting: hindari toggle balik (lihat Inventory UI)
            if uuid and id and not alreadyFav then
                local tierNo = self:_resolveFishTierNumber(id)
                local tName  = tierNo and self._tierNameByNo[tierNo] or nil
                if tName and self._targetsSet[tName] then
                    if self:_favoriteOne(uuid) then
                        done += 1
                        if done >= self._maxPerTick then break end
                        task.wait(self._delay)
                    end
                end
            end
        end
    end
    return done
end

-- ===== Interface =====
function Feature:Init(controls)
    self._tierNames, self._tierNameByNo, self._tierNoByName = buildTierMaps()

    -- simpan kontrol (kalau ada)
    self._ui.dropdown = controls and controls.dropdown or nil
    self._ui.toggle   = controls and controls.toggle or nil

    -- watcher: prefer inject global; fallback auto
    self._watcher = tryGetWatcherFromGlobal() or tryAutoLoadWatcher()

    -- kalau dropdown mendukung SetValues, isi dengan daftar tier dari game
    if self._ui.dropdown and self._ui.dropdown.SetValues then
        self._ui.dropdown:SetValues(self._tierNames)
    end

    return true
end

function Feature:GetTierNames()
    return self._tierNames
end

function Feature:SetDesiredTiersByNames(names)
    self._targetsSet = {}
    for _, name in ipairs(names or {}) do
        if self._tierNoByName[name] then
            self._targetsSet[name] = true
        else
            warn("[autofavoritefish] unknown tier name:", name)
        end
    end
end

function Feature:Start(opts)
    if self._enabled then return end
    self._enabled = true
    self._delay      = tonumber(opts and opts.delay) or self._delay
    self._maxPerTick = tonumber(opts and opts.maxPerTick) or self._maxPerTick

    -- inisialisasi target dari opsi (kalau belum diset via setter)
    if opts and opts.tierNames and #opts.tierNames > 0 then
        self:SetDesiredTiersByNames(opts.tierNames)
    end
    if next(self._targetsSet) == nil then
        warn("[autofavoritefish] no target tiers set; stopping")
        self._enabled = false
        return
    end

    task.spawn(function()
        while self._enabled do
            local n = self:_runTick()
            -- kalau nggak ada yang dikerjain, jeda sedikit lebih lama
            task.wait((n == 0) and 0.35 or 0.05)
        end
    end)
end

function Feature:Stop()
    self._enabled = false
end

function Feature:Cleanup()
    self._enabled = false
    -- nothing to disconnect specifically; rely on GC
end

return Feature
