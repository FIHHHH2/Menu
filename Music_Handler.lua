-- Music_Handler.lua
-- Robust Music Engine: Spotify with Bearer Header + Last.fm Live Scrobbler & Head Billboard

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

    -- SPOTIFY API (Uses executor request function with custom Bearer Authorization header)
    local function spotifyRequest(endpoint, method, body)
        local token = Shared.Config.SpotifyToken
        if not token or token == "" then return nil end
        return Shared.HttpRequest({
            Url     = "https://api.spotify.com/v1/me/player" .. endpoint,
            Method  = method or "GET",
            Headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-Type"]  = "application/json",
            },
            Body    = body and Http:JSONEncode(body) or nil,
        })
    end

    local function getSpotifyTrack()
        local resp = spotifyRequest("", "GET")
        if not resp or (resp.StatusCode and resp.StatusCode ~= 200 and resp.StatusCode ~= 204) then return nil end
        if not resp.Body or #resp.Body == 0 then return nil end
        local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
        if not ok or not data or not data.item then return nil end
        local item = data.item
        return {
            name      = item.name or "Unknown",
            artist    = item.artists and item.artists[1] and item.artists[1].name or "Unknown",
            isPlaying = data.is_playing or false,
            source    = "Spotify"
        }
    end

    -- LAST.FM API (Public Scrobble API - Requires only Username)
    local function getLastFMTrack()
        local user = Shared.Config.LastFMUser
        if not user or user == "" then return nil end
        local url = "https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=" .. Http:UrlEncode(user) .. "&api_key=" .. LASTFM_API_KEY .. "&format=json&limit=1"
        local resp = Shared.HttpRequest({ Url = url, Method = "GET" })
        if not resp or not resp.Body or #resp.Body == 0 then return nil end
        local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
        if not ok or not data or not data.recenttracks or not data.recenttracks.track then return nil end
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

    -- 3D BILLBOARD GUI OVER HEAD
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
            if elapsed >= 3 then
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

    -- LEFT COLUMN: LAST.FM SCROBBLER & HEAD BILLBOARD
    MkSection(leftCol, "Last.fm Scrobbler (Easiest)", 1)

    -- Text input for Last.fm username
    local lfmBox = Instance.new("TextBox")
    lfmBox.Name                  = "LastFMInput"
    lfmBox.Size                  = UDim2.new(1, 0, 0, 24)
    lfmBox.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    lfmBox.BorderSizePixel       = 1
    lfmBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    lfmBox.Text                  = Shared.Config.LastFMUser ~= "" and Shared.Config.LastFMUser or "Enter Last.fm Username"
    lfmBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    lfmBox.Font                  = Enum.Font.Code
    lfmBox.TextSize              = 11
    lfmBox.LayoutOrder           = 2
    lfmBox.Parent                = leftCol

    lfmBox.FocusLost:Connect(function()
        Shared.Config.LastFMUser = lfmBox.Text
        Shared.SaveConfig()
        Shared.Notify("Last.fm", "Saved username: " .. lfmBox.Text, true)
    end)

    MkButton(leftCol, "[ Sync Last.fm Track ]", 3, function()
        local trk = getLastFMTrack()
        if trk then
            currentTrack = trk
            Shared.Notify("Last.fm", trk.name .. " - " .. trk.artist, true)
            buildBillboard()
            startPolling()
        else
            Shared.Notify("Last.fm", "No track scrobbling now", false)
        end
    end)

    MkSection(leftCol, "Head Billboard Display", 10)
    MkToggle(leftCol, "Billboard Over Head", "MusicBillboard", 11, function(state)
        if state then buildBillboard(); startPolling() else if billboard then billboard:Destroy(); billboard = nil end end
    end)

    -- RIGHT COLUMN: SPOTIFY OAUTH & CONTROLS
    MkSection(rightCol, "Spotify OAuth Token", 1)

    local spotBox = Instance.new("TextBox")
    spotBox.Name                  = "SpotifyTokenInput"
    spotBox.Size                  = UDim2.new(1, 0, 0, 24)
    spotBox.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    spotBox.BorderSizePixel       = 1
    spotBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    spotBox.Text                  = Shared.Config.SpotifyToken ~= "" and "Token: Set (Click to change)" or "Paste Spotify OAuth Token"
    spotBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    spotBox.Font                  = Enum.Font.Code
    spotBox.TextSize              = 11
    spotBox.LayoutOrder           = 2
    spotBox.Parent                = rightCol

    spotBox.FocusLost:Connect(function()
        if spotBox.Text ~= "" and not spotBox.Text:find("Token: Set") then
            Shared.Config.SpotifyToken = spotBox.Text
            Shared.SaveConfig()
            spotBox.Text = "Token: Set (Click to change)"
            Shared.Notify("Spotify", "OAuth Token saved", true)
        end
    end)

    MkSection(rightCol, "Playback Controls", 10)
    MkButton(rightCol, "⏮  Previous Track", 11, function()
        spotifyRequest("/previous", "POST")
        Shared.Notify("Spotify", "Previous track command sent", true)
    end)
    MkButton(rightCol, "⏯  Play / Pause", 12, function()
        local t = getSpotifyTrack()
        if t and t.isPlaying then
            spotifyRequest("/pause", "PUT")
            Shared.Notify("Spotify", "Playback paused", false)
        else
            spotifyRequest("/play", "PUT")
            Shared.Notify("Spotify", "Playback resumed", true)
        end
    end)
    MkButton(rightCol, "⏭  Next Track", 13, function()
        spotifyRequest("/next", "POST")
        Shared.Notify("Spotify", "Next track command sent", true)
    end)

    print("[Music_Handler] Loaded -- Spotify + Last.fm dual scrobbler active")
end
