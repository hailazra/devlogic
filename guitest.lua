--==================================================
-- DevLogic GUI Test (Patched: drag sensitivity fix)
--==================================================

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

-- Nonaktifkan tombol open bawaan
Window:EditOpenButton({ Enabled = false })

-- (Opsional) Tambah contoh konten agar window tidak kosong
do
    local Tab = Window:Tab({ Title = "Main", Icon = "rbxassetid://0" })
    local Sec = Tab:Section({ Title = "Info" })
    Sec:Label({ Title = "Drag icon di kiri layar untuk pindah posisi.\nTap singkat pada icon untuk buka/tutup window." })
end

--========== SERVICES ==========
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--========== FLOATING ICON ==========
local iconGui = Instance.new("ScreenGui")
iconGui.Name = "DevLogicIconGui"
iconGui.ResetOnSpawn = false
iconGui.IgnoreGuiInset = true
iconGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
iconGui.Parent = PlayerGui

local iconButton = Instance.new("ImageButton")
iconButton.Name = "DevLogicOpenButton"
iconButton.Size = UDim2.fromOffset(40, 40)
iconButton.Position = UDim2.new(0, 10, 0.5, -20) -- default: kiri tengah
iconButton.BackgroundTransparency = 1
iconButton.Image = "rbxassetid://73063950477508"
iconButton.Active = true
iconButton.AutoButtonColor = false
iconButton.Parent = iconGui
iconButton.Visible = true

-- Restore posisi jika sebelumnya pernah disimpan
getgenv()._devlogic_icon_pos = getgenv()._devlogic_icon_pos or iconButton.Position
iconButton.Position = getgenv()._devlogic_icon_pos

--========== TOGGLE WINDOW (dengan debounce) ==========
local isWindowOpen = false
local lastToggleAt = 0
local TOGGLE_DEBOUNCE = 0.15

local function openWindow()
    if isWindowOpen then return end
    local ok = pcall(function() Window:Open() end)
    if ok then
        isWindowOpen = true
        iconButton.Visible = false
    end
end

local function closeWindow()
    if not isWindowOpen then return end
    local ok = pcall(function() Window:Close() end)
    if ok then
        isWindowOpen = false
        iconButton.Visible = true
    end
end

local function safeToggleWindow()
    local now = tick()
    if now - lastToggleAt < TOGGLE_DEBOUNCE then return end
    lastToggleAt = now
    if isWindowOpen then closeWindow() else openWindow() end
end

-- Sinkronkan visibilitas jika user menutup/ membuka via kontrol internal WindUI
if Window.Close then
    local originalClose = Window.Close
    Window.Close = function(self, ...)
        local result = originalClose(self, ...)
        isWindowOpen = false
        iconButton.Visible = true
        return result
    end
end
if Window.Open then
    local originalOpen = Window.Open
    Window.Open = function(self, ...)
        local result = originalOpen(self, ...)
        isWindowOpen = true
        iconButton.Visible = false
        return result
    end
end

--========== UTIL: CLAMP KE VIEWPORT ==========
local function clampToViewport(gui, targetPos)
    local cam = workspace.CurrentCamera
    if not cam then return targetPos end
    local vps = cam.ViewportSize
    local x = math.clamp(targetPos.X.Offset, 0, vps.X - gui.AbsoluteSize.X)
    local y = math.clamp(targetPos.Y.Offset, 0, vps.Y - gui.AbsoluteSize.Y)
    return UDim2.new(targetPos.X.Scale, x, targetPos.Y.Scale, y)
end

--========== PATCH DRAG SENSITIVITY ==========
-- Tweakable thresholds
local CLICK_MAX_DISTANCE       = 8      -- klik = gerak <= 8 px
local CLICK_MAX_DURATION       = 0.18   -- dan durasi <= 180 ms
local DRAG_ACTIVATION_DISTANCE = 10     -- mulai drag jika geser >= 10 px
local LONG_PRESS_TO_DRAG       = 0.15   -- atau tahan >= 150 ms

local function makeDraggable(guiButton: Instance)
    local pressing = false
    local dragging = false
    local pressPos: Vector2? = nil
    local startPos: UDim2? = nil
    local pressTick = 0
    local movementDelta = Vector2.zero
    local trackedInput -- input yang sedang ditrack (supaya multi-touch aman)

    -- Koneksi global agar gerakan tetap terbaca meski pointer keluar dari tombol
    local moveConn, endConn

    local function cleanup()
        if moveConn then moveConn:Disconnect() moveConn = nil end
        if endConn  then endConn:Disconnect()  endConn  = nil end
        pressing = false
        dragging = false
        trackedInput = nil
        movementDelta = Vector2.zero
    end

    guiButton.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        -- Ambil fokus di input pertama saja (multi-touch safe)
        if pressing then return end
        pressing = true
        dragging = false
        trackedInput = input
        pressPos  = input.Position
        startPos  = guiButton.Position
        pressTick = tick()
        movementDelta = Vector2.zero

        moveConn = UIS.InputChanged:Connect(function(changed)
            if not pressing or not trackedInput then return end
            -- Hanya respons ke gerakan tipe yang sama (mouse/touch) agar stabil
            if changed.UserInputType ~= Enum.UserInputType.MouseMovement
                and changed.UserInputType ~= Enum.UserInputType.Touch then
                return
            end

            local delta = changed.Position - pressPos
            movementDelta = Vector2.new(delta.X, delta.Y)

            -- Promosi ke mode drag
            if (not dragging) and (
                movementDelta.Magnitude >= DRAG_ACTIVATION_DISTANCE
                or (tick() - pressTick) >= LONG_PRESS_TO_DRAG
            ) then
                dragging = true
            end

            if dragging then
                local newPos = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + movementDelta.X,
                    startPos.Y.Scale, startPos.Y.Offset + movementDelta.Y
                )
                guiButton.Position = clampToViewport(guiButton, newPos)
                -- Persist posisi sementara ke global (agar kebawa selama session executor)
                getgenv()._devlogic_icon_pos = guiButton.Position
            end
        end)

        -- Lepas (gunakan UIS.InputEnded agar lebih konsisten di mobile)
        endConn = UIS.InputEnded:Connect(function(ended)
            if not pressing or not trackedInput then return end
            if ended ~= trackedInput then return end

            local dt   = tick() - pressTick
            local dist = movementDelta.Magnitude
            local wasDrag = dragging or dist >= DRAG_ACTIVATION_DISTANCE or dt >= LONG_PRESS_TO_DRAG
            cleanup()

            -- Klik valid: cepat & hampir tidak bergerak
            if (not wasDrag) and dist <= CLICK_MAX_DISTANCE and dt <= CLICK_MAX_DURATION then
                safeToggleWindow()
            end
        end)
    end)
end

makeDraggable(iconButton)

--========== (Opsional) ANIMASI MUNCUL/HILANG ICON ==========
local function animateIconVisible(v)
    if v then
        iconButton.Visible = true
        iconButton.ImageTransparency = 1
        TweenService:Create(iconButton, TweenInfo.new(0.15), { ImageTransparency = 0 }):Play()
    else
        local t = TweenService:Create(iconButton, TweenInfo.new(0.12), { ImageTransparency = 1 })
        t.Completed:Connect(function() iconButton.Visible = false end)
        t:Play()
    end
end

-- Sinkronkan animasi dengan toggle
local oldOpen = openWindow
openWindow = function()
    if isWindowOpen then return end
    local ok = pcall(function() Window:Open() end)
    if ok then
        isWindowOpen = true
        animateIconVisible(false)
    end
end

local oldClose = closeWindow
closeWindow = function()
    if not isWindowOpen then return end
    local ok = pcall(function() Window:Close() end)
    if ok then
        isWindowOpen = false
        animateIconVisible(true)
    end
end

--========== QUICK TIPS ==========
-- Jika user banyak di HP/jari besar, kamu bisa:
-- 1) Naikkan DRAG_ACTIVATION_DISTANCE ke 12–16, atau
-- 2) Ubah pola interaksi: double-tap untuk open (hampir nol false-open).
--    (Ganti safeToggleWindow() dengan deteksi double-tap kalau mau.)

-- Selesai. Tap singkat pada icon => buka/tutup window.
-- Long-press atau geser >=10px => mode drag (tidak membuka window).
