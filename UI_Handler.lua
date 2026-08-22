-- UI_Handler.lua
-- Internet Explorer 7 themed GUI
-- Layout: IE7 titlebar | nav strip | checkered sidebar + white content

return function(Shared)
    -- Pre-initialize so downstream modules never see nil even if UI errors partway
    Shared.Tabs        = {}
    Shared.GUI         = nil
    Shared.MakeSection = function() end
    Shared.MakeToggle  = function() return Instance.new("Frame"), function() end end
    Shared.MakeSlider  = function() return Instance.new("Frame") end
    Shared.MakeButton  = function() return Instance.new("TextButton") end
    Shared.SwitchTab   = function() end

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

    -- ============================================================
    -- MAIN WINDOW
    -- ============================================================
    local WIN_W, WIN_H = 640, 360
    local Window = Instance.new("Frame")
    Window.Name             = "Window"
    Window.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
    Window.Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
    Window.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Window.BorderSizePixel  = 0
    Window.ClipsDescendants = false
    Window.Parent           = ScreenGui

    -- Outer blue border (IE7 chrome)
    local WinStroke = Instance.new("UIStroke")
    WinStroke.Color     = Color3.fromRGB(58, 110, 165)
    WinStroke.Thickness = 3
    WinStroke.Parent    = Window

    -- ============================================================
    -- TITLE BAR  (IE7 gray bar)
    -- ============================================================
    local TITLE_H = 26
    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"
    TitleBar.Size             = UDim2.new(1, 0, 0, TITLE_H)
    TitleBar.Position         = UDim2.new(0, 0, 0, 0)
    TitleBar.BackgroundColor3 = Color3.fromRGB(212, 208, 200)
    TitleBar.BorderSizePixel  = 0
    TitleBar.Parent           = Window

    -- IE7 title text
    local TitleText = Instance.new("TextLabel")
    TitleText.Size                  = UDim2.new(0, 140, 1, 0)
    TitleText.Position              = UDim2.new(0, 6, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text                  = "Internet Explorer 7"
    TitleText.TextColor3            = Color3.fromRGB(0, 0, 0)
    TitleText.Font                  = Enum.Font.Code
    TitleText.TextSize              = 12
    TitleText.TextXAlignment        = Enum.TextXAlignment.Left
    TitleText.Parent                = TitleBar

    -- Rainbow gradient bar (the colored strip in the title)
    local RainbowBar = Instance.new("Frame")
    RainbowBar.Name             = "RainbowBar"
    RainbowBar.Size             = UDim2.new(1, -310, 0, TITLE_H - 4)
    RainbowBar.Position         = UDim2.new(0, 148, 0, 2)
    RainbowBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    RainbowBar.BorderSizePixel  = 0
    RainbowBar.Parent           = TitleBar

    local RainbowGrad = Instance.new("UIGradient")
    RainbowGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(0,   200,  80)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(80,  200, 220)),
        ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(60,  100, 220)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(140,  60, 200)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(200,  80, 180)),
    })
    RainbowGrad.Rotation = 0
    RainbowGrad.Parent   = RainbowBar

    -- Window buttons [-] [ ] [X]
    local btnDefs = {
        { label = "[-]", bg = Color3.fromRGB(212,208,200), x = -96 },
        { label = "[ ]", bg = Color3.fromRGB(212,208,200), x = -64 },
        { label = "[X]", bg = Color3.fromRGB(212,208,200), x = -32 },
    }
    local winBtns = {}
    for _, def in ipairs(btnDefs) do
        local b = Instance.new("TextButton")
        b.Size             = UDim2.new(0, 28, 0, TITLE_H - 2)
        b.Position         = UDim2.new(1, def.x, 0, 1)
        b.BackgroundColor3 = def.bg
        b.Text             = def.label
        b.TextColor3       = Color3.fromRGB(0, 0, 0)
        b.Font             = Enum.Font.Code
        b.TextSize         = 11
        b.BorderSizePixel  = 1
        b.BorderColor3     = Color3.fromRGB(120, 120, 120)
        b.Parent           = TitleBar
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(180,190,210)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = def.bg}):Play()
        end)
        winBtns[def.label] = b
    end

    -- ============================================================
    -- DRAGGING
    -- ============================================================
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
                Window.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
            end
        end)
    end

    -- ============================================================
    -- OPEN / CLOSE / MINIMIZE
    -- ============================================================
    local isOpen = true
    local function animClose()
        Window:TweenSize(UDim2.new(0,WIN_W,0,0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.2, true, function()
            Window.Visible = false
        end)
        isOpen = false
    end
    local function animOpen()
        Window.Visible = true
        Window:TweenSize(UDim2.new(0,WIN_W,0,WIN_H), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.28, true)
        isOpen = true
    end

    local minimized = false
    winBtns["[X]"].MouseButton1Click:Connect(animClose)
    winBtns["[-]"].MouseButton1Click:Connect(function()
        minimized = not minimized
        local target = minimized and UDim2.new(0,WIN_W,0,TITLE_H) or UDim2.new(0,WIN_W,0,WIN_H)
        Window:TweenSize(target, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
    end)
    winBtns["[ ]"].MouseButton1Click:Connect(function()
        if isOpen then animClose() else animOpen() end
    end)

    UserInput.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == Enum.KeyCode.RightShift then
            if isOpen then animClose() else animOpen() end
        end
    end)

    -- ============================================================
    -- NAV STRIP  (address bar row)
    -- ============================================================
    local NAV_H = 24
    local NavBar = Instance.new("Frame")
    NavBar.Name             = "NavBar"
    NavBar.Size             = UDim2.new(1, 0, 0, NAV_H)
    NavBar.Position         = UDim2.new(0, 0, 0, TITLE_H)
    NavBar.BackgroundColor3 = Color3.fromRGB(188, 199, 220)
    NavBar.BorderSizePixel  = 0
    NavBar.Parent           = Window

    local NavStroke = Instance.new("UIStroke")
    NavStroke.Color     = Color3.fromRGB(120, 140, 180)
    NavStroke.Thickness = 1
    NavStroke.Parent    = NavBar

    -- Current tab label (updates on tab switch)
    local NavTabLabel = Instance.new("TextLabel")
    NavTabLabel.Name                  = "NavTabLabel"
    NavTabLabel.Size                  = UDim2.new(0.5, 0, 1, 0)
    NavTabLabel.Position              = UDim2.new(0, 8, 0, 0)
    NavTabLabel.BackgroundTransparency = 1
    NavTabLabel.Text                  = "Main  --  Home"
    NavTabLabel.TextColor3            = Color3.fromRGB(20, 20, 80)
    NavTabLabel.Font                  = Enum.Font.Code
    NavTabLabel.TextSize              = 11
    NavTabLabel.TextXAlignment        = Enum.TextXAlignment.Left
    NavTabLabel.Parent                = NavBar

    -- Settings / Configs links (right side)
    local navRight = Instance.new("TextLabel")
    navRight.Size                  = UDim2.new(0, 200, 1, 0)
    navRight.Position              = UDim2.new(1, -208, 0, 0)
    navRight.BackgroundTransparency = 1
    navRight.Text                  = "settings  |  configs"
    navRight.TextColor3            = Color3.fromRGB(20, 20, 120)
    navRight.Font                  = Enum.Font.Code
    navRight.TextSize              = 11
    navRight.TextXAlignment        = Enum.TextXAlignment.Right
    navRight.Parent                = NavBar

    -- Thin bottom border on navbar
    local NavLine = Instance.new("Frame")
    NavLine.Size             = UDim2.new(1, 0, 0, 1)
    NavLine.Position         = UDim2.new(0, 0, 1, -1)
    NavLine.BackgroundColor3 = Color3.fromRGB(100, 120, 160)
    NavLine.BorderSizePixel  = 0
    NavLine.Parent           = NavBar

    -- ============================================================
    -- BODY CONTAINER
    -- ============================================================
    local BODY_Y   = TITLE_H + NAV_H
    local BODY_H   = WIN_H - BODY_Y
    local SIDEBAR_W = 72

    local Body = Instance.new("Frame")
    Body.Name             = "Body"
    Body.Size             = UDim2.new(1, 0, 0, BODY_H)
    Body.Position         = UDim2.new(0, 0, 0, BODY_Y)
    Body.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Body.BorderSizePixel  = 0
    Body.ClipsDescendants = true
    Body.Parent           = Window

    -- ============================================================
    -- CHECKERED SIDEBAR
    -- ============================================================
    local Sidebar = Instance.new("Frame")
    Sidebar.Name             = "Sidebar"
    Sidebar.Size             = UDim2.new(0, SIDEBAR_W, 1, 0)
    Sidebar.Position         = UDim2.new(0, 0, 0, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Sidebar.BorderSizePixel  = 0
    Sidebar.ClipsDescendants = true
    Sidebar.Parent           = Body

    -- Build checkered grid (10x10 cells)
    local CELL = 9
    local colA = Color3.fromRGB(210, 210, 210)
    local colB = Color3.fromRGB(240, 240, 240)
    for row = 0, math.ceil(BODY_H / CELL) + 1 do
        for col = 0, math.ceil(SIDEBAR_W / CELL) + 1 do
            local cell = Instance.new("Frame")
            cell.Size             = UDim2.new(0, CELL, 0, CELL)
            cell.Position         = UDim2.new(0, col * CELL, 0, row * CELL)
            cell.BorderSizePixel  = 0
            cell.BackgroundColor3 = ((row + col) % 2 == 0) and colA or colB
            cell.Parent           = Sidebar
        end
    end

    -- Right border on sidebar
    local SidebarBorder = Instance.new("Frame")
    SidebarBorder.Size             = UDim2.new(0, 1, 1, 0)
    SidebarBorder.Position         = UDim2.new(1, -1, 0, 0)
    SidebarBorder.BackgroundColor3 = Color3.fromRGB(140, 160, 200)
    SidebarBorder.BorderSizePixel  = 0
    SidebarBorder.ZIndex           = 5
    SidebarBorder.Parent           = Sidebar

    -- Tab buttons on top of checker
    local TabButtonContainer = Instance.new("Frame")
    TabButtonContainer.Size             = UDim2.new(1, -2, 1, 0)
    TabButtonContainer.Position         = UDim2.new(0, 0, 0, 0)
    TabButtonContainer.BackgroundTransparency = 1
    TabButtonContainer.ZIndex           = 6
    TabButtonContainer.Parent           = Sidebar

    local TabBtnLayout = Instance.new("UIListLayout")
    TabBtnLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabBtnLayout.Padding   = UDim.new(0, 2)
    TabBtnLayout.Parent    = TabButtonContainer

    local TabBtnPad = Instance.new("UIPadding")
    TabBtnPad.PaddingTop  = UDim.new(0, 6)
    TabBtnPad.PaddingLeft = UDim.new(0, 2)
    TabBtnPad.Parent      = TabButtonContainer

    -- ============================================================
    -- CONTENT AREA
    -- ============================================================
    local ContentArea = Instance.new("ScrollingFrame")
    ContentArea.Name                 = "ContentArea"
    ContentArea.Size                 = UDim2.new(1, -SIDEBAR_W, 1, 0)
    ContentArea.Position             = UDim2.new(0, SIDEBAR_W, 0, 0)
    ContentArea.BackgroundColor3     = Color3.fromRGB(255, 255, 255)
    ContentArea.BorderSizePixel      = 0
    ContentArea.ScrollBarThickness   = 8
    ContentArea.ScrollBarImageColor3 = Color3.fromRGB(140, 160, 200)
    ContentArea.CanvasSize           = UDim2.new(0, 0, 0, 0)
    ContentArea.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    ContentArea.Parent               = Body

    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ContentLayout.Padding   = UDim.new(0, 4)
    ContentLayout.Parent    = ContentArea

    local ContentPad = Instance.new("UIPadding")
    ContentPad.PaddingTop   = UDim.new(0, 10)
    ContentPad.PaddingLeft  = UDim.new(0, 12)
    ContentPad.PaddingRight = UDim.new(0, 8)
    ContentPad.Parent       = ContentArea

    -- ============================================================
    -- TAB SYSTEM
    -- ============================================================
    local Tabs       = {}
    local activeTab  = nil
    local tabDescriptions = {
        Main    = "Main  --  Home",
        MM2     = "MM2  --  Murder Mystery 2",
        Spotify = "Spotify  --  Music Controls",
    }

    local tabDefs = {
        { name = "Main",    order = 1 },
        { name = "MM2",     order = 2 },
        { name = "Spotify", order = 3 },
    }

    local function switchTab(name)
        for tName, tFrame in pairs(Tabs) do
            tFrame.Visible = (tName == name)
        end
        activeTab = name
        NavTabLabel.Text = tabDescriptions[name] or name
    end

    for _, def in ipairs(tabDefs) do
        -- Sidebar button
        local btn = Instance.new("TextButton")
        btn.Name             = "TabBtn_" .. def.name
        btn.Size             = UDim2.new(1, -4, 0, 26)
        btn.BackgroundColor3 = Color3.fromRGB(225, 230, 240)
        btn.Text             = def.name
        btn.TextColor3       = Color3.fromRGB(0, 0, 80)
        btn.Font             = Enum.Font.Code
        btn.TextSize         = 11
        btn.BorderSizePixel  = 1
        btn.BorderColor3     = Color3.fromRGB(120, 140, 180)
        btn.LayoutOrder      = def.order
        btn.ZIndex           = 7
        btn.Parent           = TabButtonContainer

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(180,200,235)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(225,230,240)}):Play()
        end)
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.06), {BackgroundColor3 = Color3.fromRGB(150,175,220)}):Play()
        end)

        -- Content frame for this tab
        local tabFrame = Instance.new("Frame")
        tabFrame.Name             = "Tab_" .. def.name
        tabFrame.Size             = UDim2.new(1, 0, 1, 0)
        tabFrame.BackgroundTransparency = 1
        tabFrame.Visible          = false
        tabFrame.LayoutOrder      = def.order
        tabFrame.Parent           = ContentArea

        local tabLayout = Instance.new("UIListLayout")
        tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabLayout.Padding   = UDim.new(0, 5)
        tabLayout.Parent    = tabFrame

        Tabs[def.name] = tabFrame

        btn.MouseButton1Click:Connect(function()
            switchTab(def.name)
        end)
    end

    -- ============================================================
    -- HOME TAB: GOOGLE PIXEL HEADER
    -- ============================================================
    local homeTab = Tabs["Main"]

    local googleLabel = Instance.new("TextLabel")
    googleLabel.Name                  = "GoogleLogo"
    googleLabel.Size                  = UDim2.new(1, -16, 0, 120)
    googleLabel.BackgroundTransparency = 1
    googleLabel.Text                  = "GOOGLE"
    googleLabel.TextColor3            = Color3.fromRGB(0, 0, 0)
    googleLabel.Font                  = Enum.Font.GothamBlack
    googleLabel.TextSize              = 88
    googleLabel.TextXAlignment        = Enum.TextXAlignment.Center
    googleLabel.TextYAlignment        = Enum.TextYAlignment.Center
    googleLabel.LayoutOrder           = 0
    googleLabel.Parent                = homeTab

    -- Blue selection border (IE text-selected look)
    local googleStroke = Instance.new("UIStroke")
    googleStroke.Color     = Color3.fromRGB(70, 130, 210)
    googleStroke.Thickness = 3
    -- LineJoinMode omitted (not available in all executors)
    googleStroke.Parent    = googleLabel

    -- Sub text below logo
    local subLabel = Instance.new("TextLabel")
    subLabel.Size                  = UDim2.new(1, -16, 0, 18)
    subLabel.BackgroundTransparency = 1
    subLabel.Text                  = "Select a tab from the left panel to get started."
    subLabel.TextColor3            = Color3.fromRGB(100, 100, 150)
    subLabel.Font                  = Enum.Font.Code
    subLabel.TextSize              = 11
    subLabel.TextXAlignment        = Enum.TextXAlignment.Center
    subLabel.LayoutOrder           = 1
    subLabel.Parent                = homeTab

    -- ============================================================
    -- FACTORY FUNCTIONS (exposed on Shared)
    -- ============================================================

    local function applyBtnAnim(btn)
        local base = btn.BackgroundColor3
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(180,200,235)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = base}):Play()
        end)
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.06), {BackgroundColor3 = Color3.fromRGB(140,170,220)}):Play()
        end)
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.06), {BackgroundColor3 = Color3.fromRGB(180,200,235)}):Play()
        end)
    end

    local function makeSection(parent, labelText, order)
        local lbl = Instance.new("TextLabel")
        lbl.Name                  = "Sec_" .. labelText
        lbl.Size                  = UDim2.new(1, -4, 0, 18)
        lbl.BackgroundColor3      = Color3.fromRGB(188, 199, 220)
        lbl.TextColor3            = Color3.fromRGB(10, 10, 80)
        lbl.Font                  = Enum.Font.Code
        lbl.TextSize              = 11
        lbl.Text                  = "  " .. labelText
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.BorderSizePixel       = 1
        lbl.BorderColor3          = Color3.fromRGB(120, 140, 180)
        lbl.LayoutOrder           = order or 0
        lbl.Parent                = parent
        return lbl
    end

    local function makeToggle(parent, labelText, flagKey, order, callback)
        local row = Instance.new("Frame")
        row.Name             = "Toggle_" .. flagKey
        row.Size             = UDim2.new(1, -4, 0, 24)
        row.BackgroundColor3 = Color3.fromRGB(248, 248, 255)
        row.BorderSizePixel  = 1
        row.BorderColor3     = Color3.fromRGB(180, 190, 210)
        row.LayoutOrder      = order or 0
        row.Parent           = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, -48, 1, 0)
        lbl.Position              = UDim2.new(0, 6, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = labelText
        lbl.TextColor3            = Color3.fromRGB(0, 0, 0)
        lbl.Font                  = Enum.Font.Code
        lbl.TextSize              = 11
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.Parent                = row

        local pill = Instance.new("Frame")
        pill.Size             = UDim2.new(0, 34, 0, 14)
        pill.Position         = UDim2.new(1, -42, 0.5, -7)
        pill.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
        pill.BorderSizePixel  = 0
        pill.Parent           = row
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size             = UDim2.new(0, 10, 0, 10)
        knob.Position         = UDim2.new(0, 2, 0.5, -5)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel  = 0
        knob.Parent           = pill
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        Shared.Flags[flagKey] = false

        local function setToggle(state)
            Shared.Flags[flagKey] = state
            TweenService:Create(pill, TweenInfo.new(0.15), {
                BackgroundColor3 = state and Color3.fromRGB(60, 120, 210) or Color3.fromRGB(180,180,180)
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {
                Position = state and UDim2.new(0, 22, 0.5, -5) or UDim2.new(0, 2, 0.5, -5)
            }):Play()
            if callback then callback(state) end
        end

        local clickArea = Instance.new("TextButton")
        clickArea.Size                  = UDim2.new(1, 0, 1, 0)
        clickArea.BackgroundTransparency = 1
        clickArea.Text                  = ""
        clickArea.Parent                = row
        clickArea.MouseButton1Click:Connect(function()
            setToggle(not Shared.Flags[flagKey])
        end)

        return row, setToggle
    end

    local function makeSlider(parent, labelText, flagKey, minVal, maxVal, defaultVal, order, callback)
        local row = Instance.new("Frame")
        row.Name             = "Slider_" .. flagKey
        row.Size             = UDim2.new(1, -4, 0, 34)
        row.BackgroundColor3 = Color3.fromRGB(248, 248, 255)
        row.BorderSizePixel  = 1
        row.BorderColor3     = Color3.fromRGB(180, 190, 210)
        row.LayoutOrder      = order or 0
        row.Parent           = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, -55, 0, 14)
        lbl.Position              = UDim2.new(0, 6, 0, 2)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = labelText
        lbl.TextColor3            = Color3.fromRGB(0, 0, 0)
        lbl.Font                  = Enum.Font.Code
        lbl.TextSize              = 11
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.Parent                = row

        local valLbl = Instance.new("TextLabel")
        valLbl.Size                  = UDim2.new(0, 48, 0, 14)
        valLbl.Position              = UDim2.new(1, -54, 0, 2)
        valLbl.BackgroundTransparency = 1
        valLbl.Text                  = tostring(defaultVal)
        valLbl.TextColor3            = Color3.fromRGB(0, 0, 120)
        valLbl.Font                  = Enum.Font.Code
        valLbl.TextSize              = 11
        valLbl.TextXAlignment        = Enum.TextXAlignment.Right
        valLbl.Parent                = row

        local track = Instance.new("Frame")
        track.Size             = UDim2.new(1, -12, 0, 6)
        track.Position         = UDim2.new(0, 6, 0, 22)
        track.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
        track.BorderSizePixel  = 1
        track.BorderColor3     = Color3.fromRGB(150, 160, 190)
        track.Parent           = row

        local fill = Instance.new("Frame")
        fill.Size             = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(60, 120, 210)
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
            if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(i.Position.X) end
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
        btn.Size             = UDim2.new(1, -4, 0, 24)
        btn.BackgroundColor3 = Color3.fromRGB(225, 230, 242)
        btn.Text             = labelText
        btn.TextColor3       = Color3.fromRGB(0, 0, 80)
        btn.Font             = Enum.Font.Code
        btn.TextSize         = 11
        btn.BorderSizePixel  = 1
        btn.BorderColor3     = Color3.fromRGB(120, 140, 180)
        btn.LayoutOrder      = order or 0
        btn.Parent           = parent
        applyBtnAnim(btn)
        if callback then btn.MouseButton1Click:Connect(callback) end
        return btn
    end

    -- ============================================================
    -- EXPOSE
    -- ============================================================
    Shared.GUI         = ScreenGui
    Shared.Tabs        = Tabs
    Shared.MakeSection = makeSection
    Shared.MakeToggle  = makeToggle
    Shared.MakeSlider  = makeSlider
    Shared.MakeButton  = makeButton
    Shared.SwitchTab   = switchTab

    switchTab("Main")
    print("[UI_Handler] Loaded -- IE7 theme -- RightShift to toggle")
end
