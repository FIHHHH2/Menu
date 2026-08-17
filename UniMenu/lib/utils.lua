-- UniMenu Utils Library
-- Shared utility functions

local ctx = ...

local HttpService = ctx.Services.HttpService
local TweenService = ctx.Services.TweenService

local Utils = {}

-- Table utilities
function Utils.DeepCopy(orig)
  local copy
  if type(orig) == "table" then
    copy = {}
    for k, v in pairs(orig) do
      copy[Utils.DeepCopy(k)] = Utils.DeepCopy(v)
    end
    setmetatable(copy, Utils.DeepCopy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
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
  return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
end

function Utils.Distance(pos1, pos2)
  return (pos1 - pos2).Magnitude
end

-- Color utilities
function Utils.ColorToHex(color)
  return string.format("#%02X%02X%02X",
    math.floor(color.R * 255),
    math.floor(color.G * 255),
    math.floor(color.B * 255)
  )
end

function Utils.HexToColor(hex)
  hex = hex:gsub("#", "")
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  return Color3.new(r, g, b)
end

function Utils.LerpColor(c1, c2, t)
  return Color3.new(
    Utils.Lerp(c1.R, c2.R, t),
    Utils.Lerp(c1.G, c2.G, t),
    Utils.Lerp(c1.B, c2.B, t)
  )
end

-- Vector3 utilities
function Utils.Flatten(v)
  return Vector3.new(v.X, 0, v.Z)
end

function Utils.YOnly(v)
  return Vector3.new(0, v.Y, 0)
end

-- Instance utilities
function Utils.CreateInstance(className, properties)
  local instance = Instance.new(className)
  if properties then
    for prop, value in pairs(properties) do
      instance[prop] = value
    end
  end
  return instance
end

function Utils.FindFirstAncestorOfClass(obj, className)
  local current = obj.Parent
  while current do
    if current:IsA(className) then return current end
    current = current.Parent
  end
  return nil
end

function Utils.GetDescendantsWithClass(obj, className)
  local results = {}
  for _, child in ipairs(obj:GetDescendants()) do
    if child:IsA(className) then
      table.insert(results, child)
    end
  end
  return results
end

-- Tween utilities
function Utils.Tween(obj, properties, duration, easingStyle, easingDirection)
  duration = duration or 0.2
  easingStyle = easingStyle or Enum.EasingStyle.Quad
  easingDirection = easingDirection or Enum.EasingDirection.Out
  local tween = TweenService:Create(obj,
    TweenInfo.new(duration, easingStyle, easingDirection), properties)
  tween:Play()
  return tween
end

function Utils.TweenPosition(obj, position, duration, easingStyle, easingDirection)
  return Utils.Tween(obj, { Position = position }, duration, easingStyle, easingDirection)
end

function Utils.TweenSize(obj, size, duration, easingStyle, easingDirection)
  return Utils.Tween(obj, { Size = size }, duration, easingStyle, easingDirection)
end

function Utils.TweenTransparency(obj, transparency, duration, easingStyle, easingDirection)
  return Utils.Tween(obj, { BackgroundTransparency = transparency }, duration, easingStyle, easingDirection)
end

-- Time utilities
function Utils.FormatTime(seconds)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = math.floor(seconds % 60)
  if hours > 0 then
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
  else
    return string.format("%02d:%02d", minutes, secs)
  end
end

function Utils.FormatDistance(studs)
  local meters = studs * 0.28
  if meters < 1 then
    return string.format("%.1fm", meters)
  elseif meters < 1000 then
    return string.format("%.0fm", meters)
  else
    return string.format("%.1fkm", meters / 1000)
  end
end

-- Random utilities
function Utils.RandomString(length)
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  local result = ""
  for i = 1, length do
    local rand = math.random(1, #chars)
    result = result .. chars:sub(rand, rand)
  end
  return result
end

-- JSON utilities
function Utils.JSONEncode(data)
  return HttpService:JSONEncode(data)
end

function Utils.JSONDecode(str)
  return HttpService:JSONDecode(str)
end

-- Safe call utilities
function Utils.SafeCall(fn, ...)
  local args = { ... }
  local ok, result = pcall(function() return fn(table.unpack(args)) end)
  return ok, result
end

function Utils.SafeGet(obj, path)
  local current = obj
  for part in path:gmatch("[^.]+") do
    if not current then return nil end
    current = current[part]
  end
  return current
end

-- Export
ctx.lib = ctx.lib or {}
ctx.lib.utils = Utils
ctx.Modules.utils = true