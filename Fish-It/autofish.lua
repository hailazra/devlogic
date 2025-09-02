-- ===========================
-- AUTO FISH FEATURE - FIXED
-- File: autofish.lua
-- ===========================

local AutoFishFeature = {}
AutoFishFeature.__index = AutoFishFeature

-- Safe service access
local function getService(serviceName)
    return game:GetService(serviceName)
end

-- Services
local Players = getService("Players")
local ReplicatedStorage = getService("ReplicatedStorage")  
local RunService = getService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Safe network path access with error handling
local NetPath = nil
local EquipTool, ChargeFishingRod, RequestFishing, FishingCompleted

local function initializeRemotes()
    local success = pcall(function()
        NetPath = ReplicatedStorage:WaitForChild("Packages", 5)
            :WaitForChild("_Index", 5)
            :WaitForChild("sleitnick_net@0.2.0", 5)
            :WaitForChild("net", 5)
        
        EquipTool = NetPath:WaitForChild("RE/EquipToolFromHotbar", 5)
        ChargeFishingRod = NetPath:WaitForChild("RF/ChargeFishingRod", 5)
        RequestFishing = NetPath:WaitForChild("RF/RequestFishingMinigameStarted", 5)
        FishingCompleted = NetPath:WaitForChild("RE/FishingCompleted", 5)
        
        return true
    end)
    
    return success
end

-- Feature state
local isRunning = false
local currentMode = "Perfect"
local connection = nil
local controls = {}
local fishingInProgress = false
local lastFishTime = 0
local remotesInitialized = false

-- Config based on mode
local FISHING_CONFIGS = {
    ["Perfect"] = {
        chargeTime = 1.0,
        waitTime = 1.0,
        rodSlot = 1
    },
    ["OK"] = {
        chargeTime = 0.9,
        waitTime = 3.0,
        rodSlot = 1
    },
    ["Mid"] = {
        chargeTime = 0.5,
        waitTime = 4.0,
        rodSlot = 1
    }
}

-- Initialize
function AutoFishFeature:Init(guiControls)
    controls = guiControls or {}
    
    -- Initialize remotes
    remotesInitialized = initializeRemotes()
    
    if not remotesInitialized then
        warn("[AutoFish] Failed to initialize network remotes")
        return false
    end
    
    print("[AutoFish] Initialized successfully")
    return true
end

-- Start fishing
function AutoFishFeature:Start(config)
    if isRunning then 
        print("[AutoFish] Already running")
        return 
    end
    
    if not remotesInitialized then
        warn("[AutoFish] Cannot start - remotes not initialized")
        return
    end
    
    isRunning = true
    currentMode = config.mode or "Perfect"
    fishingInProgress = false
    lastFishTime = 0
    
    print("[AutoFish] Started with mode:", currentMode)
    
    -- Main fishing loop
    connection = RunService.Heartbeat:Connect(function()
        if not isRunning then return end
        self:FishingLoop()
    end)
end

-- Stop fishing
function AutoFishFeature:Stop()
    if not isRunning then return end
    
    isRunning = false
    fishingInProgress = false
    
    if connection then
        connection:Disconnect()
        connection = nil
    end
    
    print("[AutoFish] Stopped")
end

-- Main fishing logic
function AutoFishFeature:FishingLoop()
    if fishingInProgress then return end
    
    local currentTime = tick()
    local config = FISHING_CONFIGS[currentMode]
    
    -- Wait between catches
    if currentTime - lastFishTime < config.waitTime then
        return
    end
    
    -- Start fishing sequence
    fishingInProgress = true
    
    spawn(function()
        local success = self:ExecuteFishingSequence()
        
        if success then
            lastFishTime = tick()
            print("[AutoFish] Fish caught! Mode:", currentMode)
        else
            print("[AutoFish] Fishing failed, retrying in", config.waitTime, "seconds")
        end
        
        wait(0.5) -- Small delay before next attempt
        fishingInProgress = false
    end)
end

-- Execute full fishing sequence
function AutoFishFeature:ExecuteFishingSequence()
    local config = FISHING_CONFIGS[currentMode]
    
    print("[AutoFish] Starting fishing sequence...")
    
    -- Step 1: Equip rod
    if not self:EquipRod(config.rodSlot) then
        warn("[AutoFish] Failed to equip rod")
        return false
    end
    
    wait(0.5)
    
    -- Step 2: Charge rod
    local chargeValue = self:ChargeRod(config.chargeTime)
    if not chargeValue then
        warn("[AutoFish] Failed to charge rod")
        return false
    end
    
    wait(0.3)
    
    -- Step 3: Cast rod
    if not self:CastRod() then
        warn("[AutoFish] Failed to cast rod")
        return false
    end
    
    -- Step 4: Wait for fish and complete
    return self:WaitAndComplete()
end

-- Equip fishing rod
function AutoFishFeature:EquipRod(slot)
    if not EquipTool then return false end
    
    local success, result = pcall(function()
        EquipTool:FireServer(slot)
        return true
    end)
    
    if success then
        print("[AutoFish] Rod equipped")
    else
        warn("[AutoFish] Failed to equip rod:", result)
    end
    
    return success
end

-- Charge fishing rod
function AutoFishFeature:ChargeRod(chargeTime)
    if not ChargeFishingRod then return false end
    
    local success, result = pcall(function()
        -- Generate realistic charge value
        local chargeValue = tick() + math.random(100, 300) / 1000
        local response = ChargeFishingRod:InvokeServer(chargeValue)
        return response
    end)
    
    if success then
        wait(chargeTime)
        print("[AutoFish] Rod charged")
        return result
    else
        warn("[AutoFish] Failed to charge rod:", result)
        return nil
    end
end

-- Cast rod to water
function AutoFishFeature:CastRod()
    if not RequestFishing then return false end
    
    local success, result = pcall(function()
        -- Random cast direction for natural behavior
        local x = math.random(-150, 150) / 100  -- -1.5 to 1.5
        local z = math.random(80, 120) / 100    -- 0.8 to 1.2
        
        local response = RequestFishing:InvokeServer(x, z)
        return response
    end)
    
    if success then
        print("[AutoFish] Rod cast")
        return result
    else
        warn("[AutoFish] Failed to cast rod:", result)
        return false
    end
end

-- Wait for fish and complete catch
function AutoFishFeature:WaitAndComplete()
    if not FishingCompleted then return false end
    
    -- Wait for fish bite (realistic timing)
    local waitTime = math.random(200, 400) / 100  -- 2-4 seconds
    wait(waitTime)
    
    -- Complete fishing
    local success, result = pcall(function()
        FishingCompleted:FireServer()
        return true
    end)
    
    if success then
        print("[AutoFish] Fishing completed")
    else
        warn("[AutoFish] Failed to complete fishing:", result)
    end
    
    return success
end

-- Get fishing status
function AutoFishFeature:GetStatus()
    return {
        running = isRunning,
        mode = currentMode,
        inProgress = fishingInProgress,
        lastCatch = lastFishTime,
        remotesReady = remotesInitialized
    }
end

-- Update mode during runtime
function AutoFishFeature:SetMode(mode)
    if FISHING_CONFIGS[mode] then
        currentMode = mode
        print("[AutoFish] Mode changed to:", mode)
        return true
    else
        warn("[AutoFish] Invalid mode:", mode)
        return false
    end
end

-- Check if feature is ready
function AutoFishFeature:IsReady()
    return remotesInitialized and EquipTool and ChargeFishingRod and RequestFishing and FishingCompleted
end

-- Cleanup
function AutoFishFeature:Cleanup()
    print("[AutoFish] Cleaning up...")
    self:Stop()
    controls = {}
    remotesInitialized = false
end

-- Return feature table
return AutoFishFeature