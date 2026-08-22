-- UniMenu Utils Module
-- Shared utility functions

local ctx = ...
local HttpService = ctx.Services.HttpService
local TweenService = ctx.Services.TweenService

local Utils = {}

-- Table utilities
-- Iterative DeepCopy to prevent stack overflows
function Utils.DeepCopy(orig)
    local copies = {}
    local stack = { { orig, false } }
    
    while #stack > 0 do
        local obj, processed = table.remove(stack, 1)
        if processed then
            local copy = copies[obj]
            if type(obj) == "table" then
                for k, v in pairs(obj) do
                    if type(k) == "table" then k = copies[k] end
                    if type(v) == "table" then v = copies[v] end
                    copy[k] = v
                end
                setmetatable(copy, copies[getmetatable(obj)])
            end
        else
            if type(obj) ~= "table" then
                copies[obj] = obj
                continue
            end
            if copies[obj] then continue end
            copies[obj] = {}
            table.insert(stack, 1, { obj, true })
            local mt = getmetatable(obj)
            if mt then
                copies[mt] = Utils.DeepCopy(mt)
                setmetatable(copies[obj], copies[mt])
            end
            for k, v in pairs(obj) do
                table.insert(stack, { v, false })
                table.insert(stack, { k, false })
            end
        end
    end
    return copies[orig]
end

function Utils.TableFind(tbl, value)
    for k, v in pairs(tbl) do
        if v == value then return k end
    end
    return nil
end

function Utils.TableContains(tbl, value)
    return Utils.TableFind(tbl, value) ~= nil
end

function Utils.TableMerge(t1, t2)
    local result = Utils.DeepCopy(t1)
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

-- String utilities
function Utils.Split(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

function Utils.Trim(str)
    return str:match("^%s*(.-)%s*$")
end

function Utils.StartsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

function Utils.EndsWith(str, suffix)
    return str:sub(-#suffix) == suffix
end

-- Math utilities
function Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.Round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

function Utils.Map(value, inMin, inMax, outMin, outMax)
    return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)
end

-- Color utilities
function Utils.HSVToRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    
    local r, g, b
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    
    return Color3.new(r + m, g + m, b + m)
end

function Utils.RGBToHSV(color)
    local r, g, b = color.R, color.G, color.B
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min
    
    local h, s, v = max, max == 0 and 0 or delta / max, max
    
    if delta > 0 then
        if max == r then h = 60 * ((g - b) / delta % 6)
        elseif max == g then h = 60 * ((b - r) / delta + 2)
        else h = 60 * ((r - g) / delta + 4) end
    else
        h = 0
    end
    
    return h, s, v
end

-- Instance utilities
function Utils.CreateInstance(className, properties, children)
    local instance = Instance.new(className)
    for prop, value in pairs(properties or {}) do
        instance[prop] = value
    end
    for _, child in ipairs(children or {}) do
        child.Parent = instance
    end
    return instance
end

function Utils.Tween(instance, properties, duration, easingStyle, easingDirection)
    local tweenInfo = TweenInfo.new(duration or 0.2, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

-- HTTP utilities
-- Unified HTTP handler with timeout and error logging
local function UnifiedRequest(method, url, body, headers, timeout)
    local requestFunc = (syn and syn.request) or request or game.HttpGet
    if not requestFunc then return false, "No HTTP method available" end

    local startTime = os.clock()
    local success, result = pcall(function()
        if syn and syn.request then
            local res = syn.request({
                Url = url,
                Method = method,
                Body = body,
                Headers = headers,
                TimeLimit = timeout or 10
            })
            return res.Success, res.Body
        elseif request then
            local res = request({
                Url = url,
                Method = method,
                Body = body,
                Headers = headers,
            })
            return res.Success, res.Body
        elseif game.HttpGet and method == "GET" then
            return pcall(function() return game:HttpGet(url, headers) end)
        end
    end)
    
    if not success or (os.clock() - startTime) > (timeout or 10) then
        print("[UniMenu] HTTP Error " .. tostring(method) .. " " .. tostring(url) .. " Timeout or failure")
        return false, "Request timed out or failed"
    end
    return result
end

function Utils.HttpGet(url, headers, timeout)
    return UnifiedRequest("GET", url, nil, headers, timeout)
end

function Utils.HttpPost(url, body, headers, timeout)
    return UnifiedRequest("POST", url, body, headers, timeout)
end

-- Encoding utilities
function Utils.URLEncode(str)
    str = string.gsub(str, "\n", "\r\n")
    str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    str = string.gsub(str, " ", "+")
    return str
end

-- Time utilities
function Utils.FormatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", mins, secs)
end

function Utils.Timestamp()
    return os.date("%H:%M:%S")
end

-- Debug utilities
function Utils.Log(...)
    local args = {...}
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end
    print("[UniMenu] " .. table.concat(args, " "))
end

function Utils.Warn(...)
    local args = {...}
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end
    warn("[UniMenu] " .. table.concat(args, " "))
end

function Utils.Error(...)
    local args = {...}
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end
    error("[UniMenu] " .. table.concat(args, " "))
end

ctx.Modules = ctx.Modules or {}
ctx.Modules.utils = Utils

return Utils