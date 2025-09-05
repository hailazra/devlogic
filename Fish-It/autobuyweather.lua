-- ===========================
-- AUTO BUY WEATHER FEATURE
-- File: autobuyweather.lua
-- Lifecycle: :Init(guiControls?), :Start(config?), :Stop(), :Cleanup()
-- Feature-specific setter: :SetWeather(weatherName)
-- Optional helper: :GetBuyableWeathers() -> {names}
-- ===========================

local AutoBuyWeather = {}
AutoBuyWeather.__index = AutoBuyWeather

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local EventsFolder      = ReplicatedStorage:WaitForChild("Events")

-- Network (bind saat Init)
local NetPath, PurchaseWeatherRF

-- State
local isRunning        = false
local hbConn           = nil
local remotesReady     = false
local selectedWeather  = nil
local activeWeather    = {}    -- [name] = true while presumed active
local buyableMap       = nil   -- [name] = data

-- pacing
local WAIT_BETWEEN = 0.15
local _lastTick    = 0

-- ===== helpers =====
local function initRemotes()
    return pcall(function()
        NetPath = ReplicatedStorage:WaitForChild("Packages", 5)
            :WaitForChild("_Index", 5)
            :WaitForChild("sleitnick_net@0.2.0", 5)
            :WaitForChild("net", 5)
        PurchaseWeatherRF = NetPath:WaitForChild("RF/PurchaseWeatherEvent", 5)
    end)
end

local function scanBuyables()
    local map = {}
    for _, m in ipairs(EventsFolder:GetChildren()) do
        if m:IsA("ModuleScript") then
            local ok, data = pcall(require, m)
            if ok and data and data.WeatherMachine and type(data.Name) == "string" then
                map[data.Name] = data
            end
        end
    end
    return map
end

function AutoBuyWeather:GetBuyableWeathers()
    buyableMap = scanBuyables()
    local names = {}
    for n in pairs(buyableMap) do table.insert(names, n) end
    table.sort(names)
    return names
end

local function purchaseOnce(name)
    if not PurchaseWeatherRF or not name then return false end
    local ok, err = pcall(function()
        return PurchaseWeatherRF:InvokeServer(name)
    end)
    if not ok then
        warn("[AutoBuyWeather] Purchase failed for '"..tostring(name).."': "..tostring(err))
    end
    return ok
end

-- ===== lifecycle =====
function AutoBuyWeather:Init(guiControls)
    local ok = initRemotes()
    remotesReady = ok and true or false
    if not remotesReady then
        warn("[AutoBuyWeather] remotes not ready")
        return false
    end

    buyableMap = scanBuyables()

    -- optional wiring langsung ke dropdown kalau diberikan oleh GUI:
    if guiControls and guiControls.weatherDropdown then
        local dd = guiControls.weatherDropdown
        local names = self:GetBuyableWeathers()
        if dd.Reload then dd:Reload(names) elseif dd.SetOptions then dd:SetOptions(names) end
        if not selectedWeather and #names > 0 then
            selectedWeather = names[1]
            if dd.Set then dd:Set(selectedWeather) end
        end
        if dd.OnChanged then
            dd:OnChanged(function(v) self:SetWeather(v) end)
        elseif dd.Callback then
            -- beberapa lib pakai Callback langsung
            -- biarkan GUI utama yang memanggil SetWeather dari callback-nya
        end
    end

    return true
end

-- config: { weatherName = "Shark Hunt" }
function AutoBuyWeather:Start(config)
    if isRunning then return end
    if not remotesReady then
        warn("[AutoBuyWeather] Start blocked: remotes not ready")
        return
    end

    if config and type(config.weatherName) == "string" then
        self:SetWeather(config.weatherName)
    end

    -- fallback pilih pertama jika belum ada
    if not selectedWeather then
        local names = self:GetBuyableWeathers()
        selectedWeather = names[1]
    end
    if not selectedWeather then
        warn("[AutoBuyWeather] No selectable weather")
        return
    end

    isRunning = true
    hbConn = RunService.Heartbeat:Connect(function()
        if not isRunning then return end
        local now = tick()
        if now - _lastTick < WAIT_BETWEEN then return end
        _lastTick = now

        -- pastikan masih buyable
        if not buyableMap or not buyableMap[selectedWeather] then
            buyableMap = scanBuyables()
            if not buyableMap[selectedWeather] then return end
        end

        if activeWeather[selectedWeather] then return end

        local data = buyableMap[selectedWeather]
        if purchaseOnce(selectedWeather) then
            local total = (data.QueueTime or 0) + (data.Duration or 0)
            if total > 0 then
                activeWeather[selectedWeather] = true
                task.delay(total, function()
                    activeWeather[selectedWeather] = nil
                end)
            end
        end
    end)
end

function AutoBuyWeather:Stop()
    if not isRunning then return end
    isRunning = false
    if hbConn then hbConn:Disconnect() hbConn = nil end
end

function AutoBuyWeather:Cleanup()
    self:Stop()
    remotesReady  = false
    buyableMap    = nil
    activeWeather = {}
end

-- ===== feature-specific setter =====
function AutoBuyWeather:SetWeather(name)
    if type(name) ~= "string" or name == "" then return false end
    if not buyableMap or not buyableMap[name] then
        buyableMap = scanBuyables()
    end
    if not buyableMap[name] then
        warn("[AutoBuyWeather] Weather not buyable/not found: " .. name)
        return false
    end
    selectedWeather = name
    return true
end

return AutoBuyWeather
