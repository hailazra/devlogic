--[[
  INBOUND DEBUGGER (standalone)
  - Hook OnClientEvent untuk RemoteEvent tertentu (default: RE/FishCaught, RE/ObtainedNewFishNotification)
  - Log ke console: path, argc, arg preview (safe/pretty)
  - Simpan buffer (ring), bisa kamu tarik via :GetBuffer()
  - Tanpa modif fishwebhook.lua / pipeline embed kamu

  Cara pakai cepat:
    local dbg = loadstring(game:HttpGet("https://paste.your/raw/inbound_debugger.lua"))()  -- ATAU paste langsung file ini dan require
    dbg:Init({
      DEBUG = true,
      INBOUND_EVENTS   = { "RE/FishCaught", "RE/ObtainedNewFishNotification" },
      INBOUND_PATTERNS = { "fish", "catch" }, -- opsional
      HOOK_ALL = false,                       -- true kalau mau tangkap semua RemoteEvent
      RING_SIZE = 200,                        -- simpan 200 event terakhir
      MAX_DEPTH = 3,                          -- batas kedalaman pretty printer
    })
    dbg:Start()

  Perintah runtime:
    dbg:Stop()               -- cabut semua connection
    dbg:Clear()              -- bersihkan buffer
    dbg:SetFilter{...}       -- ganti filter nama/pattern saat jalan
    dbg:GetBuffer()          -- ambil ring buffer (array of items)
    dbg:ExportJSON()         -- JSON string dari buffer (buat copy)
]]

local DebugInbound = {}
DebugInbound.__index = DebugInbound

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- State
local CFG = {
  DEBUG = true,
  INBOUND_EVENTS   = { "RE/FishCaught", "RE/ObtainedNewFishNotification" },
  INBOUND_PATTERNS = { "fish", "catch", "legend", "myth", "secret", "reward" },
  HOOK_ALL = false,
  RING_SIZE = 200,
  MAX_DEPTH = 3,
}

local connections = {}
local buffer = table.create(CFG.RING_SIZE)
local head = 0
local count = 0
local running = false

-- ===== utils =====
local function now() return os.clock() end

local function log(...)
  if CFG.DEBUG then
    warn("[INBOUND-DBG]", ...)
  end
end

local function pushRing(item)
  local size = CFG.RING_SIZE
  if size <= 0 then return end
  head = (head % size) + 1
  buffer[head] = item
  if count < size then
    count += 1
  end
end

local function snapshotRing()
  local out = {}
  local size = math.min(count, CFG.RING_SIZE)
  if size == 0 then return out end
  local idx = head
  for i = 1, size do
    out[size - i + 1] = buffer[idx]   -- newest first
    idx -= 1
    if idx <= 0 then idx = CFG.RING_SIZE end
  end
  return out
end

local function safe(val, depth, seen)
  depth = depth or 0
  seen = seen or {}
  if depth > CFG.MAX_DEPTH then
    return "<max-depth>"
  end
  local t = typeof(val)
  if t == "table" then
    if seen[val] then return "<cycle>" end
    seen[val] = true
    local parts = {}
    local n = 0
    for k,v in next, val do
      n += 1
      parts[n] = tostring(k) .. "=" .. safe(v, depth+1, seen)
      if n >= 12 then parts[n+1] = "..."; break end
    end
    return "{" .. table.concat(parts, ", ") .. "}"
  elseif t == "Instance" then
    local ok, path = pcall(function() return val:GetFullName() end)
    return string.format("<%s:%s>", val.ClassName, ok and path or "?")
  elseif t == "string" then
    if #val > 200 then
      return string.format("%q...", val:sub(1,200))
    end
    return string.format("%q", val)
  else
    return tostring(val)
  end
end

local function wantByName(name)
  if CFG.HOOK_ALL then return true end
  local n = string.lower(name)
  for _, exact in ipairs(CFG.INBOUND_EVENTS or {}) do
    if string.lower(exact) == n then return true end
  end
  for _, pat in ipairs(CFG.INBOUND_PATTERNS or {}) do
    if pat ~= "" and n:find(pat, 1, true) then return true end
  end
  return false
end

local function packArgs(...)
  local p = table.pack(...)
  -- buat preview ringkas
  local preview = {}
  for i = 1, p.n do
    preview[i] = safe(p[i])
    if i >= 8 then preview[i+1] = "..."; break end
  end
  return p, preview
end

-- ===== hookers =====
local function onRemoteEvent(re)
  table.insert(connections, re.OnClientEvent:Connect(function(...)
    local args, preview = packArgs(...)
    local item = {
      t = now(),
      type = "OnClientEvent",
      name = re.Name,
      path = (function() local ok,p=pcall(function() return re:GetFullName() end); return ok and p or "?" end)(),
      argc = args.n or #args,
      preview = preview,
      args = args, -- disimpan mentah untuk inspeksi manual
    }
    pushRing(item)
    log(string.format("IN %s | %s | argc=%d | args=%s", item.type, item.path, item.argc, table.concat(preview, ", ")))
  end))
  log("hooked:", re:GetFullName())
end

local function connectAll()
  -- scan awal
  for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
    if inst:IsA("RemoteEvent") and wantByName(inst.Name) then
      onRemoteEvent(inst)
    end
  end
  -- yang muncul belakangan
  table.insert(connections, ReplicatedStorage.DescendantAdded:Connect(function(inst)
    if inst:IsA("RemoteEvent") and wantByName(inst.Name) then
      onRemoteEvent(inst)
    end
  end))
end

-- ===== API =====
function DebugInbound:Init(opts)
  opts = opts or {}
  for k,v in pairs(opts) do
    if CFG[k] ~= nil then
      CFG[k] = v
    end
  end
  -- resize ring jika perlu
  buffer = table.create(CFG.RING_SIZE)
  head, count = 0, 0
  log("init ok")
  return true
end

function DebugInbound:Start()
  if running then return end
  running = true
  connectAll()
  log("started")
  return true
end

function DebugInbound:Stop()
  if not running then return end
  running = false
  for _, c in ipairs(connections) do
    pcall(function() c:Disconnect() end)
  end
  table.clear(connections)
  log("stopped")
end

function DebugInbound:Clear()
  head, count = 0, 0
  table.clear(buffer)
  log("buffer cleared")
end

function DebugInbound:GetBuffer()
  return snapshotRing()
end

function DebugInbound:ExportJSON()
  local snap = snapshotRing()
  -- buang fungsi & userdata sebelum JSON
  for _, it in ipairs(snap) do
    it.args = nil  -- berat dan berisi function/userdata
  end
  local ok, j = pcall(HttpService.JSONEncode, HttpService, snap)
  if ok then return j end
  return "[]"
end

function DebugInbound:SetFilter(cfg)
  if type(cfg) ~= "table" then return false end
  for k,v in pairs(cfg) do
    if CFG[k] ~= nil then
      CFG[k] = v
    end
  end
  log("filter updated")
  return true
end

return setmetatable({}, DebugInbound)