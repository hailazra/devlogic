-- ===========================
-- AUTO TELEPORT ISLAND FEATURE
-- File: autoteleportisland.lua
-- ===========================

local AutoTeleportIsland = {}
AutoTeleportIsland.__index = AutoTeleportIsland

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Feature state
local isInitialized = false
local controls = {}
local currentIsland = "Fisherman Island"

-- Island mapping - maps display names to actual folder names
local ISLAND_MAPPING = {
    ["Fisherman Island"] = "Fisherman Island",
    ["Kohana"] = "Kohana",
    ["Kohana Volcano"] = "Kohana Volcano", 
    ["Coral Reefs"] = "Coral Reefs",
    ["Esoteric Depths"] = "Esoteric Depths",
    ["Tropical Grove"] = "Tropical Grove",
    ["Crater Island"] = "Crater Island",
    ["Lost Isle"] = "Lost Isle"
}

-- Get all available islands from workspace
function AutoTeleportIsland:GetAvailableIslands()
    local islands = {}
    local islandLocations = Workspace:FindFirstChild("!!!! ISLAND LOCATIONS !!!!")
    
    if islandLocations then
        for _, child in pairs(islandLocations:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                table.insert(islands, child.Name)
            end
        end
    end
    
    return islands
end

-- Get island CFrame from workspace
function AutoTeleportIsland:GetIslandCFrame(islandName)
    local islandLocations = Workspace:FindFirstChild("!!!! ISLAND LOCATIONS !!!!")
    if not islandLocations then
        warn("[AutoTeleportIsland] Island locations folder not found")
        return nil
    end
    
    local actualName = ISLAND_MAPPING[islandName] or islandName
    local island = islandLocations:FindFirstChild(actualName)
    if not island then
        warn("[AutoTeleportIsland] Island not found:", actualName)
        return nil
    end
    
    -- Try to find CFrame in Transform
    local transform = island:FindFirstChild("Transform")
    if transform and transform:IsA("CFrameValue") then
        return transform.Value
    end
    
    -- Alternative: look for a Part with CFrame
    local part = island:FindFirstChildOfClass("Part")
    if part then
        return part.CFrame
    end
    
    -- Alternative: look for a Model with PrimaryPart
    if island:IsA("Model") and island.PrimaryPart then
        return island.PrimaryPart.CFrame
    end
    
    warn("[AutoTeleportIsland] Could not find CFrame for island:", actualName)
    return nil
end

-- Teleport player to position
function AutoTeleportIsland:TeleportToPosition(cframe)
    if not LocalPlayer.Character then
        warn("[AutoTeleportIsland] Player character not found")
        return false
    end
    
    local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        warn("[AutoTeleportIsland] HumanoidRootPart not found")
        return false
    end
    
    local success = pcall(function()
        -- Add slight Y offset to prevent spawning inside terrain
        local offsetCFrame = cframe + Vector3.new(0, 5, 0)
        humanoidRootPart.CFrame = offsetCFrame
    end)
    
    return success
end

-- Initialize the feature
function AutoTeleportIsland:Init(guiControls)
    controls = guiControls or {}
    isInitialized = true
    
    print("[AutoTeleportIsland] Initialized successfully")
    return true
end

-- Set target island
function AutoTeleportIsland:SetIsland(islandName)
    if ISLAND_MAPPING[islandName] or self:GetAvailableIslands()[islandName] then
        currentIsland = islandName
        print("[AutoTeleportIsland] Target island set to:", islandName)
        return true
    else
        warn("[AutoTeleportIsland] Invalid island name:", islandName)
        return false
    end
end

-- Perform teleportation
function AutoTeleportIsland:Teleport(targetIsland)
    if not isInitialized then
        warn("[AutoTeleportIsland] Feature not initialized")
        return false
    end
    
    local island = targetIsland or currentIsland
    print("[AutoTeleportIsland] Attempting to teleport to:", island)
    
    local cframe = self:GetIslandCFrame(island)
    if not cframe then
        warn("[AutoTeleportIsland] Could not get CFrame for island:", island)
        return false
    end
    
    local success = self:TeleportToPosition(cframe)
    if success then
        print("[AutoTeleportIsland] Successfully teleported to:", island)
        
        -- Notify GUI if available
        if _G.WindUI then
            _G.WindUI:Notify({
                Title = "Teleport Success",
                Content = "Teleported to " .. island,
                Icon = "map-pin",
                Duration = 2
            })
        end
    else
        warn("[AutoTeleportIsland] Failed to teleport to:", island)
        
        -- Notify GUI if available (using WindUI from outside scope)
        if WindUI then
            WindUI:Notify({
                Title = "Teleport Failed",
                Content = "Could not teleport to " .. island,
                Icon = "x",
                Duration = 3
            })
        end
    end
    
    return success
end

-- Get current status
function AutoTeleportIsland:GetStatus()
    return {
        initialized = isInitialized,
        currentIsland = currentIsland,
        availableIslands = self:GetAvailableIslands()
    }
end

-- Get list of islands for dropdown
function AutoTeleportIsland:GetIslandList()
    local islands = {}
    for displayName, _ in pairs(ISLAND_MAPPING) do
        table.insert(islands, displayName)
    end
    table.sort(islands)
    return islands
end

-- Cleanup
function AutoTeleportIsland:Cleanup()
    print("[AutoTeleportIsland] Cleaning up...")
    controls = {}
    isInitialized = false
end

return AutoTeleportIsland