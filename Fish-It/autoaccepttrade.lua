--- AutoAcceptTrade.lua - Robust Version (Fixed All Issues)
local AutoAcceptTrade = {}
AutoAcceptTrade.__index = AutoAcceptTrade

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- State
local running = false
local isProcessingTrade = false
local currentTradeData = nil
local notificationConnection = nil

-- Statistics
local totalTradesAccepted = 0
local currentSessionTrades = 0

-- Remotes
local awaitTradeResponseRemote = nil
local textNotificationRemote = nil
local originalAwaitTradeCB = nil
local newindexHookInstalled = false

-- === ROBUST REMOTE FINDER ===
local function findRemoteWithFallback(remoteName, maxRetries)
    maxRetries = maxRetries or 3
    
    -- Common paths untuk berbagai versi game
    local searchPaths = {
        function() 
            return ReplicatedStorage:WaitForChild("Packages", 5)
                                   :WaitForChild("_Index", 5)
                                   :WaitForChild("sleitnick_net@0.2.0", 5)
                                   :WaitForChild("net", 5)
                                   :WaitForChild(remoteName, 5)
        end,
        function()
            return ReplicatedStorage:WaitForChild("Packages", 5)
                                   :WaitForChild("_Index", 5)
                                   :WaitForChild("sleitnick_net@0.1.0", 5)
                                   :WaitForChild("net", 5)
                                   :WaitForChild(remoteName, 5)
        end,
        function()
            -- Scan all net versions
            local packages = ReplicatedStorage:WaitForChild("Packages", 5)
            local index = packages:WaitForChild("_Index", 5)
            
            for _, child in pairs(index:GetChildren()) do
                if child.Name:match("sleitnick_net@") then
                    local netFolder = child:FindFirstChild("net")
                    if netFolder then
                        local remote = netFolder:FindFirstChild(remoteName)
                        if remote then
                            return remote
                        end
                    end
                end
            end
            return nil
        end,
        function()
            -- Direct scan ReplicatedStorage untuk fallback
            local function scanFolder(folder, depth)
                if depth > 3 then return nil end
                
                local remote = folder:FindFirstChild(remoteName)
                if remote then return remote end
                
                for _, child in pairs(folder:GetChildren()) do
                    if child:IsA("Folder") then
                        local found = scanFolder(child, depth + 1)
                        if found then return found end
                    end
                end
                return nil
            end
            
            return scanFolder(ReplicatedStorage, 0)
        end
    }
    
    for attempt = 1, maxRetries do
        for i, pathFunc in ipairs(searchPaths) do
            local success, result = pcall(pathFunc)
            if success and result then
                print(string.format("[AutoAcceptTrade] Found %s via path %d (attempt %d)", remoteName, i, attempt))
                return result
            end
        end
        
        if attempt < maxRetries then
            print(string.format("[AutoAcceptTrade] Retry %d/%d for %s", attempt, maxRetries, remoteName))
            task.wait(1)
        end
    end
    
    warn(string.format("[AutoAcceptTrade] Failed to find %s after %d attempts", remoteName, maxRetries))
    return nil
end

local function findRemotes()
    -- Cari dengan retry dan fallback
    awaitTradeResponseRemote = findRemoteWithFallback("RF/AwaitTradeResponse", 3)
    textNotificationRemote = findRemoteWithFallback("RE/TextNotification", 2) -- Optional
    
    if not awaitTradeResponseRemote then
        warn("[AutoAcceptTrade] Critical: AwaitTradeResponse remote not found")
        return false
    end
    
    print("[AutoAcceptTrade] Remote setup complete")
    return true
end

-- === GUARD FIRST APPROACH ===
local function installNewIndexGuardFirst()
    if newindexHookInstalled then return end
    
    if not hookmetamethod or not newcclosure then
        warn("[AutoAcceptTrade] Hooking functions not available")
        return false
    end

    local originalNewIndex
    originalNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
        -- Hook ANY RemoteFunction.OnClientInvoke assignment
        if typeof(self) == "Instance" 
           and self.ClassName == "RemoteFunction" 
           and key == "OnClientInvoke"
           and (typeof(value) == "function" or (getrawmetatable and getrawmetatable(value) and typeof(getrawmetatable(value).__call) == "function")) then
            
            -- Check if this is our target remote
            if self == awaitTradeResponseRemote then
                print("[AutoAcceptTrade] Intercepting OnClientInvoke assignment for our target remote")
                
                -- Wrap the assigned callback
                return originalNewIndex(self, key, newcclosure(function(itemData, fromPlayer, timestamp)
                    if running then
                        print("[AutoAcceptTrade] Trade intercepted via newindex hook")
                        
                        -- Log trade data
                        currentTradeData = {
                            item = itemData,
                            fromPlayer = fromPlayer,
                            timestamp = timestamp,
                            startTime = tick(),
                        }
                        isProcessingTrade = true
                        
                        -- Update stats
                        totalTradesAccepted = totalTradesAccepted + 1
                        currentSessionTrades = currentSessionTrades + 1
                        
                        print(string.format("[AutoAcceptTrade] Auto-accepted trade from %s (ID: %s)", 
                            fromPlayer and fromPlayer.Name or "Unknown",
                            itemData and itemData.Id or "Unknown"))
                        
                        -- Reset processing after delay
                        task.spawn(function()
                            task.wait(2)
                            isProcessingTrade = false
                        end)
                        
                        return true -- Accept trade
                    end
                    
                    -- Call original if not running
                    return value(itemData, fromPlayer, timestamp)
                end))
            end
        end

        return originalNewIndex(self, key, value)
    end))

    newindexHookInstalled = true
    print("[AutoAcceptTrade] Newindex guard installed FIRST (will catch late callback assignments)")
    return true
end

-- === TRY IMMEDIATE HOOK (But don't fail if it doesn't work) ===
local function tryImmediateHook()
    if not awaitTradeResponseRemote then return false end

    local Success, Callback = pcall(getcallbackvalue, awaitTradeResponseRemote, "OnClientInvoke")
    local IsCallable = (
        typeof(Callback) == "function"
        or getrawmetatable and getrawmetatable(Callback) ~= nil and typeof(getrawmetatable(Callback).__call) == "function"
        or false
    )

    if Success and IsCallable then
        print("[AutoAcceptTrade] Callback already exists, hooking immediately")
        
        -- Save original
        originalAwaitTradeCB = Callback

        -- Hook it
        awaitTradeResponseRemote.OnClientInvoke = function(itemData, fromPlayer, timestamp)
            if not running then
                return originalAwaitTradeCB(itemData, fromPlayer, timestamp)
            end

            print("[AutoAcceptTrade] Trade intercepted via immediate hook")
            
            -- Log trade data
            currentTradeData = {
                item = itemData,
                fromPlayer = fromPlayer,
                timestamp = timestamp,
                startTime = tick(),
            }
            isProcessingTrade = true
            
            -- Update stats
            totalTradesAccepted = totalTradesAccepted + 1
            currentSessionTrades = currentSessionTrades + 1
            
            print(string.format("[AutoAcceptTrade] Auto-accepted trade from %s (ID: %s)", 
                fromPlayer and fromPlayer.Name or "Unknown",
                itemData and itemData.Id or "Unknown"))
            
            -- Reset processing after delay
            task.spawn(function()
                task.wait(2)
                isProcessingTrade = false
            end)
            
            return true
        end
        
        print("[AutoAcceptTrade] Immediate hook successful")
        return true
    else
        print("[AutoAcceptTrade] No callback yet, relying on newindex guard to catch it later")
        return false
    end
end

local function setupNotificationListener()
    if not textNotificationRemote then 
        print("[AutoAcceptTrade] No notification remote, skipping notification listener")
        return 
    end
    
    if notificationConnection then return end
    
    notificationConnection = textNotificationRemote.OnClientEvent:Connect(function(data)
        if not running then return end
        
        if data and data.Text then
            local text = data.Text:lower()
            
            if string.find(text, "trade completed") or string.find(text, "trade successful") then
                print("[AutoAcceptTrade] Trade completed successfully!")
                isProcessingTrade = false
                
                if currentTradeData then
                    local duration = tick() - currentTradeData.startTime
                    print(string.format("[AutoAcceptTrade] Trade completed in %.2f seconds", duration))
                end
                
                currentTradeData = nil
                
            elseif string.find(text, "trade cancelled") or 
                   string.find(text, "trade expired") or
                   string.find(text, "trade declined") or
                   string.find(text, "trade failed") then
                print("[AutoAcceptTrade] Trade was cancelled/expired/declined")
                isProcessingTrade = false
                currentTradeData = nil
            end
        end
    end)
    
    print("[AutoAcceptTrade] Notification listener setup complete")
end

-- === Interface Methods ===

function AutoAcceptTrade:Init(guiControls)
    print("[AutoAcceptTrade] Initializing robust version...")
    
    -- Step 1: Find remotes with fallback
    if not findRemotes() then
        warn("[AutoAcceptTrade] Failed to find required remotes")
        return false
    end
    
    -- Step 2: Install guard FIRST (most important)
    local guardSuccess = installNewIndexGuardFirst()
    if not guardSuccess then
        warn("[AutoAcceptTrade] Failed to install newindex guard - feature may not work reliably")
    end
    
    -- Step 3: Try immediate hook (but don't fail if it doesn't work)
    tryImmediateHook() -- Ignore return value
    
    -- Step 4: Setup notification listener
    setupNotificationListener()
    
    print("[AutoAcceptTrade] Robust initialization complete")
    print("[AutoAcceptTrade] Guard installed:", guardSuccess and "Yes" or "No")
    print("[AutoAcceptTrade] Ready to catch trade requests!")
    
    return true -- Always return true if we got the remote and guard
end

function AutoAcceptTrade:Start(config)
    if running then 
        print("[AutoAcceptTrade] Already running!")
        return true
    end
    
    running = true
    isProcessingTrade = false
    currentTradeData = nil
    currentSessionTrades = 0
    
    print("[AutoAcceptTrade] Started - Robust direct hook mode active")
    print("[AutoAcceptTrade] Will auto-accept ALL trade requests")
    return true
end

function AutoAcceptTrade:Stop()
    if not running then 
        print("[AutoAcceptTrade] Not running!")
        return true
    end
    
    running = false
    isProcessingTrade = false
    currentTradeData = nil
    
    print("[AutoAcceptTrade] Stopped")
    print("  Session trades accepted:", currentSessionTrades)
    return true
end

function AutoAcceptTrade:Cleanup()
    self:Stop()

    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end

    -- Try to restore original callback if we saved one
    if awaitTradeResponseRemote and originalAwaitTradeCB then
        awaitTradeResponseRemote.OnClientInvoke = originalAwaitTradeCB
        originalAwaitTradeCB = nil
        print("[AutoAcceptTrade] Original callback restored")
    end

    awaitTradeResponseRemote = nil
    textNotificationRemote = nil
    currentTradeData = nil
    totalTradesAccepted = 0
    currentSessionTrades = 0
    
    print("[AutoAcceptTrade] Cleaned up")
end

-- === Status Methods ===

function AutoAcceptTrade:GetStatus()
    return {
        isRunning = running,
        isProcessingTrade = isProcessingTrade,
        totalTradesAccepted = totalTradesAccepted,
        currentSessionTrades = currentSessionTrades,
        hasCurrentTrade = currentTradeData ~= nil,
        currentTradeFrom = currentTradeData and currentTradeData.fromPlayer and currentTradeData.fromPlayer.Name or nil,
        remoteFound = awaitTradeResponseRemote ~= nil,
        hookInstalled = newindexHookInstalled,
        mode = "Robust Direct Hook"
    }
end

function AutoAcceptTrade:IsRunning()
    return running
end

function AutoAcceptTrade:IsProcessing()
    return isProcessingTrade
end

-- === Debug Methods ===

function AutoAcceptTrade:TestRemoteAccess()
    print("=== AutoAcceptTrade Remote Test ===")
    print("  awaitTradeResponseRemote:", awaitTradeResponseRemote and "Found" or "Not found")
    print("  textNotificationRemote:", textNotificationRemote and "Found" or "Not found")
    
    if awaitTradeResponseRemote then
        print("  Remote path:", awaitTradeResponseRemote:GetFullName())
        
        local success, callback = pcall(getcallbackvalue, awaitTradeResponseRemote, "OnClientInvoke")
        print("  getcallbackvalue success:", success)
        if success then
            print("  callback type:", typeof(callback))
            print("  callback value:", callback ~= nil and "Present" or "Nil")
            if originalAwaitTradeCB then
                print("  original saved:", "Yes")
                print("  hook active:", callback ~= originalAwaitTradeCB and "Yes" or "No")
            else
                print("  original saved:", "No")
            end
        end
    end
    
    print("  __newindex guard:", newindexHookInstalled and "Installed" or "Not installed")
    print("  running:", running and "Yes" or "No")
    print("=== End Test ===")
end

function AutoAcceptTrade:ForceHookNow()
    print("[AutoAcceptTrade] Force hooking current callback...")
    return tryImmediateHook()
end

-- === Statistics Methods ===

function AutoAcceptTrade:GetTotalAccepted()
    return totalTradesAccepted
end

function AutoAcceptTrade:GetSessionAccepted()
    return currentSessionTrades
end

function AutoAcceptTrade:ResetStats()
    totalTradesAccepted = 0
    currentSessionTrades = 0
    print("[AutoAcceptTrade] Statistics reset")
end

return AutoAcceptTrade