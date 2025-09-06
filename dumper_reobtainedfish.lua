-- decode_obnfn_v2.lua
-- Decoder robust untuk RE/ObtainedNewFishNotification (kebal nil & variasi struktur)

local M = {}

-- ==== util aman ====
local function isTable(x) return typeof(x) == "table" end

local function safeGet(t, k)
  if type(t) == "table" then return rawget(t, k) end
  return nil
end

local function hasKeys(tbl, keys)
  if type(tbl) ~= "table" then return false end
  for i = 1, #keys do
    local k = keys[i]
    if rawget(tbl, k) == nil then return false end
  end
  return true
end

local function walk(t, fn, seen)
  if type(t) ~= "table" then return end
  seen = seen or {}
  if seen[t] then return end
  seen[t] = true
  fn(t)
  for _, v in next, t do
    if type(v) == "table" then
      walk(v, fn, seen)
    end
  end
end

local function getFirst(rootTables, predicate)
  local found
  for i = 1, #rootTables do
    local rt = rootTables[i]
    if type(rt) == "table" then
      walk(rt, function(tbl)
        if not found and predicate(tbl) then
          found = tbl
        end
      end)
      if found then break end
    end
  end
  return found
end

-- ==== main decode ====
-- metaLookup(idStr) opsional -> {name, tier, chance, icon}
function M.decode_OBNFN(packed, metaLookup)
  -- Kumpulkan semua argumen yg bertipe table
  local bags = {}
  local n = packed and (packed.n or #packed) or 0
  for i = 1, n do
    local v = packed[i]
    if type(v) == "table" then
      bags[#bags+1] = v
    end
  end

  -- Telemetry ringan kalau nggak ada table sama sekali
  if #bags == 0 then
    warn("[OBNFN] no table args; argc=", n, "types=", (function()
      local t = {}
      for i = 1, n do t[i] = typeof(packed[i]) end
      return table.concat(t, ",")
    end)())
  end

  -- Cari node metadata ringkas: {Weight, VariantSeed, (Shiny|VariantId optional)}
  local metaNode = getFirst(bags, function(tbl)
    return hasKeys(tbl, {"Weight","VariantSeed"}) and (tbl.Shiny ~= nil or tbl.VariantId ~= nil)
  end)

  -- Alternatif: Metadata di dalam container
  if not metaNode then
    local container = getFirst(bags, function(tbl)
      local md = safeGet(tbl, "Metadata")
      return hasKeys(md, {"Weight","VariantSeed"})
    end)
    if container then
      metaNode = safeGet(container, "Metadata")
    end
  end

  -- Cari container item/ID/UUID/favorit
  local itemContainer = getFirst(bags, function(tbl)
    if safeGet(tbl, "ItemId") ~= nil then return true end
    local inv = safeGet(tbl, "InventoryItem")
    return isTable(inv) and (safeGet(inv, "Id") ~= nil or safeGet(inv, "UUID") ~= nil)
  end)

  local out = {
    source       = "RE/ObtainedNewFishNotification",
    shiny        = metaNode and metaNode.Shiny or false,
    weight       = metaNode and metaNode.Weight or nil,
    variant_id   = metaNode and metaNode.VariantId or nil,
    variant_seed = metaNode and metaNode.VariantSeed or nil,
    id           = nil,
    uuid         = nil,
    favorited    = nil,
  }

  if itemContainer then
    out.id = safeGet(itemContainer, "ItemId")
          or (isTable(itemContainer.InventoryItem) and safeGet(itemContainer.InventoryItem, "Id"))
          or out.id

    out.uuid = safeGet(itemContainer, "UUID")
           or (isTable(itemContainer.InventoryItem) and safeGet(itemContainer.InventoryItem, "UUID"))
           or out.uuid

    local fav1 = safeGet(itemContainer, "Favorited")
    local inv  = isTable(itemContainer.InventoryItem) and itemContainer.InventoryItem or nil
    local fav2 = inv and safeGet(inv, "Favorited") or nil
    if fav1 ~= nil then out.favorited = fav1
    elseif fav2 ~= nil then out.favorited = fav2
    end
  end

  -- Lengkapi dari katalog jika tersedia
  if out.id and metaLookup then
    local meta = metaLookup(tostring(out.id))
    if meta then
      out.name   = meta.name   or out.name
      out.tier   = meta.tier   or out.tier
      out.chance = meta.chance or out.chance
      out.icon   = meta.icon   or out.icon
    end
  end

  -- Mutations ringkas buat webhook/log
  out.mutations = {}
  if out.shiny ~= nil then table.insert(out.mutations, ("Shiny=%s"):format(tostring(out.shiny))) end
  if out.variant_id then table.insert(out.mutations, ("VariantId=%s"):format(tostring(out.variant_id))) end

  -- Normalisasi weight
  if out.weight ~= nil and typeof(out.weight) ~= "number" then
    local num = tonumber(out.weight)
    if num then out.weight = num end
  end

  return out
end

return M
