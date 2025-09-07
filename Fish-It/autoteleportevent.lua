--========================================================
-- Feature: AutoTeleportEvent (Patched & Fixed)
-- Lifecycle: Init(gui?), Start(config?), Stop(), Cleanup()
-- Fixes: Return home when no events available, proper priority handling
--========================================================

local AutoTeleportEvent = {}
AutoTeleportEvent.__index = AutoTeleportEvent

--========== Services ==========
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local Workspace          = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--========== Internal State ==========
local running              = false
local hbConn               = nil      -- safety-net polling (coarse)
local charConn             = nil      -- re-apply hover on respawn
local propsRemovedConn     = nil      -- event-driven return
local propsAddedConn       = nil      -- re-attach when Props recreated
local propsFolder          = nil      -- Workspace.Props
local eventsFolder         = nil      -- ReplicatedStorage.Events

local selectedPriorityList = {}       -- array of normalized names (keeps order)
local selectedRank         = {}       -- map: nameNorm -> rank (1..n)
local hoverHeight          = 15       -- default hover (lebih rendah)
local returnCFrame         = nil      -- saved home position
local currentTarget        = nil      -- { model=Model, name=string, nameKey=string, pos=Vector3 }

local eventsIndexByNorm    = {}       -- map: normName -> true (set nama event yg valid)

--========== Utils ==========
local function waitChild(parent, name, timeout)
    local t0 = os.clock()
    local obj = parent:FindFirstChild(name)
    while not obj and (os.clock() - t0) < (timeout or 5) do
        local ev; ev = parent.ChildAdded:Wait()
        if ev and ev.Name == name then obj = ev end
    end
    return obj
end

local function normName(s)
    s = string.lower(s or "")
    s = s:gsub("%W", "")
    return s
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

--========== Event Catalog ==========
local function indexEvents()
    table.clear(eventsIndexByNorm)
    if not eventsFolder then return end

    local function scan(folder)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("ModuleScript") then
                local ok, data = pcall(require, child)
                if ok and type(data) == "table" and data.Name then
                    eventsIndexByNorm[normName(data.Name)] = true
                end
                -- tetap index berdasarkan nama module juga
                eventsIndexByNorm[normName(child.Name)] = true
            elseif child:IsA("Folder") then
                scan(child)
            end
        end
    end
    scan(eventsFolder)
end

--========== Targeting ==========
local function resolveModelPivotPos(model)
    -- Posisikan tepat di area event: pakai Pivot
    local ok, pivot = pcall(function() return model:GetPivot() end)
    if ok and typeof(pivot) == "CFrame" then
        return pivot.Position
    end
    -- fallback lama
    local ok2, cf = pcall(function() return model.WorldPivot end)
    if ok2 and typeof(cf) == "CFrame" then
        return cf.Position
    end
    return nil
end

local function collectActiveEvents()
    if not propsFolder then return {} end
    local list = {}
    for _, child in ipairs(propsFolder:GetChildren()) do
        if child:IsA("Model") then
            local nmKey = normName(child.Name)
            -- hanya anggap sebagai event jika namanya cocok event catalog (lebih aman)
            if eventsIndexByNorm[nmKey] then
                local pos = resolveModelPivotPos(child)
                if pos then
                    table.insert(list, { model = child, name = child.Name, nameKey = nmKey, pos = pos })
                end
            end
        end
    end
    return list
end

-- FIX: Improved event selection logic
local function chooseBestActiveEvent()
    local actives = collectActiveEvents()
    if #actives == 0 then return nil end

    -- PERBAIKAN: Hanya pilih event yang ada dalam selectedRank
    -- Jika user tidak memilih event apapun, jangan auto-pilih event
    if next(selectedRank) == nil then
        -- Tidak ada event yang dipilih user, return nil
        return nil
    end

    -- Filter hanya event yang dipilih user
    local filteredActives = {}
    for _, a in ipairs(actives) do
        if selectedRank[a.nameKey] then
            a.rank = selectedRank[a.nameKey]
            table.insert(filteredActives, a)
        end
    end

    if #filteredActives == 0 then return nil end

    -- Sort berdasarkan prioritas (rank lebih kecil = prioritas tinggi)
    table.sort(filteredActives, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        -- tiebreaker: nama (stabil)
        return a.name < b.name
    end)

    return filteredActives[1]
end

--========== Teleport / Return ==========
local function teleportToTarget(target)
    local _, hrp = ensureCharacter()
    if not hrp then return false, "NO_HRP" end

    -- Simpan home hanya sekali saat pertama kali teleport
    if not returnCFrame then
        returnCFrame = hrp.CFrame
    end

    local tpPos = target.pos + Vector3.new(0, hoverHeight, 0)
    setCFrameSafely(hrp, tpPos)
    return true
end

-- FIX: Improved return logic
local function restorePositionIfNeeded()
    if not returnCFrame then return false end
    
    local _, hrp = ensureCharacter()
    if hrp then
        setCFrameSafely(hrp, returnCFrame.Position, returnCFrame.Position + returnCFrame.LookVector)
        returnCFrame = nil -- Clear after returning
        return true
    end
    return false
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

-- FIX: Better event gone handling
local function onCurrentEventGone()
    currentTarget = nil
    
    -- Stabilisasi sebelum evaluasi
    task.defer(function()
        task.wait(0.1)
        
        if not running then return end -- Skip jika sudah di-stop
        
        local nextBest = chooseBestActiveEvent()
        if nextBest then
            -- Ada event lain yang dipilih user dan sedang aktif
            teleportToTarget(nextBest)
            currentTarget = nextBest
        else
            -- PERBAIKAN: Tidak ada event yang cocok/dipilih -> pulang ke home
            restorePositionIfNeeded()
        end
    end)
end

--========== Listeners / Loop ==========
local function attachPropsListeners()
    if propsRemovedConn then propsRemovedConn:Disconnect() end
    propsRemovedConn = propsFolder.ChildRemoved:Connect(function(child)
        if currentTarget and child == currentTarget.model then
            onCurrentEventGone()
        end
    end)
end

local function attachWorkspaceListeners()
    if propsAddedConn then propsAddedConn:Disconnect() end
    propsAddedConn = Workspace.ChildAdded:Connect(function(c)
        if c.Name == "Props" then
            propsFolder = c
            attachPropsListeners()
        end
    end)
end

-- FIX: Improved safety net loop
local function startSafetyNetLoop()
    if hbConn then hbConn:Disconnect() end
    local lastSanity = 0
    hbConn = RunService.Heartbeat:Connect(function()
        if not running then return end

        -- Safety check setiap 1.0 detik
        local now = os.clock()
        if now - lastSanity > 1.0 then
            lastSanity = now
            
            -- Cek apakah target masih valid
            if currentTarget then
                if not currentTarget.model or not currentTarget.model:IsDescendantOf(propsFolder or Workspace) then
                    onCurrentEventGone()
                    return
                end
            end
        end

        -- PERBAIKAN: Logic untuk memilih target
        local best = chooseBestActiveEvent()
        
        if not best then
            -- Tidak ada event yang sesuai pilihan user
            if currentTarget then
                currentTarget = nil
                restorePositionIfNeeded()
            end
            return
        end

        -- Ada event yang cocok
        if (not currentTarget) or (currentTarget.model ~= best.model) then
            teleportToTarget(best)
            currentTarget = best
        end

        maintainHover()
    end)
end

--========== Lifecycle ==========
function AutoTeleportEvent:Init(guiHandles)
    -- Resolve folders
    propsFolder  = Workspace:FindFirstChild("Props") or waitChild(Workspace, "Props", 5)
    eventsFolder = ReplicatedStorage:FindFirstChild("Events") or waitChild(ReplicatedStorage, "Events", 5)

    -- Index katalog event
    indexEvents()

    -- Robust ke respawn: re-apply hover ke target aktif
    if charConn then charConn:Disconnect() end
    charConn = LocalPlayer.CharacterAdded:Connect(function()
        if running and currentTarget then
            task.defer(function()
                task.wait(0.25)
                teleportToTarget(currentTarget)
            end)
        end
    end)

    -- Listener Props & Workspace
    if propsFolder then attachPropsListeners() end
    attachWorkspaceListeners()

    return true
end

function AutoTeleportEvent:Start(config)
    if running then return true end
    running = true

    -- Konsumsi config
    if config then
        if type(config.hoverHeight) == "number" then
            hoverHeight = math.clamp(config.hoverHeight, 5, 100)
        end
        if type(config.selectedEvents) ~= "nil" then
            self:SetSelectedEvents(config.selectedEvents)
        end
    end

    -- PERBAIKAN: Hanya pilih target awal jika user sudah memilih event
    local best = chooseBestActiveEvent()
    if best then
        teleportToTarget(best)
        currentTarget = best
    end
    -- Jika tidak ada event yang dipilih/aktif, tidak melakukan apa-apa

    startSafetyNetLoop()
    return true
end

function AutoTeleportEvent:Stop()
    if not running then return true end
    running = false

    if hbConn then hbConn:Disconnect(); hbConn = nil end
    
    -- PERBAIKAN: Selalu pulang saat di-stop manual
    if currentTarget then
        currentTarget = nil
    end
    -- Pulang ke home jika ada returnCFrame
    restorePositionIfNeeded()

    return true
end

function AutoTeleportEvent:Cleanup()
    self:Stop()
    if charConn         then charConn:Disconnect();         charConn = nil end
    if propsRemovedConn then propsRemovedConn:Disconnect(); propsRemovedConn = nil end
    if propsAddedConn   then propsAddedConn:Disconnect();   propsAddedConn = nil end

    propsFolder  = nil
    eventsFolder = nil

    table.clear(selectedPriorityList)
    table.clear(selectedRank)
    table.clear(eventsIndexByNorm)
    
    -- Clear return position saat cleanup
    returnCFrame = nil

    return true
end

--========== Setters ==========
-- selected: bisa array (prioritas sesuai urutan) atau dict/set {["Admin - Black Hole"]=true, ...}
function AutoTeleportEvent:SetSelectedEvents(selected)
    table.clear(selectedPriorityList)
    table.clear(selectedRank)

    if type(selected) == "table" then
        if #selected > 0 then
            -- array
            for i, v in ipairs(selected) do
                local key = normName(v)
                selectedPriorityList[i] = key
                selectedRank[key] = i
            end
        else
            -- dict/set
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
    
    -- PERBAIKAN: Re-evaluasi target setelah mengubah pilihan (opsional untuk fleksibilitas)
    if running then
        task.defer(function()
            local best = chooseBestActiveEvent()
            if best and (not currentTarget or currentTarget.model ~= best.model) then
                teleportToTarget(best)
                currentTarget = best
            elseif not best and currentTarget then
                -- Tidak ada event aktif -> pulang ke home
                currentTarget = nil
                restorePositionIfNeeded()
            end
        end)
    end
    
    return true
end

function AutoTeleportEvent:SetHoverHeight(h)
    if type(h) == "number" then
        hoverHeight = math.clamp(h, 5, 100)
        -- kalau sedang hover, update segera
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

-- (opsional) Status untuk debug ringan
function AutoTeleportEvent:Status()
    return {
        running       = running,
        hover         = hoverHeight,
        hasHome       = returnCFrame ~= nil,
        hasTarget     = currentTarget ~= nil,
        targetName    = currentTarget and currentTarget.name or nil,
        selectedCount = #selectedPriorityList
    }
end

--========== Factory ==========
function AutoTeleportEvent.new()
    local self = setmetatable({}, AutoTeleportEvent)
    return self
end

return AutoTeleportEvent
