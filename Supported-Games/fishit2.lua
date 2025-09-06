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
    AutoFish        = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autofish.lua",
    AutoSellFish    = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autosellfish.lua", 
    AutoTeleportIsland = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autoteleportisland.lua" 
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

WindUI:SetFont("rbxasset://12187366657")

-- CUSTOM ICON INTEGRATION - Disable default open button
Window:EditOpenButton({ Enabled = false })

-- Services for custom icon
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Create custom icon
local iconGui = Instance.new("ScreenGui")
iconGui.Name = "DevLogicIconGui"
iconGui.Parent = PlayerGui

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

-- Monitor WindUI visibility
local lastVisible = nil
RunService.Heartbeat:Connect(function()
    if windowDestroyed or not iconButton then return end
    
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

-- Override Window methods with safety checks
if Window.Toggle then
    local originalToggle = Window.Toggle
    Window.Toggle = function(self)
        local result = originalToggle(self)
        if not windowDestroyed and iconButton and iconButton.Parent then
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
        if not windowDestroyed and iconButton and iconButton.Parent then
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
        if not windowDestroyed and iconButton and iconButton.Parent then
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
    "[+] Auto Fishing (Still have bug)",
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
    Title = ".devlogic",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local AboutUs = TabHome:Paragraph({
    Title = "About Us",
    Desc = "This script still under development, please report any bugs or issues in our discord server.",
    Color = "Red",
    ImageSize = 30,})

local DiscordBtn = TabHome:Button({
    Title = ".devlogic Discord",
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
  Value  = "Legendary",
  Callback = function(option)
    currentSellThreshold = option
    if sellfishFeature and sellfishFeature.SetMode then
      sellfishFeature:SetMode(option)
    end
  end
})

local sellfish_in = TabBackpack:Input({
  Title       = "Sell Limit",
  Placeholder = "e.g. 3",
  Value       = "",
  Numeric     = true,
  Callback    = function(value)
    local n = tonumber(value) or 0
    currentSellLimit = n
    if sellfishFeature and sellfishFeature.SetLimit then
      sellfishFeature:SetLimit(n)
    end
  end
})

local sellfish_tgl = TabBackpack:Toggle({
  Title    = "Auto Sell",
  Desc     = "Auto Sell when reach limit",
  Default  = false,
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
--- Item
local shoprod_sec = TabShop:Section({ 
    Title = "Rod & Item",
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

local shopitem_sec = TabShop:Section({ 
    Title = "Rod & Item",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local shopitem_ddm = TabShop:Dropdown({
    Title = "Select Item",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopitem_in = TabShop:Input({
    Title = "Quantity",
    Desc = "Item Quantity",
    Value = "",
    Placeholder = "Enter quantity",
    Type = "Input", 
    Callback = function(input) 
        print("delay entered: " .. input)
    end
})

local shopitem_btn = TabShop:Button({
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

local shopweather_ddm = TabShop:Dropdown({
    Title = "Select Weather",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopweather_tgl = TabShop:Toggle({
    Title = "Auto Buy Weather",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- === Teleport === ---
local teleisland_sec = TabTeleport:Section({ 
    Title = "Islands",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

-- Variable untuk menyimpan current island selection
local currentTeleportIsland = "Fisherman Island"

local teleisland_dd = TabTeleport:Dropdown({
    Title = "Select Island",
    Values = { "Fisherman Island", "Kohana", "Kohana Volcano", "Coral Reefs", "Esoteric Depths", "Tropical Grove", "Crater Island", "Lost Isle" },
    Value = "Fisherman Island",
    Callback = function(option) 
        currentTeleportIsland = option
        print("[GUI] Island selected: " .. option) 
    end
})

local teleisland_btn = TabTeleport:Button({
    Title = "Teleport To Island",
    Desc = "",
    Locked = false,
    Callback = function()
        print("[GUI] Teleport button clicked for island:", currentTeleportIsland)
        
        -- Ambil instance feature yang sudah dimuat atau muat baru
        local tpFeature = FeatureManager:GetFeature("AutoTeleportIsland")
        
        -- Jika belum ada, muat fitur dengan kontrol yang diperlukan
        if not tpFeature then
            tpFeature = FeatureManager:LoadFeature("AutoTeleportIsland", {
                dropdown = teleisland_dd,
                button   = teleisland_btn,
            })
        end
        
        -- Gunakan modul untuk set nama pulau dan teleport
        if tpFeature then
            if tpFeature.SetIsland then 
                tpFeature:SetIsland(currentTeleportIsland) 
            end
            if tpFeature.Teleport then 
                tpFeature:Teleport() 
            end
        else
            WindUI:Notify({
                Title = "Failed",
                Content = "Could not load AutoTeleportIsland",
                Icon = "x",
                Duration = 3
            })
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

local webhookfish_in = TabMisc:Input({
    Title = "Webhook URL",
    Desc = "Input Webhook URL",
    Value = "",
    Placeholder = "discord.gg//",
    Type = "Input", 
    Callback = function(input) 
        print("delay entered: " .. input)
    end
})

local webhookfish_dd = TabMisc:Dropdown({
    Title = "Select Fish",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local webhookfish_tgl = TabMisc:Toggle({
    Title = "Webhook",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--========== LIFECYCLE WITH INTEGRATED CLEANUP ==========
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