-- FishCatchDetector v2.3 NO-HOOK (Knit/Net aware)
local CFG = {
  WEBHOOK_URL = "https://discordapp.com/api/webhooks/1381266140625637538/lfaMWBjLeexf7H39fNyEEcBAmTg1Tmp7-TZ3xA4jcI2CdRMZUfsvZbXzmsFtqlrLjEKN",
  CATCH_WINDOW_SEC = 3,
  DEBUG = true,            -- nyalain dulu pas investigasi
  WEIGHT_DECIMALS = 2,
  INBOUND_EVENTS = { "RE/FishCaught", "FishCaught", "FishingCompleted", "Caught", "Reward", "Fishing" },

  -- Opsional: mapping rarity jika server cuma kirim tier/nama tanpa chance
  RARITY_ONEIN_MAP = {
    -- ["Common"]="1 in 1", ["Uncommon"]="1 in 3", ["Rare"]="1 in 10",
    -- ["Epic"]="1 in 50", ["Legendary"]="1 in 200",
    -- [1]="1 in 1", [2]="1 in 3", [3]="1 in 10", [4]="1 in 50", [5]="1 in 200",
  },
}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local Backpack = LP:WaitForChild("Backpack")

getgenv().FishCatchDetector = getgenv().FishCatchDetector or {}
local M = getgenv().FishCatchDetector
local _conns, _lastInbound, _recentAdds = {}, {}, {}

local function now() return os.clock() end
local function log(...) if CFG.DEBUG then warn("[FCD-2.3]", ...) end end
local function http() return (syn and syn.request) or http_request or request or (fluxus and fluxus.request) end
local function sendWebhook(embeds)
  local req=http(); if not req then return end
  req({Url=CFG.WEBHOOK_URL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({username=".devlogic notifier", embeds=embeds})})
end

local function toAttrMap(inst)
  local a={} ; for k,v in pairs(inst:GetAttributes()) do a[k]=v end
  for _,ch in ipairs(inst:GetChildren()) do if ch:IsA("ValueBase") then a[ch.Name]=ch.Value end end
  return a
end

-- ===== Registry scan (id→metadata) =====
local _regs
local function findRegistries()
  if _regs then return _regs end
  _regs = {}
  local roots={RS:FindFirstChild("Data"), RS:FindFirstChild("GameData"), RS:FindFirstChild("DataRegistry"), RS}
  local names={"FishRegistry","Fishes","Fish","Catchables","Items","Loot"}
  for _,r in ipairs(roots) do
    if r then for _,n in ipairs(names) do
      local f=r:FindFirstChild(n, true)
      if f and f:IsA("Folder") then table.insert(_regs, f) end
    end end
  end
  return _regs
end

local function enrichFromRegistry(info)
  if not info then return info end
  local id = info.id or info.name
  if not id then return info end
  for _,root in ipairs(findRegistries()) do
    for _,d in ipairs(root:GetDescendants()) do
      if d:IsA("Folder") or d:IsA("Configuration") or d:IsA("ModuleScript") then
        local a = toAttrMap(d)
        if a.Id == id or a.ItemId == id or a.TypeId == id or d.Name == id then
          info.name       = info.name       or a.FishName or a.Name or d.Name
          info.rarity     = info.rarity     or a.Rarity or a.RarityName or a.Tier
          info.rarityName = info.rarityName or a.RarityName
          info.rarityTier = info.rarityTier or a.RarityTier or a.Tier
          info.chance     = info.chance     or a.Chance or a.DropChance or a.Probability
          return info
        end
      end
    end
  end
  return info
end

-- ===== Formatting =====
local function toKg(w)
  local n=tonumber(w); if not n then return w and tostring(w) or "Unknown" end
  return string.format("%0."..tostring(CFG.WEIGHT_DECIMALS).."f kg", n)
end

local function fmtOneIn(info)
  if info and info.chance then
    local n=tonumber(info.chance)
    if n and n>0 then return ("1 in %d"):format(math.max(1, math.floor(100/n + 0.5))) end
  end
  local key = (info and (info.rarity or info.rarityName or info.rarityTier))
  if key ~= nil then
    local m = CFG.RARITY_ONEIN_MAP[key]
    if m then return m end
  end
  return "Unknown"
end

-- ===== Utility absorb / scanner =====
local function absorb(dst, t)
  if type(t)~="table" then return end
  dst.id         = dst.id         or t.Id or t.ItemId or t.TypeId or t.UID or t.IdStr
  dst.name       = dst.name       or t.FishName or t.Name or t.ItemName or t.DisplayName or t.Species
  dst.weight     = dst.weight     or t.Weight or t.weight or t.Mass or t.WeightKg or t.Kg
  dst.chance     = dst.chance     or t.Chance or t.DropChance or t.Probability or t.chance
  dst.rarity     = dst.rarity     or t.Rarity or t.rarity or t.Tier
  dst.rarityName = dst.rarityName or t.RarityName or t.rarityName
  dst.rarityTier = dst.rarityTier or t.RarityTier or t.tier
  dst.mutation   = dst.mutation   or t.Mutation or t.mutation
  dst.mutations  = dst.mutations  or t.Mutations or t.mutations or t.Modifiers
end

local function deepAbsorb(dst, x, seen)
  seen=seen or {}; if seen[x] then return end; seen[x]=true
  local ty=typeof(x)
  if ty=="table" then
    absorb(dst, x)
    for k,v in pairs(x) do deepAbsorb(dst, v, seen) end
  elseif ty=="Instance" then
    absorb(dst, toAttrMap(x))
    for _,ch in ipairs(x:GetChildren()) do deepAbsorb(dst, ch, seen) end
  elseif ty=="string" or ty=="number" then
    -- mungkin id atau nama langsung
    dst.id = dst.id or x
    if ty=="string" and (#x <= 60) then dst.name = dst.name or x end
  end
end

-- ===== ArgProbe (DEBUG) =====
local function previewVal(v)
  local t=typeof(v)
  if t=="string" then
    if #v>80 then return string.sub(v,1,77).."..."
    else return v end
  elseif t=="number" or t=="boolean" then
    return tostring(v)
  elseif t=="Instance" then
    return v.ClassName..":"..v.Name
  elseif t=="table" then
    local keys={} ; for k,_ in pairs(v) do table.insert(keys, tostring(k)) end
    table.sort(keys)
    return "table{"..table.concat(keys, ", ").."}"
  else
    return t
  end
end

local function argProbePacked(evName, packed)
  if not CFG.DEBUG then return end
  warn(("[FCD-2.3] %s argc=%d"):format(evName, packed.n or #packed))
  for i=1,(packed.n or #packed) do
    local a=packed[i]
    warn(("  ▸ arg[%d]: %s"):format(i, previewVal(a)))
    if type(a)=="table" then
      for k,v in pairs(a) do
        local pv = previewVal(v)
        warn(("     - [%s] = %s"):format(tostring(k), pv))
      end
    end
  end
end

-- ===== Targeted decoder untuk RE/FishCaught =====
local function decode_RE_FishCaught(packed)
  -- Coba 3 pola umum:
  -- P1: arg1=table(detail ikan), arg2=table(meta)
  -- P2: arg1=string/number id, arg2=table(detail)
  -- P3: arg1=Instance (item), arg2=table(meta)
  local info = {}
  local a1, a2 = packed[1], packed[2]

  -- print struktur arg
  argProbePacked("RE/FishCaught", packed)

  if type(a1)=="table" then
    deepAbsorb(info, a1)
    if type(a2)=="table" then deepAbsorb(info, a2) end
  elseif (typeof(a1)=="string" or typeof(a1)=="number") then
    info.id = tostring(a1)
    if type(a2)=="table" or typeof(a2)=="Instance" then deepAbsorb(info, a2) end
  elseif typeof(a1)=="Instance" then
    deepAbsorb(info, a1)
    if type(a2)=="table" then deepAbsorb(info, a2) end
  end

  info = enrichFromRegistry(info)
  return next(info) and info or nil
end

local EVENT_DECODERS = { ["RE/FishCaught"]=decode_RE_FishCaught }

-- ===== Pipeline =====
local _debounce = 0
local function send(info, origin)
  if now()-_debounce < 0.35 then return end
  _debounce = now()
  local mut="None"
  if type(info.mutations)=="table" then
    local t={} ; for k,v in pairs(info.mutations) do table.insert(t, tostring(k)..(v~=true and (":"..tostring(v)) or "")) end
    mut=(#t>0) and table.concat(t,", ") or "None"
  elseif info.mutation then mut=tostring(info.mutation) end

  sendWebhook({{
    title = "🐟 New Catch: " .. (info.name or "Unknown"),
    description = ("**Player:** %s\n**Origin:** %s"):format(LP.Name, origin or "unknown"),
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    fields = {
      {name="Weight", value=toKg(info.weight), inline=true},
      {name="Rarity", value=fmtOneIn(info), inline=true},
      {name="Mutation(s)", value=mut, inline=false},
    }
  }})
end

local function onCatchWindow()
  for i=#_lastInbound,1,-1 do
    local hit=_lastInbound[i]
    if now()-hit.t <= CFG.CATCH_WINDOW_SEC then
      local decoder = EVENT_DECODERS[hit.name]
      local info = (decoder and decoder(hit.args)) or (function(p) local o={} deepAbsorb(o, p) return next(o) and o or nil end)(hit.args)
      if info then send(info, "OnClientEvent:"..hit.name); return end
    end
  end
  for inst,t0 in pairs(_recentAdds) do
    if inst.Parent==Backpack and now()-t0 <= CFG.CATCH_WINDOW_SEC then
      local a=toAttrMap(inst)
      send({
        name=a.FishName or inst.Name,
        weight=a.Weight or a.Mass,
        rarity=a.Rarity or a.RarityName or a.Tier,
        mutation=a.Mutation, mutations=a.Mutations
      }, "Backpack:"..inst.Name)
      return
    end
  end
  if CFG.DEBUG then send({name="Unknown"}, "Heuristic:NoData") end
end

-- ===== Wiring =====
local function connectInbound()
  local ge = RS:FindFirstChild("GameEvents") or RS
  local function want(nm)
    local n=nm:lower()
    for _,kw in ipairs(CFG.INBOUND_EVENTS) do if n:find(kw:lower()) then return true end end
    return false
  end
  local function maybeConnect(d)
    if d:IsA("RemoteEvent") and want(d.Name) then
      table.insert(_conns, d.OnClientEvent:Connect(function(...)
        local packed = table.pack(...)
        table.insert(_lastInbound, {t=now(), name=d.Name, args=packed})
        log("Inbound:", d:GetFullName(), "argc=", packed.n or select("#", ...))
        task.defer(onCatchWindow)
      end))
      log("Hooked inbound:", d:GetFullName())
    end
  end
  for _,d in ipairs(ge:GetDescendants()) do maybeConnect(d) end
  table.insert(_conns, ge.DescendantAdded:Connect(maybeConnect))
end

local function connectSignals()
  table.insert(_conns, Backpack.ChildAdded:Connect(function(inst) _recentAdds[inst]=now() end))
  local ls = LP:FindChild("leaderstats") or LP:FindFirstChild("leaderstats")
  if ls then
    local Caught = ls:FindFirstChild("Caught")
    local Data = Caught and (Caught:FindFirstChild("Data") or Caught)
    if Data and Data:IsA("ValueBase") then
      table.insert(_conns, Data.Changed:Connect(function() task.defer(onCatchWindow) end))
    end
  end
  connectInbound()
end

function M.Start(opts)
  if opts then for k,v in pairs(opts) do CFG[k]=v end end
  connectSignals()
  log("FCD 2.3 NO-HOOK started. DEBUG=", CFG.DEBUG)
end

function M.Kill()
  for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
  table.clear(_conns); table.clear(_lastInbound); table.clear(_recentAdds)
  log("FCD 2.3 NO-HOOK stopped.")
end

function M.SetConfig(patch) for k,v in pairs(patch or {}) do CFG[k]=v end end

return M
