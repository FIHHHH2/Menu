-- UI_Handler.lua
-- IE7/XP Modular UI -- Dark Mode Engine (Sun/Moon), Smooth Tab Transitions,
-- Full Hover/Leave Interactions, Resizable Window, and Zero-Lag Debounced Saving

return function(Shared)
    Shared.Tabs         = {}
    Shared.GUI          = nil
    Shared.Toggles      = Shared.Toggles or {}
    Shared.Sliders      = Shared.Sliders or {}
    Shared.Flags        = Shared.Flags or {}
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
    local TweenSvc     = TweenService
    local UserInput    = Shared.Services.UserInput
    local CoreGui      = Shared.Services.CoreGui
    local Http         = Shared.Services.Http
    local RunService   = Shared.Services.RunService or game:GetService("RunService")
    local Players      = Shared.Services.Players or game:GetService("Players")
    local StarterGui   = game:GetService("StarterGui")

    if Shared.CleanupAll then
        pcall(Shared.CleanupAll)
    elseif CoreGui:FindFirstChild("IE7_Menu") then
        pcall(function() CoreGui:FindFirstChild("IE7_Menu"):Destroy() end)
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "IE7_Menu"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true

    local gethui = rawget(getfenv and getfenv(0) or _G, "gethui") or (getgenv and getgenv().gethui)
    local targetParent = nil
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then targetParent = h end
    end
    if not targetParent then
        local ok, _ = pcall(function() ScreenGui.Parent = CoreGui end)
        if ok and ScreenGui.Parent == CoreGui then
            targetParent = CoreGui
        else
            targetParent = (Shared.Player and Shared.Player:FindFirstChildOfClass("PlayerGui"))
                        or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        end
    end
    ScreenGui.Parent = targetParent
    Shared.GUI       = ScreenGui
    if Shared.AddCleanup then Shared.AddCleanup(ScreenGui) end

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
        BannerBg      = Color3.fromRGB(240, 245, 255),
        BannerTitle   = Color3.fromRGB(15, 30, 80),
        BannerSub     = Color3.fromRGB(90, 110, 150),
        TitleGradTop  = Color3.fromRGB(242, 244, 248),
        TitleGradBot  = Color3.fromRGB(208, 204, 196),
        NavGradTop    = Color3.fromRGB(215, 224, 240),
        NavGradBot    = Color3.fromRGB(180, 192, 215),
        BannerGradTop = Color3.fromRGB(225, 235, 255),
        BannerGradBot = Color3.fromRGB(245, 248, 255),
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
        TitleGradTop  = Color3.fromRGB(42, 48, 62),
        TitleGradBot  = Color3.fromRGB(22, 26, 34),
        NavGradTop    = Color3.fromRGB(32, 38, 52),
        NavGradBot    = Color3.fromRGB(16, 20, 28),
        BannerGradTop = Color3.fromRGB(26, 38, 62),
        BannerGradBot = Color3.fromRGB(14, 18, 26),
        IsDark        = true
    }

    -- ── ADAPTIVE SONG THEME PALETTE ENGINE (AUTHENTIC COLOR EXTRACTION) ─
    local function generateAdaptivePalette(track)
        local title = (track and track.name) or "Unknown Track"
        local artist = (track and track.artist) or "Unknown Artist"
        local cover = (track and track.cover) or ""

        local titleLower = title:lower()
        local artistLower = artist:lower()

        -- Check if artwork is monochrome/grayscale
        local isMono = false
        if track and track.palette and track.palette.isMonochrome then
            isMono = true
        elseif artistLower:find("kelestiial") or titleLower:find("around") or titleLower:find("gray") or titleLower:find("grey") or titleLower:find("mist") then
            isMono = true
        end

        if isMono then
            -- Elegant High-Contrast Monochrome / Diamond Silver / Misty Glass Theme
            return {
                WinBorder     = Color3.fromRGB(220, 230, 248),
                TitleBar      = Color3.fromRGB(18, 20, 26),
                TitleText     = Color3.fromRGB(255, 255, 255),
                NavBar        = Color3.fromRGB(14, 16, 22),
                NavText       = Color3.fromRGB(220, 230, 250),
                NavLink       = Color3.fromRGB(200, 220, 255),
                NavLinkHover  = Color3.fromRGB(255, 255, 255),
                BodyBg        = Color3.fromRGB(10, 12, 16),
                SidebarCellA  = Color3.fromRGB(14, 16, 20),
                SidebarCellB  = Color3.fromRGB(20, 22, 28),
                SidebarBorder = Color3.fromRGB(45, 52, 68),
                BtnBg         = Color3.fromRGB(22, 26, 34),
                BtnBorder     = Color3.fromRGB(60, 70, 90),
                BtnHover      = Color3.fromRGB(34, 40, 52),
                BtnDown       = Color3.fromRGB(16, 18, 24),
                BtnText       = Color3.fromRGB(245, 248, 255),
                TabActiveBg   = Color3.fromRGB(10, 12, 16),
                TabActiveText = Color3.fromRGB(255, 255, 255),
                SectionBg     = Color3.fromRGB(24, 28, 38),
                SectionText   = Color3.fromRGB(235, 242, 255),
                RowBg         = Color3.fromRGB(14, 16, 22),
                RowBorder     = Color3.fromRGB(38, 44, 58),
                RowHover      = Color3.fromRGB(24, 28, 36),
                Accent        = Color3.fromRGB(225, 235, 255),
                DrawerBg      = Color3.fromRGB(12, 14, 18),
                NotifyBg      = Color3.fromRGB(16, 18, 24),
                NotifyBorder  = Color3.fromRGB(180, 200, 235),
                BannerBg      = Color3.fromRGB(16, 18, 24),
                BannerTitle   = Color3.fromRGB(250, 252, 255),
                BannerSub     = Color3.fromRGB(160, 175, 200),
                TitleGradTop  = Color3.fromRGB(28, 32, 40),
                TitleGradBot  = Color3.fromRGB(12, 14, 18),
                NavGradTop    = Color3.fromRGB(22, 26, 34),
                NavGradBot    = Color3.fromRGB(10, 12, 16),
                BannerGradTop = Color3.fromRGB(30, 36, 48),
                BannerGradBot = Color3.fromRGB(12, 14, 18),
                IsDark        = true,
                IsAdaptive    = true
            }
        end

        local hue = 0.60
        local sat = 0.75
        local val = 0.85
        local accentHue = 0.60

        -- Authentic cover palette extraction
        if track and track.palette and track.palette.dominant then
            local d = track.palette.dominant
            local s = track.palette.secondary or d
            local h1, s1, v1 = Color3.toHSV(d)
            local h2, s2, v2 = Color3.toHSV(s)

            hue = h1
            sat = math.clamp(math.max(s1, 0.40), 0.35, 0.95)
            val = math.clamp(math.max(v1, 0.65), 0.55, 0.98)

            if s2 > 0.18 and math.abs(h1 - h2) > 0.04 then
                accentHue = h2
            else
                accentHue = (h1 + 0.05) % 1.0
            end
        elseif track and track.palette and track.palette.avg then
            local a = track.palette.avg
            local h, s, l = Color3.toHSV(a)
            hue = h
            sat = math.clamp(s, 0.40, 0.90)
            val = math.clamp(l, 0.60, 0.98)
            accentHue = (h + 0.05) % 1.0
        elseif artistLower:find("wifiskeleton") or titleLower:find("ugly") then
            hue = 0.04; accentHue = 0.03; sat = 0.90; val = 0.95
        elseif artistLower:find("interworld") or titleLower:find("metamorphosis") or titleLower:find("phonk") then
            hue = 0.85; accentHue = 0.88; sat = 0.85; val = 0.95
        elseif artistLower:find("weeknd") or titleLower:find("starboy") or titleLower:find("blinding") then
            hue = 0.01; accentHue = 0.01; sat = 0.90; val = 0.98
        elseif artistLower:find("m83") or titleLower:find("midnight city") or titleLower:find("synthwave") then
            hue = 0.58; accentHue = 0.55; sat = 0.85; val = 0.95
        else
            local hash = 5381
            local combined = tostring(cover) .. ":" .. tostring(title) .. ":" .. tostring(artist)
            for i = 1, #combined do
                hash = bit32.band(hash * 33 + string.byte(combined, i), 0x7FFFFFFF)
            end
            hue = (hash % 360) / 360
            accentHue = hue
            sat = 0.80
            val = 0.90
        end

        -- Generate unified, harmonized, vibrant palette across all UI components
        local winBorderCol = Color3.fromHSV(accentHue, math.clamp(sat, 0.70, 1.0), math.clamp(val, 0.85, 1.0))
        local titleBarCol  = Color3.fromHSV(hue, math.clamp(sat * 0.55, 0.20, 0.50), 0.12)
        local titleTextCol = Color3.fromRGB(248, 250, 255)
        local navBarCol    = Color3.fromHSV(hue, math.clamp(sat * 0.65, 0.25, 0.55), 0.09)
        local navTextCol   = Color3.fromHSV(accentHue, 0.25, 0.98)
        local navLinkCol   = Color3.fromHSV(accentHue, math.clamp(sat, 0.70, 1.0), 1.0)
        local navHoverCol  = Color3.fromHSV((accentHue + 0.05) % 1.0, 0.90, 1.0)
        local bodyBgCol    = Color3.fromHSV(hue, math.clamp(sat * 0.45, 0.15, 0.45), 0.06)
        local cellACol     = Color3.fromHSV(hue, math.clamp(sat * 0.40, 0.15, 0.40), 0.09)
        local cellBCol     = Color3.fromHSV(hue, math.clamp(sat * 0.40, 0.15, 0.40), 0.12)
        local sideBorder   = Color3.fromHSV(hue, math.clamp(sat * 0.65, 0.25, 0.60), 0.24)
        local btnBgCol     = Color3.fromHSV(hue, math.clamp(sat * 0.40, 0.15, 0.40), 0.14)
        local btnBorderCol = Color3.fromHSV(hue, math.clamp(sat * 0.55, 0.20, 0.50), 0.28)
        local btnHoverCol  = Color3.fromHSV(hue, math.clamp(sat * 0.45, 0.18, 0.45), 0.20)
        local btnDownCol   = Color3.fromHSV(hue, math.clamp(sat * 0.55, 0.20, 0.50), 0.09)
        local btnTextCol   = Color3.fromRGB(245, 248, 255)
        local tabActiveBg  = Color3.fromHSV(hue, math.clamp(sat * 0.45, 0.15, 0.45), 0.06)
        local tabActiveTxt = Color3.fromHSV(accentHue, math.clamp(sat, 0.70, 1.0), 1.0)
        local secBgCol     = Color3.fromHSV(hue, math.clamp(sat * 0.55, 0.20, 0.50), 0.15)
        local secTextCol   = Color3.fromHSV(accentHue, 0.35, 0.98)
        local rowBgCol     = Color3.fromHSV(hue, math.clamp(sat * 0.35, 0.12, 0.35), 0.09)
        local rowBorderCol = Color3.fromHSV(hue, math.clamp(sat * 0.45, 0.18, 0.45), 0.20)
        local rowHoverCol  = Color3.fromHSV(hue, math.clamp(sat * 0.45, 0.18, 0.45), 0.15)
        local accentCol    = Color3.fromHSV(accentHue, math.clamp(sat, 0.75, 1.0), math.clamp(val, 0.85, 1.0))
        local drawerBgCol  = Color3.fromHSV(hue, math.clamp(sat * 0.45, 0.15, 0.45), 0.08)
        local notifyBgCol  = Color3.fromHSV(hue, math.clamp(sat * 0.50, 0.20, 0.50), 0.10)
        local notifyBrdCol = Color3.fromHSV(accentHue, math.clamp(sat, 0.75, 1.0), 0.85)
        local bannerBgCol  = Color3.fromHSV(hue, math.clamp(sat * 0.50, 0.20, 0.50), 0.10)
        local bannerTitle  = Color3.fromHSV(accentHue, 0.30, 1.0)
        local bannerSub    = Color3.fromHSV(accentHue, 0.20, 0.85)

        -- Dynamic Multi-Tone Cover Gradient Palettes
        local titleGradTop = Color3.fromHSV(hue, math.clamp(sat * 0.65, 0.25, 0.60), 0.22)
        local titleGradBot = Color3.fromHSV(hue, math.clamp(sat * 0.50, 0.18, 0.45), 0.09)
        local navGradTop   = Color3.fromHSV(hue, math.clamp(sat * 0.70, 0.28, 0.65), 0.16)
        local navGradBot   = Color3.fromHSV(hue, math.clamp(sat * 0.55, 0.20, 0.50), 0.07)
        local bannerGradTop= Color3.fromHSV(accentHue, math.clamp(sat * 0.75, 0.35, 0.75), 0.24)
        local bannerGradBot= Color3.fromHSV(hue, math.clamp(sat * 0.50, 0.20, 0.50), 0.07)

        return {
            WinBorder     = winBorderCol,
            TitleBar      = titleBarCol,
            TitleText     = titleTextCol,
            NavBar        = navBarCol,
            NavText       = navTextCol,
            NavLink       = navLinkCol,
            NavLinkHover  = navHoverCol,
            BodyBg        = bodyBgCol,
            SidebarCellA  = cellACol,
            SidebarCellB  = cellBCol,
            SidebarBorder = sideBorder,
            BtnBg         = btnBgCol,
            BtnBorder     = btnBorderCol,
            BtnHover      = btnHoverCol,
            BtnDown       = btnDownCol,
            BtnText       = btnTextCol,
            TabActiveBg   = tabActiveBg,
            TabActiveText = tabActiveTxt,
            SectionBg     = secBgCol,
            SectionText   = secTextCol,
            RowBg         = rowBgCol,
            RowBorder     = rowBorderCol,
            RowHover      = rowHoverCol,
            Accent        = accentCol,
            DrawerBg      = drawerBgCol,
            NotifyBg      = notifyBgCol,
            NotifyBorder  = notifyBrdCol,
            BannerBg      = bannerBgCol,
            BannerTitle   = bannerTitle,
            BannerSub     = bannerSub,
            TitleGradTop  = titleGradTop,
            TitleGradBot  = titleGradBot,
            NavGradTop    = navGradTop,
            NavGradBot    = navGradBot,
            BannerGradTop = bannerGradTop,
            BannerGradBot = bannerGradBot,
            IsDark        = true,
            IsAdaptive    = true
        }
    end

    local themeMode = "Dark"
    local isDark = true
    local C = DarkTheme
    local currentAdaptiveTrack = nil

    -- Theme Registry: elements register to automatically update on theme transitions
    local themeRegistry = {}
    local function registerThemed(instance, propMap)
        table.insert(themeRegistry, { inst = instance, props = propMap })
    end

    local themeCallbacks = {}     -- other modules register here to be notified on theme change
    Shared.RegisterThemeCallback = function(fn) table.insert(themeCallbacks, fn) end
    Shared.IsDark = function() return isDark end
    Shared.GetTheme = function() return C end
    Shared.GetThemeMode = function() return themeMode end

    local applyThemeTransition = nil -- forward declaration
    local themeCallbacks = {}
    Shared.ThemeCallbacks = themeCallbacks

    local applyThemeTransition = nil

    Shared.SetAdaptiveThemeTrack = function(track)
        currentAdaptiveTrack = track
        if themeMode == "Adaptive" and track then
            local palette = generateAdaptivePalette(track)
            if applyThemeTransition then
                applyThemeTransition(palette, 0.65)
            end
        end
    end

    -- ── ROBLOX CORE UI (TOGGLEABLE RETRO AERO & CHAT ENGINE) ──────
    local StarterGui = game:GetService("StarterGui")
    local customCoreEnabled = true
    Shared.Flags["CustomCoreUI"] = true

    -- ── GAME-SPECIFIC CUSTOM CORE UI / OVERLAP SUPPRESSOR ────────
    local disableConflictingGUIs = true
    Shared.Flags["DisableConflictingGUIs"] = true
    local suppressedGameGUIs = {}

    local function isOurGui(gui)
        if not gui then return false end
        local n = gui.Name
        if n == "IE7_Menu" or n == "FihUi" or n == "Fih_CustomLeaderboard" or n == "Fih_CustomChat" or n == "Fih_BottomHUD" or n == "Fih_ArtworkBillboard" or n:find("^Fih_") then
            return true
        end
        if ScreenGui and (gui == ScreenGui or gui:IsDescendantOf(ScreenGui)) then return true end
        return false
    end

    local function checkAndSuppressConflictingGui(gui)
        if not disableConflictingGUIs then return end
        if not gui or not gui.Parent then return end
        if isOurGui(gui) then return end

        local n = gui.Name:lower()
        local isConflict = false

        -- Custom playerlist / leaderboard / tablist / tabbar replacement
        if n:find("playerlist") or n:find("player_list") or n:find("leaderboard") or n:find("leader_board")
            or n:find("scoreboard") or n:find("score_board") or n:find("tablist") or n:find("tab_list")
            or n:find("tabbar") or n:find("tab_bar") or n:find("tabmenu") or n:find("tab_menu")
            or n:find("customplayer") or n:find("customlb") or n:find("playersgui") or n:find("playerslist")
            or n:find("customtab") or n:find("scoreboardscreengui") then
            isConflict = true
        end

        -- Custom topbar replacement in PlayerGui
        if n:find("topbar") or n:find("top_bar") or n:find("topbargui") or n:find("customtopbar")
            or n:find("game_topbar") or n:find("gametopbar") or n:find("topbarcontainer")
            or n:find("topbarframe") then
            if gui.Parent ~= CoreGui and not n:find("topbarapp") then
                isConflict = true
            end
        end

        -- Explicit MM2 MainGUI components (TabBar, TopBar, Scoreboard, Leaderboard)
        local pName = (gui.Parent and gui.Parent.Name:lower()) or ""
        local ppName = (gui.Parent and gui.Parent.Parent and gui.Parent.Parent.Name:lower()) or ""
        if pName:find("maingui") or ppName:find("maingui") or pName:find("game") or pName:find("lobby") then
            if n == "topbar" or n == "tabbar" or n == "tab" or n == "scoreboard" or n == "leaderboard" or n == "playerlist" or n == "roleselector" then
                isConflict = true
            end
        end

        if isConflict then
            pcall(function()
                if gui:IsA("ScreenGui") then
                    if gui.Enabled then
                        if suppressedGameGUIs[gui] == nil then
                            suppressedGameGUIs[gui] = gui.Enabled
                        end
                        gui.Enabled = false
                    end
                elseif gui:IsA("GuiObject") then
                    if gui.Visible then
                        if suppressedGameGUIs[gui] == nil then
                            suppressedGameGUIs[gui] = gui.Visible
                        end
                        gui.Visible = false
                    end
                end
            end)
        end
    end

    local function scanAndSuppressAllConflictingGUIs()
        if not disableConflictingGUIs then return end
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
            local pGui = (Shared.Player and Shared.Player:FindFirstChildOfClass("PlayerGui"))
                      or game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pGui then
                for _, child in ipairs(pGui:GetChildren()) do
                    checkAndSuppressConflictingGui(child)
                end
                for _, desc in ipairs(pGui:GetDescendants()) do
                    checkAndSuppressConflictingGui(desc)
                end
            end
        end)
    end

    local function restoreSuppressedGameGUIs()
        for gui, origState in pairs(suppressedGameGUIs) do
            if gui and gui.Parent then
                pcall(function()
                    if gui:IsA("ScreenGui") then
                        gui.Enabled = origState
                    elseif gui:IsA("GuiObject") then
                        gui.Visible = origState
                    end
                end)
            end
        end
        suppressedGameGUIs = {}
    end

    local function restoreDefaultRobloxCoreUI()
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

        pcall(function()
            local topbar = CoreGui:FindFirstChild("TopBarApp")
            if topbar then
                for _, d in ipairs(topbar:GetDescendants()) do
                    if d:IsA("UICorner") then d.CornerRadius = UDim.new(0, 0) end
                end
            end
        end)

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

    -- Persistent Watcher: Re-enforces styling and suppresses overlapping game GUIs
    task.spawn(function()
        task.wait(0.2)
        styleRobloxCoreUI(C, isDark)
        scanAndSuppressAllConflictingGUIs()

        local pGui = (Shared.Player and Shared.Player:FindFirstChildOfClass("PlayerGui"))
                  or game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pGui then
            local daConn = pGui.DescendantAdded:Connect(function(child)
                if disableConflictingGUIs then
                    task.wait(0.02)
                    checkAndSuppressConflictingGui(child)
                end
            end)
            if Shared.AddCleanup then Shared.AddCleanup(daConn) end
        end

        local caConn = Shared.Player.CharacterAdded:Connect(function()
            task.wait(0.3)
            scanAndSuppressAllConflictingGUIs()
            local newPGui = Shared.Player:FindFirstChildOfClass("PlayerGui")
            if newPGui and newPGui ~= pGui then
                pGui = newPGui
                local newDaConn = newPGui.DescendantAdded:Connect(function(child)
                    if disableConflictingGUIs then
                        task.wait(0.02)
                        checkAndSuppressConflictingGui(child)
                    end
                end)
                if Shared.AddCleanup then Shared.AddCleanup(newDaConn) end
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(caConn) end

        local elapsed = 0
        local hbConn = RunService.Heartbeat:Connect(function(dt)
            elapsed = elapsed + dt
            if elapsed >= 0.5 then
                elapsed = 0
                if customCoreEnabled then
                    styleRobloxCoreUI(C, isDark)
                end
                if disableConflictingGUIs then
                    scanAndSuppressAllConflictingGUIs()
                end
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(hbConn) end

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

    applyThemeTransition = function(targetTheme, duration)
        C = targetTheme
        isDark = (targetTheme.IsDark ~= nil) and targetTheme.IsDark or true
        Shared.Config.DarkMode = isDark

        local tweenDuration = duration or 0.25
        local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        -- Cleanly filter out destroyed elements to prevent memory leaks and theme resetting
        local liveRegistry = {}
        for _, item in ipairs(themeRegistry) do
            if item.inst and item.inst.Parent then
                table.insert(liveRegistry, item)
                local goal = {}
                for propName, themeKey in pairs(item.props) do
                    if C[themeKey] ~= nil then
                        goal[propName] = C[themeKey]
                    end
                end
                TweenService:Create(item.inst, tweenInfo, goal):Play()
            end
        end
        themeRegistry = liveRegistry

        -- Update active tab button style
        if TabBtns and activeTab and TabBtns[activeTab] and TabBtns[activeTab].Parent then
            TweenService:Create(TabBtns[activeTab], tweenInfo, {
                BackgroundColor3 = C.TabActiveBg,
                TextColor3       = C.TabActiveText,
                BorderColor3     = C.WinBorder
            }):Play()
        end

        -- Handle semi-translucency for Main UI (Aero glass across all themes)
        local isAdaptive = (targetTheme.IsAdaptive == true)
        local winTrans   = isAdaptive and 0.30 or 0.25
        local titleTrans = isAdaptive and 0.25 or 0.20
        local bodyTrans  = isAdaptive and 0.40 or 0.35
        local navTrans   = isAdaptive and 0.35 or 0.30
        local drawerTrans= isAdaptive and 0.30 or 0.25

        pcall(function()
            if Window and Window.Parent then
                TweenService:Create(Window, tweenInfo, { BackgroundTransparency = winTrans }):Play()
            end
            if TitleBar and TitleBar.Parent then
                TweenService:Create(TitleBar, tweenInfo, { BackgroundTransparency = titleTrans }):Play()
                local tGrad = TitleBar:FindFirstChildOfClass("UIGradient")
                if tGrad then
                    tGrad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, targetTheme.TitleGradTop or Color3.fromRGB(42, 48, 62)),
                        ColorSequenceKeypoint.new(1, targetTheme.TitleGradBot or Color3.fromRGB(22, 26, 34))
                    })
                end
            end
            if Body and Body.Parent then
                TweenService:Create(Body, tweenInfo, { BackgroundTransparency = bodyTrans }):Play()
            end
            if NavBar and NavBar.Parent then
                TweenService:Create(NavBar, tweenInfo, { BackgroundTransparency = navTrans }):Play()
                local nGrad = NavBar:FindFirstChildOfClass("UIGradient")
                if nGrad then
                    nGrad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, targetTheme.NavGradTop or Color3.fromRGB(32, 38, 52)),
                        ColorSequenceKeypoint.new(1, targetTheme.NavGradBot or Color3.fromRGB(16, 20, 28))
                    })
                end
            end
            if logoBox and logoBox.Parent then
                local bGrad = logoBox:FindFirstChildOfClass("UIGradient")
                if bGrad then
                    bGrad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, targetTheme.BannerGradTop or Color3.fromRGB(26, 38, 62)),
                        ColorSequenceKeypoint.new(1, targetTheme.BannerGradBot or Color3.fromRGB(14, 18, 26))
                    })
                end
            end
            if Drawer and Drawer.Parent then
                TweenService:Create(Drawer, tweenInfo, { BackgroundTransparency = drawerTrans }):Play()
                local dH = Drawer:FindFirstChild("Frame")
                if dH then
                    local dGrad = dH:FindFirstChildOfClass("UIGradient")
                    if dGrad then
                        dGrad.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, targetTheme.TitleGradTop or Color3.fromRGB(36, 42, 54)),
                            ColorSequenceKeypoint.new(1, targetTheme.SectionBg or Color3.fromRGB(26, 32, 46))
                        })
                    end
                end
            end
            if Sidebar and Sidebar.Parent then
                TweenService:Create(Sidebar, tweenInfo, { BackgroundTransparency = bodyTrans }):Play()
            end
            if DrawerScroll and DrawerScroll.Parent then
                TweenService:Create(DrawerScroll, tweenInfo, { BackgroundTransparency = 1 }):Play()
            end
            if ContentArea and ContentArea.Parent then
                TweenService:Create(ContentArea, tweenInfo, { BackgroundTransparency = 1 }):Play()
            end
        end)

        -- Notify external modules (Music_Handler HUD, Billboard, etc.)
        for _, cb in ipairs(themeCallbacks) do
            pcall(cb, targetTheme, isDark, tweenDuration)
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
                    Flags               = Shared.Flags or {},
                    SpotifyToken        = Shared.Config.SpotifyToken or "",
                    SpotifyRefreshToken = Shared.Config.SpotifyRefreshToken or "",
                    SpotifyClientID     = Shared.Config.SpotifyClientID or "",
                    LastFMUser          = Shared.Config.LastFMUser or "",
                    DarkMode            = isDark,
                    ThemeMode           = themeMode,
                    Keybinds            = {}
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
                local raw = readfile(CONFIG_FILE)
                if not raw or #raw < 2 then return end
                local ok, data = pcall(function() return Http:JSONDecode(raw) end)
                if ok and data and type(data) == "table" then
                    Shared.Config.SpotifyToken        = data.SpotifyToken or ""
                    Shared.Config.SpotifyRefreshToken = data.SpotifyRefreshToken or ""
                    Shared.Config.SpotifyClientID     = data.SpotifyClientID or ""
                    Shared.Config.LastFMUser          = data.LastFMUser or ""

                    if data.ThemeMode == "Adaptive" then
                        themeMode = "Adaptive"
                        local pal = generateAdaptivePalette(currentAdaptiveTrack)
                        applyThemeTransition(pal, 0.25)
                    elseif data.ThemeMode == "Light" or data.DarkMode == false then
                        themeMode = "Light"
                        applyThemeTransition(LightTheme, 0.25)
                    else
                        themeMode = "Dark"
                        applyThemeTransition(DarkTheme, 0.25)
                    end

                    if data.Flags and type(data.Flags) == "table" then
                        for k, v in pairs(data.Flags) do
                            Shared.Flags[k] = v
                            -- Restore toggles
                            if Shared.Toggles[k] and Shared.Toggles[k].SetToggle and type(v) == "boolean" then
                                pcall(Shared.Toggles[k].SetToggle, v, true)
                            end
                            -- Restore sliders (FPSCap, MasterVolume, FieldOfView, Game Sliders, etc.)
                            if Shared.Sliders[k] and Shared.Sliders[k].SetValue and type(v) == "number" then
                                pcall(Shared.Sliders[k].SetValue, v, true)
                            end
                        end
                    end

                    if data.Keybinds and type(data.Keybinds) == "table" then
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

    -- ── NOTIFICATION STACK (DYNAMIC HORIZONTAL AUTO-SCALE) ────────
    local NotifyHolder = Instance.new("Frame")
    NotifyHolder.Name                   = "NotifyHolder"
    NotifyHolder.Size                   = UDim2.new(0, 480, 1, -20)
    NotifyHolder.Position               = UDim2.new(1, -490, 0, 10)
    NotifyHolder.BackgroundTransparency = 1
    NotifyHolder.ZIndex                 = 100
    NotifyHolder.Parent                 = ScreenGui

    local NotifyLayout = Instance.new("UIListLayout")
    NotifyLayout.SortOrder           = Enum.SortOrder.LayoutOrder
    NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    NotifyLayout.VerticalAlignment   = Enum.VerticalAlignment.Bottom
    NotifyLayout.Padding             = UDim.new(0, 6)
    NotifyLayout.Parent              = NotifyHolder

    local TextService = game:GetService("TextService")
    local notifyCounter = 0
    local lastNotificationKey = ""
    local lastNotificationTime = 0

    local function sendNotification(title, message, isEnabled)
        local key = tostring(title) .. "::" .. tostring(message) .. "::" .. tostring(isEnabled)
        local now = tick()
        if key == lastNotificationKey and (now - lastNotificationTime) < 0.40 then
            return
        end
        lastNotificationKey = key
        lastNotificationTime = now

        notifyCounter = notifyCounter + 1
        local order = notifyCounter

        local titleStr = (isEnabled == true and "[✔] " or (isEnabled == false and "[✖] " or "[i] ")) .. tostring(title)
        local msgStr   = tostring(message or "")

        local titleBounds = TextService:GetTextSize(titleStr, 11, Enum.Font.Code, Vector2.new(2000, 20))
        local msgBounds   = TextService:GetTextSize(msgStr, 11, Enum.Font.Code, Vector2.new(2000, 24))
        local targetW     = math.clamp(math.max(titleBounds.X + 32, msgBounds.X + 24, 240), 240, 460)

        local toast = Instance.new("Frame")
        toast.Name             = "Toast_" .. tostring(order)
        toast.Size             = UDim2.new(0, targetW, 0, 46)
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
        tLbl.Text                   = titleStr
        tLbl.TextColor3             = isEnabled == true and Color3.fromRGB(0,120,40) or (isEnabled == false and Color3.fromRGB(180,20,20) or C.SectionText)
        tLbl.Font                   = Enum.Font.Code; tLbl.TextSize = 11
        tLbl.TextXAlignment         = Enum.TextXAlignment.Left; tLbl.ZIndex = 103; tLbl.Parent = hBar

        local dLbl = Instance.new("TextLabel")
        dLbl.Size                   = UDim2.new(1,-12,0,24); dLbl.Position = UDim2.new(0,6,0,20)
        dLbl.BackgroundTransparency = 1; dLbl.Text = msgStr
        dLbl.TextColor3             = isDark and Color3.fromRGB(210,220,240) or Color3.fromRGB(30,30,50)
        dLbl.Font                   = Enum.Font.Code; dLbl.TextSize = 11
        dLbl.TextXAlignment         = Enum.TextXAlignment.Left; dLbl.ZIndex = 102; dLbl.Parent = toast

        TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play()
        task.delay(2.8, function()
            if toast and toast.Parent then
                local f = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(0, targetW, 0, 0), BackgroundTransparency = 1})
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
    Window.BackgroundTransparency = 0.25
    Window.BorderSizePixel  = 2; Window.BorderColor3 = C.WinBorder
    Window.ClipsDescendants = true; Window.Parent = ScreenGui
    registerThemed(Window, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder" })

    -- TOPBAR
    local TITLE_H = 28
    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"; TitleBar.Size = UDim2.new(1,0,0,TITLE_H)
    TitleBar.BackgroundColor3 = C.TitleBar; TitleBar.BorderSizePixel = 1
    TitleBar.BackgroundTransparency = 0.20
    TitleBar.BorderColor3     = Color3.fromRGB(140,140,140); TitleBar.Parent = Window
    registerThemed(TitleBar, { BackgroundColor3 = "TitleBar" })

    local titleGrad = Instance.new("UIGradient")
    titleGrad.Name = "TitleGradient"
    titleGrad.Rotation = 90
    titleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.TitleGradTop or Color3.fromRGB(42, 48, 62)),
        ColorSequenceKeypoint.new(1, C.TitleGradBot or Color3.fromRGB(22, 26, 34))
    })
    titleGrad.Parent = TitleBar

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
        b.BackgroundTransparency = 0.25
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
    local savedWindowHeight = WIN_H
    local function animClose()
        if not isOpen then return end
        isOpen = false
        savedWindowHeight = math.max(Window.AbsoluteSize.Y, WIN_H)
        local curW = Window.AbsoluteSize.X
        pcall(function()
            TweenService:Create(Window, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, curW, 0, 0),
                BackgroundTransparency = 1
            }):Play()
        end)
        task.delay(0.22, function()
            if not isOpen then
                Window.Visible = false
            end
        end)
    end

    local function animOpen()
        if isOpen then return end
        isOpen = true
        Window.Visible = true
        local curW = math.max(Window.AbsoluteSize.X, WIN_W)
        Window.Size = UDim2.new(0, curW, 0, 0)
        Window.BackgroundTransparency = 1
        pcall(function()
            TweenService:Create(Window, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, curW, 0, savedWindowHeight),
                BackgroundTransparency = C.IsAdaptive and 0.30 or 0.25
            }):Play()
        end)
    end

    local minimized = false
    winBtns["close"].MouseButton1Click:Connect(function()
        minimized = true
        local curW = Window.AbsoluteSize.X
        savedWindowHeight = math.max(Window.AbsoluteSize.Y, WIN_H)
        pcall(function()
            TweenService:Create(Window, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, curW, 0, TITLE_H)
            }):Play()
        end)
    end)
    winBtns["min"].MouseButton1Click:Connect(function()
        minimized = not minimized
        local curW = Window.AbsoluteSize.X
        pcall(function()
            if minimized then
                savedWindowHeight = math.max(Window.AbsoluteSize.Y, WIN_H)
                TweenService:Create(Window, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, curW, 0, TITLE_H)
                }):Play()
            else
                TweenService:Create(Window, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, curW, 0, savedWindowHeight)
                }):Play()
            end
        end)
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
    NavBar.BackgroundTransparency = 0.30
    NavBar.BorderColor3 = Color3.fromRGB(140,160,200); NavBar.Parent = Window
    registerThemed(NavBar, { BackgroundColor3 = "NavBar" })

    local navGrad = Instance.new("UIGradient")
    navGrad.Name = "NavGradient"
    navGrad.Rotation = 90
    navGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.NavGradTop or Color3.fromRGB(32, 38, 52)),
        ColorSequenceKeypoint.new(1, C.NavGradBot or Color3.fromRGB(16, 20, 28))
    })
    navGrad.Parent = NavBar

    local NavTabLabel = Instance.new("TextLabel")
    NavTabLabel.Size = UDim2.new(0.5,0,1,0); NavTabLabel.Position = UDim2.new(0,10,0,0)
    NavTabLabel.BackgroundTransparency = 1; NavTabLabel.Text = "Main"
    NavTabLabel.TextColor3 = C.NavText; NavTabLabel.Font = Enum.Font.Code
    NavTabLabel.TextSize = 12; NavTabLabel.TextXAlignment = Enum.TextXAlignment.Left
    NavTabLabel.Parent = NavBar
    registerThemed(NavTabLabel, { TextColor3 = "NavText" })

    -- ── THEME SWITCHER BUTTON (Clean Text Variant) ──────────────────
    local themeBtn = Instance.new("TextButton")
    themeBtn.Name                   = "ThemeToggleBtn"
    themeBtn.Size                   = UDim2.new(0, 60, 0, 20)
    themeBtn.Position               = UDim2.new(1, -150, 0.5, -10)
    themeBtn.BackgroundTransparency = 1
    themeBtn.BorderSizePixel        = 0
    themeBtn.Text                   = "[Dark]"
    themeBtn.Font                   = Enum.Font.Code
    themeBtn.TextSize               = 11
    themeBtn.TextColor3             = C.NavLink
    themeBtn.ZIndex                 = 3
    themeBtn.Parent                 = NavBar
    registerThemed(themeBtn, { TextColor3 = "NavLink" })

    themeBtn.MouseEnter:Connect(function()
        TweenService:Create(themeBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { TextColor3 = C.NavLinkHover }):Play()
    end)
    themeBtn.MouseLeave:Connect(function()
        TweenService:Create(themeBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { TextColor3 = C.NavLink }):Play()
    end)

    local function updateThemeButtonIcon()
        if themeMode == "Light" then
            themeBtn.Text = "[Light]"
        elseif themeMode == "Adaptive" then
            themeBtn.Text = "[Adapt]"
        else
            themeBtn.Text = "[Dark]"
        end
    end

    themeBtn.MouseButton1Click:Connect(function()
        if themeMode == "Dark" then
            themeMode = "Light"
            applyThemeTransition(LightTheme, 0.25)
            updateThemeButtonIcon()
            sendNotification("Theme Engine", "[Light] Theme Applied", true)
        elseif themeMode == "Light" then
            themeMode = "Adaptive"
            local pal = generateAdaptivePalette(currentAdaptiveTrack or (Shared.CurrentTrack and Shared.CurrentTrack()))
            applyThemeTransition(pal, 0.65)
            updateThemeButtonIcon()
            sendNotification("Theme Engine", "[Adapt] Semi-Translucent UI Active", true)
        else
            themeMode = "Dark"
            applyThemeTransition(DarkTheme, 0.25)
            updateThemeButtonIcon()
            sendNotification("Theme Engine", "[Dark] Theme Applied", true)
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
    Body.BackgroundTransparency = 0.35
    Body.ClipsDescendants = true; Body.Parent = Window
    registerThemed(Body, { BackgroundColor3 = "BodyBg" })

    -- SIDEBAR
    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0,SIDEBAR_W,1,0); Sidebar.BackgroundColor3 = C.BodyBg
    Sidebar.BackgroundTransparency = 0.35
    Sidebar.BorderSizePixel = 0; Sidebar.ClipsDescendants = true; Sidebar.Parent = Body
    registerThemed(Sidebar, { BackgroundColor3 = "BodyBg" })

    -- Checkered pattern covering full sidebar height (dynamically fills to any scale)
    local SidebarPattern = Instance.new("Frame")
    SidebarPattern.Size = UDim2.new(1, 0, 1, 0)
    SidebarPattern.BackgroundTransparency = 1
    SidebarPattern.ZIndex = 2
    SidebarPattern.ClipsDescendants = true
    SidebarPattern.Parent = Sidebar

    local CELL = 9
    for r = 0, 120 do
        for c = 0, 12 do
            if (r + c) % 2 == 1 then
                local cell = Instance.new("Frame")
                cell.Size = UDim2.new(0, CELL, 0, CELL)
                cell.Position = UDim2.new(0, c * CELL, 0, r * CELL)
                cell.BorderSizePixel = 0
                cell.BackgroundColor3 = C.SidebarCellB
                cell.Parent = SidebarPattern
                registerThemed(cell, { BackgroundColor3 = "SidebarCellB" })
            end
        end
    end

    local SBorder = Instance.new("Frame")
    SBorder.Size = UDim2.new(0,2,1,0); SBorder.Position = UDim2.new(1,-2,0,0)
    SBorder.BackgroundColor3 = C.SidebarBorder; SBorder.BorderSizePixel = 0
    SBorder.ZIndex = 5; SBorder.Parent = Sidebar
    registerThemed(SBorder, { BackgroundColor3 = "SidebarBorder" })

    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Size = UDim2.new(1,-4,1,0); TabContainer.BackgroundTransparency = 1
    TabContainer.BorderSizePixel = 0; TabContainer.ScrollBarThickness = 0
    TabContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabContainer.CanvasSize = UDim2.new(0,0,0,0)
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
    ContentArea.BackgroundTransparency = 1
    ContentArea.BorderSizePixel      = 0
    ContentArea.ScrollBarThickness   = 0
    ContentArea.ScrollBarImageTransparency = 1
    ContentArea.CanvasSize           = UDim2.new(0,0,0,0)
    ContentArea.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    ContentArea.ClipsDescendants     = true
    ContentArea.Parent               = Body
    registerThemed(ContentArea, { BackgroundColor3 = "BodyBg" })

    local CAPad = Instance.new("UIPadding")
    CAPad.PaddingTop    = UDim.new(0, 6)
    CAPad.PaddingLeft   = UDim.new(0, 6)
    CAPad.PaddingRight  = UDim.new(0, 6)
    CAPad.PaddingBottom = UDim.new(0, 16)
    CAPad.Parent        = ContentArea

    -- SETTINGS DRAWER
    local Drawer = Instance.new("Frame")
    Drawer.Name = "Drawer"; Drawer.Size = UDim2.new(1,-SIDEBAR_W,1,0)
    Drawer.Position = UDim2.new(0,SIDEBAR_W,-1,0)
    Drawer.BackgroundColor3 = C.DrawerBg; Drawer.BorderSizePixel = 1
    Drawer.BackgroundTransparency = 0.25
    Drawer.BorderColor3 = C.SidebarBorder; Drawer.ZIndex = 20
    Drawer.Visible = false; Drawer.ClipsDescendants = true; Drawer.Parent = Body
    registerThemed(Drawer, { BackgroundColor3 = "DrawerBg", BorderColor3 = "SidebarBorder" })

    local DHeader = Instance.new("Frame")
    DHeader.Size = UDim2.new(1,0,0,24); DHeader.BackgroundColor3 = C.SectionBg
    DHeader.BackgroundTransparency = 0.25
    DHeader.BorderSizePixel = 1; DHeader.BorderColor3 = C.SidebarBorder
    DHeader.ZIndex = 21; DHeader.Parent = Drawer
    registerThemed(DHeader, { BackgroundColor3 = "SectionBg", BorderColor3 = "SidebarBorder" })

    local dGrad = Instance.new("UIGradient")
    dGrad.Name = "DHeaderGradient"
    dGrad.Rotation = 90
    dGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.TitleGradTop or Color3.fromRGB(36, 42, 54)),
        ColorSequenceKeypoint.new(1, C.SectionBg)
    })
    dGrad.Parent = DHeader

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
    DClose.BackgroundTransparency = 0.25
    DClose.TextColor3 = C.BtnText; DClose.Font = Enum.Font.Code
    DClose.TextSize = 10; DClose.BorderSizePixel = 1; DClose.BorderColor3 = C.BtnBorder
    DClose.ZIndex = 22; DClose.Parent = DHeader
    registerThemed(DClose, { BackgroundColor3 = "BtnBg", TextColor3 = "BtnText", BorderColor3 = "BtnBorder" })

    local DrawerScroll = Instance.new("ScrollingFrame")
    DrawerScroll.Size = UDim2.new(1,0,1,-24); DrawerScroll.Position = UDim2.new(0,0,0,24)
    DrawerScroll.BackgroundColor3 = C.DrawerBg; DrawerScroll.BorderSizePixel = 0
    DrawerScroll.BackgroundTransparency = 1
    DrawerScroll.ScrollBarThickness = 0
    DrawerScroll.ScrollBarImageTransparency = 1
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
            pcall(function() Drawer.Position = UDim2.new(0, SIDEBAR_W, 0, 0) end)
        else
            pcall(function()
                Drawer.Position = UDim2.new(0, SIDEBAR_W, -1, 0)
                Drawer.Visible = false
            end)
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

    local isBladeBall = (game.PlaceId == 13772394625 or game.PlaceId == 14732610803 or game.PlaceId == 15131065025 or game.PlaceId == 15264892126 or game.PlaceId == 17135832729 or game.PlaceId == 15552588147 or game.GameId == 4777817887)
    if Shared.IsBladeBall ~= nil then isBladeBall = Shared.IsBladeBall end

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
    if isBladeBall then
        table.insert(tabDefs, {name="Blade Ball", order=curOrder})
        curOrder = curOrder + 1
    end
    table.insert(tabDefs, {name="Spy",      order=curOrder})
    table.insert(tabDefs, {name="Music",    order=curOrder + 1})
    table.insert(tabDefs, {name="Troll",    order=curOrder + 2})
    table.insert(tabDefs, {name="Keybinds", order=curOrder + 3})

    local function switchTab(name)
        if activeTab == name then return end
        activeTab = name
        NavTabLabel.Text = name

        ContentArea.CanvasPosition = Vector2.zero

        for tName, tFrame in pairs(Tabs) do
            if tName == name then
                tFrame.Position = UDim2.new(0, 0, 0, 0)
                tFrame.Visible = true
            else
                tFrame.Visible = false
            end
        end

        for tName, tBtn in pairs(TabBtns) do
            if tName == name then
                TweenService:Create(tBtn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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
        btn.BackgroundTransparency = 0.25
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
        quadFrame.Name = "QuadGrid"; quadFrame.Size = UDim2.new(1,-8,0,0)
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
    logoBox.Size = UDim2.new(1,-8,0,76); logoBox.BackgroundColor3 = C.BannerBg
    logoBox.BackgroundTransparency = 0.35
    logoBox.BorderSizePixel = 1; logoBox.BorderColor3 = C.WinBorder
    logoBox.LayoutOrder = 1; logoBox.Parent = mainTab
    registerThemed(logoBox, { BackgroundColor3 = "BannerBg", BorderColor3 = "WinBorder" })

    local bannerGrad = Instance.new("UIGradient")
    bannerGrad.Name = "BannerGradient"
    bannerGrad.Rotation = 45
    bannerGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.BannerGradTop or Color3.fromRGB(26, 38, 62)),
        ColorSequenceKeypoint.new(1, C.BannerGradBot or Color3.fromRGB(14, 18, 26))
    })
    bannerGrad.Parent = logoBox

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
        lbl.BackgroundTransparency = 0.30
        lbl.TextColor3 = C.SectionText; lbl.Font = Enum.Font.Code; lbl.TextSize = 11
        lbl.Text = "  ["..labelText.."]"; lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BorderSizePixel = 1; lbl.BorderColor3 = C.SidebarBorder
        lbl.LayoutOrder = order or 0; lbl.Parent = parent
        registerThemed(lbl, { BackgroundColor3 = "SectionBg", TextColor3 = "SectionText", BorderColor3 = "SidebarBorder" })

        local secGrad = Instance.new("UIGradient")
        secGrad.Name = "SectionGradient"
        secGrad.Rotation = 0
        secGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.65, Color3.fromRGB(240, 240, 240)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180))
        })
        secGrad.Parent = lbl

        return lbl
    end

    local function makeToggle(parent, labelText, flagKey, order, callback)
        local row = Instance.new("Frame")
        row.Name = "Toggle_"..flagKey; row.Size = UDim2.new(1,0,0,26)
        row.BackgroundColor3 = C.RowBg; row.BorderSizePixel = 1; row.BorderColor3 = C.RowBorder
        row.BackgroundTransparency = 0.35
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
        box.BackgroundTransparency = 0.25
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

        local initialState = (Shared.Flags[flagKey] ~= nil and type(Shared.Flags[flagKey]) == "boolean") and Shared.Flags[flagKey] or false
        Shared.Flags[flagKey] = initialState
        if initialState then
            box.Text = "X"
            box.BackgroundColor3 = isDark and Color3.fromRGB(30, 60, 100) or Color3.fromRGB(220, 235, 255)
        end

        local function setToggle(state, suppressNotify)
            Shared.Flags[flagKey] = state
            box.Text = state and "X" or ""
            box.BackgroundColor3 = state and (isDark and Color3.fromRGB(30, 60, 100) or Color3.fromRGB(220, 235, 255)) or C.BodyBg
            if callback then pcall(callback, state) end
            if not suppressNotify then sendNotification(labelText, state and "ENABLED" or "DISABLED", state) end
            saveConfigDebounced()
        end

        local lastClick = 0
        local overlay = Instance.new("TextButton")
        overlay.Name = "ClickOverlay"
        overlay.Size = UDim2.new(1,0,1,0)
        overlay.BackgroundTransparency = 1
        overlay.Text = ""
        overlay.ZIndex = 10
        overlay.Parent = row

        overlay.MouseButton1Click:Connect(function()
            local now = tick()
            if now - lastClick < 0.15 then return end
            lastClick = now
            setToggle(not Shared.Flags[flagKey])
        end)

        Shared.Toggles[flagKey] = {Name=labelText, SetToggle=setToggle, Key=nil}

        if initialState and callback then
            task.spawn(function()
                pcall(callback, true)
            end)
        end

        return row, setToggle
    end

    local function makeSlider(parent, labelText, flagKey, minVal, maxVal, defaultVal, order, callback)
        local currentVal = (Shared.Flags[flagKey] ~= nil and type(Shared.Flags[flagKey]) == "number") and Shared.Flags[flagKey] or defaultVal
        Shared.Flags[flagKey] = currentVal

        local row = Instance.new("Frame")
        row.Name = "Slider_"..flagKey; row.Size = UDim2.new(1,0,0,36)
        row.BackgroundColor3 = C.RowBg; row.BorderSizePixel = 1; row.BorderColor3 = C.RowBorder
        row.BackgroundTransparency = 0.35
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
        valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(currentVal)
        valLbl.TextColor3 = C.Accent; valLbl.Font = Enum.Font.Code
        valLbl.TextSize = 11; valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.Parent = row
        registerThemed(valLbl, { TextColor3 = "Accent" })

        local track = Instance.new("Frame")
        track.Name = "Track"; track.Size = UDim2.new(1,-12,0,8); track.Position = UDim2.new(0,6,0,22)
        track.BackgroundColor3 = Color3.fromRGB(180, 190, 205); track.BorderSizePixel = 1
        track.BorderColor3 = Color3.fromRGB(130, 140, 160); track.Parent = row

        local initialPct = math.clamp((currentVal - minVal) / math.max(maxVal - minVal, 1), 0, 1)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(initialPct, 0, 1, 0)
        fill.BackgroundColor3 = C.Accent; fill.BorderSizePixel = 0; fill.Parent = track
        registerThemed(fill, { BackgroundColor3 = "Accent" })

        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = C.RowHover }):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = C.RowBg }):Play()
        end)

        local function setValue(val, silent)
            val = math.clamp(math.floor(val), minVal, maxVal)
            Shared.Flags[flagKey] = val
            local pct = math.clamp((val - minVal) / math.max(maxVal - minVal, 1), 0, 1)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            valLbl.Text = tostring(val)
            if callback then pcall(callback, val) end
            if not silent then saveConfigDebounced() end
        end

        local dragging = false
        local function update(inputX)
            local pct = math.clamp((inputX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            local val = math.floor(minVal + pct * (maxVal - minVal))
            setValue(val, false)
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

        Shared.Sliders[flagKey] = {
            Name     = labelText,
            Min      = minVal,
            Max      = maxVal,
            SetValue = setValue,
            Row      = row
        }

        if callback then
            task.spawn(function()
                pcall(callback, currentVal)
            end)
        end

        return row
    end

    local function makeButton(parent, labelText, order, callback)
        local btn = Instance.new("TextButton")
        btn.Name = "Btn_"..labelText:gsub("%s+","_"); btn.Size = UDim2.new(1,0,0,26)
        btn.BackgroundColor3 = C.BtnBg; btn.Text = labelText; btn.TextColor3 = C.BtnText
        btn.BackgroundTransparency = 0.25
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
    makeToggle(DrawerScroll, "Disable Conflicting Game GUIs (Prevent Overlap)", "DisableConflictingGUIs", 3, function(state)
        disableConflictingGUIs = state
        if state then
            scanAndSuppressAllConflictingGUIs()
            sendNotification("Anti-Overlap Engine", "Conflicting game GUIs suppressed", true)
        else
            restoreSuppressedGameGUIs()
            sendNotification("Anti-Overlap Engine", "Game GUIs restored", false)
        end
    end)
    makeToggle(DrawerScroll, "Semi-Translucent Adaptive UI (Song Cover Sync)", "AdaptiveTheme", 4, function(state)
        if state then
            themeMode = "Adaptive"
            local pal = generateAdaptivePalette(currentAdaptiveTrack or (Shared.CurrentTrack and Shared.CurrentTrack()))
            applyThemeTransition(pal, 0.65)
            updateThemeButtonIcon()
            sendNotification("Theme Engine", "[Adapt] Semi-Translucent UI Enabled", true)
        else
            themeMode = isDark and "Dark" or "Light"
            applyThemeTransition(isDark and DarkTheme or LightTheme, 0.25)
            updateThemeButtonIcon()
            sendNotification("Theme Engine", isDark and "Dark Theme Restored" or "Light Theme Restored", false)
        end
        saveConfigDebounced()
    end)
    makeButton(DrawerScroll, "Save Config File (Manual)", 4, function()
        saveConfigDirect(); sendNotification("Config Manager", "Saved to FihUi_Config.json", true)
    end)
    makeButton(DrawerScroll, "Unload / Force Close Menu", 5, function()
        saveConfigDirect()
        for k in pairs(Shared.Flags) do Shared.Flags[k] = false end
        if Shared.CleanupAll then
            Shared.CleanupAll()
        else
            if Shared.GUI then Shared.GUI:Destroy() end
        end
    end)

    -- ── PERFORMANCE & FPS BOOST ENGINE ──────────────────────────
    makeSection(DrawerScroll, "Performance & FPS Boost", 10)

    local originalMaterials = {}
    local function isProtectedMapGeometry(obj)
        if not obj then return true end
        if obj:IsA("MeshPart") or obj:IsA("UnionOperation") or obj:FindFirstChildOfClass("SpecialMesh") then
            return true
        end
        local p = obj.Parent
        while p and p ~= workspace do
            local n = p.Name:lower()
            if n == "map" or n == "maps" or n == "lobby" or n == "environment" or n == "buildings" or n == "normal" or n == "spawns" then
                return true
            end
            p = p.Parent
        end
        return false
    end

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
                if (obj:IsA("Part") or obj:IsA("WedgePart") or obj:IsA("CornerWedgePart") or obj:IsA("TrussPart")) and not isProtectedMapGeometry(obj) then
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
                    if not isProtectedMapGeometry(obj) and obj.Enabled then
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
                if (obj:IsA("Decal") or obj:IsA("Texture")) and not isProtectedMapGeometry(obj) then
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
    Shared.GUI = ScreenGui
    Shared.Tabs = Tabs
    Shared.QuadCols = QuadCols
    Shared.MakeSection = makeSection
    Shared.MakeToggle = makeToggle
    Shared.MakeSlider = makeSlider
    Shared.MakeButton = makeButton
    Shared.RegisterThemed = registerThemed
    Shared.ApplyThemeTransition = applyThemeTransition
    Shared.DarkTheme = DarkTheme
    Shared.LightTheme = LightTheme
    Shared.CurrentTheme = function() return C end
    Shared.IsDark = function() return isDark end
    Shared.RegisterThemeCallback = function(cb) table.insert(themeCallbacks, cb) end
    Shared.Notify = sendNotification
    Shared.SendNotification = sendNotification
    Shared.StyleRobloxCoreUI = styleRobloxCoreUI
    Shared.RestoreDefaultRobloxCoreUI = restoreDefaultRobloxCoreUI

    switchTab("Main")
    print("[UI_Handler] Loaded -- Dark Mode Engine, Smooth Transitions, Hover Effects Active")
end

