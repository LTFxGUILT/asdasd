local MaterialService = game:GetService("MaterialService")

local World = {}
World.__index = World

function World.new(options)
    options = options or {}

    local self = setmetatable({}, World)

    self.Tabs = options.Tabs
    self.Toggles = options.Toggles or {}
    self.SkyNames = options.SkyNames or {}
    self.ApplySkybox = options.ApplySkybox

    assert(self.Tabs and self.Tabs.Visuals, "[World] Tabs.Visuals is required")
    assert(self.ApplySkybox, "[World] ApplySkybox is required")

    self.Initialized = false
    self.WorldBox = nil

    return self
end

function World:_AddToggle(box, flag, options)
    local toggle = box:AddToggle(flag, options)
    self.Toggles[flag] = toggle
    return toggle
end

function World:Init()
    if self.Initialized then
        return self
    end

    self.Initialized = true

    local WorldBox = self.Tabs.Visuals:AddGroupbox({
        Side = 1,
        Name = "World"
    })

    self.WorldBox = WorldBox

    --========================================================--
    -- AMBIENT
    --========================================================--

    local Ambient = self:_AddToggle(
        WorldBox,
        "visuals/world/ambient",
        {
            Text = "Ambient",
            Default = false
        }
    )

    Ambient:AddColorPicker(
        "visuals/world/ambient/outdoorcolor",
        {
            Default = Color3.fromRGB(200, 100, 60),
            Title = "Outdoor Color"
        }
    )

    Ambient:AddColorPicker(
        "visuals/world/ambient/color",
        {
            Default = Color3.fromRGB(140, 90, 70),
            Title = "Ambient Color"
        }
    )

    --========================================================--
    -- BRIGHTNESS
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/brightness",
        {
            Text = "Brightness",
            Default = false
        }
    )

    local BrightnessDep = WorldBox:AddDependencyBox()

    BrightnessDep:AddSlider(
        "visuals/world/brightness/level",
        {
            Text = "Brightness Level",
            Min = 0,
            Max = 10,
            Rounding = 1,
            Default = 1.6
        }
    )

    BrightnessDep:AddSlider(
        "visuals/world/brightness/envdiffscale",
        {
            Text = "Environment Diffuse Scale",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 1
        }
    )

    BrightnessDep:AddSlider(
        "visuals/world/brightness/envspecscale",
        {
            Text = "Environment Specular Scale",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.9
        }
    )

    BrightnessDep:AddSlider(
        "visuals/world/brightness/exposure",
        {
            Text = "Exposure Compensation",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.15
        }
    )

    BrightnessDep:SetupDependencies({
        {
            self.Toggles["visuals/world/brightness"],
            true
        }
    })

    --========================================================--
    -- FOG
    --========================================================--

    local Fog = self:_AddToggle(
        WorldBox,
        "visuals/world/fog",
        {
            Text = "Fog",
            Default = false
        }
    )

    Fog:AddColorPicker(
        "visuals/world/fog/color",
        {
            Default = Color3.fromRGB(255, 255, 255),
            Title = "Fog Color"
        }
    )

    local FogDep = WorldBox:AddDependencyBox()

    FogDep:AddSlider(
        "visuals/world/fog/near",
        {
            Text = "Fog Near",
            Min = 0,
            Max = 1000,
            Rounding = 1,
            Default = 0
        }
    )

    FogDep:AddSlider(
        "visuals/world/fog/far",
        {
            Text = "Fog Far",
            Min = 0,
            Max = 1000,
            Rounding = 1,
            Default = 1000
        }
    )

    FogDep:SetupDependencies({
        {
            self.Toggles["visuals/world/fog"],
            true
        }
    })

    --========================================================--
    -- SHADOW MODIFICATION
    --========================================================--

    local Shadow = self:_AddToggle(
        WorldBox,
        "visuals/world/shadow",
        {
            Text = "Shadow Modification",
            Default = false
        }
    )

    Shadow:AddColorPicker(
        "visuals/world/shadow/color",
        {
            Default = Color3.fromRGB(0, 0, 0),
            Title = "Shadow Color"
        }
    )

    local ShadowDep = WorldBox:AddDependencyBox()

    ShadowDep:AddSlider(
        "visuals/world/shadow/softness",
        {
            Text = "Shadow Softness",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.5
        }
    )

    ShadowDep:AddToggle(
        "visuals/world/shadow/globalshadows",
        {
            Text = "Enable Shadows",
            Default = true
        }
    )

    ShadowDep:SetupDependencies({
        {
            self.Toggles["visuals/world/shadow"],
            true
        }
    })

    --========================================================--
    -- LIGHTING
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/lighting",
        {
            Text = "Lighting",
            Default = false
        }
    )

    local LightingDep = WorldBox:AddDependencyBox()

    LightingDep:AddSlider(
        "visuals/world/lighting/time",
        {
            Text = "Clock Time",
            Min = 0,
            Max = 23,
            Rounding = 2,
            Default = 14
        }
    )

    LightingDep:AddSlider(
        "visuals/world/lighting/latitude",
        {
            Text = "Geographic Latitude",
            Min = -90,
            Max = 90,
            Rounding = 1,
            Default = 0
        }
    )

    LightingDep:AddLabel("ColorShift Bottom"):AddColorPicker(
        "visuals/world/lighting/colorshiftbottom",
        {
            Default = Color3.fromRGB(255, 255, 255),
            Title = "ColorShift Bottom"
        }
    )

    LightingDep:AddLabel("ColorShift Top"):AddColorPicker(
        "visuals/world/lighting/colorshifttop",
        {
            Default = Color3.fromRGB(255, 255, 255),
            Title = "ColorShift Top"
        }
    )

    do
        local TechOptions = {}

        for _, EnumItem in Enum.Technology:GetEnumItems() do
            table.insert(TechOptions, EnumItem.Name)
        end

        LightingDep:AddDropdown(
            "visuals/world/lighting/technology",
            {
                Text = "Technology",
                Default = 1,
                Values = TechOptions
            }
        )
    end

    LightingDep:SetupDependencies({
        {
            self.Toggles["visuals/world/lighting"],
            true
        }
    })

    --========================================================--
    -- COLOR GRADING
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/lighting/colorgrading",
        {
            Text = "Color Grading",
            Default = false
        }
    )

    local ColorGradingDep = WorldBox:AddDependencyBox()

    do
        local TonemapOptions = {}

        for _, EnumItem in Enum.TonemapperPreset:GetEnumItems() do
            table.insert(TonemapOptions, EnumItem.Name)
        end

        ColorGradingDep:AddDropdown(
            "visuals/world/lighting/colorgrading/tonemap",
            {
                Text = "Tone Map Preset",
                Default = 1,
                Values = TonemapOptions
            }
        )
    end

    ColorGradingDep:SetupDependencies({
        {
            self.Toggles["visuals/world/lighting/colorgrading"],
            true
        }
    })

    --========================================================--
    -- COLOR CORRECTION
    --========================================================--

    local CC = self:_AddToggle(
        WorldBox,
        "visuals/world/lighting/cc",
        {
            Text = "Color Correction",
            Default = false
        }
    )

    local CCDep = WorldBox:AddDependencyBox()

    CCDep:AddSlider(
        "visuals/world/lighting/cc/saturation",
        {
            Text = "Saturation",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.5
        }
    )

    CCDep:AddSlider(
        "visuals/world/lighting/cc/contrast",
        {
            Text = "Contrast",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.5
        }
    )

    CCDep:AddSlider(
        "visuals/world/lighting/cc/brightness",
        {
            Text = "Brightness",
            Min = -1,
            Max = 1,
            Rounding = 2,
            Default = 0
        }
    )

    CC:AddColorPicker(
        "visuals/world/lighting/cc/tint",
        {
            Default = Color3.fromRGB(255, 255, 255),
            Title = "Tint Color"
        }
    )

    CCDep:SetupDependencies({
        {
            self.Toggles["visuals/world/lighting/cc"],
            true
        }
    })

    --========================================================--
    -- BLOOM
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/lighting/bloom",
        {
            Text = "Bloom",
            Default = false
        }
    )

    local BloomDep = WorldBox:AddDependencyBox()

    BloomDep:AddSlider(
        "visuals/world/lighting/bloom/intensity",
        {
            Text = "Intensity",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.5
        }
    )

    BloomDep:AddSlider(
        "visuals/world/lighting/bloom/size",
        {
            Text = "Size",
            Min = 0,
            Max = 56,
            Rounding = 2,
            Default = 24
        }
    )

    BloomDep:AddSlider(
        "visuals/world/lighting/bloom/threshold",
        {
            Text = "Threshold",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.5
        }
    )

    BloomDep:SetupDependencies({
        {
            self.Toggles["visuals/world/lighting/bloom"],
            true
        }
    })

    --========================================================--
    -- SUN RAYS
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/sunrays",
        {
            Text = "Sun Rays",
            Default = false
        }
    )

    local SunRaysDep = WorldBox:AddDependencyBox()

    SunRaysDep:AddSlider(
        "visuals/world/sunrays/intensity",
        {
            Text = "Intensity",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.1
        }
    )

    SunRaysDep:AddSlider(
        "visuals/world/sunrays/spread",
        {
            Text = "Spread",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.5
        }
    )

    SunRaysDep:SetupDependencies({
        {
            self.Toggles["visuals/world/sunrays"],
            true
        }
    })

    --========================================================--
    -- ATMOSPHERE
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/atmosphere",
        {
            Text = "Atmosphere",
            Default = false
        }
    )

    local AtmosphereDep = WorldBox:AddDependencyBox()

    AtmosphereDep:AddSlider(
        "visuals/world/atmosphere/density",
        {
            Text = "Density",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.3
        }
    )

    AtmosphereDep:AddSlider(
        "visuals/world/atmosphere/offset",
        {
            Text = "Offset",
            Min = -1,
            Max = 1,
            Rounding = 2,
            Default = 0
        }
    )

    AtmosphereDep:AddLabel("Color"):AddColorPicker(
        "visuals/world/atmosphere/color",
        {
            Default = Color3.fromRGB(199, 170, 107),
            Title = "Atmosphere Color"
        }
    )

    AtmosphereDep:AddLabel("Decay"):AddColorPicker(
        "visuals/world/atmosphere/decay",
        {
            Default = Color3.fromRGB(106, 112, 125),
            Title = "Atmosphere Decay"
        }
    )

    AtmosphereDep:AddSlider(
        "visuals/world/atmosphere/glare",
        {
            Text = "Glare",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0
        }
    )

    AtmosphereDep:AddSlider(
        "visuals/world/atmosphere/haze",
        {
            Text = "Haze",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0
        }
    )

    AtmosphereDep:SetupDependencies({
        {
            self.Toggles["visuals/world/atmosphere"],
            true
        }
    })

    --========================================================--
    -- DEPTH OF FIELD
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/dof",
        {
            Text = "Depth of Field",
            Default = false
        }
    )

    local DOFDep = WorldBox:AddDependencyBox()

    DOFDep:AddSlider(
        "visuals/world/dof/farintens",
        {
            Text = "Far Intensity",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.28
        }
    )

    DOFDep:AddSlider(
        "visuals/world/dof/nearintens",
        {
            Text = "Near Intensity",
            Min = 0,
            Max = 1,
            Rounding = 2,
            Default = 0.7
        }
    )

    DOFDep:AddSlider(
        "visuals/world/dof/focusdist",
        {
            Text = "Focus Distance",
            Min = 0,
            Max = 100,
            Rounding = 2,
            Default = 20
        }
    )

    DOFDep:AddSlider(
        "visuals/world/dof/focusinradius",
        {
            Text = "In Focus Radius",
            Min = -100,
            Max = 100,
            Rounding = 2,
            Default = 20
        }
    )

    DOFDep:SetupDependencies({
        {
            self.Toggles["visuals/world/dof"],
            true
        }
    })

    --========================================================--
    -- WEATHER
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/weather",
        {
            Text = "Weather",
            Default = false
        }
    )

    local WeatherDep = WorldBox:AddDependencyBox()

    WeatherDep:AddDropdown(
        "visuals/world/weather/type",
        {
            Text = "Type",
            Default = 1,
            Values = {
                "Rain",
                "Snow"
            }
        }
    )

    WeatherDep:AddSlider(
        "visuals/world/snow/rate",
        {
            Text = "Snow Rate",
            Min = 1,
            Max = 2000,
            Rounding = 0,
            Default = 1000
        }
    )

    WeatherDep:SetupDependencies({
        {
            self.Toggles["visuals/world/weather"],
            true
        }
    })

    --========================================================--
    -- CUSTOM SKY BOX
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/customskybox",
        {
            Text = "Custom Sky Box",
            Default = false,

            Callback = function(value)
                self.SkyboxEnabled = value

                if value then
                    self.ApplySkybox(self.CurrentSkybox or "Default")
                else
                    self.ApplySkybox("Default")
                end
            end
        }
    )

    self.CurrentSkybox = "Default"
    self.SkyboxEnabled = false

    local SkyDep = WorldBox:AddDependencyBox()

    SkyDep:AddDropdown(
        "visuals/world/customskybox/type",
        {
            Text = "Type",
            Default = 1,
            Values = self.SkyNames,

            Callback = function(value)
                self.CurrentSkybox = value

                if self.SkyboxEnabled then
                    self.ApplySkybox(value)
                end
            end
        }
    )

    SkyDep:SetupDependencies({
        {
            self.Toggles["visuals/world/customskybox"],
            true
        }
    })

    --========================================================--
    -- USE 2022 MATERIALS
    --========================================================--

    self:_AddToggle(
        WorldBox,
        "visuals/world/use2022materials",
        {
            Text = "Use 2022 Materials",
            Default = false,

            Callback = function(value)
                pcall(function()
                    sethiddenproperty(
                        MaterialService,
                        "Use2022Materials",
                        value
                    )
                end)
            end
        }
    )

    return self
end

function World:Destroy()
    self.Initialized = false
    self.WorldBox = nil
end

return World
