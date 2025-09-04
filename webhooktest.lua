-- FishCatchDetector v2 (safe)
local CFG = {
    WEBHOOK_URL = "https://discordapp.com/api/webhooks/1369085852071759903/clJFD_k9D4QeH6zZpylPId2464XJBLyGDafz8uiTotf2tReSNeZXcyIiJDdUDhu1CCzI",
    ENABLE_REGISTRY_SCAN = true,
    CATCH_WINDOW_SEC = 3,
    DEBUG = false,
    KEYWORDS = {"Fish","Fishing","Caught"},
}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")

getgenv().FishCatchDetector = getgenv().FishCatchDetector or {}
local M = getgenv().FishCatchDetector

-- state
local _conns, _lastRemoteHits, _recentBackpackAdds = {}, {}, {}
local _hooked, _origNamecall
local function now() return os.clock() end
local function log(...) if CFG.DEBUG then warn("[FCD]", ...) end end

-- utils yang sama seperti v1 (dipendekin)
local function http() return (syn and syn.request) or http_request or request or (fluxus and fluxus.request) end
local function sendWebhook(data)
    local req = http(); if not req then return end
    req({Url=CFG.WEBHOOK_URL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=game:GetService("HttpService"):JSONEncode(data)})
end
local function toAttrMap(inst)
    local a = {}
    for k,v in pairs(inst:GetAttributes()) do a[k]=v end
    for _, ch in ipairs(inst:GetChildren()) do if ch:IsA("ValueBase") then a[ch.Name]=ch.Value end end
    return a
end
local function matchesKeywords(remote)
    local n = remote and remote.Name or ""
    local p = remote and tostring(remote:GetFullName()) or ""
    for _,kw in ipairs(CFG.KEYWORDS) do
        kw = kw:lower()
        if n:lower():find(kw) or p:lower():find(kw) then return true end
    end
    return false
end

-- scanner arg → info (disingkat, cukup untuk jalan)
local function deepScan(v, sink, seen)
    seen = seen or {}
    if seen[v] then return end
    seen[v] = true
    local t = typeof(v)
    if t == "table" then
        for k,val in pairs(v) do deepScan(val, sink, seen) end
    elseif t == "Instance" then
        sink(toAttrMap(v), "inst", v)
        for _,ch in ipairs(v:GetChildren()) do deepScan(ch, sink, seen) end
    else
        sink(v, "val")
    end
end
local function extractFishInfoFromArgs(args)
    local info, cands = {}, {}
    deepScan(args, function(x, kind, inst)
        if typeof(x)=="table" then
            if x.FishName or x.Name or x.ItemName or x.Weight or x.Rarity or x.Chance or x.Mutation or x.Mutations then
                table.insert(cands, x)
            end
        elseif kind=="inst" then
            local a = x
            if a.FishName or a.Weight or a.Rarity then table.insert(cands, a) end
        end
    end)
    for _,c in ipairs(cands) do
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

local _registry = nil
local function tryRegistry()
    if _registry ~= nil then return _registry end
    _registry = {}
    local roots = {RS:FindFirstChild("Data"), RS:FindFirstChild("GameData"), RS:FindFirstChild("DataRegistry"), RS}
    local names = {"FishRegistry","Fishes","Fish","Catchables","Items","Loot"}
    for _,r in ipairs(roots) do
        if r then for _,n in ipairs(names) do
            local f = r:FindFirstChild(n, true)
            if f and f:IsA("Folder") then table.insert(_registry, f) end
        end end
    end
    return _registry
end

local function asOneIn(info)
    if info.chance then
        local n = tonumber(info.chance)
        if n and n>0 then return ("1 in %d"):format(math.max(1, math.floor(100/n + 0.5))) end
    end
    if info.rarity and type(info.rarity)=="number" and info.rarity>0 and info.rarity<=1 then
        return ("1 in %d"):format(math.max(1, math.floor(1/info.rarity + 0.5)))
    end
    return "Unknown"
end
local function toKg(w)
    local n = tonumber(w); if not n then return w and tostring(w) or "Unknown" end
    return string.format("%.3f kg", n)
end
local _sendDeb = 0
local function finalize(info, origin)
    if now() - _sendDeb < 0.4 then return end
    _sendDeb = now()
    local mut = "None"
    if info.mutations and type(info.mutations)=="table" then
        local t={} for k,v in pairs(info.mutations) do table.insert(t, tostring(k)..(v~=true and (":"..tostring(v)) or "")) end
        mut = (#t>0) and table.concat(t,", ") or "None"
    elseif info.mutation then mut = tostring(info.mutation) end
    sendWebhook({
        username = ".devlogic notifier",
        embeds = {{
            title = "🐟 New Catch: " .. (info.name or "Unknown"),
            description = ("**Player:** %s\n**Origin:** %s"):format(LocalPlayer.Name, origin or "unknown"),
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            fields = {
                {name="Weight", value=toKg(info.weight), inline=true},
                {name="Rarity", value=asOneIn(info), inline=true},
                {name="Mutation(s)", value=mut, inline=false},
            }
        }}
    })
end

local function onCatchWindowTrySend()
    -- cari hit remote terbaru
    local best
    for i=#_lastRemoteHits,1,-1 do
        local h = _lastRemoteHits[i]
        if now() - h.t <= CFG.CATCH_WINDOW_SEC and matchesKeywords(h.self) then best = h break end
    end
    if best then
        local info = extractFishInfoFromArgs(best.args) or {}
        if info.id then
            for _,root in ipairs(tryRegistry()) do
                for _,item in ipairs(root:GetDescendants()) do
                    if item:IsA("Folder") or item:IsA("Configuration") or item:IsA("ModuleScript") then
                        local a = toAttrMap(item)
                        if a.Id == info.id or a.ItemId == info.id or a.TypeId == info.id then
                            info.name   = info.name   or a.Name or a.FishName or item.Name
                            info.rarity = info.rarity or a.Rarity or a.Tier
                            info.chance = info.chance or a.Chance or a.DropChance
                            break
                        end
                    end
                end
            end
        end
        if next(info) then finalize(info, "Remote:"..best.self.Name); return end
    end
    -- fallback backpack
    for inst,t0 in pairs(_recentBackpackAdds) do
        if inst.Parent==Backpack and now()-t0 <= CFG.CATCH_WINDOW_SEC then
            local a = toAttrMap(inst)
            finalize({
                name = a.FishName or inst.Name,
                weight = a.Weight or a.Mass,
                rarity = a.Rarity or a.Tier,
                chance = a.Chance or a.DropChance,
                mutation = a.Mutation, mutations = a.Mutations
            }, "Backpack:"..inst.Name)
            return
        end
    end
    if CFG.DEBUG then finalize({name="Unknown"}, "Heuristic:NoData") end
end

-- SAFE HOOK
local function hookNamecallOnce()
    if _hooked then return end
    if typeof(hookmetamethod) ~= "function" then
        log("hookmetamethod tidak tersedia → jalan di NON-HOOK mode.")
        _hooked = false
        return
    end
    _origNamecall = _origNamecall or hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        -- jangan ganggu thread caller; cuma *mirror* data
        local method = getnamecallmethod()
        if not checkcaller() and (method=="FireServer" or method=="InvokeServer") and matchesKeywords(self) then
            local packed = table.pack(...)
            task.spawn(function()
                table.insert(_lastRemoteHits, {t=now(), self=self, method=method, args=packed})
                if CFG.DEBUG then log("Remote hit:", self:GetFullName(), method) end
            end)
        end
        return _origNamecall(self, ...)
    end))
    _hooked = true
    log("Safe namecall hook installed.")
end

local function unhookNamecall()
    -- tidak bisa “unhook” via hookmetamethod (API mengembalikan original, bukan setter).
    -- Jadi: kita biarkan hook aktif sampai sesi selesai. Yang penting hook ringan & non-blocking.
    -- Kalau tetap ingin mematikan, require rejoin.
    _hooked = false
end

local function connectSignals()
    table.insert(_conns, Backpack.ChildAdded:Connect(function(inst) _recentBackpackAdds[inst]=now() end))
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local Caught = ls:FindFirstChild("Caught")
        local Data = Caught and (Caught:FindFirstChild("Data") or Caught)
        if Data and Data:IsA("ValueBase") then
            table.insert(_conns, Data.Changed:Connect(function() task.delay(0.05, onCatchWindowTrySend) end))
        end
    end
    local ge = RS:FindFirstChild("GameEvents")
    if ge then
        for _, r in ipairs(ge:GetDescendants()) do
            if r:IsA("RemoteEvent") and matchesKeywords(r) then
                table.insert(_conns, r.OnClientEvent:Connect(function(...)
                    table.insert(_lastRemoteHits, {t=now(), self=r, method="OnClientEvent", args=table.pack(...)})
                    task.delay(0.05, onCatchWindowTrySend)
                end))
            end
        end
    end
end

local function disconnectSignals()
    for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
    table.clear(_conns)
end

function M.Start(opts)
    if opts then for k,v in pairs(opts) do CFG[k]=v end end
    hookNamecallOnce()
    connectSignals()
    log("FishCatchDetector v2 started. DEBUG =", CFG.DEBUG)
end

function M.Kill()
    disconnectSignals()
    unhookNamecall()
    table.clear(_lastRemoteHits)
    table.clear(_recentBackpackAdds)
    log("FishCatchDetector stopped.")
end

return M
