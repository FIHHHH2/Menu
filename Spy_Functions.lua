-- Spy_Functions.lua
-- Dedicated Player POV & Spectator Camera Suite
-- Real-time 3rd-Person POV camera lock, Target Dossier, Player Directory, Highlight ESP, & Tactical Utilities

return function(Shared)
    local Players      = Shared.Services.Players
    local RunService   = Shared.Services.RunService
    local UserInput    = Shared.Services.UserInput
    local TweenSvc     = Shared.Services.TweenService
    local StarterGui   = game:GetService("StarterGui")
    local GuiService   = game:GetService("GuiService")

    local Player    = Shared.Player
    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab  = Tabs["Spy"]
    local cols = QuadCols["Spy"]
    if not tab or not cols then
        warn("[Spy_Functions] Tabs['Spy'] or QuadCols['Spy'] not found!")
        return
    end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    -- ── State Variables ──────────────────────────────────────────
    local selectedPlayer = nil
    local isSpectating = false
    local targetHighlight = nil
    local filterText = ""

    local function getChar(plr)
        local p = plr or Player
        return p and p.Character
    end

    local function getHRP(plr)
        local c = getChar(plr)
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function getHum(plr)
        local c = getChar(plr)
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    -- ══════════════════════════════════════════════════════════════
    -- LEFT COLUMN: PLAYER DIRECTORY & INSTANT SEARCH
    -- ══════════════════════════════════════════════════════════════
    MkSection(leftCol, "Player Directory & Live Radar", 1)

    local searchBox = Instance.new("TextBox")
    searchBox.Name                  = "SpySearchBox"
    searchBox.Size                  = UDim2.new(1, 0, 0, 24)
    searchBox.BackgroundColor3      = Color3.fromRGB(245, 248, 255)
    searchBox.BorderSizePixel       = 1
    searchBox.BorderColor3          = Color3.fromRGB(150, 170, 200)
    searchBox.Text                  = ""
    searchBox.PlaceholderText       = "Filter by Name or @User..."
    searchBox.TextColor3            = Color3.fromRGB(20, 25, 45)
    searchBox.Font                  = Enum.Font.Code
    searchBox.TextSize              = 11
    searchBox.LayoutOrder           = 2
    searchBox.Parent                = leftCol

    local scrollHolder = Instance.new("ScrollingFrame")
    scrollHolder.Name                   = "SpyScrollHolder"
    scrollHolder.Size                   = UDim2.new(1, 0, 0, 280)
    scrollHolder.BackgroundColor3       = Color3.fromRGB(18, 22, 30)
    scrollHolder.BackgroundTransparency = 0.2
    scrollHolder.BorderSizePixel        = 1
    scrollHolder.BorderColor3           = Color3.fromRGB(60, 80, 110)
    scrollHolder.ScrollBarThickness     = 4
    scrollHolder.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    scrollHolder.CanvasSize             = UDim2.new(0, 0, 0, 0)
    scrollHolder.LayoutOrder            = 3
    scrollHolder.ZIndex                 = 10
    scrollHolder.Parent                 = leftCol

    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Padding   = UDim.new(0, 4)
    scrollLayout.Parent    = scrollHolder

    local scrollPad = Instance.new("UIPadding")
    scrollPad.PaddingTop    = UDim.new(0, 4)
    scrollPad.PaddingLeft   = UDim.new(0, 4)
    scrollPad.PaddingRight  = UDim.new(0, 4)
    scrollPad.PaddingBottom = UDim.new(0, 4)
    scrollPad.Parent        = scrollHolder

    -- ── RIGHT COLUMN: TARGET DOSSIER & 3RD-PERSON POV SUITE ────────
    MkSection(rightCol, "Target Dossier", 1)

    local dossierCard = Instance.new("Frame")
    dossierCard.Name                  = "DossierCard"
    dossierCard.Size                  = UDim2.new(1, 0, 0, 95)
    dossierCard.BackgroundColor3      = Color3.fromRGB(15, 18, 26)
    dossierCard.BackgroundTransparency= 0.15
    dossierCard.BorderSizePixel       = 1
    dossierCard.BorderColor3          = Color3.fromRGB(0, 160, 255)
    dossierCard.LayoutOrder           = 2
    dossierCard.Parent                = rightCol

    local cardAvatar = Instance.new("ImageLabel")
    cardAvatar.Size                   = UDim2.new(0, 75, 0, 75)
    cardAvatar.Position               = UDim2.new(0, 10, 0, 10)
    cardAvatar.BackgroundColor3       = Color3.fromRGB(24, 28, 40)
    cardAvatar.BorderSizePixel        = 1
    cardAvatar.BorderColor3           = Color3.fromRGB(60, 90, 140)
    cardAvatar.Image                  = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    cardAvatar.Parent                 = dossierCard

    local cardDName = Instance.new("TextLabel")
    cardDName.Size                   = UDim2.new(1, -95, 0, 16)
    cardDName.Position               = UDim2.new(0, 95, 0, 8)
    cardDName.BackgroundTransparency = 1
    cardDName.Text                   = "No Target Selected"
    cardDName.TextColor3             = Color3.fromRGB(255, 255, 255)
    cardDName.Font                   = Enum.Font.ArimoBold
    cardDName.TextSize               = 13
    cardDName.TextXAlignment         = Enum.TextXAlignment.Left
    cardDName.TextTruncate           = Enum.TextTruncate.AtEnd
    cardDName.Parent                 = dossierCard

    local cardUName = Instance.new("TextLabel")
    cardUName.Size                   = UDim2.new(1, -95, 0, 14)
    cardUName.Position               = UDim2.new(0, 95, 0, 24)
    cardUName.BackgroundTransparency = 1
    cardUName.Text                   = "@none"
    cardUName.TextColor3             = Color3.fromRGB(0, 220, 140)
    cardUName.Font                   = Enum.Font.Code
    cardUName.TextSize               = 11
    cardUName.TextXAlignment         = Enum.TextXAlignment.Left
    cardUName.TextTruncate           = Enum.TextTruncate.AtEnd
    cardUName.Parent                 = dossierCard

    local cardInfo = Instance.new("TextLabel")
    cardInfo.Size                   = UDim2.new(1, -95, 0, 14)
    cardInfo.Position               = UDim2.new(0, 95, 0, 40)
    cardInfo.BackgroundTransparency = 1
    cardInfo.Text                   = "Distance: -- | Team: Neutral"
    cardInfo.TextColor3             = Color3.fromRGB(150, 175, 210)
    cardInfo.Font                   = Enum.Font.Code
    cardInfo.TextSize               = 10
    cardInfo.TextXAlignment         = Enum.TextXAlignment.Left
    cardInfo.TextTruncate           = Enum.TextTruncate.AtEnd
    cardInfo.Parent                 = dossierCard

    local cardHealthBarBg = Instance.new("Frame")
    cardHealthBarBg.Size             = UDim2.new(1, -95, 0, 8)
    cardHealthBarBg.Position         = UDim2.new(0, 95, 0, 60)
    cardHealthBarBg.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    cardHealthBarBg.BorderSizePixel  = 1
    cardHealthBarBg.BorderColor3     = Color3.fromRGB(70, 80, 100)
    cardHealthBarBg.Parent           = dossierCard

    local cardHealthFill = Instance.new("Frame")
    cardHealthFill.Size             = UDim2.new(1, 0, 1, 0)
    cardHealthFill.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
    cardHealthFill.BorderSizePixel  = 0
    cardHealthFill.Parent           = cardHealthBarBg

    local cardHealthTxt = Instance.new("TextLabel")
    cardHealthTxt.Size              = UDim2.new(1, -95, 0, 14)
    cardHealthTxt.Position          = UDim2.new(0, 95, 0, 72)
    cardHealthTxt.BackgroundTransparency = 1
    cardHealthTxt.Text              = "HP: -- / -- | Tool: None"
    cardHealthTxt.TextColor3        = Color3.fromRGB(180, 200, 230)
    cardHealthTxt.Font              = Enum.Font.Code
    cardHealthTxt.TextSize          = 9
    cardHealthTxt.TextXAlignment    = Enum.TextXAlignment.Left
    cardHealthTxt.Parent            = dossierCard

    local function updateDossier(plr)
        if not plr then
            cardDName.Text = "No Target Selected"
            cardUName.Text = "@none"
            cardInfo.Text = "Distance: -- | Team: Neutral"
            cardHealthFill.Size = UDim2.new(0, 0, 1, 0)
            cardHealthTxt.Text = "HP: -- / -- | Tool: None"
            cardAvatar.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
            return
        end

        cardDName.Text = plr.DisplayName
        cardUName.Text = "@" .. plr.Name
        cardAvatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(plr.UserId) .. "&width=150&height=150&format=png"

        local myHRP = getHRP()
        local tHRP  = getHRP(plr)
        local distStr = "--"
        if myHRP and tHRP then
            local d = (myHRP.Position - tHRP.Position).Magnitude
            distStr = string.format("%.0f studs", d)
        end

        local teamStr = plr.Team and plr.Team.Name or "Neutral"
        cardInfo.Text = "Distance: " .. distStr .. " | Team: " .. teamStr

        local hum = getHum(plr)
        if hum and hum.MaxHealth > 0 then
            local hpFrac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            cardHealthFill.Size = UDim2.new(hpFrac, 0, 1, 0)
            cardHealthFill.BackgroundColor3 = Color3.fromHSV(hpFrac * 0.33, 0.9, 0.95)
            
            local toolName = "None"
            local char = plr.Character
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then toolName = tool.Name end
            end
            cardHealthTxt.Text = string.format("HP: %.0f / %.0f | Tool: %s", hum.Health, hum.MaxHealth, toolName)
        else
            cardHealthFill.Size = UDim2.new(0, 0, 1, 0)
            cardHealthTxt.Text = "HP: Dead/Unspawned | Tool: None"
        end
    end

    -- ── 3RD-PERSON POV SPECTATE ENGINE ─────────────────────────────
    MkSection(rightCol, "3rd-Person POV Spectate", 10)

    local spectateBtn = MkButton(rightCol, "[ View 3rd-Person POV ]", 11, function()
        if not selectedPlayer then
            Shared.Notify("Spy Suite", "Select a target from the Directory first", false)
            return
        end

        local cam = workspace.CurrentCamera
        if not cam then return end

        if isSpectating then
            -- Stop Spectating
            isSpectating = false
            local myHum = getHum() or (Shared.Character and Shared.Character:FindFirstChildOfClass("Humanoid"))
            if myHum then
                cam.CameraSubject = myHum
            end
            spectateBtn.Text = "[ View 3rd-Person POV ]"
            Shared.Notify("Spy Suite", "Returned camera to local player", true)
        else
            -- Start Spectating
            local tHum = getHum(selectedPlayer)
            if not tHum then
                Shared.Notify("Spy Suite", selectedPlayer.DisplayName .. " has no active character", false)
                return
            end

            isSpectating = true
            cam.CameraSubject = tHum
            spectateBtn.Text = "[ Stop Spectate (Return Cam) ]"
            Shared.Notify("Spy Suite", "Spectating: @" .. selectedPlayer.Name .. " (Orbit freely in 3rd person)", true)
        end
    end)

    -- Auto-restore camera if target dies or leaves
    RunService.Heartbeat:Connect(function()
        if isSpectating then
            local cam = workspace.CurrentCamera
            if not selectedPlayer or not selectedPlayer.Parent or not getHum(selectedPlayer) then
                isSpectating = false
                local myHum = getHum()
                if cam and myHum then
                    cam.CameraSubject = myHum
                end
                spectateBtn.Text = "[ View 3rd-Person POV ]"
                Shared.Notify("Spy Suite", "Target unavailable. Camera returned.", false)
            end
        end
    end)

    -- ── TACTICAL SPY UTILITIES ─────────────────────────────────────
    MkSection(rightCol, "Spy Actions & Utilities", 20)

    MkButton(rightCol, "[ Teleport Behind Target ]", 21, function()
        if not selectedPlayer then
            Shared.Notify("Spy Suite", "Select a target first", false)
            return
        end
        local myHRP = getHRP()
        local tHRP  = getHRP(selectedPlayer)
        if myHRP and tHRP then
            -- Position 4 studs directly behind target
            myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 4)
            Shared.Notify("Spy Suite", "Teleported behind @" .. selectedPlayer.Name, true)
        else
            Shared.Notify("Spy Suite", "Player character not found", false)
        end
    end)

    MkButton(rightCol, "[ Toggle Target Highlight Box ]", 22, function()
        if not selectedPlayer then
            Shared.Notify("Spy Suite", "Select a target first", false)
            return
        end

        if targetHighlight and targetHighlight.Parent then
            targetHighlight:Destroy()
            targetHighlight = nil
            Shared.Notify("Spy Suite", "Removed Highlight on target", true)
            return
        end

        local char = selectedPlayer.Character
        if not char then
            Shared.Notify("Spy Suite", "Target character not found", false)
            return
        end

        targetHighlight = Instance.new("Highlight")
        targetHighlight.Name = "Fih_SpyHighlight"
        targetHighlight.FillColor = Color3.fromRGB(0, 160, 255)
        targetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        targetHighlight.FillTransparency = 0.5
        targetHighlight.OutlineTransparency = 0
        targetHighlight.Adornee = char
        targetHighlight.Parent = Shared.GUI or game:GetService("CoreGui")

        Shared.Notify("Spy Suite", "Highlight active on @" .. selectedPlayer.Name, true)
    end)

    MkButton(rightCol, "[ Copy Roblox Profile Link ]", 23, function()
        if not selectedPlayer then
            Shared.Notify("Spy Suite", "Select a target first", false)
            return
        end
        local url = "https://www.roblox.com/users/" .. tostring(selectedPlayer.UserId) .. "/profile"
        if setclipboard then
            setclipboard(url)
            Shared.Notify("Spy Suite", "Copied profile URL to clipboard!", true)
        else
            Shared.Notify("Spy Suite", "URL: " .. url, true)
        end
    end)

    MkButton(rightCol, "[ Send Friend Request ]", 24, function()
        if selectedPlayer then
            pcall(function()
                StarterGui:SetCore("PromptSendFriendRequest", selectedPlayer)
            end)
        else
            Shared.Notify("Spy Suite", "Select a target first", false)
        end
    end)

    MkButton(rightCol, "[ Inspect Roblox Avatar ]", 25, function()
        if selectedPlayer then
            pcall(function()
                GuiService:InspectPlayerFromUserId(selectedPlayer.UserId)
            end)
        else
            Shared.Notify("Spy Suite", "Select a target first", false)
        end
    end)

    -- ── RENDER DIRECTORY PLAYERS ───────────────────────────────────
    local activeRows = {}

    local function selectPlayer(plr)
        selectedPlayer = plr
        updateDossier(plr)

        for p, row in pairs(activeRows) do
            if row and row.Parent then
                if p == plr then
                    row.BackgroundColor3 = Color3.fromRGB(0, 80, 160)
                    row.BorderColor3     = Color3.fromRGB(0, 200, 255)
                else
                    row.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
                    row.BorderColor3     = Color3.fromRGB(45, 55, 75)
                end
            end
        end

        if isSpectating and plr and getHum(plr) then
            local cam = workspace.CurrentCamera
            if cam then cam.CameraSubject = getHum(plr) end
        end
    end

    local function refreshDirectory()
        for _, child in ipairs(scrollHolder:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        activeRows = {}

        local allPlrs = Players:GetPlayers()
        local myHRP   = getHRP()

        for i, plr in ipairs(allPlrs) do
            local matchesFilter = (filterText == "")
                               or plr.Name:lower():find(filterText:lower(), 1, true)
                               or plr.DisplayName:lower():find(filterText:lower(), 1, true)

            if matchesFilter then
                local row = Instance.new("Frame")
                row.Name             = "SpyRow_" .. plr.Name
                row.Size             = UDim2.new(1, 0, 0, 32)
                row.BackgroundColor3 = (plr == selectedPlayer) and Color3.fromRGB(0, 80, 160) or Color3.fromRGB(22, 26, 36)
                row.BorderSizePixel  = 1
                row.BorderColor3     = (plr == selectedPlayer) and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(45, 55, 75)
                row.LayoutOrder      = i
                row.ZIndex           = 11
                row.Parent           = scrollHolder
                activeRows[plr] = row

                local av = Instance.new("ImageLabel")
                av.Size              = UDim2.new(0, 26, 0, 26)
                av.Position          = UDim2.new(0, 3, 0, 3)
                av.BackgroundColor3  = Color3.fromRGB(30, 35, 50)
                av.BorderSizePixel   = 0
                av.Image             = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(plr.UserId) .. "&width=48&height=48&format=png"
                av.ZIndex            = 12
                av.Parent            = row

                local dLbl = Instance.new("TextLabel")
                dLbl.Size                   = UDim2.new(1, -100, 0, 14)
                dLbl.Position               = UDim2.new(0, 34, 0, 2)
                dLbl.BackgroundTransparency = 1
                dLbl.Text                   = plr.DisplayName .. (plr == Player and " (You)" or "")
                dLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
                dLbl.Font                   = Enum.Font.ArimoBold
                dLbl.TextSize               = 11
                dLbl.TextXAlignment         = Enum.TextXAlignment.Left
                dLbl.TextTruncate           = Enum.TextTruncate.AtEnd
                dLbl.ZIndex                 = 12
                dLbl.Parent                 = row

                local uLbl = Instance.new("TextLabel")
                uLbl.Size                   = UDim2.new(1, -100, 0, 12)
                uLbl.Position               = UDim2.new(0, 34, 0, 16)
                uLbl.BackgroundTransparency = 1
                uLbl.Text                   = "@" .. plr.Name
                uLbl.TextColor3             = Color3.fromRGB(0, 200, 120)
                uLbl.Font                   = Enum.Font.Code
                uLbl.TextSize               = 9
                uLbl.TextXAlignment         = Enum.TextXAlignment.Left
                uLbl.TextTruncate           = Enum.TextTruncate.AtEnd
                uLbl.ZIndex                 = 12
                uLbl.Parent                 = row

                local distLbl = Instance.new("TextLabel")
                distLbl.Size                  = UDim2.new(0, 60, 1, 0)
                distLbl.Position              = UDim2.new(1, -64, 0, 0)
                distLbl.BackgroundTransparency= 1
                local tHRP = getHRP(plr)
                local dStr = "--"
                if myHRP and tHRP then
                    dStr = string.format("%.0fm", (myHRP.Position - tHRP.Position).Magnitude)
                end
                distLbl.Text                  = dStr
                distLbl.TextColor3            = Color3.fromRGB(150, 170, 200)
                distLbl.Font                  = Enum.Font.Code
                distLbl.TextSize              = 10
                distLbl.TextXAlignment        = Enum.TextXAlignment.Right
                distLbl.ZIndex                = 12
                distLbl.Parent                = row

                local hitBtn = Instance.new("TextButton")
                hitBtn.Size                   = UDim2.new(1, 0, 1, 0)
                hitBtn.BackgroundTransparency = 1
                hitBtn.Text                   = ""
                hitBtn.ZIndex                 = 13
                hitBtn.Parent                 = row

                hitBtn.MouseButton1Click:Connect(function()
                    selectPlayer(plr)
                end)
            end
        end
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        filterText = searchBox.Text
        refreshDirectory()
    end)

    MkButton(leftCol, "[ Refresh Directory ]", 4, function()
        refreshDirectory()
        Shared.Notify("Spy Suite", "Directory refreshed (" .. tostring(#Players:GetPlayers()) .. " players)", true)
    end)

    Players.PlayerAdded:Connect(refreshDirectory)
    Players.PlayerRemoving:Connect(function(plr)
        if selectedPlayer == plr then
            selectedPlayer = nil
            updateDossier(nil)
        end
        refreshDirectory()
    end)

    -- Initial load
    task.delay(0.2, function()
        refreshDirectory()
        local others = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player then table.insert(others, p) end
        end
        if others[1] then
            selectPlayer(others[1])
        end
    end)

    print("[Spy_Functions] Loaded -- Dedicated 3rd-Person POV & Spectate Suite")
end
