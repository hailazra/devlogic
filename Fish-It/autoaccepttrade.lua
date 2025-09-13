-- File: autoaccepttrade_spam.lua
-- Mode: NO HOOKS. Listen -> spam-click Yes button -> stop on TextNotification or prompt gone.

local AutoAcceptTradeSpam = {}
AutoAcceptTradeSpam.__index = AutoAcceptTradeSpam

-- Services
local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local VirtualInputManager  = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ===== Config (boleh di-tune) =====
local CONFIG = {
    -- Path tombol Yes (sesuai info kamu)
    YesButtonPath = {"Prompt","Blackout","Options","Yes"}, -- ImageButton

    -- Spam behavior
    ClicksPerSecond = 18,   -- 6..40 aman. 18 = natural
    MaxSpamSeconds  = 6,    -- safety stop bila trade nggak selesai
    JitterPixels    = 3,    -- random offset klik di sekitar center
    UseVIM          = true, -- pakai VirtualInputManager (lebih natural dari firesignal)

    -- Stop reasons via notif teks (lowercased contains)
    StopOnTextMatches = { "trade complete", "trade completed", "trade successful" },
    StopOnFailMatches = { "trade cancelled", "trade canceled", "trade declined", "trade expired", "trade failed" },
}

-- ===== State =====
local running        = false
local spamming       = false
local spamThread     = nil
local stopRequested  = false
local notifConn      = nil
local textNotifRE    = nil

-- ===== Helpers =====
local function findNetRemote(name)
    -- Cari di sleitnick_net dulu
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
    -- Fallback scan terbatas
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

local function getYesButton()
    local node = PlayerGui
    for _, seg in ipairs(CONFIG.YesButtonPath) do
        node = node and node:FindFirstChild(seg)
        if not node then return nil end
    end
    return (node and node:IsA("ImageButton")) and node or nil
end

local function ancestorsVisible(guiObj)
    local cur = guiObj
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") and cur.Visible == false then
            return false
        end
        cur = cur.Parent
    end
    return true
end

local function isClickable(btn)
    return btn
       and btn:IsDescendantOf(PlayerGui)
       and btn.Visible
       and ancestorsVisible(btn)
       and btn.AbsoluteSize.X > 0
       and btn.AbsoluteSize.Y > 0
end

local function clickAt(x, y)
    if VirtualInputManager and CONFIG.UseVIM then
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true,  game, 0)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    else
        -- Fallback: firesignal (beberapa anti-cheat kurang suka cara ini)
        local btn = getYesButton()
        if btn then
            pcall(function() firesignal(btn.MouseButton1Down) end)
            pcall(function() firesignal(btn.MouseButton1Click) end)
            pcall(function() firesignal(btn.MouseButton1Up) end)
        end
    end
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
            if not isClickable(btn) then
                -- Kalau prompt hilang mendadak, stop sebentar lagi
                if tick() - started > 0.15 then break end
            else
                local absPos  = btn.AbsolutePosition
                local absSize = btn.AbsoluteSize
                -- klik dekat center + jitter kecil
                local cx = absPos.X + absSize.X/2 + math.random(-CONFIG.JitterPixels, CONFIG.JitterPixels)
                local cy = absPos.Y + absSize.Y/2 + math.random(-CONFIG.JitterPixels, CONFIG.JitterPixels)
                clickAt(cx, cy)
            end

            -- pacing acak biar nggak kaku
            local base = 1 / math.clamp(CONFIG.ClicksPerSecond, 6, 40)
            task.wait(base + (math.random() - 0.5) * base * 0.35)

            -- safety timeout
            if (tick() - started) > CONFIG.MaxSpamSeconds then
                break
            end
        end
        spamming = false
    end)
end

local function stopSpam(reason)
    if not spamming then return end
    stopRequested = true
    for _ = 1, 25 do
        if not spamming then break end
        task.wait(0.01)
    end
    print(("[AutoAcceptTradeSpam] stop (%s)"):format(reason or ""))
end

local function bindTextNotifications()
    if notifConn then notifConn:Disconnect(); notifConn = nil end
    textNotifRE = textNotifRE or findNetRemote("RE/TextNotification")

    if textNotifRE and textNotifRE:IsA("RemoteEvent") then
        notifConn = textNotifRE.OnClientEvent:Connect(function(payload)
            if not running then return end
            local txt = type(payload) == "table" and payload.Text
            if not txt then return end
            local t = tostring(txt):lower()

            for _, k in ipairs(CONFIG.StopOnTextMatches) do
                if string.find(t, k, 1, true) then
                    stopSpam("complete")
                    return
                end
            end
            for _, k in ipairs(CONFIG.StopOnFailMatches) do
                if string.find(t, k, 1, true) then
                    stopSpam("cancelled")
                    return
                end
            end
        end)
        print("[AutoAcceptTradeSpam] bound RE/TextNotification")
    else
        warn("[AutoAcceptTradeSpam] RE/TextNotification not found (auto-stop via notif off)")
    end
end

-- ===== Public API =====
function AutoAcceptTradeSpam:Init(opts)
    opts = opts or {}
    for k, v in pairs(opts) do
        if CONFIG[k] ~= nil then CONFIG[k] = v end
    end

    bindTextNotifications()

    -- Passive: kalau tombol Yes muncul di PlayerGui, otomatis spam
    PlayerGui.DescendantAdded:Connect(function(obj)
        if not running then return end
        if obj:IsA("ImageButton") and obj.Name == CONFIG.YesButtonPath[#CONFIG.YesButtonPath] then
            task.delay(0.02, function() -- kasih waktu layout settle
                if running and isClickable(obj) then
                    startSpam()
                end
            end)
        end
    end)

    print("[AutoAcceptTradeSpam] ready (NO HOOKS, GUI-click method)")
    return true
end

-- Opsional: kamu bisa panggil ini dari inbound-debug kamu saat RF/AwaitTradeResponse terdeteksi
function AutoAcceptTradeSpam:NotifyAwaitTradeResponse()
    if not running then return end
    startSpam()
end

function AutoAcceptTradeSpam:Start()
    if running then return true end
    running = true
    -- kalau saat Start prompt sudah tampil, langsung spam
    task.delay(0.05, function()
        if running and isClickable(getYesButton()) then
            startSpam()
        end
    end)
    print("[AutoAcceptTradeSpam] started")
    return true
end

function AutoAcceptTradeSpam:Stop()
    if not running then return true end
    running = false
    stopSpam("manual stop")
    print("[AutoAcceptTradeSpam] stopped")
    return true
end

function AutoAcceptTradeSpam:Cleanup()
    self:Stop()
    if notifConn then notifConn:Disconnect(); notifConn = nil end
end

return AutoAcceptTradeSpam
