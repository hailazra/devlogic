--- AutoAcceptTrade.lua - Pure Detection Method (Safe from Anti-Cheat)
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
local detectConnection = nil
local notificationConnection = nil

-- Configuration
local CLICK_INTERVAL = 0.03 -- Interval antar click (30ms untuk lebih cepat)
local MAX_CLICKS = 500 -- Maximum clicks untuk safety
local BUTTON_POSITION = Vector2.new(277.137 + (80.738/2), 137.208 + (22.812/2)) -- Center position
local CLICK_TIMEOUT = 20 -- Timeout dalam detik jika tidak ada trade complete

-- Statistics
local totalTradesProcessed = 0
local currentSessionTrades = 0
local clickCount = 0
local startTime = 0

-- Detection state
local tradeDetected = false
local lastTradeTime = 0

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
    local success = false
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
                -- Multiple signal attempts untuk reliability
                firesignal(yesButton.MouseButton1Click)
                firesignal(yesButton.MouseButton1Down)
                firesignal(yesButton.MouseButton1Up) 
                firesignal(yesButton.Activated)
                
                -- Juga coba GuiService
                game:GetService("GuiService"):InspectPlayerFromUserId(0)
                success = true
            end
        end
    end)
    return success
end

-- Method 3: Mouse simulation
local function clickWithMouse(position)
    pcall(function()
        mouse1click()
    end)
end

-- Combined click function dengan multiple methods
local function performClick()
    if not isSpamming then return end
    
    clickCount = clickCount + 1
    
    -- Try semua methods untuk maximum reliability
    local directSuccess = clickButtonDirect()
    clickWithVIM(BUTTON_POSITION) 
    clickWithMouse(BUTTON_POSITION)
    
    -- Additional methods untuk bypass detection
    pcall(function()
        -- Method 4: GuiService click simulation
        local gui = game:GetService("GuiService")
        gui:GetErrorMessage()
    end)
    
    if clickCount % 50 == 0 then
        print(string.format("[AutoAcceptTrade] Clicked %d times (Direct: %s)", clickCount, directSuccess and "OK" or "FAIL"))
    end
    
    -- Safety checks
    if clickCount >= MAX_CLICKS then
        print("[AutoAcceptTrade] Reached maximum clicks, stopping")
        stopSpamming()
    end
    
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
    
    print("[AutoAcceptTrade] Started aggressive button spam clicking")
    
    -- Start high-frequency clicking loop
    clickConnection = RunService.Heartbeat:Connect(function()
        if isSpamming then
            performClick()
            -- Minimal delay untuk maximum speed
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
    tradeDetected = false
end

-- === DETECTION SYSTEM (PURE LISTENING, NO HOOKING) ===
local function setupTradeDetection()
    if not awaitTradeResponseRemote then return false end
    
    -- PURE DETECTION: Monitor remote activity tanpa hook/intercept
    detectConnection = RunService.Heartbeat:Connect(function()
        if not running then return end
        
        -- Method 1: Monitor GUI existence untuk trade prompt
        local hasTradePrompt = false
        local promptVisible = false
        
        pcall(function()
            local playerGui = LocalPlayer.PlayerGui
            local prompt = playerGui:FindFirstChild("Prompt")
            if prompt and prompt:FindFirstChild("Blackout") then
                local blackout = prompt.Blackout
                if blackout:FindFirstChild("Options") then
                    local options = blackout.Options
                    if options:FindFirstChild("Yes") then
                        hasTradePrompt = true
                        promptVisible = prompt.Visible and blackout.Visible and options.Visible
                    end
                end
            end
        end)
        
        -- Method 2: Detect berdasarkan remote activity pattern
        -- Monitor jika ada perubahan state tanpa intercept
        local currentTime = tick()
        
        -- Jika GUI trade prompt muncul dan visible
        if hasTradePrompt and promptVisible and not isSpamming then
            -- Double check: pastikan ini bukan false positive
            if currentTime - lastTradeTime > 2 then -- Minimal 2 detik antar trade
                print("[AutoAcceptTrade] TRADE DETECTED! GUI prompt visible, starting spam")
                
                tradeDetected = true
                lastTradeTime = currentTime
                totalTradesProcessed = totalTradesProcessed + 1
                currentSessionTrades = currentSessionTrades + 1
                
                startSpamming()
            end
        end
        
        -- Method 3: Stop spam jika GUI hilang (trade processed)
        if isSpamming and not (hasTradePrompt and promptVisible) then
            print("[AutoAcceptTrade] GUI disappeared, trade likely processed")
            stopSpamming()
        end
    end)
    
    print("[AutoAcceptTrade] Pure detection system active")
    return true
end

-- === NOTIFICATION LISTENER ===
local function setupNotificationListener()
    if not textNotificationRemote then 
        print("[AutoAcceptTrade] No notification remote found")
        return 
    end
    
    -- PURE LISTENER: Hanya detect, tidak intercept
    local success = pcall(function()
        notificationConnection = textNotificationRemote.OnClientEvent:Connect(function(data)
            if not running then return end
            
            if data and data.Text then
                local text = data.Text:lower()
                
                -- Check untuk trade complete/success
                if string.find(text, "Trade completed!") or 
                   string.find(text, "trade completed!") or
                   string.find(text, "trade accepted") or
                   string.find(text, "you received") then
                    
                    print("[AutoAcceptTrade] TRADE COMPLETED! Stopping spam")
                    stopSpamming()
                    
                elseif string.find(text, "trade cancelled") or 
                       string.find(text, "trade expired") or
                       string.find(text, "trade declined") or
                       string.find(text, "trade failed") or
                       string.find(text, "trade rejected") then
                    
                    print("[AutoAcceptTrade] TRADE FAILED! Stopping spam")
                    stopSpamming()
                end
            end
        end)
    end)
    
    if success then
        print("[AutoAcceptTrade] Notification listener active")
    else
        warn("[AutoAcceptTrade] Could not setup notification listener")
    end
end

-- === INTERFACE METHODS ===
function AutoAcceptTrade:Init()
    print("[AutoAcceptTrade] Initializing pure detection method...")
    
    if not findRemotes() then
        warn("[AutoAcceptTrade] Failed to find required remotes")
        return false
    end
    
    if not setupTradeDetection() then
        warn("[AutoAcceptTrade] Failed to setup trade detection")
        return false
    end
    
    setupNotificationListener()
    
    print("[AutoAcceptTrade] Pure detection method initialized successfully")
    print(string.format("[AutoAcceptTrade] Button position: %.2f, %.2f", BUTTON_POSITION.X, BUTTON_POSITION.Y))
    print("[AutoAcceptTrade] Detection mode: GUI monitoring + Notification listening")
    
    return true
end

function AutoAcceptTrade:Start()
    if running then 
        print("[AutoAcceptTrade] Already running!")
        return true
    end
    
    running = true
    isSpamming = false
    tradeDetected = false
    currentSessionTrades = 0
    lastTradeTime = 0
    
    print("[AutoAcceptTrade] Started - Pure detection mode active")
    print("[AutoAcceptTrade] Will auto-click when trade prompt detected")
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
    
    if detectConnection then
        detectConnection:Disconnect()
        detectConnection = nil
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
        tradeDetected = tradeDetected,
        totalTradesProcessed = totalTradesProcessed,
        currentSessionTrades = currentSessionTrades,
        currentClicks = clickCount,
        remoteFound = awaitTradeResponseRemote ~= nil,
        mode = "Pure Detection Method"
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
            print("  Prompt visible:", prompt.Visible)
            
            if blackout then
                local options = blackout:FindFirstChild("Options")
                print("  Options found:", options and "Yes" or "No")
                print("  Blackout visible:", blackout.Visible)
                
                if options then
                    local yesButton = options:FindFirstChild("Yes")
                    print("  Yes button found:", yesButton and "Yes" or "No")
                    print("  Options visible:", options.Visible)
                    
                    if yesButton then
                        print("  Button type:", yesButton.ClassName)
                        print("  Button visible:", yesButton.Visible)
                        print("  Button position:", yesButton.AbsolutePosition)
                        print("  Button size:", yesButton.AbsoluteSize)
                        print("  Button center:", BUTTON_POSITION)
                    end
                end
            end
        end
    end)
    
    print("  Test success:", success)
    print("=== End Test ===")
end

function AutoAcceptTrade:TestDetection()
    print("=== Detection Test ===")
    print("  Detection connection:", detectConnection and "Active" or "Inactive")
    print("  Notification connection:", notificationConnection and "Active" or "Inactive")
    print("  Trade detected:", tradeDetected)
    print("  Last trade time:", lastTradeTime)
    print("  Running:", running)
    print("  Spamming:", isSpamming)
    
    -- Test current prompt state
    local state = getPromptState()
    print("=== Current Prompt State ===")
    print("  Prompt exists:", state.promptExists)
    print("  Prompt enabled:", state.promptEnabled)
    print("  Yes button exists:", state.yesButtonExists)
    print("  Yes button visible:", state.yesButtonVisible)
    print("  Full path:", state.fullPath)
    
    -- Test if should trigger
    local shouldTrigger = testTradePromptDetection()
    
    print("=== End Test ===")
end

function AutoAcceptTrade:ForceDetectionTest()
    print("[AutoAcceptTrade] Force testing detection...")
    return testTradePromptDetection()
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