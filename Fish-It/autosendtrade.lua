-- Fish-It/autosendtrade.lua
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
local selectedTiers = {} -- set: { [tierNumber] = true } for fish
local selectedItems = {} -- set: { ["Enchant Stone"] = true } for items
local selectedPlayers = {} -- set: { [playerName] = true }
local TICK_STEP = 0.5 -- throttle interval
local TRADE_DELAY = 5.0 -- delay between trade requests

-- Cache
local fishDataCache = {} -- { [fishId] = fishData }
local itemDataCache = {} -- { [itemId] = itemData }  
local tierDataCache = {} -- { [tierNumber] = tierInfo }
local lastTradeTime = 0
local tradeQueue = {} -- queue of { uuid, targetPlayerId, itemName, tierName }

-- Remotes
local tradeRemote = nil
local textNotificationRemote = nil

-- === Helper Functions ===

local function loadTierData()
    local success, tierModule = pcall(function()
        return RS:WaitForChild("Tiers", 5)
    end)
    
    if not success or not tierModule then
        warn("[AutoSendTrade] Failed to find Tiers module")
        return false
    end
    
    local success2, tierList = pcall(function()
        return require(tierModule)
    end)
    
    if not success2 or not tierList then
        warn("[AutoSendTrade] Failed to load Tiers data")
        return false
    end
    
    -- Cache tier data
    for _, tierInfo in ipairs(tierList) do
        tierDataCache[tierInfo.Tier] = tierInfo
    end
    
    return true
end

local function scanFishData()
    local itemsFolder = RS:FindFirstChild("Items")
    if not itemsFolder then
        warn("[AutoSendTrade] Items folder not found")
        return false
    end
    
    local function scanRecursive(folder)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("ModuleScript") then
                local success, data = pcall(function()
                    return require(child)
                end)
                
                if success and data and data.Data then
                    local itemData = data.Data
                    if itemData.Type == "Fishes" and itemData.Id and itemData.Tier then
                        fishDataCache[itemData.Id] = itemData
                    elseif itemData.Type == "Items" and itemData.Id then
                        itemDataCache[itemData.Id] = itemData
                    end
                end
            elseif child:IsA("Folder") then
                scanRecursive(child)
            end
        end
    end
    
    scanRecursive(itemsFolder)
    return next(fishDataCache) ~= nil or next(itemDataCache) ~= nil
end

local function findTradeRemote()
    local success, remote = pcall(function()
        return RS:WaitForChild("Packages", 5)
                  :WaitForChild("_Index", 5)
                  :WaitForChild("sleitnick_net@0.2.0", 5)
                  :WaitForChild("net", 5)
                  :WaitForChild("RF/InitiateTrade", 5)
    end)
    
    if success and remote then
        tradeRemote = remote
        return true
    end
    
    warn("[AutoSendTrade] Failed to find InitiateTrade remote")
    return false
end

local function findTextNotificationRemote()
    pcall(function()
        textNotificationRemote = RS:WaitForChild("Packages", 5)
                                   :WaitForChild("_Index", 5)
                                   :WaitForChild("sleitnick_net@0.2.0", 5)
                                   :WaitForChild("net", 5)
                                   :WaitForChild("RE/TextNotification", 5)
    end)
end

local function shouldTradeItem(entry, category)
    if not entry then return false end

    -- id fleksibel: Id/id/FishId/ItemId
    local itemId = entry.Id or entry.id or entry.FishId or entry.ItemId
    if not itemId then return false end

    if category == "Fishes" then
        local fishData = fishDataCache[itemId]
        if not fishData then return false end

        local tierNum = tonumber(fishData.Tier) or fishData.Tier
        local tierInfo = tierDataCache[tierNum]
        local tierName = tierInfo and tierInfo.Name

        -- match by angka atau nama (karena SetSelectedItems simpan dua-duanya)
        return (tierNum and selectedTiers[tierNum]) or (tierName and selectedTiers[tierName]) or false

    elseif category == "Items" then
        local itemData = itemDataCache[itemId]
        if not itemData then return false end
        local itemName = itemData.Name
        return itemName and selectedItems[itemName] == true
    end
    return false
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

local function sendTradeRequest(uuid, targetPlayerId, itemName, tierName)
    if not tradeRemote or not uuid or not targetPlayerId then return false end
    
    local success, result = pcall(function()
        return tradeRemote:InvokeServer(targetPlayerId, uuid)
    end)
    
    if success then
        print("[AutoSendTrade] Sent trade request:", itemName, tierName or "", "to player ID", targetPlayerId)
        return true
    else
        warn("[AutoSendTrade] Failed to send trade request:", result)
        return false
    end
end

local function processInventory()
    if not inventoryWatcher then return end
    
    -- Check if we have target players
    local hasTargets = false
    for _ in pairs(selectedPlayers) do
        hasTargets = true
        break
    end
    if not hasTargets then return end
    
    -- Process Fishes - menggunakan cara yang sama persis dengan autofavoritefish
    local fishes = inventoryWatcher:getSnapshotTyped("Fishes")
    if fishes and #fishes > 0 then
        for _, fishEntry in ipairs(fishes) do
            if shouldTradeItem(fishEntry, "Fishes") then
                local uuid = fishEntry.UUID or fishEntry.Uuid or fishEntry.uuid
                if uuid then
                    -- Check if already in queue
                    local alreadyQueued = false
                    for _, queueItem in ipairs(tradeQueue) do
                        if queueItem.uuid == uuid then
                            alreadyQueued = true
                            break
                        end
                    end
                    
                    if not alreadyQueued then
                        local fishId = fishEntry.Id or fishEntry.id
                        local fishData = fishDataCache[fishId]
                        local fishName = fishData and fishData.Name or "Unknown Fish"
                        local tierInfo = fishData and tierDataCache[fishData.Tier]
                        local tierName = tierInfo and tierInfo.Name or "Unknown Tier"
                        
                        local targetPlayerId = getRandomTargetPlayerId()
                        if targetPlayerId then
                            table.insert(tradeQueue, {
                                uuid = uuid,
                                targetPlayerId = targetPlayerId,
                                itemName = fishName,
                                tierName = tierName,
                                category = "Fishes"
                            })
                            print("[AutoSendTrade] Queued fish:", fishName, "(" .. tierName .. ")", uuid)
                        end
                    end
                end
            end
        end
    end
    
    -- Process Items (Enchant Stones)
    local items = inventoryWatcher:getSnapshotTyped("Items")
    if items and #items > 0 then
        for _, itemEntry in ipairs(items) do
            if shouldTradeItem(itemEntry, "Items") then
                local uuid = itemEntry.UUID or itemEntry.Uuid or itemEntry.uuid
                if uuid then
                    -- Check if already in queue
                    local alreadyQueued = false
                    for _, queueItem in ipairs(tradeQueue) do
                        if queueItem.uuid == uuid then
                            alreadyQueued = true
                            break
                        end
                    end
                    
                    if not alreadyQueued then
                        local itemId = itemEntry.Id or itemEntry.id
                        local itemData = itemDataCache[itemId]
                        local itemName = itemData and itemData.Name or "Unknown Item"
                        
                        local targetPlayerId = getRandomTargetPlayerId()
                        if targetPlayerId then
                            table.insert(tradeQueue, {
                                uuid = uuid,
                                targetPlayerId = targetPlayerId,
                                itemName = itemName,
                                tierName = nil,
                                category = "Items"
                            })
                            print("[AutoSendTrade] Queued item:", itemName, uuid)
                        end
                    end
                end
            end
        end
    end
end

local function processTradeQueue()
    if #tradeQueue == 0 then return end
    
    local currentTime = tick()
    if currentTime - lastTradeTime < TRADE_DELAY then return end
    
    local tradeItem = table.remove(tradeQueue, 1)
    if tradeItem then
        local success = sendTradeRequest(
            tradeItem.uuid, 
            tradeItem.targetPlayerId, 
            tradeItem.itemName, 
            tradeItem.tierName
        )
        
        if success then
            lastTradeTime = currentTime
        end
    end
end

local function mainLoop()
    if not running then return end
    
    processInventory()
    processTradeQueue()
end

-- === Lifecycle Methods ===

function AutoSendTrade:Init(guiControls)
    -- Load tier data
    if not loadTierData() then
        return false
    end
    
    -- Scan fish and item data
    if not scanFishData() then
        return false
    end
    
    -- Find trade remote
    if not findTradeRemote() then
        return false
    end
    
    -- Find text notification remote (optional)
    findTextNotificationRemote()
    
    -- Initialize inventory watcher
    inventoryWatcher = InventoryWatcher.new()
    
    -- Wait for inventory watcher to be ready
    inventoryWatcher:onReady(function()
        print("[AutoSendTrade] Inventory watcher ready")
    end)
    
    -- Populate GUI dropdown if provided
    -- Populate GUI dropdown if provided
if guiControls and guiControls.itemDropdown then
    local options = {}
    -- ambil semua tier dari cache, sort by Tier
    local tiersArr = {}
    for _, info in pairs(tierDataCache) do table.insert(tiersArr, info) end
    table.sort(tiersArr, function(a,b) return (a.Tier or 0) < (b.Tier or 0) end)
    for _, info in ipairs(tiersArr) do
        table.insert(options, info.Name)
    end
    table.insert(options, "Enchant Stone")
    pcall(function() guiControls.itemDropdown:Reload(options) end)
end 
    return true
end

function AutoSendTrade:Start(config)
    if running then return end
    
    -- Apply config if provided
    if config then
        if config.tierList then
            self:SetSelectedItems(config.tierList)
        end
        if config.playerList then
            self:SetSelectedPlayers(config.playerList)
        end
    end
    
    running = true
    
    -- Start main loop
    hbConn = RunService.Heartbeat:Connect(function()
        local success = pcall(mainLoop)
        if not success then
            warn("[AutoSendTrade] Error in main loop")
        end
    end)
    
    print("[AutoSendTrade] Started")
end

function AutoSendTrade:Stop()
    if not running then return end
    
    running = false
    
    -- Disconnect heartbeat
    if hbConn then
        hbConn:Disconnect()
        hbConn = nil
    end
    
    print("[AutoSendTrade] Stopped")
end

function AutoSendTrade:Cleanup()
    self:Stop()
    
    -- Clean up inventory watcher
    if inventoryWatcher then
        inventoryWatcher:destroy()
        inventoryWatcher = nil
    end
    
    -- Clear caches and queues
    table.clear(fishDataCache)
    table.clear(itemDataCache)
    table.clear(tierDataCache)
    table.clear(selectedTiers)
    table.clear(selectedItems)
    table.clear(selectedPlayers)
    table.clear(tradeQueue)
    table.clear(pendingTrades)
    
    tradeRemote = nil
    textNotificationRemote = nil
    lastTradeTime = 0
    
    print("[AutoSendTrade] Cleaned up")
end

-- === Setters ===

-- helper kecil buat ambil string dari opsi dropdown apa pun
local function _optToString(v)
    if type(v) == "string" then return v end
    if type(v) == "number" then return tostring(v) end
    if type(v) == "table" then
        return v.Value or v.value or v.Name or v.name or v[1] or v.Selected or v.selection
    end
    return nil
end

function AutoSendTrade:SetSelectedItems(itemInput)
    -- bersihin dulu
    table.clear(selectedTiers)
    table.clear(selectedItems)

    local function addByName(name)
        if not name then return end
        name = tostring(name):gsub("^%s+",""):gsub("%s+$","") -- trim

        -- cocokkan ke tier by name/number
        for tierNum, tierInfo in pairs(tierDataCache) do
            if tierInfo and (tierInfo.Name == name or tostring(tierNum) == name) then
                -- simpan dua kunci: angka & nama → bikin shouldTradeItem anti-miss
                selectedTiers[tierNum] = true
                selectedTiers[tierInfo.Name] = true
                return
            end
        end

        -- item biasa
        if name == "Enchant Stone" then
            selectedItems[name] = true
        end
    end

    local t = type(itemInput)
    if t == "string" or t == "number" then
        addByName(itemInput)
    elseif t == "table" then
        if #itemInput > 0 then
            for _, v in ipairs(itemInput) do
                addByName(_optToString(v))
            end
        else
            for k, v in pairs(itemInput) do
                -- dukung format set {["Legendary"]=true} atau { {Value="Legendary"}, ... }
                if type(k) ~= "number" and v then
                    addByName(_optToString(k))
                else
                    addByName(_optToString(v))
                end
            end
        end
    end

    -- log nama yang kepilih biar gampang ngecek
    local pickedTierNames = {}
    for k, enabled in pairs(selectedTiers) do
        if enabled and type(k) == "number" and tierDataCache[k] then
            table.insert(pickedTierNames, tierDataCache[k].Name)
        end
    end
    print("[AutoSendTrade] Selected Tiers:", table.concat(pickedTierNames, ", "))
    local pickedItems = {}
    for name, enabled in pairs(selectedItems) do
        if enabled then table.insert(pickedItems, name) end
    end
    print("[AutoSendTrade] Selected Items:", table.concat(pickedItems, ", "))
    return true
end


function AutoSendTrade:SetSelectedPlayers(playerInput)
    if not playerInput then return false end
    
    -- Clear current selection
    table.clear(selectedPlayers)
    
    -- Handle both array and set formats
    if type(playerInput) == "table" then
        -- If it's an array
        if #playerInput > 0 then
            for _, playerName in ipairs(playerInput) do
                if type(playerName) == "string" and playerName ~= "" then
                    selectedPlayers[playerName] = true
                end
            end
        else
            -- If it's a set/dict format
            for playerName, enabled in pairs(playerInput) do
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
    if type(delay) == "number" and delay >= 0.5 then
        TRADE_DELAY = delay
        return true
    end
    return false
end

-- === Utility Methods ===

function AutoSendTrade:GetAvailableItems()
    local items = {}
    
    -- Add tier names
    for tierNum = 1, 7 do
        if tierDataCache[tierNum] then
            table.insert(items, tierDataCache[tierNum].Name)
        end
    end
    
    -- Add known items
    table.insert(items, "Enchant Stone")
    
    return items
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

function AutoSendTrade:GetSelectedItems()
    local selected = {}
    
    -- Add selected tiers
    for tierNum, enabled in pairs(selectedTiers) do
        if enabled and tierDataCache[tierNum] then
            table.insert(selected, tierDataCache[tierNum].Name)
        end
    end
    
    -- Add selected items
    for itemName, enabled in pairs(selectedItems) do
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

function AutoSendTrade:GetQueueSize()
    return #tradeQueue
end

-- Alias methods untuk kompatibilitas GUI pattern yang berbeda
function AutoSendTrade:SetDesiredItemsByNames(itemInput)
    return self:SetSelectedItems(itemInput)
end

function AutoSendTrade:SetTarget(playerName)
    return self:SetSelectedPlayers(playerName)
end

function AutoSendTrade:RefreshPlayerList()
    return self:GetOnlinePlayers()
end

return AutoSendTrade