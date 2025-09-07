--========================================================
-- Feature: AutoTeleportEvent
-- Lifecycle & style mengikuti standarfiturscript.txt
--========================================================

local AutoTeleportEvent = {}
AutoTeleportEvent.__index = AutoTeleportEvent

--========== Services ==========
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--========== Internal State ==========
local running = false
local hbConn = nil
local charConn = nil

local propsFolder -- Workspace.Props
local eventsFolder -- ReplicatedStorage.Events

local selectedPriorityList = {}    -- array yg mempertahankan urutan prioritas
local selectedRank = {}            -- map nameNorm -> rank (angka kecil = lebih prioritas)
local hoverHeight = 60             -- default tinggi melayang di atas titik event
local returnCFrame = nil           -- posisi sebelum teleport
local currentTarget = nil          -- {name=name, pos=Vector3}
local lastTeleportAt = 0

-- util: aman cari child dengan timeout singkat
local function waitChild(parent, name, timeout)
    local t0 = os.clock()
    local obj = parent:FindFirstChild(name)
    while not obj and (os.clock() - t0) < (timeout or 5) do
        parent.ChildAdded:Wait()
        obj = parent:FindFirstChild(name)
    end
    return obj
end

-- util: normalisasi nama utk pencocokan longgar ("Admin - Black Hole" ~ "adminblackhole")
local function normName(s)
    s = string.lower(s or "")
    s = s:gsub("%W", "") -- buang non-alfanum
    return s
end

-- build index dari ReplicatedStorage.Events (recursive)
local eventsIndexByAnyName = {} -- key: normName(module.Name) or normName(data.Name) -> {module=ms, data=tbl}
local function indexEvents()
    table.clear(eventsIndexByAnyName)
    local function scan(folder)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("ModuleScript") then
                local ok, data = pcall(require, child)
                if ok and type(data) == "table" then
                    if data.Name then
                        eventsIndexByAnyName[normName(data.Name)] = { module = child, data = data }
                    end
                    eventsIndexByAnyName[normName(child.Name)] = eventsIndexByAnyName[normName(data.Name)] or { module = child, data = data }
                else
                    -- fallback: index pakai nama module saja
                    eventsIndexByAnyName[normName(child.Name)] = { module = child, data = nil }
                end
            elseif child:IsA("Folder") then
                scan(child)
            end
        end
    end
    if eventsFolder then scan(eventsFolder) end
end

-- dapatkan Vector3 target untuk suatu event aktif
-- prefer: data.Coordinates[1]; fallback: model.WorldPivot.Position
local function resolveEventPosition(eventModel)
    local modelPos = nil
    -- WorldPivot adalah CFrame, kita ambil Position
    local ok, cf = pcall(function() return eventModel.WorldPivot end)
    if ok and typeof(cf) == "CFrame" then
        modelPos = cf.Position
    end

    -- coba cocokkan dengan module data
    local nameA = eventModel.Name
    local key = normName(nameA)
    local idx = eventsIndexByAnyName[key]

    if idx and idx.data and typeof(idx.data.Coordinates) == "table" and idx.data.Coordinates[1] and typeof(idx.data.Coordinates[1]) == "Vector3" then
        return idx.data.Coordinates[1]
    end

    -- fallback ke pivot
    return modelPos
end

-- pilih event aktif terbaik sesuai prioritas
local function chooseBestActiveEvent()
    if not propsFolder then return nil end
    local actives = {}
    for _, child in ipairs(propsFolder:GetChildren()) do
        if child:IsA("Model") then
            -- anggap semua Model di Props adalah kandidat event aktif
            local pos = resolveEventPosition(child)
            if pos then
                local nm = child.Name
                local nmKey = normName(nm)
                local rank = selectedRank[nmKey] or math.huge
                table.insert(actives, { name = nm, nameKey = nmKey, pos = pos, rank = rank })
            end
        end
    end
    if #actives == 0 then return nil end

    table.sort(actives, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        -- tie-breaker: lebih tinggi Tier kalau tersedia di index
        local ai = eventsIndexByAnyName[a.nameKey]
        local bi = eventsIndexByAnyName[b.nameKey]
        local at = (ai and ai.data and tonumber(ai.data.Tier)) or -1
        local bt = (bi and bi.data and tonumber(bi.data.Tier)) or -1
        if at ~= bt then return at > bt end
        return a.name < b.name
    end)

    -- kalau user tidak memilih apa pun (semua rank = inf), kita ambil elemen pertama (arbitrary terbaik)
    return actives[1]
end

-- teleport + mulai menjaga hover
local function ensureCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then hrp = waitChild(char, "HumanoidRootPart", 5) end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

local function setCFrameSafely(hrp, targetPos, keepLookAt)
    local look = keepLookAt or (hrp.CFrame.LookVector + hrp.Position)
    hrp.AssemblyLinearVelocity = Vector3.new()
    hrp.AssemblyAngularVelocity = Vector3.new()
    hrp.CFrame = CFrame.lookAt(targetPos, Vector3.new(look.X, targetPos.Y, look.Z))
end

local function teleportToTarget(target)
    local char, hrp, hum = ensureCharacter()
    if not hrp then return false, "NO_HRP" end

    if not returnCFrame then
        -- simpan posisi semula hanya sekali saat kita pertama kali teleport
        returnCFrame = hrp.CFrame
    end

    local tp = target.pos + Vector3.new(0, hoverHeight, 0)
    setCFrameSafely(hrp, tp)
    lastTeleportAt = os.clock()
    return true
end

local function restorePositionIfNeeded()
    if not returnCFrame then return end
    local char, hrp, hum = ensureCharacter()
    if hrp then
        setCFrameSafely(hrp, returnCFrame.Position, returnCFrame.Position + returnCFrame.LookVector)
    end
    returnCFrame = nil
end

-- heartbeat loop: pilih target terbaik, jaga hover, pulang bila event habis
local function runLoop()
    if hbConn then hbConn:Disconnect() end
    hbConn = RunService.Heartbeat:Connect(function()
        if not running then return end

        -- pilih target terbaik (prioritas)
        local best = chooseBestActiveEvent()
        if best == nil then
            -- tidak ada event aktif -> kalau sebelumnya kita teleport, pulangkan
            if currentTarget ~= nil then
                currentTarget = nil
                restorePositionIfNeeded()
            end
            return
        end

        -- jika target berubah (event berbeda / lebih prioritas muncul), ganti
        if (not currentTarget) or (currentTarget.nameKey ~= best.nameKey) then
            currentTarget = best
            teleportToTarget(best)
        end

        -- jaga hover stabil (anti gravity drift / arus laut)
        local _, hrp = ensureCharacter()
        if hrp and currentTarget then
            local desired = currentTarget.pos + Vector3.new(0, hoverHeight, 0)
            -- minor deadzone supaya gak nge-spam CFrame tiap frame
            if (hrp.Position - desired).Magnitude > 1.2 then
                setCFrameSafely(hrp, desired)
            else
                -- jaga agar velocity nol (stabil)
                hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity * 0
                hrp.AssemblyAngularVelocity = hrp.AssemblyAngularVelocity * 0
            end
        end
    end)
end

--========== Lifecycle ==========
function AutoTeleportEvent:Init(guiHandles)
    -- resolve folders
    propsFolder = waitChild(Workspace, "Props", 5)
    eventsFolder = waitChild(ReplicatedStorage, "Events", 5)

    if eventsFolder then
        indexEvents()
        -- optional: kalau mau pre-populate dropdown guiHandles, TAPI standar tidak mewajibkan. Kita skip.
    end

    -- robust terhadap respawn: kalau respawn saat feature aktif, kita lanjut menjaga hover
    if charConn then charConn:Disconnect() end
    charConn = LocalPlayer.CharacterAdded:Connect(function()
        if running and currentTarget then
            task.defer(function()
                task.wait(0.25)
                teleportToTarget(currentTarget)
            end)
        end
    end)

    return true
end

function AutoTeleportEvent:Start(config)
    if running then return true end
    running = true

    -- konsumsi config (opsional, sesuai standar: abaikan key yg tak dikenal)
    if config then
        if type(config.hoverHeight) == "number" then
            hoverHeight = math.clamp(config.hoverHeight, 10, 200)
        end
        if type(config.selectedEvents) ~= "nil" then
            self:SetSelectedEvents(config.selectedEvents)
        end
    end

    runLoop()
    return true
end

function AutoTeleportEvent:Stop()
    if not running then return true end
    running = false
    if hbConn then hbConn:Disconnect(); hbConn = nil end
    -- ketika berhenti manual, kembalikan posisi bila sebelumnya kita teleport ke event
    if currentTarget then
        currentTarget = nil
        restorePositionIfNeeded()
    end
    return true
end

function AutoTeleportEvent:Cleanup()
    self:Stop()
    if charConn then charConn:Disconnect(); charConn = nil end
    propsFolder = nil
    eventsFolder = nil
    table.clear(selectedPriorityList)
    table.clear(selectedRank)
    return true
end

--========== Setters (idempotent) ==========
-- selected can be: array (prioritas = urutan), atau set/dictionary {["Event A"]=true, ...}
function AutoTeleportEvent:SetSelectedEvents(selected)
    table.clear(selectedPriorityList)
    table.clear(selectedRank)

    if type(selected) == "table" then
        -- deteksi apakah array?
        local isArray = (#selected > 0)
        if isArray then
            -- urutan prioritas sesuai array
            for i, v in ipairs(selected) do
                local key = normName(v)
                selectedPriorityList[i] = key
                selectedRank[key] = i
            end
        else
            -- dict/set: fallback urut alfabet nama normalized
            local temp = {}
            for k, on in pairs(selected) do
                if on then table.insert(temp, normName(k)) end
            end
            table.sort(temp)
            for i, key in ipairs(temp) do
                selectedPriorityList[i] = key
                selectedRank[key] = i
            end
        end
    end

    -- idempotent: tidak mengganggu loop berjalan
    return true
end

function AutoTeleportEvent:SetHoverHeight(h)
    if type(h) == "number" then
        hoverHeight = math.clamp(h, 10, 200)
        return true
    end
    return false
end

--========== Factory ==========
function AutoTeleportEvent.new()
    local self = setmetatable({}, AutoTeleportEvent)
    return self
end

return AutoTeleportEvent
