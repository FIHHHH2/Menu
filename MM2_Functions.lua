-- MM2_Functions.lua
-- Persistent Chams/ESP Engine, Smooth Noclip Tween Coin Collector,
-- Unrestricted Kill Aura, Non-Intrusive Silent Aim, and Sheriff Dropped Gun Beacon

return function(Shared)
    local Players      = Shared.Services.Players
    local RunService   = Shared.Services.RunService
    local UserInput    = Shared.Services.UserInput
    local TweenService = Shared.Services.TweenService
    local Workspace    = Shared.Services.Workspace

    local Player    = Shared.Player
    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkSlider  = Shared.MakeSlider  or function() return Instance.new("Frame") end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab  = Tabs["MM2"]
    local cols = QuadCols["MM2"]
    if not tab or not cols then return end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    -- ── Helpers ──────────────────────────────────────────────────
    local function getChar()  return Shared.Character or Player.Character end
    local function getHRP()   local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
    local function getHuman() local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

    local function restoreDefaultCollisions(char)
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == "HumanoidRootPart" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" or part.Name == "Head" then
                    part.CanCollide = true
                else
                    part.CanCollide = false
                end
            end
        end
    end

    local function isAlive(plr)
        if not plr or not plr.Character then return false end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health > 0
    end

    local function selfAliveInRound()
        local c = getChar()
        if not c then return false end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local lobby = Workspace:FindFirstChild("Lobby")
        if lobby and c:IsDescendantOf(lobby) then return false end
        return true
    end

    local function getRole(plr)
        if not plr then return "Innocent" end
        local bp   = plr:FindFirstChild("Backpack")
        local char = plr.Character
        local items = {}
        if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then table.insert(items, t) end end end
        if char then for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") then table.insert(items, t) end end end

        for _, item in ipairs(items) do
            local name = item.Name:lower()
            if name == "knife" or name:find("knife") or name == "bat" or name == "scythe" or name == "harvester" or name == "corrupt" or name == "dagger" or item:FindFirstChild("KnifeServer") or item:FindFirstChild("Slash") or item:FindFirstChild("Stab") then
                return "Murderer"
            elseif name == "gun" or name == "revolver" or name:find("gun") or name:find("revolver") or name == "pistol" or name == "bow" or item:FindFirstChild("GunServer") or item:FindFirstChild("Shoot") or item:FindFirstChild("CreateBeam") then
                return "Sheriff"
            end
        end
        return "Innocent"
    end

    local function getMurderer()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) and getRole(plr) == "Murderer" then
                return plr
            end
        end
        return nil
    end

    local function getSheriff()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) and getRole(plr) == "Sheriff" then
                return plr
            end
        end
        return nil
    end

    local function getMyKnife()
        local c = getChar(); local bp = Player:FindFirstChild("Backpack")
        local items = {}
        if c then for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") then table.insert(items, t) end end end
        if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then table.insert(items, t) end end end
        for _, item in ipairs(items) do
            local name = item.Name:lower()
            if name == "knife" or name:find("knife") or name == "bat" or name == "scythe" or name == "harvester" or name == "corrupt" or name == "dagger" or item:FindFirstChild("KnifeServer") or item:FindFirstChild("Slash") then
                return item
            end
        end
        return nil
    end

    local function getMyGun()
        local c = getChar(); local bp = Player:FindFirstChild("Backpack")
        local items = {}
        if c then for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") then table.insert(items, t) end end end
        if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then table.insert(items, t) end end end
        for _, item in ipairs(items) do
            local name = item.Name:lower()
            if name == "gun" or name == "revolver" or name:find("gun") or name:find("revolver") or name == "pistol" or name == "bow" or item:FindFirstChild("GunServer") or item:FindFirstChild("Shoot") or item:FindFirstChild("CreateBeam") then
                return item
            end
        end
        return nil
    end

    local function getSilentAimTarget()
        local myHRP = getHRP()
        if not myHRP then return nil end

        local myRole = getRole(Player)
        if myRole ~= "Murderer" then
            local murd = getMurderer()
            if murd and murd.Character then
                local mHRP = murd.Character:FindFirstChild("HumanoidRootPart")
                if mHRP then return mHRP end
            end
        end

        local best, bestDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) then
                local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then
                    local d = (tHRP.Position - myHRP.Position).Magnitude
                    if d < bestDist then bestDist = d; best = tHRP end
                end
            end
        end
        return best
    end

    -- ── Cached Gun Drop Scanner ──────────────────────────────────
    local cachedGunDropPart = nil
    local cachedGunDropModel = nil

    local function findGunDrop()
        local drop = Workspace:FindFirstChild("GunDrop")
        if not drop then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj.Name == "GunDrop" then
                    drop = obj
                    break
                elseif (obj:IsA("Tool") or obj:IsA("Model")) and (obj.Name == "Gun" or obj.Name == "Revolver" or obj.Name:find("GunDrop")) then
                    if obj.Parent ~= Player.Backpack and (not getChar() or obj.Parent ~= getChar()) then
                        drop = obj
                        break
                    end
                end
            end
        end

        if not drop then
            local normal = Workspace:FindFirstChild("Normal")
            if normal then
                drop = normal:FindFirstChild("GunDrop")
            end
        end

        if drop then
            if drop:IsA("BasePart") then
                return drop, drop
            elseif drop:IsA("Model") or drop:IsA("Tool") then
                local p = drop:FindFirstChild("GunDrop") or drop:FindFirstChild("Handle") or drop:FindFirstChildOfClass("BasePart") or drop:FindFirstChildOfClass("MeshPart") or drop.PrimaryPart
                if p then return p, drop end
            end
        end
        return nil, nil
    end

    task.spawn(function()
        while true do
            if Shared.Flags["AutoGrabGun"] or Shared.Flags["GunESP"] then
                local part, model = findGunDrop()
                cachedGunDropPart = part
                cachedGunDropModel = model
            end
            task.wait(0.2)
        end
    end)

    -- ── LEFT COLUMN: KILL AURA & SILENT AIM ───────────────────────
    MkSection(leftCol, "Kill Aura Engine", 1)

    local auraBoxPart = nil
    local function updateVisualizer(hrp, radius)
        if not auraBoxPart then
            auraBoxPart = Instance.new("Part")
            auraBoxPart.Name          = "Fih_AuraBox"
            auraBoxPart.Anchored      = true
            auraBoxPart.CanCollide    = false
            auraBoxPart.CanTouch      = false
            auraBoxPart.CastShadow    = false
            auraBoxPart.Transparency  = 0.75
            auraBoxPart.Material      = Enum.Material.ForceField
            auraBoxPart.BrickColor    = BrickColor.new("Bright red")
            auraBoxPart.Parent        = Workspace

            local sel = Instance.new("SelectionBox")
            sel.Name          = "AuraSelection"
            sel.Adornee       = auraBoxPart
            sel.Color3        = Color3.fromRGB(255, 50, 50)
            sel.SurfaceColor3 = Color3.fromRGB(255, 30, 30)
            sel.SurfaceTransparency = 0.85
            sel.LineThickness = 0.05
            sel.Parent        = auraBoxPart
        end
        auraBoxPart.Size   = Vector3.new(radius * 2, radius * 2, radius * 2)
        auraBoxPart.CFrame = CFrame.new(hrp.Position)
    end

    local function clearVisualizer()
        if auraBoxPart then auraBoxPart:Destroy(); auraBoxPart = nil end
    end

    MkToggle(leftCol, "Kill Aura Box Visualizer", "KillAuraBox", 2, function(state)
        if not state then clearVisualizer() end
    end)

    MkSlider(leftCol, "Aura Radius (studs)", "KillAuraRadius", 5, 80, 20, 3, function(val)
        Shared.Flags["KillAuraRadius"] = val
        if Shared.Flags["KillAuraBox"] then
            local hrp = getHRP(); if hrp then updateVisualizer(hrp, val) end
        end
    end)

    MkToggle(leftCol, "Kill Aura (All Players)", "KillAura", 4, function(state) end)

    local visualizerConn = RunService.RenderStepped:Connect(function()
        if Shared.Flags["KillAuraBox"] then
            local hrp = getHRP()
            if hrp then updateVisualizer(hrp, Shared.Flags["KillAuraRadius"] or 20) else clearVisualizer() end
        else
            clearVisualizer()
        end
    end)
    if Shared.AddCleanup then Shared.AddCleanup(visualizerConn) end

    local killAuraConn = RunService.Heartbeat:Connect(function()
        if not Shared.Flags["KillAura"] then return end
        if not selfAliveInRound() then return end

        local hrp = getHRP(); if not hrp then return end
        local radius = Shared.Flags["KillAuraRadius"] or 20

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) then
                local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP and (tHRP.Position - hrp.Position).Magnitude <= radius then
                    local knife = getMyKnife()
                    if knife then
                        local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildOfClass("BasePart")
                        if handle then
                            pcall(function() firetouchinterest(tHRP, handle, 0) end)
                            pcall(function() firetouchinterest(tHRP, handle, 1) end)
                        end
                    end
                    local gun = getMyGun()
                    if gun then
                        local handle = gun:FindFirstChild("Handle") or gun:FindFirstChildOfClass("BasePart")
                        if handle then pcall(function() firetouchinterest(tHRP, handle, 0) end) end
                    end
                    pcall(function()
                        local kk = game:GetService("ReplicatedStorage").Remotes.Gameplay:FindFirstChild("KnifeKill")
                        if kk and getMyKnife() then kk:Fire() end
                        local gk = game:GetService("ReplicatedStorage").Remotes.Gameplay:FindFirstChild("GunKill")
                        if gk and getMyGun() then gk:Fire() end
                    end)
                end
            end
        end
    end)

    -- ── SILENT AIM ENGINE ─────────────────────────────────────────
    MkSection(leftCol, "Silent Aim (Bullet Redirection)", 10)

    local function getShootRemote()
        local rep = game:GetService("ReplicatedStorage")
        local rem = nil
        pcall(function()
            if rep:FindFirstChild("Remotes") and rep.Remotes:FindFirstChild("Gameplay") then
                rem = rep.Remotes.Gameplay:FindFirstChild("ShootGun")
            end
            if not rem and rep:FindFirstChild("WeaponEvents") then
                rem = rep.WeaponEvents:FindFirstChild("GunBeam")
            end
            if not rem then
                rem = rep:FindFirstChild("ShootGun", true)
            end
        end)
        return rem
    end

    local function shootGunAt(targetPos)
        if not targetPos then return end
        local gun = getMyGun()
        if not gun then return end
        local char = getChar()
        if not char then return end

        if gun.Parent ~= char then
            pcall(function()
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(gun) end
            end)
            task.wait(0.05)
        end

        local myHRP = getHRP()
        if not myHRP then return end

        local rem = getShootRemote()
        if rem then
            pcall(function()
                if rem:IsA("RemoteFunction") then
                    rem:InvokeServer(1, targetPos, Vector3.new(0, 0, 0))
                elseif rem:IsA("RemoteEvent") then
                    rem:FireServer(1, targetPos, Vector3.new(0, 0, 0))
                    rem:FireServer(CFrame.new(myHRP.Position, targetPos), targetPos)
                end
            end)
        end
    end

    -- Hook Metamethod for silent redirect
    local silentAimHooked = false
    local function setupSilentAimHook()
        if silentAimHooked then return end
        silentAimHooked = true

        pcall(function()
            if typeof(hookmetamethod) == "function" then
                local oldNC
                oldNC = hookmetamethod(game, "__namecall", function(self, ...)
                    if Shared.Flags["SilentAim"] and not checkcaller() then
                        local method = getnamecallmethod()
                        if method == "FireServer" or method == "InvokeServer" then
                            local sName = tostring(self)
                            if sName == "ShootGun" or sName == "GunBeam" or sName == "GunFired" then
                                local target = getSilentAimTarget()
                                if target then
                                    local targetPos = target.Position + (target.AssemblyLinearVelocity * 0.04)
                                    local args = {...}
                                    if #args >= 2 and typeof(args[2]) == "Vector3" then
                                        args[2] = targetPos
                                        return oldNC(self, table.unpack(args))
                                    end
                                    return oldNC(self, 1, targetPos, Vector3.new(0, 0, 0))
                                end
                            end
                        end
                    end
                    return oldNC(self, ...)
                end)
            end
        end)
    end

    local silentAimInputConn = nil
    MkToggle(leftCol, "Silent Aim (Auto Hit Murderer)", "SilentAim", 11, function(state)
        if silentAimInputConn then silentAimInputConn:Disconnect(); silentAimInputConn = nil end
        if state then
            setupSilentAimHook()
            Shared.Notify("Silent Aim", "Active -- Shots Automatically Redirect to Murderer", true)
        end
    end)

    -- ── AUTO COIN COLLECTOR (SMOOTH NOCLIP TWEEN) ────────────────
    MkSection(leftCol, "Auto Coin Collector (Noclip Tween)", 20)

    local function getActiveCoins()
        local coins = {}
        local container = (Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("CoinContainer"))
                       or Workspace:FindFirstChild("CoinContainer")
                       or (Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("CoinContainer"))

        if container then
            for _, c in ipairs(container:GetChildren()) do
                local part = c:IsA("BasePart") and c or c:FindFirstChildOfClass("BasePart") or c:FindFirstChild("CoinVisual")
                if part then table.insert(coins, part) end
            end
        end

        if #coins == 0 then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if (obj.Name == "Coin_Server" or obj.Name == "Coin" or obj.Name == "CoinVisual") and obj:IsA("BasePart") then
                    local lobby = Workspace:FindFirstChild("Lobby")
                    if not (lobby and obj:IsDescendantOf(lobby)) then
                        table.insert(coins, obj)
                    end
                end
            end
        end
        return coins
    end

    local coinCollectorRunning = false
    local currentCoinTween = nil

    local function stopCoinCollector()
        coinCollectorRunning = false
        if currentCoinTween then
            pcall(function() currentCoinTween:Cancel() end)
            currentCoinTween = nil
        end
        local char = getChar()
        if char then restoreDefaultCollisions(char) end
    end

    MkToggle(leftCol, "Auto Collect Coins (Tween)", "AutoCoins", 21, function(state)
        if not state then
            stopCoinCollector()
            return
        end

        coinCollectorRunning = true
        task.spawn(function()
            while coinCollectorRunning and Shared.Flags["AutoCoins"] do
                if selfAliveInRound() then
                    local myHRP = getHRP()
                    if myHRP then
                        local coins = getActiveCoins()
                        local bestCoin, bestDist = nil, math.huge
                        for _, c in ipairs(coins) do
                            if c and c.Parent then
                                local d = (c.Position - myHRP.Position).Magnitude
                                if d < bestDist then bestDist = d; bestCoin = c end
                            end
                        end

                        if bestCoin and bestCoin.Parent then
                            -- Noclip character while tweening
                            local char = getChar()
                            if char then
                                for _, p in ipairs(char:GetDescendants()) do
                                    if p:IsA("BasePart") then p.CanCollide = false end
                                end
                            end

                            local speed = Shared.Flags["CoinTweenSpeed"] or 32
                            local duration = math.clamp(bestDist / speed, 0.1, 8.0)
                            local targetCF = CFrame.new(bestCoin.Position)

                            currentCoinTween = TweenService:Create(myHRP, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                                CFrame = targetCF
                            })
                            currentCoinTween:Play()

                            local reached = false
                            local waitTime = 0
                            while waitTime < duration and coinCollectorRunning and Shared.Flags["AutoCoins"] and bestCoin.Parent do
                                task.wait(0.05)
                                waitTime = waitTime + 0.05
                                pcall(function()
                                    firetouchinterest(myHRP, bestCoin, 0)
                                    firetouchinterest(myHRP, bestCoin, 1)
                                end)
                                if (bestCoin.Position - myHRP.Position).Magnitude < 3 then
                                    reached = true
                                    break
                                end
                            end
                            pcall(function() currentCoinTween:Cancel() end)
                            task.wait(0.08)
                        else
                            task.wait(0.5)
                        end
                    else
                        task.wait(0.5)
                    end
                else
                    task.wait(0.5)
                end
            end
        end)
    end)

    MkSlider(leftCol, "Coin Tween Speed", "CoinTweenSpeed", 15, 75, 35, 22, function(val)
        Shared.Flags["CoinTweenSpeed"] = val
    end)

    -- Coin ESP & Visualizer
    local coinESPObjects = {}
    local coinESPConn = nil
    local function clearCoinESP()
        for _, obj in pairs(coinESPObjects) do pcall(function() obj:Destroy() end) end
        coinESPObjects = {}
    end

    MkToggle(leftCol, "Coin ESP & Visualizer", "CoinESP", 23, function(state)
        clearCoinESP()
        if coinESPConn then coinESPConn:Disconnect(); coinESPConn = nil end
        if not state then return end

        coinESPConn = RunService.RenderStepped:Connect(function()
            local myHRP = getHRP()
            local coins = getActiveCoins()
            local activeCoinsMap = {}

            for _, c in ipairs(coins) do
                if c and c.Parent then
                    activeCoinsMap[c] = true
                    if not coinESPObjects[c] then
                        local bb = Instance.new("BillboardGui")
                        bb.Name         = "CoinTag"
                        bb.Size         = UDim2.new(0, 80, 0, 20)
                        bb.StudsOffset  = Vector3.new(0, 1.5, 0)
                        bb.AlwaysOnTop  = true
                        bb.Adornee      = c
                        bb.Parent       = Shared.GUI

                        local lbl = Instance.new("TextLabel")
                        lbl.Size                   = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 0.3
                        lbl.BackgroundColor3       = Color3.fromRGB(40, 32, 5)
                        lbl.Font                   = Enum.Font.ArimoBold
                        lbl.TextSize               = 10
                        lbl.TextColor3             = Color3.fromRGB(255, 225, 50)
                        lbl.TextStrokeTransparency = 0
                        lbl.Parent                 = bb

                        coinESPObjects[c] = bb
                    end
                    local dist = myHRP and math.floor((c.Position - myHRP.Position).Magnitude) or 0
                    local lbl = coinESPObjects[c]:FindFirstChildOfClass("TextLabel")
                    if lbl then lbl.Text = "[COIN] " .. dist .. "m" end
                end
            end

            for c, bb in pairs(coinESPObjects) do
                if not activeCoinsMap[c] or not c.Parent then
                    pcall(function() bb:Destroy() end)
                    coinESPObjects[c] = nil
                end
            end
        end)
    end)

    MkSection(leftCol, "Auto Grab Gun (Dead Drop)", 30)

    local autoGrabConn
    local function executeGunPickup(part, model)
        if not part or not part.Parent then return false end
        local myHRP = getHRP()
        if not myHRP then return false end

        -- 1. Fire touch interest on the target part
        pcall(function()
            firetouchinterest(myHRP, part, 0)
            firetouchinterest(myHRP, part, 1)
        end)

        -- 2. Fire touch interest on all BaseParts in model if it's a model
        if model and model:IsA("Model") then
            for _, p in ipairs(model:GetChildren()) do
                if p:IsA("BasePart") then
                    pcall(function()
                        firetouchinterest(myHRP, p, 0)
                        firetouchinterest(myHRP, p, 1)
                    end)
                end
            end
        end

        -- 3. Trigger proximity prompt if present
        pcall(function()
            local prompt = part:FindFirstChildOfClass("ProximityPrompt") or (model and model:FindFirstChildOfClass("ProximityPrompt"))
            if prompt and fireproximityprompt then
                fireproximityprompt(prompt)
            end
        end)
        return true
    end

    MkToggle(leftCol, "Auto Grab Dropped Gun (Any Distance)", "AutoGrabGun", 31, function(state)
        if autoGrabConn then autoGrabConn:Disconnect(); autoGrabConn = nil end
        if state then
            autoGrabConn = RunService.Heartbeat:Connect(function()
                if not selfAliveInRound() then return end
                if getMyGun() then return end
                local part, model = cachedGunDropPart, cachedGunDropModel
                if not part or not part.Parent then
                    part, model = findGunDrop()
                end
                if part and part.Parent then
                    executeGunPickup(part, model)
                end
            end)
            if Shared.AddCleanup then Shared.AddCleanup(autoGrabConn) end
        end
    end)

    MkButton(leftCol, "[ Instant Teleport & Grab Gun ]", 32, function()
        local part, model = findGunDrop()
        if not part or not part.Parent then
            Shared.Notify("Gun Grabber", "No dropped gun found on map", false)
            return
        end
        local myHRP = getHRP()
        if not myHRP then return end
        local origCF = myHRP.CFrame
        pcall(function()
            myHRP.CFrame = part.CFrame + Vector3.new(0, 1.5, 0)
            task.wait(0.05)
            executeGunPickup(part, model)
            task.wait(0.08)
            myHRP.CFrame = origCF
            Shared.Notify("Gun Grabber", "Grabbed gun and returned to spot!", true)
        end)
    end)

    -- ── RIGHT COLUMN: KNIFE, ESP & SHERIFF TOOLS ──────────────────
    MkSection(rightCol, "Knife Controls", 1)

    local knifeThrowConn
    MkToggle(rightCol, "Knife Velocity Prediction", "KnifePrediction", 2, function(state)
        if knifeThrowConn then knifeThrowConn:Disconnect(); knifeThrowConn = nil end
        if state then
            knifeThrowConn = Workspace.ChildAdded:Connect(function(obj)
                if not Shared.Flags["KnifePrediction"] then return end
                -- Only inspect actual thrown projectile tools/models, never map geometry
                if (obj:IsA("Tool") or (obj:IsA("Model") and obj:FindFirstChild("Handle"))) and (obj.Name:find("Knife") or obj.Name:find("knife")) then
                    task.wait()
                    local myHRP = getHRP(); if not myHRP then return end
                    local target, bestDist = nil, math.huge
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= Player and isAlive(plr) then
                            local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                            if tHRP then
                                local d = (tHRP.Position - myHRP.Position).Magnitude
                                if d < bestDist then bestDist = d; target = tHRP end
                            end
                        end
                    end
                    if not target then return end
                    local vel = target.AssemblyLinearVelocity
                    local dist = (target.Position - myHRP.Position).Magnitude
                    local travelTime = dist / 80
                    local predictedPos = target.Position + vel * travelTime
                    local knifeBase = obj:FindFirstChildOfClass("BasePart") or (obj:IsA("BasePart") and obj)
                    if knifeBase then
                        pcall(function()
                            local dir = (predictedPos - knifeBase.Position).Unit
                            knifeBase.CFrame = CFrame.new(knifeBase.Position, predictedPos)
                            if not knifeBase.Anchored then
                                knifeBase.AssemblyLinearVelocity = dir * 120
                            end
                        end)
                    end
                end
            end)
            if Shared.AddCleanup then Shared.AddCleanup(knifeThrowConn) end
        end
    end)

    MkToggle(rightCol, "Auto Throw Knife at Nearest", "AutoThrow", 3, function(state) end)

    local autoThrowConn = RunService.Heartbeat:Connect(function()
        if not Shared.Flags["AutoThrow"] then return end
        if not selfAliveInRound() then return end
        if getRole(Player) ~= "Murderer" then return end
        local myHRP = getHRP(); if not myHRP then return end
        local target, bestDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) then
                local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then
                    local d = (tHRP.Position - myHRP.Position).Magnitude
                    if d < bestDist then bestDist = d; target = tHRP end
                end
            end
        end
        if target and bestDist < 60 then
            local knife = getMyKnife()
            if knife then
                local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildOfClass("BasePart")
                if handle then
                    pcall(function()
                        firetouchinterest(target, handle, 0)
                        firetouchinterest(target, handle, 1)
                    end)
                end
            end
        end
    end)
    if Shared.AddCleanup then Shared.AddCleanup(autoThrowConn) end

    MkSection(rightCol, "ESP & Visuals", 10)

    local espEntries = {}
    local espConn = nil

    local function cleanupPlayerESP(plr)
        local entry = espEntries[plr]
        if entry then
            pcall(function() if entry.gui then entry.gui:Destroy() end end)
            pcall(function() if entry.hl then entry.hl:Destroy() end end)
            espEntries[plr] = nil
        end
    end

    local function clearAllESP()
        for plr in pairs(espEntries) do cleanupPlayerESP(plr) end
        espEntries = {}
    end
    if Shared.AddCleanup then Shared.AddCleanup(clearAllESP) end

    MkToggle(rightCol, "Role ESP & Highlight Chams", "RoleESP", 11, function(state)
        clearAllESP()
        if espConn then espConn:Disconnect(); espConn = nil end
        if not state then return end

        espConn = RunService.RenderStepped:Connect(function()
            local myHRP = getHRP()
            for plr, entry in pairs(espEntries) do
                if not plr.Parent or not plr.Character or not isAlive(plr) then
                    cleanupPlayerESP(plr)
                end
            end

            local livingPlayers = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= Player and plr.Character and isAlive(plr) then
                    table.insert(livingPlayers, plr)
                end
            end

            for _, plr in ipairs(livingPlayers) do
                local char = plr.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildOfClass("Humanoid")

                if hrp and hum and hum.Health > 0 then
                    local entry = espEntries[plr]
                    if not entry or entry.lastChar ~= char or not (entry.hl and entry.hl.Parent) or not (entry.gui and entry.gui.Parent) then
                        cleanupPlayerESP(plr)
                        for _, oldHl in ipairs(char:GetChildren()) do
                            if oldHl:IsA("Highlight") and oldHl.Name:find("Fih_") then
                                pcall(function() oldHl:Destroy() end)
                            end
                        end
                        local hl = Instance.new("Highlight")
                        hl.Name                = "Fih_Chams"
                        hl.Adornee             = char
                        hl.FillTransparency    = 0.55
                        hl.OutlineTransparency = 0
                        hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent              = char

                        local bb = Instance.new("BillboardGui")
                        bb.Name         = "Fih_RoleTag"
                        bb.Size         = UDim2.new(0, 130, 0, 32)
                        bb.StudsOffset  = Vector3.new(0, 3.8, 0)
                        bb.AlwaysOnTop  = true
                        bb.Adornee      = hrp
                        bb.Parent       = Shared.GUI

                        local bg = Instance.new("Frame")
                        bg.Size                   = UDim2.new(1, 0, 1, 0)
                        bg.BackgroundColor3       = Color3.fromRGB(15, 18, 24)
                        bg.BackgroundTransparency = 0.25
                        bg.BorderSizePixel        = 1
                        bg.BorderColor3           = Color3.fromRGB(100, 120, 160)
                        bg.Parent                 = bb

                        local lbl = Instance.new("TextLabel")
                        lbl.Size                   = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font                   = Enum.Font.ArimoBold
                        lbl.TextSize               = 11
                        lbl.TextStrokeTransparency = 0
                        lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
                        lbl.Parent                 = bg

                        entry = { gui = bb, hl = hl, lbl = lbl, bg = bg, lastChar = char }
                        espEntries[plr] = entry
                    end

                    local role = getRole(plr)
                    local col, roleTag = Color3.fromRGB(80, 240, 120), "[INNOCENT]"
                    if role == "Murderer" then
                        col     = Color3.fromRGB(255, 45, 45)
                        roleTag = "[★ MURDERER]"
                    elseif role == "Sheriff" then
                        col     = Color3.fromRGB(0, 190, 255)
                        roleTag = "[✦ SHERIFF]"
                    end

                    local dist = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0

                    if entry.hl and entry.hl.Parent then
                        entry.hl.FillColor    = col
                        entry.hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        entry.hl.Adornee      = char
                    end

                    if entry.bg and entry.lbl then
                        entry.bg.BorderColor3 = col
                        entry.lbl.TextColor3  = col
                        entry.lbl.Text        = roleTag .. " " .. plr.Name .. "\n" .. dist .. " studs"
                    end
                end
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(espConn) end
    end)

    local gunEspHL = nil
    local gunEspBB = nil
    local gunEspConn = nil

    local function clearGunDropESP()
        if gunEspHL then gunEspHL:Destroy(); gunEspHL = nil end
        if gunEspBB then gunEspBB:Destroy(); gunEspBB = nil end
    end
    if Shared.AddCleanup then Shared.AddCleanup(clearGunDropESP) end

    MkToggle(rightCol, "Dropped Gun Beacon ESP", "GunESP", 12, function(state)
        clearGunDropESP()
        if gunEspConn then gunEspConn:Disconnect(); gunEspConn = nil end
        if not state then return end

        gunEspConn = RunService.RenderStepped:Connect(function()
            local myHRP = getHRP()
            local foundDrop = cachedGunDropPart or cachedGunDropModel

            if foundDrop and foundDrop.Parent then
                if not gunEspHL or not gunEspHL.Parent or not gunEspBB or not gunEspBB.Parent then
                    clearGunDropESP()

                    local hl = Instance.new("Highlight")
                    hl.Name                = "Fih_GunHL"
                    hl.Adornee             = foundDrop.Parent:IsA("Tool") and foundDrop.Parent or foundDrop
                    hl.FillColor           = Color3.fromRGB(255, 215, 0)
                    hl.OutlineColor        = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency    = 0.3
                    hl.OutlineTransparency = 0
                    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent              = foundDrop
                    gunEspHL = hl

                    local bb = Instance.new("BillboardGui")
                    bb.Name         = "Fih_GunDropTag"
                    bb.Size         = UDim2.new(0, 130, 0, 30)
                    bb.StudsOffset  = Vector3.new(0, 2.5, 0)
                    bb.AlwaysOnTop  = true
                    bb.Adornee      = foundDrop
                    bb.Parent       = Shared.GUI

                    local bg = Instance.new("Frame")
                    bg.Size                   = UDim2.new(1, 0, 1, 0)
                    bg.BackgroundColor3       = Color3.fromRGB(30, 25, 5)
                    bg.BackgroundTransparency = 0.15
                    bg.BorderSizePixel        = 1
                    bg.BorderColor3           = Color3.fromRGB(255, 215, 0)
                    bg.Parent                 = bb

                    local lbl = Instance.new("TextLabel")
                    lbl.Size                   = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Font                   = Enum.Font.ArimoBold
                    lbl.TextSize               = 11
                    lbl.TextColor3             = Color3.fromRGB(255, 220, 30)
                    lbl.TextStrokeTransparency = 0
                    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
                    lbl.Parent                 = bg
                    gunEspBB = bb
                else
                    gunEspHL.Adornee = foundDrop.Parent:IsA("Tool") and foundDrop.Parent or foundDrop
                    gunEspBB.Adornee = foundDrop
                end

                local dist = myHRP and math.floor((foundDrop.Position - myHRP.Position).Magnitude) or 0
                local lbl = gunEspBB:FindFirstChildOfClass("Frame") and gunEspBB.Frame:FindFirstChildOfClass("TextLabel")
                if lbl then lbl.Text = "[⚠ DROPPED GUN]\n" .. dist .. " studs" end
            else
                clearGunDropESP()
            end
        end)
        if Shared.AddCleanup then Shared.AddCleanup(gunEspConn) end
    end)

    MkSection(rightCol, "Sheriff Tools", 20)

    MkToggle(rightCol, "Auto Shoot Murderer", "AutoShoot", 21, function(state) end)
    local lastAutoShootTime = 0
    local autoShootConn = RunService.Heartbeat:Connect(function()
        if not Shared.Flags["AutoShoot"] then return end
        if not selfAliveInRound() then return end
        local gun = getMyGun()
        if not gun then return end
        local now = tick()
        if now - lastAutoShootTime < 0.6 then return end

        local murd = getMurderer()
        if murd and murd.Character and isAlive(murd) then
            local tHRP = murd.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = getHRP()
            if tHRP and myHRP then
                lastAutoShootTime = now
                local targetPos = tHRP.Position + (tHRP.AssemblyLinearVelocity * 0.05)
                shootGunAt(targetPos)
            end
        end
    end)
    if Shared.AddCleanup then Shared.AddCleanup(autoShootConn) end

    MkToggle(rightCol, "Auto Kill All (Murderer)", "AutoKillAll", 22, function(state) end)
    local autoKillConn = RunService.Heartbeat:Connect(function()
        if not Shared.Flags["AutoKillAll"] then return end
        if not selfAliveInRound() then return end
        if getRole(Player) ~= "Murderer" then return end
        local knife = getMyKnife(); if not knife then return end
        local myHRP = getHRP(); if not myHRP then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) then
                local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then
                    local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildOfClass("BasePart")
                    if handle then
                        pcall(function() firetouchinterest(tHRP, handle, 0) end)
                        pcall(function() firetouchinterest(tHRP, handle, 1) end)
                    end
                end
            end
        end
    end)
    if Shared.AddCleanup then Shared.AddCleanup(autoKillConn) end

    print("[MM2_Functions] Loaded -- Persistent Chams/ESP & Smooth Tween Auto-Coin Online")
end
