-- test_webhook.lua  (drop-in prototype)

-- ==== HTTP backend autodetect ====
local HttpService = game:GetService("HttpService")

local function getRequestFn()
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    if type(http_request) == "function" then return http_request end
    if type(request) == "function" then return request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
    return nil
end

-- ==== EMOJI (custom server) ====
-- Ganti ini dengan emoji server-mu; kalau kirim ke server lain dan "external emojis" nggak diizinkan,
-- string akan tampil mentah. Untuk portable, pakai Unicode biasa (🐟 ⚖️ 🎲 💎 🧬).
local EMOJI = {
    fish     = "<:emoji_1:1415617268511150130>",
    weight   = "<:emoji_2:1415617300098449419>",
    chance   = "<:emoji_3:1415617326316916787>",
    rarity   = "<:emoji_4:1415617353898790993>",
    mutation = "<:emoji_5:1415617377424511027>"
}

local function label(icon, text) return string.format("%s %s", icon or "", text or "") end

-- ==== Core send ====
local function sendWebhook(webhookUrl, payload)
    local req = getRequestFn()
    assert(req, "No HTTP request function available (syn.request/http_request/request not found)")
    assert(type(webhookUrl)=="string" and webhookUrl~="", "Webhook URL is empty")

    local ok, res = pcall(req, {
        Url = webhookUrl,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"]   = "Mozilla/5.0",
            ["Accept"]       = "*/*",
        },
        Body = HttpService:JSONEncode(payload),
    })
    if not ok then return false, "request error: "..tostring(res) end

    local code = tonumber(res.StatusCode or res.Status) or 0
    return (code>=200 and code<300), ("status "..code..(res.Body and (" body: "..tostring(res.Body)) or ""))
end

-- ==== Build a test embed ====
local function buildTestEmbed()
    local nowIso = os.date("!%Y-%m-%dT%H:%M:%SZ")

    -- helper “box” gaya kode blok 1 baris
    local function box(v)
        v = v == nil and "Unknown" or tostring(v)
        v = v:gsub("```", "ˋ``")
        return string.format("```%s```", v)
    end

    local embed = {
        title = "Webhook Test • New Catch (Prototype)",
        description = "This is a **test embed** using custom Discord server emojis.",
        color = 0x87CEEB,
        timestamp = nowIso,
        footer = { text = ".devlogic | Fish-It Notifier (test)" },

        -- NOTE: gambar di field name/value tidak didukung Discord.
        -- Gunakan emoji di name, dan taruh gambar di thumbnail/image/author/footer bila perlu.
        fields = {
            { name = label(EMOJI.fish, "Fish Name"),  value = box("Wispwing (TEST)"),                   inline = false },
            { name = label(EMOJI.weight, "Weight"),   value = box("1.27 kg"),                           inline = true  },
            { name = label(EMOJI.chance, "Chance"),   value = box("1 in 2,000"),                        inline = true  },
            { name = label(EMOJI.rarity, "Rarity"),   value = box("Legendary"),                         inline = true  },
            { name = label(EMOJI.mutation, "Mutation"), value = box("Variant: Galaxy | ✨ SHINY"),      inline = false },
        },

        -- Contoh icon di author/footer (opsional):
        -- author = { name = "Wispwing (TEST)", icon_url = "https://raw.githubusercontent.com/<user>/<repo>/main/icons/fish.png" },
        -- thumbnail = { url = "https://raw.githubusercontent.com/<user>/<repo>/main/icons/fish.png" },
    }

    return { username = ".devlogic Webhook Tester", embeds = { embed } }
end

-- ==== Public API ====
local TestWebhook = {}

-- Kirim test embed. Return (ok, info)
function TestWebhook.Send(webhookUrl)
    local payload = buildTestEmbed()
    return sendWebhook(webhookUrl, payload)
end

return TestWebhook