--- AutoAcceptTrade.lua - Button Click Method (Anti-Cheat Safe)
local AutoAcceptTrade = {}
AutoAcceptTrade.__index = AutoAcceptTrade

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- State
local running = false
local isSpamming = false
local clickConnection = nil
local notificationConnection = nil
local invokeConnection = nil

-- Configuration
local CLICK_INTERVAL = 0.05 -- Interval antar click (50ms)
local MAX_CLICKS = 300 -- Maximum clicks untuk safety
local BUTTON_POSITION = Vector2.new(277.137 + (80.738/2), 137.208 + (22.812/2)) -- Center position
local CLICK_TIMEOUT = 15 -- Timeout dalam detik jika tidak ada trade complete

-- Statistics
local totalTradesProcessed = 0
local currentSessionTrades = 0
local clickCount = 0
local startTime = 0

-- Remotes
local awaitTradeResponseRemote = nil
local textNotificationRemote = nil

-- === REMOTE FINDER ===
local function findRemoteWithFallback(remoteName, maxRetries)
    maxRetries = maxRetries or 3
    
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
            -- Scan semua versi net
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
        end
    }
    
    for attempt = 1, maxRetries do
        for i, pathFunc in ipairs(searchPaths) do
            local success, result = pcall(pathFunc)
            if success and result then
                print(string.format("[AutoAcceptTrade] Found %s via path %d", remoteName, i))
                return result
            end
        end
        
        if attempt < maxRetries then
            task.wait(1)
        end
    end
    
    warn(string.format("[AutoAcceptTrade] Failed to find %s", remoteName))
    return nil
end

local function findRemotes()
    awaitTradeResponseRemote = findRemoteWithFallback("RF/AwaitTradeResponse", 3)
    textNotificationRemote = findRemoteWithFallback("RE/TextNotification", 2)
    
    if not awaitTradeResponseRemote then
        warn("[AutoAcceptTrade] Critical: AwaitTradeResponse remote not found")
        return false
    end
    
    print("[AutoAcceptTrade] Remotes found successfully")
    return true
end

-- === BUTTON CLICKING METHODS ===

-- Method 1: VirtualInputManager (paling aman)
local function clickWithVIM(position)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, true, game, 1)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, false, game, 1)
    end)
end

-- Method 2: Direct button access dengan firesignal
local function clickButtonDirect()
    pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui", 0.1)
        if not playerGui then return end
        
        local prompt = playerGui:FindFirstChild("Prompt")
        if not prompt then return end
        
        local blackout = prompt:FindFirstChild("Blackout")
        if not blackout then return end
        
        local options = blackout:FindFirstChild("Options")
        if not options then return end
        
        local yesButton = options:FindFirstChild("Yes")
        if yesButton and yesButton:IsA("ImageButton") then
            -- Cek apakah button visible dan interactable
            if yesButton.Visible and yesButton.Parent.Visible then
                firesignal(yesButton.MouseButton1Click)
                firesignal(yesButton.MouseButton1Down)
                firesignal(yesButton.MouseButton1Up)
                firesignal(yesButton.Activated)
                return true
            end
        end
    end)
    return false
end

-- Method 3: Mouse simulation
local function clickWithMouse(position)
    pcall(function()
        local mouse = LocalPlayer:GetMouse()
        -- Simulate mouse events
        mouse1click()
    end)
end

-- Combined click function
local function performClick()
    if not isSpamming then return end
    
    clickCount = clickCount + 1
    
    -- Try multiple methods untuk reliability
    local success1 = clickButtonDirect()
    clickWithVIM(BUTTON_POSITION)
    clickWithMouse(BUTTON_POSITION)
    
    if clickCount % 20 == 0 then
        print(string.format("[AutoAcceptTrade] Clicked %d times", clickCount))
    end
    
    -- Safety check
    if clickCount >= MAX_CLICKS then
        print("[AutoAcceptTrade] Reached maximum clicks, stopping")
        stopSpamming()
    end
    
    -- Timeout check
    if tick() - startTime > CLICK_TIMEOUT then
        print("[AutoAcceptTrade] Timeout reached, stopping")
        stopSpamming()
    end
end

-- === SPAM CONTROL ===
local function startSpamming()
    if isSpamming then return end
    
    isSpamming = true
    clickCount = 0
    startTime = tick()
    
    print("[AutoAcceptTrade] Started button spam clicking")
    
    -- Start clicking loop
    clickConnection = RunService.Heartbeat:Connect(function()
        if isSpamming then
            performClick()
            task.wait(CLICK_INTERVAL)
        end
    end)
    
    -- Safety timeout
    task.spawn(function()
        task.wait(CLICK_TIMEOUT)
        if isSpamming then
            print("[AutoAcceptTrade] Safety timeout, stopping spam")
            stopSpamming()
        end
    end)
end

local function stopSpamming()
    if not isSpamming then return end
    
    isSpamming = false
    
    if clickConnection then
        clickConnection:Disconnect()
        clickConnection = nil
    end
    
    print(string.format("[AutoAcceptTrade] Stopped spam clicking (Total clicks: %d)", clickCount))
    clickCount = 0
end

-- === EVENT LISTENERS ===
local function setupTradeListener()
    if not awaitTradeResponseRemote then return false end
    
    -- Listen untuk OnClientInvoke trigger (tidak hook, hanya detect)
    invokeConnection = awaitTradeResponseRemote.OnClientInvoke:Connect(function()
        -- Event ini tidak akan pernah dipanggil karena kita tidak assign callback
        -- Tapi kita bisa detect ketika ada attempt
    end)
    
    -- Method alternatif: Monitor remote secara periodic
    task.spawn(function()
        while running do
            task.wait(0.1)
            
            -- Check apakah ada trade prompt GUI
            local hasTradePrompt = false
            pcall(function()
                local playerGui = LocalPlayer.PlayerGui
                local prompt = playerGui:FindFirstChild("Prompt")
                if prompt and prompt:FindFirstChild("Blackout") then
                    local options = prompt.Blackout:FindFirstChild("Options")
                    if options and options:FindFirstChild("Yes") then
                        hasTradePrompt = true
                    end
                end
            end)
            
            -- Jika ada trade prompt dan belum spam, mulai spam
            if hasTradePrompt and not isSpamming and running then
                print("[AutoAcceptTrade] Trade prompt detected! Starting spam click")
                totalTradesProcessed = totalTradesProcessed + 1
                currentSessionTrades = currentSessionTrades + 1
                startSpamming()
            end
        end
    end)
    
    return true
end

local function setupNotificationListener()
    if not textNotificationRemote then 
        print("[AutoAcceptTrade] No notification remote found")
        return 
    end
    
    notificationConnection = textNotificationRemote.OnClientEvent:Connect(function(data)
        if not running then return end
        
        if data and data.Text then
            local text = data.Text:lower()
            
            -- Check untuk trade complete
            if string.find(text, "Trade completed!") or 
               string.find(text, "Trade completed") or
               string.find(text, "trade accepted") then
                
                print("[AutoAcceptTrade] Trade completed! Stopping spam")
                stopSpamming()
                
            elseif string.find(text, "trade cancelled") or 
                   string.find(text, "trade expired") or
                   string.find(text, "trade declined") or
                   string.find(text, "trade failed") then
                
                print("[AutoAcceptTrade] Trade cancelled/failed, stopping spam")
                stopSpamming()
            end
        end
    end)
    
    print("[AutoAcceptTrade] Notification listener setup")
end

-- === INTERFACE METHODS ===
function AutoAcceptTrade:Init()
    print("[AutoAcceptTrade] Initializing button click method...")
    
    if not findRemotes() then
        warn("[AutoAcceptTrade] Failed to find required remotes")
        return false
    end
    
    if not setupTradeListener() then
        warn("[AutoAcceptTrade] Failed to setup trade listener")
        return false
    end
    
    setupNotificationListener()
    
    print("[AutoAcceptTrade] Button click method initialized successfully")
    print(string.format("[AutoAcceptTrade] Button position: %.2f, %.2f", BUTTON_POSITION.X, BUTTON_POSITION.Y))
    
    return true
end

function AutoAcceptTrade:Start()
    if running then 
        print("[AutoAcceptTrade] Already running!")
        return true
    end
    
    running = true
    isSpamming = false
    currentSessionTrades = 0
    
    print("[AutoAcceptTrade] Started - Button click mode active")
    print("[AutoAcceptTrade] Will auto-click trade accept button when prompt appears")
    return true
end

function AutoAcceptTrade:Stop()
    if not running then 
        print("[AutoAcceptTrade] Not running!")
        return true
    end
    
    running = false
    stopSpamming()
    
    print("[AutoAcceptTrade] Stopped")
    print("  Session trades processed:", currentSessionTrades)
    return true
end

function AutoAcceptTrade:Cleanup()
    self:Stop()

    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end
    
    if invokeConnection then
        invokeConnection:Disconnect()
        invokeConnection = nil
    end

    awaitTradeResponseRemote = nil
    textNotificationRemote = nil
    totalTradesProcessed = 0
    currentSessionTrades = 0
    
    print("[AutoAcceptTrade] Cleaned up")
end

-- === STATUS METHODS ===
function AutoAcceptTrade:GetStatus()
    return {
        isRunning = running,
        isSpamming = isSpamming,
        totalTradesProcessed = totalTradesProcessed,
        currentSessionTrades = currentSessionTrades,
        currentClicks = clickCount,
        remoteFound = awaitTradeResponseRemote ~= nil,
        mode = "Button Click Method"
    }
end

function AutoAcceptTrade:IsRunning()
    return running
end

function AutoAcceptTrade:IsSpamming()
    return isSpamming
end

-- === DEBUG METHODS ===
function AutoAcceptTrade:TestClick()
    print("[AutoAcceptTrade] Testing single click...")
    performClick()
end

function AutoAcceptTrade:TestButtonAccess()
    print("=== Button Access Test ===")
    
    local success = pcall(function()
        local playerGui = LocalPlayer.PlayerGui
        print("  PlayerGui found:", playerGui and "Yes" or "No")
        
        local prompt = playerGui:FindFirstChild("Prompt")
        print("  Prompt found:", prompt and "Yes" or "No")
        
        if prompt then
            local blackout = prompt:FindFirstChild("Blackout")
            print("  Blackout found:", blackout and "Yes" or "No")
            
            if blackout then
                local options = blackout:FindFirstChild("Options")
                print("  Options found:", options and "Yes" or "No")
                
                if options then
                    local yesButton = options:FindFirstChild("Yes")
                    print("  Yes button found:", yesButton and "Yes" or "No")
                    
                    if yesButton then
                        print("  Button type:", yesButton.ClassName)
                        print("  Button visible:", yesButton.Visible)
                        print("  Button position:", yesButton.AbsolutePosition)
                        print("  Button size:", yesButton.AbsoluteSize)
                    end
                end
            end
        end
    end)
    
    print("  Test success:", success)
    print("=== End Test ===")
end

function AutoAcceptTrade:ForceStartSpam()
    print("[AutoAcceptTrade] Force starting spam click...")
    if running then
        startSpamming()
    else
        print("[AutoAcceptTrade] Not running, start first!")
    end
end

function AutoAcceptTrade:ForceStopSpam()
    print("[AutoAcceptTrade] Force stopping spam click...")
    stopSpamming()
end

-- === STATISTICS ===
function AutoAcceptTrade:GetTotalProcessed()
    return totalTradesProcessed
end

function AutoAcceptTrade:GetSessionProcessed()
    return currentSessionTrades
end

function AutoAcceptTrade:ResetStats()
    totalTradesProcessed = 0
    currentSessionTrades = 0
    print("[AutoAcceptTrade] Statistics reset")
end

return AutoAcceptTrade