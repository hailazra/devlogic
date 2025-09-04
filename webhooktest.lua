-- FishCatchDetector v2.4.0 IMPROVED DETECTION
-- Enhanced detection for fish names, rarity, and mutations
-- Added more comprehensive argument parsing and registry scanning

local CFG = {
  WEBHOOK_URL = "https://discordapp.com/api/webhooks/1369085852071759903/clJFD_k9D4QeH6zZpylPId2464XJBLyGDafz8uiTotf2tReSNeZXcyIiJDdUDhu1CCzI",
  CATCH_WINDOW_SEC = 3,
  DEBUG = true,
  WEIGHT_DECIMALS = 2,
  INBOUND_EVENTS = { "RE/FishCaught", "FishCaught", "FishingCompleted", "Caught", "Reward", "Fishing" },

  -- Enhanced rarity mappings
  RARITY_ONEIN_MAP = {
    ["Common"] = "1 in 2", ["Uncommon"] = "1 in 5", ["Rare"] = "1 in 15",
    ["Epic"] = "1 in 75", ["Legendary"] = "1 in 300", ["Mythic"] = "1 in 1000",
    ["Exotic"] = "1 in 2500", ["Ancient"] = "1 in 5000",
    [1] = "1 in 2", [2] = "1 in 5", [3] = "1 in 15", [4] = "1 in 75", [5] = "1 in 300",
    [6] = "1 in 1000", [7] = "1 in 2500", [8] = "1 in 5000",
  },

  -- Fish ID mappings (will be populated dynamically)
  ID_NAME_MAP = {},
  ID_RARITY_MAP = {},
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
local function log(...) if CFG.DEBUG then warn("[FCD-2.4.0]", ...) end end
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

-- Enhanced attribute extraction
local function toAttrMap(inst)
  local a = {}
  if not inst then return a end
  
  -- Get direct attributes
  if inst.GetAttributes then
    for k,v in pairs(inst:GetAttributes()) do a[k] = v end
  end
  
  -- Get value objects
  for _,ch in ipairs(inst:GetChildren()) do 
    if ch:IsA("ValueBase") then 
      a[ch.Name] = ch.Value 
    elseif ch:IsA("Folder") or ch:IsA("Configuration") then
      -- Recursively check nested objects
      local nested = toAttrMap(ch)
      for k,v in pairs(nested) do a[k] = v end
    end
  end
  
  return a
end

-- Enhanced registry scanning
local _regs, _fishData
local function findRegistries()
  if _regs then return _regs end
  _regs = {}
  
  local roots = {
    RS:FindFirstChild("Data"),
    RS:FindFirstChild("GameData"), 
    RS:FindFirstChild("DataRegistry"),
    RS:FindFirstChild("Registry"),
    RS:FindFirstChild("Assets"),
    RS:FindFirstChild("Items"),
    RS:FindFirstChild("Shared"),
    RS
  }
  
  local names = {
    "FishRegistry", "Fishes", "Fish", "Catchables", "Items", "Loot",
    "FishData", "CatchableData", "ItemData", "Registry", "Database"
  }
  
  for _,r in ipairs(roots) do
    if r then
      for _,n in ipairs(names) do
        local f = r:FindFirstChild(n, true)
        if f then table.insert(_regs, f) end
      end
      -- Also add the root itself
      table.insert(_regs, r)
    end
  end
  
  log("Found registries:", #_regs)
  return _regs
end

-- Build fish database from registries
local function buildFishDatabase()
  if _fishData then return _fishData end
  _fishData = {}
  
  for _,root in ipairs(findRegistries()) do
    for _,d in ipairs(root:GetDescendants()) do
      if d:IsA("Folder") or d:IsA("Configuration") or d:IsA("ModuleScript") then
        local a = toAttrMap(d)
        local id = a.Id or a.ItemId or a.TypeId or a.FishId or d.Name
        
        if id then
          _fishData[tostring(id)] = {
            name = a.FishName or a.Name or a.ItemName or a.DisplayName or d.Name,
            rarity = a.Rarity or a.RarityName or a.Tier or a.RarityTier,
            chance = a.Chance or a.DropChance or a.Probability,
            mutations = a.Mutations or a.Modifiers
          }
          
          -- Update config maps
          if _fishData[tostring(id)].name then
            CFG.ID_NAME_MAP[tostring(id)] = _fishData[tostring(id)].name
          end
          if _fishData[tostring(id)].rarity then
            CFG.ID_RARITY_MAP[tostring(id)] = _fishData[tostring(id)].rarity
          end
        end
      end
    end
  end
  
  log("Built fish database with", table.count and table.count(_fishData) or "many", "entries")
  return _fishData
end

-- Enhanced info extraction
local function absorb(dst, t)
  if type(t) ~= "table" then return end
  
  -- Basic properties
  dst.id         = dst.id         or t.Id or t.ItemId or t.TypeId or t.UID or t.IdStr or t.FishId
  dst.name       = dst.name       or t.FishName or t.Name or t.ItemName or t.DisplayName or t.Species
  dst.weight     = dst.weight     or t.Weight or t.weight or t.Mass or t.WeightKg or t.Kg
  dst.chance     = dst.chance     or t.Chance or t.DropChance or t.Probability or t.chance
  dst.rarity     = dst.rarity     or t.Rarity or t.rarity or t.Tier or t.RarityName or t.rarityName
  dst.rarityName = dst.rarityName or t.RarityName or t.rarityName
  dst.rarityTier = dst.rarityTier or t.RarityTier or t.tier or t.Tier
  dst.mutation   = dst.mutation   or t.Mutation or t.mutation
  dst.mutations  = dst.mutations  or t.Mutations or t.mutations or t.Modifiers or t.modifiers
  
  -- Additional fields that might contain fish data
  dst.fishType   = dst.fishType   or t.FishType or t.fishType
  dst.species    = dst.species    or t.Species or t.species
end

local function deepAbsorb(dst, x, seen, depth)
  seen = seen or {}
  depth = (depth or 0) + 1
  if seen[x] or depth > 5 then return end -- Prevent infinite recursion
  seen[x] = true
  
  local ty = typeof(x)
  if ty == "table" then
    absorb(dst, x)
    for k,v in pairs(x) do 
      -- Also try to extract from keys that might be meaningful
      if type(k) == "string" and (k:lower():find("fish") or k:lower():find("name") or k:lower():find("rarity")) then
        if type(v) == "string" then
          if k:lower():find("name") then dst.name = dst.name or v end
          if k:lower():find("rarity") then dst.rarity = dst.rarity or v end
        end
      end
      deepAbsorb(dst, v, seen, depth) 
    end
  elseif ty == "Instance" then
    absorb(dst, toAttrMap(x))
    for _,ch in ipairs(x:GetChildren()) do deepAbsorb(dst, ch, seen, depth) end
  elseif ty == "string" or ty == "number" then
    if not dst.id then dst.id = tostring(x) end
    if ty == "string" and #x <= 60 and #x > 0 then 
      -- Only set name if it looks like a proper name (not just numbers/IDs)
      if not x:match("^%d+$") and not dst.name then 
        dst.name = x 
      end
    end
  end
end

-- Enhanced argument inspection
local function previewVal(v, maxDepth)
  maxDepth = maxDepth or 2
  local t = typeof(v)
  if t == "string" then
    return (#v > 80) and (v:sub(1,77).."...") or ("\"" .. v .. "\"")
  elseif t == "number" or t == "boolean" then
    return tostring(v)
  elseif t == "Instance" then
    local attrs = {}
    if v.GetAttributes then
      for k,val in pairs(v:GetAttributes()) do
        table.insert(attrs, k.."="..tostring(val))
      end
    end
    return v.ClassName..":"..v.Name..(#attrs > 0 and " {"..table.concat(attrs, ", ").."}" or "")
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
  warn(("[FCD] %s argc=%d"):format(evName, packed.n or #packed))
  for i=1,(packed.n or #packed) do
    local a = packed[i]
    warn(("  arg[%d]: %s"):format(i, previewVal(a, 2)))
  end
end

-- Enhanced decoder for RE/FishCaught
local function decode_RE_FishCaught(packed)
  local info = {}
  argProbePacked("RE/FishCaught", packed)
  
  -- Process all arguments
  for i = 1, (packed.n or #packed) do
    local arg = packed[i]
    deepAbsorb(info, arg)
  end

  -- Try to enrich from database
  buildFishDatabase()
  if info.id and _fishData[tostring(info.id)] then
    local fishInfo = _fishData[tostring(info.id)]
    info.name = info.name or fishInfo.name
    info.rarity = info.rarity or fishInfo.rarity
    info.chance = info.chance or fishInfo.chance
    info.mutations = info.mutations or fishInfo.mutations
  end

  -- Manual map fallback
  if (not info.name) and info.id and CFG.ID_NAME_MAP[tostring(info.id)] then
    info.name = CFG.ID_NAME_MAP[tostring(info.id)]
  end
  if (not info.rarity) and info.id and CFG.ID_RARITY_MAP[tostring(info.id)] then
    info.rarity = CFG.ID_RARITY_MAP[tostring(info.id)]
  end

  -- Debug output
  if CFG.DEBUG then
    log("Extracted info:", 
        "name=" .. (info.name or "nil"),
        "rarity=" .. (info.rarity or "nil"), 
        "weight=" .. (info.weight or "nil"),
        "id=" .. (info.id or "nil"))
  end

  return next(info) and info or nil
end

-- Generic decoder for other events
local function decode_generic(packed)
  local info = {}
  argProbePacked("Generic", packed)
  
  for i = 1, (packed.n or #packed) do
    local arg = packed[i]
    deepAbsorb(info, arg)
  end
  
  buildFishDatabase()
  if info.id and _fishData[tostring(info.id)] then
    local fishInfo = _fishData[tostring(info.id)]
    info.name = info.name or fishInfo.name
    info.rarity = info.rarity or fishInfo.rarity
    info.chance = info.chance or fishInfo.chance
    info.mutations = info.mutations or fishInfo.mutations
  end
  
  return next(info) and info or nil
end

local EVENT_DECODERS = {
  ["RE/FishCaught"] = decode_RE_FishCaught,
  ["FishCaught"] = decode_generic,
  ["FishingCompleted"] = decode_generic,
  ["Caught"] = decode_generic,
}

-- Enhanced formatting
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
    -- Try to match partial strings
    for k,v in pairs(CFG.RARITY_ONEIN_MAP) do
      if type(k) == "string" and type(key) == "string" then
        if k:lower() == key:lower() then return v end
      end
    end
  end
  
  return (key and tostring(key)) or "Unknown"
end

-- Enhanced mutation formatting
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

-- Send pipeline
local _debounce = 0
local function send(info, origin)
  if now() - _debounce < 0.35 then return end
  _debounce = now()

  local mut = formatMutations(info)
  local fishName = info.name or info.species or info.fishType or "Unknown Fish"
  
  -- Try one more time to get name from ID if we have it
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
    color = info.rarity and 0x00ff00 or 0x888888, -- Green if rarity detected
    fields = {
      {name="Weight", value=toKg(info.weight), inline=true},
      {name="Rarity", value=fmtOneIn(info), inline=true},
      {name="Mutation(s)", value=mut, inline=false},
      {name="Fish ID", value=info.id or "Unknown", inline=true},
    }
  }})
  
  log("Sent webhook for:", fishName, "rarity:", info.rarity or "unknown")
end

local function onCatchWindow()
  -- Try event-based detection first
  for i = #_lastInbound, 1, -1 do
    local hit = _lastInbound[i]
    if now() - hit.t <= CFG.CATCH_WINDOW_SEC then
      local decoder = EVENT_DECODERS[hit.name] or decode_generic
      local info = decoder(hit.args)
      if info and (info.name or info.id) then 
        send(info, "OnClientEvent:"..hit.name) 
        return 
      end
    end
  end
  
  -- Try backpack-based detection
  for inst, t0 in pairs(_recentAdds) do
    if inst.Parent == Backpack and now() - t0 <= CFG.CATCH_WINDOW_SEC then
      local a = toAttrMap(inst)
      local info = {
        name = a.FishName or a.Name or inst.Name,
        weight = a.Weight or a.Mass,
        rarity = a.Rarity or a.RarityName or a.Tier,
        mutation = a.Mutation, 
        mutations = a.Mutations,
        id = a.Id or a.ItemId or a.TypeId
      }
      send(info, "Backpack:"..inst.Name)
      return
    end
  end
  
  -- Fallback - send with available info
  if CFG.DEBUG then 
    log("No detailed info found, sending fallback")
    send({name="Unknown Fish"}, "Heuristic:NoData") 
  end
end

-- Wiring functions (unchanged)
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

function M.Start(opts)
  if opts then for k,v in pairs(opts) do CFG[k] = v end end
  
  -- Initialize fish database
  task.spawn(function()
    buildFishDatabase()
    log("Fish database initialized")
  end)
  
  connectSignals()
  log("FCD 2.4.0 IMPROVED started. DEBUG=", CFG.DEBUG)
end

function M.Kill()
  for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
  safeClear(_conns); safeClear(_lastInbound); safeClear(_recentAdds)
  log("FCD 2.4.0 IMPROVED stopped.")
end

function M.SetConfig(patch)
  for k,v in pairs(patch or {}) do CFG[k] = v end
end

-- Debug function to inspect current game structure
function M.InspectGame()
  log("=== GAME INSPECTION ===")
  log("ReplicatedStorage children:")
  for _,child in ipairs(RS:GetChildren()) do
    log("  " .. child.Name .. " (" .. child.ClassName .. ")")
  end
  
  log("Found registries:")
  for i,reg in ipairs(findRegistries()) do
    log("  [" .. i .. "] " .. reg:GetFullName())
  end
  
  log("Fish database entries:")
  buildFishDatabase()
  local count = 0
  for id,data in pairs(_fishData) do
    count = count + 1
    if count <= 5 then -- Show first 5 entries
      log("  " .. id .. " = " .. (data.name or "unnamed") .. " (" .. (data.rarity or "no rarity") .. ")")
    end
  end
  log("  ... and " .. (count > 5 and (count-5) or 0) .. " more entries")
end

return M