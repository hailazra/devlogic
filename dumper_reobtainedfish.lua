-- decode_obnfn.lua
-- Decoder robust untuk RE/ObtainedNewFishNotification
-- Menghasilkan info terstruktur dari packed args (table.pack(...))

local M = {}

-- ==== util: recursive scan ====
local function isTable(x) return typeof(x) == "table" end

local function walk(t, fn, seen)
  if not isTable(t) then return end
  seen = seen or {}
  if seen[t] then return end
  seen[t] = true
  fn(t)
  -- array/object agnostic
  for k, v in next, t do
    if isTable(v) then
      walk(v, fn, seen)
    end
  end
end

local function getFirst(t, predicate)
  local found
  walk(t, function(tbl)
    if not found and predicate(tbl) then
      found = tbl
    end
  end)
  return found
end

local function hasKeys(tbl, keys)
  for _, k in ipairs(keys) do
    if rawget(tbl, k) == nil then return false end
  end
  return true
end

-- ==== main decode ====
-- metaLookup(id) opsional: return {name=..., tier=..., chance=..., icon=...}
function M.decode_OBNFN(packed, metaLookup)
  -- Gabungkan semua argumen table ke satu list supaya mudah discan
  local bags = {}
  for i = 1, packed or #packed do
    if isTable(packed[i]) then table.insert(bags, packed[i]) end
  end

  -- Kandidat metadata (top-level kecil atau di bawah Metadata=)
  local meta = getFirst(bags, function(tbl)
    return hasKeys(tbl, {"Weight","VariantSeed"}) and (tbl.Shiny ~= nil or tbl.VariantId ~= nil)
  end)

  local metaNode = meta
  -- Cari juga meta yang berada di { Metadata = {...} }
  if not metaNode then
    local container = getFirst(bags, function(tbl)
      return isTable(rawget(tbl, "Metadata")) and hasKeys(tbl.Metadata, {"Weight","VariantSeed"})
    end)
    if container then metaNode = container.Metadata end
  end

  -- Cari info item/ID/UUID/favorite
  local itemContainer = getFirst(bags, function(tbl)
    return rawget(tbl, "ItemId") ~= nil or isTable(rawget(tbl, "InventoryItem"))
  end)

  local out = {
    source = "RE/ObtainedNewFishNotification",
    shiny  = metaNode and metaNode.Shiny or (meta and meta.Shiny) or false,
    weight = metaNode and metaNode.Weight or nil,
    variant_id   = metaNode and metaNode.VariantId or nil,   -- contoh: "Galaxy"
    variant_seed = metaNode and metaNode.VariantSeed or nil,
  }

  -- ID bisa muncul di beberapa tempat
  out.id = nil
  if itemContainer then
    out.id = itemContainer.ItemId or (itemContainer.InventoryItem and itemContainer.InventoryItem.Id) or out.id
    out.uuid = itemContainer.UUID
      or (itemContainer.InventoryItem and itemContainer.InventoryItem.UUID)
    out.favorited = (itemContainer.Favorited ~= nil and itemContainer.Favorited)
      or (itemContainer.InventoryItem and itemContainer.InventoryItem.Favorited)
  end

  -- Lengkapi nama/tier/chance/icon via metaLookup bila ada
  if out.id and metaLookup then
    local metaInfo = metaLookup(tostring(out.id))
    if metaInfo then
      out.name   = metaInfo.name   or out.name
      out.tier   = metaInfo.tier   or out.tier
      out.chance = metaInfo.chance or out.chance
      out.icon   = metaInfo.icon   or out.icon
    end
  end

  -- Mutations view sederhana (untuk webhook)
  out.mutations = {}
  if out.shiny ~= nil then table.insert(out.mutations, ("Shiny=%s"):format(tostring(out.shiny))) end
  if out.variant_id    then table.insert(out.mutations, ("VariantId=%s"):format(tostring(out.variant_id))) end

  -- Normalisasi tipe
  if typeof(out.weight) == "number" then
    -- biarin apa adanya; formatting kg serahin ke layer embed
  elseif out.weight ~= nil then
    -- kadang string; coba parse number ringan
    local num = tonumber(out.weight)
    if num then out.weight = num end
  end

  return out
end

return M
