-- ===========================
-- AUTO SEND TRADE FEATURE
-- File: autosendtradeFeature.lua
-- ===========================

--[[  Wiring yang disiapkan GUI:
    - Multi dropdown Rarity (list string)
    - Multi dropdown Enchant Stone (list string, dari Items)
    - Button "Refresh Player List" -> panggil autosendtradeFeature.RefreshPlayers()
    - Toggle aktif/nonaktif -> autosendtradeFeature.SetActive(true/false)
    - (Opsional) Dropdown single target player -> autosendtradeFeature.SetTargetByUserId(userId)
]]

local autosendtradeFeature = {}
autosendtradeFeature.__index = autosendtradeFeature

-- ======= Services =======
local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local RunService           = game:GetService("RunService")
local LocalPlayer          = Players.LocalPlayer

-- ======= Config =======
local TICK_STEP        = 0.25         -- throttle loop
local TRADE_COOLDOWN   = 1.0          -- minimal jeda antar request
local PROPAGATE_DELAY  = 0.35         -- kasih waktu state inventory/notif nyusul

-- ======= Net Path (sleitnick_net) =======
local Net
do
    -- Robust ke perbedaan _Index key
    local Packages = ReplicatedStorage:FindFirstChild("Packages")
    if Packages and Packages:FindFirstChild("_Index") then
        local idx = Packages._Index
        for _, child in ipairs(idx:GetChildren()) do
            if child.Name:match("sleitnick_net") then
                local mod = child:FindFirstChild("net")
                if mod then Net = mod break end
            end
        end
    end
end

if not Net then
    warn("[autosendtrade] sleitnick_net not found; pastikan path benar.")
end

local RF_InitiateTrade = Net and Net:FindFirstChild("RF/InitiateTrade")
local RE_TextNotification = Net and Net:FindFirstChild("RE/TextNotification")

-- ======= Inventory Accessor (samain dgn autofavoritefish) =======
-- Harap sudah ada inventoryWatcher:getSnapshotTyped("Fishes"|"Items")
-- Jika belum, kamu bisa adapt ke sistemmu sendiri.
local inventoryWatcher = _G.inventoryWatcher  -- pakai global yang sama seperti modul lain (optional)

-- ======= State =======
local running           = false
local selectedTargetId  = nil              -- number (UserId)
local selectedRarities  = {}               -- set[string] -> true
local selectedStones    = {}               -- set[string] -> true (by item Name)
local lastTick          = 0
local lastTradeTime     = 0
local tradeInFlight     = false            -- untuk hold sebentar setelah Invoke
local tradeQueue        = {}               -- FIFO of UUIDs to send
local queuedOrSent      = {}               -- [uuid] = true (anti duplikat)
local connections       = {}

-- ======= Utils =======
local function now()
    return tick()
end

local function toSet(list)
    local t = {}
    for _, v in ipairs(list or {}) do
        if typeof(v) == "string" or typeof(v) == "number" then
            t[tostring(v)] = true
        end
    end
    return t
end

local function getUUID(entry)
    return entry.UUID or entry.Uuid or entry.uuid
end

local function isFavorited(entry)
    if entry.Favorited ~= nil then return entry.Favorited end
    if entry.favorited ~= nil then return entry.favorited end
    if entry.Metadata and entry.Metadata.Favorited ~= nil then return entry.Metadata.Favorited end
    if entry.Metadata and entry.Metadata.favorited ~= nil then return entry.Metadata.favorited end
    return false
end

local function getRarity(entry)
    -- normalisasi field rarity/tier
    return tostring(
        entry.Rarity or entry.rarity or entry.Tier or entry.tier or
        (entry.Metadata and (entry.Metadata.Rarity or entry.Metadata.Tier)) or
        ""
    )
end

local function getName(entry)
    return tostring(entry.Name or entry.name or entry.Id or entry.id or "")
end

local function pushQueue(uuid)
    if not uuid or uuid == "" then return end
    if queuedOrSent[uuid] then return end
    table.insert(tradeQueue, uuid)
    queuedOrSent[uuid] = true
end

local function popQueue()
    if #tradeQueue == 0 then return nil end
    local uuid = table.remove(tradeQueue, 1)
    return uuid
end

local function inCooldown()
    return (now() - lastTradeTime) < TRADE_COOLDOWN
end

local function clearConnections()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(connections)
end

-- Bersihkan UUID yang sudah tidak ada di inventory (hindari stuck)
local function pruneQueueWithSnapshot(allUUIDsSet)
    -- bersihkan queuedOrSent dan tradeQueue jika itemnya sudah hilang (berhasil terkirim/terhapus)
    local newQueue = {}
    for _, uuid in ipairs(tradeQueue) do
        if allUUIDsSet[uuid] then
            table.insert(newQueue, uuid)
        else
            queuedOrSent[uuid] = nil
        end
    end
    tradeQueue = newQueue
end

-- ======= Core Collector =======
local function collectCandidates()
    if not inventoryWatcher then return end

    local fishes = inventoryWatcher:getSnapshotTyped("Fishes")
    local items  = inventoryWatcher:getSnapshotTyped("Items")

    local allUUIDsSet = {}

    -- Fishes -> filter by rarity + safety: skip favorited
    if fishes then
        for _, fish in ipairs(fishes) do
            local uuid = getUUID(fish)
            if uuid then allUUIDsSet[uuid] = true end

            local rarity = getRarity(fish)
            if uuid and not isFavorited(fish) and selectedRarities[rarity] then
                pushQueue(uuid)
            end
        end
    end

    -- Items -> filter by name in selectedStones
    if items then
        for _, itm in ipairs(items) do
            local uuid = getUUID(itm)
            if uuid then allUUIDsSet[uuid] = true end

            local name = getName(itm)
            if uuid and selectedStones[name] then
                pushQueue(uuid)
            end
        end
    end

    -- buang UUID yang sudah ga ada
    pruneQueueWithSnapshot(allUUIDsSet)
end

-- ======= Trade Sender =======
local function sendOne()
    if not running or not selectedTargetId then return end
    if tradeInFlight or inCooldown() then return end
    if not RF_InitiateTrade then return end
    local uuid = popQueue()
    if not uuid then return end

    -- kirim trade
    local ok, err = pcall(function()
        RF_InitiateTrade:InvokeServer(tonumber(selectedTargetId), tostring(uuid))
    end)

    if not ok then
        warn("[autosendtrade] InitiateTrade error:", err)
        -- biarkan entry keluar dari queue, tapi tandai supaya bisa dikumpulkan lagi di scan berikutnya
        queuedOrSent[uuid] = nil
        return
    end

    tradeInFlight = true
    lastTradeTime = now()

    -- fallback: kalau notifikasi gak datang, lepas inFlight setelah PROPAGATE_DELAY
    task.delay(PROPAGATE_DELAY, function()
        tradeInFlight = false
    end)
end

-- ======= Notifications Listener =======
local function hookNotifications()
    if not RE_TextNotification then return end
    local conn = RE_TextNotification.OnClientEvent:Connect(function(payload)
        -- payload contoh:
        -- { Type="Text", Text="Sent trade request!", CustomDuration=3, TextColor={R=0,G=255,B=0} }
        local text = (typeof(payload) == "table" and payload.Text) and tostring(payload.Text) or ""
        if text:find("Sent trade request!", 1, true) then
            -- kita sudah handle cooldown, tapi boleh log
            -- print("[autosendtrade] sent request ack")
            -- keep tradeInFlight false; next tick boleh lanjut
            tradeInFlight = false
        elseif text:find("Trade completed!", 1, true) then
            -- print("[autosendtrade] trade completed")
            -- No special action needed; inventoryWatcher rescan akan merapikan queue
        end
    end)
    table.insert(connections, conn)
end

-- ======= Main Loop =======
local function loop()
    if not running then return end
    local t = now()
    if (t - lastTick) < TICK_STEP then return end
    lastTick = t

    collectCandidates()
    sendOne()
end

-- ======= Public API (buat wiring GUI) =======
function autosendtradeFeature.SetActive(state)
    running = state and true or false
    if running then
        -- start loop & hook notif
        clearConnections()
        if RE_TextNotification then
            hookNotifications()
        end
        local hb = RunService.Heartbeat:Connect(loop)
        table.insert(connections, hb)
    else
        clearConnections()
        table.clear(tradeQueue)
        table.clear(queuedOrSent)
        tradeInFlight = false
    end
end

local function resolveUserId(target)
    -- Bisa: number (UserId) atau string (Name)
    if target == nil then return nil end
    if typeof(target) == "number" then
        return target > 0 and target or nil
    end
    if typeof(target) == "string" then
        local want = target:lower()
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == want then
                return p.UserId
            end
        end
        -- optional: fallback case-insensitive partial match (matikan kalau anti-ambigu)
        -- for _, p in ipairs(Players:GetPlayers()) do
        --     if p.Name:lower():find(want, 1, true) then
        --         return p.UserId
        --     end
        -- end
    end
    return nil
end

function autosendtradeFeature.SetTarget(target)
    local uid = resolveUserId(target)
    if uid then
        selectedTargetId = uid
        -- print("[autosendtrade] target set:", target, "->", uid)
    else
        selectedTargetId = nil
        warn("[autosendtrade] target not found for:", target)
    end
end

-- listOfStrings: {"Common","Rare",...} (samain dgn value di dropdown)
function autosendtradeFeature.SetSelectedRarities(listOfStrings)
    selectedRarities = toSet(listOfStrings)
    -- reset queue supaya pakai kriteria baru
    table.clear(tradeQueue)
    table.clear(queuedOrSent)
end

-- listOfStrings: {"Enchant Stone I","Enchant Stone II",...} (samain nama yang tampil di inventory Items)
function autosendtradeFeature.SetSelectedStones(listOfStrings)
    selectedStones = toSet(listOfStrings)
    table.clear(tradeQueue)
    table.clear(queuedOrSent)
end

-- Panggil dari tombol "Refresh Player List"
-- return: array { {text=DisplayName .. "(@"..Name..")", value=UserId}, ... }
function autosendtradeFeature.RefreshPlayers()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local label = string.format("%s (@%s)", p.DisplayName or p.Name, p.Name)
            table.insert(out, { text = label, value = p.UserId })
        end
    end
    -- Kamu bisa assign hasil ini ke dropdown kamu (non-multi) untuk target
    return out
end

-- Opsional, kalau kamu mau trigger rescan manual (misal abis ganti pilihan dropdown)
function autosendtradeFeature.ForceRescan()
    collectCandidates()
end

return autosendtradeFeature
