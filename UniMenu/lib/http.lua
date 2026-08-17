-- UniMenu HTTP Library
-- HTTP request utilities with multiple executor fallbacks

local ctx = ...

local HttpService = ctx.Services.HttpService

local HTTP = {}

-- Configuration
HTTP.DEFAULT_TIMEOUT = 10
HTTP.USER_AGENT = "UniMenu/10.0 (Roblox; " .. game.PlaceId .. ")"

-- Internal: get available HTTP function
local function GetHttpFunction()
  if typeof(game.HttpGet) == "function" then
    return function(url)
      return game:HttpGet(url)
    end
  end
  if typeof(syn) == "table" and typeof(syn.request) == "function" then
    return function(url)
      local res = syn.request({ Url = url, Method = "GET", Headers = { ["User-Agent"] = HTTP.USER_AGENT } })
      return res and (res.Body or res.body)
    end
  end
  if typeof(request) == "function" then
    return function(url)
      local res = request({ Url = url, Method = "GET", Headers = { ["User-Agent"] = HTTP.USER_AGENT } })
      return res and (res.Body or res.body)
    end
  end
  if typeof(httpget) == "function" then
    return httpget
  end
  if typeof(get) == "function" then
    return get
  end
  return nil
end

local httpFn = GetHttpFunction()

-- GET request
function HTTP.Get(url, options)
  options = options or {}
  local timeout = options.timeout or HTTP.DEFAULT_TIMEOUT
  local headers = options.headers or {}

  if not httpFn then
    return nil, "No HTTP function available"
  end

  local ok, result = pcall(function()
    if options.raw then
      return httpFn(url)
    else
      local fullHeaders = {}
      for k, v in pairs(headers) do fullHeaders[k] = v end
      fullHeaders["User-Agent"] = fullHeaders["User-Agent"] or HTTP.USER_AGENT

      if typeof(syn) == "table" and typeof(syn.request) == "function" then
        return syn.request({ Url = url, Method = "GET", Headers = fullHeaders })
      elseif typeof(request) == "function" then
        return request({ Url = url, Method = "GET", Headers = fullHeaders })
      else
        return game:HttpGet(url)
      end
    end
  end)

  if not ok then
    return nil, "Request failed: " .. tostring(result)
  end

  local body = result
  if typeof(result) == "table" then
    body = result.Body or result.body
  end

  return body, nil
end

-- POST request
function HTTP.Post(url, data, options)
  options = options or {}
  local headers = options.headers or {}

  if not httpFn and not (typeof(syn) == "table" and typeof(syn.request) == "function") and not typeof(request) == "function" then
    return nil, "POST requires syn.request or request function"
  end

  local body = data
  local contentType = headers["Content-Type"] or "application/json"
  if contentType == "application/json" and type(data) == "table" then
    body = HttpService:JSONEncode(data)
  end

  local ok, result = pcall(function()
    if typeof(syn) == "table" and typeof(syn.request) == "function" then
      return syn.request({
        Url = url,
        Method = "POST",
        Headers = headers,
        Body = body
      })
    elseif typeof(request) == "function" then
      return request({
        Url = url,
        Method = "POST",
        Headers = headers,
        Body = body
      })
    end
    return nil, "POST not supported"
  end)

  if not ok then
    return nil, "Request failed: " .. tostring(result)
  end

  local responseBody = result
  if typeof(result) == "table" then
    responseBody = result.Body or result.body
  end

  return responseBody, nil
end

-- JSON GET (auto-decode)
function HTTP.GetJSON(url, options)
  local body, err = HTTP.Get(url, options)
  if not body then return nil, err end

  local ok, decoded = pcall(function() return HttpService:JSONDecode(body) end)
  if not ok then
    return nil, "JSON decode failed: " .. tostring(decoded)
  end
  return decoded, nil
end

-- JSON POST
function HTTP.PostJSON(url, data, options)
  options = options or {}
  options.headers = options.headers or {}
  options.headers["Content-Type"] = "application/json"
  return HTTP.Post(url, data, options)
end

-- Download file (for assets)
function HTTP.DownloadFile(url, savePath)
  local body, err = HTTP.Get(url)
  if not body then return false, err end

  if typeof(writefile) == "function" then
    local ok, writeErr = pcall(writefile, savePath, body)
    if not ok then return false, "Write failed: " .. tostring(writeErr) end
    return true, nil
  end
  return false, "writefile not available"
end

-- Roblox asset helpers
function HTTP.GetAssetIdFromUrl(url)
  local id = url:match("rbxassetid://(%d+)")
  if id then return tonumber(id) end
  id = url:match("roblox.com/asset/%?id=(%d+)")
  if id then return tonumber(id) end
  id = url:match("roblox.com/library/(%d+)")
  if id then return tonumber(id) end
  return nil
end

-- Rate limiting (simple)
local lastRequest = {}
function HTTP.RateLimitedGet(url, minInterval)
  minInterval = minInterval or 0.5
  local now = tick()
  local last = lastRequest[url] or 0
  if now - last < minInterval then
    task.wait(minInterval - (now - last))
  end
  lastRequest[url] = tick()
  return HTTP.Get(url)
end

-- Export
ctx.lib = ctx.lib or {}
ctx.lib.http = HTTP
ctx.Modules.http = true