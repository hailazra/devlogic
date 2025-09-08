-- ===========================
-- Feature: autoenchantrod
-- Focus : Auto-roll sampai dapat enchant yang dipilih (by Id/Name)
-- Notes : Tanpa stone dulu. Mengandalkan:
--         - INBOUND  RE/RollEnchant.OnClientEvent: arg#2 = enchantId (number)
--         - OUTBOUND RE/RollEnchant (FireServer/InvokeServer) -> direkam sekali, lalu diulang
-- ===========================

local Feature = {}
Feature.__index = Feature

-- Services
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Config
local INTER_DELAY = 0.35 -- detik antar roll (aman default)

-- State
local running          = false
local foundOnce        = false
local loopConn         = nil
local inboundConn      = nil
local netWatchConn     = nil

local desiredIds       = {}   -- set [id]=true
local desiredNames     = {}   -- set [normName]=true
local EnchantsFolder   = nil
local IndexById        = {}   -- [id]   -> meta {Id,Name,Module}
local IndexByName      = {}   -- [name] -> meta
local IndexByModule    = {}   -- [ModuleScript] -> meta

-- Outbound replay template (terisi ketika user/triggers pertama kali roll manual)
local replayRemote     = nil  -- Instance RemoteEvent/RemoteFunction ("RE/RollEnchant")
local replayMethod     = nil  -- "FireServer" | "InvokeServer"
local replayArgs       = nil  -- { ... } (array)
local lastCallTick     = 0

-- =========== Utils ===========
local function norm(s) s = tostring(s or ""):gsub("^%s+",""):gsub("%s+$",""); return s:lower() end

local function safeRequire(ms)
    local ok, data = pcall(require, ms)
    if not ok or type(data) ~= "table" then return end
    local d = data.Data or {}
    local id = tonumber(d.Id)
    local name = d.Name
    if not (id and name) then return end
    return { Id = id, Name = name, Module = ms }
end

local function buildIndex()
    table.clear(IndexById); table.clear(IndexByName); table.clear(IndexByModule)
    EnchantsFolder = RS:FindFirstChild("Enchants")
    if not EnchantsFolder then return end
    for _, child in ipairs(EnchantsFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            local meta = safeRequire(child)
            if meta then
                IndexById[meta.Id] = meta
                IndexByName[norm(meta.Name)] = meta
                IndexByModule[child] = meta
            end
        end
    end
end

local function matches(id)
    if not id then return false end
    if desiredIds[id] then return true end
    local meta = IndexById[id]
    if meta and desiredNames[norm(meta.Name)] then return true end
    return false
end

local function stopSelf(self)
    if not running then return end
    running = false
    if loopConn   then loopConn:Disconnect();   loopConn   = nil end
    if inboundConn then inboundConn:Disconnect(); inboundConn = nil end
    if netWatchConn then netWatchConn:Disconnect(); netWatchConn = nil end
end

-- =========== Public API ===========
function Feature:Init(controls)
    buildIndex()
    -- Refresh index jika ada enchant baru muncul
    RS.DescendantAdded:Connect(function(d)
        if EnchantsFolder and d.Parent == EnchantsFolder and d:IsA("ModuleScript") then
            local meta = safeRequire(d)
            if meta then
                IndexById[meta.Id] = meta
                IndexByName[norm(meta.Name)] = meta
                IndexByModule[d] = meta
            end
        end
    end)

    -- Optional: pre-populate dropdown (kalau kontrol disediakan)
    if controls and controls.enchantDropdownMulti and controls.enchantDropdownMulti.Reload then
        local names = {}
        for _, m in pairs(IndexById) do table.insert(names, m.Name) end
        table.sort(names)
        controls.enchantDropdownMulti:Reload(names)
    end
    return true
end

function Feature:SetDesiredByIds(listOrSet)
    local tmp = {}
    if type(listOrSet) == "table" then
        if #listOrSet > 0 then
            for _, v in ipairs(listOrSet) do v = tonumber(v); if v then tmp[v] = true end end
        else
            for k, v in pairs(listOrSet) do if v then k = tonumber(k); if k then tmp[k] = true end end end
        end
    end
    desiredIds = tmp
    return true
end

function Feature:SetDesiredByNames(listOrSet)
    local tmp = {}
    if type(listOrSet) == "table" then
        if #listOrSet > 0 then
            for _, nm in ipairs(listOrSet) do tmp[norm(nm)] = true end
        else
            for k, v in pairs(listOrSet) do if v then tmp[norm(k)] = true end end
        end
    end
    desiredNames = tmp
    -- translate ke Id untuk fast path
    for n,_ in pairs(desiredNames) do
        local meta = IndexByName[n]
        if meta then desiredIds[meta.Id] = true end
    end
    return true
end

function Feature:SetDelay(sec)
    sec = tonumber(sec); if not sec or sec < 0.15 then return false end
    INTER_DELAY = sec; return true
end

-- Utility: expose daftar enchant untuk GUI (opsional)
function Feature:GetEnchantNames()
    local names = {}
    for _, m in pairs(IndexById) do table.insert(names, m.Name) end
    table.sort(names)
    return names
end

-- =========== Core ===========
local function attachInbound(self, rollRemote)
    if not rollRemote or not rollRemote:IsA("RemoteEvent") then return end
    if inboundConn then inboundConn:Disconnect(); inboundConn = nil end

    inboundConn = rollRemote.OnClientEvent:Connect(function(a1, a2)
        -- Berdasar bukti: arg#2 adalah enchantId
        local id = tonumber(a2)
        if id and matches(id) and not foundOnce then
            foundOnce = true
            -- Stop total
            stopSelf(self)
            -- Notif kecil (kalau user pakai WindUI, ini tetap print saja di modul)
            print(("[autoenchantrod] MATCH FOUND: Id=%s Name=%s"):format(
                id, (IndexById[id] and IndexById[id].Name) or "?"))
        end
    end)
end

local function findRollRemote()
    -- Prioritas cari di sleitnick net
    local Packages = RS:FindFirstChild("Packages")
    local _Index   = Packages and Packages:FindFirstChild("_Index")
    if _Index then
        for _, pkg in ipairs(_Index:GetChildren()) do
            if pkg:IsA("Folder") and pkg.Name:match("^sleitnick_net@") then
                local net = pkg:FindFirstChild("net")
                if net then
                    local r = net:FindFirstChild("RE/RollEnchant")
                    if r then return r end
                end
            end
        end
    end
    -- Fallback global search
    return RS:FindFirstChild("RE/RollEnchant", true)
end

-- Rekam panggilan outbound pertama ke RE/RollEnchant, lalu replay
local function armOutboundRecorder()
    local rawmt = getrawmetatable(game)
    local oldNC = rawmt.__namecall
    setreadonly(rawmt, false)

    rawmt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if running
           and typeof(self)=="Instance"
           and (self.ClassName=="RemoteEvent" or self.ClassName=="RemoteFunction")
           and self.Name=="RE/RollEnchant"
           and (method=="FireServer" or method=="InvokeServer")
        then
            local args = table.pack(...)
            -- simpan template pertama kali
            if not replayRemote then
                replayRemote = self
                replayMethod = method
                replayArgs   = {}
                for i=1, args.n do replayArgs[i] = args[i] end
                print("[autoenchantrod] captured outbound template:", replayMethod, "args#", args.n)
            end
            -- teruskan ke server
            return oldNC(self, ...)
        end
        return oldNC(self, ...)
    end)

    setreadonly(rawmt, true)

    -- pengembalian fungsi unclamp tidak disediakan; hook ini ringan & sempit dan aman tetap aktif
    -- (kalau ingin benar-benar restore, bisa ditambah self:Cleanup() untuk restore mt)
    return true
end

function Feature:Start(cfg)
    if running then return end
    running   = true
    foundOnce = false

    if cfg then
        if cfg.enchantIds   then self:SetDesiredByIds(cfg.enchantIds) end
        if cfg.enchantNames then self:SetDesiredByNames(cfg.enchantNames) end
        if cfg.delay        then self:SetDelay(cfg.delay) end
    end

    local roll = findRollRemote()
    if roll then attachInbound(self, roll) end

    -- Jika remote muncul belakangan
    if netWatchConn then netWatchConn:Disconnect(); netWatchConn = nil end
    netWatchConn = RS.DescendantAdded:Connect(function(d)
        if not running then return end
        if d.Name=="RE/RollEnchant" and d:IsA("RemoteEvent") then
            attachInbound(self, d)
        end
    end)

    -- Rekam outbound utk replay auto
    armOutboundRecorder()

    -- Loop replay (hanya jalan jika template sudah tertangkap)
    if loopConn then loopConn:Disconnect(); loopConn=nil end
    loopConn = RunService.Heartbeat:Connect(function()
        if not running or foundOnce then return end
        if not (replayRemote and replayMethod and replayArgs) then
            -- menunggu user/triggers manual sekali utk menangkap template
            return
        end
        if (tick() - lastCallTick) < INTER_DELAY then return end
        lastCallTick = tick()

        if replayMethod == "InvokeServer" and replayRemote.InvokeServer then
            local ok, ret = pcall(function() return replayRemote:InvokeServer(table.unpack(replayArgs)) end)
            if ok then
                local id = tonumber(ret) or (type(ret)=="table" and tonumber(ret.Id))
                if id and matches(id) then
                    foundOnce = true
                    stopSelf(self)
                    print("[autoenchantrod] MATCH FOUND via InvokeServer return:", id)
                end
            end
        elseif replayMethod == "FireServer" and replayRemote.FireServer then
            pcall(function() replayRemote:FireServer(table.unpack(replayArgs)) end)
        end
    end)
end

function Feature:Stop()
    stopSelf(self)
end

function Feature:Cleanup()
    stopSelf(self)
    desiredIds, desiredNames = {}, {}
    replayRemote, replayMethod, replayArgs = nil, nil, nil
end

return Feature

