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
local EnchantModule = ReplicatedStorage.Enchants
local BaitModule = ReplicatedStorage.Baits
local ItemsModule = ReplicatedStorage.Items
local WeatherModule = ReplicatedStorage.Events
local BoatModule = ReplicatedStorage.Boats
local TiersModule = ReplicatedStorage.Tiers

--- === HELPERS FOR DROPDOWN BY REAL DATA GAME === ---
--- Enchant
local function getEnchantName()
    local enchantName = {}
    for _, enchant in pairs(EnchantModule:GetChildren()) do
        if enchant:IsA("ModuleScript") then
            table.insert(enchantName, enchant.Name)
        end
    end
    return enchantName
end

--- Bait
local function getBaitNames()
    local baitName = {}
    for _, item in pairs(BaitModule:GetChildren()) do
        if item:IsA("ModuleScript") then
            local success, moduleData = pcall(function()
                return require(item)
            end)
            
            if success and moduleData then
                if moduleData.Data and moduleData.Data.Type == "Baits" then
                    if moduleData.Price then
                        table.insert(baitName, item.Name)
                    end
                end
            end
        end
    end
    
    return baitName
end

--- Rod
local function getFishingRodNames()
    local rodNames = {}
    for _, item in pairs(ItemsModule:GetChildren()) do
        if item:IsA("ModuleScript") then
            local success, moduleData = pcall(function()
                return require(item)
            end)
            
            if success and moduleData and moduleData.Data then
                -- Gabungin semua kondisi jadi 1 line
                if moduleData.Data.Type == "Fishing Rods" and moduleData.Price and moduleData.Data.Name then
                    table.insert(rodNames, moduleData.Data.Name)
                end
            end
        end
    end
    
    table.sort(rodNames)
    return rodNames
end

--- Weather (Buyable)
local function getWeatherNames()
    local weatherName = {}
    for _, weather in pairs(WeatherModule:GetChildren()) do
        if weather:IsA("ModuleScript") then
            local success, moduleData = pcall(function()
                return require(weather)
            end)
            
            if success and moduleData then 
                if moduleData.WeatherMachine == true and moduleData.WeatherMachinePrice then
                    table.insert(weatherName, weather.Name)
                end
            end
        end
    end
    
    table.sort(weatherName)
    return weatherName
end

--- Weather (Event)
local function getEventNames()
    local eventNames = {}
    for _, event in pairs(WeatherModule:GetChildren()) do
        if event:IsA("ModuleScript") then
            local success, moduleData = pcall(function()
                return require(event)
            end)
            
            if success and moduleData then
                if moduleData.Coordinates and moduleData.Name then
                    table.insert(eventNames, moduleData.Name)
                end
            end
        end
    end
    
    table.sort(eventNames)
    return eventNames
end

--- Tiers (Rarity)
-- Function untuk ambil semua tier names
local function getTierNames()
    local tierNames = {}
    -- Require the Tiers module
    local success, tiersData = pcall(function()
        return require(TiersModule)
    end)
    
    if success and tiersData then
        -- Loop through setiap tier data
        for _, tierInfo in pairs(tiersData) do
            if tierInfo.Name then
                table.insert(tierNames, tierInfo.Name)
            end
        end
    end
    
    return tierNames
end

--- Fish List 
local function getFishNames()
    local fishNames = {}
    
    for _, item in pairs(ItemsModule:GetChildren()) do
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
    return fishNames
end

--- Fish Name KHUSUS TRADE
local function getFishNamesForTrade()
    local fishNames = {}
    local itemsModule = ReplicatedStorage:FindFirstChild("Items")
    if not itemsModule then
        warn("[AutoSendTrade] Items module not found")
        return fishNames
    end
    
    for _, item in pairs(itemsModule:GetChildren()) do
        if item:IsA("ModuleScript") then
            local success, moduleData = pcall(function()
                return require(item)
            end)
            
            if success and moduleData then
                -- Check apakah Type = "Fishes"
                if moduleData.Data and moduleData.Data.Type == "Fishes" then
                    -- Ambil nama dari Data.Name (sama seperti di script autosendtrade)
                    if moduleData.Data.Name then
                        table.insert(fishNames, moduleData.Data.Name)
                    end
                end
            end
        end
    end
    
    table.sort(fishNames)
    return fishNames
end

local listRod       = getFishingRodNames()
local weatherName   = getWeatherNames()
local eventNames    = getEventNames()
local rarityName    = getTierNames()
local fishName      = getFishNames()

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

-- Load InventoryWatcher globally for features that need it
_G.InventoryWatcher = nil
pcall(function()
    _G.InventoryWatcher = loadstring(game:HttpGet("https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/inventdetectfishit.lua"))()
end)

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
    AutoBuyBait        = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autobuybait.lua",
    AutoBuyRod         = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autobuyrod.lua",
    AutoTeleportEvent  = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autoteleportevent.lua",
    AutoGearOxyRadar   = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autogearoxyradar.lua",
    AntiAfk            = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/antiafk.lua", 
    AutoEnchantRod     = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autoenchantrodv1.lua",
    AutoFavoriteFish   = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autofavoritefish.lua",
    AutoTeleportPlayer = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autoteleportplayer.lua",
    BoostFPS           = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/boostfps.lua",
    AutoSendTrade      = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autosendtrade.lua",
    AutoAcceptTrade    = "https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/Fish-It/autoaccepttrade.lua"
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
            print(featureName .. "Loaded Successfully!")
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

-- ===========================
-- PRELOAD ALL FEATURES
-- ===========================
local function preloadAllFeatures()
    print("[FeatureManager] Starting preload all features...")
    
    -- Urutan loading (critical features first)
    local loadOrder = {
        "AntiAfk",           -- Utility first
        "BoostFPS",
        "AutoFish",          -- Core features
        "AutoSellFish",
        "AutoTeleportIsland",
        "AutoTeleportPlayer",
        "AutoTeleportEvent",
        "AutoEnchantRod",
        "AutoFavoriteFish",
        "AutoSendTrade",
        "AutoAcceptTrade",
        "FishWebhook",       -- Notification features
        "AutoBuyWeather",    -- Shop features
        "AutoBuyBait",
        "AutoBuyRod",
        "AutoGearOxyRadar"   -- Advanced features
    }
    
    local loadedCount = 0
    local totalFeatures = #loadOrder
    
    for _, featureName in ipairs(loadOrder) do
        local success = pcall(function()
            local feature = FeatureManager:LoadFeature(featureName)
            if feature then
                loadedCount = loadedCount + 1
                print(string.format("[FeatureManager] ✓ %s loaded (%d/%d)", 
                    featureName, loadedCount, totalFeatures))
            else
                warn(string.format("[FeatureManager] ✗ Failed to load %s", featureName))
            end
        end)
        
        if not success then
            warn(string.format("[FeatureManager] ✗ Error loading %s", featureName))
        end
        
        -- Small delay untuk prevent overwhelming
        task.wait(0.1)
    end
    
    print(string.format("[FeatureManager] Preloading completed: %d/%d features loaded", 
        loadedCount, totalFeatures))
    
    -- Optional: Show completion notification
    WindUI:Notify({
        Title = "Ready",
        Content = string.format("%d features loaded", loadedCount),
        Icon = "check",
        Duration = 2
    })
end

-- Execute preloading immediately
task.spawn(preloadAllFeatures)

WindUI:AddTheme({
    Name        = "StarlessMonoPro",
    Accent      = "#DDE3F0", -- starlight lembut (bukan putih murni)
    Dialog      = "#13151A", -- panel
    Outline     = "#303845", -- border dingin (bukan putih)
    Text        = "#E9ECF2", -- teks nyaman
    Placeholder = "#999999", -- hint
    Background  = "#0A0B0D", -- hampir hitam
    Button      = "#1E232C", -- tombol idle
    Icon        = "#a1a1aa", -- ikon sedikit lebih terang
})

--========== WINDOW ==========
local Window = WindUI:CreateWindow({
    Title         = "Noctris",
    Icon          = "rbxassetid://123156553209294",
    Author        = "Fish It",
    Folder        = "NoctrisHub",
    Size          = UDim2.fromOffset(250, 250),
    Transparent   = true,
    Theme         = "Dark",
    Resizable     = false,
    SideBarWidth  = 150,
    HideSearchBar = true,
})

WindUI:SetFont("rbxasset://12187373592")

WindUI.TransparencyValue = 0.1  -- 0 = solid, 1 = full tembus
Window:ToggleTransparency(true)

-- =========================
-- IMPROVED ICON CONTROLLER (Cobalt-inspired)
-- =========================
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Helper functions
local function getUiRoot()
    return (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
end

local function clampToScreen(guiObj)
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local pos = guiObj.Position
    local sizePx = guiObj.AbsoluteSize
    
    local xOff = math.clamp(pos.X.Offset, 0, math.max(0, vp.X - sizePx.X))
    local yOff = math.clamp(pos.Y.Offset, 36, math.max(36, vp.Y - sizePx.Y))
    guiObj.Position = UDim2.new(0, xOff, 0, yOff)
end

local function edgeSnap(guiObj, snapPx)
    snapPx = snapPx or 15
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local pos = guiObj.Position
    local sizePx = guiObj.AbsoluteSize
    
    local leftDist = pos.X.Offset
    local rightDist = (vp.X - sizePx.X) - pos.X.Offset
    local topDist = pos.Y.Offset - 36
    local botDist = (vp.Y - sizePx.Y) - pos.Y.Offset
    
    local snapped = false
    
    if leftDist <= snapPx then
        guiObj.Position = UDim2.new(0, 0, 0, pos.Y.Offset)
        snapped = true
    elseif rightDist <= snapPx then
        guiObj.Position = UDim2.new(0, vp.X - sizePx.X, 0, pos.Y.Offset)
        snapped = true
    end
    
    if topDist <= snapPx then
        guiObj.Position = UDim2.new(guiObj.Position.X.Scale, guiObj.Position.X.Offset, 0, 36)
        snapped = true
    elseif botDist <= snapPx then
        guiObj.Position = UDim2.new(guiObj.Position.X.Scale, guiObj.Position.X.Offset, 0, vp.Y - sizePx.Y)
        snapped = true
    end
    
    return snapped
end

-- Improved IconController
local IconController = {}
IconController.__index = IconController

function IconController.new(Window, opts)
    local self = setmetatable({}, IconController)
    self.Window = Window
    self.Root = getUiRoot()
    
    -- Enhanced state tracking
    self.State = {
        windowOpen = true,
        dragging = false,
        startPos = nil,
        startFramePos = nil,
        totalDistance = 0,
        startTime = 0,
        dragConnection = nil,
        endConnection = nil,
    }
    
    self.Config = {
        image = (opts and opts.image) or "rbxassetid://73063950477508",
        size = (opts and opts.size) or Vector2.new(44, 44),
        startPos = (opts and opts.startPos) or UDim2.new(0, 10, 0.5, -22),
        clickThreshold = 4, -- distance
        clickTimeLimit = 0.2, -- time click
        snapDistance = 15,
        
        -- Animation configs
        showTween = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        hideTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
    }
    
    -- Create ScreenGui
    local screenGui = self.Root:FindFirstChild("DevLogicIconGui")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DevLogicIconGui"
        screenGui.IgnoreGuiInset = true
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        
        -- Protect GUI if possible
        pcall(function()
            if syn and syn.protect_gui then syn.protect_gui(screenGui) end
        end)
        
        screenGui.Parent = self.Root
    end
    self.ScreenGui = screenGui
    
    -- Create Icon Button
    self.IconButton = Instance.new("ImageButton")
    self.IconButton.Name = "DevLogicIcon"
    self.IconButton.BackgroundTransparency = 1
    self.IconButton.Image = self.Config.image
    self.IconButton.Size = UDim2.fromOffset(self.Config.size.X, self.Config.size.Y)
    self.IconButton.ZIndex = 100
    self.IconButton.Active = true
    
    -- Restore saved position or use default
    local savedPos = rawget(_G, "DevLogicIconPos")
    self.IconButton.Position = (typeof(savedPos) == "UDim2") and savedPos or self.Config.startPos
    
    -- Add corner radius for polish
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.IconButton
    
    self.IconButton.Parent = screenGui
    
    -- Hook window methods and setup drag
    self:HookWindow()
    self:SetupDrag()
    
    -- Initial state: hide icon if window is open
    if self.State.windowOpen then
        self.IconButton.Visible = false
    end
    
    clampToScreen(self.IconButton)
    
    return self
end

function IconController:SetupDrag()
    local State = self.State
    local Config = self.Config
    
    -- Main input handler
    self.IconButton.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and 
           input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        
        -- Start drag state
        State.dragging = true
        State.startPos = input.Position
        State.startFramePos = self.IconButton.Position
        State.totalDistance = 0
        State.startTime = tick()
        
        -- Clean up old connections
        if State.endConnection then
            State.endConnection:Disconnect()
        end
        
        -- Handle input end
        State.endConnection = input.Changed:Connect(function()
            if input.UserInputState ~= Enum.UserInputState.End then
                return
            end
            
            self:EndDrag()
        end)
    end)
    
    -- Global input movement handler (Cobalt style)
    if State.dragConnection then
        State.dragConnection:Disconnect()
    end
    
    State.dragConnection = UserInputService.InputChanged:Connect(function(input)
        if not State.dragging then return end
        
        local isMoveInput = (input.UserInputType == Enum.UserInputType.MouseMovement) or 
                           (input.UserInputType == Enum.UserInputType.Touch)
        
        if not isMoveInput then return end
        
        self:UpdateDrag(input)
    end)
end

function IconController:UpdateDrag(input)
    local State = self.State
    local delta = input.Position - State.startPos
    State.totalDistance = math.max(State.totalDistance, delta.Magnitude)
    
    -- Only move if we've exceeded click threshold (prevents false clicks)
    if State.totalDistance > self.Config.clickThreshold then
        self.IconButton.Position = UDim2.new(
            State.startFramePos.X.Scale,
            State.startFramePos.X.Offset + delta.X,
            State.startFramePos.Y.Scale,
            State.startFramePos.Y.Offset + delta.Y
        )
    end
end

function IconController:EndDrag()
    local State = self.State
    local Config = self.Config
    
    if not State.dragging then return end
    
    State.dragging = false
    
    -- Clean up connections
    if State.endConnection then
        State.endConnection:Disconnect()
        State.endConnection = nil
    end
    
    -- Determine if this was a click or drag
    local totalTime = tick() - State.startTime
    local isClick = (State.totalDistance <= Config.clickThreshold) and (totalTime <= Config.clickTimeLimit)
    
    if isClick then
        -- Handle click - restore window
        self:RestoreWindow()
    else
        -- Handle drag end - snap to edges and save position
        clampToScreen(self.IconButton)
        local snapped = edgeSnap(self.IconButton, Config.snapDistance)
        
        -- Save position
        _G.DevLogicIconPos = self.IconButton.Position
        
        -- Optional snap feedback
        if snapped then
            local snapTween = TweenService:Create(self.IconButton, 
                TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = UDim2.fromOffset(Config.size.X + 4, Config.size.Y + 4)}
            )
            snapTween:Play()
            snapTween.Completed:Connect(function()
                TweenService:Create(self.IconButton,
                    TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Size = UDim2.fromOffset(Config.size.X, Config.size.Y)}
                ):Play()
            end)
        end
    end
end

function IconController:RestoreWindow()
    if not self.Window then return end
    
    self.State.windowOpen = true
    
    -- Animate icon disappearing
    self.IconButton.Active = false
    local hideTween = TweenService:Create(self.IconButton, self.Config.hideTween, {
        ImageTransparency = 1,
        Size = UDim2.fromOffset(self.Config.size.X * 0.8, self.Config.size.Y * 0.8)
    })
    
    hideTween:Play()
    hideTween.Completed:Connect(function()
        self.IconButton.Visible = false
        self.IconButton.ImageTransparency = 0
        self.IconButton.Size = UDim2.fromOffset(self.Config.size.X, self.Config.size.Y)
        self.IconButton.Active = true
    end)
    
    -- Restore window
    if self.Window.Open then
        pcall(function() self.Window:Open() end)
    end
end

function IconController:MinimizeToIcon()
    if not self.IconButton then return end
    
    self.State.windowOpen = false
    
    -- Show and animate icon appearing
    self.IconButton.Visible = true
    self.IconButton.ImageTransparency = 1
    self.IconButton.Size = UDim2.fromOffset(self.Config.size.X * 1.2, self.Config.size.Y * 1.2)
    
    local showTween = TweenService:Create(self.IconButton, self.Config.showTween, {
        ImageTransparency = 0,
        Size = UDim2.fromOffset(self.Config.size.X, self.Config.size.Y)
    })
    showTween:Play()
    
    -- Ensure it's positioned correctly
    clampToScreen(self.IconButton)
end

function IconController:HookWindow()
    local Window = self.Window
    if not Window then return end
    
    -- Hook Close method
    if Window.Close and not self._hookedClose then
        local originalClose = Window.Close
        self._hookedClose = true
        
        Window.Close = function(w, ...)
            local result = originalClose(w, ...)
            self:MinimizeToIcon()
            return result
        end
    end
    
    -- Hook Open method  
    if Window.Open and not self._hookedOpen then
        local originalOpen = Window.Open
        self._hookedOpen = true
        
        Window.Open = function(w, ...)
            local result = originalOpen(w, ...)
            if self.IconButton then
                self.IconButton.Visible = false
            end
            self.State.windowOpen = true
            return result
        end
    end
    
    -- Hook Toggle method
    if Window.Toggle and not self._hookedToggle then
        local originalToggle = Window.Toggle
        self._hookedToggle = true
        
        Window.Toggle = function(w, ...)
            local result = originalToggle(w, ...)
            -- Determine new state and act accordingly
            task.wait(0.1) -- Small delay to let toggle complete
            
            if self.State.windowOpen then
                self:MinimizeToIcon()
            else
                self:RestoreWindow()
            end
            return result
        end
    end
    
    -- Hook destroy if available
    if Window.OnDestroy and typeof(Window.OnDestroy) == "function" then
        Window:OnDestroy(function()
            self:Destroy()
        end)
    end
end

function IconController:Destroy()
    -- Clean up connections
    if self.State.dragConnection then
        self.State.dragConnection:Disconnect()
    end
    if self.State.endConnection then
        self.State.endConnection:Disconnect()
    end
    
    -- Clean up GUI
    if self.IconButton and self.IconButton.Parent then
        self.IconButton:Destroy()
    end
    
    if self.ScreenGui and self.ScreenGui.Parent and #self.ScreenGui:GetChildren() == 0 then
        self.ScreenGui:Destroy()
    end
    
    -- Clear state
    self.State.dragConnection = nil
    self.State.endConnection = nil
end
-- Disable WindUI default open button
Window:EditOpenButton({ Enabled = false })

-- Create improved icon controller
local DevLogicIcon = IconController.new(Window, {
    image = "rbxassetid://123156553209294",
    size = Vector2.new(44, 44),
    startPos = UDim2.new(0, 10, 0.5, -22),
})

-- Store cleanup function globally for the old system
_G.DevLogicIconCleanup = function()
    if DevLogicIcon then
        print("[IconController] Cleaning up via global cleanup")
        DevLogicIcon:Destroy()
        DevLogicIcon = nil
    end
end

-- Optional: Start minimized
-- DevLogicIcon:MinimizeToIcon()

-- =========================
-- END CUSTOM ICON INTEGRATION v2
-- =========================

Window:Tag({
    Title = "v0.0.5",
    Color = Color3.fromHex("#000000")
})

Window:Tag({
    Title = "Dev Version",
    Color = Color3.fromHex("#000000")
})

--- === CHANGELOG & DISCORD LINK === ---
local CHANGELOG = table.concat({
    "[+] Added Teleport to Player",
    "[+] Added Boost FPS",
    "If you find bugs or have suggestions, let us know."
}, "\n")
local DISCORD = table.concat({
    "https://discord.gg/3AzvRJFT3M",
}, "\n")
    
--========== TABS ==========
local TabHome            = Window:Tab({ Title = "Home",           Icon = "house" })
local TabMain            = Window:Tab({ Title = "Main",           Icon = "gamepad" })
local TabBackpack        = Window:Tab({ Title = "Backpack",       Icon = "backpack" })
local TabAutomation      = Window:Tab({ Title = "Automation",     Icon = "workflow" })
local TabShop            = Window:Tab({ Title = "Shop",           Icon = "shopping-bag" })
local TabTeleport        = Window:Tab({ Title = "Teleport",       Icon = "map" })
local TabMisc            = Window:Tab({ Title = "Misc",           Icon = "cog" })

--- === Home === ---
local info_sec = TabHome:Section({ 
    Title = "Information",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = true
})

local info_para = TabHome:Paragraph({
    Title = "Changelog",
    Desc = CHANGELOG,
    Locked = false,
    Buttons = {
        {
            Icon = "copy",
            Title = "Discord",
            Callback = function() 
            if typeof(setclipboard) == "function" then
                        setclipboard(DISCORD)
                        WindUI:Notify({ Title = "Copied", Content = "Disord link copied!", Icon = "check", Duration = 2 })
                    else
                        WindUI:Notify({ Title = "Info", Content = "Clipboard not available", Icon = "info", Duration = 3 })
                    end
                end
        }
    }
})

--- === Main === ---
--- Auto Fish
local autofish_sec = TabMain:Section({ 
    Title = "Fishing",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local autoFishFeature = nil
local currentFishingMode = "Fast"

local autofishmode_dd = autofish_sec:Dropdown({
    Title = "Fishing Mode",
    Desc  = "Select Fishing Mode",
    Values = { "Fast", "Slow" },
    Value = "Fast",
    Callback = function(option) 
        currentFishingMode = option
        print("[GUI] Fishing mode changed to:", option)
        
        -- Update mode if feature is loaded
        if autoFishFeature and autoFishFeature.SetMode then
            autoFishFeature:SetMode(option)
        end
    end
})
    
local autofish_tgl = autofish_sec:Toggle({
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

--- Cancel Fishing/Fix Stuck
local CancelFishingEvent = game:GetService("ReplicatedStorage")
    .Packages._Index["sleitnick_net@0.2.0"]
    .net["RF/CancelFishingInputs"]

local cancelautofish_btn = autofish_sec:Button({
    Title = "Cancel Fishing",
    Desc = "Fix Stuck when Fishing",
    Locked = false,
    Callback = function()
        if CancelFishingEvent and CancelFishingEvent.InvokeServer then
            local success, result = pcall(function()
                return CancelFishingEvent:InvokeServer()
            end)

            if success then
                print("[CancelFishingInputs] Fixed", result)
            else
                warn("[CancelFishingInputs] Error, Report to Dev", result)
            end
        else
            warn("[CancelFishingInputs] Report this bug to Dev")
        end
    end
})


--- Event Teleport
local eventtele_sec = TabMain:Section({ 
    Title = "Event Teleport",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local eventteleFeature     = nil
local selectedEventsArray = {}

local eventtele_ddm = eventtele_sec:Dropdown({
    Title = "Select Event",
    Desc  = "Will priotitize selected Event",
    Values = eventNames,
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback  = function(options)
        selectedEventsArray = options or {}
        if eventteleFeature and eventteleFeature.SetSelectedEvents then
            eventteleFeature:SetSelectedEvents(selectedEventsArray) -- <<< array, bukan set
        end
    end
})

local eventtele_tgl = eventtele_sec:Toggle({
    Title = "Auto Event Teleport",
    Desc  = "Auto Teleport to Event when available",
    Default = false,
    Callback = function(state) 
     if state then
            if not eventteleFeature then
                eventteleFeature = FeatureManager:LoadFeature("AutoTeleportEvent", {
                    dropdown = eventtele_ddm,
                    toggle   = eventtele_tgl
                })
            end
            if eventteleFeature and eventteleFeature.Start then
                eventteleFeature:Start({
                    selectedEvents = selectedEventsArray,  -- <<< array prioritas
                    hoverHeight    = 12                   -- feel free adjust
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

--- === Backpack === ---
--- Favorite Fish
local favfish_sec = TabBackpack:Section({ 
    Title = "Favorite Fish",
    TextXAlignment = "Left",
    TextSize = 17,
})

local autoFavFishFeature = nil
local selectedTiers = {}

-- Dropdown: start dengan tier default, akan di-reload saat feature dimuat
local favfish_ddm = favfish_sec:Dropdown({
    Title     = "Select Rarity",
    Values    = rarityName, -- default fallback
    Value     = {},
    Multi     = true,
    AllowNone = true,
    Callback  = function(options)
        selectedTiers = options or {}
        if autoFavFishFeature and autoFavFishFeature.SetDesiredTiersByNames then
            autoFavFishFeature:SetDesiredTiersByNames(selectedTiers)
        end
    end
})

local favfish_tgl = favfish_sec:Toggle({
    Title    = "Auto Favorite Fish",
    Desc     = "Automatically favorite fish with selected rarities",
    Default  = false,
    Callback = function(state)
        if state then
            -- Load feature jika belum ada
            if not autoFavFishFeature then
                print("[AutoFavoriteFish] Loading feature...")
                autoFavFishFeature = FeatureManager:LoadFeature("AutoFavoriteFish", {
                    tierDropdown = favfish_ddm,
                    toggle       = favfish_tgl,
                })

                -- setelah Init, reload options rarity dari game
                if autoFavFishFeature then
                    task.spawn(function()
                        task.wait(0.5)
                        if autoFavFishFeature.GetTierNames then
                            local tierNames = autoFavFishFeature:GetTierNames()
                            if favfish_ddm.Reload then
                                favfish_ddm:Reload(tierNames)
                            end
                        end
                    end)
                end
            end

            -- Validasi pilihan tier
            if not selectedTiers or #selectedTiers == 0 then
                WindUI:Notify({
                    Title    = "Info",
                    Content  = "Select at least 1 rarity first",
                    Icon     = "info",
                    Duration = 2
                })
                favfish_tgl:Set(false)
                return
            end

            -- Start
            print("[AutoFavoriteFish] Starting with tiers:", table.concat(selectedTiers, ", "))
            if autoFavFishFeature and autoFavFishFeature.Start then
                autoFavFishFeature:Start({
                    tierList = selectedTiers  -- Changed from tierNames to match script
                })
                WindUI:Notify({
                    Title    = "Started",
                    Content  = "Auto Favorite Fish is now active",
                    Icon     = "check",
                    Duration = 2
                })
            else
                favfish_tgl:Set(false)
                WindUI:Notify({
                    Title    = "Failed",
                    Content  = "Could not start Auto Favorite Fish",
                    Icon     = "x",
                    Duration = 3
                })
            end
        else
            if autoFavFishFeature and autoFavFishFeature.Stop then
                autoFavFishFeature:Stop()
            end
        end
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

local sellfish_dd = sellfish_sec:Dropdown({
    Title = "Select Rarity",
    Desc  = "Rarity Threshold",
    Values = { "Secret", "Mythic", "Legendary" },
    Value = "Legendary",
    Callback = function(option)
    currentSellThreshold = option
    if sellfishFeature and sellfishFeature.SetMode then
      sellfishFeature:SetMode(option)
    end
  end
})

local sellfish_in = sellfish_sec:Input({
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

local sellfish_tgl = sellfish_sec:Toggle({
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

--- === AUTOMATION === ---
--- Auto Enchant Rod
local autoenchantrod_sec = TabAutomation:Section({ 
    Title = "Auto Enchant",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local autoEnchantFeature = nil
local selectedEnchants   = {}
local enchantName = getEnchantName()

local enchant_ddm = autoenchantrod_sec:Dropdown({
    Title     = "Select Enchants",
    Values    = enchantName,       -- akan diisi saat modul diload
    Value     = {},
    Multi     = true,
    AllowNone = true,
    Callback  = function(options)
        -- options adalah array nama enchant yang dipilih
        selectedEnchants = options or {}
        -- Jika fitur sudah ada, update target
        if autoEnchantFeature and autoEnchantFeature.SetDesiredByNames then
            autoEnchantFeature:SetDesiredByNames(selectedEnchants)
        end
    end
})

local enchant_tgl = autoenchantrod_sec:Toggle({
    Title   = "Auto Enchant Rod",
    Default = false,
    Callback = function(state)
        if state then
            -- Pastikan ada target yang dipilih
            if #selectedEnchants == 0 then
                WindUI:Notify({
                    Title    = "Info",
                    Content  = "Select at least one enchant first",
                    Icon     = "info",
                    Duration = 3
                })
                enchant_tgl:Set(false)
                return
            end
            -- Load modul jika belum ada
            if not autoEnchantFeature then
                autoEnchantFeature = FeatureManager:LoadFeature("AutoEnchantRod", {
                    enchantDropdownMulti = enchant_ddm,
                    toggle               = enchant_tgl,
                })
                -- Isi dropdown dengan semua nama enchant dari modul
                if autoEnchantFeature and autoEnchantFeature.GetEnchantNames then
                    local names = autoEnchantFeature:GetEnchantNames()
                    if enchant_ddm.Reload then enchant_ddm:Reload(names) end
                end
            end
            -- Mulai dengan target dan delay default
            if autoEnchantFeature and autoEnchantFeature.Start then
                autoEnchantFeature:Start({
                    enchantNames = selectedEnchants,
                    delay        = 0.6, -- jeda antar roll
                })
                WindUI:Notify({
                    Title    = "Tip",
                    Content  = "Place Enhance Stone at slot 3",
                    Icon     = "info",
                    Duration = 4
                })
            else
                enchant_tgl:Set(false)
                WindUI:Notify({
                    Title    = "Failed",
                    Content  = "Could not start AutoEnchantRod",
                    Icon     = "x",
                    Duration = 3
                })
            end
        else
            -- Matikan fitur jika toggle off
            if autoEnchantFeature and autoEnchantFeature.Stop then
                autoEnchantFeature:Stop()
            end
        end
    end
})

-- helpers for player lists
local function listPlayers(excludeSelf)
    local me = LocalPlayer and LocalPlayer.Name
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if not excludeSelf or (me and p.Name ~= me) then
            table.insert(t, p.Name)
        end
    end
    table.sort(t, function(a, b) return a:lower() < b:lower() end)
    return t
end

-- normalize apapun yang dikasih Dropdown (string atau table)
local function normalizeOption(opt)
    if type(opt) == "string" then return opt end
    if type(opt) == "table" then
        return opt.Value or opt.value or opt[1] or opt.Selected or opt.selection
    end
    return nil
end

local function normalizeList(opts)
    local out = {}
    local function push(v)
        if v ~= nil then table.insert(out, tostring(v)) end
    end
    if type(opts) == "string" or type(opts) == "number" then
        push(opts)
    elseif type(opts) == "table" then
        if #opts > 0 then
            for _, v in ipairs(opts) do
                if type(v) == "table" then
                    push(v.Value or v.value or v.Name or v.name or v[1] or v.Selected or v.selection)
                else
                    push(v)
                end
            end
        else
            for k, v in pairs(opts) do
                if type(k) ~= "number" and v then
                    push(k)
                else
                    if type(v) == "table" then
                        push(v.Value or v.value or v.Name or v.name or v[1] or v.Selected or v.selection)
                    else
                        push(v)
                    end
                end
            end
        end
    end
    return out
end

--- Auto Trade
local autotrade_sec = TabAutomation:Section({ 
    Title = "Auto Send Trade",
    TextXAlignment = "Left",
    TextSize = 17,
    Opened = true
})

-- State variables
local autoTradeFeature = nil
local selectedTradeItems = {}
local selectedTargetPlayers = {}

-- Dropdown untuk pilih target players (Multi - bisa kirim ke beberapa player)
local tradeplayer_ddm = autotrade_sec:Dropdown({
    Title = "Select Target Players",
    Desc = "Choose players to send trades to",
    Values = listPlayers(true),
    Value = {},
    Multi = true, -- Ubah jadi Multi
    AllowNone = true,
    Callback = function(options)
        selectedTargetPlayers = options or {}
        print("[AutoSendTrade] Selected players:", #selectedTargetPlayers, "players")
        
        -- Update feature jika sudah loaded
        if autoTradeFeature and autoTradeFeature.SetSelectedPlayers then
            autoTradeFeature:SetSelectedPlayers(selectedTargetPlayers)
        end
    end
})

-- Dropdown untuk pilih fish (Multi)
local tradeitem_ddm = autotrade_sec:Dropdown({
    Title = "Select Fish",
    Desc = "Choose fish to trade",
    Values = getFishNamesForTrade(), -- Gunakan fungsi helper
    Value = {},
    SearchBarEnabled = true,
    Multi = true,
    AllowNone = true,
    Callback = function(options)
        selectedTradeItems = options or {}
        print("[AutoSendTrade] Selected fish:", #selectedTradeItems, "items")
        
        -- Update feature jika sudah loaded
        if autoTradeFeature and autoTradeFeature.SetSelectedFish then
            autoTradeFeature:SetSelectedFish(selectedTradeItems)
        end
    end
})

-- Input untuk trade delay
local tradedelay_in = autotrade_sec:Input({
    Title = "Trade Delay (seconds)",
    Desc = "Delay between trades",
    Value = "5",
    Placeholder = "5",
    Numeric = true,
    Callback = function(value)
        local delay = tonumber(value) or 5.0
        if delay < 1.0 then delay = 1.0 end
        
        print("[AutoSendTrade] Trade delay set to:", delay, "seconds")
        
        -- Update feature jika sudah loaded
        if autoTradeFeature and autoTradeFeature.SetTradeDelay then
            autoTradeFeature:SetTradeDelay(delay)
        end
    end
})

-- Button refresh player list
local traderefresh_btn = autotrade_sec:Button({
    Title = "Refresh Player List",
    Desc = "Update online players",
    Locked = false,
    Callback = function()
        local names = listPlayers(true)
        if tradeplayer_ddm.Refresh then
            tradeplayer_ddm:Refresh(names)
        end
        
        WindUI:Notify({ 
            Title = "Players", 
            Content = ("Online: %d"):format(#names), 
            Icon = "users", 
            Duration = 2 
        })
    end
})

-- Toggle untuk start/stop auto trade
local autotrade_tgl = autotrade_sec:Toggle({
    Title = "Auto Send Trade",
    Desc = "Automatically send trade requests",
    Default = false,
    Callback = function(state)
        if state then
            -- Load feature jika belum ada
            if not autoTradeFeature then
                print("[AutoSendTrade] Loading feature...")
                autoTradeFeature = FeatureManager:GetFeature("AutoSendTrade", {
                    itemDropdown = tradeitem_ddm,
                    playerDropdown = tradeplayer_ddm,
                    refreshButton = traderefresh_btn,
                    delayInput = tradedelay_in,
                    toggle = autotrade_tgl
                })
                
                -- Refresh dropdown fish setelah feature loaded
                if autoTradeFeature then
                    task.spawn(function()
                        task.wait(1.0) -- Beri waktu feature untuk scan inventory
                        
                        local availableFish = getFishNamesForTrade() -- Reload dari game
                        if tradeitem_ddm.Refresh then
                            tradeitem_ddm:Refresh(availableFish)
                        end
                        
                        print("[AutoSendTrade] Fish dropdown refreshed with", #availableFish, "fish")
                    end)
                end
            end
            
            -- Validasi: pastikan ada fish yang dipilih
            if not selectedTradeItems or #selectedTradeItems == 0 then
                WindUI:Notify({
                    Title = "Info",
                    Content = "Select at least 1 fish first",
                    Icon = "info",
                    Duration = 3
                })
                autotrade_tgl:Set(false)
                return
            end
            
            -- Validasi: pastikan ada target players
            if not selectedTargetPlayers or #selectedTargetPlayers == 0 then
                WindUI:Notify({
                    Title = "Info",
                    Content = "Select at least 1 target player",
                    Icon = "info",
                    Duration = 3
                })
                autotrade_tgl:Set(false)
                return
            end
            
            -- Get trade delay
            local tradeDelay = tonumber(tradedelay_in.Value) or 5.0
            if tradeDelay < 1.0 then tradeDelay = 1.0 end
            
            -- Start auto trade
            if autoTradeFeature and autoTradeFeature.Start then
                local success = autoTradeFeature:Start({
                    fishNames = selectedTradeItems,    -- Sesuaikan dengan parameter yang benar
                    playerList = selectedTargetPlayers, -- Sesuaikan dengan parameter yang benar  
                    tradeDelay = tradeDelay
                })
                
                if success ~= false then -- Start() mungkin tidak return boolean
                    WindUI:Notify({
                        Title = "Started",
                        Content = string.format("Auto Trade: %d fish → %d players", 
                            #selectedTradeItems, #selectedTargetPlayers),
                        Icon = "check",
                        Duration = 3
                    })
                else
                    autotrade_tgl:Set(false)
                    WindUI:Notify({
                        Title = "Failed",
                        Content = "Could not start Auto Send Trade",
                        Icon = "x",
                        Duration = 3
                    })
                end
            else
                autotrade_tgl:Set(false)
                WindUI:Notify({
                    Title = "Failed",
                    Content = "AutoSendTrade feature not available",
                    Icon = "x",
                    Duration = 3
                })
            end
        else
            -- Stop auto trade
            if autoTradeFeature and autoTradeFeature.Stop then
                autoTradeFeature:Stop()
                WindUI:Notify({
                    Title = "Stopped", 
                    Content = "Auto Send Trade stopped",
                    Icon = "info",
                    Duration = 2
                })
            end
        end
    end
})

-- Auto Accept Trade implementation (UPDATED FOR DIRECT HOOK APPROACH)
-- UPDATED Toggle untuk Auto Accept Trade - Button Click Version
local autogiftacc_tgl = autotrade_sec:Toggle({
    Title = "Auto Accept Trade",
    Desc = "Automatically accept incoming trade requests (Button Click Method)",
    Default = false,
    Callback = function(state) 
        print("[GUI] AutoAcceptTrade toggle:", state)
        
        if state then
            -- Load feature jika belum ada
            if not autoAcceptTradeFeature then
                print("[AutoAcceptTrade] Loading feature...")
                autoAcceptTradeFeature = FeatureManager:LoadFeature("AutoAcceptTrade", {
                    toggle = autogiftacc_tgl
                })
                
                if not autoAcceptTradeFeature then
                    WindUI:Notify({
                        Title = "Failed",
                        Content = "Could not load AutoAcceptTrade feature",
                        Icon = "x",
                        Duration = 3
                    })
                    autogiftacc_tgl:Set(false)
                    return
                end
                
                print("[AutoAcceptTrade] Feature loaded successfully")
            end
            
            -- Start auto accept (Button Click Mode)
            print("[AutoAcceptTrade] Starting button click mode...")
            if autoAcceptTradeFeature and autoAcceptTradeFeature.Start then
                local success = autoAcceptTradeFeature:Start()
                
                if success ~= false then
                    WindUI:Notify({
                        Title = "Started",
                        Content = "Auto Accept Trade active (Button Click)",
                        Icon = "check",
                        Duration = 2
                    })
                    print("[AutoAcceptTrade] Successfully started in button click mode")
                else
                    autogiftacc_tgl:Set(false)
                    WindUI:Notify({
                        Title = "Failed", 
                        Content = "Could not start Auto Accept Trade",
                        Icon = "x",
                        Duration = 3
                    })
                end
            else
                autogiftacc_tgl:Set(false)
                WindUI:Notify({
                    Title = "Error",
                    Content = "Start method not available",
                    Icon = "x", 
                    Duration = 3
                })
            end
        else
            -- Stop auto accept
            if autoAcceptTradeFeature and autoAcceptTradeFeature.Stop then
                autoAcceptTradeFeature:Stop()
                WindUI:Notify({
                    Title = "Stopped",
                    Content = "Auto Accept Trade stopped", 
                    Icon = "info",
                    Duration = 2
                })
            end
        end
    end
})

-- Status button (UPDATED for Button Click Method)
local acceptstatus_btn = autotrade_sec:Button({
    Title = "Accept Trade Status",
    Desc = "Show status and statistics",
    Locked = false,
    Callback = function()
        if autoAcceptTradeFeature and autoAcceptTradeFeature.GetStatus then
            local status = autoAcceptTradeFeature:GetStatus()
            local statusText = string.format(
                "Running: %s\nSpamming: %s\nTotal Processed: %d\nSession: %d\nCurrent Clicks: %d\nMode: %s\nRemote Found: %s",
                status.isRunning and "Yes" or "No",
                status.isSpamming and "Yes" or "No",
                status.totalTradesProcessed or 0,
                status.currentSessionTrades or 0,
                status.currentClicks or 0,
                status.mode or "Unknown",
                status.remoteFound and "Yes" or "No"
            )
            
            WindUI:Notify({
                Title = "AutoAccept Status",
                Content = statusText,
                Icon = "info",
                Duration = 6
            })
        else
            WindUI:Notify({
                Title = "Status", 
                Content = "Feature not loaded yet",
                Icon = "info",
                Duration = 2
            })
        end
    end
})

-- Test detection button (NEW for Pure Detection Method)
local testdetection_btn = autotrade_sec:Button({
    Title = "Test Detection System",
    Desc = "Test trade detection system",
    Locked = false,
    Callback = function()
        if not autoAcceptTradeFeature then
            autoAcceptTradeFeature = FeatureManager:LoadFeature("AutoAcceptTrade")
            if not autoAcceptTradeFeature then
                WindUI:Notify({
                    Title = "Error",
                    Content = "Could not load AutoAcceptTrade feature",
                    Icon = "x",
                    Duration = 3
                })
                return
            end
        end
        
        if autoAcceptTradeFeature.TestDetection then
            autoAcceptTradeFeature:TestDetection()
            WindUI:Notify({
                Title = "Test Complete",
                Content = "Check console for detection test results",
                Icon = "info", 
                Duration = 3
            })
        else
            WindUI:Notify({
                Title = "Test Unavailable",
                Content = "TestDetection method not found",
                Icon = "triangle-alert",
                Duration = 3
            })
        end
    end
})


--- === Shop === --- 
--- Rod
local shoprod_sec = TabShop:Section({ 
    Title = "Rod",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local autobuyrodFeature = nil
local selectedRodsSet = {} -- State untuk menyimpan pilihan user

local shoprod_ddm = shoprod_sec:Dropdown({
    Title = "Select Rod",
    Values = listRod,
    Value = {}, -- Start with empty selection
    Multi = true,
    AllowNone = true,
    Callback = function(options) 
        -- Update state variable
        selectedRodsSet = options or {}
        
        print("[AutoBuyRod] Selected rods:", game:GetService("HttpService"):JSONEncode(selectedRodsSet))
        
        -- Update feature jika sudah dimuat
        if autobuyrodFeature and autobuyrodFeature.SetSelectedRodsByName then
            autobuyrodFeature:SetSelectedRodsByName(selectedRodsSet)
        end
    end
})

local shoprod_btn = shoprod_sec:Button({
    Title = "Buy Rod",
    Desc = "Purchase selected rods (one-time buy)",
    Locked = false,
    Callback = function()
        print("[GUI] Buy Rod button clicked")
        
        -- Load feature pada first-time saja
        if not autobuyrodFeature then
            print("[GUI] Loading AutoBuyRod feature...")
            autobuyrodFeature = FeatureManager:LoadFeature("AutoBuyRod", {
                rodsDropdown = shoprod_ddm,
                button = shoprod_btn
            })
            
            -- Jika feature berhasil dimuat, refresh dropdown dengan data real
            if autobuyrodFeature then
                print("[GUI] AutoBuyRod feature loaded successfully")
                
                -- Spawn task untuk refresh dropdown setelah Init selesai
                task.spawn(function()
                    task.wait(0.5) -- Beri waktu untuk Init() selesai
                    
                    if autobuyrodFeature.GetAvailableRods then
                        local availableRods = autobuyrodFeature:GetAvailableRods()
                        local rodNames = {}
                        
                        for _, rod in ipairs(availableRods) do
                            table.insert(rodNames, rod.name) -- Simpan nama asli untuk logic
                        end
                        
                        -- Reload dropdown dengan data real dari game
                        if shoprod_ddm.Reload then
                            shoprod_ddm:Reload(rodNames)
                            print("[AutoBuyRod] Dropdown refreshed with", #rodNames, "real rods")
                        end
                    end
                end)
            else
                print("[GUI] Failed to load AutoBuyRod feature")
                WindUI:Notify({ 
                    Title = "Error", 
                    Content = "Failed to load AutoBuyRod feature", 
                    Icon = "x", 
                    Duration = 3 
                })
                return
            end
        end
        
        -- Validasi: pastikan ada rod yang dipilih
        if not selectedRodsSet or #selectedRodsSet == 0 then
            WindUI:Notify({ 
                Title = "Info", 
                Content = "Select at least 1 Rod first", 
                Icon = "info", 
                Duration = 3 
            })
            return
        end
        
        -- Validasi: feature harus sudah dimuat
        if not autobuyrodFeature then
            WindUI:Notify({ 
                Title = "Error", 
                Content = "AutoBuyRod feature not available", 
                Icon = "x", 
                Duration = 3 
            })
            return
        end
        
        -- Execute purchase process
        print("[GUI] Starting purchase for rods:", table.concat(selectedRodsSet, ", "))
        
        -- Set selected rods ke feature
        if autobuyrodFeature.SetSelectedRodsByName then
            local setSuccess = autobuyrodFeature:SetSelectedRodsByName(selectedRodsSet)
            if not setSuccess then
                WindUI:Notify({ 
                    Title = "Error", 
                    Content = "Failed to set selected rods", 
                    Icon = "x", 
                    Duration = 3 
                })
                return
            end
        end
        
        -- Start one-time purchase
        if autobuyrodFeature.Start then
            local purchaseSuccess = autobuyrodFeature:Start({
                rodList = selectedRodsSet,
                interDelay = 0.5 -- Anti-spam delay
            })
            
            -- Feedback ke user
            if purchaseSuccess then
                WindUI:Notify({ 
                    Title = "Success", 
                    Content = "Rod purchase completed!", 
                    Icon = "check", 
                    Duration = 3 
                })
                print("[GUI] Purchase completed successfully")
            else
                WindUI:Notify({ 
                    Title = "Failed", 
                    Content = "Could not complete rod purchase", 
                    Icon = "x", 
                    Duration = 3 
                })
                print("[GUI] Purchase failed")
            end
        else
            WindUI:Notify({ 
                Title = "Error", 
                Content = "Start method not available", 
                Icon = "x", 
                Duration = 3 
            })
        end
    end
})

--- Baits
local shopbait_sec = TabShop:Section({ 
    Title = "Baits",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local autobuybaitFeature = nil
local selectedBaitsSet = {}
local baitName = getBaitNames()

local shopbait_ddm = shopbait_sec:Dropdown({
    Title = "Select Bait",
    Values = baitName,
    Value = {}, -- Start with empty selection
    Multi = true,
    AllowNone = true,
    Callback = function(options) 
        -- Update state variable
        selectedBaitsSet = options or {}
        
        print("[AutoBuyBait] Selected baits:", game:GetService("HttpService"):JSONEncode(selectedBaitsSet))
        
        -- Update feature jika sudah dimuat
        if autobuybaitFeature and autobuybaitFeature.SetSelectedBaitsByName then
            autobuybaitFeature:SetSelectedBaitsByName(selectedBaitsSet)
        end
    end
})

local shopbait_btn = shopbait_sec:Button({
    Title = "Buy Bait",
    Desc = "Purchase selected baits (one-time buy)",
    Locked = false,
    Callback = function()
        print("[GUI] Buy Bait button clicked")
        
        -- Load feature pada first-time saja
        if not autobuybaitFeature then
            print("[GUI] Loading AutoBuyBait feature...")
            autobuybaitFeature = FeatureManager:LoadFeature("AutoBuyBait", {
                dropdown = shopbait_ddm,
                button   = shopbait_btn
            })
            
            -- Jika feature berhasil dimuat, refresh dropdown dengan data real
            if autobuybaitFeature then
                print("[GUI] AutoBuyBait feature loaded successfully")
                
                -- Spawn task untuk refresh dropdown setelah Init selesai
                task.spawn(function()
                    task.wait(0.5) -- Beri waktu untuk Init() selesai
                    
                    if autobuybaitFeature.GetAvailableBaits then
                        local availableBaits = autobuybaitFeature:GetAvailableBaits()
                        local baitNames = {}
                        
                        for _, bait in ipairs(availableBaits) do
                            -- Format: "Nama Bait (Tier X - Y coins)"
                            local displayName = string.format("%s (T%d - %d coins)", 
                                bait.name, bait.tier, bait.price)
                            table.insert(baitNames, bait.name) -- Simpan nama asli untuk logic
                        end
                        
                        -- Reload dropdown dengan data real dari game
                        if shopbait_ddm.Reload then
                            shopbait_ddm:Reload(baitNames)
                            print("[AutoBuyBait] Dropdown refreshed with", #baitNames, "real baits")
                        end
                    end
                end)
            else
                print("[GUI] Failed to load AutoBuyBait feature")
                WindUI:Notify({ 
                    Title = "Error", 
                    Content = "Failed to load AutoBuyBait feature", 
                    Icon = "x", 
                    Duration = 3 
                })
                return
            end
        end
        
        -- Validasi: pastikan ada bait yang dipilih
        if not selectedBaitsSet or #selectedBaitsSet == 0 then
            WindUI:Notify({ 
                Title = "Info", 
                Content = "Select at least 1 Bait first", 
                Icon = "info", 
                Duration = 3 
            })
            return
        end
        
        -- Validasi: feature harus sudah dimuat
        if not autobuybaitFeature then
            WindUI:Notify({ 
                Title = "Error", 
                Content = "AutoBuyBait feature not available", 
                Icon = "x", 
                Duration = 3 
            })
            return
        end
        
        -- Execute purchase process
        print("[GUI] Starting purchase for baits:", table.concat(selectedBaitsSet, ", "))
        
        -- Set selected baits ke feature
        if autobuybaitFeature.SetSelectedBaitsByName then
            local setSuccess = autobuybaitFeature:SetSelectedBaitsByName(selectedBaitsSet)
            if not setSuccess then
                WindUI:Notify({ 
                    Title = "Error", 
                    Content = "Failed to set selected baits", 
                    Icon = "x", 
                    Duration = 3 
                })
                return
            end
        end
        
        -- Start one-time purchase
        if autobuybaitFeature.Start then
            local purchaseSuccess = autobuybaitFeature:Start({
                baitList = selectedBaitsSet,
                interDelay = 0.5 -- Anti-spam delay
            })
            
            -- Feedback ke user
            if purchaseSuccess then
                WindUI:Notify({ 
                    Title = "Success", 
                    Content = "Bait purchase completed!", 
                    Icon = "check", 
                    Duration = 3 
                })
                print("[GUI] Purchase completed successfully")
            else
                WindUI:Notify({ 
                    Title = "Failed", 
                    Content = "Could not complete bait purchase", 
                    Icon = "x", 
                    Duration = 3 
                })
                print("[GUI] Purchase failed")
            end
        else
            WindUI:Notify({ 
                Title = "Error", 
                Content = "Start method not available", 
                Icon = "x", 
                Duration = 3 
            })
        end
    end
})

--- Weather
local shopweather_sec = TabShop:Section({ 
    Title = "Weather",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local weatherFeature          = nil
local selectedWeatherSet      = {} 

-- Multi dropdown (Values diisi setelah modul diload)
local shopweather_ddm = shopweather_sec:Dropdown({
    Title     = "Select Weather",
    Desc      = "",
    Values    = weatherName,
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

local shopweather_tgl = shopweather_sec:Toggle({
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

local teleisland_dd = teleisland_sec:Dropdown({
    Title = "Select Island",
    Values = {
        "Fisherman Island",
        "Esoteric Depths",
        "Enchant Altar",
        "Kohana",
        "Kohana Volcano",
        "Tropical Grove",
        "Crater Island",
        "Coral Reefs",
        "Sisyphus Statue",
        "Treasure Room"
    },
    Value = currentIsland,
    Callback = function(option)
        currentIsland = option
        -- jika modul sudah dimuat, set island langsung
        if autoTeleIslandFeature and autoTeleIslandFeature.SetIsland then
            autoTeleIslandFeature:SetIsland(option)
        end
    end
})


local teleisland_btn = teleisland_sec:Button({
    Title = "Teleport To Island",
    Desc  = "",
    Locked = false,
    Callback = function()
        -- Muat modul jika belum pernah dimuat
        if not autoTeleIslandFeature then
            autoTeleIslandFeature = FeatureManager:LoadFeature("AutoTeleportIsland", {
                dropdown = teleisland_dd,
                button   = teleisland_btn
            })
        end
        -- Jika modul berhasil dimuat, lakukan set dan teleport
        if autoTeleIslandFeature then
            if autoTeleIslandFeature.SetIsland then
                autoTeleIslandFeature:SetIsland(currentIsland)
            end
            if autoTeleIslandFeature.Teleport then
                autoTeleIslandFeature:Teleport(currentIsland)
            end
        else
            WindUI:Notify({
                Title   = "Error",
                Content = "AutoTeleportIsland feature could not be loaded",
                Icon    = "x",
                Duration = 3
            })
        end
    end
})

--- Teleport To Player
local teleplayer_sec = TabTeleport:Section({ 
    Title = "Players",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local teleplayerFeature = nil
local currentPlayerName = nil

local teleplayer_dd = teleplayer_sec:Dropdown({
    Title = "Select Player",
    Values = listPlayers(true),
    Value = "",
    Callback = function(option) 
        local name = normalizeOption(option)
        currentPlayerName = name
        if teleplayerFeature and teleplayerFeature.SetTarget then
            teleplayerFeature:SetTarget(name)
        end
        -- optional: debug
         print("[teleplayer] selected:", name, typeof(option))
    end
})

local teleplayer_btn = teleplayer_sec:Button({
    Title = "Teleport To Player",
    Desc = "",
    Locked = false,
    Callback = function()
         if not teleplayerFeature then
            teleplayerFeature = FeatureManager:GetFeature("AutoTeleportPlayer", {
                dropdown       = teleplayer_dd,
                refreshButton  = teleplayerrefresh_btn,
                teleportButton = nil, -- ga wajib dipakai modul
            })
            if not teleplayerFeature then
                WindUI:Notify({ Title="Error", Content="AutoTeleportPlayer gagal dimuat", Icon="x", Duration=3 })
                return
            end
        end

        -- fallback: kalau somehow current masih nil, coba tarik dari dropdown
        if (not currentPlayerName or currentPlayerName == "") then
            local v = rawget(teleplayer_dd, "Value")
            currentPlayerName = normalizeOption(v)
        end

        if (not currentPlayerName or currentPlayerName == "") then
            WindUI:Notify({ Title = "Teleport Failed", Content = "Pilih player dulu dari dropdown", Icon = "x", Duration = 3 })
            return
        end

        teleplayerFeature:SetTarget(currentPlayerName)
        local ok = teleplayerFeature:Teleport()
        if not ok then
            WindUI:Notify({ Title = "Teleport Failed", Content = "Gagal teleport (anti-cheat/target belum spawn?)", Icon = "x", Duration = 3 })
        end
    end
})

local teleplayerrefresh_btn = teleplayer_sec:Button({
    Title = "Refresh Player List",
    Desc = "",
    Locked = false,
    Callback = function()
       local names = listPlayers(true)
        teleplayer_dd:Refresh(names) -- <— API resmi
        -- jaga state: kalau current hilang, auto-pick pertama biar nggak nil
        if not table.find(names, currentPlayerName) then
            currentPlayerName = names[1]
            if currentPlayerName then
                teleplayer_dd:Select(currentPlayerName) -- <— API resmi
                if teleplayerFeature and teleplayerFeature.SetTarget then
                    teleplayerFeature:SetTarget(currentPlayerName)
                end
            end
        end
        WindUI:Notify({ Title = "Players", Content = ("Online: %d"):format(#names), Icon = "users", Duration = 2 })
    end
})

--- === Misc === ---
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

local webhookfish_in = webhookfish_sec:Input({
    Title = "Discord Webhook URL",
    Desc = "",
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

local webhookfish_ddm = webhookfish_sec:Dropdown({
    Title = "Select Rarity",
    Desc = "Choose which fish rarities to send to webhook",
    Values = rarityName,
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


local webhookfish_tgl = webhookfish_sec:Toggle({
    Title = "Enable Fish Webhook",
    Desc = "Automatically send notifications to webhook",
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
                    Icon = "triangle-alert",
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

--- Other
local others_sec = TabMisc:Section({ 
    Title = "Other",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local autoGearFeature = nil
local oxygenOn = false
local radarOn  = false

local eqoxygentank_tgl = TabMisc:Toggle({
    Title = "Equip Diving Gear",
    Desc  = "No Need have Diving Gear",
    Default = false,
    Callback = function(state)
  print("Diving Gear toggle:", state)
  oxygenOn = state
  if state then
    -- muat modul jika belum ada, lalu panggil Start sekali saja
    if not autoGearFeature then
      autoGearFeature = FeatureManager:LoadFeature("AutoGearOxyRadar")
      if autoGearFeature and autoGearFeature.Start then
        autoGearFeature:Start()      -- init & konfigurasi default
      end
    end
    -- nyalakan oxygen tank
    if autoGearFeature and autoGearFeature.EnableOxygen then
      autoGearFeature:EnableOxygen(true)
    end
  else
    -- matikan oxygen tank
    if autoGearFeature and autoGearFeature.EnableOxygen then
      autoGearFeature:EnableOxygen(false)
    end
  end
  -- hentikan modul jika kedua toggle mati
  if autoGearFeature and (not oxygenOn) and (not radarOn) and autoGearFeature.Stop then
    autoGearFeature:Stop()
  end
end

})

local eqfishradar_tgl = TabMisc:Toggle({
    Title = "Enable Fish Radar",
    Desc  = "No Need have Fish Radar",
    Default = false,
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

--- Anti AFK
local antiafkFeature = nil

local antiafk_tgl = TabMisc:Toggle({
    Title = "Anti AFK",
    Default = true,
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

--- Boost FPS
local alreadyApplied = false
local boostFeature = nil

local boostfps_btn = TabMisc:Button({
    Title = "Boost FPS",
    Desc = "Reduce Graphics",
    Locked = false,
    Callback = function()
        if alreadyApplied then
            WindUI:Notify({ Title="Boost FPS", Content="Already applied (Ultra)", Icon="info", Duration=2 })
            return
        end

        if not boostFeature then
            boostFeature = FeatureManager:GetFeature("BoostFPS")
            if not boostFeature then
                WindUI:Notify({ Title="Failed", Content="Could not load BoostFPS", Icon="x", Duration=3 })
                return
            end
        end

        local ok, err = pcall(function()
            boostFeature:Apply({})
        end)

        if ok then
            alreadyApplied = true
            WindUI:Notify({ Title="Boost FPS", Content="Applied: Ultra Low", Icon="check", Duration=2 })
        else
            WindUI:Notify({ Title="Error", Content=tostring(err), Icon="x", Duration=3 })
        end
    end
})

Window:SelectTab(1)

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
        
        -- Cleanup DevLogicIcon secara langsung juga (double safety)
        if DevLogicIcon then
            pcall(function() DevLogicIcon:Destroy() end)
            DevLogicIcon = nil
        end
    end)
end


