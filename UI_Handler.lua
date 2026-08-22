-- UI_Handler.lua
-- Windows XP themed GUI with sidebar + content area
-- Animations: hover, click, open/close

return function(Shared)
    local TweenService = Shared.Services.TweenService
    local UserInput    = Shared.Services.UserInput
    local CoreGui      = Shared.Services.CoreGui

    -- Destroy old GUI if it exists (re-inject safe)
    if CoreGui:FindFirstChild("XP_Menu") then
        CoreGui:FindFirstChild("XP_Menu"):Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name             = "XP_Menu"
    ScreenGui.ResetOnSpawn     = false
    ScreenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent           = CoreGui

    local XP = {
        TitleBar     = Color3.fromRGB(0, 84, 166),
        TitleGrad    = Color3.fromRGB(41, 128, 185),
        Body         = Color3.fromRGB(236, 233, 216),
        Border       = Color3.fromRGB(0, 60, 116),
        Sidebar      = Color3.fromRGB(123, 162, 210),
        SidebarItem  = Color3.fromRGB(255, 255, 255),
        Button       = Color3.fromRGB(236, 233, 216),
        ButtonBorder = Color3.fromRGB(100, 100, 100),
        ButtonHover  = Color3.fromRGB(220, 230, 245),
        ButtonClick  = Color3.fromRGB(180, 200, 230),
        Text         = Color3.fromRGB(0, 0, 0),
        TitleText    = Color3.fromRGB(255, 255, 255),
        CloseBtn     = Color3.fromRGB(200, 58, 58),
        CloseHover   = Color3.fromRGB(232, 17, 35),
        MinBtn       = Color3.fromRGB(236, 233, 216),
        Toggle_ON    = Color3.fromRGB(0, 120, 215),
        Toggle_OFF   = Color3.fromRGB(180, 180, 180),
    }

    local Window = Instance.new("Frame")
    Window.Name             = "Window"
    Window.Size             = UDim2.new(0, 520, 0, 380)
    Window.Position         = UDim2.new(0.5, -260, 0.5, -190)
    Window.BackgroundColor3 = XP.Body
    Window.BorderSizePixel  = 0
    Window.ClipsDescendants = true
    Window.Parent           = ScreenGui

    local Shadow = Instance.new("Frame")
    Shadow.Name             = "Shadow"
    Shadow.Size             = UDim2.new(1, 6, 1, 6)
    Shadow.Position         = UDim2.new(0, 4, 0, 4)
    Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.BackgroundTransparency = 0.65
    Shadow.BorderSizePixel  = 0
    Shadow.ZIndex           = 0
    Shadow.Parent           = Window

    local OuterBorder = Instance.new("UIStroke")
    OuterBorder.Color     = XP.Border
    OuterBorder.Thickness = 2
    OuterBorder.Parent    = Window

    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"
    TitleBar.Size             = UDim2.new(1, 0, 0, 28)
    TitleBar.BackgroundColor3 = XP.TitleBar
    TitleBar.BorderSizePixel  = 0
    TitleBar.Parent           = Window

    local TitleGrad = Instance.new("UIGradient")
    TitleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   XP.TitleBar),
        ColorSequenceKeypoint.new(0.5, XP.TitleGrad),
        ColorSequenceKeypoint.new(1,   XP.TitleBar),
    })
    TitleGrad.Rotation = 0
    TitleGrad.Parent = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name                  = "TitleLabel"
    TitleLabel.Size                  = UDim2.new(1, -80, 1, 0)
    TitleLabel.Position              = UDim2.new(0, 8, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text                  = "Menu  v1.0"
    TitleLabel.TextColor3            = XP.TitleText
    TitleLabel.Font                  = Enum.Font.GothamBold
    TitleLabel.TextSize              = 13
    TitleLabel.TextXAlignment        = Enum.TextXAlignment.Left
    TitleLabel.Parent                = TitleBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name             = "CloseBtn"
    CloseBtn.Size             = UDim2.new(0, 22, 0, 20)
    CloseBtn.Position         = UDim2.new(1, -26, 0, 4)
    CloseBtn.BackgroundColor3 = XP.CloseBtn
    CloseBtn.Text             = "X"
    CloseBtn.TextColor3       = Color3.fromRGB(255,255,255)
    CloseBtn.Font             = Enum.Font.GothamBold
    CloseBtn.TextSize         = 12
    CloseBtn.BorderSizePixel  = 1
    CloseBtn.Parent           = TitleBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name             = "MinBtn"
    MinBtn.Size             = UDim2.new(0, 22, 0, 20)
    MinBtn.Position         = UDim2.new(1, -52, 0, 4)
    MinBtn.BackgroundColor3 = XP.MinBtn
    MinBtn.Text             = "-"
    MinBtn.TextColor3       = Color3.fromRGB(0,0,0)
    MinBtn.Font             = Enum.Font.GothamBold
    MinBtn.TextSize         = 10
    MinBtn.BorderSizePixel  = 1
    MinBtn.Parent           = TitleBar

    local Sidebar = Instance.new("Frame")
    Sidebar.Name             = "Sidebar"
    Sidebar.Size             = UDim2.new(0, 120, 1, -28)
    Sidebar.Position         = UDim2.new(0, 0, 0, 28)
    Sidebar.BackgroundColor3 = XP.Sidebar
    Sidebar.BorderSizePixel  = 0
    Sidebar.Parent           = Window

    local SidebarStroke = Instance.new("UIStroke")
    SidebarStroke.Color     = XP.Border
    SidebarStroke.Thickness = 1
    SidebarStroke.Parent    = Sidebar

    local SidebarLayout = Instance.new("UIListLayout")
    SidebarLayout.SortOrder  = Enum.SortOrder.LayoutOrder
    SidebarLayout.Padding    = UDim.new(0, 2)
    SidebarLayout.Parent     = Sidebar

    local SidebarPad = Instance.new("UIPadding")
    SidebarPad.PaddingTop  = UDim.new(0, 6)
    SidebarPad.PaddingLeft = UDim.new(0, 4)
    SidebarPad.Parent      = Sidebar

    local Content = Instance.new("ScrollingFrame")
    Content.Name                   = "Content"
    Content.Size                   = UDim2.new(1, -124, 1, -32)
    Content.Position               = UDim2.new(0, 122, 0, 30)
    Content.BackgroundColor3       = XP.Body
    Content.BorderSizePixel        = 0
    Content.ScrollBarThickness     = 6
    Content.ScrollBarImageColor3   = Color3.fromRGB(0, 84, 166)
    Content.CanvasSize             = UDim2.new(0, 0, 0, 0)
    Content.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    Content.Parent                 = Window

    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ContentLayout.Padding   = UDim.new(0, 6)
    ContentLayout.Parent    = Content

    local ContentPad = Instance.new("UIPadding")
    ContentPad.PaddingTop   = UDim.new(0, 8)
    ContentPad.PaddingLeft  = UDim.new(0, 8)
    ContentPad.PaddingRight = UDim.new(0, 8)
    ContentPad.Parent       = Content

    -- DRAGGING
    do
        local dragging, dragStart, startPos = false, nil, nil
        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging  = true
                dragStart = input.Position
                startPos  = Window.Position
            end
        end)
        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        UserInput.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                Window.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- OPEN / CLOSE ANIMATION
    local isOpen    = true
    local isVisible = true

    local function animateOpen()
        Window.Visible = true
        Window:TweenSize(
            UDim2.new(0, 520, 0, 380),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Back,
            0.35, true
        )
        TweenService:Create(Window, TweenInfo.new(0.35), {
            BackgroundTransparency = 0
        }):Play()
        isOpen = true
    end

    local function animateClose()
        Window:TweenSize(
            UDim2.new(0, 520, 0, 0),
            Enum.EasingDirection.In,
            Enum.EasingStyle.Quad,
            0.25, true, function()
                Window.Visible = false
            end
        )
        isOpen = false
    end

    CloseBtn.MouseButton1Click:Connect(function()
        animateClose()
    end)

    MinBtn.MouseButton1Click:Connect(function()
        isVisible = not isVisible
        local targetSize = isVisible
            and UDim2.new(0, 520, 0, 380)
            or  UDim2.new(0, 520, 0, 28)
        Window:TweenSize(targetSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
    end)

    UserInput.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if isOpen then
                animateClose()
            else
                animateOpen()
            end
        end
    end)

    -- BUTTON ANIM HELPERS
    local function applyButtonAnim(btn)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {
                BackgroundColor3 = XP.ButtonHover
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {
                BackgroundColor3 = XP.Button
            }):Play()
        end)
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.07), {
                BackgroundColor3 = XP.ButtonClick
            }):Play()
        end)
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.07), {
                BackgroundColor3 = XP.ButtonHover
            }):Play()
        end)
    end

    -- SECTION HEADER
    local function makeSection(parent, labelText, order)
        local lbl = Instance.new("TextLabel")
        lbl.Name                  = "Section_" .. labelText
        lbl.Size                  = UDim2.new(1, -4, 0, 20)
        lbl.BackgroundColor3      = XP.TitleBar
        lbl.TextColor3            = XP.TitleText
        lbl.Font                  = Enum.Font.GothamBold
        lbl.TextSize              = 11
        lbl.Text                  = "  " .. labelText
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.BorderSizePixel       = 0
        lbl.LayoutOrder           = order or 0
        lbl.Parent                = parent
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 3)
        return lbl
    end

    -- TOGGLE
    local function makeToggle(parent, labelText, flagKey, order, callback)
        local row = Instance.new("Frame")
        row.Name             = "Toggle_" .. flagKey
        row.Size             = UDim2.new(1, -4, 0, 26)
        row.BackgroundColor3 = XP.Button
        row.BorderSizePixel  = 1
        row.LayoutOrder      = order or 0
        row.Parent           = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 3)
        Instance.new("UIStroke", row).Color = XP.ButtonBorder

        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, -50, 1, 0)
        lbl.Position              = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = labelText
        lbl.TextColor3            = XP.Text
        lbl.Font                  = Enum.Font.Gotham
        lbl.TextSize              = 12
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.Parent                = row

        local pill = Instance.new("Frame")
        pill.Name             = "Pill"
        pill.Size             = UDim2.new(0, 36, 0, 16)
        pill.Position         = UDim2.new(1, -44, 0.5, -8)
        pill.BackgroundColor3 = XP.Toggle_OFF
        pill.BorderSizePixel  = 0
        pill.Parent           = row
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Name             = "Knob"
        knob.Size             = UDim2.new(0, 12, 0, 12)
        knob.Position         = UDim2.new(0, 2, 0.5, -6)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.BorderSizePixel  = 0
        knob.Parent           = pill
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        Shared.Flags[flagKey] = false

        local function setToggle(state)
            Shared.Flags[flagKey] = state
            TweenService:Create(pill, TweenInfo.new(0.15), {
                BackgroundColor3 = state and XP.Toggle_ON or XP.Toggle_OFF
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {
                Position = state
                    and UDim2.new(0, 22, 0.5, -6)
                    or  UDim2.new(0, 2,  0.5, -6)
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
        applyButtonAnim(clickArea)

        return row, setToggle
    end

    -- SLIDER
    local function makeSlider(parent, labelText, flagKey, minVal, maxVal, defaultVal, order, callback)
        local row = Instance.new("Frame")
        row.Name             = "Slider_" .. flagKey
        row.Size             = UDim2.new(1, -4, 0, 36)
        row.BackgroundColor3 = XP.Button
        row.BorderSizePixel  = 1
        row.LayoutOrder      = order or 0
        row.Parent           = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 3)
        Instance.new("UIStroke", row).Color = XP.ButtonBorder

        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, -60, 0, 16)
        lbl.Position              = UDim2.new(0, 8, 0, 2)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = labelText
        lbl.TextColor3            = XP.Text
        lbl.Font                  = Enum.Font.Gotham
        lbl.TextSize              = 11
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.Parent                = row

        local valLbl = Instance.new("TextLabel")
        valLbl.Size                  = UDim2.new(0, 50, 0, 16)
        valLbl.Position              = UDim2.new(1, -58, 0, 2)
        valLbl.BackgroundTransparency = 1
        valLbl.Text                  = tostring(defaultVal)
        valLbl.TextColor3            = XP.Text
        valLbl.Font                  = Enum.Font.GothamBold
        valLbl.TextSize              = 11
        valLbl.TextXAlignment        = Enum.TextXAlignment.Right
        valLbl.Parent                = row

        local track = Instance.new("Frame")
        track.Name             = "Track"
        track.Size             = UDim2.new(1, -16, 0, 6)
        track.Position         = UDim2.new(0, 8, 0, 24)
        track.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
        track.BorderSizePixel  = 0
        track.Parent           = row
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Name             = "Fill"
        fill.Size             = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
        fill.BorderSizePixel  = 0
        fill.Parent           = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        Shared.Flags[flagKey] = defaultVal

        local draggingSlider = false
        local function updateSlider(inputX)
            local absX   = track.AbsolutePosition.X
            local absW   = track.AbsoluteSize.X
            local pct    = math.clamp((inputX - absX) / absW, 0, 1)
            local val    = math.floor(minVal + pct * (maxVal - minVal))
            Shared.Flags[flagKey] = val
            fill.Size    = UDim2.new(pct, 0, 1, 0)
            valLbl.Text  = tostring(val)
            if callback then callback(val) end
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingSlider = true
                updateSlider(input.Position.X)
            end
        end)
        UserInput.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingSlider = false
            end
        end)
        UserInput.InputChanged:Connect(function(input)
            if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateSlider(input.Position.X)
            end
        end)

        return row
    end

    -- ACTION BUTTON
    local function makeButton(parent, labelText, order, callback)
        local btn = Instance.new("TextButton")
        btn.Name             = "Btn_" .. labelText:gsub("%s+", "_")
        btn.Size             = UDim2.new(1, -4, 0, 26)
        btn.BackgroundColor3 = XP.Button
        btn.Text             = labelText
        btn.TextColor3       = XP.Text
        btn.Font             = Enum.Font.Gotham
        btn.TextSize         = 12
        btn.BorderSizePixel  = 1
        btn.LayoutOrder      = order or 0
        btn.Parent           = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
        Instance.new("UIStroke", btn).Color = XP.ButtonBorder
        applyButtonAnim(btn)
        if callback then
            btn.MouseButton1Click:Connect(callback)
        end
        return btn
    end

    -- SIDEBAR NAVIGATION
    local Tabs = {}
    local activeTab = nil

    local tabDefs = {
        { name = "Main",    icon = "[Main]" },
        { name = "MM2",     icon = "[MM2]" },
        { name = "Spotify", icon = "[Spotify]" },
    }

    local function switchTab(name)
        for tabName, tabFrame in pairs(Tabs) do
            tabFrame.Visible = (tabName == name)
        end
        activeTab = name
    end

    for i, def in ipairs(tabDefs) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name             = "Tab_" .. def.name
        tabBtn.Size             = UDim2.new(1, -8, 0, 32)
        tabBtn.BackgroundColor3 = XP.SidebarItem
        tabBtn.Text             = def.icon .. " " .. def.name
        tabBtn.TextColor3       = XP.Border
        tabBtn.Font             = Enum.Font.GothamBold
        tabBtn.TextSize         = 11
        tabBtn.TextXAlignment   = Enum.TextXAlignment.Left
        tabBtn.BorderSizePixel  = 1
        tabBtn.LayoutOrder      = i
        tabBtn.Parent           = Sidebar
        Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 3)

        local tabFrame = Instance.new("Frame")
        tabFrame.Name             = "TabContent_" .. def.name
        tabFrame.Size             = UDim2.new(1, 0, 1, 0)
        tabFrame.BackgroundTransparency = 1
        tabFrame.Visible          = false
        tabFrame.Parent           = Content

        local tabLayout = Instance.new("UIListLayout")
        tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabLayout.Padding   = UDim.new(0, 4)
        tabLayout.Parent    = tabFrame

        Tabs[def.name] = tabFrame

        tabBtn.MouseButton1Click:Connect(function()
            switchTab(def.name)
        end)
    end

    switchTab("Main")

    Shared.GUI         = ScreenGui
    Shared.Tabs        = Tabs
    Shared.MakeSection = makeSection
    Shared.MakeToggle  = makeToggle
    Shared.MakeSlider  = makeSlider
    Shared.MakeButton  = makeButton
    Shared.SwitchTab   = switchTab

    print("[UI_Handler] Loaded -- RightShift to toggle")
end
