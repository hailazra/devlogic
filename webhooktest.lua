-- FishCatchDetector v2.3.1 NO-HOOK (hotfix)
-- - Fix: FindChild -> FindFirstChild
-- - ASCII only, safeClear, extra guards

local CFG = {
  WEBHOOK_URL = "https://discordapp.com/api/webhooks/1369085852071759903/clJFD_k9D4QeH6zZpylPId2464XJBLyGDafz8uiTotf2tReSNeZXcyIiJDdUDhu1CCzI",
  CATCH_WINDOW_SEC = 3,
  DEBUG = true,
  WEIGHT_DECIMALS = 2,
  INBOUND_EVENTS = { "RE/FishCaught", "FishCaught", "FishingCompleted", "Caught", "Reward", "Fishing" },

  -- Optional mappings if server doesn't send chance%
  RARITY_ONEIN_MAP = {
    -- ["Common"]="1 in 1", ["Uncommon"]="1 in 3", ["Rare"]="1 in 10",
    -- ["Epic"]="1 in 50", ["Legendary"]="1 in 200",
    -- [1]="1 in 1", [2]="1 in 3", [3]="1 in 10", [4]="1 in 50", [5]="1 in 200",
  },

  -- Optional: manual ID->Name/Rarity if args only give numeric IDs (fill when needed)
  ID_NAME_MAP = {
    -- ["173"] = "Hedgehog Fish",
  },
  ID_RARITY_MAP = {
    -- ["173"] = "Rare",
  },
}

-- Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local Backpack = LP:WaitForChild("Backpack", 10)

-- Global handle
getgenv().FishCatchDetector = getgenv().FishCatchDetector or {}
local M = getgenv().FishCatchDetector

-- State
local _conns, _lastInbound, _recentAdds = {}, {}, {}

-- Utils
local function now() return os.clock() end
local function log(...) if CFG.DEBUG then warn("[FCD-2.3.1]", ...) end end
local function http()
  return (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
end
local function sendWebhook(embeds)
  local req = http(); if not req then return end
  req({
    Url = CFG.WEBHOOK_URL,
    Method = "POST",
    Headers = {["Content-Type"]="application/json"},
    Body = HttpService:JSONEncode({username=".devlogic notifier", embeds=embeds})
  })
end
local function safeClear(t)
  if table and table.clear then table.clear(t) else for k in pairs(t) do t[k]=nil end end
end

local function toAttrMap(inst)
  local a = {}
  if not inst or not inst.GetAttributes then return a end
  for k,v in pairs(inst:GetAttributes()) do a[k]=v end
  for _,ch in ipairs(inst:GetChildren()) do if ch:IsA("ValueBase") then a[ch.Name]=ch.Value end end
  return a
end

-- Registry scan
local _regs
local function findRegistries()
  if _regs then return _regs end
  _regs = {}
  local roots = {
    RS:FindFirstChild("Data"),
    RS:FindFirstChild("GameData"),
    RS:FindFirstChild("DataRegistry"),
    RS
  }
  local names = {"FishRegistry","Fishes","Fish","Catchables","Items","Loot"}
  for _,r in ipairs(roots) do
    if r then
      for _,n in ipairs(names) do
        local f = r:FindFirstChild(n, true)
        if f and f:IsA("Folder") then table.insert(_regs, f) end
      end
    end
  end
  return _regs
end

local function enrichFromRegistry(info)
  if not info then return info end
  local id = info.id or (info.name and tostring(info.name))
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

-- Formatting
local function toKg(w)
  local n = tonumber(w)
  if not n then return (w and tostring(w)) or "Unknown" end
  return string.format("%0."..tostring(CFG.WEIGHT_DECIMALS).."f kg", n)
end

local function fmtOneIn(info)
  if info and info.chance then
    local n = tonumber(info.chance)
    if n and n > 0 then return ("1 in %d"):format(math.max(1, math.floor(100/n + 0.5))) end
  end
  local key = info and (info.rarity or info.rarityName or info.rarityTier)
  if key ~= nil then
    local mapped = CFG.RARITY_ONEIN_MAP[key]
    if mapped then return mapped end
  end
  return "Unknown"
end

-- Absorb
local function absorb(dst, t)
  if type(t) ~= "table" then return end
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
  seen = seen or {}
  if seen[x] then return end
  seen[x] = true
  local ty = typeof(x)
  if ty == "table" then
    absorb(dst, x)
    for _,v in pairs(x) do deepAbsorb(dst, v, seen) end
  elseif ty == "Instance" then
    absorb(dst, toAttrMap(x))
    for _,ch in ipairs(x:GetChildren()) do deepAbsorb(dst, ch, seen) end
  elseif ty == "string" or ty == "number" then
    dst.id = dst.id or tostring(x)
    if ty == "string" and #x <= 60 then dst.name = dst.name or x end
  end
end

-- Debug probe
local function previewVal(v)
  local t = typeof(v)
  if t == "string" then
    return (#v > 80) and (v:sub(1,77).."...") or v
  elseif t == "number" or t == "boolean" then
    return tostring(v)
  elseif t == "Instance" then
    return v.ClassName..":"..v.Name
  elseif t == "table" then
    local keys = {}
    for k,_ in pairs(v) do table.insert(keys, tostring(k)) end
    table.sort(keys)
    return "table{"..table.concat(keys, ", ").."}"
  else
    return t
  end
end

local function argProbePacked(evName, packed)
  if not CFG.DEBUG then return end
  warn(("[FCD] %s argc=%d"):format(evName, packed.n or #packed))
  for i=1,(packed.n or #packed) do
    local a = packed[i]
    warn(("  arg[%d]: %s"):format(i, previewVal(a)))
    if type(a)=="table" then
      for k,v in pairs(a) do
        warn(("    - [%s] = %s"):format(tostring(k), previewVal(v)))
      end
    end
  end
end

-- Decoder for RE/FishCaught
local function decode_RE_FishCaught(packed)
  local info = {}
  local a1, a2 = packed[1], packed[2]
  argProbePacked("RE/FishCaught", packed)

  if type(a1) == "table" then
    deepAbsorb(info, a1)
    if type(a2) == "table" or typeof(a2)=="Instance" then deepAbsorb(info, a2) end
  elseif typeof(a1) == "string" or typeof(a1) == "number" then
    info.id = tostring(a1)
    if type(a2) == "table" or typeof(a2)=="Instance" then deepAbsorb(info, a2) end
  elseif typeof(a1) == "Instance" then
    deepAbsorb(info, a1)
    if type(a2) == "table" then deepAbsorb(info, a2) end
  end

  -- Manual map if only ID present
  if (not info.name) and info.id and CFG.ID_NAME_MAP[info.id] then
    info.name = CFG.ID_NAME_MAP[info.id]
  end
  if (not info.rarity) and info.id and CFG.ID_RARITY_MAP[info.id] then
    info.rarity = CFG.ID_RARITY_MAP[info.id]
  end

  info = enrichFromRegistry(info)
  return next(info) and info or nil
end

local EVENT_DECODERS = {
  ["RE/FishCaught"] = decode_RE_FishCaught,
}

-- Send pipeline
local _debounce = 0
local function send(info, origin)
  if now() - _debounce < 0.35 then return end
  _debounce = now()

  local mut = "None"
  if type(info.mutations) == "table" then
    local t = {}
    for k,v in pairs(info.mutations) do table.insert(t, tostring(k)..((v~=true and v~=nil) and (":"..tostring(v)) or "")) end
    mut = (#t > 0) and table.concat(t, ", ") or "None"
  elseif info.mutation then
    mut = tostring(info.mutation)
  end

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
  for i = #_lastInbound, 1, -1 do
    local hit = _lastInbound[i]
    if now() - hit.t <= CFG.CATCH_WINDOW_SEC then
      local decoder = EVENT_DECODERS[hit.name]
      local info = (decoder and decoder(hit.args)) or (function(p) local o = {} deepAbsorb(o, p) return next(o) and o or nil end)(hit.args)
      if info then send(info, "OnClientEvent:"..hit.name); return end
    end
  end
  for inst, t0 in pairs(_recentAdds) do
    if inst.Parent == Backpack and now() - t0 <= CFG.CATCH_WINDOW_SEC then
      local a = toAttrMap(inst)
      send({
        name = a.FishName or inst.Name,
        weight = a.Weight or a.Mass,
        rarity = a.Rarity or a.RarityName or a.Tier,
        mutation = a.Mutation, mutations = a.Mutations
      }, "Backpack:"..inst.Name)
      return
    end
  end
  if CFG.DEBUG then send({name="Unknown"}, "Heuristic:NoData") end
end

-- Wiring
local function connectInbound()
  local ge = RS:FindFirstChild("GameEvents") or RS
  local function want(nm)
    local n = string.lower(nm)
    for _,kw in ipairs(CFG.INBOUND_EVENTS) do if string.find(n, string.lower(kw)) then return true end end
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
  if Backpack then
    table.insert(_conns, Backpack.ChildAdded:Connect(function(inst) _recentAdds[inst] = now() end))
  end
  local ls = LP:FindFirstChild("leaderstats")
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
  if opts then for k,v in pairs(opts) do CFG[k] = v end end
  connectSignals()
  log("FCD 2.3.1 NO-HOOK started. DEBUG=", CFG.DEBUG)
end

function M.Kill()
  for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
  safeClear(_conns); safeClear(_lastInbound); safeClear(_recentAdds)
  log("FCD 2.3.1 NO-HOOK stopped.")
end

function M.SetConfig(patch)
  for k,v in pairs(patch or {}) do CFG[k] = v end
end

return M

