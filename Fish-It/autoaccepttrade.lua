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

local function findYesButton()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local prompt = playerGui:FindFirstChild("Prompt")
    if not prompt then return nil end
    
    local blackout = prompt:FindFirstChild("Blackout")
    if not blackout then return nil end
    
    local options = blackout:FindFirstChild("Options")
    if not options then return nil end
    
    local yesButton = options:FindFirstChild("Yes")
    if not yesButton or not yesButton:IsA("ImageButton") then return nil end
    
    -- Check if button is visible and clickable
    if not yesButton.Visible or yesButton.Parent.Visible == false then return nil end
    
    return yesButton
end

local function clickYesButton()
    local yesButton = findYesButton()
    if not yesButton then return false end
    
    -- Simulate click using multiple methods for reliability
    local success = false
    
    -- Method 1: MouseButton1Click event
    pcall(function()
        yesButton.MouseButton1Click:Fire()
        success = true
    end)
    
    -- Method 2: GuiService (if available)
    pcall(function()
        local GuiService = game:GetService("GuiService")
        if GuiService and GuiService.SelectedObject ~= yesButton then
            GuiService.SelectedObject = yesButton
        end
    end)
    
    return success
end

local function startClickingLoop()
    if clickConnection then return end
    
    local clickAttempts = 0
    clickConnection = RunService.Heartbeat:Connect(function()
        if not running or not isProcessingTrade then
            return
        end
        
        clickAttempts = clickAttempts + 1
        
        -- Safety: Stop if too many attempts
        if clickAttempts > MAX_CLICK_ATTEMPTS then
            print("[AutoAcceptTrade] Max click attempts reached, stopping")
            stopClickingLoop()
            isProcessingTrade = false
            return
        end
        
        local success = clickYesButton()
        if success then
            print("[AutoAcceptTrade] ✓ Clicked Yes button (attempt", clickAttempts .. ")")
        end
        
        -- Small delay
        task.wait(CLICK_INTERVAL)
    end)
    
    print("[AutoAcceptTrade] Started clicking loop")
end

local function stopClickingLoop()
    if clickConnection then
        clickConnection:Disconnect()
        clickConnection = nil
        print("[AutoAcceptTrade] Stopped clicking loop")
    end
end

-- FIX 1: Proper setup mengikuti pola Incoming.luau
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

    -- Hook callback seperti di Incoming.luau
    awaitTradeResponseRemote.OnClientInvoke = function(...)
        if not running then
            -- Jika fitur off, kembalikan ke perilaku asli game
            return originalAwaitTradeCB(...)
        end

        local args = {...}
        print("[AutoAcceptTrade] 🔔 Trade request detected!")
        print("[AutoAcceptTrade] Args received:", #args)
        
        -- Parse arguments (adjust based on your game's structure)
        local itemData = args[1]
        local fromPlayer = args[2] 
        local timestamp = args[3]
        
        currentTradeData = {
            item = itemData,
            fromPlayer = fromPlayer,
            timestamp = timestamp,
            startTime = tick(),
        }
        isProcessingTrade = true

        -- Auto-accept trade
        print("[AutoAcceptTrade] ✅ Auto-accepting trade...")
        totalTradesAccepted = totalTradesAccepted + 1
        currentSessionTrades = currentSessionTrades + 1
        
        -- Reset processing state after a delay
        task.spawn(function()
            task.wait(1)
            isProcessingTrade = false
        end)

        return true -- Accept the trade
    end

    print("[AutoAcceptTrade] Trade response listener setup complete")
    return true
end

-- FIX 2: Proper __newindex hook mengikuti pola Incoming.luau
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
                -- Re-wrap the new callback
                return originalNewIndex(self, key, function(...)
                    if running then
                        -- Auto-accept if running
                        print("[AutoAcceptTrade] 🔔 Trade request intercepted via newindex hook")
                        return true
                    end
                    return value(...) -- Call original if not running
                end)
            end
        end

        return originalNewIndex(self, key, value)
    end))

    newindexHookInstalled = true
    print("[AutoAcceptTrade] __newindex guard installed")
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
                
                -- Stop clicking
                stopClickingLoop()
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
                
                -- Stop processing
                stopClickingLoop()
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
    
    -- Stop any active clicking
    stopClickingLoop()
    isProcessingTrade = false
    currentTradeData = nil
    
    print("[AutoAcceptTrade] Stopped")
    print("  Session trades accepted:", currentSessionTrades)
    
    return true
end

function AutoAcceptTrade:Cleanup()
    self:Stop()

    -- Disconnect connections
    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end

    if clickConnection then
        clickConnection:Disconnect()
        clickConnection = nil
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
    local yesButton = findYesButton()
    if yesButton then
        print("[AutoAcceptTrade] ✓ Yes button found at:", yesButton:GetFullName())
        print("  Visible:", yesButton.Visible)
        print("  AbsolutePosition:", yesButton.AbsolutePosition)
        print("  AbsoluteSize:", yesButton.AbsoluteSize)
        
        local success = clickYesButton()
        print("  Click test result:", success)
        return true
    else
        print("[AutoAcceptTrade] ❌ Yes button not found")
        print("  Checking path: Players." .. LocalPlayer.Name .. ".PlayerGui.Prompt.Blackout.Options.Yes")
        return false
    end
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