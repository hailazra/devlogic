-- File: autoaccepttrade_dynamic_patched.lua
-- Mode: DYNAMIC BUTTON DETECTION - mengambil posisi langsung dari ImageButton Yes
-- PATCHED VERSION - Fixed positioning issues
-- Start when Prompt.Enabled = true atau NotifyAwaitTradeResponse() dipanggil.
-- Stop saat RE/TextNotification mengandung "trade complete"/cancelled, Prompt dimatikan, atau timeout.

local AutoAcceptTradeSpam = {}
AutoAcceptTradeSpam.__index = AutoAcceptTradeSpam

-- Services
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService          = game:GetService("GuiService")
local UserInputService    = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ================== CONFIG ==================
local CONFIG = {
    PromptName      = "Prompt",  -- ScreenGui di PlayerGui
    YesButtonName   = "Yes",     -- nama ImageButton Yes
    ClicksPerSecond = 18,        -- 6..40 aman
    MaxSpamSeconds  = 6,         -- safety stop
    EdgePaddingFrac = 0.05,      -- padding kecil aja (5%)
    UseVIM          = true,      -- VirtualInputManager click
    AlsoMoveMouse   = true,      -- kirim mouse move sebelum click
    
    -- Opsi untuk debug
    DebugPrint      = false,     -- print posisi button saat ditemukan
    EnhancedDebug   = false,     -- detailed debug info
    
    -- Timing options
    UILoadDelay     = 0.3,       -- delay setelah prompt enabled
    ClickDelay      = 0.02,      -- delay antara mouse down/up
    RetryDelay      = 0.2,       -- delay untuk retry

    StopOnTextMatches = { "trade completed!", "Trade completed!", "trade successful" },
    StopOnFailMatches = { "trade cancelled", "trade canceled", "trade declined", "trade expired", "trade failed" },
}

-- ================== STATE ==================
local running, spamming = false, false
local stopRequested     = false
local spamThread        = nil

local promptGui         = nil
local yesButton         = nil
local promptEnabledConn = nil
local promptAncestryConn= nil

local textNotifRE       = nil
local notifConn         = nil

-- ================== HELPERS ==================
local function debugPrint(...)
    if CONFIG.DebugPrint or CONFIG.EnhancedDebug then
        print("[AutoAcceptTradeSpam]", ...)
    end
end

local function findNetRemote(name)
    local packages = ReplicatedStorage:FindFirstChild("Packages")
    if packages then
        local index = packages:FindFirstChild("_Index")
        if index then
            for _, child in ipairs(index:GetChildren()) do
                if child.Name:match("sleitnick_net@") then
                    local net = child:FindFirstChild("net")
                    if net then
                        local r = net:FindFirstChild(name)
                        if r then return r end
                    end
                end
            end
        end
    end
    -- fallback scan pendek
    local function scan(folder, depth)
        if depth > 3 then return nil end
        local r = folder:FindFirstChild(name)
        if r then return r end
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA("Folder") then
                local f = scan(c, depth + 1)
                if f then return f end
            end
        end
    end
    return scan(ReplicatedStorage, 0)
end

local function getPromptGui()
    local g = PlayerGui:FindFirstChild(CONFIG.PromptName)
    return (g and g:IsA("ScreenGui")) and g or nil
end

local function isButtonValid(button)
    return button and 
           button.Parent and 
           button.Visible and 
           button.Active and 
           button.AbsoluteSize.Magnitude > 0 and
           button:IsDescendantOf(PlayerGui)
end

local function findYesButton(gui)
    if not gui then return nil end
    
    local function searchInDescendants(parent)
        for _, child in ipairs(parent:GetDescendants()) do
            if child:IsA("ImageButton") and child.Name == CONFIG.YesButtonName then
                if isButtonValid(child) then
                    debugPrint("Found valid Yes button:", child:GetFullName())
                    return child
                else
                    debugPrint("Found Yes button but invalid state:", child.Name, "Visible:", child.Visible, "Active:", child.Active)
                end
            end
        end
        return nil
    end
    
    local button = searchInDescendants(gui)
    
    -- Enhanced debug: show all ImageButtons if target not found
    if not button and CONFIG.EnhancedDebug then
        debugPrint("=== ALL IMAGEBUTTONS IN PROMPT ===")
        for _, child in ipairs(gui:GetDescendants()) do
            if child:IsA("ImageButton") then
                debugPrint("ImageButton:", child.Name, "Visible:", child.Visible, "Active:", child.Active, "Size:", child.AbsoluteSize)
            end
        end
    end
    
    return button
end

local function getButtonRect(button)
    if not isButtonValid(button) then return nil end
    
    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize
    
    -- Get GUI inset untuk kompensasi topbar/etc
    local guiInset = GuiService:GetGuiInset()
    
    local rect = {
        X = absPos.X,
        Y = absPos.Y + guiInset.Y,
        W = absSize.X,
        H = absSize.Y
    }
    
    if CONFIG.EnhancedDebug then
        debugPrint("Button rect calculation:")
        debugPrint("  AbsolutePosition:", absPos)
        debugPrint("  AbsoluteSize:", absSize)
        debugPrint("  GuiInset:", guiInset)
        debugPrint("  Final rect:", rect.X, rect.Y, rect.W, rect.H)
    end
    
    return rect
end

local function randomPointInRect(rect)
    if not rect then return nil, nil end
    
    local pad = math.clamp(CONFIG.EdgePaddingFrac or 0, 0, 0.49)
    local minX = rect.X + rect.W * pad
    local maxX = rect.X + rect.W * (1 - pad)
    local minY = rect.Y + rect.H * pad
    local maxY = rect.Y + rect.H * (1 - pad)
    local x = minX + (maxX - minX) * math.random()
    local y = minY + (maxY - minY) * math.random()
    
    debugPrint("Random click point:", x, y, "in rect:", rect.X, rect.Y, rect.W, rect.H)
    return x, y
end

local function clickXY(x, y)
    if not x or not y then 
        debugPrint("Invalid click coordinates:", x, y)
        return 
    end
    
    local success = false
    
    -- Method 1: VirtualInputManager
    if CONFIG.UseVIM and VirtualInputManager then
        pcall(function()
            if CONFIG.AlsoMoveMouse then
                VirtualInputManager:SendMouseMoveEvent(x, y, game)
                task.wait(CONFIG.ClickDelay)
            end
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(CONFIG.ClickDelay)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
            success = true
        end)
    end
    
    -- Method 2: Direct button fire (fallback)
    if not success and yesButton and isButtonValid(yesButton) then
        pcall(function()
            -- Try to fire the button directly
            if yesButton.MouseButton1Click then
                yesButton.MouseButton1Click:Fire()
                success = true
                debugPrint("Used direct button fire fallback")
            end
        end)
    end
    
    if CONFIG.EnhancedDebug then
        debugPrint("Click attempted at:", x, y, "Success:", success)
    end
end

local function stopSpam(reason)
    if not spamming then return end
    stopRequested = true
    for _ = 1, 50 do  -- Increased timeout
        if not spamming then break end
        task.wait(0.01)
    end
    debugPrint("Spam stopped:", reason or "unknown")
end

local function waitForButtonReady(gui, maxWait)
    local deadline = tick() + (maxWait or 2)
    while tick() < deadline do
        local button = findYesButton(gui)
        if button and isButtonValid(button) then
            return button
        end
        task.wait(0.05)
    end
    return nil
end

local function startSpam()
    if spamming then 
        debugPrint("Already spamming, ignoring start request")
        return 
    end
    
    -- Wait for button to be ready
    yesButton = waitForButtonReady(promptGui, 2)
    if not yesButton then
        warn("[AutoAcceptTradeSpam] ImageButton 'Yes' tidak ditemukan atau tidak valid setelah menunggu!")
        return
    end
    
    local rect = getButtonRect(yesButton)
    if not rect then
        warn("[AutoAcceptTradeSpam] Tidak bisa ambil posisi button!")
        return
    end
    
    debugPrint("Button validation passed - starting spam")
    debugPrint("Button rect:", rect.X, rect.Y, rect.W, rect.H)
    
    spamming = true
    stopRequested = false

    spamThread = task.spawn(function()
        local started = tick()
        print(("[AutoAcceptTradeSpam] Spam dimulai pada Yes button @ (%.1f, %.1f) size: (%.1f, %.1f)")
            :format(rect.X, rect.Y, rect.W, rect.H))

        local clickCount = 0
        while spamming and running do
            if stopRequested then break end
            
            -- Validate button masih ada dan valid
            if not isButtonValid(yesButton) then
                debugPrint("Button became invalid, stopping spam")
                break
            end
            
            -- Update rect setiap beberapa click untuk handle perubahan posisi
            if clickCount % 5 == 0 then
                local currentRect = getButtonRect(yesButton)
                if currentRect then
                    rect = currentRect
                else
                    debugPrint("Could not get current button rect")
                    break
                end
            end
            
            local x, y = randomPointInRect(rect)
            if x and y then
                clickXY(x, y)
                clickCount = clickCount + 1
            end

            local base = 1 / math.clamp(CONFIG.ClicksPerSecond, 6, 40)
            local jitter = (math.random() - 0.5) * base * 0.35
            task.wait(base + jitter)

            if (tick() - started) > CONFIG.MaxSpamSeconds then
                debugPrint("Max spam time reached")
                break
            end
        end
        
        spamming = false
        debugPrint("Spam loop ended, total clicks:", clickCount)
    end)
end

local function bindTextNotifications()
    if notifConn then notifConn:Disconnect(); notifConn = nil end
    textNotifRE = textNotifRE or findNetRemote("RE/TextNotification")
    if textNotifRE and textNotifRE:IsA("RemoteEvent") then
        notifConn = textNotifRE.OnClientEvent:Connect(function(payload)
            if not running then return end
            local txt = type(payload) == "table" and payload.Text or payload
            if not txt then return end
            local t = tostring(txt):lower()
            
            for _, k in ipairs(CONFIG.StopOnTextMatches) do
                if string.find(t, k:lower(), 1, true) then 
                    stopSpam("trade completed")
                    debugPrint("Trade completed notification received:", txt)
                    return 
                end
            end
            for _, k in ipairs(CONFIG.StopOnFailMatches) do
                if string.find(t, k:lower(), 1, true) then 
                    stopSpam("trade failed/cancelled")
                    debugPrint("Trade failed/cancelled notification received:", txt)
                    return 
                end
            end
        end)
        debugPrint("Bound to RE/TextNotification")
    else
        warn("[AutoAcceptTradeSpam] RE/TextNotification not found - auto-stop via notification disabled")
    end
end

local function unbindPrompt()
    if promptEnabledConn then promptEnabledConn:Disconnect(); promptEnabledConn = nil end
    if promptAncestryConn then promptAncestryConn:Disconnect(); promptAncestryConn = nil end
    promptGui = nil
    yesButton = nil
    debugPrint("Unbound from prompt")
end

local function onPromptEnabledChanged()
    if not running then return end
    if not promptGui then return end
    
    if promptGui.Enabled then
        debugPrint("Prompt enabled, waiting for UI to load...")
        task.delay(CONFIG.UILoadDelay, function()
            if running and promptGui and promptGui.Enabled then
                local button = findYesButton(promptGui)
                if button and isButtonValid(button) then
                    startSpam()
                else
                    debugPrint("Button not ready, retrying...")
                    -- Retry after additional delay
                    task.delay(CONFIG.RetryDelay, function()
                        if running and promptGui and promptGui.Enabled then
                            startSpam()
                        end
                    end)
                end
            end
        end)
    else
        stopSpam("prompt disabled")
    end
end

local function bindPrompt()
    unbindPrompt()
    promptGui = getPromptGui()
    if not promptGui then
        debugPrint("Prompt GUI not found, waiting...")
        -- tunggu Prompt muncul
        task.spawn(function()
            local deadline = os.clock() + 5  -- Increased wait time
            while running and (os.clock() < deadline) and not promptGui do
                promptGui = getPromptGui()
                if promptGui then break end
                task.wait(0.1)  -- Less frequent checks
            end
            if running and promptGui then 
                debugPrint("Prompt GUI found after waiting")
                bindPrompt() 
            else
                debugPrint("Prompt GUI not found within timeout")
            end
        end)
        return
    end

    debugPrint("Binding to Prompt GUI:", promptGui:GetFullName())

    promptAncestryConn = promptGui.AncestryChanged:Connect(function()
        task.delay(0, function()
            if not promptGui or not promptGui:IsDescendantOf(PlayerGui) then
                debugPrint("Prompt GUI ancestry changed, rebinding...")
                bindPrompt()
            end
        end)
    end)

    promptEnabledConn = promptGui:GetPropertyChangedSignal("Enabled"):Connect(onPromptEnabledChanged)
    debugPrint("Bound Prompt.Enabled watcher")

    if promptGui.Enabled then 
        debugPrint("Prompt already enabled, triggering handler")
        onPromptEnabledChanged() 
    end
end

-- ================== PUBLIC API ==================
function AutoAcceptTradeSpam:Init(opts)
    opts = opts or {}
    for k, v in pairs(opts) do
        if CONFIG[k] ~= nil then
            CONFIG[k] = v
        end
    end
    bindTextNotifications()
    debugPrint("Initialized with config:", CONFIG)
    print("[AutoAcceptTradeSpam] Ready - Dynamic Button Detection Mode (Patched)")
    return true
end

function AutoAcceptTradeSpam:NotifyAwaitTradeResponse()
    if not running then 
        debugPrint("NotifyAwaitTradeResponse called but not running")
        return 
    end
    debugPrint("NotifyAwaitTradeResponse called")
    startSpam()
end

function AutoAcceptTradeSpam:Start()
    if running then 
        debugPrint("Already running")
        return true 
    end
    running = true
    debugPrint("Starting AutoAcceptTradeSpam")
    bindPrompt()

    -- kalau saat Start prompt udah nyala, langsung spam
    task.delay(CONFIG.UILoadDelay, function()
        if running then
            local g = getPromptGui()
            if g and g.Enabled then 
                debugPrint("Prompt already enabled at startup")
                startSpam() 
            end
        end
    end)

    print("[AutoAcceptTradeSpam] Started")
    return true
end

function AutoAcceptTradeSpam:Stop()
    if not running then return true end
    running = false
    stopSpam("manual stop")
    unbindPrompt()
    debugPrint("AutoAcceptTradeSpam stopped")
    return true
end

function AutoAcceptTradeSpam:Cleanup()
    self:Stop()
    if notifConn then notifConn:Disconnect(); notifConn = nil end
    debugPrint("Cleanup completed")
end

-- Utility functions
function AutoAcceptTradeSpam:SetYesButtonName(name)
    CONFIG.YesButtonName = name
    debugPrint("Yes button name set to:", name)
end

function AutoAcceptTradeSpam:EnableDebug(enable)
    CONFIG.DebugPrint = enable or true
    debugPrint("Debug mode:", enable and "enabled" or "disabled")
end

function AutoAcceptTradeSpam:EnableEnhancedDebug(enable)
    CONFIG.EnhancedDebug = enable or true
    CONFIG.DebugPrint = enable or true  -- Enhanced debug implies regular debug
    debugPrint("Enhanced debug mode:", enable and "enabled" or "disabled")
end

function AutoAcceptTradeSpam:SetUILoadDelay(delay)
    CONFIG.UILoadDelay = delay or 0.3
    debugPrint("UI load delay set to:", CONFIG.UILoadDelay)
end

function AutoAcceptTradeSpam:GetStatus()
    return {
        running = running,
        spamming = spamming,
        promptGui = promptGui and promptGui:GetFullName() or "nil",
        yesButton = yesButton and yesButton:GetFullName() or "nil"
    }
end

-- Enhanced test function
function AutoAcceptTradeSpam:TestButtonPosition()
    print("=== BUTTON POSITION TEST ===")
    
    local gui = getPromptGui()
    if not gui then
        print("❌ Prompt GUI tidak ditemukan!")
        return false
    end
    print("✅ Prompt GUI ditemukan:", gui:GetFullName())
    print("   Enabled:", gui.Enabled)
    
    local button = findYesButton(gui)
    if not button then
        print("❌ Button 'Yes' tidak ditemukan!")
        
        -- Show all ImageButtons for debugging
        print("\n=== ALL IMAGEBUTTONS IN PROMPT ===")
        local found = 0
        for _, child in ipairs(gui:GetDescendants()) do
            if child:IsA("ImageButton") then
                found = found + 1
                print(("  %d. %s - Visible: %s, Active: %s, Size: %s"):format(
                    found, child.Name, tostring(child.Visible), 
                    tostring(child.Active), tostring(child.AbsoluteSize)
                ))
            end
        end
        if found == 0 then
            print("  Tidak ada ImageButton ditemukan!")
        end
        return false
    end
    
    print("✅ Button 'Yes' ditemukan:", button:GetFullName())
    print("   Valid:", isButtonValid(button))
    print("   Visible:", button.Visible)
    print("   Active:", button.Active)
    print("   Size:", button.AbsoluteSize)
    
    local rect = getButtonRect(button)
    if not rect then
        print("❌ Tidak bisa mendapatkan posisi button!")
        return false
    end
    
    print("\n=== POSITION INFO ===")
    print("AbsolutePosition:", button.AbsolutePosition)
    print("AbsoluteSize:", button.AbsoluteSize)
    print("GuiInset:", GuiService:GetGuiInset())
    print("Calculated Rect:", rect.X, rect.Y, rect.W, rect.H)
    
    -- Test multiple clicks
    print("\n=== TESTING CLICKS ===")
    for i = 1, 3 do
        local x, y = randomPointInRect(rect)
        if x and y then
            print(("Test click %d: (%.1f, %.1f)"):format(i, x, y))
            clickXY(x, y)
            task.wait(0.8)  -- Longer delay between test clicks
        end
    end
    
    return true
end

-- Quick test function
function AutoAcceptTradeSpam:QuickTest()
    local gui = getPromptGui()
    local button = gui and findYesButton(gui)
    
    print("Quick Test Results:")
    print("  Prompt GUI:", gui and "✅ Found" or "❌ Not found")
    print("  Yes Button:", button and "✅ Found" or "❌ Not found")
    print("  Button Valid:", button and isButtonValid(button) and "✅ Valid" or "❌ Invalid")
    
    if button and isButtonValid(button) then
        local rect = getButtonRect(button)
        if rect then
            print(("  Position: (%.1f, %.1f) Size: (%.1f, %.1f)"):format(rect.X, rect.Y, rect.W, rect.H))
        end
    end
end

return AutoAcceptTradeSpam