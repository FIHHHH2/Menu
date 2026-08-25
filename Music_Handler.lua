-- Music_Handler.lua
-- Robust Music Engine: Spotify + Last.fm Live Scrobbler with Dynamic Cache-Busted Album Covers,
-- Scaled Cover Art, Crisp Well-Spaced Text, Respawn Tracking, and Resizable Bottom-Left Info Widget

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
    if not tab or not cols then return end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    -- Verified working Last.fm public API key
    local LASTFM_API_KEY = "b25b959554ed76058ac220b7b2e0a026"
    local currentTrack = {
        name      = "Not Playing",
        artist    = "No Artist",
        cover     = "",
        isPlaying = false,
        source    = "None"
    }
    Shared.GetCurrentTrack = function() return currentTrack end

    local billboard   = nil
    local hudWidget   = nil
    local pollConn    = nil
    local placeTitle  = "Roblox Place"
    local lastLoadedCoverUrl = ""
    local currentCoverAsset  = ""
    local previousCoverFile  = ""

    -- Fetch place name asynchronously
    task.spawn(function()
        local ok, info = pcall(function() return MarketSvc:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then
            placeTitle = info.Name
        end
    end)

    -- ── PROVEN MULTI-METHOD COVER PIPELINE ──────────────────────
    -- Mirrors the working approach from Universal Cheat Panel v10:
    -- unified HTTP wrapper → Last.fm URL first → iTunes fallback

    -- Unified HTTP: tries all executor methods in order
    local function CoverHTTP(url)
        if not url or url == "" then return nil end

        -- Method 1: request / http_request / syn.request / http.request
        local reqFn = (typeof(request) == "function" and request)
                   or (typeof(http_request) == "function" and http_request)
                   or (getgenv and typeof(getgenv().request) == "function" and getgenv().request)
                   or (typeof(syn) == "table" and syn.request)
                   or (typeof(http) == "table" and http.request)

        if reqFn then
            local ok1, res1 = pcall(reqFn, { Url = url, Method = "GET" })
            if ok1 and res1 then
                local b = res1.Body or res1.body
                if b and type(b) == "string" and #b > 1000 then
                    return b
                end
            end
            local ok2, res2 = pcall(reqFn, { url = url, method = "GET" })
            if ok2 and res2 then
                local b = res2.Body or res2.body
                if b and type(b) == "string" and #b > 1000 then
                    return b
                end
            end
        end

        -- Method 2: game:HttpGet
        local ok3, body3 = pcall(function() return game:HttpGet(url) end)
        if ok3 and body3 and type(body3) == "string" and #body3 > 1000 then
            return body3
        end

        -- Method 3: Shared.HttpRequest
        local res4 = Shared.HttpRequest({ Url = url, Method = "GET" })
        if res4 then
            local b = res4.Body or res4.body
            if b and type(b) == "string" and #b > 1000 then
                return b
            end
        end

        return nil
    end

    -- Strict header check: only real image binary passes
    local function isValidImageData(data)
        if not data or type(data) ~= "string" or #data < 500 then return false end
        local b1, b2, b3 = string.byte(data, 1, 3)
        -- JPEG: FF D8 FF
        if b1 == 255 and b2 == 216 and b3 == 255 then return true end
        -- PNG: 89 50 4E
        if b1 == 137 and b2 == 80 and b3 == 78 then return true end
        -- GIF: 47 49 46
        if b1 == 71 and b2 == 73 and b3 == 70 then return true end
        -- WEBP / BMP
        if b1 == 82 and b2 == 73 then return true end
        if b1 == 66 and b2 == 77 then return true end
        return false
    end

    local function getImageExtension(data)
        if not data or #data < 2 then return "jpg" end
        local b1, b2 = string.byte(data, 1, 2)
        if b1 == 255 and b2 == 216 then return "jpg" end
        if b1 == 137 then return "png" end
        return "jpg"
    end

    -- Write bytes to executor filesystem and return rbxasset:// URL
    local function writeAndGetAsset(imgBytes)
        local getcustomasset = getcustomasset or getsynasset
                            or (getgenv and (getgenv().getcustomasset or getgenv().getsynasset))
        local writefile_fn   = writefile or (getgenv and getgenv().writefile)
        local delfile_fn     = delfile   or (getgenv and getgenv().delfile)

        if not getcustomasset or not writefile_fn then return nil end

        local ext  = getImageExtension(imgBytes)
        local name = "fih_cov_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000,9999)) .. "." .. ext
        local okW  = pcall(function() writefile_fn(name, imgBytes) end)
        if not okW then return nil end

        local okA, asset = pcall(function() return getcustomasset(name) end)
        if okA and asset and asset ~= "" then
            -- Clean up previous cover file
            if previousCoverFile ~= "" and previousCoverFile ~= name and delfile_fn then
                pcall(function() delfile_fn(previousCoverFile) end)
            end
            previousCoverFile = name
            return asset
        end
        return nil
    end

    -- Fetch cover from iTunes Search API (proven to work in all executors)
    local function fetchiTunesCover(artist, song)
        if not artist or not song or artist == "" or song == "" then return nil end
        local query = Http:UrlEncode(artist .. " " .. song)
        local url   = "https://itunes.apple.com/search?term=" .. query .. "&media=music&entity=song&limit=1"

        local res = CoverHTTP(url)
        if not res or #res < 10 then return nil end

        local ok, data = pcall(function() return Http:JSONDecode(res) end)
        if not ok or not data or not data.results or #data.results == 0 then return nil end

        local artUrl = data.results[1].artworkUrl100
        if not artUrl or artUrl == "" then return nil end

        -- Try HD first (600x600), fall back to 100x100
        local hdUrl = artUrl:gsub("100x100bb", "600x600bb")
        local imgBytes = CoverHTTP(hdUrl)
        if imgBytes and isValidImageData(imgBytes) then return imgBytes end

        imgBytes = CoverHTTP(artUrl)
        if imgBytes and isValidImageData(imgBytes) then return imgBytes end

        return nil
    end

    -- Also try artist-only iTunes lookup (for obscure tracks where artist+title fails)
    local function fetchiTunesArtistCover(artist)
        if not artist or artist == "" then return nil end
        local query = Http:UrlEncode(artist)
        local url   = "https://itunes.apple.com/search?term=" .. query .. "&media=music&entity=musicArtist&limit=1"
        local res   = CoverHTTP(url)
        if not res or #res < 10 then return nil end
        local ok, data = pcall(function() return Http:JSONDecode(res) end)
        if not ok or not data or not data.results or #data.results == 0 then return nil end
        local r = data.results[1]
        local artUrl = r.artworkUrl100 or r.artworkUrl60
        if not artUrl then return nil end
        local hdUrl = artUrl:gsub("100x100bb", "600x600bb")
        local imgBytes = CoverHTTP(hdUrl)
        if imgBytes and isValidImageData(imgBytes) then return imgBytes end
        return nil
    end

    local function extractDominantColorFromBytes(bytes)
        if not bytes or #bytes < 128 then return nil end
        local totalR, totalG, totalB = 0, 0, 0
        local count = 0
        local grayscaleCount = 0

        -- 12-hue bucket histogram for true most common color selection
        local buckets = {}
        for b = 1, 12 do buckets[b] = { count = 0, totalR = 0, totalG = 0, totalB = 0, maxSat = 0 } end

        local step = math.max(1, math.floor(#bytes / 250))
        local startIdx = math.min(256, math.floor(#bytes * 0.05))
        local endIdx = math.min(#bytes - 32, math.floor(#bytes * 0.95))

        for i = startIdx, endIdx, step do
            local b1 = string.byte(bytes, i) or 128
            local b2 = string.byte(bytes, i + 1) or 128
            local b3 = string.byte(bytes, i + 2) or 128

            local r = b1 / 255
            local g = b2 / 255
            local b = b3 / 255

            totalR = totalR + r
            totalG = totalG + g
            totalB = totalB + b
            count = count + 1

            local maxC = math.max(r, g, b)
            local minC = math.min(r, g, b)
            local sat = maxC > 0 and (maxC - minC) / maxC or 0

            if sat < 0.16 then
                grayscaleCount = grayscaleCount + 1
            else
                local h, _, _ = Color3.new(r, g, b):ToHSV()
                local bIdx = math.clamp(math.floor(h * 12) + 1, 1, 12)
                local bucket = buckets[bIdx]
                bucket.count = bucket.count + 1
                bucket.totalR = bucket.totalR + r
                bucket.totalG = bucket.totalG + g
                bucket.totalB = bucket.totalB + b
                if sat > bucket.maxSat then
                    bucket.maxSat = sat
                end
            end
        end

        if count == 0 then return nil end

        -- Check if artwork is predominantly grayscale/monochrome
        local isMonochrome = (grayscaleCount / count) > 0.65

        -- Find the most common / most frequent color bucket
        local bestBucket = nil
        local maxFreq = -1
        for b = 1, 12 do
            if buckets[b].count > maxFreq and buckets[b].count > 0 then
                maxFreq = buckets[b].count
                bestBucket = buckets[b]
            end
        end

        local dominantCol = nil
        if bestBucket and bestBucket.count > 0 then
            dominantCol = Color3.new(
                bestBucket.totalR / bestBucket.count,
                bestBucket.totalG / bestBucket.count,
                bestBucket.totalB / bestBucket.count
            )
        end

        return {
            avg = Color3.new(totalR / count, totalG / count, totalB / count),
            dominant = dominantCol,
            isMonochrome = isMonochrome
        }
    end

    local labelTokens = {}
    local cachedCoverTrackKey = ""

    local function applyImage(imgLabel, trackOrUrl, optArtist)
        if not imgLabel then return end

        local artist    = ""
        local trackName = ""
        local rawUrl    = ""

        if type(trackOrUrl) == "table" then
            artist    = trackOrUrl.artist or ""
            trackName = trackOrUrl.name or ""
            rawUrl    = trackOrUrl.cover or ""
        else
            rawUrl    = tostring(trackOrUrl or "")
            artist    = tostring(optArtist or "")
            trackName = currentTrack.name or ""
        end

        local trackKey = tostring(rawUrl) .. "|" .. tostring(trackName) .. "|" .. tostring(artist)

        -- If asset already cached for this exact track, apply synchronously to avoid race conditions
        if currentCoverAsset and currentCoverAsset ~= "" and trackKey == cachedCoverTrackKey then
            imgLabel.BackgroundTransparency = 1
            imgLabel.Image = currentCoverAsset
            imgLabel.Visible = true
            return
        end

        -- Immediately clear so no white shows during async load
        if imgLabel and imgLabel.Parent then
            imgLabel.BackgroundTransparency = 1
            imgLabel.Image = ""
        end

        labelTokens[imgLabel] = (labelTokens[imgLabel] or 0) + 1
        local myToken = labelTokens[imgLabel]

        task.spawn(function()
            local function apply(imgBytes)
                if labelTokens[imgLabel] ~= myToken then return false end
                if not imgLabel or not imgLabel.Parent then return false end

                -- Extract dominant artwork palette from raw image data
                local pal = extractDominantColorFromBytes(imgBytes)
                if pal then
                    currentTrack.palette = pal
                    if Shared.SetAdaptiveThemeTrack then
                        pcall(Shared.SetAdaptiveThemeTrack, currentTrack)
                    end
                end

                local asset = writeAndGetAsset(imgBytes)
                if asset then
                    currentCoverAsset   = asset
                    cachedCoverTrackKey = trackKey
                    lastLoadedCoverUrl  = rawUrl
                    imgLabel.BackgroundTransparency = 1
                    imgLabel.Image   = asset
                    imgLabel.Visible = true
                    return true
                end
                -- Fallback direct URL if getcustomasset unavailable
                imgLabel.BackgroundTransparency = 1
                imgLabel.Image   = rawUrl ~= "" and rawUrl or ""
                imgLabel.Visible = true
                return true
            end

            -- Step 1: Try the Last.fm provided URL
            if rawUrl ~= "" and not rawUrl:find("2a96cbd8b46e442fc41c2b86b821562f") then
                local imgBytes = CoverHTTP(rawUrl)
                if imgBytes and isValidImageData(imgBytes) then
                    if apply(imgBytes) then return end
                end
            end

            -- Step 2: iTunes with full artist + title
            local imgBytes = fetchiTunesCover(artist, trackName)
            if imgBytes then
                if apply(imgBytes) then return end
            end

            -- Step 3: iTunes with cleaned artist + title
            local cleanArtist = tostring(artist):gsub("%b()", ""):gsub("ft%..*", ""):gsub("feat%..*", ""):gsub("^%s+", ""):gsub("%s+$", "")
            local cleanTrack  = tostring(trackName):gsub("%b()", ""):gsub("ft%..*", ""):gsub("feat%..*", ""):gsub("%-.*", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if cleanArtist ~= artist or cleanTrack ~= trackName then
                imgBytes = fetchiTunesCover(cleanArtist, cleanTrack)
                if imgBytes then
                    if apply(imgBytes) then return end
                end
            end

            -- Step 4: iTunes artist-only fallback
            imgBytes = fetchiTunesArtistCover(cleanArtist ~= "" and cleanArtist or artist)
            if imgBytes then
                if apply(imgBytes) then return end
            end

            -- All sources exhausted — leave transparent placeholder
            if labelTokens[imgLabel] == myToken and imgLabel and imgLabel.Parent then
                imgLabel.BackgroundTransparency = 1
                imgLabel.Image   = ""
                imgLabel.Visible = true
            end
        end)
    end
    Shared.ApplyArtworkImage = applyImage

    -- SPOTIFY API
    local function cleanToken(tok)
        if not tok then return "" end
        tok = tok:gsub("^%s+", ""):gsub("%s+$", "")
        if tok:sub(1, 7):lower() == "bearer " then
            tok = tok:sub(8)
        end
        return tok
    end

    -- ── BASE64 ENCODER FOR SPOTIFY CLIENT AUTH ─────────────────────
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local function toBase64(data)
        return ((data:gsub('.', function(x) 
            local r,b='',x:byte()
            for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
            return r;
        end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
            if (#x < 6) then return '' end
            local c=0
            for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
            return b64chars:sub(c+1,c+1)
        end)..({ '', '==', '=' })[#data%3+1])
    end

    -- ── PERMANENT SPOTIFY AUTO-REFRESH ENGINE ───────────────────────
    local isRefreshingToken = false
    local function refreshSpotifyToken()
        local rToken   = cleanToken(Shared.Config.SpotifyRefreshToken)
        local clientId = (Shared.Config.SpotifyClientId and cleanToken(Shared.Config.SpotifyClientId) ~= "") and cleanToken(Shared.Config.SpotifyClientId) or "1842aff694404946af4ac03a457c54ab"
        local clientSec = (Shared.Config.SpotifyClientSecret and cleanToken(Shared.Config.SpotifyClientSecret) ~= "") and cleanToken(Shared.Config.SpotifyClientSecret) or "b90742dc54544188a5e2f88d5383bd3c"

        if not rToken or rToken == "" or rToken == "Paste Spotify Refresh Token (Permanent)" or rToken == "Permanent Refresh Token: Set" then
            return false, "No Refresh Token"
        end
        if isRefreshingToken then return false, "Refresh in progress" end
        isRefreshingToken = true

        local authHeader = "Basic " .. toBase64(clientId .. ":" .. clientSec)
        local headers = {
            ["Content-Type"]  = "application/x-www-form-urlencoded",
            ["Authorization"] = authHeader,
        }
        local body = "grant_type=refresh_token&refresh_token=" .. Http:UrlEncode(rToken) .. "&client_id=" .. clientId

        local resp = Shared.HttpRequest({
            Url     = "https://accounts.spotify.com/api/token",
            Method  = "POST",
            Headers = headers,
            Body    = body,
        })

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
                    return false, data.error
                end
            end
        end
        return false, (resp and resp.Body) or "Network/auth failed"
    end

    local function spotifyRequest(endpoint, method, body, hasRetried)
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

    local function getSpotifyTrack(hasRetried)
        local token = cleanToken(Shared.Config.SpotifyToken)
        if not token or token == "" then
            if Shared.Config.SpotifyRefreshToken and not hasRetried then
                local ok = refreshSpotifyToken()
                if ok then return getSpotifyTrack(true) end
            end
            return nil, "No Token"
        end

        local resp = Shared.HttpRequest({
            Url     = "https://api.spotify.com/v1/me/player/currently-playing",
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

        if not resp or (resp.StatusCode and resp.StatusCode == 401) then
            return nil, "Expired/Invalid Token (401)"
        end
        if resp.StatusCode == 204 or not resp.Body or #resp.Body == 0 then
            return nil, "No Active Playback"
        end

        local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
        if not ok or not data or not data.item then return nil, "No Track Found" end
        local item = data.item

        local trackName  = item.name or "Unknown"
        local artistName = item.artists and item.artists[1] and item.artists[1].name or "Unknown"

        local coverUrl = ""
        if item.album and item.album.images and #item.album.images > 0 then
            coverUrl = item.album.images[1].url or ""
        end

        -- Multi-source fallback if cover is missing
        if not coverUrl or coverUrl == "" then
            coverUrl = fetchArtworkFallback(artistName, trackName)
        end

        return {
            id          = item.id,
            name        = trackName,
            artist      = artistName,
            cover       = coverUrl,
            isPlaying   = data.is_playing or false,
            progress_ms = data.progress_ms or 0,
            duration_ms = item.duration_ms or 0,
            pollTime    = os.clock(),
            source      = "Spotify"
        }
    end

    -- LAST.FM API (Public Scrobbler)
    local function getLastFMTrack()
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

        -- Multi-source fallback if Last.fm returned no cover
        if not coverUrl or coverUrl == "" then
            coverUrl = fetchArtworkFallback(artistName, trackName)
        end

        return {
            name      = trackName,
            artist    = artistName,
            cover     = coverUrl,
            isPlaying = isNowPlaying,
            source    = "Last.fm"
        }
    end

    -- ── CENTRAL SPOTIFY PLAYBACK CONTROLLER ──────────────────────
    local function handleSpotifyPrevious()
        task.spawn(function()
            local token = cleanToken(Shared.Config.SpotifyToken)
            if not token or token == "" then
                Shared.Notify("Spotify", "[!] No OAuth Token configured (Auth Required)", false)
                return
            end
            local resp = spotifyRequest("/previous", "POST")
            if resp and resp.StatusCode == 403 then
                Shared.Notify("Spotify", "[!] Skipping requires Spotify Premium & active OAuth", false)
            elseif resp and (resp.StatusCode == 204 or resp.StatusCode == 200) then
                Shared.Notify("Spotify", "[|<] Skipped to previous track", true)
            else
                Shared.Notify("Spotify", "[!] Previous track failed (Requires Premium & Active Player)", false)
            end
            task.wait(0.4)
            local trk = getSpotifyTrack()
            if trk then updateVisuals(trk) end
        end)
    end

    local function handleSpotifyPlayPause()
        task.spawn(function()
            local token = cleanToken(Shared.Config.SpotifyToken)
            if not token or token == "" then
                Shared.Notify("Spotify", "[!] No OAuth Token configured (Auth Required)", false)
                return
            end
            -- Check live playback state from /v1/me/player
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
            else
                isCurrentlyPlaying = currentTrack.isPlaying
            end

            if isCurrentlyPlaying then
                local resp = spotifyRequest("/pause", "PUT")
                if resp and resp.StatusCode == 403 then
                    Shared.Notify("Spotify", "[!] Playback control requires Spotify Premium", false)
                elseif resp and (resp.StatusCode == 204 or resp.StatusCode == 200) then
                    currentTrack.isPlaying = false
                    Shared.Notify("Spotify", "[||] Playback paused", false)
                else
                    Shared.Notify("Spotify", "[!] Pause failed (Requires Premium & Active Player)", false)
                end
            else
                local resp = spotifyRequest("/play", "PUT")
                if resp and resp.StatusCode == 403 then
                    Shared.Notify("Spotify", "[!] Playback control requires Spotify Premium", false)
                elseif resp and (resp.StatusCode == 204 or resp.StatusCode == 200) then
                    currentTrack.isPlaying = true
                    Shared.Notify("Spotify", "[>] Playback resumed", true)
                else
                    Shared.Notify("Spotify", "[!] Resume failed (Requires Premium & Active Player)", false)
                end
            end
            task.wait(0.4)
            local trk = getSpotifyTrack()
            if trk then updateVisuals(trk) end
        end)
    end

    local function handleSpotifyNext()
        task.spawn(function()
            local token = cleanToken(Shared.Config.SpotifyToken)
            if not token or token == "" then
                Shared.Notify("Spotify", "[!] No OAuth Token configured (Auth Required)", false)
                return
            end
            local resp = spotifyRequest("/next", "POST")
            if resp and resp.StatusCode == 403 then
                Shared.Notify("Spotify", "[!] Skipping requires Spotify Premium & active OAuth", false)
            elseif resp and (resp.StatusCode == 204 or resp.StatusCode == 200) then
                Shared.Notify("Spotify", "[>|] Skipped to next track", true)
            else
                Shared.Notify("Spotify", "[!] Next track failed (Requires Premium & Active Player)", false)
            end
            task.wait(0.4)
            local trk = getSpotifyTrack()
            if trk then updateVisuals(trk) end
        end)
    end

    -- ── 3D BILLBOARD GUI OVER HEAD ─────────────────────────────────
    local bbSongLbl, bbArtistLbl, bbCoverImg
    local bbVisBars  = {}
    local hudVisBars = {}

    local function getHRP()
        return Shared.HumanoidRP or (Shared.Character and Shared.Character:FindFirstChild("HumanoidRootPart")) or (Player.Character and Player.Character:FindFirstChild("HumanoidRootPart"))
    end

    local function buildBillboard()
        if billboard then billboard:Destroy(); billboard = nil end
        local hrp = getHRP()
        if not hrp then return end

        local head = (Player.Character and Player.Character:FindFirstChild("Head")) or hrp

        billboard = Instance.new("BillboardGui")
        billboard.Name                   = "MusicBillboard"
        billboard.Size                   = UDim2.new(0, 305, 0, 66)
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
        bbCoverContainer.Size             = UDim2.new(0, 50, 0, 50)
        bbCoverContainer.Position         = UDim2.new(0, 6, 0, 6)
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
        songLbl.Size                  = UDim2.new(1, -140, 0, 18)
        songLbl.Position              = UDim2.new(0, 62, 0, 8)
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
        artistLbl.Size                  = UDim2.new(1, -140, 0, 16)
        artistLbl.Position              = UDim2.new(0, 62, 0, 28)
        artistLbl.BackgroundTransparency = 1
        artistLbl.Text                  = currentTrack.artist .. " [" .. currentTrack.source .. "]"
        artistLbl.TextColor3            = Color3.fromRGB(0, 220, 140)
        artistLbl.Font                  = Enum.Font.Code
        artistLbl.TextSize              = 9
        artistLbl.TextXAlignment        = Enum.TextXAlignment.Left
        artistLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        artistLbl.Parent                = bg
        bbArtistLbl = artistLbl

        -- ── BILLBOARD AUDIO EQUALIZER VISUALIZER ──
        local bbVisualizer = Instance.new("Frame")
        bbVisualizer.Name                   = "BB_Visualizer"
        bbVisualizer.Size                   = UDim2.new(0, 52, 0, 18)
        bbVisualizer.Position               = UDim2.new(0, 62, 0, 43)
        bbVisualizer.BackgroundTransparency = 1
        bbVisualizer.BorderSizePixel        = 0
        bbVisualizer.Parent                 = bg

        bbVisBars = {}
        for i = 1, 6 do
            local bar = Instance.new("Frame")
            bar.Size = UDim2.new(0, 5, 0, 3)
            bar.Position = UDim2.new(0, (i - 1) * 8, 1, 0)
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

    -- ── DRAGGABLE & RESIZABLE BOTTOM-LEFT INFO WIDGET ──────────────
    local hudSongLbl, hudArtistLbl, hudCoverImg, hudPlaceLbl, hudUserLbl

    local function buildHUD()
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
            CoverBg   = Color3.fromRGB(25, 28, 38)
        } or {
            WinBorder = Color3.fromRGB(58, 110, 165),
            TitleBar  = Color3.fromRGB(212, 208, 200),
            TitleText = Color3.fromRGB(0, 0, 0),
            BodyBg    = Color3.fromRGB(248, 250, 255),
            BorderCol = Color3.fromRGB(180, 190, 210),
            TextDark  = Color3.fromRGB(15, 25, 60),
            Accent    = Color3.fromRGB(0, 120, 40),
            SubText   = Color3.fromRGB(80, 95, 120),
            CoverBg   = Color3.fromRGB(225, 230, 240)
        }

        local frame = Instance.new("Frame")
        frame.Name             = "Fih_BottomHUD"
        frame.Size             = UDim2.new(0, 310, 0, 126)
        frame.Position         = UDim2.new(0, 16, 1, -142)
        frame.BackgroundColor3 = C.BodyBg
        frame.BorderSizePixel  = 2
        frame.BorderColor3     = C.WinBorder
        frame.ClipsDescendants = true
        frame.ZIndex           = 50
        frame.Parent           = Shared.GUI
        hudWidget = frame

        local tBar = Instance.new("Frame")
        tBar.Size             = UDim2.new(1, 0, 0, 20)
        tBar.BackgroundColor3 = C.TitleBar
        tBar.BorderSizePixel  = 1
        tBar.BorderColor3     = Color3.fromRGB(140, 140, 140)
        tBar.ZIndex           = 51
        tBar.Parent           = frame

        local tLbl = Instance.new("TextLabel")
        tLbl.Size                   = UDim2.new(1, -8, 1, 0)
        tLbl.Position               = UDim2.new(0, 6, 0, 0)
        tLbl.BackgroundTransparency = 1
        tLbl.Text                   = "Fih HUD  ::  Now Playing & Session"
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

        -- 1. Album Cover Art Container: Dark vinyl frame with note icon (never shows white box)
        local coverContainer = Instance.new("Frame")
        coverContainer.Name             = "CoverContainer"
        coverContainer.Position         = UDim2.new(0, 6, 0, 6)
        coverContainer.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
        coverContainer.BorderSizePixel  = 1
        coverContainer.BorderColor3     = C.BorderCol
        coverContainer.ZIndex           = 52
        coverContainer.Parent           = content

        local noteIcon = Instance.new("TextLabel")
        noteIcon.Size                   = UDim2.new(1, 0, 1, 0)
        noteIcon.BackgroundTransparency = 1
        noteIcon.Text                   = "[♪]"
        noteIcon.Font                   = Enum.Font.Code
        noteIcon.TextSize               = 14
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

        -- 2. Right Text Container (holds crisp text moved down so nothing clips)
        local rightBox = Instance.new("Frame")
        rightBox.Name                   = "TextContainer"
        rightBox.Size                   = UDim2.new(1, -66, 1, -8)
        rightBox.Position               = UDim2.new(0, 62, 0, 4)
        rightBox.BackgroundTransparency = 1
        rightBox.ZIndex                 = 52
        rightBox.Parent                 = content

        -- Bold Song Title (Fixed clean size, positioned down)
        local sLbl = Instance.new("TextLabel")
        sLbl.Size                  = UDim2.new(1, 0, 0, 18)
        sLbl.Position              = UDim2.new(0, 0, 0, 6)
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

        -- Bold Artist / Source
        local aLbl = Instance.new("TextLabel")
        aLbl.Size                  = UDim2.new(1, 0, 0, 16)
        aLbl.Position              = UDim2.new(0, 0, 0, 26)
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

        -- ── HUD PLAYBACK CONTROLS (⏮ ⏯ ⏭) ──
        local hudControls = Instance.new("Frame")
        hudControls.Name                   = "HUD_PlaybackControls"
        hudControls.Size                   = UDim2.new(1, 0, 0, 20)
        hudControls.Position               = UDim2.new(0, 0, 0, 44)
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

        -- ── HUD AUDIO EQUALIZER VISUALIZER ──
        local hudVisualizer = Instance.new("Frame")
        hudVisualizer.Name                   = "HUD_Visualizer"
        hudVisualizer.Size                   = UDim2.new(0, 72, 0, 24)
        hudVisualizer.Position               = UDim2.new(1, -78, 0, 40)
        hudVisualizer.BackgroundTransparency = 1
        hudVisualizer.BorderSizePixel        = 0
        hudVisualizer.ZIndex                 = 54
        hudVisualizer.Parent                 = rightBox

        hudVisBars = {}
        for i = 1, 7 do
            local bar = Instance.new("Frame")
            bar.Size = UDim2.new(0, 6, 0, 4)
            bar.Position = UDim2.new(0, (i - 1) * 10, 1, 0)
            bar.AnchorPoint = Vector2.new(0, 1)
            bar.BackgroundColor3 = C.Accent
            bar.BorderSizePixel = 0
            bar.ZIndex = 55
            bar.Parent = hudVisualizer
            hudVisBars[i] = bar
        end

        -- Divider Line
        local div = Instance.new("Frame")
        div.Size             = UDim2.new(1, 0, 0, 1)
        div.Position         = UDim2.new(0, 0, 0, 68)
        div.BackgroundColor3 = C.BorderCol
        div.BorderSizePixel  = 0
        div.ZIndex           = 53
        div.Parent           = rightBox

        -- Place Info (Moved down)
        local pLbl = Instance.new("TextLabel")
        pLbl.Size                  = UDim2.new(1, 0, 0, 14)
        pLbl.Position              = UDim2.new(0, 0, 0, 72)
        pLbl.BackgroundTransparency = 1
        pLbl.Text                  = "Map: " .. placeTitle .. " (ID: " .. tostring(game.PlaceId) .. ")"
        pLbl.TextColor3            = C.SubText
        pLbl.Font                  = Enum.Font.Code
        pLbl.TextSize              = 9
        pLbl.TextXAlignment        = Enum.TextXAlignment.Left
        pLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        pLbl.ZIndex                = 53
        pLbl.Parent                = rightBox
        hudPlaceLbl = pLbl

        -- User Info (Moved down)
        local uLbl = Instance.new("TextLabel")
        uLbl.Size                  = UDim2.new(1, 0, 0, 14)
        uLbl.Position              = UDim2.new(0, 0, 0, 87)
        uLbl.BackgroundTransparency = 1
        uLbl.Text                  = "User: " .. Player.DisplayName .. " (@" .. Player.Name .. ")"
        uLbl.TextColor3            = C.SubText
        uLbl.Font                  = Enum.Font.Code
        uLbl.TextSize              = 9
        uLbl.TextXAlignment        = Enum.TextXAlignment.Left
        uLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        uLbl.ZIndex                = 53
        uLbl.Parent                = rightBox
        hudUserLbl = uLbl

        -- Function to adjust cover size & text layout on resize
        local function updateHUDLayout()
            local totalH = frame.AbsoluteSize.Y
            local coverDim = math.clamp(totalH - 34, 44, 200)
            coverContainer.Size = UDim2.new(0, coverDim, 0, coverDim)

            rightBox.Position = UDim2.new(0, coverDim + 14, 0, 0)
            rightBox.Size     = UDim2.new(1, -(coverDim + 22), 1, 0)
        end
        updateHUDLayout()

        -- Resizing corner grip for HUD
        do
            local resizeGrip = Instance.new("TextButton")
            resizeGrip.Name                   = "HUDResizeGrip"
            resizeGrip.Size                   = UDim2.new(0, 14, 0, 14)
            resizeGrip.Position               = UDim2.new(1, -14, 1, -14)
            resizeGrip.BackgroundTransparency = 1
            resizeGrip.Text                   = "◢"
            resizeGrip.TextColor3             = Color3.fromRGB(100, 125, 170)
            resizeGrip.Font                   = Enum.Font.Code
            resizeGrip.TextSize               = 11
            resizeGrip.ZIndex                 = 55
            resizeGrip.Parent                 = frame

            local resizing = false
            local rStartPos, rStartSize

            resizeGrip.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    resizing = true; rStartPos = i.Position; rStartSize = frame.AbsoluteSize
                end
            end)
            UserInput.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    resizing = false
                end
            end)
            UserInput.InputChanged:Connect(function(i)
                if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                    local d = i.Position - rStartPos
                    local newW = math.clamp(rStartSize.X + d.X, 240, 700)
                    local newH = math.clamp(rStartSize.Y + d.Y, 95, 320)
                    frame.Size = UDim2.new(0, newW, 0, newH)
                    updateHUDLayout()
                end
            end)
        end

        applyImage(hudCoverImg, currentTrack)

        if Shared.RegisterThemeCallback then
            Shared.RegisterThemeCallback(function(targetTheme, isDarkMode)
                if hudWidget and hudWidget.Parent then
                    TweenService:Create(hudWidget, TweenInfo.new(0.25), {
                        BackgroundColor3 = targetTheme.BodyBg or Color3.fromRGB(10, 12, 16),
                        BorderColor3     = targetTheme.WinBorder or Color3.fromRGB(0, 160, 255)
                    }):Play()
                    if tBar and tBar.Parent then
                        TweenService:Create(tBar, TweenInfo.new(0.25), {
                            BackgroundColor3 = targetTheme.TitleBar or Color3.fromRGB(18, 20, 26),
                            BorderColor3     = targetTheme.WinBorder or Color3.fromRGB(0, 160, 255)
                        }):Play()
                    end
                    if tLbl and tLbl.Parent then
                        TweenService:Create(tLbl, TweenInfo.new(0.25), {
                            TextColor3 = targetTheme.TitleText or Color3.fromRGB(248, 250, 255)
                        }):Play()
                    end
                    if hudSongLbl and hudSongLbl.Parent then
                        TweenService:Create(hudSongLbl, TweenInfo.new(0.25), {
                            TextColor3 = targetTheme.BtnText or Color3.fromRGB(248, 250, 255)
                        }):Play()
                    end
                    if hudArtistLbl and hudArtistLbl.Parent then
                        TweenService:Create(hudArtistLbl, TweenInfo.new(0.25), {
                            TextColor3 = targetTheme.Accent or Color3.fromRGB(0, 200, 255)
                        }):Play()
                    end
                    if hudVisBars then
                        for _, bar in ipairs(hudVisBars) do
                            if bar and bar.Parent then
                                TweenService:Create(bar, TweenInfo.new(0.25), {
                                    BackgroundColor3 = targetTheme.Accent or Color3.fromRGB(0, 200, 255)
                                    }):Play()
                            end
                        end
                    end
                    if hudPlaceLbl and hudPlaceLbl.Parent then
                        TweenService:Create(hudPlaceLbl, TweenInfo.new(0.25), {
                            TextColor3 = targetTheme.BannerSub or Color3.fromRGB(160, 175, 200)
                        }):Play()
                    end
                    if hudUserLbl and hudUserLbl.Parent then
                        TweenService:Create(hudUserLbl, TweenInfo.new(0.25), {
                            TextColor3 = targetTheme.BannerSub or Color3.fromRGB(160, 175, 200)
                        }):Play()
                    end
                end
            end)
        end
    end

    -- ── SPOTIFY AUDIO ANALYSIS FETCHER (Segments, Beats, Loudness, Pitches) ──
    local trackAnalysisCache = {}
    local isFetchingAnalysis = {}

    local function fetchAudioAnalysis(trackId)
        if not trackId or trackId == "" or trackAnalysisCache[trackId] or isFetchingAnalysis[trackId] then return end
        isFetchingAnalysis[trackId] = true

        task.spawn(function()
            local token = cleanToken(Shared.Config.SpotifyToken)
            if not token or token == "" then
                isFetchingAnalysis[trackId] = nil
                return
            end

            local resp = Shared.HttpRequest({
                Url     = "https://api.spotify.com/v1/audio-analysis/" .. trackId,
                Method  = "GET",
                Headers = {
                    ["Authorization"] = "Bearer " .. token,
                    ["Content-Type"]  = "application/json"
                }
            })

            isFetchingAnalysis[trackId] = nil

            if resp and resp.Body then
                local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
                if ok and data and data.segments then
                    trackAnalysisCache[trackId] = {
                        segments = data.segments,
                        beats    = data.beats or {},
                        tatums   = data.tatums or {},
                        sections = data.sections or {},
                    }
                end
            end
        end)
    end

    -- Update all visual elements & apply new cover image when URL changes
    local function updateVisuals(track)
        currentTrack = track

        if track.source == "Spotify" and track.id then
            fetchAudioAnalysis(track.id)
        end

        if bbSongLbl then bbSongLbl.Text = track.name end
        if bbArtistLbl then bbArtistLbl.Text = track.artist .. " [" .. track.source .. "]" end
        if bbCoverImg then applyImage(bbCoverImg, track) end

        if hudSongLbl then hudSongLbl.Text = track.name end
        if hudArtistLbl then hudArtistLbl.Text = track.artist .. " [" .. track.source .. "]" end
        if hudCoverImg then applyImage(hudCoverImg, track) end

        -- Update Opaque Adaptive UI Theme if active
        if Shared.SetAdaptiveThemeTrack then
            pcall(Shared.SetAdaptiveThemeTrack, track)
        end

        -- Broadcast updated track to peer script users immediately
        if Shared.BroadcastBeacon then
            pcall(Shared.BroadcastBeacon)
        end
    end

    Shared.CurrentTrack = function() return currentTrack end

    -- Persistent Polling Engine
    local function startPolling()
        if pollConn then pollConn:Disconnect() end
        local elapsed = 0
        pollConn = RunSvc.Heartbeat:Connect(function(dt)
            elapsed = elapsed + dt
            if elapsed >= 3 then
                elapsed = 0
                local track = getSpotifyTrack() or getLastFMTrack()
                if track then
                    if track.name ~= currentTrack.name or track.cover ~= currentTrack.cover or track.isPlaying ~= currentTrack.isPlaying then
                        updateVisuals(track)
                    end
                end
            end
        end)
    end

    -- ── RESPAWN / DEATH RE-TRACKING ────────────────────────────────
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

    -- LEFT COLUMN: LAST.FM SCROBBLER & HEAD BILLBOARD
    MkSection(leftCol, "Last.fm Scrobbler (No Auth Required)", 1)

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
            Shared.Notify("Last.fm", "No track found / scrobbling", false)
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

    -- RIGHT COLUMN: PERMANENT SPOTIFY OAUTH & CONTROLS
    MkSection(rightCol, "Spotify Permanent OAuth", 1)

    -- Refresh Token Input (Permanent - Never Expires)
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
                Shared.Notify("Spotify", "Permanent OAuth connected & refreshed!", true)
                local trk = getSpotifyTrack()
                if trk then updateVisuals(trk) end
            else
                Shared.Notify("Spotify", "Refresh Token saved (Awaiting client trigger)", true)
            end
        end
    end)

    -- Standard Token Input (Fallback / Manual)
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

    MkButton(rightCol, "[ Test & Auto-Refresh Token ]", 4, function()
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
                                       "   http://localhost:8888/callback\n" ..
                                       "3. Obtain Refresh Token with scopes:\n" ..
                                       "   user-read-playback-state\n" ..
                                       "   user-modify-playback-state\n" ..
                                       "   user-read-currently-playing\n" ..
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
                    "2. Create an app and set Redirect URI to http://localhost:8888/callback\n" ..
                    "3. Generate an OAuth Refresh Token with scopes: user-read-playback-state user-modify-playback-state user-read-currently-playing\n" ..
                    "4. Paste the token into Fih UI Music Tab -> Spotify Refresh Token box and click [ Test & Auto-Refresh Token ].\n\n" ..
                    "Notice: Track skipping and remote play/pause controls require an active OAuth connection AND a Spotify Premium subscription."
                )
                Shared.Notify("Spotify", "OAuth Guide copied to clipboard!", true)
            else
                Shared.Notify("Spotify", "Clipboard function not supported by executor", false)
            end
        end)
    end)

    -- ── DARK MODE THEME CALLBACK ──────────────────────────────────
    -- Rebuilds the HUD with the correct colour palette when the user switches theme
    if Shared.RegisterThemeCallback then
        Shared.RegisterThemeCallback(function(theme, darkMode)
            -- Update bottom-left HUD colours
            if hudWidget and hudWidget.Parent then
                local tBar = hudWidget:FindFirstChildOfClass("Frame")
                if tBar then
                    TweenSvc:Create(tBar, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                        BackgroundColor3 = darkMode and Color3.fromRGB(32, 36, 46) or Color3.fromRGB(212, 208, 200)
                    }):Play()
                    local tLbl = tBar:FindFirstChildOfClass("TextLabel")
                    if tLbl then
                        TweenSvc:Create(tLbl, TweenInfo.new(0.25), {
                            TextColor3 = darkMode and Color3.fromRGB(220, 225, 240) or Color3.fromRGB(0, 0, 0)
                        }):Play()
                    end
                end
                TweenSvc:Create(hudWidget, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = darkMode and Color3.fromRGB(16, 18, 24) or Color3.fromRGB(248, 250, 255),
                    BorderColor3     = darkMode and Color3.fromRGB(30, 75, 130) or Color3.fromRGB(58, 110, 165)
                }):Play()
                local content = hudWidget:FindFirstChild("HUDContent")
                if content then
                    local rightBox = content:FindFirstChild("TextContainer")
                    if rightBox then
                        for _, lbl in ipairs(rightBox:GetChildren()) do
                            if lbl:IsA("TextLabel") then
                                local isDimText = lbl.Name == "PlaceLbl" or lbl.Name == "UserLbl" or lbl.Position.Y.Offset > 44
                                if isDimText then
                                    TweenSvc:Create(lbl, TweenInfo.new(0.25), {
                                        TextColor3 = darkMode and Color3.fromRGB(130, 150, 180) or Color3.fromRGB(80, 95, 120)
                                    }):Play()
                                end
                            end
                        end
                    end
                end
            end
            -- Update billboard (over-head) background
            if billboard and billboard.Parent then
                local bg = billboard:FindFirstChildOfClass("Frame")
                if bg then
                    TweenSvc:Create(bg, TweenInfo.new(0.25), {
                        BackgroundColor3 = darkMode and Color3.fromRGB(10, 12, 18) or Color3.fromRGB(15, 18, 24),
                        BorderColor3     = darkMode and Color3.fromRGB(0, 120, 220) or Color3.fromRGB(0, 160, 255)
                    }):Play()
                end
            end
        end)
    end

    -- ── HARDWARE AUDIO SPECTRUM CAPTURE (AudioListener + AudioAnalyzer) ──
    local gameAudioListener, gameAudioAnalyzer, gameAudioWire
    pcall(function()
        gameAudioListener = Instance.new("AudioListener")
        gameAudioListener.Parent = workspace

        gameAudioAnalyzer = Instance.new("AudioAnalyzer")
        gameAudioAnalyzer.Parent = workspace

        gameAudioWire = Instance.new("Wire")
        gameAudioWire.SourceInstance = gameAudioListener
        gameAudioWire.TargetInstance = gameAudioAnalyzer
        gameAudioWire.Parent = workspace
    end)

    -- ── HIGH-FIDELITY EQUALIZER ENGINE (Attack, Decay, Perlin Dynamics & Pitch Vectors) ──
    local lastSegIdx = 1
    local hudBarLevels = { 0, 0, 0, 0, 0, 0, 0 }
    local bbBarLevels  = { 0, 0, 0, 0, 0, 0 }
    local lastFrameTime = os.clock()

    local RunService = game:GetService("RunService")
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local dt = math.clamp(now - lastFrameTime, 0.001, 0.05)
        lastFrameTime = now

        local isPlaying = (currentTrack.isPlaying ~= false) and (currentTrack.name ~= "Not Playing" and currentTrack.name ~= "Error loading" and currentTrack.name ~= "" and currentTrack.name ~= nil)

        -- Unique track seed to produce completely distinct harmonic profiles for every song
        local trackSeed = 0
        if currentTrack.name then
            for c = 1, math.min(10, #currentTrack.name) do
                trackSeed = (trackSeed + currentTrack.name:byte(c) * c) % 500
            end
        end

        local analysis = (currentTrack.id and trackAnalysisCache[currentTrack.id])
        local songSec = 0
        if currentTrack.isPlaying and currentTrack.pollTime then
            songSec = ((currentTrack.progress_ms or 0) / 1000) + (now - currentTrack.pollTime)
        end

        -- Find active Spotify audio segment for exact millisecond timestamp
        local activeSegment = nil
        local beatKick = 0
        if analysis and analysis.segments and #analysis.segments > 0 then
            local segs = analysis.segments
            if lastSegIdx > #segs then lastSegIdx = 1 end
            local found = false
            for i = math.max(1, lastSegIdx - 5), math.min(#segs, lastSegIdx + 30) do
                local s = segs[i]
                if s and s.start <= songSec and (s.start + s.duration) > songSec then
                    activeSegment = s
                    lastSegIdx = i
                    found = true
                    break
                end
            end
            if not found then
                for i = 1, #segs do
                    local s = segs[i]
                    if s and s.start <= songSec and (s.start + s.duration) > songSec then
                        activeSegment = s
                        lastSegIdx = i
                        break
                    end
                end
            end

            -- Beat drop impulse
            if analysis.beats then
                for _, b in ipairs(analysis.beats) do
                    if math.abs(b.start - songSec) < 0.09 then
                        beatKick = 0.40 * (b.confidence or 0.8)
                        break
                    end
                end
            end
        end

        local function calculateTargetLevel(barIdx, totalBars)
            if not isPlaying then return 0 end

            local rawLevel = 0

            -- 1. Precision Spotify Pitch & Loudness Segment Vector
            if activeSegment and activeSegment.pitches then
                local loudnessDb = activeSegment.loudness_max or -18
                local normVol = math.clamp((loudnessDb + 45) / 45, 0.1, 1)

                local pitches = activeSegment.pitches
                local pVal = 0
                if barIdx == 1 then
                    pVal = (pitches[1] or 0.5) * 0.7 + (pitches[2] or 0.5) * 0.3
                elseif barIdx == 2 then
                    pVal = (pitches[2] or 0.5) * 0.3 + (pitches[3] or 0.5) * 0.4 + (pitches[4] or 0.5) * 0.3
                elseif barIdx == 3 then
                    pVal = (pitches[4] or 0.5) * 0.3 + (pitches[5] or 0.5) * 0.4 + (pitches[6] or 0.5) * 0.3
                elseif barIdx == 4 then
                    pVal = (pitches[6] or 0.5) * 0.3 + (pitches[7] or 0.5) * 0.4 + (pitches[8] or 0.5) * 0.3
                elseif barIdx == 5 then
                    pVal = (pitches[8] or 0.5) * 0.3 + (pitches[9] or 0.5) * 0.4 + (pitches[10] or 0.5) * 0.3
                elseif barIdx == 6 then
                    pVal = (pitches[10] or 0.5) * 0.3 + (pitches[11] or 0.5) * 0.4 + (pitches[12] or 0.5) * 0.3
                else
                    pVal = (pitches[12] or 0.5) * 0.5 + (pitches[1] or 0.5) * 0.5
                end

                local noiseMod = math.noise(barIdx * 0.5, songSec * 3.6, trackSeed) * 0.18
                rawLevel = math.clamp((pVal * 0.72 + normVol * 0.28 + noiseMod) * normVol + beatKick, 0, 1)
            else
                -- 2. Organic Multi-Octave Perlin Audio Spectrum
                local n1 = (math.noise(barIdx * 0.5, songSec * 4.2, trackSeed) + 1) * 0.5
                local n2 = (math.noise(barIdx * 1.0, songSec * 8.4, trackSeed + 50) + 1) * 0.25
                local n3 = math.abs(math.sin(songSec * 2.8 + barIdx * 0.65)) * 0.2
                rawLevel = math.clamp(n1 * 0.6 + n2 + n3, 0, 1)
            end

            -- Non-linear power curve: Filters out jittery micro-noise, highlights solid rhythmic beats
            local shaped = math.clamp(rawLevel ^ 1.6, 0.05, 1)
            return shaped
        end

        -- Update HUD Equalizer Bars with snappy attack & physics gravity decay
        if hudVisBars then
            for i, bar in ipairs(hudVisBars) do
                if bar and bar.Parent then
                    local target = calculateTargetLevel(i, #hudVisBars)
                    local cur = hudBarLevels[i] or 0
                    if target > cur then
                        cur = cur + (target - cur) * math.clamp(dt * 14, 0.15, 0.85)
                    else
                        cur = math.max(target, cur - dt * 1.8)
                    end
                    hudBarLevels[i] = cur

                    local barH = isPlaying and math.clamp(math.floor(cur * 24) + 2, 2, 24) or 3
                    bar.Size = UDim2.new(0, 6, 0, barH)
                    bar.BackgroundColor3 = isPlaying and Color3.fromHSV((0.55 + i * 0.03) % 1, 0.85, 1) or Color3.fromRGB(60, 75, 100)
                end
            end
        end

        -- Update Billboard Equalizer Bars
        if bbVisBars then
            for i, bar in ipairs(bbVisBars) do
                if bar and bar.Parent then
                    local target = calculateTargetLevel(i, #bbVisBars)
                    local cur = bbBarLevels[i] or 0
                    if target > cur then
                        cur = cur + (target - cur) * math.clamp(dt * 14, 0.15, 0.85)
                    else
                        cur = math.max(target, cur - dt * 1.8)
                    end
                    bbBarLevels[i] = cur

                    local barH = isPlaying and math.clamp(math.floor(cur * 18) + 2, 2, 18) or 2
                    bar.Size = UDim2.new(0, 5, 0, barH)
                    bar.BackgroundColor3 = isPlaying and Color3.fromHSV((0.36 + i * 0.04) % 1, 0.9, 0.95) or Color3.fromRGB(70, 85, 110)
                end
            end
        end
    end)

    print("[Music_Handler] Loaded -- Dynamic Covers, Scaled HUD, Clean Typography Online")
end
