-- utils_dump_inventory.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
local StringLib   = require(ReplicatedStorage.Shared.StringLibrary)

local function resolveName(category, id)
    -- Coba path spesifik dulu, fallback ke GetItemData generic
    if category == "Baits" then
        local d = ItemUtility:GetBaitData(id)
        return d and d.Data and d.Data.Name
    end
    local d2 = ItemUtility.GetItemDataFromItemType and ItemUtility:GetItemDataFromItemType(category, id)
    if d2 and d2.Data then return d2.Data.Name end
    local d3 = ItemUtility:GetItemData(id)
    return (d3 and d3.Data and d3.Data.Name) or tostring(id)
end

local function fmtWeight(w)
    if not w then return nil end
    -- kalau game punya AddWeight, pakai itu; kalau tidak ya tambal sederhana:
    return (StringLib.AddWeight and StringLib:AddWeight(w)) or (tostring(w).."kg")
end

-- Dump satu kategori ke console
local function dumpCategory(inv, category)
    local arr = inv:getSnapshot(category)  -- dari inventory_watcher_v2
    print(("-- %s (%d items) --"):format(category, #arr))
    for i, entry in ipairs(arr) do
        local id    = entry.Id or entry.id
        local uuid  = entry.UUID or entry.Uuid or entry.uuid
        local meta  = entry.Metadata or {}
        local name  = resolveName(category, id)
        if category == "Fishes" then
            local w  = fmtWeight(meta.Weight)
            local v  = meta.VariantId or meta.Mutation or meta.Variant
            local sh = (meta.Shiny == true) and "★" or ""
            print(i, name, uuid, w or "-", v or "-", sh)
        else
            print(i, name, uuid)
        end
    end
end

-- Dump semua kategori
local function dumpAll(inv)
    for _, key in ipairs({ "Items","Fishes","Potions","Baits","Fishing Rods" }) do
        dumpCategory(inv, key)
    end
end

return { dumpCategory = dumpCategory, dumpAll = dumpAll }
