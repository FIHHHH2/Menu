-- UniMenu MM2 Module
-- Murder Mystery 2 specific features

local ctx = ...

local Players = game:GetService("Players")
local RunService = ctx.Services.RunService
local TweenService = ctx.Services.TweenService
local ReplicatedStorage = ctx.Services.ReplicatedStorage

local player = game:GetService("Players").LocalPlayer or Players:WaitForChild("LocalPlayer")
if not player then
    player = Players:WaitForChild("LocalPlayer")
end
local camera = workspace.CurrentCamera

local S = ctx.State.S
local MM2 = ctx.State.MM2
local GetCharacter = ctx.Core.GetCharacter
local GetHumanoid = ctx.Core.GetHumanoid
local GetRoot = ctx.Core.GetRoot

-- Detection: check for MM2
local isMM2 = false
pcall(function()
    isMM2 = ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("Gameplay")
end)

-- Only run MM2-specific code if MM2 is detected
if not isMM2 then
    return ctx.Game
end

-- ==================== MM2 ROLE DETECTION ====================
local function GetMM2Murderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        local char = p.Character
        local bp = p:FindFirstChild("Backpack")
        local charTool = char and char:FindFirstChildWhichIsA("Tool")
        local bpTool = bp and bp:FindFirstChildWhichIsA("Tool")
        
        if charTool and charTool.Name == "Knife" then return p end
        if bpTool and bpTool.Name == "Knife" then return p end
    end
    return nil
end

local function GetMM2Sheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        local char = p.Character
        local bp = p:FindFirstChild("Backpack")
        local charTool = char and char:FindFirstChildWhichIsA("Tool")
        local bpTool = bp and bp:FindFirstChildWhichIsA("Tool")
        
        if charTool and charTool.Name == "Gun" then return p end
        if bpTool and bpTool.Name == "Gun" then return p end
    end
    return nil
end

local function GetMM2Innocents()
    local murderer = GetMM2Murderer()
    local sheriff = GetMM2Sheriff()
    local innocents = {}
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p == player or p == murderer or p == sheriff then continue end
        table.insert(innocents, p)
    end
    return innocents
end

-- ==================== MM2 ESP ====================
local mm2EspObjects = {}

local function CreateMM2ESP(plr, color, label)
    if mm2EspObjects[plr.Name] then
        mm2EspObjects[plr.Name]:Destroy()
    end
    
    local char = plr.Character
    if not char then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "MM2_ESP_" .. plr.Name
    highlight.Adornee = char
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = char
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MM2_Label_" .. plr.Name
    billboard.Adornee = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    billboard.Size = UDim2.new(0, 100, 0, 20)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = workspace
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = label
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard
    
    mm2EspObjects[plr.Name] = { highlight = highlight, billboard = billboard }
end

local function RemoveMM2ESP(plr)
    local obj = mm2EspObjects[plr.Name]
    if obj then
        if obj.highlight then obj.highlight:Destroy() end
        if obj.billboard then obj.billboard:Destroy() end
        mm2EspObjects[plr.Name] = nil
    end
end

local function UpdateMM2ESP()
    if not MM2.roleESP then
        for plrName in pairs(mm2EspObjects) do
            RemoveMM2ESP(Players:FindFirstChild(plrName))
        end
        return
    end
    
    local murderer = GetMM2Murderer()
    local sheriff = GetMM2Sheriff()
    local innocents = GetMM2Innocents()
    
    if murderer then CreateMM2ESP(murderer, Color3.fromRGB(255, 50, 50), "🔪 Murderer") end
    if sheriff then CreateMM2ESP(sheriff, Color3.fromRGB(50, 150, 255), "🔫 Sheriff") end
    for _, p in ipairs(innocents) do
        CreateMM2ESP(p, Color3.fromRGB(100, 255, 100), "👤 Innocent")
    end
    
    -- Clean up for players who left or changed role
    for plrName, _ in pairs(mm2EspObjects) do
        local plr = Players:FindFirstChild(plrName)
        if not plr or plr == murderer or plr == sheriff then continue end
        local isInnocent = false
        for _, p in ipairs(innocents) do if p == plr then isInnocent = true break end end
        if not isInnocent then RemoveMM2ESP(plr) end
    end
end

-- ==================== COIN ESP ====================
local coinEspObjects = {}

local function CreateCoinESP(coin)
    if coinEspObjects[coin] then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Coin_ESP"
    billboard.Adornee = coin
    billboard.Size = UDim2.new(0, 50, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = workspace
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "💰"
    label.TextColor3 = Color3.fromRGB(255, 215, 0)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 24
    label.TextScaled = true
    label.Parent = billboard
    
    coinEspObjects[coin] = billboard
end

local function RemoveCoinESP(coin)
    local billboard = coinEspObjects[coin]
    if billboard then
        billboard:Destroy()
        coinEspObjects[coin] = nil
    end
end

local function UpdateCoinESP()
    if not MM2.coinESP then
        for coin, _ in pairs(coinEspObjects) do
            RemoveCoinESP(coin)
        end
        return
    end
    
    local map = workspace:FindFirstChild("Map")
    if map then
        for _, coin in ipairs(map:GetDescendants()) do
            if coin.Name == "Coin_Server" and coin:IsA("BasePart") then
                CreateCoinESP(coin)
            end
        end
    end
end

-- ==================== AUTO FEATURES ====================
local autoKillConn = nil
local autoGrabConn = nil
local coinFarmConn = nil

local function ToggleAutoKillMurderer(enabled)
    MM2.autoKillMurderer = enabled
    
    if autoKillConn then
        autoKillConn:Disconnect()
        autoKillConn = nil
    end
    
    if enabled then
        autoKillConn = RunService.Heartbeat:Connect(function()
            if not MM2.autoKillMurderer then return end
            
            local murderer = GetMM2Murderer()
            if not murderer then return end
            
            local myChar = GetCharacter()
            local myRoot = GetRoot()
            local murdererChar = murderer.Character
            local murdererRoot = murdererChar and murdererChar:FindFirstChild("HumanoidRootPart")
            
            if not myRoot or not murdererRoot then return end
            
            -- Check if we have gun
            local myTool = myChar and myChar:FindFirstChildWhichIsA("Tool")
            if not myTool or myTool.Name ~= "Gun" then return end
            
            -- Check distance
            local dist = (myRoot.Position - murdererRoot.Position).Magnitude
            if dist > 100 then return end
            
            -- Shoot
            local remote = ReplicatedStorage:FindFirstChild("Remotes")
            if remote then
                local gameplay = remote:FindFirstChild("Gameplay")
                if gameplay then
                    local shoot = gameplay:FindFirstChild("ShootGun")
                    if shoot then
                        shoot:FireServer(murdererRoot.Position)
                    end
                end
            end
        end)
    end
end

local function ToggleAutoGrabGun(enabled)
    MM2.autoGrabGun = enabled
    
    if autoGrabConn then
        autoGrabConn:Disconnect()
        autoGrabConn = nil
    end
    
    if enabled then
        autoGrabConn = RunService.Heartbeat:Connect(function()
            if not MM2.autoGrabGun then return end
            if tick() - MM2.lastGrabTime < MM2.grabDelay then return end
            
            local myChar = GetCharacter()
            if not myChar then return end
            
            -- Check if we already have gun
            if myChar:FindFirstChild("Gun") then return end
            
            local map = workspace:FindFirstChild("Map")
            if not map then return end
            
            for _, obj in ipairs(map:GetDescendants()) do
                if obj.Name == "GunDrop" and obj:IsA("BasePart") then
                    local dist = (GetRoot().Position - obj.Position).Magnitude
                    if dist < 15 then
                        local remote = ReplicatedStorage:FindFirstChild("Remotes")
                        if remote then
                            local gameplay = remote:FindFirstChild("Gameplay")
                            if gameplay then
                                local grab = gameplay:FindFirstChild("GrabGun")
                                if grab then
                                    grab:FireServer(obj)
                                    MM2.lastGrabTime = tick()
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

local function ToggleCoinAutoFarm(enabled)
    MM2.coinAutoFarm = enabled
    
    if coinFarmConn then
        coinFarmConn:Disconnect()
        coinFarmConn = nil
    end
    
    if enabled then
        coinFarmConn = RunService.Heartbeat:Connect(function()
            if not MM2.coinAutoFarm then return end
            if tick() - MM2.lastCoinFarmTime < MM2.coinFarmDelay then return end
            
            local myRoot = GetRoot()
            if not myRoot then return end
            
            local map = workspace:FindFirstChild("Map")
            if not map then return end
            
            for _, coin in ipairs(map:GetDescendants()) do
                if coin.Name == "Coin_Server" and coin:IsA("BasePart") then
                    local dist = (myRoot.Position - coin.Position).Magnitude
                    if dist < 12 then
                        myRoot.CFrame = coin.CFrame
                        MM2.lastCoinFarmTime = tick()
                        break
                    end
                end
            end
        end)
    end
end

-- ==================== CHARACTER EVENTS ====================
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(1)
        UpdateMM2ESP()
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    RemoveMM2ESP(plr)
end)

-- ==================== EXPORTS ====================
ctx.Game.MM2 = {
    GetMM2Murderer = GetMM2Murderer,
    GetMM2Sheriff = GetMM2Sheriff,
    GetMM2Innocents = GetMM2Innocents,
    UpdateMM2ESP = UpdateMM2ESP,
    UpdateCoinESP = UpdateCoinESP,
    ToggleAutoKillMurderer = ToggleAutoKillMurderer,
    ToggleAutoGrabGun = ToggleAutoGrabGun,
    ToggleCoinAutoFarm = ToggleCoinAutoFarm,
    isMM2 = isMM2,
}

return ctx.Game.MM2