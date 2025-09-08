--[[
  inventory_watcher_standalone_fix.lua
  - Reclassify setiap entry -> kategori kanonik (Fishes/Items/Potions/Baits/Fishing Rods)
  - Dump & counting pakai kategori kanonik (bukan path raw)
]]

-- ====== Config printing ======
local PRINT_SUMMARY_ON_READY = true
local PRINT_DUMP_ON_READY    = false
local DUMP_LIMIT_PER_CAT     = 200

-- ====== Services & game deps ======
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Replion     = require(ReplicatedStorage.Packages.Replion)
local Constants   = require(ReplicatedStorage.Shared.Constants)
local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
local StringLib   = nil
pcall(function() StringLib = require(ReplicatedStorage.Shared.StringLibrary) end)

-- ====== Helpers ======
local function mkSignal()
    local ev = Instance.new("BindableEvent")
    return {
        Fire=function(_,...) ev:Fire(...) end,
        Connect=function(_,f) return ev.Event:Connect(f) end,
        Destroy=function(_) ev:Destroy() end
    }
end

local function shallowCopyArray(t)
    local out = {}
    if type(t)=="table" then for i,v in ipairs(t) do out[i]=v end end
    return out
end

local RAW_KEYS   = { "Items", "Fishes", "Potions", "Baits", "Fishing Rods" } -- path di Replion
local TYPED_KEYS = { "Items", "Fishes", "Potions", "Baits", "Fishing Rods" } -- kategori kanonik

-- Call ItemUtility method (colon/dot safe)
local function IU(method, ...)
    local f = ItemUtility and ItemUtility[method]
    if type(f) == "function" then
        local ok, res = pcall(f, ItemUtility, ...)
        if ok then return res end
    end
    return nil
end

local function fmtWeight(w)
    if not w then return nil end
    if StringLib and StringLib.AddWeight then
        local ok, txt = pcall(function() return StringLib:AddWeight(w) end)
        if ok and txt then return txt end
    end
    return tostring(w).."kg"
end

-- Klasifikasi entry -> kategori kanonik
local function classifyEntry(entry)
    local id = entry and (entry.Id or entry.id)
    if not id then return "Items" end

    -- Jika ada metadata berat, sangat kuat indikasi Fishes
    if entry.Metadata and entry.Metadata.Weight then
        return "Fishes"
    end

    -- Spesifik Bait / Potion
    local b = IU("GetBaitData", id)
    if b and b.Data then return "Baits" end
    local p = IU("GetPotionData", id)
    if p and p.Data then return "Potions" end

    -- Per-type resolver
    local f = IU("GetItemDataFromItemType", "Fishes", id)
    if f and f.Data and f.Data.Type == "Fishes" then return "Fishes" end

    local it = IU("GetItemDataFromItemType", "Items", id)
    if it and it.Data and it.Data.Type == "Items" then return "Items" end

    -- Generic resolver (cek Type)
    local g = IU("GetItemData", id)
    if g and g.Data and g.Data.Type then
        -- normalisasi nama type agar match TYPED_KEYS
        local typ = tostring(g.Data.Type)
        if typ == "Fishing Rods" then return "Fishing Rods" end
        if typ == "Fishes"       then return "Fishes" end
        if typ == "Baits"        then return "Baits" end
        if typ == "Potions"      then return "Potions" end
        if typ == "Items"        then return "Items" end
    end

    -- Fallback aman
    return "Items"
end

local function resolveName(typedCategory, id)
    if not id then return "<?>"
    end
    if typedCategory == "Baits" then
        local d = IU("GetBaitData", id)
        if d and d.Data and d.Data.Name then return d.Data.Name end
    elseif typedCategory == "Potions" then
        local d = IU("GetPotionData", id)
        if d and d.Data and d.Data.Name then return d.Data.Name end
    end
    -- Coba per-type sesuai kategori
    local d2 = IU("GetItemDataFromItemType", typedCategory, id)
    if d2 and d2.Data and d2.Data.Name then return d2.Data.Name end
    -- Generic
    local d3 = IU("GetItemData", id)
    if d3 and d3.Data and d3.Data.Name then return d3.Data.Name end
    return tostring(id)
end

-- ====== InventoryWatcher ======
local InventoryWatcher = {}
InventoryWatcher.__index = InventoryWatcher

function InventoryWatcher.new()
    local self = setmetatable({}, InventoryWatcher)
    self._data   = nil
    self._max    = Constants.MaxInventorySize or 0
    self._total  = 0

    -- Snapshot RAW (sesuai path di Replion)
    self._rawSnap = { Items={}, Fishes={}, Potions={}, Baits={}, ["Fishing Rods"]={} }

    -- Snapshot TYPED (hasil klasifikasi → dipakai untuk dump & hitung)
    self._typedSnap = { Items={}, Fishes={}, Potions={}, Baits={}, ["Fishing Rods"]={} }
    self._byType    = { Items=0, Fishes=0, Potions=0, Baits=0, ["Fishing Rods"]=0 }

    self._equipped = { itemsSet = {}, baitId = nil }

    self._changed  = mkSignal()  -- (total,max,free,byType)
    self._equipSig = mkSignal()  -- (equippedSet, baitId)
    self._readySig = mkSignal()
    self._conns    = {}
    self._ready    = false

    Replion.Client:AwaitReplion("Data", function(data)
        self._data = data
        self:_resubscribe()
        self._ready = true
        self._readySig:Fire()
    end)

    return self
end

function InventoryWatcher:_get(path)
    local ok, res = pcall(function() return self._data and self._data:Get(path) end)
    return ok and res or nil
end

function InventoryWatcher:_recountTotal()
    local ok, total = pcall(function()
        return self._data and Constants:CountInventorySize(self._data) or 0
    end)
    self._total = ok and total or 0
    self._max   = Constants.MaxInventorySize or self._max or 0
end

function InventoryWatcher:_snapRawCategory(key)
    local arr = self:_get({"Inventory", key})
    if type(arr) == "table" then
        self._rawSnap[key] = shallowCopyArray(arr)
    else
        self._rawSnap[key] = {}
    end
end

function InventoryWatcher:_rebuildTypedFromRaw()
    -- reset
    for _,k in ipairs(TYPED_KEYS) do
        self._typedSnap[k] = {}
        self._byType[k]    = 0
    end
    -- klasifikasi tiap entry dari semua array RAW
    for _, rawKey in ipairs(RAW_KEYS) do
        local arr = self._rawSnap[rawKey]
        for _, entry in ipairs(arr) do
            local cat = classifyEntry(entry)
            table.insert(self._typedSnap[cat], entry)
            self._byType[cat] += 1
        end
    end
end

function InventoryWatcher:_notify()
    local free = math.max(0, (self._max or 0) - (self._total or 0))
    self._changed:Fire(self._total, self._max, free, self:getCountsByType())
end

function InventoryWatcher:_rescanAll()
    -- refresh RAW
    for _, key in ipairs(RAW_KEYS) do
        self:_snapRawCategory(key)
    end
    -- rebuild typed + recount total
    self:_rebuildTypedFromRaw()
    self:_recountTotal()
    self:_notify()
end

function InventoryWatcher:_clearConns()
    for _,c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    table.clear(self._conns)
end

function InventoryWatcher:_resubscribe()
    self:_clearConns()
    self:_rescanAll()

    -- subscribe per path RAW (perubahan apapun -> rebuild typed)
    local function bindKey(key)
        local function onChange()
            self:_snapRawCategory(key)
            self:_rebuildTypedFromRaw()
            self:_recountTotal()
            self:_notify()
        end
        table.insert(self._conns, self._data:OnChange({"Inventory", key}, onChange))
        table.insert(self._conns, self._data:OnArrayInsert({"Inventory", key}, onChange))
        table.insert(self._conns, self._data:OnArrayRemove({"Inventory", key}, onChange))
    end
    for _, key in ipairs(RAW_KEYS) do bindKey(key) end

    -- equipped items
    table.insert(self._conns, self._data:OnChange("EquippedItems", function(_, new)
        local set = {}
        if typeof(new)=="table" then for _,uuid in ipairs(new) do set[uuid] = true end end
        self._equipped.itemsSet = set
        self._equipSig:Fire(self._equipped.itemsSet, self._equipped.baitId)
    end))

    -- equipped bait
    table.insert(self._conns, self._data:OnChange("EquippedBaitId", function(_, newId)
        self._equipped.baitId = newId
        self._equipSig:Fire(self._equipped.itemsSet, self._equipped.baitId)
    end))
end

-- ==== Public API ====
function InventoryWatcher:onReady(cb)
    if self._ready then task.defer(cb); return {Disconnect=function() end} end
    return self._readySig:Connect(cb)
end

function InventoryWatcher:onChanged(cb)  -- cb(total,max,free,byType)
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

function InventoryWatcher:getSnapshot(typeName) -- kategori kanonik
    if typeName then
        return shallowCopyArray(self._typedSnap[typeName] or {})
    else
        local out = {}
        for k,arr in pairs(self._typedSnap) do out[k]=shallowCopyArray(arr) end
        return out
    end
end

function InventoryWatcher:getTotals()
    local free = math.max(0,(self._max or 0)-(self._total or 0))
    return self._total or 0, self._max or 0, free
end

function InventoryWatcher:getEquippedBaitId() return self._equipped.baitId end
function InventoryWatcher:isEquipped(uuid) return self._equipped.itemsSet[uuid] == true end

function InventoryWatcher:getAutoSellThreshold()
    local ok, val = pcall(function() return self._data and self._data:Get("AutoSellThreshold") end)
    return ok and val or nil
end

function InventoryWatcher:destroy()
    self:_clearConns()
    self._changed:Destroy()
    self._equipSig:Destroy()
    self._readySig:Destroy()
end

-- ====== Dumper ======
local function dumpCategory(inv, typedCategory, limit)
    limit = limit or DUMP_LIMIT_PER_CAT
    local arr = inv:getSnapshot(typedCategory)
    print(("-- %s (%d) --"):format(typedCategory, #arr))
    for i, entry in ipairs(arr) do
        if i > limit then
            print(("... truncated at %d (set DUMP_LIMIT_PER_CAT to see more)"):format(limit))
            break
        end
        local id    = entry.Id or entry.id
        local uuid  = entry.UUID or entry.Uuid or entry.uuid
        local meta  = entry.Metadata or {}
        local name  = resolveName(typedCategory, id)

        if typedCategory == "Fishes" then
            local w  = fmtWeight(meta.Weight)
            local v  = meta.VariantId or meta.Mutation or meta.Variant
            local sh = (meta.Shiny == true) and "★" or ""
            print(i, name, uuid or "-", w or "-", v or "-", sh)
        else
            print(i, name, uuid or "-")
        end
    end
end

local function dumpAll(inv)
    for _, key in ipairs(TYPED_KEYS) do
        dumpCategory(inv, key)
    end
end

-- ====== Runner ======
local inv = InventoryWatcher.new()

inv:onReady(function()
    local total, max, free = inv:getTotals()
    local byType = inv:getCountsByType()
    print(("[INV] %d/%d (free %d) | Fishes=%d, Items=%d, Potions=%d, Baits=%d, Rods=%d")
        :format(total, max, free,
            byType.Fishes or 0, byType.Items or 0, byType.Potions or 0, byType.Baits or 0, byType["Fishing Rods"] or 0))

    print("Equipped bait:", inv:getEquippedBaitId(), "AutoSellThreshold:", inv:getAutoSellThreshold())

    if PRINT_DUMP_ON_READY then
        dumpAll(inv)
    end
end)

-- Global helpers
getgenv().DevlogicInv = {
    dumpAll = function() dumpAll(inv) end,
    dump    = function(cat, limit) dumpCategory(inv, cat, limit) end, -- cat: "Fishes"/"Items"/"Potions"/"Baits"/"Fishing Rods"
    snap    = function(cat) return inv:getSnapshot(cat) end,
    totals  = function() return inv:getTotals() end,
    counts  = function() return inv:getCountsByType() end,
    bait    = function() return inv:getEquippedBaitId() end,
}

print("[inventory_watcher] fixed. Use DevlogicInv.dump('Fishes') / DevlogicInv.dump('Items').")


return InventoryWatcher