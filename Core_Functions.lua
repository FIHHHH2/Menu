-- Core_Functions.lua
-- Custom Windows Aero Leaderboard, Playerlist, Profile Cards, and Aero Chat System

return function(Shared)
    local Players      = Shared.Services.Players or game:GetService("Players")
    local UserInput    = Shared.Services.UserInput or game:GetService("UserInputService")
    local TweenService = Shared.Services.TweenService or game:GetService("TweenService")
    local TweenSvc     = TweenService
    local StarterGui   = game:GetService("StarterGui")
    local GuiService   = game:GetService("GuiService")
    local VirtualInput = game:GetService("VirtualInputManager")
    local RunService   = Shared.Services.RunService or game:GetService("RunService")
    local ScreenGui = Shared.GUI
    if not ScreenGui then
        local gethui = rawget(getfenv and getfenv(0) or _G, "gethui") or (getgenv and getgenv().gethui)
        local h = (type(gethui) == "function" and gethui())
               or (Shared.Services and Shared.Services.CoreGui)
               or (Shared.Player and Shared.Player:FindFirstChildOfClass("PlayerGui"))
        if h and typeof(h) == "Instance" then
            ScreenGui = h:FindFirstChild("IE7_Menu")
        end
    end

    if not ScreenGui then
        warn("[Core_Functions] Shared.GUI not initialized!")
        return
    end

    local function getTheme()
        if Shared.CurrentTheme then return Shared.CurrentTheme() end
        return Shared.DarkTheme or {}
    end

    local C = getTheme()
    local isDark = (Shared.IsDark ~= nil) and Shared.IsDark() or true

    local function registerThemed(instance, propMap)
        if Shared.RegisterThemed then
            Shared.RegisterThemed(instance, propMap)
        end
    end

    local function sendNotification(title, msg, state)
        if Shared.Notify then
            Shared.Notify(title, msg, state)
        elseif Shared.SendNotification then
            Shared.SendNotification(title, msg, state)
        end
    end

    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    end)

    -- ── CUSTOM WINDOWS AERO LEADERBOARD (PLAYERLIST) ─────────────
    local playerRows = {}
    local lbScroll = nil
    local lbResizeGrip = nil
    local renderLeaderboardPlayers = nil

    local function getLbTargetHeight(count, customPosY)
        local c = count or #Players:GetPlayers()
        local cam = workspace.CurrentCamera
        local viewportH = (cam and cam.ViewportSize.Y) or 800
        local posY = customPosY or 48
        local calculatedH = 26 + 6 + (c * (30 + 5)) + 6
        local maxAllowedH = math.max(56, viewportH - posY - 60)
        return math.clamp(calculatedH, 56, math.min(maxAllowedH, 480))
    end

    local initialTargetH = getLbTargetHeight(#Players:GetPlayers(), 48)
    local lbWindow = Instance.new("Frame")
    lbWindow.Name = "Fih_CustomLeaderboard"
    lbWindow.Size = UDim2.new(0, 230, 0, initialTargetH)
    lbWindow.Position = UDim2.new(1, -242, 0, 48)
    lbWindow.BackgroundColor3 = C.BodyBg
    lbWindow.BackgroundTransparency = 1
    lbWindow.BorderSizePixel = 0
    lbWindow.ClipsDescendants = true
    lbWindow.ZIndex = 40
    lbWindow.Parent = ScreenGui

    -- TitleBar (Movable / Draggable Header Tab)
    local lbTitleBar = Instance.new("Frame")
    lbTitleBar.Size = UDim2.new(1, 0, 0, 24)
    lbTitleBar.BackgroundColor3 = C.TitleBar
    lbTitleBar.BackgroundTransparency = 0.25
    lbTitleBar.BorderSizePixel = 1
    lbTitleBar.BorderColor3 = C.WinBorder
    lbTitleBar.ZIndex = 41
    lbTitleBar.Parent = lbWindow
    registerThemed(lbTitleBar, { BackgroundColor3 = "TitleBar", BorderColor3 = "WinBorder" })

    local lbTitleText = Instance.new("TextLabel")
    lbTitleText.Size = UDim2.new(1, -52, 1, 0)
    lbTitleText.Position = UDim2.new(0, 8, 0, 0)
    lbTitleText.BackgroundTransparency = 1
    lbTitleText.Text = "Players (" .. tostring(#Players:GetPlayers()) .. ")"
    lbTitleText.TextColor3 = C.TitleText
    lbTitleText.Font = Enum.Font.ArimoBold
    lbTitleText.TextSize = 11
    lbTitleText.TextXAlignment = Enum.TextXAlignment.Left
    lbTitleText.ZIndex = 42
    lbTitleText.Parent = lbTitleBar
    registerThemed(lbTitleText, { TextColor3 = "TitleText" })

    local lbMinBtn = Instance.new("TextButton")
    lbMinBtn.Size = UDim2.new(0, 18, 0, 18)
    lbMinBtn.Position = UDim2.new(1, -40, 0, 3)
    lbMinBtn.BackgroundColor3 = C.BtnBg
    lbMinBtn.BorderSizePixel = 1
    lbMinBtn.BorderColor3 = C.BtnBorder
    lbMinBtn.Text = "-"
    lbMinBtn.TextColor3 = C.BtnText
    lbMinBtn.Font = Enum.Font.GothamBold
    lbMinBtn.TextSize = 12
    lbMinBtn.ZIndex = 43
    lbMinBtn.Parent = lbTitleBar
    registerThemed(lbMinBtn, { BackgroundColor3 = "BtnBg", BorderColor3 = "BtnBorder", TextColor3 = "BtnText" })

    local lbCloseBtn = Instance.new("TextButton")
    lbCloseBtn.Size = UDim2.new(0, 18, 0, 18)
    lbCloseBtn.Position = UDim2.new(1, -20, 0, 3)
    lbCloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    lbCloseBtn.BorderSizePixel = 1
    lbCloseBtn.BorderColor3 = Color3.fromRGB(220, 70, 70)
    lbCloseBtn.Text = "X"
    lbCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbCloseBtn.Font = Enum.Font.GothamBold
    lbCloseBtn.TextSize = 10
    lbCloseBtn.ZIndex = 43
    lbCloseBtn.Parent = lbTitleBar

    local ContextActionService = game:GetService("ContextActionService")

    local isLbCollapsed = false
    local isLbOpen = true
    local currentLbOpenTween = nil
    local currentLbCollapseTween = nil
    local lastTabToggleTime = 0

    local function toggleLeaderboardOpen(explicitState)
        local nextState = (explicitState ~= nil) and explicitState or (not isLbOpen)
        if nextState == isLbOpen and lbWindow.Visible == isLbOpen then return end
        isLbOpen = nextState

        if currentLbOpenTween then
            currentLbOpenTween:Cancel()
            currentLbOpenTween = nil
        end

        local curW = math.max(lbWindow.AbsoluteSize.X, 230)
        local curY = lbWindow.Position.Y.Offset

        if isLbOpen then
            lbWindow.Position = UDim2.new(1, 20, 0, curY)
            lbWindow.BackgroundTransparency = 1
            lbWindow.Visible = true
            if not isLbCollapsed and lbScroll then lbScroll.Visible = true end

            local targetH = isLbCollapsed and 24 or getLbTargetHeight(#Players:GetPlayers())
            lbWindow.Size = UDim2.new(0, curW, 0, targetH)

            if renderLeaderboardPlayers and not isLbCollapsed then
                renderLeaderboardPlayers(true)
            end

            local tweenIn = TweenService:Create(lbWindow, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(1, -(curW + 12), 0, curY),
                BackgroundTransparency = 0.50
            })
            currentLbOpenTween = tweenIn
            tweenIn:Play()
            tweenIn.Completed:Connect(function()
                if isLbOpen then
                    if not isLbCollapsed and lbResizeGrip then lbResizeGrip.Visible = true end
                end
            end)
        else
            if lbResizeGrip then lbResizeGrip.Visible = false end

            local tweenOut = TweenService:Create(lbWindow, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 20, 0, curY),
                BackgroundTransparency = 1
            })
            currentLbOpenTween = tweenOut
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                if not isLbOpen then
                    lbWindow.Visible = false
                end
            end)
        end
    end

    local function toggleLeaderboardCollapse(explicitState)
        if not isLbOpen or not lbWindow.Visible then
            toggleLeaderboardOpen(true)
            return
        end

        local nextState = (explicitState ~= nil) and explicitState or (not isLbCollapsed)
        isLbCollapsed = nextState

        if currentLbCollapseTween then
            currentLbCollapseTween:Cancel()
            currentLbCollapseTween = nil
        end

        local curW = math.max(lbWindow.AbsoluteSize.X, 230)
        local targetH = getLbTargetHeight(#Players:GetPlayers())

        if isLbCollapsed then
            lbMinBtn.Text = "+"
            if lbResizeGrip then lbResizeGrip.Visible = false end

            -- Animate all player tabs sliding out to the right when collapsed
            local sortedPlrs = {}
            for plr, entry in pairs(playerRows) do
                if entry and entry.row and entry.row.Parent then
                    table.insert(sortedPlrs, entry)
                end
            end
            table.sort(sortedPlrs, function(a, b) return (a.row.LayoutOrder or 0) < (b.row.LayoutOrder or 0) end)
            for i, entry in ipairs(sortedPlrs) do
                task.delay((i - 1) * 0.025, function()
                    if entry and entry.row and entry.row.Parent then
                        TweenService:Create(entry.row, TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                            Position = UDim2.new(0, 300, 0, 0),
                            BackgroundTransparency = 1
                        }):Play()
                        if entry.avatar then TweenService:Create(entry.avatar, TweenInfo.new(0.18), { ImageTransparency = 1 }):Play() end
                        if entry.dName then TweenService:Create(entry.dName, TweenInfo.new(0.18), { TextTransparency = 1 }):Play() end
                        if entry.uName then TweenService:Create(entry.uName, TweenInfo.new(0.18), { TextTransparency = 1 }):Play() end
                    end
                end)
            end

            local t = TweenService:Create(lbWindow, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, curW, 0, 24)
            })
            currentLbCollapseTween = t
            t:Play()
            t.Completed:Connect(function()
                if isLbCollapsed and lbScroll then
                    lbScroll.Visible = false
                end
            end)
        else
            lbMinBtn.Text = "-"
            if lbScroll then lbScroll.Visible = true end
            local t = TweenService:Create(lbWindow, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, curW, 0, targetH)
            })
            currentLbCollapseTween = t
            t:Play()
            if renderLeaderboardPlayers then
                renderLeaderboardPlayers(true)
            end
            t.Completed:Connect(function()
                if not isLbCollapsed and lbResizeGrip then
                    lbResizeGrip.Visible = true
                end
            end)
        end
    end

    lbMinBtn.MouseButton1Click:Connect(function()
        toggleLeaderboardCollapse()
    end)

    lbCloseBtn.MouseButton1Click:Connect(function()
        toggleLeaderboardOpen(false)
    end)

    local function triggerTabToggle()
        local now = tick()
        if now - lastTabToggleTime < 0.15 then return end
        local isTyping = UserInput:GetFocusedTextBox() ~= nil
        if isTyping then return end
        lastTabToggleTime = now
        toggleLeaderboardOpen()
    end

    local function handleTabKey(actionName, inputState, inputObject)
        if inputState == Enum.UserInputState.Begin then
            local isTyping = UserInput:GetFocusedTextBox() ~= nil
            if not isTyping then
                triggerTabToggle()
                return Enum.ContextActionResult.Sink
            end
        end
        return Enum.ContextActionResult.Pass
    end

    pcall(function()
        ContextActionService:BindActionAtPriority(
            "Fih_ToggleLeaderboard",
            handleTabKey,
            false,
            Enum.ContextActionPriority.High.Value + 2000,
            Enum.KeyCode.Tab
        )
    end)

    UserInput.InputBegan:Connect(function(input, gpe)
        if input.KeyCode == Enum.KeyCode.Tab then
            triggerTabToggle()
        end
    end)

    -- Dragging Logic for Leaderboard
    do
        local dragging = false
        local dragInput, dragStart, startPos
        lbTitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = lbWindow.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        lbTitleBar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInput.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                local cam = workspace.CurrentCamera
                local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
                local curW = lbWindow.AbsoluteSize.X
                local curH = lbWindow.AbsoluteSize.Y

                local rawX = (startPos.X.Scale * vp.X) + startPos.X.Offset + delta.X
                local rawY = (startPos.Y.Scale * vp.Y) + startPos.Y.Offset + delta.Y

                local clampedX = math.clamp(rawX, 4, math.max(vp.X - curW - 4, 4))
                local clampedY = math.clamp(rawY, 4, math.max(vp.Y - curH - 4, 4))

                lbWindow.Position = UDim2.new(0, clampedX, 0, clampedY)
            end
        end)
    end

    -- Resizing Grip for Leaderboard
    do
        lbResizeGrip = Instance.new("TextButton")
        lbResizeGrip.Name                   = "LBResizeGrip"
        lbResizeGrip.Size                   = UDim2.new(0, 14, 0, 14)
        lbResizeGrip.Position               = UDim2.new(1, -14, 1, -14)
        lbResizeGrip.BackgroundTransparency = 1
        lbResizeGrip.Text                   = "◢"
        lbResizeGrip.TextColor3             = C.WinBorder
        lbResizeGrip.Font                   = Enum.Font.Code
        lbResizeGrip.TextSize               = 11
        lbResizeGrip.ZIndex                 = 50
        lbResizeGrip.Parent                 = lbWindow
        registerThemed(lbResizeGrip, { TextColor3 = "WinBorder" })

        local resizing = false
        local rStartPos, rStartSize
        lbResizeGrip.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                rStartPos = i.Position
                rStartSize = lbWindow.AbsoluteSize
            end
        end)
        UserInput.InputChanged:Connect(function(i)
            if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local delta = i.Position - rStartPos
                local newW = math.clamp(rStartSize.X + delta.X, 180, 500)
                local newH = math.clamp(rStartSize.Y + delta.Y, 70, 800)
                lbWindow.Size = UDim2.new(0, newW, 0, newH)
            end
        end)
        UserInput.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                resizing = false
            end
        end)
    end

    -- Scroll Area (Spaced Out Player Tabs)
    lbScroll = Instance.new("ScrollingFrame")
    lbScroll.Size = UDim2.new(1, 0, 1, -26)
    lbScroll.Position = UDim2.new(0, 0, 0, 26)
    lbScroll.BackgroundTransparency = 1
    lbScroll.BorderSizePixel = 0
    lbScroll.ScrollBarThickness = 3
    lbScroll.ScrollBarImageColor3 = C.WinBorder
    lbScroll.ScrollBarImageTransparency = 0.4
    lbScroll.ClipsDescendants = true
    lbScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    lbScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    lbScroll.ZIndex = 41
    lbScroll.Parent = lbWindow

    local lbLayout = Instance.new("UIListLayout")
    lbLayout.SortOrder = Enum.SortOrder.LayoutOrder
    lbLayout.Padding = UDim.new(0, 5)
    lbLayout.Parent = lbScroll

    local lbPad = Instance.new("UIPadding")
    lbPad.PaddingTop = UDim.new(0, 2)
    lbPad.PaddingBottom = UDim.new(0, 4)
    lbPad.PaddingLeft = UDim.new(0, 0)
    lbPad.PaddingRight = UDim.new(0, 0)
    lbPad.Parent = lbScroll

    -- ── THEMED PLAYER PROFILE POPUP CARD ────────────────────────
    local profileCard = Instance.new("Frame")
    profileCard.Name = "Fih_PlayerProfileCard"
    profileCard.Size = UDim2.new(0, 220, 0, 215)
    profileCard.Position = UDim2.new(1, -475, 0, 48)
    profileCard.BackgroundColor3 = C.BodyBg
    profileCard.BackgroundTransparency = 0.15
    profileCard.BorderSizePixel = 1
    profileCard.BorderColor3 = C.WinBorder
    profileCard.ZIndex = 90
    profileCard.Visible = false
    profileCard.ClipsDescendants = true
    profileCard.Parent = ScreenGui
    registerThemed(profileCard, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder" })

    local pcHeader = Instance.new("Frame")
    pcHeader.Size = UDim2.new(1, 0, 0, 24)
    pcHeader.BackgroundColor3 = C.TitleBar
    pcHeader.BackgroundTransparency = 0.20
    pcHeader.BorderSizePixel = 1
    pcHeader.BorderColor3 = C.WinBorder
    pcHeader.ZIndex = 91
    pcHeader.Parent = profileCard
    registerThemed(pcHeader, { BackgroundColor3 = "TitleBar", BorderColor3 = "WinBorder" })

    local pcTitle = Instance.new("TextLabel")
    pcTitle.Size = UDim2.new(1, -28, 1, 0)
    pcTitle.Position = UDim2.new(0, 8, 0, 0)
    pcTitle.BackgroundTransparency = 1
    pcTitle.Text = "Player Profile"
    pcTitle.TextColor3 = C.TitleText
    pcTitle.Font = Enum.Font.ArimoBold
    pcTitle.TextSize = 11
    pcTitle.TextXAlignment = Enum.TextXAlignment.Left
    pcTitle.ZIndex = 92
    pcTitle.Parent = pcHeader
    registerThemed(pcTitle, { TextColor3 = "TitleText" })

    local pcClose = Instance.new("TextButton")
    pcClose.Size = UDim2.new(0, 18, 0, 18)
    pcClose.Position = UDim2.new(1, -21, 0, 3)
    pcClose.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    pcClose.BorderSizePixel = 1
    pcClose.BorderColor3 = Color3.fromRGB(220, 70, 70)
    pcClose.Text = "X"
    pcClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    pcClose.Font = Enum.Font.GothamBold
    pcClose.TextSize = 10
    pcClose.ZIndex = 93
    pcClose.Parent = pcHeader
    pcClose.MouseButton1Click:Connect(function()
        profileCard.Visible = false
    end)

    local pcAvatar = Instance.new("ImageLabel")
    pcAvatar.Size = UDim2.new(0, 42, 0, 42)
    pcAvatar.Position = UDim2.new(0, 8, 0, 30)
    pcAvatar.BackgroundTransparency = 1
    pcAvatar.BorderSizePixel = 1
    pcAvatar.BorderColor3 = C.WinBorder
    pcAvatar.ZIndex = 91
    pcAvatar.Parent = profileCard
    registerThemed(pcAvatar, { BorderColor3 = "WinBorder" })

    local pcDName = Instance.new("TextLabel")
    pcDName.Size = UDim2.new(1, -58, 0, 15)
    pcDName.Position = UDim2.new(0, 56, 0, 30)
    pcDName.BackgroundTransparency = 1
    pcDName.Text = "DisplayName"
    pcDName.TextColor3 = C.BtnText
    pcDName.Font = Enum.Font.ArimoBold
    pcDName.TextSize = 11
    pcDName.TextXAlignment = Enum.TextXAlignment.Left
    pcDName.TextTruncate = Enum.TextTruncate.AtEnd
    pcDName.ZIndex = 91
    pcDName.Parent = profileCard
    registerThemed(pcDName, { TextColor3 = "BtnText" })

    local pcUName = Instance.new("TextLabel")
    pcUName.Size = UDim2.new(1, -58, 0, 13)
    pcUName.Position = UDim2.new(0, 56, 0, 45)
    pcUName.BackgroundTransparency = 1
    pcUName.Text = "@Username"
    pcUName.TextColor3 = C.Accent
    pcUName.Font = Enum.Font.Code
    pcUName.TextSize = 10
    pcUName.TextXAlignment = Enum.TextXAlignment.Left
    pcUName.TextTruncate = Enum.TextTruncate.AtEnd
    pcUName.ZIndex = 91
    pcUName.Parent = profileCard
    registerThemed(pcUName, { TextColor3 = "Accent" })

    local pcInfo = Instance.new("TextLabel")
    pcInfo.Size = UDim2.new(1, -58, 0, 13)
    pcInfo.Position = UDim2.new(0, 56, 0, 58)
    pcInfo.BackgroundTransparency = 1
    pcInfo.Text = "ID: 0"
    pcInfo.TextColor3 = C.BannerSub
    pcInfo.Font = Enum.Font.Code
    pcInfo.TextSize = 9
    pcInfo.TextXAlignment = Enum.TextXAlignment.Left
    pcInfo.ZIndex = 91
    pcInfo.Parent = profileCard
    registerThemed(pcInfo, { TextColor3 = "BannerSub" })

    local function makePcBtn(text, yPos, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -16, 0, 24)
        btn.Position = UDim2.new(0, 8, 0, yPos)
        btn.BackgroundColor3 = C.BtnBg
        btn.BackgroundTransparency = 0.25
        btn.BorderSizePixel = 1
        btn.BorderColor3 = C.BtnBorder
        btn.Text = text
        btn.TextColor3 = C.BtnText
        btn.Font = Enum.Font.Code
        btn.TextSize = 10
        btn.ZIndex = 92
        btn.Parent = profileCard
        registerThemed(btn, { BackgroundColor3 = "BtnBg", BorderColor3 = "BtnBorder", TextColor3 = "BtnText" })
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = C.BtnHover }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = C.BtnBg }):Play()
        end)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    local currentSelectedPlr = nil
    local function openPlayerProfile(plr, rowInstance)
        if not plr then return end
        currentSelectedPlr = plr
        pcTitle.Text = "Player :: @" .. plr.Name
        pcDName.Text = plr.DisplayName
        pcUName.Text = "@" .. plr.Name
        pcInfo.Text = "Age: " .. tostring(plr.AccountAge) .. "d | ID: " .. tostring(plr.UserId)
        pcAvatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(plr.UserId) .. "&width=150&height=150&format=png"

        local cardH = 215
        local cardW = 220
        local cam = workspace.CurrentCamera
        local viewportH = (cam and cam.ViewportSize.Y) or 800

        local rowY = (rowInstance and rowInstance.AbsolutePosition.Y) or lbWindow.AbsolutePosition.Y
        local targetY = math.clamp(rowY - 8, 36, viewportH - cardH - 12)
        local targetX = math.max(lbWindow.AbsolutePosition.X - cardW - 8, 8)
        local startX  = targetX + 45

        profileCard.Position = UDim2.new(0, startX, 0, targetY)
        profileCard.BackgroundTransparency = 1
        profileCard.Visible = true

        pcall(function()
            TweenService:Create(profileCard, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, targetX, 0, targetY),
                BackgroundTransparency = 0.15
            }):Play()
        end)
    end

    makePcBtn("📋  Copy Username", 78, function()
        if currentSelectedPlr then
            local clip = setclipboard or (getgenv and getgenv().setclipboard)
            if type(clip) == "function" then
                pcall(function() clip(currentSelectedPlr.Name) end)
            end
            sendNotification("Player Profile", "Copied @" .. currentSelectedPlr.Name .. " to clipboard", true)
        end
    end)

    makePcBtn("📋  Copy User ID", 108, function()
        if currentSelectedPlr then
            local clip = setclipboard or (getgenv and getgenv().setclipboard)
            if type(clip) == "function" then
                pcall(function() clip(tostring(currentSelectedPlr.UserId)) end)
            end
            sendNotification("Player Profile", "Copied ID: " .. tostring(currentSelectedPlr.UserId) .. " to clipboard", true)
        end
    end)

    makePcBtn("👥  Send Friend Request", 138, function()
        if currentSelectedPlr then
            pcall(function()
                StarterGui:SetCore("PromptSendFriendRequest", currentSelectedPlr)
            end)
        end
    end)

    makePcBtn("👁  Inspect Roblox Avatar", 168, function()
        if currentSelectedPlr then
            pcall(function()
                GuiService:InspectPlayerFromUserId(currentSelectedPlr.UserId)
            end)
        end
    end)

    local function createPlayerRow(plr, layoutOrder, staggerDelay)
        if playerRows[plr] and playerRows[plr].row and playerRows[plr].row.Parent then
            playerRows[plr].row.LayoutOrder = layoutOrder or 1
            return playerRows[plr].row
        end

        local row = Instance.new("Frame")
        row.Name = "TabCard_" .. plr.Name
        row.Size = UDim2.new(1, 0, 0, 30)
        -- Start position: off-screen to the right (appears from right to left)
        row.Position = UDim2.new(0, 280, 0, 0)
        row.BackgroundColor3 = C.RowBg
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 1
        row.BorderColor3 = C.WinBorder
        row.LayoutOrder = layoutOrder or 1
        row.ZIndex = 42
        row.Parent = lbScroll
        registerThemed(row, { BackgroundColor3 = "RowBg", BorderColor3 = "WinBorder" })

        local avatar = Instance.new("ImageLabel")
        avatar.Size = UDim2.new(0, 24, 0, 24)
        avatar.Position = UDim2.new(0, 3, 0, 3)
        avatar.BackgroundTransparency = 1
        avatar.ImageTransparency = 1
        avatar.BorderSizePixel = 0
        avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(plr.UserId) .. "&width=48&height=48&format=png"
        avatar.ZIndex = 43
        avatar.Parent = row

        local dName = Instance.new("TextLabel")
        dName.Size = UDim2.new(1, -34, 0, 13)
        dName.Position = UDim2.new(0, 32, 0, 2)
        dName.BackgroundTransparency = 1
        dName.TextTransparency = 1
        dName.Text = plr.DisplayName
        dName.TextColor3 = C.BtnText
        dName.Font = Enum.Font.ArimoBold
        dName.TextSize = 11
        dName.TextXAlignment = Enum.TextXAlignment.Left
        dName.TextTruncate = Enum.TextTruncate.AtEnd
        dName.ZIndex = 43
        dName.Parent = row
        registerThemed(dName, { TextColor3 = "BtnText" })

        local uName = Instance.new("TextLabel")
        uName.Size = UDim2.new(1, -34, 0, 12)
        uName.Position = UDim2.new(0, 32, 0, 15)
        uName.BackgroundTransparency = 1
        uName.TextTransparency = 1
        uName.Text = "@" .. plr.Name
        uName.TextColor3 = (plr == Players.LocalPlayer) and Color3.fromRGB(0, 220, 140) or (isDark and Color3.fromRGB(120, 150, 190) or Color3.fromRGB(70, 90, 120))
        uName.Font = Enum.Font.Code
        uName.TextSize = 9
        uName.TextXAlignment = Enum.TextXAlignment.Left
        uName.TextTruncate = Enum.TextTruncate.AtEnd
        uName.ZIndex = 43
        uName.Parent = row

        local rowBtn = Instance.new("TextButton")
        rowBtn.Size = UDim2.new(1, 0, 1, 0)
        rowBtn.BackgroundTransparency = 1
        rowBtn.Text = ""
        rowBtn.ZIndex = 44
        rowBtn.Parent = row

        rowBtn.MouseEnter:Connect(function()
            TweenSvc:Create(row, TweenInfo.new(0.12), { BackgroundTransparency = 0.15, BackgroundColor3 = C.RowHover }):Play()
        end)
        rowBtn.MouseLeave:Connect(function()
            TweenSvc:Create(row, TweenInfo.new(0.12), { BackgroundTransparency = 0.35, BackgroundColor3 = C.RowBg }):Play()
        end)
        rowBtn.MouseButton1Click:Connect(function()
            openPlayerProfile(plr, row)
        end)

        playerRows[plr] = {
            row = row,
            avatar = avatar,
            dName = dName,
            uName = uName
        }

        -- Right-to-Left Entrance Transition (0.075s stagger delay for domino on launch / immediate on join)
        local function playEntrance()
            if row and row.Parent then
                TweenSvc:Create(row, TweenInfo.new(0.34, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0, 0, 0, 0),
                    BackgroundTransparency = 0.35
                }):Play()
                TweenSvc:Create(avatar, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    ImageTransparency = 0
                }):Play()
                TweenSvc:Create(dName, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    TextTransparency = 0
                }):Play()
                TweenSvc:Create(uName, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    TextTransparency = 0
                }):Play()
            end
        end

        if staggerDelay and staggerDelay > 0 then
            task.delay(staggerDelay, playEntrance)
        else
            task.spawn(playEntrance)
        end

        return row
    end

    local function updateLeaderboardHeight(count)
        local allPlrs = Players:GetPlayers()
        local c = count or #allPlrs
        lbTitleText.Text = "Players (" .. tostring(c) .. ")"
        local targetH = getLbTargetHeight(c)
        local curW = math.max(lbWindow.AbsoluteSize.X, 230)
        if isLbOpen and lbWindow.Visible and not isLbCollapsed then
            pcall(function()
                TweenSvc:Create(lbWindow, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, curW, 0, targetH)
                }):Play()
            end)
        end
    end

    renderLeaderboardPlayers = function(animateDomino)
        for plr, entry in pairs(playerRows) do
            if entry.row then
                pcall(function() entry.row:Destroy() end)
            end
        end
        playerRows = {}

        local allPlrs = Players:GetPlayers()
        updateLeaderboardHeight(#allPlrs)

        for i, plr in ipairs(allPlrs) do
            local delay = animateDomino and ((i - 1) * 0.075) or 0
            createPlayerRow(plr, i, delay)
        end
    end

    -- Initial domino cascade on script execution (Right to Left)
    renderLeaderboardPlayers(true)

    -- New Player Joined: Slides in smoothly from Right to Left
    local pAddedConn = Players.PlayerAdded:Connect(function(plr)
        updateLeaderboardHeight(#Players:GetPlayers())
        createPlayerRow(plr, #Players:GetPlayers(), 0)
    end)
    if Shared.AddCleanup then Shared.AddCleanup(pAddedConn) end

    -- Player Leaving: Slides out smoothly from Left to Right and destroys
    local pRemovingConn = Players.PlayerRemoving:Connect(function(plr)
        local countAfter = math.max(0, #Players:GetPlayers() - 1)
        updateLeaderboardHeight(countAfter)

        local entry = playerRows[plr]
        if entry and entry.row and entry.row.Parent then
            local row = entry.row
            playerRows[plr] = nil

            local slideOut = TweenSvc:Create(row, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(0, 300, 0, 0),
                BackgroundTransparency = 1
            })
            if entry.avatar then
                TweenSvc:Create(entry.avatar, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { ImageTransparency = 1 }):Play()
            end
            if entry.dName then
                TweenSvc:Create(entry.dName, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
            end
            if entry.uName then
                TweenSvc:Create(entry.uName, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
            end

            slideOut:Play()
            slideOut.Completed:Connect(function()
                pcall(function() row:Destroy() end)
            end)
        end
    end)
    if Shared.AddCleanup then Shared.AddCleanup(pRemovingConn) end

    local cam = workspace.CurrentCamera
    if cam then
        local camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if isLbOpen and lbWindow.Visible and not isLbCollapsed then
                updateLeaderboardHeight(#Players:GetPlayers())
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(camConn) end
    end

    if Shared.RegisterThemeCallback then
        Shared.RegisterThemeCallback(function(targetTheme, isDarkMode)
            C = targetTheme
            isDark = isDarkMode
            renderLeaderboardPlayers(false)
        end)
    end

    Shared.ToggleLeaderboard = toggleLeaderboardOpen

    -- ── CUSTOM WINDOWS AERO CHAT (UNIFIED TOPBAR: ROBLOX, ≡, 🎙, DEDUP) ─
    local chatScroll = nil
    local inputBar = nil
    local chatResizeGrip = nil

    local chatWindow = Instance.new("Frame")
    chatWindow.Name = "Fih_CustomChat"
    chatWindow.Size = UDim2.new(0, 420, 0, 260)
    chatWindow.Position = UDim2.new(0, 8, 0, 4)
    chatWindow.BackgroundColor3 = C.BodyBg
    chatWindow.BackgroundTransparency = 0.45
    chatWindow.BorderSizePixel = 1
    chatWindow.BorderColor3 = C.WinBorder
    chatWindow.ClipsDescendants = true
    chatWindow.ZIndex = 40
    chatWindow.Parent = ScreenGui
    registerThemed(chatWindow, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder" })
    local chatWinCorner = Instance.new("UICorner")
    chatWinCorner.CornerRadius = UDim.new(0, 0)
    chatWinCorner.Parent = chatWindow

    -- TitleBar (Unified TopBar: [Roblox] [≡] [🎙] Title ... [-] [□])
    local chatTitleBar = Instance.new("Frame")
    chatTitleBar.Size = UDim2.new(1, 0, 0, 26)
    chatTitleBar.BackgroundColor3 = C.TitleBar
    chatTitleBar.BackgroundTransparency = 0.25
    chatTitleBar.BorderSizePixel = 1
    chatTitleBar.BorderColor3 = C.WinBorder
    chatTitleBar.ZIndex = 41
    chatTitleBar.Parent = chatWindow
    registerThemed(chatTitleBar, { BackgroundColor3 = "TitleBar", BorderColor3 = "WinBorder" })
    local chatTitleCorner = Instance.new("UICorner")
    chatTitleCorner.CornerRadius = UDim.new(0, 0)
    chatTitleCorner.Parent = chatTitleBar

    -- Left Navigation: [Roblox] [≡] [🎙] + Mic Meter
    local leftNavHolder = Instance.new("Frame")
    leftNavHolder.Size = UDim2.new(0, 105, 0, 20)
    leftNavHolder.Position = UDim2.new(0, 4, 0, 3)
    leftNavHolder.BackgroundTransparency = 1
    leftNavHolder.ZIndex = 42
    leftNavHolder.Parent = chatTitleBar

    -- 1. [Roblox Logo] Button (Toggles Pause / Escape Menu)
    local rbxLogoBtn = Instance.new("ImageButton")
    rbxLogoBtn.Size = UDim2.new(0, 22, 0, 20)
    rbxLogoBtn.Position = UDim2.new(0, 0, 0, 0)
    rbxLogoBtn.BackgroundColor3 = C.BtnBg
    rbxLogoBtn.BorderSizePixel = 1
    rbxLogoBtn.BorderColor3 = C.BtnBorder
    rbxLogoBtn.Image = "rbxasset://textures/ui/TopBar/icon_roblox.png"
    rbxLogoBtn.ImageColor3 = C.BtnText
    rbxLogoBtn.ScaleType = Enum.ScaleType.Fit
    rbxLogoBtn.ZIndex = 43
    rbxLogoBtn.Parent = leftNavHolder
    registerThemed(rbxLogoBtn, { BackgroundColor3 = "BtnBg", BorderColor3 = "BtnBorder", ImageColor3 = "BtnText" })

    rbxLogoBtn.MouseButton1Click:Connect(function()
        pcall(function()
            VirtualInput:SendKeyEvent(true, Enum.KeyCode.Escape, false, game)
            task.delay(0.03, function()
                VirtualInput:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
            end)
        end)
    end)

    -- 2. [≡] Three Lines Menu Button (Toggles In-Game Settings / Menu)
    local menuBtn = Instance.new("TextButton")
    menuBtn.Size = UDim2.new(0, 22, 0, 20)
    menuBtn.Position = UDim2.new(0, 25, 0, 0)
    menuBtn.BackgroundColor3 = C.BtnBg
    menuBtn.BorderSizePixel = 1
    menuBtn.BorderColor3 = C.BtnBorder
    menuBtn.Text = "≡"
    menuBtn.TextColor3 = C.BtnText
    menuBtn.Font = Enum.Font.ArimoBold
    menuBtn.TextSize = 14
    menuBtn.ZIndex = 43
    menuBtn.Parent = leftNavHolder
    registerThemed(menuBtn, { BackgroundColor3 = "BtnBg", BorderColor3 = "BtnBorder", TextColor3 = "BtnText" })

    -- Quick Actions Dropdown Menu (Underneath the [≡] button)
    local quickMenu = Instance.new("Frame")
    quickMenu.Name = "Fih_QuickActionsMenu"
    quickMenu.Size = UDim2.new(0, 160, 0, 145)
    quickMenu.Position = UDim2.new(0, 33, 0, 29)
    quickMenu.BackgroundColor3 = C.BodyBg
    quickMenu.BackgroundTransparency = 0.15
    quickMenu.BorderSizePixel = 1
    quickMenu.BorderColor3 = C.WinBorder
    quickMenu.ClipsDescendants = true
    quickMenu.Visible = false
    quickMenu.ZIndex = 100
    quickMenu.Parent = ScreenGui
    registerThemed(quickMenu, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder" })
    local qmCorner = Instance.new("UICorner")
    qmCorner.CornerRadius = UDim.new(0, 0)
    qmCorner.Parent = quickMenu

    local qmLayout = Instance.new("UIListLayout")
    qmLayout.FillDirection = Enum.FillDirection.Vertical
    qmLayout.SortOrder = Enum.SortOrder.LayoutOrder
    qmLayout.Padding = UDim.new(0, 1)
    qmLayout.Parent = quickMenu

    local function createQuickMenuItem(text, order, callback)
        local itemBtn = Instance.new("TextButton")
        itemBtn.Size = UDim2.new(1, 0, 0, 28)
        itemBtn.BackgroundColor3 = C.BtnBg
        itemBtn.BackgroundTransparency = 0.4
        itemBtn.BorderSizePixel = 0
        itemBtn.Text = "  " .. text
        itemBtn.TextColor3 = C.BtnText
        itemBtn.Font = Enum.Font.ArimoBold
        itemBtn.TextSize = 12
        itemBtn.TextXAlignment = Enum.TextXAlignment.Left
        itemBtn.LayoutOrder = order
        itemBtn.ZIndex = 101
        itemBtn.Parent = quickMenu
        registerThemed(itemBtn, { BackgroundColor3 = "BtnBg", TextColor3 = "BtnText" })
        local ic = Instance.new("UICorner")
        ic.CornerRadius = UDim.new(0, 0)
        ic.Parent = itemBtn

        itemBtn.MouseEnter:Connect(function()
            itemBtn.BackgroundTransparency = 0.1
        end)
        itemBtn.MouseLeave:Connect(function()
            itemBtn.BackgroundTransparency = 0.4
        end)
        itemBtn.MouseButton1Click:Connect(function()
            quickMenu.Visible = false
            callback()
        end)
        return itemBtn
    end

    createQuickMenuItem("👥  Leaderboard", 1, function()
        if Shared.ToggleLeaderboard then
            Shared.ToggleLeaderboard()
        else
            local lb = ScreenGui:FindFirstChild("Fih_CustomLeaderboard")
            if lb then lb.Visible = not lb.Visible end
        end
    end)

    createQuickMenuItem("🎭  Emotes", 2, function()
        pcall(function()
            VirtualInput:SendKeyEvent(true, Enum.KeyCode.Period, false, game)
            task.delay(0.03, function()
                VirtualInput:SendKeyEvent(false, Enum.KeyCode.Period, false, game)
            end)
        end)
    end)

    createQuickMenuItem("🎒  Inventory / Backpack", 3, function()
        pcall(function()
            VirtualInput:SendKeyEvent(true, Enum.KeyCode.Backquote, false, game)
            task.delay(0.03, function()
                VirtualInput:SendKeyEvent(false, Enum.KeyCode.Backquote, false, game)
            end)
        end)
    end)

    createQuickMenuItem("🔄  Reset Character", 4, function()
        pcall(function()
            local char = Players.LocalPlayer and Players.LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.Health = 0 else char:BreakJoints() end
            end
        end)
    end)

    createQuickMenuItem("⚙️  Roblox Menu", 5, function()
        pcall(function()
            VirtualInput:SendKeyEvent(true, Enum.KeyCode.Escape, false, game)
            task.delay(0.03, function()
                VirtualInput:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
            end)
        end)
    end)

    local function updateQuickMenuPos()
        local pos = menuBtn.AbsolutePosition
        local sz  = menuBtn.AbsoluteSize
        local sgPos = ScreenGui.AbsolutePosition
        quickMenu.Position = UDim2.new(0, (pos.X - sgPos.X), 0, (pos.Y - sgPos.Y) + sz.Y + 3)
    end

    menuBtn.MouseButton1Click:Connect(function()
        quickMenu.Visible = not quickMenu.Visible
        if quickMenu.Visible then
            updateQuickMenuPos()
        end
    end)

    -- 3. [🎙] Voice Chat Mute/Unmute Button
    local vcBtn = Instance.new("TextButton")
    vcBtn.Size = UDim2.new(0, 22, 0, 20)
    vcBtn.Position = UDim2.new(0, 50, 0, 0)
    vcBtn.BackgroundColor3 = C.BtnBg
    vcBtn.BorderSizePixel = 1
    vcBtn.BorderColor3 = C.BtnBorder
    vcBtn.Text = "🎙"
    vcBtn.TextColor3 = C.BtnText
    vcBtn.Font = Enum.Font.ArimoBold
    vcBtn.TextSize = 11
    vcBtn.ZIndex = 43
    vcBtn.Parent = leftNavHolder
    registerThemed(vcBtn, { BackgroundColor3 = "BtnBg", BorderColor3 = "BtnBorder", TextColor3 = "BtnText" })

    -- 4. Mic Volume Threshold Visualizer Meter
    local micMeter = Instance.new("Frame")
    micMeter.Name = "MicVolumeMeter"
    micMeter.Size = UDim2.new(0, 24, 0, 16)
    micMeter.Position = UDim2.new(0, 75, 0, 2)
    micMeter.BackgroundTransparency = 1
    micMeter.ZIndex = 43
    micMeter.Parent = leftNavHolder

    local micBars = {}
    for i = 1, 4 do
        local mb = Instance.new("Frame")
        mb.Size = UDim2.new(0, 4, 0, 4)
        mb.Position = UDim2.new(0, (i - 1) * 6, 1, 0)
        mb.AnchorPoint = Vector2.new(0, 1)
        mb.BackgroundColor3 = Color3.fromRGB(70, 85, 110)
        mb.BorderSizePixel = 0
        mb.ZIndex = 44
        mb.Parent = micMeter
        micBars[i] = mb
    end

    local hwMicInput, hwMicAnalyzer, hwMicWire
    pcall(function()
        hwMicInput = Instance.new("AudioDeviceInput")
        hwMicInput.Player = Players.LocalPlayer
        hwMicInput.Parent = workspace

        hwMicAnalyzer = Instance.new("AudioAnalyzer")
        hwMicAnalyzer.Parent = workspace

        hwMicWire = Instance.new("Wire")
        hwMicWire.SourceInstance = hwMicInput
        hwMicWire.TargetInstance = hwMicAnalyzer
        hwMicWire.Parent = workspace
    end)

    local isMicMuted = true
    vcBtn.MouseButton1Click:Connect(function()
        isMicMuted = not isMicMuted
        pcall(function()
            local VCI = game:GetService("VoiceChatInternal")
            if VCI then
                VCI:PublishPause(isMicMuted)
            end
        end)
        vcBtn.TextColor3 = isMicMuted and C.BtnText or Color3.fromRGB(0, 220, 140)
        if Shared.Notify then
            Shared.Notify("Voice Chat", isMicMuted and "Microphone Muted [OFF]" or "Microphone Active [ON]", not isMicMuted)
        end
    end)

    if Shared.AddCleanup then
        Shared.AddCleanup(function()
            pcall(function()
                if hwMicWire then hwMicWire:Destroy() end
                if hwMicAnalyzer then hwMicAnalyzer:Destroy() end
                if hwMicInput then hwMicInput:Destroy() end
            end)
        end)
    end

    local micRenderConn = RunService.RenderStepped:Connect(function()
        if isMicMuted then 
            for i, mb in ipairs(micBars) do
                if mb and mb.Parent then
                    mb.Size = UDim2.new(0, 4, 0, 3)
                    mb.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
                end
            end
            return 
        end
        local rawLevel = 0
        if hwMicAnalyzer then
            pcall(function()
                local rms  = hwMicAnalyzer.RmsLevel or 0
                local peak = hwMicAnalyzer.PeakLevel or 0
                rawLevel = math.max(rms * 12.0, peak * 6.0)
            end)
        end

        local level = math.clamp(rawLevel, 0, 1)
        local fallbackT = os.clock() * 8

        for i, mb in ipairs(micBars) do
            if mb and mb.Parent then
                local threshold = (i / 4.0)
                local barLevel
                if rawLevel > 0.005 then
                    barLevel = math.clamp((level - (threshold - 0.25)) / 0.25, 0.15, 1)
                else
                    barLevel = 0.2 + 0.1 * math.sin(fallbackT + i * 0.8)
                end
                local barH = math.clamp(math.floor(barLevel * 15) + 1, 3, 16)
                mb.Size = UDim2.new(0, 4, 0, barH)
                mb.BackgroundColor3 = (i == 4) and Color3.fromRGB(255, 80, 80)
                    or ((i >= 3) and Color3.fromRGB(255, 205, 40)
                    or Color3.fromRGB(0, 230, 140))
            end
        end
    end)
    if Shared.AddCleanup then Shared.AddCleanup(micRenderConn) end

    -- Title Label
    local chatTitleText = Instance.new("TextLabel")
    chatTitleText.Size = UDim2.new(1, -165, 1, 0)
    chatTitleText.Position = UDim2.new(0, 110, 0, 0)
    chatTitleText.BackgroundTransparency = 1
    chatTitleText.Text = "Chat"
    chatTitleText.TextColor3 = C.TitleText
    chatTitleText.Font = Enum.Font.ArimoBold
    chatTitleText.TextSize = 13
    chatTitleText.TextXAlignment = Enum.TextXAlignment.Left
    chatTitleText.ZIndex = 42
    chatTitleText.Parent = chatTitleBar
    registerThemed(chatTitleText, { TextColor3 = "TitleText" })

    -- Right Control Buttons: [-] Minimize, [□] Maximize
    local chatCtrlHolder = Instance.new("Frame")
    chatCtrlHolder.Size = UDim2.new(0, 48, 0, 20)
    chatCtrlHolder.Position = UDim2.new(1, -52, 0, 3)
    chatCtrlHolder.BackgroundTransparency = 1
    chatCtrlHolder.ZIndex = 42
    chatCtrlHolder.Parent = chatTitleBar

    local chatMinBtn = Instance.new("TextButton")
    chatMinBtn.Size = UDim2.new(0, 20, 0, 20)
    chatMinBtn.Position = UDim2.new(0, 0, 0, 0)
    chatMinBtn.BackgroundColor3 = C.BtnBg
    chatMinBtn.BorderSizePixel = 1
    chatMinBtn.BorderColor3 = C.BtnBorder
    chatMinBtn.Text = "-"
    chatMinBtn.TextColor3 = C.BtnText
    chatMinBtn.Font = Enum.Font.ArimoBold
    chatMinBtn.TextSize = 13
    chatMinBtn.ZIndex = 43
    chatMinBtn.Parent = chatCtrlHolder
    registerThemed(chatMinBtn, { BackgroundColor3 = "BtnBg", BorderColor3 = "BtnBorder", TextColor3 = "BtnText" })

    local chatMaxBtn = Instance.new("TextButton")
    chatMaxBtn.Size = UDim2.new(0, 20, 0, 20)
    chatMaxBtn.Position = UDim2.new(0, 24, 0, 0)
    chatMaxBtn.BackgroundColor3 = C.BtnBg
    chatMaxBtn.BorderSizePixel = 1
    chatMaxBtn.BorderColor3 = C.BtnBorder
    chatMaxBtn.Text = "□"
    chatMaxBtn.TextColor3 = C.BtnText
    chatMaxBtn.Font = Enum.Font.ArimoBold
    chatMaxBtn.TextSize = 11
    chatMaxBtn.ZIndex = 43
    chatMaxBtn.Parent = chatCtrlHolder
    registerThemed(chatMaxBtn, { BackgroundColor3 = "BtnBg", BorderColor3 = "BtnBorder", TextColor3 = "BtnText" })

    local isChatCollapsed = false
    local isChatMaximized = false
    local savedChatHeight = 260
    local savedChatWidth  = 420

    chatMinBtn.MouseButton1Click:Connect(function()
        isChatCollapsed = not isChatCollapsed
        if isChatCollapsed then
            savedChatHeight = math.max(chatWindow.AbsoluteSize.Y, 180)
            savedChatWidth  = chatWindow.AbsoluteSize.X
            inputBar.Visible = false
            chatScroll.Visible = false
            if chatResizeGrip then chatResizeGrip.Visible = false end
            chatMinBtn.Text = "+"
            pcall(function()
                TweenService:Create(chatWindow, TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, savedChatWidth, 0, 26)
                }):Play()
            end)
        else
            chatMinBtn.Text = "-"
            local curW = savedChatWidth or 420
            local curH = savedChatHeight or 260
            pcall(function()
                TweenService:Create(chatWindow, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, curW, 0, curH)
                }):Play()
            end)
            task.delay(0.12, function()
                if not isChatCollapsed then
                    inputBar.Visible = true
                    chatScroll.Visible = true
                    if chatResizeGrip then chatResizeGrip.Visible = true end
                end
            end)
        end
    end)

    chatMaxBtn.MouseButton1Click:Connect(function()
        isChatMaximized = not isChatMaximized
        if isChatMaximized then
            savedChatHeight = chatWindow.AbsoluteSize.Y
            savedChatWidth  = chatWindow.AbsoluteSize.X
            chatWindow.Size = UDim2.new(0, 580, 0, 420)
            chatMaxBtn.Text = "❐"
        else
            chatWindow.Size = UDim2.new(0, savedChatWidth or 420, 0, savedChatHeight or 260)
            chatMaxBtn.Text = "□"
        end
    end)

    -- Chat Dragging Engine
    do
        local isChatDragging = false
        local chatDragStart  = Vector2.zero
        local chatPosStart   = UDim2.new()

        chatTitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isChatDragging = true
                chatDragStart  = UserInput:GetMouseLocation()
                chatPosStart   = chatWindow.Position
            end
        end)

        UserInput.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isChatDragging = false
            end
        end)

        UserInput.InputChanged:Connect(function(input)
            if isChatDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local cur = UserInput:GetMouseLocation()
                local dx  = cur.X - chatDragStart.X
                local dy  = cur.Y - chatDragStart.Y
                local cam = workspace.CurrentCamera
                local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
                local curW = chatWindow.AbsoluteSize.X
                local curH = chatWindow.AbsoluteSize.Y

                local rawX = (chatPosStart.X.Scale * vp.X) + chatPosStart.X.Offset + dx
                local rawY = (chatPosStart.Y.Scale * vp.Y) + chatPosStart.Y.Offset + dy

                local clampedX = math.clamp(rawX, 4, math.max(vp.X - curW - 4, 4))
                local clampedY = math.clamp(rawY, 4, math.max(vp.Y - curH - 4, 4))

                chatWindow.Position = UDim2.new(0, clampedX, 0, clampedY)
            end
        end)
    end

    local function getUniquePlayerHex(name)
        if not name or #name == 0 then return "00ccff" end
        local hash = 0
        for i = 1, #name do
            hash = (hash * 37 + string.byte(name, i)) % 360
        end
        local col = Color3.fromHSV(hash / 360, 0.78, 0.98)
        return col:ToHex()
    end

    chatScroll = Instance.new("ScrollingFrame")
    chatScroll.Size = UDim2.new(1, -2, 1, -64)
    chatScroll.Position = UDim2.new(0, 1, 0, 27)
    chatScroll.BackgroundTransparency = 1
    chatScroll.BorderSizePixel = 0
    chatScroll.ScrollBarThickness = 0
    chatScroll.ScrollBarImageTransparency = 1
    chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    chatScroll.ZIndex = 41
    chatScroll.Parent = chatWindow
    registerThemed(chatScroll, { ScrollBarImageColor3 = "WinBorder" })

    local chatList = Instance.new("UIListLayout")
    chatList.Padding = UDim.new(0, 4)
    chatList.SortOrder = Enum.SortOrder.LayoutOrder
    chatList.Parent = chatScroll

    local chatPad = Instance.new("UIPadding")
    chatPad.PaddingLeft   = UDim.new(0, 8)
    chatPad.PaddingRight  = UDim.new(0, 8)
    chatPad.PaddingTop    = UDim.new(0, 5)
    chatPad.PaddingBottom = UDim.new(0, 5)
    chatPad.Parent = chatScroll

    local recentMsgCache = {}

    local function addChatMessage(senderName, text, customColorHex)
        if not text or #text == 0 then return end
        local dedupKey = senderName .. "::" .. text
        local now = os.clock()
        if recentMsgCache[dedupKey] and (now - recentMsgCache[dedupKey]) < 0.6 then
            return
        end
        recentMsgCache[dedupKey] = now

        local msgLabel = Instance.new("TextLabel")
        msgLabel.Size = UDim2.new(1, 0, 0, 0)
        msgLabel.BackgroundTransparency = 1
        msgLabel.RichText = true
        msgLabel.TextWrapped = true
        msgLabel.AutomaticSize = Enum.AutomaticSize.Y
        msgLabel.Font = Enum.Font.Code
        msgLabel.TextSize = 13
        msgLabel.TextXAlignment = Enum.TextXAlignment.Left
        msgLabel.TextColor3 = C.BtnText
        msgLabel.ZIndex = 42

        local nameColor = customColorHex or getUniquePlayerHex(senderName)
        local textBodyColor = isDark and "f0f4fc" or "101525"
        msgLabel.Text = string.format('<font color="#%s"><b>%s:</b></font> <font color="#%s">%s</font>', nameColor, senderName, textBodyColor, text)
        msgLabel.Parent = chatScroll

        task.defer(function()
            chatScroll.CanvasPosition = Vector2.new(0, chatScroll.AbsoluteCanvasSize.Y)
        end)
    end

    inputBar = Instance.new("Frame")
    inputBar.Size = UDim2.new(1, 0, 0, 34)
    inputBar.Position = UDim2.new(0, 0, 1, -34)
    inputBar.BackgroundColor3 = C.RowBg
    inputBar.BackgroundTransparency = 0.20
    inputBar.BorderSizePixel = 1
    inputBar.BorderColor3 = C.WinBorder
    inputBar.ZIndex = 41
    inputBar.Parent = chatWindow
    registerThemed(inputBar, { BackgroundColor3 = "RowBg", BorderColor3 = "WinBorder" })

    local quickBtn = Instance.new("TextButton")
    quickBtn.Size = UDim2.new(0, 56, 1, 0)
    quickBtn.Position = UDim2.new(0, 0, 0, 0)
    quickBtn.BackgroundColor3 = C.BtnBg
    quickBtn.BackgroundTransparency = 0.25
    quickBtn.BorderSizePixel = 1
    quickBtn.BorderColor3 = C.WinBorder
    quickBtn.Text = "Quick"
    quickBtn.TextColor3 = C.BtnText
    quickBtn.Font = Enum.Font.Code
    quickBtn.TextSize = 12
    quickBtn.ZIndex = 42
    quickBtn.Parent = inputBar
    registerThemed(quickBtn, { BackgroundColor3 = "BtnBg", BorderColor3 = "WinBorder", TextColor3 = "BtnText" })

    local chatBox = Instance.new("TextBox")
    chatBox.Size = UDim2.new(1, -118, 1, 0)
    chatBox.Position = UDim2.new(0, 56, 0, 0)
    chatBox.BackgroundColor3 = C.BodyBg
    chatBox.BackgroundTransparency = 0.15
    chatBox.BorderSizePixel = 1
    chatBox.BorderColor3 = C.WinBorder
    chatBox.Text = ""
    chatBox.PlaceholderText = "To chat click here or press / key"
    chatBox.PlaceholderColor3 = C.BannerSub
    chatBox.TextColor3 = C.BtnText
    chatBox.Font = Enum.Font.Code
    chatBox.TextSize = 13
    chatBox.ClearTextOnFocus = false
    chatBox.ZIndex = 42
    chatBox.Parent = inputBar
    registerThemed(chatBox, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder", TextColor3 = "BtnText", PlaceholderColor3 = "BannerSub" })

    local boxPad = Instance.new("UIPadding")
    boxPad.PaddingLeft  = UDim.new(0, 8)
    boxPad.PaddingRight = UDim.new(0, 8)
    boxPad.Parent = chatBox

    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0, 54, 1, 0)
    sendBtn.Position = UDim2.new(1, -76, 0, 0)
    sendBtn.BackgroundColor3 = C.BtnBg
    sendBtn.BackgroundTransparency = 0.25
    sendBtn.BorderSizePixel = 1
    sendBtn.BorderColor3 = C.WinBorder
    sendBtn.Text = "Send"
    sendBtn.TextColor3 = C.BtnText
    sendBtn.Font = Enum.Font.Code
    sendBtn.TextSize = 12
    sendBtn.ZIndex = 42
    sendBtn.Parent = inputBar
    registerThemed(sendBtn, { BackgroundColor3 = "BtnBg", BorderColor3 = "WinBorder", TextColor3 = "BtnText" })

    local function dispatchMessage(text)
        if not text or #text == 0 then return end
        local TextChatService = game:GetService("TextChatService")
        local tc = TextChatService:FindFirstChild("TextChannels")
        local general = tc and tc:FindFirstChild("RBXGeneral")
        if general then
            general:SendAsync(text)
        else
            local rEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            local sayReq = rEvents and rEvents:FindFirstChild("SayMessageRequest")
            if sayReq then
                sayReq:FireServer(text, "All")
            end
        end
        chatBox.Text = ""
    end

    chatBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and #chatBox.Text > 0 then
            dispatchMessage(chatBox.Text)
        end
    end)

    sendBtn.MouseButton1Click:Connect(function()
        if #chatBox.Text > 0 then
            dispatchMessage(chatBox.Text)
        end
    end)

    local quickPhrasesMenu = Instance.new("Frame")
    quickPhrasesMenu.Size = UDim2.new(0, 110, 0, 115)
    quickPhrasesMenu.Position = UDim2.new(0, 0, 0, -118)
    quickPhrasesMenu.BackgroundColor3 = C.BodyBg
    quickPhrasesMenu.BackgroundTransparency = 0.2
    quickPhrasesMenu.BorderSizePixel = 1
    quickPhrasesMenu.BorderColor3 = C.WinBorder
    quickPhrasesMenu.Visible = false
    quickPhrasesMenu.ZIndex = 45
    quickPhrasesMenu.Parent = inputBar
    registerThemed(quickPhrasesMenu, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder" })

    local quickPhrases = { "gg", "hello", "lol", "nice", "afk" }
    for i, phrase in ipairs(quickPhrases) do
        local qBtn = Instance.new("TextButton")
        qBtn.Size = UDim2.new(1, 0, 0, 22)
        qBtn.Position = UDim2.new(0, 0, 0, (i - 1) * 23)
        qBtn.BackgroundColor3 = C.RowBg
        qBtn.BackgroundTransparency = 0.3
        qBtn.BorderSizePixel = 1
        qBtn.BorderColor3 = C.RowBorder
        qBtn.Text = phrase
        qBtn.TextColor3 = C.BtnText
        qBtn.Font = Enum.Font.Code
        qBtn.TextSize = 11
        qBtn.ZIndex = 46
        qBtn.Parent = quickPhrasesMenu
        registerThemed(qBtn, { BackgroundColor3 = "RowBg", BorderColor3 = "RowBorder", TextColor3 = "BtnText" })

        qBtn.MouseButton1Click:Connect(function()
            dispatchMessage(phrase)
            quickPhrasesMenu.Visible = false
        end)
    end

    quickBtn.MouseButton1Click:Connect(function()
        quickPhrasesMenu.Visible = not quickPhrasesMenu.Visible
    end)

    local TextChatService = game:GetService("TextChatService")
    local isModernTextChat = (TextChatService.ChatVersion == Enum.ChatVersion.TextChatService)

    if isModernTextChat then
        TextChatService.MessageReceived:Connect(function(msg)
            if msg.Text and msg.Text:find("%[FIH_PEER:") then return end
            local sender = (msg.TextSource and msg.TextSource.Name) or "System"
            addChatMessage(sender, msg.Text, getUniquePlayerHex(sender))
        end)
    else
        for _, p in ipairs(Players:GetPlayers()) do
            p.Chatted:Connect(function(msg)
                if msg and msg:find("%[FIH_PEER:") then return end
                addChatMessage(p.DisplayName or p.Name, msg, getUniquePlayerHex(p.Name))
            end)
        end
        Players.PlayerAdded:Connect(function(p)
            p.Chatted:Connect(function(msg)
                if msg and msg:find("%[FIH_PEER:") then return end
                addChatMessage(p.DisplayName or p.Name, msg, getUniquePlayerHex(p.Name))
            end)
        end)
    end

    UserInput.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        local isCustomCore = (Shared.Flags and Shared.Flags["CustomCoreUI"] ~= false)
        if input.KeyCode == Enum.KeyCode.Slash and isCustomCore then
            task.defer(function()
                if isChatCollapsed then
                    isChatCollapsed = false
                    chatWindow.Size = UDim2.new(0, savedChatWidth, 0, savedChatHeight)
                end
                chatWindow.Visible = true
                chatBox:CaptureFocus()
                chatBox.Text = ""
                task.delay(0.015, function()
                    if chatBox.Text == "/" then
                        chatBox.Text = ""
                    end
                end)
            end)
        end
    end)

    chatBox:GetPropertyChangedSignal("Text"):Connect(function()
        if chatBox:IsFocused() and chatBox.Text == "/" then
            chatBox.Text = ""
        end
    end)

    chatResizeGrip = Instance.new("TextButton")
    chatResizeGrip.Name = "ChatResizeGrip"
    chatResizeGrip.Size = UDim2.new(0, 18, 0, 18)
    chatResizeGrip.Position = UDim2.new(1, -18, 1, -18)
    chatResizeGrip.BackgroundTransparency = 1
    chatResizeGrip.Text = "◢"
    chatResizeGrip.TextColor3 = C.WinBorder
    chatResizeGrip.Font = Enum.Font.Code
    chatResizeGrip.TextSize = 13
    chatResizeGrip.ZIndex = 60
    chatResizeGrip.Parent = chatWindow
    registerThemed(chatResizeGrip, { TextColor3 = "WinBorder" })

    do
        local isChatResizing = false
        local chatResizeStart = Vector2.zero
        local chatSizeStart   = Vector2.zero

        chatResizeGrip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isChatResizing = true
                chatResizeStart = UserInput:GetMouseLocation()
                chatSizeStart   = chatWindow.AbsoluteSize
            end
        end)

        UserInput.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isChatResizing = false
            end
        end)

        UserInput.InputChanged:Connect(function(input)
            if isChatResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local cur = UserInput:GetMouseLocation()
                local dx  = cur.X - chatResizeStart.X
                local dy  = cur.Y - chatResizeStart.Y
                local newW = math.clamp(chatSizeStart.X + dx, 260, 750)
                local newH = math.clamp(chatSizeStart.Y + dy, 160, 600)
                chatWindow.Size = UDim2.new(0, newW, 0, newH)
            end
        end)
    end

    print("[Core_Functions] Loaded -- Windows Aero Leaderboard & Chat Systems Active")
end
