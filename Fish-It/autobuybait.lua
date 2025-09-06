-- Fish-It Feature: AutoBuy Bait (one-shot, no delay/jitter/maxspend)
-- Lifecycle: :Init(gui?), :Start(config?), :Stop(), :Cleanup()
-- Setters: :SetSelectedBaitsByName(listOrSet), :SetSelectedBaitsById(listOrArray)
-- Utils: :GetCatalogRows(), :RefreshCatalog(), :GetLogSignal()
-- Patuh kontrak standarfiturscript (lifecycle, setters, config fleksibel, no popup)

local AutoBuybBaitFeature = {}
AutoBuyBaitFeature.__index = AutoBuyBaitFeature

-- Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- ========= State =========
local running = false
local logEvent = Instance.new("BindableEvent")

local opts = {
    SafeRequire = true,
    ListOnInit  = false,
}

local purchaseRF = nil

-- Catalog
local byId, byName = {}, {}
local rows = {}  -- { {Id,Name,Tier,Price}, ... }

-- Selection (set: id->true)
local selectedIds = {}

-- ========= Utils =========
local function log(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(tostring(fmt), ...) or tostring(fmt)
    if logEvent then logEvent:Fire(msg) end
    print("[autobuybait] " .. msg)
end

local function scanDescendantsForRF()
    -- cari RemoteFunction bernama "RF/PurchaseBait" di seluruh RS
    for _, inst in ipairs(RS:GetDescendants()) do
        if inst.ClassName == "RemoteFunction" and inst.Name == "RF/PurchaseBait" then
            return inst
        end
    end
    -- fallback ke Packages/_Index/*/net/RF/PurchaseBait
    local ok, rf = pcall(function()
        local Packages = RS:FindFirstChild("Packages")
        if not Packages then return nil end
        local _Index = Packages:FindFirstChild("_Index")
        if not _Index then return nil end
        for _, folder in ipairs(_Index:GetChildren()) do
            local net = folder:FindFirstChild("net", true)
            if net then
                local cand = net:FindFirstChild("RF/PurchaseBait")
                if cand and cand.ClassName == "RemoteFunction" then
                    return cand
                end
            end
        end
        return nil
    end)
    if ok and rf then return rf end
    return nil
end

local function addRowFromModule(mod)
    local ok, data
    if opts.SafeRequire then
        ok, data = pcall(require, mod)
    else
        ok, data = true, require(mod)
    end
    if not ok or typeof(data) ~= "table" then return end
    local d = data.Data or {}
    local id = d.Id or data.Id
    local name = d.Name or data.Name or mod.Name
    local tier = d.Tier or data.Tier
    local price = data.Price
    if typeof(id) == "number" and name and typeof(price) == "number" then
        byId[id] = { Id=id, Name=name, Tier=tier, Price=price, Module=mod, Raw=data }
        byName[string.lower(name)] = byId[id]
        table.insert(rows, { Id=id, Name=name, Tier=tier, Price=price })
    end
end

local function buildCatalogRecursive()
    table.clear(byId); table.clear(byName); table.clear(rows)
    local root = RS:FindFirstChild("Baits")
    if not root then
        warn("[autobuybait] ReplicatedStorage.Baits tidak ditemukan")
        return
    end
    -- dukung struktur bersarang: ambil semua ModuleScript di bawah Baits
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("ModuleScript") then
            addRowFromModule(inst)
        end
    end
    table.sort(rows, function(a,b)
        if (a.Tier or 0) == (b.Tier or 0) then return a.Id < b.Id end
        return (a.Tier or 0) < (b.Tier or 0)
    end)
end

-- ========= Lifecycle (SPEC) =========
function AutoBuyBaitFeature:Init(guiControls)
    -- guiControls boleh dipakai untuk pre-populate dropdown, tapi opsional
    purchaseRF = scanDescendantsForRF()
    if not purchaseRF then
        warn("[autobuybait] RemoteFunction 'RF/PurchaseBait' tidak ditemukan.")
        -- tetap return true; GUI bisa menampilkan warning dan coba lagi nanti
    end

    buildCatalogRecursive()
    if opts.ListOnInit then
        log("Baits terdeteksi: %d", #rows)
        for _, r in ipairs(rows) do
            log("  #%d  %-22s  Tier:%s  Price:%s", r.Id, r.Name, tostring(r.Tier), tostring(r.Price))
        end
    end

    -- Contoh: pre-populate dropdown kalau disediakan
    -- if guiControls and guiControls.dropdown then guiControls.dropdown:Reload(mapNames) end

    return true
end

function AutoBuyBaitFeature:Start(config)
    if running then return end
    -- config override (khusus fitur); abaikan kunci tak dikenal
    if typeof(config) == "table" then
        if config.baitNames then self:SetSelectedBaitsByName(config.baitNames) end
        if config.baitIds   then self:SetSelectedBaitsById(config.baitIds)   end
    end

    if not next(selectedIds) then
        log("Tidak ada bait yang dipilih. Set lewat setter atau config.")
        return
    end
    if not purchaseRF then
        log("Tidak bisa start: RF/PurchaseBait tidak ditemukan.")
        return
    end

    running = true
    -- one-shot synchronous: beli sekali per bait yang dipilih (berurutan, non-paralel)
    local ids = {}
    for id in pairs(selectedIds) do table.insert(ids, id) end
    table.sort(ids)

    local tried, success = 0, 0
    for _, id in ipairs(ids) do
        if not running then break end
        local row = byId[id]
        if row then
            tried += 1
            log("Beli #%d (%s)", row.Id, row.Name)
            local ok, res = pcall(function()
                return purchaseRF:InvokeServer(row.Id)
            end)
            if ok then
                success += 1
            else
                log("Gagal beli #%d: %s", row.Id, tostring(res))
            end
        end
    end

    log("Selesai. success=%d/%d", success, tried)
    running = false
end

function AutoBuyBaitFeature:Stop()
    if not running then return end
    running = false
    log("Stopped.")
end

function AutoBuyBaitFeature:Cleanup()
    self:Stop()
    -- reset state & cache
    table.clear(byId); table.clear(byName); table.clear(rows)
    table.clear(selectedIds)
    purchaseRF = nil
end

-- ========= Setters (khusus fitur) =========
function AutoBuyBaitFeature:SetSelectedBaitsByName(namesOrSet)
    table.clear(selectedIds)
    if typeof(namesOrSet) == "table" then
        -- dukung array atau set/dict
        if #namesOrSet > 0 then
            for _, nm in ipairs(namesOrSet) do
                local row = byName[string.lower(tostring(nm))]
                if row then selectedIds[row.Id] = true end
            end
        else
            for nm, on in pairs(namesOrSet) do
                if on then
                    local row = byName[string.lower(tostring(nm))]
                    if row then selectedIds[row.Id] = true end
                end
            end
        end
    elseif typeof(namesOrSet) == "string" then
        local row = byName[string.lower(namesOrSet)]
        if row then selectedIds[row.Id] = true end
    else
        return false
    end
    return true
end

function AutoBuyBaitFeature:SetSelectedBaitsById(listOrSet)
    table.clear(selectedIds)
    if typeof(listOrSet) == "table" then
        if #listOrSet > 0 then
            for _, id in ipairs(listOrSet) do
                id = tonumber(id)
                if id and byId[id] then selectedIds[id] = true end
            end
        else
            for id, on in pairs(listOrSet) do
                if on then
                    id = tonumber(id)
                    if id and byId[id] then selectedIds[id] = true end
                end
            end
        end
    elseif tonumber(listOrSet) and byId[tonumber(listOrSet)] then
        selectedIds[tonumber(listOrSet)] = true
    else
        return false
    end
    return true
end

-- ========= Public Utils =========
function AutoBuyBaitFeature:GetCatalogRows()
    return rows
end

function AutoBuyBaitFeature:RefreshCatalog()
    buildCatalogRecursive()
    return true
end

function AutoBuyBaitFeature:GetLogSignal()
    return logEvent.Event
end

return AutoBuyBaitFeature
