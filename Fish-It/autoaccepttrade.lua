-- File: autoaccepttrade_spam.lua
-- Mode: NO HOOKS. Listen Prompt.Enabled -> spam-click Yes -> stop by TextNotification/prompt gone/timeout.

local AutoAcceptTradeSpam = {}
AutoAcceptTradeSpam.__index = AutoAcceptTradeSpam

--// Services
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

--// ================== CONFIG ==================
local CONFIG = {
    -- Path tombol Yes (sesuai path kamu)
    PromptName      = "Prompt", -- ScreenGui
    YesButtonPath   = {"Blackout","Options","Yes"}, -- di bawah Prompt
    ClicksPerSecond = 18,
    MaxSpamSeconds  = 6,
    JitterPixels    = 3,

    UseVIM        = true,  -- VirtualInputManager mouse click
    UseActivate   = true,  -- :Activate() to trigger Activated
    UseFireSignal = true,  -- firesignal fallback

    -- (Opsional) Paksa klik titik tetap bila ABS pos tombol suka nyeleneh
    ForceCoords      = Vector2.new(277, 137),
    ForceEveryClick  = false,      -- true = selalu pakai ForceCoords

    StopOnTextMatches = { "trade complete", "trade completed", "trade successful" },
    StopOnFailMatches = { "trade cancelled", "trade canceled", "trade declined", "trade expired", "trade failed" },
}

--// ================== STATE ==================
local running, spamming = false, false
local stopRequested     = false
local spamThread        = nil

local textNotifRE       = nil
local notifConn         = nil

local promptGui         = nil
local promptEnabledConn = nil
local promptAncestryConn= nil
local promptChildConn1  = nil
local promptChildConn2  = nil

--// ================== HELPERS ==================
local function findNetRemote(name)
    -- cari sleitnick_net dulu
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
    if g and g:IsA("ScreenGui") then
        return g
    end
    return nil
end

local function getYesButton()
    local g = promptGui or getPromptGui()
    if not g then return nil end
    local node = g
    for _, seg in ipairs(CONFIG.YesButtonPath) do
        node = node and node:FindFirstChild(seg)
        if not node then return nil end
    end
    return (node and node:IsA("GuiButton")) and node or nil
end

local function isBtnRenderable(btn)
    -- Ketika ScreenGui.Enabled = false, event input nggak akan sampai, jadi cek Enabled juga
    local g = promptGui or getPromptGui()
    if not (g and g.Enabled) then return false end
    if not (btn and btn:IsDescendantOf(g)) then return false end
    if not (btn.Visible) then return false end
    local size = btn.AbsoluteSize
    return size.X > 0 and size.Y > 0
end

local function clickAt(x, y, btn)
    if CONFIG.UseVIM and VirtualInputManager then
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true,  game, 0)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end
    if CONFIG.UseActivate and btn and btn.Activate then
        pcall(function() btn:Activate() end)
    end
    if CONFIG.UseFireSignal and btn then
        pcall(function() if btn.MouseButton1Down  then firesignal(btn.MouseButton1Down)  end end)
        pcall(function() if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end end)
        pcall(function() if btn.MouseButton1Up    then firesignal(btn.MouseButton1Up)    end end)
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
    spamming = true
    stopRequested = false

    spamThread = task.spawn(function()
        local started = tick()
        while spamming do
            if stopRequested then break end

            local btn = getYesButton()
            local cx, cy

            if CONFIG.ForceCoords and (CONFIG.ForceEveryClick or not isBtnRenderable(btn)) then
                cx, cy = CONFIG.ForceCoords.X, CONFIG.ForceCoords.Y
            elseif isBtnRenderable(btn) then
                local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
                cx, cy = pos.X + size.X/2, pos.Y + size.Y/2
                if CONFIG.JitterPixels and CONFIG.JitterPixels > 0 then
                    cx += math.random(-CONFIG.JitterPixels, CONFIG.JitterPixels)
                    cy += math.random(-CONFIG.JitterPixels, CONFIG.JitterPixels)
                end
            end

            if cx and cy then
                clickAt(cx, cy, btn)
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

-- Rebind seluruh koneksi untuk Prompt ScreenGui
local function unbindPrompt()
    if promptEnabledConn then promptEnabledConn:Disconnect(); promptEnabledConn = nil end
    if promptAncestryConn then promptAncestryConn:Disconnect(); promptAncestryConn = nil end
    if promptChildConn1 then promptChildConn1:Disconnect(); promptChildConn1 = nil end
    if promptChildConn2 then promptChildConn2:Disconnect(); promptChildConn2 = nil end
    promptGui = nil
end

local function onPromptEnabledChanged()
    if not running then return end
    if not promptGui then return end
    if promptGui.Enabled then
        -- Beri sedikit waktu layout settle, lalu mulai spam
        task.delay(0.03, function()
            if running and promptGui and promptGui.Enabled then
                local btn = getYesButton()
                if isBtnRenderable(btn) or CONFIG.ForceCoords then
                    print("[AutoAcceptTradeSpam] Prompt.Enabled = true → start spam")
                    startSpam()
                end
            end
        end)
    else
        -- Prompt dimatikan
        stopSpam("prompt disabled")
    end
end

local function bindPrompt()
    unbindPrompt()
    promptGui = getPromptGui()
    if not promptGui then
        -- Tunggu sampai Prompt muncul di PlayerGui
        task.spawn(function()
            local deadline = os.clock() + 3
            while running and (os.clock() < deadline) and not promptGui do
                promptGui = getPromptGui()
                if promptGui then break end
                task.wait(0.05)
            end
            if running and promptGui then
                bindPrompt() -- re-enter untuk pasang koneksi
            end
        end)
        return
    end

    promptAncestryConn = promptGui.AncestryChanged:Connect(function()
        -- Prompt diganti/destroy -> rebind
        task.delay(0, function()
            if not promptGui or not promptGui:IsDescendantOf(PlayerGui) then
                bindPrompt()
            end
        end)
    end)

    -- Kalau game ganti struktur di bawah Prompt, re-evaluate Yes button
    promptChildConn1 = promptGui.DescendantAdded:Connect(function(obj)
        if not running then return end
        if obj.Name == (CONFIG.YesButtonPath[#CONFIG.YesButtonPath]) then
            -- kemungkinan Yes baru dibuat ulang, dan Prompt.Enabled sudah true
            task.delay(0.02, function()
                if running and promptGui and promptGui.Enabled then
                    local btn = getYesButton()
                    if isBtnRenderable(btn) then startSpam() end
                end
            end)
        end
    end)
    promptChildConn2 = promptGui.DescendantRemoving:Connect(function(obj)
        if not running then return end
        if obj == getYesButton() then
            stopSpam("yes removed")
        end
    end)

    promptEnabledConn = promptGui:GetPropertyChangedSignal("Enabled"):Connect(onPromptEnabledChanged)

    print("[AutoAcceptTradeSpam] bound Prompt ScreenGui (Enabled watcher)")

    -- Jika saat bind Prompt sudah enabled, langsung jalan
    if promptGui.Enabled then
        onPromptEnabledChanged()
    end
end

--// ================== PUBLIC API ==================
function AutoAcceptTradeSpam:Init(opts)
    opts = opts or {}
    for k, v in pairs(opts) do
        if CONFIG[k] ~= nil then CONFIG[k] = v end
    end
    bindTextNotifications()
    print("[AutoAcceptTradeSpam] ready (watch ScreenGui.Enabled, no hooks)")
    return true
end

-- Opsional: panggil ini dari deteksi RF/AwaitTradeResponse kamu (tanpa hook)
function AutoAcceptTradeSpam:NotifyAwaitTradeResponse()
    if not running then return end
    -- Mulai lebih awal; kalau Prompt belum Enabled, spam akan mulai begitu enabled
    startSpam()
end

function AutoAcceptTradeSpam:Start()
    if running then return true end
    running = true
    bindPrompt()

    -- Kalau saat Start Prompt sudah enabled + Yes ada, langsung spam
    task.delay(0.05, function()
        if running then
            local g = getPromptGui()
            if g and g.Enabled then
                local btn = getYesButton()
                if isBtnRenderable(btn) or CONFIG.ForceCoords then
                    startSpam()
                end
            end
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

return AutoAcceptTradeSpam
