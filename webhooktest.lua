-- webhooktest.lua
-- FishCatchDetector v3.4.0
-- Focus sumber utama: RE/FishCaught, leaderstats trigger, Items ModuleScript (Fishes)
-- NO-HOOK, lazy require per-ID + cache, gambar via Roblox thumbnails API

-- =========================
-- CONFIG
-- =========================
local CFG = {
  WEBHOOK_URL          = "https://discordapp.com/api/webhooks/1369085852071759903/clJFD_k9D4QeH6zZpylPId2464XJBLyGDafz8uiTotf2tReSNeZXcyIiJDdUDhu1CCzI", -- <<< GANTI
  DEBUG                = true,
  WEIGHT_DECIMALS      = 2,
  CATCH_WINDOW_SEC     = 2.5,   -- korelasi event <-> trigger
  USE_LARGE_IMAGE      = true,  -- true: gambar besar; false: thumbnail kecil
  THUMB_SIZE           = "420x420", -- 150x150, 420x420, 720x720
  PRELOAD_ITEM_COUNT   = 0,     -- 0 = tidak preload; >0 = pre-require N module pertama (hati2 lag)
  USE_BACKPACK_FALLBACK= false, -- default OFF (fokus 3 sumber utama)
  USE_REGISTRY_FALLBACK= false, -- default OFF (hindari scan besar)

  INBOUND_EVENTS       = { "RE/FishCaught" }, -- cukup event utama
  ID_NAME_MAP          = {},   -- override opsional
}

local TIER_NAME_MAP = {
  [1]="Common",[2]="Uncommon",[3]="Rare",[4]="Epic",
  [5]="Legendary",[6]="Mythic",[7]="Secret",
}

-- =========================
-- Services
-- =========================
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local HttpService  = game:GetService("HttpService")
local LP           = Players.LocalPlayer
local Backpack     = LP:WaitForChild("Backpack", 10)

-- =========================
-- State
-- =========================
local _conns           = {}
local _lastInbound     = {}     -- queue event inbound (ts, name, args)
local _recentTriggerTs = 0      -- ts terakhir leaderstats trigger
local _debounce        = 0

-- Items cache
local _itemsRoot       = nil
local _indexBuilt      = false
local _moduleById      = {}     -- [idStr] -> ModuleScript
local _metaById        = {}     -- [idStr] -> {name,tier,chance,icon,..., _source="items"}
local _scannedSet      = {}     -- [ModuleScript]=true (agar tidak require 2x)
local _preloadCount    = 0

-- Thumb cache
local _thumbCache      = {}     -- [assetId] -> url

-- =========================
-- Utils
-- =========================
local function now() return os.clock() end
local function log(...) if CFG.DEBUG then warn("[FCD]", ...) end end
local function toIdStr(v) local n=tonumber(v); return n and tostring(n) or (v and tostring(v) or nil) end

-- HTTP
local function getRequestFn()
  if syn and type(syn.request)=="function" then return syn.request end
  if http and type(http.request)=="function" then return http.request end
  if type(http_request)=="function" then return http_request end
  if type(request)=="function" then return request end
  if fluxus and type(fluxus.request)=="function" then return fluxus.request end
  return nil
end

local function sendWebhook(payload)
  if not CFG.WEBHOOK_URL or CFG.WEBHOOK_URL:find("XXXX/BBBB") then
    log("WEBHOOK_URL belum di-set."); return
  end
  local req=getRequestFn()
  if not req then log("No HTTP backend"); return end
  local ok,res=pcall(req,{
    Url=CFG.WEBHOOK_URL, Method="POST",
    Headers={["Content-Type"]="application/json",["User-Agent"]="Mozilla/5.0",["Accept"]="*/*"},
    Body=HttpService:JSONEncode(payload)
  })
  if not ok then log("pcall error:",tostring(res)); return end
  local code=tonumber(res.StatusCode or res.Status) or 0
  if code<200 or code>=300 then log("HTTP status:",code," body:",tostring(res.Body)) else log("Webhook OK (",code,")") end
end

-- Attr map
local function toAttrMap(inst)
  local a={}; if not inst or not inst.GetAttributes then return a end
  for k,v in pairs(inst:GetAttributes()) do a[k]=v end
  for _,ch in ipairs(inst:GetChildren()) do if ch:IsA("ValueBase") then a[ch.Name]=ch.Value end end
  return a
end

-- =========================
-- Items resolver (ReplicatedStorage.Items)
-- =========================
local function detectItemsRoot()
  if _itemsRoot and _itemsRoot.Parent then return _itemsRoot end
  -- coba beberapa hint umum
  local function findPath(root, path)
    local cur=root
    for part in string.gmatch(path,"[^/]+") do
      cur=cur and cur:FindFirstChild(part)
    end
    return cur
  end
  local hints={"Items","GameData/Items","Data/Items"}
  for _,h in ipairs(hints) do
    local r=findPath(RS,h)
    if r then _itemsRoot=r; break end
  end
  _itemsRoot=_itemsRoot or RS:FindFirstChild("Items") or RS
  return _itemsRoot
end

local function safeRequire(ms)
  local ok,data=pcall(require,ms)
  if not ok or type(data)~="table" then return nil end
  local D=data.Data or {}
  if D.Type~="Fishes" then return nil end
  local chance=nil
  if type(data.Probability)=="table" then chance=data.Probability.Chance end
  return {
    id    = toIdStr(D.Id),
    name  = D.Name,
    tier  = D.Tier,
    chance= chance,       -- bisa prob (0..1) atau percent (0..100)
    icon  = D.Icon,
    desc  = D.Description,
    _ms   = ms
  }
end

local function buildLightIndex()
  if _indexBuilt then return end
  local root=detectItemsRoot()
  -- Map berdasarkan nama numerik; tanpa require
  for _,d in ipairs(root:GetDescendants()) do
    if d:IsA("ModuleScript") then
      local n=tonumber(d.Name)
      if n then
        local id=toIdStr(n)
        _moduleById[id]=_moduleById[id] or d
      end
    end
  end
  _indexBuilt=true
end

local function ensureMetaById(idStr)
  idStr=toIdStr(idStr); if not idStr then return nil end
  if _metaById[idStr] then return _metaById[idStr] end
  buildLightIndex()
  -- 1) kalau ada MS dengan nama=ID, require 1x
  local ms=_moduleById[idStr]
  if ms and not _scannedSet[ms] then
    local meta=safeRequire(ms); _scannedSet[ms]=true
    if meta and meta.id==idStr then
      _metaById[idStr]=meta; return meta
    end
  end
  -- 2) else: scan LAZY semua ModuleScript satu kali sampai ketemu id
  local root=detectItemsRoot()
  for _,d in ipairs(root:GetDescendants()) do
    if d:IsA("ModuleScript") and not _scannedSet[d] then
      local meta=safeRequire(d); _scannedSet[d]=true
      if meta and meta.id then
        _moduleById[meta.id]=_moduleById[meta.id] or d
        _metaById[meta.id]=_metaById[meta.id] or meta
        if meta.id==idStr then return meta end
      end
    end
  end
  return nil
end

-- Optional preload beberapa module di background (batch kecil biar gak spike)
local function preloadSome(count)
  if (count or 0)<=0 then return end
  buildLightIndex()
  local loaded=0
  for id,ms in pairs(_moduleById) do
    if loaded>=count then break end
    if not _scannedSet[ms] then
      task.defer(function()
        local _=ensureMetaById(id)
      end)
      loaded+=1
    end
  end
  _preloadCount=loaded
  log("Preload scheduled:",loaded)
end

-- =========================
-- Thumbnail resolver (rbxassetid:// → image URL)
-- =========================
local function extractAssetId(icon)
  if not icon then return nil end
  if type(icon)=="number" then return tostring(icon) end
  if type(icon)=="string" then
    local m=icon:match("rbxassetid://(%d+)"); if m then return m end
    local n=icon:match("(%d+)$"); if n then return n end
  end
  return nil
end

local function httpGet(url)
  local req=getRequestFn(); if not req then return nil,"no_request_fn" end
  local ok,res=pcall(req,{Url=url,Method="GET",Headers={["User-Agent"]="Mozilla/5.0",["Accept"]="application/json,*/*"}})
  if not ok then return nil,tostring(res) end
  local code=tonumber(res.StatusCode or res.Status) or 0
  if code<200 or code>=300 then return nil,"status:"..tostring(code) end
  return res.Body or "", nil
end

local function resolveIconUrl(icon)
  local id=extractAssetId(icon); if not id then return nil end
  if _thumbCache[id] then return _thumbCache[id] end
  local size=CFG.THUMB_SIZE or "420x420"
  local api=("https://thumbnails.roblox.com/v1/assets?assetIds=%s&size=%s&format=Png&isCircular=false"):format(id,size)
  local body,err=httpGet(api)
  if body then
    local ok,data=pcall(function() return HttpService:JSONDecode(body) end)
    if ok and data and data.data and data.data[1] then
      local d=data.data[1]
      if d.state=="Completed" and d.imageUrl and #d.imageUrl>0 then
        _thumbCache[id]=d.imageUrl; return d.imageUrl
      end
    end
  else
    log("Thumb API fail:",err or "unknown")
  end
  local url=("https://www.roblox.com/asset-thumbnail/image?assetId=%s&width=420&height=420&format=png"):format(id)
  _thumbCache[id]=url; return url
end

-- =========================
-- Event decoding (RE/FishCaught)
-- =========================
local function parseChanceToProb(ch)
  local n=tonumber(ch); if not n or n<=0 then return nil end
  if n>1 then return n/100.0 else return n end
end

local function fmtChanceOneInFromNumber(ch)
  local p=parseChanceToProb(ch); if not p or p<=0 then return "Unknown" end
  local oneIn=math.max(1, math.floor((1/p)+0.5))
  return ("1 in %d"):format(oneIn)
end

local function absorbQuick(info, t)
  if type(t)~="table" then return end
  info.id      = info.id      or t.Id or t.ItemId or t.TypeId or t.FishId
  info.weight  = info.weight  or t.Weight or t.Mass or t.Kg or t.WeightKg
  info.chance  = info.chance  or t.Chance or t.Probability
  info.tier    = info.tier    or t.Tier
  info.icon    = info.icon    or t.Icon
  info.mutations = info.mutations or t.Mutations or t.Modifiers
  if t.Data and type(t.Data)=="table" then
    absorbQuick(info, t.Data)
  end
end

local function decode_RE_FishCaught(packed)
  local info={}
  -- Pola umum Knit/Net:
  -- A) arg1=table{Data={Id, Tier...}, Weight=.., Mutations=..}, arg2=meta
  -- B) arg1=Id (number/string), arg2=table{...}
  local a1,a2=packed[1], packed[2]
  if type(a1)=="table" then
    absorbQuick(info,a1)
    if type(a2)=="table" then absorbQuick(info,a2) end
  elseif typeof(a1)=="number" or typeof(a1)=="string" then
    info.id=toIdStr(a1)
    if type(a2)=="table" then absorbQuick(info,a2) end
  elseif typeof(a1)=="Instance" then
    local a=toAttrMap(a1); absorbQuick(info,a)
    if type(a2)=="table" then absorbQuick(info,a2) end
  end

  -- Lengkapi dari Items metadata
  if info.id then
    local meta=ensureMetaById(toIdStr(info.id))
    if meta then
      info.name = info.name or meta.name
      info.tier = info.tier or meta.tier
      info.chance = info.chance or meta.chance
      info.icon = info.icon or meta.icon
    end
  end

  -- Override manual
  local idS=info.id and toIdStr(info.id)
  if idS and not info.name and CFG.ID_NAME_MAP[idS] then info.name=CFG.ID_NAME_MAP[idS] end

  return next(info) and info or nil
end

-- =========================
-- Formatting
-- =========================
local function toKg(w)
  local n=tonumber(w); if not n then return (w and tostring(w)) or "Unknown" end
  return string.format("%0."..tostring(CFG.WEIGHT_DECIMALS).."f kg", n)
end

local function getTierName(tier) return (tier and TIER_NAME_MAP[tier]) or (tier and tostring(tier)) or "Unknown" end

local function formatMutations(mut)
  if type(mut)=="table" then
    local t={} ; for k,v in pairs(mut) do
      if type(v)=="boolean" and v then table.insert(t,tostring(k))
      elseif v~=nil and v~=false then table.insert(t, tostring(k)..":"..tostring(v)) end
    end
    return (#t>0) and table.concat(t,", ") or "None"
  elseif mut~=nil then
    return tostring(mut)
  end
  return "None"
end

-- =========================
-- Send pipeline
-- =========================
local function sendEmbed(info, origin)
  local fishName=info.name or "Unknown Fish"
  if fishName=="Unknown Fish" and info.id then
    local meta=_metaById[toIdStr(info.id)]
    if meta and meta.name then fishName=meta.name end
  end

  local imageUrl=nil
  if info.icon then
    imageUrl=resolveIconUrl(info.icon)
  elseif info.id and _metaById[toIdStr(info.id)] and _metaById[toIdStr(info.id)].icon then
    imageUrl=resolveIconUrl(_metaById[toIdStr(info.id)].icon)
  end
  if CFG.DEBUG then log("Image URL:", tostring(imageUrl)) end

  local embed={
    title="🐟 New Catch: "..fishName,
    description=("**Player:** %s\n**Origin:** %s"):format(Players.LocalPlayer.Name, origin or "unknown"),
    timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
    fields={
      {name="Weight", value=toKg(info.weight), inline=true},
      {name="Chance", value=fmtChanceOneInFromNumber(info.chance), inline=true},
      {name="Rarity", value=getTierName(info.tier), inline=true},
      {name="Mutation(s)", value=formatMutations(info.mutations or info.mutation), inline=false},
      {name="Fish ID", value=info.id and tostring(info.id) or "Unknown", inline=true},
    }
  }
  if imageUrl then
    if CFG.USE_LARGE_IMAGE then embed.image={url=imageUrl} else embed.thumbnail={url=imageUrl} end
  end

  sendWebhook({ username=".devlogic notifier", embeds={embed} })
end

local function onCatchWindow()
  -- Pakai inbound event terbaru di jendela waktu
  for i=#_lastInbound,1,-1 do
    local hit=_lastInbound[i]
    if now()-hit.t <= CFG.CATCH_WINDOW_SEC then
      local info=decode_RE_FishCaught(hit.args)
      if info and (info.id or info.name) then
        sendEmbed(info, "OnClientEvent:"..hit.name)
        return
      end
    end
  end

  -- Fallback ringan (opsional) — default OFF
  if CFG.USE_BACKPACK_FALLBACK then
    for _,inst in ipairs(Backpack:GetChildren()) do
      local a=toAttrMap(inst)
      if a and a.Id then
        local meta=ensureMetaById(toIdStr(a.Id))
        if meta then
          sendEmbed({
            id=a.Id, name=meta.name, tier=meta.tier, chance=meta.chance, icon=meta.icon,
            weight=a.Weight or a.Mass, mutations=a.Mutations or a.Mutation
          }, "Backpack:"..inst.Name)
          return
        end
      end
    end
  end

  if CFG.DEBUG then log("No info in window; skipped") end
end

-- =========================
-- Wiring (3 sumber utama)
-- =========================
local function connectInbound()
  local function want(nm)
    local n=string.lower(nm)
    for _,kw in ipairs(CFG.INBOUND_EVENTS) do if string.find(n, string.lower(kw)) then return true end end
    return false
  end
  local ge=RS
  local function maybeConnect(d)
    if d:IsA("RemoteEvent") and want(d.Name) then
      table.insert(_conns, d.OnClientEvent:Connect(function(...)
        local packed=table.pack(...)
        table.insert(_lastInbound, {t=now(), name=d.Name, args=packed})
        if CFG.DEBUG then
          -- print bentuk arg ringkas tanpa deep scan
          local a1=packed[1]; local typ=typeof(a1)
          log("Inbound:", d.Name, "argc=", packed.n or 0, "arg1=", typ)
        end
        task.defer(onCatchWindow)
      end))
      log("Hooked:", d:GetFullName())
    end
  end
  for _,d in ipairs(ge:GetDescendants()) do maybeConnect(d) end
  table.insert(_conns, ge.DescendantAdded:Connect(maybeConnect))
end

local function connectLeaderstatsTrigger()
  local ls = LP:FindFirstChild("leaderstats")
  if not ls then return end
  local Caught = ls:FindFirstChild("Caught")
  local Data   = Caught and (Caught:FindFirstChild("Data") or Caught)
  if Data and Data:IsA("ValueBase") then
    table.insert(_conns, Data.Changed:Connect(function()
      _recentTriggerTs = now()
      if CFG.DEBUG then log("leaderstats trigger") end
      task.defer(onCatchWindow)
    end))
  end
end

local function connectBackpackLight()
  if not CFG.USE_BACKPACK_FALLBACK then return end
  table.insert(_conns, Backpack.ChildAdded:Connect(function(inst)
    if CFG.DEBUG then log("Backpack +", inst.Name) end
  end))
end

-- =========================
-- Public API
-- =========================
getgenv().FishCatchDetector = getgenv().FishCatchDetector or {}
local M = getgenv().FishCatchDetector

function M.Start(opts)
  if opts then for k,v in pairs(opts) do CFG[k]=v end end
  detectItemsRoot(); buildLightIndex()
  if (tonumber(CFG.PRELOAD_ITEM_COUNT) or 0)>0 then preloadSome(tonumber(CFG.PRELOAD_ITEM_COUNT)) end
  connectInbound()
  connectLeaderstatsTrigger()
  connectBackpackLight()
  log("FCD v3.4.0 started. DEBUG=", CFG.DEBUG)
end

function M.Kill()
  for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
  table.clear(_conns)
  log("FCD v3.4.0 stopped.")
end

function M.SetConfig(patch) for k,v in pairs(patch or {}) do CFG[k]=v end end

function M.TestWebhook(msg)
  sendWebhook({ username=".devlogic notifier", content=msg or "Test ping" })
end

-- Debug: lihat meta by ID
function M.DebugFishID(id)
  local idStr=toIdStr(id)
  local meta=ensureMetaById(idStr)
  if meta then
    log(("ID %s -> name=%s, tier=%s, chance=%s, icon=%s"):format(idStr, tostring(meta.name), tostring(meta.tier), tostring(meta.chance), tostring(meta.icon)))
  else
    log("ID not found:", tostring(idStr))
  end
end

return M
