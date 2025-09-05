# Fish-It Feature Script Contract (SPEC)

Tujuan: semua **Feature Script** punya pola yang konsisten supaya gampang di-load, di-wiring, dan di-maintain lewat GUI utama (`fishit.lua`) + `FeatureManager`.

---

## 1) Lifecycle Wajib

Setiap fitur **HARUS** mengekspor object/table dengan metode berikut:

- `:Init(guiControls?) -> boolean`  
  Inisialisasi resource (remotes, references, cache). Return `true` jika siap.

- `:Start(config?) -> void`  
  Mulai loop/logic utama. **Idempotent** (panggilan ganda tidak dobel jalan).

- `:Stop() -> void`  
  Hentikan loop/connection/heartbeat. **Idempotent**.

- `:Cleanup() -> void`  
  Bersih-bersih total (reset cache/state). Boleh panggil `:Stop()` di dalamnya.

> **Catatan:** `config` adalah **khusus per-fitur** (tidak diseragamkan), lihat §3.

---

## 2) Setters & Aksi (Khusus Per-Fitur)

- **Tidak ada** nama setter global yang dipaksakan lintas fitur.
- Pilih nama yang **jelas** dan **unik**, merefleksikan kebutuhan fitur:
  - Contoh:  
    - `autobuyweather`: `:SetWeathers(listOrSet)`, `:SetInterPurchaseDelay(sec)`  
    - `autosellfish`: `:SetRarityThreshold(tier)`, `:SetSellDelay(sec)`
    - `autoteleportisland`: `:SetIsland(name)` / `:SetRoute({ ... })`
- Setters **idempotent** dan **validasi input** (abaikan input buruk, return `false`).

**Multi-dropdown convention:** setter **boleh menerima**:
- **array**: `{"A","B"}`
- **set/dict**: `{ A=true, B=true }`  
Konversi internal ke array unik, clamp jika perlu (mis. max 3).

---

## 3) `Start(config)` — Konfigurasi Per-Fitur

`config` bukan schema global; **ditentukan oleh fitur**.
- Rekomendasi: gunakan nama kunci yang mendeskripsikan maksud, bukan warisan generic.
  - Contoh `autobuyweather`:
    ```lua
    feature:Start({
      weatherList = {"Shark Hunt","Snow"},
      interDelay  = 0.75
    })
    ```
- Abaikan kunci yang tidak dikenal; jangan error.

---

## 4) Integrasi dengan FeatureManager

Feature di-load via `FeatureManager:LoadFeature("FeatureName", guiControls?)`.

- **Return** dari file fitur harus **object table** yang berisi lifecycle & setters.
- `guiControls` (opsional) adalah pegangan komponen UI terkait fitur:
  - Contoh: `{ weatherDropdownMulti = <Dropdown>, toggle = <Toggle> }`
  - Fitur **boleh** memanfaatkan untuk pre-populate options (mis. `:Init()` memanggil `dropdown:Reload(names)`), tapi **tidak wajib**.

---

## 5) Pedoman Teknis (Best Practices)

### 5.1 Remotes & Replication
- Cari Remote dengan `WaitForChild` ber-timeout dan bungkus `pcall`.
- Untuk data di `ReplicatedStorage`, dukung struktur **bersarang** (scan rekursif).

### 5.2 Loop & Koneksi
- Gunakan `RunService.Heartbeat`/`RenderStepped`/`task.spawn` seperlunya.
- Jaga pacing: variabel `TICK_STEP` (mis. `0.15s`) untuk throttle.
- Simpan koneksi ke variabel dan **putuskan** di `:Stop()`.

### 5.3 Anti-Spam & Rate-Limit
- Gate pemanggilan Remote dengan:
  - _Inter-purchase delay_ global kecil (mis. `0.5–1.0s`).
  - Cooldown per-item berdasar data modul (mis. `QueueTime + Duration`).
- Selalu `pcall` saat `InvokeServer`/`FireServer`.

### 5.4 Error Handling & Logging
- Jangan `error()`; gunakan `warn()` + return `false`.
- Notifikasi ke user (jika perlu) serahkan ke GUI (WindUI `Notify`) — **fitur tidak mem-pop-up** sendiri kecuali sangat perlu.

### 5.5 Kinerja & Kebersihan State
- `:Stop()` harus menghentikan semua aktivitas (loop, connection).
- `:Cleanup()` mengosongkan cache map/set, meng-nil kan reference, reset pointer.

---

## 6) Template Feature Minimal
```lua
-- File: Fish-It/feature-name.lua
local Feature = {}
Feature.__index = Feature

-- services / refs
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- state
local running = false
local hbConn  = nil

-- === lifecycle ===
function Feature:Init(gui)
  -- init remotes/scan data with pcall/timeout
  return true
end

function Feature:Start(config)
  if running then return end
  running = true
  hbConn = RunService.Heartbeat:Connect(function()
    if not running then return end
    -- main loop step
  end)
end

function Feature:Stop()
  if not running then return end
  running = false
  if hbConn then hbConn:Disconnect(); hbConn = nil end
end

function Feature:Cleanup()
  self:Stop()
  -- reset local caches/state if any
end

-- === setters (feature-specific) ===
function Feature:SetSomething(v)
  -- validate & store
  return true
end

return Feature

--### 7) Contoh Wiring GUI Pattern
local featureObj = nil

local dd = TabX:Dropdown({
  Title = "Select Items",
  Values = {}, Multi = true, AllowNone = true,
  Callback = function(opts)
    -- normalize array -> set (atau langsung pass array)
    local set = {}
    for _, v in ipairs(opts) do set[v] = true end
    if featureObj and featureObj.SetItems then
      featureObj:SetItems(set) -- modul menerima set/array
    end
  end
})

local tgl = TabX:Toggle({
  Title = "Enable Feature",
  Default = false,
  Callback = function(state)
    if state then
      if not featureObj then
        featureObj = FeatureManager:LoadFeature("FeatureName", {
          itemsDropdown = dd,
          toggle        = tgl,
        })
      end
      if featureObj and featureObj.Start then
        featureObj:Start({ items = {"A","B"} }) -- atau set/dict sesuai setter
      else
        tgl:Set(false)
        WindUI:Notify({ Title="Failed", Content="Could not start FeatureName", Icon="x", Duration=3 })
      end
    else
      if featureObj and featureObj.Stop then featureObj:Stop() end
    end
  end
})


--8) Quality Checklist (Anti-Footgun)

-- Lifecycle lengkap (Init/Start/Stop/Cleanup) & idempotent.

-- Semua Remote pcall, ada throttle & cooldown anti-spam.

-- Scanner folder rekursif untuk data di ReplicatedStorage.

-- Setters hanya yang fitur butuhkan; terima array/set untuk multi.

-- Tidak ada notifikasi UI dari dalam fitur (biar GUI yang handle).

-- Stop() memutus semua koneksi; Cleanup() reset state.

-- Variabel/timer tidak bocor antar start/stop.