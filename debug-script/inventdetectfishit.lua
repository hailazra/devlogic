-- ===========================
-- inventoryDetector.lua
-- Raw detector for Inventory/Bag/Backpack
-- - Listen-only: no side effects
-- - Event-driven (Replion + InventoryController + Backpack)
-- ===========================

local inventoryDetector = {}
inventoryDetector.__index = inventoryDetector

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

--=====================================
-- Config
--=====================================
local PATH = {"Inventory", "Items"}     -- Replion path per BagSize
local USE_CONTROLLER_FIRST = true       -- prefer controller if it exposes good signals/APIs
local DEBUG = false

--=====================================
-- Internal state
--=====================================
local state = {
    count = 0,                -- final computed bag count
    max = nil,                -- MaxInventorySize (if available)
    isFull = false,           -- derived from count >= max
    items = {},               -- shallow array snapshot from Replion/Controller
    toolsCount = 0,           -- number of Tools in Roblox Backpack
    sources = {               -- which sources are active
        replion = false,
        controller = false,
        constants = false,
        backpack = false,
    },
    ts = 0,                   -- last update timestamp (os.clock)
}

local started = false
local conns = {}
local ReplionClient, Constants, Controller, ReplionData
local ChangedBE = Instance.new("BindableEvent")
inventoryDetector.Changed = ChangedBE.Event

--=====================================
-- Utils
--=====================================
local function dprint(...)
    if DEBUG then
        print("[inventoryDetector]", ...)
    end
end

local function safeRequire(pathArr)
    return pcall(function()
        local ptr = ReplicatedStorage
        for i = 1, #pathArr do
            ptr = ptr:WaitForChild(pathArr[i], 5)
        end
        return require(ptr)
    end)
end

local function isConnectable(v) -- RBXScriptSignal / GoodSignal-like / BindableEvent
    if typeof(v) == "RBXScriptSignal" then return true end
    if typeof(v) == "Instance" and v:IsA("BindableEvent") then return true end
    if type(v) == "table" then
        local ok = (type(v.Connect) == "function") or (type(v.Event) == "userdata")
        return ok
    end
    return false
end

local function connectSignal(sig, fn)
    if typeof(sig) == "RBXScriptSignal" then
        return sig:Connect(fn)
    elseif typeof(sig) == "Instance" and sig:IsA("BindableEvent") then
        return sig.Event:Connect(fn)
    elseif type(sig) == "table" and type(sig.Connect) == "function" then
        return sig:Connect(fn)
    end
end

local function shallowArray(t)
    if type(t) ~= "table" then return {} end
    local r = {}
    for i = 1, #t do r[i] = t[i] end
    return r
end

local function backpackToolCount()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local n = 0
    if bp then
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") then n += 1 end
        end
    end
    return n
end

local function fireChanged()
    state.ts = os.clock()
    -- emit an immutable copy so external code gak bisa ngubah internal
    ChangedBE:Fire({
        count = state.count,
        max = state.max,
        isFull = state.isFull,
        items = state.items,
        toolsCount = state.toolsCount,
        sources = {
            replion = state.sources.replion,
            controller = state.sources.controller,
            constants = state.sources.constants,
            backpack = state.sources.backpack,
        },
        ts = state.ts,
    })
end

--=====================================
-- Core recompute pipeline
--=====================================
local function computeFromConstants(repl)
    if not Constants then return nil end
    local ok, c = pcall(function()
        return Constants:CountInventorySize(repl)
    end)
    if ok and tonumber(c) then
        state.sources.constants = true
        return tonumber(c)
    end
    return nil
end

local function tryReadMax()
    if Constants and tonumber(Constants.MaxInventorySize) then
        state.max = tonumber(Constants.MaxInventorySize)
    end
end

local function deriveCountFallback(itemsArr)
    -- last-resort if CountInventorySize/Controller unavailable
    return type(itemsArr) == "table" and #itemsArr or 0
end

local function recompute()
    -- priority: Constants:CountInventorySize(ReplionData) > Controller API > #items
    local newCount = nil

    if ReplionData and Constants then
        newCount = computeFromConstants(ReplionData)
    end

    if not newCount and Controller then
        -- Try common controller getters
        local tried = false
        local ok, got = pcall(function()
            tried = true
            if type(Controller.GetCount) == "function" then
                return Controller:GetCount()
            elseif type(Controller.getCount) == "function" then
                return Controller:getCount()
            elseif type(Controller.Size) == "number" then
                return Controller.Size
            end
        end)
        if tried and ok and tonumber(got) then
            newCount = tonumber(got)
            state.sources.controller = true
        end
    end

    if not newCount then
        newCount = deriveCountFallback(state.items)
    end

    tryReadMax()

    state.count = newCount or 0
    local cap = state.max or state.count
    state.isFull = (state.count >= cap)
    state.toolsCount = backpackToolCount()
    state.sources.backpack = true

    fireChanged()
end

--=====================================
-- Replion wiring
--=====================================
local function hookReplion()
    local okReplion, Replion = safeRequire({"Packages", "Replion"})
    if not okReplion or not Replion or not Replion.Client then
        dprint("Replion not found")
        return
    end
    ReplionClient = Replion.Client

    -- Constants for CountInventorySize & MaxInventorySize
    local okConst, Const = safeRequire({"Shared", "Constants"})
    if okConst and Const then
        Constants = Const
    end

    ReplionClient:AwaitReplion("Data", function(repl)
        ReplionData = repl
        state.sources.replion = true

        local function pullItems()
            local arr = repl:Get(PATH)
            state.items = shallowArray(arr or {})
        end

        local function onChange()
            pullItems()
            recompute()
        end

        -- initial
        onChange()

        -- subscribe per BagSize
        table.insert(conns, repl:OnChange(PATH, onChange))
        table.insert(conns, repl:OnArrayInsert(PATH, onChange))
        table.insert(conns, repl:OnArrayRemove(PATH, onChange))
    end)
end

--=====================================
-- Backpack wiring
--=====================================
local function hookBackpack()
    local bp = LocalPlayer:WaitForChild("Backpack", 10)
    if not bp then return end
    table.insert(conns, bp.ChildAdded:Connect(function()
        state.toolsCount = backpackToolCount()
        fireChanged()
    end))
    table.insert(conns, bp.ChildRemoved:Connect(function()
        state.toolsCount = backpackToolCount()
        fireChanged()
    end))
    state.toolsCount = backpackToolCount()
    state.sources.backpack = true
end

--=====================================
-- InventoryController wiring (best-effort)
--=====================================
local function hookInventoryController()
    -- Try require
    local okCtl, ctl = safeRequire({"Controllers", "InventoryController"})
    if not okCtl or type(ctl) ~= "table" then
        dprint("InventoryController not found or invalid")
        return
    end
    Controller = ctl

    -- Try read items once from common getters
    local function snapFromController()
        local got = nil
        -- common patterns: GetItems / GetInventory / Items field
        local triedFuncs = {
            "GetItems","getItems","GetInventory","getInventory","GetAll","getAll","Items",
        }
        for _, k in ipairs(triedFuncs) do
            local v = Controller[k]
            if type(v) == "function" then
                local ok, res = pcall(function() return v(Controller) end)
                if ok and type(res) == "table" then got = res break end
            elseif type(v) == "table" then
                got = v
                break
            end
        end
        if got then
            state.items = shallowArray(got)
            state.sources.controller = true
        end
    end

    snapFromController()
    recompute()

    -- Try hook events/signals commonly exposed
    local candidateEvents = {
        "Changed","OnChanged","ItemsChanged","InventoryChanged","Updated","OnUpdate","Event",
    }
    local connected = false
    for _, name in ipairs(candidateEvents) do
        local sig = Controller[name]
        if sig and isConnectable(sig) then
            local conn = connectSignal(sig, function()
                -- on any controller tick, attempt to refresh snapshot & recompute
                snapFromController()
                recompute()
            end)
            if conn then
                table.insert(conns, conn)
                dprint("Hooked InventoryController signal:", name)
                connected = true
                break
            end
        end
    end

    if not connected then
        dprint("No connectable signal found on InventoryController (fallback to Replion)")
    end
end

--=====================================
-- Public API
--=====================================
function inventoryDetector.Start(opts)
    if started then return end
    started = true
    if opts and type(opts.DEBUG) == "boolean" then DEBUG = opts.DEBUG end

    if USE_CONTROLLER_FIRST then
        hookInventoryController()
        hookReplion()
    else
        hookReplion()
        hookInventoryController()
    end
    hookBackpack()
end

function inventoryDetector.Stop()
    if not started then return end
    started = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)
end

function inventoryDetector.GetSnapshot()
    -- read-only copy
    return {
        count = state.count,
        max = state.max,
        isFull = state.isFull,
        items = state.items,
        toolsCount = state.toolsCount,
        sources = {
            replion = state.sources.replion,
            controller = state.sources.controller,
            constants = state.sources.constants,
            backpack = state.sources.backpack,
        },
        ts = state.ts,
    }
end

function inventoryDetector.EnableDebug(on)
    DEBUG = not not on
end

return inventoryDetector
