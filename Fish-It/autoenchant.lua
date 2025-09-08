-- ==========================================
-- Feature: autoenchantrod
-- Contract: Init / Start / Stop / Cleanup
-- Purpose : Auto-roll enchant sampai ketemu salah satu pilihan user.
-- Notes   : Inbound RE/RollEnchant -> arg#2 = enchantId (number)
--            Outbound signature bisa beda-beda; gunakan SetRollArgsBuilder(fn)
-- ==========================================

local autoenchantFeature = {}
autoenchantFeature.__index = autoenchantFeature

-- ===== Services / Refs =====
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ===== Config defaults =====
local DEFAULT_DELAY = 0.35  -- throttle antar roll

-- ===== State =====
local running      = false
local hbConn       = nil
local inboundConn  = nil
local inboundConn2 = nil
local foundOnce    = false

-- Selections
local desiredIds   = {}   -- [id]=true
local desiredNames = {}   -- [normName]=true
local interDelay   = DEFAULT_DELAY
local chosenStone  = nil  -- bebas: name/id/module; dipakai builder arg
local rollArgsBuilder = nil -- function()-> {method="FireServer"/"InvokeServer", args={...}}

-- Indices
local EnchantsFolder = nil
local IndexById      = {}  -- [id]   = meta
local IndexByName    = {}  -- [norm] = meta
local IndexByModule  = {}  -- [ModuleScript] = meta

-- Remotes
local RollRemote        = nil   -- "RE/RollEnchant"
local ActivateAltar     = nil   -- "RE/ActivateEnchantingAltar"

-- ===== Utils =====
local function norm(s)
    s = tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")
    return s:lower()
end

local function safeRequire(ms)
    local ok, data = pcall(function() return require(ms) end)
    if not ok or type(data) ~= "table" then return nil end
    local d = data.Data or {}
    local meta = {
        Id     = tonumber(d.Id),
        Type   = d.Type,
        Name   = d.Name,
        Module = ms,
    }
    return (meta.Id and meta.Name) and meta or nil
end

local function findUnderNet(remoteName)
    local Packages = RS:FindFirstChild("Packages")
    local _Index   = Packages and Packages:FindFirstChild("_Index")
    if not _Index then return nil end
    for _, pkg in ipairs(_Index:GetChildren()) do
        if pkg:IsA("Folder") and pkg.Name:match("^sleitnick_net@") then
            local net = pkg:FindFirstChild("net")
            if net then
                local inst = net:FindFirstChild(remoteName)
                if inst then return inst end
            end
        end
    end
    return nil
end

local function findRemote(remoteName)
    return findUnderNet(remoteName) or RS:FindFirstChild(remoteName, true)
end

local function rebuildEnchantIndex()
    table.clear(IndexById)
    table.clear(IndexByName)
    table.clear(IndexByModule)
    if not EnchantsFolder then return end
    for _, child in ipairs(EnchantsFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            local meta = safeRequire(child)
            if meta then
                IndexById[meta.Id]             = meta
                IndexByName[norm(meta.Name)]   = meta
                IndexByModule[child]           = meta
            end
        end
    end
end

local function matches(id)
    if not id then return false end
    if desiredIds[id] then return true end
    local meta = IndexById[id]
    if meta and desiredNames[norm(meta.Name)] then
        return true
    end
    return false
end

local function disconnectConn(conn)
    if conn then conn:Disconnect() end
end

-- ===== Lifecycle =====
function autoenchantFeature:Init(gui)
    -- find folders
    EnchantsFolder = RS:WaitForChild("Enchants", 5)
    if not EnchantsFolder then
        warn("[autoenchantrod] Enchants folder not found")
    end
    rebuildEnchantIndex()
    -- watch new enchants
    RS.DescendantAdded:Connect(function(d)
        if EnchantsFolder and d.Parent == EnchantsFolder and d:IsA("ModuleScript") then
            local meta = safeRequire(d)
            if meta then
                IndexById[meta.Id]           = meta
                IndexByName[norm(meta.Name)] = meta
                IndexByModule[d]             = meta
            end
        end
    end)

    -- find remotes
    RollRemote    = findRemote("RE/RollEnchant")
    ActivateAltar = findRemote("RE/ActivateEnchantingAltar")

    -- GUI (opsional) pre-populate
    if gui and gui.enchantDropdownMulti and gui.enchantDropdownMulti.Reload then
        local names = {}
        for _, meta in pairs(IndexById) do table.insert(names, meta.Name) end
        table.sort(names)
        pcall(function() gui.enchantDropdownMulti:Reload(names) end)
    end

    return true
end

function autoenchantFeature:Start(config)
    if running then return end
    running   = true
    foundOnce = false

    -- apply optional config
    if type(config) == "table" then
        if config.enchantIds   then self:SetDesiredEnchantsByIds(config.enchantIds) end
        if config.enchantNames then self:SetDesiredEnchantsByNames(config.enchantNames) end
        if config.stone        then self:SetStone(config.stone) end
        if tonumber(config.delay) then self:SetInterRollDelay(tonumber(config.delay)) end
        if type(config.rollArgsBuilder) == "function" then self:SetRollArgsBuilder(config.rollArgsBuilder) end
    end

    -- Arm inbound listener: server → client result
    -- Screenshot lo nunjukin OnClientEvent di RE/RollEnchant dimana arg#2 = enchantId
    disconnectConn(inboundConn)
    if RollRemote and RollRemote:IsA("RemoteEvent") then
        inboundConn = RollRemote.OnClientEvent:Connect(function(a1, a2, a3, a4, ...)
            local id = tonumber(a2)
            if id and matches(id) and not foundOnce then
                foundOnce = true
                -- auto-stop
                self:Stop()
            end
        end)
    end

    -- Main loop (optional auto-roll) — hanya jalan jika ada RollRemote & builder
    disconnectConn(hbConn)
    hbConn = RunService.Heartbeat:Connect(function()
        if not running then return end
        if foundOnce then return end

        -- Kalau user belum pasang builder, jangan spam remote; hanya “armed” deteksi.
        if not (RollRemote and rollArgsBuilder) then
            return
        end

        -- Activate altar (best effort; beberapa game hanya perlu sekali di awal)
        if ActivateAltar and ActivateAltar.FireServer then
            pcall(function() ActivateAltar:FireServer() end)
        end

        local spec = nil
        local okSpec, err = pcall(function()
            spec = rollArgsBuilder({
                stone     = chosenStone,
                desired   = desiredIds,   -- set by id
                idxById   = IndexById,
                idxByName = IndexByName,
            })
        end)
        if not okSpec or type(spec) ~= "table" then
            -- diam-diam skip; biar nggak noisy
            task.wait(interDelay)
            return
        end

        local method = spec.method
        local args   = spec.args or {}
        if method == "InvokeServer" and RollRemote.InvokeServer then
            local ok, ret = pcall(function() return RollRemote:InvokeServer(table.unpack(args)) end)
            -- Kalau server return Id juga, hajar cek cepat:
            if ok then
                local id = tonumber(ret) or (type(ret)=="table" and tonumber(ret.Id))
                if id and matches(id) then
                    foundOnce = true
                    self:Stop()
                    return
                end
            end
        elseif method == "FireServer" and RollRemote.FireServer then
            pcall(function() RollRemote:FireServer(table.unpack(args)) end)
        end

        task.wait(interDelay)
    end)
end

function autoenchantFeature:Stop()
    if not running then return end
    running = false
    disconnectConn(hbConn)      ; hbConn      = nil
    disconnectConn(inboundConn) ; inboundConn = nil
    disconnectConn(inboundConn2); inboundConn2= nil
end

function autoenchantFeature:Cleanup()
    self:Stop()
    desiredIds   = {}
    desiredNames = {}
    interDelay   = DEFAULT_DELAY
    chosenStone  = nil
    rollArgsBuilder = nil
    foundOnce    = false
end

-- ===== Setters =====
function autoenchantFeature:SetDesiredEnchantsByIds(listOrSet)
    local tmp = {}
    if type(listOrSet) == "table" then
        -- support array or set
        local isArray = (#listOrSet > 0)
        if isArray then
            for _, v in ipairs(listOrSet) do
                local id = tonumber(v); if id then tmp[id] = true end
            end
        else
            for k, v in pairs(listOrSet) do
                if v then
                    local id = tonumber(k); if id then tmp[id] = true end
                end
            end
        end
    end
    desiredIds = tmp
    return true
end

function autoenchantFeature:SetDesiredEnchantsByNames(listOrSet)
    local tmp = {}
    if type(listOrSet) == "table" then
        local isArray = (#listOrSet > 0)
        if isArray then
            for _, nm in ipairs(listOrSet) do
                tmp[norm(nm)] = true
            end
        else
            for k, v in pairs(listOrSet) do
                if v then tmp[norm(k)] = true end
            end
        end
    end
    desiredNames = tmp
    -- Optional: translate names -> ids for speed (keep both)
    for n,_ in pairs(desiredNames) do
        local meta = IndexByName[n]
        if meta then desiredIds[meta.Id] = true end
    end
    return true
end

function autoenchantFeature:SetStone(stone)
    -- fleksibel: bebas (name/id/module). Builder yang akan interpret.
    chosenStone = stone
    return true
end

function autoenchantFeature:SetInterRollDelay(sec)
    sec = tonumber(sec)
    if not sec or sec < 0.1 then return false end
    interDelay = sec
    return true
end

function autoenchantFeature:SetRollArgsBuilder(fn)
    if type(fn) ~= "function" then return false end
    rollArgsBuilder = fn
    return true
end

return autoenchantFeature
