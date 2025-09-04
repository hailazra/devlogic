-- FishCatchDetector v2.2 NO-HOOK
local CFG = {
  WEBHOOK_URL = "https://discordapp.com/api/webhooks/1369085852071759903/clJFD_k9D4QeH6zZpylPId2464XJBLyGDafz8uiTotf2tReSNeZXcyIiJDdUDhu1CCzI",
  CATCH_WINDOW_SEC = 3,
  DEBUG = false,

  -- Event inbound yang relevan (jaga tetap NO-HOOK)
  INBOUND_EVENTS = { "FishingCompleted", "FishCaught", "Caught", "Reward", "Fishing", "RE/FishCaught" },

  -- Desimal untuk berat
  WEIGHT_DECIMALS = 2,

  -- Opsional: mapping rarity (string/tier) → "1 in X"
  -- contoh asumsi; EDIT sesuai game kamu. Kalau tak diisi, akan "Unknown".
  RARITY_ONEIN_MAP = {
    -- ["Common"] = "1 in 1",
    -- ["Uncommon"] = "1 in 3",
    -- ["Rare"] = "1 in 10",
    -- ["Epic"] = "1 in 50",
    -- ["Legendary"] = "1 in 200",
    -- [1] = "1 in 1", [2] = "1 in 3", ...
  },
}

-- =========================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local Backpack = LP:WaitForChild("Backpack")

getgenv().FishCatchDetector = getgenv().FishCatchDetector or {}
local M = getgenv().FishCatchDetector
local _conns, _lastInbound, _recentAdds = {}, {}, {}

local function now() return os.clock() end
local function log(...) if CFG.DEBUG then warn("[FCD-2.2]", ...) end end
local function http() return (syn and syn.request) or http_request or request or (fluxus and fluxus.request) end
local function sendWebhook(embeds)
  local req = http(); if not req then return end
  req({Url=CFG.WEBHOOK_URL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({username=".devlogic notifier", embeds=embeds})})
end

local function toAttrMap(inst)
  local a = {}
  for k,v in pairs(inst:GetAttributes()) do a[k]=v end
  for _,ch in ipairs(inst:GetChildren()) do if ch:IsA("ValueBase") then a[ch.Name]=ch.Value end end
  return a
end

local function fmtOneInFromChanceOrTier(info)
  -- 1) langsung dari chance persen
  if info.chance then
    local n = tonumber(info.chance)
    if n and n>0 then
      return ("1 in %d"):format(math.max(1, math.floor(100/n + 0.5)))
    end
  end
  -- 2) dari rarity string / tier via mapping opsional
  local key = info.rarity or info.rarityName or info.rarityTier
  if key ~= nil then
    local mapped = CFG.RARITY_ONEIN_MAP[key]
    if mapped then return mapped end
  end
  -- 3) fallback
  return "Unknown"
end

local function toKg(w)
  local n = tonumber(w)
  if not n then return w and tostring(w) or "Unknown" end
  local fmt = ("%0."..tostring(CFG.WEIGHT_DECIMALS).."f kg")
  return string.format(fmt, n)
end

-- ====== DECODERS ======
-- Decoder khusus berdasarkan nama event (lebih akurat dari heuristik generik)
local function absorb_from_table(dst, t)
  if type(t) ~= "table" then return end
  dst.name       = dst.name       or t.FishName or t.Name or t.ItemName or t.Species or t.DisplayName
  dst.weight     = dst.weight     or t.Weight or t.weight or t.Mass
  dst.chance     = dst.chance     or t.Chance or t.DropChance or t.chance or t.Probability
  dst.rarity     = dst.rarity     or t.Rarity or t.rarity or t.RarityName
  dst.rarityName = dst.rarityName or t.RarityName or t.rarityName
  dst.rarityTier = dst.rarityTier or t.RarityTier or t.rarityTier or t.Tier
  dst.mutation   = dst.mutation   or t.Mutation or t.mutation
  dst.mutations  = dst.mutations  or t.Mutations or t.mutations or t.Modifiers
end

local function deep_scan_any(args, sink, seen)
  seen = seen or {}
  if seen[args] then return end
  seen[args] = true
  local ty = typeof(args)
  if ty == "table" then
    sink(args)
    for k,v in pairs(args) do deep_scan_any(v, sink, seen) end
  elseif ty == "Instance" then
    sink(toAttrMap(args))
    for _,ch in ipairs(args:GetChildren()) do deep_scan_any(ch, sink, seen) end
  end
end

local function decode_generic(args)
  local info = {}
  deep_scan_any(args, function(t) absorb_from_table(info, t) end)
  return next(info) and info or nil
end

-- Targeted decoder untuk RE/FishCaught:
-- Banyak game mengirim salah satu dari pola berikut di args:
--  a) args[1] = { FishName=..., Weight=..., RarityName=... , RarityTier=..., Chance=..., Mutations={...} }
--  b) args[1] = { Data={Name/DisplayName, Weight, Rarity...}, Reward={...} } dst.
local function decode_RE_FishCaught(packed)
  local info = {}
  -- `packed` adalah table.pack(...) dari OnClientEvent
  for i=1, packed.n or #packed do
    local a = packed[i]
    if type(a) == "table" then
      absorb_from_table(info, a)
      for _,k in ipairs({"Fish","Data","Item","Reward","Catch","Result"}) do
        if type(a[k])=="table" then absorb_from_table(info, a[k]) end
      end
    elseif typeof(a)=="Instance" then
      absorb_from_table(info, toAttrMap(a))
    end
  end
  return next(info) and info or nil
end

local EVENT_DECODERS = {
  ["RE/FishCaught"] = decode_RE_FishCaught,
 
-- TEMP debug kirim keys ke console
if CFG.DEBUG then
  local function keys(t)
    local out={} for k,_ in pairs(t) do table.insert(out, tostring(k)) end
    table.sort(out); return table.concat(out, ", ")
  end
  for i=1, (packed.n or #packed) do
    local a = packed[i]
    if type(a)=="table" then
      warn("[FCD-2.2] args["..i.."] keys:", keys(a))
      for _,k in ipairs({"Fish","Data","Item","Reward","Catch","Result"}) do
        if type(a[k])=="table" then warn("[FCD-2.2] args["..i.."]."..k.." keys:", keys(a[k])) end
      end
    end
  end
end
}

-- ====== PIPELINE ======
local _debounce = 0
local function send(info, origin)
  if now()-_debounce < 0.35 then return end
  _debounce = now()

  local mut = "None"
  if type(info.mutations)=="table" then
    local t={}
    for k,v in pairs(info.mutations) do
      table.insert(t, tostring(k)..(v~=true and (":"..tostring(v)) or "")) 
    end
    mut=(#t>0) and table.concat(t,", ") or "None"
  elseif info.mutation then
    mut=tostring(info.mutation)
  end

  sendWebhook({{
    title = "🐟 New Catch: " .. (info.name or "Unknown"),
    description = ("**Player:** %s\n**Origin:** %s"):format(LP.Name, origin or "unknown"),
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    fields = {
      {name="Weight",  value=toKg(info.weight),                inline=true},
      {name="Rarity",  value=fmtOneInFromChanceOrTier(info),   inline=true},
      {name="Mutation(s)", value=mut,                          inline=false},
    }
  }})
end

local function onCatchWindow()
  -- 1) Prioritaskan hit terbaru
  for i=#_lastInbound,1,-1 do
    local hit=_lastInbound[i]
    if now()-hit.t <= CFG.CATCH_WINDOW_SEC then
      local decoder = EVENT_DECODERS[hit.name] or nil
      local info = (decoder and decoder(hit.args)) or decode_generic(hit.args)
      if info then send(info, "OnClientEvent:"..hit.name); return end
    end
  end
  -- 2) Fallback ke Backpack delta
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

-- ====== WIRING ======
local function connectInbound()
  local ge = RS:FindFirstChild("GameEvents") or RS
  local function want(reName)
    local n = reName:lower()
    for _,kw in ipairs(CFG.INBOUND_EVENTS) do if n:find(kw:lower()) then return true end end
    return false
  end
  local function maybeConnect(d)
    if d:IsA("RemoteEvent") and want(d.Name) then
      table.insert(_conns, d.OnClientEvent:Connect(function(...)
        table.insert(_lastInbound, {t=now(), name=d.Name, args=table.pack(...)})
        if CFG.DEBUG then log("Inbound:", d:GetFullName(), "argc=", select("#", ...)) end
        task.defer(onCatchWindow)
      end))
      if CFG.DEBUG then log("Hooked inbound:", d:GetFullName()) end
    end
  end
  for _,d in ipairs(ge:GetDescendants()) do maybeConnect(d) end
  table.insert(_conns, ge.DescendantAdded:Connect(maybeConnect))
end

local function connectSignals()
  table.insert(_conns, Backpack.ChildAdded:Connect(function(inst) _recentAdds[inst]=now() end))
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
  if opts then for k,v in pairs(opts) do CFG[k]=v end end
  connectSignals()
  log("FCD 2.2 NO-HOOK started. DEBUG=", CFG.DEBUG)
end

function M.Kill()
  for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
  table.clear(_conns); table.clear(_lastInbound); table.clear(_recentAdds)
  log("FCD 2.2 NO-HOOK stopped.")
end

-- expose quick config at runtime (opsional)
function M.SetConfig(patch)
  for k,v in pairs(patch or {}) do CFG[k]=v end
end

return M
