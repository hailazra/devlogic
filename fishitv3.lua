-- Load Universal Scanner
local UniversalScanner = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/universal-scanner.lua"
))()

-- WindUI Library
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

-- ===========================
-- ENHANCED FEATURE MANAGER
-- ===========================
local FeatureManager = {}
FeatureManager.LoadedFeatures = {}

local FEATURE_URLS = {
    AutoFish           = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autofish.lua", 
    AutoSellFish       = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autosellfish.lua",
    AutoTeleportIsland = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autoteleportisland.lua",
    FishWebhook        = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/fishwebhook.lua",
    AutoBuyWeather     = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autobuyweather.lua",
    AutoBuyBait        = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autobuybait.lua",
    AutoBuyRod         = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autobuyrod.lua",
    AutoTeleportEvent  = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autoteleportevent.lua",
    AutoGearOxyRadar   = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autogearoxyradar.lua",
    AntiAfk            = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/antiafk.lua"
}

function FeatureManager:LoadFeature(featureName, controls)
    if self.LoadedFeatures[featureName] then
        return self.LoadedFeatures[featureName]
    end
    
    local url = FEATURE_URLS[featureName]
    if not url then return nil end

    local success, feature = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)

    if success and type(feature) == "table" and feature.Init then
        local initSuccess = pcall(feature.Init, feature, controls)
        if initSuccess then
            self.LoadedFeatures[featureName] = feature
            WindUI:Notify({
                Title = "Success", Content = featureName .. " loaded", 
                Icon = "check", Duration = 2
            })
            return feature
        end
    end
    
    WindUI:Notify({
        Title = "Load Failed", Content = "Could not load " .. featureName,
        Icon = "x", Duration = 3
    })
    return nil
end

-- Auto-populate dropdown dengan Universal Scanner
function FeatureManager:AutoPopulateDropdown(dropdown, scannerMethod, label)
    if not dropdown or not UniversalScanner[scannerMethod] then return end
    
    task.spawn(function()
        -- Immediate populate
        local data = UniversalScanner[scannerMethod](UniversalScanner)
        if data and #data > 0 then
            if dropdown.Reload then
                dropdown:Reload(data)
                print("[AutoPopulate] " .. label .. " loaded: " .. #data .. " items")
            end
        end
        
        -- Delayed populate untuk network timing
        task.wait(2)
        local data2 = UniversalScanner[scannerMethod](UniversalScanner)
        if data2 and #data2 > 0 and dropdown.Reload then
            dropdown:Reload(data2)
            print("[AutoPopulate] " .. label .. " refreshed: " .. #data2 .. " items")
        end
    end)
end

--========== WINDOW ==========
local Window = WindUI:CreateWindow({
    Title         = ".devlogic",
    Icon          = "rbxassetid://73063950477508",
    Author        = "Fish It",
    Folder        = ".devlogichub",
    Size          = UDim2.fromOffset(250, 250),
    Theme         = "Dark",
    Resizable     = false,
    SideBarWidth  = 120,
    HideSearchBar = true,
})

WindUI:SetFont("rbxasset://12187373592")

-- [CUSTOM ICON CODE SAMA SEPERTI SEBELUMNYA - TIDAK BERUBAH]
Window:EditOpenButton({ Enabled = false })

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local function getUiRoot()
    return (gethui and gethui()) or game:GetService("CoreGui") or PlayerGui
end

local iconGui = getUiRoot():FindFirstChild("DevLogicIconGui") or Instance.new("ScreenGui")
iconGui.Name = "DevLogicIconGui"
iconGui.IgnoreGuiInset = true
iconGui.ResetOnSpawn = false
pcall(function() if syn and syn.protect_gui then syn.protect_gui(iconGui) end end)
iconGui.Parent = getUiRoot()

local iconButton = Instance.new("ImageButton")
iconButton.Name = "DevLogicOpenButton"
iconButton.Size = UDim2.fromOffset(40, 40)
iconButton.Position = UDim2.new(0, 10, 0.5, -20)
iconButton.BackgroundTransparency = 1
iconButton.Image = "rbxassetid://73063950477508"
iconButton.Parent = iconGui
iconButton.Visible = false

local isWindowOpen = true
local windowDestroyed = false

local function cleanupIcon()
    print("[GUI] Cleaning up custom icon...")
    windowDestroyed = true
    if iconButton then iconButton:Destroy() iconButton = nil end
    if iconGui then iconGui:Destroy() iconGui = nil end
    print("[GUI] Icon cleanup completed")
end
_G.DevLogicIconCleanup = cleanupIcon

local function toggleWindow()
    if windowDestroyed then return end
    if isWindowOpen then
        local success = pcall(function() Window:Close() end)
        if success then
            iconButton.Visible = true
            isWindowOpen = false
        end
    else
        local success = pcall(function() Window:Open() end)
        if success then
            iconButton.Visible = false
            isWindowOpen = true
        end
    end
end

-- [DRAG SYSTEM CODE - SAMA SEPERTI SEBELUMNYA]
local function makeDraggable(gui)
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    local dragDistance = 0
    local hasDraggedFar = false
    local dragStartTime = 0
    
    local MIN_DRAG_DISTANCE = 8     
    local TOGGLE_MAX_DISTANCE = 5   
    local TOGGLE_MAX_TIME = 0.5     

    local function updateInput(input)
        if not isDragging or not dragStart then return end
        local Delta = input.Position - dragStart
        dragDistance = math.sqrt(Delta.X^2 + Delta.Y^2)
        if dragDistance > MIN_DRAG_DISTANCE then hasDraggedFar = true end
        if hasDraggedFar then
            local Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + Delta.X, 
                startPos.Y.Scale, startPos.Y.Offset + Delta.Y
            )
            gui.Position = Position
        end
    end

    local inputChangedConnection = nil
    local inputEndedConnection = nil

    gui.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isDragging = true
            dragDistance = 0
            hasDraggedFar = false
            dragStart = input.Position
            startPos = gui.Position
            dragStartTime = tick()
            
            if inputChangedConnection then inputChangedConnection:Disconnect() end
            if inputEndedConnection then inputEndedConnection:Disconnect() end
            
            inputEndedConnection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    local dragEndTime = tick()
                    local dragDuration = dragEndTime - dragStartTime
                    isDragging = false
                    local isClick = (dragDistance < TOGGLE_MAX_DISTANCE) and 
                                  (dragDuration < TOGGLE_MAX_TIME) and (not hasDraggedFar)
                    if isClick then
                        wait(0.1)
                        toggleWindow()
                    end
                    if inputChangedConnection then
                        inputChangedConnection:Disconnect()
                        inputChangedConnection = nil
                    end
                    if inputEndedConnection then
                        inputEndedConnection:Disconnect()
                        inputEndedConnection = nil
                    end
                end
            end)
        end
    end)

    gui.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if isDragging then updateInput(input) end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            if isDragging then
                isDragging = false
                if inputChangedConnection then
                    inputChangedConnection:Disconnect()
                    inputChangedConnection = nil
                end
                if inputEndedConnection then
                    inputEndedConnection:Disconnect()
                    inputEndedConnection = nil
                end
            end
        end
    end)
end

makeDraggable(iconButton)

local lastVisible = nil
RunService.Heartbeat:Connect(function()
    if windowDestroyed then return end
    local windUIFrame = PlayerGui:FindFirstChild("WindUI")
    if windUIFrame then
        local mainFrame = windUIFrame:FindFirstChild("Frame") or windUIFrame:FindFirstChild("Main")
        if mainFrame and mainFrame.Visible ~= lastVisible then
            lastVisible = mainFrame.Visible
            if mainFrame.Visible then
                iconButton.Visible = false
                isWindowOpen = true
            else
                iconButton.Visible = true
                isWindowOpen = false
            end
        end
    end
end)

if Window.Toggle then
    local originalToggle = Window.Toggle
    Window.Toggle = function(self)
        local result = originalToggle(self)
        if not windowDestroyed and iconButton then
            iconButton.Visible = not iconButton.Visible
            isWindowOpen = not isWindowOpen
        end
        return result
    end
end

if Window.Close then
    local originalClose = Window.Close
    Window.Close = function(self)
        local result = originalClose(self)
        if not windowDestroyed and iconButton then
            iconButton.Visible = true
            isWindowOpen = false
        end
        return result
    end
end

if Window.Open then
    local originalOpen = Window.Open
    Window.Open = function(self)
        local result = originalOpen(self)
        if not windowDestroyed and iconButton then
            iconButton.Visible = false
            isWindowOpen = true
        end
        return result
    end
end

Window:Tag({ Title = "v0.0.0", Color = Color3.fromHex("#000000") })
Window:Tag({ Title = "Dev Version", Color = Color3.fromHex("#000000") })

local CHANGELOG = table.concat({
    "[+] Auto Fishing", "[+] Auto Teleport Island", "[+] Auto Buy Weather",
    "[+] Auto Sell Fish", "[+] Webhook",
}, "\n")
local DISCORD = "https://discord.gg/3AzvRJFT3M"
    
local function ShowChangelog()
    Window:Dialog({
        Title   = "Changelog",
        Content = CHANGELOG,
        Buttons = {
            {
                Title   = "Discord", Icon = "copy", Variant = "Secondary",
                Callback = function()
                    if typeof(setclipboard) == "function" then
                        setclipboard(DISCORD)
                        WindUI:Notify({ Title = "Copied", Content = "Discord copied", Icon = "check", Duration = 2 })
                    else
                        WindUI:Notify({ Title = "Info", Content = "Clipboard not available", Icon = "info", Duration = 3 })
                    end
                end
            },
            { Title = "Close", Variant = "Primary" }
        }
    })
end

Window:CreateTopbarButton("changelog", "newspaper", ShowChangelog, 995)

--========== TABS ==========
local TabHome     = Window:Tab({ Title = "Home",     Icon = "house" })
local TabMain     = Window:Tab({ Title = "Main",     Icon = "gamepad" })
local TabBackpack = Window:Tab({ Title = "Backpack", Icon = "backpack" })
local TabShop     = Window:Tab({ Title = "Shop",     Icon = "shopping-bag" })
local TabTeleport = Window:Tab({ Title = "Teleport", Icon = "map" })
local TabMisc     = Window:Tab({ Title = "Misc",     Icon = "cog" })

-- === HOME TAB ===
local DLsec = TabHome:Section({ Title = "Information", TextXAlignment = "Left", TextSize = 17 })

local AboutUs = TabHome:Paragraph({
    Title = ".devlogic", Desc = "Fully automatic game data scanning - no manual updates needed!",
    Color = "White", ImageSize = 30
})

local DiscordBtn = TabHome:Button({
    Title = "Discord", Icon = "message-circle",
    Callback = function() 
        if setclipboard then 
            setclipboard("https://discord.gg/3AzvRJFT3M") 
            WindUI:Notify({ Title = "Copied", Content = "Discord link copied", Icon = "check", Duration = 2 })
        end 
    end
})

-- Scanner Status Display
local scannerStatus = TabHome:Paragraph({
    Title = "Scanner Status", 
    Desc = "Universal scanner is loading game data...",
    Color = "Blue", 
    ImageSize = 25
})

-- Update scanner status periodically
task.spawn(function()
    task.wait(3)
    local weatherCount = #UniversalScanner:GetWeatherNames()
    local rodCount = #UniversalScanner:GetRodNames()
    local baitCount = #UniversalScanner:GetBaitNames()
    local islandCount = #UniversalScanner:GetIslandNames()
    local eventCount = #UniversalScanner:GetEventNames()
    
    scannerStatus:Set({
        Desc = string.format("✅ Scanned: %d Weather, %d Rods, %d Baits, %d Islands, %d Events", 
            weatherCount, rodCount, baitCount, islandCount, eventCount)
    })
end)

local antiafkFeature = nil
local antiafk_tgl = TabHome:Toggle({
    Title = "Anti AFK", Default = false,
    Callback = function(state) 
        if state then
            if not antiafkFeature then
                antiafkFeature = FeatureManager:LoadFeature("AntiAfk")
            end
            if antiafkFeature and antiafkFeature.Start then
                antiafkFeature:Start()
            else
                antiafk_tgl:Set(false)
                WindUI:Notify({ Title="Failed", Content="Could not start AntiAfk", Icon="x", Duration=3 })
            end
        else
            if antiafkFeature and antiafkFeature.Stop then antiafkFeature:Stop() end
        end
    end
})

-- === MAIN TAB - FISHING ===
local autofish_sec = TabMain:Section({ Title = "Fishing", TextXAlignment = "Left", TextSize = 17 })

local autoFishFeature = nil
local currentFishingMode = "Perfect"

local autofishmode_dd = TabMain:Dropdown({
    Title = "Fishing Mode", Values = { "Perfect", "OK", "Mid" }, Value = "Perfect",
    Callback = function(option) 
        currentFishingMode = option
        if autoFishFeature and autoFishFeature.SetMode then
            autoFishFeature:SetMode(option)
        end
    end
})
    
local autofish_tgl = TabMain:Toggle({
    Title = "Auto Fishing", Desc = "Automatically fishing with selected mode", Default = false,
    Callback = function(state) 
        if state then
            if not autoFishFeature then
                autoFishFeature = FeatureManager:LoadFeature("AutoFish", {
                    modeDropdown = autofishmode_dd, toggle = autofish_tgl
                })
            end
            if autoFishFeature and autoFishFeature.Start then
                autoFishFeature:Start({ mode = currentFishingMode })
            else
                WindUI:Notify({ Title = "Failed", Content = "Could not start AutoFish", Icon = "x", Duration = 3 })
            end
        else
            if autoFishFeature and autoFishFeature.Stop then autoFishFeature:Stop() end
        end
    end
})

-- === MAIN TAB - EVENT TELEPORT ===
local eventtele_sec = TabMain:Section({ Title = "Event Teleport", TextXAlignment = "Left", TextSize = 17 })

local eventteleFeature = nil
local selectedEventsArray = {}

local eventtele_ddm = TabMain:Dropdown({
    Title = "Select Event", Values = {"Scanning..."}, Value = {}, Multi = true, AllowNone = true,
    Callback = function(options)
        selectedEventsArray = options or {}
        if eventteleFeature and eventteleFeature.SetSelectedEvents then
            eventteleFeature:SetSelectedEvents(selectedEventsArray)
        end
    end
})

-- === BACKPACK TAB - FAVORITE FISH ===
local favfish_sec = TabBackpack:Section({ Title = "Favorite Fish", TextXAlignment = "Left", TextSize = 17 })

local selectedFishList = {}
local favfish_ddm = TabBackpack:Dropdown({
    Title = "Select Fish", Values = {"Scanning..."}, Value = {}, Multi = true, AllowNone = true,
    Callback = function(options) 
        selectedFishList = options or {}
        print("Fish selected: " ..game:GetService("HttpService"):JSONEncode(selectedFishList)) 
    end
})

-- AUTO-POPULATE FISH DROPDOWN
FeatureManager:AutoPopulateDropdown(favfish_ddm, "GetFishNames", "Fish")

local favfish_tgl = TabBackpack:Toggle({
    Title = "Auto Favorite Fish", Default = false,
    Callback = function(state) 
        if state then
            if #selectedFishList == 0 then
                WindUI:Notify({ 
                    Title = "Info", 
                    Content = "Select at least 1 fish first", 
                    Icon = "info", 
                    Duration = 3 
                })
                favfish_tgl:Set(false)
                return
            end
            print("Auto favorite activated for:", table.concat(selectedFishList, ", "))
        else
            print("Auto favorite deactivated")
        end
    end
})

-- === BACKPACK TAB - SELL FISH ===
local sellfish_sec = TabBackpack:Section({ Title = "Sell Fish", TextXAlignment = "Left", TextSize = 17 })

local sellfishFeature = nil
local currentSellThreshold = "Legendary"
local currentSellLimit = 0

local sellfish_dd = TabBackpack:Dropdown({
    Title = "Select Rarity", Values = { "Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" }, 
    Value = "Legendary",
    Callback = function(option)
        currentSellThreshold = option
        if sellfishFeature and sellfishFeature.SetMode then
            sellfishFeature:SetMode(option)
        end
    end
})

local sellfish_in = TabBackpack:Input({
    Title = "Sell Delay", Placeholder = "e.g 60 (second)", Desc = "Input delay in seconds.",
    Value = "60", Numeric = true,
    Callback = function(value)
        local n = tonumber(value) or 0
        currentSellLimit = n
        if sellfishFeature and sellfishFeature.SetLimit then
            sellfishFeature:SetLimit(n)
        end
    end
})

local sellfish_tgl = TabBackpack:Toggle({
    Title = "Auto Sell", Default = false,
    Callback = function(state)
        if state then
            if not sellfishFeature then
                sellfishFeature = FeatureManager:LoadFeature("AutoSellFish", {
                    thresholdDropdown = sellfish_dd, limitInput = sellfish_in, toggle = sellfish_tgl,
                })
            end
            if sellfishFeature and sellfishFeature.Start then
                sellfishFeature:Start({
                    threshold = currentSellThreshold, limit = currentSellLimit, autoOnLimit = true,
                })
            else
                sellfish_tgl:Set(false)
                WindUI:Notify({ Title="Failed", Content="Could not start AutoSellFish", Icon="x", Duration=3 })
            end
        else
            if sellfishFeature and sellfishFeature.Stop then sellfishFeature:Stop() end
        end
    end
})

-- === BACKPACK TAB - AUTO GIFT ===
local autogift_sec = TabBackpack:Section({ Title = "Auto Gift", TextXAlignment = "Left", TextSize = 17 })

local selectedGiftPlayer = ""
local autogiftplayer_dd = TabBackpack:Dropdown({
    Title = "Select Player", Values = {"Scanning..."}, Value = "",
    Callback = function(option) 
        selectedGiftPlayer = option
        print("Gift target selected: " .. option) 
    end
})

-- AUTO-UPDATE PLAYERS LIST FOR GIFT
local function updateGiftPlayersList()
    task.spawn(function()
        while true do
            local playerNames = UniversalScanner:GetPlayerNames()
            if autogiftplayer_dd.Reload and #playerNames > 0 then
                autogiftplayer_dd:Reload(playerNames)
            end
            task.wait(5) -- Update every 5 seconds
        end
    end)
end
updateGiftPlayersList()

local autogift_tgl = TabBackpack:Toggle({
    Title = "Auto Gift Fish", Desc = "Auto Gift held Fish/Item", Default = false,
    Callback = function(state) 
        if state then
            if selectedGiftPlayer == "" then
                WindUI:Notify({ 
                    Title = "Error", 
                    Content = "Please select a player first", 
                    Icon = "x", 
                    Duration = 3 
                })
                autogift_tgl:Set(false)
                return
            end
            print("Auto gift activated for player:", selectedGiftPlayer)
        else
            print("Auto gift deactivated")
        end
    end
})

-- === SHOP TAB - RODS ===
local shoprod_sec = TabShop:Section({ Title = "Rod", TextXAlignment = "Left", TextSize = 17 })

local autobuyrodFeature = nil
local selectedRodsSet = {}

local shoprod_ddm = TabShop:Dropdown({
    Title = "Select Rod", Values = {"Scanning..."}, Value = {}, Multi = true, AllowNone = true,
    Callback = function(options) 
        selectedRodsSet = options or {}
        if autobuyrodFeature and autobuyrodFeature.SetSelectedRodsByName then
            autobuyrodFeature:SetSelectedRodsByName(selectedRodsSet)
        end
    end
})

-- AUTO-POPULATE ROD DROPDOWN  
FeatureManager:AutoPopulateDropdown(shoprod_ddm, "GetRodNames", "Rods")

local shoprod_btn = TabShop:Button({
    Title = "Buy Rod", Desc = "Purchase selected rods (one-time buy)",
    Callback = function()
        if not autobuyrodFeature then
            autobuyrodFeature = FeatureManager:LoadFeature("AutoBuyRod", {
                rodsDropdown = shoprod_ddm, button = shoprod_btn
            })
        end
        
        if not selectedRodsSet or #selectedRodsSet == 0 then
            WindUI:Notify({ Title = "Info", Content = "Select at least 1 Rod first", Icon = "info", Duration = 3 })
            return
        end
        
        if autobuyrodFeature and autobuyrodFeature.Start then
            autobuyrodFeature:SetSelectedRodsByName(selectedRodsSet)
            autobuyrodFeature:Start({ rodList = selectedRodsSet, interDelay = 0.5 })
            WindUI:Notify({ Title = "Success", Content = "Rod purchase completed!", Icon = "check", Duration = 3 })
        end
    end
})

-- === SHOP TAB - BAITS ===
local shopbait_sec = TabShop:Section({ Title = "Baits", TextXAlignment = "Left", TextSize = 17 })

local autobuybaitFeature = nil
local selectedBaitsSet = {}

local shopbait_ddm = TabShop:Dropdown({
    Title = "Select Bait", Values = {"Scanning..."}, Value = {}, Multi = true, AllowNone = true,
    Callback = function(options) 
        selectedBaitsSet = options or {}
        if autobuybaitFeature and autobuybaitFeature.SetSelectedBaitsByName then
            autobuybaitFeature:SetSelectedBaitsByName(selectedBaitsSet)
        end
    end
})

-- AUTO-POPULATE BAIT DROPDOWN
FeatureManager:AutoPopulateDropdown(shopbait_ddm, "GetBaitNames", "Baits")

local shopbait_btn = TabShop:Button({
    Title = "Buy Bait", Desc = "Purchase selected baits (one-time buy)",
    Callback = function()
        if not autobuybaitFeature then
            autobuybaitFeature = FeatureManager:LoadFeature("AutoBuyBait", {
                dropdown = shopbait_ddm, button = shopbait_btn
            })
        end
        
        if not selectedBaitsSet or #selectedBaitsSet == 0 then
            WindUI:Notify({ Title = "Info", Content = "Select at least 1 Bait first", Icon = "info", Duration = 3 })
            return
        end
        
        if autobuybaitFeature and autobuybaitFeature.Start then
            autobuybaitFeature:SetSelectedBaitsByName(selectedBaitsSet)
            autobuybaitFeature:Start({ baitList = selectedBaitsSet, interDelay = 0.5 })
            WindUI:Notify({ Title = "Success", Content = "Bait purchase completed!", Icon = "check", Duration = 3 })
        end
    end
})

-- === SHOP TAB - WEATHER ===
local shopweather_sec = TabShop:Section({ Title = "Weather", TextXAlignment = "Left", TextSize = 17 })

local weatherFeature = nil
local selectedWeatherSet = {}

local shopweather_ddm = TabShop:Dropdown({
    Title = "Select Weather", Values = {"Scanning..."}, Value = {}, Multi = true, AllowNone = true,
    Callback = function(options)
        selectedWeatherSet = {}
        for _, opt in ipairs(options) do
            if type(opt) == "string" and opt ~= "" then
                selectedWeatherSet[opt] = true
            end
        end
        if weatherFeature and weatherFeature.SetWeathers then
            weatherFeature:SetWeathers(selectedWeatherSet)
        end
    end
})

-- AUTO-POPULATE WEATHER DROPDOWN
FeatureManager:AutoPopulateDropdown(shopweather_ddm, "GetWeatherNames", "Weather")

local shopweather_tgl = TabShop:Toggle({
    Title = "Auto Buy Weather", Default = false,
    Callback = function(state)
        if state then
            if not weatherFeature then
                weatherFeature = FeatureManager:LoadFeature("AutoBuyWeather", {
                    weatherDropdownMulti = shopweather_ddm, toggle = shopweather_tgl,
                })
            end

            if next(selectedWeatherSet) == nil then
                WindUI:Notify({ Title="Info", Content="Select atleast 1 Weather", Icon="info", Duration=3 })
                shopweather_tgl:Set(false)
                return
            end

            if weatherFeature and weatherFeature.Start then
                weatherFeature:Start({ weatherList = selectedWeatherSet })
            else
                shopweather_tgl:Set(false)
                WindUI:Notify({ Title="Failed", Content="Could not start AutoBuyWeather", Icon="x", Duration=3 })
            end
        else
            if weatherFeature and weatherFeature.Stop then weatherFeature:Stop() end
        end
    end
})

-- === TELEPORT TAB - ISLANDS ===
local teleisland_sec = TabTeleport:Section({ Title = "Islands", TextXAlignment = "Left", TextSize = 17 })

local autoTeleIslandFeature = nil
local currentIsland = ""

local teleisland_dd = TabTeleport:Dropdown({
    Title = "Select Island", Values = {"Scanning..."}, Value = "",
    Callback = function(option)
        currentIsland = option
        if autoTeleIslandFeature and autoTeleIslandFeature.SetIsland then
            autoTeleIslandFeature:SetIsland(option)
        end
    end
})

-- AUTO-POPULATE ISLAND DROPDOWN
FeatureManager:AutoPopulateDropdown(teleisland_dd, "GetIslandNames", "Islands")

local teleisland_btn = TabTeleport:Button({
    Title = "Teleport To Island", Locked = false,
    Callback = function()
        if not autoTeleIslandFeature then
            autoTeleIslandFeature = FeatureManager:LoadFeature("AutoTeleportIsland", {
                dropdown = teleisland_dd, button = teleisland_btn
            })
        end
        if autoTeleIslandFeature then
            if autoTeleIslandFeature.SetIsland then
                autoTeleIslandFeature:SetIsland(currentIsland)
            end
            if autoTeleIslandFeature.Teleport then
                autoTeleIslandFeature:Teleport(currentIsland)
            end
        else
            WindUI:Notify({
                Title = "Error", Content = "AutoTeleportIsland feature could not be loaded",
                Icon = "x", Duration = 3
            })
        end
    end
})

-- === TELEPORT TAB - PLAYERS ===
local teleplayer_sec = TabTeleport:Section({ Title = "Players", TextXAlignment = "Left", TextSize = 17 })

local selectedPlayer = ""
local teleplayer_dd = TabTeleport:Dropdown({
    Title = "Select Player", Values = {"Scanning..."}, Value = "",
    Callback = function(option) 
        selectedPlayer = option
        print("Player selected: " .. option) 
    end
})

-- AUTO-UPDATE PLAYERS LIST
local function updatePlayersList()
    task.spawn(function()
        while true do
            local playerNames = UniversalScanner:GetPlayerNames()
            if teleplayer_dd.Reload and #playerNames > 0 then
                teleplayer_dd:Reload(playerNames)
            end
            task.wait(5) -- Update every 5 seconds
        end
    end)
end
updatePlayersList()

local teleplayer_btn = TabTeleport:Button({
    Title = "Teleport To Player", Locked = false,
    Callback = function() 
        if selectedPlayer and selectedPlayer ~= "" then
            -- Implement player teleport logic here
            WindUI:Notify({ 
                Title = "Teleporting", 
                Content = "Teleporting to " .. selectedPlayer, 
                Icon = "navigation", 
                Duration = 2 
            })
        else
            WindUI:Notify({ 
                Title = "Error", 
                Content = "Please select a player first", 
                Icon = "x", 
                Duration = 3 
            })
        end
    end
})

-- === MISC TAB - WEBHOOK ===
local webhookfish_sec = TabMisc:Section({ Title = "Webhook", TextXAlignment = "Left", TextSize = 17 })

local fishWebhookFeature = nil
local currentWebhookUrl = ""
local selectedWebhookFishTypes = {}

-- Use scanner untuk dapatkan fish rarities yang real dari game
task.spawn(function()
    task.wait(2)
    local fishByRarity = UniversalScanner:GetFishByRarity()
    local rarities = {}
    for rarity, _ in pairs(fishByRarity) do
        table.insert(rarities, rarity)
    end
    table.sort(rarities)
    
    if #rarities > 0 then
        print("[Webhook] Found rarities:", table.concat(rarities, ", "))
        -- Update webhook dropdown jika perlu
    end
end)

local webhookfish_in = TabMisc:Input({
    Title = "Discord Webhook URL", Desc = "Paste your Discord webhook URL here",
    Value = "", Placeholder = "https://discord.com/api/webhooks/...", Type = "Input",
    Callback = function(input)
        currentWebhookUrl = input
        if fishWebhookFeature and fishWebhookFeature.SetWebhookUrl then
            fishWebhookFeature:SetWebhookUrl(input)
        end
    end
})

local webhookfish_ddm = TabMisc:Dropdown({
    Title = "Select Rarity", Desc = "Choose which fish rarities to send to webhook",
    Values = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }, 
    Value = {"Legendary", "Mythic", "Secret"}, Multi = true, AllowNone = true,
    Callback = function(options)
        selectedWebhookFishTypes = {}
        for _, option in ipairs(options) do
            selectedWebhookFishTypes[option] = true
        end
        if fishWebhookFeature and fishWebhookFeature.SetSelectedFishTypes then
            fishWebhookFeature:SetSelectedFishTypes(selectedWebhookFishTypes)
        end
    end
})

local webhookfish_tgl = TabMisc:Toggle({
    Title = "Enable Fish Webhook", Desc = "Automatically send notifications when catching selected fish", Default = false,
    Callback = function(state)
        if state then
            if currentWebhookUrl == "" then
                WindUI:Notify({ Title = "Error", Content = "Please enter webhook URL first", Icon = "x", Duration = 3 })
                webhookfish_tgl:Set(false)
                return
            end
            
            if not fishWebhookFeature then
                fishWebhookFeature = FeatureManager:LoadFeature("FishWebhook", {
                    urlInput = webhookfish_in, fishTypesDropdown = webhookfish_ddm, toggle = webhookfish_tgl
                })
            end
            
            if fishWebhookFeature and fishWebhookFeature.Start then
                local success = fishWebhookFeature:Start({
                    webhookUrl = currentWebhookUrl, selectedFishTypes = selectedWebhookFishTypes
                })
                if success then
                    WindUI:Notify({ Title = "Webhook Active", Content = "Fish notifications enabled", Icon = "check", Duration = 2 })
                else
                    webhookfish_tgl:Set(false)
                    WindUI:Notify({ Title = "Failed", Content = "Could not start webhook", Icon = "x", Duration = 3 })
                end
            end
        else
            if fishWebhookFeature and fishWebhookFeature.Stop then
                fishWebhookFeature:Stop()
                WindUI:Notify({ Title = "Webhook Stopped", Content = "Notifications disabled", Icon = "info", Duration = 2 })
            end
        end
    end
})

--========== INITIALIZATION ==========
print("[GUI] Fish-It GUI with Universal Auto-Scanner initialized!")
print("[Scanner] Starting automatic game data scanning...")

-- Display initial scan progress
WindUI:Notify({
    Title = "🔍 Scanning",
    Content = "Automatically scanning game data...",
    Icon = "search",
    Duration = 3
})

-- Show scan completion after delay
task.spawn(function()
    task.wait(5)
    local totalItems = #UniversalScanner:GetWeatherNames() + #UniversalScanner:GetRodNames() + 
                      #UniversalScanner:GetBaitNames() + #UniversalScanner:GetIslandNames() +
                      #UniversalScanner:GetEventNames()
    
    WindUI:Notify({
        Title = "✅ Scan Complete",
        Content = "Found " .. totalItems .. " items automatically!",
        Icon = "check-circle",
        Duration = 4
    })
end)

--========== LIFECYCLE ==========
if type(Window.OnClose) == "function" then
    Window:OnClose(function()
        print("[GUI] Window closed")
    end)
end

if type(Window.OnDestroy) == "function" then
    Window:OnDestroy(function()
        print("[GUI] Window destroying - cleaning up")
        
        -- Cleanup semua fitur
        for _, feature in pairs(FeatureManager.LoadedFeatures) do
            if feature.Cleanup then
                pcall(feature.Cleanup, feature)
            end
        end
        FeatureManager.LoadedFeatures = {}
        FeatureManager.DropdownRegistry = {}
        
        -- Cleanup custom icon
        if _G.DevLogicIconCleanup then
            pcall(_G.DevLogicIconCleanup)
            _G.DevLogicIconCleanup = nil
        end
    end)
end