-- ===========================
-- UNIVERSAL GAME DATA SCANNER
-- Otomatis scan semua item dari game tanpa hardcode
-- ===========================

local UniversalScanner = {}
UniversalScanner.Cache = {}
UniversalScanner.LastUpdate = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ===========================
-- GENERIC SCANNING FUNCTIONS
-- ===========================

-- Scan semua ModuleScript dan extract data
local function scanModuleScripts(root, filter)
    local results = {}
    local function recursiveScan(folder)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("ModuleScript") then
                local success, data = pcall(require, child)
                if success and type(data) == "table" then
                    -- Apply filter function
                    if not filter or filter(data, child) then
                        table.insert(results, {
                            name = child.Name,
                            data = data,
                            path = child:GetFullName()
                        })
                    end
                end
            elseif child:IsA("Folder") then
                recursiveScan(child)
            end
        end
    end
    
    if root then recursiveScan(root) end
    return results
end

-- Scan RemoteFunction/RemoteEvent patterns
local function scanRemotes(root, pattern)
    local results = {}
    local function recursiveScan(folder)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("RemoteFunction") or child:IsA("RemoteEvent") then
                if string.find(child.Name:lower(), pattern:lower()) then
                    table.insert(results, {
                        name = child.Name,
                        type = child.ClassName,
                        path = child:GetFullName()
                    })
                end
            elseif child:IsA("Folder") then
                recursiveScan(child)
            end
        end
    end
    
    if root then recursiveScan(root) end
    return results
end

-- ===========================
-- SPECIALIZED SCANNERS
-- ===========================

function UniversalScanner:ScanWeatherData()
    local cacheKey = "WeatherData"
    local now = tick()
    
    -- Cache untuk 30 detik
    if self.Cache[cacheKey] and (now - self.LastUpdate[cacheKey]) < 30 then
        return self.Cache[cacheKey]
    end
    
    print("[UniversalScanner] Scanning weather data...")
    
    local weatherItems = {}
    local sources = {
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage:FindFirstChild("WeatherData"),
        ReplicatedStorage:FindFirstChild("Shop"),
        ReplicatedStorage:FindFirstChild("GameData")
    }
    
    for _, source in ipairs(sources) do
        if source then
            -- Scan ModuleScripts yang mengandung weather data
            local modules = scanModuleScripts(source, function(data, module)
                -- Deteksi weather berdasarkan struktur data
                return (data.WeatherMachine or data.Weather or data.Name) and 
                       (data.Duration or data.QueueTime or string.find(module.Name:lower(), "weather"))
            end)
            
            for _, module in ipairs(modules) do
                local weatherName = module.data.Name or module.name
                if weatherName and type(weatherName) == "string" then
                    local weatherInfo = {
                        name = weatherName,
                        price = module.data.Price or module.data.Cost or 0,
                        duration = module.data.Duration or 0,
                        queueTime = module.data.QueueTime or 0,
                        tier = module.data.Tier or 1,
                        source = module.path
                    }
                    weatherItems[weatherName] = weatherInfo
                end
            end
        end
    end
    
    -- Convert ke array untuk dropdown
    local weatherNames = {}
    for name, _ in pairs(weatherItems) do
        table.insert(weatherNames, name)
    end
    table.sort(weatherNames)
    
    self.Cache[cacheKey] = {
        names = weatherNames,
        details = weatherItems,
        count = #weatherNames
    }
    self.LastUpdate[cacheKey] = now
    
    print("[UniversalScanner] Found " .. #weatherNames .. " weather items")
    return self.Cache[cacheKey]
end

function UniversalScanner:ScanRodData()
    local cacheKey = "RodData"
    local now = tick()
    
    if self.Cache[cacheKey] and (now - self.LastUpdate[cacheKey]) < 30 then
        return self.Cache[cacheKey]
    end
    
    print("[UniversalScanner] Scanning rod data...")
    
    local rodItems = {}
    local sources = {
        ReplicatedStorage:FindFirstChild("Shop"),
        ReplicatedStorage:FindFirstChild("Items"),
        ReplicatedStorage:FindFirstChild("Rods"),
        ReplicatedStorage:FindFirstChild("Equipment")
    }
    
    for _, source in ipairs(sources) do
        if source then
            local modules = scanModuleScripts(source, function(data, module)
                -- Deteksi rod berdasarkan properties
                return (data.Rod or data.FishingRod or data.Type == "Rod") or
                       string.find(module.Name:lower(), "rod") or
                       (data.Luck or data.Resilience or data.Control)
            end)
            
            for _, module in ipairs(modules) do
                local rodName = module.data.Name or module.name
                if rodName and type(rodName) == "string" then
                    rodItems[rodName] = {
                        name = rodName,
                        price = module.data.Price or module.data.Cost or 0,
                        tier = module.data.Tier or 1,
                        luck = module.data.Luck or 0,
                        resilience = module.data.Resilience or 0,
                        control = module.data.Control or 0,
                        source = module.path
                    }
                end
            end
        end
    end
    
    local rodNames = {}
    for name, _ in pairs(rodItems) do
        table.insert(rodNames, name)
    end
    table.sort(rodNames)
    
    self.Cache[cacheKey] = {
        names = rodNames,
        details = rodItems,
        count = #rodNames
    }
    self.LastUpdate[cacheKey] = now
    
    print("[UniversalScanner] Found " .. #rodNames .. " rod items")
    return self.Cache[cacheKey]
end

function UniversalScanner:ScanBaitData()
    local cacheKey = "BaitData"
    local now = tick()
    
    if self.Cache[cacheKey] and (now - self.LastUpdate[cacheKey]) < 30 then
        return self.Cache[cacheKey]
    end
    
    print("[UniversalScanner] Scanning bait data...")
    
    local baitItems = {}
    local sources = {
        ReplicatedStorage:FindFirstChild("Shop"),
        ReplicatedStorage:FindFirstChild("Items"),
        ReplicatedStorage:FindFirstChild("Baits"),
        ReplicatedStorage:FindFirstChild("Consumables")
    }
    
    for _, source in ipairs(sources) do
        if source then
            local modules = scanModuleScripts(source, function(data, module)
                return (data.Bait or data.Type == "Bait") or
                       string.find(module.Name:lower(), "bait") or
                       (data.LuckBoost or data.Attraction)
            end)
            
            for _, module in ipairs(modules) do
                local baitName = module.data.Name or module.name
                if baitName and type(baitName) == "string" then
                    baitItems[baitName] = {
                        name = baitName,
                        price = module.data.Price or module.data.Cost or 0,
                        tier = module.data.Tier or 1,
                        luckBoost = module.data.LuckBoost or 0,
                        attraction = module.data.Attraction or 0,
                        source = module.path
                    }
                end
            end
        end
    end
    
    local baitNames = {}
    for name, _ in pairs(baitItems) do
        table.insert(baitNames, name)
    end
    table.sort(baitNames)
    
    self.Cache[cacheKey] = {
        names = baitNames,
        details = baitItems,
        count = #baitNames
    }
    self.LastUpdate[cacheKey] = now
    
    print("[UniversalScanner] Found " .. #baitNames .. " bait items")
    return self.Cache[cacheKey]
end

function UniversalScanner:ScanIslandData()
    local cacheKey = "IslandData"
    local now = tick()
    
    if self.Cache[cacheKey] and (now - self.LastUpdate[cacheKey]) < 30 then
        return self.Cache[cacheKey]
    end
    
    print("[UniversalScanner] Scanning island data...")
    
    local islandItems = {}
    local sources = {
        ReplicatedStorage:FindFirstChild("Islands"),
        ReplicatedStorage:FindFirstChild("Locations"),
        ReplicatedStorage:FindFirstChild("Maps"),
        workspace:FindFirstChild("Islands")
    }
    
    for _, source in ipairs(sources) do
        if source then
            -- Scan folders yang represent islands
            for _, child in ipairs(source:GetChildren()) do
                if child:IsA("Folder") or child:IsA("Model") then
                    local islandName = child.Name
                    -- Filter nama yang masuk akal
                    if not string.find(islandName:lower(), "script") and
                       not string.find(islandName:lower(), "gui") and
                       string.len(islandName) > 2 then
                        islandItems[islandName] = {
                            name = islandName,
                            source = child:GetFullName(),
                            position = child:IsA("Model") and child.PrimaryPart and child.PrimaryPart.Position or Vector3.new(0,0,0)
                        }
                    end
                end
            end
            
            -- Scan ModuleScripts untuk island data
            local modules = scanModuleScripts(source, function(data, module)
                return data.Island or data.Location or data.Position or
                       string.find(module.Name:lower(), "island")
            end)
            
            for _, module in ipairs(modules) do
                local islandName = module.data.Name or module.data.Island or module.name
                if islandName and type(islandName) == "string" then
                    islandItems[islandName] = {
                        name = islandName,
                        position = module.data.Position or Vector3.new(0,0,0),
                        source = module.path
                    }
                end
            end
        end
    end
    
    local islandNames = {}
    for name, _ in pairs(islandItems) do
        table.insert(islandNames, name)
    end
    table.sort(islandNames)
    
    self.Cache[cacheKey] = {
        names = islandNames,
        details = islandItems,
        count = #islandNames
    }
    self.LastUpdate[cacheKey] = now
    
    print("[UniversalScanner] Found " .. #islandNames .. " islands")
    return self.Cache[cacheKey]
end

function UniversalScanner:ScanEventData()
    local cacheKey = "EventData"
    local now = tick()
    
    if self.Cache[cacheKey] and (now - self.LastUpdate[cacheKey]) < 30 then
        return self.Cache[cacheKey]
    end
    
    print("[UniversalScanner] Scanning event data...")
    
    local eventItems = {}
    local sources = {
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage:FindFirstChild("GameEvents"),
        ReplicatedStorage:FindFirstChild("ServerEvents")
    }
    
    -- Scan RemoteEvents/Functions dengan pattern event
    local remotePatterns = {"hunt", "event", "admin", "shark", "worm", "ghost"}
    
    for _, source in ipairs(sources) do
        if source then
            for _, pattern in ipairs(remotePatterns) do
                local remotes = scanRemotes(source, pattern)
                for _, remote in ipairs(remotes) do
                    local eventName = remote.name
                    -- Clean up nama event
                    eventName = eventName:gsub("Event", ""):gsub("RF", ""):gsub("RE", "")
                    eventName = eventName:gsub("([a-z])([A-Z])", "%1 %2") -- CamelCase to spaces
                    
                    if string.len(eventName) > 2 then
                        eventItems[eventName] = {
                            name = eventName,
                            originalName = remote.name,
                            type = remote.type,
                            source = remote.path
                        }
                    end
                end
            end
            
            -- Scan ModuleScripts
            local modules = scanModuleScripts(source, function(data, module)
                return string.find(module.name:lower(), "hunt") or 
                       string.find(module.name:lower(), "event") or
                       data.Event or data.Hunt
            end)
            
            for _, module in ipairs(modules) do
                local eventName = module.data.Name or module.name
                eventName = eventName:gsub("([a-z])([A-Z])", "%1 %2")
                
                if eventName and type(eventName) == "string" then
                    eventItems[eventName] = {
                        name = eventName,
                        duration = module.data.Duration or 0,
                        source = module.path
                    }
                end
            end
        end
    end
    
    local eventNames = {}
    for name, _ in pairs(eventItems) do
        table.insert(eventNames, name)
    end
    table.sort(eventNames)
    
    self.Cache[cacheKey] = {
        names = eventNames,
        details = eventItems,
        count = #eventNames
    }
    self.LastUpdate[cacheKey] = now
    
    print("[UniversalScanner] Found " .. #eventNames .. " events")
    return self.Cache[cacheKey]
end

function UniversalScanner:ScanFishData()
    local cacheKey = "FishData"
    local now = tick()
    
    if self.Cache[cacheKey] and (now - self.LastUpdate[cacheKey]) < 30 then
        return self.Cache[cacheKey]
    end
    
    print("[UniversalScanner] Scanning fish data...")
    
    local fishItems = {}
    local fishByRarity = {}
    local sources = {
        ReplicatedStorage:FindFirstChild("Fish"),
        ReplicatedStorage:FindFirstChild("FishData"),
        ReplicatedStorage:FindFirstChild("Items")
    }
    
    for _, source in ipairs(sources) do
        if source then
            local modules = scanModuleScripts(source, function(data, module)
                return data.Fish or data.Rarity or data.Value or
                       string.find(module.name:lower(), "fish")
            end)
            
            for _, module in ipairs(modules) do
                local fishName = module.data.Name or module.name
                local rarity = module.data.Rarity or "Common"
                
                if fishName and type(fishName) == "string" then
                    fishItems[fishName] = {
                        name = fishName,
                        rarity = rarity,
                        value = module.data.Value or module.data.Price or 0,
                        weight = module.data.Weight or 0,
                        source = module.path
                    }
                    
                    -- Group by rarity
                    if not fishByRarity[rarity] then
                        fishByRarity[rarity] = {}
                    end
                    table.insert(fishByRarity[rarity], fishName)
                end
            end
        end
    end
    
    local fishNames = {}
    for name, _ in pairs(fishItems) do
        table.insert(fishNames, name)
    end
    table.sort(fishNames)
    
    self.Cache[cacheKey] = {
        names = fishNames,
        details = fishItems,
        byRarity = fishByRarity,
        count = #fishNames
    }
    self.LastUpdate[cacheKey] = now
    
    print("[UniversalScanner] Found " .. #fishNames .. " fish types")
    return self.Cache[cacheKey]
end

function UniversalScanner:ScanPlayerList()
    local playerNames = {}
    local localPlayer = Players.LocalPlayer
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Name then
            table.insert(playerNames, player.Name)
        end
    end
    
    return {
        names = playerNames,
        count = #playerNames
    }
end

-- ===========================
-- UNIVERSAL GETTER FUNCTIONS
-- ===========================

function UniversalScanner:GetWeatherNames()
    return self:ScanWeatherData().names
end

function UniversalScanner:GetRodNames()
    return self:ScanRodData().names
end

function UniversalScanner:GetBaitNames()
    return self:ScanBaitData().names
end

function UniversalScanner:GetIslandNames()
    return self:ScanIslandData().names
end

function UniversalScanner:GetEventNames()
    return self:ScanEventData().names
end

function UniversalScanner:GetFishNames()
    return self:ScanFishData().names
end

function UniversalScanner:GetPlayerNames()
    return self:ScanPlayerList().names
end

-- Get detailed info
function UniversalScanner:GetWeatherDetails(name)
    return self:ScanWeatherData().details[name]
end

function UniversalScanner:GetRodDetails(name)
    return self:ScanRodData().details[name]
end

function UniversalScanner:GetFishByRarity()
    return self:ScanFishData().byRarity
end

-- ===========================
-- AUTO-REFRESH SYSTEM
-- ===========================

function UniversalScanner:StartAutoRefresh()
    if self.RefreshConnection then return end
    
    print("[UniversalScanner] Starting auto-refresh system...")
    
    self.RefreshConnection = game:GetService("RunService").Heartbeat:Connect(function()
        -- Refresh every 30 seconds
        if tick() - (self.lastRefresh or 0) >= 30 then
            self:ClearCache()
            self.lastRefresh = tick()
            print("[UniversalScanner] Cache cleared for auto-refresh")
        end
    end)
end

function UniversalScanner:StopAutoRefresh()
    if self.RefreshConnection then
        self.RefreshConnection:Disconnect()
        self.RefreshConnection = nil
        print("[UniversalScanner] Auto-refresh stopped")
    end
end

function UniversalScanner:ClearCache()
    self.Cache = {}
    self.LastUpdate = {}
end

-- Initialize auto-refresh
UniversalScanner:StartAutoRefresh()

return UniversalScanner