-- ===========================
-- inventoryDetector_v2.lua
-- Raw detector for Inventory/Bag/Backpack (listen-only)
-- - Nunggu game.Loaded & LocalPlayer
-- - Hook Replion + Constants + InventoryController (best-effort)
-- - Tanpa operator/utility yang kadang bikin error di executor lama
-- ===========================

local inventoryDetector = {}
inventoryDetector.__index = inventoryDetector

-- ======= Guard: pastikan game siap =======
if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end

-- ======= Services =======
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Tunggu LocalPlayer (hindari nil index di awal)
while not Players.LocalPlayer do task.wait() end
local LocalPlayer = Players.LocalPlayer

-- ======= Config =======
local PATH = {"Inventory", "Items"}      -- Replion path per BagSize
local USE_CONTROLLER_FIRST = true
local DEBUG = false

-- ======= State =======
local state = {
    count = 0,
    max = nil,
    isFull = false,
    items = {},
    toolsCount = 0,
    sources = { replion=false, controller=false, constants=false, backpack=false },
    ts = 0,
}

local started = false
local conns = {}                -- simpan RBXScriptConnection
local ReplionClient, Constants, Controller, ReplionData

local ChangedBE = Instance.new("BindableEvent")
inventoryDetector.Changed = ChangedBE.Event

-- ======= Utils =======
local function dprint(...)
    if DEBUG then
        print("[inventoryDetector]", ...)
    end
end

local function typeofCompat(v)
    -- Beberapa executor lama suka aneh; fallback ke type()
    local ok, t = pcall(function() return typeof(v) end)
    if ok then return t end
    return type(v)
end

local function safeWaitForChild(parent, name, timeout)
    timeout = tonumber(timeout) or 5
    local obj = parent:FindFirstChild(name)
    if obj then return obj end
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        obj = parent:FindFirstChild(name)
        if obj then return obj end
        task.wait()
    end
    return nil
end

local function safeRequire(pathArr)
    -- pathArr ex: {"Packages","Replion"}
    local ptr = ReplicatedStorage
    for i = 1, #pathArr do
        ptr = safeWaitForChild(ptr, pathArr[i], 5)
        if not ptr then return false, nil end
    end
    local ok, mod = pcall(function() return require(ptr) end)
    if ok then return true, mod end
    return false, nil
end

local function isConnectable(v)
    local t = typeofCompat(v)
    if t == "RBXScriptSignal" then return true end
    if t == "Instance" and v and v.ClassName == "BindableEvent" then return true end
    if t == "table" then
        local ok = (type(v.Connect) == "function") or (typeofCompat(v.Event) == "RBXScriptSignal")
        return ok
    end
    return false
end

local function connectSignal(sig, fn)
    local t = typeofCompat(sig)
    if t == "RBXScriptSignal" then
        return sig:Connect(fn)
    elseif t == "Instance" and sig.ClassName == "BindableEvent" then
        return sig.Event:Connect(fn)
    elseif t == "table" and type(sig.Connect) == "function" then
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
        local children = bp:GetChildren()
        for i = 1, #children do
            local ch = children[i]
            if ch and ch:IsA("Tool") then
                n = n + 1
            end
        end
    end
    return n
end

local function fireChanged()
    state.ts = os.clock()
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

-- ======= Compute Pipeline =======
local function computeFromConstants(repl)
    if not Constants then return nil end
    local ok, c = pcall(function() return Constants:CountInventorySize(repl) end)
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
    return type(itemsArr) == "table" and #itemsArr or 0
end

local function recompute()
    local newCount = nil

    if ReplionData and Constants then
        newCount = computeFromConstants(ReplionData)
    end

    if not newCount and Controller then
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

-- ======= Replion wiring =======
local function hookReplion()
    local okReplion, Replion = safeRequire({"Packages","Replion"})
    if not okReplion or not Replion or not Replion.Client then
        dprint("Replion not found")
        return
    end
    ReplionClient = Replion.Client

    local okConst, Const = safeRequire({"Shared","Constants"})
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

        onChange()
        local c1 = repl:OnChange(PATH, onChange)
        local c2 = repl:OnArrayInsert(PATH, onChange)
        local c3 = repl:OnArrayRemove(PATH, onChange)
        if c1 then table.insert(conns, c1) end
        if c2 then table.insert(conns, c2) end
        if c3 then table.insert(conns, c3) end
    end)
end

-- ======= Backpack wiring =======
local function hookBackpack()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 10)
    if not bp then return end
    local cA = bp.ChildAdded:Connect(function()
        state.toolsCount = backpackToolCount()
        fireChanged()
    end)
    local cR = bp.ChildRemoved:Connect(function()
        state.toolsCount = backpackToolCount()
        fireChanged()
    end)
    table.insert(conns, cA)
    table.insert(conns, cR)
    state.toolsCount = backpackToolCount()
    state.sources.backpack = true
end

-- ======= InventoryController wiring (best-effort) =======
local function hookInventoryController()
    local okCtl, ctl = safeRequire({"Controllers","InventoryController"})
    if not okCtl or type(ctl) ~= "table" then
        dprint("InventoryController not found or invalid")
        return
    end
    Controller = ctl

    local function snapFromController()
        local got = nil
        local candidates = {"GetItems","getItems","GetInventory","getInventory","GetAll","getAll","Items"}
        for i = 1, #candidates do
            local k = candidates[i]
            local v = Controller[k]
            if type(v) == "function" then
                local ok, res = pcall(function() return v(Controller) end)
                if ok and type(res) == "table" then got = res break end
            elseif type(v) == "table" then
                got = v; break
            end
        end
        if got then
            state.items = shallowArray(got)
            state.sources.controller = true
        end
    end

    snapFromController()
    recompute()

    local evNames = {"Changed","OnChanged","ItemsChanged","InventoryChanged","Updated","OnUpdate","Event"}
    local hooked = false
    for i = 1, #evNames do
        local name = evNames[i]
        local sig = Controller[name]
        if sig and isConnectable(sig) then
            local conn = connectSignal(sig, function()
                snapFromController()
                recompute()
            end)
            if conn then
                table.insert(conns, conn)
                dprint("Hooked InventoryController signal:", name)
                hooked = true
                break
            end
        end
    end

    if not hooked then
        dprint("No connectable signal on InventoryController (fallback to Replion)")
    end
end

-- ======= Public API =======
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
    for i = 1, #conns do
        local c = conns[i]
        pcall(function() if c and c.Disconnect then c:Disconnect() end end)
    end
    -- manual clear (tanpa table.clear)
    for i = #conns, 1, -1 do conns[i] = nil end
end

function inventoryDetector.GetSnapshot()
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
    DEBUG = (on and true) or false
end

return inventoryDetector
