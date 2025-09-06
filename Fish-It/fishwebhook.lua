-- ===========================
-- FISH WEBHOOK FEATURE (UPDATED)
-- File: fishwebhook.lua
-- Updated to use RE/ObtainedNewFishNotification
-- ===========================

local FishWebhookFeature = {}
FishWebhookFeature.__index = FishWebhookFeature

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack", 10)

-- Feature state
local isRunning = false
local webhookUrl = ""
local selectedFishTypes = {}
local controls = {}

-- Internal state
local connections = {}
local lastInbound = {}
local recentAdds = {}
local rareWatchUntil = 0
local onCatchWindowBusy = false
local debounceSend = 0

-- Configuration
local CONFIG = {
    DEBUG = true,
    WEIGHT_DECIMALS = 2,
    CATCH_WINDOW_SEC = 2.5,
    RARE_WINDOW_SEC = 10.0,
    DEDUP_TTL_SEC = 12.0,
    USE_LARGE_IMAGE = false,
    THUMB_SIZE = "150x150",
    -- UPDATED: Use new RemoteEvent for fish notifications
    INBOUND_EVENTS = { "RE/ObtainedNewFishNotification" },
    INBOUND_PATTERNS = { "fish", "catch", "legend", "myth", "secret", "reward", "obtained", "notification" },
    ID_NAME_MAP = {},
}

local TIER_NAME_MAP = {
    [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic",
    [5] = "Legendary", [6] = "Mythic", [7] = "Secret",
    -- Add potential alternative mappings that games might use
    [0] = "Basic", [8] = "Ultra", [9] = "Master", [10] = "Divine",
    -- Sometimes games use different tier systems
    ["Common"] = "Common", ["Uncommon"] = "Uncommon", ["Rare"] = "Rare", 
    ["Epic"] = "Epic", ["Legendary"] = "Legendary", ["Mythic"] = "Mythic", 
    ["Secret"] = "Secret", ["Ultra"] = "Ultra", ["Master"] = "Master"
}

-- Items cache
local itemsRoot = nil
local tiersData = nil
local indexBuilt = false
local moduleById = {}
local metaById = {}
local scannedSet = {}
local tiersByNumber = {}
local tiersByName = {}

-- Thumbnail and dedup cache
local thumbCache = {}
local sentCache = {}

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================
local function now() return os.clock() end
local function log(...) if CONFIG.DEBUG then warn("[FishWebhook]", ...) end end
local function toIdStr(v) 
    local n = tonumber(v) 
    return n and tostring(n) or (v and tostring(v) or nil) 
end
local function safeClear(t) 
    if table and table.clear then 
        table.clear(t) 
    else 
        for k in pairs(t) do t[k] = nil end 
    end 
end

-- ===========================
-- HTTP FUNCTIONS
-- ===========================
local function getRequestFn()
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    if type(http_request) == "function" then return http_request end
    if type(request) == "function" then return request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
    return nil
end

local function sendWebhook(payload)
    if not webhookUrl or webhookUrl:find("XXXX/BBBB") or webhookUrl == "" then
        log("WEBHOOK_URL not set or invalid")
        return
    end
    
    local req = getRequestFn()
    if not req then 
        log("No HTTP backend available")
        return 
    end
    
    local ok, res = pcall(req, {
        Url = webhookUrl,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "Mozilla/5.0",
            ["Accept"] = "*/*"
        },
        Body = HttpService:JSONEncode(payload)
    })
    
    if not ok then 
        log("HTTP request error:", tostring(res))
        return 
    end
    
    local code = tonumber(res.StatusCode or res.Status) or 0
    if code < 200 or code >= 300 then
        log("HTTP status:", code, "body:", tostring(res.Body))
    else
        log("Webhook sent successfully (", code, ")")
    end
end

local function httpGet(url)
    local req = getRequestFn()
    if not req then return nil, "no_request_fn" end
    
    local ok, res = pcall(req, {
        Url = url,
        Method = "GET",
        Headers = {
            ["User-Agent"] = "Mozilla/5.0",
            ["Accept"] = "application/json,*/*"
        }
    })
    
    if not ok then return nil, tostring(res) end
    
    local code = tonumber(res.StatusCode or res.Status) or 0
    if code < 200 or code >= 300 then
        return nil, "status:" .. tostring(code)
    end
    
    return res.Body or "", nil
end

-- ===========================
-- ICON RESOLUTION FUNCTIONS
-- ===========================
local function extractAssetId(icon)
    if not icon then return nil end
    if type(icon) == "number" then return tostring(icon) end
    if type(icon) == "string" then
        local m = icon:match("rbxassetid://(%d+)")
        if m then return m end
        local n = icon:match("(%d+)$")
        if n then return n end
    end
    return nil
end

local function resolveIconUrl(icon)
    local id = extractAssetId(icon)
    if not id then return nil end
    
    if thumbCache[id] then return thumbCache[id] end
    
    local size = CONFIG.THUMB_SIZE or "420x420"
    local api = string.format(
        "https://thumbnails.roblox.com/v1/assets?assetIds=%s&size=%s&format=Png&isCircular=false", 
        id, size
    )
    
    local body, err = httpGet(api)
    if body then
        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        if ok and data and data.data and data.data[1] then
            local d = data.data[1]
            if d.state == "Completed" and d.imageUrl and #d.imageUrl > 0 then
                thumbCache[id] = d.imageUrl
                return d.imageUrl
            end
        end
    else
        log("Thumbnail API failed:", err or "unknown")
    end
    
    local url = string.format(
        "https://www.roblox.com/asset-thumbnail/image?assetId=%s&width=420&height=420&format=png", 
        id
    )
    thumbCache[id] = url
    return url
end

-- ===========================
-- ITEMS DETECTION FUNCTIONS
-- ===========================
local function toAttrMap(inst)
    local a = {}
    if not inst or not inst.GetAttributes then return a end
    
    for k, v in pairs(inst:GetAttributes()) do a[k] = v end
    for _, ch in ipairs(inst:GetChildren()) do
        if ch:IsA("ValueBase") then a[ch.Name] = ch.Value end
    end
    return a
end

local function detectItemsRoot()
    if itemsRoot and itemsRoot.Parent then return itemsRoot end
    
    local function findPath(root, path)
        local cur = root
        for part in string.gmatch(path, "[^/]+") do
            cur = cur and cur:FindFirstChild(part)
        end
        return cur
    end
    
    local hints = {"Items", "GameData/Items", "Data/Items"}
    for _, h in ipairs(hints) do
        local r = findPath(ReplicatedStorage, h)
        if r then 
            itemsRoot = r
            break 
        end
    end
    
    itemsRoot = itemsRoot or ReplicatedStorage:FindFirstChild("Items") or ReplicatedStorage
    return itemsRoot
end

local function safeRequire(ms)
    local ok, data = pcall(require, ms)
    if not ok or type(data) ~= "table" then return nil end
    
    local D = data.Data or {}
    if D.Type ~= "Fishes" then return nil end
    
    local chance = nil
    if type(data.Probability) == "table" then
        chance = data.Probability.Chance
    end
    
    -- Get tier info from the actual Tiers module
    local tierInfo = getTierInfo(D.Tier)
    local tierRarity = tierInfo and tierInfo.Rarity or chance
    
    return {
        id = toIdStr(D.Id),
        name = D.Name,
        tier = D.Tier,  -- Keep original tier number/name
        tierName = tierInfo and tierInfo.Name or getTierName(D.Tier),
        chance = tierRarity,
        icon = D.Icon,
        desc = D.Description,
        _ms = ms,
        _tierInfo = tierInfo  -- Store full tier info for later use
    }
end

local function buildLightIndex()
    if indexBuilt then return end
    
    local root = detectItemsRoot()
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ModuleScript") then
            local n = tonumber(d.Name)
            if n then
                local id = toIdStr(n)
                moduleById[id] = moduleById[id] or d
            end
        end
    end
    indexBuilt = true
end

local function ensureMetaById(idStr)
    idStr = toIdStr(idStr)
    if not idStr then return nil end
    if metaById[idStr] then return metaById[idStr] end
    
    buildLightIndex()
    local ms = moduleById[idStr]
    if ms and not scannedSet[ms] then
        local meta = safeRequire(ms)
        scannedSet[ms] = true
        if meta and meta.id == idStr then
            metaById[idStr] = meta
            return meta
        end
    end
    
    -- Lazy scan until found
    local root = detectItemsRoot()
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ModuleScript") and not scannedSet[d] then
            local meta = safeRequire(d)
            scannedSet[d] = true
            if meta and meta.id then
                moduleById[meta.id] = moduleById[meta.id] or d
                metaById[meta.id] = metaById[meta.id] or meta
                if meta.id == idStr then return meta end
            end
        end
    end
    
    return nil
end

-- ===========================
-- FISH PROCESSING FUNCTIONS (UPDATED)
-- ===========================
local function absorbQuick(info, t)
    if type(t) ~= "table" then return end
    
    info.id = info.id or t.Id or t.ItemId or t.TypeId or t.FishId
    info.weight = info.weight or t.Weight or t.Mass or t.Kg or t.WeightKg
    info.chance = info.chance or t.Chance or t.Probability
    info.tier = info.tier or t.Tier or t.Rarity or t.RarityTier
    info.icon = info.icon or t.Icon
    info.mutations = info.mutations or t.Mutations or t.Modifiers or t.Variants
    info.variantId = info.variantId or t.VariantId or t.Variant
    info.variantSeed = info.variantSeed or t.VariantSeed
    info.shiny = info.shiny or t.Shiny
    info.favorited = info.favorited or t.Favorited or t.Favorite
    info.uuid = info.uuid or t.UUID or t.Uuid
    info.name = info.name or t.Name or t.FishName or t.ItemName
    
    -- Additional tier detection for different game structures
    if not info.tier then
        info.tier = t.Type or t.Class or t.Grade or t.Level
    end
    
    if t.Data and type(t.Data) == "table" then
        absorbQuick(info, t.Data)
    end
    if t.Metadata and type(t.Metadata) == "table" then
        absorbQuick(info, t.Metadata)
    end
    if t.Stats and type(t.Stats) == "table" then
        absorbQuick(info, t.Stats)
    end
    if t.Properties and type(t.Properties) == "table" then
        absorbQuick(info, t.Properties)
    end
end

-- UPDATED: New decoder for RE/ObtainedNewFishNotification with proper tier handling
local function decode_RE_ObtainedNewFishNotification(packed)
    local info = {}
    
    if CONFIG.DEBUG then
        log("=== DECODING ObtainedNewFishNotification ===")
        log("Total args:", packed.n or #packed)
        for i = 1, math.min(packed.n or #packed, 6) do
            if packed[i] then
                log("  arg[" .. i .. "]:", type(packed[i]))
                if type(packed[i]) == "table" then
                    -- Log important fields for debugging
                    for k, v in pairs(packed[i]) do
                        if type(k) == "string" and (
                            k:lower():find("tier") or 
                            k:lower():find("rarity") or 
                            k:lower():find("id") or 
                            k:lower():find("name") or
                            k:lower():find("type") or
                            k:lower():find("itemid")
                        ) then
                            log("    [" .. tostring(k) .. "] = " .. tostring(v))
                        end
                    end
                end
            end
        end
    end
    
    -- Process each argument
    for i = 1, packed.n or #packed do
        local arg = packed[i]
        if type(arg) == "table" then
            absorbQuick(info, arg)
        elseif type(arg) == "number" or type(arg) == "string" then
            if not info.id then
                info.id = toIdStr(arg)
            end
        elseif typeof(arg) == "Instance" then
            absorbQuick(info, toAttrMap(arg))
        end
    end
    
    -- CRITICAL: Get fish data from ModuleScript using the ID
    if info.id then
        local meta = ensureMetaById(toIdStr(info.id))
        if meta then
            info.name = info.name or meta.name
            info.icon = info.icon or meta.icon
            info.desc = info.desc or meta.desc
            
            -- IMPORTANT: Use tier from fish ModuleScript, not from event
            -- Event might not have tier, but ModuleScript always has correct tier
            info.tier = meta.tier
            info.tierName = meta.tierName
            info.chance = info.chance or meta.chance
            
            if CONFIG.DEBUG then
                log("Found fish module for ID", info.id)
                log("  ModuleScript tier:", meta.tier)
                log("  Tier name:", meta.tierName)
                log("  Fish name:", meta.name)
            end
        else
            if CONFIG.DEBUG then
                log("WARNING: No ModuleScript found for fish ID:", info.id)
            end
        end
    end
    
    -- Fallback name lookup
    local idS = info.id and toIdStr(info.id)
    if idS and not info.name and CONFIG.ID_NAME_MAP[idS] then
        info.name = CONFIG.ID_NAME_MAP[idS]
    end
    
    if CONFIG.DEBUG then
        log("=== DECODED RESULT ===")
        log("Name:", info.name or "Unknown")
        log("ID:", info.id or "?")
        log("Tier (final):", info.tier or "?")
        log("Tier Name (final):", info.tierName or getTierName(info.tier))
        log("Weight:", info.weight or "?")
        log("Shiny:", info.shiny or false)
        log("VariantId:", info.variantId or "none")
        log("=======================")
    end
    
    return next(info) and info or nil
end

-- Keep old decoder as fallback
local function decode_RE_FishCaught(packed)
    local info = {}
    local a1, a2 = packed[1], packed[2]
    
    if type(a1) == "table" then
        absorbQuick(info, a1)
        if type(a2) == "table" then absorbQuick(info, a2) end
    elseif typeof(a1) == "number" or typeof(a1) == "string" then
        info.id = toIdStr(a1)
        if type(a2) == "table" then absorbQuick(info, a2) end
    elseif typeof(a1) == "Instance" then
        absorbQuick(info, toAttrMap(a1))
        if type(a2) == "table" then absorbQuick(info, a2) end
    end
    
    if info.id then
        local meta = ensureMetaById(toIdStr(info.id))
        if meta then
            info.name = info.name or meta.name
            info.tier = info.tier or meta.tier
            info.chance = info.chance or meta.chance
            info.icon = info.icon or meta.icon
        end
    end
    
    local idS = info.id and toIdStr(info.id)
    if idS and not info.name and CONFIG.ID_NAME_MAP[idS] then
        info.name = CONFIG.ID_NAME_MAP[idS]
    end
    
    return next(info) and info or nil
end

-- UPDATED: Universal decoder that handles both event types
local function decodeInboundEvent(eventName, packed)
    if eventName == "RE/ObtainedNewFishNotification" then
        return decode_RE_ObtainedNewFishNotification(packed)
    elseif eventName == "RE/FishCaught" then
        return decode_RE_FishCaught(packed)
    else
        -- Try both decoders for unknown events
        local info = decode_RE_ObtainedNewFishNotification(packed)
        if not info then
            info = decode_RE_FishCaught(packed)
        end
        return info
    end
end

-- ===========================
-- FORMATTING FUNCTIONS
-- ===========================
local function parseChanceToProb(ch)
    local n = tonumber(ch)
    if not n or n <= 0 then return nil end
    if n > 1 then return n / 100.0 else return n end
end

local function fmtChanceOneInFromNumber(ch)
    local p = parseChanceToProb(ch)
    if not p or p <= 0 then return "Unknown" end
    local oneIn = math.max(1, math.floor((1 / p) + 0.5))
    return string.format("1 in %d", oneIn)
end

local function toKg(w)
    local n = tonumber(w)
    if not n then return (w and tostring(w)) or "Unknown" end
    return string.format("%0." .. tostring(CONFIG.WEIGHT_DECIMALS) .. "f kg", n)
end

-- ===========================
-- TIER DATA FUNCTIONS (NEW)
-- ===========================
local function loadTiersData()
    if tiersData then return tiersData end
    
    local tiersModule = ReplicatedStorage:FindFirstChild("Tiers")
    if not tiersModule or not tiersModule:IsA("ModuleScript") then
        log("Tiers module not found at ReplicatedStorage.Tiers")
        return nil
    end
    
    local ok, data = pcall(require, tiersModule)
    if not ok or type(data) ~= "table" then
        log("Failed to load Tiers module:", tostring(data))
        return nil
    end
    
    tiersData = data
    
    -- Build lookup tables for fast access
    safeClear(tiersByNumber)
    safeClear(tiersByName)
    
    for _, tierInfo in ipairs(data) do
        if tierInfo.Tier and tierInfo.Name then
            tiersByNumber[tierInfo.Tier] = tierInfo
            tiersByName[tierInfo.Name:lower()] = tierInfo
        end
    end
    
    if CONFIG.DEBUG then
        log("Loaded", #data, "tier definitions")
        for tier, info in pairs(tiersByNumber) do
            log("  Tier", tier, "=", info.Name, "(Rarity:", info.Rarity, ")")
        end
    end
    
    return tiersData
end

local function getTierInfo(tierInput)
    loadTiersData()
    if not tiersData then return nil end
    
    -- Try by tier number first
    if type(tierInput) == "number" then
        return tiersByNumber[tierInput]
    end
    
    -- Try by tier name
    if type(tierInput) == "string" then
        return tiersByName[tierInput:lower()]
    end
    
    return nil
end

local function getTierName(tier)
    local tierInfo = getTierInfo(tier)
    if tierInfo then
        return tierInfo.Name
    end
    
    -- Fallback to original mapping
    if not tier then return "Unknown" end
    
    -- Try direct lookup from old mapping
    local mapped = TIER_NAME_MAP[tier]
    if mapped then return mapped end
    
    -- If tier is a string, capitalize first letter
    if type(tier) == "string" then
        return tier:sub(1,1):upper() .. tier:sub(2):lower()
    end
    
    return tostring(tier)
end

local function getTierRarity(tier)
    local tierInfo = getTierInfo(tier)
    return tierInfo and tierInfo.Rarity or nil
end

local function getTierColor(tier)
    local tierInfo = getTierInfo(tier)
    return tierInfo and tierInfo.TierColor or nil
end

local function formatMutations(mut)
    if type(mut) == "table" then
        local t = {}
        for k, v in pairs(mut) do
            if type(v) == "boolean" and v then
                table.insert(t, tostring(k))
            elseif v ~= nil and v ~= false then
                table.insert(t, tostring(k) .. ":" .. tostring(v))
            end
        end
        return (#t > 0) and table.concat(t, ", ") or "None"
    elseif mut ~= nil then
        return tostring(mut)
    end
    return "None"
end

-- UPDATED: Format variant information
local function formatVariant(info)
    local parts = {}
    if info.variantId and info.variantId ~= "" then
        table.insert(parts, "Variant: " .. tostring(info.variantId))
    end
    if info.variantSeed then
        table.insert(parts, "Seed: " .. tostring(info.variantSeed))
    end
    if info.shiny then
        table.insert(parts, "✨ SHINY")
    end
    return (#parts > 0) and table.concat(parts, " | ") or "None"
end

-- ===========================
-- DEDUPLICATION FUNCTIONS
-- ===========================
local function roundWeight(w)
    local n = tonumber(w)
    if not n then return "?" end
    local fmt = "%0." .. tostring(CONFIG.WEIGHT_DECIMALS) .. "f"
    return string.format(fmt, n)
end

local function sigFromInfo(info)
    local id = info.id and tostring(info.id) or "?"
    local wt = roundWeight(info.weight)
    local tier = tostring(info.tier or "?")
    local ch = tostring(info.chance or "?")
    local variant = tostring(info.variantId or "")
    local shiny = tostring(info.shiny or false)
    local uuid = tostring(info.uuid or "")
    
    local mut = ""
    if type(info.mutations) == "table" then
        local keys = {}
        for k in pairs(info.mutations) do
            table.insert(keys, tostring(k))
        end
        table.sort(keys)
        
        local parts = {}
        for _, k in ipairs(keys) do
            table.insert(parts, k .. "=" .. tostring(info.mutations[k]))
        end
        mut = table.concat(parts, "&")
    else
        mut = tostring(info.mutation or "")
    end
    
    return table.concat({id, wt, tier, ch, variant, shiny, uuid, mut}, "|")
end

local function shouldSend(sig)
    -- Purge old entries
    local t = now()
    for k, ts in pairs(sentCache) do
        if (t - ts) > CONFIG.DEDUP_TTL_SEC then
            sentCache[k] = nil
        end
    end
    
    if sentCache[sig] then return false end
    sentCache[sig] = t
    return true
end

-- ===========================
-- FISH FILTER FUNCTIONS
-- ===========================
local function shouldSendFish(info)
    -- Check if fish type is selected for webhook
    if not info.name then return false end
    
    -- If no fish types selected, send all
    if not selectedFishTypes or next(selectedFishTypes) == nil then
        return true
    end
    
    -- Check if fish name or tier matches selected types
    for selectedType, _ in pairs(selectedFishTypes) do
        if info.name:lower():find(selectedType:lower()) or 
           getTierName(info.tier):lower() == selectedType:lower() then
            return true
        end
    end
    
    return false
end

-- ===========================
-- WEBHOOK SENDING FUNCTION (UPDATED)
-- ===========================
local function sendEmbed(info, origin)
    -- Soft debounce for burst spam with different signatures
    if now() - debounceSend < 0.15 then return end
    debounceSend = now()
    
    -- Check if we should send this fish
    if not shouldSendFish(info) then
        log("Fish not in selected types, skipping:", info.name or "Unknown")
        return
    end
    
    local sig = sigFromInfo(info)
    if not shouldSend(sig) then
        log("Dedup suppress for sig:", sig)
        return
    end
    
    local fishName = info.name or "Unknown Fish"
    if fishName == "Unknown Fish" and info.id and metaById[toIdStr(info.id)] and metaById[toIdStr(info.id)].name then
        fishName = metaById[toIdStr(info.id)].name
    end
    
    local imageUrl = nil
    if info.icon then
        imageUrl = resolveIconUrl(info.icon)
    elseif info.id and metaById[toIdStr(info.id)] and metaById[toIdStr(info.id)].icon then
        imageUrl = resolveIconUrl(metaById[toIdStr(info.id)].icon)
    end

    -- Fallback: use assetId directly
    if not imageUrl and info.id then
        imageUrl = resolveIconUrl(info.id)
    end
    
    if CONFIG.DEBUG then 
        log("Image URL:", tostring(imageUrl)) 
    end

    -- Create "box" formatting for Discord embed (inline code)
    local function box(v)
        v = v == nil and "Unknown" or tostring(v)
        v = v:gsub("`", "ˋ") -- Replace backticks to avoid breaking formatting
        return string.format("`%s`", v)
    end

    -- UPDATED: Enhanced embed with proper tier handling
    local embed = {
        title = (info.shiny and "✨ SHINY ✨ " or "🎣 ") .. "New Catch: " .. fishName,
        description = string.format("**Player:** %s\n**Origin:** %s", LocalPlayer.Name, origin or "unknown"),
        color = info.shiny and 0xFFD700 or 0x87CEEB, -- Gold for shiny, light blue for normal
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = { text = ".devlogic Fish Notifier v2.1" },
        fields = {
            { name = "Fish Name 🐟",   value = box(fishName),                              inline = false },
            { name = "⚖️ Weight",      value = box(toKg(info.weight)),                     inline = true  },
            { name = "🎲 Chance",       value = box(fmtChanceOneInFromNumber(info.chance)), inline = true  },
            { name = "💎 Rarity",       value = box(info.tierName or getTierName(info.tier)), inline = true  },
            { name = "🧬 Mutation(s)",  value = box(formatMutations(info.mutations or info.mutation)), inline = false },
            { name = "🎨 Variant",      value = box(formatVariant(info)),                   inline = false },
            { name = "Fish ID",         value = box(info.id and tostring(info.id) or "Unknown"),       inline = true  },
        }
    }

    -- Add UUID field if available
    if info.uuid and info.uuid ~= "" then
        table.insert(embed.fields, { name = "🆔 UUID", value = box(info.uuid), inline = true })
    end
    
    if imageUrl then
        if CONFIG.USE_LARGE_IMAGE then
            embed.image = {url = imageUrl}
        else
            embed.thumbnail = {url = imageUrl}
        end
    end
    
    sendWebhook({ 
        username = ".devlogic Fish Notifier v2", 
        embeds = {embed} 
    })
    
    -- Clean up to prevent resend from late callbacks
    safeClear(lastInbound)
    safeClear(recentAdds)
    rareWatchUntil = 0
end

-- ===========================
-- CORE CORRELATION FUNCTION (UPDATED)
-- ===========================
local function onCatchWindow()
    if onCatchWindowBusy then return end
    onCatchWindowBusy = true
    
    local function finally()
        onCatchWindowBusy = false
    end
    
    -- Try latest event in quick window
    for i = #lastInbound, 1, -1 do
        local hit = lastInbound[i]
        if now() - hit.t <= CONFIG.CATCH_WINDOW_SEC then
            local info = decodeInboundEvent(hit.name, hit.args)
            if info and (info.id or info.name) then
                sendEmbed(info, "OnClientEvent:" .. hit.name)
                finally()
                return
            end
        end
    end
    
    -- Rare watch active?
    if now() <= rareWatchUntil then
        -- Try older events in rare window
        for i = #lastInbound, 1, -1 do
            local hit = lastInbound[i]
            if now() - hit.t <= CONFIG.RARE_WINDOW_SEC then
                local info = decodeInboundEvent(hit.name, hit.args)
                if info and (info.id or info.name) then
                    sendEmbed(info, "OnClientEvent(RARE):" .. hit.name)
                    finally()
                    return
                end
            else
                break
            end
        end
        
        -- Correlate with Backpack adds in rare window
        for inst, ts in pairs(recentAdds) do
            if inst.Parent == Backpack and now() - ts <= CONFIG.RARE_WINDOW_SEC then
                local a = toAttrMap(inst)
                local id = a.Id or a.ItemId or a.TypeId or a.FishId
                local meta = id and ensureMetaById(toIdStr(id)) or nil
                if meta then
                    sendEmbed({
                        id = id,
                        name = meta.name,
                        tier = meta.tier,
                        chance = meta.chance,
                        icon = meta.icon,
                        weight = a.Weight or a.Mass,
                        mutations = a.Mutations or a.Mutation,
                        variantId = a.VariantId,
                        variantSeed = a.VariantSeed,
                        shiny = a.Shiny,
                        uuid = a.UUID
                    }, "Backpack(RARE):" .. inst.Name)
                    finally()
                    return
                end
            end
        end
    end
    
    if CONFIG.DEBUG then
        log("No info in window; skipped")
    end
    
    finally()
end

-- ===========================
-- CONNECTION FUNCTIONS
-- ===========================
local function wantByName(nm)
    local n = string.lower(nm)
    for _, ex in ipairs(CONFIG.INBOUND_EVENTS) do
        if string.lower(ex) == n then return true end
    end
    for _, pat in ipairs(CONFIG.INBOUND_PATTERNS or {}) do
        if n:find(pat, 1, true) then return true end
    end
    return false
end

local function connectInbound()
    local ge = ReplicatedStorage
    
    local function maybeConnect(d)
        if d:IsA("RemoteEvent") and wantByName(d.Name) then
            table.insert(connections, d.OnClientEvent:Connect(function(...)
                local packed = table.pack(...)
                table.insert(lastInbound, {t = now(), name = d.Name, args = packed})
                if CONFIG.DEBUG then
                    log("Inbound:", d.Name, "argc=", packed.n or 0)
                end
                task.defer(onCatchWindow)
            end))
            log("Hooked:", d:GetFullName())
        end
    end
    
    for _, d in ipairs(ge:GetDescendants()) do
        maybeConnect(d)
    end
    
    table.insert(connections, ge.DescendantAdded:Connect(maybeConnect))
end

local function connectLeaderstatsTrigger()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return end
    
    local Caught = ls:FindFirstChild("Caught")
    local Data = Caught and (Caught:FindFirstChild("Data") or Caught)
    
    if Data and Data:IsA("ValueBase") then
        table.insert(connections, Data.Changed:Connect(function()
            rareWatchUntil = now() + CONFIG.RARE_WINDOW_SEC
            if CONFIG.DEBUG then
                log("leaderstats trigger; rare-watch until +", CONFIG.RARE_WINDOW_SEC .. "s")
            end
            task.defer(onCatchWindow)
        end))
    end
end

local function connectBackpackLight()
    table.insert(connections, Backpack.ChildAdded:Connect(function(inst)
        recentAdds[inst] = now()
        if CONFIG.DEBUG then
            log("Backpack +", inst.Name)
        end
    end))
    
    table.insert(connections, Backpack.ChildRemoved:Connect(function(inst)
        recentAdds[inst] = nil
    end))
end

-- ===========================
-- MAIN FEATURE FUNCTIONS
-- ===========================
function FishWebhookFeature:Init(guiControls)
    controls = guiControls or {}
    
    detectItemsRoot()
    buildLightIndex()
    
    print("[FishWebhook] Initialized with new detector (RE/ObtainedNewFishNotification)")
    return true
end

function FishWebhookFeature:Start(config)
    if isRunning then return end
    
    webhookUrl = config.webhookUrl or ""
    selectedFishTypes = config.selectedFishTypes or {}
    
    if not webhookUrl or webhookUrl == "" then
        warn("[FishWebhook] Cannot start - webhook URL not set")
        return false
    end
    
    isRunning = true
    
    connectInbound()
    connectLeaderstatsTrigger()
    connectBackpackLight()
    
    print("[FishWebhook] Started with URL:", webhookUrl:sub(1, 50) .. "...")
    print("[FishWebhook] Selected fish types:", HttpService:JSONEncode(selectedFishTypes))
    print("[FishWebhook] Using detector: RE/ObtainedNewFishNotification")
    
    return true
end

function FishWebhookFeature:Stop()
    if not isRunning then return end
    
    isRunning = false
    
    -- Disconnect all connections
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    
    -- Clear state
    safeClear(lastInbound)
    safeClear(recentAdds)
    rareWatchUntil = 0
    
    print("[FishWebhook] Stopped")
end

function FishWebhookFeature:SetWebhookUrl(url)
    webhookUrl = url or ""
    log("Webhook URL updated")
end

function FishWebhookFeature:SetSelectedFishTypes(fishTypes)
    selectedFishTypes = fishTypes or {}
    log("Selected fish types updated:", HttpService:JSONEncode(selectedFishTypes))
end

function FishWebhookFeature:TestWebhook(message)
    if not webhookUrl or webhookUrl == "" then
        warn("[FishWebhook] Cannot test - webhook URL not set")
        return false
    end
    
    sendWebhook({ 
        username = ".devlogic Fish Notifier v2", 
        content = message or "🐟 Webhook test from Fish-It script (Updated Detector)" 
    })
    return true
end

function FishWebhookFeature:GetStatus()
    return {
        running = isRunning,
        webhookUrl = webhookUrl ~= "" and (webhookUrl:sub(1, 50) .. "...") or "Not set",
        selectedFishTypes = selectedFishTypes,
        connectionsCount = #connections,
        lastInboundCount = #lastInbound,
        recentAddsCount = next(recentAdds) and 1 or 0,
        detector = "RE/ObtainedNewFishNotification"
    }
end

function FishWebhookFeature:Cleanup()
    print("[FishWebhook] Cleaning up...")
    self:Stop()
    controls = {}
    
    -- Clear all caches
    safeClear(moduleById)
    safeClear(metaById)
    safeClear(scannedSet)
    safeClear(thumbCache)
    safeClear(sentCache)
end

-- ===========================
-- DEBUG FUNCTIONS (ENHANCED)
-- ===========================
function FishWebhookFeature:EnableInboundDebug()
    CONFIG.DEBUG = true
    log("Inbound debugging enabled")
end

function FishWebhookFeature:DisableInboundDebug()
    CONFIG.DEBUG = false
end

function FishWebhookFeature:GetLastInbound()
    return lastInbound
end

function FishWebhookFeature:SimulateFishCatch(testData)
    -- For testing purposes - simulate a fish catch event
    testData = testData or {
        id = "69",
        name = "Test Fish",
        weight = 1.27,
        tier = 5,
        chance = 0.001,
        shiny = true,
        variantId = "Galaxy",
        variantSeed = 1757126016
    }
    
    sendEmbed(testData, "SIMULATED_TEST")
end

-- NEW: Debug tier detection specifically
function FishWebhookFeature:DebugTierDetection()
    log("=== LOADING TIERS MODULE ===")
    local tiers = loadTiersData()
    if not tiers then
        log("ERROR: Could not load tiers data!")
        return
    end
    
    log("=== TIER MAPPING DEBUG ===")
    for tier, info in pairs(tiersByNumber) do
        log("Tier", tier, "->", info.Name, "(Rarity:", info.Rarity, ")")
    end
    log("==========================")
    
    log("=== OLD TIER NAME TESTS ===")
    for k, v in pairs(TIER_NAME_MAP) do
        log("Old mapping:", tostring(k), "->", tostring(v))
    end
    
    -- Test common tier values
    local testTiers = {1, 2, 3, 4, 5, 6, 7, "Common", "Legendary", "Mythic", "SECRET"}
    log("=== TIER NAME TESTS ===")
    for _, tier in ipairs(testTiers) do
        log("Input:", tostring(tier), "-> Output:", getTierName(tier))
    end
    log("=======================")
end

-- NEW: Test specific fish ID
function FishWebhookFeature:TestFishId(fishId)
    if not fishId then
        log("Usage: TestFishId(69) -- where 69 is fish ID")
        return
    end
    
    log("=== TESTING FISH ID", fishId, "===")
    local meta = ensureMetaById(toIdStr(fishId))
    if meta then
        log("Fish found!")
        log("  Name:", meta.name)
        log("  Tier:", meta.tier)
        log("  Tier Name:", meta.tierName)
        log("  Chance:", meta.chance)
        log("  Icon:", meta.icon)
    else
        log("Fish ID", fishId, "not found in modules")
    end
    log("========================")
end

-- NEW: Monitor and log all incoming fish data for analysis
function FishWebhookFeature:StartTierAnalysis()
    CONFIG.DEBUG = true
    log("Started tier analysis mode - all fish data will be logged")
end

return FishWebhookFeature