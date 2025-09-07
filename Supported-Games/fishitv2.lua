-- WindUI Library
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

-- ===========================
-- GLOBAL SERVICES & VARIABLES
-- ===========================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- Make global for features to access
_G.GameServices = {
    Players = Players,
    ReplicatedStorage = ReplicatedStorage,
    RunService = RunService,
    LocalPlayer = LocalPlayer,
    HttpService = HttpService
}

-- Safe network path access
local NetPath = nil
pcall(function()
    NetPath = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
end)
_G.NetPath = NetPath

-- ===========================
-- FEATURE MANAGER (IMPROVED)
-- ===========================
local FeatureManager = {}
FeatureManager.LoadedFeatures = {}
FeatureManager.DropdownRegistry = {} -- Track dropdown references for auto-update

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

-- Load feature for scanning only (tidak start, hanya init)
function FeatureManager:LoadFeatureForScan(featureName, controls)
    local url = FEATURE_URLS[featureName]
    if not url then return nil end

    local success, feature = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)

    if success and type(feature) == "table" and feature.Init then
        local initSuccess = pcall(feature.Init, feature, controls)
        if initSuccess then
            self.LoadedFeatures[featureName] = feature
            return feature
        end
    end
    return nil
end

function FeatureManager:LoadFeature(featureName, controls)
    -- Jika sudah dimuat sebelumnya, return existing
    if self.LoadedFeatures[featureName] then
        return self.LoadedFeatures[featureName]
    end
    
    local feature = self:LoadFeatureForScan(featureName, controls)
    if feature then
        WindUI:Notify({
            Title = "Success",
            Content = featureName .. " loaded successfully",
            Icon = "check",
            Duration = 2
        })
    else
        WindUI:Notify({
            Title = "Load Failed",
            Content = "Could not load " .. featureName,
            Icon = "x",
            Duration = 3
        })
    end
    return feature
end

-- Register dropdown untuk auto-update
function FeatureManager:RegisterDropdown(featureName, dropdownRef, dataFunction)
    if not self.DropdownRegistry[featureName] then
        self.DropdownRegistry[featureName] = {}
    end
    table.insert(self.DropdownRegistry[featureName], {
        dropdown = dropdownRef,
        dataFunc = dataFunction
    })
end

-- Auto-populate specific dropdown
function FeatureManager:PopulateDropdown(featureName, dropdownRef, dataFunction)
    local feature = self.LoadedFeatures[featureName] or self:LoadFeatureForScan(featureName)
    if not feature then return false end
    
    if dataFunction and feature[dataFunction] then
        local data = feature[dataFunction](feature)
        if data and type(data) == "table" then
            if dropdownRef.Reload then
                dropdownRef:Reload(data)
                print("[FeatureManager] " .. featureName .. " dropdown populated with " .. #data .. " items")
                return true
            end
        end
    end
    return false
end

-- Populate all registered dropdowns
function FeatureManager:PopulateAllDropdowns()
    print("[FeatureManager] Starting auto-populate for all dropdowns...")
    
    for featureName, dropdowns in pairs(self.DropdownRegistry) do
        for _, dropdownData in ipairs(dropdowns) do
            task.spawn(function()
                -- Immediate populate
                self:PopulateDropdown(featureName, dropdownData.dropdown, dropdownData.dataFunc)
                
                -- Delayed populate untuk network timing
                task.wait(2)
                self:PopulateDropdown(featureName, dropdownData.dropdown, dropdownData.dataFunc)
            end)
        end
    end
end

function FeatureManager:GetFeature(name)
    return self.LoadedFeatures[name]
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
    Title = ".devlogic", Desc = "If you found bugs or have suggestion, let us know.",
    Color = "White", ImageSize = 30
})
local DiscordBtn = TabHome:Button({
    Title = "Discord", Icon = "message-circle",
    Callback = function() if setclipboard then setclipboard(DISCORD) end end
})

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

-- === MAIN TAB ===
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

-- Event Teleport
local eventtele_sec = TabMain:Section({ Title = "Event Teleport", TextXAlignment = "Left", TextSize = 17 })

local eventteleFeature = nil
local selectedEventsArray = {}

local eventtele_ddm = TabMain:Dropdown({
    Title = "Select Event", 
    Values = {"Loading..."}, -- Placeholder sementara
    Value = {}, Multi = true, AllowNone = true,
    Callback = function(options)
        selectedEventsArray = options or {}
        if eventteleFeature and eventteleFeature.SetSelectedEvents then
            eventteleFeature:SetSelectedEvents(selectedEventsArray)
        end
    end
})

-- Register dropdown untuk auto-populate 
FeatureManager:RegisterDropdown("AutoTeleportEvent", eventtele_ddm, "GetAvailableEvents")

local eventtele_tgl = TabMain:Toggle({
    Title = "Auto Event Teleport", Desc = "Auto Teleport to Event when available", Default = false,
    Callback = function(state) 
        if state then
            if not eventteleFeature then
                eventteleFeature = FeatureManager:LoadFeature("AutoTeleportEvent", {
                    dropdown = eventtele_ddm, toggle = eventtele_tgl
                })
            end
            if eventteleFeature and eventteleFeature.Start then
                eventteleFeature:Start({
                    selectedEvents = selectedEventsArray, hoverHeight = 12
                })
            else
                eventtele_tgl:Set(false)
                WindUI:Notify({ Title="Failed", Content="Could not start AutoTeleportEvent", Icon="x", Duration=3 })
            end
        else
            if eventteleFeature and eventteleFeature.Stop then eventteleFeature:Stop() end
        end
    end
})

-- === BACKPACK TAB ===
local favfish_sec = TabBackpack:Section({ Title = "Favorite Fish", TextXAlignment = "Left", TextSize = 17 })

-- Auto-populate fish list dropdown
local favfish_ddm = TabBackpack:Dropdown({
    Title = "Select Fish", Values = {"Loading..."}, Value = {}, Multi = true, AllowNone = true,
    Callback = function(option) 
        print("Fish selected: " ..HttpService:JSONEncode(option)) 
    end
})

-- Register untuk auto-populate (jika ada fitur untuk scan fish)
-- FeatureManager:RegisterDropdown("FishScanner", favfish_ddm, "GetAllFishNames")

local favfish_tgl = TabBackpack:Toggle({
    Title = "Auto Favorite Fish", Default = false,
    Callback = function(state) print("Toggle Activated" .. tostring(state)) end
})

-- Sell Fish  
local sellfish_sec = TabBackpack:Section({ Title = "Sell Fish", TextXAlignment = "Left", TextSize = 17 })

local sellfishFeature = nil
local currentSellThreshold = "Legendary"
local currentSellLimit = 0

local sellfish_dd = TabBackpack:Dropdown({
    Title = "Select Rarity", Values = { "Secret", "Mythic", "Legendary" }, Value = "Legendary",
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

-- Auto Gift
local autogift_sec = TabBackpack:Section({ Title = "Auto Gift", TextXAlignment = "Left", TextSize = 17 })

-- Auto-populate players dropdown
local autogiftplayer_dd = TabBackpack:Dropdown({
    Title = "Select Player", Values = {"Loading..."}, Value = "",
    Callback = function(option) print("Player selected: " .. option) end
})

-- Auto-update players list
task.spawn(function()
    while true do
        local playerNames = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(playerNames, player.Name)
            end
        end
        if autogiftplayer_dd.Reload and #playerNames > 0 then
            autogiftplayer_dd:Reload(playerNames)
        end
        task.wait(5) -- Update every 5 seconds
    end
end)

local autogift_tgl = TabBackpack:Toggle({
    Title = "Auto Gift Fish", Desc = "Auto Gift held Fish/Item", Default = false,
    Callback = function(state) print("Toggle Activated" .. tostring(state)) end
})

-- === SHOP TAB ===
local shoprod_sec = TabShop:Section({ Title = "Rod", TextXAlignment = "Left", TextSize = 17 })

local autobuyrodFeature = nil
local selectedRodsSet = {}

local shoprod_ddm = TabShop:Dropdown({
    Title = "Select Rod", Values = {"Loading..."}, Value = {}, Multi = true, AllowNone = true,
    Callback = function(options) 
        selectedRodsSet = options or {}
        if autobuyrodFeature and autobuyrodFeature.SetSelectedRodsByName then
            autobuyrodFeature:SetSelectedRodsByName(selectedRodsSet)
        end
    end
})

-- Register untuk auto-populate
FeatureManager:RegisterDropdown("AutoBuyRod", shoprod_ddm, "GetAvailableRods")

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

-- Baits
local shopbait_sec = TabShop:Section({ Title = "Baits", TextXAlignment = "Left", TextSize = 17 })

local autobuybaitFeature = nil
local selectedBaitsSet = {}

local shopbait_ddm = TabShop:Dropdown({
    Title = "Select Bait", Values = {"Loading..."}, Value = {}, Multi = true, AllowNone = true,
    Callback = function(options) 
        selectedBaitsSet = options or {}
        if autobuybaitFeature and autobuybaitFeature.SetSelectedBaitsByName then
            autobuybaitFeature:SetSelectedBaitsByName(selectedBaitsSet)
        end
    end
})

-- Register untuk auto-populate
FeatureManager:RegisterDropdown("AutoBuyBait", shopbait_ddm, "GetAvailableBaits")

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

-- Weather
local shopweather_sec = TabShop:Section({ Title = "Weather", TextXAlignment = "Left", TextSize = 17 })

local weatherFeature = nil
local selectedWeatherSet = {}

local shopweather_ddm = TabShop:Dropdown({
    Title = "Select Weather", Values = {"Loading..."}, Value = {}, Multi = true, AllowNone = true,
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

-- Register untuk auto-populate
FeatureManager:RegisterDropdown("AutoBuyWeather", shopweather_ddm, "GetBuyableWeathers")

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

-- === TELEPORT TAB ===
local teleisland_sec = TabTeleport:Section({ Title = "Islands", TextXAlignment = "Left", TextSize = 17 })

local autoTeleIslandFeature = nil
local currentIsland = "Fisherman Island"

local teleisland_dd = TabTeleport:Dropdown({
    Title = "Select Island", Values = {"Loading..."}, Value = currentIsland,
    Callback = function(option)
        currentIsland = option
        if autoTeleIslandFeature and autoTeleIslandFeature.SetIsland then
            autoTeleIslandFeature:SetIsland(option)
        end
    end
})

-- Register untuk auto-populate islands
FeatureManager:RegisterDropdown("AutoTeleportIsland", teleisland_dd, "GetAvailableIslands")

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

local teleplayer_sec = TabTeleport:Section({ Title = "Players", TextXAlignment = "Left", TextSize = 17 })

local teleplayer_dd = TabTeleport:Dropdown({
    Title = "Select Player", Values = {"Loading..."}, Value = "",
    Callback = function(option) print("Player selected: " .. option) end
})

-- Auto-update players list for teleport
task.spawn(function()
    while true do
        local playerNames = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(playerNames, player.Name)
            end
        end
        if teleplayer_dd.Reload and #playerNames > 0 then
            teleplayer_dd:Reload(playerNames)
        end
        task.wait(5) -- Update every 5 seconds
    end
end)

local teleplayer_btn = TabTeleport:Button({
    Title = "Teleport To Player", Locked = false,
    Callback = function() print("clicked") end
})

-- === MISC TAB ===
local servutils_sec = TabMisc:Section({ Title = "Join Server", TextXAlignment = "Left", TextSize = 17 })

local servjoin_in = TabMisc:Input({
    Title = "Job Id", Desc = "Input Server Job Id", Value = "", Placeholder = "000-000-000",
    Type = "Input", Callback = function(input) print("Job ID entered: " .. input) end
})

local servjoin_btn = TabMisc:Button({
    Title = "Join Server", Locked = false,
    Callback = function() print("clicked") end
})

local servcopy_btn = TabMisc:Button({
    Title = "Copy Server ID", Desc = "Copy Current Server Job ID", Locked = false,
    Callback = function()
        local jobId = game.JobId
        if setclipboard and jobId ~= "" then
            setclipboard(jobId)
            WindUI:Notify({ Title = "Copied", Content = "Server ID copied to clipboard", Icon = "check", Duration = 2 })
        else
            WindUI:Notify({ Title = "Error", Content = "Could not copy server ID", Icon = "x", Duration = 3 })
        end
    end
})

-- Server Hop
local servhop_sec = TabMisc:Section({ Title = "Hop Server", TextXAlignment = "Left", TextSize = 17 })

local servhop_dd = TabMisc:Dropdown({
    Title = "Select Server Luck", Values = { "Any Server", "Low Players", "Medium Players", "High Players" },
    Value = "Any Server", Callback = function(option) print("Server type selected: " .. option) end
})

local servhop_tgl = TabMisc:Toggle({
    Title = "Auto Hop Server", Desc = "Auto Hop until found desired Server", Default = false,
    Callback = function(state) print("Server hop toggle: " .. tostring(state)) end
})

-- Webhook
local webhookfish_sec = TabMisc:Section({ Title = "Webhook", TextXAlignment = "Left", TextSize = 17 })

local fishWebhookFeature = nil
local currentWebhookUrl = ""
local selectedWebhookFishTypes = {}

local FISH_TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local webhookfish_in = TabMisc:Input({
    Title = "Discord Webhook URL", Desc = "Paste your Discord webhook URL here",
    Value = "", Placeholder = "https://discord.com/api/webhooks/...", Type = "Input",
    Callback = function(input)
        currentWebhookUrl = input
        print("[Webhook] URL updated:", input:sub(1, 50) .. (input:len() > 50 and "..." or ""))
        if fishWebhookFeature and fishWebhookFeature.SetWebhookUrl then
            fishWebhookFeature:SetWebhookUrl(input)
        end
    end
})

local webhookfish_ddm = TabMisc:Dropdown({
    Title = "Select Rarity", Desc = "Choose which fish types/rarities to send to webhook",
    Values = FISH_TIERS, Value = {"Legendary", "Mythic", "Secret"}, Multi = true, AllowNone = true,
    Callback = function(options)
        selectedWebhookFishTypes = {}
        for _, option in ipairs(options) do
            selectedWebhookFishTypes[option] = true
        end
        print("[Webhook] Fish types selected:", HttpService:JSONEncode(options))
        if fishWebhookFeature and fishWebhookFeature.SetSelectedFishTypes then
            fishWebhookFeature:SetSelectedFishTypes(selectedWebhookFishTypes)
        end
    end
})

local webhookfish_tgl = TabMisc:Toggle({
    Title = "Enable Fish Webhook", Desc = "Automatically send notifications when catching selected fish types",
    Default = false,
    Callback = function(state)
        if state then
            if currentWebhookUrl == "" then
                WindUI:Notify({
                    Title = "Error", Content = "Please enter webhook URL first",
                    Icon = "x", Duration = 3
                })
                webhookfish_tgl:Set(false)
                return
            end
            
            if next(selectedWebhookFishTypes) == nil then
                WindUI:Notify({
                    Title = "Warning", Content = "No fish types selected - will monitor all catches",
                    Icon = "alert-triangle", Duration = 3
                })
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
                    WindUI:Notify({ Title = "Start Failed", Content = "Could not start webhook monitoring", Icon = "x", Duration = 3 })
                end
            else
                webhookfish_tgl:Set(false)
                WindUI:Notify({ Title = "Load Failed", Content = "Could not load webhook feature", Icon = "x", Duration = 3 })
            end
        else
            if fishWebhookFeature and fishWebhookFeature.Stop then
                fishWebhookFeature:Stop()
                WindUI:Notify({ Title = "Webhook Stopped", Content = "Fish notifications disabled", Icon = "info", Duration = 2 })
            end
        end
    end
})

-- Vuln
local vuln_sec = TabMisc:Section({ Title = "Vuln", TextXAlignment = "Left", TextSize = 17 })

local autoGearFeature = nil
local oxygenOn = false
local radarOn = false

local eqoxygentank_tgl = TabMisc:Toggle({
    Title = "Equip Diving Gear", Desc = "No Need have Diving Gear", Default = false,
    Callback = function(state)
        print("Diving Gear toggle:", state)
        oxygenOn = state
        if state then
            if not autoGearFeature then
                autoGearFeature = FeatureManager:LoadFeature("AutoGearOxyRadar")
                if autoGearFeature and autoGearFeature.Start then
                    autoGearFeature:Start()
                end
            end
            if autoGearFeature and autoGearFeature.EnableOxygen then
                autoGearFeature:EnableOxygen(true)
            end
        else
            if autoGearFeature and autoGearFeature.EnableOxygen then
                autoGearFeature:EnableOxygen(false)
            end
        end
        if autoGearFeature and (not oxygenOn) and (not radarOn) and autoGearFeature.Stop then
            autoGearFeature:Stop()
        end
    end
})

local eqfishradar_tgl = TabMisc:Toggle({
    Title = "Enable Fish Radar", Desc = "No Need have Fish Radar", Default = false,
    Callback = function(state)
        print("Fish Radar toggle:", state)
        radarOn = state
        if state then
            if not autoGearFeature then
                autoGearFeature = FeatureManager:LoadFeature("AutoGearOxyRadar")
                if autoGearFeature and autoGearFeature.Start then
                    autoGearFeature:Start()
                end
            end
            if autoGearFeature and autoGearFeature.EnableRadar then
                autoGearFeature:EnableRadar(true)
            end
        else
            if autoGearFeature and autoGearFeature.EnableRadar then
                autoGearFeature:EnableRadar(false)
            end
        end
        if autoGearFeature and (not oxygenOn) and (not radarOn) and autoGearFeature.Stop then
            autoGearFeature:Stop()
        end
    end
})

--========== AUTO-POPULATE INITIALIZATION ==========
print("[GUI] Starting auto-populate initialization...")

-- Jalankan auto-populate setelah GUI selesai dibuat
task.spawn(function()
    task.wait(1) -- Tunggu GUI fully loaded
    
    print("[GUI] Triggering auto-populate for all registered dropdowns...")
    FeatureManager:PopulateAllDropdowns()
    
    -- Populate ulang setelah delay lebih lama untuk network timing
    task.wait(3)
    print("[GUI] Second wave auto-populate...")
    FeatureManager:PopulateAllDropdowns()
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