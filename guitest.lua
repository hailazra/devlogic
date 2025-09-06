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

-- IMPROVED DRAG SYSTEM (Lebih akurat dan tidak mudah trigger toggle)
local function makeDraggable(gui)
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    local dragDistance = 0
    local hasDraggedFar = false
    local dragStartTime = 0
    
    -- Konstanta untuk kontrol drag
    local MIN_DRAG_DISTANCE = 8     -- Minimum pixel untuk dianggap drag (lebih kecil)
    local TOGGLE_MAX_DISTANCE = 5   -- Maximum pixel untuk dianggap click
    local TOGGLE_MAX_TIME = 0.5     -- Maximum time untuk dianggap click (detik)

    local function updateInput(input)
        if not isDragging or not dragStart then return end
        
        local Delta = input.Position - dragStart
        dragDistance = math.sqrt(Delta.X^2 + Delta.Y^2)
        
        -- Mark sebagai drag jika sudah bergerak > MIN_DRAG_DISTANCE
        if dragDistance > MIN_DRAG_DISTANCE then
            hasDraggedFar = true
        end
        
        -- Update posisi hanya jika sudah dianggap drag
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

    -- Connection variables untuk cleanup
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
            
            print("Drag started at:", dragStart) -- Debug
            
            -- Cleanup previous connections
            if inputChangedConnection then
                inputChangedConnection:Disconnect()
            end
            if inputEndedConnection then
                inputEndedConnection:Disconnect()
            end
            
            -- Track input end untuk detect click vs drag
            inputEndedConnection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    local dragEndTime = tick()
                    local dragDuration = dragEndTime - dragStartTime
                    
                    isDragging = false
                    
                    print("Drag ended - Distance:", dragDistance, "Duration:", dragDuration, "HasDraggedFar:", hasDraggedFar)
                    
                    -- Kondisi untuk toggle window (harus memenuhi SEMUA kriteria):
                    -- 1. Jarak drag kecil (< TOGGLE_MAX_DISTANCE)
                    -- 2. Durasi pendek (< TOGGLE_MAX_TIME)
                    -- 3. Tidak pernah drag jauh
                    local isClick = (dragDistance < TOGGLE_MAX_DISTANCE) and 
                                  (dragDuration < TOGGLE_MAX_TIME) and 
                                  (not hasDraggedFar)
                    
                    if isClick then
                        print("Detected CLICK - Toggling window")
                        -- Small delay untuk memastikan drag benar-benar selesai
                        wait(0.1)
                        toggleWindow()
                    else
                        print("Detected DRAG - No toggle")
                    end
                    
                    -- Cleanup connections
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

    -- Track mouse/touch movement
    gui.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if isDragging then
                updateInput(input)
            end
        end
    end)
    
    -- Tambahan: Track global input ended untuk cleanup jika input berubah di luar gui
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            if isDragging then
                local dragEndTime = tick()
                local dragDuration = dragEndTime - dragStartTime
                
                isDragging = false
                
                print("Global input ended - Distance:", dragDistance, "Duration:", dragDuration)
                
                -- Reset connections
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