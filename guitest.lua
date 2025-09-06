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

-- Services
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")

-- Buat ikon kustom
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
iconButton.Visible = false -- Mulai hidden karena window terbuka

-- Variable untuk track status
local isWindowOpen = true
local windowDestroyed = false

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

-- DRAG SYSTEM (Fixed dan lebih responsive)
local function makeDraggable(gui)
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    local dragDistance = 0
    local hasDraggedFar = false

    local function updateInput(input)
        local Delta = input.Position - dragStart
        dragDistance = math.sqrt(Delta.X^2 + Delta.Y^2)
        
        -- Mark sebagai drag jika sudah bergerak > 15 pixel
        if dragDistance > 15 then
            hasDraggedFar = true
        end
        
        -- Update posisi langsung tanpa tween (lebih responsive)
        local Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + Delta.X, startPos.Y.Scale, startPos.Y.Offset + Delta.Y)
        gui.Position = Position
    end

    gui.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isDragging = true
            dragDistance = 0
            hasDraggedFar = false
            dragStart = input.Position
            startPos = gui.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                    
                    -- Hanya toggle jika TIDAK pernah drag jauh
                    if not hasDraggedFar then
                        print("Detected click, distance:", dragDistance)
                        wait(0.05) -- Small delay untuk memastikan drag selesai
                        toggleWindow()
                    else
                        print("Detected drag, distance:", dragDistance)
                    end
                end
            end)
        end
    end)

    gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if isDragging then
                updateInput(input)
            end
        end
    end)
end

-- Apply drag system ke icon
makeDraggable(iconButton)

-- Monitor WindUI visibility dengan RunService
local RunService = game:GetService("RunService")
local lastVisible = nil

RunService.Heartbeat:Connect(function()
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

-- Backup: Override methods jika tersedia
if Window.Toggle then
    local originalToggle = Window.Toggle
    Window.Toggle = function(self)
        local result = originalToggle(self)
        iconButton.Visible = not iconButton.Visible
        isWindowOpen = not isWindowOpen
        return result
    end
end

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