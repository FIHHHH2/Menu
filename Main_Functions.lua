-- Main_Functions.lua
-- Fih UI Framework: Interface Customization, Visual Engine, Performance & Server Suite

return function(Shared)
    local Services        = Shared.Services or {}
    local Players         = Services.Players or game:GetService("Players")
    local RunService      = Services.RunService or game:GetService("RunService")
    local UserInput       = Services.UserInput or game:GetService("UserInputService")
    local TweenService    = Services.TweenService or game:GetService("TweenService")
    local Lighting        = game:GetService("Lighting")
    local TeleportService = game:GetService("TeleportService")
    local HttpService     = Services.Http or game:GetService("HttpService")

    local Player    = Shared.Player or Players.LocalPlayer
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

    -- ── LEFT COLUMN: FIH UI & INTERFACE ──────────────────────────
    MkSection(leftCol, "Fih UI & Interface", 1)

    MkToggle(leftCol, "Smooth Window Animations", "SmoothAnimations", 2, function(state)
        Shared.Flags["SmoothAnimations"] = state
    end)

    MkToggle(leftCol, "Interface Click Sounds", "InterfaceSounds", 3, function(state)
        Shared.Flags["InterfaceSounds"] = state
    end)

    MkToggle(leftCol, "Retro Glass Aero Borders", "AeroGlassBorder", 4, function(state)
        Shared.Flags["AeroGlassBorder"] = state
        if Shared.GUI and Shared.GUI:FindFirstChild("IE7_Menu") then
            local mainFrame = Shared.GUI.IE7_Menu:FindFirstChild("MainFrame")
            if mainFrame then
                mainFrame.BorderSizePixel = state and 2 or 1
            end
        end
    end)

    MkSlider(leftCol, "Interface Scale (%)", "InterfaceScale", 75, 125, 100, 5, function(val)
        Shared.Flags["InterfaceScale"] = val
    end)

    MkButton(leftCol, "[ 🔄 Reset Window Positions ]", 6, function()
        if Shared.GUI and Shared.GUI:FindFirstChild("IE7_Menu") then
            local mainFrame = Shared.GUI.IE7_Menu:FindFirstChild("MainFrame")
            if mainFrame then
                mainFrame.Position = UDim2.new(0.5, -290, 0.5, -200)
            end
        end
        local lb = Shared.GUI and Shared.GUI:FindFirstChild("Fih_CustomLeaderboard")
        if lb then
            lb.Position = UDim2.new(1, -242, 0, 48)
        end
        local chat = Shared.GUI and Shared.GUI:FindFirstChild("Fih_CustomChat")
        if chat then
            chat.Position = UDim2.new(0, 16, 0, 48)
        end
        local hud = Shared.GUI and Shared.GUI:FindFirstChild("Fih_BottomHUD")
        if hud then
            hud.Position = UDim2.new(0.5, -165, 1, -115)
        end
        Shared.Notify("UI Engine", "All window positions reset to defaults", true)
    end)

    -- ── LEFT COLUMN: CAMERA & VISUAL ENVIRONMENT ─────────────────
    MkSection(leftCol, "Camera & Visual Environment", 10)

    local originalBrightness = Lighting.Brightness
    local originalClockTime   = Lighting.ClockTime
    local originalGlobalShadows = Lighting.GlobalShadows

    MkToggle(leftCol, "Fullbright Lighting", "Fullbright", 11, function(state)
        if state then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1e6
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = originalBrightness
            Lighting.ClockTime = originalClockTime
            Lighting.GlobalShadows = originalGlobalShadows
        end
    end)

    MkSlider(leftCol, "Field of View (FOV)", "FieldOfView", 60, 120, 70, 12, function(val)
        if workspace.CurrentCamera then
            workspace.CurrentCamera.FieldOfView = val
        end
    end)

    MkSlider(leftCol, "Max Camera Zoom Distance", "MaxCameraZoom", 10, 500, 128, 13, function(val)
        if Player then
            Player.CameraMaxZoomDistance = val
        end
    end)

    MkSlider(leftCol, "Time of Day (Hours)", "TimeOfDay", 0, 24, 14, 14, function(val)
        Lighting.ClockTime = val
    end)

    MkSlider(leftCol, "Master Audio Volume", "MasterVolume", 0, 100, 50, 15, function(val)
        for _, s in ipairs(workspace:GetDescendants()) do
            if s:IsA("Sound") then
                s.Volume = val / 100
            end
        end
    end)

    -- ── RIGHT COLUMN: GRAPHICS & PERFORMANCE ENGINE ──────────────
    MkSection(rightCol, "Graphics & Performance Engine", 1)

    MkToggle(rightCol, "Disable Global Shadows", "NoShadows", 2, function(state)
        Lighting.GlobalShadows = not state
    end)

    local disabledEffects = {}
    MkToggle(rightCol, "Disable Post-Processing (Blur/Bloom)", "NoPostProcessing", 3, function(state)
        if state then
            for _, obj in ipairs(Lighting:GetChildren()) do
                if obj:IsA("PostProcessEffect") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
                    if obj.Enabled then
                        disabledEffects[obj] = true
                        obj.Enabled = false
                    end
                end
            end
        else
            for obj in pairs(disabledEffects) do
                if obj and obj.Parent then pcall(function() obj.Enabled = true end) end
            end
            disabledEffects = {}
        end
    end)

    local setfpscap = setfpscap or (getgenv and getgenv().setfpscap)
    if setfpscap then
        MkSlider(rightCol, "FPS Limiter / Cap", "FPSCap", 30, 360, 144, 4, function(val)
            pcall(function() setfpscap(val) end)
        end)
    end

    -- ── RIGHT COLUMN: SERVER & SESSION UTILITIES ─────────────────
    MkSection(rightCol, "Server & Session Utilities", 10)

    -- 1. Rejoin Server
    MkButton(rightCol, "[ 🔄 Reconnect / Rejoin Server ]", 11, function()
        Shared.Notify("Server", "Reconnecting to current server...", true)
        task.defer(function()
            if #Players:GetPlayers() <= 1 then
                Player:Kick("\n[FihUI] Reconnecting to server...")
                task.wait(0.2)
                TeleportService:Teleport(game.PlaceId, Player)
            else
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
            end
        end)
    end)

    -- 2. Server Hop
    MkButton(rightCol, "[ 🌐 Server Hop (Next Active Server) ]", 12, function()
        Shared.Notify("Server Hop", "Searching for available public server...", true)
        task.spawn(function()
            local success, res = pcall(function()
                return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100")
            end)

            if not success or not res or #res == 0 then
                local reqRes = Shared.HttpRequest({
                    Url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100",
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

    -- 3. Teleport to Specific Place ID
    local targetPlaceId = ""
    local targetJobId   = ""

    local placeBox = Instance.new("TextBox")
    placeBox.Name                  = "PlaceIdInput"
    placeBox.Size                  = UDim2.new(1, 0, 0, 24)
    placeBox.BackgroundColor3      = Color3.fromRGB(245, 248, 255)
    placeBox.BorderSizePixel       = 1
    placeBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    placeBox.Text                  = ""
    placeBox.PlaceholderText       = "Enter Place ID (e.g. 189707)"
    placeBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    placeBox.Font                  = Enum.Font.Code
    placeBox.TextSize              = 11
    placeBox.LayoutOrder           = 13
    placeBox.Parent                = rightCol

    placeBox.FocusLost:Connect(function()
        targetPlaceId = placeBox.Text:gsub("%D+", "")
    end)

    local jobBox = Instance.new("TextBox")
    jobBox.Name                  = "JobIdInput"
    jobBox.Size                  = UDim2.new(1, 0, 0, 24)
    jobBox.BackgroundColor3      = Color3.fromRGB(245, 248, 255)
    jobBox.BorderSizePixel       = 1
    jobBox.BorderColor3          = Color3.fromRGB(150, 160, 180)
    jobBox.Text                  = ""
    jobBox.PlaceholderText       = "Enter Server Job ID (Optional)"
    jobBox.TextColor3            = Color3.fromRGB(20, 20, 60)
    jobBox.Font                  = Enum.Font.Code
    jobBox.TextSize              = 11
    jobBox.LayoutOrder           = 14
    jobBox.Parent                = rightCol

    jobBox.FocusLost:Connect(function()
        targetJobId = jobBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    end)

    MkButton(rightCol, "[ 🚀 Teleport to Custom Place ]", 15, function()
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
    MkToggle(rightCol, "Auto-Rejoin on Disconnect", "AutoRejoin", 16, function(state)
        if autoRejoinConn then autoRejoinConn:Disconnect(); autoRejoinConn = nil end
        if state then
            local CoreGui = Services.CoreGui
            if not CoreGui then pcall(function() CoreGui = game:GetService("CoreGui") end) end
            local promptOverlay = CoreGui and CoreGui:FindFirstChild("RobloxPromptGui") and CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
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

    -- ── RIGHT COLUMN: CONFIGURATION MANAGER ──────────────────────
    MkSection(rightCol, "Configuration Manager", 20)

    MkButton(rightCol, "[ 💾 Save Config (FihUi_Config.json) ]", 21, function()
        if Shared.SaveConfig then
            Shared.SaveConfig()
            Shared.Notify("Config Manager", "Configuration saved successfully", true)
        end
    end)

    print("[Main_Functions] Loaded -- Fih UI Area & Session Utilities Active")
end
