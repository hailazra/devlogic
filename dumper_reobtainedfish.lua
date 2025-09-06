--[[
  RE/ObtainedNewFishNotification – Payload Dumper + Schema Inference (standalone)

  Fitur:
    - Hook OnClientEvent utk RemoteEvent bernama persis "RE/ObtainedNewFishNotification".
    - Pretty dump payload (deep, aman).
    - Kumpulin beberapa sample, bikin "schema/template" (union key + tipe + contoh).
    - Export JSON dari sample terakhir (bersih dari function/userdata).



local Dumper = {}
Dumper.__index = Dumper

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Config
local CFG = {
  TARGET_NAME   = "RE/ObtainedNewFishNotification",
  MAX_DEPTH     = 6,     -- kedalaman pretty/schema
  MAX_ARRAY_SCAN= 200,   -- batas elemen array yg discan
  MAX_SAMPLES   = 200,   -- simpan contoh maksimal
  SHOW_RAW_DUMP = true,  -- print payload mentah (pretty) setiap event
  SHOW_PATH     = true,  -- print full path instance
  SHOW_TIMING   = true,  -- print timestamp os.clock()
  SCAN_ROOTS    = {ReplicatedStorage}, -- tambah root lain kalau perlu
}

-- State
local conns = {}
local running = false
local samples = {}   -- list of {t, path, payload}
local lastRaw = nil  -- raw payload terakhir (steril utk JSON)
local schema = {}    -- tree schema (union dari semua sample)

-- ===== utils =====
local function log(...)
  warn("[RE/ObtainedNewFishNotification]", ...)
end

local function now() return os.clock() end

local function isArray(tbl)
  local n = #tbl
  if n == 0 then
    -- bisa aja dictionary kosong, treat as dict
    -- biarin schema mark sebagai object jika ada key non-numeric nanti
    return false
  end
  -- cek apakah indeks 1..n semua ada
  for i = 1, n do
    if tbl[i] == nil then return false end
  end
  -- ada elemen di atas #tbl?
  for k in next, tbl do
    if type(k) ~= "number" then return false end
    if k < 1 or k % 1 ~= 0 then return false end
    if k > n then return false end
  end
  return true
end

local function typeofLoose(v)
  local t = typeof(v)
  if t == "table" then
    if isArray(v) then return "array" else return "object" end
  end
  if t == "Instance" then return "Instance" end
  if t == "userdata" or t == "thread" or t == "function" then return "unsupported" end
  return t
end

local function safePreview(v, depth, seen)
  depth = depth or 0
  seen = seen or {}
  if depth > CFG.MAX_DEPTH then return "<max-depth>" end
  local t = typeof(v)
  if t == "table" then
    if seen[v] then return "<cycle>" end
    seen[v] = true
    if isArray(v) then
      local out, n = {}, math.min(#v, 10)
      for i = 1, n do
        out[i] = safePreview(v[i], depth+1, seen)
      end
      if #v > n then out[n+1] = "..." end
      return "[" .. table.concat(out, ", ") .. "]"
    else
      local parts, n = {}, 0
      for k,val in next, v do
        n += 1
        parts[n] = tostring(k) .. "=" .. safePreview(val, depth+1, seen)
        if n >= 12 then parts[n+1] = "..."; break end
      end
      return "{" .. table.concat(parts, ", ") .. "}"
    end
  elseif t == "Instance" then
    local ok, path = pcall(function() return v:GetFullName() end)
    return string.format("<%s:%s>", v.ClassName, ok and path or "?")
  elseif t == "string" then
    if #v > 300 then
      return string.format("%q...", v:sub(1,300))
    end
    return string.format("%q", v)
  elseif t == "function" or t == "userdata" or t == "thread" then
    return "<"..t..">"
  else
    return tostring(v)
  end
end

-- Sterilizer: hapus function/userdata/thread, ganti Instance dengan path, batasi depth/array
local function sterilize(v, depth, seen)
  depth = depth or 0
  seen = seen or {}
  if depth > CFG.MAX_DEPTH then return "<max-depth>" end
  local t = typeof(v)
  if t == "table" then
    if seen[v] then return "<cycle>" end
    seen[v] = true
    if isArray(v) then
      local out = {}
      local n = math.min(#v, CFG.MAX_ARRAY_SCAN)
      for i = 1, n do
        out[i] = sterilize(v[i], depth+1, seen)
      end
      if #v > n then out[n+1] = "<truncated>" end
      return out
    else
      local out = {}
      local n = 0
      for k,val in next, v do
        n += 1
        if n > 500 then
          out["<truncated_keys>"] = true
          break
        end
        out[tostring(k)] = sterilize(val, depth+1, seen)
      end
      return out
    end
  elseif t == "Instance" then
    local ok, path = pcall(function() return v:GetFullName() end)
    return { __instance = v.ClassName, path = (ok and path or "?") }
  elseif t == "function" or t == "userdata" or t == "thread" then
    return "<"..t..">"
  else
    return v
  end
end

-- ===== schema inference =====
-- node format:
--   { __k = {key1=true,...}, __t = {set of types}, example = any, props = map, items = node }
local function ensureSet(tbl, key)
  local set = rawget(tbl, key)
  if not set then
    set = {}
    rawset(tbl, key, set)
  end
  return set
end

local function pickExample(old, v)
  if old ~= nil then return old end
  return v
end

local function mergeSchema(node, v, depth, seen)
  depth = depth or 0
  seen = seen or {}
  if depth > CFG.MAX_DEPTH then return end

  node.__t = node.__t or {}
  local t = typeofLoose(v)
  node.__t[t] = true
  node.example = pickExample(node.example, (t == "object" or t == "array") and nil or v)

  if t == "object" then
    if seen[v] then return end
    seen[v] = true
    node.props = node.props or {}
    node.__k = node.__k or {}
    local n = 0
    for k,val in next, v do
      n += 1
      if n > 500 then
        node.props["<truncated_keys>"] = {__t={notice=true}, example=true}
        break
      end
      local ks = tostring(k)
      node.__k[ks] = true
      node.props[ks] = node.props[ks] or {}
      mergeSchema(node.props[ks], val, depth+1, seen)
    end
  elseif t == "array" then
    node.items = node.items or {}
    local n = math.min(#v, CFG.MAX_ARRAY_SCAN)
    for i = 1, n do
      mergeSchema(node.items, v[i], depth+1, seen)
    end
    if #v > n then
      -- mark truncated but still fine
      node.items.__t = node.items.__t or {}
      node.items.__t.truncated = true
    end
  elseif t == "Instance" then
    -- nothing extra
  end
end

local function schemaToLines(node, indent, name)
  indent = indent or ""
  local lines = {}
  local function tsetToStr(tset)
    local keys = {}
    for k in pairs(tset or {}) do table.insert(keys, k) end
    table.sort(keys)
    return table.concat(keys, "|")
  end

  local header = string.format("%s%s: (%s)", indent, name or "<root>", tsetToStr(node.__t))
  table.insert(lines, header)
  if node.example ~= nil then
    table.insert(lines, string.format("%s  example = %s", indent, safePreview(node.example)))
  end

  if node.props then
    table.insert(lines, string.format("%s  props:", indent))
    local keys = {}
    for k in pairs(node.props) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local child = node.props[k]
      local childHead = string.format("%s    %s (%s)", indent, k, tsetToStr(child.__t))
      table.insert(lines, childHead)
      if child.example ~= nil then
        table.insert(lines, string.format("%s      example = %s", indent, safePreview(child.example)))
      end
      -- recurse props/items
      if child.props or child.items then
        local sub = schemaToLines(child, indent .. "      ")
        for i=2,#sub do table.insert(lines, sub[i]) end
      end
    end
  end

  if node.items then
    table.insert(lines, string.format("%s  items:", indent))
    local sub = schemaToLines(node.items, indent .. "    ", "[*]")
    for i=2,#sub do table.insert(lines, sub[i]) end
  end
  return lines
end

local function printSchema()
  if not next(schema) then
    log("schema kosong (belum ada sample).")
    return
  end
  log("======== SCHEMA (union dari semua sample) ========")
  local lines = schemaToLines(schema, "", "<payload>")
  for _, ln in ipairs(lines) do print(ln) end
  log("==================================================")
end

-- ===== hook =====
local function onRemote(re)
  table.insert(conns, re.OnClientEvent:Connect(function(...)
    local tnow = now()
    local packed = table.pack(...)
    local payload = (#packed >= 1) and packed[1] or packed -- kebanyakan game kirim 1 arg table
    local path = (function() local ok,p=pcall(function() return re:GetFullName() end); return ok and p or "?" end)()

    -- Sterilize & simpan sample (ring manual)
    local sterile = sterilize(payload)
    lastRaw = sterile
    table.insert(samples, 1, {t=tnow, path=path, payload=sterile})
    if #samples > CFG.MAX_SAMPLES then table.remove(samples) end

    -- Merge ke schema
    mergeSchema(schema, payload)

    -- Dump
    if CFG.SHOW_TIMING then
      print(string.format("[time=%.3f]", tnow))
    end
    if CFG.SHOW_PATH then
      print("[path]", path)
    end
    if CFG.SHOW_RAW_DUMP then
      print("----- PAYLOAD (preview) -----")
      print(safePreview(payload, 0, {}))
      print("-----------------------------")
    end

    -- Tampilkan delta schema setiap event (ringkas)
    print(">> schema updated. samples:", #samples)
  end))
  log("hooked:", re:GetFullName())
end

local function findAndHook()
  local found = 0
  for _, root in ipairs(CFG.SCAN_ROOTS) do
    for _, d in ipairs(root:GetDescendants()) do
      if d:IsA("RemoteEvent") and d.Name == CFG.TARGET_NAME then
        onRemote(d)
        found += 1
      end
    end
    table.insert(conns, root.DescendantAdded:Connect(function(d)
      if d:IsA("RemoteEvent") and d.Name == CFG.TARGET_NAME then
        onRemote(d)
      end
    end))
  end
  log("scan done; found:", found)
end

-- ===== API =====
function Dumper:Init(opts)
  opts = opts or {}
  for k,v in pairs(opts) do
    if CFG[k] ~= nil then CFG[k] = v end
  end
  samples, schema, lastRaw = {}, {}, nil
  return true
end

function Dumper:Start()
  if running then return end
  running = true
  findAndHook()
  log("started")
end

function Dumper:Stop()
  if not running then return end
  running = false
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  table.clear(conns)
  log("stopped")
end

function Dumper:PrintSchema()
  printSchema()
end

function Dumper:GetSamples()
  return samples -- newest-first
end

function Dumper:ExportLastJSON()
  if not lastRaw then return "null" end
  local ok, j = pcall(HttpService.JSONEncode, HttpService, lastRaw)
  return ok and j or "null"
end

return setmetatable({}, Dumper)