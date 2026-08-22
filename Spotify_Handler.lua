-- Spotify_Handler.lua
-- Connect to Spotify via access token, display song above head as BillboardGui
-- Controls: skip, prev, pause/play
-- SETUP: Go to developer.spotify.com, create an app, get an access token with scopes:
--   user-read-playback-state  user-modify-playback-state
-- Then paste the token into CONFIG.ACCESS_TOKEN below

return function(Shared)
    local Http      = Shared.Services.Http
    local Player    = Shared.Player
    local RunSvc    = Shared.Services.RunService
    local Tabs      = Shared.Tabs
    local MkSection = Shared.MakeSection
    local MkButton  = Shared.MakeButton
    local MkToggle  = Shared.MakeToggle

    local tab = Tabs["Spotify"]

    -- CONFIGURATION
    local CONFIG = {
        ACCESS_TOKEN = "",  -- Paste your Spotify access token here
    }

    local currentTrack = { name = "Not Playing", artist = "", isPlaying = false }
    local billboard    = nil
    local pollConn     = nil

    -- SPOTIFY API HELPERS
    local BASE = "https://api.spotify.com/v1/me/player"

    local function spotifyRequest(endpoint, method, body)
        if CONFIG.ACCESS_TOKEN == "" then
            warn("[Spotify] No access token set.")
            return nil
        end
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
        if not ok then
            warn("[Spotify] Request failed: " .. tostring(result))
            return nil
        end
        return result
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

    -- BILLBOARD ABOVE HEAD
    local function buildBillboard()
        if billboard then billboard:Destroy(); billboard = nil end
        local hrp = Shared.HumanoidRP
        if not hrp then return end

        billboard = Instance.new("BillboardGui")
        billboard.Name          = "SpotifyBillboard"
        billboard.Size          = UDim2.new(0, 210, 0, 60)
        billboard.StudsOffset   = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop   = false
        billboard.Adornee       = hrp
        billboard.Parent        = Shared.GUI

        local bg = Instance.new("Frame")
        bg.Size             = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        bg.BackgroundTransparency = 0.15
        bg.BorderSizePixel  = 0
        bg.Parent           = billboard
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

        -- Music note icon placeholder (Roblox cant load external images directly)
        local art = Instance.new("ImageLabel")
        art.Size             = UDim2.new(0, 44, 0, 44)
        art.Position         = UDim2.new(0, 8, 0.5, -22)
        art.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
        art.BorderSizePixel  = 0
        art.Image            = "rbxassetid://3926305904"
        art.Parent           = bg
        Instance.new("UICorner", art).CornerRadius = UDim.new(0, 6)

        local songLbl = Instance.new("TextLabel")
        songLbl.Name                  = "SongName"
        songLbl.Size                  = UDim2.new(1, -62, 0, 24)
        songLbl.Position              = UDim2.new(0, 58, 0, 8)
        songLbl.BackgroundTransparency = 1
        songLbl.Text                  = currentTrack.name
        songLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
        songLbl.Font                  = Enum.Font.GothamBold
        songLbl.TextSize              = 12
        songLbl.TextXAlignment        = Enum.TextXAlignment.Left
        songLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        songLbl.Parent                = bg

        local artistLbl = Instance.new("TextLabel")
        artistLbl.Name                  = "ArtistName"
        artistLbl.Size                  = UDim2.new(1, -62, 0, 18)
        artistLbl.Position              = UDim2.new(0, 58, 0, 32)
        artistLbl.BackgroundTransparency = 1
        artistLbl.Text                  = currentTrack.artist
        artistLbl.TextColor3            = Color3.fromRGB(180, 180, 180)
        artistLbl.Font                  = Enum.Font.Gotham
        artistLbl.TextSize              = 10
        artistLbl.TextXAlignment        = Enum.TextXAlignment.Left
        artistLbl.TextTruncate          = Enum.TextTruncate.AtEnd
        artistLbl.Parent                = bg

        local dot = Instance.new("Frame")
        dot.Size             = UDim2.new(0, 6, 0, 6)
        dot.Position         = UDim2.new(1, -10, 0, 6)
        dot.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
        dot.BorderSizePixel  = 0
        dot.Parent           = bg
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        Shared._SpotifyLabels = { songLbl, artistLbl }
    end

    local function updateBillboard(track)
        if not Shared._SpotifyLabels then return end
        local s, a = Shared._SpotifyLabels[1], Shared._SpotifyLabels[2]
        if s then s.Text = track.name end
        if a then a.Text = track.artist end
    end

    -- POLL LOOP (every 5 seconds)
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
                    if billboard then updateBillboard(track) end
                end
            end
        end)
    end

    -- UI
    MkSection(tab, "Spotify", 1)

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name                  = "SpotifyStatus"
    statusLbl.Size                  = UDim2.new(1, -4, 0, 20)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text                  = "Status: Token not set"
    statusLbl.TextColor3            = Color3.fromRGB(150, 150, 150)
    statusLbl.Font                  = Enum.Font.Gotham
    statusLbl.TextSize              = 11
    statusLbl.TextXAlignment        = Enum.TextXAlignment.Left
    statusLbl.LayoutOrder           = 2
    statusLbl.Parent                = tab

    MkButton(tab, "Connect Spotify", 3, function()
        if CONFIG.ACCESS_TOKEN == "" then
            statusLbl.Text      = "Set ACCESS_TOKEN in Spotify_Handler.lua"
            statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
            return
        end
        buildBillboard()
        startPolling()
        statusLbl.Text       = "Connected"
        statusLbl.TextColor3 = Color3.fromRGB(30, 215, 96)
    end)

    MkButton(tab, "Previous Track", 4, function()
        spotifyRequest("/previous", "POST")
    end)

    MkButton(tab, "Play / Pause", 5, function()
        local track = getCurrentTrack()
        if track and track.isPlaying then
            spotifyRequest("/pause", "PUT")
        else
            spotifyRequest("/play", "PUT")
        end
    end)

    MkButton(tab, "Next Track", 6, function()
        spotifyRequest("/next", "POST")
    end)

    MkToggle(tab, "Billboard Above Head", "SpotifyBillboard", 7, function(state)
        if state then
            buildBillboard()
            startPolling()
        else
            if pollConn then pollConn:Disconnect(); pollConn = nil end
            if billboard then billboard:Destroy(); billboard = nil end
        end
    end)

    Player.CharacterAdded:Connect(function()
        task.wait(1)
        Shared.HumanoidRP = Shared.Character and Shared.Character:WaitForChild("HumanoidRootPart")
        if Shared.Flags["SpotifyBillboard"] then
            buildBillboard()
        end
    end)

    print("[Spotify_Handler] Loaded -- set CONFIG.ACCESS_TOKEN to connect")
end
