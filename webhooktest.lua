-- FishCatchDetector v2.1 NO-HOOK (inbound-only)
local CFG = {
  WEBHOOK_URL = "https://discordapp.com/api/webhooks/1369085852071759903/clJFD_k9D4QeH6zZpylPId2464XJBLyGDafz8uiTotf2tReSNeZXcyIiJDdUDhu1CCzI", -- ganti
  CATCH_WINDOW_SEC = 3,
  DEBUG = false,
  -- Nama event masuk yang relevan (silakan tambah kalau perlu)
  INBOUND_EVENTS = { "FishingCompleted", "FishCaught", "Caught", "Reward", "Fishing" },
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
local function log(...) if CFG.DEBUG then warn("[FCD-NOHOOK]", ...) end end
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

local function asOneIn(info)
  if info.chance then
    local n = tonumber(info.chance)
    if n and n>0 then return ("1 in %d"):format(math.max(1, math.floor(100/n + 0.5))) end
  end
  if type(info.rarity)=="number" and info.rarity>0 and info.rarity<=1 then
    return ("1 in %d"):format(math.max(1, math.floor(1/info.rarity + 0.5)))
  end
  return "Unknown"
end

local function toKg(w)
  local n=tonumber(w); if not n then return w and tostring(w) or "Unknown" end
  return string.format("%.3f kg", n)
end

local function extractFromArgs(args)
  -- cari table/instance yang punya field ikan
  local info={}
  local function scan(x, seen)
    seen=seen or {}; if seen[x] then return end; seen[x]=true
    local t=typeof(x)
    if t=="table" then
      if x.FishName or x.Name or x.ItemName or x.Weight or x.Rarity or x.Chance or x.Mutation or x.Mutations then
        info.name     = info.name     or x.FishName or x.Name or x.ItemName
        info.weight   = info.weight   or x.Weight or x.weight or x.Mass
        info.rarity   = info.rarity   or x.Rarity or x.rarity or x.Tier
        info.chance   = info.chance   or x.Chance or x.DropChance or x.chance
        info.mutation = info.mutation or x.Mutation or x.mutation
        info.mutations= info.mutations or x.Mutations or x.mutations
      end
      for k,v in pairs(x) do scan(v, seen) end
    elseif t=="Instance" then
      local a=toAttrMap(x)
      if a.FishName or a.Weight or a.Rarity or a.Chance then
        info.name     = info.name     or a.FishName or x.Name
        info.weight   = info.weight   or a.Weight or a.Mass
        info.rarity   = info.rarity   or a.Rarity or a.Tier
        info.chance   = info.chance   or a.Chance or a.DropChance
        info.mutation = info.mutation or a.Mutation
        info.mutations= info.mutations or a.Mutations
      end
      for _,ch in ipairs(x:GetChildren()) do scan(ch, seen) end
    end
  end
  scan(args)
  return next(info) and info or nil
end

local _debounce = 0
local function send(info, origin)
  if now()-_debounce < 0.4 then return end
  _debounce = now()
  local mut = "None"
  if type(info.mutations)=="table" then
    local t={} for k,v in pairs(info.mutations) do table.insert(t, tostring(k)..(v~=true and (":"..tostring(v)) or "")) end
    mut=(#t>0) and table.concat(t,", ") or "None"
  elseif info.mutation then mut=tostring(info.mutation) end
  sendWebhook({{
    title = "🐟 New Catch: " .. (info.name or "Unknown"),
    description = ("**Player:** %s\n**Origin:** %s"):format(LP.Name, origin or "unknown"),
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    fields = {
      {name="Weight", value=toKg(info.weight), inline=true},
      {name="Rarity", value=asOneIn(info), inline=true},
      {name="Mutation(s)", value=mut, inline=false},
    }
  }})
end

local function onCatchWindow()
  -- 1) prefer inbound remote payload (terakhir)
  for i=#_lastInbound,1,-1 do
    local hit=_lastInbound[i]
    if now()-hit.t <= CFG.CATCH_WINDOW_SEC then
      local info=extractFromArgs(hit.args) or {}
      if next(info) then send(info, "OnClientEvent:"..hit.name); return end
    end
  end
  -- 2) fallback backpack delta
  for inst,t0 in pairs(_recentAdds) do
    if inst.Parent==Backpack and now()-t0 <= CFG.CATCH_WINDOW_SEC then
      local a=toAttrMap(inst)
      send({
        name=a.FishName or inst.Name,
        weight=a.Weight or a.Mass,
        rarity=a.Rarity or a.Tier,
        chance=a.Chance or a.DropChance,
        mutation=a.Mutation, mutations=a.Mutations
      }, "Backpack:"..inst.Name)
      return
    end
  end
  if CFG.DEBUG then send({name="Unknown"}, "Heuristic:NoData") end
end

local function connectInbound()
  local ge = RS:FindFirstChild("GameEvents") or RS
  -- sambungkan ke semua RemoteEvent yang namanya cocok
  local function maybeConnect(re)
    if not re:IsA("RemoteEvent") then return end
    local n=re.Name:lower()
    for _,kw in ipairs(CFG.INBOUND_EVENTS) do
      if n:find(kw:lower()) then
        table.insert(_conns, re.OnClientEvent:Connect(function(...)
          table.insert(_lastInbound, {t=now(), name=re.Name, args=table.pack(...)})
          task.defer(onCatchWindow)
        end))
        log("Hooked inbound:", re:GetFullName())
        break
      end
    end
  end
  for _,d in ipairs(ge:GetDescendants()) do maybeConnect(d) end
  table.insert(_conns, ge.DescendantAdded:Connect(maybeConnect))
end

local function connectSignals()
  -- Backpack additions
  table.insert(_conns, Backpack.ChildAdded:Connect(function(inst) _recentAdds[inst]=now() end))
  -- leaderstats watcher (backup trigger)
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
  log("FCD NO-HOOK started. DEBUG=", CFG.DEBUG)
end

function M.Kill()
  for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
  table.clear(_conns); table.clear(_lastInbound); table.clear(_recentAdds)
  log("FCD NO-HOOK stopped.")
end

return M
