-- autofavoritefish.lua (patched)
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- --- net helpers ---
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
local function getRemote(name)
    local net = findNetRoot()
    if net then
        local r = net:FindFirstChild(name)
        if r then return r end
    end
    return ReplicatedStorage:FindFirstChild(name, true)
end

-- --- deps (opsional) ---
local ItemUtility = nil
pcall(function() ItemUtility = require(ReplicatedStorage.Shared.ItemUtility) end)
local TierUtility = nil
pcall(function() TierUtility = require(ReplicatedStorage.Shared.TierUtility) end)

-- --- build tier maps from ReplicatedStorage.Tiers ---
local function buildTierMaps()
    local names, byNum, byName = {}, {}, {}
    local ms = ReplicatedStorage:FindFirstChild("Tiers")
    if ms and ms:IsA("ModuleScript") then
        local ok, arr = pcall(require, ms)
        if ok and type(arr) == "table" then
            for _, t in ipairs(arr) do
                if t and t.Name and t.Tier then
                    byNum[tonumber(t.Tier)]  = tostring(t.Name)
                    byName[tostring(t.Name)] = tonumber(t.Tier)
                    table.insert(names, tostring(t.Name))
                end
            end
        end
    end
    table.sort(names, function(a,b) return (byName[a] or 0) > (byName[b] or 0) end)
    return names, byNum, byName
end

-- --- fallback fish DB from ReplicatedStorage.Items ---
local FishDB_ById = nil
local function buildFishDB()
    FishDB_ById = {}
    local folder = ReplicatedStorage:FindFirstChild("Items")
    if not folder then return end
    for _, ms in ipairs(folder:GetChildren()) do
        if ms:IsA("ModuleScript") then
            local ok, mod = pcall(require, ms)
            if ok and type(mod) == "table" and mod.Data and mod.Data.Id and mod.Data.Type == "Fishes" then
                FishDB_ById[tonumber(mod.Data.Id)] = {
                    Tier = tonumber(mod.Data.Tier),
                    Name = tostring(mod.Data.Name or ms.Name),
                }
            end
        end
    end
end

-- --- watcher fallback (min) ---
local function tryGetWatcherFromGlobal()
    return rawget(_G,"InventoryWatcherInstance") or rawget(_G,"invWatcher") or rawget(_G,"INV_WATCHER")
end
local function tryAutoLoadWatcher()
    local Replion = nil
    pcall(function() Replion = require(ReplicatedStorage.Packages.Replion) end)
    if not Replion then return nil end
    local W = { _data=nil }
    function W:getSnapshot(typeName)
        if not self._data then return {} end
        local ok, arr = pcall(function() return self._data:Get({"Inventory", typeName or "Fishes"}) end)
        return (ok and type(arr)=="table") and arr or {}
    end
    function W:getSnapshotTyped(typeName) return self:getSnapshot(typeName) end
    Replion.Client:AwaitReplion("Data", function(d) W._data = d end)
    return W
end

-- --- feature ---
local Feature = {
    _enabled=false, _running=false,
    _delay=0.10, _maxPerTick=15,
    _targetsSet={},              -- ["Legendary"]=true, ...
    _tierNames={}, _tierNameByNo={}, _tierNoByName={},
    _watcher=nil, _ui={dropdown=nil,toggle=nil},
}

local REMOTE_FAVORITE = "RE/FavoriteItem"

-- robust favorite flag check
local function isFavoritedEntry(entry)
    if not entry then return false end
    if entry.Favorited == true or entry.Favorite == true or entry.IsFavorite == true then return true end
    local m = entry.Metadata
    if type(m)=="table" and (m.Favorited==true or m.Favorite==true or m.IsFavorite==true) then return true end
    return false
end

-- resolve tier number for a fish Id with robust fallbacks
function Feature:_resolveFishTierNumber(fishId)
    fishId = tonumber(fishId)
    -- 1) ItemUtility (fast path)
    if ItemUtility and ItemUtility.GetItemDataFromItemType then
        local ok, d = pcall(function() return ItemUtility:GetItemDataFromItemType("Fishes", fishId) end)
        if ok and d and d.Data and d.Data.Tier then return tonumber(d.Data.Tier) end
        if ok and d and d.Probability and d.Probability.Chance and TierUtility then
            local num = TierUtility:GetTierFromRarity(d.Probability.Chance)
            if num then return tonumber(num) end
        end
    end
    -- 2) fallback DB (ReplicatedStorage.Items)
    if FishDB_ById == nil then buildFishDB() end
    local rec = FishDB_ById and FishDB_ById[fishId]
    if rec and rec.Tier then return tonumber(rec.Tier) end
    return nil
end

function Feature:_favoriteOne(uuid)
    local ev = getRemote(REMOTE_FAVORITE)
    if not ev or not ev:IsA("RemoteEvent") then
        warn("[autofavoritefish] FavoriteItem remote not found")
        return false
    end
    local ok = pcall(function() ev:FireServer(uuid) end)
    if not ok then warn("[autofavoritefish] FavoriteItem FireServer failed", uuid) end
    return ok
end

-- try to pre-arm "Favorite mode" if such a remote exists
function Feature:_preArmFavoriteMode()
    local net = findNetRoot()
    if not net then return end
    -- candidates by name
    local candidates = {}
    for _, obj in ipairs(net:GetChildren()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name
            if n:find("Favorite") and (n:find("Mode") or n:find("Toggle") or n:find("Enable") or n:find("State")) and n ~= "RE/FavoriteStateChanged" then
                table.insert(candidates, obj)
            end
        end
    end
    for _, rem in ipairs(candidates) do
        -- coba beberapa pola argumen umum
        pcall(function() rem:FireServer(true) end)
        pcall(function() rem:FireServer("Enable") end)
        pcall(function() rem:FireServer({Enabled=true}) end)
    end
end

function Feature:_runTick()
    local fishes
    if self._watcher and self._watcher.getSnapshotTyped then
        fishes = self._watcher:getSnapshotTyped("Fishes")
    elseif self._watcher and self._watcher.getSnapshot then
        fishes = self._watcher:getSnapshot("Fishes")
    else
        fishes = {}
    end

    local done = 0
    for _, entry in ipairs(fishes) do
        if not self._enabled then break end
        if type(entry)=="table" then
            local uuid = entry.UUID or entry.Uuid or entry.uuid
            local id   = entry.Id or entry.id
            if uuid and id and not isFavoritedEntry(entry) then
                local tierNo = self:_resolveFishTierNumber(id)
                local tName  = tierNo and self._tierNameByNo[tierNo]
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

-- ===== interface =====
function Feature:Init(controls)
    self._tierNames, self._tierNameByNo, self._tierNoByName = buildTierMaps()
    self._ui.dropdown = controls and controls.dropdown or nil
    self._ui.toggle   = controls and controls.toggle   or nil
    self._watcher     = tryGetWatcherFromGlobal() or tryAutoLoadWatcher()
    if self._ui.dropdown and self._ui.dropdown.SetValues then
        self._ui.dropdown:SetValues(self._tierNames)
    end
    return true
end

function Feature:GetTierNames() return self._tierNames end

function Feature:SetDesiredTiersByNames(names)
    self._targetsSet = {}
    for _, nm in ipairs(names or {}) do
        if self._tierNoByName[nm] then self._targetsSet[nm] = true end
    end
end

function Feature:Start(opts)
    if self._enabled then return end
    opts = opts or {}
    if opts.tierNames and #opts.tierNames>0 then self:SetDesiredTiersByNames(opts.tierNames) end
    self._delay      = tonumber(opts.delay)      or self._delay
    self._maxPerTick = tonumber(opts.maxPerTick) or self._maxPerTick
    if next(self._targetsSet) == nil then
        warn("[autofavoritefish] no target tiers set; stopping"); return
    end
    -- pre-arm favorite mode if available
    self:_preArmFavoriteMode()
    self._enabled = true
    task.spawn(function()
        if self._running then return end
        self._running = true
        while self._enabled do
            local n = self:_runTick()
            task.wait((n == 0) and 0.35 or 0.05)
        end
        self._running = false
    end)
end

function Feature:Stop()    self._enabled = false end
function Feature:Cleanup() self._enabled = false end

return Feature

