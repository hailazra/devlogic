-- WindUI Teleport Hub — by you + gpt
-- Requires: WindUI (auto-loaded from releases)
-- Notes:
--  - Soft Teleport: lebih “ramah” anti-cheat (hop kecil bertahap)
--  - Hard Teleport: langsung set CFrame (risiko rubberband/flag tergantung game)
--  - Y Offset: tambahin ketinggian supaya gak spawn nembus lantai

--================= WINDUI =================
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title         = ".devlogic | Teleport",
    Icon          = "map",
    Author        = "logicdev",
    Folder        = ".devlogichub",
    Theme = "Dark",
    Size  = UDim2.fromOffset(540, 400),
    Resizable = true,
})

local Tab = Window:Tab({ Title = "Teleport", Icon = "map" })
local Header = Tab:Section({ Title = "Select Island & Teleport" })

--================= DATA ===================
-- Masukin CFrame & Pivot yang kamu kasih (exact)
local Islands = {
  ["Fisherman Island"] = {
      CFrame = CFrame.new(33.4889145, 9.78529263, 2808.38818, 0.999970615, 0, 0.00766801229, 0, 1, 0, -0.00766801229, 0, 0.999970615),
      Pivot  = CFrame.new(33.4889069, 11.2543802, 2808.38745, 0.999946415, -1.21293378e-05, 0.0103534162, -4.36976097e-06, 0.999998748, 0.00159240642, -0.0103534218, -0.00159236626, 0.999945164)
  },
  ["Esoteric Depths"] = {
      CFrame = CFrame.new(2023.6178, 27.3971195, 1395.06812, 0.385756761, 1.05182835e-07, -0.922600508, -1.02617278e-07, 1, 7.11006791e-08, 0.922600508, 6.72471856e-08, 0.385756761),
      Pivot  = CFrame.new(2023.61975, 28.8889542, 1395.06726, 0.388359666, 0.00389935751, -0.92149961, -1.18578637e-05, 0.999991059, 0.00422650622, 0.921507835, -0.00163049297, 0.388356239)
  },
  ["Enchant Altar"] = {
      CFrame = CFrame.new(3232.21899, -1302.85486, 1400.52661, 0.435549557, -5.62926949e-08, -0.900164723, -1.01161399e-08, 1, -6.74307401e-08, 0.900164723, 3.84756227e-08, 0.435549557),
      Pivot  = CFrame.new(3232.21997, -1301.38416, 1400.52612, 0.438252181, 0.00210453011, -0.898849547, -7.25453219e-06, 0.999997258, 0.00233782805, 0.89885205, -0.00101805944, 0.438250989)
  },
  ["Kohana"] = {
      CFrame = CFrame.new(-641.098267, 16.0354462, 611.625916, 0.999887645, 1.07221638e-07, -0.0149896732, -1.06285079e-07, 1, 6.32765662e-08, 0.0149896732, -6.16762748e-08, 0.999887645),
      Pivot  = CFrame.new(-641.098267, 17.5078163, 611.62439, 0.999931991, 4.6239431e-05, -0.011666215, -1.02412196e-05, 0.999995232, 0.00308352546, 0.0116663026, -0.00308319577, 0.999927223)
  },
  ["Kohana Volcano"] = {
      CFrame = CFrame.new(-530.639709, 24.0000591, 169.182816, 0.60094595, -1.06010241e-07, 0.799289644, 6.39355164e-08, 1, 8.45606465e-08, -0.799289644, 2.86618757e-10, 0.60094595),
      Pivot  = CFrame.new(-530.640808, 25.4716072, 169.182007, 0.598413885, -0.00216652406, 0.801184177, -8.82031964e-06, 0.999996305, 0.002710714, -0.801187098, -0.00162917806, 0.598411679)
  },
  ["Tropical Grove"] = {
      CFrame = CFrame.new(-2096.33252, 6.2707715, 3699.2312, 0.870488882, -2.185838e-08, -0.492188066, 1.7358655e-08, 1, -1.37099292e-08, 0.492188066, 3.39061867e-09, 0.870488882),
      Pivot  = CFrame.new(-2096.33154, 7.74807262, 3699.22925, 0.872346461, 0.00211998471, -0.488883644, -1.64255925e-05, 0.999990702, 0.00430704001, 0.488888234, -0.00374920317, 0.872338355)
  },
  ["Crater Island"] = {
      CFrame = CFrame.new(1012.39233, 22.8119335, 5079.95361, 0.224941075, -5.15924121e-08, -0.974372387, -1.26314745e-08, 1, -5.58654492e-08, 0.974372387, 2.48741934e-08, 0.224941075),
      Pivot  = CFrame.new(1012.38928, 24.281353, 5079.9541, 0.22401166, -0.00612191297, -0.974567235, -6.15271347e-06, 0.999980271, -0.00628296286, 0.974586427, 0.00141344953, 0.224007189)
  },
  ["Coral Reefs"] = {
      CFrame = CFrame.new(-3201.69507, 4.62324762, 2108.83252, 0.961145103, 1.20140157e-07, 0.276043564, -1.19486756e-07, 1, -1.91855563e-08, -0.276043564, -1.45434447e-08, 0.961145103),
      Pivot  = CFrame.new(-3201.69409, 6.09415054, 2108.83569, 0.961477041, 0.00186939933, 0.274878711, -8.08853201e-06, 0.999977052, -0.00677237194, -0.274885058, 0.00650925701, 0.961455047)
  },
}

local IslandOrder = {
  "Fisherman Island","Esoteric Depths","Enchant Altar","Kohana",
  "Kohana Volcano","Tropical Grove","Crater Island","Coral Reefs"
}

--================= SERVICES =================
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP = Char:WaitForChild("HumanoidRootPart")

--================= TELEPORT UTILS ===========
local function getTargetCF(name, usePivot, yOffset)
    local info = Islands[name]
    if not info then return end
    local cf = usePivot and info.Pivot or info.CFrame
    if yOffset and yOffset ~= 0 then
        cf = CFrame.new(cf.Position + Vector3.new(0, yOffset, 0)) * (cf - cf.Position)
    end
    return cf
end

local function softTeleport(targetCF, step, delayPerStep)
    step = step or 35
    delayPerStep = delayPerStep or 0.05
    local start = HRP.Position
    local finish = targetCF.Position
    local delta = finish - start
    local dist = delta.Magnitude
    if dist < 1 then Char:PivotTo(targetCF) return end
    local dir = delta.Unit
    for d = 0, dist, step do
        local p = start + dir * math.min(d, dist)
        -- Hadapkan karakter ke arah tujuan
        local look = (finish - p).Magnitude > 1 and (finish - p).Unit or HRP.CFrame.LookVector
        Char:PivotTo(CFrame.new(p, p + look))
        task.wait(delayPerStep)
    end
    Char:PivotTo(targetCF)
end

local function hardTeleport(targetCF)
    Char:PivotTo(targetCF)
end

--================= STATE =====================
local SelectedIsland = IslandOrder[1]
local UseKind        = "Pivot"   -- "Pivot" | "CFrame"
local MethodKind     = "Soft"    -- "Soft"  | "Hard"
local YOffset        = 6
local StepStuds      = 35
local StepDelay      = 0.05

--================= UI CONTROLS ===============
Tab:Dropdown({
    Title   = "Select Island",
    Values  = IslandOrder,
    Value   = SelectedIsland,
    Callback = function(v) SelectedIsland = v end
})

Tab:Dropdown({
    Title   = "Use",
    Values  = { "Pivot", "CFrame" },
    Value   = UseKind,
    Callback = function(v) UseKind = v end
})

Tab:Dropdown({
    Title   = "Method",
    Values  = { "Soft", "Hard" },
    Value   = MethodKind,
    Callback = function(v) MethodKind = v end
})

Tab:Slider({
    Title = "Y Offset (studs)",
    Step  = 1,
    Value = { Min = 0, Max = 20, Default = YOffset },
    Callback = function(v) YOffset = v end
})

Tab:Slider({
    Title = "Soft Step (studs)",
    Step  = 1,
    Value = { Min = 10, Max = 60, Default = StepStuds },
    Callback = function(v) StepStuds = v end
})

Tab:Slider({
    Title = "Soft Delay (sec)",
    Step  = 0.005, -- float supported
    Value = { Min = 0, Max = 0.2, Default = StepDelay },
    Callback = function(v) StepDelay = v end
})

Tab:Button({
    Title = "Teleport",
    Desc  = "Teleport to selected island",
    Callback = function()
        local cf = getTargetCF(SelectedIsland, UseKind == "Pivot", YOffset)
        if not cf then
            warn("Island not found: " .. tostring(SelectedIsland))
            return
        end
        if MethodKind == "Soft" then
            softTeleport(cf, StepStuds, StepDelay)
        else
            hardTeleport(cf)
        end
    end
})

