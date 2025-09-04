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

-- Buat ikon kustom yang menggantikan tombol bawaan
local Players   = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local iconGui   = Instance.new("ScreenGui")
iconGui.Name    = "DevLogicIconGui"
iconGui.Parent  = PlayerGui

local iconButton        = Instance.new("ImageButton")
iconButton.Name         = "DevLogicOpenButton"
iconButton.Size         = UDim2.fromOffset(40, 40)
iconButton.Position     = UDim2.new(0, 10, 0.5, -20)
iconButton.BackgroundTransparency = 1
iconButton.Image        = "rbxassetid://73063950477508"
iconButton.Draggable    = true
iconButton.Parent       = iconGui

-- Variable untuk track status window
local isWindowOpen = true -- Window mulai dalam keadaan terbuka

-- Fungsi untuk toggle window dan ikon
local function toggleWindow()
    if isWindowOpen then
        -- Tutup window, tampilkan ikon
        Window:Close()
        iconButton.Visible = true
        isWindowOpen = false
    else
        -- Buka window, sembunyikan ikon
        Window:Open()
        iconButton.Visible = false
        isWindowOpen = true
    end
end

-- Klik ikon untuk membuka window
iconButton.MouseButton1Click:Connect(toggleWindow)

-- Sembunyikan ikon di awal karena window sudah terbuka
iconButton.Visible = false

-- SOLUSI ALTERNATIF 3: Coba hook ke method Close dan Open
if Window.Close then
    local originalClose = Window.Close
    Window.Close = function(self)
        local result = originalClose(self)
        iconButton.Visible = true
        isWindowOpen = false
        return result
    end
end

if Window.Open then
    local originalOpen = Window.Open
    Window.Open = function(self)
        local result = originalOpen(self)
        iconButton.Visible = false
        isWindowOpen = true
        return result
    end
end
