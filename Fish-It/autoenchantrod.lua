-- ==========================================
-- Feature: autoenchantrod
-- Flow   : Equip Enchant Stone -> Activate Altar -> Wait result -> repeat
-- Stop   : Ketika RE/RollEnchant (OnClientEvent) mengirim enchantId yg match
-- Notes  : Menangkap UUID Enchant Stone otomatis dari RE/EquipItem ("EnchantStones")
-- ==========================================

local Feature = {}
Feature.__index = Feature

-- Services
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Config
local DELAY_BETWEEN_ROLLS = 0.6   -- jeda aman antar siklus
local RESULT_TIMEOUT      = 3.0   -- kalau ga ada hasil, ulang equip+activate

-- State
local running        = false
local foundOnce      = false
local hbConn         = nil
local resultConn     = nil
local watchConn      = nil

-- Selections
local wantedIds      = {}   -- [id]=true
local wantedNames    = {}   -- [normName]=true

-- Indices
local EnchantsFolder = nil
local IndexById      = {}   -- [id] = meta {Id, Name, Module}
local IndexByName    = {}   -- [norm] = meta

-- Remotes
local RollEvent              = nil  -- "RE/RollEnchant" (RemoteEvent inbound)
local ActivateEnchantingAltar= nil  -- "RE/ActivateEnchantingAltar" (RemoteEvent)
local EquipItem              = nil  -- "RE/EquipItem" (RemoteEvent)

-- Stone UUID
local StoneUUID              = nil  -- string "xxxxxxxx-...."
local lastResultAt           = 0

-- ============== Utils ==============
local function norm(s) s = tostring(s or ""):gsub("^%s+",""):gsub("%s+$",""); return s:lower() end

local function safeRequire(ms)
    local ok, data = pcall(require, ms)
    if not ok or type(data) ~= "table" then return end
    local d = data.Data or {}
    local id, name = tonumber(d.Id), d.Name
    if not (id and name) then return end
    return { Id = id, Name = name, Module = ms }
end

local function buildEnchantIndex()
    EnchantsFolder = RS:FindFirstChild("Enchants")
    if not EnchantsFolder then return end
    table.clear(IndexById); table.clear(IndexByName)
    for _,child in ipairs(EnchantsFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            local meta = safeRequire(child)
            if meta then
                IndexById[meta.Id] = meta
                IndexByName[norm(meta.Name)] = meta
            end
        end
    end
end

local function matches(id)
    if not id then return false end
    if wantedIds[id] then return true end
    local m = IndexById[id]
    if m and wantedNames[norm(m.Name)] then return true end
    return false
end

local function findUnderNet(name)
    local Packages = RS:FindFirstChild("Packages")
    local _Index   = Packages and Packages:FindFirstChild("_Index")
    if not _Index then return end
    for _,pkg in ipairs(_Index:GetChildren()) do
        if pkg:IsA("Folder") and pkg.Name:match("^sleitnick_net@") then
            local net = pkg:FindFirstChild("net")
            if net then
                local inst = net:FindFirstChild(name)
                if inst then return inst end
            end
        end
    end
end

local function findRemote(name)
    return findUnderNet(name) or RS:FindFirstChild(name, true)
end

local function disconnect(x) if x then x:Disconnect() end end

-- ============== API ==============
function Feature:Init(controls)
    buildEnchantIndex()

    -- find remotes
    RollEvent               = findRemote("RE/RollEnchant")
    ActivateEnchantingAltar = findRemote("RE/ActivateEnchantingAltar")
    EquipItem               = findRemote("RE/EquipItem")

    -- listen enchant index refresh (jaga2 ada update)
    RS.DescendantAdded:Connect(function(d)
        if EnchantsFolder and d.Parent == EnchantsFolder and d:IsA("ModuleScript") then
            local meta = safeRequire(d)
            if meta then
                IndexById[meta.Id] = meta
                IndexByName[norm(meta.Name)] = meta
            end
        end
    end)

    -- auto-capture StoneUUID saat user equip manual
    -- (RE/EquipItem:FireServer(<uuid>, "EnchantStones"))
    local rawmt = getrawmetatable(game); local old = rawmt.__namecall
    setreadonly(rawmt, false)
    rawmt.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if typeof(self)=="Instance" and self.Name=="RE/EquipItem" and m=="FireServer" then
            local args = table.pack(...)
            if type(args[1])=="string" and args[2]=="EnchantStones" then
                StoneUUID = args[1]
                print("[autoenchantrod] captured Stone UUID:", StoneUUID)
            end
        end
        return old(self, ...)
    end)
    setreadonly(rawmt, true)

    -- pre-populate dropdown (optional)
    if controls and controls.enchantDropdownMulti and controls.enchantDropdownMulti.Reload then
        local names = {}
        for _, meta in pairs(IndexById) do table.insert(names, meta.Name) end
        table.sort(names)
        controls.enchantDropdownMulti:Reload(names)
    end

    return true
end

function Feature:SetDesiredByNames(listOrSet)
    wantedNames, wantedIds = {}, {}
    if type(listOrSet)=="table" then
        if #listOrSet > 0 then
            for _,nm in ipairs(listOrSet) do wantedNames[norm(nm)] = true end
        else
            for k,v in pairs(listOrSet) do if v then wantedNames[norm(k)] = true end end
        end
    end
    for n,_ in pairs(wantedNames) do
        local m = IndexByName[n]; if m then wantedIds[m.Id] = true end
    end
end

function Feature:SetDesiredByIds(listOrSet)
    wantedIds, wantedNames = {}, {}
    if type(listOrSet)=="table" then
        if #listOrSet > 0 then
            for _,id in ipairs(listOrSet) do id=tonumber(id); if id then wantedIds[id]=true end end
        else
            for k,v in pairs(listOrSet) do if v then k=tonumber(k); if k then wantedIds[k]=true end end end
        end
    end
end

function Feature:SetDelay(sec)
    sec = tonumber(sec); if sec and sec>=0.2 then DELAY_BETWEEN_ROLLS = sec; return true end
    return false
end

-- Optional manual setter kalau mau paste UUID langsung
function Feature:SetStoneUUID(uuid)
    if type(uuid)=="string" and #uuid>=8 then StoneUUID = uuid; return true end
    return false
end

-- ============== Core ==============
local function attachResultListener(self)
    disconnect(resultConn)
    if not RollEvent or not RollEvent:IsA("RemoteEvent") then return end
    resultConn = RollEvent.OnClientEvent:Connect(function(a1, a2)
        lastResultAt = tick()
        local id = tonumber(a2)
        if id then
            -- debug kecil
            -- print("[autoenchantrod] result id:", id, IndexById[id] and IndexById[id].Name)
            if matches(id) and not foundOnce then
                foundOnce = true
                print("[autoenchantrod] MATCH FOUND:", id, IndexById[id] and IndexById[id].Name or "?")
                self:Stop()
            end
        end
    end)
end

function Feature:Start(cfg)
    if running then return end
    running   = true
    foundOnce = false
    if cfg then
        if cfg.enchantNames then self:SetDesiredByNames(cfg.enchantNames) end
        if cfg.enchantIds   then self:SetDesiredByIds(cfg.enchantIds)   end
        if cfg.delay        then self:SetDelay(cfg.delay)                end
        if type(cfg.stoneUUID)=="string" then self:SetStoneUUID(cfg.stoneUUID) end
    end

    -- ensure remotes
    RollEvent               = RollEvent               or findRemote("RE/RollEnchant")
    ActivateEnchantingAltar = ActivateEnchantingAltar or findRemote("RE/ActivateEnchantingAltar")
    EquipItem               = EquipItem               or findRemote("RE/EquipItem")

    attachResultListener(self)

    -- watch jika remote muncul telat
    disconnect(watchConn)
    watchConn = RS.DescendantAdded:Connect(function(d)
        if d.Name=="RE/RollEnchant" and d:IsA("RemoteEvent") then
            RollEvent = d; attachResultListener(self)
        elseif d.Name=="RE/ActivateEnchantingAltar" and d:IsA("RemoteEvent") then
            ActivateEnchantingAltar = d
        elseif d.Name=="RE/EquipItem" and d:IsA("RemoteEvent") then
            EquipItem = d
        end
    end)

    disconnect(hbConn)
    hbConn = RunService.Heartbeat:Connect(function()
        if not running or foundOnce then return end
        -- Harus punya UUID & remotes
        if not (EquipItem and ActivateEnchantingAltar and StoneUUID) then
            return
        end

        -- Timeout: kalau belum ada hasil cukup lama, ulang siklus
        if (tick() - lastResultAt) < DELAY_BETWEEN_ROLLS then return end
        lastResultAt = tick()  -- set lebih awal untuk throttling

        -- 1) Equip Enchant Stone
        pcall(function() EquipItem:FireServer(StoneUUID, "EnchantStones") end)

        -- 2) Activate Altar
        pcall(function() ActivateEnchantingAltar:FireServer() end)

        -- (Server akan memicu RE/RollEnchant → listener di atas yang memutuskan stop)
        -- Jika tidak ada hasil dalam RESULT_TIMEOUT, loop akan memukul lagi
        task.delay(RESULT_TIMEOUT, function()
            if running and (tick() - lastResultAt) >= RESULT_TIMEOUT then
                -- no-op; Heartbeat berikutnya akan trigger siklus lagi
            end
        end)
    end)
end

function Feature:Stop()
    if not running then return end
    running = false
    disconnect(hbConn)      ; hbConn = nil
    disconnect(resultConn)  ; resultConn = nil
    disconnect(watchConn)   ; watchConn = nil
end

function Feature:Cleanup()
    self:Stop()
    wantedIds, wantedNames = {}, {}
    StoneUUID = nil
end

-- Convenience untuk GUI agar bisa mengambil list nama enchant
function Feature:GetEnchantNames()
    local names = {}
    for _, m in pairs(IndexById) do table.insert(names, m.Name) end
    table.sort(names)
    return names
end

return Feature
