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
iconButton.Parent       = iconGui

-- Buat ikon draggable
local UserInputService = game:GetService("UserInputService")
local isDragging = false
local dragStart = nil
local startPos = nil
local hasMoved = false


-- Klik ikon untuk membuka window (dengan delay untuk membedakan drag dan click)
local clickStartTime = 0
iconButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        clickStartTime = tick()
    end
end)

iconButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        -- Jika waktu click kurang dari 0.2 detik dan tidak sedang drag, anggap sebagai click
        local clickDuration = tick() - clickStartTime
        if clickDuration < 0.2 and not dragging then
            toggleWindow()
        end
    end
end)

iconButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        hasMoved = false
        dragStart = input.Position
        startPos = iconButton.Position
    end
end)

        
        

-- Variable untuk track status window
local isWindowOpen = true -- Window mulai dalam keadaan terbuka

-- Fungsi untuk toggle window dan ikon
local function toggleWindow()
    print("Toggle window called!") -- Debug
    if isWindowOpen then
        -- Tutup window, tampilkan ikon
        Window:Close()
        iconButton.Visible = true
        isWindowOpen = false
        print("Window closed")
    else
        -- Buka window, sembunyikan ikon
        Window:Open()
        iconButton.Visible = false
        isWindowOpen = true
        print("Window opened")
    end
end

-- Klik ikon untuk membuka window (dengan delay untuk membedakan drag dan click)
local clickStartTime = 0
iconButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        clickStartTime = tick()
    end
end)

iconButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        -- Jika waktu click kurang dari 0.2 detik dan tidak sedang drag, anggap sebagai click
        local clickDuration = tick() - clickStartTime
        if clickDuration < 0.2 and not dragging then
            toggleWindow()
        end
    end
end)

-- Sembunyikan ikon di awal karena window sudah terbuka
iconButton.Visible = false

-- SOLUSI ALTERNATIF 1: Gunakan RunService untuk monitor visibility
local RunService = game:GetService("RunService")
local lastVisible = nil

RunService.Heartbeat:Connect(function()
    -- Cari WindUI main frame untuk cek visibility
    local windUIFrame = PlayerGui:FindFirstChild("WindUI")
    if windUIFrame then
        local mainFrame = windUIFrame:FindFirstChild("Frame") or windUIFrame:FindFirstChild("Main")
        if mainFrame and mainFrame.Visible ~= lastVisible then
            lastVisible = mainFrame.Visible
            if mainFrame.Visible then
                -- Window terbuka, sembunyikan ikon
                iconButton.Visible = false
                isWindowOpen = true
            else
                -- Window tertutup, tampilkan ikon
                iconButton.Visible = true
                isWindowOpen = false
            end
        end
    end
end)

-- SOLUSI ALTERNATIF 2: Override Toggle function (jika tersedia)
if Window.Toggle then
    local originalToggle = Window.Toggle
    Window.Toggle = function(self)
        local result = originalToggle(self)
        -- Toggle ikon visibility
        iconButton.Visible = not iconButton.Visible
        isWindowOpen = not isWindowOpen
        return result
    end
end

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