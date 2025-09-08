--========================================
-- Rollenchant Detector (focused, low-noise)
-- Targets: "RE/RollEnchant"
-- Safe: narrow __namecall hook; won't touch others
--========================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- ==== CONFIG ====
local TARGET_NAME = "RE/RollEnchant"   -- ganti kalau namanya beda
local MAX_DEPTH   = 5                  -- batas pretty print table
local MAX_ITEMS   = 100                -- batas banyaknya item per table

-- ==== UTIL ====
local function safeGetFullName(obj)
    local ok, res = pcall(function() return obj:GetFullName() end)
    return ok and res or (typeof(obj) .. "<?>")
end

local function dumpAttributes(inst)
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if not ok or type(attrs) ~= "table" then return {} end
    return attrs
end

local function typeofLite(v)
    local t = typeof(v)
    if t == "Instance" then
        return ("Instance<%s>(%s)"):format(v.ClassName, v.Name)
    elseif t == "table" then
        return "table"
    else
        return t
    end
end

local function pretty(v, depth, seen)
    depth = depth or 0
    seen = seen or {}

    local t = typeof(v)

    if t == "Instance" then
        local attrs = dumpAttributes(v)
        local parts = {}
        for k,val in pairs(attrs) do
            table.insert(parts, tostring(k) .. "=" .. tostring(val))
        end
        local attrStr = (#parts > 0) and (" attrs{"..table.concat(parts,", ").."}") or ""
        return ("<%s %s path='%s'%s>")
            :format(v.ClassName, v.Name, safeGetFullName(v), attrStr)

    elseif t == "table" then
        if seen[v] then return "<recursive>" end
        seen[v] = true
        if depth >= MAX_DEPTH then return "<table …>" end
        local n = 0
        local out = {}
        table.insert(out, "{")
        for k,val in pairs(v) do
            n += 1
            if n > MAX_ITEMS then
                table.insert(out, "  …(truncated)…")
                break
            end
            local kk = pretty(k, depth+1, seen)
            local vv = pretty(val, depth+1, seen)
            table.insert(out, ("  [%s] = %s"):format(kk, vv))
        end
        table.insert(out, "}")
        return table.concat(out, "\n")

    elseif t == "Vector3" or t == "Vector2" then
        return ("%s(%s)"):format(t, tostring(v))
    elseif t == "CFrame" then
        return ("CFrame(%s)"):format(tostring(v))
    elseif t == "userdata" then
        return "<userdata>"
    elseif t == "function" then
        return "<function>"
    elseif t == "RBXScriptSignal" then
        return "<Signal>"
    else
        return ("%s(%s)"):format(t, tostring(v))
    end
end

local function banner(title)
    print(("\n===== %s ====="):format(title))
end

local function logArgs(prefix, args)
    if not args or #args == 0 then
        print(prefix .. " (no args)")
        return
    end
    for i,arg in ipairs(args) do
        print(("[%s] #%d type=%s\n%s")
            :format(prefix, i, typeofLite(arg), pretty(arg)))
    end
end

-- ==== FIND NET/REMOTE ====
local function findNetRoot()
    -- Typical path: ReplicatedStorage/Packages/_Index/sleitnick_net@x.y.z/net
    local Packages = ReplicatedStorage:FindFirstChild("Packages")
    if not Packages then return nil end
    local _Index = Packages:FindFirstChild("_Index")
    if not _Index then return nil end
    for _, pkg in ipairs(_Index:GetChildren()) do
        -- Accept any sleitnick_net@*/net
        if pkg:IsA("Folder") and pkg.Name:match("^sleitnick_net@") then
            local net = pkg:FindFirstChild("net")
            if net then
                return net
            end
        end
    end
end

local function findTarget()
    -- Priority 1: exact path under sleitnick net
    local net = findNetRoot()
    if net then
        local inst = net:FindFirstChild(TARGET_NAME)
        if inst then return inst end
    end
    -- Fallback: global search under ReplicatedStorage
    -- (Name literally "RE/RollEnchant")
    local found = ReplicatedStorage:FindFirstChild(TARGET_NAME, true)
    return found
end

local target = findTarget()
if not target then
    warn("[rollenchant-detector] Target not found yet: " .. TARGET_NAME .. " (will continue watching)")
end

-- Keep watching if it appears later
local function onDescendantAdded(desc)
    if desc.Name == TARGET_NAME and (desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction")) then
        target = desc
        banner("FOUND TARGET LATE")
        print(("Class=%s path=%s"):format(desc.ClassName, safeGetFullName(desc)))
    end
end

ReplicatedStorage.DescendantAdded:Connect(onDescendantAdded)

-- ==== SERVER -> CLIENT TAPS ====
local function attachInboundTaps(inst)
    if inst:IsA("RemoteEvent") then
        inst.OnClientEvent:Connect(function(...)
            local args = table.pack(...)
            banner("INBOUND OnClientEvent  (" .. TARGET_NAME .. ")")
            print("RemoteEvent path: " .. safeGetFullName(inst))
            logArgs("arg", args)
        end)
    elseif inst:IsA("RemoteFunction") then
        -- Preserve existing handler if any:
        local prev = inst.OnClientInvoke
        inst.OnClientInvoke = function(...)
            local args = table.pack(...)
            banner("INBOUND OnClientInvoke (" .. TARGET_NAME .. ")")
            print("RemoteFunction path: " .. safeGetFullName(inst))
            logArgs("arg", args)
            if prev then
                local ok, res = pcall(prev, table.unpack(args, 1, args.n))
                banner("OnClientInvoke return (delegated)")
                if ok then
                    print(pretty(res))
                    return res
                else
                    warn("Prev OnClientInvoke error: " .. tostring(res))
                    return nil
                end
            end
            -- no previous handler
            return nil
        end
    end
end

-- If already present, attach now
if target then
    attachInboundTaps(target)
end

-- Also watch future
ReplicatedStorage.DescendantAdded:Connect(function(desc)
    if desc == target then return end
    if desc.Name == TARGET_NAME and (desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction")) then
        attachInboundTaps(desc)
    end
end)

-- ==== CLIENT -> SERVER HOOK (focused) ====
-- Narrow hook: only RemoteEvent/RemoteFunction + correct name + specific methods.

local rawmt = getrawmetatable(game)
local oldNamecall = rawmt.__namecall
setreadonly(rawmt, false)

rawmt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    -- Fast path: ignore non-Instance or wrong classes
    if typeof(self) == "Instance" then
        local class = self.ClassName
        if (class == "RemoteEvent" or class == "RemoteFunction")
           and self.Name == TARGET_NAME
           and (method == "FireServer" or method == "InvokeServer")
        then
            local args = table.pack(...)
            if method == "FireServer" then
                banner("OUTBOUND FireServer (" .. TARGET_NAME .. ")")
                print("RemoteEvent path: " .. safeGetFullName(self))
                logArgs("arg", args)
                -- proceed
                return oldNamecall(self, table.unpack(args, 1, args.n))
            else -- InvokeServer
                banner("OUTBOUND InvokeServer (" .. TARGET_NAME .. ")")
                print("RemoteFunction path: " .. safeGetFullName(self))
                logArgs("arg", args)
                local res = oldNamecall(self, table.unpack(args, 1, args.n))
                banner("InvokeServer return (" .. TARGET_NAME .. ")")
                print(pretty(res))
                return res
            end
        end
    end
    return oldNamecall(self, ...)
end)

setreadonly(rawmt, true)

banner("rollenchant-detector ready")
print("Target:", TARGET_NAME, " | Depth:", MAX_DEPTH, " | Items:", MAX_ITEMS)
print("Tips: Mulai altar ⇒ jalanin enchant ⇒ lihat console untuk OUTBOUND/INBOUND log.")