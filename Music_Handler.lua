-- Music_Handler.lua
-- Unified Music Engine: Spotify OAuth + Last.fm Live Scrobble Detector & Head Billboard

return function(Shared)
    local Http      = Shared.Services.Http
    local Player    = Shared.Player
    local RunSvc    = Shared.Services.RunService
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

    local LASTFM_API_KEY = "2c6a0c0a373a693b827361ab6e1b6f00"
    local currentTrack = { name = "Not Playing", artist = "No Artist", isPlaying = false, source = "None" }
    local billboard    = nil
    local pollConn     = nil

    -- SPOTIFY API
    local function spotifyRequest(endpoint, method, body)
        local token = Shared.Config.SpotifyToken
        if not token or token == "" then return nil end
        local ok, result = pcall(function()
            return Http:RequestAsync({
                Url     = "https://api.spotify.com/v1/me/player" .. endpoint,
                Method  = method or "GET",
                Headers = {
                    ["Authorization"] = "Bearer " .. token,
                    ["Content-Type"]  = "application/json",
                },
                Body    = body and Http:JSONEncode(body) or nil,
            })
        end)
        return ok and result or nil
    end

    local function getSpotifyTrack()
        local resp = spotifyRequest("", "GET")
        if not resp or resp.StatusCode ~= 200 then return nil end
        local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
        if not ok or not data or not data.item then return nil end
        local item = data.item
        return {
            name      = item.name or "Unknown",
            artist    = item.artists and item.artists[1] and item.artists[1].name or "Unknown",
            isPlaying = data.is_playing,
            source    = "Spotify"
        }
    end

    -- LAST.FM API
    local function getLastFMTrack()
        local user = Shared.Config.LastFMUser
        if not user or user == "" then return nil end
        local url = "https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=" .. Http:UrlEncode(user) .. "&api_key=" .. LASTFM_API_KEY .. "&format=json&limit=1"
        local ok, resp = pcall(function()
            return Http:RequestAsync({ Url = url, Method = "GET" })
        end)
        if not ok or not resp or resp.StatusCode ~= 200 then return nil end
        local ok2, data = pcall(function() return Http:JSONDecode(resp.Body) end)
        if not ok2 or not data or not data.recenttracks or not data.recenttracks.track then return nil end
        local track = data.recenttracks.track[1] or data.recenttracks.track
        if not track then return nil end
        local isNowPlaying = (track["@attr"] and track["@attr"].nowplaying == "true") or false
        return {
            name      = track.name or "Unknown",
            artist    = track.artist and (track.artist["#text"] or track.artist.name) or "Unknown",
            isPlaying = isNowPlaying,
            source    = "Last.fm"
        }
    end

    -- BILLBOARD GUI
    local function buildBillboard()
        if billboard then billboard:Destroy(); billboard = nil end
        local hrp = Shared.HumanoidRP
        if not hrp then return end

        billboard = Instance.new("BillboardGui")
        billboard.Name          = "MusicBillboard"
        billboard.Size          = UDim2.new(0, 210, 0, 52)
        billboard.StudsOffset   = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop   = false
        billboard.Adornee       = hrp
        billboard.Parent        = Shared.GUI

        local bg = Instance.new("Frame")
        bg.Size             = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
        bg.BackgroundTransparency = 0.15
        bg.BorderSizePixel  = 1
        bg.BorderColor3     = Color3.fromRGB(0, 160, 255)
        bg.Parent           = billboard

        local songLbl = Instance.new("TextLabel")
        songLbl.Size                  = UDim2.new(1, -12, 0, 22)
        songLbl.Position              = UDim2.new(0, 6, 0, 4)
        songLbl.BackgroundTransparency = 1
        songLbl.Text                  = currentTrack.name
        songLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
        songLbl.Font                  = Enum.Font.Code
        songLbl.TextSize              = 11
        songLbl.TextXAlignment        = Enum.TextXAlignment.Left
        songLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        songLbl.Parent                = bg

        local artistLbl = Instance.new("TextLabel")
        artistLbl.Size                  = UDim2.new(1, -12, 0, 18)
        artistLbl.Position              = UDim2.new(0, 6, 0, 24)
        artistLbl.BackgroundTransparency = 1
        artistLbl.Text                  = currentTrack.artist .. " [" .. currentTrack.source .. "]"
        artistLbl.TextColor3            = Color3.fromRGB(0, 200, 120)
        artistLbl.Font                  = Enum.Font.Code
        artistLbl.TextSize              = 10
        artistLbl.TextXAlignment        = Enum.TextXAlignment.Left
        artistLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        artistLbl.Parent                = bg

        Shared._MusicLabels = { songLbl, artistLbl }
    end

    local function startPolling()
        if pollConn then pollConn:Disconnect() end
        local elapsed = 0
        pollConn = RunSvc.Heartbeat:Connect(function(dt)
            elapsed = elapsed + dt
            if elapsed >= 4 then
                elapsed = 0
                local track = getSpotifyTrack() or getLastFMTrack()
                if track then
                    currentTrack = track
                    if Shared._MusicLabels then
                        Shared._MusicLabels[1].Text = track.name
                        Shared._MusicLabels[2].Text = track.artist .. " [" .. track.source .. "]"
                    end
                end
            end
        end)
    end

    -- LEFT COLUMN: LAST.FM SCROBBLER & SPOTIFY
    MkSection(leftCol, "Last.fm Scrobble Detector", 1)

    local lfmStatus = Instance.new("TextLabel")
    lfmStatus.Size                  = UDim2.new(1, 0, 0, 20)
    lfmStatus.BackgroundTransparency = 1
    lfmStatus.Text                  = "User: " .. (Shared.Config.LastFMUser ~= "" and Shared.Config.LastFMUser or "Not Set")
    lfmStatus.TextColor3            = Color3.fromRGB(120, 120, 140)
    lfmStatus.Font                  = Enum.Font.Code
    lfmStatus.TextSize              = 10
    lfmStatus.TextXAlignment        = Enum.TextXAlignment.Left
    lfmStatus.LayoutOrder           = 2
    lfmStatus.Parent                = leftCol

    MkButton(leftCol, "[ Set Last.fm Username ]", 3, function()
        -- Quick prompt or toggle
        local cur = Shared.Config.LastFMUser
        Shared.Notify("Last.fm", "Set username in FihUi_Config.json or paste below", true)
    end)

    MkButton(leftCol, "[ Sync Last.fm Now ]", 4, function()
        local trk = getLastFMTrack()
        if trk then
            currentTrack = trk
            Shared.Notify("Last.fm", trk.name .. " - " .. trk.artist, true)
            buildBillboard()
            startPolling()
        else
            Shared.Notify("Last.fm", "No active scrobble found", false)
        end
    end)

    MkSection(leftCol, "Head Billboard", 10)
    MkToggle(leftCol, "Show Billboard Over Head", "MusicBillboard", 11, function(state)
        if state then buildBillboard(); startPolling() else if billboard then billboard:Destroy(); billboard = nil end end
    end)

    -- RIGHT COLUMN: SPOTIFY CONTROLS
    MkSection(rightCol, "Spotify Playback Controls", 1)
    MkButton(rightCol, "⏮  Previous Track", 2, function() spotifyRequest("/previous", "POST") end)
    MkButton(rightCol, "⏯  Play / Pause", 3, function()
        local t = getSpotifyTrack()
        spotifyRequest(t and t.isPlaying and "/pause" or "/play", "PUT")
    end)
    MkButton(rightCol, "⏭  Next Track", 4, function() spotifyRequest("/next", "POST") end)

    print("[Music_Handler] Loaded -- Spotify + Last.fm dual scrobbler online")
end
