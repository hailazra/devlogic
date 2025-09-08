--[[
  inventory_watcher_standalone.lua
  - Satu file langsung jalan (NO external module selain yg sudah ada di game: Replion, Constants, ItemUtility)
  - Cetak ringkasan inventory + bisa dump isi per kategori (Items/Fishes/Potions/Baits/Fishing Rods)

  Tips:
  - Kalau sebelumnya kamu dapat error "nil" di `local inv = InventoryWatcher.new()`,
    itu biasanya karena variabel InventoryWatcher belum terisi (mis. kamu loadstring modul tanpa `return`),
    atau kamu lupa assign hasil return ke variabel. Di file ini, InventoryWatcher didefinisikan inline, jadi aman.
]]

-- ====== Config printing ======
local PRINT_SUMMARY_ON_READY = true
local PRINT_DUMP_ON_READY    = false   -- set true kalau mau auto-dump semua kategori pas ready
local DUMP_LIMIT_PER_CAT     = 200     -- biar console nggak banjir

-- ====== Services & game deps ======
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replion   = require(ReplicatedStorage.Packages.Replion)
local Constants = require(ReplicatedStorage.Shared.Constants)
local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
local StringLib = nil
pcall(function() StringLib = require(ReplicatedStorage.Shared.StringLibrary) end)

-- ====== Utility helpers ======
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

local KNOWN_KEYS = { "Items", "Fishes", "Potions", "Baits", "Fishing Rods" }

-- Call ItemUtility method (colon/dot safe)
local function IU(method, ...)
    local f = ItemUtility and ItemUtility[method]
    if type(f) == "function" then
        -- coba colon-call
        local ok, res = pcall(f, ItemUtility, ...)
        if ok then return res end
    end
    return nil
end

local function resolveName(category, id)
    if not id then return "<?>"
    end
    if category == "Baits" then
        local d = IU("GetBaitData", id)
        if d and d.Data and d.Data.Name then return d.Data.Name end
    end
    -- Coba generic per-type
    local d2 = IU("GetItemDataFromItemType", category, id)
    if d2 and d2.Data and d2.Data.Name then return d2.Data.Name end
    -- Coba generic tanpa type
    local d3 = IU("GetItemData", id)
    if d3 and d3.Data and d3.Data.Name then return d3.Data.Name end
    return tostring(id)
end

local function fmtWeight(w)
    if not w then return nil end
    -- pakai util game kalau ada
    if StringLib and StringLib.AddWeight then
        local ok, txt = pcall(function() return StringLib:AddWeight(w) end)
        if ok and txt then return txt end
    end
    return tostring(w).."kg"
end

-- ====== InventoryWatcher (inline class) ======
local InventoryWatcher = {}
InventoryWatcher.__index = InventoryWatcher

function InventoryWatcher.new()
    local self = setmetatable({}, InventoryWatcher)
    self._data   = nil
    self._max    = Constants.MaxInventorySize or 0
    self._total  = 0
    self._snap   = { Items={}, Fishes={}, Potions={}, Baits={}, ["Fishing Rods"]={} }
    self._byType = { Items=0, Fishes=0, Potions=0, Baits=0, ["Fishing Rods"]=0 }
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

function InventoryWatcher:_recount()
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
        self._byType[key] = #arr
    else
        self._snap[key] = {}
        self._byType[key] = 0
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
    self:_notify()
end

function InventoryWatcher:_clearConns()
    for _,c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    table.clear(self._conns)
end

function InventoryWatcher:_resubscribe()
    self:_clearConns()
    self:_rescanAll()

    -- per-category subscriptions
    local function bindKey(key)
        local function onChange()
            self:_snapCategory(key)
            self:_recount()
            self:_notify()
        end
        table.insert(self._conns, self._data:OnChange({"Inventory", key}, onChange))
        table.insert(self._conns, self._data:OnArrayInsert({"Inventory", key}, onChange))
        table.insert(self._conns, self._data:OnArrayRemove({"Inventory", key}, onChange))
    end
    for _, key in ipairs(KNOWN_KEYS) do bindKey(key) end

    -- equipped items
    table.insert(self._conns, self._data:OnChange("EquippedItems", function(_, new)
        local set = {}
        if typeof(new)=="table" then
            for _,uuid in ipairs(new) do set[uuid] = true end
        end
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

function InventoryWatcher:getSnapshot(typeName) -- nil -> semua dict
    if typeName then
        return shallowCopyArray(self._snap[typeName] or {})
    else
        local out = {}
        for k,arr in pairs(self._snap) do out[k]=shallowCopyArray(arr) end
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

-- ====== Dumper helpers ======
local function dumpCategory(inv, category, limit)
    limit = limit or DUMP_LIMIT_PER_CAT
    local arr = inv:getSnapshot(category)
    print(("-- %s (%d) --"):format(category, #arr))
    for i, entry in ipairs(arr) do
        if i > limit then
            print(("... truncated at %d (set DUMP_LIMIT_PER_CAT to see more)"):format(limit))
            break
        end
        local id    = entry.Id or entry.id
        local uuid  = entry.UUID or entry.Uuid or entry.uuid
        local meta  = entry.Metadata or {}
        local name  = resolveName(category, id)

        if category == "Fishes" then
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
    for _, key in ipairs(KNOWN_KEYS) do
        dumpCategory(inv, key)
    end
end

-- ====== Runner (auto create + print) ======
local inv = InventoryWatcher.new()

inv:onReady(function()
    local total, max, free = inv:getTotals()
    local byType = inv:getCountsByType()
    print(("[INV] %d/%d (free %d) | Fishes=%d, Items=%d, Potions=%d, Baits=%d, Rods=%d")
        :format(total, max, free,
            byType.Fishes or 0, byType.Items or 0, byType.Potions or 0, byType.Baits or 0, byType["Fishing Rods"] or 0))

    print("Equipped bait:", inv:getEquippedBaitId(), "AutoSellThreshold:", inv:getAutoSellThreshold())

    if PRINT_SUMMARY_ON_READY then
        -- already printed summary
    end
    if PRINT_DUMP_ON_READY then
        dumpAll(inv)
    end
end)

-- Optional: expose global commands biar gampang dipanggil dari console
getgenv().DevlogicInv = {
    dumpAll = function() dumpAll(inv) end,
    dump    = function(cat, limit) dumpCategory(inv, cat, limit) end,
    snap    = function(cat) return inv:getSnapshot(cat) end,
    totals  = function() return inv:getTotals() end,
    counts  = function() return inv:getCountsByType() end,
    bait    = function() return inv:getEquippedBaitId() end,
}

print("[inventory_watcher] loaded. Use DevlogicInv.dump('Items') / DevlogicInv.dumpAll().")
