-- ===========================
-- AUTO SELL FISH FEATURE
-- File: autosellfish.lua
-- ===========================

local AutoSellFish = {}
AutoSellFish.__index = AutoSellFish

-- Services
local Players        = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local LocalPlayer    = Players.LocalPlayer

-- Network objects (initialized in Init)
local NetPath = nil
local UpdateAutoSellThresholdRF, SellAllItemsRF

-- Initialize remote references. Returns true on success.
local function initializeRemotes()
    local success, err = pcall(function()
        NetPath = ReplicatedStorage:WaitForChild("Packages", 5)
            :WaitForChild("_Index", 5)
            :WaitForChild("sleitnick_net@0.2.0", 5)
            :WaitForChild("net", 5)
        UpdateAutoSellThresholdRF = NetPath:WaitForChild("RF/UpdateAutoSellThreshold", 5)
        SellAllItemsRF            = NetPath:WaitForChild("RF/SellAllItems", 5)
    end)
    return success
end

-- Rarity threshold enumeration. These numeric codes must match the
-- server‑side expectations for UpdateAutoSellThreshold.
local THRESHOLD_ENUM = {
    Legendary = 5,
    Mythic    = 6,
    Secret    = 7,
}

-- Internal state
local isRunning          = false
local connection         = nil
local remotesInitialized = false
local currentMode        = "Legendary" -- default rarity threshold
local lastAppliedMode    = nil         -- used to debounce threshold updates
local limitEnabled       = true        -- auto sell will run when true
local limitValue         = 0           -- number of fish (Tools) to trigger sell
local lastInventoryCount = 0           -- cached count of Tools in backpack

-- Interval between loop iterations (in seconds). A small wait
-- prevents the loop from overloading the Heartbeat event.
local WAIT_BETWEEN = 0.15
local _lastTick    = 0

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

-- Count how many fish (Tools) are currently in the player's Backpack.
-- The game treats fish as Tool instances in Backpack. Other items in
-- Backpack will also be counted, so only fish should be stored there.
local function getInventoryItemCount()
    local bp = LocalPlayer and LocalPlayer:FindFirstChild("Backpack")
    if not bp then return 0 end
    local count = 0
    for _, child in ipairs(bp:GetChildren()) do
        if child:IsA("Tool") then
            count = count + 1
        end
    end
    return count
end

-- Update the cached inventory count
function AutoSellFish:UpdateInventoryCount()
    lastInventoryCount = getInventoryItemCount()
end

-- Apply the rarity threshold on the server. This function is debounced
-- using `lastAppliedMode` to avoid sending the same value repeatedly.
function AutoSellFish:_applyThreshold(mode)
    if not UpdateAutoSellThresholdRF then return false end
    if lastAppliedMode == mode then return true end
    local code = THRESHOLD_ENUM[mode]
    if not code then return false end
    local ok = pcall(function()
        UpdateAutoSellThresholdRF:InvokeServer(code)
    end)
    if ok then
        lastAppliedMode = mode
    else
        warn("[AutoSellFish] Failed to apply threshold: " .. tostring(mode))
    end
    return ok
end

-- Trigger the remote call to sell all fish. Returns true on success.
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



--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

-- Init must be called before using the module. Optionally accepts a table
-- of GUI controls (not used by this module but provided for API parity).
function AutoSellFish:Init(guiControls)
    remotesInitialized = initializeRemotes()
    if not remotesInitialized then
        warn("[AutoSellFish] Failed to initialize remotes")
        return false
    end
    self:UpdateInventoryCount()
    return true
end

-- Start the automation. Accepts a config table:
--  threshold   : string ("Legendary", "Mythic", "Secret")
--  limit       : number (fish count to trigger sell)
--  autoOnLimit : boolean (enable/disable auto sell on limit)
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
        if type(config.limit) == "number" then
            limitValue = math.max(0, math.floor(config.limit))
        end
        if type(config.autoOnLimit) == "boolean" then
            limitEnabled = config.autoOnLimit
        end
    end
    -- Apply threshold once on start
    self:_applyThreshold(currentMode)
    isRunning = true
    connection = RunService.Heartbeat:Connect(function()
        if not isRunning then return end
        self:_loop()
    end)
end

-- Stop the automation and disconnect events.
function AutoSellFish:Stop()
    if not isRunning then return end
    isRunning = false
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

-- Cleanup resets internal state. Should be called when the feature is
-- unloaded from the GUI.
function AutoSellFish:Cleanup()
    self:Stop()
    remotesInitialized = false
end

-- Set the rarity threshold ("Legendary", "Mythic", "Secret"). Returns true
-- if the threshold is valid.
function AutoSellFish:SetMode(mode)
    if not THRESHOLD_ENUM[mode] then return false end
    currentMode = mode
    -- Apply immediately; debounced internally
    return self:_applyThreshold(mode)
end

-- Set the limit at which auto sell triggers. Must be non-negative.
function AutoSellFish:SetLimit(n)
    if type(n) ~= "number" then return false end
    limitValue = math.max(0, math.floor(n))
    return true
end

-- Enable or disable automatic selling when the limit is reached.
function AutoSellFish:SetAutoSellOnLimit(enabled)
    limitEnabled = not not enabled
    return true
end

--------------------------------------------------------------------------
-- Internal loop
--------------------------------------------------------------------------

-- The heartbeat loop checks whether the fish count meets the limit and
-- triggers a sell if necessary. It also reapplies the threshold as needed.
function AutoSellFish:_loop()
    local now = tick()
    if now - _lastTick < WAIT_BETWEEN then
        return
    end
    _lastTick = now
    -- Ensure threshold is applied (debounced)
    self:_applyThreshold(currentMode)
    -- Auto sell on limit
    if limitEnabled then
        self:UpdateInventoryCount()
        if lastInventoryCount >= limitValue and limitValue > 0 then
            if self:PerformSellAll() then
                -- Allow some time for the server to process the sale
                task.wait(0.1)
                self:UpdateInventoryCount()
            end
        end
    end
end

return AutoSellFish