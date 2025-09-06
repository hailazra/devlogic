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
-- FEATURE MANAGER
-- ===========================
local FeatureManager = {}
FeatureManager.LoadedFeatures = {}

local FEATURE_URLS = {
    AutoFish           = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autofish.lua", 
    AutoSellFish       = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autosellfish.lua",
    AutoTeleportIsland = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autoteleportisland.lua",
    FishWebhook        = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/fishwebhook.lua",
    AutoBuyWeather     = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autobuyweather.lua",
    AutoBuyBait        = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autobuybait.lua"
}

function FeatureManager:LoadFeature(featureName, controls)
    local url = FEATURE_URLS[featureName]
    if not url then 
        WindUI:Notify({
            Title = "Error",
            Content = "Feature " .. featureName .. " URL not found",
            Icon = "x",
            Duration = 3
        })
        return nil 
    end

      local success, feature = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)

    if success and type(feature) == "table" and feature.Init then
        local initSuccess = pcall(feature.Init, feature, controls)
        if initSuccess then
            self.LoadedFeatures[featureName] = feature
            WindUI:Notify({
                Title = "Success",
                Content = featureName .. " loaded successfully",
                Icon = "check",
                Duration = 2
            })
            return feature
        end
    end
    
    WindUI:Notify({
        Title = "Load Failed",
        Content = "Could not load " .. featureName,
        Icon = "x",
        Duration = 3
    })
    return nil
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

-- CUSTOM ICON INTEGRATION - Disable default open button
Window:EditOpenButton({ Enabled = false })

-- Services for custom icon
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Root UI yang lebih tahan reset (prioritas: gethui/CoreGui; fallback ke PlayerGui)
local function getUiRoot()
    return (gethui and gethui()) or game:GetService("CoreGui") or PlayerGui
end

-- Reuse kalau sudah ada (hindari duplikasi saat re-exec)
local iconGui = getUiRoot():FindFirstChild("DevLogicIconGui") or Instance.new("ScreenGui")
iconGui.Name = "DevLogicIconGui"
iconGui.IgnoreGuiInset = true
iconGui.ResetOnSpawn = false   -- <- kunci: jangan hilang saat respawn

-- (Opsional) proteksi GUI (beberapa executor support)
pcall(function() if syn and syn.protect_gui then syn.protect_gui(iconGui) end end)

iconGui.Parent = getUiRoot()


local iconButton = Instance.new("ImageButton")
iconButton.Name = "DevLogicOpenButton"
iconButton.Size = UDim2.fromOffset(40, 40)
iconButton.Position = UDim2.new(0, 10, 0.5, -20)
iconButton.BackgroundTransparency = 1
iconButton.Image = "rbxassetid://73063950477508"
iconButton.Parent = iconGui
iconButton.Visible = false -- Start hidden because window is open

-- Variable untuk track status
local isWindowOpen = true
local windowDestroyed = false

-- Cleanup function untuk icon
local function cleanupIcon()
    print("[GUI] Cleaning up custom icon...")
    windowDestroyed = true
    
    if iconButton then
        iconButton:Destroy()
        iconButton = nil
    end
    
    if iconGui then
        iconGui:Destroy()
        iconGui = nil
    end
    
    print("[GUI] Icon cleanup completed")
end

-- Make cleanup globally available
_G.DevLogicIconCleanup = cleanupIcon

-- Fungsi toggle window
local function toggleWindow()
    if windowDestroyed then
        print("Window already destroyed, cannot toggle")
        return
    end
    
    print("Toggling window...") -- Debug
    
    if isWindowOpen then
        local success = pcall(function() Window:Close() end)
        if success then
            iconButton.Visible = true
            isWindowOpen = false
            print("Window closed, icon shown")
        else
            print("Failed to close window")
        end
    else
        local success = pcall(function() Window:Open() end)
        if success then
            iconButton.Visible = false
            isWindowOpen = true
            print("Window opened, icon hidden")
        else
            print("Failed to open window")
        end
    end
end

-- IMPROVED DRAG SYSTEM
local function makeDraggable(gui)
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    local dragDistance = 0
    local hasDraggedFar = false
    local dragStartTime = 0
    
    -- Konstanta untuk kontrol drag
    local MIN_DRAG_DISTANCE = 8     
    local TOGGLE_MAX_DISTANCE = 5   
    local TOGGLE_MAX_TIME = 0.5     

    local function updateInput(input)
        if not isDragging or not dragStart then return end
        
        local Delta = input.Position - dragStart
        dragDistance = math.sqrt(Delta.X^2 + Delta.Y^2)
        
        if dragDistance > MIN_DRAG_DISTANCE then
            hasDraggedFar = true
        end
        
        if hasDraggedFar then
            local Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + Delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + Delta.Y
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
            
            if inputChangedConnection then
                inputChangedConnection:Disconnect()
            end
            if inputEndedConnection then
                inputEndedConnection:Disconnect()
            end
            
            inputEndedConnection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    local dragEndTime = tick()
                    local dragDuration = dragEndTime - dragStartTime
                    
                    isDragging = false
                    
                    local isClick = (dragDistance < TOGGLE_MAX_DISTANCE) and 
                                  (dragDuration < TOGGLE_MAX_TIME) and 
                                  (not hasDraggedFar)
                    
                    if isClick then
                        print("Detected CLICK - Toggling window")
                        wait(0.1)
                        toggleWindow()
                    else
                        print("Detected DRAG - No toggle")
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
            if isDragging then
                updateInput(input)
            end
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

-- Apply drag system ke icon
makeDraggable(iconButton)

-- Monitor WindUI visibility
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

-- Override Window methods
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

-- END CUSTOM ICON INTEGRATION

Window:Tag({
    Title = "v0.0.0",
    Color = Color3.fromHex("#000000")
})

Window:Tag({
    Title = "Dev Version",
    Color = Color3.fromHex("#000000")
})

-- === Topbar Changelog (simple) ===
local CHANGELOG = table.concat({
    "[+] Auto Fishing",
    "[+] Auto Teleport Island",
    "[+] Auto Buy Weather",
    "[+] Auto Sell Fish",
    "[+] Webhook",
}, "\n")
local DISCORD = table.concat({
    "https://discord.gg/3AzvRJFT3M",
}, "\n")
    
local function ShowChangelog()
    Window:Dialog({
        Title   = "Changelog",
        Content = CHANGELOG,
        Buttons = {
            {
                Title   = "Discord",
                Icon    = "copy",
                Variant = "Secondary",
                Callback = function()
                    if typeof(setclipboard) == "function" then
                        setclipboard(DISCORD)
                        WindUI:Notify({ Title = "Copied", Content = "Changelog copied", Icon = "check", Duration = 2 })
                    else
                        WindUI:Notify({ Title = "Info", Content = "Clipboard not available", Icon = "info", Duration = 3 })
                    end
                end
            },
            { Title = "Close", Variant = "Primary" }
        }
    })
end

-- name, icon, callback, order
Window:CreateTopbarButton("changelog", "newspaper", ShowChangelog, 995)

--========== TABS ==========
local TabHome     = Window:Tab({ Title = "Home",     Icon = "house" })
local TabMain     = Window:Tab({ Title = "Main",     Icon = "gamepad" })
local TabBackpack = Window:Tab({ Title = "Backpack", Icon = "backpack" })
local TabShop     = Window:Tab({ Title = "Shop",     Icon = "shopping-bag" })
local TabTeleport = Window:Tab({ Title = "Teleport", Icon = "map" })
local TabMisc     = Window:Tab({ Title = "Misc",     Icon = "cog" })

--- === Home === ---
local DLsec = TabHome:Section({ 
    Title = "Information",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local AboutUs = TabHome:Paragraph({
    Title = ".devlogic",
    Desc = "If you found bugs or have suggestion, let us know.",
    Color = "White",
    ImageSize = 30,})

local DiscordBtn = TabHome:Button({
    Title = "Discord",
    Icon  = "message-circle",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/3AzvRJFT3M") -- ganti invite kamu
        end
    end
})

--- === Main === ---
--- Auto Fish
local autofish_sec = TabMain:Section({ 
    Title = "Fishing",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local autoFishFeature = nil
local currentFishingMode = "Perfect"

local autofishmode_dd = TabMain:Dropdown({
    Title = "Fishing Mode",
    Values = { "Perfect", "OK", "Mid" },
    Value = "Perfect",
    Callback = function(option) 
        currentFishingMode = option
        print("[GUI] Fishing mode changed to:", option)
        
        -- Update mode if feature is loaded
        if autoFishFeature and autoFishFeature.SetMode then
            autoFishFeature:SetMode(option)
        end
    end
})
    
local autofish_tgl = TabMain:Toggle({
    Title = "Auto Fishing",
    Desc = "Automatically fishing with selected mode",
    Default = false,
    Callback = function(state) 
        print("[GUI] AutoFish toggle:", state)
        
        if state then
            -- Load feature if not already loaded
            if not autoFishFeature then
                autoFishFeature = FeatureManager:LoadFeature("AutoFish", {
                    modeDropdown = autofishmode_dd,
                    toggle = autofish_tgl
                })
            end
            
            -- Start fishing if feature loaded successfully
            if autoFishFeature and autoFishFeature.Start then
                autoFishFeature:Start({ mode = currentFishingMode })
            else
                -- Reset toggle if failed to load
                WindUI:Notify({
                    Title = "Failed",
                    Content = "Could not start AutoFish",
                    Icon = "x",
                    Duration = 3
                })
            end
        else
            -- Stop fishing
            if autoFishFeature and autoFishFeature.Stop then
                autoFishFeature:Stop()
            end
        end
    end
})

--- Event Teleport
local eventtele_sec = TabMain:Section({ 
    Title = "Event Teleport",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local eventtele_ddm = TabMain:Dropdown({
    Title = "Select Event",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local eventtele_tgl = TabMain:Toggle({
    Title = "Auto Event Teleport",
    Desc  = "Auto Teleport to Event when available",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- === Backpack === ---
--- Favorite Fish
local favfish_sec = TabBackpack:Section({ 
    Title = "Favorite Fish",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local favfish_ddm = TabBackpack:Dropdown({
    Title = "Select Fish",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local favfish_tgl = TabBackpack:Toggle({
    Title = "Auto Favorite Fish",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Sell Fish
local sellfish_sec = TabBackpack:Section({ 
    Title = "Sell Fish",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local sellfishFeature        = nil
local currentSellThreshold   = "Legendary"
local currentSellLimit       = 0

local sellfish_dd = TabBackpack:Dropdown({
    Title = "Select Rarity",
    Values = { "Secret", "Mythic", "Legendary" },
    Value = "Legendary",
    Callback = function(option)
    currentSellThreshold = option
    if sellfishFeature and sellfishFeature.SetMode then
      sellfishFeature:SetMode(option)
    end
  end
})

local sellfish_in = TabBackpack:Input({
    Title = "Sell Delay",
    Placeholder = "e.g 60 (second)",
    Desc = "Input delay in seconds.",
    Value = "60",
    Numeric = true,
    Callback    = function(value)
    local n = tonumber(value) or 0
    currentSellLimit = n
    if sellfishFeature and sellfishFeature.SetLimit then
      sellfishFeature:SetLimit(n)
    end
  end
})

local sellfish_tgl = TabBackpack:Toggle({
    Title = "Auto Sell",
    Desc = "",
    Default = false,
    Callback = function(state)
    if state then
      if not sellfishFeature then
        sellfishFeature = FeatureManager:LoadFeature("AutoSellFish", {
          thresholdDropdown = sellfish_dd,
          limitInput        = sellfish_in,
          toggle            = sellfish_tgl,
        })
      end
      if sellfishFeature and sellfishFeature.Start then
        sellfishFeature:Start({
          threshold   = currentSellThreshold,
          limit       = currentSellLimit,
          autoOnLimit = true,
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

--- Gift Fish
local autogift_sec = TabBackpack:Section({ 
    Title = "Auto Gift",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local autogiftplayer_dd = TabBackpack:Dropdown({
    Title = "Select Player",
    Values = { "Category A", "Category B", "Category C" },
    Value = "Category A",
    Callback = function(option) 
        print("Category selected: " .. option) 
    end
})

local autogift_tgl = TabBackpack:Toggle({
    Title = "Auto Gift Fish",
    Desc  = "Auto Gift held Fish/Item",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- === Shop === --- 
--- Rod
local shoprod_sec = TabShop:Section({ 
    Title = "Rod",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local shoprod_ddm = TabShop:Dropdown({
    Title = "Select Rod",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shoprod_tgl = TabShop:Button({
    Title = "Buy Rod",
    Desc = "",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})

--- Baits
local shopbait_sec = TabShop:Section({ 
    Title = "Baits",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local buyBaitFeature          = nil
local selectedBuyBait            = {}

local BUYABLE_BAIT = {
    "Topwater Bait", "Luck Bait", "Midnight Bait", "Nature Bait", "Chroma Bait", "Dark Matter Bait", "Corrupt Bait", "Aether Bait"  
}

local BUYABLE_BAIT_OPTIONS = {}
for _, bait in ipairs(BUYABLE_BAIT) do
    table.insert(BUYABLE_BAIT_OPTIONS, bait)
end

local shopbait_ddm = TabShop:Dropdown({
    Title = "Select Bait",
    Values = BUYABLE_BAIT_OPTIONS,
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
    selectedBuyBait = {}
        for _, opt in ipairs(options) do
            if type(opt) == "string" and opt ~= "" then
                selectedBuyBait[opt] = true
            end
        end
        if buyBaitFeature and buyBaitFeature.SetBait then
            buyBaitFeature:SetBait(selectedBuyBait)
        end
    end
})


local shopbait_btn = TabShop:Button({
    Title = "Buy Bait",
    Desc = "",
    Locked = false,
    Callback = function()
  if not autobuybaitFeature then
    autobuybaitFeature = FeatureManager:LoadFeature("AutoBuyBait",{ 
        dropdown = shopbait_ddm, 
        button = shopbait_btn })
end
if autobuybaitFeature then
    autobuybaitFeature:SetSelectedBaitsByName(selectedBaitsSet)
    autobuybaitFeature:Start()  -- beli 1× per bait yang dipilih, langsung selesai
else
    shopbait_tgl:Set(false)
                WindUI:Notify({ Title="Failed", Content="Could not start AutoBuyBait", Icon="x", Duration=3 })
end
})

--- Other Item
local shopother_sec = TabShop:Section({ 
    Title = "Others",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local shopothers_ddm = TabShop:Dropdown({
    Title = "Select Item",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopother_btn = TabShop:Button({
    Title = "Buy Item",
    Desc = "",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})

--- Weather
local shopweather_sec = TabShop:Section({ 
    Title = "Weather",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local weatherFeature          = nil
local selectedWeatherSet      = {}  -- pakai set seperti pola webhook

local BUYABLE_WEATHER = {
    "Shark Hunt", "Wind", "Snow", "Radiant", "Storm", "Cloudy" 
}

local BUYABLE_WEATHER_OPTIONS = {}
for _, weather in ipairs(BUYABLE_WEATHER) do
    table.insert(BUYABLE_WEATHER_OPTIONS, weather)
end


-- Multi dropdown (Values diisi setelah modul diload)
local shopweather_ddm = TabShop:Dropdown({
    Title     = "Select Weather",
    Desc      = "",
    Values    = BUYABLE_WEATHER_OPTIONS,
    Value     = {},
    Multi     = true,
    AllowNone = true,
    Callback  = function(options)
        -- rebuild set
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

local shopweather_tgl = TabShop:Toggle({
    Title   = "Auto Buy Weather",
    Default = false,
    Callback = function(state)
        if state then
            if not weatherFeature then
                weatherFeature = FeatureManager:LoadFeature("AutoBuyWeather", {
                    weatherDropdownMulti = shopweather_ddm,
                    toggle               = shopweather_tgl,
                })
                if weatherFeature and weatherFeature.GetBuyableWeathers then
                    local names = weatherFeature:GetBuyableWeathers()
                    if shopweather_ddm.Reload then
                        shopweather_ddm:Reload(names)
                    elseif shopweather_ddm.SetOptions then
                        shopweather_ddm:SetOptions(names)
                    end
                    task.delay(1.5, function()
                        if weatherFeature and weatherFeature.GetBuyableWeathers then
                            local names2 = weatherFeature:GetBuyableWeathers()
                            if shopweather_ddm.Reload then
                                shopweather_ddm:Reload(names2)
                            elseif shopweather_ddm.SetOptions then
                                shopweather_ddm:SetOptions(names2)
                            end
                        end
                    end)
                end
            end

            if next(selectedWeatherSet) == nil then
                WindUI:Notify({ Title="Info", Content="Select atleast 1 Weather", Icon="info", Duration=3 })
                shopweather_tgl:Set(false)
                return
            end

            if weatherFeature and weatherFeature.Start then
                weatherFeature:Start({
                    weatherList = selectedWeatherSet, -- boleh set atau array
                    -- interDelay default 0.75s di modul; ga perlu input GUI
                })
            else
                shopweather_tgl:Set(false)
                WindUI:Notify({ Title="Failed", Content="Could not start AutoBuyWeather", Icon="x", Duration=3 })
            end
        else
            if weatherFeature and weatherFeature.Stop then weatherFeature:Stop() end
        end
    end
})


--- === Teleport === ---
local teleisland_sec = TabTeleport:Section({ 
    Title = "Islands",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local autoTeleIslandFeature = nil 
local currentIsland = "Fisherman Island" 

local teleisland_dd = TabTeleport:Dropdown({
     Title = "Select Island",
      Values = { "Fisherman Island", 
      "Esoteric Depths", 
      "Enchant Altar", 
      "Kohana", 
      "Kohana Volcano", 
      "Tropical Grove", 
      "Crater Island", 
      "Coral Reefs", 
      "Sisyphus Statue", 
      "Treasure Room" }, 
      Value = currentIsland, 
      Callback = function(option) 
        currentIsland = option 
         if autoTeleIslandFeature and autoTeleIslandFeature.SetIsland 
         then autoTeleIslandFeature:SetIsland(option) 
        end 
    end }) 

local teleisland_btn = TabTeleport:Button({
         Title = "Teleport To Island", 
         Desc = "", 
         Locked = false, 
         Callback = function() 
             if not autoTeleIslandFeature then 
                autoTeleIslandFeature = FeatureManager:LoadFeature("AutoTeleportIsland",
                 { dropdown = teleisland_dd, button = teleisland_btn }) 
           end 
             if autoTeleIslandFeature then 
                if autoTeleIslandFeature.SetIsland then 
                    autoTeleIslandFeature:SetIsland(currentIsland) 
            end 
               if autoTeleIslandFeature.Teleport then 
                    autoTeleIslandFeature:Teleport(currentIsland) end 
                else WindUI:Notify({ 
                    Title = "Error",
                     Content = "AutoTeleportIsland feature could not be loaded",
                      Icon = "x", Duration = 3 })
          end 
     end 
})

local teleplayer_sec = TabTeleport:Section({ 
    Title = "Players",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local teleplayer_dd = TabTeleport:Dropdown({
    Title = "Select Player",
    Values = { "Category A", "Category B", "Category C" },
    Value = "Category A",
    Callback = function(option) 
        print("Category selected: " .. option) 
    end
})

local teleplayer_btn = TabTeleport:Button({
    Title = "Teleport To Player",
    Desc = "",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})

--- === Misc === ---
--- Server
local servutils_sec = TabMisc:Section({ 
    Title = "Join Server",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local servjoin_in = TabMisc:Input({
    Title = "Job Id",
    Desc = "Input Server Job Id",
    Value = "",
    Placeholder = "000-000-000",
    Type = "Input", 
    Callback = function(input) 
        print("delay entered: " .. input)
    end
})

local servjoin_btn = TabMisc:Button({
    Title = "Join Server",
    Desc = "",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})

local servcopy_btn = TabMisc:Button({
    Title = "Copy Server ID",
    Desc = "Copy Current Server Job ID",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})

--- Server Hop
local servhop_sec = TabMisc:Section({ 
    Title = "Hop Server",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local servhop_dd = TabMisc:Dropdown({
    Title = "Select Server Luck",
    Values = { "Category A", "Category B", "Category C" },
    Value = "Category A",
    Callback = function(option) 
        print("Category selected: " .. option) 
    end
})

local servhop_tgl = TabMisc:Toggle({
    Title = "Auto Hop Server",
    Desc  = "Auto Hop until found desired Server",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})


--- Webhook
local webhookfish_sec = TabMisc:Section({ 
    Title = "Webhook",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

-- State variables untuk webhook
local fishWebhookFeature = nil
local currentWebhookUrl = ""
local selectedWebhookFishTypes = {}

-- Daftar tier ikan yang bisa dipilih
local FISH_TIERS = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"
}

-- Gabungkan opsi untuk dropdown
local WEBHOOK_FISH_OPTIONS = {}
for _, tier in ipairs(FISH_TIERS) do
    table.insert(WEBHOOK_FISH_OPTIONS, tier)
end

local webhookfish_in = TabMisc:Input({
    Title = "Discord Webhook URL",
    Desc = "Paste your Discord webhook URL here",
    Value = "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Type = "Input",
    Callback = function(input)
        currentWebhookUrl = input
        print("[Webhook] URL updated:", input:sub(1, 50) .. (input:len() > 50 and "..." or ""))
        
        -- Update webhook URL jika feature sudah dimuat
        if fishWebhookFeature and fishWebhookFeature.SetWebhookUrl then
            fishWebhookFeature:SetWebhookUrl(input)
        end
    end
})

local webhookfish_ddm = TabMisc:Dropdown({
    Title = "Select Rarity",
    Desc = "Choose which fish types/rarities to send to webhook",
    Values = WEBHOOK_FISH_OPTIONS,
    Value = {"Legendary", "Mythic", "Secret"}, -- Default selection
    Multi = true,
    AllowNone = true,
    Callback = function(options)
        selectedWebhookFishTypes = {}
        for _, option in ipairs(options) do
            selectedWebhookFishTypes[option] = true
        end
        
        print("[Webhook] Fish types selected:", HttpService:JSONEncode(options))
        
        -- Update selected fish types jika feature sudah dimuat
        if fishWebhookFeature and fishWebhookFeature.SetSelectedFishTypes then
            fishWebhookFeature:SetSelectedFishTypes(selectedWebhookFishTypes)
        end
    end
})


local webhookfish_tgl = TabMisc:Toggle({
    Title = "Enable Fish Webhook",
    Desc = "Automatically send notifications when catching selected fish types",
    Default = false,
    Callback = function(state)
        print("[Webhook] Toggle:", state)
        
        if state then
            -- Validasi input
            if currentWebhookUrl == "" then
                WindUI:Notify({
                    Title = "Error", 
                    Content = "Please enter webhook URL first",
                    Icon = "x",
                    Duration = 3
                })
                webhookfish_tgl:Set(false) -- Reset toggle
                return
            end
            
            if next(selectedWebhookFishTypes) == nil then
                WindUI:Notify({
                    Title = "Warning",
                    Content = "No fish types selected - will monitor all catches",
                    Icon = "alert-triangle",
                    Duration = 3
                })
            end
            
            -- Load feature jika belum dimuat
            if not fishWebhookFeature then
                fishWebhookFeature = FeatureManager:LoadFeature("FishWebhook", {
                    urlInput = webhookfish_in,
                    fishTypesDropdown = webhookfish_dd,
                    testButton = webhooktest_btn,
                    toggle = webhookfish_tgl
                })
            end
            
            -- Start webhook monitoring
            if fishWebhookFeature and fishWebhookFeature.Start then
                local success = fishWebhookFeature:Start({
                    webhookUrl = currentWebhookUrl,
                    selectedFishTypes = selectedWebhookFishTypes
                })
                
                if success then
                    WindUI:Notify({
                        Title = "Webhook Active",
                        Content = "Fish notifications enabled",
                        Icon = "check",
                        Duration = 2
                    })
                else
                    webhookfish_tgl:Set(false)
                    WindUI:Notify({
                        Title = "Start Failed",
                        Content = "Could not start webhook monitoring",
                        Icon = "x", 
                        Duration = 3
                    })
                end
            else
                webhookfish_tgl:Set(false)
                WindUI:Notify({
                    Title = "Load Failed",
                    Content = "Could not load webhook feature",
                    Icon = "x",
                    Duration = 3
                })
            end
        else
            -- Stop webhook monitoring
            if fishWebhookFeature and fishWebhookFeature.Stop then
                fishWebhookFeature:Stop()
                WindUI:Notify({
                    Title = "Webhook Stopped",
                    Content = "Fish notifications disabled",
                    Icon = "info",
                    Duration = 2
                })
            end
        end
    end
})

--========== LIFECYCLE (tanpa cleanup integrasi) ==========
if type(Window.OnClose) == "function" then
    Window:OnClose(function()
        print("[GUI] Window closed")
        -- Tidak ada cleanup integrasi fitur di sini
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
        
        -- Cleanup custom icon
        if _G.DevLogicIconCleanup then
            pcall(_G.DevLogicIconCleanup)
            _G.DevLogicIconCleanup = nil
        end
    end)
end



