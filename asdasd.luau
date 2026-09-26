--!native
--!optimize 2

getgenv().__Testing = getgenv().__Testing or {}

if getgenv().__Testing.Unload then

    pcall(getgenv().__Testing.Unload)

    getgenv().__Testing.Unload = nil

end

pcall(function()

    if getgenv().__Testing.ForceRestore then

        getgenv().__Testing.ForceRestore()
        getgenv().__Testing.ForceRestore = nil

    end

end)

pcall(function()

    local stats = getgenv().__Testing.COSStats

    if stats and stats.uninstall then

        stats.uninstall()
        getgenv().__Testing.COSStats = nil

    end

end)

pcall(function()

    local shoom = getgenv().__Testing.Shoom

    if shoom and shoom.stop then

        shoom.stop()
        getgenv().__Testing.Shoom = nil

    end

end)

pcall(function()

    local crystal = getgenv().__Testing.Crystal

    if crystal and crystal.stop then

        crystal.stop()
        getgenv().__Testing.Crystal = nil

    end

end)

pcall(function()

    for _, name in ipairs({ "Token", "Trinket" }) do
        local state = getgenv().__Testing[name]

        if state and state.stop then
            state.stop()
        end

        getgenv().__Testing[name] = nil
    end

    pcall(function()
        local travel = getgenv().__Testing.Travel

        if travel then travel.busy = false end
    end)

    getgenv().__Testing.Travel = nil
end)

pcall(function()

    if getgenv().Library and getgenv().Library.ScreenGui then

        getgenv().Library.ScreenGui:Destroy()

    end

end)

pcall(function()

    game:GetService("UserInputService").MouseIconEnabled = true

end)

pcall(function()

    local realm = getgenv().__Testing.TradeRealm

    if realm and realm.stop then

        realm.stop()
        getgenv().__Testing.TradeRealm = nil

    end

    local sales = getgenv().__Testing.SalesViewer

    if sales then

        sales.pollRunning = false
        getgenv().__Testing.SalesViewer = nil

    end

    getgenv().__Testing.PriceViewer = nil

    pcall(function()
        for _, existing in ipairs(game:GetService("CoreGui"):GetChildren()) do
            if existing.Name == "CSTPriceViewer" or existing.Name == "CSTSalesViewer" then
                existing:Destroy()
            end
        end
    end)

end)

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lighting = game:GetService("Lighting")

local VirtualUser = game:GetService("VirtualUser")

local TeleportService = game:GetService("TeleportService")

local MaterialService = game:GetService("MaterialService")

local CoreGui = game:GetService("CoreGui")

local MarketplaceService = game:GetService("MarketplaceService")

local Workspace = game:GetService("Workspace")

local Stats = game:GetService("Stats")

local UserInputService = game:GetService("UserInputService")

local TextChatService = game:GetService("TextChatService")

local LocalPlayer = Players.LocalPlayer

local Camera = workspace.CurrentCamera

local DataPing = Stats.Network.ServerStatsItem["Data Ping"]

local FrameRateManager = Stats:FindFirstChild("FrameRateManager")

local RenderAverage = FrameRateManager and FrameRateManager:FindFirstChild("RenderAverage")

local ModuleCache = {}

local function LoadModule(Path)

    if ModuleCache[Path] ~= nil then return ModuleCache[Path] end

    local ok, result = pcall(function()

        local url = Path

        if not string.match(Path, "^https?://") then

            url = "https://cats-cure-depression.vercel.app/" .. Path

        end

        return loadstring(game:HttpGet(url))()

    end)

    if ok then ModuleCache[Path] = result return result end

    warn("[LoadModule] failed:", Path)

    return nil

end

local Library = LoadModule("moehack.net/interface/library.luau")

local SaveManager = LoadModule("moehack.net/interface/addons/SaveManager.lua")

local ThemeManager = LoadModule("moehack.net/interface/addons/ThemeManager.lua")

local Toggles = {}

local function AddToggle(box, flag, options)

    local toggle = box:AddToggle(flag, options)

    Toggles[flag] = toggle

    return toggle

end

local Visuals = LoadModule("moehack.net/modules/visuals.luau")

local Misc = LoadModule("moehack.net/modules/misc.luau")

local Desync = LoadModule("moehack.net/modules/desync.luau")

local PlaceId = game.PlaceId

local PlaceName = "Unknown"

pcall(function()

    local info = MarketplaceService:GetProductInfo(PlaceId)

    if info and info.Name then PlaceName = info.Name end

end)

local IsBugFixes = PlaceId == 100971017807798

local IsWarTycoon = PlaceId == 4639625707

local IsCreaturesOfSonaria = PlaceId == 5233782396

local IsTradeRealm = PlaceId == 14119723130

local IsSupported = IsBugFixes or IsWarTycoon or IsCreaturesOfSonaria or IsTradeRealm

local SKYBOX_URL = "https://raw.githubusercontent.com/LTFxGUILT/asdasd/refs/heads/main/skyboxes.luau"

local SkyboxList = { ["Default"] = nil }

pcall(function()

    local remote = loadstring(game:HttpGet(SKYBOX_URL))()

    if type(remote) == "table" then

        local n = 0

        for name, data in pairs(remote) do

            SkyboxList[name] = data

            n = n + 1

        end

        print("[Skyboxes] loaded", n)

    end

end)

local SkyNames = {}

for name in pairs(SkyboxList) do table.insert(SkyNames, name) end

table.sort(SkyNames)

local currentSkybox, skyboxEnabled, originalSky = "Default", false, nil

local function ApplySkybox(name)

    if not originalSky then

        local existing = Lighting:FindFirstChildOfClass("Sky")

        if existing then originalSky = existing:Clone() end

    end

    for _, child in ipairs(Lighting:GetChildren()) do

        if child:IsA("Sky") then child:Destroy() end

    end

    if name == "Default" or not skyboxEnabled then

        if originalSky then originalSky:Clone().Parent = Lighting end

        return

    end

    local data = SkyboxList[name]

    if not data then return end

    local sky = Instance.new("Sky")

    sky.Name = "CustomSky_" .. name

    for prop, value in pairs(data) do pcall(function() sky[prop] = value end) end

    sky.Parent = Lighting

end

local LimbExtender

pcall(function()

    getgenv().le = getgenv().le or loadstring(game:HttpGet('https://raw.githubusercontent.com/AAPVdev/scripts/refs/heads/main/LimbExtender.lua'))()

    LimbExtender = getgenv().le({

        LISTEN_FOR_INPUT = false, USE_HIGHLIGHT = false,

        ESP = false, ESP_BOX = false, ESP_TRACER = false,

        ESP_SKELETON = false, ESP_HEALTH = false, ESP_LABEL = false, CHAMS = false,

        TARGET_LIMB = "Head", LIMB_SIZE = 5

    })

end)

local noFallEnabled, cframeEnabled, lockFOV = false, false, false

local rainbowBody, rainbowGun, infiniteAmmo = false, false, false

local headExpandEnabled, quickInteract, chamsEnabled = false, false, false

local cframeSpeed, currentFOV, headSize = 50, 70, 5

local charTransparency, charHue, rainbowBodySpeed = 0, 0, 0.008

local gunTransparency, gunHue, rainbowGunSpeed = 0, 0, 0.015

local fallConnection, originalPrompts, ChamObjects = nil, {}, {}

local safeTeleportEnabled = true

local tpProtectUntil, tpLockCF = 0, nil

local antiAfkConnection = nil

local espEnabled, espBox, espBoxFill, espName, espDistance = false, false, false, false, false

local espHealthText, espTool, espRenderTeam = false, false, false

local espBoxFillTransparency, espRenderDistance, espRenderHz = 0.5, 500, 60

local espBoxColor = Color3.fromRGB(255, 255, 255)

local espFillColor = Color3.fromRGB(255, 255, 255)

local espNameColor = Color3.fromRGB(255, 255, 255)

local espObjects, espAccumulator = {}, 0

local friendUsers, kosUsers = {}, {}

local friendColor = Color3.fromRGB(0, 255, 100)

local kosColor = Color3.fromRGB(255, 50, 50)

local selectedPlayerName, playerDropdown = nil, nil

local itemEspEnabled, showAccessories, showTools = false, true, true

local showWorkspaceOnly, showOnPlayers = false, true

local maxItemEspDistance, itemEspObjects, trackedItems = 500, {}, {}

local itemEspAccum, rainbowAccum = 0, 0

local autoPrayEnabled = false

local autoPrayInterval = 4

local autoPrayTpToShrine = true

local prayBusyUntil = 0

local lastAutoPrayAttempt = 0

local prayAttemptCount = 0

local praySuccessCount = 0

local itemRewardCounts = {}

local knownItemInstances = {}

local rewardListenUntil = 0

local currentAttemptGotReward = false

local praySummaryLabel = nil

local trackerOverlayVisible = true

local FrameRate, Ping = 0, 0

local HardcodedTPs = {

    { Name = "Tea House", CFrame = CFrame.new(607.75, 5.78, -34.50) },

    { Name = "Shrine",    CFrame = CFrame.new(312.02, 3.01, 201.71) },

    { Name = "Temple",    CFrame = CFrame.new(547.50, 4.55, 598.36) },

}

local function getRoot()

    local char = LocalPlayer.Character

    return char and char:FindFirstChild("HumanoidRootPart"),

           char and char:FindFirstChildOfClass("Humanoid"),

           char

end

local function getPlayerNames()

    local names = {}

    for _, p in ipairs(Players:GetPlayers()) do

        if p ~= LocalPlayer then table.insert(names, p.Name) end

    end

    table.sort(names)

    if #names == 0 then table.insert(names, "(none)") end

    return names

end

local function findPlayerByName(name)

    if not name or name == "(none)" then return nil end

    for _, p in ipairs(Players:GetPlayers()) do

        if p.Name == name then return p end

    end

    return nil

end

local function getPlayerStatus(player)

    if not player then return "none" end

    if friendUsers[player.UserId] then return "friend" end

    if kosUsers[player.UserId] then return "kos" end

    return "none"

end

local function setFriend(player)

    if not player then return end

    friendUsers[player.UserId] = true

    kosUsers[player.UserId] = nil

end

local function setKOS(player)

    if not player then return end

    kosUsers[player.UserId] = true

    friendUsers[player.UserId] = nil

end

local function clearStatus(player)

    if not player then return end

    friendUsers[player.UserId] = nil

    kosUsers[player.UserId] = nil

end

local function refreshPlayerDropdown()

    if playerDropdown and playerDropdown.SetValues then

        pcall(function() playerDropdown:SetValues(getPlayerNames()) end)

    end

end

local function colorsForPlayer(player)

    local status = getPlayerStatus(player)

    if status == "friend" then return friendColor, friendColor end

    if status == "kos" then return kosColor, kosColor end

    return espBoxColor, espFillColor

end

local function getCoordsString()

    local root = select(1, getRoot())

    if not root then return "0, 0, 0" end

    local p = root.Position

    return string.format("%.0f, %.0f, %.0f", p.X, p.Y, p.Z)

end

local trackerGui, trackerFrame, trackerBody = nil, nil, nil

if IsBugFixes then

    pcall(function()

        if CoreGui:FindFirstChild("PrayTrackerOverlay") then

            CoreGui.PrayTrackerOverlay:Destroy()

        end

    end)

    trackerGui = Instance.new("ScreenGui")

    trackerGui.Name = "PrayTrackerOverlay"

    trackerGui.ResetOnSpawn = false

    trackerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    trackerGui.Parent = CoreGui

    trackerFrame = Instance.new("Frame")

    trackerFrame.Size = UDim2.new(0, 200, 0, 160)

    trackerFrame.Position = UDim2.new(0, 12, 0.5, -80)

    trackerFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)

    trackerFrame.BackgroundTransparency = 0.2

    trackerFrame.BorderSizePixel = 0

    trackerFrame.Visible = trackerOverlayVisible

    trackerFrame.Parent = trackerGui

    Instance.new("UICorner", trackerFrame).CornerRadius = UDim.new(0, 6)

    local trStroke = Instance.new("UIStroke")

    trStroke.Color = Color3.fromRGB(55, 55, 65)

    trStroke.Thickness = 1

    trStroke.Parent = trackerFrame

    local trackerTitle = Instance.new("TextLabel")

    trackerTitle.Size = UDim2.new(1, -8, 0, 22)

    trackerTitle.Position = UDim2.new(0, 4, 0, 2)

    trackerTitle.BackgroundTransparency = 1

    trackerTitle.Font = Enum.Font.Code

    trackerTitle.TextSize = 13

    trackerTitle.TextXAlignment = Enum.TextXAlignment.Left

    trackerTitle.TextColor3 = Color3.fromRGB(220, 220, 230)

    trackerTitle.Text = "Pray Tracker"

    trackerTitle.Parent = trackerFrame

    trackerBody = Instance.new("TextLabel")

    trackerBody.Size = UDim2.new(1, -8, 1, -28)

    trackerBody.Position = UDim2.new(0, 4, 0, 24)

    trackerBody.BackgroundTransparency = 1

    trackerBody.Font = Enum.Font.Code

    trackerBody.TextSize = 12

    trackerBody.TextXAlignment = Enum.TextXAlignment.Left

    trackerBody.TextYAlignment = Enum.TextYAlignment.Top

    trackerBody.TextColor3 = Color3.fromRGB(200, 200, 210)

    trackerBody.Text = "Attempts: 0\nWith loot: 0\n—"

    trackerBody.TextWrapped = true

    trackerBody.Parent = trackerFrame

    do

        local dragging, dragStart, startPos = false, nil, nil

        trackerFrame.InputBegan:Connect(function(input)

            if input.UserInputType == Enum.UserInputType.MouseButton1

            or input.UserInputType == Enum.UserInputType.Touch then

                dragging = true

                dragStart = input.Position

                startPos = trackerFrame.Position

                input.Changed:Connect(function()

                    if input.UserInputState == Enum.UserInputState.End then dragging = false end

                end)

            end

        end)

        UserInputService.InputChanged:Connect(function(input)

            if not dragging then return end

            if input.UserInputType == Enum.UserInputType.MouseMovement

            or input.UserInputType == Enum.UserInputType.Touch then

                local d = input.Position - dragStart

                trackerFrame.Position = UDim2.new(

                    startPos.X.Scale, startPos.X.Offset + d.X,

                    startPos.Y.Scale, startPos.Y.Offset + d.Y

                )

            end

        end)

    end

end

local function buildTrackerText()

    local parts = {}

    for name, count in pairs(itemRewardCounts) do

        table.insert(parts, { name = name, count = count })

    end

    table.sort(parts, function(a, b)

        if a.count == b.count then return a.name < b.name end

        return a.count > b.count

    end)

    local lines = {

        string.format("Attempts: %d", prayAttemptCount),

        string.format("With loot: %d", praySuccessCount),

        "─────────",

    }

    if #parts == 0 then

        table.insert(lines, "(no items yet)")

    else

        local maxLines = 12

        for i, e in ipairs(parts) do

            if i > maxLines then

                table.insert(lines, string.format("… +%d more", #parts - maxLines))

                break

            end

            table.insert(lines, string.format("%d × %s", e.count, e.name))

        end

    end

    return table.concat(lines, "\n")

end

local function refreshTrackerUI()

    if not IsBugFixes then return end

    if trackerBody then trackerBody.Text = buildTrackerText() end

    if praySummaryLabel and praySummaryLabel.SetText then

        local top, n = {}, 0

        for name, count in pairs(itemRewardCounts) do

            n = n + 1

            if n <= 3 then table.insert(top, count .. "×" .. name) end

        end

        local summary = string.format("Attempts %d | Loot %d", prayAttemptCount, praySuccessCount)

        if #top > 0 then summary = summary .. " | " .. table.concat(top, ", ") end

        if n > 3 then summary = summary .. "…" end

        pcall(function() praySummaryLabel:SetText(summary) end)

    end

end

local function markKnownInventory()

    table.clear(knownItemInstances)

    local function scan(container)

        if not container then return end

        for _, obj in ipairs(container:GetChildren()) do

            if obj:IsA("Tool") or obj:IsA("Accessory") then

                knownItemInstances[obj] = true

            end

        end

    end

    scan(LocalPlayer:FindFirstChild("Backpack"))

    if LocalPlayer.Character then scan(LocalPlayer.Character) end

end

local function onPossibleReward(obj)

    if not obj or not (obj:IsA("Tool") or obj:IsA("Accessory")) then return end

    if knownItemInstances[obj] then return end

    if os.clock() > rewardListenUntil then return end

    knownItemInstances[obj] = true

    local name = obj.Name

    itemRewardCounts[name] = (itemRewardCounts[name] or 0) + 1

    if not currentAttemptGotReward then

        currentAttemptGotReward = true

        praySuccessCount = praySuccessCount + 1

    end

    print("[Pray] reward:", name)

    refreshTrackerUI()

end

local function hookInventoryTracking()

    local function hookContainer(container)

        if not container then return end

        container.ChildAdded:Connect(function(obj)

            task.defer(function() onPossibleReward(obj) end)

        end)

        for _, obj in ipairs(container:GetChildren()) do

            knownItemInstances[obj] = true

        end

    end

    hookContainer(LocalPlayer:FindFirstChild("Backpack"))

    LocalPlayer.CharacterAdded:Connect(function(char)

        task.wait(0.4)

        markKnownInventory()

        hookContainer(char)

        hookContainer(LocalPlayer:FindFirstChild("Backpack"))

    end)

    if LocalPlayer.Character then hookContainer(LocalPlayer.Character) end

    LocalPlayer.ChildAdded:Connect(function(child)

        if child.Name == "Backpack" then hookContainer(child) end

    end)

end

local function doHardTP(entry)

    local root, hum = getRoot()

    if not root then return false end

    tpLockCF = entry.CFrame + Vector3.new(0, 1.5, 0)

    tpProtectUntil = safeTeleportEnabled and (os.clock() + 6) or 0

    pcall(function()

        root.CFrame = tpLockCF

        root.AssemblyLinearVelocity = Vector3.zero

        root.AssemblyAngularVelocity = Vector3.zero

        if hum then hum.PlatformStand = false; hum.Sit = false end

    end)

    return true

end

local function doWarTP(entry)
    if not entry then return false end
    local cf = entry.CFrame
    if typeof(cf) ~= "CFrame" then
        if typeof(entry) == "Vector3" then
            cf = CFrame.new(entry)
        else
            return false
        end
    end
    local root, hum, char = getRoot()
    if not char or not root then
        warn("[War] TP failed: no character")
        return false
    end
    local target = cf + Vector3.new(0, 4, 0)
    local ok = pcall(function()
        if hum then
            hum.Sit = false
            hum.PlatformStand = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        char:PivotTo(target)
        root.CFrame = target
        root.AssemblyLinearVelocity = Vector3.zero
    end)
    if not ok then
        ok = pcall(function()
            root.CFrame = target
        end)
    end
    task.spawn(function()
        for _ = 1, 8 do
            task.wait(0.05)
            local r = select(1, getRoot())
            if r then
                pcall(function()
                    r.CFrame = target
                    r.AssemblyLinearVelocity = Vector3.zero
                end)
            end
        end
    end)
    if ok then
        print("[War] TP ->", target.Position)
    else
        warn("[War] TP failed")
    end
    return ok and true or false
end

local function tickSafeTP()

    if not safeTeleportEnabled or os.clock() > tpProtectUntil or not tpLockCF then return end

    local root, hum = getRoot()

    if not root then return end

    pcall(function()

        root.CFrame = tpLockCF

        root.AssemblyLinearVelocity = Vector3.zero

        root.AssemblyAngularVelocity = Vector3.zero

    end)

    if hum then

        pcall(function()

            hum.PlatformStand = false

            hum.Sit = false

            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

            hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)

            local st = hum:GetState()

            if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown

            or st == Enum.HumanoidStateType.Freefall then

                hum:ChangeState(Enum.HumanoidStateType.GettingUp)

            end

        end)

    end

end

local function fireGiveCrateItems(a1)

    local remote = ReplicatedStorage:FindFirstChild("GiveCrateItems")

    if not remote then return end

    pcall(function()

        if a1 ~= nil then remote:FireServer(a1) else remote:FireServer() end

    end)

end

local function firePrayTriggers()

    pcall(function()

        local bp = LocalPlayer:FindFirstChild("Backpack")

        local katana = bp and bp:FindFirstChild("katana")

        local epic = katana and katana:FindFirstChild("epicthing")

        if epic and epic:IsA("RemoteEvent") then epic:FireServer() end

    end)

    pcall(function()

        local char = LocalPlayer.Character

        local bowcode = char and char:FindFirstChild("bowcode")

        local bow2 = bowcode and bowcode:FindFirstChild("bow2")

        if bow2 and bow2:IsA("RemoteEvent") then bow2:FireServer() end

    end)

    fireGiveCrateItems()

    fireGiveCrateItems(LocalPlayer)

end

local function doPrayAttempt(fromAuto)

    local now = os.clock()

    if now < prayBusyUntil then return false end

    markKnownInventory()

    currentAttemptGotReward = false

    rewardListenUntil = now + 5

    prayBusyUntil = now + math.max(autoPrayInterval, 2.5)

    if autoPrayTpToShrine or not fromAuto then

        doHardTP(HardcodedTPs[2])

        task.wait(0.3)

    end

    firePrayTriggers()

    prayAttemptCount = prayAttemptCount + 1

    refreshTrackerUI()

    print("[Pray] attempt", prayAttemptCount, fromAuto and "(auto)" or "(manual)")

    return true

end

local function tickAutoPray()

    if not autoPrayEnabled or not IsBugFixes then return end

    local now = os.clock()

    if now < prayBusyUntil then return end

    if now - lastAutoPrayAttempt < autoPrayInterval then return end

    lastAutoPrayAttempt = now

    task.spawn(function() doPrayAttempt(true) end)

end

local function clearItemESP()

    for _, data in pairs(itemEspObjects) do

        if data.billboard then pcall(function() data.billboard:Destroy() end) end

        if data.highlight then pcall(function() data.highlight:Destroy() end) end

    end

    table.clear(itemEspObjects)

end

local function isItem(obj) return obj:IsA("Accessory") or obj:IsA("Tool") end

local function shouldShowItem(obj)

    if not obj or not obj.Parent then return false end

    if obj:IsA("Accessory") and not showAccessories then return false end

    if obj:IsA("Tool") and not showTools then return false end

    if not isItem(obj) then return false end

    local part = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true)

    if not part then return false end

    local root = select(1, getRoot())

    if root and (part.Position - root.Position).Magnitude > maxItemEspDistance then return false end

    local onPlayer = false

    for _, plr in ipairs(Players:GetPlayers()) do

        if (plr.Character and obj:IsDescendantOf(plr.Character))

            or (plr:FindFirstChild("Backpack") and obj:IsDescendantOf(plr.Backpack)) then

            onPlayer = true; break

        end

    end

    if showWorkspaceOnly and onPlayer then return false end

    if not showOnPlayers and onPlayer then return false end

    return true

end

local function createItemEsp(obj)

    if itemEspObjects[obj] or not shouldShowItem(obj) then return end

    local part = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true)

    if not part then return end

    local data = {}

    local hl = Instance.new("Highlight")

    hl.Adornee = obj

    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    hl.FillColor = obj:IsA("Tool") and Color3.fromRGB(255, 180, 50) or Color3.fromRGB(100, 200, 255)

    hl.OutlineColor = Color3.fromRGB(255, 255, 255)

    hl.FillTransparency = 0.6

    hl.Parent = CoreGui

    data.highlight = hl

    local bb = Instance.new("BillboardGui")

    bb.Adornee = part

    bb.Size = UDim2.new(0, 150, 0, 40)

    bb.StudsOffset = Vector3.new(0, 2, 0)

    bb.AlwaysOnTop = true

    bb.Parent = CoreGui

    local label = Instance.new("TextLabel")

    label.Size = UDim2.fromScale(1, 1)

    label.BackgroundTransparency = 1

    label.Text = obj.Name .. "\n[" .. obj.ClassName .. "]"

    label.TextColor3 = Color3.fromRGB(255, 255, 255)

    label.TextStrokeTransparency = 0

    label.Font = Enum.Font.Code

    label.TextSize = 12

    label.Parent = bb

    data.billboard = bb

    itemEspObjects[obj] = data

end

local function trackItem(obj) if isItem(obj) then trackedItems[obj] = true end end

local function untrackItem(obj)

    trackedItems[obj] = nil

    local data = itemEspObjects[obj]

    if data then

        if data.billboard then pcall(function() data.billboard:Destroy() end) end

        if data.highlight then pcall(function() data.highlight:Destroy() end) end

        itemEspObjects[obj] = nil

    end

end

local function initialItemScan()

    table.clear(trackedItems)

    for _, obj in ipairs(Workspace:GetDescendants()) do trackItem(obj) end

    for _, plr in ipairs(Players:GetPlayers()) do

        if plr.Character then for _, obj in ipairs(plr.Character:GetChildren()) do trackItem(obj) end end

        local bp = plr:FindFirstChild("Backpack")

        if bp then for _, obj in ipairs(bp:GetChildren()) do trackItem(obj) end end

    end

end

Workspace.DescendantAdded:Connect(function(obj) if isItem(obj) then trackItem(obj) end end)

Workspace.DescendantRemoving:Connect(function(obj) if trackedItems[obj] then untrackItem(obj) end end)

local function updateItemESP()

    if not itemEspEnabled then clearItemESP() return end

    for obj in pairs(trackedItems) do

        if not obj.Parent then untrackItem(obj)

        elseif shouldShowItem(obj) then createItemEsp(obj)

        else

            local data = itemEspObjects[obj]

            if data then

                if data.billboard then pcall(function() data.billboard:Destroy() end) end

                if data.highlight then pcall(function() data.highlight:Destroy() end) end

                itemEspObjects[obj] = nil

            end

        end

    end

end

assert(Library, "[Testing] Library failed to load — check HttpGet / host")

local Window = Library:CreateWindow({

    Title = "Testing",

    Center = true,

    AutoShow = true,

    TabPadding = 8,

    MenuFadeTime = 0.2,

})

local Tabs = {

    Zex = Window:AddTab("Zex"),

    ESP = Window:AddTab("ESP"),

    Visuals = Window:AddTab("Visuals"),

    Misc = Window:AddTab("Misc"),

    GameMods = Window:AddTab("Game Mods"),

    Settings = Window:AddTab("Settings"),

}

RunService.PreRender:Connect(function()

    if RenderAverage then

        local v = RenderAverage:GetValue()

        if typeof(v) == "number" and v > 0 then FrameRate = math.floor(1000 / v) end

    end

    pcall(function() Ping = math.floor(DataPing:GetValue()) end)

end)

task.spawn(function()

    while true do

        task.wait(1)

        if Library and Library.SetWatermark then

            pcall(function()

                Library:SetWatermark(string.format(

                    "Testing » %dfps » %dms » %s » %s",

                    FrameRate, Ping, string.lower(LocalPlayer.Name), getCoordsString()

                ))

            end)

        end

    end

end)

local MovementBox = Tabs.Zex:AddLeftGroupbox("Movement")

MovementBox:AddToggle("NoFall", {

    Text = "No Fall Damage", Default = false,

    Callback = function(v)

        noFallEnabled = v

        if fallConnection then fallConnection:Disconnect(); fallConnection = nil end

        if v then

            fallConnection = RunService.Heartbeat:Connect(function()

                local _, hum = getRoot()

                if not hum then return end

                pcall(function()

                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

                    hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)

                    if hum:GetState() == Enum.HumanoidStateType.Freefall then

                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)

                    end

                end)

            end)

        end

    end

})

MovementBox:AddToggle("CFrameSpeed", { Text = "CFrame Speed", Default = false, Callback = function(v) cframeEnabled = v end })

MovementBox:AddSlider("CFrameSpeedValue", { Text = "CFrame Speed", Min = 10, Max = 150, Default = 50, Rounding = 0, Callback = function(v) cframeSpeed = v end })

local FOVBox = Tabs.Zex:AddRightGroupbox("FOV")

FOVBox:AddSlider("FOV", { Text = "FOV", Min = 30, Max = 120, Default = 70, Rounding = 0, Callback = function(v) currentFOV = v; pcall(function() Camera.FieldOfView = v end) end })

FOVBox:AddToggle("LockFOV", { Text = "Lock FOV", Default = false, Callback = function(v) lockFOV = v end })

local RainbowBox = Tabs.Zex:AddLeftGroupbox("Rainbow")

RainbowBox:AddToggle("RainbowBody", { Text = "Rainbow Body", Default = false, Callback = function(v) rainbowBody = v end })

RainbowBox:AddSlider("BodyTransparency", { Text = "Body Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Callback = function(v) charTransparency = v end })

RainbowBox:AddSlider("BodySpeed", { Text = "Body Speed", Min = 0.001, Max = 0.05, Default = 0.008, Rounding = 3, Callback = function(v) rainbowBodySpeed = v end })

RainbowBox:AddToggle("RainbowGun", { Text = "Rainbow Gun", Default = false, Callback = function(v) rainbowGun = v end })

RainbowBox:AddSlider("GunTransparency", { Text = "Gun Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Callback = function(v) gunTransparency = v end })

RainbowBox:AddSlider("GunSpeed", { Text = "Gun Speed", Min = 0.001, Max = 0.05, Default = 0.015, Rounding = 3, Callback = function(v) rainbowGunSpeed = v end })

local HeadBox = Tabs.Zex:AddRightGroupbox("Limb Extender")

HeadBox:AddToggle("HeadExpand", {

    Text = "Enabled", Default = false,

    Callback = function(v)

        headExpandEnabled = v

        if LimbExtender then

            pcall(function()

                if v then

                    LimbExtender:Set("TARGET_LIMB", "Head")

                    LimbExtender:Set("LIMB_SIZE", headSize)

                    LimbExtender:Start()

                else LimbExtender:Stop() end

            end)

        end

    end

})

HeadBox:AddSlider("HeadSize", {

    Text = "Limb Size", Min = 5, Max = 50, Default = 5, Rounding = 0,

    Callback = function(v)

        headSize = v

        if LimbExtender and headExpandEnabled then pcall(function() LimbExtender:Set("LIMB_SIZE", v) end) end

    end

})

HeadBox:AddDropdown("TargetLimb", {

    Text = "Target Limb", Default = 1,

    Values = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},

    Callback = function(v)

        if LimbExtender and headExpandEnabled then pcall(function() LimbExtender:Set("TARGET_LIMB", v) end) end

    end

})

local InteractBox = Tabs.Zex:AddLeftGroupbox("Interaction")

InteractBox:AddToggle("QuickInteract", {

    Text = "Quick Interact", Default = false,

    Callback = function(v)

        quickInteract = v

        for _, obj in ipairs(workspace:GetDescendants()) do

            if obj:IsA("ProximityPrompt") then

                if v then

                    if not originalPrompts[obj] then

                        originalPrompts[obj] = { HoldDuration = obj.HoldDuration, RequiresLineOfSight = obj.RequiresLineOfSight }

                    end

                    pcall(function() obj.HoldDuration = 0; obj.RequiresLineOfSight = false end)

                else

                    local o = originalPrompts[obj]

                    if o then pcall(function() obj.HoldDuration = o.HoldDuration; obj.RequiresLineOfSight = o.RequiresLineOfSight end) end

                end

            end

        end

    end

})

workspace.DescendantAdded:Connect(function(obj)

    if quickInteract and obj:IsA("ProximityPrompt") then

        pcall(function() obj.HoldDuration = 0; obj.RequiresLineOfSight = false end)

    end

end)

local ChamsBox = Tabs.Zex:AddLeftGroupbox("Chams")

ChamsBox:AddToggle("SimpleChams", {

    Text = "Simple Chams", Default = false,

    Callback = function(v)

        chamsEnabled = v

        if not v then

            for _, hl in pairs(ChamObjects) do if hl then pcall(function() hl:Destroy() end) end end

            ChamObjects = {}

        end

    end

})

local function RemoveESP(player)

    local data = espObjects[player]

    if not data then return end

    for _, object in pairs(data) do

        if typeof(object) == "Instance" then pcall(function() object:Destroy() end) end

    end

    espObjects[player] = nil

end

local function CreateESP(player)

    if player == LocalPlayer or espObjects[player] then return end

    local data = {}

    local highlight = Instance.new("Highlight")

    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    highlight.Enabled = false

    highlight.Parent = CoreGui

    data.Highlight = highlight

    local billboard = Instance.new("BillboardGui")

    billboard.Size = UDim2.new(0, 220, 0, 100)

    billboard.StudsOffset = Vector3.new(0, -3.5, 0)

    billboard.AlwaysOnTop = true

    billboard.Enabled = false

    billboard.Parent = CoreGui

    data.Billboard = billboard

    local text = Instance.new("TextLabel")

    text.BackgroundTransparency = 1

    text.Size = UDim2.fromScale(1, 1)

    text.Font = Enum.Font.Code

    text.TextSize = 13

    text.TextStrokeTransparency = 0

    text.TextColor3 = Color3.fromRGB(255, 255, 255)

    text.TextYAlignment = Enum.TextYAlignment.Top

    text.Parent = billboard

    data.Text = text

    espObjects[player] = data

end

local function UpdatePlayerESP(player)

    if player == LocalPlayer then return end

    local data = espObjects[player]

    if not espEnabled then

        if data then data.Highlight.Enabled = false; data.Billboard.Enabled = false end

        return

    end

    local character = player.Character

    local root = character and character:FindFirstChild("HumanoidRootPart")

    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid then

        if data then data.Highlight.Enabled = false; data.Billboard.Enabled = false end

        return

    end

    if not espRenderTeam and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then

        if data then data.Highlight.Enabled = false; data.Billboard.Enabled = false end

        return

    end

    local localRoot = select(1, getRoot())

    if not localRoot then return end

    local distance = (root.Position - localRoot.Position).Magnitude

    if distance > espRenderDistance then

        if data then data.Highlight.Enabled = false; data.Billboard.Enabled = false end

        return

    end

    CreateESP(player)

    data = espObjects[player]

    if not data then return end

    local outlineCol, fillCol = colorsForPlayer(player)

    local status = getPlayerStatus(player)

    data.Highlight.Adornee = character

    data.Highlight.OutlineColor = outlineCol

    data.Highlight.FillColor = fillCol

    data.Highlight.OutlineTransparency = espBox and 0 or 1

    data.Highlight.FillTransparency = espBoxFill and espBoxFillTransparency or 1

    data.Highlight.Enabled = espBox or espBoxFill

    local lines = {}

    if espName then

        local tag = status == "friend" and " [FRIEND]" or (status == "kos" and " [KOS]" or "")

        table.insert(lines, player.Name .. tag)

    end

    if espDistance then table.insert(lines, string.format("[%d studs]", math.floor(distance))) end

    if espHealthText then table.insert(lines, string.format("HP: %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))) end

    if espTool then

        local tool = character:FindFirstChildOfClass("Tool")

        if tool then table.insert(lines, tool.Name) end

    end

    local nameCol = espNameColor

    if status == "friend" then nameCol = friendColor elseif status == "kos" then nameCol = kosColor end

    data.Text.Text = table.concat(lines, "\n")

    data.Text.TextColor3 = nameCol

    data.Billboard.Adornee = root

    data.Billboard.Enabled = #lines > 0

end

local function UpdateAllESP()

    for _, p in ipairs(Players:GetPlayers()) do UpdatePlayerESP(p) end

end

local ESPPlayers = Tabs.ESP:AddLeftGroupbox("Players")

local ESPSettings = Tabs.ESP:AddRightGroupbox("Settings")

local ESPList = Tabs.ESP:AddLeftGroupbox("Player List")

local ESPColors = Tabs.ESP:AddRightGroupbox("Friend / KOS Colors")

ESPPlayers:AddToggle("ESPEnabled", { Text = "Enabled", Default = false, Callback = function(v) espEnabled = v; if not v then UpdateAllESP() end end })

ESPPlayers:AddToggle("ESPBox", { Text = "Bounding Box", Default = false, Callback = function(v) espBox = v end }):AddColorPicker("ESPBoxColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Default Box", Callback = function(v) espBoxColor = v end })

ESPPlayers:AddToggle("ESPBoxFill", { Text = "Fill Box", Default = false, Callback = function(v) espBoxFill = v end }):AddColorPicker("ESPBoxFillColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Default Fill", Transparency = 0.5, Callback = function(v) espFillColor = v end })

ESPPlayers:AddSlider("ESPFillTransparency", { Text = "Fill Transparency", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Callback = function(v) espBoxFillTransparency = v end })

ESPPlayers:AddToggle("ESPName", { Text = "Name", Default = false, Callback = function(v) espName = v end }):AddColorPicker("ESPNameColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Default Name", Callback = function(v) espNameColor = v end })

ESPPlayers:AddToggle("ESPDistance", { Text = "Distance", Default = false, Callback = function(v) espDistance = v end })

ESPPlayers:AddToggle("ESPHealthText", { Text = "Health Text", Default = false, Callback = function(v) espHealthText = v end })

ESPPlayers:AddToggle("ESPTool", { Text = "Tool", Default = false, Callback = function(v) espTool = v end })

ESPSettings:AddSlider("ESPRenderHz", { Text = "Render Hertz", Min = 10, Max = 240, Default = 60, Rounding = 0, Callback = function(v) espRenderHz = v end })

ESPSettings:AddSlider("ESPRenderDistance", { Text = "Render Distance", Min = 10, Max = 1000, Default = 500, Rounding = 0, Callback = function(v) espRenderDistance = v end })

ESPSettings:AddToggle("ESPRenderTeam", { Text = "Render Teammates", Default = false, Callback = function(v) espRenderTeam = v end })

playerDropdown = ESPList:AddDropdown("ESPPlayerSelect", {

    Text = "Select Player", Default = 1, Values = getPlayerNames(),

    Callback = function(v) selectedPlayerName = v end

})

ESPList:AddButton("Mark Friend", function() local p = findPlayerByName(selectedPlayerName); if p then setFriend(p) end end)

ESPList:AddButton("Mark KOS", function() local p = findPlayerByName(selectedPlayerName); if p then setKOS(p) end end)

ESPList:AddButton("Clear Status", function() local p = findPlayerByName(selectedPlayerName); if p then clearStatus(p) end end)

ESPList:AddButton("Refresh List", function() refreshPlayerDropdown() end)

ESPList:AddButton("Clear All Friends", function() table.clear(friendUsers) end)

ESPList:AddButton("Clear All KOS", function() table.clear(kosUsers) end)

ESPColors:AddLabel("Friend Color"):AddColorPicker("FriendESPColor", {

    Default = Color3.fromRGB(0, 255, 100), Title = "Friend ESP", Callback = function(v) friendColor = v end

})

ESPColors:AddLabel("KOS / Enemy Color"):AddColorPicker("KOSESPColor", {

    Default = Color3.fromRGB(255, 50, 50), Title = "KOS ESP", Callback = function(v) kosColor = v end

})

local PlayerBoxV = Tabs.Visuals:AddGroupbox({ Side = 2, Name = "Player" })

local CameraBox = Tabs.Visuals:AddGroupbox({ Side = 2, Name = "Camera" })

local LightingModule = LoadModule(

    "https://raw.githubusercontent.com/LTFxGUILT/asdasd/refs/heads/main/Lighting.Luau"

)

if LightingModule then

    local WorldModule

    WorldModule = LightingModule.new({

        Tabs = Tabs,

        Toggles = Toggles,

        SkyNames = SkyNames,

        ApplySkybox = function(name)

            skyboxEnabled = WorldModule and WorldModule.SkyboxEnabled or false

            return ApplySkybox(name)

        end,

    })

    WorldModule:Init()

end

local ChineseHat = AddToggle(PlayerBoxV, "visuals/player/chinesehat", { Text = "Chinese Hat", Default = false })

ChineseHat:AddColorPicker("visuals/player/chinesehat/color", { Default = Color3.fromRGB(255, 255, 255), Title = "Chinese Hat Color" })

local ChineseHatDep = PlayerBoxV:AddDependencyBox()

ChineseHatDep:AddSlider("visuals/player/chinesehat/glowfac", { Text = "Glow Factor", Min = 10, Max = 20, Rounding = 0, Default = 10 })

ChineseHatDep:AddSlider("visuals/player/chinesehat/radius", { Text = "Radius", Min = 0, Max = 2, Rounding = 1, Default = 1.5 })

ChineseHatDep:AddSlider("visuals/player/chinesehat/height", { Text = "Height", Min = 0, Max = 2, Rounding = 1, Default = 1 })

ChineseHatDep:AddToggle("visuals/player/chinesehat/alwaysontop", { Text = "Always On Top", Default = false })

ChineseHatDep:SetupDependencies({ { Toggles["visuals/player/chinesehat"], true } })

AddToggle(PlayerBoxV, "visuals/player/appearance", { Text = "Appearance Changer", Default = false })

PlayerBoxV:AddInput("visuals/player/appearance/id", { Numeric = true, Finished = true, Text = "UserId" })

local Breadcrumbs = AddToggle(PlayerBoxV, "visuals/player/breadcrumbs", { Text = "Breadcrumbs", Default = false })

Breadcrumbs:AddColorPicker("visuals/player/breadcrumbs/color", { Default = Color3.fromRGB(255, 255, 255), Title = "Breadcrumbs Color" })

local BreadcrumbsDep = PlayerBoxV:AddDependencyBox()

BreadcrumbsDep:AddSlider("visuals/player/breadcrumbs/glowfac", { Text = "Glow Factor", Min = 10, Max = 20, Rounding = 0, Default = 10 })

BreadcrumbsDep:AddSlider("visuals/player/breadcrumbs/lifetime", { Text = "Life Time", Min = 0.1, Max = 5, Rounding = 1, Default = 5 })

BreadcrumbsDep:AddSlider("visuals/player/breadcrumbs/fadetime", { Text = "Fade Time", Min = 0.1, Max = 5, Rounding = 1, Default = 5 })

BreadcrumbsDep:SetupDependencies({ { Toggles["visuals/player/breadcrumbs"], true } })

AddToggle(CameraBox, "visuals/camera/waifu", { Text = "Waifu", Default = false })

local WaifuDep = CameraBox:AddDependencyBox()

WaifuDep:AddInput("visuals/camera/waifu/link", { Text = "Image / GIF URL", Default = "" })

WaifuDep:AddSlider("visuals/camera/waifu/x", { Text = "X", Min = -1920, Max = 1920, Rounding = 0, Default = 0 })

WaifuDep:AddSlider("visuals/camera/waifu/y", { Text = "Y", Min = -1080, Max = 1080, Rounding = 0, Default = 0 })

WaifuDep:AddSlider("visuals/camera/waifu/transparency", { Text = "Transparency", Min = 0, Max = 1, Rounding = 1, Default = 0.5 })

WaifuDep:AddSlider("visuals/camera/waifu/scale", { Text = "Scale", Min = 0, Max = 1, Rounding = 1, Default = 0.5 })

WaifuDep:SetupDependencies({ { Toggles["visuals/camera/waifu"], true } })

local Movement = Tabs.Misc:AddGroupbox({ Side = 1, Name = "Movement" })

local Exploits = Tabs.Misc:AddGroupbox({ Side = 2, Name = "Exploits" })

local ClientBox = Tabs.Misc:AddGroupbox({ Side = 1, Name = "Client" })

local DesyncBox = Tabs.Misc:AddGroupbox({ Side = 2, Name = "Namsync" })

local miscMovementState = {
    character = nil,
    humanoid = nil,
    root = nil,
    originalWalkSpeed = nil,
    originalAutoRotate = nil,
    originalCanCollide = {},
    noClipCharacter = nil,
    autoJumpTimer = 0,
    wasFlying = false,
    wasSpeeding = false,
    speedMethod = nil,
    wasMoonWalking = false,
}

local function miscGetCharacter()
    local char = LocalPlayer.Character
    if not char then
        return nil, nil, nil
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
end

local function miscGetValue(flag, fallback)
    local option = Options and Options[flag]
    if not option then
        return fallback
    end

    local ok, value = pcall(function()
        return option.Value
    end)

    if ok and value ~= nil then
        return value
    end

    return fallback
end

local function miscToggleEnabled(flag)
    local toggle = Toggles[flag]
    if not toggle then
        return false
    end

    local ok, value = pcall(function()
        return toggle.Value
    end)

    return ok and value == true
end

local function miscKeyHeld(flag)
    local key = Options and Options[flag]
    if not key or not key.GetState then
        return false
    end

    local ok, state = pcall(function()
        return key:GetState()
    end)

    return ok and state == true
end

local function miscRestoreWalkSpeed(humanoid)
    if humanoid and humanoid.Parent and miscMovementState.originalWalkSpeed ~= nil then
        pcall(function()
            humanoid.WalkSpeed = miscMovementState.originalWalkSpeed
        end)
    end
    miscMovementState.originalWalkSpeed = nil
    miscMovementState.wasSpeeding = false
    miscMovementState.speedMethod = nil
end

local function miscRestoreAutoRotate(humanoid)
    if humanoid and humanoid.Parent and miscMovementState.originalAutoRotate ~= nil then
        pcall(function()
            humanoid.AutoRotate = miscMovementState.originalAutoRotate
        end)
    end
    miscMovementState.originalAutoRotate = nil
    miscMovementState.wasMoonWalking = false
end

local function miscRestoreNoClip()
    for part, original in pairs(miscMovementState.originalCanCollide) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = original
            end)
        end
    end

    table.clear(miscMovementState.originalCanCollide)
    miscMovementState.noClipCharacter = nil
end

local function miscApplyNoClip(character)
    if miscMovementState.noClipCharacter ~= character then
        miscRestoreNoClip()
        miscMovementState.noClipCharacter = character
    end

    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            if miscMovementState.originalCanCollide[obj] == nil then
                miscMovementState.originalCanCollide[obj] = obj.CanCollide
            end
            obj.CanCollide = false
        end
    end
end

local function miscGetDirectionalMove(humanoid)
    local move = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move += Vector3.new(0, 0, 1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move += Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Vector3.new(1, 0, 0) end

    if move.Magnitude <= 0 then
        return humanoid.MoveDirection
    end

    move = move.Unit
    local camera = workspace.CurrentCamera
    if not camera then
        return humanoid.MoveDirection
    end

    local look = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    local flatRight = Vector3.new(right.X, 0, right.Z)

    if flatLook.Magnitude <= 0 or flatRight.Magnitude <= 0 then
        return humanoid.MoveDirection
    end

    flatLook = flatLook.Unit
    flatRight = flatRight.Unit
    local direction = flatRight * move.X - flatLook * move.Z
    return direction.Magnitude > 0 and direction.Unit or Vector3.zero
end

local function miscUpdateMovement(dt)
    local character, humanoid, root = miscGetCharacter()

    if character ~= miscMovementState.character then
        if miscMovementState.humanoid then
            miscRestoreWalkSpeed(miscMovementState.humanoid)
            miscRestoreAutoRotate(miscMovementState.humanoid)
        end
        miscRestoreNoClip()
        miscMovementState.character = character
        miscMovementState.humanoid = humanoid
        miscMovementState.root = root
        miscMovementState.autoJumpTimer = 0
        miscMovementState.wasFlying = false
        miscMovementState.speedMethod = nil
    end

    if not character or not humanoid or not root then
        return
    end

    local speedEnabled = miscToggleEnabled("misc/movement/speed")
    if speedEnabled then
        local speed = math.max(1, tonumber(miscGetValue("misc/movement/speed/value", 30)) or 30)
        local method = miscGetValue("misc/movement/speed/method", "Directional")
        if type(method) == "number" then
            method = ({"Directional", "MoveDir"})[method] or "Directional"
        end

        if not miscMovementState.wasSpeeding then
            miscMovementState.originalWalkSpeed = humanoid.WalkSpeed
            miscMovementState.wasSpeeding = true
        end

        if miscMovementState.speedMethod ~= method then
            if miscMovementState.speedMethod == "MoveDir" and miscMovementState.originalWalkSpeed ~= nil then
                pcall(function() humanoid.WalkSpeed = miscMovementState.originalWalkSpeed end)
            end
            miscMovementState.speedMethod = method
        end

        if method == "MoveDir" then
            pcall(function()
                humanoid.WalkSpeed = speed
            end)
        else
            pcall(function()
                if miscMovementState.originalWalkSpeed ~= nil then
                    humanoid.WalkSpeed = miscMovementState.originalWalkSpeed
                end
                local direction = miscGetDirectionalMove(humanoid)
                if direction.Magnitude > 0.01 then
                    root.CFrame = root.CFrame + direction * speed * dt
                end
            end)
        end
    elseif miscMovementState.wasSpeeding then
        miscRestoreWalkSpeed(humanoid)
    end

    local moonwalkActive = miscToggleEnabled("misc/movement/moonwalk")
        and miscKeyHeld("misc/movement/moonwalk/key")

    if moonwalkActive then
        if not miscMovementState.wasMoonWalking then
            miscMovementState.originalAutoRotate = humanoid.AutoRotate
        end

        pcall(function()
            humanoid.AutoRotate = false
            local move = humanoid.MoveDirection
            if move.Magnitude > 0.05 then
                root.CFrame = CFrame.lookAt(root.Position, root.Position - move.Unit)
            end
        end)
        miscMovementState.wasMoonWalking = true
    elseif miscMovementState.wasMoonWalking then
        miscRestoreAutoRotate(humanoid)
    end

    local autoJump = miscToggleEnabled("misc/movement/autojump")
    if autoJump then
        miscMovementState.autoJumpTimer -= dt
        if miscMovementState.autoJumpTimer <= 0 then
            local method = miscGetValue("misc/movement/autojump/method", "Humanoid")
            if type(method) == "number" then
                method = ({"Humanoid", "Velocity", "State"})[method] or "Humanoid"
            end

            local state = humanoid:GetState()
            local grounded = state == Enum.HumanoidStateType.Running
                or state == Enum.HumanoidStateType.RunningNoPhysics
                or state == Enum.HumanoidStateType.Landed

            if grounded then
                pcall(function()
                    if method == "Velocity" then
                        local v = root.AssemblyLinearVelocity
                        root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 42), v.Z)
                    elseif method == "State" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    else
                        humanoid.Jump = true
                    end
                end)
                miscMovementState.autoJumpTimer = 0.12
            else
                miscMovementState.autoJumpTimer = 0.05
            end
        end
    else
        miscMovementState.autoJumpTimer = 0
    end

    local flyActive = miscToggleEnabled("misc/movement/fly")
        and miscKeyHeld("misc/movement/fly/key")

    if flyActive then
        local flySpeed = math.max(1, tonumber(miscGetValue("misc/movement/flyspeed/value", 30)) or 30)
        local camera = workspace.CurrentCamera
        local move = humanoid.MoveDirection

        if camera then
            local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
            local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
            local horizontal = Vector3.zero

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then horizontal += forward end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then horizontal -= forward end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then horizontal += right end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then horizontal -= right end

            if horizontal.Magnitude > 0 then
                move = horizontal.Unit
            elseif move.Magnitude > 0 then
                move = move.Unit
            else
                move = Vector3.zero
            end
        end

        local vertical = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical += 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
            vertical -= 1
        end

        pcall(function()
            humanoid.AutoRotate = false
            root.AssemblyLinearVelocity = (move * flySpeed) + Vector3.new(0, vertical * flySpeed, 0)
        end)
        miscMovementState.wasFlying = true
    elseif miscMovementState.wasFlying then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            humanoid.AutoRotate = true
        end)
        miscMovementState.wasFlying = false
    end

    local noClipActive = miscToggleEnabled("misc/movement/noclip")
        and miscKeyHeld("misc/movement/noclip/key")

    if noClipActive then
        miscApplyNoClip(character)
    elseif next(miscMovementState.originalCanCollide) ~= nil then
        miscRestoreNoClip()
    end

    local pixelSurfActive = miscToggleEnabled("misc/movement/pixelsurf")
        and miscKeyHeld("misc/movement/pixelsurf/key")

    if pixelSurfActive then
        pcall(function()
            local v = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, -2), v.Z)
        end)
    end
end

local movementCharacterConnection = LocalPlayer.CharacterAdded:Connect(function(character)
    if miscMovementState.humanoid then
        miscRestoreWalkSpeed(miscMovementState.humanoid)
        miscRestoreAutoRotate(miscMovementState.humanoid)
    end
    miscRestoreNoClip()
    miscMovementState.character = character
    miscMovementState.humanoid = nil
    miscMovementState.root = nil
    miscMovementState.autoJumpTimer = 0
    miscMovementState.wasFlying = false
end)

AddToggle(Movement, "misc/movement/speed", { Text = "Speed Hack", Default = false })

Movement:AddSlider("misc/movement/speed/value", { Text = "Speed Hack Value", Min = 1, Max = 500, Rounding = 0, Default = 30 })

Movement:AddDropdown("misc/movement/speed/method", { Text = "Speed Hack Method", Default = 1, Values = {"Directional", "MoveDir"} })

AddToggle(Movement, "misc/movement/moonwalk", { Text = "Moon Walk", Default = false }):AddKeyPicker("misc/movement/moonwalk/key", { Text = "Moon Walk Key", SyncToggleState = false, Mode = "Hold", Default = "T" })

AddToggle(Movement, "misc/movement/autojump", { Text = "Auto Jump", Default = false })

Movement:AddDropdown("misc/movement/autojump/method", { Text = "Auto Jump Method", Default = 1, Values = {"Humanoid", "Velocity", "State"} })

AddToggle(Movement, "misc/movement/fly", { Text = "Fly", Default = false }):AddKeyPicker("misc/movement/fly/key", { Text = "Fly Key", SyncToggleState = false, Mode = "Hold", Default = "T" })

Movement:AddSlider("misc/movement/flyspeed/value", { Text = "Fly Speed", Min = 1, Max = 500, Rounding = 0, Default = 30 })

AddToggle(Movement, "misc/movement/noclip", { Text = "No Collisions", Default = false }):AddKeyPicker("misc/movement/noclip/key", { Text = "No Collisions Key", SyncToggleState = false, Mode = "Hold", Default = "T" })

AddToggle(Movement, "misc/movement/pixelsurf", { Text = "Pixel Surf", Default = false }):AddKeyPicker("misc/movement/pixelsurf/key", { Text = "Pixel Surf Key", SyncToggleState = false, Mode = "Hold", Default = "F" })

AddToggle(Exploits, "misc/exploits/antifling", { Text = "Anti Fling", Default = false })

ClientBox:AddToggle("AntiAFK", {

    Text = "Anti AFK", Default = false,

    Callback = function(v)

        if antiAfkConnection then antiAfkConnection:Disconnect(); antiAfkConnection = nil end

        if v then

            antiAfkConnection = LocalPlayer.Idled:Connect(function()

                pcall(function()

                    VirtualUser:CaptureController()

                    VirtualUser:ClickButton2(Vector2.new())

                end)

            end)

        end

    end

})

ClientBox:AddButton("Respawn", function()

    local _, hum = getRoot()

    if hum then hum.Health = 0 else pcall(function() LocalPlayer:LoadCharacter() end) end

end)

ClientBox:AddButton("Rejoin", function()

    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)

end)

AddToggle(DesyncBox, "misc/desync", { Text = "Enable", Default = false })

AddToggle(DesyncBox, "misc/desync/freezepos", { Text = "Freeze Position", Default = false }):AddKeyPicker("misc/desync/freezepos/key", { Text = "Freeze Pos Key", SyncToggleState = false, Mode = "Hold", Default = "E" })

AddToggle(DesyncBox, "misc/desync/randompos", { Text = "Random Position", Default = false }):AddKeyPicker("misc/desync/randompos/key", { Text = "Random Pos Key", SyncToggleState = false, Mode = "Toggle", Default = "F" })

local RandomPosDep = DesyncBox:AddDependencyBox()

RandomPosDep:AddSlider("misc/desync/randompos/x", { Text = "X", Min = -360, Max = 360, Rounding = 0, Default = 0 })

RandomPosDep:AddSlider("misc/desync/randompos/y", { Text = "Y", Min = -360, Max = 360, Rounding = 0, Default = 0 })

RandomPosDep:AddSlider("misc/desync/randompos/z", { Text = "Z", Min = -360, Max = 360, Rounding = 0, Default = 0 })

RandomPosDep:SetupDependencies({ { Toggles["misc/desync/randompos"], true } })

AddToggle(DesyncBox, "misc/desync/offset", { Text = "Offset", Default = false })

local OffsetDep = DesyncBox:AddDependencyBox()

OffsetDep:AddSlider("misc/desync/offset/x", { Text = "X", Min = -360, Max = 360, Rounding = 0, Default = 0 })

OffsetDep:AddSlider("misc/desync/offset/y", { Text = "Y", Min = -360, Max = 360, Rounding = 0, Default = 0 })

OffsetDep:AddSlider("misc/desync/offset/z", { Text = "Z", Min = -360, Max = 360, Rounding = 0, Default = 0 })

OffsetDep:AddSlider("misc/desync/offset/speed", { Text = "Animation Speed", Min = 0, Max = 100, Rounding = 1, Default = 10 })

OffsetDep:AddDropdown("misc/desync/offset/animation", {

    Text = "Animation", Default = 1,

    Values = {"None", "Sine", "Cosine", "Triangle", "Square", "Sawtooth", "SmoothStep", "Circle", "Figure8", "Spiral"}

})

OffsetDep:SetupDependencies({ { Toggles["misc/desync/offset"], true } })

AddToggle(DesyncBox, "misc/desync/jitter", { Text = "Jitter", Default = false })

local JitterDep = DesyncBox:AddDependencyBox()

JitterDep:AddSlider("misc/desync/jitter/x", { Text = "X", Min = -360, Max = 360, Rounding = 0, Default = 0 })

JitterDep:AddSlider("misc/desync/jitter/y", { Text = "Y", Min = -360, Max = 360, Rounding = 0, Default = 0 })

JitterDep:AddSlider("misc/desync/jitter/z", { Text = "Z", Min = -360, Max = 360, Rounding = 0, Default = 0 })

JitterDep:AddSlider("misc/desync/jitter/speed", { Text = "Speed", Min = 1, Max = 60, Rounding = 0, Default = 10 })

JitterDep:SetupDependencies({ { Toggles["misc/desync/jitter"], true } })

AddToggle(DesyncBox, "misc/desync/rotation", { Text = "Rotation Offset", Default = false })

local RotationDep = DesyncBox:AddDependencyBox()

RotationDep:AddSlider("misc/desync/rotation/x", { Text = "Pitch", Min = -180, Max = 180, Rounding = 0, Default = 0 })

RotationDep:AddSlider("misc/desync/rotation/y", { Text = "Yaw", Min = -180, Max = 180, Rounding = 0, Default = 0 })

RotationDep:AddSlider("misc/desync/rotation/z", { Text = "Roll", Min = -180, Max = 180, Rounding = 0, Default = 0 })

RotationDep:AddToggle("misc/desync/rotation/randomize", { Text = "Randomize Rotation", Default = false })

RotationDep:AddSlider("misc/desync/rotation/speed", { Text = "Animation Speed", Min = 0, Max = 100, Rounding = 1, Default = 10 })

RotationDep:AddDropdown("misc/desync/rotation/animation", {

    Text = "Animation", Default = 1,

    Values = {"None", "Sine", "Cosine", "Triangle", "Square", "Sawtooth", "SmoothStep"}

})

RotationDep:SetupDependencies({ { Toggles["misc/desync/rotation"], true } })

DesyncBox:AddSlider("misc/desync/speed", { Text = "Speed", Min = 0, Max = 100, Rounding = 1, Default = 1 })

AddToggle(DesyncBox, "misc/desync/useeasingstyle", { Text = "Use Easing Style", Default = false })

DesyncBox:AddDropdown("misc/desync/easingstyle", {

    Text = "Easing Style", Default = 1,

    Values = {"Sine", "Quad", "Cubic", "Quart", "Quint", "Exponential", "Circular", "Linear", "SmoothStep", "SmootherStep", "Back", "Elastic", "Bounce"}

})

DesyncBox:AddDropdown("misc/desync/easingdirection", {

    Text = "Easing Direction", Default = 3, Values = {"In", "Out", "InOut"}

})

local ChatLogger = LoadModule("https://raw.githubusercontent.com/LTFxGUILT/asdasd/refs/heads/main/ChatLogger.luau")

local GameInfo = Tabs.GameMods:AddLeftGroupbox("Game Info")

GameInfo:AddLabel("Place : " .. PlaceName)

GameInfo:AddLabel("ID : " .. tostring(PlaceId))

if IsBugFixes then

    GameInfo:AddLabel("Status : Supported")

    local TpSafety = Tabs.GameMods:AddRightGroupbox("Teleport Safety")

    TpSafety:AddToggle("SafeTP", {

        Text = "Anti Fall / Ragdoll on TP", Default = true,

        Callback = function(v)

            safeTeleportEnabled = v

            if not v then tpProtectUntil = 0; tpLockCF = nil end

        end

    })

    local SafeZones = Tabs.GameMods:AddLeftGroupbox("Teleports")

    for _, loc in ipairs(HardcodedTPs) do

        SafeZones:AddButton(loc.Name, function() doHardTP(loc) end)

    end

    local EspBox = Tabs.GameMods:AddLeftGroupbox("Item ESP")

    EspBox:AddToggle("ItemESP_Enabled", {

        Text = "Enabled", Default = false,

        Callback = function(v) itemEspEnabled = v; if v then initialItemScan() else clearItemESP() end end

    })

    EspBox:AddToggle("ItemESP_Accessories", { Text = "Accessories", Default = true, Callback = function(v) showAccessories = v end })

    EspBox:AddToggle("ItemESP_Tools", { Text = "Tools", Default = true, Callback = function(v) showTools = v end })

    EspBox:AddToggle("ItemESP_WorkspaceOnly", { Text = "Workspace Only", Default = false, Callback = function(v) showWorkspaceOnly = v end })

    EspBox:AddToggle("ItemESP_OnPlayers", { Text = "Show On Players", Default = true, Callback = function(v) showOnPlayers = v end })

    EspBox:AddSlider("ItemESP_Distance", { Text = "Max Distance", Min = 50, Max = 2000, Default = 500, Rounding = 0, Callback = function(v) maxItemEspDistance = v end })

    local PrayBox = Tabs.GameMods:AddRightGroupbox("Pray")

    PrayBox:AddButton("Pray Once (Shrine)", function()

        task.spawn(function() doPrayAttempt(false) end)

    end)

    PrayBox:AddToggle("AutoPray", {

        Text = "Auto Pray", Default = false,

        Callback = function(v)

            autoPrayEnabled = v

            if v then lastAutoPrayAttempt = 0; markKnownInventory() end

        end

    })

    PrayBox:AddToggle("AutoPrayTP", {

        Text = "TP to Shrine each attempt", Default = true,

        Callback = function(v) autoPrayTpToShrine = v end

    })

    PrayBox:AddSlider("AutoPrayInterval", {

        Text = "Min interval (sec)", Min = 2, Max = 20, Default = 4, Rounding = 1,

        Callback = function(v) autoPrayInterval = v end

    })

    PrayBox:AddLabel("Busy lock stops spam while praying.")

    PrayBox:AddLabel("Loot counted only on new items.")

    local TrackerBox = Tabs.GameMods:AddLeftGroupbox("Pray Tracker")

    praySummaryLabel = TrackerBox:AddLabel("Attempts 0 | Loot 0")

    TrackerBox:AddToggle("TrackerOverlay", {

        Text = "On-screen panel", Default = true,

        Callback = function(v)

            trackerOverlayVisible = v

            if trackerFrame then trackerFrame.Visible = v end

        end

    })

    TrackerBox:AddButton("Reset Tracker", function()

        prayAttemptCount = 0

        praySuccessCount = 0

        table.clear(itemRewardCounts)

        markKnownInventory()

        refreshTrackerUI()

    end)

    TrackerBox:AddButton("Print Tracker", function()

        print("—— Pray —— attempts", prayAttemptCount, "loot sessions", praySuccessCount)

        for name, count in pairs(itemRewardCounts) do

            print(string.format("  %d × %s", count, name))

        end

    end)

elseif IsWarTycoon then

    GameInfo:AddLabel("Status : Supported")

    local function SetupWarTycoon()
        do
            local W = {
                BASE_POSITIONS = {
                    Alpha = Vector3.new(-1167, 65, -4854),
                    Bravo = Vector3.new(-174, 65, -4973),
                    Charlie = Vector3.new(855, 67, -4780),
                    Delta = Vector3.new(2115, 68, -3990),
                    Echo = Vector3.new(2810, 68, -3012),
                    Foxtrot = Vector3.new(3099, 65, -1743),
                    Golf = Vector3.new(3430, 66, -517),
                    Hotel = Vector3.new(3335, 66, 641),
                    Juliet = Vector3.new(2996, 67, 1862),
                    Kilo = Vector3.new(2593, 67, 2992),
                    Lima = Vector3.new(1024, 66, 3480),
                    Omega = Vector3.new(-365, 66, 3986),
                    Romeo = Vector3.new(-1543, 65, 3752),
                    Sierra = Vector3.new(-2598, 65, 2555),
                    Tango = Vector3.new(-3088, 65, 1496),
                    Victor = Vector3.new(-3587, 59, 634),
                    Yankee = Vector3.new(-4021, 66, -316),
                    Zulu = Vector3.new(-4064, 65, -1265),
                },
                ownedSpawn = nil,
                selectedEnemy = nil,
                                            warAccum = 0,
            }
            local function findRemote(name)
                local r = ReplicatedStorage:FindFirstChild(name, true)
                if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction") or r:IsA("UnreliableRemoteEvent")) then
                    return r
                end
                return nil
            end
            local function warTPTo(pos)
                if typeof(pos) == "CFrame" then
                    doWarTP({ CFrame = pos })
                elseif typeof(pos) == "Vector3" then
                    doWarTP({ CFrame = CFrame.new(pos) })
                end
            end
            local function clearMap(t)
                for k, v in pairs(t) do
                    pcall(function() v:Destroy() end)
                    t[k] = nil
                end
            end
            local function makeBillboard(adornee, text, color)
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.fromOffset(140, 28)
                bb.AlwaysOnTop = true
                bb.MaxDistance = 2000
                bb.Adornee = adornee
                bb.StudsOffset = Vector3.new(0, 4, 0)
                local lab = Instance.new("TextLabel")
                lab.Size = UDim2.fromScale(1, 1)
                lab.BackgroundTransparency = 0.35
                lab.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
                lab.TextColor3 = color or Color3.new(1, 1, 1)
                lab.Font = Enum.Font.GothamBold
                lab.TextSize = 12
                lab.Text = text
                lab.Parent = bb
                bb.Parent = CoreGui
                return bb
            end
            local function setGunValue(folder, names, value)
                for _, n in ipairs(names) do
                    local v = folder:FindFirstChild(n, true)
                    if v then
                        pcall(function()
                            if v:IsA("NumberValue") or v:IsA("IntValue") then
                                v.Value = value
                            elseif v:IsA("DoubleConstrainedValue") then
                                v.Value = math.clamp(value, v.MinValue, v.MaxValue)
                            elseif v:IsA("Vector3Value") then
                                v.Value = Vector3.zero
                            elseif v:IsA("BoolValue") and type(value) == "boolean" then
                                v.Value = value
                            elseif v:IsA("StringValue") and type(value) == "string" then
                                v.Value = value
                            end
                        end)
                    end
                end
            end
            local OwnBox = Tabs.GameMods:AddLeftGroupbox("Owned Base")
            local ownStatus = OwnBox:AddLabel("Status : Scanning...")
            local ownNameLbl = OwnBox:AddLabel("Base : —")
            local function findOwnedBase()
                local myId = LocalPlayer.UserId
                local root = select(1, getRoot())
                local best, bestDist, bestName = nil, math.huge, nil
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    local lower = string.lower(obj.Name)
                    if lower == "basespawn" or lower == "base_spawn" then
                        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local owned = false
                            local node = obj
                            for _ = 1, 10 do
                                if not node then break end
                                local ok, uid = pcall(function()
                                    return node:GetAttribute("OwnerUserId") or node:GetAttribute("Owner") or node:GetAttribute("UserId")
                                end)
                                if ok and uid ~= nil and tonumber(uid) == myId then
                                    owned = true
                                    break
                                end
                                local ov = node:FindFirstChild("Owner") or node:FindFirstChild("OwnerUserId")
                                if ov and ov:IsA("ValueBase") and tonumber(ov.Value) == myId then
                                    owned = true
                                    break
                                end
                                node = node.Parent
                            end
                            if owned then
                                best, bestName, bestDist = part, (obj.Parent and obj.Parent.Name) or obj.Name, 0
                                break
                            end
                            if root then
                                local d = (part.Position - root.Position).Magnitude
                                if d < bestDist then
                                    bestDist, best, bestName = d, part, (obj.Parent and obj.Parent.Name) or obj.Name
                                end
                            end
                        end
                    end
                end
                if best and bestDist <= 1500 then
                    W.ownedSpawn = best
                    ownStatus:SetText("Status : OWNED")
                    ownNameLbl:SetText("Base : " .. tostring(bestName))
                    return true
                end
                W.ownedSpawn = nil
                ownStatus:SetText("Status : Not found")
                ownNameLbl:SetText("Base : —")
                return false
            end
            OwnBox:AddButton("Refresh Owned Base", function() task.spawn(findOwnedBase) end)
            OwnBox:AddButton("TP to Owned Base", function()
                if not W.ownedSpawn then findOwnedBase() end
                if W.ownedSpawn then
                    warTPTo(W.ownedSpawn.Position + Vector3.new(0, 5, 0))
                    return
                end
                local team = LocalPlayer.Team
                local tn = team and tostring(team.Name)
                if tn and W.BASE_POSITIONS[tn] then
                    print("[War] Owned spawn missing; using team slot", tn)
                    warTPTo(W.BASE_POSITIONS[tn])
                    return
                end
                warn("[War] No owned base found")
            end)
            task.spawn(function() task.wait(1) findOwnedBase() end)
            local EnemyBox = Tabs.GameMods:AddRightGroupbox("Enemy Bases")
            local enemyStatus = EnemyBox:AddLabel("Occupied : —")
            local enemyDropdown = EnemyBox:AddDropdown("WarEnemyBaseSelect", {
                Text = "Occupied base",
                Values = { "(none)" },
                Default = 1,
                Callback = function(v)
                    W.selectedEnemy = (v ~= "(none)") and v or nil
                end,
            })
            local function refreshEnemyList()
                local grouped = {}
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Team then
                        local tn = tostring(plr.Team.Name)
                        if tn ~= "" then
                            grouped[tn] = grouped[tn] or {}
                            table.insert(grouped[tn], plr.Name)
                        end
                    end
                end
                local myTeam = LocalPlayer.Team and tostring(LocalPlayer.Team.Name)
                local names = {}
                for tn in pairs(grouped) do
                    if tn ~= myTeam then table.insert(names, tn) end
                end
                table.sort(names)
                if #names == 0 then
                    names = { "(none)" }
                    enemyStatus:SetText("Occupied : none")
                else
                    enemyStatus:SetText("Occupied : " .. #names)
                end
                pcall(function() enemyDropdown:SetValues(names) end)
                if W.selectedEnemy and not grouped[W.selectedEnemy] then W.selectedEnemy = nil end
            end
            EnemyBox:AddButton("Refresh List", refreshEnemyList)
            EnemyBox:AddButton("TP to Selected", function()
                if not W.selectedEnemy then
                    warn("[War] Select an occupied base first")
                    return
                end
                local pos = W.BASE_POSITIONS[W.selectedEnemy]
                if pos then warTPTo(pos) else warn("[War] No coords for", W.selectedEnemy) end
            end)
            task.spawn(function()
                while task.wait(6) do
                    if not IsWarTycoon then break end
                    pcall(refreshEnemyList)
                end
            end)
            task.defer(refreshEnemyList)
            local WarBox = Tabs.GameMods:AddLeftGroupbox("War Tycoon")
            WarBox:AddToggle("InfiniteAmmo", {
                Text = "Infinite Ammo",
                Default = false,
                Callback = function(v) infiniteAmmo = v end,
            })
            local CashBox = Tabs.GameMods:AddRightGroupbox("Auto Cash")
            W.autoCash = false
            W.autoCashUsePass = true
            W.autoCashLast = 0
            W.autoCashStatus = nil

            local cashStatus = CashBox:AddLabel("Status : Off")
            W.autoCashStatus = cashStatus

            CashBox:AddToggle("WarAutoCash", {
                Text = "Auto Collect Cash",
                Default = false,
                Callback = function(v)
                    W.autoCash = v
                    if cashStatus then
                        cashStatus:SetText(v and "Status : Running..." or "Status : Off")
                    end
                end,
            })
            CashBox:AddToggle("WarAutoCashPass", {
                Text = "Try game AutoCollect setting",
                Default = true,
                Callback = function(v) W.autoCashUsePass = v end,
            })
            CashBox:AddLabel("Only team CollectorParts — not oil")
            CashBox:AddLabel("Pass 164758956 = Auto Collect")

            local function getTeamTycoon()
                local team = LocalPlayer.Team
                if not team then return nil end
                local tn = team.Name
                if tn == "" or tn == "Loading" then return nil end
                local tycoons = Workspace:FindFirstChild("Tycoon")
                tycoons = tycoons and tycoons:FindFirstChild("Tycoons")
                return tycoons and tycoons:FindFirstChild(tn)
            end

            local function getCollectorPad()
                local tycoon = getTeamTycoon()
                if not tycoon then return nil, "no tycoon" end
                local essentials = tycoon:FindFirstChild("Essentials")
                local parts = essentials and essentials:FindFirstChild("CollectorParts")
                if not parts then return nil, "no CollectorParts" end
                local metal = parts:FindFirstChild("Metal")
                if metal and metal:IsA("BasePart") then return metal, "Metal" end
                local base = parts:FindFirstChildWhichIsA("BasePart", true)
                if base then return base, base.Name end
                return nil, "no part"
            end

            local function tryEnableGameAutoCollect()
                if not W.autoCashUsePass then return end
                local tycoon = getTeamTycoon()
                if not tycoon then return end
                local purchased = tycoon:FindFirstChild("PurchasedObjects")
                if purchased and not purchased:FindFirstChild("Auto Collect") then
                    pcall(function()
                        local f = Instance.new("Folder")
                        f.Name = "Auto Collect"
                        f.Parent = purchased
                    end)
                end
                pcall(function()
                    for _, v in ipairs(LocalPlayer:GetDescendants()) do
                        if v.Name == "AutoCollect" and v:IsA("BoolValue") then
                            v.Value = true
                        end
                    end
                end)
                pcall(function()
                    local rs = ReplicatedStorage
                    for _, v in ipairs(rs:GetDescendants()) do
                        if v.Name == "SetSetting" and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
                            pcall(function()
                                if v:IsA("RemoteEvent") then
                                    v:FireServer("AutoCollect", true)
                                else
                                    v:InvokeServer("AutoCollect", true)
                                end
                            end)
                        end
                    end
                end)
            end

            local function fireCashPromptsNearPad(pad)
                if not pad then return end
                for _, obj in ipairs(pad:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then
                        pcall(function()
                            obj.HoldDuration = 0
                            obj.RequiresLineOfSight = false
                            if fireproximityprompt then fireproximityprompt(obj) end
                        end)
                    end
                end
                if pad.Parent then
                    for _, obj in ipairs(pad.Parent:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            pcall(function()
                                obj.HoldDuration = 0
                                if fireproximityprompt then fireproximityprompt(obj) end
                            end)
                        end
                    end
                end
            end

            local function getAllCollectorPads()
                local pads = {}
                local tycoon = getTeamTycoon()
                if not tycoon then return pads end
                local essentials = tycoon:FindFirstChild("Essentials")
                local parts = essentials and essentials:FindFirstChild("CollectorParts")
                if not parts then return pads end

                for _, p in ipairs(parts:GetDescendants()) do
                    if p:IsA("BasePart") then
                        local n = string.lower(p.Name)
                        if not string.find(n, "oil", 1, true) then
                            table.insert(pads, p)
                        end
                    end
                end
                return pads
            end

            local function pickStandPart(pads)
                if #pads == 0 then return nil end
                local best, bestScore = nil, math.huge
                for _, p in ipairs(pads) do
                    local size = p.Size
                    local flat = size.Y
                    local area = size.X * size.Z
                    local score = flat * 5 - area * 0.01 + p.Position.Y * 0.05
                    local n = string.lower(p.Name)
                    if n == "metal" or string.find(n, "pad", 1, true) or string.find(n, "floor", 1, true) or string.find(n, "base", 1, true) then
                        score = score - 20
                    end
                    if size.Y > 4 then score = score + 30 end
                    if score < bestScore then
                        bestScore = score
                        best = p
                    end
                end
                return best or pads[1]
            end

            local function forceTouch(pad)
                local root, hum, char = getRoot()
                if not root or not char or not pad then return false end

                local topY = pad.Position.Y + pad.Size.Y * 0.5
                local standPos = Vector3.new(pad.Position.X, topY + 3, pad.Position.Z)
                local sinkPos = Vector3.new(pad.Position.X, topY + 2.6, pad.Position.Z)

                pcall(function()
                    if hum then
                        hum.Sit = false
                        hum.PlatformStand = false
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end)

                for i = 1, 4 do
                    local pos = (i % 2 == 0) and sinkPos or standPos
                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                        char:PivotTo(CFrame.new(pos))
                        root.CFrame = CFrame.new(pos)
                    end)
                    pcall(function()
                        if firetouchinterest then
                            firetouchinterest(root, pad, 0)
                            firetouchinterest(root, pad, 1)
                            if pad.Parent then
                                for _, p in ipairs(pad.Parent:GetDescendants()) do
                                    if p:IsA("BasePart") then
                                        firetouchinterest(root, p, 0)
                                        firetouchinterest(root, p, 1)
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.08)
                end
                return true
            end

            CashBox:AddButton("TP to cash pad once", function()
                local pads = getAllCollectorPads()
                local pad = pickStandPart(pads)
                if not pad then
                    local teamName = LocalPlayer.Team and LocalPlayer.Team.Name or "?"
                    warn("[War] No CollectorParts for team", teamName)
                    if W.autoCashStatus then W.autoCashStatus:SetText("Status : no pad (" .. teamName .. ")") end
                    return
                end
                print("[War] pad", pad:GetFullName(), pad.Size)
                forceTouch(pad)
                if W.autoCashStatus then W.autoCashStatus:SetText("Status : " .. pad.Name) end
            end)

            local function tickAutoCash()
                if not W.autoCash then return end
                local now = os.clock()
                if now - (W.autoCashLast or 0) < 0.6 then return end
                W.autoCashLast = now

                tryEnableGameAutoCollect()

                local pads = getAllCollectorPads()
                local pad = pickStandPart(pads)
                if not pad then
                    if W.autoCashStatus then W.autoCashStatus:SetText("Status : no CollectorParts") end
                    return
                end

                fireCashPromptsNearPad(pad)
                forceTouch(pad)

                if W.autoCashStatus then
                    W.autoCashStatus:SetText("Status : on " .. pad.Name)
                end
            end

            RunService.Heartbeat:Connect(function()
                if IsWarTycoon then tickAutoCash() end
            end)

            local MountsModule = LoadModule("https://raw.githubusercontent.com/LTFxGUILT/asdasd/refs/heads/main/Wartycoon/HeliSpawner.luau")

            if MountsModule then

                local WarMounts = MountsModule.new({

                    Tabs = Tabs,
                    ReplicatedStorage = ReplicatedStorage,
                    Workspace = Workspace,
                    LocalPlayer = LocalPlayer,

                })

                WarMounts:Init()

                getgenv().TestingWarMounts = WarMounts

            end

            local VisBox = Tabs.GameMods:AddRightGroupbox("War Visuals")
            VisBox:AddToggle("WarCosmeticBullets", {
                Text = "Cosmetic Bullets Visible", Default = true,
                Callback = function(v)
                    local folder = Workspace:FindFirstChild("CosmeticBulletsFolder") or ReplicatedStorage:FindFirstChild("CosmeticBulletsFolder")
                    if folder then
                        for _, c in ipairs(folder:GetDescendants()) do
                            if c:IsA("BasePart") then pcall(function() c.Transparency = v and 0 or 1 end) end
                        end
                    end
                end,
            })
            
        end
    end

    task.spawn(SetupWarTycoon)

elseif IsCreaturesOfSonaria then

    GameInfo:AddLabel("Status : Supported")
    GameInfo:AddLabel("Game Mods : Creatures of Sonaria")

    local setupCos = LoadModule("https://raw.githubusercontent.com/LTFxGUILT/asdasd/refs/heads/main/CoS/cos.luau")

    if type(setupCos) == "function" then
        task.spawn(function()
            local ok, err = pcall(setupCos, {
                Tabs = Tabs,
                Toggles = Toggles,
                Library = Library,
                ThemeManager = ThemeManager,
                AddToggle = AddToggle,
                GameInfo = GameInfo,
                Players = Players,
                LocalPlayer = LocalPlayer,
                RunService = RunService,
                ReplicatedStorage = ReplicatedStorage,
                Workspace = Workspace,
                CoreGui = CoreGui,
                UserInputService = UserInputService,
                CollectionService = CollectionService,
                MarketplaceService = MarketplaceService,
                PlaceId = PlaceId,
                PlaceName = PlaceName,
                getRoot = getRoot,
            })
            if not ok then
                warn("[Testing] CoS module error:", err)
            end
        end)
    else
        warn("[Testing] CoS module failed to load — upload modules/cos.luau to the repo")
    end

elseif IsTradeRealm then

    local setupTrade = LoadModule("https://raw.githubusercontent.com/LTFxGUILT/asdasd/refs/heads/main/CoS/TradeRealm.luau")

    if type(setupTrade) == "function" then
        task.spawn(function()
            local ok, err = pcall(setupTrade, {
                Tabs = Tabs,
                Toggles = Toggles,
                Library = Library,
                ThemeManager = ThemeManager,
                AddToggle = AddToggle,
                GameInfo = GameInfo,
                Players = Players,
                LocalPlayer = LocalPlayer,
                RunService = RunService,
                ReplicatedStorage = ReplicatedStorage,
                Workspace = Workspace,
                CoreGui = CoreGui,
                UserInputService = UserInputService,
                TeleportService = TeleportService,
                PlaceId = PlaceId,
                PlaceName = PlaceName,
                getRoot = getRoot,
            })
            if not ok then
                warn("[Testing] Trade Realm module error:", err)
            end
        end)
    else
        warn("[Testing] Trade Realm module failed to load — upload modules/trade_realm.luau to the repo")
    end

else

    GameInfo:AddLabel("Status : Not Supported")

end

if ThemeManager and SaveManager then

    ThemeManager:SetLibrary(Library)

    SaveManager:SetLibrary(Library)

    SaveManager:IgnoreThemeSettings()

    SaveManager:SetIgnoreIndexes({"MenuKeybind"})

    ThemeManager:SetFolder("Testing")

    SaveManager:SetFolder("Testing")

    SaveManager:BuildConfigSection(Tabs.Settings)

    ThemeManager:ApplyToTab(Tabs.Settings)

end

if ChatLogger then

    local chatLogger = ChatLogger.new({

        Tabs = Tabs,

        Toggles = Toggles,

        Library = Library,

        ThemeManager = ThemeManager,

    })

    chatLogger:Init()

end

hookInventoryTracking()

markKnownInventory()

refreshTrackerUI()

local function forceAmmo()

    if not IsWarTycoon and not IsBugFixes then return end

    local configurations = ReplicatedStorage:FindFirstChild("Configurations")

    local acsGuns = configurations and configurations:FindFirstChild("ACS_Guns")

    if not acsGuns then return end

    for _, folder in ipairs(acsGuns:GetChildren()) do

        local ammo = folder:FindFirstChild("Ammo")

        if ammo then pcall(function() ammo.Value = 999 end) end

    end

end

local function applyRainbowGun()

    if not rainbowGun and gunTransparency <= 0 then return end

    local char = LocalPlayer.Character

    if not char then return end

    if rainbowGun then gunHue = (gunHue + rainbowGunSpeed) % 1 end

    local gunColor = rainbowGun and Color3.fromHSV(gunHue, 1, 1) or nil

    local tool = char:FindFirstChildOfClass("Tool")

    if tool then

        for _, obj in ipairs(tool:GetDescendants()) do

            if obj:IsA("BasePart") then

                if gunColor then pcall(function() obj.Color = gunColor; obj.Material = Enum.Material.ForceField end) end

                pcall(function() obj.Transparency = gunTransparency end)

            end

        end

    end

end

local function UpdateChams()

    if not chamsEnabled then

        for _, hl in pairs(ChamObjects) do if hl then pcall(function() hl:Destroy() end) end end

        ChamObjects = {}

        return

    end

    for _, player in ipairs(Players:GetPlayers()) do

        if player ~= LocalPlayer and player.Character then

            if not ChamObjects[player] or not ChamObjects[player].Parent then

                local highlight = Instance.new("Highlight")

                highlight.Adornee = player.Character

                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

                highlight.FillTransparency = 0.5

                highlight.Parent = CoreGui

                ChamObjects[player] = highlight

            else

                ChamObjects[player].Adornee = player.Character

            end

            local status = getPlayerStatus(player)

            if status == "friend" then

                ChamObjects[player].FillColor = friendColor

                ChamObjects[player].OutlineColor = friendColor

            elseif status == "kos" then

                ChamObjects[player].FillColor = kosColor

                ChamObjects[player].OutlineColor = kosColor

            else

                ChamObjects[player].FillColor = Color3.fromRGB(255, 255, 255)

                ChamObjects[player].OutlineColor = Color3.fromRGB(0, 0, 0)

            end

        end

    end

end

RunService.Heartbeat:Connect(function(dt)

    pcall(function()

        if Visuals and Visuals.Tick then Visuals.Tick(dt) end

        if Misc and Misc.Tick then Misc.Tick(dt) end

        if Desync and Desync.Tick then Desync.Tick(dt) end

    end)

    pcall(function()
        miscUpdateMovement(dt)
    end)

    if IsBugFixes then

        tickSafeTP()

    end

    tickAutoPray()

    if espEnabled then

        espAccumulator = espAccumulator + dt

        if espAccumulator >= (1 / math.max(espRenderHz, 1)) then

            espAccumulator = 0

            UpdateAllESP()

        end

    end

    if itemEspEnabled then

        itemEspAccum = itemEspAccum + dt

        if itemEspAccum >= 1 then

            itemEspAccum = 0

            pcall(updateItemESP)

        end

    end

    local root, hum, char = getRoot()

    if not char then return end

    if cframeEnabled and root and hum and hum.MoveDirection.Magnitude > 0 then

        pcall(function() root.CFrame = root.CFrame + hum.MoveDirection * (cframeSpeed * 0.02) end)

    end

    if lockFOV and Camera then pcall(function() Camera.FieldOfView = currentFOV end) end

    if rainbowBody then

        rainbowAccum = rainbowAccum + dt

        if rainbowAccum >= 0.05 then

            rainbowAccum = 0

            charHue = (charHue + rainbowBodySpeed * 3) % 1

            local bodyColor = Color3.fromHSV(charHue, 1, 1)

            for _, obj in ipairs(char:GetChildren()) do

                if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then

                    pcall(function()

                        obj.Material = Enum.Material.ForceField

                        obj.Color = bodyColor

                        obj.Transparency = charTransparency

                    end)

                elseif obj:IsA("Accessory") then

                    local handle = obj:FindFirstChild("Handle")

                    if handle then

                        pcall(function()

                            handle.Material = Enum.Material.ForceField

                            handle.Color = bodyColor

                            handle.Transparency = charTransparency

                        end)

                    end

                end

            end

        end

    end

    applyRainbowGun()

    if infiniteAmmo then forceAmmo() end

    if chamsEnabled then UpdateChams() end

end)

Players.PlayerAdded:Connect(function(p)

    if espEnabled then CreateESP(p) end

    task.defer(refreshPlayerDropdown)

end)

Players.PlayerRemoving:Connect(function(p)

    RemoveESP(p)

    friendUsers[p.UserId] = nil

    kosUsers[p.UserId] = nil

    if ChamObjects[p] then pcall(function() ChamObjects[p]:Destroy() end) ChamObjects[p] = nil end

    task.defer(refreshPlayerDropdown)

end)

for _, p in ipairs(Players:GetPlayers()) do

    if p ~= LocalPlayer then CreateESP(p) end

end

getgenv().__Testing.Body = function()

    pcall(function()
        if getgenv().TestingWarMounts then getgenv().TestingWarMounts:Destroy() end
        getgenv().TestingWarMounts = nil
    end)

    if fallConnection then fallConnection:Disconnect() end

    if antiAfkConnection then antiAfkConnection:Disconnect() end

    if movementCharacterConnection then movementCharacterConnection:Disconnect() end

    pcall(function()
        if miscMovementState.humanoid then
            miscRestoreWalkSpeed(miscMovementState.humanoid)
            miscRestoreAutoRotate(miscMovementState.humanoid)
        end
        miscRestoreNoClip()
    end)

    if LimbExtender then pcall(function() LimbExtender:Stop() end) end

    ApplySkybox("Default")

    clearItemESP()

    pcall(function()
        if IsCreaturesOfSonaria and getgenv().TestingCOSFoodCleanup then
            getgenv().TestingCOSFoodCleanup()
            getgenv().TestingCOSFoodCleanup = nil
        end
    end)

    pcall(function()

        if trackerGui then trackerGui:Destroy() end

    end)

    for player in pairs(espObjects) do RemoveESP(player) end

    for _, hl in pairs(ChamObjects) do if hl then hl:Destroy() end end

    print("Testing unloaded")

end

Library:OnUnload(getgenv().__Testing.Body)

getgenv().__Testing.Unload = function()

    getgenv().__Testing.Unload = nil

    pcall(function() Library:Unload() end)

    pcall(function() Library.ScreenGui:Destroy() end)

end

print("Testing")
