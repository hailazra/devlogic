-- File: autoaccepttrade_dynamic.lua
-- Mode: DYNAMIC BUTTON DETECTION - mengambil posisi langsung dari ImageButton Yes
-- Start when Prompt.Enabled = true atau NotifyAwaitTradeResponse() dipanggil.
-- Stop saat RE/TextNotification mengandung "trade complete"/cancelled, Prompt dimatikan, atau timeout.

local AutoAcceptTradeSpam = {}
AutoAcceptTradeSpam.__index = AutoAcceptTradeSpam

-- Services
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

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

local function findYesButton(gui)
    if not gui then return nil end
    
    -- Search untuk ImageButton bernama "Yes" di dalam Prompt
    local function searchInDescendants(parent)
        for _, child in ipairs(parent:GetDescendants()) do
            if child:IsA("ImageButton") and child.Name == CONFIG.YesButtonName then
                return child
            end
        end
        return nil
    end
    
    return searchInDescendants(gui)
end

local function getButtonRect(button)
    if not button then return nil end
    
    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize
    
    return {
        X = absPos.X,
        Y = absPos.Y,
        W = absSize.X,
        H = absSize.Y
    }
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
    return x, y
end

local function clickXY(x, y)
    if not x or not y then return end
    
    if CONFIG.AlsoMoveMouse and VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseMoveEvent(x, y, game)
        end)
    end
    if CONFIG.UseVIM and VirtualInputManager then
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true,  game, 0)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end
end

local function stopSpam(reason)
    if not spamming then return end
    stopRequested = true
    for _ = 1, 30 do
        if not spamming then break end
        task.wait(0.01)
    end
    print(("[AutoAcceptTradeSpam] stop (%s)"):format(reason or ""))
end

local function startSpam()
    if spamming then return end
    
    -- Cari button Yes terlebih dahulu
    yesButton = findYesButton(promptGui)
    if not yesButton then
        warn("[AutoAcceptTradeSpam] ImageButton 'Yes' tidak ditemukan!")
        return
    end
    
    local rect = getButtonRect(yesButton)
    if not rect then
        warn("[AutoAcceptTradeSpam] Tidak bisa ambil posisi button!")
        return
    end
    
    if CONFIG.DebugPrint then
        print(("[AutoAcceptTradeSpam] Button pos: (%.3f, %.3f) size: (%.3f, %.3f)")
            :format(rect.X, rect.Y, rect.W, rect.H))
    end
    
    spamming = true
    stopRequested = false

    spamThread = task.spawn(function()
        local started = tick()
        print(("[AutoAcceptTradeSpam] spam start pada Yes button @ (%.3f, %.3f, %.3f, %.3f)")
            :format(rect.X, rect.Y, rect.W, rect.H))

        while spamming do
            if stopRequested then break end
            
            -- Update rect setiap loop untuk handle perubahan posisi
            local currentRect = getButtonRect(yesButton)
            if currentRect then
                local x, y = randomPointInRect(currentRect)
                if x and y then
                    clickXY(x, y)
                end
            end

            local base = 1 / math.clamp(CONFIG.ClicksPerSecond, 6, 40)
            task.wait(base + (math.random() - 0.5) * base * 0.35)

            if (tick() - started) > CONFIG.MaxSpamSeconds then
                break
            end
        end
        spamming = false
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
                if string.find(t, k, 1, true) then stopSpam("complete"); return end
            end
            for _, k in ipairs(CONFIG.StopOnFailMatches) do
                if string.find(t, k, 1, true) then stopSpam("cancelled"); return end
            end
        end)
        print("[AutoAcceptTradeSpam] bound RE/TextNotification")
    else
        warn("[AutoAcceptTradeSpam] RE/TextNotification not found (auto-stop via notif off)")
    end
end

local function unbindPrompt()
    if promptEnabledConn then promptEnabledConn:Disconnect(); promptEnabledConn = nil end
    if promptAncestryConn then promptAncestryConn:Disconnect(); promptAncestryConn = nil end
    promptGui = nil
    yesButton = nil
end

local function onPromptEnabledChanged()
    if not running then return end
    if not promptGui then return end
    if promptGui.Enabled then
        task.delay(0.1, function()  -- delay lebih lama untuk pastikan UI ready
            if running and promptGui and promptGui.Enabled then
                startSpam()
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
        -- tunggu Prompt muncul
        task.spawn(function()
            local deadline = os.clock() + 3
            while running and (os.clock() < deadline) and not promptGui do
                promptGui = getPromptGui()
                if promptGui then break end
                task.wait(0.05)
            end
            if running and promptGui then bindPrompt() end
        end)
        return
    end

    promptAncestryConn = promptGui.AncestryChanged:Connect(function()
        task.delay(0, function()
            if not promptGui or not promptGui:IsDescendantOf(PlayerGui) then
                bindPrompt()
            end
        end)
    end)

    promptEnabledConn = promptGui:GetPropertyChangedSignal("Enabled"):Connect(onPromptEnabledChanged)
    print("[AutoAcceptTradeSpam] bound Prompt.Enabled watcher")

    if promptGui.Enabled then onPromptEnabledChanged() end
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
    print("[AutoAcceptTradeSpam] ready (dynamic button detection mode)")
    return true
end

function AutoAcceptTradeSpam:NotifyAwaitTradeResponse()
    if not running then return end
    startSpam()
end

function AutoAcceptTradeSpam:Start()
    if running then return true end
    running = true
    bindPrompt()

    -- kalau saat Start prompt udah nyala, langsung spam
    task.delay(0.1, function()
        if running then
            local g = getPromptGui()
            if g and g.Enabled then startSpam() end
        end
    end)

    print("[AutoAcceptTradeSpam] started")
    return true
end

function AutoAcceptTradeSpam:Stop()
    if not running then return true end
    running = false
    stopSpam("manual stop")
    unbindPrompt()
    print("[AutoAcceptTradeSpam] stopped")
    return true
end

function AutoAcceptTradeSpam:Cleanup()
    self:Stop()
    if notifConn then notifConn:Disconnect(); notifConn = nil end
end

-- Utility functions
function AutoAcceptTradeSpam:SetYesButtonName(name)
    CONFIG.YesButtonName = name
end

function AutoAcceptTradeSpam:EnableDebug(enable)
    CONFIG.DebugPrint = enable or true
end

-- Manual function untuk test posisi button
function AutoAcceptTradeSpam:TestButtonPosition()
    local gui = getPromptGui()
    if not gui then
        print("Prompt GUI tidak ditemukan!")
        return
    end
    
    local button = findYesButton(gui)
    if not button then
        print("Button 'Yes' tidak ditemukan!")
        return
    end
    
    local rect = getButtonRect(button)
    if rect then
        print(("Button 'Yes' ditemukan - Pos: (%.3f, %.3f) Size: (%.3f, %.3f)")
            :format(rect.X, rect.Y, rect.W, rect.H))
        
        -- Test click sekali
        local x, y = randomPointInRect(rect)
        if x and y then
            print(("Test click di: (%.3f, %.3f)"):format(x, y))
            clickXY(x, y)
        end
    end
end

return AutoAcceptTradeSpam