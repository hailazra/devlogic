-- FishCatchDetector v3.0.0
--
-- Patched version implementing robust fish detection without metatable hooks.
-- This script listens for client-side fishing events and correlates them with
-- inventory changes. It also builds a fish database by scanning known
-- registries and requiring item ModuleScripts in ReplicatedStorage.Items.
-- When a catch occurs the script sends a Discord webhook with the fish name,
-- weight, rarity (expressed as "1 in X" if possible) and any mutations.

local CFG = {
  -- Replace this URL with your own Discord webhook endpoint
  WEBHOOK_URL = "https://discordapp.com/api/webhooks/1369085852071759903/clJFD_k9D4QeH6zZpylPId2464XJBLyGDafz8uiTotf2tReSNeZXcyIiJDdUDhu1CCzI",
  CATCH_WINDOW_SEC = 3,
  DEBUG = true,
  WEIGHT_DECIMALS = 2,
  -- RemoteEvent names to hook inbound for fish catches
  INBOUND_EVENTS = { "RE/FishCaught", "FishCaught", "FishingCompleted", "Caught", "Reward", "Fishing" },
  -- Mapping of rarity names or tiers to "1 in X". This table can be customised
  -- to suit your game's probability distribution. It will be used when no
  -- explicit chance value is provided by the server.
  RARITY_ONEIN_MAP = {
    [1] = "1 in 2", [2] = "1 in 5", [3] = "1 in 15", [4] = "1 in 75", [5] = "1 in 300",
    [6] = "1 in 1000", [7] = "1 in 2500", [8] = "1 in 5000",
    Common = "1 in 2", Uncommon = "1 in 5", Rare = "1 in 15",
    Epic = "1 in 75", Legendary = "1 in 300", Mythic = "1 in 1000",
    Exotic = "1 in 2500", Ancient = "1 in 5000",
  },
  -- Internal maps populated at runtime: fishId → name and fishId → rarity
  ID_NAME_MAP = {},
  ID_RARITY_MAP = {},
}

-- Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local Backpack = LP:WaitForChild("Backpack", 10)

-- Expose module via global environment for easy access
getgenv().FishCatchDetector = getgenv().FishCatchDetector or {}
local M = getgenv().FishCatchDetector

-- State
local _conns = {}
local _lastInbound = {}
local _recentAdds = {}

-- Utility functions
local function now() return os.clock() end
local function log(...)
  if CFG.DEBUG then warn("[FCD-3.0]", ...) end
end
local function http()
  return (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
end
local function sendWebhook(embeds)
  local req = http(); if not req then return end
  req({
    Url = CFG.WEBHOOK_URL,
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body = HttpService:JSONEncode({ username = ".devlogic notifier", embeds = embeds }),
  })
end
local function safeClear(t)
  if table and table.clear then
    table.clear(t)
  else
    for k in pairs(t) do t[k] = nil end
  end
end

-- Extract attributes from an instance. Also recurses into ValueBase children.
local function toAttrMap(inst)
  local a = {}
  if not inst then return a end
  if inst.GetAttributes then
    for k,v in pairs(inst:GetAttributes()) do a[k] = v end
  end
  for _,ch in ipairs(inst:GetChildren()) do
    if ch:IsA("ValueBase") then
      a[ch.Name] = ch.Value
    elseif ch:IsA("Folder") or ch:IsA("Configuration") then
      -- Recurse into nested containers for attributes
      local nested = toAttrMap(ch)
      for k,v in pairs(nested) do a[k] = v end
    end
  end
  return a
end

-- Registry scanning
local _regs
local _fishData
local function findRegistries()
  if _regs then return _regs end
  _regs = {}
  -- Candidate roots to search for fish definitions. These cover common naming patterns.
  local roots = {
    RS:FindFirstChild("Data"),
    RS:FindFirstChild("GameData"),
    RS:FindFirstChild("DataRegistry"),
    RS:FindFirstChild("Registry"),
    RS:FindFirstChild("Assets"),
    RS:FindFirstChild("Items"),
    RS:FindFirstChild("Shared"),
    RS,
  }
  local names = {
    "FishRegistry", "Fishes", "Fish", "Catchables", "Items", "Loot",
    "FishData", "CatchableData", "ItemData", "Registry", "Database",
  }
  for _,root in ipairs(roots) do
    if root then
      for _,n in ipairs(names) do
        local f = root:FindFirstChild(n, true)
        if f then table.insert(_regs, f) end
      end
      -- Also include the root itself
      table.insert(_regs, root)
    end
  end
  log("Found registries:", #_regs)
  return _regs
end

-- Build a fish database. The database maps fish IDs (as strings) to a table
-- containing name, rarity, chance and mutations. It scans known registries for
-- attributes and additionally requires ModuleScripts in ReplicatedStorage.Items
-- whose Data.Type == "Fishes".
local function buildFishDatabase()
  if _fishData then return _fishData end
  _fishData = {}
  -- Scan attribute-based registries
  for _,root in ipairs(findRegistries()) do
    for _,d in ipairs(root:GetDescendants()) do
      if d:IsA("Folder") or d:IsA("Configuration") then
        local a = toAttrMap(d)
        local id = a.Id or a.ItemId or a.TypeId or a.FishId or d.Name
        if id then
          local entry = {
            name = a.FishName or a.Name or a.ItemName or a.DisplayName or d.Name,
            rarity = a.Rarity or a.RarityName or a.Tier or a.RarityTier,
            chance = a.Chance or a.DropChance or a.Probability,
            mutations = a.Mutations or a.Modifiers,
          }
          _fishData[tostring(id)] = entry
          if entry.name then CFG.ID_NAME_MAP[tostring(id)] = entry.name end
          if entry.rarity then CFG.ID_RARITY_MAP[tostring(id)] = entry.rarity end
        end
      end
    end
  end
  -- Lazy require ModuleScripts representing fish items
  local itemsRoot = RS:FindFirstChild("Items")
  if itemsRoot then
    for _,ms in ipairs(itemsRoot:GetDescendants()) do
      if ms:IsA("ModuleScript") then
        local ok, data = pcall(require, ms)
        if ok and type(data) == "table" then
          local Data = data.Data or {}
          if Data.Type == "Fishes" then
            local id = Data.Id or ms.Name
            local name = Data.Name or Data.DisplayName or ms.Name
            local rarity = Data.Rarity or Data.RarityName or Data.Tier or Data.RarityTier
            local chance
            if data.Probability and (data.Probability.Chance ~= nil) then
              chance = data.Probability.Chance
            elseif data.Probability and (data.Probability.probability ~= nil) then
              chance = data.Probability.probability
            end
            local mutations = Data.Mutations or Data.Modifiers
            _fishData[tostring(id)] = {
              name = name,
              rarity = rarity,
              chance = chance,
              mutations = mutations,
            }
            if name then CFG.ID_NAME_MAP[tostring(id)] = name end
            if rarity then CFG.ID_RARITY_MAP[tostring(id)] = rarity end
          end
        end
      end
    end
  end
  log("Built fish database with", (_fishData and #_fishData) or "many", "entries")
  return _fishData
end

-- Absorb known fields from a table into the provided destination table
local function absorb(dst, t)
  if type(t) ~= "table" then return end
  dst.id         = dst.id         or t.Id or t.ItemId or t.TypeId or t.UID or t.IdStr or t.FishId
  dst.name       = dst.name       or t.FishName or t.Name or t.ItemName or t.DisplayName or t.Species
  dst.weight     = dst.weight     or t.Weight or t.weight or t.Mass or t.WeightKg or t.Kg
  dst.chance     = dst.chance     or t.Chance or t.DropChance or t.Probability or t.chance
  dst.rarity     = dst.rarity     or t.Rarity or t.rarity or t.Tier
  dst.rarityName = dst.rarityName or t.RarityName or t.rarityName
  dst.rarityTier = dst.rarityTier or t.RarityTier or t.tier or t.Tier
  dst.mutation   = dst.mutation   or t.Mutation or t.mutation
  dst.mutations  = dst.mutations  or t.Mutations or t.mutations or t.Modifiers
end

-- Recursively traverse values to extract fish information
local function deepAbsorb(dst, x, seen, depth)
  seen = seen or {}
  depth = (depth or 0) + 1
  if seen[x] or depth > 5 then return end
  seen[x] = true
  local ty = typeof(x)
  if ty == "table" then
    absorb(dst, x)
    for k,v in pairs(x) do
      deepAbsorb(dst, v, seen, depth)
    end
  elseif ty == "Instance" then
    absorb(dst, toAttrMap(x))
    for _,ch in ipairs(x:GetChildren()) do deepAbsorb(dst, ch, seen, depth) end
  elseif ty == "string" or ty == "number" then
    if not dst.id then dst.id = tostring(x) end
    if ty == "string" and #x > 0 and #x <= 60 and not x:match("^%d+$") then
      dst.name = dst.name or x
    end
  end
end

-- Debug: preview values for console output
local function previewVal(v, maxDepth)
  maxDepth = maxDepth or 2
  local t = typeof(v)
  if t == "string" then
    return (#v > 80) and (v:sub(1,77).."...") or ("\"" .. v .. "\"")
  elseif t == "number" or t == "boolean" then
    return tostring(v)
  elseif t == "Instance" then
    return v.ClassName .. ":" .. v.Name
  elseif t == "table" and maxDepth > 0 then
    local items = {}
    local count = 0
    for k,val in pairs(v) do
      count = count + 1
      if count > 10 then table.insert(items, "..."); break end
      table.insert(items, tostring(k) .. "=" .. previewVal(val, maxDepth-1))
    end
    return "table{" .. table.concat(items, ", ") .. "}"
  else
    return t
  end
end

local function argProbePacked(evName, packed)
  if not CFG.DEBUG then return end
  warn(('[FCD] %s argc=%d'):format(evName, packed.n or #packed))
  for i = 1, (packed.n or #packed) do
    warn(('  arg[%d]: %s'):format(i, previewVal(packed[i])))
  end
end

-- Decoder for RE/FishCaught events. Processes all arguments to extract fish info
local function decode_RE_FishCaught(packed)
  local info = {}
  argProbePacked('RE/FishCaught', packed)
  for i = 1, (packed.n or #packed) do
    local arg = packed[i]
    deepAbsorb(info, arg)
  end
  -- Enrich from fish database
  buildFishDatabase()
  if info.id and _fishData[tostring(info.id)] then
    local f = _fishData[tostring(info.id)]
    info.name = info.name or f.name
    info.rarity = info.rarity or f.rarity
    info.chance = info.chance or f.chance
    info.mutations = info.mutations or f.mutations
  end
  -- Manual fallbacks
  if (not info.name) and info.id and CFG.ID_NAME_MAP[tostring(info.id)] then
    info.name = CFG.ID_NAME_MAP[tostring(info.id)]
  end
  if (not info.rarity) and info.id and CFG.ID_RARITY_MAP[tostring(info.id)] then
    info.rarity = CFG.ID_RARITY_MAP[tostring(info.id)]
  end
  return next(info) and info or nil
end

-- Generic decoder for other events (fallback)
local function decode_generic(packed)
  local info = {}
  argProbePacked('Generic', packed)
  for i = 1, (packed.n or #packed) do
    deepAbsorb(info, packed[i])
  end
  buildFishDatabase()
  if info.id and _fishData[tostring(info.id)] then
    local f = _fishData[tostring(info.id)]
    info.name = info.name or f.name
    info.rarity = info.rarity or f.rarity
    info.chance = info.chance or f.chance
    info.mutations = info.mutations or f.mutations
  end
  if (not info.name) and info.id and CFG.ID_NAME_MAP[tostring(info.id)] then
    info.name = CFG.ID_NAME_MAP[tostring(info.id)]
  end
  if (not info.rarity) and info.id and CFG.ID_RARITY_MAP[tostring(info.id)] then
    info.rarity = CFG.ID_RARITY_MAP[tostring(info.id)]
  end
  return next(info) and info or nil
end

local EVENT_DECODERS = {
  ["RE/FishCaught"] = decode_RE_FishCaught,
  ["FishCaught"] = decode_generic,
  ["FishingCompleted"] = decode_generic,
  ["Caught"] = decode_generic,
}

-- Formatters
local function toKg(w)
  local n = tonumber(w)
  if not n then return (w and tostring(w)) or "Unknown" end
  return string.format("%0."..tostring(CFG.WEIGHT_DECIMALS).."f kg", n)
end
local function fmtOneIn(info)
  if info and info.chance then
    local n = tonumber(info.chance)
    if n and n > 0 then
      return ("1 in %d"):format(math.max(1, math.floor(100 / n + 0.5)))
    end
  end
  local key = info and (info.rarity or info.rarityName or info.rarityTier)
  if key ~= nil then
    local mapped = CFG.RARITY_ONEIN_MAP[key]
    if mapped then return mapped end
    -- Case-insensitive match on string keys
    for k,v in pairs(CFG.RARITY_ONEIN_MAP) do
      if type(k) == "string" and type(key) == "string" then
        if k:lower() == key:lower() then return v end
      end
    end
  end
  return (key and tostring(key)) or "Unknown"
end
local function formatMutations(info)
  if type(info.mutations) == "table" then
    local t = {}
    for k,v in pairs(info.mutations) do
      if type(v) == "boolean" and v then
        table.insert(t, tostring(k))
      elseif v ~= nil and v ~= false then
        table.insert(t, tostring(k) .. ":" .. tostring(v))
      end
    end
    return (#t > 0) and table.concat(t, ", ") or "None"
  elseif info.mutation and info.mutation ~= "" then
    return tostring(info.mutation)
  end
  return "None"
end

-- Send a webhook with deduplicated messages (debounce)
local _debounce = 0
local function send(info, origin)
  if now() - _debounce < 0.35 then return end
  _debounce = now()
  local mut = formatMutations(info)
  local fishName = info.name or info.species or info.fishType or "Unknown Fish"
  if fishName == "Unknown Fish" and info.id then
    buildFishDatabase()
    if _fishData[tostring(info.id)] and _fishData[tostring(info.id)].name then
      fishName = _fishData[tostring(info.id)].name
    end
  end
  sendWebhook({{
    title = "🐟 New Catch: " .. fishName,
    description = ("**Player:** %s\n**Origin:** %s"):format(LP.Name, origin or "unknown"),
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    color = info.rarity and 0x00ff00 or 0x888888,
    fields = {
      { name = "Weight", value = toKg(info.weight), inline = true },
      { name = "Rarity", value = fmtOneIn(info), inline = true },
      { name = "Mutation(s)", value = mut, inline = false },
      { name = "Fish ID", value = info.id or "Unknown", inline = true },
    }
  }})
  log("Sent webhook for:", fishName, "rarity:", info.rarity or "unknown")
end

-- Catch window handler: correlate inbound events with backpack additions
local function onCatchWindow()
  -- Prefer information from event payloads
  for i = #_lastInbound, 1, -1 do
    local hit = _lastInbound[i]
    if now() - hit.t <= CFG.CATCH_WINDOW_SEC then
      local decoder = EVENT_DECODERS[hit.name] or decode_generic
      local info = decoder(hit.args)
      if info and (info.name or info.id) then
        send(info, "OnClientEvent:" .. hit.name)
        return
      end
    end
  end
  -- Fallback: inspect new items in backpack
  for inst, t0 in pairs(_recentAdds) do
    if inst.Parent == Backpack and now() - t0 <= CFG.CATCH_WINDOW_SEC then
      local a = toAttrMap(inst)
      local info = {
        name = a.FishName or a.Name or inst.Name,
        weight = a.Weight or a.Mass,
        rarity = a.Rarity or a.RarityName or a.Tier,
        mutation = a.Mutation,
        mutations = a.Mutations,
        id = a.Id or a.ItemId or a.TypeId or a.FishId,
      }
      send(info, "Backpack:" .. inst.Name)
      return
    end
  end
  -- Last resort: send unknown catch if debugging
  if CFG.DEBUG then
    log("No detailed info found, sending fallback")
    send({ name = "Unknown Fish" }, "Heuristic:NoData")
  end
end

-- Hook inbound RemoteEvents for fishing events
local function connectInbound()
  local ge = RS:FindFirstChild("GameEvents") or RS
  local function want(nm)
    local n = string.lower(nm)
    for _,kw in ipairs(CFG.INBOUND_EVENTS) do
      if string.find(n, string.lower(kw)) then return true end
    end
    return false
  end
  local function maybeConnect(d)
    if d:IsA("RemoteEvent") and want(d.Name) then
      table.insert(_conns, d.OnClientEvent:Connect(function(...)
        local packed = table.pack(...)
        table.insert(_lastInbound, { t = now(), name = d.Name, args = packed })
        log("Inbound:", d:GetFullName(), "argc=", packed.n or select("#", ...))
        task.defer(onCatchWindow)
      end))
      log("Hooked inbound:", d:GetFullName())
    end
  end
  for _,d in ipairs(ge:GetDescendants()) do maybeConnect(d) end
  table.insert(_conns, ge.DescendantAdded:Connect(maybeConnect))
end

-- Connect signals: backpack additions and leaderstats changes
local function connectSignals()
  if Backpack then
    table.insert(_conns, Backpack.ChildAdded:Connect(function(inst)
      _recentAdds[inst] = now()
      log("Backpack item added:", inst.Name)
    end))
  end
  local ls = LP:FindFirstChild("leaderstats")
  if ls then
    local Caught = ls:FindFirstChild("Caught")
    local Data = Caught and (Caught:FindFirstChild("Data") or Caught)
    if Data and Data:IsA("ValueBase") then
      table.insert(_conns, Data.Changed:Connect(function()
        log("Leaderstats changed")
        task.defer(onCatchWindow)
      end))
    end
  end
  connectInbound()
end

-- Public API
function M.Start(opts)
  if opts then for k,v in pairs(opts) do CFG[k] = v end end
  -- Pre-build fish database asynchronously
  task.spawn(function()
    buildFishDatabase()
    log("Fish database initialized")
  end)
  connectSignals()
  log("FishCatchDetector v3.0 started. DEBUG=", CFG.DEBUG)
end
function M.Kill()
  for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
  safeClear(_conns); safeClear(_lastInbound); safeClear(_recentAdds)
  log("FishCatchDetector v3.0 stopped.")
end
function M.SetConfig(patch)
  for k,v in pairs(patch or {}) do CFG[k] = v end
end

-- Optional debug helpers
function M.DebugFishID(fishID)
  local idStr = tostring(fishID)
  log("=== DEBUGGING FISH ID:", idStr, "===")
  buildFishDatabase()
  local data = _fishData[idStr]
  if data then
    for k,v in pairs(data) do log("  ", k, "=", tostring(v)) end
  else
    log("Fish ID not found in database")
  end
  if CFG.ID_NAME_MAP[idStr] then log("ID_NAME_MAP:", CFG.ID_NAME_MAP[idStr]) end
  if CFG.ID_RARITY_MAP[idStr] then log("ID_RARITY_MAP:", CFG.ID_RARITY_MAP[idStr]) end
end

return M