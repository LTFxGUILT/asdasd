--========================================================--
-- Testing / Moe - COMPLETE (nothing removed)
-- Full Visuals + Misc + Zex + ESP Friend/KOS
-- Improved Auto Pray + on-screen tracker + Moe watermark
--========================================================--

--!native
--!optimize 2

local Players = game:GetService("Players")
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

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local DataPing = Stats.Network.ServerStatsItem["Data Ping"]
local FrameRateManager = Stats:FindFirstChild("FrameRateManager")
local RenderAverage = FrameRateManager and FrameRateManager:FindFirstChild("RenderAverage")

--========================================================--
-- MODULE LOADER
--========================================================--

local ModuleCache = {}
local function LoadModule(Path)
    if ModuleCache[Path] ~= nil then return ModuleCache[Path] end
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://cats-cure-depression.vercel.app/" .. Path))()
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

--========================================================--
-- GAME DETECTION
--========================================================--

local PlaceId = game.PlaceId
local PlaceName = "Unknown"
pcall(function()
    local info = MarketplaceService:GetProductInfo(PlaceId)
    if info and info.Name then PlaceName = info.Name end
end)
local IsBugFixes = PlaceId == 100971017807798

--========================================================--
-- SKYBOXES (remote)
--========================================================--

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

--========================================================--
-- LIMB EXTENDER
--========================================================--

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

--========================================================--
-- STATE
--========================================================--

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

-- Pray (improved)
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

--========================================================--
-- HELPERS
--========================================================--

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

--========================================================--
-- ON-SCREEN PRAY TRACKER
--========================================================--

pcall(function()
    if CoreGui:FindFirstChild("PrayTrackerOverlay") then
        CoreGui.PrayTrackerOverlay:Destroy()
    end
end)

local trackerGui = Instance.new("ScreenGui")
trackerGui.Name = "PrayTrackerOverlay"
trackerGui.ResetOnSpawn = false
trackerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
trackerGui.Parent = CoreGui

local trackerFrame = Instance.new("Frame")
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

local trackerBody = Instance.new("TextLabel")
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
    trackerBody.Text = buildTrackerText()
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

--========================================================--
-- SAFE TP
--========================================================--

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

--========================================================--
-- PRAY
--========================================================--

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

--========================================================--
-- ITEM ESP
--========================================================--

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

--========================================================--
-- WINDOW
--========================================================--

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

-- Moe watermark
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

--========================================================--
-- ZEX
--========================================================--

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

local AmmoBox = Tabs.Zex:AddRightGroupbox("Ammo")
AmmoBox:AddToggle("InfiniteAmmo", { Text = "Infinite Ammo", Default = false, Callback = function(v) infiniteAmmo = v end })

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

--========================================================--
-- ESP + FRIEND / KOS
--========================================================--

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
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
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

--========================================================--
-- VISUALS (FULL — all Moe world options)
--========================================================--

local World = Tabs.Visuals:AddGroupbox({ Side = 1, Name = "World" })
local PlayerBoxV = Tabs.Visuals:AddGroupbox({ Side = 2, Name = "Player" })
local CameraBox = Tabs.Visuals:AddGroupbox({ Side = 2, Name = "Camera" })

local Ambient = AddToggle(World, "visuals/world/ambient", { Text = "Ambient", Default = false })
Ambient:AddColorPicker("visuals/world/ambient/outdoorcolor", { Default = Color3.fromRGB(200, 100, 60), Title = "Outdoor Color" })
Ambient:AddColorPicker("visuals/world/ambient/color", { Default = Color3.fromRGB(140, 90, 70), Title = "Ambient Color" })

AddToggle(World, "visuals/world/brightness", { Text = "Brightness", Default = false })
local BrightnessDep = World:AddDependencyBox()
BrightnessDep:AddSlider("visuals/world/brightness/level", { Text = "Brightness Level", Min = 0, Max = 10, Rounding = 1, Default = 1.6 })
BrightnessDep:AddSlider("visuals/world/brightness/envdiffscale", { Text = "Environment Diffuse Scale", Min = 0, Max = 1, Rounding = 2, Default = 1 })
BrightnessDep:AddSlider("visuals/world/brightness/envspecscale", { Text = "Environment Specular Scale", Min = 0, Max = 1, Rounding = 2, Default = 0.9 })
BrightnessDep:AddSlider("visuals/world/brightness/exposure", { Text = "Exposure Compensation", Min = 0, Max = 1, Rounding = 2, Default = 0.15 })
BrightnessDep:SetupDependencies({ { Toggles["visuals/world/brightness"], true } })

local Fog = AddToggle(World, "visuals/world/fog", { Text = "Fog", Default = false })
Fog:AddColorPicker("visuals/world/fog/color", { Default = Color3.fromRGB(255, 255, 255), Title = "Fog Color" })
local FogDep = World:AddDependencyBox()
FogDep:AddSlider("visuals/world/fog/near", { Text = "Fog Near", Min = 0, Max = 1000, Rounding = 1, Default = 0 })
FogDep:AddSlider("visuals/world/fog/far", { Text = "Fog Far", Min = 0, Max = 1000, Rounding = 1, Default = 1000 })
FogDep:SetupDependencies({ { Toggles["visuals/world/fog"], true } })

local Shadow = AddToggle(World, "visuals/world/shadow", { Text = "Shadow Modification", Default = false })
Shadow:AddColorPicker("visuals/world/shadow/color", { Default = Color3.fromRGB(0, 0, 0), Title = "Shadow Color" })
local ShadowDep = World:AddDependencyBox()
ShadowDep:AddSlider("visuals/world/shadow/softness", { Text = "Shadow Softness", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
ShadowDep:AddToggle("visuals/world/shadow/globalshadows", { Text = "Enable Shadows", Default = true })
ShadowDep:SetupDependencies({ { Toggles["visuals/world/shadow"], true } })

AddToggle(World, "visuals/world/lighting", { Text = "Lighting", Default = false })
local LightingDep = World:AddDependencyBox()
LightingDep:AddSlider("visuals/world/lighting/time", { Text = "Clock Time", Min = 0, Max = 23, Rounding = 2, Default = 14 })
LightingDep:AddSlider("visuals/world/lighting/latitude", { Text = "Geographic Latitude", Min = -90, Max = 90, Rounding = 1, Default = 0 })
LightingDep:AddLabel("ColorShift Bottom"):AddColorPicker("visuals/world/lighting/colorshiftbottom", { Default = Color3.fromRGB(255, 255, 255), Title = "ColorShift Bottom" })
LightingDep:AddLabel("ColorShift Top"):AddColorPicker("visuals/world/lighting/colorshifttop", { Default = Color3.fromRGB(255, 255, 255), Title = "ColorShift Top" })
do
    local TechOptions = {}
    for _, EnumItem in Enum.Technology:GetEnumItems() do table.insert(TechOptions, EnumItem.Name) end
    LightingDep:AddDropdown("visuals/world/lighting/technology", { Text = "Technology", Default = 1, Values = TechOptions })
end
LightingDep:SetupDependencies({ { Toggles["visuals/world/lighting"], true } })

AddToggle(World, "visuals/world/lighting/colorgrading", { Text = "Color Grading", Default = false })
local ColorGradingDep = World:AddDependencyBox()
do
    local TonemapOptions = {}
    for _, EnumItem in Enum.TonemapperPreset:GetEnumItems() do table.insert(TonemapOptions, EnumItem.Name) end
    ColorGradingDep:AddDropdown("visuals/world/lighting/colorgrading/tonemap", { Text = "Tone Map Preset", Default = 1, Values = TonemapOptions })
end
ColorGradingDep:SetupDependencies({ { Toggles["visuals/world/lighting/colorgrading"], true } })

local CC = AddToggle(World, "visuals/world/lighting/cc", { Text = "Color Correction", Default = false })
local CCDep = World:AddDependencyBox()
CCDep:AddSlider("visuals/world/lighting/cc/saturation", { Text = "Saturation", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
CCDep:AddSlider("visuals/world/lighting/cc/contrast", { Text = "Contrast", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
CCDep:AddSlider("visuals/world/lighting/cc/brightness", { Text = "Brightness", Min = -1, Max = 1, Rounding = 2, Default = 0 })
CC:AddColorPicker("visuals/world/lighting/cc/tint", { Default = Color3.fromRGB(255, 255, 255), Title = "Tint Color" })
CCDep:SetupDependencies({ { Toggles["visuals/world/lighting/cc"], true } })

AddToggle(World, "visuals/world/lighting/bloom", { Text = "Bloom", Default = false })
local BloomDep = World:AddDependencyBox()
BloomDep:AddSlider("visuals/world/lighting/bloom/intensity", { Text = "Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
BloomDep:AddSlider("visuals/world/lighting/bloom/size", { Text = "Size", Min = 0, Max = 56, Rounding = 2, Default = 24 })
BloomDep:AddSlider("visuals/world/lighting/bloom/threshold", { Text = "Threshold", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
BloomDep:SetupDependencies({ { Toggles["visuals/world/lighting/bloom"], true } })

AddToggle(World, "visuals/world/sunrays", { Text = "Sun Rays", Default = false })
local SunRaysDep = World:AddDependencyBox()
SunRaysDep:AddSlider("visuals/world/sunrays/intensity", { Text = "Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.1 })
SunRaysDep:AddSlider("visuals/world/sunrays/spread", { Text = "Spread", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
SunRaysDep:SetupDependencies({ { Toggles["visuals/world/sunrays"], true } })

AddToggle(World, "visuals/world/atmosphere", { Text = "Atmosphere", Default = false })
local AtmosphereDep = World:AddDependencyBox()
AtmosphereDep:AddSlider("visuals/world/atmosphere/density", { Text = "Density", Min = 0, Max = 1, Rounding = 2, Default = 0.3 })
AtmosphereDep:AddSlider("visuals/world/atmosphere/offset", { Text = "Offset", Min = -1, Max = 1, Rounding = 2, Default = 0 })
AtmosphereDep:AddLabel("Color"):AddColorPicker("visuals/world/atmosphere/color", { Default = Color3.fromRGB(199, 170, 107), Title = "Atmosphere Color" })
AtmosphereDep:AddLabel("Decay"):AddColorPicker("visuals/world/atmosphere/decay", { Default = Color3.fromRGB(106, 112, 125), Title = "Atmosphere Decay" })
AtmosphereDep:AddSlider("visuals/world/atmosphere/glare", { Text = "Glare", Min = 0, Max = 1, Rounding = 2, Default = 0 })
AtmosphereDep:AddSlider("visuals/world/atmosphere/haze", { Text = "Haze", Min = 0, Max = 1, Rounding = 2, Default = 0 })
AtmosphereDep:SetupDependencies({ { Toggles["visuals/world/atmosphere"], true } })

AddToggle(World, "visuals/world/dof", { Text = "Depth of Field", Default = false })
local DOFDep = World:AddDependencyBox()
DOFDep:AddSlider("visuals/world/dof/farintens", { Text = "Far Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.28 })
DOFDep:AddSlider("visuals/world/dof/nearintens", { Text = "Near Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.7 })
DOFDep:AddSlider("visuals/world/dof/focusdist", { Text = "Focus Distance", Min = 0, Max = 100, Rounding = 2, Default = 20 })
DOFDep:AddSlider("visuals/world/dof/focusinradius", { Text = "In Focus Radius", Min = -100, Max = 100, Rounding = 2, Default = 20 })
DOFDep:SetupDependencies({ { Toggles["visuals/world/dof"], true } })

AddToggle(World, "visuals/world/weather", { Text = "Weather", Default = false })
local WeatherDep = World:AddDependencyBox()
WeatherDep:AddDropdown("visuals/world/weather/type", { Text = "Type", Default = 1, Values = {"Rain", "Snow"} })
WeatherDep:AddSlider("visuals/world/snow/rate", { Text = "Snow Rate", Min = 1, Max = 2000, Rounding = 0, Default = 1000 })
WeatherDep:SetupDependencies({ { Toggles["visuals/world/weather"], true } })

AddToggle(World, "visuals/world/customskybox", {
    Text = "Custom Sky Box", Default = false,
    Callback = function(v)
        skyboxEnabled = v
        if v then ApplySkybox(currentSkybox) else ApplySkybox("Default") end
    end
})
local SkyDep = World:AddDependencyBox()
SkyDep:AddDropdown("visuals/world/customskybox/type", {
    Text = "Type", Default = 1, Values = SkyNames,
    Callback = function(value)
        currentSkybox = value
        if skyboxEnabled then ApplySkybox(value) end
    end
})
SkyDep:SetupDependencies({ { Toggles["visuals/world/customskybox"], true } })

AddToggle(World, "visuals/world/use2022materials", {
    Text = "Use 2022 Materials", Default = false,
    Callback = function(v) pcall(function() sethiddenproperty(MaterialService, "Use2022Materials", v) end) end
})

-- Player visuals
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

-- Camera
AddToggle(CameraBox, "visuals/camera/waifu", { Text = "Waifu", Default = false })
local WaifuDep = CameraBox:AddDependencyBox()
WaifuDep:AddInput("visuals/camera/waifu/link", { Text = "Image / GIF URL", Default = "" })
WaifuDep:AddSlider("visuals/camera/waifu/x", { Text = "X", Min = -1920, Max = 1920, Rounding = 0, Default = 0 })
WaifuDep:AddSlider("visuals/camera/waifu/y", { Text = "Y", Min = -1080, Max = 1080, Rounding = 0, Default = 0 })
WaifuDep:AddSlider("visuals/camera/waifu/transparency", { Text = "Transparency", Min = 0, Max = 1, Rounding = 1, Default = 0.5 })
WaifuDep:AddSlider("visuals/camera/waifu/scale", { Text = "Scale", Min = 0, Max = 1, Rounding = 1, Default = 0.5 })
WaifuDep:SetupDependencies({ { Toggles["visuals/camera/waifu"], true } })

--========================================================--
-- MISC (FULL)
--========================================================--

local Movement = Tabs.Misc:AddGroupbox({ Side = 1, Name = "Movement" })
local Exploits = Tabs.Misc:AddGroupbox({ Side = 2, Name = "Exploits" })
local ClientBox = Tabs.Misc:AddGroupbox({ Side = 1, Name = "Client" })
local DesyncBox = Tabs.Misc:AddGroupbox({ Side = 2, Name = "Namsync" })

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

--========================================================--
-- GAME MODS
--========================================================--

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
            trackerFrame.Visible = v
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

hookInventoryTracking()
markKnownInventory()
refreshTrackerUI()

--========================================================--
-- MAIN LOOP
--========================================================--

local function forceAmmo()
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

    tickSafeTP()
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

Library:OnUnload(function()
    if fallConnection then fallConnection:Disconnect() end
    if antiAfkConnection then antiAfkConnection:Disconnect() end
    if LimbExtender then pcall(function() LimbExtender:Stop() end) end
    ApplySkybox("Default")
    clearItemESP()
    pcall(function() if trackerGui then trackerGui:Destroy() end end)
    for player in pairs(espObjects) do RemoveESP(player) end
    for _, hl in pairs(ChamObjects) do if hl then hl:Destroy() end end
    print("Testing unloaded")
end)

print("Testing")
