
-- load the latest version of WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- create a window
local window = WindUI:CreateWindow({
    Title  = "Pivot & CFrame Detector",
    Author = "PivotHelper",
    Folder = "PivotDetector",
    -- optional UI adjustments
    Theme = "Dark",
    Size  = UDim2.fromOffset(540, 400),
    Resizable = true,
})

-- create a tab
local tab = window:Tab({
    Title = "Detector",
    Icon  = "compass",
})

-- helper function to fetch pivot and CFrame strings
local function getValues()
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    -- ensure HumanoidRootPart exists
    local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
    local pivotCFrame = character:GetPivot() -- world pivot as CFrame【563157844627578†L84-L97】
    local cframe      = hrp.CFrame
    return tostring(pivotCFrame), tostring(cframe)
end

-- create read‑only inputs for pivot and CFrame
local pivotInput = tab:Input({
    Title   = "Character Pivot (CFrame)",
    Desc    = "Current model pivot as CFrame",
    Value   = "", -- initial empty value
    Type    = "Textarea",
    Placeholder = "Click 'Refresh' to populate",
    -- Lock input so it can't be edited; user can still select text for manual copying
    Locked  = true,
})

local cframeInput = tab:Input({
    Title   = "HumanoidRootPart CFrame",
    Desc    = "Current HRP CFrame",
    Value   = "",
    Type    = "Textarea",
    Placeholder = "Click 'Refresh' to populate",
    Locked  = true,
})

-- function to refresh display values
local function refreshValues()
    local pivotStr, cframeStr = getValues()
    pivotInput:Set(pivotStr)
    cframeInput:Set(cframeStr)
    -- optionally display a notification
    WindUI:Notification({
        Title = "Updated",
        Desc = "Pivot and CFrame values have been refreshed.",
        Duration = 2,
    })
end

-- function to copy text to clipboard (if supported)
local function copyToClipboard(text)
    if typeof(setclipboard) == "function" then
        -- use exploit's clipboard function
        setclipboard(text)
        WindUI:Notification({
            Title = "Copied",
            Desc  = "Value has been copied to your clipboard.",
            Duration = 2,
        })
    else
        -- fallback: print to console
        warn("Clipboard API not available. Value:\n" .. text)
        WindUI:Notification({
            Title = "Clipboard Unavailable",
            Desc  = "Value printed to console instead.",
            Duration = 3,
        })
    end
end

-- add a button to refresh values
tab:Button({
    Title = "Refresh Values",
    Desc  = "Fetch current pivot and CFrame",
    Callback = function()
        refreshValues()
    end,
})

-- add a button to copy pivot
tab:Button({
    Title = "Copy Pivot",
    Desc  = "Copy the character's pivot CFrame",
    Callback = function()
        local pivotStr, _ = getValues()
        copyToClipboard(pivotStr)
    end,
})

-- add a button to copy CFrame
tab:Button({
    Title = "Copy CFrame",
    Desc  = "Copy the HumanoidRootPart's CFrame",
    Callback = function()
        local _, cframeStr = getValues()
        copyToClipboard(cframeStr)
    end,
})

-- prefill values on load
refreshValues()