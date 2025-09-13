--- AutoAcceptTrade.lua - Auto Accept Trade Requests (PURE DIRECT HOOK, resilient like Incoming.txt)
local AutoAcceptTrade = {}
AutoAcceptTrade.__index = AutoAcceptTrade

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- State
local running = false
local isProcessingTrade = false
local currentTradeData = nil
local notificationConnection = nil

-- Statistics
local totalTradesAccepted = 0
local currentSessionTrades = 0

-- Remotes
local awaitTradeResponseRemote :: RemoteFunction? = nil
local textNotificationRemote :: RemoteEvent? = nil
local originalAwaitTradeCB : any = nil
local newindexHookInstalled = false

-- === Helper Functions ===

local function smartFind(desc, className, nameContains)
    for _, inst in ipairs(desc:GetDescendants()) do
        if inst.ClassName == className then
            local n = tostring(inst.Name)
            if n == nameContains or string.find(n, nameContains, 1, true) then
                return inst
            end
        end
    end
    return nil
end

local function findRemotes()
    -- Primary path (sleitnick/net convention)
    do
        local ok, rf = pcall(function()
            return ReplicatedStorage:WaitForChild("Packages", 3)
                :WaitForChild("_Index", 3)
                :WaitForChild("sleitnick_net@0.2.0", 3)
                :WaitForChild("net", 3)
                :WaitForChild("RF/AwaitTradeResponse", 2)
        end)
        if ok and rf then
            awaitTradeResponseRemote = rf
            print("[AutoAcceptTrade] AwaitTradeResponse remote found (primary)")
        end
        local ok2, re = pcall(function()
            return ReplicatedStorage:WaitForChild("Packages", 2)
                :WaitForChild("_Index", 2)
                :WaitForChild("sleitnick_net@0.2.0", 2)
                :WaitForChild("net", 2)
                :WaitForChild("RE/TextNotification", 2)
        end)
        if ok2 and re then
            textNotificationRemote = re
            print("[AutoAcceptTrade] TextNotification remote found (primary)")
        end
    end

    -- Fallback: dynamic search
    if not awaitTradeResponseRemote then
        local alt = smartFind(ReplicatedStorage, "RemoteFunction", "AwaitTradeResponse")
        if alt then
            awaitTradeResponseRemote = alt
            print(("[AutoAcceptTrade] Found RF by scan: %s"):format(alt:GetFullName()))
        end
    end
    if not textNotificationRemote then
        local alt2 = smartFind(ReplicatedStorage, "RemoteEvent", "TextNotification")
        if alt2 then
            textNotificationRemote = alt2
            print(("[AutoAcceptTrade] Found RE by scan: %s"):format(alt2:GetFullName()))
        end
    end

    if not awaitTradeResponseRemote then
        warn("[AutoAcceptTrade] Failed to find AwaitTradeResponse RemoteFunction")
        return false
    end
    return true
end

-- shared wrapper used both by direct assign and by __newindex guard
local function makeAcceptWrapper(orig)
    originalAwaitTradeCB = orig or originalAwaitTradeCB
    local wrap
    if typeof(newcclosure) == "function" then
        wrap = newcclosure
    else
        wrap = function(fn) return fn end
    end
    return wrap(function(itemData, fromPlayer, timestamp, ...)
        if running then
            -- accept directly
            currentTradeData = {
                item = itemData,
                fromPlayer = fromPlayer,
                timestamp = timestamp,
                startTime = tick(),
            }
            isProcessingTrade = true
            totalTradesAccepted += 1
            currentSessionTrades += 1
            print("[AutoAcceptTrade] 🔔 Intercepted trade, auto-accept = true")
            task.spawn(function()
                task.wait(2)
                isProcessingTrade = false
            end)
            return true
        end
        -- feature OFF: fall back to original if any, else decline
        if originalAwaitTradeCB then
            return originalAwaitTradeCB(itemData, fromPlayer, timestamp, ...)
        end
        return false
    end)
end

-- Guard against game overwriting our hook (install FIRST)
local function installNewIndexGuard()
    if newindexHookInstalled then return end
    if type(hookmetamethod) ~= "function" then
        warn("[AutoAcceptTrade] hookmetamethod not available; guard skipped")
        return
    end
    local oldNewIndex
    oldNewIndex = hookmetamethod(game, "__newindex", (typeof(newcclosure)=="function" and newcclosure or function(x) return x end)(function(self, key, value)
        if typeof(self) == "Instance" and self.ClassName == "RemoteFunction" and key == "OnClientInvoke" then
            if self == awaitTradeResponseRemote then
                local isCallable = (typeof(value) == "function"
                    or (getrawmetatable and getrawmetatable(value) and typeof(getrawmetatable(value).__call)=="function"))
                if isCallable then
                    -- store original then wrap
                    originalAwaitTradeCB = value
                    return oldNewIndex(self, key, makeAcceptWrapper(value))
                end
            end
        end
        return oldNewIndex(self, key, value)
    end))
    newindexHookInstalled = true
    print("[AutoAcceptTrade] __newindex guard installed")
end

-- PURE DIRECT HOOK - No GUI interaction at all
local function setupTradeResponseListener()
    if not awaitTradeResponseRemote then return false end

    -- Try Incoming.txt pattern: wrap existing callback if present
    local Success, Callback = pcall(getcallbackvalue, awaitTradeResponseRemote, "OnClientInvoke")
    local IsCallable = Success and (
        typeof(Callback) == "function"
        or (getrawmetatable and getrawmetatable(Callback) and typeof(getrawmetatable(Callback).__call) == "function")
    )

    if IsCallable then
        originalAwaitTradeCB = Callback
        awaitTradeResponseRemote.OnClientInvoke = makeAcceptWrapper(Callback)
        print("[AutoAcceptTrade] Wrapped existing OnClientInvoke (Incoming-style)")
        return true
    else
        -- Fallback: assign our wrapper now; guard will re-wrap if the game sets later
        awaitTradeResponseRemote.OnClientInvoke = makeAcceptWrapper(nil)
        warn("[AutoAcceptTrade] No original callback yet; assigned provisional wrapper")
        return true
    end
end

local function setupNotificationListener()
    if not textNotificationRemote or notificationConnection then return end
    notificationConnection = textNotificationRemote.OnClientEvent:Connect(function(data)
        if not running then return end
        local text = (data and data.Text and tostring(data.Text):lower()) or ""
        if text == "" then return end

        if string.find(text, "trade completed", 1, true) or string.find(text, "trade successful", 1, true) then
            print("[AutoAcceptTrade] Trade completed")
            isProcessingTrade = false
            if currentTradeData then
                print(string.format("[AutoAcceptTrade] Duration: %.2fs", tick() - currentTradeData.startTime))
            end
            currentTradeData = nil
        elseif string.find(text, "trade cancelled", 1, true)
            or string.find(text, "trade canceled", 1, true)
            or string.find(text, "trade expired", 1, true)
            or string.find(text, "trade declined", 1, true)
            or string.find(text, "trade failed", 1, true) then
            print("[AutoAcceptTrade] Trade canceled/expired/declined")
            isProcessingTrade = false
            currentTradeData = nil
        end
    end)
    print("[AutoAcceptTrade] Notification listener setup complete")
end

-- === Interface Methods ===

function AutoAcceptTrade:Init(guiControls)
    print("[AutoAcceptTrade] Initializing (Incoming-style hook)")
    if not findRemotes() then
        warn("[AutoAcceptTrade] Required remotes not found")
        return false
    end

    -- IMPORTANT: install guard FIRST so late assignments also get wrapped
    installNewIndexGuard()

    -- Then wrap current callback or assign provisional wrapper
    local ok = setupTradeResponseListener()
    if not ok then
        warn("[AutoAcceptTrade] Failed to set up trade response listener (will rely on guard)")
    end

    setupNotificationListener()
    print("[AutoAcceptTrade] Init complete")
    return true
end

function AutoAcceptTrade:Start(config)
    if running then
        print("[AutoAcceptTrade] Already running")
        return true
    end
    running = true
    isProcessingTrade = false
    currentTradeData = nil
    currentSessionTrades = 0
    print("[AutoAcceptTrade] Started")
    return true
end

function AutoAcceptTrade:Stop()
    if not running then
        print("[AutoAcceptTrade] Not running")
        return true
    end
    running = false
    isProcessingTrade = false
    currentTradeData = nil
    print("[AutoAcceptTrade] Stopped | session accepted:", currentSessionTrades)
    return true
end

function AutoAcceptTrade:Cleanup()
    self:Stop()
    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end
    if awaitTradeResponseRemote then
        if originalAwaitTradeCB then
            awaitTradeResponseRemote.OnClientInvoke = originalAwaitTradeCB
            print("[AutoAcceptTrade] Original callback restored")
        else
            awaitTradeResponseRemote.OnClientInvoke = nil
        end
    end
    awaitTradeResponseRemote = nil
    textNotificationRemote = nil
    currentTradeData = nil
    totalTradesAccepted = 0
    currentSessionTrades = 0
    print("[AutoAcceptTrade] Cleaned up")
end

-- === Status / Debug ===

function AutoAcceptTrade:GetStatus()
    return {
        isRunning = running,
        isProcessingTrade = isProcessingTrade,
        totalTradesAccepted = totalTradesAccepted,
        currentSessionTrades = currentSessionTrades,
        hasCurrentTrade = currentTradeData ~= nil,
        currentTradeFrom = currentTradeData and currentTradeData.fromPlayer and currentTradeData.fromPlayer.Name or nil,
        remoteFound = awaitTradeResponseRemote ~= nil,
        hookInstalled = newindexHookInstalled,
        mode = "Direct Hook",
    }
end

function AutoAcceptTrade:DumpStatus()
    local status = self:GetStatus()
    print("=== AutoAcceptTrade Status ===")
    for k, v in pairs(status) do
        print(k .. ":", v)
    end
end

function AutoAcceptTrade:TestRemoteAccess()
    print("[AutoAcceptTrade] Testing remote access...")
    print("  awaitTradeResponseRemote:", awaitTradeResponseRemote and "Found" or "Not found")
    print("  textNotificationRemote:", textNotificationRemote and "Found" or "Not found")
    if awaitTradeResponseRemote then
        local success, callback = pcall(getcallbackvalue, awaitTradeResponseRemote, "OnClientInvoke")
        print("  getcallbackvalue:", success and "Success" or "Failed")
        if success then
            print("  callback type:", typeof(callback))
            print("  equal to original:", tostring(callback == originalAwaitTradeCB))
        end
    end
    print("  __newindex guard:", newindexHookInstalled and "Installed" or "Not installed")
end

-- Rescan in case remotes moved (optional)
function AutoAcceptTrade:Rescan()
    findRemotes()
    if awaitTradeResponseRemote and not newindexHookInstalled then
        installNewIndexGuard()
    end
    setupTradeResponseListener()
    print("[AutoAcceptTrade] Rescan complete")
end

-- === Statistics ===

function AutoAcceptTrade:GetTotalAccepted() return totalTradesAccepted end
function AutoAcceptTrade:GetSessionAccepted() return currentSessionTrades end
function AutoAcceptTrade:ResetStats()
    totalTradesAccepted = 0
    currentSessionTrades = 0
    print("[AutoAcceptTrade] Statistics reset")
end

return AutoAcceptTrade
