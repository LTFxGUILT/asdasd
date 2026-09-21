--========================================================--
-- Moe - Full Script using Original Modules + Limb Extender
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
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--========================================================--
-- MODULE LOADER
--========================================================--

local ModuleCache = {}

local function LoadModule(Path)
    if ModuleCache[Path] ~= nil then
        return ModuleCache[Path]
    end
    local url = "https://cats-cure-depression.vercel.app/" .. Path
    local source = game:HttpGet(url)
    local result = loadstring(source)()
    ModuleCache[Path] = result
    return result
end

--========================================================--
-- LIBRARY
--========================================================--

local Library = LoadModule("moehack.net/interface/library.luau")
local SaveManager = LoadModule("moehack.net/interface/addons/SaveManager.lua")
local ThemeManager = LoadModule("moehack.net/interface/addons/ThemeManager.lua")

--========================================================--
-- LOAD ORIGINAL MODULES
--========================================================--

local Visuals = LoadModule("moehack.net/modules/visuals.luau")
local Misc = LoadModule("moehack.net/modules/misc.luau")
local Desync = LoadModule("moehack.net/modules/desync.luau")

--========================================================--
-- LIMB EXTENDER
--========================================================--

local LimbExtender
pcall(function()
    getgenv().le = getgenv().le or loadstring(game:HttpGet('https://raw.githubusercontent.com/AAPVdev/scripts/refs/heads/main/LimbExtender.lua'))()
    LimbExtender = getgenv().le({
        LISTEN_FOR_INPUT = false,
        USE_HIGHLIGHT = false,
        ESP = false,
        ESP_BOX = false,
        ESP_TRACER = false,
        ESP_SKELETON = false,
        ESP_HEALTH = false,
        ESP_LABEL = false,
        CHAMS = false,
        TARGET_LIMB = "Head",
        LIMB_SIZE = 5
    })
end)

--========================================================--
-- STATE (your Zex features)
--========================================================--

local noFallEnabled = false
local cframeEnabled = false
local cframeSpeed = 50
local currentFOV = 70
local lockFOV = false
local rainbowBody = false
local charTransparency = 0
local charHue = 0
local rainbowBodySpeed = 0.008
local rainbowGun = false
local gunTransparency = 0
local gunHue = 0
local rainbowGunSpeed = 0.015
local infiniteAmmo = false
local headExpandEnabled = false
local headSize = 5
local quickInteract = false
local originalPrompts = {}
local chamsEnabled = false
local fallConnection = nil

local espEnabled = false
local espBox = false
local espBoxFill = false
local espBoxFillTransparency = 0.5
local espName = false
local espDistance = false
local espHealthBar = false
local espHealthText = false
local espTool = false
local espRenderDistance = 500
local espRenderTeam = false
local espRenderHz = 60
local espBoxColor = Color3.fromRGB(255, 255, 255)
local espFillColor = Color3.fromRGB(255, 255, 255)
local espNameColor = Color3.fromRGB(255, 255, 255)
local espObjects = {}
local espAccumulator = 0
local ChamObjects = {}

--========================================================--
-- WINDOW
--========================================================--

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
    Settings = Window:AddTab("Settings"),
}

--========================================================--
-- ZEX TAB
--========================================================--

local MovementBox = Tabs.Zex:AddLeftGroupbox("Movement")

MovementBox:AddToggle("NoFall", {
    Text = "No Fall Damage",
    Default = false,
    Callback = function(v)
        noFallEnabled = v
        if fallConnection then fallConnection:Disconnect() fallConnection = nil end
        if v then
            fallConnection = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
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

MovementBox:AddToggle("CFrameSpeed", {
    Text = "CFrame Speed",
    Default = false,
    Callback = function(v) cframeEnabled = v end
})

MovementBox:AddSlider("CFrameSpeedValue", {
    Text = "CFrame Speed",
    Min = 10, Max = 150, Default = 50, Rounding = 0,
    Callback = function(v) cframeSpeed = v end
})

local FOVBox = Tabs.Zex:AddRightGroupbox("FOV")
FOVBox:AddSlider("FOV", {
    Text = "FOV",
    Min = 30, Max = 120, Default = 70, Rounding = 0,
    Callback = function(v)
        currentFOV = v
        pcall(function() Camera.FieldOfView = v end)
    end
})
FOVBox:AddToggle("LockFOV", {
    Text = "Lock FOV",
    Default = false,
    Callback = function(v) lockFOV = v end
})

local RainbowBox = Tabs.Zex:AddLeftGroupbox("Rainbow")
RainbowBox:AddToggle("RainbowBody", {
    Text = "Rainbow Body",
    Default = false,
    Callback = function(v) rainbowBody = v end
})
RainbowBox:AddSlider("BodyTransparency", {
    Text = "Body Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2,
    Callback = function(v) charTransparency = v end
})
RainbowBox:AddSlider("BodySpeed", {
    Text = "Body Speed", Min = 0.001, Max = 0.05, Default = 0.008, Rounding = 3,
    Callback = function(v) rainbowBodySpeed = v end
})
RainbowBox:AddToggle("RainbowGun", {
    Text = "Rainbow Gun",
    Default = false,
    Callback = function(v) rainbowGun = v end
})
RainbowBox:AddSlider("GunTransparency", {
    Text = "Gun Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2,
    Callback = function(v) gunTransparency = v end
})
RainbowBox:AddSlider("GunSpeed", {
    Text = "Gun Speed", Min = 0.001, Max = 0.05, Default = 0.015, Rounding = 3,
    Callback = function(v) rainbowGunSpeed = v end
})

local AmmoBox = Tabs.Zex:AddRightGroupbox("Ammo")
AmmoBox:AddToggle("InfiniteAmmo", {
    Text = "Infinite Ammo",
    Default = false,
    Callback = function(v) infiniteAmmo = v end
})

--===== Limb Extender =====--
local HeadBox = Tabs.Zex:AddRightGroupbox("Limb Extender")

HeadBox:AddToggle("HeadExpand", {
    Text = "Enabled",
    Default = false,
    Callback = function(v)
        headExpandEnabled = v
        if LimbExtender then
            pcall(function()
                if v then
                    LimbExtender:Set("TARGET_LIMB", "Head")
                    LimbExtender:Set("LIMB_SIZE", headSize)
                    LimbExtender:Start()
                else
                    LimbExtender:Stop()
                end
            end)
        end
    end
})

HeadBox:AddSlider("HeadSize", {
    Text = "Limb Size",
    Min = 5, Max = 50, Default = 5, Rounding = 0,
    Callback = function(v)
        headSize = v
        if LimbExtender and headExpandEnabled then
            pcall(function()
                LimbExtender:Set("LIMB_SIZE", v)
            end)
        end
    end
})

HeadBox:AddDropdown("TargetLimb", {
    Text = "Target Limb",
    Default = 1,
    Values = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
    Callback = function(v)
        if LimbExtender and headExpandEnabled then
            pcall(function()
                LimbExtender:Set("TARGET_LIMB", v)
            end)
        end
    end
})

local InteractBox = Tabs.Zex:AddLeftGroupbox("Interaction")
InteractBox:AddToggle("QuickInteract", {
    Text = "Quick Interact",
    Default = false,
    Callback = function(v)
        quickInteract = v
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                if v then
                    if not originalPrompts[obj] then
                        originalPrompts[obj] = {
                            HoldDuration = obj.HoldDuration,
                            RequiresLineOfSight = obj.RequiresLineOfSight
                        }
                    end
                    pcall(function()
                        obj.HoldDuration = 0
                        obj.RequiresLineOfSight = false
                    end)
                else
                    local original = originalPrompts[obj]
                    if original then
                        pcall(function()
                            obj.HoldDuration = original.HoldDuration
                            obj.RequiresLineOfSight = original.RequiresLineOfSight
                        end)
                    end
                end
            end
        end
    end
})

workspace.DescendantAdded:Connect(function(obj)
    if quickInteract and obj:IsA("ProximityPrompt") then
        pcall(function()
            obj.HoldDuration = 0
            obj.RequiresLineOfSight = false
        end)
    end
end)

local ChamsBox = Tabs.Zex:AddLeftGroupbox("Chams")
ChamsBox:AddToggle("SimpleChams", {
    Text = "Simple Chams",
    Default = false,
    Callback = function(v)
        chamsEnabled = v
        if not v then
            for _, hl in pairs(ChamObjects) do
                if hl then pcall(function() hl:Destroy() end) end
            end
            ChamObjects = {}
        end
    end
})

--========================================================--
-- ESP (your existing ESP)
--========================================================--

local function RemoveESP(player)
    local data = espObjects[player]
    if not data then return end
    for _, object in pairs(data) do
        if typeof(object) == "Instance" then
            pcall(function() object:Destroy() end)
        end
    end
    espObjects[player] = nil
end

local function CreateESP(player)
    if player == LocalPlayer or espObjects[player] then return end
    local data = {}
    local highlight = Instance.new("Highlight")
    highlight.Name = "ZexESP"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = espFillColor
    highlight.OutlineColor = espBoxColor
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Enabled = false
    highlight.Parent = CoreGui
    data.Highlight = highlight

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ZexESPInfo"
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
    text.Text = ""
    text.TextYAlignment = Enum.TextYAlignment.Top
    text.Parent = billboard
    data.Text = text

    espObjects[player] = data
end

local function UpdatePlayerESP(player)
    if player == LocalPlayer then return end
    if not espEnabled then
        local data = espObjects[player]
        if data then
            data.Highlight.Enabled = false
            data.Billboard.Enabled = false
        end
        return
    end

    local character = player.Character
    if not character then
        local data = espObjects[player]
        if data then
            data.Highlight.Enabled = false
            data.Billboard.Enabled = false
        end
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end

    if not espRenderTeam then
        if LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
            local data = espObjects[player]
            if data then
                data.Highlight.Enabled = false
                data.Billboard.Enabled = false
            end
            return
        end
    end

    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    local distance = (root.Position - localRoot.Position).Magnitude
    if distance > espRenderDistance then
        local data = espObjects[player]
        if data then
            data.Highlight.Enabled = false
            data.Billboard.Enabled = false
        end
        return
    end

    CreateESP(player)
    local data = espObjects[player]
    if not data then return end

    data.Highlight.Adornee = character
    data.Highlight.OutlineColor = espBoxColor
    data.Highlight.FillColor = espFillColor
    data.Highlight.OutlineTransparency = espBox and 0 or 1
    data.Highlight.FillTransparency = espBoxFill and espBoxFillTransparency or 1
    data.Highlight.Enabled = espBox or espBoxFill

    local lines = {}
    if espName then table.insert(lines, player.Name) end
    if espDistance then table.insert(lines, string.format("[%d studs]", math.floor(distance))) end
    if espHealthBar then
        local health = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
        local bars = 10
        local filled = math.floor(health * bars)
        local healthBar = ""
        for i = 1, bars do
            healthBar = healthBar .. (i <= filled and "█" or "░")
        end
        table.insert(lines, healthBar)
    end
    if espHealthText then
        table.insert(lines, string.format("HP: %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth)))
    end
    if espTool then
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then table.insert(lines, tool.Name) end
    end

    data.Text.Text = table.concat(lines, "\n")
    data.Text.TextColor3 = espNameColor
    data.Billboard.Adornee = root
    data.Billboard.Enabled = #lines > 0
end

local function UpdateAllESP()
    if not espEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local data = espObjects[player]
                if data then
                    data.Highlight.Enabled = false
                    data.Billboard.Enabled = false
                end
            end
        end
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        UpdatePlayerESP(player)
    end
end

local ESPPlayers = Tabs.ESP:AddLeftGroupbox("Players")
local ESPSettings = Tabs.ESP:AddRightGroupbox("Settings")

ESPPlayers:AddToggle("ESPEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(v)
        espEnabled = v
        if not v then UpdateAllESP() end
    end
})

ESPPlayers:AddToggle("ESPBox", {
    Text = "Bounding Box",
    Default = false,
    Callback = function(v) espBox = v end
}):AddColorPicker("ESPBoxColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Box Color",
    Callback = function(v) espBoxColor = v end
})

ESPPlayers:AddToggle("ESPBoxFill", {
    Text = "Fill Box",
    Default = false,
    Callback = function(v) espBoxFill = v end
}):AddColorPicker("ESPBoxFillColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Fill Color",
    Transparency = 0.5,
    Callback = function(v) espFillColor = v end
})

ESPPlayers:AddSlider("ESPFillTransparency", {
    Text = "Fill Transparency",
    Min = 0, Max = 1, Default = 0.5, Rounding = 2,
    Callback = function(v) espBoxFillTransparency = v end
})

ESPPlayers:AddToggle("ESPName", {
    Text = "Name",
    Default = false,
    Callback = function(v) espName = v end
}):AddColorPicker("ESPNameColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Name Color",
    Callback = function(v) espNameColor = v end
})

ESPPlayers:AddToggle("ESPDistance", {
    Text = "Distance",
    Default = false,
    Callback = function(v) espDistance = v end
})

ESPPlayers:AddToggle("ESPHealthBar", {
    Text = "Health Bar",
    Default = false,
    Callback = function(v) espHealthBar = v end
})

ESPPlayers:AddToggle("ESPHealthText", {
    Text = "Health Text",
    Default = false,
    Callback = function(v) espHealthText = v end
})

ESPPlayers:AddToggle("ESPTool", {
    Text = "Tool",
    Default = false,
    Callback = function(v) espTool = v end
})

ESPSettings:AddSlider("ESPRenderHz", {
    Text = "Render Hertz",
    Min = 10, Max = 240, Default = 60, Rounding = 0,
    Callback = function(v) espRenderHz = v end
})

ESPSettings:AddSlider("ESPRenderDistance", {
    Text = "Render Distance",
    Min = 10, Max = 1000, Default = 500, Rounding = 0,
    Callback = function(v) espRenderDistance = v end
})

ESPSettings:AddToggle("ESPRenderTeam", {
    Text = "Render Teammates",
    Default = false,
    Callback = function(v) espRenderTeam = v end
})

--========================================================--
-- VISUALS TAB (original structure)
--========================================================--

local World = Tabs.Visuals:AddGroupbox({ Side = 1, Name = "World" })
local PlayerBox = Tabs.Visuals:AddGroupbox({ Side = 2, Name = "Player" })
local CameraBox = Tabs.Visuals:AddGroupbox({ Side = 2, Name = "Camera" })

-- Ambient
local Ambient = World:AddToggle("visuals/world/ambient", { Text = "Ambient", Default = false })
Ambient:AddColorPicker("visuals/world/ambient/outdoorcolor", { Default = Color3.fromRGB(200, 100, 60), Title = "Outdoor Color" })
Ambient:AddColorPicker("visuals/world/ambient/color", { Default = Color3.fromRGB(140, 90, 70), Title = "Ambient Color" })

-- Brightness
local Brightness = World:AddToggle("visuals/world/brightness", { Text = "Brightness", Default = false })
local BrightnessDep = World:AddDependencyBox()
BrightnessDep:AddSlider("visuals/world/brightness/level", { Text = "Brightness Level", Min = 0, Max = 10, Rounding = 1, Default = 1.6 })
BrightnessDep:AddSlider("visuals/world/brightness/envdiffscale", { Text = "Environment Diffuse Scale", Min = 0, Max = 1, Rounding = 2, Default = 1 })
BrightnessDep:AddSlider("visuals/world/brightness/envspecscale", { Text = "Environment Specular Scale", Min = 0, Max = 1, Rounding = 2, Default = 0.9 })
BrightnessDep:AddSlider("visuals/world/brightness/exposure", { Text = "Exposure Compensation", Min = 0, Max = 1, Rounding = 2, Default = 0.15 })
BrightnessDep:SetupDependencies({ { Toggles["visuals/world/brightness"], true } })

-- Fog
local Fog = World:AddToggle("visuals/world/fog", { Text = "Fog", Default = false })
Fog:AddColorPicker("visuals/world/fog/color", { Default = Color3.fromRGB(255, 255, 255), Title = "Fog Color" })
local FogDep = World:AddDependencyBox()
FogDep:AddSlider("visuals/world/fog/near", { Text = "Fog Near", Min = 0, Max = 1000, Rounding = 1, Default = 0 })
FogDep:AddSlider("visuals/world/fog/far", { Text = "Fog Far", Min = 0, Max = 1000, Rounding = 1, Default = 1000 })
FogDep:SetupDependencies({ { Toggles["visuals/world/fog"], true } })

-- Shadow
local Shadow = World:AddToggle("visuals/world/shadow", { Text = "Shadow Modification", Default = false })
Shadow:AddColorPicker("visuals/world/shadow/color", { Default = Color3.fromRGB(0, 0, 0), Title = "Shadow Color" })
local ShadowDep = World:AddDependencyBox()
ShadowDep:AddSlider("visuals/world/shadow/softness", { Text = "Shadow Softness", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
ShadowDep:AddToggle("visuals/world/shadow/globalshadows", { Text = "Enable Shadows", Default = true })
ShadowDep:SetupDependencies({ { Toggles["visuals/world/shadow"], true } })

-- Lighting
local LightingT = World:AddToggle("visuals/world/lighting", { Text = "Lighting", Default = false })
local LightingDep = World:AddDependencyBox()
LightingDep:AddSlider("visuals/world/lighting/time", { Text = "Clock Time", Min = 0, Max = 23, Rounding = 2, Default = 14 })
LightingDep:AddSlider("visuals/world/lighting/latitude", { Text = "Geographic Latitude", Min = -90, Max = 90, Rounding = 1, Default = 0 })
LightingDep:AddLabel("ColorShift Bottom"):AddColorPicker("visuals/world/lighting/colorshiftbottom", { Default = Color3.fromRGB(255, 255, 255), Title = "ColorShift Bottom" })
LightingDep:AddLabel("ColorShift Top"):AddColorPicker("visuals/world/lighting/colorshifttop", { Default = Color3.fromRGB(255, 255, 255), Title = "ColorShift Top" })
LightingDep:SetupDependencies({ { Toggles["visuals/world/lighting"], true } })

-- Color Grading
World:AddToggle("visuals/world/lighting/colorgrading", { Text = "Color Grading", Default = false })
local ColorGradingDep = World:AddDependencyBox()
local TonemapOptions = {}
for _, EnumItem in Enum.TonemapperPreset:GetEnumItems() do
    table.insert(TonemapOptions, EnumItem.Name)
end
ColorGradingDep:AddDropdown("visuals/world/lighting/colorgrading/tonemap", { Text = "Tone Map Preset", Default = 1, Values = TonemapOptions })
ColorGradingDep:SetupDependencies({ { Toggles["visuals/world/lighting/colorgrading"], true } })

-- Color Correction
local CC = World:AddToggle("visuals/world/lighting/cc", { Text = "Color Correction", Default = false })
local CCDep = World:AddDependencyBox()
CCDep:AddSlider("visuals/world/lighting/cc/saturation", { Text = "Saturation", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
CCDep:AddSlider("visuals/world/lighting/cc/contrast", { Text = "Contrast", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
CCDep:AddSlider("visuals/world/lighting/cc/brightness", { Text = "Brightness", Min = -1, Max = 1, Rounding = 2, Default = 0 })
CC:AddColorPicker("visuals/world/lighting/cc/tint", { Default = Color3.fromRGB(255, 255, 255), Title = "Tint Color" })
CCDep:SetupDependencies({ { Toggles["visuals/world/lighting/cc"], true } })

-- Bloom
World:AddToggle("visuals/world/lighting/bloom", { Text = "Bloom", Default = false })
local BloomDep = World:AddDependencyBox()
BloomDep:AddSlider("visuals/world/lighting/bloom/intensity", { Text = "Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
BloomDep:AddSlider("visuals/world/lighting/bloom/size", { Text = "Size", Min = 0, Max = 56, Rounding = 2, Default = 24 })
BloomDep:AddSlider("visuals/world/lighting/bloom/threshold", { Text = "Threshold", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
BloomDep:SetupDependencies({ { Toggles["visuals/world/lighting/bloom"], true } })

-- Sun Rays
World:AddToggle("visuals/world/sunrays", { Text = "Sun Rays", Default = false })
local SunRaysDep = World:AddDependencyBox()
SunRaysDep:AddSlider("visuals/world/sunrays/intensity", { Text = "Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.1 })
SunRaysDep:AddSlider("visuals/world/sunrays/spread", { Text = "Spread", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
SunRaysDep:SetupDependencies({ { Toggles["visuals/world/sunrays"], true } })

-- Atmosphere
World:AddToggle("visuals/world/atmosphere", { Text = "Atmosphere", Default = false })
local AtmosphereDep = World:AddDependencyBox()
AtmosphereDep:AddSlider("visuals/world/atmosphere/density", { Text = "Density", Min = 0, Max = 1, Rounding = 2, Default = 0.3 })
AtmosphereDep:AddSlider("visuals/world/atmosphere/offset", { Text = "Offset", Min = -1, Max = 1, Rounding = 2, Default = 0 })
AtmosphereDep:AddLabel("Color"):AddColorPicker("visuals/world/atmosphere/color", { Default = Color3.fromRGB(199, 170, 107), Title = "Atmosphere Color" })
AtmosphereDep:AddLabel("Decay"):AddColorPicker("visuals/world/atmosphere/decay", { Default = Color3.fromRGB(106, 112, 125), Title = "Atmosphere Decay" })
AtmosphereDep:AddSlider("visuals/world/atmosphere/glare", { Text = "Glare", Min = 0, Max = 1, Rounding = 2, Default = 0 })
AtmosphereDep:AddSlider("visuals/world/atmosphere/haze", { Text = "Haze", Min = 0, Max = 1, Rounding = 2, Default = 0 })
AtmosphereDep:SetupDependencies({ { Toggles["visuals/world/atmosphere"], true } })

-- Depth of Field
World:AddToggle("visuals/world/dof", { Text = "Depth of Field", Default = false })
local DOFDep = World:AddDependencyBox()
DOFDep:AddSlider("visuals/world/dof/farintens", { Text = "Far Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.28 })
DOFDep:AddSlider("visuals/world/dof/nearintens", { Text = "Near Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.7 })
DOFDep:AddSlider("visuals/world/dof/focusdist", { Text = "Focus Distance", Min = 0, Max = 100, Rounding = 2, Default = 20 })
DOFDep:AddSlider("visuals/world/dof/focusinradius", { Text = "In Focus Radius", Min = -100, Max = 100, Rounding = 2, Default = 20 })
DOFDep:SetupDependencies({ { Toggles["visuals/world/dof"], true } })

-- Weather
World:AddToggle("visuals/world/weather", { Text = "Weather", Default = false })
local WeatherDep = World:AddDependencyBox()
WeatherDep:AddDropdown("visuals/world/weather/type", { Text = "Type", Default = 1, Values = {"Rain", "Snow"} })
WeatherDep:AddSlider("visuals/world/snow/rate", { Text = "Snow Rate", Min = 1, Max = 2000, Rounding = 0, Default = 1000 })
WeatherDep:SetupDependencies({ { Toggles["visuals/world/weather"], true } })

-- Custom Sky Box
World:AddToggle("visuals/world/customskybox", { Text = "Custom Sky Box", Default = false })
local SkyDep = World:AddDependencyBox()
SkyDep:AddDropdown("visuals/world/customskybox/type", { Text = "Type", Default = 1, Values = {"Default"} })
SkyDep:SetupDependencies({ { Toggles["visuals/world/customskybox"], true } })

-- Use 2022 Materials
World:AddToggle("visuals/world/use2022materials", {
    Text = "Use 2022 Materials",
    Default = false,
    Callback = function(v)
        pcall(function()
            sethiddenproperty(MaterialService, "Use2022Materials", v)
        end)
    end
})

-- Player
PlayerBox:AddToggle("visuals/player/chinesehat", { Text = "Chinese Hat", Default = false }):AddColorPicker("visuals/player/chinesehat/color", { Default = Color3.fromRGB(255, 255, 255), Title = "Chinese Hat Color" })
local ChineseHatDep = PlayerBox:AddDependencyBox()
ChineseHatDep:AddSlider("visuals/player/chinesehat/glowfac", { Text = "Glow Factor", Min = 10, Max = 20, Rounding = 0, Default = 10 })
ChineseHatDep:AddSlider("visuals/player/chinesehat/radius", { Text = "Radius", Min = 0, Max = 2, Rounding = 1, Default = 1.5 })
ChineseHatDep:AddSlider("visuals/player/chinesehat/height", { Text = "Height", Min = 0, Max = 2, Rounding = 1, Default = 1 })
ChineseHatDep:AddToggle("visuals/player/chinesehat/alwaysontop", { Text = "Always On Top", Default = false })
ChineseHatDep:SetupDependencies({ { Toggles["visuals/player/chinesehat"], true } })

PlayerBox:AddToggle("visuals/player/appearance", { Text = "Appearance Changer", Default = false })
PlayerBox:AddInput("visuals/player/appearance/id", { Numeric = true, Finished = true, Text = "UserId" })

PlayerBox:AddToggle("visuals/player/breadcrumbs", { Text = "Breadcrumbs", Default = false }):AddColorPicker("visuals/player/breadcrumbs/color", { Default = Color3.fromRGB(255, 255, 255), Title = "Breadcrumbs Color" })
local BreadcrumbsDep = PlayerBox:AddDependencyBox()
BreadcrumbsDep:AddSlider("visuals/player/breadcrumbs/glowfac", { Text = "Glow Factor", Min = 10, Max = 20, Rounding = 0, Default = 10 })
BreadcrumbsDep:AddSlider("visuals/player/breadcrumbs/lifetime", { Text = "Life Time", Min = 0.1, Max = 5, Rounding = 1, Default = 5 })
BreadcrumbsDep:AddSlider("visuals/player/breadcrumbs/fadetime", { Text = "Fade Time", Min = 0.1, Max = 5, Rounding = 1, Default = 5 })
BreadcrumbsDep:SetupDependencies({ { Toggles["visuals/player/breadcrumbs"], true } })

-- Camera / Waifu
CameraBox:AddToggle("visuals/camera/waifu", { Text = "Waifu", Default = false })
local WaifuDep = CameraBox:AddDependencyBox()
WaifuDep:AddInput("visuals/camera/waifu/link", { Text = "Image / GIF URL", Default = "" })
WaifuDep:AddSlider("visuals/camera/waifu/x", { Text = "X", Min = -1920, Max = 1920, Rounding = 0, Default = 0 })
WaifuDep:AddSlider("visuals/camera/waifu/y", { Text = "Y", Min = -1080, Max = 1080, Rounding = 0, Default = 0 })
WaifuDep:AddSlider("visuals/camera/waifu/transparency", { Text = "Transparency", Min = 0, Max = 1, Rounding = 1, Default = 0.5 })
WaifuDep:AddSlider("visuals/camera/waifu/scale", { Text = "Scale", Min = 0, Max = 1, Rounding = 1, Default = 0.5 })
WaifuDep:SetupDependencies({ { Toggles["visuals/camera/waifu"], true } })

--========================================================--
-- MISC TAB (original structure)
--========================================================--

local Movement = Tabs.Misc:AddGroupbox({ Side = 1, Name = "Movement" })
local Exploits = Tabs.Misc:AddGroupbox({ Side = 2, Name = "Exploits" })
local DesyncBox = Tabs.Misc:AddGroupbox({ Side = 2, Name = "Namsync" })

Movement:AddToggle("misc/movement/speed", { Text = "Speed Hack", Default = false })
Movement:AddSlider("misc/movement/speed/value", { Text = "Speed Hack Value", Min = 1, Max = 500, Rounding = 0, Default = 30 })
Movement:AddDropdown("misc/movement/speed/method", { Text = "Speed Hack Method", Default = 1, Values = {"Directional", "MoveDir"} })

Movement:AddToggle("misc/movement/moonwalk", { Text = "Moon Walk", Default = false }):AddKeyPicker("misc/movement/moonwalk/key", { Text = "Moon Walk Key", SyncToggleState = false, Mode = "Hold", Default = "T" })

Movement:AddToggle("misc/movement/autojump", { Text = "Auto Jump", Default = false })
Movement:AddDropdown("misc/movement/autojump/method", { Text = "Auto Jump Method", Default = 1, Values = {"Humanoid", "Velocity", "State"} })

Movement:AddToggle("misc/movement/fly", { Text = "Fly", Default = false }):AddKeyPicker("misc/movement/fly/key", { Text = "Fly Key", SyncToggleState = false, Mode = "Hold", Default = "T" })
Movement:AddSlider("misc/movement/flyspeed/value", { Text = "Fly Speed", Min = 1, Max = 500, Rounding = 0, Default = 30 })

Movement:AddToggle("misc/movement/noclip", { Text = "No Collisions", Default = false }):AddKeyPicker("misc/movement/noclip/key", { Text = "No Collisions Key", SyncToggleState = false, Mode = "Hold", Default = "T" })

Movement:AddToggle("misc/movement/pixelsurf", { Text = "Pixel Surf", Default = false }):AddKeyPicker("misc/movement/pixelsurf/key", { Text = "Pixel Surf Key", SyncToggleState = false, Mode = "Hold", Default = "F" })

Exploits:AddToggle("misc/exploits/antifling", { Text = "Anti Fling", Default = false })

DesyncBox:AddToggle("misc/desync", { Text = "Enable", Default = false })
DesyncBox:AddToggle("misc/desync/freezepos", { Text = "Freeze Position", Default = false }):AddKeyPicker("misc/desync/freezepos/key", { Text = "Freeze Pos Key", SyncToggleState = false, Mode = "Hold", Default = "E" })
DesyncBox:AddToggle("misc/desync/randompos", { Text = "Random Position", Default = false }):AddKeyPicker("misc/desync/randompos/key", { Text = "Random Pos Key", SyncToggleState = false, Mode = "Toggle", Default = "F" })
local RandomPosDep = DesyncBox:AddDependencyBox()
RandomPosDep:AddSlider("misc/desync/randompos/x", { Text = "X", Min = -360, Max = 360, Rounding = 0, Default = 0 })
RandomPosDep:AddSlider("misc/desync/randompos/y", { Text = "Y", Min = -360, Max = 360, Rounding = 0, Default = 0 })
RandomPosDep:AddSlider("misc/desync/randompos/z", { Text = "Z", Min = -360, Max = 360, Rounding = 0, Default = 0 })
RandomPosDep:SetupDependencies({ { Toggles["misc/desync/randompos"], true } })

DesyncBox:AddToggle("misc/desync/offset", { Text = "Offset", Default = false })
local OffsetDep = DesyncBox:AddDependencyBox()
OffsetDep:AddSlider("misc/desync/offset/x", { Text = "X", Min = -360, Max = 360, Rounding = 0, Default = 0 })
OffsetDep:AddSlider("misc/desync/offset/y", { Text = "Y", Min = -360, Max = 360, Rounding = 0, Default = 0 })
OffsetDep:AddSlider("misc/desync/offset/z", { Text = "Z", Min = -360, Max = 360, Rounding = 0, Default = 0 })
OffsetDep:AddSlider("misc/desync/offset/speed", { Text = "Animation Speed", Min = 0, Max = 100, Rounding = 1, Default = 10 })
OffsetDep:SetupDependencies({ { Toggles["misc/desync/offset"], true } })

DesyncBox:AddToggle("misc/desync/jitter", { Text = "Jitter", Default = false })
local JitterDep = DesyncBox:AddDependencyBox()
JitterDep:AddSlider("misc/desync/jitter/x", { Text = "X", Min = -360, Max = 360, Rounding = 0, Default = 0 })
JitterDep:AddSlider("misc/desync/jitter/y", { Text = "Y", Min = -360, Max = 360, Rounding = 0, Default = 0 })
JitterDep:AddSlider("misc/desync/jitter/z", { Text = "Z", Min = -360, Max = 360, Rounding = 0, Default = 0 })
JitterDep:AddSlider("misc/desync/jitter/speed", { Text = "Speed", Min = 1, Max = 60, Rounding = 0, Default = 10 })
JitterDep:SetupDependencies({ { Toggles["misc/desync/jitter"], true } })

DesyncBox:AddToggle("misc/desync/rotation", { Text = "Rotation Offset", Default = false })
local RotationDep = DesyncBox:AddDependencyBox()
RotationDep:AddSlider("misc/desync/rotation/x", { Text = "Pitch", Min = -180, Max = 180, Rounding = 0, Default = 0 })
RotationDep:AddSlider("misc/desync/rotation/y", { Text = "Yaw", Min = -180, Max = 180, Rounding = 0, Default = 0 })
RotationDep:AddSlider("misc/desync/rotation/z", { Text = "Roll", Min = -180, Max = 180, Rounding = 0, Default = 0 })
RotationDep:SetupDependencies({ { Toggles["misc/desync/rotation"], true } })

DesyncBox:AddSlider("misc/desync/speed", { Text = "Speed", Min = 0, Max = 100, Rounding = 1, Default = 1 })
DesyncBox:AddToggle("misc/desync/useeasingstyle", { Text = "Use Easing Style", Default = false })
DesyncBox:AddDropdown("misc/desync/easingstyle", { Text = "Easing Style", Default = 1, Values = {"Sine", "Quad", "Cubic", "Quart", "Quint", "Exponential", "Circular", "Linear", "SmoothStep", "SmootherStep", "Back", "Elastic", "Bounce"} })
DesyncBox:AddDropdown("misc/desync/easingdirection", { Text = "Easing Direction", Default = 3, Values = {"In", "Out", "InOut"} })

--========================================================--
-- SETTINGS
--========================================================--

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("Testing")
SaveManager:SetFolder("Testing")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

--========================================================--
-- HELPERS
--========================================================--

local function forceAmmo()
    local configurations = ReplicatedStorage:FindFirstChild("Configurations")
    if not configurations then return end
    local acsGuns = configurations:FindFirstChild("ACS_Guns")
    if not acsGuns then return end
    for _, folder in ipairs(acsGuns:GetChildren()) do
        local ammo = folder:FindFirstChild("Ammo")
        if ammo then pcall(function() ammo.Value = 999 end) end
        local chambered = folder:FindFirstChild("Chambered")
        if chambered then pcall(function() chambered.Value = true end) end
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
                if gunColor then
                    pcall(function()
                        obj.Color = gunColor
                        obj.Material = Enum.Material.ForceField
                    end)
                end
                pcall(function() obj.Transparency = gunTransparency end)
            end
        end
    end
end

local function UpdateChams()
    if not chamsEnabled then
        for _, hl in pairs(ChamObjects) do
            if hl then pcall(function() hl:Destroy() end) end
        end
        ChamObjects = {}
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local existing = ChamObjects[player]
            if not existing or not existing.Parent then
                local highlight = Instance.new("Highlight")
                highlight.Name = "ZexCham"
                highlight.Adornee = player.Character
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillColor = Color3.fromRGB(255, 255, 255)
                highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
                highlight.FillTransparency = 0.5
                highlight.Parent = CoreGui
                ChamObjects[player] = highlight
            else
                existing.Adornee = player.Character
            end
        end
    end
end

--========================================================--
-- MAIN LOOP (runs original modules + your features)
--========================================================--

RunService.Heartbeat:Connect(function(dt)
    -- Original modules
    pcall(function()
        if Visuals and Visuals.Tick then Visuals.Tick(dt) end
        if Misc and Misc.Tick then Misc.Tick(dt) end
        if Desync and Desync.Tick then Desync.Tick(dt) end
    end)

    -- Your ESP
    if espEnabled then
        espAccumulator = espAccumulator + dt
        if espAccumulator >= (1 / math.max(espRenderHz, 1)) then
            espAccumulator = 0
            UpdateAllESP()
        end
    end

    local char = LocalPlayer.Character
    if not char then return end

    -- Your CFrame Speed
    if cframeEnabled then
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if root and hum and hum.MoveDirection.Magnitude > 0 then
            pcall(function()
                root.CFrame = root.CFrame + hum.MoveDirection * (cframeSpeed * 0.02)
            end)
        end
    end

    -- FOV Lock
    if lockFOV and Camera then
        pcall(function() Camera.FieldOfView = currentFOV end)
    end

    -- Rainbow Body
    if rainbowBody then
        charHue = (charHue + rainbowBodySpeed) % 1
        local bodyColor = Color3.fromHSV(charHue, 1, 1)
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
                pcall(function()
                    obj.Material = Enum.Material.ForceField
                    obj.Color = bodyColor
                    obj.Transparency = charTransparency
                end)
            elseif obj:IsA("Accessory") then
                local handle = obj:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    pcall(function()
                        handle.Material = Enum.Material.ForceField
                        handle.Color = bodyColor
                        handle.Transparency = charTransparency
                    end)
                end
            end
        end
    end

    applyRainbowGun()
    if infiniteAmmo then forceAmmo() end
    if chamsEnabled then UpdateChams() end
end)

Players.PlayerAdded:Connect(function(player)
    if espEnabled then CreateESP(player) end
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    if ChamObjects[player] then
        pcall(function() ChamObjects[player]:Destroy() end)
        ChamObjects[player] = nil
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then CreateESP(player) end
end

Library:OnUnload(function()
    if fallConnection then fallConnection:Disconnect() end
    if LimbExtender then pcall(function() LimbExtender:Stop() end) end
    for player in pairs(espObjects) do RemoveESP(player) end
    for _, hl in pairs(ChamObjects) do if hl then hl:Destroy() end end
    print("Moe unloaded")
end)

print("Moe - Full Script with Original Modules + Limb Extender loaded")
