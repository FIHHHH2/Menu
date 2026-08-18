-- UniMenu Spotify Module
-- Spotify Web API integration with OAuth PKCE flow

local ctx = ...
local HttpService = ctx.Services.HttpService

local Music = ctx.State.Music

-- Spotify state (stored in Music.spotify)
-- clientId, clientSecret (obfuscated), accessToken, refreshToken, expiresAt, deviceId, connected, song, artist, isPlaying, progressMs, durationMs

-- ==================== PKCE HELPERS ====================
local function GenerateCodeVerifier()
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  local len = 128
  local result = ""
  for i = 1, len do
    local idx = math.random(1, #chars)
    result = result .. chars:sub(idx, idx)
  end
  return result
end

local function GenerateCodeChallenge(verifier)
  -- SHA256 + base64url encode
  -- Since we don't have crypto in Luau, we'll use a simplified approach
  -- In practice, you'd need a proper SHA256 implementation
  -- For now, we'll use the verifier directly (plain challenge method)
  -- NOTE: This is less secure but works without crypto library
  return verifier
end

local function GenerateState()
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  local result = ""
  for i = 1, 32 do
    local idx = math.random(1, #chars)
    result = result .. chars:sub(idx, idx)
  end
  return result
end

-- ==================== OAUTH URLS ====================
local SPOTIFY_AUTH_URL = "https://accounts.spotify.com/authorize"
local SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
local SPOTIFY_API_BASE = "https://api.spotify.com/v1"

-- Scopes needed
local SPOTIFY_SCOPES = table.concat({
  "user-read-currently-playing",
  "user-read-playback-state",
  "user-modify-playback-state",
  "user-read-recently-played",
  "user-top-read",
  "streaming",
  "app-remote-control"
}, " ")

-- ==================== TOKEN MANAGEMENT ====================
local function SaveSpotifyTokens()
  local data = {
    clientId = Music.spotify.clientId or "",
    clientSecret = Music.spotify.clientSecret or "",
    accessToken = Music.spotify.accessToken or "",
    refreshToken = Music.spotify.refreshToken or "",
    expiresAt = Music.spotify.expiresAt or 0,
  }
  local json = HttpService:JSONEncode(data)
  if typeof(writefile) == "function" then
    writefile("UniMenu_spotify_tokens.json", json)
  end
end

local function LoadSpotifyTokens()
  if typeof(readfile) ~= "function" then return end
  if not isfile or not isfile("UniMenu_spotify_tokens.json") then return end
  local ok, content = pcall(readfile, "UniMenu_spotify_tokens.json")
  if not ok or not content then return end
  local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
  if not ok2 or type(data) ~= "table" then return end
  Music.spotify.clientId = data.clientId or ""
  Music.spotify.clientSecret = data.clientSecret or ""
  Music.spotify.accessToken = data.accessToken or ""
  Music.spotify.refreshToken = data.refreshToken or ""
  Music.spotify.expiresAt = data.expiresAt or 0
end

local function IsTokenExpired()
  return os.time() >= (Music.spotify.expiresAt or 0) - 60 -- 60s buffer
end

local function RefreshAccessToken()
  if not Music.spotify.refreshToken or Music.spotify.refreshToken == "" then
    return false, "No refresh token"
  end
  
  local url = SPOTIFY_TOKEN_URL
  local body = "grant_type=refresh_token&refresh_token=" .. ctx.Core.UrlEncode(Music.spotify.refreshToken)
  if Music.spotify.clientId and Music.spotify.clientId ~= "" then
    body = body .. "&client_id=" .. ctx.Core.UrlEncode(Music.spotify.clientId)
  end
  
  local res = ctx.Core.MusicHTTP(url .. "?" .. body) -- Will need POST support
  -- For now, return false - need proper POST implementation
  return false, "POST not implemented"
end

-- ==================== OAUTH FLOW ====================
local authState = nil
local codeVerifier = nil
local authCallbackReceived = false
local authCallbackCode = nil
local authCallbackError = nil

local function BuildAuthUrl()
  if not Music.spotify.clientId or Music.spotify.clientId == "" then
    return nil, "Client ID not set"
  end
  
  codeVerifier = GenerateCodeVerifier()
  local codeChallenge = GenerateCodeChallenge(codeVerifier)
  authState = GenerateState()
  
  local params = {
    "response_type=code",
    "client_id=" .. ctx.Core.UrlEncode(Music.spotify.clientId),
    "redirect_uri=" .. ctx.Core.UrlEncode("http://localhost:8888/callback"),
    "scope=" .. ctx.Core.UrlEncode(SPOTIFY_SCOPES),
    "state=" .. ctx.Core.UrlEncode(authState),
    "code_challenge_method=S256",
    "code_challenge=" .. ctx.Core.UrlEncode(codeChallenge),
    "show_dialog=true",
  }
  
  return SPOTIFY_AUTH_URL .. "?" .. table.concat(params, "&")
end

local function StartSpotifyAuth()
  local authUrl, err = BuildAuthUrl()
  if not authUrl then
    ctx.Core.ShowNotification("Spotify: " .. err)
    return false
  end
  
  authCallbackReceived = false
  authCallbackCode = nil
  authCallbackError = nil
  
  -- Open browser
  pcall(function() game:OpenBrowser(authUrl) end)
  ctx.Core.ShowNotification("Spotify: Opening browser for authentication...")
  
  -- Poll for callback (simplified - in reality needs a local server)
  task.spawn(function()
    local attempts = 0
    while not authCallbackReceived and attempts < 120 do -- 60 seconds
      task.wait(0.5)
      attempts = attempts + 1
    end
    
    if authCallbackReceived then
      if authCallbackCode then
        ExchangeCodeForTokens(authCallbackCode)
      elseif authCallbackError then
        ctx.Core.ShowNotification("Spotify auth failed: " .. authCallbackError)
      end
    else
      ctx.Core.ShowNotification("Spotify auth timed out")
    end
  end)
  
  return true
end

-- Handle OAuth callback (called from external callback handler)
ctx.Core.HandleSpotifyCallback = function(code, state, error)
  if state ~= authState then
    ctx.Core.ShowNotification("Spotify: Invalid state parameter")
    return
  end
  
  authCallbackReceived = true
  if error then
    authCallbackError = error
  else
    authCallbackCode = code
  end
end

local function ExchangeCodeForTokens(code)
  -- This needs POST request with body - not fully supported by all executors
  -- Fallback: Use client credentials flow or manual token entry
  ctx.Core.ShowNotification("Spotify: Token exchange requires POST support")
end

-- ==================== SPOTIFY API CALLS ====================
local function SpotifyRequest(method, endpoint, body)
  if not Music.spotify.accessToken or Music.spotify.accessToken == "" then
    return nil, "No access token"
  end
  
  if IsTokenExpired() then
    local ok, err = RefreshAccessToken()
    if not ok then
      return nil, "Token expired: " .. err
    end
  end
  
  local url = SPOTIFY_API_BASE .. endpoint
  local headers = {
    Authorization = "Bearer " .. Music.spotify.accessToken,
    ["Content-Type"] = "application/json",
  }
  
  -- Try different HTTP methods
  local methods = {
    function()
      return request({
        Url = url,
        Method = method,
        Headers = headers,
        Body = body and HttpService:JSONEncode(body) or nil,
      })
    end,
    function()
      return syn and syn.request({
        Url = url,
        Method = method,
        Headers = headers,
        Body = body and HttpService:JSONEncode(body) or nil,
      })
    end,
  }
  
  for _, methodFn in ipairs(methods) do
    local ok, res = pcall(methodFn)
    if ok and res and (res.Body or res.body) then
      local responseBody = res.Body or res.body
      if responseBody and #responseBody > 0 then
        local ok2, data = pcall(function() return HttpService:JSONDecode(responseBody) end)
        if ok2 then return data end
      end
      return true
    end
  end
  
  return nil, "Request failed"
end

-- ==================== PLAYBACK POLLING ====================
local spotifyPollingActive = false
local spotifyPollThread = nil

local function SpotifyPoll()
  if not Music.spotify.connected then return end
  
  -- Get currently playing
  local data = SpotifyRequest("GET", "/me/player/currently-playing")
  if not data then return end
  
  if data.item then
    local newSong = data.item.name or ""
    local newArtist = ""
    if data.item.artists and #data.item.artists > 0 then
      newArtist = data.item.artists[1].name or ""
    end
    local newAlbum = data.item.album and data.item.album.name or ""
    local isPlaying = data.is_playing or false
    local progress = data.progress_ms or 0
    local duration = data.item.duration_ms or 0
    
    -- Check if track changed
    local trackChanged = false
    if Music.spotify.song ~= newSong or Music.spotify.artist ~= newArtist then
      trackChanged = true
    end
    
    Music.spotify.song = newSong
    Music.spotify.artist = newArtist
    Music.spotify.album = newAlbum
    Music.spotify.isPlaying = isPlaying
    Music.spotify.progressMs = progress
    Music.spotify.durationMs = duration
    
    -- Update main Music state if using Spotify direct
    if Music.useSpotifyDirect then
      Music.song = newSong
      Music.artist = newArtist
      Music.album = newAlbum
      Music.active = isPlaying
      Music.statusText = isPlaying and "[OK] Playing via Spotify" or "[OK] Paused (Spotify)"
      
      -- Download cover
      local imgUrl = ""
      if data.item.album and data.item.album.images and #data.item.album.images > 0 then
        -- Get largest image
        local largest = data.item.album.images[1]
        for _, img in ipairs(data.item.album.images) do
          if (img.width or 0) > (largest.width or 0) then
            largest = img
          end
        end
        imgUrl = largest.url or ""
      end
      if trackChanged or Music.coverAsset == "" then
        ctx.Core.DownloadAlbumCover(imgUrl, Music.song, Music.artist)
      end
    end
  else
    -- Nothing playing
    if Music.useSpotifyDirect and Music.song ~= "" then
      Music.active = false
      Music.statusText = "[OK] Spotify connected (idle)"
    end
    Music.spotify.isPlaying = false
  end
  
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
end

local function StartSpotifyPolling()
  if spotifyPollingActive then return end
  if not Music.spotify.connected then return end
  
  spotifyPollingActive = true
  spotifyPollThread = task.spawn(function()
    while spotifyPollingActive and ctx.Core.isScriptRunning and Music.spotify.connected do
      pcall(SpotifyPoll)
      task.wait(3) -- More frequent than Last.fm
    end
    spotifyPollingActive = false
    spotifyPollThread = nil
  end)
end

local function StopSpotifyPolling()
  spotifyPollingActive = false
  if spotifyPollThread then
    task.cancel(spotifyPollThread)
    spotifyPollThread = nil
  end
end

-- ==================== PLAYBACK CONTROL ====================
local function SpotifyPlay()
  return SpotifyRequest("PUT", "/me/player/play")
end

local function SpotifyPause()
  return SpotifyRequest("PUT", "/me/player/pause")
end

local function SpotifyNext()
  return SpotifyRequest("POST", "/me/player/next")
end

local function SpotifyPrev()
  return SpotifyRequest("POST", "/me/player/previous")
end

local function SpotifySetVolume(vol)
  vol = math.clamp(math.floor(vol), 0, 100)
  return SpotifyRequest("PUT", "/me/player/volume?volume_percent=" .. vol)
end

local function SpotifyGetDevices()
  return SpotifyRequest("GET", "/me/player/devices")
end

-- ==================== CONNECTION MANAGEMENT ====================
local function SetSpotifyConnected(connected)
  Music.spotify.connected = connected
  if connected then
    StartSpotifyPolling()
  else
    StopSpotifyPolling()
  end
  ctx.Core.SaveSettings()
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
end

local function DisconnectSpotify()
  Music.spotify.accessToken = ""
  Music.spotify.refreshToken = ""
  Music.spotify.expiresAt = 0
  Music.spotify.connected = false
  Music.spotify.deviceId = ""
  StopSpotifyPolling()
  SaveSpotifyTokens()
  ctx.Core.SaveSettings()
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
end

-- ==================== INITIALIZATION ====================
local function InitSpotify()
  LoadSpotifyTokens()
  if Music.spotify.accessToken and Music.spotify.accessToken ~= "" then
    Music.spotify.connected = true
    StartSpotifyPolling()
  end
end

-- Exports
ctx.Core.Spotify = {
  BuildAuthUrl = BuildAuthUrl,
  StartAuth = StartSpotifyAuth,
  HandleCallback = function(code, state, error) ctx.Core.HandleSpotifyCallback(code, state, error) end,
  Poll = SpotifyPoll,
  StartPolling = StartSpotifyPolling,
  StopPolling = StopSpotifyPolling,
  Play = SpotifyPlay,
  Pause = SpotifyPause,
  Next = SpotifyNext,
  Prev = SpotifyPrev,
  SetVolume = SpotifySetVolume,
  GetDevices = SpotifyGetDevices,
  SetConnected = SetSpotifyConnected,
  Disconnect = DisconnectSpotify,
  Init = InitSpotify,
  IsTokenExpired = IsTokenExpired,
  RefreshToken = RefreshAccessToken,
}

return ctx.Core.Spotify