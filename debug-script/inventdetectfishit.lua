-- inventory_watcher_v2.lua
-- Lintas kategori + aware equip & autosell threshold

local InventoryWatcher = {}
InventoryWatcher.__index = InventoryWatcher

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Replion     = require(ReplicatedStorage.Packages.Replion)
local Constants   = require(ReplicatedStorage.Shared.Constants)
local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)

-- Kategori yang diketahui oleh game (lihat InventoryController)
local KNOWN_KEYS = { "Items", "Fishes", "Potions", "Baits", "Fishing Rods" }

local function mkSignal()
    local ev = Instance.new("BindableEvent")
    return {
        Fire=function(_,...) ev:Fire(...) end,
        Connect=function(_,f) return ev.Event:Connect(f) end,
        Destroy=function(_) ev:Destroy() end
    }
end

function InventoryWatcher.new()
    local self = setmetatable({}, InventoryWatcher)
    self._data      = nil
    self._max       = Constants.MaxInventorySize or 0
    self._byType    = { Items=0, Fishes=0, Potions=0, Baits=0, ["Fishing Rods"]=0 }
    self._snap      = { Items={}, Fishes={}, Potions={}, Baits={}, ["Fishing Rods"]={} }
    self._equipped  = { itemsSet = {}, baitId = nil }
    self._changed   = mkSignal()  -- (total,max,free,byType)
    self._equipSig  = mkSignal()  -- (equippedSet, baitId)
    self._readySig  = mkSignal()
    self._ready     = false
    self._conns     = {}

    Replion.Client:AwaitReplion("Data", function(data) -- Data replion
        self._data = data
        self:_scanAndSubscribeAll()
        self:_subscribeEquip()     -- EquippedItems / EquippedBaitId
        self._ready = true
        self._readySig:Fire()
    end)

    return self
end

-- ===== Helpers =====

function InventoryWatcher:_get(path) -- safe get
    local ok, res = pcall(function() return self._data and self._data:Get(path) end)
    return ok and res or nil
end

local function shallowCopyArray(t)
    local out = {}
    if type(t)=="table" then for i,v in ipairs(t) do out[i]=v end end
    return out
end

function InventoryWatcher:_classifyEntry(hintKey, entry)
    -- Pakai ItemUtility untuk pastikan type (robust vs obfuscation)
    -- Entry minimal punya Id; beberapa punya Metadata (Weight/VariantId/EnchantId)
    if hintKey == "Potions" then
        local d = ItemUtility:GetPotionData(entry.Id)
        if d then return "Potions" end
    elseif hintKey == "Baits" then
        local d = ItemUtility:GetBaitData(entry.Id)
        if d then return "Baits" end
    elseif hintKey == "Fishing Rods" then
        local d = ItemUtility:GetItemData(entry.Id)
        if d and d.Data and d.Data.Type == "Fishing Rods" then return "Fishing Rods" end
    end
    -- Items/Fishes sering satu path → gunakan GetItemDataFromItemType untuk dua-duanya
    local di = ItemUtility.GetItemDataFromItemType and ItemUtility:GetItemDataFromItemType("Items", entry.Id)
    if di and di.Data and di.Data.Type == "Items" then return "Items" end
    local df = ItemUtility.GetItemDataFromItemType and ItemUtility:GetItemDataFromItemType("Fishes", entry.Id)
    if df and df.Data and df.Data.Type == "Fishes" then return "Fishes" end
    -- Fallback heuristik: kalau ada Metadata.Weight → treat as Fishes
    if entry.Metadata and entry.Metadata.Weight then return "Fishes" end
    return "Items"
end

function InventoryWatcher:_recount()
    -- Total size pakai util server → robust
    local ok, total = pcall(function()
        return self._data and Constants:CountInventorySize(self._data) or 0
    end)
    self._total = ok and total or 0
    self._max   = Constants.MaxInventorySize or self._max or 0
end

function InventoryWatcher:_snapCategory(key)
    local arr = self:_get({"Inventory", key})
    if type(arr) == "table" then
        self._snap[key] = shallowCopyArray(arr)
        self._byType[key] = #arr -- sementara raw count; akan dikoreksi di _rebuildByType()
    else
        self._snap[key] = {}
        self._byType[key] = 0
    end
end

function InventoryWatcher:_rebuildByType()
    -- Hitung ulang byType dengan klasifikasi yang benar
    for k in pairs(self._byType) do self._byType[k]=0 end
    for _, key in ipairs(KNOWN_KEYS) do
        local arr = self._snap[key]
        for _, entry in ipairs(arr) do
            local typ = self:_classifyEntry(key, entry)
            self._byType[typ] += 1
        end
    end
end

function InventoryWatcher:_notify()
    local free = math.max(0, (self._max or 0) - (self._total or 0))
    self._changed:Fire(self._total, self._max, free, self:getCountsByType())
end

function InventoryWatcher:_rescanAll()
    for _, key in ipairs(KNOWN_KEYS) do
        self:_snapCategory(key)
    end
    self:_recount()
    self:_rebuildByType()
    self:_notify()
end

function InventoryWatcher:_scanAndSubscribeAll()
    -- initial scan
    self:_rescanAll()

    -- clear old
    for _,c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    table.clear(self._conns)

    -- per-path watcher
    local function bindPath(key)
        local function onChange()
            self:_snapCategory(key)
            self:_recount()
            self:_rebuildByType()
            self:_notify()
        end
        table.insert(self._conns, self._data:OnChange({"Inventory", key}, onChange))
        table.insert(self._conns, self._data:OnArrayInsert({"Inventory", key}, onChange))
        table.insert(self._conns, self._data:OnArrayRemove({"Inventory", key}, onChange))
    end
    for _, key in ipairs(KNOWN_KEYS) do bindPath(key) end
end

function InventoryWatcher:_subscribeEquip()
    -- EquippedItems
    table.insert(self._conns, self._data:OnChange("EquippedItems", function(_, new)
        local set = {}
        if typeof(new)=="table" then for _,uuid in ipairs(new) do set[uuid]=true end end
        self._equipped.itemsSet = set
        self._equipSig:Fire(self._equipped.itemsSet, self._equipped.baitId)
    end))
    -- EquippedBaitId
    table.insert(self._conns, self._data:OnChange("EquippedBaitId", function(_, newId)
        self._equipped.baitId = newId
        self._equipSig:Fire(self._equipped.itemsSet, self._equipped.baitId)
    end))
end

-- ===== Public API =====
function InventoryWatcher:onReady(cb)
    if self._ready then task.defer(cb); return {Disconnect=function() end} end
    return self._readySig:Connect(cb)
end

function InventoryWatcher:onChanged(cb)  -- cb(total, max, free, byTypeTable)
    return self._changed:Connect(cb)
end

function InventoryWatcher:onEquipChanged(cb) -- cb(equippedSet, baitId)
    return self._equipSig:Connect(cb)
end

function InventoryWatcher:getCountsByType()
    local t = {}
    for k,v in pairs(self._byType) do t[k]=v end
    return t
end

function InventoryWatcher:getSnapshot(typeName) -- nil => semua kategori (dict)
    if typeName then
        return shallowCopyArray(self._snap[typeName] or {})
    else
        local out = {}
        for k,arr in pairs(self._snap) do out[k]=shallowCopyArray(arr) end
        return out
    end
end

function InventoryWatcher:isEquipped(uuid) return self._equipped.itemsSet[uuid] == true end
function InventoryWatcher:getEquippedBaitId() return self._equipped.baitId end

function InventoryWatcher:getTotals()
    local free = math.max(0,(self._max or 0)-(self._total or 0))
    return self._total or 0, self._max or 0, free
end

function InventoryWatcher:getAutoSellThreshold()
    -- Bacaan satu kali; kalau mau realtime, pasang OnChange sendiri di luar
    local ok, val = pcall(function() return self._data:Get("AutoSellThreshold") end)
    return ok and val or nil
end

function InventoryWatcher:destroy()
    for _,c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    table.clear(self._conns)
    self._changed:Destroy()
    self._equipSig:Destroy()
    self._readySig:Destroy()
end

return InventoryWatcher
