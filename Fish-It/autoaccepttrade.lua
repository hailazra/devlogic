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
local originalAwaitTradeCB :: any = nil  -- simpan callback asli
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
    
    -- Method 3: UserInputService simulation (backup)
    if not success then
        pcall(function()
            local buttonPos = yesButton.AbsolutePosition
            local buttonSize = yesButton.AbsoluteSize
            local centerX = buttonPos.X + (buttonSize.X / 2)
            local centerY = buttonPos.Y + (buttonSize.Y / 2)
            
            -- This won't actually work on most executors, but keeping for completeness
            UserInputService.InputBegan:Fire({
                UserInputType = Enum.UserInputType.MouseButton1,
                Position = Vector2.new(centerX, centerY)
            })
        end)
    end
    
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

local function setupTradeResponseListener()
    if not awaitTradeResponseRemote then return end

    -- ikuti pola Incoming.txt: wrap callback, bukan :Connect
    local function wrapAwaitTradeResponse(rf: RemoteFunction)
    if not rf then return false end

    local ok, cb = pcall(getcallbackvalue, rf, "OnClientInvoke")
    local callable = ok and (
        type(cb) == "function"
        or (getrawmetatable(cb) and type(getrawmetatable(cb).__call) == "function")
    )

    if not callable then
        warn("[AutoAcceptTrade] getcallbackvalue gagal / callback tidak callable; batal wrap")
        return false
    end

    originalAwaitTradeCB = cb

    -- MODE A (disarankan): auto-accept langsung tanpa klik GUI
    rf.OnClientInvoke = newcclosure(function(itemData, fromPlayer, timestamp, ...)
        if not running then
            -- jika fitur off, kembalikan ke perilaku asli game
            return originalAwaitTradeCB(itemData, fromPlayer, timestamp, ...)
        end

        print("[AutoAcceptTrade] 🔔 Trade request detected!")
        currentTradeData = {
            item = itemData,
            fromPlayer = fromPlayer,
            timestamp = timestamp,
            startTime = tick(),
        }
        isProcessingTrade = true

        -- langsung terima trade (hindari fragilitas klik GUI)
        return true
    end)

    print("[AutoAcceptTrade] Wrapped AwaitTradeResponse.OnClientInvoke (ala Incoming)")
    return true
end

-- ==== GUARD: jaga kalau game assign OnClientInvoke lagi ====
local function installNewIndexGuard()
    if newindexHookInstalled then return end
    if type(hookmetamethod) ~= "function" or type(newcclosure) ~= "function" or type(checkcaller) ~= "function" then
        warn("[AutoAcceptTrade] __newindex hook tidak tersedia di executor; guard dilewati")
        return
    end

    local oldNewIndex
    oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
        -- Mirip pola Incoming.txt: jika ada assignment ke RemoteFunction.OnClientInvoke, re-wrap
        if typeof(self) == "Instance"
            and self.ClassName == "RemoteFunction"
            and key == "OnClientInvoke"
            and (type(value) == "function"
                 or (getrawmetatable(value) and type(getrawmetatable(value).__call) == "function")) then

            -- bungkus callback baru supaya auto-accept tetap aktif untuk RF target kita
            return oldNewIndex(self, key, newcclosure(function(...)
                -- kalau yang di-assign ini adalah RF target kita dan fitur sedang aktif → tetap auto-accept
                if self == awaitTradeResponseRemote and running then
                    return true
                end
                -- kalau fitur off / RF lain → jalankan callback aslinya
                return value(...)
            end))
        end
        return oldNewIndex(self, key, value)
    end))

    newindexHookInstalled = true
    print("[AutoAcceptTrade] __newindex guard terpasang")
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

    -- kembalikan callback asli biar logic game aman
    if awaitTradeResponseRemote then
        if originalAwaitTradeCB then
            awaitTradeResponseRemote.OnClientInvoke = originalAwaitTradeCB
            originalAwaitTradeCB = nil
        else
            -- hanya kalau kita memang meng-overwrite total
            awaitTradeResponseRemote.OnClientInvoke = nil
        end
    end

    awaitTradeResponseRemote = nil
    textNotificationRemote = nil
    currentTradeData = nil
    totalTradesAccepted = 0
    currentSessionTrades = 0

    print("[AutoAcceptTrade] Cleaned up (callback restored)")
end
    
    -- Disconnect all connections
    if responseConnection then
        responseConnection:Disconnect()
        responseConnection = nil
    end
    
    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end
    
    if clickConnection then
        clickConnection:Disconnect()
        clickConnection = nil
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