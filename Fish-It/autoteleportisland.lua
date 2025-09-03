-- ===========================
-- AUTO TELEPORT ISLAND FEATURE
-- File: autoteleport.lua
-- ===========================
local AutoTeleport = {}
AutoTeleport.__index = AutoTeleport

-- Services
local Players    = game:GetService("Players")
local Workspace  = game:GetService("Workspace")

-- Internal state
local isRunning     = false
local currentIsland = nil

--====================================================================
-- Public API
--====================================================================

-- Init is required for API parity. It currently does no setup but
-- returns true for consistency. You could extend this to verify the
-- presence of the island folder.
function AutoTeleport:Init(guiControls)
    return true
end

-- Start does not spin up any loops for teleporting; instead, it
-- optionally teleports once based on the provided config. The config
-- table may include an `island` key with the name of the island.
function AutoTeleport:Start(config)
    if isRunning then return end
    isRunning = true
    if config and config.island then
        currentIsland = config.island
        -- Immediately teleport if island provided
        self:Teleport(currentIsland)
    end
end

-- Stop simply marks the feature as inactive. There is no ongoing
-- loop to disconnect for this feature.
function AutoTeleport:Stop()
    if not isRunning then return end
    isRunning = false
end

-- Cleanup resets internal state. Should be called when unloading
-- the feature.
function AutoTeleport:Cleanup()
    self:Stop()
    currentIsland = nil
end

-- SetIsland updates the stored island name. The user can call
-- `Teleport()` afterwards or include the island in the Start config.
function AutoTeleport:SetIsland(name)
    currentIsland = name
end

-- Teleport moves the local player to the specified island. If
-- `islandName` is omitted, it uses the current stored island. It
-- returns true on success, false on failure.
function AutoTeleport:Teleport(islandName)
    local targetName = islandName or currentIsland
    if not targetName then return false end
    local islandsFolder = Workspace:FindFirstChild("!!!! ISLAND LOCATIONS !!!!")
    if not islandsFolder then
        warn("[AutoTeleport] '!!!! ISLAND LOCATIONS !!!!' folder not found")
        return false
    end
    local island = islandsFolder:FindFirstChild(targetName)
    if not island then
        warn("[AutoTeleport] Island '" .. tostring(targetName) .. "' not found")
        return false
    end
    -- Attempt to locate the Transform object and extract a CFrame
    local transform = island:FindFirstChild("Transform")
    local targetCFrame = nil
    if transform then
        -- If Transform is a CFrameValue
        if transform:IsA("CFrameValue") then
            targetCFrame = transform.Value
        -- If Transform is a Part or Model with a CFrame property
        elseif transform:IsA("BasePart") then
            targetCFrame = transform.CFrame
        else
            -- Check for a child named "CFrame" that might be a CFrameValue
            local cfVal = transform:FindFirstChild("CFrame")
            if cfVal and cfVal:IsA("CFrameValue") then
                targetCFrame = cfVal.Value
            end
        end
    end
    if not targetCFrame then
        warn("[AutoTeleport] No CFrame found for island '" .. tostring(targetName) .. "'")
        return false
    end
    -- Teleport the player's HumanoidRootPart
    local character = Players.LocalPlayer.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    -- Offset upward slightly to avoid getting stuck in the ground
    local offsetCFrame = targetCFrame + Vector3.new(0, 3, 0)
    pcall(function()
        rootPart.CFrame = offsetCFrame
    end)
    return true
end

return AutoTeleport