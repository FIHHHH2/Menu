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

    -- ── 7-STAGE CASCADING ALBUM ARTWORK PIPELINE ────────────────
    -- Validates binary image bytes and chains through fallback endpoints
    local function isValidImageData(data)
        if not data or type(data) ~= "string" or #data < 400 then return false end
        local b1, b2 = string.byte(data, 1, 2)
        -- JPEG (FF D8) or PNG (89 50) or GIF (47 49) or WEBP (52 49)
        if (b1 == 255 and b2 == 216) or (b1 == 137 and b2 == 80) or (b1 == 71 and b2 == 73) or (b1 == 82 and b2 == 73) then
            return true
        end
        return false
    end

    local function downloadImageBytes(url)
        if not url or url == "" then return nil end
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and isValidImageData(res) then return res end

        local reqRes = Shared.HttpRequest({
            Url     = url,
            Method  = "GET",
            Headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
        })
        if reqRes and reqRes.Body and isValidImageData(reqRes.Body) then
            return reqRes.Body
        end
        return nil
    end

    -- Collects all available candidate URLs across multiple public databases
    local function gatherCoverCandidates(artist, trackName, primaryUrl)
        local list = {}
        if primaryUrl and primaryUrl ~= "" and primaryUrl:find("http") then
            table.insert(list, primaryUrl)
        end

        if not artist or not trackName or trackName == "Not Playing" or trackName == "Unknown" then
            return list
        end

        local cleanArtist = tostring(artist):gsub("%b()", ""):gsub("%b[]", ""):gsub("ft%..*", ""):gsub("feat%..*", ""):gsub("^%s+", ""):gsub("%s+$", "")
        local cleanTrack  = tostring(trackName):gsub("%b()", ""):gsub("%b[]", ""):gsub("ft%..*", ""):gsub("feat%..*", ""):gsub("^%s+", ""):gsub("%s+$", "")
        local term = Http:UrlEncode(cleanArtist .. " " .. cleanTrack)

        -- 1. Apple iTunes Search API (HD 600x600)
        pcall(function()
            local res = game:HttpGet("https://itunes.apple.com/search?term=" .. term .. "&media=music&entity=song&limit=1")
            if res and #res > 0 then
                local data = Http:JSONDecode(res)
                if data and data.results and data.results[1] and data.results[1].artworkUrl100 then
                    local art = data.results[1].artworkUrl100:gsub("100x100bb", "600x600bb")
                    table.insert(list, art)
                    table.insert(list, data.results[1].artworkUrl100)
                end
            end
        end)

        -- 2. Deezer Search API
        pcall(function()
            local res = game:HttpGet("https://api.deezer.com/search?q=" .. term .. "&limit=1")
            if res and #res > 0 then
                local data = Http:JSONDecode(res)
                if data and data.data and data.data[1] and data.data[1].album then
                    local alb = data.data[1].album
                    if alb.cover_xl then table.insert(list, alb.cover_xl) end
                    if alb.cover_big then table.insert(list, alb.cover_big) end
                    if alb.cover_medium then table.insert(list, alb.cover_medium) end
                end
            end
        end)

        -- 3. Last.fm track.getInfo API
        pcall(function()
            local url = "https://ws.audioscrobbler.com/2.0/?method=track.getInfo&api_key=" .. LASTFM_API_KEY .. "&artist=" .. Http:UrlEncode(artist) .. "&track=" .. Http:UrlEncode(trackName) .. "&format=json"
            local res = game:HttpGet(url)
            if res and #res > 0 then
                local data = Http:JSONDecode(res)
                if data and data.track and data.track.album and data.track.album.image then
                    for i = #data.track.album.image, 1, -1 do
                        local imgObj = data.track.album.image[i]
                        if imgObj and imgObj["#text"] and #imgObj["#text"] > 0 then
                            table.insert(list, imgObj["#text"])
                        end
                    end
                end
            end
        end)

        -- 4. Genius Multi-Search API
        pcall(function()
            local res = game:HttpGet("https://genius.com/api/search/multi?q=" .. term)
            if res and #res > 0 then
                local data = Http:JSONDecode(res)
                if data and data.response and data.response.sections then
                    for _, sec in ipairs(data.response.sections) do
                        if sec.hits and sec.hits[1] and sec.hits[1].result then
                            local r = sec.hits[1].result
                            if r.song_art_image_url then table.insert(list, r.song_art_image_url) end
                            if r.header_image_url then table.insert(list, r.header_image_url) end
                            break
                        end
                    end
                end
            end
        end)

        -- 5. Last.fm artist.getInfo fallback (Artist avatar if no album cover)
        pcall(function()
            local url = "https://ws.audioscrobbler.com/2.0/?method=artist.getInfo&api_key=" .. LASTFM_API_KEY .. "&artist=" .. Http:UrlEncode(artist) .. "&format=json"
            local res = game:HttpGet(url)
            if res and #res > 0 then
                local data = Http:JSONDecode(res)
                if data and data.artist and data.artist.image then
                    for i = #data.artist.image, 1, -1 do
                        local imgObj = data.artist.image[i]
                        if imgObj and imgObj["#text"] and #imgObj["#text"] > 0 then
                            table.insert(list, imgObj["#text"])
                        end
                    end
                end
            end
        end)

        return list
    end

    local currentLoadingToken = 0
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

        currentLoadingToken = currentLoadingToken + 1
        local myToken = currentLoadingToken

        task.spawn(function()
            local candidates = gatherCoverCandidates(artist, trackName, rawUrl)
            local getcustomasset = getcustomasset or getsynasset or (getgenv and getgenv().getcustomasset)
            local writefile      = writefile or (getgenv and getgenv().writefile)
            local delfile        = delfile or (getgenv and getgenv().delfile)

            local ContentProvider = game:GetService("ContentProvider")

            for _, candidateUrl in ipairs(candidates) do
                if myToken ~= currentLoadingToken then return end
                local imgBytes = downloadImageBytes(candidateUrl)

                if imgBytes and isValidImageData(imgBytes) then
                    if getcustomasset and writefile then
                        local uniqueName = "fih_cov_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)) .. ".png"
                        local okW = pcall(function() writefile(uniqueName, imgBytes) end)
                        if okW then
                            local okA, newAsset = pcall(function() return getcustomasset(uniqueName) end)
                            if okA and newAsset and newAsset ~= "" then
                                if myToken == currentLoadingToken and imgLabel and imgLabel.Parent then
                                    imgLabel.Image = newAsset
                                    imgLabel.BackgroundTransparency = 1
                                    imgLabel.Visible = true

                                    -- Verify texture renders successfully
                                    local loaded = true
                                    local okPreload = pcall(function()
                                        ContentProvider:PreloadAsync({ imgLabel })
                                    end)
                                    task.wait(0.05)
                                    if imgLabel.IsLoaded == false then
                                        loaded = false
                                    end

                                    if loaded then
                                        if previousCoverFile ~= "" and previousCoverFile ~= uniqueName and delfile then
                                            pcall(function() delfile(previousCoverFile) end)
                                        end
                                        previousCoverFile = uniqueName
                                        currentCoverAsset = newAsset
                                        lastLoadedCoverUrl = candidateUrl
                                        return
                                    else
                                        -- Texture failed to render, try next candidate stage
                                        if delfile then pcall(function() delfile(uniqueName) end) end
                                    end
                                end
                            end
                        end
                    else
                        if myToken == currentLoadingToken and imgLabel and imgLabel.Parent then
                            imgLabel.Image = candidateUrl
                            imgLabel.BackgroundTransparency = 1
                            imgLabel.Visible = true
                            task.wait(0.05)
                            if imgLabel.IsLoaded ~= false then
                                return
                            end
                        end
                    end
                end
            end

            -- If all candidate downloads failed, clear image cleanly without white box
            if myToken == currentLoadingToken and imgLabel and imgLabel.Parent then
                imgLabel.Image = ""
                imgLabel.Visible = true
            end
        end)
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
            name      = trackName,
            artist    = artistName,
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
        billboard.Size          = UDim2.new(0, 260, 0, 58)
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
        cover.Position            = UDim2.new(0, 5, 0, 5)
        cover.BackgroundColor3    = Color3.fromRGB(25, 28, 35)
        cover.BorderSizePixel     = 1
        cover.BorderColor3        = Color3.fromRGB(60, 80, 110)
        cover.ScaleType           = Enum.ScaleType.Fit
        cover.Parent              = bg
        bbCoverImg = cover

        local songLbl = Instance.new("TextLabel")
        songLbl.Size                  = UDim2.new(1, -62, 0, 20)
        songLbl.Position              = UDim2.new(0, 58, 0, 7)
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
        artistLbl.Size                  = UDim2.new(1, -62, 0, 16)
        artistLbl.Position              = UDim2.new(0, 58, 0, 30)
        artistLbl.BackgroundTransparency = 1
        artistLbl.Text                  = currentTrack.artist .. " [" .. currentTrack.source .. "]"
        artistLbl.TextColor3            = Color3.fromRGB(0, 220, 140)
        artistLbl.Font                  = Enum.Font.Code
        artistLbl.TextSize              = 10
        artistLbl.TextXAlignment        = Enum.TextXAlignment.Left
        artistLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        artistLbl.Parent                = bg
        bbArtistLbl = artistLbl

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
        frame.Size             = UDim2.new(0, 290, 0, 114)
        frame.Position         = UDim2.new(0, 16, 1, -130)
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
        noteIcon.Text                   = "🎵"
        noteIcon.TextSize               = 22
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

        -- Divider Line
        local div = Instance.new("Frame")
        div.Size             = UDim2.new(1, 0, 0, 1)
        div.Position         = UDim2.new(0, 0, 0, 46)
        div.BackgroundColor3 = C.BorderCol
        div.BorderSizePixel  = 0
        div.ZIndex           = 53
        div.Parent           = rightBox

        -- Place Info (Moved down)
        local pLbl = Instance.new("TextLabel")
        pLbl.Size                  = UDim2.new(1, 0, 0, 15)
        pLbl.Position              = UDim2.new(0, 0, 0, 52)
        pLbl.BackgroundTransparency = 1
        pLbl.Text                  = "Map: " .. placeTitle .. " (ID: " .. tostring(game.PlaceId) .. ")"
        pLbl.TextColor3            = C.SubText
        pLbl.Font                  = Enum.Font.Code
        pLbl.TextSize              = 10
        pLbl.TextXAlignment        = Enum.TextXAlignment.Left
        pLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        pLbl.ZIndex                = 53
        pLbl.Parent                = rightBox
        hudPlaceLbl = pLbl

        -- User Info (Moved down)
        local uLbl = Instance.new("TextLabel")
        uLbl.Size                  = UDim2.new(1, 0, 0, 15)
        uLbl.Position              = UDim2.new(0, 0, 0, 69)
        uLbl.BackgroundTransparency = 1
        uLbl.Text                  = "User: " .. Player.DisplayName .. " (@" .. Player.Name .. ")"
        uLbl.TextColor3            = C.SubText
        uLbl.Font                  = Enum.Font.Code
        uLbl.TextSize              = 10
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
    end

    -- Update all visual elements & apply new cover image when URL changes
    local function updateVisuals(track)
        currentTrack = track

        if bbSongLbl then bbSongLbl.Text = track.name end
        if bbArtistLbl then bbArtistLbl.Text = track.artist .. " [" .. track.source .. "]" end
        if bbCoverImg then applyImage(bbCoverImg, track) end

        if hudSongLbl then hudSongLbl.Text = track.name end
        if hudArtistLbl then hudArtistLbl.Text = track.artist .. " [" .. track.source .. "]" end
        if hudCoverImg then applyImage(hudCoverImg, track) end

        -- Broadcast updated track to peer script users immediately
        if Shared.BroadcastBeacon then
            pcall(Shared.BroadcastBeacon)
        end
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
            if not hudWidget then buildHUD() end
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

    print("[Music_Handler] Loaded -- Dynamic Covers, Scaled HUD, Clean Typography Online")
end
