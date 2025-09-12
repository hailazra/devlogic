-- ===========================
-- AUTO TELEPORT PLAYER FEATURE
-- API disamakan dengan AutoTeleportIsland:
--   :Init(guiControls) -> bool
--   :SetTarget(playerName) -> bool
--   :Teleport(optionalPlayerName) -> bool
--   :GetPlayerList(excludeSelf) -> {string}
--   :GetStatus() -> table
--   :Cleanup() -> ()
-- ===========================

local AutoTeleportPlayer = {}
AutoTeleportPlayer.__index = AutoTeleportPlayer

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- State
local isInitialized = false
local controls = {}
local selectedPlayerName = nil

-- Settings (boleh lu ubah sesuai preferensi)
local SETTINGS = {
    yOffset = 6,        -- naik 6 stud biar ga nyangkut
    behindDist = 3,     -- spawn 3 stud di belakang target
    excludeSelf = true, -- dropdown ga nampilin diri sendiri
    notify = true,      -- pake _G.WindUI:Notify kalau ada
}

-- ===== Helpers =====
local function getCharacter(player)
    return player and player.Character or nil
end

local function getHRP(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso") -- R6 fallback
end

local function getTargetCFrame(targetPlayer)
    local char = getCharacter(targetPlayer)
    if not char then return nil end

    -- Prioritas HRP; fallback ke Pivot
    local hrp = getHRP(char)
    if hrp then
        return hrp.CFrame
    end

    if char.PrimaryPart then
        return char.PrimaryPart.CFrame
    end

    -- Roblox modern model biasanya punya Pivot
    local ok, pivot = pcall(function()
        return char:GetPivot()
    end)
    if ok and typeof(pivot) == "CFrame" then
        return pivot
    end

    return nil
end

local function tpNotify(title, content, icon, duration)
    if SETTINGS.notify and _G.WindUI and _G.WindUI.Notify then
        _G.WindUI:Notify({
            Title = title, Content = content, Icon = icon or "map-pin", Duration = duration or 2
        })
    end
end

-- Hard teleport to CFrame (sedikit di belakang target + offset Y)
function AutoTeleportPlayer:TeleportToPosition(baseCF)
    if not LocalPlayer or not LocalPlayer.Character then
        warn("[AutoTeleportPlayer] Local character not found")
        return false
    end
    local myHRP = getHRP(LocalPlayer.Character)
    if not myHRP then
        warn("[AutoTeleportPlayer] Local HumanoidRootPart not found")
        return false
    end

    -- Posisi di belakang target + offset Y
    local behind = baseCF.Position - (baseCF.LookVector * SETTINGS.behindDist)
    local final = CFrame.new(behind) * CFrame.Angles(0, baseCF:ToEulerAnglesYXZ())
    final = final + Vector3.new(0, SETTINGS.yOffset, 0)

    local ok = pcall(function()
        myHRP.CFrame = final
        -- -- Soft teleport alternative (lebih aman anti-cheat, tapi bisa lambat):
        -- LocalPlayer.Character:PivotTo(final)
    end)
    return ok
end

-- ===== Public API =====

function AutoTeleportPlayer:Init(guiControls)
    controls = guiControls or {}
    isInitialized = true
    print("[AutoTeleportPlayer] Initialized")
    return true
end

function AutoTeleportPlayer:SetTarget(playerName)
    if typeof(playerName) ~= "string" or playerName == "" then
        warn("[AutoTeleportPlayer] Invalid player name")
        return false
    end
    if SETTINGS.excludeSelf and playerName == LocalPlayer.Name then
        warn("[AutoTeleportPlayer] Target is yourself; ignoring")
        return false
    end
    selectedPlayerName = playerName
    print("[AutoTeleportPlayer] Target set to:", selectedPlayerName)
    return true
end

function AutoTeleportPlayer:Teleport(optionalPlayerName)
    if not isInitialized then
        warn("[AutoTeleportPlayer] Feature not initialized")
        return false
    end

    local name = optionalPlayerName or selectedPlayerName
    if not name or name == "" then
        warn("[AutoTeleportPlayer] No target player selected")
        tpNotify("Teleport Failed", "Pilih player dulu dari dropdown", "x", 3)
        return false
    end

    if SETTINGS.excludeSelf and name == LocalPlayer.Name then
        warn("[AutoTeleportPlayer] Target is yourself")
        tpNotify("Teleport Failed", "Ga bisa teleport ke diri sendiri", "x", 3)
        return false
    end

    local target = Players:FindFirstChild(name)
    if not target then
        warn("[AutoTeleportPlayer] Target player not found:", name)
        tpNotify("Teleport Failed", "Player tidak ditemukan (mungkin sudah leave)", "x", 3)
        return false
    end

    local cf = getTargetCFrame(target)
    if not cf then
        warn("[AutoTeleportPlayer] Could not get target CFrame:", name)
        tpNotify("Teleport Failed", "Posisi player belum siap (character belum spawn?)", "x", 3)
        return false
    end

    local ok = self:TeleportToPosition(cf)
    if ok then
        print("[AutoTeleportPlayer] Teleported to", name)
        tpNotify("Teleport Success", "Ke " .. name, "map-pin", 2)
    else
        warn("[AutoTeleportPlayer] Teleport pcall failed")
        tpNotify("Teleport Failed", "Gagal set CFrame", "x", 3)
    end
    return ok
end

function AutoTeleportPlayer:GetPlayerList(excludeSelf)
    local out, me = {}, LocalPlayer and LocalPlayer.Name
    for _, p in ipairs(Players:GetPlayers()) do
        if not excludeSelf or (me and p.Name ~= me) then
            table.insert(out, p.Name)
        end
    end
    table.sort(out, function(a,b) return a:lower() < b:lower() end)
    return out
end

function AutoTeleportPlayer:RefreshList()
    return self:GetPlayerList(SETTINGS.excludeSelf)
end

function AutoTeleportPlayer:GetStatus()
    return {
        initialized = isInitialized,
        selectedPlayer = selectedPlayerName,
        yOffset = SETTINGS.yOffset,
        behindDist = SETTINGS.behindDist,
        players = self:GetPlayerList(SETTINGS.excludeSelf),
    }
end

function AutoTeleportPlayer:Cleanup()
    controls = {}
    isInitialized = false
    selectedPlayerName = nil
    print("[AutoTeleportPlayer] Cleaned up")
end

return AutoTeleportPlayer
