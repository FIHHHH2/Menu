-- UniMenu MM2 Module
-- MM2-specific features, hooks, ESP, auto-farm, magic bullet
-- This module is OPTIONAL - script works without MM2

local ctx = ...

-- Services
local Players = ctx.Services.Players
local RunService = ctx.Services.RunService
local TweenService = ctx.Services.TweenService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Core helpers
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- State refs
local S = ctx.State.S
local MM2 = ctx.State.MM2
local GetCharacter = ctx.Core.GetCharacter
local GetHumanoid = ctx.Core.GetHumanoid
local GetRoot = ctx.Core.GetRoot

-- Detection: check for MM2 (OPTIONAL - doesn't break script if not found)
local isMM2 = false
pcall(function()
    isMM2 = ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("Gameplay")
end)

-- Initialize MM2 state if not exists
if not MM2 then
    ctx.State.MM2 = {
        roleESP = false,
        coinESP = false,
        autoKillMurderer = false,
        killEveryone = false,
        autoDodgeKnife = false,
        autoGrabGun = false,
        coinAutoFarm = false,
        lastCoinFarmTime = 0,
        coinFarmDelay = 0.5,
        lastGrabTime = 0,
        grabDelay = 1.0,
    }
    MM2 = ctx.State.MM2
end

-- Only run MM2-specific code if MM2 is detected
if isMM2 then
    -- ==================== MM2 ROLE DETECTION ====================
    local function GetMM2Murderer()
        for _, p in ipairs(Players:GetPlayers()) do
            local char = p.Character
            local bp = p:FindFirstChild("Backpack")
            local charTool = char and char:FindFirstChildWhichIsA("Tool")
            local bpTool = bp and bp:FindFirstChildWhichIsA("Tool")
            local hasK = (char and (char:FindFirstChild("Knife")
                or (charTool and (charTool.Name:lower():find("knife")
                    or charTool:FindFirstChild("KnifeServer")))))
                or (bp and (bp:FindFirstChild("Knife")
                    or (bpTool and (bpTool.Name:lower():find("knife")
                        or bpTool:FindFirstChild("KnifeServer")))))
            if hasK then return p end
        end
        return nil
    end

    local function GetMM2Sheriff()
        for _, p in ipairs(Players:GetPlayers()) do
            local char = p.Character
            local bp = p:FindFirstChild("Backpack")
            local charTool = char and char:FindFirstChildWhichIsA("Tool")
            local bpTool = bp and bp:FindFirstChildWhichIsA("Tool")
            local hasG = (char and (char:FindFirstChild("Gun")
                or (charTool and (charTool.Name:lower():find("gun")
                    or charTool:FindFirstChild("GunServer")))))
                or (bp and (bp:FindFirstChild("Gun")
                    or (bpTool and (bpTool.Name:lower():find("gun")
                        or bpTool:FindFirstChild("GunServer")))))
            if hasG then return p end
        end
        return nil
    end

    ctx.Game.MM2 = {}
    ctx.Game.MM2.GetMM2Murderer = GetMM2Murderer
    ctx.Game.MM2.GetMM2Sheriff = GetMM2Sheriff

    -- ==================== COIN AUTO FARM ====================
    task.spawn(function()
        while task.wait(0.5) do
            if not MM2.coinAutoFarm or os.clock() - MM2.lastCoinFarmTime < MM2.coinFarmDelay then
                continue
            end
            MM2.lastCoinFarmTime = os.clock()

            local myChar = GetCharacter()
            if not myChar then continue end
            local myRoot = GetRoot(myChar)
            if not myRoot then continue end

            local closestCoin = nil
            local closestDistance = math.huge

            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name:find("Coin") and obj:IsA("Part") then
                    local dist = (obj.Position - myRoot.Position).Magnitude
                    if dist < closestDistance then
                        closestDistance = dist
                        closestCoin = obj
                    end
                end
            end

            if closestCoin then
                myRoot.CFrame = closestCoin.CFrame * CFrame.new(0, 3, 0)
            end
        end
    end)

    -- ==================== AUTO KILL MURDERER ====================
    task.spawn(function()
        while task.wait(0.3) do
            if not MM2.autoKillMurderer then continue end
            local murderer = GetMM2Murderer()
            if murderer and murderer.Character then
                local hum = murderer.Character:FindFirstChild("Humanoid")
                if hum then hum.Health = 0 end
            end
        end
    end)

    -- ==================== AUTO DODGE KNIFE ====================
    task.spawn(function()
        while task.wait(0.05) do
            if not MM2.autoDodgeKnife then continue end
            local myChar = GetCharacter()
            if not myChar then continue end
            local myRoot = GetRoot(myChar)
            if not myRoot then continue end

            local murderer = GetMM2Murderer()
            if not murderer or not murderer.Character then continue end

            local bp = murderer:FindFirstChild("Backpack")
            local knife = murderer.Character:FindFirstChild("Knife")
                or (bp and bp:FindFirstChild("Knife"))
            if not knife then continue end

            local handle = knife:FindFirstChild("Handle")
            if not handle then continue end

            local dist = (handle.Position - myRoot.Position).Magnitude
            if dist < 15 then
                myRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -8)
            end
        end
    end)

    -- ==================== AUTO GRAB GUN ====================
    task.spawn(function()
        while task.wait(1) do
            if not MM2.autoGrabGun or os.clock() - MM2.lastGrabTime < MM2.grabDelay then
                continue
            end
            MM2.lastGrabTime = os.clock()

            local sheriff = GetMM2Sheriff()
            if sheriff and sheriff.Character then
                local bp = sheriff:FindFirstChild("Backpack")
                local gun = sheriff.Character:FindFirstChild("Gun")
                    or (bp and bp:FindFirstChild("Gun"))
                if gun then
                    local myChar = GetCharacter()
                    if myChar then
                        gun.Parent = myChar
                    end
                end
            end
        end
    end)
end

-- ==================== MM2 FEATURE LIST ====================
local SRef = S

local mm2FeatureList = {
    { isSection = true, name = "MM2 Automation" },
    {
        name = "Coins ESP",
        desc = "Highlight all coins with yellow ESP",
        isToggle = true,
        get = function() return S.mm2CoinsESP end,
        toggle = function(state) S.mm2CoinsESP = state end,
    },
    {
        name = "Auto Kill Murderer",
        desc = "Automatically kill the murderer",
        isToggle = true,
        get = function() return MM2.autoKillMurderer end,
        toggle = function(state) MM2.autoKillMurderer = state end,
    },
    {
        name = "Kill Everyone",
        desc = "Kill all players in the game",
        isButton = true,
        action = function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local hum = p.Character:FindFirstChild("Humanoid")
                    if hum then hum.Health = 0 end
                end
            end
        end,
    },
    {
        name = "Auto Grab Gun",
        desc = "Auto-grab sheriff's gun when dropped",
        isToggle = true,
        get = function() return MM2.autoGrabGun end,
        toggle = function(state) MM2.autoGrabGun = state end,
    },
    {
        name = "MM2 Role ESP",
        desc = "Show ESP for Murderer/Sheriff/Innocent",
        isToggle = true,
        get = function() return S.mm2RoleESP end,
        toggle = function(state) S.mm2RoleESP = state end,
    },
    {
        name = "Auto Dodge Knife",
        desc = "Automatically dodge incoming knife attacks",
        isToggle = true,
        get = function() return MM2.autoDodgeKnife end,
        toggle = function(state) MM2.autoDodgeKnife = state end,
    },
    {
        name = "Coin Auto Farm",
        desc = "Teleport to nearest coin automatically",
        isToggle = true,
        get = function() return MM2.coinAutoFarm end,
        toggle = function(state) MM2.coinAutoFarm = state end,
    },
    { isSection = true, name = "Teleports" },
    {
        name = "TP to Murderer",
        desc = "Teleport behind the murderer",
        isButton = true,
        action = function()
            if not isMM2 then
                ctx.Core.ShowNotification("MM2 not detected", 0.75, "warning")
                return
            end
            local murderer = ctx.Game.MM2.GetMM2Murderer()
            if murderer and murderer.Character then
                local root = murderer.Character:FindFirstChild("HumanoidRootPart")
                local myRoot = GetRoot()
                if root and myRoot then
                    myRoot.CFrame = root.CFrame * CFrame.new(0, 3, 5)
                end
            end
        end,
    },
    {
        name = "TP to Sheriff",
        desc = "Teleport behind the sheriff",
        isButton = true,
        action = function()
            if not isMM2 then
                ctx.Core.ShowNotification("MM2 not detected", 0.75, "warning")
                return
            end
            local sheriff = ctx.Game.MM2.GetMM2Sheriff()
            if sheriff and sheriff.Character then
                local root = sheriff.Character:FindFirstChild("HumanoidRootPart")
                local myRoot = GetRoot()
                if root and myRoot then
                    myRoot.CFrame = root.CFrame * CFrame.new(0, 3, 5)
                end
            end
        end,
    },
    {
        name = "TP to Lobby",
        desc = "Teleport back to lobby",
        isButton = true,
        action = function()
            local myRoot = GetRoot()
            if myRoot then
                myRoot.CFrame = CFrame.new(0, 50, 0)
            end
        end,
    },
}

-- Register MM2 features (always register, even without MM2)
if isMM2 then
    ctx.Core.RegisterFeatures("MM2", mm2FeatureList)
else
    local basicMM2Features = {
        { isSection = true, name = "MM2 Features" },
        {
            name = "MM2 Not Detected",
            desc = "This game is not Murder Mystery 2",
            isButton = true,
            action = function()
                ctx.Core.ShowNotification("Not in MM2 - features disabled", 0.75, "info")
            end,
        },
    }
    ctx.Core.RegisterFeatures("MM2", basicMM2Features)
end

-- Peer icon toggle (added to Config tab)
local peerIconFeature = {
    name = "Show Peer Icons",
    desc = "Show music peer icons above other UniMenu users",
    isToggle = true,
    get = function() return SRef.showPeerIcon end,
    toggle = function(state) ctx.Core.TogglePeerIcon(state) end,
}

if not ctx.Core.features["Config"] then
    ctx.Core.features["Config"] = {}
end
table.insert(ctx.Core.features["Config"], peerIconFeature)

ctx.Modules.mm2 = true