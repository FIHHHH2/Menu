-- UniMenu Last.fm Module
-- Handles Last.fm API polling and track detection

local ctx = ...
local HttpService = ctx.Services.HttpService

local Music = ctx.State.Music
local lastTrackData = nil -- {song, artist, album, active, timestamp}

-- ==================== URL ENCODING ====================
local function UrlEncode(str)
  return string.gsub(tostring(str), "([^%w_%-.~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
end

ctx.Core.UrlEncode = UrlEncode

-- ==================== HTTP WRAPPER ====================
local function MusicHTTP(url)
  -- Try multiple HTTP methods available in executors
  local methods = {
    function(u) return { Body = game:HttpGet(u) } end,
    function(u) return { Body = httpget(u) } end,
    function(u) return request({ Url = u, Method = "GET" }) end,
    function(u) return syn and syn.request({ Url = u, Method = "GET" }) end,
  }

  for _, method in ipairs(methods) do
    local ok, res = pcall(method, url)
    if ok and res and (res.Body or res.body) then
      return { Body = res.Body or res.body }
    end
  end
  return nil
end

ctx.Core.MusicHTTP = MusicHTTP

-- ==================== LAST.FM POLLING ====================
local function LastfmPoll()
  if Music.user == "" then return end
  local url = "https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user="
      .. UrlEncode(Music.user)
      .. "&api_key=" .. Music.apiKey
      .. "&format=json&limit=1"

  local res = MusicHTTP(url)
  if not res or not res.Body then
    local fallbackUrl = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user="
        .. UrlEncode(Music.user)
        .. "&api_key=" .. Music.apiKey
        .. "&format=json&limit=1"
    res = MusicHTTP(fallbackUrl)
  end

  if not res or not res.Body then
    Music.statusText = "[ERR] HTTP GET failed (no executor HTTP method responded)"
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
    return
  end

  local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
  if not ok or not data then
    Music.statusText = "[ERR] Failed to decode JSON response"
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
    return
  end

  if data.error then
    Music.statusText = "[ERR] " .. tostring(data.message or ("Error code " .. tostring(data.error)))
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
    return
  end

  if not data.recenttracks then
    Music.statusText = "[ERR] No recent tracks found for user"
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
    return
  end

  local tracks = data.recenttracks.track
  local t = nil
  if typeof(tracks) == "table" then
    t = tracks[1] or tracks
  end

  if t and t.name then
    local newSong = tostring(t.name)
    local art = (t.artist and (t.artist["#text"] or t.artist.name or tostring(t.artist))) or ""
    local newArtist = tostring(art)
    local newAlbum = (t.album and (t.album["#text"] or tostring(t.album))) or ""
    local newActive = (t["@attr"] and t["@attr"].nowplaying == "true") or false
    
    -- Check if track actually changed
    local trackChanged = false
    if not lastTrackData then
      trackChanged = true
    elseif lastTrackData.song ~= newSong or lastTrackData.artist ~= newArtist then
      trackChanged = true
    elseif lastTrackData.active ~= newActive then
      trackChanged = true
    end
    
    -- Debug logging
    if trackChanged then
      print("[Last.fm] Track changed:", newSong, "-", newArtist, "| Active:", newActive, "| Prev:", lastTrackData and lastTrackData.song or "nil")
    elseif lastTrackData then
      print("[Last.fm] Poll: same track", newSong, "-", newArtist, "| Active:", newActive)
    end
    
    -- Update state
    Music.song = newSong
    Music.artist = newArtist
    Music.album = newAlbum
    Music.active = newActive
    Music.statusText = newActive and "[OK] Scrobbling live from Spotify" or
        "[OK] Connected (Idle / Last played track)"
    
    lastTrackData = {
      song = newSong,
      artist = newArtist,
      album = newAlbum,
      active = newActive,
      timestamp = os.time()
    }

    -- Extract album cover image URL
    local imgUrl = ""
    if t.image and typeof(t.image) == "table" then
      for _, img in ipairs(t.image) do
        if img["#text"] and img["#text"] ~= "" then
          imgUrl = img["#text"]
        end
      end
    end
    
    -- Download cover if track changed or cover missing
    if trackChanged or Music.coverAsset == "" then
      ctx.Core.DownloadAlbumCover(imgUrl, Music.song, Music.artist)
    end
  else
    -- No track playing
    if lastTrackData and lastTrackData.song ~= "" then
      -- Track just ended, keep showing last track with paused indicator
      Music.active = false
      Music.statusText = "[OK] Connected (Idle / Last played track)"
      lastTrackData.active = false
      if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
    elseif Music.song == "" then
      Music.song = ""
      Music.artist = ""
      Music.active = false
      Music.coverAsset = ""
      Music.coverIsProcedural = false
      Music.statusText = "[OK] Connected (no scrobbles yet)"
      ctx.Core.RevertToDefaultTheme()
    end
  end
  
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
end

-- ==================== POLLING CONTROL ====================
local lastfmPollingActive = false
local lastfmPollThread = nil

local function StartLastfmPolling()
  if lastfmPollingActive then return end
  lastfmPollingActive = true
  
  lastfmPollThread = task.spawn(function()
    while lastfmPollingActive and ctx.Core.isScriptRunning do
      if Music.user ~= "" then
        LastfmPoll()
      end
      task.wait(4)
    end
    lastfmPollingActive = false
    lastfmPollThread = nil
  end)
end

local function StopLastfmPolling()
  lastfmPollingActive = false
  if lastfmPollThread then
    task.cancel(lastfmPollThread)
    lastfmPollThread = nil
  end
end

local function ForceLastfmPoll()
  if Music.user ~= "" then
    LastfmPoll()
  end
end

-- Exports
ctx.Core.StartLastfmPolling = StartLastfmPolling
ctx.Core.StopLastfmPolling = StopLastfmPolling
ctx.Core.LastfmPoll = LastfmPoll
ctx.Core.ForceLastfmPoll = ForceLastfmPoll
ctx.Core.LastfmPollingActive = function() return lastfmPollingActive end

return {
  StartLastfmPolling = StartLastfmPolling,
  StopLastfmPolling = StopLastfmPolling,
  LastfmPoll = LastfmPoll,
  ForceLastfmPoll = ForceLastfmPoll,
  LastfmPollingActive = function() return lastfmPollingActive end,
}