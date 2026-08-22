-- Spotify_Handler.lua
-- Spotify Playback Controls & Billboard formatted into Quad Columns

return function(Shared)
    local Http      = Shared.Services.Http
    local Player    = Shared.Player
    local RunSvc    = Shared.Services.RunService
    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end

    local tab = Tabs["Spotify"]
    local cols = QuadCols["Spotify"]
    if not tab or not cols then
        warn("[Spotify_Handler] Quad columns not found")
        return
    end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    local CONFIG = {
        ACCESS_TOKEN = "",
    }

    local currentTrack = { name = "Not Playing", artist = "No Artist", isPlaying = false }
    local billboard    = nil
    local pollConn     = nil
    local BASE = "https://api.spotify.com/v1/me/player"

    local function spotifyRequest(endpoint, method, body)
        if CONFIG.ACCESS_TOKEN == "" then return nil end
        local ok, result = pcall(function()
            return Http:RequestAsync({
                Url     = BASE .. endpoint,
                Method  = method or "GET",
                Headers = {
                    ["Authorization"] = "Bearer " .. CONFIG.ACCESS_TOKEN,
                    ["Content-Type"]  = "application/json",
                },
                Body    = body and Http:JSONEncode(body) or nil,
            })
        end)
        return ok and result or nil
    end

    local function getCurrentTrack()
        local resp = spotifyRequest("", "GET")
        if not resp or resp.StatusCode ~= 200 then return nil end
        local ok, data = pcall(function() return Http:JSONDecode(resp.Body) end)
        if not ok or not data or not data.item then return nil end
        local item = data.item
        return {
            name      = item.name or "Unknown",
            artist    = item.artists and item.artists[1] and item.artists[1].name or "Unknown",
            isPlaying = data.is_playing,
        }
    end

    local function buildBillboard()
        if billboard then billboard:Destroy(); billboard = nil end
        local hrp = Shared.HumanoidRP
        if not hrp then return end

        billboard = Instance.new("BillboardGui")
        billboard.Name          = "SpotifyBillboard"
        billboard.Size          = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset   = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop   = false
        billboard.Adornee       = hrp
        billboard.Parent        = Shared.GUI

        local bg = Instance.new("Frame")
        bg.Size             = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        bg.BackgroundTransparency = 0.2
        bg.BorderSizePixel  = 1
        bg.BorderColor3     = Color3.fromRGB(30, 215, 96)
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
        artistLbl.Text                  = currentTrack.artist
        artistLbl.TextColor3            = Color3.fromRGB(30, 215, 96)
        artistLbl.Font                  = Enum.Font.Code
        artistLbl.TextSize              = 10
        artistLbl.TextXAlignment        = Enum.TextXAlignment.Left
        artistLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        artistLbl.Parent                = bg

        Shared._SpotifyLabels = { songLbl, artistLbl }
    end

    local function startPolling()
        if pollConn then pollConn:Disconnect() end
        local elapsed = 0
        pollConn = RunSvc.Heartbeat:Connect(function(dt)
            elapsed = elapsed + dt
            if elapsed >= 5 then
                elapsed = 0
                local track = getCurrentTrack()
                if track then
                    currentTrack = track
                    if Shared._SpotifyLabels then
                        Shared._SpotifyLabels[1].Text = track.name
                        Shared._SpotifyLabels[2].Text = track.artist
                    end
                end
            end
        end)
    end

    -- LEFT COLUMN: AUTH & SETTINGS
    MkSection(leftCol, "Authentication", 1)
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size                  = UDim2.new(1, 0, 0, 20)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text                  = "Status: Paste Token in CONFIG"
    statusLbl.TextColor3            = Color3.fromRGB(120, 120, 140)
    statusLbl.Font                  = Enum.Font.Code
    statusLbl.TextSize              = 10
    statusLbl.TextXAlignment        = Enum.TextXAlignment.Left
    statusLbl.LayoutOrder           = 2
    statusLbl.Parent                = leftCol

    MkButton(leftCol, "[ Connect Playback API ]", 3, function()
        buildBillboard()
        startPolling()
        statusLbl.Text = "Status: Polling Spotify Active"
        statusLbl.TextColor3 = Color3.fromRGB(0, 160, 60)
    end)

    MkToggle(leftCol, "Head Billboard Display", "SpotifyBillboard", 4, function(state)
        if state then buildBillboard(); startPolling() else if billboard then billboard:Destroy(); billboard = nil end end
    end)

    -- RIGHT COLUMN: PLAYBACK CONTROLS
    MkSection(rightCol, "Track Controls", 1)
    MkButton(rightCol, "⏮  Previous Track", 2, function() spotifyRequest("/previous", "POST") end)
    MkButton(rightCol, "⏯  Play / Pause", 3, function()
        local t = getCurrentTrack()
        spotifyRequest(t and t.isPlaying and "/pause" or "/play", t and t.isPlaying and "PUT" or "PUT")
    end)
    MkButton(rightCol, "⏭  Next Track", 4, function() spotifyRequest("/next", "POST") end)

    print("[Spotify_Handler] Loaded -- Spotify Quad panel ready")
end
