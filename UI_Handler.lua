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

    local Services     = Shared.Services or {}
    local TweenService = Services.TweenService or game:GetService("TweenService")
    local TweenSvc     = TweenService
    local UserInput    = Services.UserInput or game:GetService("UserInputService")
    local CoreGui      = Services.CoreGui
    local Http         = Services.Http or game:GetService("HttpService")
    local RunService   = Services.RunService or game:GetService("RunService")
    local Players      = Services.Players or game:GetService("Players")
    local StarterGui   = game:GetService("StarterGui")
    local Lighting     = Services.Lighting or game:GetService("Lighting")

    if not CoreGui then
        pcall(function() CoreGui = game:GetService("CoreGui") end)
    end

    if Shared.CleanupAll then
        pcall(Shared.CleanupAll)
    elseif CoreGui and CoreGui:FindFirstChild("IE7_Menu") then
        pcall(function() CoreGui:FindFirstChild("IE7_Menu"):Destroy() end)
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "IE7_Menu"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true

    local isStudio = RunService:IsStudio()
    local gethui = not isStudio and (rawget(getfenv and getfenv(0) or _G, "gethui") or (getgenv and getgenv().gethui))
    local targetParent = nil
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then targetParent = h end
    end
    if not targetParent and not isStudio and CoreGui then
        local ok, _ = pcall(function() ScreenGui.Parent = CoreGui end)
        if ok and ScreenGui.Parent == CoreGui then
            targetParent = CoreGui
        end
    end
    if not targetParent then
        local lp = Shared.Player or Players.LocalPlayer
        targetParent = (lp and lp:FindFirstChildOfClass("PlayerGui"))
                    or (lp and lp:WaitForChild("PlayerGui", 5))
    end
    ScreenGui.Parent = targetParent
    ScreenGui.Enabled = true
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
            if n == "topbar" or n == "tabbar" or n == "scoreboard" or n == "leaderboard" or n == "playerlist" then
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
                local mainGui = pGui:FindFirstChild("MainGUI") or pGui:FindFirstChild("MainGui") or pGui:FindFirstChild("Main")
                if mainGui then
                    for _, d in ipairs(mainGui:GetChildren()) do
                        checkAndSuppressConflictingGui(d)
                        if d.Name == "Game" or d.Name == "Lobby" then
                            for _, sub in ipairs(d:GetChildren()) do
                                checkAndSuppressConflictingGui(sub)
                            end
                        end
                    end
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

        pcall(function()
            if CoreGui and CoreGui:IsA("Instance") then
                local descConn = CoreGui.DescendantAdded:Connect(function(desc)
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
                if Shared.AddCleanup then Shared.AddCleanup(descConn) end
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
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    local WIN_W = math.clamp(math.floor(vp.X * 0.60), 560, 780)
    local WIN_H = math.clamp(math.floor(vp.Y * 0.60), 380, 460)

    local Window = Instance.new("Frame")
    Window.Name             = "Window"
    Window.AnchorPoint      = Vector2.new(0.5, 0.5)
    Window.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
    Window.Position         = UDim2.new(0.5, 0, 0.5, 0)
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

    do  -- DRAG WINDOW WITH SCREEN BOUNDARY CONSTRAINTS
        local drag, ds, sp = false, nil, nil
        TitleBar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag = true; ds = i.Position; sp = Window.Position
            end
        end)
        TitleBar.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag = false
            end
        end)
        UserInput.InputChanged:Connect(function(i)
            if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - ds
                local curCam = workspace.CurrentCamera
                local curVp = (curCam and curCam.ViewportSize) or Vector2.new(1920, 1080)
                local curW = Window.AbsoluteSize.X
                local curH = Window.AbsoluteSize.Y
                local halfW = curW / 2
                local halfH = curH / 2

                local rawX = (sp.X.Scale * curVp.X) + sp.X.Offset + d.X
                local rawY = (sp.Y.Scale * curVp.Y) + sp.Y.Offset + d.Y

                local minX = halfW + 4
                local maxX = math.max(curVp.X - halfW - 4, minX)
                local minY = halfH + 4
                local maxY = math.max(curVp.Y - halfH - 4, minY)

                local clampedX = math.clamp(rawX, minX, maxX)
                local clampedY = math.clamp(rawY, minY, maxY)

                Window.Position = UDim2.new(0, clampedX, 0, clampedY)
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
                local curCam = workspace.CurrentCamera
                local curVp = (curCam and curCam.ViewportSize) or Vector2.new(1920, 1080)
                local maxW = math.max(curVp.X - 20, 480)
                local maxH = math.max(curVp.Y - 20, 260)
                local newW = math.clamp(rStartSize.X + d.X, 480, maxW)
                local newH = math.clamp(rStartSize.Y + d.Y, 260, maxH)
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

    local isMaximized = false
    local savedNormalSize = UDim2.new(0, WIN_W, 0, WIN_H)
    local savedNormalPos  = Window.Position

    local minimized = false
    -- 1. MINIMIZE BUTTON [-]: Collapses window body down to title bar
    winBtns["min"].MouseButton1Click:Connect(function()
        minimized = not minimized
        local curW = Window.AbsoluteSize.X
        pcall(function()
            if minimized then
                savedWindowHeight = math.max(Window.AbsoluteSize.Y, WIN_H)
                TweenService:Create(Window, TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, curW, 0, TITLE_H)
                }):Play()
            else
                TweenService:Create(Window, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, curW, 0, savedWindowHeight)
                }):Play()
            end
        end)
    end)

    -- 2. MAXIMIZE BUTTON [ ]: Toggles maximized scale across viewport vs normal window size
    winBtns["max"].MouseButton1Click:Connect(function()
        isMaximized = not isMaximized
        minimized = false
        pcall(function()
            if isMaximized then
                savedNormalSize = Window.Size
                savedNormalPos  = Window.Position
                TweenService:Create(Window, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0.5, -420, 0.5, -280),
                    Size     = UDim2.new(0, 840, 0, 560)
                }):Play()
            else
                TweenService:Create(Window, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = savedNormalPos,
                    Size     = savedNormalSize
                }):Play()
            end
        end)
    end)

    -- 3. CLOSE BUTTON [X]: Smoothly animates and closes/hides the menu
    winBtns["close"].MouseButton1Click:Connect(function()
        animClose()
    end)

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
    ContentArea.ScrollBarThickness   = 4
    ContentArea.ScrollBarImageColor3 = Color3.fromRGB(100, 125, 170)
    ContentArea.ScrollBarImageTransparency = 0.4
    ContentArea.CanvasSize           = UDim2.new(0,0,0,0)
    ContentArea.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    ContentArea.ClipsDescendants     = true
    ContentArea.Parent               = Body
    registerThemed(ContentArea, { BackgroundColor3 = "BodyBg" })

    local CAPad = Instance.new("UIPadding")
    CAPad.PaddingTop    = UDim.new(0, 6)
    CAPad.PaddingLeft   = UDim.new(0, 14)
    CAPad.PaddingRight  = UDim.new(0, 16)
    CAPad.PaddingBottom = UDim.new(0, 20)
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

    local tabDefs = {
        {name="Menu",     order=1},
        {name="Player",   order=2},
        {name="Visuals",  order=3},
        {name="Music",    order=4},
        {name="Keybinds", order=5},
    }

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
        tabFrame.Size = UDim2.new(1, -30, 0, 0)
        tabFrame.AutomaticSize = Enum.AutomaticSize.Y
        tabFrame.BackgroundTransparency = 1
        tabFrame.Visible = false
        tabFrame.LayoutOrder = def.order
        tabFrame.Parent = ContentArea

        local tLayout = Instance.new("UIListLayout")
        tLayout.SortOrder = Enum.SortOrder.LayoutOrder; tLayout.Padding = UDim.new(0,6); tLayout.Parent = tabFrame

        if def.name ~= "Menu" then
            local quadFrame = Instance.new("Frame")
            quadFrame.Name = "QuadGrid"; quadFrame.Size = UDim2.new(1, 0, 0, 0)
            quadFrame.AutomaticSize = Enum.AutomaticSize.Y; quadFrame.BackgroundTransparency = 1
            quadFrame.LayoutOrder = 1; quadFrame.Parent = tabFrame

            local leftCol = Instance.new("Frame")
            leftCol.Name = "LeftCol"; leftCol.Size = UDim2.new(0.5, -6, 0, 0)
            leftCol.Position = UDim2.new(0, 0, 0, 0); leftCol.AutomaticSize = Enum.AutomaticSize.Y
            leftCol.BackgroundTransparency = 1; leftCol.Parent = quadFrame
            local lLayout = Instance.new("UIListLayout")
            lLayout.SortOrder = Enum.SortOrder.LayoutOrder; lLayout.Padding = UDim.new(0,6); lLayout.Parent = leftCol

            local rightCol = Instance.new("Frame")
            rightCol.Name = "RightCol"; rightCol.Size = UDim2.new(0.5, -6, 0, 0)
            rightCol.Position = UDim2.new(0.5, 6, 0, 0); rightCol.AutomaticSize = Enum.AutomaticSize.Y
            rightCol.BackgroundTransparency = 1; rightCol.Parent = quadFrame
            local rLayout = Instance.new("UIListLayout")
            rLayout.SortOrder = Enum.SortOrder.LayoutOrder; rLayout.Padding = UDim.new(0,6); rLayout.Parent = rightCol

            QuadCols[def.name] = {Left = leftCol, Right = rightCol}
        end

        if def.name == "Music" then
            btn.Visible = (Shared.Flags["EnableMusicTab"] == true)
        end

        Tabs[def.name] = tabFrame; TabBtns[def.name] = btn
        btn.MouseButton1Click:Connect(function() switchTab(def.name) end)
    end

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

    -- MENU TAB (User Profile & Fih Ui Header Card)
    local menuTab = Tabs["Menu"]
    if menuTab then
        local menuContainer = Instance.new("Frame")
        menuContainer.Name = "MenuContainer"
        menuContainer.Size = UDim2.new(1, 0, 0, 0)
        menuContainer.AutomaticSize = Enum.AutomaticSize.Y
        menuContainer.BackgroundTransparency = 1
        menuContainer.LayoutOrder = 1
        menuContainer.Parent = menuTab

        local mLayout = Instance.new("UIListLayout")
        mLayout.SortOrder = Enum.SortOrder.LayoutOrder
        mLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        mLayout.Padding = UDim.new(0, 12)
        mLayout.Parent = menuContainer

        -- Header Banner Card
        local headerCard = Instance.new("Frame")
        headerCard.Name = "HeaderCard"
        headerCard.Size = UDim2.new(1, -8, 0, 84)
        headerCard.BackgroundColor3 = C.BannerBg
        headerCard.BackgroundTransparency = 0.35
        headerCard.BorderSizePixel = 1
        headerCard.BorderColor3 = C.WinBorder
        headerCard.LayoutOrder = 1
        headerCard.Parent = menuContainer
        registerThemed(headerCard, { BackgroundColor3 = "BannerBg", BorderColor3 = "WinBorder" })

        local headerGrad = Instance.new("UIGradient")
        headerGrad.Name = "HeaderGradient"
        headerGrad.Rotation = 45
        headerGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, C.BannerGradTop or Color3.fromRGB(26, 38, 62)),
            ColorSequenceKeypoint.new(1, C.BannerGradBot or Color3.fromRGB(14, 18, 26))
        })
        headerGrad.Parent = headerCard

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.Size = UDim2.new(1, 0, 0, 46)
        titleLabel.Position = UDim2.new(0, 0, 0, 8)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "Fih Ui"
        titleLabel.TextColor3 = C.BannerTitle
        titleLabel.Font = Enum.Font.ArimoBold
        titleLabel.TextSize = 40
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = headerCard
        registerThemed(titleLabel, { TextColor3 = "BannerTitle" })

        local subLabel = Instance.new("TextLabel")
        subLabel.Name = "SubLabel"
        subLabel.Size = UDim2.new(1, 0, 0, 20)
        subLabel.Position = UDim2.new(0, 0, 0, 54)
        subLabel.BackgroundTransparency = 1
        subLabel.Text = "Keybind ] to close GUI"
        subLabel.TextColor3 = C.BannerSub
        subLabel.Font = Enum.Font.Code
        subLabel.TextSize = 12
        subLabel.TextXAlignment = Enum.TextXAlignment.Center
        subLabel.Parent = headerCard
        registerThemed(subLabel, { TextColor3 = "BannerSub" })

        -- Profile Card
        local profileCard = Instance.new("Frame")
        profileCard.Name = "ProfileCard"
        profileCard.Size = UDim2.new(1, -8, 0, 110)
        profileCard.BackgroundColor3 = C.RowBg
        profileCard.BackgroundTransparency = 0.35
        profileCard.BorderSizePixel = 1
        profileCard.BorderColor3 = C.RowBorder
        profileCard.LayoutOrder = 2
        profileCard.Parent = menuContainer
        registerThemed(profileCard, { BackgroundColor3 = "RowBg", BorderColor3 = "RowBorder" })

        local curPlr = Shared.Player or Players.LocalPlayer

        local avatarFrame = Instance.new("Frame")
        avatarFrame.Name = "AvatarFrame"
        avatarFrame.Size = UDim2.new(0, 80, 0, 80)
        avatarFrame.Position = UDim2.new(0, 16, 0.5, -40)
        avatarFrame.BackgroundColor3 = C.BodyBg
        avatarFrame.BackgroundTransparency = 0.25
        avatarFrame.BorderSizePixel = 1
        avatarFrame.BorderColor3 = C.WinBorder
        avatarFrame.Parent = profileCard
        registerThemed(avatarFrame, { BackgroundColor3 = "BodyBg", BorderColor3 = "WinBorder" })

        local avatarImg = Instance.new("ImageLabel")
        avatarImg.Name = "AvatarImage"
        avatarImg.Size = UDim2.new(1, -4, 1, -4)
        avatarImg.Position = UDim2.new(0, 2, 0, 2)
        avatarImg.BackgroundTransparency = 1
        avatarImg.Image = (curPlr and curPlr.UserId) and ("rbxthumb://type=AvatarHeadShot&id=" .. tostring(curPlr.UserId) .. "&w=150&h=150") or ""
        avatarImg.Parent = avatarFrame

        -- Try high-res headshot fetch async
        if curPlr and curPlr.UserId then
            task.spawn(function()
                pcall(function()
                    local thumb = Players:GetUserThumbnailAsync(curPlr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                    if thumb then avatarImg.Image = thumb end
                end)
            end)
        end

        local infoContainer = Instance.new("Frame")
        infoContainer.Name = "InfoContainer"
        infoContainer.Size = UDim2.new(1, -118, 1, -20)
        infoContainer.Position = UDim2.new(0, 108, 0, 10)
        infoContainer.BackgroundTransparency = 1
        infoContainer.Parent = profileCard

        local infoLayout = Instance.new("UIListLayout")
        infoLayout.SortOrder = Enum.SortOrder.LayoutOrder
        infoLayout.Padding = UDim.new(0, 3)
        infoLayout.Parent = infoContainer

        local dispNameLabel = Instance.new("TextLabel")
        dispNameLabel.Name = "DisplayNameLabel"
        dispNameLabel.Size = UDim2.new(1, 0, 0, 24)
        dispNameLabel.BackgroundTransparency = 1
        dispNameLabel.Text = (curPlr and curPlr.DisplayName) or "Unknown Player"
        dispNameLabel.TextColor3 = C.BtnText
        dispNameLabel.Font = Enum.Font.ArimoBold
        dispNameLabel.TextSize = 18
        dispNameLabel.TextXAlignment = Enum.TextXAlignment.Left
        dispNameLabel.LayoutOrder = 1
        dispNameLabel.Parent = infoContainer
        registerThemed(dispNameLabel, { TextColor3 = "BtnText" })

        local userNameLabel = Instance.new("TextLabel")
        userNameLabel.Name = "UserNameLabel"
        userNameLabel.Size = UDim2.new(1, 0, 0, 18)
        userNameLabel.BackgroundTransparency = 1
        userNameLabel.Text = "@" .. ((curPlr and curPlr.Name) or "Unknown")
        userNameLabel.TextColor3 = C.Accent
        userNameLabel.Font = Enum.Font.Code
        userNameLabel.TextSize = 13
        userNameLabel.TextXAlignment = Enum.TextXAlignment.Left
        userNameLabel.LayoutOrder = 2
        userNameLabel.Parent = infoContainer
        registerThemed(userNameLabel, { TextColor3 = "Accent" })

        local userDetailsLabel = Instance.new("TextLabel")
        userDetailsLabel.Name = "UserDetailsLabel"
        userDetailsLabel.Size = UDim2.new(1, 0, 0, 18)
        userDetailsLabel.BackgroundTransparency = 1
        userDetailsLabel.Text = "User ID: " .. tostring(curPlr and curPlr.UserId or 0) .. "   |   Account Age: " .. tostring(curPlr and curPlr.AccountAge or 0) .. " days"
        userDetailsLabel.TextColor3 = Color3.fromRGB(150, 160, 175)
        userDetailsLabel.Font = Enum.Font.Code
        userDetailsLabel.TextSize = 11
        userDetailsLabel.TextXAlignment = Enum.TextXAlignment.Left
        userDetailsLabel.LayoutOrder = 3
        userDetailsLabel.Parent = infoContainer
    end

    -- ── PLAYER TAB POPULATION ─────────────────────────────────────
    local playerCols = QuadCols["Player"]
    if playerCols then
        local localPlr = Shared.Player or Players.LocalPlayer
        local mouse = localPlr and localPlr:GetMouse()
        local camera = workspace.CurrentCamera

        local function getLocalRoot()
            local c = localPlr and localPlr.Character
            return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso"))
        end

        local function getLocalHum()
            local c = localPlr and localPlr.Character
            return c and c:FindFirstChildOfClass("Humanoid")
        end

        -- Base stats sync
        local baseWalkSpeed = 16
        local baseJumpPower = 50
        local baseJumpHeight = 7.2

        local function onCharAdded(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if hum then
                baseWalkSpeed = hum.WalkSpeed
                baseJumpPower = hum.JumpPower
                baseJumpHeight = hum.JumpHeight

                local wsConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                    if not Shared.Flags["SpeedEnabled"] then
                        baseWalkSpeed = hum.WalkSpeed
                        if Shared.Sliders["CustomSpeed"] then
                            Shared.Sliders["CustomSpeed"].SetValue(hum.WalkSpeed)
                        end
                    end
                end)
                if Shared.AddCleanup then Shared.AddCleanup(wsConn) end

                local jpConn = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
                    if not Shared.Flags["JumpEnabled"] then
                        baseJumpPower = hum.JumpPower
                        if hum.UseJumpPower and Shared.Sliders["CustomJump"] then
                            Shared.Sliders["CustomJump"].SetValue(hum.JumpPower)
                        end
                    end
                end)
                if Shared.AddCleanup then Shared.AddCleanup(jpConn) end
            end
        end

        if localPlr and localPlr.Character then task.spawn(onCharAdded, localPlr.Character) end
        if localPlr then
            local charConn = localPlr.CharacterAdded:Connect(onCharAdded)
            if Shared.AddCleanup then Shared.AddCleanup(charConn) end
        end

        -- Left Column: Movement, Flight & Teleport
        makeSection(playerCols.Left, "Movement & Teleport", 1)

        makeButton(playerCols.Left, "Dump / Reset Character", 2, function()
            local char = localPlr and localPlr.Character
            if char then
                local hum = getLocalHum()
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Dead)
                    hum.Health = 0
                end
                char:BreakJoints()
            end
        end)

        makeToggle(playerCols.Left, "Ctrl + Click Teleport", "CtrlClickTP", 3, function(state) end)

        local tpConn = UserInput.InputBegan:Connect(function(input, processed)
            if processed then return end
            if not Shared.Flags["CtrlClickTP"] then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local isCtrl = UserInput:IsKeyDown(Enum.KeyCode.LeftControl) or UserInput:IsKeyDown(Enum.KeyCode.RightControl)
                if isCtrl and mouse and mouse.Hit then
                    local root = getLocalRoot()
                    if root then
                        local targetPos = mouse.Hit.Position + Vector3.new(0, 3, 0)
                        root.CFrame = CFrame.new(targetPos, targetPos + root.CFrame.LookVector)
                    end
                end
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(tpConn) end

        -- Functional 6-DOF Flight Engine
        local flightBV = nil
        local flightBG = nil
        local isFlying = false

        local function stopFlight()
            isFlying = false
            if flightBV then pcall(function() flightBV:Destroy() end); flightBV = nil end
            if flightBG then pcall(function() flightBG:Destroy() end); flightBG = nil end
            local hum = getLocalHum()
            if hum then hum.PlatformStand = false end
        end

        local function startFlight()
            local root = getLocalRoot()
            local hum = getLocalHum()
            if not (root and hum) then return end
            stopFlight()
            isFlying = true

            flightBV = Instance.new("BodyVelocity")
            flightBV.Name = "Fih_FlightBV"
            flightBV.Velocity = Vector3.zero
            flightBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flightBV.Parent = root

            flightBG = Instance.new("BodyGyro")
            flightBG.Name = "Fih_FlightBG"
            flightBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            flightBG.P = 10000
            flightBG.CFrame = camera.CFrame
            flightBG.Parent = root

            hum.PlatformStand = true
        end

        makeToggle(playerCols.Left, "Flight Mode (6-DOF)", "Flight", 4, function(state)
            if state then startFlight() else stopFlight() end
        end)
        makeSlider(playerCols.Left, "Flight Speed", "FlightSpeed", 10, 300, 60, 5, function(val) end)

        local flightConn = RunService.RenderStepped:Connect(function()
            if not Shared.Flags["Flight"] then
                if isFlying then stopFlight() end
                return
            end

            local root = getLocalRoot()
            local hum = getLocalHum()
            if not (root and hum and hum.Health > 0) then
                stopFlight()
                return
            end

            if not (flightBV and flightBV.Parent == root and flightBG and flightBG.Parent == root) then
                startFlight()
            end

            hum.PlatformStand = true
            local speed = Shared.Flags["FlightSpeed"] or 60
            local moveDir = Vector3.zero

            local isFocused = UserInput:GetFocusedTextBox() ~= nil
            if not isFocused then
                if UserInput:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
                if UserInput:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
                if UserInput:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
                if UserInput:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
                if UserInput:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
                if UserInput:IsKeyDown(Enum.KeyCode.LeftShift) or UserInput:IsKeyDown(Enum.KeyCode.LeftControl) or UserInput:IsKeyDown(Enum.KeyCode.Q) then
                    moveDir = moveDir - Vector3.new(0, 1, 0)
                end
            end

            if moveDir.Magnitude > 0 then
                flightBV.Velocity = moveDir.Unit * speed
            else
                flightBV.Velocity = Vector3.zero
            end
            flightBG.CFrame = camera.CFrame
        end)
        if Shared.AddCleanup then
            Shared.AddCleanup(flightConn)
            Shared.AddCleanup(stopFlight)
        end

        makeToggle(playerCols.Left, "WalkSpeed Adjuster", "SpeedEnabled", 6, function(state)
            local hum = getLocalHum()
            if not state and hum then hum.WalkSpeed = baseWalkSpeed end
        end)

        makeSlider(playerCols.Left, "Speed Value", "CustomSpeed", 16, 250, 16, 7, function(val)
            local hum = getLocalHum()
            if Shared.Flags["SpeedEnabled"] and hum then hum.WalkSpeed = val end
        end)

        makeToggle(playerCols.Left, "JumpPower Adjuster", "JumpEnabled", 8, function(state)
            local hum = getLocalHum()
            if not state and hum then
                if hum.UseJumpPower then hum.JumpPower = baseJumpPower else hum.JumpHeight = baseJumpHeight end
            end
        end)

        makeSlider(playerCols.Left, "Jump Value", "CustomJump", 50, 300, 50, 9, function(val)
            local hum = getLocalHum()
            if Shared.Flags["JumpEnabled"] and hum then
                if hum.UseJumpPower then hum.JumpPower = val else hum.JumpHeight = val end
            end
        end)

        -- Right Column: Physics & Exploits
        makeSection(playerCols.Right, "Physics & Exploits", 1)

        makeToggle(playerCols.Right, "Noclip Mode", "Noclip", 2, function(state) end)

        local noclipConn = RunService.Stepped:Connect(function()
            if not Shared.Flags["Noclip"] then return end
            local char = localPlr and localPlr.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(noclipConn) end

        makeToggle(playerCols.Right, "Fight Float (Anti-Fall)", "FightFloat", 3, function(state) end)
        makeSlider(playerCols.Right, "Float Height", "FloatHeight", 1, 15, 3, 4, function(val) end)

        local floatConn = RunService.Stepped:Connect(function()
            if not Shared.Flags["FightFloat"] then return end
            local char = localPlr and localPlr.Character
            local root = getLocalRoot()
            local hum = getLocalHum()
            if root and hum and hum.Health > 0 then
                local fh = Shared.Flags["FloatHeight"] or 3
                local rayOrigin = root.Position
                local rayDir = Vector3.new(0, -(fh + 4), 0)
                local params = RaycastParams.new()
                params.FilterDescendantsInstances = {char}
                params.FilterType = Enum.RaycastFilterType.Exclude

                local hit = workspace:Raycast(rayOrigin, rayDir, params)
                if hit and root.AssemblyLinearVelocity.Y < -5 then
                    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, math.max(0, -root.AssemblyLinearVelocity.Y * 0.1), root.AssemblyLinearVelocity.Z)
                end
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(floatConn) end

        -- Non-Blocking Fake Lag / Packet Choke Engine (Zero Player Freeze)
        makeToggle(playerCols.Right, "Fake Lag (Desync)", "FakeLag", 5, function(state) end)
        makeSlider(playerCols.Right, "Fake Lag Factor", "FakeLagFactor", 2, 20, 6, 6, function(val) end)

        local fakeLagTick = 0
        local fakeLagConn = RunService.Heartbeat:Connect(function()
            if not Shared.Flags["FakeLag"] then return end
            local root = getLocalRoot()
            if not root then return end

            fakeLagTick = fakeLagTick + 1
            local interval = Shared.Flags["FakeLagFactor"] or 6
            if fakeLagTick >= interval then
                fakeLagTick = 0
                pcall(function()
                    local sethp = rawget(getfenv and getfenv(0) or _G, "sethiddenproperty") or (getgenv and getgenv().sethiddenproperty)
                    if type(sethp) == "function" then
                        sethp(root, "NetworkIsSleeping", true)
                        task.delay(0.03, function() pcall(sethp, root, "NetworkIsSleeping", false) end)
                    end
                end)
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(fakeLagConn) end

        -- ── DAMAGE / FALL SCRIPT AUTO-PURGER HELPER ─────────────────
        local function neutralizeFallDamageScripts(char)
            if not char then return end
            for _, obj in ipairs(char:GetChildren()) do
                if (obj:IsA("Script") or obj:IsA("LocalScript")) and (obj.Name:find("Fall") or obj.Name:find("Damage") or obj.Name:find("Ragdoll")) then
                    pcall(function()
                        obj.Disabled = true
                        obj:Destroy()
                    end)
                end
            end
        end

        local function bindCharProtection(char)
            if not char then return end
            neutralizeFallDamageScripts(char)
            char.ChildAdded:Connect(function(child)
                task.wait()
                neutralizeFallDamageScripts(char)
            end)
        end

        localPlr.CharacterAdded:Connect(bindCharProtection)
        if localPlr.Character then bindCharProtection(localPlr.Character) end

        local autoPurgeConn = RunService.Stepped:Connect(function()
            if localPlr and localPlr.Character then
                neutralizeFallDamageScripts(localPlr.Character)
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(autoPurgeConn) end

        -- ── WALK FLING ENGINE (TOUCH / CONTACT FLING) ────────────────
        makeToggle(playerCols.Right, "Walk Fling (Touch Fling)", "WalkFling", 7, function(state) end)
        makeSlider(playerCols.Right, "Fling Force", "FlingPower", 0, 100000, 25000, 8, function(val) end)

        local flingSavedAngVel = Vector3.zero
        local flingActiveContact = false

        local walkFlingHeartbeat = RunService.Heartbeat:Connect(function()
            if not Shared.Flags["WalkFling"] then return end
            local power = Shared.Flags["FlingPower"] or 25000
            if power <= 0 then return end

            local root = getLocalRoot()
            local hum = getLocalHum()
            local char = localPlr and localPlr.Character
            if not (root and hum and hum.Health > 0 and char) then return end

            neutralizeFallDamageScripts(char)

            -- Detect proximity to other players
            local nearbyPlayer = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= localPlr and p.Character then
                    local pRoot = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Torso")
                    local pHum = p.Character:FindFirstChildOfClass("Humanoid")
                    if pRoot and pHum and pHum.Health > 0 then
                        local dist = (root.Position - pRoot.Position).Magnitude
                        if dist <= 7.5 then
                            nearbyPlayer = true
                            break
                        end
                    end
                end
            end

            flingActiveContact = nearbyPlayer
            if nearbyPlayer then
                flingSavedAngVel = root.AssemblyAngularVelocity
                -- Pure rotational kinetic torque on network replication step (Zero vertical linear velocity = 0 self fall damage)
                root.AssemblyAngularVelocity = Vector3.new(0, power * 25, 0)
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            end
        end)

        local walkFlingRender = RunService.RenderStepped:Connect(function()
            if not Shared.Flags["WalkFling"] then return end
            local root = getLocalRoot()
            if root and flingActiveContact then
                -- Instantly zero out angular torque locally so your character walks completely normally
                root.AssemblyAngularVelocity = flingSavedAngVel
            end
        end)
        if Shared.AddCleanup then
            Shared.AddCleanup(walkFlingHeartbeat)
            Shared.AddCleanup(walkFlingRender)
        end

        -- ── ANTI-FLING PROTECTION (VELOCITY & COLLISION SHIELD) ─────
        makeToggle(playerCols.Right, "Anti-Fling Shield", "AntiFling", 9, function(state)
            local hum = getLocalHum()
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not state)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not state)
            end
        end)

        local antiFlingConn = RunService.Stepped:Connect(function()
            if not Shared.Flags["AntiFling"] then return end
            local char = localPlr and localPlr.Character
            local root = getLocalRoot()
            local hum = getLocalHum()
            if not (char and root and hum and hum.Health > 0) then return end

            -- 1. Strip collision with other player characters
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= localPlr and p.Character then
                    for _, pPart in ipairs(p.Character:GetDescendants()) do
                        if pPart:IsA("BasePart") and pPart.CanCollide then
                            pPart.CanCollide = false
                        end
                    end
                end
            end

            -- 2. Clamp extreme external velocities while not flying
            if not Shared.Flags["Flight"] then
                local linVel = root.AssemblyLinearVelocity
                local angVel = root.AssemblyAngularVelocity
                if linVel.Magnitude > 100 or angVel.Magnitude > 50 then
                    root.AssemblyLinearVelocity = Vector3.new(
                        math.clamp(linVel.X, -50, 50),
                        math.clamp(linVel.Y, -40, 50),
                        math.clamp(linVel.Z, -50, 50)
                    )
                    root.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(antiFlingConn) end

        -- ── VELOCITY FALL DAMAGE SHIELD (NO FALL DAMAGE) ─────────────
        makeToggle(playerCols.Right, "No Fall Damage", "NoFallDamage", 10, function(state) end)

        local fallParams = RaycastParams.new()
        fallParams.FilterType = Enum.RaycastFilterType.Exclude

        local fallDamageConn = RunService.Heartbeat:Connect(function()
            local char = localPlr and localPlr.Character
            if not char then return end

            if Shared.Flags["NoFallDamage"] or Shared.Flags["FightFloat"] or Shared.Flags["WalkFling"] then
                neutralizeFallDamageScripts(char)
            end

            if not (Shared.Flags["NoFallDamage"] or Shared.Flags["FightFloat"]) then return end
            local root = getLocalRoot()
            local hum = getLocalHum()
            if not (root and hum and hum.Health > 0) then return end

            local vel = root.AssemblyLinearVelocity
            -- If falling rapidly downwards
            if vel.Y < -20 then
                fallParams.FilterDescendantsInstances = {char}
                local ray = workspace:Raycast(root.Position, Vector3.new(0, -14, 0), fallParams)
                if ray then
                    -- Cushion landing: clamp downward velocity before ground impact
                    root.AssemblyLinearVelocity = Vector3.new(vel.X, -4, vel.Z)
                    pcall(function()
                        hum:ChangeState(Enum.HumanoidStateType.Freefall)
                    end)
                end
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(fallDamageConn) end

        -- Speed/Jump render step enforcer
        local renderStatConn = RunService.RenderStepped:Connect(function()
            local hum = getLocalHum()
            if not hum then return end
            if Shared.Flags["SpeedEnabled"] then
                local targetSpeed = Shared.Flags["CustomSpeed"] or 16
                if hum.WalkSpeed ~= targetSpeed then hum.WalkSpeed = targetSpeed end
            end
            if Shared.Flags["JumpEnabled"] then
                local targetJump = Shared.Flags["CustomJump"] or 50
                if hum.UseJumpPower then
                    if hum.JumpPower ~= targetJump then hum.JumpPower = targetJump end
                else
                    if hum.JumpHeight ~= targetJump then hum.JumpHeight = targetJump end
                end
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(renderStatConn) end
    end

    -- ── VISUALS TAB POPULATION ────────────────────────────────────
    local visualsCols = QuadCols["Visuals"]
    if visualsCols then
        local localPlr = Shared.Player or Players.LocalPlayer
        local camera = workspace.CurrentCamera
        local hasDrawing = (type(Drawing) == "table" and type(Drawing.new) == "function")

        local espDrawings = {}
        local playerHighlights = {}
        local playerBillboards = {}

        local originalVisuals = {
            Lighting = {
                Brightness = Lighting and Lighting.Brightness or 1,
                ClockTime = Lighting and Lighting.ClockTime or 14,
                FogEnd = Lighting and Lighting.FogEnd or 100000,
                GlobalShadows = Lighting and Lighting.GlobalShadows or true,
                Ambient = Lighting and Lighting.Ambient or Color3.fromRGB(128, 128, 128),
                OutdoorAmbient = Lighting and Lighting.OutdoorAmbient or Color3.fromRGB(128, 128, 128)
            },
            PostFX = {},
            MapParts = {},
            CamZoom = {
                Min = (localPlr and localPlr.CameraMinZoomDistance) or 0.5,
                Max = (localPlr and localPlr.CameraMaxZoomDistance) or 128,
                Mode = (localPlr and localPlr.CameraMode) or Enum.CameraMode.Classic
            }
        }

        local function createDrawObj(dType, props)
            if not hasDrawing then return nil end
            local ok, d = pcall(function()
                local obj = Drawing.new(dType)
                for k, v in pairs(props or {}) do obj[k] = v end
                table.insert(espDrawings, obj)
                return obj
            end)
            return ok and d or nil
        end

        local crosshairDot = createDrawObj("Circle", {
            Radius = 2.5,
            Filled = true,
            Color = Color3.fromRGB(255, 255, 255),
            Visible = false,
            ZIndex = 100
        })

        local radarCenter = Vector2.new(130, 180)
        local radarRadius = 60
        local radarCircle = createDrawObj("Circle", {
            Radius = radarRadius,
            Filled = true,
            Color = Color3.fromRGB(20, 24, 30),
            Transparency = 0.7,
            Visible = false,
            ZIndex = 50,
            Position = radarCenter
        })
        local radarBorder = createDrawObj("Circle", {
            Radius = radarRadius,
            Filled = false,
            Color = Color3.fromRGB(70, 90, 130),
            Thickness = 1.5,
            Visible = false,
            ZIndex = 51,
            Position = radarCenter
        })
        local radarDot = createDrawObj("Circle", {
            Radius = 3,
            Filled = true,
            Color = Color3.fromRGB(0, 255, 120),
            Visible = false,
            ZIndex = 52,
            Position = radarCenter
        })
        local radarBlips = {}

        local playerESPItems = {}
        local function registerPlayerESP(p)
            if p == localPlr then return end
            playerESPItems[p] = {
                BoxOutline = createDrawObj("Square", { Color = Color3.fromRGB(0, 0, 0), Thickness = 3, Filled = false, Visible = false, ZIndex = 1 }),
                Box = createDrawObj("Square", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Filled = false, Visible = false, ZIndex = 2 }),
                Tracer = createDrawObj("Line", { Color = Color3.fromRGB(255, 75, 75), Thickness = 1.2, Visible = false, ZIndex = 2 }),
                Name = createDrawObj("Text", { Color = Color3.fromRGB(255, 255, 255), Size = 13, Center = true, Outline = true, Visible = false, ZIndex = 3 }),
                HealthBarOutline = createDrawObj("Line", { Color = Color3.fromRGB(0, 0, 0), Thickness = 4, Visible = false, ZIndex = 1 }),
                HealthBar = createDrawObj("Line", { Color = Color3.fromRGB(50, 220, 50), Thickness = 2, Visible = false, ZIndex = 2 }),
                Skeleton = {
                    HeadSpine = createDrawObj("Line", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Visible = false }),
                    LeftArm = createDrawObj("Line", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Visible = false }),
                    RightArm = createDrawObj("Line", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Visible = false }),
                    LeftLeg = createDrawObj("Line", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Visible = false }),
                    RightLeg = createDrawObj("Line", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Visible = false })
                }
            }
        end

        local function unregisterPlayerESP(p)
            local esp = playerESPItems[p]
            if esp then
                pcall(function()
                    if esp.BoxOutline then esp.BoxOutline:Remove() end
                    if esp.Box then esp.Box:Remove() end
                    if esp.Tracer then esp.Tracer:Remove() end
                    if esp.Name then esp.Name:Remove() end
                    if esp.HealthBarOutline then esp.HealthBarOutline:Remove() end
                    if esp.HealthBar then esp.HealthBar:Remove() end
                    for _, line in pairs(esp.Skeleton or {}) do line:Remove() end
                end)
                playerESPItems[p] = nil
            end
            if playerHighlights[p] then
                pcall(function() playerHighlights[p]:Destroy() end)
                playerHighlights[p] = nil
            end
            if playerBillboards[p] then
                pcall(function() playerBillboards[p]:Destroy() end)
                playerBillboards[p] = nil
            end
            if radarBlips[p] then
                pcall(function() radarBlips[p]:Remove() end)
                radarBlips[p] = nil
            end
        end

        for _, p in ipairs(Players:GetPlayers()) do registerPlayerESP(p) end
        local pAddConn = Players.PlayerAdded:Connect(registerPlayerESP)
        local pRemConn = Players.PlayerRemoving:Connect(unregisterPlayerESP)
        if Shared.AddCleanup then
            Shared.AddCleanup(pAddConn)
            Shared.AddCleanup(pRemConn)
            Shared.AddCleanup(function()
                for _, d in ipairs(espDrawings) do pcall(function() d:Remove() end) end
                for _, hl in pairs(playerHighlights) do pcall(function() hl:Destroy() end) end
                for _, bb in pairs(playerBillboards) do pcall(function() bb:Destroy() end) end
            end)
        end

        -- Left Column: 2D ESP & Radar
        makeSection(visualsCols.Left, "2D ESP & Tracers", 1)

        makeToggle(visualsCols.Left, "2D Box ESP", "ESP2D", 2, function(state) end)
        makeToggle(visualsCols.Left, "Chams (Highlight ESP)", "ESPChams", 3, function(state) end)
        makeToggle(visualsCols.Left, "Skeleton ESP", "ESPSkeleton", 4, function(state) end)
        makeToggle(visualsCols.Left, "Health Bar Display", "ESPHealth", 5, function(state) end)
        makeToggle(visualsCols.Left, "Player Names & Dist", "ESPNames", 6, function(state) end)
        makeToggle(visualsCols.Left, "2D Screen Tracers", "Tracers", 7, function(state) end)
        makeToggle(visualsCols.Left, "Mini Radar", "Radar", 8, function(state) end)
        makeToggle(visualsCols.Left, "White Dot Crosshair", "Crosshair", 9, function(state) end)

        -- Right Column: Camera & World Effects
        makeSection(visualsCols.Right, "Camera & World Lighting", 1)

        makeToggle(visualsCols.Right, "Custom FOV Slider", "FOVEnabled", 2, function(state) end)
        makeSlider(visualsCols.Right, "Field of View", "CustomFOV", 30, 130, 70, 3, function(val)
            if Shared.Flags["FOVEnabled"] and camera then camera.FieldOfView = val end
        end)

        makeToggle(visualsCols.Right, "Force 3rd-Person View", "ForceThirdPerson", 4, function(state)
            if not localPlr then return end
            if state then
                localPlr.CameraMode = Enum.CameraMode.Classic
                localPlr.CameraMinZoomDistance = 12
                localPlr.CameraMaxZoomDistance = 128
            else
                localPlr.CameraMode = originalVisuals.CamZoom.Mode
                localPlr.CameraMinZoomDistance = originalVisuals.CamZoom.Min
                localPlr.CameraMaxZoomDistance = originalVisuals.CamZoom.Max
            end
        end)

        makeToggle(visualsCols.Right, "X-Ray Vision", "XRayVision", 5, function(state)
            if state then
                for _, part in ipairs(workspace:GetDescendants()) do
                    if part:IsA("BasePart") and not (localPlr and localPlr.Character and part:IsDescendantOf(localPlr.Character)) then
                        local isPlayerPart = false
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p.Character and part:IsDescendantOf(p.Character) then
                                isPlayerPart = true
                                break
                            end
                        end
                        if not isPlayerPart and part.Transparency < 0.5 then
                            originalVisuals.MapParts[part] = part.Transparency
                            part.Transparency = 0.6
                        end
                    end
                end
            else
                for part, origTrans in pairs(originalVisuals.MapParts) do
                    if part and part.Parent then part.Transparency = origTrans end
                end
                originalVisuals.MapParts = {}
            end
        end)

        makeToggle(visualsCols.Right, "Fullbright Mode", "Fullbright", 6, function(state)
            if not Lighting then return end
            if state then
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.FogEnd = 1e6
                Lighting.GlobalShadows = false
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            else
                Lighting.Brightness = originalVisuals.Lighting.Brightness
                Lighting.ClockTime = originalVisuals.Lighting.ClockTime
                Lighting.FogEnd = originalVisuals.Lighting.FogEnd
                Lighting.GlobalShadows = originalVisuals.Lighting.GlobalShadows
                Lighting.Ambient = originalVisuals.Lighting.Ambient
                Lighting.OutdoorAmbient = originalVisuals.Lighting.OutdoorAmbient
            end
        end)

        makeToggle(visualsCols.Right, "Disable Visual Effects (Blur/DOF)", "NoVisualEffects", 7, function(state)
            if not Lighting then return end
            local effectClasses = {"BlurEffect", "DepthOfFieldEffect", "SunRaysEffect", "BloomEffect", "ColorCorrectionEffect", "Atmosphere"}
            if state then
                for _, inst in ipairs(Lighting:GetDescendants()) do
                    for _, cls in ipairs(effectClasses) do
                        if inst:IsA(cls) then
                            if originalVisuals.PostFX[inst] == nil then
                                originalVisuals.PostFX[inst] = inst.Enabled
                            end
                            inst.Enabled = false
                        end
                    end
                end
            else
                for inst, originalEnabled in pairs(originalVisuals.PostFX) do
                    if inst and inst.Parent then inst.Enabled = originalEnabled end
                end
                originalVisuals.PostFX = {}
            end
        end)

        makeToggle(visualsCols.Right, "No Recoil / Anti-Shake", "NoRecoil", 8, function(state) end)

        local lastCamCFrame = camera.CFrame
        local noRecoilConn = RunService.RenderStepped:Connect(function()
            if Shared.Flags["NoRecoil"] and camera then
                local prevRot = lastCamCFrame - lastCamCFrame.Position
                local deltaAngle = math.acos(math.clamp((camera.CFrame.LookVector:Dot(lastCamCFrame.LookVector)), -1, 1))
                if deltaAngle > math.rad(15) then
                    camera.CFrame = CFrame.new(camera.CFrame.Position) * prevRot
                end
            end
            lastCamCFrame = camera.CFrame
        end)
        if Shared.AddCleanup then Shared.AddCleanup(noRecoilConn) end

        -- Visuals Render Loop (ESP, Chams, Tracers, Radar, Crosshair, FOV)
        local visualsRenderConn = RunService.RenderStepped:Connect(function()
            local vpSize = camera.ViewportSize
            local screenCenter = Vector2.new(vpSize.X / 2, vpSize.Y / 2)

            if crosshairDot then
                crosshairDot.Position = screenCenter
                crosshairDot.Visible = (Shared.Flags["Crosshair"] == true)
            end

            if Shared.Flags["FOVEnabled"] and camera then
                camera.FieldOfView = Shared.Flags["CustomFOV"] or 70
            end

            local showRadar = (Shared.Flags["Radar"] == true) and hasDrawing
            if radarCircle and radarBorder and radarDot then
                radarCircle.Visible = showRadar
                radarBorder.Visible = showRadar
                radarDot.Visible = showRadar
            end

            local localChar = localPlr and localPlr.Character
            local localRoot = localChar and (localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso"))

            for p, esp in pairs(playerESPItems) do
                pcall(function()
                    local char = p.Character
                    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local valid = char and hum and hum.Health > 0 and root ~= nil

                    -- Highlight / Chams
                    if Shared.Flags["ESPChams"] and valid then
                        if not playerHighlights[p] then
                            local hl = Instance.new("Highlight")
                            hl.Name = "Fih_Cham_" .. p.Name
                            hl.FillColor = Color3.fromRGB(230, 60, 60)
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.FillTransparency = 0.4
                            hl.OutlineTransparency = 0
                            hl.Parent = ScreenGui
                            playerHighlights[p] = hl
                        end
                        playerHighlights[p].Adornee = char
                        playerHighlights[p].Enabled = true
                    else
                        if playerHighlights[p] then playerHighlights[p].Enabled = false end
                    end

                    -- Fallback Billboard for Names & Health when Drawing is not available
                    if not hasDrawing and valid and (Shared.Flags["ESPNames"] or Shared.Flags["ESPHealth"]) then
                        if not playerBillboards[p] then
                            local bb = Instance.new("BillboardGui")
                            bb.Name = "Fih_BB_" .. p.Name
                            bb.Size = UDim2.new(0, 150, 0, 40)
                            bb.StudsOffset = Vector3.new(0, 3, 0)
                            bb.AlwaysOnTop = true
                            bb.Parent = ScreenGui

                            local nameLbl = Instance.new("TextLabel")
                            nameLbl.Name = "NameLabel"
                            nameLbl.Size = UDim2.new(1, 0, 0, 18)
                            nameLbl.BackgroundTransparency = 1
                            nameLbl.Font = Enum.Font.Code
                            nameLbl.TextSize = 12
                            nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                            nameLbl.TextStrokeTransparency = 0
                            nameLbl.Parent = bb

                            local hpBar = Instance.new("Frame")
                            hpBar.Name = "HPBar"
                            hpBar.Size = UDim2.new(0.8, 0, 0, 4)
                            hpBar.Position = UDim2.new(0.1, 0, 0, 22)
                            hpBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                            hpBar.BorderSizePixel = 0
                            hpBar.Parent = bb

                            local hpFill = Instance.new("Frame")
                            hpFill.Name = "Fill"
                            hpFill.Size = UDim2.new(1, 0, 1, 0)
                            hpFill.BackgroundColor3 = Color3.fromRGB(50, 220, 50)
                            hpFill.BorderSizePixel = 0
                            hpFill.Parent = hpBar

                            playerBillboards[p] = bb
                        end

                        local bb = playerBillboards[p]
                        bb.Adornee = root
                        bb.Enabled = true

                        local dist = math.floor((camera.CFrame.Position - root.Position).Magnitude)
                        local nameLbl = bb:FindFirstChild("NameLabel")
                        if nameLbl then
                            nameLbl.Visible = (Shared.Flags["ESPNames"] == true)
                            nameLbl.Text = string.format("%s [%dm]", p.DisplayName, dist)
                        end

                        local hpBar = bb:FindFirstChild("HPBar")
                        if hpBar then
                            hpBar.Visible = (Shared.Flags["ESPHealth"] == true)
                            local hpFill = hpBar:FindFirstChild("Fill")
                            if hpFill and hum then
                                local pct = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                                hpFill.Size = UDim2.new(pct, 0, 1, 0)
                                hpFill.BackgroundColor3 = Color3.fromHSV(pct * 0.33, 0.9, 1)
                            end
                        end
                    else
                        if playerBillboards[p] then playerBillboards[p].Enabled = false end
                    end

                    if not (valid and hasDrawing) then
                        if esp.Box then esp.Box.Visible = false end
                        if esp.BoxOutline then esp.BoxOutline.Visible = false end
                        if esp.Tracer then esp.Tracer.Visible = false end
                        if esp.Name then esp.Name.Visible = false end
                        if esp.HealthBar then esp.HealthBar.Visible = false end
                        if esp.HealthBarOutline then esp.HealthBarOutline.Visible = false end
                        for _, skLine in pairs(esp.Skeleton or {}) do skLine.Visible = false end
                        if radarBlips[p] then radarBlips[p].Visible = false end
                        return
                    end

                    local rootPos, onScreen = camera:WorldToViewportPoint(root.Position)
                    local head = char:FindFirstChild("Head")
                    local headPos = head and camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2.5, 0))
                    local footPos = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

                    -- 2D Box ESP & Health
                    if onScreen and Shared.Flags["ESP2D"] then
                        local boxHeight = math.abs(headPos.Y - footPos.Y)
                        local boxWidth = boxHeight * 0.65
                        local boxPos = Vector2.new(rootPos.X - (boxWidth / 2), headPos.Y)

                        esp.Box.Size = Vector2.new(boxWidth, boxHeight)
                        esp.Box.Position = boxPos
                        esp.Box.Visible = true

                        esp.BoxOutline.Size = esp.Box.Size
                        esp.BoxOutline.Position = esp.Box.Position
                        esp.BoxOutline.Visible = true

                        if Shared.Flags["ESPHealth"] and hum then
                            local healthPct = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                            local barStart = Vector2.new(boxPos.X - 5, boxPos.Y + boxHeight)
                            local barEnd = Vector2.new(boxPos.X - 5, boxPos.Y + (boxHeight * (1 - healthPct)))

                            esp.HealthBarOutline.From = Vector2.new(boxPos.X - 5, boxPos.Y + boxHeight + 1)
                            esp.HealthBarOutline.To = Vector2.new(boxPos.X - 5, boxPos.Y - 1)
                            esp.HealthBarOutline.Visible = true

                            esp.HealthBar.From = barStart
                            esp.HealthBar.To = barEnd
                            esp.HealthBar.Color = Color3.fromHSV(healthPct * 0.33, 0.9, 1)
                            esp.HealthBar.Visible = true
                        else
                            esp.HealthBar.Visible = false
                            esp.HealthBarOutline.Visible = false
                        end
                    else
                        esp.Box.Visible = false
                        esp.BoxOutline.Visible = false
                        esp.HealthBar.Visible = false
                        esp.HealthBarOutline.Visible = false
                    end

                    -- Names & Distance
                    if onScreen and Shared.Flags["ESPNames"] then
                        local dist = math.floor((camera.CFrame.Position - root.Position).Magnitude)
                        esp.Name.Text = string.format("%s [%dm]", p.DisplayName, dist)
                        esp.Name.Position = Vector2.new(rootPos.X, headPos.Y - 16)
                        esp.Name.Visible = true
                    else
                        esp.Name.Visible = false
                    end

                    -- Tracers
                    if onScreen and Shared.Flags["Tracers"] then
                        esp.Tracer.From = Vector2.new(vpSize.X / 2, vpSize.Y)
                        esp.Tracer.To = Vector2.new(rootPos.X, footPos.Y)
                        esp.Tracer.Visible = true
                    else
                        esp.Tracer.Visible = false
                    end

                    -- Skeleton ESP
                    if onScreen and Shared.Flags["ESPSkeleton"] then
                        local isR15 = hum.RigType == Enum.HumanoidRigType.R15
                        local pHead = char:FindFirstChild("Head")
                        local pTorso = isR15 and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("LowerTorso")) or char:FindFirstChild("Torso")
                        local pLeftArm = isR15 and char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
                        local pRightArm = isR15 and char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
                        local pLeftLeg = isR15 and char:FindFirstChild("LeftFoot") or char:FindFirstChild("Left Leg")
                        local pRightLeg = isR15 and char:FindFirstChild("RightFoot") or char:FindFirstChild("Right Leg")

                        local function drawBone(line, partA, partB)
                            if partA and partB then
                                local aPos, aVis = camera:WorldToViewportPoint(partA.Position)
                                local bPos, bVis = camera:WorldToViewportPoint(partB.Position)
                                if aVis and bVis then
                                    line.From = Vector2.new(aPos.X, aPos.Y)
                                    line.To = Vector2.new(bPos.X, bPos.Y)
                                    line.Visible = true
                                    return
                                end
                            end
                            line.Visible = false
                        end

                        drawBone(esp.Skeleton.HeadSpine, pHead, pTorso)
                        drawBone(esp.Skeleton.LeftArm, pTorso, pLeftArm)
                        drawBone(esp.Skeleton.RightArm, pTorso, pRightArm)
                        drawBone(esp.Skeleton.LeftLeg, pTorso, pLeftLeg)
                        drawBone(esp.Skeleton.RightLeg, pTorso, pRightLeg)
                    else
                        for _, skLine in pairs(esp.Skeleton or {}) do skLine.Visible = false end
                    end

                    -- Radar Blip Mapping
                    if showRadar and localRoot then
                        if not radarBlips[p] then
                            radarBlips[p] = createDrawObj("Circle", {
                                Radius = 2.5,
                                Filled = true,
                                Color = Color3.fromRGB(255, 80, 80),
                                Visible = false,
                                ZIndex = 53
                            })
                        end
                        local blip = radarBlips[p]
                        if blip then
                            local relPos = root.Position - localRoot.Position
                            local flatRel = Vector3.new(relPos.X, 0, relPos.Z)

                            local camCFrame = camera.CFrame
                            local forward = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z).Unit
                            local right = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z).Unit

                            local localX = flatRel:Dot(right)
                            local localY = -flatRel:Dot(forward)

                            local scale = 0.45
                            local blipOffset = Vector2.new(localX * scale, localY * scale)
                            if blipOffset.Magnitude > radarRadius - 4 then
                                blipOffset = blipOffset.Unit * (radarRadius - 4)
                            end

                            blip.Position = radarCenter + blipOffset
                            blip.Visible = true
                        end
                    else
                        if radarBlips[p] then radarBlips[p].Visible = false end
                    end
                end)
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(visualsRenderConn) end
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
    makeToggle(DrawerScroll, "Enable Music Suite & Tab", "EnableMusicTab", 4, function(state)
        Shared.Flags["EnableMusicTab"] = state
        local musicBtn = TabBtns["Music"]
        if musicBtn then
            musicBtn.Visible = state
        end
        if not state and activeTab == "Music" then
            switchTab("Menu")
        end
        local hud = ScreenGui:FindFirstChild("Fih_BottomHUD")
        if not state and hud then
            hud.Visible = false
        end
        sendNotification("Music Engine", state and "Music Tab & Suite Enabled" or "Music Tab & Suite Hidden", state)
        if Shared.SaveConfigDebounced then Shared.SaveConfigDebounced() end
    end)
    makeToggle(DrawerScroll, "Music HUD & Playback Widget", "MusicHUD", 5, function(state)
        Shared.Flags["MusicHUD"] = state
        local hud = ScreenGui:FindFirstChild("Fih_BottomHUD")
        if state then
            if not hud and Shared.BuildMusicHUD then Shared.BuildMusicHUD() end
            if hud then hud.Visible = true end
            if Shared.StartMusicPolling then Shared.StartMusicPolling() end
            sendNotification("Music Engine", "Music Info HUD Enabled", true)
        else
            if hud then hud.Visible = false end
            sendNotification("Music Engine", "Music Info HUD Disabled", false)
        end
        if Shared.SaveConfigDebounced then Shared.SaveConfigDebounced() end
    end)
    makeToggle(DrawerScroll, "Semi-Translucent Adaptive UI (Song Cover Sync)", "AdaptiveTheme", 6, function(state)
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

    switchTab("Menu")
    print("[UI_Handler] Loaded -- Dark Mode Engine, Smooth Transitions, Hover Effects Active")
end

