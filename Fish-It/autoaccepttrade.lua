--- AutoAcceptTrade.lua - Auto Accept Trade Requests
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
local responseConnection = nil
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

    local ok = false
    if typeof(firesignal) == "function" then
        pcall(function() firesignal(yesButton.MouseButton1Down) end)
        pcall(function() firesignal(yesButton.MouseButton1Click) end)
        pcall(function() firesignal(yesButton.Activated) end)
        ok = true
    else
        local vim = game:GetService("VirtualInputManager")
        local pos = yesButton.AbsolutePosition + (yesButton.AbsoluteSize / 2)
        pcall(function()
            vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true,  nil, 0)
            vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, nil, 0)
        end)
        ok = true
    end
    return ok
end


local function startClickingLoop()
    if clickConnection then return end
    local t, attempts = 0, 0
    clickConnection = RunService.Heartbeat:Connect(function(dt)
        if not running or not isProcessingTrade then return end
        t += dt
        if t < CLICK_INTERVAL then return end
        t = 0

        attempts += 1
        if attempts > MAX_CLICK_ATTEMPTS then
            print("[AutoAcceptTrade] Max click attempts reached, stopping")
            stopClickingLoop()
            isProcessingTrade = false
            return
        end

        if clickYesButton() then
            print(("[AutoAcceptTrade] ✓ Clicked Yes (attempt %d)"):format(attempts))
        end
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

-- simpan callback asli biar bisa di-restore di Cleanup
local originalAwaitTradeCB

local function setupTradeResponseListener()
    if not awaitTradeResponseRemote or responseConnection then return end

    -- coba ambil callback asli seperti Incoming.txt
    local ok, cb = pcall(getcallbackvalue, awaitTradeResponseRemote, "OnClientInvoke")
    if ok and cb then
        originalAwaitTradeCB = cb
        awaitTradeResponseRemote.OnClientInvoke = function(itemData, fromPlayer, timestamp, ...)
            if not running then
                return originalAwaitTradeCB(itemData, fromPlayer, timestamp, ...)
            end

            print("[AutoAcceptTrade] 🔔 Trade request detected!")
            currentTradeData = {
                item = itemData, fromPlayer = fromPlayer,
                timestamp = timestamp, startTime = tick()
            }
            isProcessingTrade = true

            -- MODE A (disarankan): terima tanpa GUI
            return true

            -- MODE B (kalau mau tetap buka prompt):
            -- task.defer(function() startClickingLoop() end)
            -- return originalAwaitTradeCB(itemData, fromPlayer, timestamp, ...)
        end
        responseConnection = "HOOKED"
        print("[AutoAcceptTrade] Hooked AwaitTradeResponse.OnClientInvoke (wrapped)")
    else
        -- fallback: override langsung (bypass UI)
        awaitTradeResponseRemote.OnClientInvoke = function(itemData, fromPlayer, timestamp, ...)
            if not running then return end
            currentTradeData = {
                item = itemData, fromPlayer = fromPlayer,
                timestamp = timestamp, startTime = tick()
            }
            isProcessingTrade = true
            return true
        end
        responseConnection = "HOOKED"
        warn("[AutoAcceptTrade] getcallbackvalue failed; overriding OnClientInvoke directly")
    end
end

local function setupNotificationListener()
    if not textNotificationRemote or notificationConnection then return end
    
    notificationConnection = textNotificationRemote.OnClientEvent:Connect(function(data)
        if not running or not isProcessingTrade then return end
        
        if data and data.Text then
            -- Check for trade completion
            if string.find(data.Text:lower(), "trade completed") then
                print("[AutoAcceptTrade] ✅ Trade completed successfully!")
                
                -- Stop clicking
                stopClickingLoop()
                isProcessingTrade = false
                
                -- Update statistics
                totalTradesAccepted = totalTradesAccepted + 1
                currentSessionTrades = currentSessionTrades + 1
                
                -- Log trade info
                if currentTradeData then
                    local duration = tick() - currentTradeData.startTime
                    print(string.format("[AutoAcceptTrade] Trade from %s completed in %.2f seconds", 
                        currentTradeData.fromPlayer and currentTradeData.fromPlayer.Name or "Unknown", duration))
                end
                
                -- Clear trade data
                currentTradeData = nil
                
            elseif string.find(data.Text:lower(), "trade cancelled") or 
                   string.find(data.Text:lower(), "trade expired") or
                   string.find(data.Text:lower(), "trade declined") then
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
        return false
    end
    
    -- Setup listeners
    setupTradeResponseListener()
    setupNotificationListener()
    
    print("[AutoAcceptTrade] Initialization complete")
    return true
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
    -- ... putus semua connection ...

    if awaitTradeResponseRemote then
        if originalAwaitTradeCB then
            awaitTradeResponseRemote.OnClientInvoke = originalAwaitTradeCB
            originalAwaitTradeCB = nil
        else
            -- kalau kamu memang override total, baru nil-kan
            awaitTradeResponseRemote.OnClientInvoke = nil
        end
    end
end

    
    -- Disconnect all connections
    if responseConnection and type(responseConnection) == "RBXScriptConnection" then
        responseConnection:Disconnect()
    end
    responseConnection = nil
    
    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end
    
    if clickConnection then
        clickConnection:Disconnect()
        clickConnection = nil
    end
    
    -- Reset OnClientInvoke if we hooked it
    if awaitTradeResponseRemote then
        awaitTradeResponseRemote.OnClientInvoke = nil
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
        currentTradeFrom = currentTradeData and currentTradeData.fromPlayer and currentTradeData.fromPlayer.Name or nil
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
        print("Item ID:", currentTradeData.item and currentTradeData.item.Id or "Unknown")
        print("UUID:", currentTradeData.item and currentTradeData.item.UUID or "Unknown")
        print("Duration:", tick() - currentTradeData.startTime, "seconds")
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