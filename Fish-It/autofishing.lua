-- ===========================
-- AUTO FISH FEATURE
-- File: autofish.lua
-- ===========================

local AutoFishFeature = {}
AutoFishFeature.__index = AutoFishFeature

-- Services (pass dari GUI utama atau akses global)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Network path
local NetPath = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")

-- Remotes
local EquipTool = NetPath:WaitForChild("RE/EquipToolFromHotbar")
local ChargeFishingRod = NetPath:WaitForChild("RF/ChargeFishingRod")
local RequestFishing = NetPath:WaitForChild("RF/RequestFishingMinigameStarted")
local FishingCompleted = NetPath:WaitForChild("RE/FishingCompleted")

-- Feature state
local isRunning = false
local currentMode = "Perfect"
local connection = nil
local controls = {}
local fishingInProgress = false
local lastFishTime = 0

-- Config based on mode
local FISHING_CONFIGS = {
    ["Perfect"] = {
        chargeTime = 1,
        waitTime = 2.0,
        rodSlot = 1
    },
    ["OK"] = {
        chargeTime = 0.9,
        waitTime = 4.0,
        rodSlot = 1
    },
    ["Mid"] = {
        chargeTime = 0.5,
        waitTime = 5.0,
        rodSlot = 1
    }
}

-- Initialize
function AutoFishFeature:Init(guiControls)
    controls = guiControls
    print("[AutoFish] Initialized")
    return true
end

-- Start fishing
function AutoFishFeature:Start(config)
    if isRunning then return end
    
    isRunning = true
    currentMode = config.mode or "Perfect"
    fishingInProgress = false
    
    print("[AutoFish] Started - Mode:", currentMode)
    
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
            print("[AutoFish] Fish caught!")
        else
            print("[AutoFish] Fishing failed, retrying...")
        end
        
        fishingInProgress = false
    end)
end

-- Execute full fishing sequence
function AutoFishFeature:ExecuteFishingSequence()
    local config = FISHING_CONFIGS[currentMode]
    
    -- Step 1: Equip rod
    if not self:EquipRod(config.rodSlot) then
        return false
    end
    
    wait(0.5)
    
    -- Step 2: Charge rod
    local chargeValue = self:ChargeRod(config.chargeTime)
    if not chargeValue then
        return false
    end
    
    wait(0.3)
    
    -- Step 3: Cast rod
    if not self:CastRod() then
        return false
    end
    
    -- Step 4: Wait for fish and complete
    return self:WaitAndComplete()
end

-- Equip fishing rod
function AutoFishFeature:EquipRod(slot)
    local success, result = pcall(function()
        EquipTool:FireServer(slot)
        return true
    end)
    
    return success
end

-- Charge fishing rod
function AutoFishFeature:ChargeRod(chargeTime)
    local success, result = pcall(function()
        -- Generate charge value based on time
        local chargeValue = tick() + math.random(100, 500) / 1000
        return ChargeFishingRod:InvokeServer(chargeValue)
    end)
    
    if success then
        wait(chargeTime)
        return result
    end
    
    return nil
end

-- Cast rod to water
function AutoFishFeature:CastRod()
    local success, result = pcall(function()
        -- Random cast direction
        local x = math.random(-200, 200) / 100
        local z = math.random(50, 150) / 100
        
        return RequestFishing:InvokeServer(x, z)
    end)
    
    return success and result
end

-- Wait for fish and complete catch
function AutoFishFeature:WaitAndComplete()
    -- Wait for fish bite (simulate)
    local waitTime = math.random(2, 5)
    wait(waitTime)
    
    -- Complete fishing
    local success, result = pcall(function()
        FishingCompleted:FireServer()
        return true
    end)
    
    return success
end

-- Get fishing status
function AutoFishFeature:GetStatus()
    return {
        running = isRunning,
        mode = currentMode,
        inProgress = fishingInProgress,
        lastCatch = lastFishTime
    }
end

-- Update mode
function AutoFishFeature:SetMode(mode)
    if FISHING_CONFIGS[mode] then
        currentMode = mode
        print("[AutoFish] Mode changed to:", mode)
    end
end

-- Cleanup
function AutoFishFeature:Cleanup()
    self:Stop()
    controls = {}
end

-- Return feature
return AutoFishFeature
