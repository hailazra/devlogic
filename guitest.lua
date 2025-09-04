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

-- Nonaktifkan tombol open bawaan
Window:EditOpenButton({ Enabled = false })

-- Buat ikon kustom
local Players     = game:GetService("Players")
local PlayerGui   = Players.LocalPlayer:WaitForChild("PlayerGui")
local iconGui     = Instance.new("ScreenGui", PlayerGui)
iconGui.Name      = "DevLogicIconGui"

local iconButton  = Instance.new("ImageButton")
iconButton.Name   = "DevLogicOpenButton"
iconButton.Size   = UDim2.fromOffset(40, 40)
iconButton.Position = UDim2.new(0, 10, 0.5, -20)
iconButton.BackgroundTransparency = 1
iconButton.Image  = "rbxassetid://73063950477508" -- ganti dengan asset ID ikon Anda
iconButton.Active = true      -- agar bisa menerima input
iconButton.Draggable = true   -- membuat ikon bisa dipindah
iconButton.Parent = iconGui

-- Awalnya jendela terbuka, jadi sembunyikan ikon
iconButton.Visible = false

-- Klik ikon untuk membuka jendela
iconButton.MouseButton1Click:Connect(function()
    -- buka jendela WindUI
    Window:Toggle()
    -- sembunyikan ikon
    iconButton.Visible = false
end)

-- Tampilkan kembali ikon ketika jendela WindUI ditutup
if type(Window.OnClose) == "function" then
    Window:OnClose(function()
        iconButton.Visible = true
    end)
end
-- … sisanya tetap sama (Tag, Changelog, Tabs, dsb.)

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



