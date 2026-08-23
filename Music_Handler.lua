-- Music_Handler.lua
-- Robust Music Engine: Spotify + Last.fm Live Scrobbler with Dynamic Album Covers, Bold Typography,
-- Respawn Tracking, and Draggable Bottom-Left Info Widget

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

    local billboard   = nil
    local hudWidget   = nil
    local pollConn    = nil
    local placeTitle  = "Roblox Place"
    local lastCoverUrl = ""
    local coverFileCounter = 0

    -- Fetch place name asynchronously
    task.spawn(function()
        local ok, info = pcall(function() return MarketSvc:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then
            placeTitle = info.Name
        end
    end)

    -- Dynamic image downloader with cache-busting per track cover
    local function applyImage(imgLabel, url)
        if not url or url == "" then
            imgLabel.Visible = false
            imgLabel.Image = ""
            return
        end
        imgLabel.Visible = true

        if getcustomasset and writefile then
            task.spawn(function()
                coverFileCounter = (coverFileCounter + 1) % 10
                local fName = "fih_cover_" .. tostring(coverFileCounter) .. ".png"
                local ok, res = pcall(function()
                    return Shared.HttpRequest({ Url = url, Method = "GET" })
                end)
                if ok and res and res.Body and #res.Body > 0 then
                    pcall(function()
                        writefile(fName, res.Body)
                        imgLabel.Image = ""
                        task.wait()
                        imgLabel.Image = getcustomasset(fName)
                    end)
                else
                    pcall(function() imgLabel.Image = url end)
                end
            end)
        else
            pcall(function() imgLabel.Image = url end)
        end
    end

    -- SPOTIFY API
    local function cleanToken(tok)
        if not tok then return "" end
        tok = tok:gsub("^%s+", ""):gsub("%s+$", "")
        if tok:sub(1, 7):lower() == "bearer " then
            tok = tok:sub(8)
        end
        return tok
    end

    local function spotifyRequest(endpoint, method, body)
        local token = cleanToken(Shared.Config.SpotifyToken)
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
        local token = cleanToken(Shared.Config.SpotifyToken)
        if not token or token == "" then return nil, "No Token" end

        local resp = Shared.HttpRequest({
            Url     = "https://api.spotify.com/v1/me/player/currently-playing",
            Method  = "GET",
            Headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-Type"]  = "application/json",
            },
        })

        if not resp or (resp.StatusCode and resp.StatusCode == 401) then
            return nil, "Expired/Invalid Token (401)"
        end
        if resp.StatusCode == 204 or not resp.Body or #resp.Body == 0 then
            return nil, "No Active Playback"
        end

        local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
        if not ok or not data or not data.item then return nil, "No Track Found" end
        local item = data.item

        local coverUrl = ""
        if item.album and item.album.images and #item.album.images > 0 then
            coverUrl = item.album.images[1].url or ""
        end

        return {
            name      = item.name or "Unknown",
            artist    = item.artists and item.artists[1] and item.artists[1].name or "Unknown",
            cover     = coverUrl,
            isPlaying = data.is_playing or false,
            source    = "Spotify"
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

        return {
            name      = track.name or "Unknown",
            artist    = artistName,
            cover     = coverUrl,
            isPlaying = isNowPlaying,
            source    = "Last.fm"
        }
    end

    -- ── 3D BILLBOARD GUI OVER HEAD ─────────────────────────────────
    local bbSongLbl, bbArtistLbl, bbCoverImg

    local function getHRP()
        return Shared.HumanoidRP or (Shared.Character and Shared.Character:FindFirstChild("HumanoidRootPart")) or (Player.Character and Player.Character:FindFirstChild("HumanoidRootPart"))
    end

    local function buildBillboard()
        if billboard then billboard:Destroy(); billboard = nil end
        local hrp = getHRP()
        if not hrp then return end

        billboard = Instance.new("BillboardGui")
        billboard.Name          = "MusicBillboard"
        billboard.Size          = UDim2.new(0, 250, 0, 56)
        billboard.StudsOffset   = Vector3.new(0, 3.8, 0)
        billboard.AlwaysOnTop   = false
        billboard.Adornee       = hrp
        billboard.Parent        = Shared.GUI

        local bg = Instance.new("Frame")
        bg.Size                 = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3     = Color3.fromRGB(15, 18, 24)
        bg.BackgroundTransparency = 0.15
        bg.BorderSizePixel      = 1
        bg.BorderColor3         = Color3.fromRGB(0, 160, 255)
        bg.Parent               = billboard

        local cover = Instance.new("ImageLabel")
        cover.Name                = "CoverArt"
        cover.Size                = UDim2.new(0, 48, 0, 48)
        cover.Position            = UDim2.new(0, 4, 0, 4)
        cover.BackgroundColor3    = Color3.fromRGB(25, 28, 35)
        cover.BorderSizePixel     = 1
        cover.BorderColor3        = Color3.fromRGB(60, 80, 110)
        cover.ScaleType           = Enum.ScaleType.Fit
        cover.Parent              = bg
        bbCoverImg = cover

        local songLbl = Instance.new("TextLabel")
        songLbl.Size                  = UDim2.new(1, -60, 0, 22)
        songLbl.Position              = UDim2.new(0, 56, 0, 4)
        songLbl.BackgroundTransparency = 1
        songLbl.Text                  = currentTrack.name
        songLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
        songLbl.Font                  = Enum.Font.ArimoBold
        songLbl.TextSize              = 12
        songLbl.TextXAlignment        = Enum.TextXAlignment.Left
        songLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        songLbl.Parent                = bg
        bbSongLbl = songLbl

        local artistLbl = Instance.new("TextLabel")
        artistLbl.Size                  = UDim2.new(1, -60, 0, 18)
        artistLbl.Position              = UDim2.new(0, 56, 0, 26)
        artistLbl.BackgroundTransparency = 1
        artistLbl.Text                  = currentTrack.artist .. " [" .. currentTrack.source .. "]"
        artistLbl.TextColor3            = Color3.fromRGB(0, 220, 140)
        artistLbl.Font                  = Enum.Font.Code
        artistLbl.TextSize              = 10
        artistLbl.TextXAlignment        = Enum.TextXAlignment.Left
        artistLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        artistLbl.Parent                = bg
        bbArtistLbl = artistLbl

        applyImage(bbCoverImg, currentTrack.cover)
    end

    -- ── DRAGGABLE BOTTOM-LEFT INFO WIDGET ──────────────────────────
    local hudSongLbl, hudArtistLbl, hudCoverImg, hudPlaceLbl, hudUserLbl

    local function buildHUD()
        if hudWidget then hudWidget:Destroy(); hudWidget = nil end

        local C = {
            WinBorder = Color3.fromRGB(58, 110, 165),
            TitleBar  = Color3.fromRGB(212, 208, 200),
            TitleText = Color3.fromRGB(0, 0, 0),
            BodyBg    = Color3.fromRGB(248, 250, 255),
            BorderCol = Color3.fromRGB(180, 190, 210),
            TextDark  = Color3.fromRGB(15, 25, 60),
            Accent    = Color3.fromRGB(0, 120, 40),
            SubText   = Color3.fromRGB(80, 95, 120)
        }

        local frame = Instance.new("Frame")
        frame.Name             = "Fih_BottomHUD"
        frame.Size             = UDim2.new(0, 280, 0, 108)
        frame.Position         = UDim2.new(0, 16, 1, -126)
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
        content.Size             = UDim2.new(1, 0, 1, -20)
        content.Position         = UDim2.new(0, 0, 0, 20)
        content.BackgroundTransparency = 1
        content.ZIndex           = 51
        content.Parent           = frame

        local cover = Instance.new("ImageLabel")
        cover.Size                = UDim2.new(0, 48, 0, 48)
        cover.Position            = UDim2.new(0, 6, 0, 6)
        cover.BackgroundColor3    = Color3.fromRGB(225, 230, 240)
        cover.BorderSizePixel     = 1
        cover.BorderColor3        = C.BorderCol
        cover.ScaleType           = Enum.ScaleType.Fit
        cover.ZIndex              = 52
        cover.Parent              = content
        hudCoverImg = cover

        local sLbl = Instance.new("TextLabel")
        sLbl.Size                  = UDim2.new(1, -62, 0, 18)
        sLbl.Position              = UDim2.new(0, 58, 0, 4)
        sLbl.BackgroundTransparency = 1
        sLbl.Text                  = currentTrack.name
        sLbl.TextColor3            = C.TextDark
        sLbl.Font                  = Enum.Font.ArimoBold
        sLbl.TextSize              = 12
        sLbl.TextXAlignment        = Enum.TextXAlignment.Left
        sLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        sLbl.ZIndex                = 52
        sLbl.Parent                = content
        hudSongLbl = sLbl

        local aLbl = Instance.new("TextLabel")
        aLbl.Size                  = UDim2.new(1, -62, 0, 16)
        aLbl.Position              = UDim2.new(0, 58, 0, 22)
        aLbl.BackgroundTransparency = 1
        aLbl.Text                  = currentTrack.artist .. " [" .. currentTrack.source .. "]"
        aLbl.TextColor3            = C.Accent
        aLbl.Font                  = Enum.Font.Code
        aLbl.TextSize              = 10
        aLbl.TextXAlignment        = Enum.TextXAlignment.Left
        aLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        aLbl.ZIndex                = 52
        aLbl.Parent                = content
        hudArtistLbl = aLbl

        local div = Instance.new("Frame")
        div.Size             = UDim2.new(1, -12, 0, 1)
        div.Position         = UDim2.new(0, 6, 0, 58)
        div.BackgroundColor3 = C.BorderCol
        div.BorderSizePixel  = 0
        div.ZIndex           = 52
        div.Parent           = content

        local pLbl = Instance.new("TextLabel")
        pLbl.Size                  = UDim2.new(1, -12, 0, 14)
        pLbl.Position              = UDim2.new(0, 6, 0, 62)
        pLbl.BackgroundTransparency = 1
        pLbl.Text                  = "Map: " .. placeTitle .. " (ID: " .. tostring(game.PlaceId) .. ")"
        pLbl.TextColor3            = C.SubText
        pLbl.Font                  = Enum.Font.Code
        pLbl.TextSize              = 10
        pLbl.TextXAlignment        = Enum.TextXAlignment.Left
        pLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        pLbl.ZIndex                = 52
        pLbl.Parent                = content
        hudPlaceLbl = pLbl

        local uLbl = Instance.new("TextLabel")
        uLbl.Size                  = UDim2.new(1, -12, 0, 14)
        uLbl.Position              = UDim2.new(0, 6, 0, 76)
        uLbl.BackgroundTransparency = 1
        uLbl.Text                  = "User: " .. Player.DisplayName .. " (@" .. Player.Name .. ")"
        uLbl.TextColor3            = C.SubText
        uLbl.Font                  = Enum.Font.Code
        uLbl.TextSize              = 10
        uLbl.TextXAlignment        = Enum.TextXAlignment.Left
        uLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        uLbl.ZIndex                = 52
        uLbl.Parent                = content
        hudUserLbl = uLbl

        applyImage(hudCoverImg, currentTrack.cover)
    end

    -- Update all visual elements & apply new cover image when URL changes
    local function updateVisuals(track)
        local coverChanged = (track.cover ~= lastCoverUrl)
        currentTrack = track
        lastCoverUrl = track.cover

        if bbSongLbl then bbSongLbl.Text = track.name end
        if bbArtistLbl then bbArtistLbl.Text = track.artist .. " [" .. track.source .. "]" end
        if bbCoverImg and coverChanged then applyImage(bbCoverImg, track.cover) end

        if hudSongLbl then hudSongLbl.Text = track.name end
        if hudArtistLbl then hudArtistLbl.Text = track.artist .. " [" .. track.source .. "]" end
        if hudCoverImg and coverChanged then applyImage(hudCoverImg, track.cover) end
    end

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
                    updateVisuals(track)
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
            if Shared.Flags["MusicHUD"] then buildHUD() end
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

    MkToggle(leftCol, "Bottom-Left Info HUD", "MusicHUD", 12, function(state)
        if state then
            buildHUD()
            startPolling()
        else
            if hudWidget then hudWidget:Destroy(); hudWidget = nil end
        end
    end)

    -- RIGHT COLUMN: SPOTIFY OAUTH & CONTROLS
    MkSection(rightCol, "Spotify OAuth Token", 1)

    local spotBox = Instance.new("TextBox")
    spotBox.Name                  = "SpotifyTokenInput"
    spotBox.Size                  = UDim2.new(1, 0, 0, 24)
    spotBox.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    spotBox.BorderSizePixel       = 1
    spotBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    spotBox.Text                  = (Shared.Config.SpotifyToken and Shared.Config.SpotifyToken ~= "") and "Token: Set (Click to change)" or "Paste Spotify OAuth Token"
    spotBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    spotBox.Font                  = Enum.Font.Code
    spotBox.TextSize              = 11
    spotBox.LayoutOrder           = 2
    spotBox.Parent                = rightCol

    spotBox.FocusLost:Connect(function()
        if spotBox.Text ~= "" and not spotBox.Text:find("Token: Set") then
            Shared.Config.SpotifyToken = cleanToken(spotBox.Text)
            if Shared.SaveConfig then Shared.SaveConfig() end
            spotBox.Text = "Token: Set (Click to change)"
            Shared.Notify("Spotify", "OAuth Token saved", true)
        end
    end)

    MkButton(rightCol, "[ Test Spotify Token ]", 3, function()
        local trk, err = getSpotifyTrack()
        if trk then
            updateVisuals(trk)
            Shared.Notify("Spotify", trk.name .. " - " .. trk.artist, true)
            if Shared.Flags["MusicBillboard"] then buildBillboard() end
            if Shared.Flags["MusicHUD"] then buildHUD() end
            startPolling()
        else
            Shared.Notify("Spotify", "Status: " .. tostring(err or "Failed"), false)
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

    print("[Music_Handler] Loaded -- Dynamic Covers, HUD, Bold Fonts, Respawn Tracking Online")
end
