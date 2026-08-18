-- UniMenu Loader - Entry point for modular system
-- Paste this into your executor to load UniMenu

local BASE_URL = "https://raw.githubusercontent.com/FIHHHH2/Menu/main/UniMenu/"

local ctx = {
  Services = {},
  State = { S = {}, MM2 = {}, Music = {} },
  Config = { gameConfig = {}, Themes = {}, currentThemeName = "Windows XP Luna", XP = nil },
  Core = {},
  UI = {},
  Game = {},
  Modules = {}
}

local cache = {}

local function loadModule(name)
  if cache[name] then return cache[name] end

  local src
  if typeof(game.HttpGet) == "function" then
    local ok, result = pcall(game.HttpGet, game, BASE_URL .. name .. ".lua")
    if ok and result then src = result end
  end

  if not src and typeof(syn) == "table" and typeof(syn.request) == "function" then
    local ok, res = pcall(syn.request, { Url = BASE_URL .. name .. ".lua", Method = "GET" })
    if ok and res and (res.Body or res.body) then
      src = res.Body or res.body
    end
  end

  if not src and typeof(request) == "function" then
    local ok, res = pcall(request, { Url = BASE_URL .. name .. ".lua", Method = "GET" })
    if ok and res and (res.Body or res.body) then
      src = res.Body or res.body
    end
  end

  if not src then
    error("Failed to load module: " .. name .. " from " .. BASE_URL .. name .. ".lua")
  end

  local fn, err = loadstring(src)
  if not fn then
    error("Failed to compile module " .. name .. ": " .. tostring(err))
  end

  local ok, result = pcall(fn, ctx)
  if not ok then
    error("Failed to execute module " .. name .. ": " .. tostring(result))
  end

  cache[name] = true
  return true
end

-- Load modules in dependency order
loadModule("core")
loadModule("ui")
loadModule("mm2")
loadModule("lib/utils")
loadModule("lib/http")
loadModule("lib/notifications")
loadModule("music/covers")
loadModule("music/lastfm")
loadModule("music/spotify")

-- Initialize everything
if ctx.Core.Init then
  ctx.Core.Init()
end
