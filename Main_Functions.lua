-- Main_Functions.lua
-- Movement, Stat Multipliers, World Modifiers, and Performance & FPS Boost Suite

return function(Shared)
    local Players      = Shared.Services.Players
    local RunService   = Shared.Services.RunService
    local UserInput    = Shared.Services.UserInput
    local TweenService = Shared.Services.TweenService
    local Lighting     = game:GetService("Lighting")

    local Player    = Shared.Player
    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkSlider  = Shared.MakeSlider  or function() return Instance.new("Frame") end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab  = Tabs["Main"]
    local cols = QuadCols["Main"]
    if not tab or not cols then return end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    local function getChar()  return Shared.Character or Player.Character end
    local function getHRP()   return Shared.HumanoidRP or (getChar() and getChar():FindFirstChild("HumanoidRootPart")) end
    local function getHuman() return getChar() and getChar():FindFirstChildOfClass("Humanoid") end

    local function restoreDefaultCollisions(char)
        if Shared.Flags["FragilePlayer"] then setupFragileCharacter(char) end
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == "HumanoidRootPart" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" or part.Name == "Head" then
                    part.CanCollide = true
                else
                    -- Limbs (arms, legs, hands, feet) and accessory handles MUST be CanCollide = false
                    part.CanCollide = false
                end
            end
        end
    end

    -- ── LEFT COLUMN: MOVEMENT & PHYSICS ──────────────────────────
    MkSection(leftCol, "Movement & Physics", 1)

    local infJumpConn
    MkToggle(leftCol, "Infinite Jump", "InfiniteJump", 2, function(state)
        if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
        if state then
            infJumpConn = UserInput.JumpRequest:Connect(function()
                local hum = getHuman(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        end
    end)

    local flightBV, flightConn
    MkToggle(leftCol, "Flight", "Flight", 3, function(state)
        local hrp = getHRP(); if not hrp then return end
        if state then
            hrp.Velocity = Vector3.zero
            flightBV = Instance.new("BodyVelocity")
            flightBV.MaxForce = Vector3.new(1e5,1e5,1e5); flightBV.Velocity = Vector3.zero; flightBV.Parent = hrp
            local cam = workspace.CurrentCamera
            flightConn = RunService.Heartbeat:Connect(function()
                if not Shared.Flags["Flight"] then return end
                local speed = Shared.Flags["FlightSpeed"] or 65; local dir = Vector3.zero
                if UserInput:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInput:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInput:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInput:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInput:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
                if UserInput:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
                flightBV.Velocity = dir.Magnitude > 0 and (dir.Unit * speed) or Vector3.zero
            end)
        else
            if flightConn then flightConn:Disconnect(); flightConn = nil end
            if flightBV   then flightBV:Destroy();     flightBV   = nil end
        end
    end)

    MkSlider(leftCol, "Flight Speed", "FlightSpeed", 20, 300, 65, 4, function(val) Shared.Flags["FlightSpeed"] = val end)

    local noclipConn
    MkToggle(leftCol, "Noclip", "Noclip", 5, function(state)
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        if state then
            noclipConn = RunService.Stepped:Connect(function()
                local char = getChar(); if not char then return end
                for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
            end)
        else
            local char = getChar()
            if char then restoreDefaultCollisions(char)
        if Shared.Flags["FragilePlayer"] then setupFragileCharacter(char) end end
        end
    end)

    local clickTPConn
    MkToggle(leftCol, "Click TP (Ctrl + Click)", "ClickTP", 6, function(state)
        if clickTPConn then clickTPConn:Disconnect(); clickTPConn = nil end
        if state then
            clickTPConn = UserInput.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local isCtrlHeld = UserInput:IsKeyDown(Enum.KeyCode.LeftControl) or UserInput:IsKeyDown(Enum.KeyCode.RightControl)
                    if isCtrlHeld then
                        local hrp = getHRP(); if not hrp then return end
                        local mouse = Player:GetMouse()
                        if mouse and mouse.Hit then
                            hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3.2, 0))
                        else
                            local mouseLoc = UserInput:GetMouseLocation()
                            local cam = workspace.CurrentCamera
                            local ray = cam:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
                            local params = RaycastParams.new()
                            params.FilterDescendantsInstances = {getChar()}
                            params.FilterType = Enum.RaycastFilterType.Exclude
                            local res = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
                            if res then
                                hrp.CFrame = CFrame.new(res.Position + Vector3.new(0, 3.2, 0))
                            end
                        end
                    end
                end
            end)
        end
    end)

    MkToggle(leftCol, "Anti-Ragdoll", "AntiRagdoll", 7, function(state)
        local char = getChar(); if not char then return end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BallSocketConstraint") or obj:IsA("HingeConstraint") then
                obj.Enabled = not state
            end
        end
    end)

    -- ── Fragile Player (Glass Character / Shatter on Impact) ──────
    local fragileConns = {}
    local fragileCooldown = false

    local function setupFragileCharacter(char)
        for _, conn in ipairs(fragileConns) do pcall(function() conn:Disconnect() end) end
        fragileConns = {}

        if not char then return end
        local hum = char:WaitForChild("Humanoid", 3)
        local hrp = char:WaitForChild("HumanoidRootPart", 3)
        if not hum or not hrp then return end

        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                local conn = part.Touched:Connect(function(hit)
                    if not Shared.Flags["FragilePlayer"] or fragileCooldown then return end
                    if not hit or not hit.Parent or hit:IsDescendantOf(char) then return end

                    -- Check if touched by another player or moving object/floor with momentum
                    local hitHum = hit.Parent:FindFirstChildOfClass("Humanoid") or (hit.Parent.Parent and hit.Parent.Parent:FindFirstChildOfClass("Humanoid"))
                    local isFast = hrp.AssemblyLinearVelocity.Magnitude > 12 or hit.AssemblyLinearVelocity.Magnitude > 8

                    if hitHum or isFast then
                        fragileCooldown = true
                        local force = Shared.Flags["FragileForce"] or 85
                        local hitDir = (hrp.Position - hit.Position).Magnitude > 0.1 and (hrp.Position - hit.Position).Unit or Vector3.new(0, 1, 0)

                        -- Ragdoll collapse
                        hum.PlatformStand = true
                        hum:ChangeState(Enum.HumanoidStateType.FallingDown)
                        hrp.AssemblyLinearVelocity = hitDir * force + Vector3.new(0, force * 0.6, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))

                        -- Auto recover after short comedic delay
                        task.delay(1.6, function()
                            if hum and hum.Parent then
                                hum.PlatformStand = false
                                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                            end
                            task.wait(0.3)
                            fragileCooldown = false
                        end)
                    end
                end)
                table.insert(fragileConns, conn)
            end
        end
    end

    MkToggle(leftCol, "Fragile Player (Glass Mode)", "FragilePlayer", 8, function(state)
        if state then
            setupFragileCharacter(getChar())
            Shared.Notify("Fragile Player", "Glass Physics Enabled -- Ragdoll on Contact", true)
        else
            for _, conn in ipairs(fragileConns) do pcall(function() conn:Disconnect() end) end
            fragileConns = {}
            local hum = getHuman()
            if hum then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            Shared.Notify("Fragile Player", "Glass Mode Disabled", false)
        end
    end)

    MkSlider(leftCol, "Fragile Knockback Force", "FragileForce", 20, 250, 85, 9, function(val)
        Shared.Flags["FragileForce"] = val
    end)

    MkButton(leftCol, "[ Force Respawn ]", 10, function()
        Player:LoadCharacter()
    end)



    -- ── RIGHT COLUMN: STAT MULTIPLIERS & WORLD ───────────────────
    MkSection(rightCol, "Stat Multipliers", 10)

    MkSlider(rightCol, "Walk Speed", "WalkSpeed", 16, 250, 16, 11, function(val)
        local hum = getHuman(); if hum then hum.WalkSpeed = val end
    end)
    local function applyJumpStats(hum, val)
        if not hum then return end
        pcall(function()
            hum.UseJumpPower = false
            hum.JumpHeight   = val
            -- Scale JumpPower for games enforcing UseJumpPower (50 power ~ 7.2 height)
            hum.JumpPower    = math.clamp(val * 7, 50, 1000)
        end)
    end

    MkSlider(rightCol, "Jump Height", "JumpHeight", 7, 250, 7, 12, function(val)
        Shared.Flags["JumpHeight"] = val
        local hum = getHuman(); applyJumpStats(hum, val)
    end)

    -- Continuous jump & speed enforcement loop
    RunService.Heartbeat:Connect(function()
        local hum = getHuman()
        if hum then
            if Shared.Flags["JumpHeight"] and Shared.Flags["JumpHeight"] > 7 then
                applyJumpStats(hum, Shared.Flags["JumpHeight"])
            end
            if Shared.Flags["WalkSpeed"] and Shared.Flags["WalkSpeed"] > 16 then
                hum.WalkSpeed = Shared.Flags["WalkSpeed"]
            end
        end
    end)

    Player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid"); task.wait(0.1)
        hum.WalkSpeed  = Shared.Flags["WalkSpeed"]  or 16
        applyJumpStats(hum, Shared.Flags["JumpHeight"] or 7)
        restoreDefaultCollisions(char)
        if Shared.Flags["FragilePlayer"] then setupFragileCharacter(char) end
    end)

    MkSection(rightCol, "World Modifiers", 20)

    MkSlider(rightCol, "Gravity", "Gravity", 10, 200, 196, 21, function(val)
        workspace.Gravity = val
    end)

    MkSlider(rightCol, "Reach Extender", "Reach", 2, 40, 2, 22, function(val)
        local hrp = getHRP()
        if hrp then
            if val <= 2 then
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.CanCollide = true
            else
                hrp.Size = Vector3.new(val, 2, val)
                -- Keep enlarged root part non-collidable so player can fit through tight spaces and doors
                hrp.CanCollide = false
            end
        end
    end)

    local antiAimConn
    MkToggle(rightCol, "Anti-Aim (Spin HRP)", "AntiAim", 23, function(state)
        if antiAimConn then antiAimConn:Disconnect(); antiAimConn = nil end
        if state then
            local t = 0
            antiAimConn = RunService.RenderStepped:Connect(function(dt)
                t = t + dt * 10
                local hrp = getHRP(); if not hrp then return end
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(t*15), 0)
            end)
        end
    end)

    MkSection(rightCol, "Camera & View", 30)

    MkSlider(rightCol, "FOV", "FOV", 70, 120, 70, 31, function(val)
        if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = val end
    end)

    MkToggle(rightCol, "Full Bright", "FullBright", 32, function(state)
        if state then
            Lighting.Brightness = 2; Lighting.ClockTime = 14
            Lighting.FogEnd = 1e6; Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 1; Lighting.ClockTime = 14
            Lighting.FogEnd = 1e6; Lighting.GlobalShadows = true
        end
    end)

    -- ── RIGHT COLUMN: UNIVERSAL ESP & CROSS-PLAYER DETECTION ──────
    MkSection(rightCol, "Universal ESP & Peer Radar", 35)

    local peerUsers = {}          -- [UserId] = { isPeer = true, song = "", artist = "", cover = "", billboard = nil, visBars = {}, lastSeen = 0 }
    local universalESPList = {}   -- [Player] = { gui = BillboardGui, hl = Highlight, lbl = TextLabel, bg = Frame }
    local universalESPConn = nil

    local TAG_NAME = "Fih_PeerTag"
    local curJobIdClean = (game.JobId ~= "" and game.JobId:gsub("-", "")) or "local_server"

    local ronaldAsset = nil
    local function getRonaldAsset()
        if ronaldAsset then return ronaldAsset end
        local gca = getcustomasset or getsynasset or (getgenv and (getgenv().getcustomasset or getgenv().getsynasset))
        local wf  = writefile or (getgenv and getgenv().writefile)
        local isf = isfile or (getgenv and getgenv().isfile)
        local fname = "fih_ronald.png"
        if gca and wf then
            pcall(function()
                if not (isf and isf(fname)) then
                    local bytes = game:HttpGet("https://raw.githubusercontent.com/FIHHHH2/Menu/main/ronald_cat.png")
                    if bytes and #bytes > 1000 then wf(fname, bytes) end
                end
            end)
            local ok, a = pcall(function() return gca(fname) end)
            if ok and a and a ~= "" then
                ronaldAsset = a
                return a
            end
        end
        return "https://raw.githubusercontent.com/FIHHHH2/Menu/main/ronald_cat.png"
    end

    -- Create or update an AlwaysOnTop 3D Overhead Music Billboard on a Peer Player
    local function updatePeerBillboard(plr, songName, artistName, coverUrl)
        if not plr or not plr.Character then return end
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local info = peerUsers[plr.UserId]
        if not info then return end

        local isPlaying = (songName and songName ~= "" and songName ~= "Not Playing")

        if not info.billboard or not info.billboard.Parent or info.billboard.Adornee ~= hrp then
            if info.billboard then pcall(function() info.billboard:Destroy() end) end

            local head = plr.Character:FindFirstChild("Head") or hrp

            local bb = Instance.new("BillboardGui")
            bb.Name                   = "PeerMusicBillboard_" .. tostring(plr.UserId)
            bb.Size                   = UDim2.new(0, 280, 0, 68)
            bb.StudsOffsetWorldSpace  = Vector3.new(0, 4.2, 0)
            bb.AlwaysOnTop            = (Shared.Flags and Shared.Flags["UniversalESP"]) or false
            bb.Active                 = true
            bb.MaxDistance            = 75
            bb.ClipsDescendants       = false
            bb.Adornee                = head
            bb.Parent                 = Shared.GUI

            local bg = Instance.new("Frame")
            bg.Size                   = UDim2.new(1, 0, 1, 0)
            bg.BackgroundColor3       = Color3.fromRGB(15, 18, 24)
            bg.BackgroundTransparency = 0.15
            bg.BorderSizePixel        = 1
            bg.BorderColor3           = Color3.fromRGB(255, 205, 30)
            bg.ClipsDescendants       = false
            bg.Parent                 = bb

            -- Ronald Cat Overlay INSIDE BG on far right side
            local ronaldImg = Instance.new("ImageLabel")
            ronaldImg.Name                   = "RonaldCatOverlay"
            ronaldImg.Size                   = UDim2.new(0, 38, 0, 52)
            ronaldImg.AnchorPoint            = Vector2.new(1, 0.5)
            ronaldImg.Position               = UDim2.new(1, -6, 0.5, 0)
            ronaldImg.BackgroundTransparency = 1
            ronaldImg.BorderSizePixel        = 0
            ronaldImg.ScaleType              = Enum.ScaleType.Fit
            ronaldImg.ZIndex                 = 25
            ronaldImg.Image                  = getRonaldAsset()
            ronaldImg.Parent                 = bg

            -- Album Cover Container
            local coverFrame = Instance.new("Frame")
            coverFrame.Name             = "CoverContainer"
            coverFrame.Size             = UDim2.new(0, 52, 0, 52)
            coverFrame.Position         = UDim2.new(0, 6, 0, 8)
            coverFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
            coverFrame.BorderSizePixel  = 1
            coverFrame.BorderColor3     = Color3.fromRGB(255, 205, 30)
            coverFrame.ClipsDescendants = true
            coverFrame.Parent           = bg

            local note = Instance.new("TextLabel")
            note.Name                   = "NoteFallback"
            note.Size                   = UDim2.new(1, 0, 1, 0)
            note.BackgroundTransparency = 1
            note.Text                   = "🎵"
            note.TextSize               = 22
            note.TextColor3             = Color3.fromRGB(255, 215, 50)
            note.ZIndex                 = 1
            note.Parent                 = coverFrame

            local coverImg = Instance.new("ImageLabel")
            coverImg.Name                   = "CoverArtwork"
            coverImg.Size                   = UDim2.new(1, 0, 1, 0)
            coverImg.BackgroundTransparency = 1
            coverImg.BorderSizePixel        = 0
            coverImg.ScaleType              = Enum.ScaleType.Crop
            coverImg.ZIndex                 = 2
            coverImg.Parent                 = coverFrame

            if Shared.ApplyArtworkImage then
                Shared.ApplyArtworkImage(coverImg, { cover = coverUrl or "", name = songName or "", artist = artistName or "" })
            elseif coverUrl and coverUrl ~= "" then
                coverImg.Image = coverUrl
            end

            local songLbl = Instance.new("TextLabel")
            songLbl.Name                  = "SongTitle"
            songLbl.Size                  = UDim2.new(1, -95, 0, 16)
            songLbl.Position              = UDim2.new(0, 64, 0, 6)
            songLbl.BackgroundTransparency = 1
            songLbl.Text                  = (isPlaying and songName) or "No Active Playback"
            songLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
            songLbl.Font                  = Enum.Font.ArimoBold
            songLbl.TextSize              = 11
            songLbl.TextXAlignment        = Enum.TextXAlignment.Left
            songLbl.TextTruncate          = Enum.TextTruncate.AtEnd
            songLbl.Parent                = bg

            local artistLbl = Instance.new("TextLabel")
            artistLbl.Name                  = "ArtistTitle"
            artistLbl.Size                  = UDim2.new(1, -95, 0, 14)
            artistLbl.Position              = UDim2.new(0, 64, 0, 22)
            artistLbl.BackgroundTransparency = 1
            artistLbl.Text                  = (isPlaying and artistName and artistName ~= "") and artistName or "[👑 FIH USER]"
            artistLbl.TextColor3            = Color3.fromRGB(0, 230, 150)
            artistLbl.Font                  = Enum.Font.Code
            artistLbl.TextSize              = 10
            artistLbl.TextXAlignment        = Enum.TextXAlignment.Left
            artistLbl.TextTruncate          = Enum.TextTruncate.AtEnd
            artistLbl.Parent                = bg

            -- 6-Bar Peer Overhead Equalizer
            local visBox = Instance.new("Frame")
            visBox.Name                   = "PeerEqualizer"
            visBox.Size                   = UDim2.new(0, 52, 0, 16)
            visBox.Position               = UDim2.new(0, 64, 0, 42)
            visBox.BackgroundTransparency = 1
            visBox.BorderSizePixel        = 0
            visBox.Parent                 = bg

            local vBars = {}
            for i = 1, 6 do
                local bar = Instance.new("Frame")
                bar.Size = UDim2.new(0, 5, 0, 3)
                bar.Position = UDim2.new(0, (i - 1) * 8, 1, 0)
                bar.AnchorPoint = Vector2.new(0, 1)
                bar.BackgroundColor3 = Color3.fromRGB(255, 205, 30)
                bar.BorderSizePixel = 0
                bar.Parent = visBox
                vBars[i] = bar
            end
            info.visBars = vBars

            local badgeLbl = Instance.new("TextLabel")
            badgeLbl.Size                  = UDim2.new(1, -125, 0, 14)
            badgeLbl.Position              = UDim2.new(0, 120, 0, 44)
            badgeLbl.BackgroundTransparency = 1
            badgeLbl.Text                  = "👑 " .. plr.DisplayName
            badgeLbl.TextColor3            = Color3.fromRGB(255, 205, 30)
            badgeLbl.Font                  = Enum.Font.Code
            badgeLbl.TextSize              = 9
            badgeLbl.TextXAlignment        = Enum.TextXAlignment.Left
            badgeLbl.TextTruncate          = Enum.TextTruncate.AtEnd
            badgeLbl.Parent                = bg

            info.billboard = bb
        else
            local bg = info.billboard:FindFirstChildOfClass("Frame")
            if bg then
                local sLbl = bg:FindFirstChild("SongTitle")
                if sLbl then sLbl.Text = (isPlaying and songName) or "No Active Playback" end
                local aLbl = bg:FindFirstChild("ArtistTitle")
                if aLbl then aLbl.Text = (isPlaying and artistName and artistName ~= "") and artistName or "[👑 FIH USER]" end
                local cFrame = bg:FindFirstChild("CoverContainer")
                if cFrame then
                    local cImg = cFrame:FindFirstChild("CoverArtwork")
                    if cImg and Shared.ApplyArtworkImage then
                        Shared.ApplyArtworkImage(cImg, { cover = coverUrl or "", name = songName or "", artist = artistName or "" })
                    end
                end
            end
        end
    end

    local function registerPeerData(userId, name, dispName, song, artist, cover)
        local uid = tonumber(userId)
        if not uid or uid == Player.UserId then return end
        local p = Players:GetPlayerByUserId(uid)
        if not p then return end

        local isNew = not peerUsers[uid]
        local prevBB = peerUsers[uid] and peerUsers[uid].billboard or nil
        local prevBars = peerUsers[uid] and peerUsers[uid].visBars or {}

        peerUsers[uid] = {
            isPeer    = true,
            song      = song or "",
            artist    = artist or "",
            cover     = cover or "",
            billboard = prevBB,
            visBars   = prevBars,
            lastSeen  = os.time()
        }

        updatePeerBillboard(p, song or "", artist or "", cover or "")

        if isNew then
            local songMsg = (song and song ~= "" and song ~= "Not Playing") and (" (🎵 " .. song .. ")") or ""
            Shared.Notify("Peer Detected", p.DisplayName .. " is running FIH UI!" .. songMsg, true)
        end
    end

    local function broadcastBeacon()
        pcall(function()
            local curTrack = Shared.GetCurrentTrack and Shared.GetCurrentTrack() or { name = "", artist = "", cover = "" }
            local s = (curTrack.name and curTrack.name ~= "Not Playing") and curTrack.name or ""
            local a = (curTrack.artist and curTrack.artist ~= "No Artist") and curTrack.artist or ""
            local c = curTrack.cover or ""

            -- 1. Local File Relay (Multi-Client / Same Machine)
            if writefile then
                local fname1 = "fih_peer_" .. curJobIdClean .. "_" .. tostring(Player.UserId) .. ".json"
                local fname2 = "fih_peer_" .. tostring(Player.UserId) .. ".json"
                local payload = game:GetService("HttpService"):JSONEncode({
                    u = Player.UserId,
                    n = Player.Name,
                    d = Player.DisplayName,
                    s = s,
                    a = a,
                    c = c,
                    t = os.time()
                })
                pcall(function() writefile(fname1, payload) end)
                pcall(function() writefile(fname2, payload) end)
            end
        end)
    end
    Shared.BroadcastBeacon = broadcastBeacon

    -- Scan local file relay for active peers
    local function scanFileRelay()
        if not (listfiles and readfile) then return end
        local ok, files = pcall(function() return listfiles("") end)
        if not ok or not files then return end

        local now = os.time()
        for _, file in ipairs(files) do
            local basename = file:match("([^\\/]+)$") or file
            if basename:find("^fih_peer_") and basename:find("%.json$") then
                local okR, content = pcall(function() return readfile(file) end)
                if okR and content and #content > 10 then
                    local okJ, data = pcall(function() return game:GetService("HttpService"):JSONDecode(content) end)
                    if okJ and data and data.u and (now - (data.t or 0)) < 30 then
                        registerPeerData(data.u, data.n, data.d, data.s, data.a, data.c)
                    end
                end
            end
        end
    end

    -- Animate Peer Billboard Equalizers
    RunService.RenderStepped:Connect(function()
        local t = os.clock()
        for uid, pInfo in pairs(peerUsers) do
            if pInfo.visBars and #pInfo.visBars > 0 then
                local isPlaying = (pInfo.song and pInfo.song ~= "" and pInfo.song ~= "Not Playing")
                for i, bar in ipairs(pInfo.visBars) do
                    if bar and bar.Parent then
                        local h = 2
                        if isPlaying then
                            local n = (math.noise(i * 0.6, t * 3.8, uid % 200) + 1) * 0.5
                            h = math.clamp(math.floor((n ^ 1.6) * 16) + 2, 2, 16)
                            bar.BackgroundColor3 = Color3.fromHSV((0.12 + i * 0.04) % 1, 0.9, 1)
                        else
                            bar.BackgroundColor3 = Color3.fromRGB(70, 85, 110)
                        end
                        bar.Size = UDim2.new(0, 5, 0, h)
                    end
                end
            end
        end
    end)

    -- Background loop: periodic broadcast and scan every 2 seconds
    task.spawn(function()
        while true do
            task.wait(2)
            broadcastBeacon()
            scanFileRelay()
        end
    end)

    local function cleanupUniversalESP(plr)
        local item = universalESPList[plr]
        if item then
            pcall(function() if item.gui then item.gui:Destroy() end end)
            pcall(function() if item.hl then item.hl:Destroy() end end)
            universalESPList[plr] = nil
        end
        local pInfo = peerUsers[plr.UserId]
        if pInfo and pInfo.billboard then
            pcall(function() pInfo.billboard:Destroy() end)
            pInfo.billboard = nil
        end
    end

    local function clearAllUniversalESP()
        for plr in pairs(universalESPList) do cleanupUniversalESP(plr) end
        universalESPList = {}
    end

    -- Universal ESP & Comprehensive Player Info
    MkToggle(rightCol, "Universal Player ESP & Chams", "UniversalESP", 36, function(state)
        clearAllUniversalESP()
        if universalESPConn then universalESPConn:Disconnect(); universalESPConn = nil end

        -- Update AlwaysOnTop on all peer billboards
        for _, pInfo in pairs(peerUsers) do
            if pInfo.billboard then
                pcall(function() pInfo.billboard.AlwaysOnTop = state end)
            end
        end
        local selfBB = Shared.GUI and Shared.GUI:FindFirstChild("MusicBillboard")
        if selfBB then pcall(function() selfBB.AlwaysOnTop = state end) end

        if not state then return end

        broadcastBeacon()
        universalESPConn = RunService.RenderStepped:Connect(function()
            local myHRP = getHRP()

            -- Clean dead players
            for plr, item in pairs(universalESPList) do
                if not plr.Parent or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
                    cleanupUniversalESP(plr)
                end
            end

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= Player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    local char = plr.Character
                    local hrp  = char.HumanoidRootPart
                    local hum  = char:FindFirstChildOfClass("Humanoid")
                    local peerInfo = peerUsers[plr.UserId]
                    local isPeer = (peerInfo ~= nil and peerInfo.isPeer == true)

                    if hum and hum.Health > 0 then
                        local entry = universalESPList[plr]

                        if not entry or not (entry.hl and entry.hl.Parent) or not (entry.gui and entry.gui.Parent) or entry.gui.Adornee ~= hrp then
                            cleanupUniversalESP(plr)

                            local hl = Instance.new("Highlight")
                            hl.Name                = "Fih_UnivChams"
                            hl.Adornee             = char
                            hl.FillTransparency    = 0.5
                            hl.OutlineTransparency = 0
                            hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
                            hl.Parent              = char

                            local bb = Instance.new("BillboardGui")
                            bb.Name         = "Fih_UnivTag"
                            bb.Size         = UDim2.new(0, 160, 0, 44)
                            bb.StudsOffset  = Vector3.new(0, 3.8, 0)
                            bb.AlwaysOnTop  = true
                            bb.MaxDistance  = 1200
                            bb.Adornee      = hrp
                            bb.Parent       = Shared.GUI

                            local bg = Instance.new("Frame")
                            bg.Size                   = UDim2.new(1, 0, 1, 0)
                            bg.BackgroundColor3       = Color3.fromRGB(15, 18, 24)
                            bg.BackgroundTransparency = 0.2
                            bg.BorderSizePixel        = 1
                            bg.BorderColor3           = isPeer and Color3.fromRGB(255, 205, 30) or Color3.fromRGB(0, 170, 255)
                            bg.Parent                 = bb

                            local lbl = Instance.new("TextLabel")
                            lbl.Size                   = UDim2.new(1, -6, 1, -4)
                            lbl.Position               = UDim2.new(0, 3, 0, 2)
                            lbl.BackgroundTransparency = 1
                            lbl.Font                   = Enum.Font.ArimoBold
                            lbl.TextSize               = 10
                            lbl.TextStrokeTransparency = 0
                            lbl.Parent                 = bg

                            entry = { gui = bb, hl = hl, lbl = lbl, bg = bg }
                            universalESPList[plr] = entry
                        end

                        -- Get equipped tool info
                        local heldTool = char:FindFirstChildOfClass("Tool")
                        local heldName = heldTool and (" [Holding: " .. heldTool.Name .. "]") or ""

                        local dist = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
                        local hp = math.floor(hum.Health)
                        local maxHp = math.floor(hum.MaxHealth)

                        -- Update 3D Overhead Billboard if peer
                        if isPeer then
                            updatePeerBillboard(plr, peerInfo.song or "", peerInfo.artist or "")
                        end

                        local themeCol = isPeer and Color3.fromRGB(255, 205, 30) or Color3.fromRGB(0, 190, 255)
                        entry.gui.Size = UDim2.new(0, 140, 0, 32)

                        if entry.hl and entry.hl.Parent then
                            entry.hl.FillColor    = themeCol
                            entry.hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        end
                        if entry.bg and entry.lbl then
                            entry.bg.BorderColor3 = themeCol
                            entry.lbl.TextColor3  = themeCol
                            entry.lbl.Text        = plr.DisplayName .. " (@" .. plr.Name .. ")" .. heldName .. "\n" .. hp .. "/" .. maxHp .. " HP | " .. dist .. "m"
                        end
                    end
                end
            end
        end)
    end)

    MkToggle(rightCol, "Cross-Player Detection (Peer Radar)", "PeerDetect", 37, function(state)
        if state then
            broadcastBeacon()
            Shared.Notify("Peer Radar", "Broadcasting & scanning for script peers...", true)
        end
    end)



    -- ── RIGHT COLUMN: SERVER & TELEPORTS ─────────────────────────
    local TeleportService = game:GetService("TeleportService")
    local HttpService     = game:GetService("HttpService")

    MkSection(rightCol, "Server & Teleports", 40)

    -- 1. Rejoin Current Server
    MkButton(rightCol, "[ 🔄 Rejoin Current Server ]", 41, function()
        Shared.Notify("Teleport", "Rejoining current server...", true)
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
        end)
        if not ok then
            TeleportService:Teleport(game.PlaceId, Player)
        end
    end)

    -- 2. Server Hop (Find different active public server)
    MkButton(rightCol, "[ ⚡ Server Hop (New Server) ]", 42, function()
        Shared.Notify("Server Hop", "Searching for available server...", true)
        task.spawn(function()
            local success, res = pcall(function()
                return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Desc&limit=100")
            end)

            if not success or not res or #res == 0 then
                local reqRes = Shared.HttpRequest({
                    Url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Desc&limit=100",
                    Method = "GET"
                })
                if reqRes and reqRes.Body and #reqRes.Body > 0 then
                    res = reqRes.Body
                    success = true
                end
            end

            if success and res then
                local okD, data = pcall(function() return HttpService:JSONDecode(res) end)
                if okD and data and data.data then
                    local validServers = {}
                    for _, s in ipairs(data.data) do
                        if type(s) == "table" and s.id and s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
                            table.insert(validServers, s.id)
                        end
                    end

                    if #validServers > 0 then
                        local chosen = validServers[math.random(1, #validServers)]
                        Shared.Notify("Server Hop", "Connecting to server: " .. chosen:sub(1,8) .. "...", true)
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen, Player)
                        return
                    end
                end
            end

            Shared.Notify("Server Hop", "Connecting to next available server...", true)
            TeleportService:Teleport(game.PlaceId, Player)
        end)
    end)

    -- 3. Join Random Roblox Game
    local POPULAR_PLACES = {
        142823291,   -- Murder Mystery 2
        2753915549,  -- Blox Fruits
        920587237,   -- Adopt Me!
        4924922222,  -- Brookhaven RP
        286090429,   -- Arsenal
        189707,      -- Natural Disaster Survival
        1962086868,  -- Tower of Hell
        6872265039,  -- BedWars
        6516141723,  -- Doors
        13772394625, -- Blade Ball
        606849621,   -- Jailbreak
        16732694052, -- Fisch
        1730877806,  -- The Strongest Battlegrounds
        9872472334,  -- Evade
        292439477,   -- Phantom Forces
        17625359962, -- Rivals
        155615604,   -- Prison Life
        3956818381,  -- Ninja Legends
        4442272183,  -- Flee the Facility
        185655149,   -- Welcome to Bloxburg
        8737602449,  -- Pls Donate
        1240123653,  -- Zombie Stories
        11131159953, -- Combat Initiation
        12552538292, -- Pressure
        18115804639, -- Dress To Impress
    }

    MkButton(rightCol, "[ 🎲 Join Random Game ]", 43, function()
        Shared.Notify("Random Game", "Finding a random experience...", true)
        task.spawn(function()
            -- 1. Try dynamic discovery from Roblox Recommendations API
            local livePlaces = {}
            local success, res = pcall(function()
                return game:HttpGet("https://games.roblox.com/v1/games/recommendations/game/" .. tostring(game.PlaceId) .. "?maxRows=50")
            end)

            if not success or not res or #res == 0 then
                local reqRes = Shared.HttpRequest({
                    Url = "https://games.roblox.com/v1/games/recommendations/game/" .. tostring(game.PlaceId) .. "?maxRows=50",
                    Method = "GET"
                })
                if reqRes and reqRes.Body and #reqRes.Body > 0 then
                    res = reqRes.Body
                    success = true
                end
            end

            if success and res then
                local okD, data = pcall(function() return HttpService:JSONDecode(res) end)
                if okD and data and data.games then
                    for _, g in ipairs(data.games) do
                        if g.placeId and g.placeId ~= game.PlaceId then
                            table.insert(livePlaces, g.placeId)
                        end
                    end
                end
            end

            -- 2. Select from dynamic list or verified popular pool
            local chosenPlaceId = nil
            if #livePlaces > 0 then
                chosenPlaceId = livePlaces[math.random(1, #livePlaces)]
            else
                local pool = {}
                for _, id in ipairs(POPULAR_PLACES) do
                    if id ~= game.PlaceId then table.insert(pool, id) end
                end
                chosenPlaceId = pool[math.random(1, #pool)]
            end

            Shared.Notify("Random Game", "Teleporting to Place ID: " .. tostring(chosenPlaceId) .. "...", true)
            TeleportService:Teleport(chosenPlaceId, Player)
        end)
    end)

    -- 4. Join Game by Place ID
    local targetPlaceId = ""
    local targetJobId   = ""

    local placeBox = Instance.new("TextBox")
    placeBox.Name                  = "PlaceIdInput"
    placeBox.Size                  = UDim2.new(1, 0, 0, 24)
    placeBox.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    placeBox.BorderSizePixel       = 1
    placeBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    placeBox.Text                  = "Enter Place ID (e.g. 142823291)"
    placeBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    placeBox.Font                  = Enum.Font.Code
    placeBox.TextSize              = 11
    placeBox.LayoutOrder           = 44
    placeBox.Parent                = rightCol

    placeBox.Focused:Connect(function()
        if placeBox.Text:find("Enter Place ID") then placeBox.Text = "" end
    end)
    placeBox.FocusLost:Connect(function()
        targetPlaceId = placeBox.Text:gsub("%D+", "")
    end)

    local jobBox = Instance.new("TextBox")
    jobBox.Name                  = "JobIdInput"
    jobBox.Size                  = UDim2.new(1, 0, 0, 24)
    jobBox.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    jobBox.BorderSizePixel       = 1
    jobBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    jobBox.Text                  = "Enter Job/Server ID (Optional)"
    jobBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    jobBox.Font                  = Enum.Font.Code
    jobBox.TextSize              = 11
    jobBox.LayoutOrder           = 44
    jobBox.Parent                = rightCol

    jobBox.Focused:Connect(function()
        if jobBox.Text:find("Enter Job") then jobBox.Text = "" end
    end)
    jobBox.FocusLost:Connect(function()
        targetJobId = jobBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    end)

    MkButton(rightCol, "[ 🚀 Teleport to Place ID ]", 46, function()
        local pId = tonumber(targetPlaceId) or tonumber(placeBox.Text:gsub("%D+", ""))
        if not pId or pId <= 0 then
            Shared.Notify("Teleport", "Invalid Place ID entered", false)
            return
        end

        local jId = (targetJobId ~= "" and not targetJobId:find("Enter Job")) and targetJobId or nil
        Shared.Notify("Teleport", "Teleporting to Place ID: " .. tostring(pId) .. "...", true)

        if jId and #jId > 10 then
            local ok = pcall(function() TeleportService:TeleportToPlaceInstance(pId, jId, Player) end)
            if not ok then TeleportService:Teleport(pId, Player) end
        else
            TeleportService:Teleport(pId, Player)
        end
    end)

    -- 4. Auto-Rejoin on Disconnect / Kick
    local autoRejoinConn = nil
    MkToggle(rightCol, "Auto-Rejoin on Disconnect", "AutoRejoin", 47, function(state)
        if autoRejoinConn then autoRejoinConn:Disconnect(); autoRejoinConn = nil end
        if state then
            local CoreGui = game:GetService("CoreGui")
            local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui") and CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
            if promptOverlay then
                autoRejoinConn = promptOverlay.ChildAdded:Connect(function(child)
                    if not Shared.Flags["AutoRejoin"] then return end
                    if child.Name == "ErrorPrompt" or child.Name:find("Prompt") then
                        task.wait(1)
                        TeleportService:Teleport(game.PlaceId, Player)
                    end
                end)
            end
        end
    end)

    print("[Main_Functions] Loaded -- Performance, Teleports & Server Hop Active")
end
