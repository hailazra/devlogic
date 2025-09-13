--- AutoAcceptTrade.lua - Auto Accept Trade Requests (PURE DIRECT HOOK) ----
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

-- === Helper Functions ===

local function findRemotes()
    local success1, remote1 = pcall(function()
        return ReplicatedStorage:WaitForChild("Packages", 5)
                              :WaitForChild("_Index", 5)
                              :WaitForChild("sleitnick_net@0.2.0", 5)
                              :WaitForChild("net", 5)
                              :WaitForChild("RF/AwaitTradeResponse", 5)
    end)
    
    if success1 and remote1 then
        awaitTradeResponseRemote = remote1
        print("[AutoAcceptTrade] AwaitTradeResponse remote found")
    else
        warn("[AutoAcceptTrade] Failed to find AwaitTradeResponse remote")
        return false
    end
    
    local success2, remote2 = pcall(function()
        return ReplicatedStorage:WaitForChild("Packages", 5)
                              :WaitForChild("_Index", 5)
                              :WaitForChild("sleitnick_net@0.2.0", 5)
                              :WaitForChild("net", 5)
                              :WaitForChild("RE/TextNotification", 5)
    end)
    
    if success2 and remote2 then
        textNotificationRemote = remote2
        print("[AutoAcceptTrade] TextNotification remote found")
    else
        warn("[AutoAcceptTrade] TextNotification remote not found")
    end
    
    return true
end

-- PURE DIRECT HOOK - No GUI interaction at all
local function setupTradeResponseListener()
    if not awaitTradeResponseRemote then return false end

    -- Get original callback using pattern from Incoming.luau
    local Success, Callback = pcall(getcallbackvalue, awaitTradeResponseRemote, "OnClientInvoke")
    local IsCallable = (
        typeof(Callback) == "function"
        or getrawmetatable and getrawmetatable(Callback) ~= nil and typeof(getrawmetatable(Callback)["__call"]) == "function"
        or false
    )

    if not Success or not IsCallable then
        warn("[AutoAcceptTrade] getcallbackvalue failed or callback not callable")
        return false
    end

    -- Save original callback
    originalAwaitTradeCB = Callback

    -- Hook callback - DIRECT RESPONSE ONLY
    awaitTradeResponseRemote.OnClientInvoke = function(itemData, fromPlayer, timestamp)
        if not running then
            -- If feature is off, return to original game behavior
            return originalAwaitTradeCB(itemData, fromPlayer, timestamp)
        end

        print("[AutoAcceptTrade] Trade request intercepted!")
        print("[AutoAcceptTrade] From:", fromPlayer and fromPlayer.Name or "Unknown")
        print("[AutoAcceptTrade] Item ID:", itemData and itemData.Id or "Unknown")
        print("[AutoAcceptTrade] UUID:", itemData and itemData.UUID or "Unknown")
        
        currentTradeData = {
            item = itemData,
            fromPlayer = fromPlayer,
            timestamp = timestamp,
            startTime = tick(),
        }
        isProcessingTrade = true

        -- DIRECT ACCEPT - Return true immediately
        print("[AutoAcceptTrade] Auto-accepting trade (direct response)")
        totalTradesAccepted = totalTradesAccepted + 1
        currentSessionTrades = currentSessionTrades + 1
        
        -- Reset processing state after delay
        task.spawn(function()
            task.wait(2)
            isProcessingTrade = false
        end)

        -- Return TRUE = Accept trade (server will process this trade)
        return true
    end

    print("[AutoAcceptTrade] Direct trade response hook installed")
    return true
end

-- Guard against game overwriting our hook
local function installNewIndexGuard()
    if newindexHookInstalled then return end
    
    if not hookmetamethod or not newcclosure then
        warn("[AutoAcceptTrade] Hooking functions not available")
        return
    end

    local originalNewIndex
    originalNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
        if typeof(self) ~= "Instance" or self.ClassName ~= "RemoteFunction" then
            return originalNewIndex(self, key, value)
        end

        if self == awaitTradeResponseRemote and key == "OnClientInvoke" then
            local IsCallable = (
                typeof(value) == "function"
                or getrawmetatable and getrawmetatable(value) ~= nil and typeof(getrawmetatable(value)["__call"]) == "function"
                or false
            )

            if IsCallable then
                -- Re-wrap the new callback to maintain our auto-accept
                return originalNewIndex(self, key, function(itemData, fromPlayer, timestamp)
                    if running then
                        print("[AutoAcceptTrade] Trade intercepted via newindex hook - auto-accepting")
                        totalTradesAccepted = totalTradesAccepted + 1
                        currentSessionTrades = currentSessionTrades + 1
                        return true
                    end
                    return value(itemData, fromPlayer, timestamp)
                end)
            end
        end

        return originalNewIndex(self, key, value)
    end))

    newindexHookInstalled = true
    print("[AutoAcceptTrade] Direct response __newindex guard installed")
end

local function setupNotificationListener()
    if not textNotificationRemote or notificationConnection then return end
    
    notificationConnection = textNotificationRemote.OnClientEvent:Connect(function(data)
        if not running then return end
        
        if data and data.Text then
            local text = data.Text:lower()
            
            -- Check for trade completion
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
    print("[AutoAcceptTrade] Initializing direct hook version...")
    
    -- Find remotes
    if not findRemotes() then
        warn("[AutoAcceptTrade] Failed to find required remotes")
        return false
    end
    
    -- Setup listeners
    local success1 = setupTradeResponseListener()
    if not success1 then
        warn("[AutoAcceptTrade] Failed to setup trade response listener")
        return false
    end
    
    setupNotificationListener()
    installNewIndexGuard()
    
    print("[AutoAcceptTrade] Direct hook initialization complete")
    return true
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
    
    print("[AutoAcceptTrade] Started - Direct hook mode active")
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

    -- Disconnect notification connection
    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end

    -- Restore original callback
    if awaitTradeResponseRemote and originalAwaitTradeCB then
        awaitTradeResponseRemote.OnClientInvoke = originalAwaitTradeCB
        originalAwaitTradeCB = nil
        print("[AutoAcceptTrade] Original callback restored")
    end

    -- Clear references
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
        mode = "Direct Hook"
    }
end

function AutoAcceptTrade:IsRunning()
    return running
end

function AutoAcceptTrade:IsProcessing()
    return isProcessingTrade
end

-- === Debug Methods ===

function AutoAcceptTrade:DumpStatus()
    local status = self:GetStatus()
    print("=== AutoAcceptTrade Status ===")
    for k, v in pairs(status) do
        print(k .. ":", v)
    end
    
    if currentTradeData then
        print("=== Current Trade Data ===")
        print("From:", currentTradeData.fromPlayer and currentTradeData.fromPlayer.Name or "Unknown")
        if currentTradeData.item then
            print("Item ID:", currentTradeData.item.Id or "Unknown")
            print("UUID:", currentTradeData.item.UUID or "Unknown")
        end
        print("Duration:", tick() - currentTradeData.startTime, "seconds")
    end
end

function AutoAcceptTrade:TestRemoteAccess()
    print("[AutoAcceptTrade] Testing remote access...")
    print("  awaitTradeResponseRemote:", awaitTradeResponseRemote and "Found" or "Not found")
    print("  textNotificationRemote:", textNotificationRemote and "Found" or "Not found")
    
    if awaitTradeResponseRemote then
        local success, callback = pcall(getcallbackvalue, awaitTradeResponseRemote, "OnClientInvoke")
        print("  getcallbackvalue:", success and "Success" or "Failed")
        if success then
            print("  callback type:", typeof(callback))
            print("  hook installed:", callback ~= originalAwaitTradeCB and "Yes" or "No")
        end
    end
    
    print("  __newindex guard:", newindexHookInstalled and "Installed" or "Not installed")
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