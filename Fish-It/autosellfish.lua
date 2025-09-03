-- ===========================
-- AUTO SELL FISH FEATURE (tanpa Status Panel & mode configs)
-- File: autosellfish.lua
-- ===========================

local AutoSellFish = {}
AutoSellFish.__index = AutoSellFish

-- Services
local Players        = game:GetService("Players")
local Replicated     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local LocalPlayer    = Players.LocalPlayer

-- Network setup
local NetPath = nil
local UpdateAutoSellThresholdRF, SellAllItemsRF

local function initializeRemotes()
    local ok = pcall(function()
        NetPath = Replicated:WaitForChild("Packages", 5)
            :WaitForChild("_Index", 5)
            :WaitForChild("sleitnick_net@0.2.0", 5)
            :WaitForChild("net", 5)

        UpdateAutoSellThresholdRF = NetPath:WaitForChild("RF/UpdateAutoSellThreshold", 5)
        SellAllItemsRF            = NetPath:WaitForChild("RF/SellAllItems", 5)
    end)
    return ok
end

-- Feature state
local isRunning            = false
local connection           = nil
local controls             = {}
local remotesInitialized   = false

-- Threshold state
local currentMode          = "Legendary" -- "Legendary" | "Mythic" | "Secret"
local _lastAppliedMode     = nil

-- Limit-based auto sell
local limitEnabled         = true   -- default: ON sampai kamu matikan
local limitValue           = 50     -- override via Start(config) atau SetLimit
local lastInventoryCount   = 0

-- Loop pacing (bukan "mode", cuma konstanta)
local WAIT_BETWEEN         = 0.15   -- detik; bisa override via Start(config.waitBetween)

-- Rarity mapping -> angka sesuai info kamu
local THRESHOLD_ENUM = {
    ["Legendary"] = 5,
    ["Mythic"]    = 6,
    ["Secret"]    = 7,
}

-- ===========================
-- Initialize
-- ===========================
function AutoSellFish:Init(guiControls)
    controls = guiControls or {}
    remotesInitialized = initializeRemotes()

    if not remotesInitialized then
        warn("[AutoSellFish] Failed to initialize remotes")
        return false
    end

    self:UpdateInventoryCount()
    print("[AutoSellFish] Initialized")
    return true
end

-- ===========================
-- Start
-- config: { threshold="Legendary|Mythic|Secret", limit:number, autoOnLimit:boolean, waitBetween:number }
-- ===========================
function AutoSellFish:Start(config)
    if isRunning then return end
    if not remotesInitialized then
        warn("[AutoSellFish] Cannot start - remotes not initialized")
        return
    end

    if config then
        if THRESHOLD_ENUM[config.threshold] then
            currentMode = config.threshold
        end
        if typeof(config.limit) == "number" then
            limitValue = math.max(0, math.floor(config.limit))
        end
        if typeof(config.autoOnLimit) == "boolean" then
            limitEnabled = config.autoOnLimit
        end
        if typeof(config.waitBetween) == "number" then
            WAIT_BETWEEN = math.max(0.01, config.waitBetween)
        end
    end

    -- apply threshold sekali di awal (debounced)
    self:_applyThreshold(currentMode)

    isRunning = true
    connection = RunService.Heartbeat:Connect(function()
        if not isRunning then return end
        self:SellLoop()
    end)

    print(("[AutoSellFish] Started | Threshold=%s | Limit=%d | AutoOnLimit=%s | Wait=%.2fs")
        :format(currentMode, limitValue, tostring(limitEnabled), WAIT_BETWEEN))
end

-- ===========================
-- Stop
-- ===========================
function AutoSellFish:Stop()
    if not isRunning then return end
    isRunning = false

    if connection then
        connection:Disconnect()
        connection = nil
    end

    print("[AutoSellFish] Stopped")
end

-- ===========================
-- Main loop
-- ===========================
local _lastTick = 0
function AutoSellFish:SellLoop()
    local now = tick()
    if now - _lastTick < WAIT_BETWEEN then
        return
    end
    _lastTick = now

    -- pastikan threshold sesuai (debounce)
    self:_applyThreshold(currentMode)

    -- cek limit backpack (Tool saja, di Backpack)
    if limitEnabled then
        self:UpdateInventoryCount()
        if lastInventoryCount >= limitValue then
            local ok = self:PerformSellAll()
            if ok then
                -- beri waktu server proses, lalu refresh count
                task.wait(0.1)
                self:UpdateInventoryCount()
            end
        end
    end
end

-- ===========================
-- Threshold apply (debounced)
-- ===========================
function AutoSellFish:_applyThreshold(mode)
    if not UpdateAutoSellThresholdRF then return false end
    if _lastAppliedMode == mode then return true end -- sudah sama, skip

    local code = THRESHOLD_ENUM[mode]
    if not code then return false end

    local ok = pcall(function()
        UpdateAutoSellThresholdRF:InvokeServer(code)
    end)

    if ok then
        _lastAppliedMode = mode
        -- print("[AutoSellFish] Threshold applied:", mode)
    else
        warn("[AutoSellFish] Failed to apply threshold:", mode)
    end
    return ok
end

-- ===========================
-- Sell All
-- ===========================
function AutoSellFish:PerformSellAll()
    if not SellAllItemsRF then return false end
    local ok = pcall(function()
        SellAllItemsRF:InvokeServer()
    end)
    if not ok then
        warn("[AutoSellFish] SellAllItems failed")
    end
    return ok
end

-- ===========================
-- Inventory utils (Tool di Backpack SAJA)
-- ===========================
function AutoSellFish:UpdateInventoryCount()
    lastInventoryCount = self:GetInventoryItemCount()
end

function AutoSellFish:GetInventoryItemCount()
    local count = 0
    local bp = LocalPlayer and LocalPlayer:FindFirstChild("Backpack")
    if not bp then return 0 end

    for _, child in ipairs(bp:GetChildren()) do
        if child:IsA("Tool") then
            count += 1
        end
    end
    return count
end

-- ===========================
-- Setters (dipanggil dari GUI)
-- ===========================
function AutoSellFish:SetMode(mode)
    if not THRESHOLD_ENUM[mode] then return false end
    currentMode = mode
    -- apply segera, tetap didebounce internalnya
    return self:_applyThreshold(mode)
end

function AutoSellFish:SetLimit(value)
    if typeof(value) ~= "number" then return false end
    limitValue = math.max(0, math.floor(value))
    return true
end

function AutoSellFish:SetAutoSellOnLimit(enabled)
    limitEnabled = not not enabled
    return true
end

function AutoSellFish:SetWaitBetween(sec)
    if typeof(sec) ~= "number" then return false end
    WAIT_BETWEEN = math.max(0.01, sec)
    return true
end

-- ===========================
-- Cleanup
-- ===========================
function AutoSellFish:Cleanup()
    print("[AutoSellFish] Cleaning up...")
    self:Stop()
    controls           = {}
    remotesInitialized = false
end

return AutoSellFish