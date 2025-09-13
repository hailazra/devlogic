--- AutoSendTrade.lua - Interface lifecycle yang konsisten + logic by fish names
local AutoSendTrade = {}
AutoSendTrade.__index = AutoSendTrade

-- Services
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Dependencies
local InventoryWatcher = _G.InventoryWatcher or loadstring(game:HttpGet("https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/debug-script/inventdetectfishit.lua"))()

-- State
local running = false
local hbConn = nil
local inventoryWatcher = nil

-- Configuration
local selectedFishNames = {} -- set: { ["Fish Name"] = true }
local selectedItemNames = {} -- set: { ["Item Name"] = true }
local selectedPlayers = {} -- set: { [playerName] = true }
local TRADE_DELAY = 3.0 -- delay between trade requests
local MAX_TRADES_PER_BATCH = 5
local BATCH_DELAY = 10.0

-- Tracking
local tradeQueue = {}
local pendingTrades = {}
local tradeCount = 0
local lastTradeTime = 0
local isProcessing = false

-- Remotes
local tradeRemote = nil
local textNotificationRemote = nil

-- Cache for fish names
local fishNamesCache = {}

-- === Helper Functions ===

-- Get fish names dari Items module (sama seperti GUI kamu)
local function getFishNames()
    if next(fishNamesCache) then return fishNamesCache end
    
    local itemsModule = RS:FindFirstChild("Items")
    if not itemsModule then
        warn("[AutoSendTrade] Items module not found")
        return {}
    end
    
    local fishNames = {}
    for _, item in pairs(itemsModule:GetChildren()) do
        if item:IsA("ModuleScript") then
            local success, moduleData = pcall(function()
                return require(item)
            end)
            
            if success and moduleData then
                -- Check apakah Type = "Fishes"
                if moduleData.Data and moduleData.Data.Type == "Fishes" then
                    -- Ambil nama dari Data.Name (bukan nama ModuleScript)
                    if moduleData.Data.Name then
                        table.insert(fishNames, moduleData.Data.Name)
                    end
                end
            end
        end
    end
    
    table.sort(fishNames)
    fishNamesCache = fishNames
    return fishNames
end

local function findRemotes()
    local success1, remote1 = pcall(function()
        return RS:WaitForChild("Packages", 5)
                  :WaitForChild("_Index", 5)
                  :WaitForChild("sleitnick_net@0.2.0", 5)
                  :WaitForChild("net", 5)
                  :WaitForChild("RF/InitiateTrade", 5)
    end)
    
    if success1 and remote1 then
        tradeRemote = remote1
    else
        warn("[AutoSendTrade] Failed to find InitiateTrade remote")
        return false
    end
    
    -- Text notification remote (optional)
    pcall(function()
        textNotificationRemote = RS:WaitForChild("Packages", 5)
                                   :WaitForChild("_Index", 5)
                                   :WaitForChild("sleitnick_net@0.2.0", 5)
                                   :WaitForChild("net", 5)
                                   :WaitForChild("RE/TextNotification", 5)
    end)
    
    return true
end

local function shouldTradeFish(fishEntry)
    if not fishEntry then return false end
    
    -- Resolve nama ikan menggunakan inventoryWatcher
    local fishId = fishEntry.Id or fishEntry.id
    local fishName = inventoryWatcher:_resolveName("Fishes", fishId)
    
    -- Check apakah nama ikan ini ada di selected list
    return selectedFishNames[fishName] == true
end

local function shouldTradeItem(itemEntry)
    if not itemEntry then return false end
    
    -- Resolve nama item menggunakan inventoryWatcher
    local itemId = itemEntry.Id or itemEntry.id
    local itemName = inventoryWatcher:_resolveName("Items", itemId)
    
    -- Check apakah nama item ini ada di selected list
    return selectedItemNames[itemName] == true
end

local function getRandomTargetPlayerId()
    local availablePlayers = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer and selectedPlayers[player.Name] then
            table.insert(availablePlayers, player.UserId)
        end
    end
    
    if #availablePlayers > 0 then
        return availablePlayers[math.random(1, #availablePlayers)]
    end
    
    return nil
end

local function sendTradeRequest(uuid, targetPlayerId, itemName)
    if not tradeRemote or not uuid or not targetPlayerId then return false end
    
    local success, result = pcall(function()
        return tradeRemote:InvokeServer(targetPlayerId, uuid)
    end)
    
    if success then
        print("[AutoSendTrade] Sent trade request:", itemName, "to player ID", targetPlayerId)
        return true
    else
        warn("[AutoSendTrade] Failed to send trade request:", result)
        return false
    end
end

local function scanForTradableItems()
    if not inventoryWatcher or not inventoryWatcher._ready or isProcessing then return end
    
    -- Check if we have targets
    local hasTargets = false
    for _ in pairs(selectedPlayers) do
        hasTargets = true
        break
    end
    if not hasTargets then return end
    
    -- Scan fishes
    local fishSnapshot = inventoryWatcher:getSnapshotTyped("Fishes")
    for _, fishEntry in ipairs(fishSnapshot) do
        local fishUuid = fishEntry.UUID or fishEntry.Uuid or fishEntry.uuid
        
        if fishUuid and not inventoryWatcher:isEquipped(fishUuid) and not pendingTrades[fishUuid] then
            if shouldTradeFish(fishEntry) then
                -- Check if already queued
                local alreadyQueued = false
                for _, queuedItem in ipairs(tradeQueue) do
                    if queuedItem.uuid == fishUuid then
                        alreadyQueued = true
                        break
                    end
                end
                
                if not alreadyQueued then
                    local fishId = fishEntry.Id or fishEntry.id
                    local fishName = inventoryWatcher:_resolveName("Fishes", fishId)
                    
                    table.insert(tradeQueue, {
                        uuid = fishUuid,
                        name = fishName,
                        category = "Fishes",
                        metadata = fishEntry.Metadata
                    })
                end
            end
        end
    end
    
    -- Scan items
    local itemSnapshot = inventoryWatcher:getSnapshotTyped("Items")
    for _, itemEntry in ipairs(itemSnapshot) do
        local itemUuid = itemEntry.UUID or itemEntry.Uuid or itemEntry.uuid
        
        if itemUuid and not inventoryWatcher:isEquipped(itemUuid) and not pendingTrades[itemUuid] then
            if shouldTradeItem(itemEntry) then
                -- Check if already queued
                local alreadyQueued = false
                for _, queuedItem in ipairs(tradeQueue) do
                    if queuedItem.uuid == itemUuid then
                        alreadyQueued = true
                        break
                    end
                end
                
                if not alreadyQueued then
                    local itemId = itemEntry.Id or itemEntry.id
                    local itemName = inventoryWatcher:_resolveName("Items", itemId)
                    
                    table.insert(tradeQueue, {
                        uuid = itemUuid,
                        name = itemName,
                        category = "Items"
                    })
                end
            end
        end
    end
end

local function processTradeQueue()
    if not running or #tradeQueue == 0 or isProcessing then return end
    
    local currentTime = tick()
    if currentTime - lastTradeTime < TRADE_DELAY then return end
    
    -- Check batch limits
    if tradeCount >= MAX_TRADES_PER_BATCH then
        if currentTime - lastTradeTime < BATCH_DELAY then return end
        tradeCount = 0 -- Reset batch counter
    end
    
    isProcessing = true
    
    -- Get next item
    local nextItem = table.remove(tradeQueue, 1)
    if not nextItem then
        isProcessing = false
        return
    end
    
    -- Double-check item still exists and not equipped
    local currentItems = inventoryWatcher:getSnapshotTyped(nextItem.category)
    local itemExists = false
    for _, item in ipairs(currentItems) do
        local uuid = item.UUID or item.Uuid or item.uuid
        if uuid == nextItem.uuid and not inventoryWatcher:isEquipped(uuid) then
            itemExists = true
            break
        end
    end
    
    if not itemExists then
        print("[AutoSendTrade] Item no longer available:", nextItem.name)
        isProcessing = false
        return
    end
    
    -- Send trade
    local targetPlayerId = getRandomTargetPlayerId()
    if targetPlayerId then
        local success = sendTradeRequest(nextItem.uuid, targetPlayerId, nextItem.name)
        
        if success then
            pendingTrades[nextItem.uuid] = {
                item = nextItem,
                timestamp = currentTime,
                targetPlayerId = targetPlayerId
            }
            tradeCount += 1
            lastTradeTime = currentTime
        end
    end
    
    isProcessing = false
end

local function setupNotificationListener()
    if not textNotificationRemote then return end
    
    textNotificationRemote.OnClientEvent:Connect(function(data)
        if data and data.Text then
            if data.Text == "Trade completed!" then
                -- Clear pending trades (simple approach)
                table.clear(pendingTrades)
                print("[AutoSendTrade] Trade completed! Total:", tradeCount)
            elseif data.Text == "Sent trade request!" then
                print("[AutoSendTrade] Trade request sent successfully")
            end
        end
    end)
end

local function mainLoop()
    if not running then return end
    
    scanForTradableItems()
    processTradeQueue()
end

-- === Interface Methods (lifecycle seperti versi lama) ===

function AutoSendTrade:Init(guiControls)
    print("[AutoSendTrade] Initializing...")
    
    -- Find remotes
    if not findRemotes() then
        return false
    end
    
    -- Initialize inventory watcher
    inventoryWatcher = InventoryWatcher.new()
    
    -- Wait for inventory watcher to be ready
    inventoryWatcher:onReady(function()
        print("[AutoSendTrade] Inventory watcher ready")
    end)
    
    -- Setup notification listener
    setupNotificationListener()
    
    -- Populate GUI dropdown jika diberikan
    if guiControls and guiControls.itemDropdown then
        local fishNames = getFishNames()
        
        -- Reload dropdown
        pcall(function()
            guiControls.itemDropdown:Reload(fishNames)
        end)
    end
    
    print("[AutoSendTrade] Initialization complete")
    return true
end

function AutoSendTrade:Start(config)
    if running then 
        print("[AutoSendTrade] Already running!")
        return 
    end
    
    -- Apply config if provided
    if config then
        if config.fishNames then
            self:SetSelectedFish(config.fishNames)
        end
        if config.itemNames then
            self:SetSelectedItems(config.itemNames)
        end
        if config.playerList then
            self:SetSelectedPlayers(config.playerList)
        end
    end
    
    running = true
    tradeCount = 0
    isProcessing = false
    
    -- Start main loop
    hbConn = RunService.Heartbeat:Connect(function()
        local success, err = pcall(mainLoop)
        if not success then
            warn("[AutoSendTrade] Error in main loop:", err)
        end
    end)
    
    print("[AutoSendTrade] Started")
end

function AutoSendTrade:Stop()
    if not running then 
        print("[AutoSendTrade] Not running!")
        return 
    end
    
    running = false
    isProcessing = false
    
    -- Disconnect heartbeat
    if hbConn then
        hbConn:Disconnect()
        hbConn = nil
    end
    
    -- Clear queues
    table.clear(tradeQueue)
    table.clear(pendingTrades)
    
    print("[AutoSendTrade] Stopped")
end

function AutoSendTrade:Cleanup()
    self:Stop()
    
    -- Clean up inventory watcher
    if inventoryWatcher then
        inventoryWatcher:destroy()
        inventoryWatcher = nil
    end
    
    -- Clear all data
    table.clear(selectedFishNames)
    table.clear(selectedItemNames)
    table.clear(selectedPlayers)
    table.clear(tradeQueue)
    table.clear(pendingTrades)
    table.clear(fishNamesCache)
    
    tradeRemote = nil
    textNotificationRemote = nil
    lastTradeTime = 0
    tradeCount = 0
    
    print("[AutoSendTrade] Cleaned up")
end

-- === Configuration Methods ===

function AutoSendTrade:SetSelectedFish(fishNames)
    if not fishNames then return false end
    
    -- Clear current selection
    table.clear(selectedFishNames)
    
    if type(fishNames) == "table" then
        if #fishNames > 0 then
            -- Array format: {"Shark", "Tuna"}
            for _, fishName in ipairs(fishNames) do
                if type(fishName) == "string" then
                    selectedFishNames[fishName] = true
                end
            end
        else
            -- Set format: {["Shark"] = true, ["Tuna"] = true}
            for fishName, enabled in pairs(fishNames) do
                if enabled and type(fishName) == "string" then
                    selectedFishNames[fishName] = true
                end
            end
        end
    end
    
    print("[AutoSendTrade] Selected fish:", selectedFishNames)
    return true
end

function AutoSendTrade:SetSelectedItems(itemNames)
    if not itemNames then return false end
    
    -- Clear current selection
    table.clear(selectedItemNames)
    
    if type(itemNames) == "table" then
        if #itemNames > 0 then
            -- Array format: {"Enchant Stone"}
            for _, itemName in ipairs(itemNames) do
                if type(itemName) == "string" then
                    selectedItemNames[itemName] = true
                end
            end
        else
            -- Set format: {["Enchant Stone"] = true}
            for itemName, enabled in pairs(itemNames) do
                if enabled and type(itemName) == "string" then
                    selectedItemNames[itemName] = true
                end
            end
        end
    end
    
    print("[AutoSendTrade] Selected items:", selectedItemNames)
    return true
end

function AutoSendTrade:SetSelectedPlayers(playerNames)
    if not playerNames then return false end
    
    -- Clear current selection
    table.clear(selectedPlayers)
    
    if type(playerNames) == "table" then
        if #playerNames > 0 then
            -- Array format: {"Player1", "Player2"}
            for _, playerName in ipairs(playerNames) do
                if type(playerName) == "string" and playerName ~= "" then
                    selectedPlayers[playerName] = true
                end
            end
        else
            -- Set format: {["Player1"] = true}
            for playerName, enabled in pairs(playerNames) do
                if enabled and type(playerName) == "string" and playerName ~= "" then
                    selectedPlayers[playerName] = true
                end
            end
        end
    end
    
    print("[AutoSendTrade] Selected players:", selectedPlayers)
    return true
end

function AutoSendTrade:SetTradeDelay(delay)
    if type(delay) == "number" and delay >= 1.0 then
        TRADE_DELAY = delay
        print("[AutoSendTrade] Trade delay set to:", delay)
        return true
    end
    return false
end

-- === Getter Methods ===

function AutoSendTrade:GetAvailableFish()
    return getFishNames()
end

function AutoSendTrade:GetOnlinePlayers()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    return players
end

function AutoSendTrade:GetSelectedFish()
    local selected = {}
    for fishName, enabled in pairs(selectedFishNames) do
        if enabled then
            table.insert(selected, fishName)
        end
    end
    return selected
end

function AutoSendTrade:GetSelectedItems()
    local selected = {}
    for itemName, enabled in pairs(selectedItemNames) do
        if enabled then
            table.insert(selected, itemName)
        end
    end
    return selected
end

function AutoSendTrade:GetSelectedPlayers()
    local selected = {}
    for playerName, enabled in pairs(selectedPlayers) do
        if enabled then
            table.insert(selected, playerName)
        end
    end
    return selected
end

function AutoSendTrade:GetStatus()
    return {
        isRunning = running,
        selectedFishCount = table.count(selectedFishNames),
        selectedItemCount = table.count(selectedItemNames),
        selectedPlayerCount = table.count(selectedPlayers),
        queueLength = #tradeQueue,
        completedTrades = tradeCount,
        isProcessing = isProcessing
    }
end

function AutoSendTrade:GetQueueSize()
    return #tradeQueue
end

function AutoSendTrade:IsRunning()
    return running
end

-- === Debug Methods ===

function AutoSendTrade:DumpStatus()
    local status = self:GetStatus()
    print("=== AutoSendTrade Status ===")
    for k, v in pairs(status) do
        print(k .. ":", v)
    end
    print("Selected Fish:", self:GetSelectedFish())
    print("Selected Items:", self:GetSelectedItems())
    print("Selected Players:", self:GetSelectedPlayers())
end

function AutoSendTrade:DumpQueue()
    print("=== Trade Queue ===")
    for i, item in ipairs(tradeQueue) do
        print(i, item.name, item.category, item.uuid)
    end
    print("Queue length:", #tradeQueue)
end

return AutoSendTrade