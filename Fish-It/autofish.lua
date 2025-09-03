-- ===========================
-- AUTO FISH FEATURE - SPAM METHOD (FIXED)
-- File: autofishv4_fixed.lua
-- ===========================

local AutoFishFeature = {}
AutoFishFeature.__index = AutoFishFeature

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")  
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Network setup
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
local spamConnection = nil
local equipConnection = nil
local controls = {}
local fishingInProgress = false
local lastFishTime = 0
local remotesInitialized = false

-- Spam and completion tracking
local spamActive = false
local completionCheckActive = false
local lastCaughtCount = 0

-- Auto equip state
local autoEquipEnabled = true
local rodEquipped = false

-- Rod-specific configs
local FISHING_CONFIGS = {
    ["Perfect"] = {
        chargeTime = 1.0,
        waitBetween = 0.5,
        rodSlot = 1,
        spamDelay = 0.05,      -- Spam every 50ms
        maxSpamTime = 3        -- Stop spam after 3s
    },
    ["OK"] = {
        chargeTime = 0.9,
        waitBetween = 0.3,
        rodSlot = 1,
        spamDelay = 0.1,
        maxSpamTime = 8
    },
    ["Mid"] = {
        chargeTime = 0.5,
        waitBetween = 0.2,
        rodSlot = 1,
        spamDelay = 0.1,
        maxSpamTime = 6
    }
}

-- Initialize
function AutoFishFeature:Init(guiControls)
    controls = guiControls or {}
    remotesInitialized = initializeRemotes()
    
    if not remotesInitialized then
        warn("[AutoFish] Failed to initialize remotes")
        return false
    end
    
    -- Initialize caught count for completion detection
    self:UpdateCaughtCount()
    
    print("[AutoFish] Initialized with SPAM method (FIXED)")
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
    spamActive = false
    lastFishTime = 0
    rodEquipped = false
    autoEquipEnabled = true
    
    print("[AutoFish] Started SPAM method (FIXED) - Mode:", currentMode)
    
    -- Auto equip monitoring (continuous)
    equipConnection = RunService.Heartbeat:Connect(function()
        if not isRunning then return end
        self:MonitorRodEquip()
    end)
    
    -- Main fishing loop
    connection = RunService.Heartbeat:Connect(function()
        if not isRunning then return end
        self:SpamFishingLoop()
    end)
end

-- Stop fishing
function AutoFishFeature:Stop()
    if not isRunning then return end
    
    isRunning = false
    fishingInProgress = false
    spamActive = false
    completionCheckActive = false
    rodEquipped = false
    autoEquipEnabled = false
    
    if connection then
        connection:Disconnect()
        connection = nil
    end
    
    if spamConnection then
        spamConnection:Disconnect()
        spamConnection = nil
    end
    
    if equipConnection then
        equipConnection:Disconnect()
        equipConnection = nil
    end
    
    print("[AutoFish] Stopped SPAM method (FIXED)")
end

-- Monitor and auto-equip rod
function AutoFishFeature:MonitorRodEquip()
    if not autoEquipEnabled or fishingInProgress then return end
    
    local config = FISHING_CONFIGS[currentMode]
    local isEquipped = self:IsRodEquipped()
    
    if not isEquipped then
        rodEquipped = false
        -- Auto equip rod
        self:EquipRod(config.rodSlot)
        wait(0.1) -- Small delay after equipping
    else
        rodEquipped = true
    end
end

-- Check if rod is equipped
function AutoFishFeature:IsRodEquipped()
    if not LocalPlayer.Character then return false end
    
    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool then
        local toolName = tool.Name:lower()
        -- Check if it's a fishing rod (adjust based on game's rod names)
        if toolName:find("rod") or toolName:find("fishing") or toolName:find("pole") then
            return true
        end
    end
    
    return false
end

-- Main spam-based fishing loop
function AutoFishFeature:SpamFishingLoop()
    if fishingInProgress or spamActive or not rodEquipped then return end
    
    local currentTime = tick()
    local config = FISHING_CONFIGS[currentMode]
    
    -- Wait between cycles
    if currentTime - lastFishTime < config.waitBetween then
        return
    end
    
    -- Start fishing sequence
    fishingInProgress = true
    lastFishTime = currentTime
    
    spawn(function()
        local success = self:ExecuteSpamFishingSequence()
        fishingInProgress = false
        
        if success then
            print("[AutoFish] SPAM cycle completed!")
        end
    end)
end

-- Execute spam-based fishing sequence
function AutoFishFeature:ExecuteSpamFishingSequence()
    local config = FISHING_CONFIGS[currentMode]
    
    -- Step 1: Ensure rod is equipped (double check)
    if not self:IsRodEquipped() then
        if not self:EquipRod(config.rodSlot) then
            return false
        end
        wait(0.2) -- Wait for equip to complete
    end
    
    -- Step 2: Charge rod
    if not self:ChargeRod(config.chargeTime) then
        return false
    end
    
    -- Step 3: Cast rod
    if not self:CastRod() then
        return false
    end
    
    -- Step 4: Start completion spam with leaderstats detection
    self:StartCompletionSpam(config.spamDelay, config.maxSpamTime)
    
    return true
end

-- Equip rod
function AutoFishFeature:EquipRod(slot)
    if not EquipTool then return false end
    
    local success = pcall(function()
        EquipTool:FireServer(slot)
    end)
    
    if success then
        wait(0.1) -- Give time for equip to process
    end
    
    return success
end

-- Charge rod
function AutoFishFeature:ChargeRod(chargeTime)
    if not ChargeFishingRod then return false end
    
    local success = pcall(function()
        local chargeValue = tick() + (chargeTime * 1000)
        return ChargeFishingRod:InvokeServer(chargeValue)
    end)
    
    return success
end

-- Cast rod
function AutoFishFeature:CastRod()
    if not RequestFishing then return false end
    
    local success = pcall(function()
        local x = -1.2
        local z = 0.8
        return RequestFishing:InvokeServer(x, z)
    end)
    
    return success
end

-- Start spamming FishingCompleted with leaderstats detection
function AutoFishFeature:StartCompletionSpam(delay, maxTime)
    if spamActive then return end
    
    spamActive = true
    completionCheckActive = true
    local spamStartTime = tick()
    
    print("[AutoFish] Starting completion SPAM with leaderstats detection...")
    
    -- Update caught count before spam
    self:UpdateCaughtCount()
    
    spawn(function()
        while spamActive and isRunning and (tick() - spamStartTime) < maxTime do
            -- Fire completion
            local fired = self:FireCompletion()
            
            -- Check if fishing completed using leaderstats
            if self:CheckFishingCompletedByLeaderstats() then
                print("[AutoFish] Fish caught detected via leaderstats!")
                break
            end
            
            wait(delay)
        end
        
        -- Stop spam
        spamActive = false
        completionCheckActive = false
        
        if (tick() - spamStartTime) >= maxTime then
            print("[AutoFish] SPAM timeout after", maxTime, "seconds")
        end
    end)
end

-- Fire FishingCompleted
function AutoFishFeature:FireCompletion()
    if not FishingCompleted then return false end
    
    local success = pcall(function()
        FishingCompleted:FireServer()
    end)
    
    return success
end

-- Check if fishing completed using leaderstats (PRIMARY METHOD)
function AutoFishFeature:CheckFishingCompletedByLeaderstats()
    local currentCaught = self:GetCaughtCount()
    
    -- If caught count increased, fish was successfully caught
    if currentCaught > lastCaughtCount then
        lastCaughtCount = currentCaught
        print("[AutoFish] Leaderstats detection: Caught increased to", currentCaught)
        return true
    end
    
    return false
end

-- Get current caught count from leaderstats
function AutoFishFeature:GetCaughtCount()
    local caught = 0
    
    pcall(function()
        -- Access Player[Username].leaderstats.Caught.Data.Value
        local player = LocalPlayer
        local leaderstats = player:FindFirstChild("leaderstats")
        
        if leaderstats then
            local caughtStat = leaderstats:FindFirstChild("Caught")
            if caughtStat then
                local data = caughtStat:FindFirstChild("Data")
                if data then
                    local value = data:FindFirstChild("Value")
                    if value then
                        caught = tonumber(value.Value) or 0
                    end
                end
            end
        end
    end)
    
    return caught
end

-- Update caught count
function AutoFishFeature:UpdateCaughtCount()
    lastCaughtCount = self:GetCaughtCount()
    print("[AutoFish] Updated caught count:", lastCaughtCount)
end

-- Fallback: Check if fishing completed by other methods
function AutoFishFeature:CheckFishingCompleted()
    -- Primary method: leaderstats
    if self:CheckFishingCompletedByLeaderstats() then
        return true
    end
    
    -- Fallback method: Check tool state
    if LocalPlayer.Character then
        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if not tool then
            -- Tool unequipped might indicate completion
            return false -- Don't rely on this alone for spam method
        end
    end
    
    return false
end

-- Get status
function AutoFishFeature:GetStatus()
    return {
        running = isRunning,
        mode = currentMode,
        inProgress = fishingInProgress,
        spamming = spamActive,
        rodEquipped = rodEquipped,
        autoEquip = autoEquipEnabled,
        lastCatch = lastFishTime,
        caughtCount = lastCaughtCount,
        remotesReady = remotesInitialized
    }
end

-- Update mode
function AutoFishFeature:SetMode(mode)
    if FISHING_CONFIGS[mode] then
        currentMode = mode
        print("[AutoFish] SPAM mode changed to:", mode)
        return true
    end
    return false
end

-- Toggle auto equip
function AutoFishFeature:SetAutoEquip(enabled)
    autoEquipEnabled = enabled
    print("[AutoFish] Auto equip", enabled and "enabled" or "disabled")
end

-- Manual equip rod
function AutoFishFeature:ManualEquipRod()
    local config = FISHING_CONFIGS[currentMode]
    return self:EquipRod(config.rodSlot)
end

-- Get leaderstats info for debugging
function AutoFishFeature:GetLeaderstatsInfo()
    local info = {
        hasLeaderstats = false,
        hasCaught = false,
        hasData = false,
        hasValue = false,
        currentValue = 0
    }
    
    pcall(function()
        local player = LocalPlayer
        local leaderstats = player:FindFirstChild("leaderstats")
        
        if leaderstats then
            info.hasLeaderstats = true
            local caughtStat = leaderstats:FindFirstChild("Caught")
            
            if caughtStat then
                info.hasCaught = true
                local data = caughtStat:FindFirstChild("Data")
                
                if data then
                    info.hasData = true
                    local value = data:FindFirstChild("Value")
                    
                    if value then
                        info.hasValue = true
                        info.currentValue = tonumber(value.Value) or 0
                    end
                end
            end
        end
    end)
    
    return info
end

-- Cleanup
function AutoFishFeature:Cleanup()
    print("[AutoFish] Cleaning up SPAM method (FIXED)...")
    self:Stop()
    controls = {}
    remotesInitialized = false
end

return AutoFishFeature