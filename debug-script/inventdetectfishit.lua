-- inventory_watcher.lua
-- Reusable watcher buat Inventory/Bag berbasis Replion "Data"
-- Tidak ganggu modul BagSize bawaan game.

local InventoryWatcher = {}
InventoryWatcher.__index = InventoryWatcher

-- ===== Services & Deps =====
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- Replion & Constants dari game
local Replion    = require(ReplicatedStorage.Packages.Replion)
local Constants  = require(ReplicatedStorage.Shared.Constants)

-- Optional: kalau butuh AddCommas buat display
-- local StringLib = require(ReplicatedStorage.Shared.StringLibrary)

-- ===== Config default =====
local INV_PATH = {"Inventory","Items"} -- dari BagSize
local CHECK_INTERVAL = 0.25            -- fallback wait loop (detik)

-- ===== Util =====
local function shallowCopy(t)
    local out = {}
    if type(t) == "table" then
        for i,v in ipairs(t) do out[i] = v end
    end
    return out
end

-- Signal super ringan
local function makeSignal()
    local bind = Instance.new("BindableEvent")
    return {
        Fire = function(_, ...) bind:Fire(...) end,
        Connect = function(_, f) return bind.Event:Connect(f) end,
        Destroy = function(_) bind:Destroy() end
    }
end

-- ===== Core =====
function InventoryWatcher.new()
    local self = setmetatable({}, InventoryWatcher)

    self._dataReplion   = nil
    self._count         = 0
    self._max           = Constants.MaxInventorySize or 0
    self._itemsSnapshot = {}
    self._changed       = makeSignal()
    self._readySignal   = makeSignal()
    self._ready         = false
    self._conns         = {}

    -- Tunggu Replion "Data"
    Replion.Client:AwaitReplion("Data", function(data)
        self._dataReplion = data
        -- Initial compute + subscribe
        self:_recompute()
        self:_subscribe()
        self._ready = true
        self._readySignal:Fire()
    end)

    return self
end

function InventoryWatcher:_safeCount()
    -- Ikuti cara BagSize: gunakan CountInventorySize(dataReplion) jika ada
    local ok, result = pcall(function()
        if self._dataReplion then
            -- Beberapa game implement CountInventorySize expecting replion object
            return Constants:CountInventorySize(self._dataReplion)
        end
    end)
    if ok and typeof(result) == "number" then
        return result
    end

    -- Fallback: hitung array langsung
    local arr = self._dataReplion and self._dataReplion:Get(INV_PATH) or nil
    return (type(arr) == "table") and #arr or 0
end

function InventoryWatcher:_snapshotItems()
    local arr = self._dataReplion and self._dataReplion:Get(INV_PATH) or nil
    if type(arr) == "table" then
        self._itemsSnapshot = shallowCopy(arr)
    else
        self._itemsSnapshot = {}
    end
end

function InventoryWatcher:_recompute()
    self._max   = Constants.MaxInventorySize or self._max or 0
    self._count = self:_safeCount()
    self:_snapshotItems()
end

function InventoryWatcher:_notify()
    -- Fire: count, max, free
    self._changed:Fire(self._count, self._max, self:getFreeSlots())
end

function InventoryWatcher:_subscribe()
    -- Pastikan bersih
    for _,c in ipairs(self._conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(self._conns)

    -- Handler tunggal supaya konsisten
    local function onAnyChange()
        local prevCount = self._count
        local prevMax   = self._max
        self:_recompute()
        if self._count ~= prevCount or self._max ~= prevMax then
            self:_notify()
        end
    end

    -- Replion array watchers
    table.insert(self._conns, self._dataReplion:OnChange(INV_PATH, onAnyChange))
    table.insert(self._conns, self._dataReplion:OnArrayInsert(INV_PATH, onAnyChange))
    table.insert(self._conns, self._dataReplion:OnArrayRemove(INV_PATH, onAnyChange))

    -- Initial notify
    self:_notify()
end

-- ===== Public API =====
function InventoryWatcher:onReady(callback)
    if self._ready then
        task.defer(callback)
        return { Disconnect = function() end }
    end
    return self._readySignal:Connect(callback)
end

function InventoryWatcher:onChanged(callback)
    -- callback(count, max, free)
    return self._changed:Connect(callback)
end

function InventoryWatcher:getCount()
    return self._count
end

function InventoryWatcher:getMax()
    return self._max
end

function InventoryWatcher:getFreeSlots()
    local free = (self._max or 0) - (self._count or 0)
    if free < 0 then free = 0 end
    return free
end

function InventoryWatcher:isFull(threshold)
    -- threshold opsional:
    --  - number 0..1 -> persen penuh (misal 0.9 = 90%)
    --  - integer >=1 -> sisa slot minimum yang diinginkan
    if typeof(threshold) == "number" then
        if threshold > 0 and threshold <= 1 then
            local ratio = (self._count > 0 and self._max > 0) and (self._count / self._max) or 0
            return ratio >= threshold
        elseif threshold >= 1 then
            return self:getFreeSlots() < threshold
        end
    end
    -- default benar-benar penuh
    return self._count >= self._max
end

function InventoryWatcher:getItemsSnapshot()
    -- Shallow copy biar aman
    local copy = {}
    for i,v in ipairs(self._itemsSnapshot) do copy[i] = v end
    return copy
end

function InventoryWatcher:waitForSlots(requiredFree, timeoutSeconds)
    -- Tunggu sampai free slots >= requiredFree. Return true kalau berhasil, false kalau timeout.
    requiredFree = math.max(0, tonumber(requiredFree) or 1)
    local start = os.clock()

    if self:getFreeSlots() >= requiredFree then
        return true
    end

    local done = false
    local conn
    conn = self:onChanged(function()
        if self:getFreeSlots() >= requiredFree then
            done = true
            if conn then conn:Disconnect() end
        end
    end)

    while not done do
        task.wait(CHECK_INTERVAL)
        if timeoutSeconds and (os.clock() - start) >= timeoutSeconds then
            if conn then conn:Disconnect() end
            return false
        end
    end
    return true
end

function InventoryWatcher:destroy()
    for _,c in ipairs(self._conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(self._conns)
    self._changed:Destroy()
    self._readySignal:Destroy()
end

return InventoryWatcher
