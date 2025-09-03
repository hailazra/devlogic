-- ===========================
-- AUTO FISH FEATURE - OPTIMIZED
-- File: autofish.lua
-- ===========================

local AutoFishFeature = {}
AutoFishFeature.__index = AutoFishFeature

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")  
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Safe network path access
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
local fishingConnection = nil
local controls = {}
local fishingInProgress = false
local lastFishTime = 0
local remotesInitialized = false

-- Fishing detection
local biteDetectionActive = false
local castTime = 0

-- Speed-optimized configs
local FISHING_CONFIGS = {
    ["Perfect"] = {
        chargeTime = 1.0,
        waitBetween = 0.5,  -- Minimal wait between cycles
        rodSlot = 1,
        maxWaitForBite = 8   -- Max wait for fish bite
    },
    ["OK"] = {
        chargeTime = 0.9,
        waitBetween = 0.3,
        rodSlot = 1,
        maxWaitForBite = 6
    },
    ["Mid"] = {
        chargeTime = 0.5,
        waitBetween = 0.2,
        rodSlot = 1,
        maxWaitForBite = 5
    }
}

-- Initialize
function AutoFishFeature:Init(guiControls)
    controls = guiControls or {}
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
    if isRunning then return end
    
    if not remotesInitialized then
        warn("[AutoFish] Cannot start - remotes not initialized")
        return
    end
    
    isRunning = true
    currentMode = config.mode or "Perfect"
    fishingInProgress = false
    biteDetectionActive = false
    lastFishTime = 0
    
    print("[AutoFish] Started FAST mode:", currentMode)
    
    -- Main fishing loop (optimized for speed)
    connection = RunService.Heartbeat:Connect(function()
        if not isRunning then return end
        self:FastFishingLoop()
    end)
end

-- Stop fishing
function AutoFishFeature:Stop()
    if not isRunning then return end
    
    isRunning = false
    fishingInProgress = false
    biteDetectionActive = false
    
    if connection then
        connection:Disconnect()
        connection = nil
    end
    
    if fishingConnection then
        fishingConnection:Disconnect()
        fishingConnection = nil
    end
    
    print("[AutoFish] Stopped")
end

-- Optimized fishing loop for maximum speed
function AutoFishFeature:FastFishingLoop()
    if fishingInProgress or biteDetectionActive then return end
    
    local currentTime = tick()
    local config = FISHING_CONFIGS[currentMode]
    
    -- Minimal wait between cycles
    if currentTime - lastFishTime < config.waitBetween then
        return
    end
    
    -- Start fishing sequence
    fishingInProgress = true
    lastFishTime = currentTime
    
    spawn(function()
        local success = self:ExecuteFastFishingSequence()
        fishingInProgress = false
        
        if success then
            print("[AutoFish] FAST catch completed!")
        end
    end)
end

-- Execute FAST fishing sequence
function AutoFishFeature:ExecuteFastFishingSequence()
    local config = FISHING_CONFIGS[currentMode]
    
    -- Step 1: Equip rod (no wait)
    if not self:EquipRod(config.rodSlot) then
        return false
    end
    
    -- Step 2: Charge rod immediately
    if not self:ChargeRod(config.chargeTime) then
        return false
    end
    
    -- Step 3: Cast rod immediately  
    if not self:CastRod() then
        return false
    end
    
    -- Step 4: Start bite detection
    castTime = tick()
    self:StartBiteDetection(config.maxWaitForBite)
    
    return true
end

-- Equip fishing rod (fast)
function AutoFishFeature:EquipRod(slot)
    if not EquipTool then return false end
    
    local success = pcall(function()
        EquipTool:FireServer(slot)
    end)
    
    return success
end

-- Charge fishing rod (fast)
function AutoFishFeature:ChargeRod(chargeTime)
    if not ChargeFishingRod then return false end
    
    local success, result = pcall(function()
        local chargeValue = tick() + (chargeTime * 1000) -- Convert to milliseconds
        return ChargeFishingRod:InvokeServer(chargeValue)
    end)
    
    return success
end

-- Cast rod (fast)
function AutoFishFeature:CastRod()
    if not RequestFishing then return false end
    
    local success = pcall(function()
        -- Fixed good cast position
        local x = -1.2  -- Consistent position
        local z = 0.8
        return RequestFishing:InvokeServer(x, z)
    end)
    
    return success
end

-- Start bite detection system
function AutoFishFeature:StartBiteDetection(maxWaitTime)
    if biteDetectionActive then return end
    
    biteDetectionActive = true
    
    spawn(function()
        -- Method 1: Check for UI elements (tanda seru)
        local detected = self:DetectFishBite(maxWaitTime)
        
        if detected and isRunning then
            wait(0.1) -- Tiny delay for stability
            self:CompleteInstantCatch()
        end
        
        biteDetectionActive = false
    end)
end

-- Detect fish bite via multiple methods
function AutoFishFeature:DetectFishBite(maxWaitTime)
    local startTime = tick()
    local player = LocalPlayer
    
    while tick() - startTime < maxWaitTime and isRunning and biteDetectionActive do
        -- Method 1: Check character for fishing tool state
        if player.Character then
            local tool = player.Character:FindFirstChildOfClass("Tool")
            if tool then
                -- Check tool properties that might indicate bite
                local handle = tool:FindFirstChild("Handle")
                if handle then
                    -- Some games modify tool properties on bite
                    -- This is game-specific, might need adjustment
                end
            end
        end
        
        -- Method 2: Check PlayerGui for bite indicators
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            -- Look for fishing UI elements (tanda seru UI)
            for _, gui in pairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    local found = self:CheckGuiForBiteIndicator(gui)
                    if found then
                        print("[AutoFish] Bite detected via GUI!")
                        return true
                    end
                end
            end
        end
        
        -- Method 3: Time-based detection (fallback)
        local elapsedTime = tick() - castTime
        if elapsedTime >= 2 and elapsedTime <= maxWaitTime then
            -- Fish typically bite within 2-8 seconds
            print("[AutoFish] Bite assumed (time-based)")
            return true
        end
        
        wait(0.1) -- Check every 100ms
    end
    
    return false
end

-- Check GUI for bite indicators
function AutoFishFeature:CheckGuiForBiteIndicator(gui)
    -- Look for exclamation mark or fishing indicators
    local function searchForIndicator(obj)
        if not obj then return false end
        
        -- Check for common bite indicator patterns
        if obj.Name:lower():find("exclamation") or 
           obj.Name:lower():find("bite") or
           obj.Name:lower():find("fish") then
            if obj:IsA("GuiObject") and obj.Visible then
                return true
            end
        end
        
        -- Check text for "!" or fishing terms
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = obj.Text:lower()
            if text:find("!") or text:find("bite") or text:find("pull") then
                return obj.Visible
            end
        end
        
        -- Recursively check children
        for _, child in pairs(obj:GetChildren()) do
            if searchForIndicator(child) then
                return true
            end
        end
        
        return false
    end
    
    return searchForIndicator(gui)
end

-- Complete catch instantly
function AutoFishFeature:CompleteInstantCatch()
    if not FishingCompleted then return false end
    
    local success = pcall(function()
        FishingCompleted:FireServer()
    end)
    
    if success then
        print("[AutoFish] INSTANT catch completed!")
    end
    
    return success
end

-- Get status
function AutoFishFeature:GetStatus()
    return {
        running = isRunning,
        mode = currentMode,
        inProgress = fishingInProgress,
        detecting = biteDetectionActive,
        lastCatch = lastFishTime,
        remotesReady = remotesInitialized
    }
end

-- Update mode
function AutoFishFeature:SetMode(mode)
    if FISHING_CONFIGS[mode] then
        currentMode = mode
        print("[AutoFish] FAST mode changed to:", mode)
        return true
    end
    return false
end

-- Cleanup
function AutoFishFeature:Cleanup()
    print("[AutoFish] Cleaning up...")
    self:Stop()
    controls = {}
    remotesInitialized = false
end

return AutoFishFeature