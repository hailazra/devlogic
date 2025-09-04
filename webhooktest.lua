--// ===========================
--// FishCatchDetector (Client)
--// by .devlogic
--// ===========================

local CFG = {
    WEBHOOK_URL = "https://discordapp.com/api/webhooks/1369085852071759903/clJFD_k9D4QeH6zZpylPId2464XJBLyGDafz8uiTotf2tReSNeZXcyIiJDdUDhu1CCzI", -- ganti ini
    ENABLE_REGISTRY_SCAN = true,
    CATCH_WINDOW_SEC = 3,
    DEBUG = false,
    KEYWORDS = {"Fish","Fishing","Caught"}, -- filter remote keywords
}

--// Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")

--// Globals (optional, integrate with RemnantGlobals jika mau)
getgenv().FishCatchDetector = getgenv().FishCatchDetector or {}
local M = getgenv().FishCatchDetector

--// State
local _conns = {}
local _oldNamecall
local _hooked = false
local _lastRemoteHits = {} -- { {t=os.clock(), self=Remote, method="FireServer", args={...}} }
local _catchWindowUntil = 0
local _recentBackpackAdds = {} -- map instance → tstamp
local _registryCandidates = {}
local _sentDebounce = 0

--// Utils
local function safe(t, k) local ok, v = pcall(function() return t[k] end); return ok and v or nil end
local function isTable(x) return typeof(x) == "table" end
local function now() return os.clock() end
local function within(t0, dur) return now() - t0 <= dur end
local function log(...) if CFG.DEBUG then warn("[FishCatchDetector]", ...) end end

local function http()
    return (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
end

local function sendWebhook(data)
    local req = http()
    if not req then
        log("Tidak ada HTTP request fn (syn.request/http_request). Webhook skip.")
        return
    end
    local payload = game:GetService("HttpService"):JSONEncode(data)
    req({
        Url = CFG.WEBHOOK_URL,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = payload
    })
end

local function asPercentToOneIn(pct)
    if type(pct) ~= "number" or pct <= 0 then return nil end
    return math.max(1, math.floor(100 / pct + 0.5))
end

local function tryFindFishRegistry()
    if #_registryCandidates > 0 then return _registryCandidates end
    local roots = {RS:FindFirstChild("Data"), RS:FindFirstChild("GameData"), RS:FindFirstChild("DataRegistry"), RS}
    local names = {"FishRegistry","Fishes","Fish","Catchables","Items","Loot"}
    for _, root in ipairs(roots) do
        if root then
            for _, n in ipairs(names) do
                local f = root:FindFirstChild(n, true)
                if f and f:IsA("Folder") then table.insert(_registryCandidates, f) end
            end
        end
    end
    return _registryCandidates
end

local function toAttrMap(inst)
    local a = {}
    for k,v in pairs(inst:GetAttributes()) do a[k]=v end
    -- also scan ValueObjects
    for _, child in ipairs(inst:GetChildren()) do
        if child:IsA("ValueBase") then a[child.Name] = child.Value end
    end
    return a
end

local function matchesKeywords(remote)
    local n = remote and remote.Name or ""
    for _, kw in ipairs(CFG.KEYWORDS) do
        if string.find(string.lower(n), string.lower(kw)) then return true end
    end
    -- allow by parent path
    local p = tostring(remote:GetFullName())
    for _, kw in ipairs(CFG.KEYWORDS) do
        if string.find(string.lower(p), string.lower(kw)) then return true end
    end
    return false
end

local function deepScan(v, sink)
    local seen = {}
    local function rec(x, path)
        if seen[x] then return end
        seen[x] = true
        local t = typeof(x)
        if t == "table" then
            for k,val in pairs(x) do rec(val, (path and (path.."."..tostring(k))) or tostring(k)) end
        elseif t == "Instance" then
            -- scan attributes if looks like item
            local attrs = toAttrMap(x)
            sink(attrs, path, x)
            for _, ch in ipairs(x:GetChildren()) do rec(ch, (path and (path.."."..ch.Name)) or ch.Name) end
        else
            sink(x, path)
        end
    end
    rec(v, nil)
end

local function extractFishInfoFromArgs(args)
    local info = {}
    local candidates = {}

    local function sink(x, path, inst)
        if typeof(x) == "table" then
            -- might be dict-like with fields we care
            local n = x.Name or x.FishName or x.ItemName
            local id = x.Id or x.ItemId or x.TypeId
            local w  = x.Weight or x.weight or x.Mass
            local r  = x.Rarity or x.rarity or x.Tier
            local p  = x.Chance or x.DropChance or x.chance
            local m  = x.Mutations or x.mutations or x.Mutation or x.mutation
            if n or id or w or r or p or m then table.insert(candidates, x) end
        elseif typeof(x) == "Instance" and inst then
            local attrs = toAttrMap(inst)
            if attrs.ItemType == "Fish" or attrs.FishName or attrs.Rarity or attrs.Weight then
                table.insert(candidates, attrs)
            end
        end
    end

    deepScan(args, sink)
    -- merge best candidate
    for _, c in ipairs(candidates) do
        info.name     = info.name     or c.FishName or c.Name or c.ItemName
        info.id       = info.id       or c.Id or c.ItemId or c.TypeId or c.UID
        info.weight   = info.weight   or c.Weight or c.weight or c.Mass
        info.rarity   = info.rarity   or c.Rarity or c.rarity or c.Tier
        info.chance   = info.chance   or c.Chance or c.DropChance or c.chance
        info.mutation = info.mutation or c.Mutation or c.mutation
        info.mutations= info.mutations or c.Mutations or c.mutations
    end
    return next(info) and info or nil
end

local function findNewBackpackFish()
    local best
    local t0 = now()
    for inst, tAdded in pairs(_recentBackpackAdds) do
        if within(tAdded, CFG.CATCH_WINDOW_SEC) and inst.Parent == Backpack then
            local attrs = toAttrMap(inst)
            if attrs.FishName or attrs.Weight or attrs.Rarity or string.find(string.lower(inst.Name), "fish") then
                best = {instance=inst, attrs=attrs}; break
            end
        end
    end
    return best
end

local function enrichFromRegistry(info)
    if not CFG.ENABLE_REGISTRY_SCAN then return info end
    if info and (info.name and info.rarity and info.chance) then return info end
    local regs = tryFindFishRegistry()
    if #regs == 0 then return info end
    local id = info and info.id
    if not id then return info end
    for _, root in ipairs(regs) do
        for _, item in ipairs(root:GetDescendants()) do
            if item:IsA("Folder") or item:IsA("Configuration") or item:IsA("ModuleScript") then
                local attrs = toAttrMap(item)
                if attrs.Id == id or attrs.ItemId == id or attrs.TypeId == id then
                    info.name   = info.name   or attrs.Name or attrs.FishName or item.Name
                    info.rarity = info.rarity or attrs.Rarity or attrs.Tier
                    info.chance = info.chance or attrs.Chance or attrs.DropChance
                    return info
                end
            end
        end
    end
    return info
end

local function formatOneIn(info)
    if info.chance then
        local oneIn = asPercentToOneIn(tonumber(info.chance))
        if oneIn then return ("1 in %d"):format(oneIn) end
    end
    if info.rarity and type(info.rarity) == "number" and info.rarity > 0 and info.rarity <= 1 then
        local oneIn = math.max(1, math.floor(1/info.rarity + 0.5))
        return ("1 in %d"):format(oneIn)
    end
    return "Unknown"
end

local function toKg(w)
    if not w then return nil end
    local n = tonumber(w)
    if not n then return tostring(w) end
    -- asumsi w sudah kg; jika grams deteksi > 50? tidak pasti → tampilkan raw
    return ("%0.3f kg"):format(n)
end

local function finalizeAndSend(info, origin)
    if now() - _sentDebounce < 0.5 then return end
    _sentDebounce = now()

    local fishName = info.name or "Unknown"
    local weight = toKg(info.weight) or "Unknown"
    local rarityOneIn = formatOneIn(info)
    local mutText = "None"
    if info.mutations and type(info.mutations) == "table" then
        local list = {}
        for k,v in pairs(info.mutations) do table.insert(list, tostring(k) .. (v ~= true and (":"..tostring(v)) or "")) end
        mutText = (#list>0) and table.concat(list, ", ") or "None"
    elseif info.mutation then
        mutText = tostring(info.mutation)
    end

    local desc = ("**Player:** %s\n**Origin:** %s"):format(LocalPlayer.Name, origin or "unknown")
    local embed = {
        title = "🐟 New Catch: " .. fishName,
        description = desc,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        fields = {
            { name = "Weight", value = weight, inline = true },
            { name = "Rarity", value = rarityOneIn, inline = true },
            { name = "Mutation(s)", value = mutText, inline = false },
        }
    }
    sendWebhook({username=".devlogic notifier", embeds={embed}})
    log("Webhook sent for", fishName)
end

local function onCatchWindowTrySend()
    -- 1) Prefer remote args
    local bestRemote
    for i = #_lastRemoteHits, 1, -1 do
        local hit = _lastRemoteHits[i]
        if within(hit.t, CFG.CATCH_WINDOW_SEC) and matchesKeywords(hit.self) then
            bestRemote = hit; break
        end
    end

    local info
    if bestRemote then
        info = extractFishInfoFromArgs(bestRemote.args) or {}
        info = enrichFromRegistry(info)
        if info and next(info) then
            finalizeAndSend(info, "Remote:" .. bestRemote.self.Name)
            return
        end
    end

    -- 2) Fallback to backpack instance
    local bp = findNewBackpackFish()
    if bp then
        local attrs = bp.attrs
        local i = {
            name = attrs.FishName or bp.instance.Name,
            weight = attrs.Weight or attrs.Mass,
            rarity = attrs.Rarity or attrs.Tier,
            chance = attrs.Chance or attrs.DropChance,
            mutation = attrs.Mutation,
            mutations = attrs.Mutations,
        }
        finalizeAndSend(i, "Backpack:" .. bp.instance.Name)
        return
    end

    -- 3) As last resort, still send minimal record so kamu bisa lihat path apa yang harus digali
    if CFG.DEBUG then
        finalizeAndSend({name="Unknown", weight=nil, rarity=nil, chance=nil, mutation=nil}, "Heuristic:NoData")
    end
end

--// Hooks & Signals
local function hookNamecallOnce()
    if _hooked then return end
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    _oldNamecall = _oldNamecall or mt.__namecall

    mt.__namecall = function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") then
            local args = {...}
            local ok, firstStr = pcall(function()
                local a = args[1]
                return typeof(a) == "string" and a or nil
            end)
            local plausible = matchesKeywords(self)
            if ok and firstStr then
                for _, kw in ipairs(CFG.KEYWORDS) do
                    if string.find(string.lower(firstStr), string.lower(kw)) then plausible = true break end
                end
            end
            if plausible then
                table.insert(_lastRemoteHits, {t=now(), self=self, method=method, args=args})
                if CFG.DEBUG then
                    log("Remote hit:", self:GetFullName(), method, args and #args or 0)
                end
            end
        end
        return _oldNamecall(self, ...)
    end
    setreadonly(mt, true)
    _hooked = true
    log("Namecall hook installed.")
end

local function unhookNamecall()
    if not _hooked or not _oldNamecall then return end
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    mt.__namecall = _oldNamecall
    setreadonly(mt, true)
    _hooked = false
    log("Namecall hook removed.")
end

local function connectSignals()
    -- Backpack additions
    table.insert(_conns, Backpack.ChildAdded:Connect(function(inst)
        _recentBackpackAdds[inst] = now()
    end))

    -- leaderstats watcher
    local ls = LocalPlayer:WaitForChild("leaderstats", 10)
    if ls then
        local Caught = ls:FindFirstChild("Caught")
        if Caught then
            local Data = Caught:FindFirstChild("Data") or Caught -- handle both patterns
            if Data and Data:IsA("ValueBase") then
                table.insert(_conns, Data.Changed:Connect(function()
                    _catchWindowUntil = now() + CFG.CATCH_WINDOW_SEC
                    task.delay(0.1, onCatchWindowTrySend)
                end))
            end
        end
    end

    -- (Optional) listen to candidate RemoteEvents pushing to client
    local ge = RS:FindFirstChild("GameEvents")
    if ge then
        for _, r in ipairs(ge:GetDescendants()) do
            if r:IsA("RemoteEvent") and matchesKeywords(r) then
                table.insert(_conns, r.OnClientEvent:Connect(function(...)
                    table.insert(_lastRemoteHits, {t=now(), self=r, method="OnClientEvent", args={...}})
                    _catchWindowUntil = now() + CFG.CATCH_WINDOW_SEC
                    task.delay(0.05, onCatchWindowTrySend)
                end))
            end
        end
    end

    log("Signals connected.")
end

local function disconnectSignals()
    for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
    table.clear(_conns)
end

--// Public API
function M.Start(opts)
    if opts then for k,v in pairs(opts) do CFG[k]=v end end
    hookNamecallOnce()
    connectSignals()
    log("FishCatchDetector started. Debug =", CFG.DEBUG)
end

function M.Kill()
    disconnectSignals()
    unhookNamecall()
    table.clear(_lastRemoteHits)
    table.clear(_recentBackpackAdds)
    log("FishCatchDetector killed.")
end

-- Auto-start if desired:
-- M.Start()
return M
