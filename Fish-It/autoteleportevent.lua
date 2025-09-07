--========================================================
-- Feature: AutoTeleportEvent (Patched v2)
--========================================================

local AutoTeleportEvent = {}
AutoTeleportEvent.__index = AutoTeleportEvent

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ===== State =====
local running          = false
local hbConn           = nil         -- polling ringan
local charConn         = nil
local propsAddedConn   = nil         -- jika Props di-recreate
local propsFolder      = nil         -- Workspace.Props
local eventsFolder     = nil         -- ReplicatedStorage.Events

local selectedPriorityList = {}      -- <<< urutan prioritas (array)
local selectedSet           = {}     -- untuk cocokkan cepat (dict)
local hoverHeight           = 15
local returnCFrame          = nil
local currentTarget         = nil     -- { model, name, nameKey, pos }

-- Cache nama event valid (dari ReplicatedStorage.Events)
local validEventName = {}            -- set of normName

-- ===== Utils =====
local function normName(s)
    s = string.lower(s or "")
    s = s:gsub("%W", "")
    return s
end

local function waitChild(parent, name, timeout)
    local t0 = os.clock()
    local obj = parent:FindFirstChild(name)
    while not obj and (os.clock() - t0) < (timeout or 5) do
        parent.ChildAdded:Wait()
        obj = parent:FindFirstChild(name)
    end
    return obj
end

local function ensureCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart") or waitChild(char, "HumanoidRootPart", 5)
    local hum  = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

local function setCFrameSafely(hrp, targetPos, keepLookAt)
    local look = keepLookAt or (hrp.CFrame.LookVector + hrp.Position)
    hrp.AssemblyLinearVelocity = Vector3.new()
    hrp.AssemblyAngularVelocity = Vector3.new()
    hrp.CFrame = CFrame.lookAt(targetPos, Vector3.new(look.X, targetPos.Y, look.Z))
end

-- ===== Index Events from ReplicatedStorage.Events =====
local function indexEvents()
    table.clear(validEventName)
    if not eventsFolder then return end
    local function scan(folder)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("ModuleScript") then
                local ok, data = pcall(require, child)
                if ok and type(data) == "table" and data.Name then
                    validEventName[normName(data.Name)] = true
                end
                validEventName[normName(child.Name)] = true
            elseif child:IsA("Folder") then
                scan(child)
            end
        end
    end
    scan(eventsFolder)
end

-- ===== Resolve Model Pivot =====
local function resolveModelPivotPos(model)
    local ok, cf = pcall(function() return model:GetPivot() end)
    if ok and typeof(cf) == "CFrame" then return cf.Position end
    local ok2, cf2 = pcall(function() return model.WorldPivot end)
    if ok2 and typeof(cf2) == "CFrame" then return cf2.Position end
    return nil
end

-- ===== Collect Active Events (recursive di dalam Props & sub-Props) =====
local function collectActiveEvents()
    local out = {}
    if not propsFolder then return out end

    -- ambil semua Model di bawah Workspace.Props (deep)
    for _, desc in ipairs(propsFolder:GetDescendants()) do
        if desc:IsA("Model") then
            local model = desc
            -- cocokan nama model atau parent folder dengan daftar event valid
            local mKey  = normName(model.Name)
            local pKey  = model.Parent and normName(model.Parent.Name) or nil

            local isEventish =
                (validEventName[mKey] == true) or
                (pKey and validEventName[pKey] == true)

            if isEventish then
                local pos = resolveModelPivotPos(model)
                if pos then
                    -- pilih nama “representatif” untuk prioritas: prefer parent folder (Shark Hunt / Ghost Shark)
                    local repName = model.Parent and model.Parent.Name or model.Name
                    table.insert(out, {
                        model   = model,
                        name    = repName,
                        nameKey = normName(repName),
                        pos     = pos
                    })
                end
            end
        end
    end

    return out
end

-- ===== Match terhadap pilihan user =====
local function matchesSelection(nameKey)
    if #selectedPriorityList == 0 then return true end -- user tidak memilih apa-apa -> semua boleh
    -- “contains” match dua arah supaya toleran variasi nama
    for _, selKey in ipairs(selectedPriorityList) do
        if nameKey:find(selKey, 1, true) or selKey:find(nameKey, 1, true) then
            return true
        end
    end
    return false
end

local function rankOf(nameKey)
    for i, selKey in ipairs(selectedPriorityList) do
        if nameKey:find(selKey, 1, true) or selKey:find(nameKey, 1, true) then
            return i
        end
    end
    return math.huge
end

-- ===== Choose Best =====
local function chooseBestActiveEvent()
    local actives = collectActiveEvents()
    if #actives == 0 then return nil end

    -- filter sesuai pilihan user jika ada
    local filtered = {}
    if #selectedPriorityList > 0 then
        for _, a in ipairs(actives) do
            if matchesSelection(a.nameKey) then
                table.insert(filtered, a)
            end
        end
        actives = filtered
        if #actives == 0 then
            -- tidak ada event TERPILIH yang aktif -> jangan teleport ke event lain
            return nil
        end
    end

    for _, a in ipairs(actives) do
        a.rank = rankOf(a.nameKey)
    end

    table.sort(actives, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        -- stabil
        return a.name < b.name
    end)

    return actives[1]
end

-- ===== Teleport / Return =====
local function teleportToTarget(target)
    local _, hrp = ensureCharacter()
    if not hrp then return false, "NO_HRP" end
    if not returnCFrame then
        returnCFrame = hrp.CFrame -- simpan HARD posisi sekarang sebelum teleport pertama
    end
    local tpPos = target.pos + Vector3.new(0, hoverHeight, 0)
    setCFrameSafely(hrp, tpPos)
    return true
end

local function restorePositionIfNeeded()
    if not returnCFrame then return end
    local _, hrp = ensureCharacter()
    if hrp then
        setCFrameSafely(hrp, returnCFrame.Position, returnCFrame.Position + returnCFrame.LookVector)
    end
    returnCFrame = nil
end

local function maintainHover()
    local _, hrp = ensureCharacter()
    if hrp and currentTarget then
        local desired = currentTarget.pos + Vector3.new(0, hoverHeight, 0)
        if (hrp.Position - desired).Magnitude > 1.2 then
            setCFrameSafely(hrp, desired)
        else
            hrp.AssemblyLinearVelocity = Vector3.new()
            hrp.AssemblyAngularVelocity = Vector3.new()
        end
    end
end

-- ===== Loop =====
local function startLoop()
    if hbConn then hbConn:Disconnect() end
    local lastTick = 0
    hbConn = RunService.Heartbeat:Connect(function()
        if not running then return end
        local now = os.clock()
        if now - lastTick < 0.25 then -- throttle scan Workspace
            maintainHover()
            return
        end
        lastTick = now

        -- pilih target terbaik
        local best = chooseBestActiveEvent()

        if not best then
            -- tidak ada event terpilih (atau tidak ada event sama sekali)
            if currentTarget then
                currentTarget = nil
            end
            if returnCFrame then
                restorePositionIfNeeded() -- <<< pulang otomatis walau currentTarget sudah nil
            end
            return
        end

        if (not currentTarget) or (currentTarget.model ~= best.model) then
            teleportToTarget(best)
            currentTarget = best
        end

        maintainHover()
    end)
end

-- ===== Lifecycle =====
function AutoTeleportEvent:Init(gui)
    propsFolder  = Workspace:FindFirstChild("Props") or waitChild(Workspace, "Props", 5)
    eventsFolder = ReplicatedStorage:FindFirstChild("Events") or waitChild(ReplicatedStorage, "Events", 5)
    indexEvents()

    if charConn then charConn:Disconnect() end
    charConn = LocalPlayer.CharacterAdded:Connect(function()
        if running and currentTarget then
            task.defer(function()
                task.wait(0.25)
                teleportToTarget(currentTarget)
            end)
        end
    end)

    if propsAddedConn then propsAddedConn:Disconnect() end
    propsAddedConn = Workspace.ChildAdded:Connect(function(c)
        if c.Name == "Props" then
            propsFolder = c
        end
    end)

    return true
end

function AutoTeleportEvent:Start(config)
    if running then return true end
    running = true

    if config then
        if type(config.hoverHeight) == "number" then
            hoverHeight = math.clamp(config.hoverHeight, 5, 100)
        end
        if type(config.selectedEvents) ~= "nil" then
            self:SetSelectedEvents(config.selectedEvents) -- terima array (prioritas) atau dict
        end
    end

    -- coba target awal
    local best = chooseBestActiveEvent()
    if best then
        teleportToTarget(best)
        currentTarget = best
    end

    startLoop()
    return true
end

function AutoTeleportEvent:Stop()
    if not running then return true end
    running = false
    if hbConn then hbConn:Disconnect(); hbConn = nil end

    -- saat stop, selalu pulang kalau pernah teleport
    if returnCFrame then
        restorePositionIfNeeded()
    end
    currentTarget = nil
    return true
end

function AutoTeleportEvent:Cleanup()
    self:Stop()
    if charConn       then charConn:Disconnect();       charConn = nil end
    if propsAddedConn then propsAddedConn:Disconnect(); propsAddedConn = nil end
    propsFolder  = nil
    eventsFolder = nil
    table.clear(validEventName)
    table.clear(selectedPriorityList)
    table.clear(selectedSet)
    return true
end

-- ===== Setters =====
-- selected bisa: array (prioritas) **atau** dict/set {["Shark Hunt"]=true, ["Ghost Shark"]=true}
function AutoTeleportEvent:SetSelectedEvents(selected)
    table.clear(selectedPriorityList)
    table.clear(selectedSet)

    if type(selected) == "table" then
        if #selected > 0 then
            -- ARRAY: pertahankan urutan prioritas
            for _, v in ipairs(selected) do
                local key = normName(v)
                table.insert(selectedPriorityList, key)
                selectedSet[key] = true
            end
        else
            -- DICT/SET: tanpa urutan → pakai set saja
            for k, on in pairs(selected) do
                if on then
                    local key = normName(k)
                    selectedSet[key] = true
                end
            end
            -- biarkan selectedPriorityList kosong → artinya "boleh semua"
        end
    end
    return true
end

function AutoTeleportEvent:SetHoverHeight(h)
    if type(h) == "number" then
        hoverHeight = math.clamp(h, 5, 100)
        if running and currentTarget then
            local _, hrp = ensureCharacter()
            if hrp then
                local desired = currentTarget.pos + Vector3.new(0, hoverHeight, 0)
                setCFrameSafely(hrp, desired)
            end
        end
        return true
    end
    return false
end

function AutoTeleportEvent:Status()
    return {
        running    = running,
        hover      = hoverHeight,
        hasHome    = returnCFrame ~= nil,
        target     = currentTarget and currentTarget.name or nil
    }
end

function AutoTeleportEvent.new()
    local self = setmetatable({}, AutoTeleportEvent)
    return self
end

return AutoTeleportEvent
