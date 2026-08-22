-- UI_Handler.lua
-- Internet Explorer 7 / Windows XP Modular UI
-- Quad 2-Column Side-to-Side Grid layout, Keybinds system, Stacking & Dropping popup notification system, Strict Cube geometry

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

    local TweenService = Shared.Services.TweenService
    local UserInput    = Shared.Services.UserInput
    local CoreGui      = Shared.Services.CoreGui

    if CoreGui:FindFirstChild("IE7_Menu") then
        CoreGui:FindFirstChild("IE7_Menu"):Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "IE7_Menu"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent         = CoreGui

    local C = {
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
        Accent        = Color3.fromRGB(0, 100, 220),
        AccentActive  = Color3.fromRGB(0, 150, 60),
        DrawerBg      = Color3.fromRGB(244, 246, 250),
        NotifyBg      = Color3.fromRGB(250, 250, 255),
        NotifyBorder  = Color3.fromRGB(58, 110, 165),
    }

    -- ============================================================
    -- NOTIFICATION STACK SYSTEM (Drops down when previous expires)
    -- ============================================================
    local NotifyHolder = Instance.new("Frame")
    NotifyHolder.Name             = "NotifyHolder"
    NotifyHolder.Size             = UDim2.new(0, 240, 1, -20)
    NotifyHolder.Position         = UDim2.new(1, -250, 0, 10)
    NotifyHolder.BackgroundTransparency = 1
    NotifyHolder.ZIndex           = 100
    NotifyHolder.Parent           = ScreenGui

    local NotifyLayout = Instance.new("UIListLayout")
    NotifyLayout.SortOrder            = Enum.SortOrder.LayoutOrder
    NotifyLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Right
    NotifyLayout.VerticalAlignment    = Enum.VerticalAlignment.Bottom
    NotifyLayout.Padding              = UDim.new(0, 6)
    NotifyLayout.Parent               = NotifyHolder

    local notifyCounter = 0
    local function sendNotification(title, message, isEnabled)
        notifyCounter = notifyCounter + 1
        local order = notifyCounter

        local toast = Instance.new("Frame")
        toast.Name             = "Toast_" .. tostring(order)
        toast.Size             = UDim2.new(1, 0, 0, 46)
        toast.BackgroundColor3 = C.NotifyBg
        toast.BorderSizePixel  = 2
        toast.BorderColor3     = isEnabled == true and Color3.fromRGB(0, 160, 60) or (isEnabled == false and Color3.fromRGB(200, 40, 40) or C.NotifyBorder)
        toast.LayoutOrder      = order
        toast.ZIndex           = 101
        toast.BackgroundTransparency = 1
        toast.Parent           = NotifyHolder

        -- Header tag
        local headerBar = Instance.new("Frame")
        headerBar.Size             = UDim2.new(1, 0, 0, 18)
        headerBar.BackgroundColor3 = isEnabled == true and Color3.fromRGB(225, 255, 230) or (isEnabled == false and Color3.fromRGB(255, 230, 230) or C.SectionBg)
        headerBar.BorderSizePixel  = 0
        headerBar.ZIndex           = 102
        headerBar.Parent           = toast

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size                  = UDim2.new(1, -8, 1, 0)
        titleLbl.Position              = UDim2.new(0, 6, 0, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text                  = (isEnabled == true and "[✔] " or (isEnabled == false and "[✖] " or "[i] ")) .. title
        titleLbl.TextColor3            = isEnabled == true and Color3.fromRGB(0, 120, 40) or (isEnabled == false and Color3.fromRGB(180, 20, 20) or C.SectionText)
        titleLbl.Font                  = Enum.Font.Code
        titleLbl.TextSize              = 11
        titleLbl.TextXAlignment        = Enum.TextXAlignment.Left
        titleLbl.ZIndex                = 103
        titleLbl.Parent                = headerBar

        local descLbl = Instance.new("TextLabel")
        descLbl.Size                  = UDim2.new(1, -12, 0, 24)
        descLbl.Position              = UDim2.new(0, 6, 0, 20)
        descLbl.BackgroundTransparency = 1
        descLbl.Text                  = message
        descLbl.TextColor3            = Color3.fromRGB(30, 30, 50)
        descLbl.Font                  = Enum.Font.Code
        descLbl.TextSize              = 11
        descLbl.TextXAlignment        = Enum.TextXAlignment.Left
        descLbl.ZIndex                = 102
        descLbl.Parent                = toast

        -- Fade in & slide
        TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 0 }):Play()

        -- Auto expire & drop stack
        task.delay(2.8, function()
            if toast and toast.Parent then
                local fade = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1
                })
                fade:Play()
                fade.Completed:Connect(function()
                    toast:Destroy()
                end)
            end
        end)
    end
    Shared.Notify = sendNotification

    -- ============================================================
    -- MAIN WINDOW (Cube geometry)
    -- ============================================================
    local WIN_W, WIN_H = 680, 400
    local Window = Instance.new("Frame")
    Window.Name             = "Window"
    Window.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
    Window.Position         = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)
    Window.BackgroundColor3 = C.BodyBg
    Window.BorderSizePixel  = 2
    Window.BorderColor3     = C.WinBorder
    Window.ClipsDescendants = false
    Window.Parent           = ScreenGui

    -- TITLE BAR
    local TITLE_H = 26
    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"
    TitleBar.Size             = UDim2.new(1, 0, 0, TITLE_H)
    TitleBar.Position         = UDim2.new(0, 0, 0, 0)
    TitleBar.BackgroundColor3 = C.TitleBar
    TitleBar.BorderSizePixel  = 1
    TitleBar.BorderColor3     = Color3.fromRGB(140, 140, 140)
    TitleBar.Parent           = Window

    local TitleText = Instance.new("TextLabel")
    TitleText.Size                  = UDim2.new(0, 145, 1, 0)
    TitleText.Position              = UDim2.new(0, 8, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text                  = "Internet Explorer 7"
    TitleText.TextColor3            = C.TitleText
    TitleText.Font                  = Enum.Font.Code
    TitleText.TextSize              = 12
    TitleText.TextXAlignment        = Enum.TextXAlignment.Left
    TitleText.Parent                = TitleBar

    local RainbowBar = Instance.new("Frame")
    RainbowBar.Name             = "RainbowBar"
    RainbowBar.Size             = UDim2.new(1, -260, 0, TITLE_H - 6)
    RainbowBar.Position         = UDim2.new(0, 155, 0, 3)
    RainbowBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    RainbowBar.BorderSizePixel  = 1
    RainbowBar.BorderColor3     = Color3.fromRGB(160, 160, 160)
    RainbowBar.Parent           = TitleBar

    local RainbowGrad = Instance.new("UIGradient")
    RainbowGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(34, 177, 76)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(0, 162, 232)),
        ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(63, 72, 204)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(163, 73, 164)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(237, 28, 36)),
    })
    RainbowGrad.Rotation = 0
    RainbowGrad.Parent   = RainbowBar

    local btnDefs = {
        { id = "min",   label = "[-]", x = -90 },
        { id = "max",   label = "[ ]", x = -60 },
        { id = "close", label = "[X]", x = -30 },
    }
    local winBtns = {}
    for _, def in ipairs(btnDefs) do
        local b = Instance.new("TextButton")
        b.Name             = "WinBtn_" .. def.id
        b.Size             = UDim2.new(0, 26, 0, TITLE_H - 4)
        b.Position         = UDim2.new(1, def.x, 0, 2)
        b.BackgroundColor3 = C.BtnBg
        b.Text             = def.label
        b.TextColor3       = C.BtnText
        b.Font             = Enum.Font.Code
        b.TextSize         = 11
        b.BorderSizePixel  = 1
        b.BorderColor3     = C.BtnBorder
        b.Parent           = TitleBar

        b.MouseEnter:Connect(function()
            b.BackgroundColor3 = def.id == "close" and Color3.fromRGB(232, 17, 35) or C.BtnHover
            if def.id == "close" then b.TextColor3 = Color3.fromRGB(255, 255, 255) end
        end)
        b.MouseLeave:Connect(function()
            b.BackgroundColor3 = C.BtnBg
            b.TextColor3       = C.BtnText
        end)
        winBtns[def.id] = b
    end

    -- DRAGGING
    do
        local drag, ds, sp = false, nil, nil
        TitleBar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                drag = true; ds = i.Position; sp = Window.Position
            end
        end)
        TitleBar.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
        end)
        UserInput.InputChanged:Connect(function(i)
            if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
                local d = i.Position - ds
                Window.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
            end
        end)
    end

    -- OPEN / CLOSE ANIMATIONS
    local isOpen = true
    local function animClose()
        Window:TweenSize(UDim2.new(0, WIN_W, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.2, true, function()
            Window.Visible = false
        end)
        isOpen = false
    end
    local function animOpen()
        Window.Visible = true
        Window:TweenSize(UDim2.new(0, WIN_W, 0, WIN_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25, true)
        isOpen = true
    end

    local minimized = false
    winBtns["close"].MouseButton1Click:Connect(animClose)
    winBtns["min"].MouseButton1Click:Connect(function()
        minimized = not minimized
        local target = minimized and UDim2.new(0, WIN_W, 0, TITLE_H) or UDim2.new(0, WIN_W, 0, WIN_H)
        Window:TweenSize(target, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
    end)
    winBtns["max"].MouseButton1Click:Connect(function()
        if isOpen then animClose() else animOpen() end
    end)

    UserInput.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == Enum.KeyCode.RightShift then
            if isOpen then animClose() else animOpen() end
        end
    end)

    -- NAV STRIP
    local NAV_H = 26
    local NavBar = Instance.new("Frame")
    NavBar.Name             = "NavBar"
    NavBar.Size             = UDim2.new(1, 0, 0, NAV_H)
    NavBar.Position         = UDim2.new(0, 0, 0, TITLE_H)
    NavBar.BackgroundColor3 = C.NavBar
    NavBar.BorderSizePixel  = 1
    NavBar.BorderColor3     = Color3.fromRGB(140, 160, 200)
    NavBar.Parent           = Window

    local NavTabLabel = Instance.new("TextLabel")
    NavTabLabel.Name                  = "NavTabLabel"
    NavTabLabel.Size                  = UDim2.new(0.4, 0, 1, 0)
    NavTabLabel.Position              = UDim2.new(0, 10, 0, 0)
    NavTabLabel.BackgroundTransparency = 1
    NavTabLabel.Text                  = "Main"
    NavTabLabel.TextColor3            = C.NavText
    NavTabLabel.Font                  = Enum.Font.Code
    NavTabLabel.TextSize              = 12
    NavTabLabel.TextXAlignment        = Enum.TextXAlignment.Left
    NavTabLabel.Parent                = NavBar

    local NavLinksContainer = Instance.new("Frame")
    NavLinksContainer.Name             = "NavLinksContainer"
    NavLinksContainer.Size             = UDim2.new(0, 180, 1, 0)
    NavLinksContainer.Position         = UDim2.new(1, -190, 0, 0)
    NavLinksContainer.BackgroundTransparency = 1
    NavLinksContainer.Parent           = NavBar

    local NavLinksLayout = Instance.new("UIListLayout")
    NavLinksLayout.FillDirection        = Enum.FillDirection.Horizontal
    NavLinksLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Right
    NavLinksLayout.VerticalAlignment    = Enum.VerticalAlignment.Center
    NavLinksLayout.Padding              = UDim.new(0, 4)
    NavLinksLayout.Parent               = NavLinksContainer

    local function makeHyperlink(text, callback)
        local btn = Instance.new("TextButton")
        btn.Size                  = UDim2.new(0, 65, 0, 18)
        btn.BackgroundTransparency = 1
        btn.Text                  = text
        btn.TextColor3            = C.NavLink
        btn.Font                  = Enum.Font.Code
        btn.TextSize              = 11
        btn.BorderSizePixel       = 0
        btn.Parent                = NavLinksContainer

        btn.MouseEnter:Connect(function() btn.TextColor3 = C.NavLinkHover end)
        btn.MouseLeave:Connect(function() btn.TextColor3 = C.NavLink end)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    makeHyperlink("settings", function()
        Shared.ToggleDrawer("settings")
    end)

    local divider = Instance.new("TextLabel")
    divider.Size                  = UDim2.new(0, 6, 0, 18)
    divider.BackgroundTransparency = 1
    divider.Text                  = "|"
    divider.TextColor3            = Color3.fromRGB(100, 120, 160)
    divider.Font                  = Enum.Font.Code
    divider.TextSize              = 11
    divider.Parent                = NavLinksContainer

    makeHyperlink("configs", function()
        Shared.ToggleDrawer("configs")
    end)

    -- BODY
    local BODY_Y    = TITLE_H + NAV_H
    local BODY_H    = WIN_H - BODY_Y
    local SIDEBAR_W = 88

    local Body = Instance.new("Frame")
    Body.Name             = "Body"
    Body.Size             = UDim2.new(1, 0, 0, BODY_H)
    Body.Position         = UDim2.new(0, 0, 0, BODY_Y)
    Body.BackgroundColor3 = C.BodyBg
    Body.BorderSizePixel  = 0
    Body.ClipsDescendants = true
    Body.Parent           = Window

    -- SIDEBAR (Centered tabs)
    local Sidebar = Instance.new("Frame")
    Sidebar.Name             = "Sidebar"
    Sidebar.Size             = UDim2.new(0, SIDEBAR_W, 1, 0)
    Sidebar.Position         = UDim2.new(0, 0, 0, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Sidebar.BorderSizePixel  = 0
    Sidebar.ClipsDescendants = true
    Sidebar.Parent           = Body

    local CELL = 9
    for r = 0, math.ceil(BODY_H / CELL) + 1 do
        for c = 0, math.ceil(SIDEBAR_W / CELL) + 1 do
            local cell = Instance.new("Frame")
            cell.Size             = UDim2.new(0, CELL, 0, CELL)
            cell.Position         = UDim2.new(0, c * CELL, 0, r * CELL)
            cell.BorderSizePixel  = 0
            cell.BackgroundColor3 = ((r + c) % 2 == 0) and C.SidebarCellA or C.SidebarCellB
            cell.Parent           = Sidebar
        end
    end

    local SidebarBorder = Instance.new("Frame")
    SidebarBorder.Size             = UDim2.new(0, 2, 1, 0)
    SidebarBorder.Position         = UDim2.new(1, -2, 0, 0)
    SidebarBorder.BackgroundColor3 = C.SidebarBorder
    SidebarBorder.BorderSizePixel  = 0
    SidebarBorder.ZIndex           = 5
    SidebarBorder.Parent           = Sidebar

    local TabContainer = Instance.new("Frame")
    TabContainer.Name                 = "TabContainer"
    TabContainer.Size                 = UDim2.new(1, -4, 1, 0)
    TabContainer.Position             = UDim2.new(0, 0, 0, 0)
    TabContainer.BackgroundTransparency = 1
    TabContainer.ZIndex               = 6
    TabContainer.Parent               = Sidebar

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.SortOrder             = Enum.SortOrder.LayoutOrder
    TabLayout.HorizontalAlignment   = Enum.HorizontalAlignment.Center
    TabLayout.VerticalAlignment     = Enum.VerticalAlignment.Top
    TabLayout.Padding               = UDim.new(0, 4)
    TabLayout.Parent                = TabContainer

    local TabPad = Instance.new("UIPadding")
    TabPad.PaddingTop = UDim.new(0, 8)
    TabPad.Parent     = TabContainer

    -- CONTENT AREA (Holds quad column views)
    local ContentArea = Instance.new("ScrollingFrame")
    ContentArea.Name                 = "ContentArea"
    ContentArea.Size                 = UDim2.new(1, -SIDEBAR_W, 1, 0)
    ContentArea.Position             = UDim2.new(0, SIDEBAR_W, 0, 0)
    ContentArea.BackgroundColor3     = C.BodyBg
    ContentArea.BorderSizePixel      = 0
    ContentArea.ScrollBarThickness   = 8
    ContentArea.ScrollBarImageColor3 = Color3.fromRGB(140, 160, 200)
    ContentArea.CanvasSize           = UDim2.new(0, 0, 0, 0)
    ContentArea.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    ContentArea.Parent               = Body

    local ContentPad = Instance.new("UIPadding")
    ContentPad.PaddingTop    = UDim.new(0, 8)
    ContentPad.PaddingLeft   = UDim.new(0, 10)
    ContentPad.PaddingRight  = UDim.new(0, 10)
    ContentPad.PaddingBottom = UDim.new(0, 10)
    ContentPad.Parent        = ContentArea

    -- DROPDOWN DRAWER (Settings & Configs from top to bottom)
    local Drawer = Instance.new("Frame")
    Drawer.Name             = "Drawer"
    Drawer.Size             = UDim2.new(1, -SIDEBAR_W, 1, 0)
    Drawer.Position         = UDim2.new(0, SIDEBAR_W, 0, -BODY_H)
    Drawer.BackgroundColor3 = C.DrawerBg
    Drawer.BorderSizePixel  = 1
    Drawer.BorderColor3     = C.SidebarBorder
    Drawer.ZIndex           = 20
    Drawer.Visible          = false
    Drawer.Parent           = Body

    local DrawerHeader = Instance.new("Frame")
    DrawerHeader.Name             = "DrawerHeader"
    DrawerHeader.Size             = UDim2.new(1, 0, 0, 24)
    DrawerHeader.BackgroundColor3 = C.SectionBg
    DrawerHeader.BorderSizePixel  = 1
    DrawerHeader.BorderColor3     = C.SidebarBorder
    DrawerHeader.ZIndex           = 21
    DrawerHeader.Parent           = Drawer

    local DrawerTitle = Instance.new("TextLabel")
    DrawerTitle.Name                  = "DrawerTitle"
    DrawerTitle.Size                  = UDim2.new(1, -85, 1, 0)
    DrawerTitle.Position              = UDim2.new(0, 8, 0, 0)
    DrawerTitle.BackgroundTransparency = 1
    DrawerTitle.Text                  = "Settings & Configuration"
    DrawerTitle.TextColor3            = C.SectionText
    DrawerTitle.Font                  = Enum.Font.Code
    DrawerTitle.TextSize              = 11
    DrawerTitle.TextXAlignment        = Enum.TextXAlignment.Left
    DrawerTitle.ZIndex                = 22
    DrawerTitle.Parent                = DrawerHeader

    local DrawerCloseBtn = Instance.new("TextButton")
    DrawerCloseBtn.Name             = "DrawerCloseBtn"
    DrawerCloseBtn.Size             = UDim2.new(0, 76, 0, 18)
    DrawerCloseBtn.Position         = UDim2.new(1, -80, 0, 3)
    DrawerCloseBtn.BackgroundColor3 = C.BtnBg
    DrawerCloseBtn.Text             = "[ ▲ Close ]"
    DrawerCloseBtn.TextColor3       = C.BtnText
    DrawerCloseBtn.Font             = Enum.Font.Code
    DrawerCloseBtn.TextSize         = 10
    DrawerCloseBtn.BorderSizePixel  = 1
    DrawerCloseBtn.BorderColor3     = C.BtnBorder
    DrawerCloseBtn.ZIndex           = 22
    DrawerCloseBtn.Parent           = DrawerHeader

    local DrawerScroll = Instance.new("ScrollingFrame")
    DrawerScroll.Name                 = "DrawerScroll"
    DrawerScroll.Size                 = UDim2.new(1, 0, 1, -24)
    DrawerScroll.Position             = UDim2.new(0, 0, 0, 24)
    DrawerScroll.BackgroundColor3     = C.DrawerBg
    DrawerScroll.BorderSizePixel      = 0
    DrawerScroll.ScrollBarThickness   = 8
    DrawerScroll.ScrollBarImageColor3 = Color3.fromRGB(140, 160, 200)
    DrawerScroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
    DrawerScroll.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    DrawerScroll.ZIndex               = 21
    DrawerScroll.Parent               = Drawer

    local DrawerLayout = Instance.new("UIListLayout")
    DrawerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    DrawerLayout.Padding   = UDim.new(0, 6)
    DrawerLayout.Parent    = DrawerScroll

    local DrawerPad = Instance.new("UIPadding")
    DrawerPad.PaddingTop    = UDim.new(0, 8)
    DrawerPad.PaddingLeft   = UDim.new(0, 10)
    DrawerPad.PaddingRight  = UDim.new(0, 10)
    DrawerPad.PaddingBottom = UDim.new(0, 12)
    DrawerPad.Parent        = DrawerScroll

    local drawerOpen = false
    local function toggleDrawer(mode)
        drawerOpen = not drawerOpen
        if drawerOpen then
            Drawer.Visible = true
            DrawerTitle.Text = mode == "configs" and "Configuration Manager" or "Settings & Audio Controls"
            Drawer:TweenPosition(
                UDim2.new(0, SIDEBAR_W, 0, 0),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.25,
                true
            )
        else
            Drawer:TweenPosition(
                UDim2.new(0, SIDEBAR_W, 0, -BODY_H),
                Enum.EasingDirection.In,
                Enum.EasingStyle.Quad,
                0.2,
                true,
                function()
                    Drawer.Visible = false
                end
            )
        end
    end

    DrawerCloseBtn.MouseButton1Click:Connect(function()
        toggleDrawer()
    end)
    Shared.ToggleDrawer  = toggleDrawer
    Shared.DrawerContent = DrawerScroll

    -- ============================================================
    -- TABS CREATION (Including Keybinds Tab)
    -- ============================================================
    local Tabs      = {}
    local TabBtns   = {}
    local QuadCols  = {} -- [tabName] = { Left = frame, Right = frame }
    local activeTab = nil

    local tabDefs = {
        { name = "Main",     order = 1 },
        { name = "MM2",      order = 2 },
        { name = "Spotify",  order = 3 },
        { name = "Keybinds", order = 4 },
    }

    local function switchTab(name)
        for tName, tFrame in pairs(Tabs) do
            tFrame.Visible = (tName == name)
        end
        for tName, tBtn in pairs(TabBtns) do
            if tName == name then
                tBtn.BackgroundColor3 = C.TabActiveBg
                tBtn.TextColor3       = C.TabActiveText
                tBtn.BorderColor3     = C.WinBorder
            else
                tBtn.BackgroundColor3 = C.BtnBg
                tBtn.TextColor3       = C.BtnText
                tBtn.BorderColor3     = C.BtnBorder
            end
        end
        activeTab = name
        NavTabLabel.Text = name
    end

    for _, def in ipairs(tabDefs) do
        local btn = Instance.new("TextButton")
        btn.Name             = "TabBtn_" .. def.name
        btn.Size             = UDim2.new(0, 76, 0, 24)
        btn.BackgroundColor3 = C.BtnBg
        btn.Text             = def.name
        btn.TextColor3       = C.BtnText
        btn.Font             = Enum.Font.Code
        btn.TextSize         = 11
        btn.BorderSizePixel  = 1
        btn.BorderColor3     = C.BtnBorder
        btn.LayoutOrder      = def.order
        btn.ZIndex           = 7
        btn.Parent           = TabContainer

        btn.MouseEnter:Connect(function()
            if activeTab ~= def.name then btn.BackgroundColor3 = C.BtnHover end
        end)
        btn.MouseLeave:Connect(function()
            if activeTab ~= def.name then btn.BackgroundColor3 = C.BtnBg end
        end)

        -- Tab Base Container (Vertical stack of banners / quad columns)
        local tabFrame = Instance.new("Frame")
        tabFrame.Name                 = "Tab_" .. def.name
        tabFrame.Size                 = UDim2.new(1, 0, 0, 0)
        tabFrame.AutomaticSize        = Enum.AutomaticSize.Y
        tabFrame.BackgroundTransparency = 1
        tabFrame.Visible              = false
        tabFrame.LayoutOrder          = def.order
        tabFrame.Parent               = ContentArea

        local tabMainLayout = Instance.new("UIListLayout")
        tabMainLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabMainLayout.Padding   = UDim.new(0, 8)
        tabMainLayout.Parent    = tabFrame

        -- Quad 2-Column Container (Side to side, then below)
        local quadFrame = Instance.new("Frame")
        quadFrame.Name                 = "QuadGrid"
        quadFrame.Size                 = UDim2.new(1, 0, 0, 0)
        quadFrame.AutomaticSize        = Enum.AutomaticSize.Y
        quadFrame.BackgroundTransparency = 1
        quadFrame.LayoutOrder          = 2
        quadFrame.Parent               = tabFrame

        local leftCol = Instance.new("Frame")
        leftCol.Name                 = "LeftCol"
        leftCol.Size                 = UDim2.new(0.5, -4, 0, 0)
        leftCol.Position             = UDim2.new(0, 0, 0, 0)
        leftCol.AutomaticSize        = Enum.AutomaticSize.Y
        leftCol.BackgroundTransparency = 1
        leftCol.Parent               = quadFrame

        local leftLayout = Instance.new("UIListLayout")
        leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
        leftLayout.Padding   = UDim.new(0, 6)
        leftLayout.Parent    = leftCol

        local rightCol = Instance.new("Frame")
        rightCol.Name                 = "RightCol"
        rightCol.Size                 = UDim2.new(0.5, -4, 0, 0)
        rightCol.Position             = UDim2.new(0.5, 4, 0, 0)
        rightCol.AutomaticSize        = Enum.AutomaticSize.Y
        rightCol.BackgroundTransparency = 1
        rightCol.Parent               = quadFrame

        local rightLayout = Instance.new("UIListLayout")
        rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rightLayout.Padding   = UDim.new(0, 6)
        rightLayout.Parent    = rightCol

        Tabs[def.name]     = tabFrame
        TabBtns[def.name]  = btn
        QuadCols[def.name] = { Left = leftCol, Right = rightCol }

        btn.MouseButton1Click:Connect(function()
            switchTab(def.name)
        end)
    end

    -- MAIN TAB: Fih Ui Banner (ArimoBold)
    local mainTab = Tabs["Main"]
    local logoBox = Instance.new("Frame")
    logoBox.Name             = "LogoBox"
    logoBox.Size             = UDim2.new(1, 0, 0, 95)
    logoBox.BackgroundColor3 = Color3.fromRGB(248, 250, 255)
    logoBox.BorderSizePixel  = 1
    logoBox.BorderColor3     = C.WinBorder
    logoBox.LayoutOrder      = 1
    logoBox.Parent           = mainTab

    local logoText = Instance.new("TextLabel")
    logoText.Name                  = "LogoText"
    logoText.Size                  = UDim2.new(1, 0, 0, 56)
    logoText.Position              = UDim2.new(0, 0, 0, 6)
    logoText.BackgroundTransparency = 1
    logoText.Text                  = "Fih Ui"
    logoText.TextColor3            = Color3.fromRGB(15, 30, 80)
    logoText.Font                  = Enum.Font.ArimoBold
    logoText.TextSize              = 48
    logoText.TextXAlignment        = Enum.TextXAlignment.Center
    logoText.Parent                = logoBox

    local logoSub = Instance.new("TextLabel")
    logoSub.Name                  = "LogoSub"
    logoSub.Size                  = UDim2.new(1, 0, 0, 20)
    logoSub.Position              = UDim2.new(0, 0, 0, 66)
    logoSub.BackgroundTransparency = 1
    logoSub.Text                  = "Quad Layout Framework  |  RightShift: Toggle Menu"
    logoSub.TextColor3            = Color3.fromRGB(90, 110, 150)
    logoSub.Font                  = Enum.Font.Code
    logoSub.TextSize              = 11
    logoSub.TextXAlignment        = Enum.TextXAlignment.Center
    logoSub.Parent                = logoBox

    -- ============================================================
    -- FACTORY BUILDERS (QUAD FORM FACTOR & NOTIFICATIONS)
    -- ============================================================

    local function makeSection(parent, labelText, order)
        local lbl = Instance.new("TextLabel")
        lbl.Name                  = "Sec_" .. labelText
        lbl.Size                  = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundColor3      = C.SectionBg
        lbl.TextColor3            = C.SectionText
        lbl.Font                  = Enum.Font.Code
        lbl.TextSize              = 11
        lbl.Text                  = "  [" .. labelText .. "]"
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.BorderSizePixel       = 1
        lbl.BorderColor3          = C.SidebarBorder
        lbl.LayoutOrder           = order or 0
        lbl.Parent                = parent
        return lbl
    end

    local function makeToggle(parent, labelText, flagKey, order, callback)
        local row = Instance.new("Frame")
        row.Name             = "Toggle_" .. flagKey
        row.Size             = UDim2.new(1, 0, 0, 26)
        row.BackgroundColor3 = C.RowBg
        row.BorderSizePixel  = 1
        row.BorderColor3     = C.RowBorder
        row.LayoutOrder      = order or 0
        row.Parent           = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, -44, 1, 0)
        lbl.Position              = UDim2.new(0, 6, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = labelText
        lbl.TextColor3            = C.BtnText
        lbl.Font                  = Enum.Font.Code
        lbl.TextSize              = 11
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.TextTruncate          = Enum.TextTruncate.AtEnd
        lbl.Parent                = row

        local box = Instance.new("TextButton")
        box.Name             = "CheckBox"
        box.Size             = UDim2.new(0, 18, 0, 18)
        box.Position         = UDim2.new(1, -24, 0.5, -9)
        box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        box.BorderSizePixel  = 1
        box.BorderColor3     = Color3.fromRGB(100, 100, 100)
        box.Text             = ""
        box.TextColor3       = Color3.fromRGB(0, 80, 200)
        box.Font             = Enum.Font.Code
        box.TextSize         = 12
        box.Parent           = row

        Shared.Flags[flagKey] = false

        local function setToggle(state, suppressNotify)
            Shared.Flags[flagKey] = state
            box.Text = state and "X" or ""
            box.BackgroundColor3 = state and Color3.fromRGB(220, 235, 255) or Color3.fromRGB(255, 255, 255)
            if callback then callback(state) end
            if not suppressNotify then
                sendNotification(labelText, state and "ENABLED" or "DISABLED", state)
            end
        end

        local clickOverlay = Instance.new("TextButton")
        clickOverlay.Size                  = UDim2.new(1, 0, 1, 0)
        clickOverlay.BackgroundTransparency = 1
        clickOverlay.Text                  = ""
        clickOverlay.Parent                = row
        clickOverlay.MouseButton1Click:Connect(function()
            setToggle(not Shared.Flags[flagKey])
        end)
        box.MouseButton1Click:Connect(function()
            setToggle(not Shared.Flags[flagKey])
        end)

        -- Register in toggle registry for keybind assignment
        Shared.Toggles[flagKey] = {
            Name      = labelText,
            SetToggle = setToggle,
            Key       = nil
        }

        return row, setToggle
    end

    local function makeSlider(parent, labelText, flagKey, minVal, maxVal, defaultVal, order, callback)
        local row = Instance.new("Frame")
        row.Name             = "Slider_" .. flagKey
        row.Size             = UDim2.new(1, 0, 0, 36)
        row.BackgroundColor3 = C.RowBg
        row.BorderSizePixel  = 1
        row.BorderColor3     = C.RowBorder
        row.LayoutOrder      = order or 0
        row.Parent           = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, -55, 0, 16)
        lbl.Position              = UDim2.new(0, 6, 0, 2)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = labelText
        lbl.TextColor3            = C.BtnText
        lbl.Font                  = Enum.Font.Code
        lbl.TextSize              = 11
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.TextTruncate          = Enum.TextTruncate.AtEnd
        lbl.Parent                = row

        local valLbl = Instance.new("TextLabel")
        valLbl.Size                  = UDim2.new(0, 48, 0, 16)
        valLbl.Position              = UDim2.new(1, -52, 0, 2)
        valLbl.BackgroundTransparency = 1
        valLbl.Text                  = tostring(defaultVal)
        valLbl.TextColor3            = Color3.fromRGB(0, 50, 180)
        valLbl.Font                  = Enum.Font.Code
        valLbl.TextSize              = 11
        valLbl.TextXAlignment        = Enum.TextXAlignment.Right
        valLbl.Parent                = row

        local track = Instance.new("Frame")
        track.Name             = "Track"
        track.Size             = UDim2.new(1, -12, 0, 8)
        track.Position         = UDim2.new(0, 6, 0, 22)
        track.BackgroundColor3 = Color3.fromRGB(215, 218, 225)
        track.BorderSizePixel  = 1
        track.BorderColor3     = Color3.fromRGB(150, 160, 180)
        track.Parent           = row

        local fill = Instance.new("Frame")
        fill.Name             = "Fill"
        fill.Size             = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = C.Accent
        fill.BorderSizePixel  = 0
        fill.Parent           = track

        Shared.Flags[flagKey] = defaultVal
        local dragging = false

        local function update(x)
            local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor(minVal + pct * (maxVal - minVal))
            Shared.Flags[flagKey] = val
            fill.Size = UDim2.new(pct, 0, 1, 0)
            valLbl.Text = tostring(val)
            if callback then callback(val) end
        end

        track.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                update(i.Position.X)
            end
        end)
        UserInput.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UserInput.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then update(i.Position.X) end
        end)

        return row
    end

    local function makeButton(parent, labelText, order, callback)
        local btn = Instance.new("TextButton")
        btn.Name             = "Btn_" .. labelText:gsub("%s+", "_")
        btn.Size             = UDim2.new(1, 0, 0, 26)
        btn.BackgroundColor3 = C.BtnBg
        btn.Text             = labelText
        btn.TextColor3       = C.BtnText
        btn.Font             = Enum.Font.Code
        btn.TextSize         = 11
        btn.BorderSizePixel  = 1
        btn.BorderColor3     = C.BtnBorder
        btn.LayoutOrder      = order or 0
        btn.Parent           = parent

        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = C.BtnHover end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = C.BtnBg end)
        btn.MouseButton1Down:Connect(function() btn.BackgroundColor3 = C.BtnDown end)
        btn.MouseButton1Up:Connect(function() btn.BackgroundColor3 = C.BtnHover end)

        if callback then
            btn.MouseButton1Click:Connect(callback)
        end
        return btn
    end

    -- ============================================================
    -- KEYBINDS TAB POPULATION & LISTENER
    -- ============================================================
    local keybindsTab = Tabs["Keybinds"]
    local keybindCols = QuadCols["Keybinds"]

    local function buildKeybindsUI()
        for _, c in ipairs(keybindCols.Left:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        for _, c in ipairs(keybindCols.Right:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end

        makeSection(keybindCols.Left, "Features (A-M)", 1)
        makeSection(keybindCols.Right, "Features (N-Z)", 1)

        local toggleList = {}
        for fKey, info in pairs(Shared.Toggles) do
            table.insert(toggleList, { Key = fKey, Info = info })
        end
        table.sort(toggleList, function(a, b) return a.Info.Name < b.Info.Name end)

        local listeningKeyFor = nil

        for idx, item in ipairs(toggleList) do
            local parentCol = (idx % 2 == 1) and keybindCols.Left or keybindCols.Right
            local fKey = item.Key
            local info = item.Info

            local row = Instance.new("Frame")
            row.Name             = "KeybindRow_" .. fKey
            row.Size             = UDim2.new(1, 0, 0, 26)
            row.BackgroundColor3 = C.RowBg
            row.BorderSizePixel  = 1
            row.BorderColor3     = C.RowBorder
            row.LayoutOrder      = idx + 1
            row.Parent           = parentCol

            local lbl = Instance.new("TextLabel")
            lbl.Size                  = UDim2.new(1, -70, 1, 0)
            lbl.Position              = UDim2.new(0, 6, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text                  = info.Name
            lbl.TextColor3            = C.BtnText
            lbl.Font                  = Enum.Font.Code
            lbl.TextSize              = 11
            lbl.TextXAlignment        = Enum.TextXAlignment.Left
            lbl.TextTruncate          = Enum.TextTruncate.AtEnd
            lbl.Parent                = row

            local bindBtn = Instance.new("TextButton")
            bindBtn.Name             = "BindBtn"
            bindBtn.Size             = UDim2.new(0, 60, 0, 20)
            bindBtn.Position         = UDim2.new(1, -64, 0.5, -10)
            bindBtn.BackgroundColor3 = C.BtnBg
            bindBtn.BorderSizePixel  = 1
            bindBtn.BorderColor3     = C.BtnBorder
            bindBtn.Text             = info.Key and ("[" .. info.Key.Name .. "]") or "[ None ]"
            bindBtn.TextColor3       = info.Key and Color3.fromRGB(0, 60, 180) or Color3.fromRGB(120, 120, 120)
            bindBtn.Font             = Enum.Font.Code
            bindBtn.TextSize         = 10
            bindBtn.Parent           = row

            bindBtn.MouseButton1Click:Connect(function()
                listeningKeyFor = fKey
                bindBtn.Text = "[ ... ]"
                bindBtn.TextColor3 = Color3.fromRGB(220, 80, 0)
            end)
        end

        -- Keybind Input Listener
        if Shared._KeybindConn then Shared._KeybindConn:Disconnect() end
        Shared._KeybindConn = UserInput.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if listeningKeyFor then
                    local target = listeningKeyFor
                    listeningKeyFor = nil
                    if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
                        Shared.Toggles[target].Key = nil
                        sendNotification(Shared.Toggles[target].Name, "Keybind Cleared", nil)
                    else
                        Shared.Toggles[target].Key = input.KeyCode
                        sendNotification(Shared.Toggles[target].Name, "Bound to [" .. input.KeyCode.Name .. "]", true)
                    end
                    buildKeybindsUI()
                else
                    -- Execute assigned keybind
                    for fKey, info in pairs(Shared.Toggles) do
                        if info.Key and info.Key == input.KeyCode then
                            info.SetToggle(not Shared.Flags[fKey])
                        end
                    end
                end
            end
        end)
    end

    -- Delay keybinds UI build slightly so all modules have registered their toggles
    task.delay(0.5, buildKeybindsUI)

    -- SETTINGS DRAWER
    makeSection(DrawerScroll, "General Controls", 1)
    makeButton(DrawerScroll, "Unload / Force Close Menu", 2, function()
        if Shared.GUI then Shared.GUI:Destroy() end
        for k in pairs(Shared.Flags) do Shared.Flags[k] = false end
    end)

    makeSection(DrawerScroll, "Audio & Performance", 10)
    makeSlider(DrawerScroll, "Master Volume", "MasterVolume", 0, 100, 50, 11, function(val)
        for _, s in ipairs(workspace:GetDescendants()) do
            if s:IsA("Sound") then s.Volume = val / 100 end
        end
    end)
    makeToggle(DrawerScroll, "Disable VFX (FPS Boost)", "NoVFX_Setting", 12, function(state)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = not state
            end
        end
        workspace.Terrain.Decoration = not state
    end)
    makeToggle(DrawerScroll, "Remove Textures (FPS Boost)", "NoTex_Setting", 13, function(state)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = state and 1 or 0
            end
        end
    end)

    -- EXPOSE API
    Shared.GUI         = ScreenGui
    Shared.Tabs        = Tabs
    Shared.QuadCols    = QuadCols
    Shared.MakeSection = makeSection
    Shared.MakeToggle  = makeToggle
    Shared.MakeSlider  = makeSlider
    Shared.MakeButton  = makeButton
    Shared.SwitchTab   = switchTab
    Shared.RebuildKeybinds = buildKeybindsUI

    switchTab("Main")
    print("[UI_Handler] Loaded -- Quad layout, keybinds engine & popup stack active")
end
