--========================================================
-- autofavoritefishFeature.lua
--========================================================
-- Interface: :Init(controls), :Start(config), :Stop(), :Cleanup()
-- Setter/aksi khusus fitur:
--   :SetDesiredTiersByNames(namesTbl)   -- contoh: {"Legendary","Mythic","SECRET"}
--   :GetTierNames() -> { "Common", "Uncommon", ... }
--========================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- -------- sleitnick net remotes ----------
local function findNetRoot()
    local Packages = ReplicatedStorage:FindFirstChild("Packages"); if not Packages then return end
    local _Index   = Packages:FindFirstChild("_Index"); if not _Index then return end
    for _, pkg in ipairs(_Index:GetChildren()) do
        if pkg:IsA("Folder") and pkg.Name:match("^sleitnick_net@") then
            local net = pkg:FindFirstChild("net")
            if net then return net end
        end
    end
end

local function getRemote(path)
    local net = findNetRoot()
    if net then
        local r = net:FindFirstChild(path)
        if r then return r end
    end
    return ReplicatedStorage:FindFirstChild(path, true)
end

local REMOTE_FAVORITE = "RE/FavoriteItem"

-- -------- ItemUtility helpers ----------
local function safeRequireItemUtility()
    local ok, IU = pcall(function() return require(ReplicatedStorage.Shared.ItemUtility) end)
    if ok then return IU end
    return nil
end

local function IU_call(IU, method, ...)
    if not IU then return nil end
    local f = IU[method]
    if type(f) ~= "function" then return nil end
    local ok, res = pcall(f, IU, ...)
    if ok then return res end
    return nil
end

-- -------- Tier index (Tier# <-> Name) ----------
local function buildTierIndex()
    local byNum, byName, ordered = {}, {}, {}
    local ok, tiers = pcall(function() return require(ReplicatedStorage:WaitForChild("Tiers")) end)
    if ok and type(tiers) == "table" then
        for _, t in ipairs(tiers) do
            if t and t.Tier and t.Name then
                byNum[t.Tier]      = t.Name
                byName[t.Name]     = t.Tier
                table.insert(ordered, t.Name)
            end
        end
        table.sort(ordered, function(a,b)
            return (byName[a] or 99) < (byName[b] or 99)
        end)
    end
    return byNum, byName, ordered
end

-- -------- Fish data lookup ----------
local function getFishTierById(id, IU)
    -- 1) coba via ItemUtility
    local d = IU_call(IU, "GetItemDataFromItemType", "Fishes", id)
    if d and d.Data and d.Data.Tier then return d.Data.Tier end
    -- 2) fallback generic
    d = IU_call(IU, "GetItemData", id)
    if d and d.Data and d.Data.Type == "Fishes" and d.Data.Tier then return d.Data.Tier end
    -- 3) fallback require dari folder Items
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if itemsFolder then
        for _, ms in ipairs(itemsFolder:GetChildren()) do
            if ms:IsA("ModuleScript") then
                local ok2, mod = pcall(require, ms)
                if ok2 and type(mod)=="table" and mod.Data and mod.Data.Id == id and mod.Data.Type == "Fishes" then
                    return mod.Data.Tier
                end
            end
        end
    end
    return nil
end

-- -------- Watcher fallback (minimal) ----------
local Replion = nil
local function minimalFishesProvider(onChanged)
    -- fallback sederhana kalau watcher tidak diinject
    local fishes = {}
    local function getNow() return fishes end
    -- try subscribe to Replion Data
    local ok, pkg = pcall(function() return require(ReplicatedStorage.Packages.Replion) end)
    if ok and pkg and pkg.Client then
        Replion = pkg
        pkg.Client:AwaitReplion("Data", function(data)
            local function resnap()
                local arr = nil
                local ok2, got = pcall(function() return data:Get({"Inventory","Fishes"}) end)
                if ok2 and type(got)=="table" then arr = got else arr = {} end
                fishes = arr
                if onChanged then onChanged() end
            end
            data:OnChange({"Inventory","Fishes"}, resnap)
            data:OnArrayInsert({"Inventory","Fishes"}, resnap)
            data:OnArrayRemove({"Inventory","Fishes"}, resnap)
            resnap()
        end)
    end
    return { getFishes = getNow, destroy = function() end }
end

--========================================================
-- Feature Class
--========================================================
local Feature = {}
Feature.__index = Feature

function Feature:Init(controls)
    controls = controls or {}
    -- watcher optional (disarankan): harus punya getSnapshotTyped("Fishes") atau getSnapshot("Fishes")
    self._watcher = controls.watcher
    -- index tier
    self._tierNum2Name, self._tierName2Num, self._tierNamesOrdered = buildTierIndex()
    -- desired tiers (set num)
    self._targets = {}       -- [tierNum]=true
    -- rate/loop
    self._enabled = false
    self._running = false
    self._delay   = 0.12     -- jeda antar FavoriteItem
    self._maxPerTick = 10    -- batasi per siklus
    -- processed UUID guard
    self._processed = {}     -- [uuid]=true
    -- ItemUtility cache
    self._IU = safeRequireItemUtility()
    -- fallback provider jika watcher tidak ada
    self._fallback = nil
    if not self._watcher then
        self._fallback = minimalFishesProvider(function()
            -- on change; kita gak trigger apa-apa di sini, loop akan nge-scan
        end)
    end
    return true
end

function Feature:GetTierNames()
    return table.clone(self._tierNamesOrdered)
end

function Feature:SetDesiredTiersByNames(names)
    self._targets = {}
    for _, nm in ipairs(names or {}) do
        local n = self._tierName2Num[nm]
        if n then self._targets[n] = true end
    end
end

function Feature:_currentFishes()
    -- Prioritas typed watcher → anti “ikan nyasar”
    if self._watcher and self._watcher.getSnapshotTyped then
        return self._watcher:getSnapshotTyped("Fishes")
    end
    if self._watcher and self._watcher.getSnapshot then
        return self._watcher:getSnapshot("Fishes")
    end
    if self._fallback then
        return self._fallback.getFishes()
    end
    return {}
end

function Feature:_isFavorited(entry)
    local m = entry and entry.Metadata
    if type(m) ~= "table" then return false end
    return (m.Favorited == true) or (m.Favorite == true) or (m.IsFavorite == true)
end

function Feature:_doFavorite(uuid)
    local r = getRemote(REMOTE_FAVORITE)
    if not r then return false end
    local ok = pcall(function() r:FireServer(uuid) end)
    return ok
end

function Feature:_processBatch()
    local fishes = self:_currentFishes()
    local done = 0
    for _, entry in ipairs(fishes) do
        if done >= self._maxPerTick then break end
        local uuid = entry and (entry.UUID or entry.Uuid or entry.uuid)
        local id   = entry and (entry.Id   or entry.id)
        if uuid and id and not self._processed[uuid] then
            -- skip kalau sudah favorit (kalau metadata tersedia)
            if not self:_isFavorited(entry) then
                local tierNum = getFishTierById(id, self._IU)
                if tierNum and self._targets[tierNum] then
                    if self:_doFavorite(uuid) then
                        self._processed[uuid] = true
                        done += 1
                        task.wait(self._delay)
                    end
                else
                    -- bukan target -> tandai processed agar tidak discan berkali-kali
                    self._processed[uuid] = true
                end
            else
                -- sudah favorit
                self._processed[uuid] = true
            end
        end
        if not self._enabled then break end
    end
    return done
end

function Feature:Start(config)
    if self._enabled then return end
    config = config or {}
    -- setter via Start (opsional)
    if config.tierNames then self:SetDesiredTiersByNames(config.tierNames) end
    if tonumber(config.delay) then self._delay = tonumber(config.delay) end
    if tonumber(config.maxPerTick) then self._maxPerTick = tonumber(config.maxPerTick) end

    -- safety: butuh minimal 1 target
    local any = false; for _ in pairs(self._targets) do any = true break end
    if not any then
        warn("[autofavoritefish] no tiers selected; Start aborted.")
        return
    end

    -- reset processed agar run baru tetap memproses ikan baru/yang lama
    self._processed = {}

    self._enabled = true
    task.spawn(function()
        if self._running then return end
        self._running = true
        while self._enabled do
            local n = self:_processBatch()
            -- kalau tidak ada kerja, tidur agak lama dikit, supaya nge-pick ikan baru
            if n == 0 then task.wait(0.5) end
        end
        self._running = false
    end)
end

function Feature:Stop()
    self._enabled = false
end

function Feature:Cleanup()
    self._enabled = false
    if self._fallback and self._fallback.destroy then
        self._fallback.destroy()
        self._fallback = nil
    end
end

return Feature
