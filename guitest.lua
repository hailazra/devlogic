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

-- Buat ikon kustom
local Players   = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Tunggu WindUI selesai load
wait(1)

-- Cari dan ganti tombol bawaan WindUI
local function replaceDefaultButton()
    local windUIGui = PlayerGui:FindFirstChild("WindUI")
    if windUIGui then
        -- Cari tombol minimize/open bawaan
        local defaultButton = windUIGui:FindFirstChild("OpenButton") or 
                             windUIGui:FindFirstDescendant("OpenButton")
        
        if defaultButton then
            -- Ganti image tombol bawaan
            if defaultButton:IsA("ImageButton") or defaultButton:IsA("ImageLabel") then
                defaultButton.Image = "rbxassetid://73063950477508"
                defaultButton.Size = UDim2.fromOffset(40, 40)
            end
            
            -- Atau buat tombol baru mengganti yang lama
            local newButton = defaultButton:Clone()
            newButton.Image = "rbxassetid://73063950477508"
            newButton.Size = UDim2.fromOffset(40, 40)
            newButton.Position = UDim2.new(0, 10, 0.5, -20)
            newButton.Parent = defaultButton.Parent
            
            -- Hapus tombol lama
            defaultButton:Destroy()
            
            print("Berhasil mengganti tombol WindUI!")
            return true
        end
    end
    return false
end

-- Coba ganti tombol beberapa kali sampai berhasil
spawn(function()
    for i = 1, 10 do
        if replaceDefaultButton() then
            break
        end
        wait(0.5)
    end
end)

-- Atau langsung disable dan buat sendiri seperti script asli kamu
Window:EditOpenButton({ Enabled = false })

local iconGui   = Instance.new("ScreenGui")
iconGui.Name    = "DevLogicIconGui"
iconGui.Parent  = PlayerGui

local iconButton        = Instance.new("ImageButton")
iconButton.Name         = "DevLogicOpenButton"
iconButton.Size         = UDim2.fromOffset(40, 40)
iconButton.Position     = UDim2.new(0, 10, 0.5, -20)
iconButton.BackgroundTransparency = 1
iconButton.Image        = "rbxassetid://73063950477508"
iconButton.Parent       = iconGui
iconButton.Visible      = false -- Mulai hidden

-- Fungsi toggle sederhana
iconButton.MouseButton1Click:Connect(function()
    -- Langsung panggil toggle WindUI
    pcall(function()
        Window:Toggle()
    end)
    
    -- Force show/hide ikon berdasarkan window state
    wait(0.1)
    local windUIGui = PlayerGui:FindFirstChild("WindUI")
    if windUIGui then
        local mainFrame = windUIGui:FindFirstChild("Frame") or windUIGui:FindFirstChild("Main")
        if mainFrame then
            iconButton.Visible = not mainFrame.Visible
        end
    end
end)