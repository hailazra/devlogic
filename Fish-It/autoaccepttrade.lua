--- AutoAcceptTrade.lua - Auto Accept Trade Requests (FIXED)
local AutoAcceptTrade = {}
AutoAcceptTrade.__index = AutoAcceptTrade

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Local player
local LocalPlayer = Players.LocalPlayer

-- State
local running = false
local isProcessingTrade = false
local currentTradeData = nil
local clickConnection = nil
local notificationConnection = nil

-- Statistics
local totalTradesAccepted = 0
local currentSessionTrades = 0

-- Configuration
local CLICK_INTERVAL = 0.1 -- Click every 100ms
local MAX_CLICK_ATTEMPTS = 100 -- Maximum clicks per trade (10 seconds)

-- Remotes
local awaitTradeResponseRemote = nil
local textNotificationRemote = nil
local originalAwaitTradeCB = nil  -- simpan callback asli
local newindexHookInstalled = false

-- === Helper Functions === (REMOVED CLICKING LOGIC)

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

-- NOTE: GUI clicking functions removed - no longer needed with direct hook approach

-- FIX 1: Direct hook approach (NO GUI CLICKING) - mengikuti pola Incoming.luau
local function setupTradeResponseListener()
    if not awaitTradeResponseRemote then return false end

    -- Mengikuti pola dari Incoming.luau: HandleInstance untuk RemoteFunction
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

    -- Simpan callback asli
    originalAwaitTradeCB = Callback

    -- Hook callback seperti di Incoming.luau - DIRECT RESPONSE, NO GUI INTERACTION
    awaitTradeResponseRemote.OnClientInvoke = function(itemData, fromPlayer, timestamp)
        if not running then
            -- Jika fitur off, kembalikan ke perilaku asli game
            return originalAwaitTradeCB(itemData, fromPlayer, timestamp)
        end

        print("[AutoAcceptTrade] 🔔 Trade request intercepted!")
        print("[AutoAcceptTrade] From:", fromPlayer and fromPlayer.Name or "Unknown")
        print("[AutoAcceptTrade] Item ID:", itemData and itemData.Id or "Unknown")
        print("[AutoAcceptTrade] UUID:", itemData and itemData.UUID or "Unknown")
        print("[AutoAcceptTrade] Timestamp:", timestamp)
        
        currentTradeData = {
            item = itemData,
            fromPlayer = fromPlayer,
            timestamp = timestamp,
            startTime = tick(),
        }
        isProcessingTrade = true

        -- LANGSUNG ACCEPT - No GUI interaction needed!
        print("[AutoAcceptTrade] ✅ Auto-accepting trade (direct response)...")
        totalTradesAccepted = totalTradesAccepted + 1
        currentSessionTrades = currentSessionTrades + 1
        
        -- Reset processing state after a delay
        task.spawn(function()
            task.wait(2) -- Give some time for trade to process
            isProcessingTrade = false
        end)

        -- Return TRUE = Accept trade (server akan proses trade ini)
        return true
    end

    print("[AutoAcceptTrade] Direct trade response hook installed (no GUI clicking needed)")
    return true
end

-- FIX 2: Simplified __newindex hook - no GUI clicking
local function installNewIndexGuard()
    if newindexHookInstalled then return end
    
    -- Check if hooking functions are available
    if not hookmetamethod or not newcclosure then
        warn("[AutoAcceptTrade] Hooking functions not available")
        return
    end

    local originalNewIndex
    originalNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
        -- Mengikuti pola dari Incoming.luau
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
                -- Re-wrap the new callback - DIRECT APPROACH
                return originalNewIndex(self, key, function(itemData, fromPlayer, timestamp)
                    if running then
                        -- LANGSUNG RETURN TRUE - no GUI needed
                        print("[AutoAcceptTrade] 🔔 Trade intercepted via newindex hook - auto-accepting")
                        totalTradesAccepted = totalTradesAccepted + 1
                        currentSessionTrades = currentSessionTrades + 1
                        return true
                    end
                    return value(itemData, fromPlayer, timestamp) -- Call original if not running
                end)
            end
        end

        return originalNewIndex(self, key, value)
    end))

    newindexHookInstalled = true
    print("[AutoAcceptTrade] Direct response __newindex guard installed (no GUI clicking)")
end

local function setupNotificationListener()
    if not textNotificationRemote or notificationConnection then return end
    
    notificationConnection = textNotificationRemote.OnClientEvent:Connect(function(data)
        if not running then return end
        
        if data and data.Text then
            local text = data.Text:lower()
            
            -- Check for trade completion
            if string.find(text, "trade completed") or string.find(text, "trade successful") then
                print("[AutoAcceptTrade] ✅ Trade completed successfully!")
                
                -- Stop processing (no clicking to stop since we don't click)
                isProcessingTrade = false
                
                -- Log trade info
                if currentTradeData then
                    local duration = tick() - currentTradeData.startTime
                    print(string.format("[AutoAcceptTrade] Trade completed in %.2f seconds", duration))
                end
                
                -- Clear trade data
                currentTradeData = nil
                
            elseif string.find(text, "trade cancelled") or 
                   string.find(text, "trade expired") or
                   string.find(text, "trade declined") or
                   string.find(text, "trade failed") then
                print("[AutoAcceptTrade] ❌ Trade was cancelled/expired/declined")
                
                -- Stop processing (no clicking to stop)
                isProcessingTrade = false
                currentTradeData = nil
            end
        end
    end)
    
    print("[AutoAcceptTrade] Notification listener setup complete")
end

-- === Interface Methods ===

function AutoAcceptTrade:Init(guiControls)
    print("[AutoAcceptTrade] Initializing...")
    
    -- Find remotes
    if not findRemotes() then
        warn("[AutoAcceptTrade] Failed to find required remotes")
        return false
    end
    
    -- Setup listeners (with error handling)
    local success1 = setupTradeResponseListener()
    if not success1 then
        warn("[AutoAcceptTrade] Failed to setup trade response listener")
    end
    
    setupNotificationListener()
    installNewIndexGuard()
    
    print("[AutoAcceptTrade] Initialization complete")
    return success1
end

function AutoAcceptTrade:Start(config)
    if running then 
        print("[AutoAcceptTrade] Already running!")
        return true
    end
    
    -- Apply config if provided
    if config then
        if config.clickInterval then
            CLICK_INTERVAL = math.max(0.05, config.clickInterval)
        end
        if config.maxClickAttempts then
            MAX_CLICK_ATTEMPTS = math.max(10, config.maxClickAttempts)
        end
    end
    
    running = true
    isProcessingTrade = false
    currentTradeData = nil
    currentSessionTrades = 0
    
    print("[AutoAcceptTrade] Started - Ready to accept trades")
    print("  Click interval:", CLICK_INTERVAL, "seconds")
    print("  Max attempts:", MAX_CLICK_ATTEMPTS)
    
    return true
end

function AutoAcceptTrade:Stop()
    if not running then 
        print("[AutoAcceptTrade] Not running!")
        return true
    end
    
    running = false
    
    -- Stop processing (no clicking to stop)
    isProcessingTrade = false
    currentTradeData = nil
    
    print("[AutoAcceptTrade] Stopped")
    print("  Session trades accepted:", currentSessionTrades)
    
    return true
end

function AutoAcceptTrade:Cleanup()
    self:Stop()

    -- Disconnect connections (no clicking connections to clean)
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
        clickInterval = CLICK_INTERVAL,
        maxClickAttempts = MAX_CLICK_ATTEMPTS,
        hasCurrentTrade = currentTradeData ~= nil,
        currentTradeFrom = currentTradeData and currentTradeData.fromPlayer and currentTradeData.fromPlayer.Name or nil,
        remoteFound = awaitTradeResponseRemote ~= nil,
        hookInstalled = newindexHookInstalled
    }
end

function AutoAcceptTrade:IsRunning()
    return running
end

function AutoAcceptTrade:IsProcessing()
    return isProcessingTrade
end

-- === Configuration Methods ===

function AutoAcceptTrade:SetClickInterval(interval)
    if type(interval) == "number" and interval >= 0.05 then
        CLICK_INTERVAL = interval
        print("[AutoAcceptTrade] Click interval set to:", interval)
        return true
    end
    return false
end

function AutoAcceptTrade:SetMaxClickAttempts(attempts)
    if type(attempts) == "number" and attempts >= 10 then
        MAX_CLICK_ATTEMPTS = attempts
        print("[AutoAcceptTrade] Max click attempts set to:", attempts)
        return true
    end
    return false
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
    print("  awaitTradeResponseRemote:", awaitTradeResponseRemote and "✓ Found" or "❌ Not found")
    print("  textNotificationRemote:", textNotificationRemote and "✓ Found" or "❌ Not found")
    
    if awaitTradeResponseRemote then
        local success, callback = pcall(getcallbackvalue, awaitTradeResponseRemote, "OnClientInvoke")
        print("  getcallbackvalue:", success and "✓ Success" or "❌ Failed")
        if success then
            print("  callback type:", typeof(callback))
        end
    end
end

function AutoAcceptTrade:TestYesButton()
    -- This function is now deprecated since we use direct hook approach
    print("[AutoAcceptTrade] ℹ️  TestYesButton is deprecated - using direct hook approach instead")
    print("[AutoAcceptTrade] ℹ️  No GUI clicking needed with current implementation")
    return true
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