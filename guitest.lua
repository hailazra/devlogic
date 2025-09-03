-- WindUI Library
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()


-- Custom Theme: DarkPurple
WindUI.Themes["DarkRedDL"] = {
     Accent      = "#5A0F0F",  -- oxblood/ruby gelap
    Dialog      = "#5A0F0F",
    Outline     = "#5A0F0F",
    Text        = "#F4F4F5",
    Placeholder = "#5A0F0F",
    Background  = "#09090B",
    Button      = "#1A1A1E",
    Icon        = "#5A0F0F",

}

Theme = "DarkRedDL"
--========== WINDOW ==========
local Window = WindUI:CreateWindow({
    Title         = ".devlogic",
    Icon          = "rbxassetid://73063950477508",
    Author        = "Grow A Garden",
    Folder        = ".devlogichub",
    Size          = UDim2.fromOffset(250, 250),
    Theme         = "DarkRedDL",
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
        for _, feature in pairs(FeatureManager.LoadedFeatures) do
            if feature.Cleanup then
                pcall(feature.Cleanup, feature)
            end
        end
        FeatureManager.LoadedFeatures = {}
    end)
end