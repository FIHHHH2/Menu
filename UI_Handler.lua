-- UI_Handler.lua
-- IE7/XP Modular UI -- Dark Mode Engine (Sun/Moon), Smooth Tab Transitions,
-- Full Hover/Leave Interactions, Resizable Window, and Zero-Lag Debounced Saving

return function(Shared)
    Shared.Tabs         = {}
    Shared.GUI          = nil
    Shared.MakeSection  = function() end
    Shared.MakeToggle   = function() return Instance.new("Frame"), function() end end
    Shared.MakeSlider   = function() return Instance.new("Frame") end
    Shared.MakeButton   = function() return Instance.new("TextButton") end
    Shared.SwitchTab    = function() end
    Shared.ToggleDrawer = function() end
    Shared.Notify       = function() end
    Shared.SaveConfig   = function() end
    Shared.LoadConfig   = function() end

    local TweenService = Shared.Services.TweenService
    local UserInput    = Shared.Services.UserInput
    local CoreGui      = Shared.Services.CoreGui
    local Http         = Shared.Services.Http
    local RunService   = Shared.Services.RunService or game:GetService("RunService")
    local Players      = Shared.Services.Players or game:GetService("Players")
    local StarterGui   = game:GetService("StarterGui")

    if CoreGui:FindFirstChild("IE7_Menu") then
        CoreGui:FindFirstChild("IE7_Menu"):Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "IE7_Menu"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent         = CoreGui

    -- ── THEME PALETTES ───────────────────────────────────────────
    local LightTheme = {
        WinBorder     = Color3.fromRGB(58, 110, 165),
        TitleBar      = Color3.fromRGB(212, 208, 200),
        TitleText     = Color3.fromRGB(0, 0, 0),
        NavBar        = Color3.fromRGB(188, 199, 220),
        NavText       = Color3.fromRGB(10, 20, 80),
        NavLink       = Color3.fromRGB(0, 0, 180),
        NavLinkHover  = Color3.fromRGB(255, 0, 0),
        BodyBg        = Color3.fromRGB(255, 255, 255),
        SidebarCellA  = Color3.fromRGB(210, 210, 210),
        SidebarCellB  = Color3.fromRGB(240, 240, 240),
        SidebarBorder = Color3.fromRGB(140, 160, 200),
        BtnBg         = Color3.fromRGB(236, 233, 216),
        BtnBorder     = Color3.fromRGB(113, 111, 100),
        BtnHover      = Color3.fromRGB(220, 230, 248),
        BtnDown       = Color3.fromRGB(180, 200, 230),
        BtnText       = Color3.fromRGB(0, 0, 0),
        TabActiveBg   = Color3.fromRGB(255, 255, 255),
        TabActiveText = Color3.fromRGB(0, 50, 160),
        SectionBg     = Color3.fromRGB(188, 199, 220),
        SectionText   = Color3.fromRGB(10, 20, 80),
        RowBg         = Color3.fromRGB(248, 248, 252),
        RowBorder     = Color3.fromRGB(190, 195, 210),
        RowHover      = Color3.fromRGB(232, 238, 252),
        Accent        = Color3.fromRGB(0, 100, 220),
        DrawerBg      = Color3.fromRGB(244, 246, 250),
        NotifyBg      = Color3.fromRGB(250, 250, 255),
        NotifyBorder  = Color3.fromRGB(58, 110, 165),
        BannerBg      = Color3.fromRGB(248, 250, 255),
        BannerTitle   = Color3.fromRGB(15, 30, 80),
        BannerSub     = Color3.fromRGB(90, 110, 150),
        IsDark        = false
    }

    local DarkTheme = {
        WinBorder     = Color3.fromRGB(30, 75, 130),
        TitleBar      = Color3.fromRGB(32, 36, 46),
        TitleText     = Color3.fromRGB(240, 240, 245),
        NavBar        = Color3.fromRGB(24, 28, 38),
        NavText       = Color3.fromRGB(190, 210, 245),
        NavLink       = Color3.fromRGB(100, 175, 255),
        NavLinkHover  = Color3.fromRGB(255, 110, 110),
        BodyBg        = Color3.fromRGB(16, 18, 24),
        SidebarCellA  = Color3.fromRGB(22, 26, 34),
        SidebarCellB  = Color3.fromRGB(28, 32, 42),
        SidebarBorder = Color3.fromRGB(40, 50, 70),
        BtnBg         = Color3.fromRGB(34, 38, 50),
        BtnBorder     = Color3.fromRGB(55, 65, 85),
        BtnHover      = Color3.fromRGB(48, 58, 78),
        BtnDown       = Color3.fromRGB(26, 30, 40),
        BtnText       = Color3.fromRGB(235, 240, 250),
        TabActiveBg   = Color3.fromRGB(16, 18, 24),
        TabActiveText = Color3.fromRGB(80, 170, 255),
        SectionBg     = Color3.fromRGB(26, 32, 46),
        SectionText   = Color3.fromRGB(175, 205, 250),
        RowBg         = Color3.fromRGB(22, 25, 34),
        RowBorder     = Color3.fromRGB(40, 48, 64),
        RowHover      = Color3.fromRGB(32, 38, 52),
        Accent        = Color3.fromRGB(30, 130, 245),
        DrawerBg      = Color3.fromRGB(20, 23, 32),
        NotifyBg      = Color3.fromRGB(20, 24, 34),
        NotifyBorder  = Color3.fromRGB(40, 90, 155),
        BannerBg      = Color3.fromRGB(22, 26, 36),
        BannerTitle   = Color3.fromRGB(210, 230, 255),
        BannerSub     = Color3.fromRGB(130, 150, 180),
        IsDark        = true
    }

    local isDark = false
    local C = LightTheme

    -- Theme Registry: elements register to automatically update on theme transitions
    local themeRegistry = {}
    local function registerThemed(instance, propMap)
        table.insert(themeRegistry, { inst = instance, props = propMap })
    end

    local themeCallbacks = {}     -- other modules register here to be notified on theme change
    Shared.RegisterThemeCallback = function(fn) table.insert(themeCallbacks, fn) end
    Shared.IsDark = function() return isDark end
    Shared.GetTheme = function() return C end

        -- ── ROBLOX CORE UI (TOGGLEABLE RETRO AERO & CHAT ENGINE) ──────
    local StarterGui = game:GetService("StarterGui")
    local customCoreEnabled = true
    Shared.Flags["CustomCoreUI"] = true

    local function restoreDefaultRobloxCoreUI()
        -- Re-enable native TopBar ScreenGuis
        pcall(function()
            local topbarFolder = CoreGui:FindFirstChild("TopBarApp")
            if topbarFolder then
                local topbarGui   = topbarFolder:FindFirstChild("TopBarApp")
                local topbarScrim = topbarFolder:FindFirstChild("TopBarScrim")
                if topbarGui   then topbarGui.Enabled   = true end
                if topbarScrim then topbarScrim.Enabled = true end
            end
        end)
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        end)
        local TextChatService = game:GetService("TextChatService")
        pcall(function()
            local cwc = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
            if cwc then
                cwc.Enabled                = true
                cwc.BackgroundColor3       = Color3.fromRGB(25, 27, 38)
                cwc.BackgroundTransparency = 0.3
                cwc.TextColor3             = Color3.fromRGB(255, 255, 255)
                cwc.FontFace               = Font.fromEnum(Enum.Font.BuilderSans)
            end
            local cibc = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
            if cibc then
                cibc.Enabled                = true
                cibc.BackgroundColor3       = Color3.fromRGB(25, 27, 38)
                cibc.BackgroundTransparency = 0.2
                cibc.TextColor3             = Color3.fromRGB(255, 255, 255)
                cibc.PlaceholderColor3      = Color3.fromRGB(178, 178, 178)
            end
            local expChat = CoreGui:FindFirstChild("ExperienceChat")
            if expChat then
                local app = expChat:FindFirstChild("appLayout")
                if app then app.Visible = true end
            end
        end)
    end

    local function styleRobloxCoreUI(targetTheme, isDarkMode)
        if not customCoreEnabled then return end
        local theme = targetTheme or C
        local dark  = (isDarkMode ~= nil) and isDarkMode or isDark

        local bgCol     = dark and Color3.fromRGB(16, 20, 30) or Color3.fromRGB(242, 246, 252)
        local cardBg    = dark and Color3.fromRGB(22, 28, 42) or Color3.fromRGB(230, 236, 248)
        local borderCol = dark and Color3.fromRGB(40, 85, 145) or Color3.fromRGB(140, 170, 210)
        local textCol   = dark and Color3.fromRGB(245, 250, 255) or Color3.fromRGB(15, 25, 55)
        local iconCol   = dark and Color3.fromRGB(245, 250, 255) or Color3.fromRGB(20, 25, 40)
        local inputBg   = dark and Color3.fromRGB(24, 30, 44) or Color3.fromRGB(255, 255, 255)
        local placeCol  = dark and Color3.fromRGB(120, 150, 190) or Color3.fromRGB(100, 120, 150)

        -- Universal Squircles Killer: scoped only to TopBarApp (never touches ExperienceChat)
        pcall(function()
            local topbar = CoreGui:FindFirstChild("TopBarApp")
            if topbar then
                for _, d in ipairs(topbar:GetDescendants()) do
                    if d:IsA("UICorner") then d.CornerRadius = UDim.new(0, 0) end
                end
            end
        end)

        -- 1. TopBarApp (Disable both ScreenGuis so chat bar replaces it completely)
        pcall(function()
            local topbarFolder = CoreGui:FindFirstChild("TopBarApp")
            if topbarFolder then
                local topbarGui  = topbarFolder:FindFirstChild("TopBarApp")
                local topbarScrim = topbarFolder:FindFirstChild("TopBarScrim")
                local shouldHide  = customCoreEnabled
                if topbarGui  then topbarGui.Enabled  = not shouldHide end
                if topbarScrim then topbarScrim.Enabled = not shouldHide end
            end
        end)

        -- 2. TextChatService Configurations (Hide native chat widgets when custom chat is active)
        pcall(function()
            local TextChatService = game:GetService("TextChatService")
            local cwc = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
            if cwc then
                cwc.Enabled = not customCoreEnabled
            end
            local cibc = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
            if cibc then
                cibc.Enabled = not customCoreEnabled
            end
            local expChat = CoreGui:FindFirstChild("ExperienceChat")
            if expChat then
                local app = expChat:FindFirstChild("appLayout")
                if app then app.Visible = not customCoreEnabled end
            end
        end)
    end

    -- Persistent Watcher: Re-enforces styling when active
    task.spawn(function()
        task.wait(0.3)
        styleRobloxCoreUI(C, isDark)

        local elapsed = 0
        RunService.Heartbeat:Connect(function(dt)
            if not customCoreEnabled then return end
            elapsed = elapsed + dt
            if elapsed >= 0.8 then
                elapsed = 0
                styleRobloxCoreUI(C, isDark)
            end
        end)

        CoreGui.DescendantAdded:Connect(function(desc)
            if not customCoreEnabled then return end
            if desc:IsA("UICorner") then
                -- Never touch UICorners inside ExperienceChat - corrupts BuilderIcons ligatures
                local inChat = false
                local p = desc.Parent
                while p and p ~= CoreGui do
                    if p.Name == "ExperienceChat" then inChat = true break end
                    p = p.Parent
                end
                if not inChat then desc.CornerRadius = UDim.new(0, 0) end
            end
        end)
    end)

    local function applyThemeTransition(targetTheme)
        C = targetTheme
        isDark = targetTheme.IsDark
        Shared.Config.DarkMode = isDark

        for _, item in ipairs(themeRegistry) do
            if item.inst and item.inst.Parent then
                local goal = {}
                for propName, themeKey in pairs(item.props) do
                    if C[themeKey] then
                        goal[propName] = C[themeKey]
                    end
                end
                TweenService:Create(item.inst, TweenInfo.new(0.25, Enum.EasingStyle.Quad), goal):Play()
            end
        end

        -- Notify external modules (Music_Handler HUD, Billboard, etc.)
        for _, cb in ipairs(themeCallbacks) do
            pcall(cb, targetTheme, isDark)
        end

        -- Re-skin Roblox Core UI (Chat, PlayerList, TopBar) on theme transition
        styleRobloxCoreUI(targetTheme, isDark)
    end

    -- ── ZERO-LAG DEBOUNCED CONFIG SAVING ────────────────────────
    local CONFIG_FILE = "FihUi_Config.json"
    local saveDebounce = false

    local function saveConfigDirect()
        pcall(function()
            if writefile then
                local data = {
                    Flags        = Shared.Flags,
                    SpotifyToken = Shared.Config.SpotifyToken or "",
                    LastFMUser   = Shared.Config.LastFMUser or "",
                    DarkMode     = isDark,
                    Keybinds     = {}
                }
                for fKey, item in pairs(Shared.Toggles) do
                    if item.Key then data.Keybinds[fKey] = item.Key.Name end
                end
                writefile(CONFIG_FILE, Http:JSONEncode(data))
            end
        end)
    end

    local function saveConfigDebounced()
        if saveDebounce then return end
        saveDebounce = true
        task.delay(0.6, function()
            saveDebounce = false
            saveConfigDirect()
        end)
    end
    Shared.SaveConfig = saveConfigDebounced

    local function loadConfig()
        pcall(function()
            if isfile and readfile and isfile(CONFIG_FILE) then
                local data = Http:JSONDecode(readfile(CONFIG_FILE))
                if data then
                    Shared.Config.SpotifyToken = data.SpotifyToken or ""
                    Shared.Config.LastFMUser   = data.LastFMUser or ""
                    if data.DarkMode == true then
                        applyThemeTransition(DarkTheme)
                        if themeBtn then themeBtn.Text = '☀️' end
                    end
                    if data.Flags then
                        for k, v in pairs(data.Flags) do
                            Shared.Flags[k] = v
                            if Shared.Toggles[k] and Shared.Toggles[k].SetToggle and type(v) == "boolean" then
                                Shared.Toggles[k].SetToggle(v, true)
                            end
                        end
                    end
                    if data.Keybinds then
                        for fKey, kName in pairs(data.Keybinds) do
                            local code = Enum.KeyCode[kName]
                            if code and Shared.Toggles[fKey] then
                                Shared.Toggles[fKey].Key = code
                            end
                        end
                    end
                end
            end
        end)
    end
    Shared.LoadConfig = loadConfig

    Shared.Services.Players.PlayerRemoving:Connect(function(plr)
        if plr == Shared.Player then saveConfigDirect() end
    end)

    -- ── NOTIFICATION STACK ──────────────────────────────────────
    local NotifyHolder = Instance.new("Frame")
    NotifyHolder.Name                   = "NotifyHolder"
    NotifyHolder.Size                   = UDim2.new(0, 240, 1, -20)
    NotifyHolder.Position               = UDim2.new(1, -250, 0, 10)
    NotifyHolder.BackgroundTransparency = 1
    NotifyHolder.ZIndex                 = 100
    NotifyHolder.Parent                 = ScreenGui

    local NotifyLayout = Instance.new("UIListLayout")
    NotifyLayout.SortOrder           = Enum.SortOrder.LayoutOrder
    NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    NotifyLayout.VerticalAlignment   = Enum.VerticalAlignment.Bottom
    NotifyLayout.Padding             = UDim.new(0, 6)
    NotifyLayout.Parent              = NotifyHolder

    local notifyCounter = 0
    local function sendNotification(title, message, isEnabled)
        notifyCounter = notifyCounter + 1
        local order = notifyCounter
        local toast = Instance.new("Frame")
        toast.Name             = "Toast_" .. tostring(order)
        toast.Size             = UDim2.new(1, 0, 0, 46)
        toast.BackgroundColor3 = C.NotifyBg
        toast.BorderSizePixel  = 2
        toast.BorderColor3     = isEnabled == true and Color3.fromRGB(0,160,60) or (isEnabled == false and Color3.fromRGB(200,40,40) or C.NotifyBorder)
        toast.LayoutOrder      = order
        toast.ZIndex           = 101
        toast.BackgroundTransparency = 1
        toast.Parent           = NotifyHolder

        local hBar = Instance.new("Frame")
        hBar.Size             = UDim2.new(1,0,0,18)
        hBar.BackgroundColor3 = isEnabled == true and Color3.fromRGB(225,255,230) or (isEnabled == false and Color3.fromRGB(255,230,230) or C.SectionBg)
        hBar.BorderSizePixel  = 0; hBar.ZIndex = 102; hBar.Parent = toast

        local tLbl = Instance.new("TextLabel")
        tLbl.Size                   = UDim2.new(1,-8,1,0); tLbl.Position = UDim2.new(0,6,0,0)
        tLbl.BackgroundTransparency = 1
        tLbl.Text                   = (isEnabled == true and "[✔] " or (isEnabled == false and "[✖] " or "[i] ")) .. title
        tLbl.TextColor3             = isEnabled == true and Color3.fromRGB(0,120,40) or (isEnabled == false and Color3.fromRGB(180,20,20) or C.SectionText)
        tLbl.Font                   = Enum.Font.Code; tLbl.TextSize = 11
        tLbl.TextXAlignment         = Enum.TextXAlignment.Left; tLbl.ZIndex = 103; tLbl.Parent = hBar

        local dLbl = Instance.new("TextLabel")
        dLbl.Size                   = UDim2.new(1,-12,0,24); dLbl.Position = UDim2.new(0,6,0,20)
        dLbl.BackgroundTransparency = 1; dLbl.Text = message
        dLbl.TextColor3             = isDark and Color3.fromRGB(210,220,240) or Color3.fromRGB(30,30,50)
        dLbl.Font                   = Enum.Font.Code; dLbl.TextSize = 11
        dLbl.TextXAlignment         = Enum.TextXAlignment.Left; dLbl.ZIndex = 102; dLbl.Parent = toast

        TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play()
        task.delay(2.8, function()
            if toast and toast.Parent then
                local f = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(1,0,0,0), BackgroundTransparency = 1})
                f:Play(); f.Completed:Connect(function() toast:Destroy() end)
            end
        end)
    end
    Shared.Notify = sendNotification

    -- ── MAIN WINDOW ─────────────────────────────────────────────
    local WIN_W, WIN_H = 820, 440
    local Window = Instance.new("Frame")
    Window.Name             = "Window"
    Window.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
    Window.Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
    Window.BackgroundColor3 = C.BodyBg
    Window.BorderSizePixel  = 2; Window.BorderColor3 = C.WinBorder
    Window.ClipsDescendants = true; Window.Parent = ScreenGui
    registerThemed(Window, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder" })

    -- TOPBAR
    local TITLE_H = 28
    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"; TitleBar.Size = UDim2.new(1,0,0,TITLE_H)
    TitleBar.BackgroundColor3 = C.TitleBar; TitleBar.BorderSizePixel = 1
    TitleBar.BorderColor3     = Color3.fromRGB(140,140,140); TitleBar.Parent = Window
    registerThemed(TitleBar, { BackgroundColor3 = "TitleBar" })

    local TitleText = Instance.new("TextLabel")
    TitleText.Size = UDim2.new(0,200,1,0); TitleText.Position = UDim2.new(0,10,0,0)
    TitleText.BackgroundTransparency = 1; TitleText.Text = "Fih Ui"
    TitleText.TextColor3 = C.TitleText; TitleText.Font = Enum.Font.Code
    TitleText.TextSize = 13; TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.Parent = TitleBar
    registerThemed(TitleText, { TextColor3 = "TitleText" })

    local winBtns = {}
    for _, def in ipairs({{id="min",label="[-]",x=-88},{id="max",label="[ ]",x=-58},{id="close",label="[X]",x=-28}}) do
        local b = Instance.new("TextButton")
        b.Name = "WinBtn_"..def.id; b.Size = UDim2.new(0,26,0,20)
        b.Position = UDim2.new(1,def.x,0.5,-10)
        b.BackgroundColor3 = C.BtnBg; b.Text = def.label
        b.TextColor3 = C.BtnText; b.Font = Enum.Font.Code
        b.TextSize = 11; b.BorderSizePixel = 1; b.BorderColor3 = C.BtnBorder
        b.Parent = TitleBar
        registerThemed(b, { BackgroundColor3 = "BtnBg", TextColor3 = "BtnText", BorderColor3 = "BtnBorder" })

        b.MouseEnter:Connect(function()
            local hCol = def.id == "close" and Color3.fromRGB(232,17,35) or C.BtnHover
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = hCol }):Play()
            if def.id == "close" then b.TextColor3 = Color3.fromRGB(255,255,255) end
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = C.BtnBg }):Play()
            b.TextColor3 = C.BtnText
        end)
        winBtns[def.id] = b
    end

    do  -- DRAG WINDOW
        local drag, ds, sp = false, nil, nil
        TitleBar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag=true; ds=i.Position; sp=Window.Position
            end
        end)
        TitleBar.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag=false
            end
        end)
        UserInput.InputChanged:Connect(function(i)
            if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - ds
                Window.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
            end
        end)
    end

    -- ── RESIZABLE CORNER GRIP FOR MAIN WINDOW ────────────────────
    do
        local resizeGrip = Instance.new("TextButton")
        resizeGrip.Name                   = "ResizeGrip"
        resizeGrip.Size                   = UDim2.new(0, 16, 0, 16)
        resizeGrip.Position               = UDim2.new(1, -16, 1, -16)
        resizeGrip.BackgroundTransparency = 1
        resizeGrip.Text                   = "◢"
        resizeGrip.TextColor3             = Color3.fromRGB(100, 125, 170)
        resizeGrip.Font                   = Enum.Font.Code
        resizeGrip.TextSize               = 13
        resizeGrip.ZIndex                 = 30
        resizeGrip.Parent                 = Window

        local resizing = false
        local rStartPos, rStartSize

        resizeGrip.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                resizing = true; rStartPos = i.Position; rStartSize = Window.AbsoluteSize
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
                local newW = math.clamp(rStartSize.X + d.X, 520, 1600)
                local newH = math.clamp(rStartSize.Y + d.Y, 300, 1100)
                Window.Size = UDim2.new(0, newW, 0, newH)
            end
        end)
    end

    local isOpen = true
    local function animClose()
        Window:TweenSize(UDim2.new(0,Window.AbsoluteSize.X,0,0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.2, true, function() Window.Visible=false end)
        isOpen = false
    end
    local function animOpen()
        Window.Visible = true
        Window:TweenSize(UDim2.new(0,Window.AbsoluteSize.X,0,Window.AbsoluteSize.Y > 50 and Window.AbsoluteSize.Y or WIN_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25, true)
        isOpen = true
    end
    local minimized = false
    winBtns["close"].MouseButton1Click:Connect(animClose)
    winBtns["min"].MouseButton1Click:Connect(function()
        minimized = not minimized
        Window:TweenSize(minimized and UDim2.new(0,Window.AbsoluteSize.X,0,TITLE_H) or UDim2.new(0,Window.AbsoluteSize.X,0,WIN_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
    end)
    winBtns["max"].MouseButton1Click:Connect(function() if isOpen then animClose() else animOpen() end end)
    UserInput.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == Enum.KeyCode.RightBracket then if isOpen then animClose() else animOpen() end end
    end)

    -- NAV STRIP
    local NAV_H = 26
    local NavBar = Instance.new("Frame")
    NavBar.Size = UDim2.new(1,0,0,NAV_H); NavBar.Position = UDim2.new(0,0,0,TITLE_H)
    NavBar.BackgroundColor3 = C.NavBar; NavBar.BorderSizePixel = 1
    NavBar.BorderColor3 = Color3.fromRGB(140,160,200); NavBar.Parent = Window
    registerThemed(NavBar, { BackgroundColor3 = "NavBar" })

    local NavTabLabel = Instance.new("TextLabel")
    NavTabLabel.Size = UDim2.new(0.5,0,1,0); NavTabLabel.Position = UDim2.new(0,10,0,0)
    NavTabLabel.BackgroundTransparency = 1; NavTabLabel.Text = "Main"
    NavTabLabel.TextColor3 = C.NavText; NavTabLabel.Font = Enum.Font.Code
    NavTabLabel.TextSize = 12; NavTabLabel.TextXAlignment = Enum.TextXAlignment.Left
    NavTabLabel.Parent = NavBar
    registerThemed(NavTabLabel, { TextColor3 = "NavText" })

    -- ── THEME SWITCHER BUTTON (Clean Transparent Sun / Moon Emoji) ──
    local themeBtn = Instance.new("TextButton")
    themeBtn.Name                   = "ThemeToggleBtn"
    themeBtn.Size                   = UDim2.new(0, 24, 0, 24)
    themeBtn.Position               = UDim2.new(1, -118, 0.5, -12)
    themeBtn.BackgroundTransparency = 1
    themeBtn.BorderSizePixel        = 0
    themeBtn.Text                   = "🌙"
    themeBtn.Font                   = Enum.Font.SourceSans
    themeBtn.TextSize               = 18
    themeBtn.ZIndex                 = 15
    themeBtn.Parent                 = NavBar

    themeBtn.MouseEnter:Connect(function()
        TweenService:Create(themeBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { TextSize = 21 }):Play()
    end)
    themeBtn.MouseLeave:Connect(function()
        TweenService:Create(themeBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { TextSize = 18 }):Play()
    end)

    local function updateThemeButtonIcon()
        themeBtn.Text = isDark and "☀️" or "🌙"
    end

    themeBtn.MouseButton1Click:Connect(function()
        if isDark then
            applyThemeTransition(LightTheme)
            updateThemeButtonIcon()
            sendNotification("Theme Engine", "Light Theme Applied", true)
        else
            applyThemeTransition(DarkTheme)
            updateThemeButtonIcon()
            sendNotification("Theme Engine", "Dark Theme Applied", true)
        end
        saveConfigDebounced()
    end)

    local settingsLink = Instance.new("TextButton")
    settingsLink.Size = UDim2.new(0,75,0,20); settingsLink.Position = UDim2.new(1,-85,0.5,-10)
    settingsLink.BackgroundTransparency = 1; settingsLink.Text = "settings"
    settingsLink.TextColor3 = C.NavLink; settingsLink.Font = Enum.Font.Code
    settingsLink.TextSize = 11; settingsLink.BorderSizePixel = 0; settingsLink.Parent = NavBar
    registerThemed(settingsLink, { TextColor3 = "NavLink" })

    settingsLink.MouseEnter:Connect(function()
        TweenService:Create(settingsLink, TweenInfo.new(0.12), { TextColor3 = C.NavLinkHover }):Play()
    end)
    settingsLink.MouseLeave:Connect(function()
        TweenService:Create(settingsLink, TweenInfo.new(0.12), { TextColor3 = C.NavLink }):Play()
    end)
    settingsLink.MouseButton1Click:Connect(function() Shared.ToggleDrawer("settings") end)

    -- BODY
    local BODY_Y    = TITLE_H + NAV_H
    local SIDEBAR_W = 92

    local Body = Instance.new("Frame")
    Body.Size = UDim2.new(1,0,1,-BODY_Y); Body.Position = UDim2.new(0,0,0,BODY_Y)
    Body.BackgroundColor3 = C.BodyBg; Body.BorderSizePixel = 0
    Body.ClipsDescendants = true; Body.Parent = Window
    registerThemed(Body, { BackgroundColor3 = "BodyBg" })

    -- SIDEBAR
    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0,SIDEBAR_W,1,0); Sidebar.BackgroundColor3 = C.BodyBg
    Sidebar.BorderSizePixel = 0; Sidebar.ClipsDescendants = true; Sidebar.Parent = Body
    registerThemed(Sidebar, { BackgroundColor3 = "BodyBg" })

    local CELL = 9
    local cellCache = {}
    local function updateSidebarCells()
        local targetH = math.max(Sidebar.AbsoluteSize.Y, 1500)
        local maxR = math.ceil(targetH / CELL) + 4
        for r = 0, maxR do
            for c = 0, 11 do
                local key = r * 12 + c
                if not cellCache[key] then
                    local cell = Instance.new("Frame")
                    cell.Size = UDim2.new(0, CELL, 0, CELL)
                    cell.Position = UDim2.new(0, c * CELL, 0, r * CELL)
                    cell.BorderSizePixel = 0
                    cell.BackgroundColor3 = ((r + c) % 2 == 0) and C.SidebarCellA or C.SidebarCellB
                    cell.Parent = Sidebar
                    cellCache[key] = cell
                    registerThemed(cell, { BackgroundColor3 = ((r + c) % 2 == 0) and "SidebarCellA" or "SidebarCellB" })
                end
            end
        end
    end
    updateSidebarCells()
    Sidebar:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSidebarCells)

    local SBorder = Instance.new("Frame")
    SBorder.Size = UDim2.new(0,2,1,0); SBorder.Position = UDim2.new(1,-2,0,0)
    SBorder.BackgroundColor3 = C.SidebarBorder; SBorder.BorderSizePixel = 0
    SBorder.ZIndex = 5; SBorder.Parent = Sidebar
    registerThemed(SBorder, { BackgroundColor3 = "SidebarBorder" })

    local TabContainer = Instance.new("Frame")
    TabContainer.Size = UDim2.new(1,-4,1,0); TabContainer.BackgroundTransparency = 1
    TabContainer.ZIndex = 6; TabContainer.Parent = Sidebar
    local TabLayout = Instance.new("UIListLayout")
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    TabLayout.Padding = UDim.new(0,4); TabLayout.Parent = TabContainer
    local TabPad = Instance.new("UIPadding")
    TabPad.PaddingTop = UDim.new(0,8); TabPad.Parent = TabContainer

    -- ── CONTENT AREA ─────────────────────────────────────────────
    local ContentArea = Instance.new("ScrollingFrame")
    ContentArea.Name                 = "ContentArea"
    ContentArea.Size                 = UDim2.new(1, -SIDEBAR_W, 1, 0)
    ContentArea.Position             = UDim2.new(0, SIDEBAR_W, 0, 0)
    ContentArea.BackgroundColor3     = C.BodyBg
    ContentArea.BorderSizePixel      = 0
    ContentArea.ScrollBarThickness   = 6
    ContentArea.ScrollBarImageColor3 = Color3.fromRGB(140,160,200)
    ContentArea.CanvasSize           = UDim2.new(0,0,0,0)
    ContentArea.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    ContentArea.ClipsDescendants     = true
    ContentArea.Parent               = Body
    registerThemed(ContentArea, { BackgroundColor3 = "BodyBg" })

    local CAPad = Instance.new("UIPadding")
    CAPad.PaddingTop    = UDim.new(0, 6)
    CAPad.PaddingLeft   = UDim.new(0, 6)
    CAPad.PaddingRight  = UDim.new(0, 12)
    CAPad.PaddingBottom = UDim.new(0, 12)
    CAPad.Parent        = ContentArea

    local CALayout = Instance.new("UIListLayout")
    CALayout.SortOrder = Enum.SortOrder.LayoutOrder
    CALayout.Padding   = UDim.new(0, 0)
    CALayout.Parent    = ContentArea

    -- SETTINGS DRAWER
    local Drawer = Instance.new("Frame")
    Drawer.Name = "Drawer"; Drawer.Size = UDim2.new(1,-SIDEBAR_W,1,0)
    Drawer.Position = UDim2.new(0,SIDEBAR_W,-1,0)
    Drawer.BackgroundColor3 = C.DrawerBg; Drawer.BorderSizePixel = 1
    Drawer.BorderColor3 = C.SidebarBorder; Drawer.ZIndex = 20
    Drawer.Visible = false; Drawer.ClipsDescendants = true; Drawer.Parent = Body
    registerThemed(Drawer, { BackgroundColor3 = "DrawerBg", BorderColor3 = "SidebarBorder" })

    local DHeader = Instance.new("Frame")
    DHeader.Size = UDim2.new(1,0,0,24); DHeader.BackgroundColor3 = C.SectionBg
    DHeader.BorderSizePixel = 1; DHeader.BorderColor3 = C.SidebarBorder
    DHeader.ZIndex = 21; DHeader.Parent = Drawer
    registerThemed(DHeader, { BackgroundColor3 = "SectionBg", BorderColor3 = "SidebarBorder" })

    local DTitle = Instance.new("TextLabel")
    DTitle.Size = UDim2.new(1,-85,1,0); DTitle.Position = UDim2.new(0,8,0,0)
    DTitle.BackgroundTransparency = 1; DTitle.Text = "Settings & Configuration"
    DTitle.TextColor3 = C.SectionText; DTitle.Font = Enum.Font.Code
    DTitle.TextSize = 11; DTitle.TextXAlignment = Enum.TextXAlignment.Left
    DTitle.ZIndex = 22; DTitle.Parent = DHeader
    registerThemed(DTitle, { TextColor3 = "SectionText" })

    local DClose = Instance.new("TextButton")
    DClose.Size = UDim2.new(0,76,0,18); DClose.Position = UDim2.new(1,-80,0,3)
    DClose.BackgroundColor3 = C.BtnBg; DClose.Text = "[ ▲ Close ]"
    DClose.TextColor3 = C.BtnText; DClose.Font = Enum.Font.Code
    DClose.TextSize = 10; DClose.BorderSizePixel = 1; DClose.BorderColor3 = C.BtnBorder
    DClose.ZIndex = 22; DClose.Parent = DHeader
    registerThemed(DClose, { BackgroundColor3 = "BtnBg", TextColor3 = "BtnText", BorderColor3 = "BtnBorder" })

    local DrawerScroll = Instance.new("ScrollingFrame")
    DrawerScroll.Size = UDim2.new(1,0,1,-24); DrawerScroll.Position = UDim2.new(0,0,0,24)
    DrawerScroll.BackgroundColor3 = C.DrawerBg; DrawerScroll.BorderSizePixel = 0
    DrawerScroll.ScrollBarThickness = 6; DrawerScroll.ScrollBarImageColor3 = Color3.fromRGB(140,160,200)
    DrawerScroll.CanvasSize = UDim2.new(0,0,0,0); DrawerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    DrawerScroll.ClipsDescendants = true; DrawerScroll.ZIndex = 21; DrawerScroll.Parent = Drawer
    registerThemed(DrawerScroll, { BackgroundColor3 = "DrawerBg" })

    local DLayout = Instance.new("UIListLayout")
    DLayout.SortOrder = Enum.SortOrder.LayoutOrder; DLayout.Padding = UDim.new(0,6); DLayout.Parent = DrawerScroll
    local DPad = Instance.new("UIPadding")
    DPad.PaddingTop=UDim.new(0,8); DPad.PaddingLeft=UDim.new(0,10)
    DPad.PaddingRight=UDim.new(0,16); DPad.PaddingBottom=UDim.new(0,14); DPad.Parent=DrawerScroll

    local drawerOpen = false
    local function toggleDrawer()
        drawerOpen = not drawerOpen
        if drawerOpen then
            Drawer.Visible = true
            Drawer:TweenPosition(UDim2.new(0,SIDEBAR_W,0,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25, true)
        else
            Drawer:TweenPosition(UDim2.new(0,SIDEBAR_W,-1,0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.2, true, function() Drawer.Visible=false end)
        end
    end
    DClose.MouseButton1Click:Connect(toggleDrawer)
    Shared.ToggleDrawer  = toggleDrawer
    Shared.DrawerContent = DrawerScroll

    -- ── TABS WITH SMOOTH TRANSITIONS ─────────────────────────────
    local Tabs     = {}
    local TabBtns  = {}
    local QuadCols = {}
    local activeTab = nil

    local isMM2 = (game.PlaceId == 142823291 or game.GameId == 66654135 or game.PlaceId == 335132309 or game.PlaceId == 63518381)
    if Shared.IsMM2 ~= nil then isMM2 = Shared.IsMM2 end

    local isNDS = (game.PlaceId == 189707 or game.GameId == 65241)
    if Shared.IsNDS ~= nil then isNDS = Shared.IsNDS end

    local tabDefs = {
        {name="Main",     order=1},
    }
    local curOrder = 2
    if isMM2 then
        table.insert(tabDefs, {name="MM2", order=curOrder})
        curOrder = curOrder + 1
    end
    if isNDS then
        table.insert(tabDefs, {name="Disasters", order=curOrder})
        curOrder = curOrder + 1
    end
    table.insert(tabDefs, {name="Music",    order=curOrder})
    table.insert(tabDefs, {name="Troll",    order=curOrder + 1})
    table.insert(tabDefs, {name="Keybinds", order=curOrder + 2})

    local function switchTab(name)
        if activeTab == name then return end
        activeTab = name
        NavTabLabel.Text = name

        for tName, tFrame in pairs(Tabs) do
            if tName == name then
                tFrame.Visible = true
                tFrame.Position = UDim2.new(0, 0, 0, 8)
                TweenService:Create(tFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = UDim2.new(0, 0, 0, 0) }):Play()
            else
                tFrame.Visible = false
            end
        end

        for tName, tBtn in pairs(TabBtns) do
            if tName == name then
                TweenService:Create(tBtn, TweenInfo.new(0.15), {
                    BackgroundColor3 = C.TabActiveBg,
                    TextColor3       = C.TabActiveText,
                    BorderColor3     = C.WinBorder
                }):Play()
            else
                TweenService:Create(tBtn, TweenInfo.new(0.15), {
                    BackgroundColor3 = C.BtnBg,
                    TextColor3       = C.BtnText,
                    BorderColor3     = C.BtnBorder
                }):Play()
            end
        end
    end

    for _, def in ipairs(tabDefs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0,80,0,24); btn.BackgroundColor3 = C.BtnBg
        btn.Text = def.name; btn.TextColor3 = C.BtnText; btn.Font = Enum.Font.Code
        btn.TextSize = 11; btn.BorderSizePixel = 1; btn.BorderColor3 = C.BtnBorder
        btn.LayoutOrder = def.order; btn.ZIndex = 7; btn.Parent = TabContainer
        registerThemed(btn, { BackgroundColor3 = "BtnBg", TextColor3 = "BtnText", BorderColor3 = "BtnBorder" })

        btn.MouseEnter:Connect(function()
            if activeTab ~= def.name then
                TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = C.BtnHover }):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if activeTab ~= def.name then
                TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = C.BtnBg }):Play()
            end
        end)

        local tabFrame = Instance.new("Frame")
        tabFrame.Name = "Tab_"..def.name
        tabFrame.Size = UDim2.new(1, 0, 0, 0)
        tabFrame.AutomaticSize = Enum.AutomaticSize.Y
        tabFrame.BackgroundTransparency = 1
        tabFrame.Visible = false
        tabFrame.LayoutOrder = def.order
        tabFrame.Parent = ContentArea

        local tLayout = Instance.new("UIListLayout")
        tLayout.SortOrder = Enum.SortOrder.LayoutOrder; tLayout.Padding = UDim.new(0,6); tLayout.Parent = tabFrame

        local quadFrame = Instance.new("Frame")
        quadFrame.Name = "QuadGrid"; quadFrame.Size = UDim2.new(1,0,0,0)
        quadFrame.AutomaticSize = Enum.AutomaticSize.Y; quadFrame.BackgroundTransparency = 1
        quadFrame.LayoutOrder = 2; quadFrame.Parent = tabFrame

        local leftCol = Instance.new("Frame")
        leftCol.Name = "LeftCol"; leftCol.Size = UDim2.new(0.5,-4,0,0)
        leftCol.Position = UDim2.new(0,0,0,0); leftCol.AutomaticSize = Enum.AutomaticSize.Y
        leftCol.BackgroundTransparency = 1; leftCol.Parent = quadFrame
        local lLayout = Instance.new("UIListLayout")
        lLayout.SortOrder = Enum.SortOrder.LayoutOrder; lLayout.Padding = UDim.new(0,6); lLayout.Parent = leftCol

        local rightCol = Instance.new("Frame")
        rightCol.Name = "RightCol"; rightCol.Size = UDim2.new(0.5,-4,0,0)
        rightCol.Position = UDim2.new(0.5,4,0,0); rightCol.AutomaticSize = Enum.AutomaticSize.Y
        rightCol.BackgroundTransparency = 1; rightCol.Parent = quadFrame
        local rLayout = Instance.new("UIListLayout")
        rLayout.SortOrder = Enum.SortOrder.LayoutOrder; rLayout.Padding = UDim.new(0,6); rLayout.Parent = rightCol

        Tabs[def.name] = tabFrame; TabBtns[def.name] = btn
        QuadCols[def.name] = {Left = leftCol, Right = rightCol}
        btn.MouseButton1Click:Connect(function() switchTab(def.name) end)
    end

    -- MAIN BANNER
    local mainTab = Tabs["Main"]
    local logoBox = Instance.new("Frame")
    logoBox.Size = UDim2.new(1,0,0,76); logoBox.BackgroundColor3 = C.BannerBg
    logoBox.BorderSizePixel = 1; logoBox.BorderColor3 = C.WinBorder
    logoBox.LayoutOrder = 1; logoBox.Parent = mainTab
    registerThemed(logoBox, { BackgroundColor3 = "BannerBg", BorderColor3 = "WinBorder" })

    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.new(1,0,0,46); logoText.Position = UDim2.new(0,0,0,4)
    logoText.BackgroundTransparency = 1; logoText.Text = "Fih Ui"
    logoText.TextColor3 = C.BannerTitle; logoText.Font = Enum.Font.ArimoBold
    logoText.TextSize = 40; logoText.TextXAlignment = Enum.TextXAlignment.Center; logoText.Parent = logoBox
    registerThemed(logoText, { TextColor3 = "BannerTitle" })

    local logoSub = Instance.new("TextLabel")
    logoSub.Size = UDim2.new(1,0,0,18); logoSub.Position = UDim2.new(0,0,0,50)
    logoSub.BackgroundTransparency = 1
    logoSub.Text = "Windows XP / IE7 Modular Engine  |  ] to Toggle"
    logoSub.TextColor3 = C.BannerSub; logoSub.Font = Enum.Font.Code
    logoSub.TextSize = 11; logoSub.TextXAlignment = Enum.TextXAlignment.Center; logoSub.Parent = logoBox
    registerThemed(logoSub, { TextColor3 = "BannerSub" })

    -- ── FACTORY BUILDERS WITH HOVER & THEME SUPPORT ──────────────
    local function makeSection(parent, labelText, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,0,20); lbl.BackgroundColor3 = C.SectionBg
        lbl.TextColor3 = C.SectionText; lbl.Font = Enum.Font.Code; lbl.TextSize = 11
        lbl.Text = "  ["..labelText.."]"; lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BorderSizePixel = 1; lbl.BorderColor3 = C.SidebarBorder
        lbl.LayoutOrder = order or 0; lbl.Parent = parent
        registerThemed(lbl, { BackgroundColor3 = "SectionBg", TextColor3 = "SectionText", BorderColor3 = "SidebarBorder" })
        return lbl
    end

    local function makeToggle(parent, labelText, flagKey, order, callback)
        local row = Instance.new("Frame")
        row.Name = "Toggle_"..flagKey; row.Size = UDim2.new(1,0,0,26)
        row.BackgroundColor3 = C.RowBg; row.BorderSizePixel = 1; row.BorderColor3 = C.RowBorder
        row.LayoutOrder = order or 0; row.Parent = parent
        registerThemed(row, { BackgroundColor3 = "RowBg", BorderColor3 = "RowBorder" })

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-34,1,0); lbl.Position = UDim2.new(0,6,0,0)
        lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = C.BtnText
        lbl.Font = Enum.Font.Code; lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextTruncate = Enum.TextTruncate.AtEnd; lbl.Parent = row
        registerThemed(lbl, { TextColor3 = "BtnText" })

        local box = Instance.new("TextButton")
        box.Name = "CheckBox"; box.Size = UDim2.new(0,18,0,18); box.Position = UDim2.new(1,-24,0.5,-9)
        box.BackgroundColor3 = C.BodyBg; box.BorderSizePixel = 1
        box.BorderColor3 = Color3.fromRGB(100,100,100); box.Text = ""; box.TextSize = 12
        box.Font = Enum.Font.Code; box.TextColor3 = C.Accent; box.Parent = row
        registerThemed(box, { BackgroundColor3 = "BodyBg", TextColor3 = "Accent" })

        -- Row hover effects
        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = C.RowHover }):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = C.RowBg }):Play()
        end)

        Shared.Flags[flagKey] = false
        local function setToggle(state, suppressNotify)
            Shared.Flags[flagKey] = state
            box.Text = state and "X" or ""
            box.BackgroundColor3 = state and (isDark and Color3.fromRGB(30, 60, 100) or Color3.fromRGB(220, 235, 255)) or C.BodyBg
            if callback then callback(state) end
            if not suppressNotify then sendNotification(labelText, state and "ENABLED" or "DISABLED", state) end
            saveConfigDebounced()
        end

        local overlay = Instance.new("TextButton")
        overlay.Size = UDim2.new(1,0,1,0); overlay.BackgroundTransparency = 1; overlay.Text = ""; overlay.Parent = row
        overlay.MouseButton1Click:Connect(function() setToggle(not Shared.Flags[flagKey]) end)
        box.MouseButton1Click:Connect(function() setToggle(not Shared.Flags[flagKey]) end)

        Shared.Toggles[flagKey] = {Name=labelText, SetToggle=setToggle, Key=nil}
        return row, setToggle
    end

    local function makeSlider(parent, labelText, flagKey, minVal, maxVal, defaultVal, order, callback)
        local row = Instance.new("Frame")
        row.Name = "Slider_"..flagKey; row.Size = UDim2.new(1,0,0,36)
        row.BackgroundColor3 = C.RowBg; row.BorderSizePixel = 1; row.BorderColor3 = C.RowBorder
        row.LayoutOrder = order or 0; row.Parent = parent
        registerThemed(row, { BackgroundColor3 = "RowBg", BorderColor3 = "RowBorder" })

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-45,0,16); lbl.Position = UDim2.new(0,6,0,2)
        lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = C.BtnText
        lbl.Font = Enum.Font.Code; lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextTruncate = Enum.TextTruncate.AtEnd; lbl.Parent = row
        registerThemed(lbl, { TextColor3 = "BtnText" })

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0,38,0,16); valLbl.Position = UDim2.new(1,-42,0,2)
        valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(defaultVal)
        valLbl.TextColor3 = C.Accent; valLbl.Font = Enum.Font.Code
        valLbl.TextSize = 11; valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.Parent = row
        registerThemed(valLbl, { TextColor3 = "Accent" })

        local track = Instance.new("Frame")
        track.Name = "Track"; track.Size = UDim2.new(1,-12,0,8); track.Position = UDim2.new(0,6,0,22)
        track.BackgroundColor3 = Color3.fromRGB(180, 190, 205); track.BorderSizePixel = 1
        track.BorderColor3 = Color3.fromRGB(130, 140, 160); track.Parent = row

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(math.clamp((defaultVal-minVal)/(maxVal-minVal),0,1),0,1,0)
        fill.BackgroundColor3 = C.Accent; fill.BorderSizePixel = 0; fill.Parent = track
        registerThemed(fill, { BackgroundColor3 = "Accent" })

        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = C.RowHover }):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = C.RowBg }):Play()
        end)

        Shared.Flags[flagKey] = defaultVal
        local dragging = false
        local function update(inputX)
            local pct = math.clamp((inputX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X,1), 0, 1)
            local val = math.floor(minVal + pct*(maxVal-minVal))
            Shared.Flags[flagKey] = val; fill.Size = UDim2.new(pct,0,1,0); valLbl.Text = tostring(val)
            if callback then callback(val) end
            saveConfigDebounced()
        end

        local sliderBtn = Instance.new("TextButton")
        sliderBtn.Size = UDim2.new(1,0,1,0); sliderBtn.BackgroundTransparency = 1; sliderBtn.Text = ""; sliderBtn.Parent = track
        sliderBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true; update(i.Position.X)
            end
        end)
        UserInput.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        UserInput.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i.Position.X) end
        end)
        return row
    end

    local function makeButton(parent, labelText, order, callback)
        local btn = Instance.new("TextButton")
        btn.Name = "Btn_"..labelText:gsub("%s+","_"); btn.Size = UDim2.new(1,0,0,26)
        btn.BackgroundColor3 = C.BtnBg; btn.Text = labelText; btn.TextColor3 = C.BtnText
        btn.Font = Enum.Font.Code; btn.TextSize = 11; btn.BorderSizePixel = 1; btn.BorderColor3 = C.BtnBorder
        btn.LayoutOrder = order or 0; btn.Parent = parent
        registerThemed(btn, { BackgroundColor3 = "BtnBg", TextColor3 = "BtnText", BorderColor3 = "BtnBorder" })

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = C.BtnHover }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = C.BtnBg }):Play()
        end)
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = C.BtnDown }):Play()
        end)
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = C.BtnHover }):Play()
        end)

        if callback then btn.MouseButton1Click:Connect(callback) end
        return btn
    end

    -- KEYBINDS TAB
    local keybindCols = QuadCols["Keybinds"]
    local function buildKeybindsUI()
        for _, c in ipairs(keybindCols.Left:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        for _, c in ipairs(keybindCols.Right:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        makeSection(keybindCols.Left, "Features (A-M)  [R-Click Clears]", 1)
        makeSection(keybindCols.Right, "Features (N-Z)  [R-Click Clears]", 1)
        local toggleList = {}
        for fKey, info in pairs(Shared.Toggles) do table.insert(toggleList, {Key=fKey, Info=info}) end
        table.sort(toggleList, function(a,b) return a.Info.Name < b.Info.Name end)
        local listeningKeyFor = nil
        for idx, item in ipairs(toggleList) do
            local parentCol = (idx%2==1) and keybindCols.Left or keybindCols.Right
            local fKey = item.Key; local info = item.Info
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,0,0,26); row.BackgroundColor3 = C.RowBg
            row.BorderSizePixel = 1; row.BorderColor3 = C.RowBorder
            row.LayoutOrder = idx+1; row.Parent = parentCol
            registerThemed(row, { BackgroundColor3 = "RowBg", BorderColor3 = "RowBorder" })

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,-66,1,0); lbl.Position = UDim2.new(0,6,0,0)
            lbl.BackgroundTransparency = 1; lbl.Text = info.Name; lbl.TextColor3 = C.BtnText
            lbl.Font = Enum.Font.Code; lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextTruncate = Enum.TextTruncate.AtEnd; lbl.Parent = row
            registerThemed(lbl, { TextColor3 = "BtnText" })

            local bindBtn = Instance.new("TextButton")
            bindBtn.Size = UDim2.new(0,58,0,20); bindBtn.Position = UDim2.new(1,-62,0.5,-10)
            bindBtn.BackgroundColor3 = C.BtnBg; bindBtn.BorderSizePixel = 1; bindBtn.BorderColor3 = C.BtnBorder
            bindBtn.Text = info.Key and ("["..info.Key.Name.."]") or "[ None ]"
            bindBtn.TextColor3 = info.Key and C.Accent or Color3.fromRGB(120,120,120)
            bindBtn.Font = Enum.Font.Code; bindBtn.TextSize = 10; bindBtn.Parent = row
            registerThemed(bindBtn, { BackgroundColor3 = "BtnBg", BorderColor3 = "BtnBorder" })

            bindBtn.MouseButton1Click:Connect(function()
                listeningKeyFor = fKey; bindBtn.Text = "[ ... ]"; bindBtn.TextColor3 = Color3.fromRGB(220,80,0)
            end)

            -- Right-click to clear keybind
            bindBtn.MouseButton2Click:Connect(function()
                if Shared.Toggles[fKey] then
                    Shared.Toggles[fKey].Key = nil
                    sendNotification(Shared.Toggles[fKey].Name, "Keybind Cleared", nil)
                    saveConfigDebounced()
                    buildKeybindsUI()
                end
            end)
        end

        if Shared._KeybindConn then Shared._KeybindConn:Disconnect() end
        Shared._KeybindConn = UserInput.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if listeningKeyFor then
                    local target = listeningKeyFor; listeningKeyFor = nil
                    if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
                        Shared.Toggles[target].Key = nil
                        sendNotification(Shared.Toggles[target].Name, "Keybind Cleared", nil)
                    else
                        Shared.Toggles[target].Key = input.KeyCode
                        sendNotification(Shared.Toggles[target].Name, "Bound to ["..input.KeyCode.Name.."]", true)
                    end
                    saveConfigDebounced(); buildKeybindsUI()
                else
                    for fKey, info in pairs(Shared.Toggles) do
                        if info.Key and info.Key == input.KeyCode then info.SetToggle(not Shared.Flags[fKey]) end
                    end
                end
            end
        end)
    end

    task.delay(0.6, function() loadConfig(); buildKeybindsUI() end)

    -- SETTINGS DRAWER POPULATION (General, Performance, Audio & Camera)
    local Lighting = game:GetService("Lighting")

    makeSection(DrawerScroll, "General & Engine", 1)
    makeToggle(DrawerScroll, "Custom Windows Aero Core UI", "CustomCoreUI", 2, function(state)
        customCoreEnabled = state
        local lb = ScreenGui:FindFirstChild("Fih_CustomLeaderboard")
        local ch = ScreenGui:FindFirstChild("Fih_CustomChat")
        if state then
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
            if lb then lb.Visible = true end
            if ch then ch.Visible = true end
            styleRobloxCoreUI(C, isDark)
            sendNotification("Core UI Engine", "Custom Windows Aero Core UI enabled", true)
        else
            if lb then lb.Visible = false end
            if ch then ch.Visible = false end
            restoreDefaultRobloxCoreUI()
            sendNotification("Core UI Engine", "Default Roblox Core UI restored", false)
        end
    end)
    makeButton(DrawerScroll, "Save Config File (Manual)", 3, function()
        saveConfigDirect(); sendNotification("Config Manager", "Saved to FihUi_Config.json", true)
    end)
    makeButton(DrawerScroll, "Unload / Force Close Menu", 3, function()
        saveConfigDirect(); if Shared.GUI then Shared.GUI:Destroy() end; for k in pairs(Shared.Flags) do Shared.Flags[k] = false end
    end)

    -- ── PERFORMANCE & FPS BOOST ENGINE ──────────────────────────
    makeSection(DrawerScroll, "Performance & FPS Boost", 10)

    local originalMaterials = {}
    makeToggle(DrawerScroll, "FPS Boost (Low Graphics)", "FPSBoost", 11, function(state)
        if state then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            pcall(function()
                workspace.Terrain.WaterWaveSize = 0
                workspace.Terrain.WaterWaveSpeed = 0
                workspace.Terrain.WaterReflectance = 0
                workspace.Terrain.WaterTransparency = 0
            end)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    if not originalMaterials[obj] then originalMaterials[obj] = { mat = obj.Material, shadow = obj.CastShadow } end
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.CastShadow = false
                end
            end
        else
            Lighting.GlobalShadows = true
            for obj, info in pairs(originalMaterials) do
                if obj and obj.Parent then
                    pcall(function()
                        obj.Material = info.mat
                        obj.CastShadow = info.shadow
                    end)
                end
            end
            originalMaterials = {}
        end
    end)

    local disabledEmitters = {}
    makeToggle(DrawerScroll, "Disable Particles & Trails", "NoParticles", 12, function(state)
        if state then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    if obj.Enabled then
                        disabledEmitters[obj] = true
                        obj.Enabled = false
                    end
                end
            end
        else
            for obj in pairs(disabledEmitters) do
                if obj and obj.Parent then pcall(function() obj.Enabled = true end) end
            end
            disabledEmitters = {}
        end
    end)

    local disabledEffects = {}
    makeToggle(DrawerScroll, "Disable Post-Processing", "NoPostProcessing", 13, function(state)
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

    local disabledTextures = {}
    makeToggle(DrawerScroll, "Disable 3D Textures & Decals", "NoTextures", 14, function(state)
        if state then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Decal") or obj:IsA("Texture") then
                    if obj.Transparency < 1 then
                        disabledTextures[obj] = obj.Transparency
                        obj.Transparency = 1
                    end
                end
            end
        else
            for obj, orig in pairs(disabledTextures) do
                if obj and obj.Parent then pcall(function() obj.Transparency = orig end) end
            end
            disabledTextures = {}
        end
    end)

    makeToggle(DrawerScroll, "No Shadows Mode", "NoShadows", 15, function(state)
        Lighting.GlobalShadows = not state
    end)

    local setfpscap = setfpscap or (getgenv and getgenv().setfpscap)
    if setfpscap then
        makeSlider(DrawerScroll, "FPS Cap (Max FPS)", "FPSCap", 30, 360, 144, 16, function(val)
            pcall(function() setfpscap(val) end)
        end)
    end

    -- ── AUDIO & CAMERA ───────────────────────────────────────────
    makeSection(DrawerScroll, "Audio & Camera", 20)
    makeSlider(DrawerScroll, "Master Volume", "MasterVolume", 0, 100, 50, 21, function(val)
        for _, s in ipairs(workspace:GetDescendants()) do if s:IsA("Sound") then s.Volume = val/100 end end
    end)
    makeSlider(DrawerScroll, "Field of View (FOV)", "FieldOfView", 70, 120, 70, 22, function(val)
        if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = val end
    end)

    -- EXPOSE
    Shared.GUI = ScreenGui; Shared.Tabs = Tabs; Shared.QuadCols = QuadCols
    Shared.MakeSection = makeSection; Shared.MakeToggle = makeToggle
    Shared.MakeSlider = makeSlider; Shared.MakeButton = makeButton
    -- ── CUSTOM FIH UI THEMED LEADERBOARD (DRAGGABLE, RESIZABLE, THEME-SYNCED) ──
    local StarterGui = game:GetService("StarterGui")
    local Players    = game:GetService("Players")

    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    end)

    local lbWindow = Instance.new("Frame")
    lbWindow.Name = "Fih_CustomLeaderboard"
    lbWindow.Size = UDim2.new(0, 230, 0, 360)
    lbWindow.Position = UDim2.new(1, -242, 0, 48)
    lbWindow.BackgroundColor3 = C.BodyBg
    lbWindow.BackgroundTransparency = 0.50
    lbWindow.BorderSizePixel = 1
    lbWindow.BorderColor3 = C.WinBorder
    lbWindow.ClipsDescendants = true
    lbWindow.ZIndex = 40
    lbWindow.Parent = ScreenGui
    registerThemed(lbWindow, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder" })
    local lbWinCorner = Instance.new("UICorner")
    lbWinCorner.CornerRadius = UDim.new(0, 0)
    lbWinCorner.Parent = lbWindow

    -- TitleBar (Movable / Draggable)
    local lbTitleBar = Instance.new("Frame")
    lbTitleBar.Size = UDim2.new(1, 0, 0, 24)
    lbTitleBar.BackgroundColor3 = C.TitleBar
    lbTitleBar.BackgroundTransparency = 0.40
    lbTitleBar.BorderSizePixel = 1
    lbTitleBar.BorderColor3 = C.WinBorder
    lbTitleBar.ZIndex = 41
    lbTitleBar.Parent = lbWindow
    registerThemed(lbTitleBar, { BackgroundColor3 = "TitleBar", BorderColor3 = "WinBorder" })
    local lbTitleCorner = Instance.new("UICorner")
    lbTitleCorner.CornerRadius = UDim.new(0, 0)
    lbTitleCorner.Parent = lbTitleBar

    local lbTitleText = Instance.new("TextLabel")
    lbTitleText.Size = UDim2.new(1, -30, 1, 0)
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

    local lbCloseBtn = Instance.new("TextButton")
    lbCloseBtn.Size = UDim2.new(0, 18, 0, 18)
    lbCloseBtn.Position = UDim2.new(1, -21, 0, 3)
    lbCloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    lbCloseBtn.BorderSizePixel = 1
    lbCloseBtn.BorderColor3 = Color3.fromRGB(220, 70, 70)
    lbCloseBtn.Text = "X"
    lbCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbCloseBtn.Font = Enum.Font.GothamBold
    lbCloseBtn.TextSize = 10
    lbCloseBtn.ZIndex = 43
    lbCloseBtn.Parent = lbTitleBar
    lbCloseBtn.MouseButton1Click:Connect(function()
        lbWindow.Visible = not lbWindow.Visible
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
                lbWindow.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- Resizing Grip for Leaderboard
    do
        local resizeGrip = Instance.new("TextButton")
        resizeGrip.Name                   = "LBResizeGrip"
        resizeGrip.Size                   = UDim2.new(0, 14, 0, 14)
        resizeGrip.Position               = UDim2.new(1, -14, 1, -14)
        resizeGrip.BackgroundTransparency = 1
        resizeGrip.Text                   = "◢"
        resizeGrip.TextColor3             = C.WinBorder
        resizeGrip.Font                   = Enum.Font.Code
        resizeGrip.TextSize               = 11
        resizeGrip.ZIndex                 = 50
        resizeGrip.Parent                 = lbWindow
        registerThemed(resizeGrip, { TextColor3 = "WinBorder" })

        local resizing = false
        local rStartPos, rStartSize
        resizeGrip.InputBegan:Connect(function(i)
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
                local newH = math.clamp(rStartSize.Y + delta.Y, 150, 800)
                lbWindow.Size = UDim2.new(0, newW, 0, newH)
            end
        end)
        UserInput.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                resizing = false
            end
        end)
    end

    -- Scroll Area
    local lbScroll = Instance.new("ScrollingFrame")
    lbScroll.Size = UDim2.new(1, 0, 1, -24)
    lbScroll.Position = UDim2.new(0, 0, 0, 24)
    lbScroll.BackgroundTransparency = 1
    lbScroll.BorderSizePixel = 0
    lbScroll.ScrollBarThickness = 0
    lbScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    lbScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    lbScroll.ZIndex = 41
    lbScroll.Parent = lbWindow

    local lbLayout = Instance.new("UIListLayout")
    lbLayout.SortOrder = Enum.SortOrder.LayoutOrder
    lbLayout.Padding = UDim.new(0, 3)
    lbLayout.Parent = lbScroll

    local lbPad = Instance.new("UIPadding")
    lbPad.PaddingTop = UDim.new(0, 4)
    lbPad.PaddingLeft = UDim.new(0, 4)
    lbPad.PaddingRight = UDim.new(0, 4)
    lbPad.Parent = lbScroll

    local function renderLeaderboardPlayers()
        for _, child in ipairs(lbScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local allPlrs = Players:GetPlayers()
        lbTitleText.Text = "Players (" .. tostring(#allPlrs) .. ")"

        for i, plr in ipairs(allPlrs) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 28)
            row.BackgroundColor3 = C.RowBg
            row.BackgroundTransparency = 0.55
            row.BorderSizePixel = 1
            row.BorderColor3 = C.RowBorder
            row.LayoutOrder = i
            row.ZIndex = 42
            row.Parent = lbScroll
            registerThemed(row, { BackgroundColor3 = "RowBg", BorderColor3 = "RowBorder" })

            local avatar = Instance.new("ImageLabel")
            avatar.Size = UDim2.new(0, 22, 0, 22)
            avatar.Position = UDim2.new(0, 3, 0, 3)
            avatar.BackgroundTransparency = 1
            avatar.BorderSizePixel = 0
            avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(plr.UserId) .. "&width=48&height=48&format=png"
            avatar.ZIndex = 43
            avatar.Parent = row
            -- Force square avatar: 0px corner radius
            local avatarCorner = Instance.new("UICorner")
            avatarCorner.CornerRadius = UDim.new(0, 0)
            avatarCorner.Parent = avatar

            local dName = Instance.new("TextLabel")
            dName.Size = UDim2.new(1, -32, 0, 13)
            dName.Position = UDim2.new(0, 28, 0, 2)
            dName.BackgroundTransparency = 1
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
            uName.Size = UDim2.new(1, -32, 0, 12)
            uName.Position = UDim2.new(0, 28, 0, 14)
            uName.BackgroundTransparency = 1
            uName.Text = "@" .. plr.Name
            uName.TextColor3 = (plr == Players.LocalPlayer) and Color3.fromRGB(0, 220, 140) or (isDark and Color3.fromRGB(120, 150, 190) or Color3.fromRGB(70, 90, 120))
            uName.Font = Enum.Font.Code
            uName.TextSize = 9
            uName.TextXAlignment = Enum.TextXAlignment.Left
            uName.TextTruncate = Enum.TextTruncate.AtEnd
            uName.ZIndex = 43
            uName.Parent = row
        end
    end

    renderLeaderboardPlayers()
    Players.PlayerAdded:Connect(renderLeaderboardPlayers)
    Players.PlayerRemoving:Connect(renderLeaderboardPlayers)

    -- Auto-refresh leaderboard rows on theme change
    Shared.RegisterThemeCallback(function(targetTheme, isDarkMode)
        renderLeaderboardPlayers()
    end)

    -- Tab Key Toggle for Leaderboard
    UserInput.InputBegan:Connect(function(input, gpe)
        if input.KeyCode == Enum.KeyCode.Tab and not gpe then
            lbWindow.Visible = not lbWindow.Visible
        end
    end)


    -- ── CUSTOM WINDOWS AERO CHAT (UNIFIED TOPBAR: ROBLOX, ≡, 🎙, DEDUP) ─
    local GuiService = game:GetService("GuiService")
    local VirtualInput = game:GetService("VirtualInputManager")

    local chatWindow = Instance.new("Frame")
    chatWindow.Name = "Fih_CustomChat"
    chatWindow.Size = UDim2.new(0, 420, 0, 260)
    chatWindow.Position = UDim2.new(0, 8, 0, 4)
    chatWindow.BackgroundColor3 = C.BodyBg
    chatWindow.BackgroundTransparency = 0.45
    chatWindow.BorderSizePixel = 1
    chatWindow.BorderColor3 = C.WinBorder
    chatWindow.ClipsDescendants = false
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
        local lb = ScreenGui:FindFirstChild("Fih_CustomLeaderboard")
        if lb then
            lb.Visible = not lb.Visible
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

    -- 3. [🎙] Voice Chat Mute/Unmute Button (Direct VoiceChatInternal toggle + Toast Notification)
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

    -- 4. Mic Volume Threshold Visualizer Meter (Hardware Mic AudioDeviceInput + AudioAnalyzer)
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

    -- Real-time Hardware Microphone Capture Pipeline
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

    -- Live Hardware Microphone Audio Level Renderer
    RunService.RenderStepped:Connect(function()
        local rawLevel = 0
        if hwMicAnalyzer and not isMicMuted then
            pcall(function()
                local rms  = hwMicAnalyzer.RmsLevel or 0
                local peak = hwMicAnalyzer.PeakLevel or 0
                rawLevel = math.max(rms * 12.0, peak * 6.0)
            end)
        end

        local level = isMicMuted and 0 or math.clamp(rawLevel, 0, 1)
        local fallbackT = os.clock() * 8

        for i, mb in ipairs(micBars) do
            if mb and mb.Parent then
                if isMicMuted then
                    mb.Size = UDim2.new(0, 4, 0, 3)
                    mb.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
                else
                    local threshold = (i / 4.0)
                    local barLevel
                    if rawLevel > 0.005 then
                        -- True hardware mic volume
                        barLevel = math.clamp((level - (threshold - 0.25)) / 0.25, 0.15, 1)
                    else
                        -- Fallback active breathing pulse when mic is open but quiet
                        barLevel = 0.2 + 0.1 * math.sin(fallbackT + i * 0.8)
                    end
                    local barH = math.clamp(math.floor(barLevel * 15) + 1, 3, 16)
                    mb.Size = UDim2.new(0, 4, 0, barH)
                    mb.BackgroundColor3 = (i == 4) and Color3.fromRGB(255, 80, 80)
                        or ((i >= 3) and Color3.fromRGB(255, 205, 40)
                        or Color3.fromRGB(0, 230, 140))
                end
            end
        end
    end)

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

    -- Right Control Buttons: [-] Minimize, [□] Maximize/Fullscreen
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

    -- Minimize strictly collapses chat down to topbar only
    chatMinBtn.MouseButton1Click:Connect(function()
        isChatCollapsed = not isChatCollapsed
        if isChatCollapsed then
            savedChatHeight = chatWindow.AbsoluteSize.Y
            savedChatWidth  = chatWindow.AbsoluteSize.X
            chatWindow.Size = UDim2.new(0, savedChatWidth, 0, 26)
        else
            chatWindow.Size = UDim2.new(0, savedChatWidth, 0, savedChatHeight)
        end
    end)

    -- [□] Maximize / Fullscreen toggle
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
            chatWindow.Position = UDim2.new(
                chatPosStart.X.Scale, chatPosStart.X.Offset + dx,
                chatPosStart.Y.Scale, chatPosStart.Y.Offset + dy
            )
        end
    end)

    -- Deterministic Unique Player Color Generator
    local function getUniquePlayerHex(name)
        if not name or #name == 0 then return "00ccff" end
        local hash = 0
        for i = 1, #name do
            hash = (hash * 37 + string.byte(name, i)) % 360
        end
        local col = Color3.fromHSV(hash / 360, 0.78, 0.98)
        return col:ToHex()
    end

    -- Message Scroll Area with Message Deduplication Filter
    local chatScroll = Instance.new("ScrollingFrame")
    chatScroll.Size = UDim2.new(1, -2, 1, -64)
    chatScroll.Position = UDim2.new(0, 1, 0, 27)
    chatScroll.BackgroundTransparency = 1
    chatScroll.BorderSizePixel = 0
    chatScroll.ScrollBarThickness = 5
    chatScroll.ScrollBarImageColor3 = C.WinBorder
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
            return -- Suppress duplicate message!
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

    -- Bottom 3-Column Input Bar: [Quick] | [Text Box] | [Send]
    local inputBar = Instance.new("Frame")
    inputBar.Size = UDim2.new(1, 0, 0, 34)
    inputBar.Position = UDim2.new(0, 0, 1, -34)
    inputBar.BackgroundColor3 = C.RowBg
    inputBar.BackgroundTransparency = 0.20
    inputBar.BorderSizePixel = 1
    inputBar.BorderColor3 = C.WinBorder
    inputBar.ZIndex = 41
    inputBar.Parent = chatWindow
    registerThemed(inputBar, { BackgroundColor3 = "RowBg", BorderColor3 = "WinBorder" })

    -- 1. Quick Button
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

    -- 2. Text Box
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

    -- 3. Send Button
    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0, 62, 1, 0)
    sendBtn.Position = UDim2.new(1, -62, 0, 0)
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

    -- Message Sender Engine
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

    -- Quick Chat Dropdown
    local quickMenu = Instance.new("Frame")
    quickMenu.Size = UDim2.new(0, 110, 0, 115)
    quickMenu.Position = UDim2.new(0, 0, 0, -118)
    quickMenu.BackgroundColor3 = C.BodyBg
    quickMenu.BackgroundTransparency = 0.2
    quickMenu.BorderSizePixel = 1
    quickMenu.BorderColor3 = C.WinBorder
    quickMenu.Visible = false
    quickMenu.ZIndex = 45
    quickMenu.Parent = inputBar
    registerThemed(quickMenu, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder" })

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
        qBtn.Parent = quickMenu
        registerThemed(qBtn, { BackgroundColor3 = "RowBg", BorderColor3 = "RowBorder", TextColor3 = "BtnText" })

        qBtn.MouseButton1Click:Connect(function()
            dispatchMessage(phrase)
            quickMenu.Visible = false
        end)
    end

    quickBtn.MouseButton1Click:Connect(function()
        quickMenu.Visible = not quickMenu.Visible
    end)

    -- Stream Incoming Messages (Deduplicated Single Event Stream)
    local TextChatService = game:GetService("TextChatService")
    local isModernTextChat = (TextChatService.ChatVersion == Enum.ChatVersion.TextChatService)

    if isModernTextChat then
        TextChatService.MessageReceived:Connect(function(msg)
            local sender = (msg.TextSource and msg.TextSource.Name) or "System"
            addChatMessage(sender, msg.Text, getUniquePlayerHex(sender))
        end)
    else
        for _, p in ipairs(Players:GetPlayers()) do
            p.Chatted:Connect(function(msg)
                addChatMessage(p.DisplayName or p.Name, msg, getUniquePlayerHex(p.Name))
            end)
        end
        Players.PlayerAdded:Connect(function(p)
            p.Chatted:Connect(function(msg)
                addChatMessage(p.DisplayName or p.Name, msg, getUniquePlayerHex(p.Name))
            end)
        end)
    end

    -- Slash key '/' focus listener
    UserInput.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Slash and customCoreEnabled then
            task.defer(function()
                if isChatCollapsed then
                    isChatCollapsed = false
                    chatWindow.Size = UDim2.new(0, savedChatWidth, 0, savedChatHeight)
                end
                chatWindow.Visible = true
                chatBox:CaptureFocus()
                chatBox.Text = ""
            end)
        end
    end)

    -- Bottom-Right Corner Resize Grip (◢)
    local chatResizeGrip = Instance.new("TextLabel")
    chatResizeGrip.Size = UDim2.new(0, 14, 0, 14)
    chatResizeGrip.Position = UDim2.new(1, -14, 1, -14)
    chatResizeGrip.BackgroundTransparency = 1
    chatResizeGrip.Text = "◢"
    chatResizeGrip.TextColor3 = C.WinBorder
    chatResizeGrip.Font = Enum.Font.Code
    chatResizeGrip.TextSize = 11
    chatResizeGrip.ZIndex = 43
    chatResizeGrip.Parent = chatWindow
    registerThemed(chatResizeGrip, { TextColor3 = "WinBorder" })

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

        switchTab("Main")
    print("[UI_Handler] Loaded -- Dark Mode Engine, Smooth Transitions, Hover Effects Active")
end
