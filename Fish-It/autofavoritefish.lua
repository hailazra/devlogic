-- autofavoritefish.lua (fixed version)
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- ==== Net helpers (same pattern as autoenchantrodv1) ====
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
    -- fallback cari global
    return ReplicatedStorage:FindFirstChild(name, true)
end

-- ==== Dependencies ====
local ItemUtility = nil
pcall(function() ItemUtility = require(ReplicatedStorage.Shared.ItemUtility) end)

-- ==== Build tier maps from ReplicatedStorage.Tiers ====
local function buildTierMaps()
    local names, byNum, byName = {}, {}, {}
    local tiersModule = ReplicatedStorage:FindFirstChild("Tiers")
    if tiersModule and tiersModule:IsA("ModuleScript") then
        local ok, tiers = pcall(require, tiersModule)
        if ok and type(tiers) == "table" then
            for _, tierData in ipairs(tiers) do
                if tierData and tierData.Name and tierData.Tier then
                    local tierNum = tonumber(tierData.Tier)
                    local tierName = tostring(tierData.Name)
                    byNum[tierNum] = tierName
                    byName[tierName] = tierNum
                    table.insert(names, tierName)
                end
            end
        end
    end
    -- Sort by tier number (highest first)
    table.sort(names, function(a, b) 
        return (byName[a] or 0) > (byName[b] or 0) 
    end)
    return names, byNum, byName
end

-- ==== Build fish database from ReplicatedStorage.Items ====
local FishDB_ById = nil
local function buildFishDB()
    FishDB_ById = {}
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if not itemsFolder then return end
    
    for _, child in ipairs(itemsFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            local ok, fishData = pcall(require, child)
            if ok and type(fishData) == "table" and fishData.Data then
                local data = fishData.Data
                if data.Type == "Fishes" and data.Id and data.Tier then
                    FishDB_ById[tonumber(data.Id)] = {
                        Name = tostring(data.Name or child.Name),
                        Tier = tonumber(data.Tier),
                        Id = tonumber(data.Id)
                    }
                end
            end
        end
    end
end

-- ==== Safe item data helper (similar to autoenchantrodv1) ====
local function safeFishData(fishId)
    fishId = tonumber(fishId)
    if not fishId then return nil end
    
    -- Try ItemUtility first
    if ItemUtility and ItemUtility.GetItemDataFromItemType then
        local ok, data = pcall(function() 
            return ItemUtility:GetItemDataFromItemType("Fishes", fishId) 
        end)
        if ok and data and data.Data then return data.Data end
    end
    
    -- Fallback to our built database
    if FishDB_ById == nil then buildFishDB() end
    return FishDB_ById and FishDB_ById[fishId]
end

-- ==== Check if fish entry is favorited ====
local function isFavoritedEntry(entry)
    if not entry then return false end
    
    -- Check direct properties
    if entry.Favorited == true or entry.Favorite == true or entry.IsFavorite == true then 
        return true 
    end
    
    -- Check metadata
    local meta = entry.Metadata
    if type(meta) == "table" then
        if meta.Favorited == true or meta.Favorite == true or meta.IsFavorite == true then 
            return true 
        end
    end
    
    return false
end

-- ==== Check if entry is a fish (similar to isEnchantStoneEntry in autoenchantrodv1) ====
local function isFishEntry(entry)
    if type(entry) ~= "table" then return false end
    
    local id = entry.Id or entry.id
    if not id then return false end
    
    -- Check if this ID corresponds to a fish
    local fishData = safeFishData(id)
    if fishData and fishData.Tier then return true end
    
    -- Additional check: if entry has Weight metadata (fish characteristic)
    if entry.Metadata and entry.Metadata.Weight then return true end
    
    return false
end

-- ==== Auto Favorite Fish Feature ====
local AutoFavoriteFish = {}
AutoFavoriteFish.__index = AutoFavoriteFish

function AutoFavoriteFish.new(opts)
    opts = opts or {}
    
    -- Try to get watcher
    local watcher = opts.watcher
    if not watcher and opts.attemptAutoWatcher then
        local ok, WatcherMod = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/debug-script/inventdetectfishit.lua"))()
        end)
        if ok and WatcherMod then
            watcher = WatcherMod.new()
        end
    end
    
    local self = setmetatable({
        _watcher = watcher,
        _enabled = false,
        _running = false,
        _delay = tonumber(opts.delay or 0.10),
        _maxPerTick = tonumber(opts.maxPerTick or 15),
        _targetTiers = {}, -- set[tierName] = true
        _tierNames = {},   -- ordered array
        _tierByNum = {},   -- [tierNum] = tierName
        _tierByName = {},  -- [tierName] = tierNum
    }, AutoFavoriteFish)
    
    -- Build tier mappings
    self._tierNames, self._tierByNum, self._tierByName = buildTierMaps()
    
    return self
end

-- ---- Public API ----
function AutoFavoriteFish:getTierNames()
    return self._tierNames
end

function AutoFavoriteFish:setTargetTiers(tierNames)
    self._targetTiers = {}
    for _, tierName in ipairs(tierNames or {}) do
        if self._tierByName[tierName] then
            self._targetTiers[tierName] = true
        else
            warn("[autofavoritefish] unknown tier name:", tierName)
        end
    end
end

function AutoFavoriteFish:isEnabled()
    return self._enabled
end

function AutoFavoriteFish:start()
    if self._enabled then return end
    
    -- Check if we have targets
    local hasTarget = false
    for _ in pairs(self._targetTiers) do 
        hasTarget = true 
        break 
    end
    if not hasTarget then
        warn("[autofavoritefish] no target tiers set")
        return false
    end
    
    self._enabled = true
    task.spawn(function() self:_runLoop() end)
    return true
end

function AutoFavoriteFish:stop()
    self._enabled = false
end

function AutoFavoriteFish:destroy()
    self._enabled = false
end

-- ---- Internal methods ----
function AutoFavoriteFish:_favoriteItem(uuid)
    local remoteEvent = getRemote("RE/FavoriteItem")
    if not remoteEvent or not remoteEvent:IsA("RemoteEvent") then
        warn("[autofavoritefish] FavoriteItem remote not found")
        return false
    end
    
    local ok = pcall(function()
        remoteEvent:FireServer(uuid)
    end)
    
    if not ok then
        warn("[autofavoritefish] failed to favorite item:", uuid)
    end
    
    return ok
end

function AutoFavoriteFish:_getFishTierName(fishId)
    local fishData = safeFishData(fishId)
    if not fishData or not fishData.Tier then return nil end
    
    return self._tierByNum[fishData.Tier]
end

function AutoFavoriteFish:_findFishesToFavorite()
    if not self._watcher then return {} end
    
    -- Use typed snapshot to get Fishes category
    local fishes = nil
    if self._watcher.getSnapshotTyped then
        fishes = self._watcher:getSnapshotTyped("Fishes")
    elseif self._watcher.getSnapshot then
        fishes = self._watcher:getSnapshot("Fishes") 
    else
        return {}
    end
    
    local candidates = {}
    for _, entry in ipairs(fishes or {}) do
        if type(entry) == "table" and isFishEntry(entry) and not isFavoritedEntry(entry) then
            local uuid = entry.UUID or entry.Uuid or entry.uuid
            local fishId = entry.Id or entry.id
            
            if uuid and fishId then
                local tierName = self:_getFishTierName(fishId)
                if tierName and self._targetTiers[tierName] then
                    table.insert(candidates, {
                        uuid = uuid,
                        fishId = fishId,
                        tierName = tierName
                    })
                end
            end
        end
    end
    
    return candidates
end

function AutoFavoriteFish:_runOnce()
    local candidates = self:_findFishesToFavorite()
    if #candidates == 0 then
        return 0 -- no fish to favorite
    end
    
    local favorited = 0
    for i, fish in ipairs(candidates) do
        if not self._enabled then break end
        
        if self:_favoriteItem(fish.uuid) then
            print(("[autofavoritefish] favorited %s fish (ID: %d, UUID: %s)"):format(
                fish.tierName, fish.fishId, fish.uuid
            ))
            favorited = favorited + 1
            
            if favorited >= self._maxPerTick then break end
            task.wait(self._delay)
        end
    end
    
    return favorited
end

function AutoFavoriteFish:_runLoop()
    if self._running then return end
    self._running = true
    
    -- Wait for watcher to be ready
    if self._watcher and self._watcher.onReady then
        if not self._watcher._ready then
            local ready = false
            local conn = self._watcher:onReady(function() ready = true end)
            local startTime = os.clock()
            while not ready and self._enabled do
                task.wait(0.05)
                if os.clock() - startTime > 10 then -- 10 second timeout
                    warn("[autofavoritefish] watcher ready timeout")
                    break
                end
            end
            if conn and conn.Disconnect then conn:Disconnect() end
            if not ready then
                self._running = false
                self._enabled = false
                return
            end
        end
    end
    
    print("[autofavoritefish] started with targets:", table.concat(table.keys(self._targetTiers), ", "))
    
    while self._enabled do
        local favorited = self:_runOnce()
        
        -- Adaptive wait: longer if nothing was done
        if favorited == 0 then
            task.wait(0.5) -- wait longer when idle
        else
            task.wait(0.1) -- shorter wait when active
        end
    end
    
    self._running = false
    print("[autofavoritefish] stopped")
end

-- ==== Feature wrapper for compatibility ====
local AutoFavoriteFishFeature = {}
AutoFavoriteFishFeature.__index = AutoFavoriteFishFeature

function AutoFavoriteFishFeature:Init(controls)
    -- Try to get watcher from controls
    local watcher = controls and controls.watcher
    
    -- Create the underlying auto favoriter
    self._auto = AutoFavoriteFish.new({
        watcher = watcher,
        attemptAutoWatcher = watcher == nil
    })
    
    return true
end

function AutoFavoriteFishFeature:GetTierNames()
    return self._auto and self._auto:getTierNames() or {}
end

function AutoFavoriteFishFeature:SetDesiredTiersByNames(names)
    if self._auto then
        self._auto:setTargetTiers(names)
    end
end

function AutoFavoriteFishFeature:Start(config)
    if not self._auto then return end
    
    config = config or {}
    
    -- Set targets
    if config.tierNames then
        self:SetDesiredTiersByNames(config.tierNames)
    end
    
    -- Update settings
    if config.delay then
        local d = tonumber(config.delay)
        if d then self._auto._delay = d end
    end
    
    if config.maxPerTick then
        local m = tonumber(config.maxPerTick)
        if m then self._auto._maxPerTick = m end
    end
    
    -- Start
    return self._auto:start()
end

function AutoFavoriteFishFeature:Stop()
    if self._auto then
        self._auto:stop()
    end
end

function AutoFavoriteFishFeature:Cleanup()
    if self._auto then
        self._auto:destroy()
        self._auto = nil
    end
end

-- Additional utility function for table.keys (if not available)
if not table.keys then
    table.keys = function(t)
        local keys = {}
        for k, _ in pairs(t) do
            table.insert(keys, k)
        end
        return keys
    end
end

return setmetatable(AutoFavoriteFishFeature, AutoFavoriteFishFeature)