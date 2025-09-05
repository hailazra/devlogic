-- webhooktest.lua
-- FishCatchDetector v3.1.0 (NO-HOOK, Items ModuleScript aware)
-- .devlogic — Discord: send embed on fish catch

-- =========================
-- CONFIG
-- =========================
local CFG = {
  WEBHOOK_URL       = "https://discordapp.com/api/webhooks/1369085852071759903/clJFD_k9D4QeH6zZpylPId2464XJBLyGDafz8uiTotf2tReSNeZXcyIiJDdUDhu1CCzI",
  CATCH_WINDOW_SEC  = 3,     -- jendela korelasi event/backpack
  DEBUG             = true,  -- set true sementara untuk investigasi
  WEIGHT_DECIMALS   = 2,     -- 2 → 6.70 kg
  INBOUND_EVENTS    = { "RE/FishCaught", "FishCaught", "FishingCompleted", "Caught", "Reward", "Fishing" },

  -- Optional fallback maps (kalau ada ID unik yang bandel)
  ID_NAME_MAP       = {},
  ID_RARITY_MAP     = {},    -- kalau ingin memaksa nama rarity untuk ID tertentu
}

-- Tier → Nama Rarity (sesuai spesifikasi kamu)
local TIER_NAME_MAP = {
  [1] = "Common",
  [2] = "Uncommon",
  [3] = "Rare",
  [4] = "Epic",
  [5] = "Legendary",
  [6] = "Mythic",
  [7] = "Secret",
}

-- =========================
-- Services / Globals
-- =========================
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local HttpService  = game:GetService("HttpService")
local LP           = Players.LocalPlayer
local Backpack     = LP:WaitForChild("Backpack", 10)

getgenv().FishCatchDetector = getgenv().FishCatchDetector or {}
local M = getgenv().FishCatchDetector

-- =========================
-- State
-- =========================
local _conns           = {}
local _lastInbound     = {}   -- { {t, name, args=table.pack(...)} , ...}
local _recentAdds      = {}   -- [Instance] = timestamp
local _fishData        = nil  -- lazy-built: [idStr] = { name, chance, tier, rarityTier, rarityName, ... }
local _itemsRoot       = nil
local _indexBuilt      = false
local _moduleById      = {}   -- [idStr] = ModuleScript
local _debounce        = 0

-- =========================
-- Utils
-- =========================
local function now() return os.clock() end
local function log(...) if CFG.DEBUG then warn("[FCD]", ...) end end
-- Lebih robust: cari berbagai backend request yang umum di executor
local function getRequestFn()
  if syn and type(syn.request) == "function" then return syn.request end
  if http and type(http.request) == "function" then return http.request end
  if type(http_request) == "function" then return http_request end
  if type(request) == "function" then return request end
  if fluxus and type(fluxus.request) == "function" then return fluxus.request end
  return nil
end

local function sendWebhook(payload)
  if not CFG.WEBHOOK_URL or CFG.WEBHOOK_URL:find("XXXX/BBBB") then
    log("WEBHOOK_URL belum di-set (placeholder). Skip.")
    return
  end

  local req = getRequestFn()
  if not req then
    log("Tidak menemukan fungsi HTTP request (syn.request/http.request/http_request/request/fluxus.request).")
    return
  end

  local body = HttpService:JSONEncode(payload)
  local headers = {
    ["Content-Type"] = "application/json",
    ["User-Agent"]   = "Mozilla/5.0" -- beberapa executor/nginx butuh UA
  }

  local ok, res = pcall(req, {
    Url = CFG.WEBHOOK_URL,
    Method = "POST",
    Headers = headers,
    Body = body
  })

  if not ok then
    log("Webhook pcall error:", tostring(res))
    return
  end

  -- Beberapa executor mengembalikan res.StatusCode/res.Status/res.Body
  local code = res.StatusCode or res.Status or res.StatusCodeLine
  local ok2xx = (type(code)=="number" and code >= 200 and code < 300)
  if not ok2xx then
    log("Webhook HTTP status:", tostring(code), " Body:", tostring(res.Body))
  else
    log("Webhook terkirim (", tostring(code), ")")
  end
end

local function safeClear(t)
  if table and table.clear then table.clear(t) else for k in pairs(t) do t[k] = nil end end
end

local function toAttrMap(inst)
  local a = {}
  if not inst or not inst.GetAttributes then return a end
  for k, v in pairs(inst:GetAttributes()) do a[k] = v end
  for _, ch in ipairs(inst:GetChildren()) do
    if ch:IsA("ValueBase") then a[ch.Name] = ch.Value end
  end
  return a
end

-- =========================
-- Items ModuleScript Resolver (ReplicatedStorage.Items)
-- =========================
local function detectItemsRoot()
  if _itemsRoot and _itemsRoot.Parent then return _itemsRoot end
  local candidates = {
    RS:FindFirstChild("Items"),
    RS:FindFirstChild("GameData") and RS.GameData:FindFirstChild("Items"),
    RS:FindFirstChild("Data") and RS.Data:FindFirstChild("Items"),
    RS
  }
  for _,root in ipairs(candidates) do
    if root then
      -- heuristik: harus ada ModuleScript di bawahnya
      local foundMS = false
      for _,d in ipairs(root:GetDescendants()) do
        if d:IsA("ModuleScript") then foundMS = true break end
      end
      if foundMS then _itemsRoot = root; return _itemsRoot end
    end
  end
  _itemsRoot = RS
  return _itemsRoot
end

local function toIdStr(v)
  if v == nil then return nil end
  local n = tonumber(v)
  return n and tostring(n) or tostring(v)
end

local function safeRequire(ms)
  local ok, data = pcall(require, ms)
  if not ok or type(data) ~= "table" then return nil end
  -- Format contoh:
  -- return {
  --   Data = { Id=65; Type="Fishes"; Name="Strawberry Dotty"; Tier=1; ... };
  --   Probability = { Chance = 0.05 };
  --   Weight = { Default = NumberRange.new(min, max); Big = NumberRange.new(min, max) };
  -- }
  local D = data.Data or {}
  if D.Type ~= "Fishes" then return nil end
  local chance = nil
  if type(data.Probability) == "table" then chance = data.Probability.Chance end
  return {
    id          = toIdStr(D.Id),
    name        = D.Name,
    tier        = D.Tier,
    rarityTier  = D.Tier,
    rarityName  = D.RarityName,
    chance      = chance,             -- bisa 0.05 atau 5
    icon        = D.Icon,
    desc        = D.Description,
    _module     = ms
  }
end

local function buildLightIndex()
  if _indexBuilt then return end
  local root = detectItemsRoot()
  for _,ms in ipairs(root:GetDescendants()) do
    if ms:IsA("ModuleScript") then
      local idFromName = tonumber(ms.Name)
      if idFromName then
        local k = tostring(idFromName)
        _moduleById[k] = _moduleById[k] or ms
      end
    end
  end
  _indexBuilt = true
end

local function ensureLoadedById(idStr)
  idStr = toIdStr(idStr)
  if not idStr then return nil end
  if _fishData and _fishData[idStr] and _fishData[idStr]._source == "items" then
    return _fishData[idStr]
  end
  buildLightIndex()
  -- 1) Module berdasarkan nama numerik, kalau ada
  local ms = _moduleById[idStr]
  if ms then
    local meta = safeRequire(ms)
    if meta and meta.id == idStr then
      _fishData = _fishData or {}
      _fishData[idStr] = {
        name       = meta.name,
        chance     = meta.chance,
        tier       = meta.tier,
        rarityTier = meta.rarityTier,
        rarityName = meta.rarityName,
        icon       = meta.icon,
        _source    = "items",
      }
      return _fishData[idStr]
    end
  end
  -- 2) Scan semua ModuleScript di Items sampai ketemu Id yang sesuai
  local root = detectItemsRoot()
  for _,d in ipairs(root:GetDescendants()) do
    if d:IsA("ModuleScript") then
      local meta = safeRequire(d)
      if meta and meta.id == idStr then
        _fishData = _fishData or {}
        _fishData[idStr] = {
          name       = meta.name,
          chance     = meta.chance,
          tier       = meta.tier,
          rarityTier = meta.rarityTier,
          rarityName = meta.rarityName,
          icon       = meta.icon,
          _source    = "items",
        }
        _moduleById[idStr] = d
        return _fishData[idStr]
      end
    end
  end
  return nil
end

-- =========================
-- Registry scan (atribut/ValueBase di RS) — lightweight
-- =========================
local function findRegistries()
  local regs = {}
  local roots = {
    RS:FindFirstChild("Data"),
    RS:FindFirstChild("GameData"),
    RS:FindFirstChild("DataRegistry"),
    RS
  }
  local names = { "FishRegistry", "Fishes", "Fish", "Catchables", "Items", "Loot" }
  for _,r in ipairs(roots) do
    if r then
      for _,n in ipairs(names) do
        local f = r:FindFirstChild(n, true)
        if f and f:IsA("Folder") then table.insert(regs, f) end
      end
    end
  end
  return regs
end

local function buildFishDatabase()
  if _fishData then return _fishData end
  _fishData = {}

  -- 1) Ambil dari registry berbasis attributes/valueobjects (cepat)
  for _,root in ipairs(findRegistries()) do
    for _,d in ipairs(root:GetDescendants()) do
      if d:IsA("Folder") or d:IsA("Configuration") or d:IsA("ModuleScript") then
        local a   = toAttrMap(d)
        local id  = a.Id or a.ItemId or a.TypeId or a.FishId or d.Name
        if id then
          local idStr = toIdStr(id)
          _fishData[idStr] = _fishData[idStr] or {}
          local slot = _fishData[idStr]
          slot.name        = slot.name        or a.FishName or a.Name or a.ItemName or a.DisplayName or d.Name
          slot.rarityTier  = slot.rarityTier  or a.RarityTier or a.Tier
          slot.rarityName  = slot.rarityName  or a.RarityName
          slot.tier        = slot.tier        or a.Tier
          slot.chance      = slot.chance      or a.Chance or a.DropChance or a.Probability -- kadang float/percent
          slot._source     = slot._source     or "registry"
        end
      end
    end
  end

  -- 2) Enrich dari Items ModuleScript (lazy prefer, tapi kita coba seed cepat untuk ID yang namanya numerik)
  buildLightIndex()
  for idStr, ms in pairs(_moduleById) do
    if not _fishData[idStr] or not _fishData[idStr].name or not _fishData[idStr].chance then
      local meta = safeRequire(ms)
      if meta and meta.id == idStr then
        _fishData[idStr] = _fishData[idStr] or {}
        local slot = _fishData[idStr]
        slot.name        = slot.name        or meta.name
        slot.rarityTier  = slot.rarityTier  or meta.rarityTier
        slot.rarityName  = slot.rarityName  or meta.rarityName
        slot.tier        = slot.tier        or meta.tier
        slot.chance      = slot.chance      or meta.chance
        slot._source     = "items"
      end
    end
  end

  log("Built fish database, entries:", (function(t) local c=0; for _ in pairs(t) do c=c+1 end; return c end)(_fishData))
  return _fishData
end

-- =========================
-- Extraction helpers
-- =========================
local function absorb(dst, t)
  if type(t) ~= "table" then return end

  dst.id         = dst.id         or t.Id or t.ItemId or t.TypeId or t.UID or t.IdStr or t.FishId
  dst.name       = dst.name       or t.FishName or t.Name or t.ItemName or t.DisplayName or t.Species
  dst.weight     = dst.weight     or t.Weight or t.weight or t.Mass or t.WeightKg or t.Kg
  dst.chance     = dst.chance     or t.Chance or t.DropChance or t.Probability or t.chance
  dst.tier       = dst.tier       or t.Tier                          -- <<< penting: simpan Tier
  dst.rarity     = dst.rarity     or t.Rarity or t.rarity or t.RarityName
  dst.rarityName = dst.rarityName or t.RarityName or t.rarityName
  dst.rarityTier = dst.rarityTier or t.RarityTier or t.tier or t.Tier
  dst.mutation   = dst.mutation   or t.Mutation or t.mutation
  dst.mutations  = dst.mutations  or t.Mutations or t.mutations or t.Modifiers or t.modifiers

  dst.fishType   = dst.fishType   or t.FishType or t.fishType
  dst.species    = dst.species    or t.Species or t.species
end

local function deepAbsorb(dst, x, seen, depth)
  seen = seen or {}
  depth = (depth or 0) + 1
  if seen[x] or depth > 5 then return end
  seen[x] = true

  local ty = typeof(x)
  if ty == "table" then
    absorb(dst, x)
    for k, v in pairs(x) do
      if type(k) == "string" then
        local lk = k:lower()
        if lk:find("fish") or lk:find("name") or lk:find("rarity") or lk == "tier" then
          if type(v) == "string" then
            if lk:find("name") and not dst.name then dst.name = v end
            if lk:find("rarity") and not dst.rarity then dst.rarity = v end
          elseif type(v) == "number" and lk == "tier" and not dst.tier then
            dst.tier = v
          end
        end
      end
      deepAbsorb(dst, v, seen, depth)
    end
  elseif ty == "Instance" then
    absorb(dst, toAttrMap(x))
    for _, ch in ipairs(x:GetChildren()) do deepAbsorb(dst, ch, seen, depth) end
  elseif ty == "string" or ty == "number" then
    if not dst.id then dst.id = tostring(x) end
    if ty == "string" and #x <= 60 and #x > 0 and not x:match("^%d+$") and not dst.name then
      dst.name = x
    end
  end
end

-- =========================
-- Debug arg probe
-- =========================
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
      for k,val in pairs(v:GetAttributes()) do table.insert(attrs, k.."="..tostring(val)) end
    end
    return v.ClassName..":"..v.Name..(#attrs>0 and " {"..table.concat(attrs, ", ").."}" or "")
  elseif t == "table" and maxDepth > 0 then
    local items, count = {}, 0
    for k,val in pairs(v) do
      count += 1
      if count > 10 then table.insert(items, "..."); break end
      table.insert(items, tostring(k).."="..previewVal(val, maxDepth-1))
    end
    return "table{"..table.concat(items, ", ").."}"
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

-- =========================
-- Decoders
-- =========================
local function decode_RE_FishCaught(packed)
  local info = {}
  argProbePacked("RE/FishCaught", packed)

  for i=1,(packed.n or #packed) do
    deepAbsorb(info, packed[i])
  end

  -- Enrich by ID from Items / Registry
  if info.id then
    buildFishDatabase()
    local idStr = toIdStr(info.id)
    -- prefer Items resolve (lazy)
    local fromItems = ensureLoadedById(idStr)
    local DB = _fishData[idStr]
    local fishInfo = fromItems or DB
    if fishInfo then
      info.name       = info.name       or fishInfo.name
      info.chance     = info.chance     or fishInfo.chance
      info.tier       = info.tier       or fishInfo.tier or fishInfo.rarityTier
      info.rarityName = info.rarityName or fishInfo.rarityName
      info.rarityTier = info.rarityTier or fishInfo.rarityTier or fishInfo.tier
    end
  end

  -- Manual override maps
  local idS = info.id and toIdStr(info.id)
  if idS and not info.name and CFG.ID_NAME_MAP[idS] then info.name = CFG.ID_NAME_MAP[idS] end
  if idS and not info.rarity and CFG.ID_RARITY_MAP[idS] then info.rarity = CFG.ID_RARITY_MAP[idS] end

  return next(info) and info or nil
end

local function decode_generic(packed)
  local info = {}
  argProbePacked("Generic", packed)
  for i=1,(packed.n or #packed) do deepAbsorb(info, packed[i]) end

  if info.id then
    buildFishDatabase()
    local idStr = toIdStr(info.id)
    local fromItems = ensureLoadedById(idStr)
    local DB = _fishData[idStr]
    local fishInfo = fromItems or DB
    if fishInfo then
      info.name       = info.name       or fishInfo.name
      info.chance     = info.chance     or fishInfo.chance
      info.tier       = info.tier       or fishInfo.tier or fishInfo.rarityTier
      info.rarityName = info.rarityName or fishInfo.rarityName
      info.rarityTier = info.rarityTier or fishInfo.rarityTier or fishInfo.tier
    end
  end

  return next(info) and info or nil
end

local EVENT_DECODERS = {
  ["RE/FishCaught"]   = decode_RE_FishCaught,
  ["FishCaught"]      = decode_generic,
  ["FishingCompleted"]= decode_generic,
  ["Caught"]          = decode_generic,
}

-- =========================
-- Formatting (Weight / Chance / Tier)
-- =========================
local function toKg(w)
  local n = tonumber(w)
  if not n then return (w and tostring(w)) or "Unknown" end
  return string.format("%0."..tostring(CFG.WEIGHT_DECIMALS).."f kg", n)
end

-- Chance bisa 0..1 (probability) atau 0..100 (percent)
local function parseChanceToProb(ch)
  local n = tonumber(ch)
  if not n or n <= 0 then return nil end
  if n > 1 then
    -- interpret sebagai persen
    return n / 100.0
  else
    return n
  end
end

local function fmtChanceOneIn(info)
  local p = parseChanceToProb(info and info.chance)
  if p and p > 0 then
    local oneIn = math.max(1, math.floor((1 / p) + 0.5))
    return ("1 in %d"):format(oneIn)
  end
  return "Unknown"
end

local function getTierName(info)
  local tier = (info and (info.tier or info.rarityTier)) or nil
  if tier and TIER_NAME_MAP[tier] then return TIER_NAME_MAP[tier] end
  return tier and tostring(tier) or "Unknown"
end

-- Mutations formatter
local function formatMutations(info)
  if type(info.mutations) == "table" then
    local t = {}
    for k, v in pairs(info.mutations) do
      if type(v) == "boolean" and v then
        table.insert(t, tostring(k))
      elseif v ~= nil and v ~= false then
        table.insert(t, tostring(k)..":"..tostring(v))
      end
    end
    return (#t > 0) and table.concat(t, ", ") or "None"
  elseif info.mutation and info.mutation ~= "" then
    return tostring(info.mutation)
  end
  return "None"
end

-- =========================
-- Send pipeline
-- =========================
local function send(info, origin)
  if now() - _debounce < 0.35 then return end
  _debounce = now()

  local fishName = info.name or info.species or info.fishType or "Unknown Fish"
  if fishName == "Unknown Fish" and info.id then
    buildFishDatabase()
    local slot = _fishData[toIdStr(info.id)]
    if slot and slot.name then fishName = slot.name end
  end

  local mut = formatMutations(info)

  sendWebhook({
    username = ".devlogic notifier",
    embeds = {{
      title = "🐟 New Catch: " .. fishName,
      description = ("**Player:** %s\n**Origin:** %s"):format(LP.Name, origin or "unknown"),
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      fields = {
        { name="Weight",       value=toKg(info.weight),        inline=true },
        { name="Chance",       value=fmtChanceOneIn(info),     inline=true }, -- <- dari Probability.Chance
        { name="Rarity",       value=getTierName(info),        inline=true }, -- <- nama dari Tier
        { name="Mutation(s)",  value=mut,                      inline=false },
        { name="Fish ID",      value=info.id or "Unknown",     inline=true },
      }
    }}
  })

  log("Sent webhook:", fishName, "Chance=", fmtChanceOneIn(info), "Tier=", getTierName(info))
end

local function onCatchWindow()
  -- 1) Event-based
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

  -- 2) Backpack delta
  for inst, t0 in pairs(_recentAdds) do
    if inst.Parent == Backpack and now() - t0 <= CFG.CATCH_WINDOW_SEC then
      local a = toAttrMap(inst)
      local info = {
        name      = a.FishName or a.Name or inst.Name,
        weight    = a.Weight or a.Mass,
        tier      = a.Tier or a.RarityTier,
        rarity    = a.Rarity or a.RarityName,
        mutation  = a.Mutation,
        mutations = a.Mutations,
        id        = a.Id or a.ItemId or a.TypeId or a.FishId,
        chance    = a.Chance or a.DropChance or a.Probability,
      }
      send(info, "Backpack:"..inst.Name)
      return
    end
  end

  -- 3) Fallback
  if CFG.DEBUG then
    log("No detailed info; sending fallback")
    send({ name="Unknown Fish" }, "Heuristic:NoData")
  end
end

-- =========================
-- Wiring
-- =========================
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
        table.insert(_lastInbound, { t=now(), name=d.Name, args=packed })
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
      log("Backpack +", inst.Name)
    end))
  end
  local ls = LP:FindFirstChild("leaderstats")
  if ls then
    local Caught = ls:FindFirstChild("Caught")
    local Data = Caught and (Caught:FindFirstChild("Data") or Caught)
    if Data and Data:IsA("ValueBase") then
      table.insert(_conns, Data.Changed:Connect(function()
        log("leaderstats.Caught changed")
        task.defer(onCatchWindow)
      end))
    end
  end
  connectInbound()
end

-- =========================
-- Public API
-- =========================
function M.Start(opts)
  if opts then for k,v in pairs(opts) do CFG[k] = v end end

  task.spawn(function()
    buildFishDatabase()
    log("Fish database initialized.")
  end)

  connectSignals()
  log("FCD v3.1.0 started. DEBUG=", CFG.DEBUG)
end

function M.Kill()
  for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
  safeClear(_conns); safeClear(_lastInbound); safeClear(_recentAdds)
  log("FCD v3.1.0 stopped.")
end

function M.SetConfig(patch) for k,v in pairs(patch or {}) do CFG[k] = v end end

-- Debug helper (opsional)
function M.InspectGame()
  log("=== GAME INSPECTION ===")
  log("ReplicatedStorage children:")
  for _,child in ipairs(RS:GetChildren()) do log("  "..child.Name.." ("..child.ClassName..")") end
  log("Items root:", (detectItemsRoot() and detectItemsRoot():GetFullName()) or "N/A")
  log("Registries:")
  for _,reg in ipairs(findRegistries()) do log("  - "..reg:GetFullName()) end
  buildFishDatabase()
  local shown, total = 0, 0
  for _ in pairs(_fishData) do total += 1 end
  for id,data in pairs(_fishData) do
    if shown < 10 then
      log(("  %s => %s (tier=%s, chance=%s)"):format(id, data.name or "-", tostring(data.rarityTier or data.tier or "?"), tostring(data.chance or "?")))
      shown += 1
    end
  end
  log("  ... total "..tostring(total).." entries")
end

function M.DebugFishID(id)
  local idStr = toIdStr(id)
  log("=== DEBUG FISH ID: "..tostring(idStr).." ===")
  buildFishDatabase()
  local slot = _fishData[idStr]
  if slot then
    for k,v in pairs(slot) do log("  "..k.." = "..tostring(v)) end
  else
    log("  not found in DB; try ensureLoadedById")
    local r = ensureLoadedById(idStr)
    if r then
      log("  loaded from Items:")
      for k,v in pairs(r) do log("    "..k.." = "..tostring(v)) end
    else
      log("  still not found.")
    end
  end
end

return M
