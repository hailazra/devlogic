-- WindUI Library
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()


--========== WINDOW ==========
local Window = WindUI:CreateWindow({
    Title         = ".devlogic",
    Icon          = "rbxassetid://73063950477508",
    Author        = "Grow A Garden",
    Folder        = ".devlogichub",
    Size          = UDim2.fromOffset(250, 250),
    Theme         = "Dark",
    Resizable     = false,
    SideBarWidth  = 120,
    HideSearchBar = true,
})

WindUI:SetFont("rbxasset://12187366657")

Window:EditOpenButton({
    Title = "",
    Icon = "rbxassetid://73063950477508",
    CornerRadius = UDim.new(0,1),
    StrokeThickness = 1,
    Color = ColorSequence.new( -- gradient
        Color3.fromHex("000000"), 
        Color3.fromHex("000000")
    ),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

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
    "[+] Optimization GUI",
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

-- helper ambil value kontrol yg compatible (tanpa integrasi apapun)
local function getValue(ctrl)
    if ctrl == nil then return nil end
    if type(ctrl.GetValue) == "function" then
        local ok, v = pcall(ctrl.GetValue, ctrl)
        if ok then return v end
    end
    return rawget(ctrl, "Value")
end

local function toListText(v)
    if typeof(v) == "table" then
        local buf = {}
        for _, item in ipairs(v) do table.insert(buf, tostring(item)) end
        return table.concat(buf, ", ")
    end
    return tostring(v)
end

--========== TABS ==========
-- Home
local TabHome = Window:Tab({ Title = "Home", Icon = "house" })
-- Farm
local SFarm         = Window:Section({ Title = "Farm", Icon = "wheat", Opened = false })
local TabPlants     = SFarm:Tab({ Title = "Plants & Fruits", Icon = "sprout" })
local TabSprinkler  = SFarm:Tab({ Title = "Sprinkler",       Icon = "droplets" })
-- Inventory
local SInventory   = Window:Section({ Title = "Inventory", Icon = "backpack", Opened = false })
local TabBackpack = SInventory:Tab({ Title = "Inventory", Icon = "backpack" })
-- Pet & Egg
local SPetEgg    = Window:Section({ Title = "Pet & Egg", Icon = "egg", Opened = false })
local TabPet     = SPetEgg:Tab({ Title = "Pet",     Icon = "paw-print" })
local TabEgg     = SPetEgg:Tab({ Title = "Egg",     Icon = "egg" })
-- Shop & Craft
local SShopCraft = Window:Section({ Title = "Shop", Icon = "shopping-bag", Opened = false })
local TabShop    = SShopCraft:Tab({ Title = "Shop",   Icon = "shopping-cart" })
local TabCraft   = SShopCraft:Tab({ Title = "Craft",  Icon = "settings" })
-- Misc
local TabMisc   = Window:Tab({ Title = "Misc", Icon = "house" }) 
-- Settings
local TabSettings = Window:Tab({ Title = "Settings", Icon = "settings" })

-- === SECTION === --
-- Home
local ImportanSec = TabHome:Section({ 
    Title = "Important",
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

-- === Plants & Fruits === ---
-- Auto Plant Seeds
local plantseed_sec = TabPlants:Section({ 
    Title = "Auto Plant Seeds",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = true
})

local plantseed_ddm = plantseed_sec:Dropdown({
    Title = "Select Seeds",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local plantseedpos_dd = plantseed_sec:Dropdown({
    Title = "Select Position",
    Values = { "Category A", "Category B", "Category C" },
    Value = "Category A",
    Callback = function(option) 
        print("Category selected: " .. option) 
    end
})

local plantseed_tgl = plantseed_sec:Toggle({
    Title = "Auto Plant Seeds",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Auto Collect Fruits
local collectfruit_sec = TabPlants:Section({ 
    Title = "Auto Collect Fruits",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local collectfruit_ddm = collectfruit_sec:Dropdown({
    Title = "Select Fruits",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local collectwhitelist_ddm = collectfruit_sec:Dropdown({
    Title = "Whitelist Mutation",
    Values = { "World A", "World B", "World C" },
    Value = { "World A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Worlds selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local collectblacklist_ddm = collectfruit_sec:Dropdown({
    Title = "Blacklist Mutation",
    Values = { "World A", "World B", "World C" },
    Value = { "World A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Worlds selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local collectthershold_dd = collectfruit_sec:Dropdown({
    Title = "Weight Threshold",
    Values = { "World A", "World B", "World C" },
    Value = "World A",
    Callback = function(option) 
        print("World selected: " .. option) 
    end
})

local collectweight_in = collectfruit_sec:Input({
    Title = "Weight",
    Placeholder = "e.g 30",
    Value = "",
    Numeric = false,
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local collectfruit_tgl = collectfruit_sec:Toggle({
    Title = "Auto Collect Fruits",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Auto Shovel Fruits
local shovelfruit_sec = TabPlants:Section({ 
    Title = "Auto Shovel Fruits",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local shovelfruit_ddm = shovelfruit_sec:Dropdown({
    Title = "Select Fruit",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shovelfruitthresh_dd = shovelfruit_sec:Dropdown({
    Title = "Weight Threshold",
    Values = { "World A", "World B", "World C" },
    Value = "World A",
    Callback = function(option) 
        print("World selected: " .. option) 
    end
})

local shovelfruit_in = shovelfruit_sec:Input({
    Title = "Weight",
    Placeholder = "e.g 30",
    Value = "",
    Numeric = false,
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local shovelfruit_tgl = shovelfruit_sec:Toggle({
    Title = "Auto Shovel Fruits",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Move Plants
local moveplant_sec = TabPlants:Section({ 
    Title = "Move Plants",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local moveplant_ddm = moveplant_sec:Dropdown({
    Title = "Select Plants",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local moveplantpos_dd = moveplant_sec:Dropdown({
    Title = "Position",
    Values = { "World A", "World B", "World C" },
    Value = "World A",
    Callback = function(option) 
        print("World selected: " .. option) 
    end
})

local moveplant_tgl = moveplant_sec:Toggle({
    Title = "Auto Move Plants",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Shovel Plants
local shovelplant_sec = TabPlants:Section({ 
    Title = "Auto Shovel Plants",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local shovelplant_ddm = shovelplant_sec:Dropdown({
    Title = "Select Plants",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shovelplant_tgl = shovelplant_sec:Toggle({
    Title = "Auto Shovel Plants",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Auto Water Plants
local waterplant_sec = TabPlants:Section({ 
    Title = "Auto Water Plants",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local waterplant_dd = waterplant_sec:Dropdown({
    Title = "Select Plants",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local waterplant_tgl = waterplant_sec:Toggle({
    Title = "Auto Water Plants",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})


--- ==== TAB SPRINKLER === ---
--- Auto Place Sprinkler
local placesprinkler_sec = TabSprinkler:Section({ 
    Title = "Auto Place Sprinkler",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local placesprinkler_ddm = TabSprinkler:Dropdown({
    Title = "Select Sprinkler",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local placesprinklerpos_dd = TabSprinkler:Dropdown({
    Title = "Position",
    Values = { "World A", "World B", "World C" },
    Value = "World A",
    Callback = function(option) 
        print("World selected: " .. option) 
    end
})

local placesprinkler_tgl = TabSprinkler:Toggle({
    Title = "Auto Place Sprinkler",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})
--- Auto Sovel Sprinkler
local shovelsprinkler_sec = TabSprinkler:Section({ 
    Title = "Auto Sovel Sprinkler",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local shovelsprinkler_ddm = TabSprinkler:Dropdown({
    Title = "Select Sprinkler",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shovelsprinkler_tgl = TabSprinkler:Toggle({
    Title = "Auto Sovel Sprinkler",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- ==== TAB INVENTORY === ---
--- Auto Favorite Fruit
local favfruit_sec = TabBackpack:Section({ 
    Title = "Auto Favorite Fruits",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local favfruit_ddm = favfruit_sec:Dropdown({
    Title = "Select Fruits",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local favmutation_ddm = favfruit_sec:Dropdown({
    Title = "Whitelist Mutation",
    Values = { "World A", "World B", "World C" },
    Value = { "World A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Worlds selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local favfruit_tgl = favfruit_sec:Toggle({
    Title = "Auto Favorite Fruit",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Auto Favorite Pets
local favpet_sec = TabBackpack:Section({ 
    Title = "Auto Favorite Pets",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local favpet_ddm = favpet_sec:Dropdown({
    Title = "Select Pet",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local favpet_tgl = favpet_sec:Toggle({
    Title = "Auto Favorite Pet",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Gift Pets and Fruits
local giftpetfruit_sec = TabBackpack:Section({ 
    Title = "Auto Gift Pets & Fruits",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local giftpetfruitplayer_dd = giftpetfruit_sec:Dropdown({
    Title = "Select Player",
    Values = { "World A", "World B", "World C" },
    Value = "World A",
    Callback = function(option) 
        print("World selected: " .. option) 
    end
})

local giftpet_ddm = giftpetfruit_sec:Dropdown({
    Title = "Select Pet",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local giftfruit_ddm = giftpetfruit_sec:Dropdown({
    Title = "Select Fruit",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local giftpetfruit_in = giftpetfruit_sec:Input({
    Title = "Gift Delay",
    Placeholder = "e.g 0.5 (seconds)",
    Value = "",
    Numeric = false,
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local giftpetfruit_tgl = giftpetfruit_sec:Toggle({
    Title = "Auto Gift Pets/Fruits",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

local accgiftpetfruit_tgl = giftpetfruit_sec:Toggle({
    Title = "Auto Accept Gift",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- ==== TAB PET & EGG === ---
--- ==== PET === ---
--- Pet Loadout
local petloadout_sec = TabPet:Section({ 
    Title = "Pet Loadout",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local petloadout_in = petloadout_sec:Input({
    Title = "Loadout Name",
    Placeholder = "Load Out Name",
    Value = "",
    Numeric = false,
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local petloadoutsave_btn = petloadout_sec:Button({
    Title = "Save Loadout",
    Desc = "Save Current Loadout",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})

local petloadout_dd = petloadout_sec:Dropdown({
    Title = "Select Loadout",
    Values = { "World A", "World B", "World C" },
    Value = "World A",
    Callback = function(option) 
        print("World selected: " .. option) 
    end
})

local petloadoutload_btn = petloadout_sec:Button({
    Title = "Change Loadout",
    Desc = "Load Selected Loadout",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})

--- Boost Pets
local boostpet_sec = TabPet:Section({ 
    Title = "Boost Pets",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local boostpetboost_ddm = boostpet_sec:Dropdown({
    Title = "Select Boost",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local boostpetselect_ddm = boostpet_sec:Dropdown({
    Title = "Select Pet",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local boostpet_tgl = boostpet_sec:Toggle({
    Title = "Auto Boost Pet",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Auto Sell Pets
local sellpet_sec = TabPet:Section({ 
    Title = "Auto Sell Pets",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local sellpet_ddm = sellpet_sec:Dropdown({
    Title = "Select Pet",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local sellpetthresh_dd = sellpet_sec:Dropdown({
    Title = "Weight Threshold",
    Values = { "World A", "World B", "World C" },
    Value = "World A",
    Callback = function(option) 
        print("World selected: " .. option) 
    end
})

local sellpetweight_in = sellpet_sec:Input({
    Title = "Weight",
    Placeholder = "e.g 30",
    Value = "",
    Numeric = false,
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local sellpet_tgl = sellpet_sec:Toggle({
    Title = "Auto Sell Pet",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- === EGG === ---
--- Plaace Egg
local placeegg_sec = TabEgg:Section({ 
    Title = "Auto Place Egg",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local placeeggslot_in = TabEgg:Input({
    Title = "Max Egg Slot",
    Placeholder = "e.g 3",
    Value = "Input number of your egg slot",
    Numeric =true,
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local placeeggselect_ddm = TabEgg:Dropdown({
    Title = "Select Egg",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local placeegg_tgl = TabEgg:Toggle({
    Title = "Auto Place Egg",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Hatch Egg
local hatchegg_sec = TabEgg:Section({ 
    Title = "Auto Place Egg",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
})

local hatcheggselect_ddm = TabEgg:Dropdown({
    Title = "Select Egg",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local hatchegg_tgl = TabEgg:Toggle({
    Title = "Auto Hatch Egg",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

---- ==== TAB SHOP & CRAFT === ---
---- ==== SHOP === ---
--- Seed
local shopseed_sec = TabShop:Section({ 
    Title = "Seeds",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local shopseed_ddm = shopseed_sec:Dropdown({
    Title = "Select Seeds",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopseed_tgl = shopseed_sec:Toggle({
    Title = "Auto Buy Seeds",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Gear
local shopgear_sec = TabShop:Section({ 
    Title = "Gears",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local shopgear_ddm = shopgear_sec:Dropdown({
    Title = "Select Gears",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopgear_tgl = shopgear_sec:Toggle({
    Title = "Auto Buy Gears",
    Default = false,
    Callback = function(state) 
         print("Toggle Activated" .. tostring(state))
    end
})

--- Egg
local shopegg_sec = TabShop:Section({ 
    Title = "Eggs",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local shopegg_ddm = shopegg_sec:Dropdown({
    Title = "Select Eggs",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopegg_tgl = shopegg_sec:Toggle({
    Title = "Auto Buy Eggs",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Cosmetic
local shopcosmetic_sec = TabShop:Section({ 
    Title = "Cosmetics",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local shopcosmetic_ddm = shopcosmetic_sec:Dropdown({
    Title = "Select Cosmetics",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopcosmetic_tgl = shopcosmetic_sec:Toggle({
    Title = "Auto Buy Cosmetics",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Merchant
local shopmerchant_sec = TabShop:Section({ 
    Title = "Merchant",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local shopmerchanselect_dd = shopmerchant_sec:Dropdown({
    Title = "Select Merchant",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopmerchant_ddm = shopmerchant_sec:Dropdown({
    Title = "Select Items",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopmerchant_tgl = shopmerchant_sec:Toggle({
    Title = "Auto Buy Merchant Items",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

---- Event
local shopevent_sec = TabShop:Section({ 
    Title = "Event",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local shopevent_ddm = shopevent_sec:Dropdown({
    Title = "Select Event Items",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local shopevent_tgl = shopevent_sec:Toggle({
    Title = "Auto Buy Event Items",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- ==== CRAFT === ---
--- Gear
local craftgear_sec = TabCraft:Section({ 
    Title = "Gears",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local craftgear_ddm = craftgear_sec:Dropdown({
    Title = "Select Gears",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local craftgear_tgl = craftgear_sec:Toggle({
    Title = "Auto Craft Gears",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Seed
local craftseed_sec = TabCraft:Section({ 
    Title = "Seeds",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local craftseed_ddm = craftseed_sec:Dropdown({
    Title = "Select Seeds",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local craftseed_tgl = craftseed_sec:Toggle({
    Title = "Auto Craft Seeds",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Event
local craftevent_sec = TabCraft:Section({ 
    Title = "Event",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local craftevent_ddm = craftevent_sec:Dropdown({
    Title = "Select Event Items",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local craftevent_tgl = craftevent_sec:Toggle({
    Title = "Auto Craft Event Items",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- ==== TAB MISC === ---
--- Server Utils
local servutils_sec = TabMisc:Section({ 
    Title = "Server",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = true
})

local servjoin_in = servutils_sec:Input({
    Title = "Job ID",
    Placeholder = "e.g 0000-000-000",
    Value = "",
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local servjoin_btn = servutils_sec:Button({
    Title = "Join Server",
    Desc = "Join Server by Job ID",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})

local servcopy_btn = servutils_sec:Button({
    Title = "Copy Server ID",
    Desc = "Copy Current Server Job ID",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})

local servrejoin_btn = servutils_sec:Button({
    Title = "Rejoin Server",
    Desc = "Rejoin Current Server",
    Locked = false,
    Callback = function()
        print("clicked")
    end
})


--- Server Hop
local servhop_sec = TabMisc:Section({ 
    Title = "Server Hop",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local servhop_in = servhop_sec:Input({
    Title = "Server Version",
    Placeholder = "e.g 1819",
    Value = "",
    Numeric = false,
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local servhop_tgl = servhop_sec:Toggle({
    Title = "Auto Server Hop",
    Desc = "Auto Server Hop until found desired server version",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
    end
})

--- Webhook
local webhook_sec = TabMisc:Section({ 
    Title = "Discord Webhook",
    TextXAlignment = "Left",
    TextSize = 17, -- Default Size
    Opened = false
})

local webhook_in = webhook_sec:Input({
    Title = "Webhook URL",
    Placeholder = "e.g https://discord.com/api/webhooks/...",
    Value = "",
    Numeric = false,
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local webhookhatch_ddm = webhook_sec:Dropdown({
    Title = "Select Egg",
    Values = { "Category A", "Category B", "Category C" },
    Value = { "Category A" },
    Multi = true,
    AllowNone = true,
    Callback = function(option) 
        print("Categories selected: " ..game:GetService("HttpService"):JSONEncode(option)) 
    end
})

local webhookthershhatch_dd = webhook_sec:Dropdown({
    Title = "Weight Threshold",
    Values = { "Category A", "Category B", "Category C" },
    Value = "Category A",
    Callback = function(option) 
        print("Category selected: " .. option) 
    end
})

local webhookweighthatch_in = webhook_sec:Input({
    Title = "Weight",
    Placeholder = "e.g 3",
    Value = "",
    Numeric = true,
    Callback = function(value) 
        print("Input: " .. tostring(value)) 
    end
})

local webhookhatch_tgl = webhook_sec:Toggle({
    Title = "Webhook on Hatch",
    Default = false,
    Callback = function(state) 
        print("Toggle Activated" .. tostring(state))
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
        print("[GUI] Window destroyed")
        -- Tidak ada cleanup integrasi fitur di sini
    end)
end