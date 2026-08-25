-- Music_Handler.lua
-- Robust Music Engine: Last.fm (Public Scrobbler) + Spotify (OAuth / Refresh / Permanent)
-- Real-Time Synced Lyrics (LRCLIB), High-Threshold 28-Bar Equalizer, Overhead Billboard, & Resizable Drag HUD

return function(Shared)
    local Http        = Shared.Services.Http
    local Player      = Shared.Player
    local RunSvc      = Shared.Services.RunService
    local UserInput   = Shared.Services.UserInput
    local TweenSvc    = Shared.Services.TweenService
    local MarketSvc   = game:GetService("MarketplaceService")

    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end

    local tab = Tabs["Music"]
    local cols = QuadCols["Music"]
    if not tab or not cols then
        warn("[Music_Handler] Tabs['Music'] or QuadCols['Music'] not found!")
        return
    end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    -- Forward declarations to ensure zero nil-function reference errors
    local updateVisuals, buildBillboard, buildHUD, startPolling
    local getSpotifyTrack, getLastFMTrack, refreshSpotifyToken, spotifyRequest
    local handleSpotifyPrevious, handleSpotifyPlayPause, handleSpotifyNext
    local fetchSyncedLyrics, applyImage, parseLRC

    -- Verified working Last.fm public API key
    local LASTFM_API_KEY = "b25b959554ed76058ac220b7b2e0a026"
    local currentTrack = {
        name        = "Not Playing",
        artist      = "No Artist",
        cover       = "",
        isPlaying   = false,
        source      = "None",
        progress_ms = 0,
        duration_ms = 0,
        pollTime    = os.clock(),
    }
    Shared.GetCurrentTrack = function() return currentTrack end

    local billboard   = nil
    local hudWidget   = nil
    local pollConn    = nil
    local placeTitle  = "Roblox Place"
    local lastLoadedCoverUrl = ""
    local currentCoverAsset  = ""
    local previousCoverFile  = ""
    local hudVisBars  = {}
    local bbVisBars   = {}

    -- ── REAL-TIME SYNCED LYRICS ENGINE (LRCLIB) ────────────────────
    local currentLyrics = nil
    local lastLyricsQuery = ""
    local hudLyricsLbl, bbLyricsLbl

    parseLRC = function(lrcText)
        if not lrcText or type(lrcText) ~= "string" or #lrcText == 0 then return nil end
        local parsed = {}
        for line in lrcText:gmatch("[^\r\n]+") do
            local min, sec, text = line:match("%[(%d+):(%d+%.?%d*)%](.*)")
            if min and sec then
                local totalSec = (tonumber(min) or 0) * 60 + (tonumber(sec) or 0)
                local cleanText = text:gsub("^%s+", ""):gsub("%s+$", "")
                if #cleanText > 0 then
                    table.insert(parsed, { time = totalSec, text = cleanText })
                end
            end
        end
        table.sort(parsed, function(a, b) return a.time < b.time end)
        return #parsed > 0 and parsed or nil
    end

    fetchSyncedLyrics = function(artist, trackName)
        if not artist or artist == "" or not trackName or trackName == "" then return end
        local queryKey = artist:lower() .. "::" .. trackName:lower()
        if queryKey == lastLyricsQuery then return end
        lastLyricsQuery = queryKey
        currentLyrics = nil

        task.spawn(function()
            local url = "https://lrclib.net/api/get?artist_name=" .. Http:UrlEncode(artist) .. "&track_name=" .. Http:UrlEncode(trackName)
            local resp = Shared.HttpRequest({
                Url = url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "FihUI/2.0 (Roblox Client)"
                }
            })
            if resp and resp.Body and #resp.Body > 5 then
                local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
                if ok and data then
                    if data.syncedLyrics and #data.syncedLyrics > 0 then
                        currentLyrics = parseLRC(data.syncedLyrics)
                    elseif data.plainLyrics and #data.plainLyrics > 0 then
                        currentLyrics = { { time = 0, text = data.plainLyrics:match("^[^\r\n]+") or data.plainLyrics } }
                    end
                end
            end
        end)
    end

    -- Fetch place name asynchronously
    task.spawn(function()
        local ok, info = pcall(function() return MarketSvc:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then
            placeTitle = info.Name
        end
    end)

    -- ── PROVEN MULTI-METHOD COVER PIPELINE ──────────────────────
    local function CoverHTTP(url)
        if not url or url == "" then return nil end

        local reqFn = (typeof(request) == "function" and request)
                   or (typeof(http_request) == "function" and http_request)
                   or (getgenv and typeof(getgenv().request) == "function" and getgenv().request)
                   or (typeof(syn) == "table" and syn.request)
                   or (typeof(http) == "table" and http.request)

        if reqFn then
            local ok1, res1 = pcall(reqFn, { Url = url, Method = "GET" })
            if ok1 and res1 then
                local b = res1.Body or res1.body
                if b and type(b) == "string" and #b > 1000 then return b end
            end
            local ok2, res2 = pcall(reqFn, { url = url, method = "GET" })
            if ok2 and res2 then
                local b = res2.Body or res2.body
                if b and type(b) == "string" and #b > 1000 then return b end
            end
        end

        local ok3, body3 = pcall(function() return game:HttpGet(url) end)
        if ok3 and body3 and type(body3) == "string" and #body3 > 1000 then return body3 end

        local res4 = Shared.HttpRequest({ Url = url, Method = "GET" })
        if res4 then
            local b = res4.Body or res4.body
            if b and type(b) == "string" and #b > 1000 then return b end
        end

        return nil
    end

    local function isValidImageData(data)
        if not data or type(data) ~= "string" or #data < 1000 then return false end
        local h = data:sub(1, 16)
        if h:sub(1, 8) == "\137PNG\r\n\26\n" then return true end
        if h:sub(1, 3) == "\255\216\255" then return true end
        if h:sub(1, 6) == "GIF87a" or h:sub(1, 6) == "GIF89a" then return true end
        if h:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WEBP" then return true end
        return false
    end

    local function fetchArtworkFallback(artist, song)
        if not artist or artist == "" or not song or song == "" then return "" end
        local term = artist .. " " .. song
        local url = "https://itunes.apple.com/search?term=" .. Http:UrlEncode(term) .. "&media=music&limit=1"
        local resp = Shared.HttpRequest({ Url = url, Method = "GET" })
        if resp and resp.Body and #resp.Body > 0 then
            local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
            if ok and data and data.results and data.results[1] and data.results[1].artworkUrl100 then
                return data.results[1].artworkUrl100:gsub("100x100bb", "600x600bb")
            end
        end
        return ""
    end

    applyImage = function(imgLabel, track)
        if not imgLabel or not imgLabel.Parent then return end
        local url = track and track.cover or ""
        if not url or url == "" then
            if track and track.artist and track.name and track.artist ~= "No Artist" and track.name ~= "Not Playing" then
                task.spawn(function()
                    local fallback = fetchArtworkFallback(track.artist, track.name)
                    if fallback and fallback ~= "" and fallback ~= url then
                        track.cover = fallback
                        applyImage(imgLabel, track)
                    end
                end)
            end
            imgLabel.Visible = false
            return
        end

        if url == lastLoadedCoverUrl and currentCoverAsset ~= "" then
            pcall(function()
                imgLabel.Image = currentCoverAsset
                imgLabel.Visible = true
            end)
            return
        end

        task.spawn(function()
            local rawData = CoverHTTP(url)
            if not rawData or not isValidImageData(rawData) then
                if track and track.artist and track.name then
                    local fallback = fetchArtworkFallback(track.artist, track.name)
                    if fallback and fallback ~= "" and fallback ~= url then
                        track.cover = fallback
                        rawData = CoverHTTP(fallback)
                    end
                end
            end

            if not rawData or not isValidImageData(rawData) then
                pcall(function() imgLabel.Visible = false end)
                return
            end

            local filename = "fih_cover_" .. tostring(os.time()) .. ".png"
            local writeSuccess = false
            if typeof(writefile) == "function" then
                pcall(function()
                    writefile(filename, rawData)
                    writeSuccess = true
                end)
            end

            local asset = ""
            if writeSuccess and typeof(getcustomasset) == "function" then
                pcall(function() asset = getcustomasset(filename) end)
            end

            if not asset or asset == "" then
                asset = url
            end

            if previousCoverFile ~= "" and previousCoverFile ~= filename and typeof(delfile) == "function" then
                pcall(function() delfile(previousCoverFile) end)
            end
            previousCoverFile   = filename
            lastLoadedCoverUrl  = url
            currentCoverAsset   = asset

            if imgLabel and imgLabel.Parent then
                imgLabel.Image = asset
                imgLabel.Visible = true
            end
        end)
    end
    Shared.ApplyArtworkImage = applyImage

    -- ── STRING / TOKEN CLEANER ──────────────────────────────────────
    local function cleanToken(tok)
        if not tok or type(tok) ~= "string" then return "" end
        tok = tok:gsub("^%s+", ""):gsub("%s+$", "")
        if tok:sub(1, 7):lower() == "bearer " then
            tok = tok:sub(8)
        end
        if tok:find("^Paste ") or tok:find("^Permanent Refresh Token: ") or tok:find("^Access Token: ") then
            return ""
        end
        return tok
    end

    -- ── BASE64 ENCODER (BIT-SAFE) ──────────────────────────────────
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local function toBase64(data)
        if crypt and typeof(crypt.base64_encode) == "function" then
            return crypt.base64_encode(data)
        elseif crypt and typeof(crypt.base64encode) == "function" then
            return crypt.base64encode(data)
        elseif syn and syn.crypt and typeof(syn.crypt.base64.encode) == "function" then
            return syn.crypt.base64.encode(data)
        end
        return ((data:gsub('.', function(x) 
            local r,b='',x:byte()
            for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
            return r;
        end)..'0000'):gsub('%d%d%d?%d?%d?', function(x)
            if (#x < 6) then return '' end
            local c=0
            for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
            return b64chars:sub(c+1,c+1)
        end)..({ '', '==', '=' })[#data%3+1])
    end

    -- ── OPTION 2: SPOTIFY OAUTH ENGINE ─────────────────────────────
    local isRefreshingToken = false
    refreshSpotifyToken = function()
        local raw = cleanToken(Shared.Config.SpotifyRefreshToken)

        -- Parse combined paste "token|clientId|clientSecret"
        if raw:find("|") or raw:find(":::") then
            local sep = raw:find(":::") and ":::" or "|"
            local parts = raw:split(sep)
            if parts[1] and parts[1] ~= "" then Shared.Config.SpotifyRefreshToken = cleanToken(parts[1]) end
            if parts[2] and parts[2] ~= "" then Shared.Config.SpotifyClientId     = cleanToken(parts[2]) end
            if parts[3] and parts[3] ~= "" then Shared.Config.SpotifyClientSecret = cleanToken(parts[3]) end
            if Shared.SaveConfig then Shared.SaveConfig() end
            raw = cleanToken(Shared.Config.SpotifyRefreshToken)
        end

        local rToken = raw
        local aToken = cleanToken(Shared.Config.SpotifyToken)

        -- Direct Access Token support
        if rToken:sub(1, 2) == "BQ" or (#rToken > 160 and rToken:sub(1, 2) ~= "AQ") then
            Shared.Config.SpotifyToken = rToken
            return true, rToken
        end

        if not rToken or rToken == "" then
            if aToken ~= "" then return true, aToken end
            return false, "No Token — paste Refresh Token or Access Token"
        end

        if isRefreshingToken then return false, "Refresh in progress" end
        isRefreshingToken = true

        local clientId  = (Shared.Config.SpotifyClientId and cleanToken(Shared.Config.SpotifyClientId) ~= "") and cleanToken(Shared.Config.SpotifyClientId) or "1842aff694404946af4ac03a457c54ab"
        local clientSec = (Shared.Config.SpotifyClientSecret and cleanToken(Shared.Config.SpotifyClientSecret) ~= "") and cleanToken(Shared.Config.SpotifyClientSecret) or "b90742dc54544188a5e2f88d5383bd3c"

        local authHeader = "Basic " .. toBase64(clientId .. ":" .. clientSec)
        local resp = Shared.HttpRequest({
            Url     = "https://accounts.spotify.com/api/token",
            Method  = "POST",
            Headers = {
                ["Content-Type"]  = "application/x-www-form-urlencoded",
                ["Authorization"] = authHeader,
            },
            Body    = "grant_type=refresh_token&refresh_token=" .. Http:UrlEncode(rToken) .. "&client_id=" .. clientId,
        })

        -- Fallback to Body Auth if Basic header rejected
        if not resp or not resp.Body or resp.Body:find("invalid_client") then
            resp = Shared.HttpRequest({
                Url     = "https://accounts.spotify.com/api/token",
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
                Body    = "grant_type=refresh_token&refresh_token=" .. Http:UrlEncode(rToken)
                       .. "&client_id=" .. Http:UrlEncode(clientId)
                       .. "&client_secret=" .. Http:UrlEncode(clientSec),
            })
        end

        isRefreshingToken = false

        if resp and resp.Body then
            local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
            if ok and data then
                if data.access_token then
                    Shared.Config.SpotifyToken = data.access_token
                    if data.refresh_token then
                        Shared.Config.SpotifyRefreshToken = data.refresh_token
                    end
                    if Shared.SaveConfig then Shared.SaveConfig() end
                    return true, data.access_token
                elseif data.error_description then
                    return false, data.error_description
                elseif data.error then
                    return false, tostring(data.error)
                end
            end
        end
        return false, (resp and resp.Body) or "Network error"
    end

    spotifyRequest = function(endpoint, method, body, hasRetried)
        local token = cleanToken(Shared.Config.SpotifyToken)
        if not token or token == "" then
            if Shared.Config.SpotifyRefreshToken and not hasRetried then
                local ok = refreshSpotifyToken()
                if ok then return spotifyRequest(endpoint, method, body, true) end
            end
            return nil, "No Token"
        end

        local payload = body and Http:JSONEncode(body) or ""
        local resp = Shared.HttpRequest({
            Url     = "https://api.spotify.com/v1/me/player" .. endpoint,
            Method  = method or "GET",
            Headers = {
                ["Authorization"]  = "Bearer " .. token,
                ["Content-Type"]   = "application/json",
                ["Content-Length"] = tostring(#payload),
            },
            Body    = payload ~= "" and payload or nil,
        })

        if resp and resp.StatusCode == 401 and not hasRetried and Shared.Config.SpotifyRefreshToken then
            local ok = refreshSpotifyToken()
            if ok then
                return spotifyRequest(endpoint, method, body, true)
            end
        end

        return resp
    end

    getSpotifyTrack = function(hasRetried)
        local token = cleanToken(Shared.Config.SpotifyToken)
        if not token or token == "" then
            if Shared.Config.SpotifyRefreshToken and not hasRetried then
                local ok = refreshSpotifyToken()
                if ok then return getSpotifyTrack(true) end
            end
            return nil, "No Token"
        end

        local resp = Shared.HttpRequest({
            Url     = "https://api.spotify.com/v1/me/player/currently-playing?additional_types=track,episode",
            Method  = "GET",
            Headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-Type"]  = "application/json",
            },
        })

        if resp and resp.StatusCode == 401 and not hasRetried and Shared.Config.SpotifyRefreshToken then
            local ok = refreshSpotifyToken()
            if ok then
                return getSpotifyTrack(true)
            end
            return nil, "Expired/Invalid Token (401)"
        end

        local item = nil
        local isPlaying = false
        local progress_ms = 0
        local duration_ms = 0

        if resp and resp.Body and #resp.Body > 5 then
            local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
            if ok and data and data.item then
                item = data.item
                isPlaying = (data.is_playing == true)
                progress_ms = data.progress_ms or 0
                duration_ms = item.duration_ms or 0
            end
        end

        -- Fallback to recently-played if currently-playing is idle (204)
        if not item then
            local recResp = Shared.HttpRequest({
                Url     = "https://api.spotify.com/v1/me/player/recently-played?limit=1",
                Method  = "GET",
                Headers = {
                    ["Authorization"] = "Bearer " .. token,
                    ["Content-Type"]  = "application/json",
                },
            })
            if recResp and recResp.Body and #recResp.Body > 5 then
                local ok, data = pcall(function() return Http:JSONDecode(recResp.Body) end)
                if ok and data and data.items and data.items[1] and data.items[1].track then
                    item = data.items[1].track
                    isPlaying = false
                    progress_ms = 0
                    duration_ms = item.duration_ms or 0
                end
            end
        end

        if not item then
            return nil, "No Track Found (Play a track in Spotify)"
        end

        local trackName  = item.name or "Unknown"
        local artistName = item.artists and item.artists[1] and item.artists[1].name or "Unknown"

        local coverUrl = ""
        if item.album and item.album.images and #item.album.images > 0 then
            coverUrl = item.album.images[1].url or ""
        elseif item.images and #item.images > 0 then
            coverUrl = item.images[1].url or ""
        end

        if not coverUrl or coverUrl == "" then
            coverUrl = fetchArtworkFallback(artistName, trackName)
        end

        return {
            id          = item.id or "",
            name        = trackName,
            artist      = artistName,
            cover       = coverUrl,
            isPlaying   = isPlaying,
            progress_ms = progress_ms,
            duration_ms = duration_ms,
            pollTime    = os.clock(),
            source      = "Spotify"
        }
    end

    -- ── OPTION 1: LAST.FM SCROBBLER ────────────────────────────────
    getLastFMTrack = function()
        local user = Shared.Config.LastFMUser
        if not user or user == "" or user == "Enter Last.fm Username" then return nil end
        local url = "https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=" .. Http:UrlEncode(user) .. "&api_key=" .. LASTFM_API_KEY .. "&format=json&limit=1"
        local resp = Shared.HttpRequest({
            Url = url,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
            }
        })
        if not resp or not resp.Body or #resp.Body == 0 then return nil end
        local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
        if not ok or not data or not data.recenttracks or not data.recenttracks.track then return nil end

        local track = data.recenttracks.track
        if type(track) == "table" and track[1] then
            track = track[1]
        end
        if not track or type(track) ~= "table" then return nil end

        local isNowPlaying = (track["@attr"] and track["@attr"].nowplaying == "true") or false
        local trackName = track.name or "Unknown"
        local artistName = "Unknown"
        if type(track.artist) == "table" then
            artistName = track.artist["#text"] or track.artist.name or "Unknown"
        elseif type(track.artist) == "string" then
            artistName = track.artist
        end

        local coverUrl = ""
        if track.image and type(track.image) == "table" and #track.image > 0 then
            for i = #track.image, 1, -1 do
                local imgObj = track.image[i]
                if type(imgObj) == "table" and imgObj["#text"] and #imgObj["#text"] > 0 then
                    coverUrl = imgObj["#text"]
                    break
                end
            end
        end

        if not coverUrl or coverUrl == "" then
            coverUrl = fetchArtworkFallback(artistName, trackName)
        end

        return {
            id          = "",
            name        = trackName,
            artist      = artistName,
            cover       = coverUrl,
            isPlaying   = isNowPlaying,
            progress_ms = 0,
            duration_ms = 0,
            pollTime    = os.clock(),
            source      = "Last.fm"
        }
    end

    -- ── PLAYBACK CONTROLS (⏮ ⏯ ⏭) ──────────────────────────────────
    handleSpotifyPrevious = function()
        task.spawn(function()
            local token = cleanToken(Shared.Config.SpotifyToken)
            if not token or token == "" then
                Shared.Notify("Spotify", "[!] No OAuth Token configured", false)
                return
            end
            local resp = spotifyRequest("/previous", "POST")
            if resp and (resp.StatusCode == 204 or resp.StatusCode == 200) then
                Shared.Notify("Spotify", "[|<] Previous track", true)
            else
                Shared.Notify("Spotify", "[!] Previous requires Spotify Premium & active player", false)
            end
            task.wait(0.4)
            local trk = getSpotifyTrack()
            if trk then updateVisuals(trk) end
        end)
    end

    handleSpotifyPlayPause = function()
        task.spawn(function()
            local token = cleanToken(Shared.Config.SpotifyToken)
            if not token or token == "" then
                Shared.Notify("Spotify", "[!] No OAuth Token configured", false)
                return
            end
            local statusResp = Shared.HttpRequest({
                Url     = "https://api.spotify.com/v1/me/player",
                Method  = "GET",
                Headers = { ["Authorization"] = "Bearer " .. token }
            })
            local isCurrentlyPlaying = false
            if statusResp and statusResp.Body and #statusResp.Body > 0 then
                local ok, d = pcall(function() return Http:JSONDecode(statusResp.Body) end)
                if ok and d and d.is_playing ~= nil then
                    isCurrentlyPlaying = d.is_playing
                end
            end

            local endpoint = isCurrentlyPlaying and "/pause" or "/play"
            local resp = spotifyRequest(endpoint, "PUT")
            if resp and (resp.StatusCode == 204 or resp.StatusCode == 200) then
                currentTrack.isPlaying = not isCurrentlyPlaying
                Shared.Notify("Spotify", isCurrentlyPlaying and "[||] Paused" or "[>] Playing", true)
            else
                Shared.Notify("Spotify", "[!] Remote play/pause requires Spotify Premium", false)
            end
            task.wait(0.4)
            local trk = getSpotifyTrack()
            if trk then updateVisuals(trk) end
        end)
    end

    handleSpotifyNext = function()
        task.spawn(function()
            local token = cleanToken(Shared.Config.SpotifyToken)
            if not token or token == "" then
                Shared.Notify("Spotify", "[!] No OAuth Token configured", false)
                return
            end
            local resp = spotifyRequest("/next", "POST")
            if resp and (resp.StatusCode == 204 or resp.StatusCode == 200) then
                Shared.Notify("Spotify", "[>|] Next track", true)
            else
                Shared.Notify("Spotify", "[!] Skip requires Spotify Premium & active player", false)
            end
            task.wait(0.4)
            local trk = getSpotifyTrack()
            if trk then updateVisuals(trk) end
        end)
    end

    -- ── OVERHEAD BILLBOARD (305x70px) ──────────────────────────────
    local bbSongLbl, bbArtistLbl, bbCoverImg

    buildBillboard = function()
        if billboard then billboard:Destroy(); billboard = nil end

        local char = Shared.Character or Player.Character
        if not char then return end
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not head then return end

        billboard = Instance.new("BillboardGui")
        billboard.Name                   = "MusicBillboard"
        billboard.Size                   = UDim2.new(0, 305, 0, 72)
        billboard.StudsOffsetWorldSpace  = Vector3.new(0, 4.2, 0)
        billboard.AlwaysOnTop            = (Shared.Flags and Shared.Flags["UniversalESP"]) or false
        billboard.Active                 = true
        billboard.MaxDistance            = 75
        billboard.LightInfluence         = 0
        billboard.Adornee                = head
        billboard.Parent                 = Shared.GUI

        local bg = Instance.new("Frame")
        bg.Size                 = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3     = Color3.fromRGB(15, 18, 24)
        bg.BackgroundTransparency = 0.15
        bg.BorderSizePixel      = 1
        bg.BorderColor3         = Color3.fromRGB(0, 160, 255)
        bg.ClipsDescendants     = true
        bg.Parent               = billboard

        local bbCoverContainer = Instance.new("Frame")
        bbCoverContainer.Size             = UDim2.new(0, 56, 0, 56)
        bbCoverContainer.Position         = UDim2.new(0, 7, 0, 7)
        bbCoverContainer.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
        bbCoverContainer.BorderSizePixel  = 1
        bbCoverContainer.BorderColor3     = Color3.fromRGB(60, 80, 110)
        bbCoverContainer.Parent           = bg

        local bbNote = Instance.new("TextLabel")
        bbNote.Size                   = UDim2.new(1, 0, 1, 0)
        bbNote.BackgroundTransparency = 1
        bbNote.Text                   = "[♪]"
        bbNote.Font                   = Enum.Font.Code
        bbNote.TextSize               = 14
        bbNote.TextColor3             = Color3.fromRGB(100, 130, 180)
        bbNote.TextTransparency       = 0.3
        bbNote.Parent                 = bbCoverContainer

        local cover = Instance.new("ImageLabel")
        cover.Name                    = "CoverArt"
        cover.Size                    = UDim2.new(1, 0, 1, 0)
        cover.BackgroundTransparency  = 1
        cover.BorderSizePixel         = 0
        cover.ScaleType               = Enum.ScaleType.Crop
        cover.Parent                  = bbCoverContainer
        bbCoverImg = cover

        local songLbl = Instance.new("TextLabel")
        songLbl.Size                  = UDim2.new(1, -165, 0, 16)
        songLbl.Position              = UDim2.new(0, 68, 0, 6)
        songLbl.BackgroundTransparency = 1
        songLbl.Text                  = currentTrack.name
        songLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
        songLbl.Font                  = Enum.Font.ArimoBold
        songLbl.TextSize              = 11
        songLbl.TextXAlignment        = Enum.TextXAlignment.Left
        songLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        songLbl.Parent                = bg
        bbSongLbl = songLbl

        local artistLbl = Instance.new("TextLabel")
        artistLbl.Size                  = UDim2.new(1, -165, 0, 14)
        artistLbl.Position              = UDim2.new(0, 68, 0, 22)
        artistLbl.BackgroundTransparency = 1
        artistLbl.Text                  = currentTrack.artist .. " [" .. currentTrack.source .. "]"
        artistLbl.TextColor3            = Color3.fromRGB(0, 220, 140)
        artistLbl.Font                  = Enum.Font.Code
        artistLbl.TextSize              = 9
        artistLbl.TextXAlignment        = Enum.TextXAlignment.Left
        artistLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        artistLbl.Parent                = bg
        bbArtistLbl = artistLbl

        -- Synced Live Lyrics on Billboard
        local lyLbl = Instance.new("TextLabel")
        lyLbl.Size                  = UDim2.new(1, -165, 0, 14)
        lyLbl.Position              = UDim2.new(0, 68, 0, 36)
        lyLbl.BackgroundTransparency = 1
        lyLbl.Text                  = "♪ Synchronizing..."
        lyLbl.TextColor3            = Color3.fromRGB(255, 235, 120)
        lyLbl.Font                  = Enum.Font.Code
        lyLbl.TextSize              = 9
        lyLbl.TextXAlignment        = Enum.TextXAlignment.Left
        lyLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        lyLbl.Parent                = bg
        bbLyricsLbl = lyLbl

        -- ── BILLBOARD 10-BAR AUDIO EQUALIZER ──
        local bbVisualizer = Instance.new("Frame")
        bbVisualizer.Name                   = "BB_Visualizer"
        bbVisualizer.Size                   = UDim2.new(0, 75, 0, 14)
        bbVisualizer.Position               = UDim2.new(0, 68, 0, 52)
        bbVisualizer.BackgroundTransparency = 1
        bbVisualizer.BorderSizePixel        = 0
        bbVisualizer.Parent                 = bg

        bbVisBars = {}
        for i = 1, 10 do
            local bar = Instance.new("Frame")
            bar.Size = UDim2.new(0, 5, 0, 3)
            bar.Position = UDim2.new(0, (i - 1) * 7, 1, 0)
            bar.AnchorPoint = Vector2.new(0, 1)
            bar.BackgroundColor3 = Color3.fromRGB(0, 220, 140)
            bar.BorderSizePixel = 0
            bar.Parent = bbVisualizer
            bbVisBars[i] = bar
        end

        -- ── BILLBOARD PLAYBACK CONTROLS (⏮ ⏯ ⏭) (IN-BOUNDS) ──
        local ctrlBox = Instance.new("Frame")
        ctrlBox.Size                  = UDim2.new(0, 84, 0, 24)
        ctrlBox.Position              = UDim2.new(1, -92, 0.5, -12)
        ctrlBox.BackgroundTransparency = 1
        ctrlBox.BorderSizePixel       = 0
        ctrlBox.Parent                = bg

        local function mkBBCtrlBtn(txt, posX, fn)
            local btn = Instance.new("TextButton")
            btn.Size                  = UDim2.new(0, 25, 0, 22)
            btn.Position              = UDim2.new(0, posX, 0, 1)
            btn.BackgroundColor3      = Color3.fromRGB(25, 30, 42)
            btn.BackgroundTransparency = 0.1
            btn.BorderSizePixel       = 1
            btn.BorderColor3          = Color3.fromRGB(0, 160, 255)
            btn.Text                  = txt
            btn.TextColor3            = Color3.fromRGB(255, 255, 255)
            btn.Font                  = Enum.Font.GothamBold
            btn.TextSize              = 10
            btn.Active                = true
            btn.Selectable            = true
            btn.AutoButtonColor       = true
            btn.ZIndex                = 20
            btn.Parent                = ctrlBox

            btn.MouseButton1Click:Connect(function()
                TweenSvc:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = Color3.fromRGB(0, 180, 255) }):Play()
                task.delay(0.12, function()
                    TweenSvc:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(25, 30, 42) }):Play()
                end)
                fn()
            end)
            return btn
        end

        mkBBCtrlBtn("[|<]", 0, handleSpotifyPrevious)
        mkBBCtrlBtn("[||]", 28, handleSpotifyPlayPause)
        mkBBCtrlBtn("[>|]", 56, handleSpotifyNext)

        applyImage(bbCoverImg, currentTrack)
    end

    -- ── DRAGGABLE & RESIZABLE BOTTOM-LEFT INFO HUD ──────────────────
    local hudSongLbl, hudArtistLbl, hudCoverImg, hudPlaceLbl, hudUserLbl, coverContainerRef, rightBoxRef

    buildHUD = function()
        if hudWidget then hudWidget:Destroy(); hudWidget = nil end

        local isDark = (Shared.IsDark and Shared.IsDark()) or (Shared.Config and Shared.Config.DarkMode == true)
        local C = isDark and {
            WinBorder = Color3.fromRGB(30, 75, 130),
            TitleBar  = Color3.fromRGB(32, 36, 46),
            TitleText = Color3.fromRGB(220, 225, 240),
            BodyBg    = Color3.fromRGB(16, 18, 24),
            BorderCol = Color3.fromRGB(40, 50, 70),
            TextDark  = Color3.fromRGB(235, 240, 250),
            Accent    = Color3.fromRGB(60, 145, 255),
            SubText   = Color3.fromRGB(130, 150, 180),
        } or {
            WinBorder = Color3.fromRGB(58, 110, 165),
            TitleBar  = Color3.fromRGB(212, 208, 200),
            TitleText = Color3.fromRGB(0, 0, 0),
            BodyBg    = Color3.fromRGB(248, 250, 255),
            BorderCol = Color3.fromRGB(180, 190, 210),
            TextDark  = Color3.fromRGB(15, 25, 60),
            Accent    = Color3.fromRGB(0, 120, 40),
            SubText   = Color3.fromRGB(80, 95, 120),
        }

        local frame = Instance.new("Frame")
        frame.Name             = "Fih_BottomHUD"
        frame.Size             = UDim2.new(0, 390, 0, 150)
        frame.Position         = UDim2.new(0, 16, 1, -165)
        frame.BackgroundColor3 = C.BodyBg
        frame.BackgroundTransparency = 0.25
        frame.BorderSizePixel  = 2
        frame.BorderColor3     = C.WinBorder
        frame.ClipsDescendants = true
        frame.ZIndex           = 50
        frame.Parent           = Shared.GUI
        hudWidget = frame

        local tBar = Instance.new("Frame")
        tBar.Size             = UDim2.new(1, 0, 0, 20)
        tBar.BackgroundColor3 = C.TitleBar
        tBar.BackgroundTransparency = 0.20
        tBar.BorderSizePixel  = 1
        tBar.BorderColor3     = Color3.fromRGB(140, 140, 140)
        tBar.ZIndex           = 51
        tBar.Parent           = frame

        local tLbl = Instance.new("TextLabel")
        tLbl.Size                   = UDim2.new(1, -8, 1, 0)
        tLbl.Position               = UDim2.new(0, 6, 0, 0)
        tLbl.BackgroundTransparency = 1
        tLbl.Text                   = "Fih HUD  ::  Now Playing & Synced Lyrics"
        tLbl.TextColor3             = C.TitleText
        tLbl.Font                   = Enum.Font.Code
        tLbl.TextSize               = 11
        tLbl.TextXAlignment         = Enum.TextXAlignment.Left
        tLbl.ZIndex                 = 52
        tLbl.Parent                 = tBar

        -- Dragging logic
        do
            local drag, ds, sp = false, nil, nil
            tBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    drag = true; ds = i.Position; sp = frame.Position
                end
            end)
            tBar.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    drag = false
                end
            end)
            UserInput.InputChanged:Connect(function(i)
                if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                    local d = i.Position - ds
                    frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
                end
            end)
        end

        local content = Instance.new("Frame")
        content.Name             = "HUDContent"
        content.Size             = UDim2.new(1, 0, 1, -20)
        content.Position         = UDim2.new(0, 0, 0, 20)
        content.BackgroundTransparency = 1
        content.ZIndex           = 51
        content.Parent           = frame

        -- ── PROMINENT DYNAMIC RESIZING ALBUM COVER ART ──────────────
        local coverContainer = Instance.new("Frame")
        coverContainer.Name             = "CoverContainer"
        coverContainer.Size             = UDim2.new(0, 118, 1, -12)
        coverContainer.Position         = UDim2.new(0, 6, 0, 6)
        coverContainer.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
        coverContainer.BackgroundTransparency = 0.35
        coverContainer.BorderSizePixel  = 1
        coverContainer.BorderColor3     = C.BorderCol
        coverContainer.ZIndex           = 52
        coverContainer.Parent           = content
        coverContainerRef = coverContainer

        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio = 1.0
        aspect.DominantAxis = Enum.DominantAxis.Height
        aspect.Parent = coverContainer

        local noteIcon = Instance.new("TextLabel")
        noteIcon.Size                   = UDim2.new(1, 0, 1, 0)
        noteIcon.BackgroundTransparency = 1
        noteIcon.Text                   = "[♪]"
        noteIcon.Font                   = Enum.Font.Code
        noteIcon.TextSize               = 24
        noteIcon.TextColor3             = Color3.fromRGB(110, 130, 170)
        noteIcon.TextTransparency       = 0.35
        noteIcon.ZIndex                 = 52
        noteIcon.Parent                 = coverContainer

        local cover = Instance.new("ImageLabel")
        cover.Name                = "CoverArt"
        cover.Size                = UDim2.new(1, 0, 1, 0)
        cover.BackgroundTransparency = 1
        cover.BorderSizePixel     = 0
        cover.ScaleType           = Enum.ScaleType.Crop
        cover.ZIndex              = 53
        cover.Parent              = coverContainer
        hudCoverImg = cover

        -- ── RIGHT TEXT & CONTROLS CONTAINER ─────────────────────────
        local rightBox = Instance.new("Frame")
        rightBox.Name                   = "TextContainer"
        rightBox.Size                   = UDim2.new(1, -140, 1, -8)
        rightBox.Position               = UDim2.new(0, 132, 0, 4)
        rightBox.BackgroundTransparency = 1
        rightBox.ZIndex                 = 52
        rightBox.Parent                 = content
        rightBoxRef = rightBox

        local sLbl = Instance.new("TextLabel")
        sLbl.Size                  = UDim2.new(1, 0, 0, 18)
        sLbl.Position              = UDim2.new(0, 0, 0, 2)
        sLbl.BackgroundTransparency = 1
        sLbl.Text                  = currentTrack.name
        sLbl.TextColor3            = C.TextDark
        sLbl.Font                  = Enum.Font.ArimoBold
        sLbl.TextSize              = 12
        sLbl.TextXAlignment        = Enum.TextXAlignment.Left
        sLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        sLbl.ZIndex                = 53
        sLbl.Parent                = rightBox
        hudSongLbl = sLbl

        local aLbl = Instance.new("TextLabel")
        aLbl.Size                  = UDim2.new(1, 0, 0, 14)
        aLbl.Position              = UDim2.new(0, 0, 0, 20)
        aLbl.BackgroundTransparency = 1
        aLbl.Text                  = currentTrack.artist .. " [" .. currentTrack.source .. "]"
        aLbl.TextColor3            = C.Accent
        aLbl.Font                  = Enum.Font.Code
        aLbl.TextSize              = 10
        aLbl.TextXAlignment        = Enum.TextXAlignment.Left
        aLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        aLbl.ZIndex                = 53
        aLbl.Parent                = rightBox
        hudArtistLbl = aLbl

        -- ── REAL-TIME SYNCED LYRICS LINE DISPLAY ───────────────────
        local lyLbl = Instance.new("TextLabel")
        lyLbl.Name                  = "SyncedLyricsLine"
        lyLbl.Size                  = UDim2.new(1, 0, 0, 16)
        lyLbl.Position              = UDim2.new(0, 0, 0, 36)
        lyLbl.BackgroundTransparency = 1
        lyLbl.Text                  = "♪ Synced lyrics ready..."
        lyLbl.TextColor3            = Color3.fromRGB(255, 230, 110)
        lyLbl.Font                  = Enum.Font.GothamMedium
        lyLbl.TextSize              = 10
        lyLbl.TextXAlignment        = Enum.TextXAlignment.Left
        lyLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        lyLbl.ZIndex                = 53
        lyLbl.Parent                = rightBox
        hudLyricsLbl = lyLbl

        -- ── FULL-WIDTH 28-BAR AUDIO EQUALIZER (SPANS HORIZONTALLY) ──
        local hudVisualizer = Instance.new("Frame")
        hudVisualizer.Name                   = "HUD_Visualizer"
        hudVisualizer.Size                   = UDim2.new(1, -8, 0, 24)
        hudVisualizer.Position               = UDim2.new(0, 0, 0, 54)
        hudVisualizer.BackgroundTransparency = 1
        hudVisualizer.BorderSizePixel        = 0
        hudVisualizer.ZIndex                 = 54
        hudVisualizer.Parent                 = rightBox

        hudVisBars = {}
        for i = 1, 28 do
            local bar = Instance.new("Frame")
            bar.Size = UDim2.new(0, 5, 0, 4)
            bar.Position = UDim2.new(0, (i - 1) * 7, 1, 0)
            bar.AnchorPoint = Vector2.new(0, 1)
            bar.BackgroundColor3 = C.Accent
            bar.BorderSizePixel = 0
            bar.ZIndex = 55
            bar.Parent = hudVisualizer
            hudVisBars[i] = bar
        end

        -- ── HUD PLAYBACK CONTROLS (⏮ ⏯ ⏭) ──
        local hudControls = Instance.new("Frame")
        hudControls.Name                   = "HUD_PlaybackControls"
        hudControls.Size                   = UDim2.new(1, 0, 0, 20)
        hudControls.Position               = UDim2.new(0, 0, 0, 80)
        hudControls.BackgroundTransparency = 1
        hudControls.BorderSizePixel        = 0
        hudControls.ZIndex                 = 53
        hudControls.Parent                 = rightBox

        local function mkHUDCtrlBtn(txt, posX, width, fn)
            local btn = Instance.new("TextButton")
            btn.Size                  = UDim2.new(0, width or 28, 0, 18)
            btn.Position              = UDim2.new(0, posX, 0, 0)
            btn.BackgroundColor3      = C.TitleBar
            btn.BackgroundTransparency = 0.2
            btn.BorderSizePixel       = 1
            btn.BorderColor3          = C.BorderCol
            btn.Text                  = txt
            btn.TextColor3            = C.TextDark
            btn.Font                  = Enum.Font.GothamBold
            btn.TextSize              = 10
            btn.ZIndex                = 54
            btn.Parent                = hudControls
            btn.MouseButton1Click:Connect(fn)
            return btn
        end

        mkHUDCtrlBtn("[|<]", 0, 28, handleSpotifyPrevious)
        mkHUDCtrlBtn("[||]", 32, 28, handleSpotifyPlayPause)
        mkHUDCtrlBtn("[>|]", 64, 28, handleSpotifyNext)

        local pLbl = Instance.new("TextLabel")
        pLbl.Size                  = UDim2.new(1, -98, 0, 14)
        pLbl.Position              = UDim2.new(0, 98, 0, 2)
        pLbl.BackgroundTransparency = 1
        pLbl.Text                  = placeTitle
        pLbl.TextColor3            = C.SubText
        pLbl.Font                  = Enum.Font.Code
        pLbl.TextSize              = 9
        pLbl.TextXAlignment        = Enum.TextXAlignment.Left
        pLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        pLbl.ZIndex                = 53
        pLbl.Parent                = hudControls
        hudPlaceLbl = pLbl

        local div = Instance.new("Frame")
        div.Size             = UDim2.new(1, 0, 0, 1)
        div.Position         = UDim2.new(0, 0, 0, 102)
        div.BackgroundColor3 = C.BorderCol
        div.BorderSizePixel  = 0
        div.ZIndex           = 53
        div.Parent           = rightBox

        local uLbl = Instance.new("TextLabel")
        uLbl.Size                  = UDim2.new(1, 0, 0, 14)
        uLbl.Position              = UDim2.new(0, 0, 0, 106)
        uLbl.BackgroundTransparency = 1
        uLbl.Text                  = "User: @" .. Player.Name .. "  ::  " .. Player.DisplayName
        uLbl.TextColor3            = C.SubText
        uLbl.Font                  = Enum.Font.Code
        uLbl.TextSize              = 9
        uLbl.TextXAlignment        = Enum.TextXAlignment.Left
        uLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        uLbl.ZIndex                = 53
        uLbl.Parent                = rightBox
        hudUserLbl = uLbl

        -- ── RESIZABLE CORNER GRIP ───────────────────────────────────
        local resizeGrip = Instance.new("TextButton")
        resizeGrip.Name                   = "HUD_ResizeGrip"
        resizeGrip.Size                   = UDim2.new(0, 14, 0, 14)
        resizeGrip.Position               = UDim2.new(1, -14, 1, -14)
        resizeGrip.BackgroundTransparency = 1
        resizeGrip.Text                   = "◢"
        resizeGrip.TextColor3             = C.BorderCol
        resizeGrip.Font                   = Enum.Font.GothamBold
        resizeGrip.TextSize               = 11
        resizeGrip.ZIndex                 = 60
        resizeGrip.Parent                 = frame

        do
            local resizing = false
            local startMouse = Vector2.zero
            local startSize = Vector2.zero

            resizeGrip.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    resizing = true
                    startMouse = UserInput:GetMouseLocation()
                    startSize = Vector2.new(frame.AbsoluteSize.X, frame.AbsoluteSize.Y)
                end
            end)

            resizeGrip.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    resizing = false
                end
            end)

            UserInput.InputChanged:Connect(function(i)
                if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                    local delta = UserInput:GetMouseLocation() - startMouse
                    local newW = math.clamp(startSize.X + delta.X, 320, 850)
                    local newH = math.clamp(startSize.Y + delta.Y, 130, 420)
                    frame.Size = UDim2.new(0, newW, 0, newH)

                    local coverSide = math.clamp(newH - 32, 90, 360)
                    coverContainer.Size = UDim2.new(0, coverSide, 0, coverSide)
                    rightBox.Position = UDim2.new(0, coverSide + 14, 0, 4)
                    rightBox.Size = UDim2.new(1, -(coverSide + 20), 1, -8)
                end
            end)
        end

        applyImage(hudCoverImg, currentTrack)
    end

    -- ── VISUALS SYNC ───────────────────────────────────────────────
    updateVisuals = function(track)
        if not track then return end
        currentTrack = track

        if hudSongLbl and hudSongLbl.Parent then hudSongLbl.Text = track.name end
        if hudArtistLbl and hudArtistLbl.Parent then hudArtistLbl.Text = track.artist .. " [" .. track.source .. "]" end
        if hudCoverImg and hudCoverImg.Parent then applyImage(hudCoverImg, track) end

        if bbSongLbl and bbSongLbl.Parent then bbSongLbl.Text = track.name end
        if bbArtistLbl and bbArtistLbl.Parent then bbArtistLbl.Text = track.artist .. " [" .. track.source .. "]" end
        if bbCoverImg and bbCoverImg.Parent then applyImage(bbCoverImg, track) end

        -- Fetch and prepare real-time synced lyrics
        if track.name and track.artist and track.name ~= "Not Playing" and track.name ~= "Error loading" then
            fetchSyncedLyrics(track.artist, track.name)
        end

        if Shared.SetAdaptiveThemeTrack then
            pcall(Shared.SetAdaptiveThemeTrack, track)
        end
        if Shared.BroadcastBeacon then
            pcall(Shared.BroadcastBeacon)
        end
    end

    Shared.CurrentTrack = function() return currentTrack end

    -- ── PERSISTENT AUTO-POLL ENGINE ────────────────────────────────
    startPolling = function()
        if pollConn then pollConn:Disconnect() end
        local elapsed = 0
        pollConn = RunSvc.Heartbeat:Connect(function(dt)
            elapsed = elapsed + dt
            if elapsed >= 2 then
                elapsed = 0
                local track = getSpotifyTrack() or getLastFMTrack()
                if track then
                    if track.name ~= currentTrack.name
                    or track.isPlaying ~= currentTrack.isPlaying
                    or track.cover ~= currentTrack.cover then
                        updateVisuals(track)
                    end
                end
            end
        end)
    end

    -- ── RESPAWN RE-TRACKING ────────────────────────────────────────
    Player.CharacterAdded:Connect(function(char)
        Shared.Character = char
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        Shared.HumanoidRP = hrp
        if Shared.Flags["MusicBillboard"] then
            task.wait(0.2)
            if billboard and hrp then
                billboard.Adornee = hrp
            else
                buildBillboard()
            end
        end
    end)

    -- ══════════════════════════════════════════════════════════════
    -- OPTION 1: LEFT COLUMN — LAST.FM SCROBBLER (NO AUTH REQUIRED)
    -- ══════════════════════════════════════════════════════════════
    MkSection(leftCol, "Option 1: Last.fm (Zero Auth)", 1)

    local lfmBox = Instance.new("TextBox")
    lfmBox.Name                  = "LastFMInput"
    lfmBox.Size                  = UDim2.new(1, 0, 0, 24)
    lfmBox.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    lfmBox.BorderSizePixel       = 1
    lfmBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    lfmBox.Text                  = (Shared.Config.LastFMUser and Shared.Config.LastFMUser ~= "") and Shared.Config.LastFMUser or "Enter Last.fm Username"
    lfmBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    lfmBox.Font                  = Enum.Font.Code
    lfmBox.TextSize              = 11
    lfmBox.LayoutOrder           = 2
    lfmBox.Parent                = leftCol

    lfmBox.FocusLost:Connect(function()
        Shared.Config.LastFMUser = lfmBox.Text
        if Shared.SaveConfig then Shared.SaveConfig() end
        Shared.Notify("Last.fm", "Saved username: " .. lfmBox.Text, true)
    end)

    MkButton(leftCol, "[ Sync Last.fm Track ]", 3, function()
        local trk = getLastFMTrack()
        if trk then
            updateVisuals(trk)
            Shared.Notify("Last.fm", trk.name .. " - " .. trk.artist, true)
            if Shared.Flags["MusicBillboard"] then buildBillboard() end
            if not hudWidget then buildHUD() end
            startPolling()
        else
            Shared.Notify("Last.fm", "No scrobble found for @" .. tostring(Shared.Config.LastFMUser or "user"), false)
        end
    end)

    MkSection(leftCol, "Display Overlays", 10)

    MkToggle(leftCol, "Billboard Over Head", "MusicBillboard", 11, function(state)
        if state then
            buildBillboard()
            startPolling()
        else
            if billboard then billboard:Destroy(); billboard = nil end
        end
    end)

    local _, setHudToggle = MkToggle(leftCol, "Bottom-Left Info HUD", "MusicHUD", 12, function(state)
        if state then
            buildHUD()
            startPolling()
        else
            if hudWidget then hudWidget:Destroy(); hudWidget = nil end
        end
    end)

    -- Auto-launch HUD by default
    task.delay(0.5, function()
        if setHudToggle then
            setHudToggle(true, true)
        else
            buildHUD()
            startPolling()
        end
    end)

    -- ══════════════════════════════════════════════════════════════
    -- OPTION 2: RIGHT COLUMN — SPOTIFY OAUTH / REFRESH / PERMANENT
    -- ══════════════════════════════════════════════════════════════
    MkSection(rightCol, "Option 2: Spotify (Permanent Key)", 1)

    local refreshBox = Instance.new("TextBox")
    refreshBox.Name                  = "SpotifyRefreshTokenInput"
    refreshBox.Size                  = UDim2.new(1, 0, 0, 24)
    refreshBox.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    refreshBox.BorderSizePixel       = 1
    refreshBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    refreshBox.Text                  = (Shared.Config.SpotifyRefreshToken and Shared.Config.SpotifyRefreshToken ~= "") and "Permanent Refresh Token: Set" or "Paste Spotify Refresh Token (Permanent)"
    refreshBox.PlaceholderText       = "Paste Spotify Refresh Token"
    refreshBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    refreshBox.Font                  = Enum.Font.Code
    refreshBox.TextSize              = 10
    refreshBox.LayoutOrder           = 2
    refreshBox.Parent                = rightCol

    refreshBox.FocusLost:Connect(function()
        if refreshBox.Text ~= "" and not refreshBox.Text:find("Permanent Refresh Token: Set") then
            Shared.Config.SpotifyRefreshToken = cleanToken(refreshBox.Text)
            if Shared.SaveConfig then Shared.SaveConfig() end
            refreshBox.Text = "Permanent Refresh Token: Set"
            local ok, res = refreshSpotifyToken()
            if ok then
                Shared.Notify("Spotify", "OAuth connected & refreshed!", true)
                local trk = getSpotifyTrack()
                if trk then updateVisuals(trk) end
            else
                Shared.Notify("Spotify", "Key saved. Click Test to connect.", true)
            end
        end
    end)

    local spotBox = Instance.new("TextBox")
    spotBox.Name                  = "SpotifyTokenInput"
    spotBox.Size                  = UDim2.new(1, 0, 0, 24)
    spotBox.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    spotBox.BorderSizePixel       = 1
    spotBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    spotBox.Text                  = (Shared.Config.SpotifyToken and Shared.Config.SpotifyToken ~= "") and "Access Token: Set (Click to change)" or "Paste Spotify Access Token (1-Hr)"
    spotBox.PlaceholderText       = "Paste Spotify Access Token"
    spotBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    spotBox.Font                  = Enum.Font.Code
    spotBox.TextSize              = 10
    spotBox.LayoutOrder           = 3
    spotBox.Parent                = rightCol

    spotBox.FocusLost:Connect(function()
        if spotBox.Text ~= "" and not spotBox.Text:find("Access Token: Set") then
            Shared.Config.SpotifyToken = cleanToken(spotBox.Text)
            if Shared.SaveConfig then Shared.SaveConfig() end
            spotBox.Text = "Access Token: Set (Click to change)"
            Shared.Notify("Spotify", "Access Token saved", true)
        end
    end)

    MkButton(rightCol, "[ Test & Connect Spotify ]", 4, function()
        if Shared.Config.SpotifyRefreshToken and Shared.Config.SpotifyRefreshToken ~= "" then
            local ok, err = refreshSpotifyToken()
            if ok then
                Shared.Notify("Spotify", "Token refreshed successfully!", true)
            else
                Shared.Notify("Spotify", "Auth: " .. tostring(err or "Failed"), false)
            end
        end
        local trk, err = getSpotifyTrack()
        if trk then
            updateVisuals(trk)
            Shared.Notify("Spotify", "Playing: " .. trk.name .. " - " .. trk.artist, true)
            if Shared.Flags["MusicBillboard"] then buildBillboard() end
            if not hudWidget then buildHUD() end
            startPolling()
        else
            if err == "No Active Playback" then
                Shared.Notify("Spotify", "Token Valid! (Play a song in Spotify app)", true)
                if Shared.Flags["MusicBillboard"] then buildBillboard() end
                if not hudWidget then buildHUD() end
                startPolling()
            else
                Shared.Notify("Spotify", "Status: " .. tostring(err or "Failed"), false)
            end
        end
    end)

    MkSection(rightCol, "Playback Controls", 10)
    MkButton(rightCol, "[|<]  Previous Track", 11, handleSpotifyPrevious)
    MkButton(rightCol, "[||]  Play / Pause", 12, handleSpotifyPlayPause)
    MkButton(rightCol, "[>|]  Next Track", 13, handleSpotifyNext)

    MkSection(rightCol, "OAuth Guide & Requirements", 15)

    local guideFrame = Instance.new("Frame")
    guideFrame.Name                  = "OAuthGuideFrame"
    guideFrame.Size                  = UDim2.new(1, 0, 0, 160)
    guideFrame.BackgroundColor3      = Color3.fromRGB(240, 244, 252)
    guideFrame.BorderSizePixel       = 1
    guideFrame.BorderColor3          = Color3.fromRGB(160, 180, 215)
    guideFrame.LayoutOrder           = 16
    guideFrame.Parent                = rightCol

    local guidePad = Instance.new("UIPadding")
    guidePad.PaddingTop    = UDim.new(0, 6)
    guidePad.PaddingLeft   = UDim.new(0, 8)
    guidePad.PaddingRight  = UDim.new(0, 8)
    guidePad.PaddingBottom = UDim.new(0, 6)
    guidePad.Parent        = guideFrame

    local guideText = Instance.new("TextLabel")
    guideText.Size                   = UDim2.new(1, 0, 1, 0)
    guideText.BackgroundTransparency = 1
    guideText.Text                   = "[ HOW TO GET SPOTIFY OAUTH TOKEN ]\n" ..
                                       "1. Open developer.spotify.com/dashboard & Log in.\n" ..
                                       "2. Create an App -> Set Redirect URI to:\n" ..
                                       "   http://127.0.0.1:8888/callback\n" ..
                                       "3. Run GetSpotifyToken.exe to generate token.\n" ..
                                       "4. Paste token above & click Test.\n\n" ..
                                       "[!] REQUIREMENTS & LIMITATIONS:\n" ..
                                       "* Playback skipping ([|<], [>|], [||]) requires an\n" ..
                                       "  active OAuth token AND a Spotify Premium subscription.\n" ..
                                       "* Free accounts / Last.fm mode support live track\n" ..
                                       "  scrobbling & cover display only."
    guideText.TextColor3             = Color3.fromRGB(20, 30, 60)
    guideText.Font                   = Enum.Font.Code
    guideText.TextSize               = 9
    guideText.TextXAlignment         = Enum.TextXAlignment.Left
    guideText.TextYAlignment         = Enum.TextYAlignment.Top
    guideText.Parent                 = guideFrame

    MkButton(rightCol, "[ Copy Guide Steps to Clipboard ]", 17, function()
        pcall(function()
            if setclipboard then
                setclipboard(
                    "Spotify OAuth Token Guide for Fih UI:\n" ..
                    "1. Open https://developer.spotify.com/dashboard and log in.\n" ..
                    "2. Create an app and set Redirect URI to http://127.0.0.1:8888/callback\n" ..
                    "3. Run GetSpotifyToken.exe with your Client ID / Secret.\n" ..
                    "4. Paste the token into Fih UI Music Tab -> Spotify Refresh Token box and click [ Test & Connect Spotify ].\n\n" ..
                    "Notice: Track skipping and remote play/pause controls require an active OAuth connection AND a Spotify Premium subscription."
                )
                Shared.Notify("Spotify", "OAuth Guide copied to clipboard!", true)
            else
                Shared.Notify("Spotify", "Clipboard function not supported by executor", false)
            end
        end)
    end)

    -- ── THEME CALLBACK ─────────────────────────────────────────────
    if Shared.RegisterThemeCallback then
        Shared.RegisterThemeCallback(function(theme, darkMode)
            if hudWidget and hudWidget.Parent then
                local tBar = hudWidget:FindFirstChildOfClass("Frame")
                if tBar then
                    TweenSvc:Create(tBar, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                        BackgroundColor3 = darkMode and (theme.TitleBar or Color3.fromRGB(32, 36, 46)) or (theme.TitleBar or Color3.fromRGB(212, 208, 200)),
                        BackgroundTransparency = 0.20
                    }):Play()
                    local tLbl = tBar:FindFirstChildOfClass("TextLabel")
                    if tLbl then
                        TweenSvc:Create(tLbl, TweenInfo.new(0.25), {
                            TextColor3 = darkMode and (theme.TitleText or Color3.fromRGB(220, 225, 240)) or (theme.TitleText or Color3.fromRGB(0, 0, 0))
                        }):Play()
                    end
                end
                TweenSvc:Create(hudWidget, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = darkMode and (theme.BodyBg or Color3.fromRGB(16, 18, 24)) or (theme.BodyBg or Color3.fromRGB(248, 250, 255)),
                    BorderColor3     = darkMode and (theme.WinBorder or Color3.fromRGB(30, 75, 130)) or (theme.WinBorder or Color3.fromRGB(58, 110, 165)),
                    BackgroundTransparency = 0.25
                }):Play()
            end
            if billboard and billboard.Parent then
                local bg = billboard:FindFirstChildOfClass("Frame")
                if bg then
                    TweenSvc:Create(bg, TweenInfo.new(0.25), {
                        BackgroundColor3 = darkMode and Color3.fromRGB(10, 12, 18) or Color3.fromRGB(15, 18, 24),
                        BorderColor3     = theme.Accent or (darkMode and Color3.fromRGB(0, 120, 220) or Color3.fromRGB(0, 160, 255))
                    }):Play()
                end
            end
        end)
    end

    -- ── HIGH-THRESHOLD DYNAMIC 28-BAR & 10-BAR AUDIO EQUALIZER ───────
    local hudBarLevels = {}
    for i = 1, 28 do hudBarLevels[i] = 0 end
    local bbBarLevels  = {}
    for i = 1, 10 do bbBarLevels[i] = 0 end
    local lastFrameTime = os.clock()
    local lastDisplayedLyric = ""

    RunSvc.RenderStepped:Connect(function()
        local now = os.clock()
        local dt = math.clamp(now - lastFrameTime, 0.001, 0.05)
        lastFrameTime = now

        local hasTrack = (currentTrack.name ~= "Not Playing" and currentTrack.name ~= "Error loading" and currentTrack.name ~= "" and currentTrack.name ~= nil)
        local isPlaying = hasTrack and (currentTrack.isPlaying ~= false or currentTrack.source == "Last.fm")

        local trackSeed = 0
        if currentTrack.name then
            for c = 1, math.min(10, #currentTrack.name) do
                trackSeed = (trackSeed + currentTrack.name:byte(c) * c) % 500
            end
        end

        local songSec = now
        if currentTrack.isPlaying and currentTrack.pollTime then
            songSec = ((currentTrack.progress_ms or 0) / 1000) + (now - currentTrack.pollTime)
        end

        -- Update Real-Time Live Lyrics with accurate timestamp synchronization
        local activeLyricText = ""
        if hasTrack and currentLyrics and #currentLyrics > 0 then
            for i = #currentLyrics, 1, -1 do
                if songSec >= currentLyrics[i].time then
                    activeLyricText = currentLyrics[i].text
                    break
                end
            end
            if activeLyricText == "" and currentLyrics[1] then
                activeLyricText = currentLyrics[1].text
            end
        elseif hasTrack then
            activeLyricText = "♪ " .. currentTrack.name .. " - " .. currentTrack.artist
        else
            activeLyricText = "♪ No active song playback"
        end

        if activeLyricText ~= lastDisplayedLyric then
            lastDisplayedLyric = activeLyricText
            if hudLyricsLbl and hudLyricsLbl.Parent then
                hudLyricsLbl.Text = activeLyricText
            end
            if bbLyricsLbl and bbLyricsLbl.Parent then
                bbLyricsLbl.Text = activeLyricText
            end
        end

        local function calculateTargetLevel(barIdx, totalBars)
            if not isPlaying then return 0 end

            local frac = (barIdx - 1) / math.max(1, totalBars - 1)
            -- Balanced frequency movement: smooth rolling sub-bass to gentle treble waves
            local freqMult = 0.75 + frac * 3.6
            local beatImpulse = (math.sin(songSec * 2.4) ^ 2) * (0.7 - frac * 0.35)

            local n1 = (math.noise(barIdx * 0.16, songSec * freqMult, trackSeed) + 1) * 0.50
            local n2 = (math.noise(barIdx * 0.35, songSec * (freqMult * 1.4) + 10, trackSeed + 60) + 1) * 0.28
            local n3 = (math.noise(barIdx * 0.70, songSec * (freqMult * 2.2) + 20, trackSeed + 120) + 1) * 0.12

            local raw = math.clamp((n1 + n2 + n3) * (0.65 + beatImpulse * 0.25), 0, 1.0)
            -- Calibrated, fluid musical curve (less aggressive spikes, pleasant wave flow)
            local shaped = math.clamp((raw ^ 1.35) * 0.88, 0.05, 0.95)
            return shaped
        end

        -- Update HUD 28-Bar Equalizer with smooth fluid response & organic falloff
        if hudVisBars then
            for i, bar in ipairs(hudVisBars) do
                if bar and bar.Parent then
                    local target = calculateTargetLevel(i, #hudVisBars)
                    local cur = hudBarLevels[i] or 0
                    if target > cur then
                        cur = cur + (target - cur) * math.clamp(dt * 7.5, 0.15, 0.65)
                    else
                        cur = math.max(target, cur - dt * 1.35)
                    end
                    hudBarLevels[i] = cur

                    local barH = isPlaying and math.clamp(math.floor(cur * 22) + 2, 2, 24) or 3
                    bar.Size = UDim2.new(0, 5, 0, barH)
                    bar.BackgroundColor3 = isPlaying and Color3.fromHSV((0.55 + i * 0.012) % 1, 0.85, 1) or Color3.fromRGB(60, 75, 100)
                end
            end
        end

        -- Update Billboard 10-Bar Equalizer
        if bbVisBars then
            for i, bar in ipairs(bbVisBars) do
                if bar and bar.Parent then
                    local target = calculateTargetLevel(i, #bbVisBars)
                    local cur = bbBarLevels[i] or 0
                    if target > cur then
                        cur = cur + (target - cur) * math.clamp(dt * 7.5, 0.15, 0.65)
                    else
                        cur = math.max(target, cur - dt * 1.35)
                    end
                    bbBarLevels[i] = cur

                    local barH = isPlaying and math.clamp(math.floor(cur * 15) + 2, 2, 16) or 2
                    bar.Size = UDim2.new(0, 5, 0, barH)
                    bar.BackgroundColor3 = isPlaying and Color3.fromHSV((0.36 + i * 0.03) % 1, 0.9, 0.95) or Color3.fromRGB(70, 85, 110)
                end
            end
        end
    end)

    print("[Music_Handler] Loaded -- High-Threshold Dynamic 28-Bar Visualizer & Synced Lyrics")
end
