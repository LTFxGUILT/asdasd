-- Creatures of Sonaria game module
-- return setup(deps) where deps supplies Tabs, Library, services, helpers

return function(deps)
    deps = deps or {}

    local Tabs = deps.Tabs
    local Toggles = deps.Toggles or {}
    local Library = deps.Library
    local ThemeManager = deps.ThemeManager
    local AddToggle = deps.AddToggle
    local GameInfo = deps.GameInfo

    local Players = deps.Players or game:GetService("Players")
    local LocalPlayer = deps.LocalPlayer or Players.LocalPlayer
    local RunService = deps.RunService or game:GetService("RunService")
    local ReplicatedStorage = deps.ReplicatedStorage or game:GetService("ReplicatedStorage")
    local Workspace = deps.Workspace or game:GetService("Workspace")
    local CoreGui = deps.CoreGui or game:GetService("CoreGui")
    local UserInputService = deps.UserInputService or game:GetService("UserInputService")
    local CollectionService = deps.CollectionService or game:GetService("CollectionService")
    local MarketplaceService = deps.MarketplaceService or game:GetService("MarketplaceService")

    local PlaceId = deps.PlaceId or game.PlaceId
    local PlaceName = deps.PlaceName or "Creatures of Sonaria"
    local getRoot = deps.getRoot

    if not getRoot then
        getRoot = function()
            local char = LocalPlayer.Character
            return char and char:FindFirstChild("HumanoidRootPart"),
                char and char:FindFirstChildOfClass("Humanoid"),
                char
        end
    end

    if not AddToggle then
        AddToggle = function(box, flag, options)
            local toggle = box:AddToggle(flag, options)
            Toggles[flag] = toggle
            return toggle
        end
    end

    local function SetupCreaturesOfSonaria()
        do
            local C = {
                espEnabled = false,
                showName = true,
                showSpecies = true,
                showDistance = true,
                showHealth = true,
                showGrowth = true,
                showWeight = true,
                showHighlight = true,
                maxDistance = 500,
                maxTracked = 50,
                renderHz = 12,
                scanAccum = 0,
                espObjects = {},
                foodEspEnabled = false,
                foodChamsEnabled = true,
                foodEspDistance = 500,
                foodEspHz = 2,
                foodScanAccum = 0,
                foodEspObjects = {},
                foodCandidates = {},
                foodCandidatesInitialized = false,
            }

            local PURPLE = Color3.fromRGB(170, 90, 255)
            local WHITE = Color3.fromRGB(235, 235, 240)
            local MUTED = Color3.fromRGB(155, 155, 170)

            --==========================================================
            -- CHARACTER DATA REGISTRY
            --
            -- Every stat in CoS is read through one method,
            -- CharacterData:GetWithModifiers(name), and that method lives on
            -- the class table rather than on an instance. So it is wrapped
            -- once, in place, and every read for every player in the server
            -- passes through it:
            --
            --   local class = Sonar("CharacterData")   -- the class, not an instance
            --   class.GetWithModifiers = function(self, stat, extra) ... end
            --
            -- Each instance carries a .Player field, which is what makes the
            -- local one identifiable exactly. Identifying it by species does
            -- not work: the HUD surfaces on this account read
            -- Lmakosauruodon while the live CharacterData says Ani, because
            -- those labels are slot and skin previews rather than the
            -- creature actually being played.
            --
            -- Read volume is roughly 700 calls a second, so the wrapper stays
            -- allocation free. Two guarded table writes, one lookup that
            -- misses almost every time, then straight through to the original.
            --
            -- Overrides apply to the local instance only. The method is shared
            -- by every player, so applying them unconditionally would change
            -- what the client believes about everyone else, which is both
            -- wrong and visible in the ESP.
            --==========================================================
            local Stats = {
                installed = false,
                class = nil,
                original = nil,
                repOriginal = nil,
                byPlayer = setmetatable({}, { __mode = "k" }),
                localData = nil,
                overrides = {},
                repOverrides = nil,
                mult = {},
                flag = {},
                activeCount = 0,
            }

            -- Ability cooldowns are not a stat at all, which is why pinning
            -- AbilityCooldown changed nothing. ActiveAbilityData gates on a
            -- replicated server timestamp instead:
            --
            --   local last = Target.CharacterData:GetReplicatedData("LastShadowBarrage")
            --   if last and workspace:GetServerTimeNow() - last < Data.Cooldown then
            --       return
            --   end
            --
            -- The AbilityCooldown stat is a separate path whose base is
            -- already 1, so Data.Cooldown * (1 - 1) is already zero and
            -- moving it changed no behaviour. Reading the timestamp back as 0
            -- makes the elapsed time enormous instead, which is what actually
            -- clears the gate.
            --
            -- These apply to every instance, not just the local one, because
            -- the gate reads p1.Target.CharacterData: when an ability picks a
            -- target the check runs against that target's data, so a
            -- local-only override would miss it. Unlike the stat overrides
            -- nothing here feeds the ESP, so widening it is not visible.
            --
            -- Deliberately excluded: LastBite, LastBreathHit, LastHit,
            -- LastNest and LastSniff. LastBite in particular is read by Damage
            -- for damage attribution, so rewriting it is not the same thing
            -- as clearing a client gate.
            local ABILITY_COOLDOWN_KEYS = {
                LastShadowBarrage = true,
                LastCharacterHit = true,
            }

            local function readStat(instance, stat)
                local fn = Stats.original

                if type(instance) ~= "table" or type(fn) ~= "function" then return nil end

                local ok, value = pcall(fn, instance, stat)

                if ok and type(value) == "number" then return value end

                return nil
            end

            local function readCached(instance, key)
                if type(instance) ~= "table" then return nil end

                local ok, value = pcall(instance.GetCached, instance, key)

                if not ok then return nil end

                if value == nil then return nil end

                return value
            end

            local function speciesOf(instance)
                if type(instance) ~= "table" then return nil end

                local ok, value = pcall(function() return instance.Species end)

                if ok and type(value) == "string" and value ~= "" then return value end

                return nil
            end

            -- Rebuilds the override table from the multipliers and flags
            -- against the current real values. Recomputing rather than caching
            -- a base matters because the real values move on their own as the
            -- creature grows, and it also covers the window between a slider
            -- moving and the local instance existing at all.
            local function recomputeOverrides()

                local instance = Stats.localData
                local out = {}

                for stat, mult in pairs(Stats.mult) do
                    if type(mult) == "number" and mult > 1 then
                        local base = readStat(instance, stat)

                        if base then out[stat] = base * mult end
                    end
                end

                -- Bite Cooldown is the one stat where going DOWN is the useful
                -- direction, so it cannot go through the loop above. That loop
                -- only applies a multiplier when it is greater than 1, on the
                -- assumption that every other stat is a "bigger is stronger"
                -- value. BiteCooldown is the reverse, a lower number meaning
                -- a shorter wait between attacks, so a slider sitting at 0.25
                -- would have been read and then discarded and the bite rate
                -- would never have changed while the panel claimed it had.
                --
                -- It is a real stat, read through GetWithModifiers by
                -- CharacterData.GetNewPlayerBiteMultiplier, which is the same
                -- function AttackHandler.Bite, the server Damage module and
                -- RunicSnareClient.canSpendBite all call to decide whether a
                -- bite is allowed yet. Measured live with a real BiteCooldown
                -- of 0.8 and 1870 seconds played, the multiplier read 0.685;
                -- at a quarter it read 0.171, and it returned to 0.685 the
                -- moment the override was dropped.
                local bite = Stats.mult.BiteCooldown

                if type(bite) == "number" and bite > 0 and bite < 1 then
                    local base = readStat(instance, "BiteCooldown")

                    if base then out.BiteCooldown = base * bite end
                end

                -- AbilityCooldown is consumed as Cooldown * (1 - value) in one
                -- path, but its base is already 1 so that path is already
                -- zero. The gate that actually blocks an ability is the
                -- replicated timestamp, handled by the GetReplicatedData
                -- wrapper below.
                if Stats.flag.NoCooldown then
                    Stats.repOverrides = ABILITY_COOLDOWN_KEYS
                else
                    Stats.repOverrides = nil
                end

                -- Nightvision is only ever tested for truthiness
                if Stats.flag.Nightvision then out.Nightvision = 4 end

                -- Stamina is tracked on the client by StaminaTracker, which
                -- ClientCharacter builds itself, and the drain timestamps
                -- LastSprintStaminaDrain, LastFlightStaminaDrain and
                -- LastSwimStaminaDrain all live there too. So the regen rate
                -- is genuinely ours to change. Measured with the real
                -- StaminaRegen of 5, a drain to 29 then sat at 27, 27, 27,
                -- 26, 26, 25 and kept falling; with this applied the same
                -- drain refilled to 190 and held at 190, 190, 190, 190, 189,
                -- 188. Both regen rates are worth a very large number for
                -- the same reason.
                if Stats.flag.NoStaminaDrain then out.StaminaRegen = 1e6 end
                if Stats.flag.InfiniteGlide then out.GlideRegen = 1e6 end

                -- CanSlowFallAtAge is compared as Age.Value < value, so
                -- anything above the current age lets every fall be slowed.
                -- This one is kept because ClientCharacter's
                -- _getSoftLandingPower reads it directly, so it changes how
                -- the client controller actually handles a fall.
                if Stats.flag.SlowFall then out.CanSlowFallAtAge = 1e6 end

                -- Walk and run animation speed are read from the same modifier
                -- family as Speed. Raising Speed on its own leaves the
                -- creature moving faster than its legs are cycling, which
                -- reads as a moonwalk, so they are moved together.
                local speed = Stats.mult.Speed
                if type(speed) == "number" and speed > 1 then
                    local walk = readStat(instance, "WalkAnimationSpeed")
                    local run = readStat(instance, "RunAnimationSpeed")

                    if walk then out.WalkAnimationSpeed = walk * speed end
                    if run then out.RunAnimationSpeed = run * speed end
                end

                Stats.overrides = out

                local count = 0
                for _ in pairs(out) do count = count + 1 end

                Stats.activeCount = count
            end

            local function installStats()

                if Stats.installed then return true end

                local okSonar, Sonar = pcall(require, game.ReplicatedStorage.Sonar)

                if not okSonar then return false end

                local okClass, class = pcall(Sonar, "CharacterData")

                if not okClass or type(class) ~= "table" then return false end

                local original = class.GetWithModifiers

                if type(original) ~= "function" then return false end

                Stats.class = class
                Stats.original = original
                Stats.installed = true

                class.GetWithModifiers = function(self, stat, extra)
                    if type(self) == "table" and type(stat) == "string" then
                        local owner = rawget(self, "Player")

                        if typeof(owner) == "Instance" then
                            if Stats.byPlayer[owner] ~= self then
                                Stats.byPlayer[owner] = self
                            end

                            if owner == LocalPlayer then
                                Stats.localData = self

                                local override = Stats.overrides[stat]

                                if override ~= nil then return override end
                            end
                        end
                    end

                    return original(self, stat, extra)
                end

                -- Second hook on the same class, for the ability cooldown
                -- gate. Same read volume class, same guarded lookup, and it
                -- shares this function's install and uninstall so there is
                -- still only one thing to restore.
                local repOriginal = class.GetReplicatedData

                if type(repOriginal) == "function" then
                    Stats.repOriginal = repOriginal

                    class.GetReplicatedData = function(self, key, ...)
                        if type(self) == "table" and type(key) == "string" then
                            local rep = Stats.repOverrides

                            if rep ~= nil and rep[key] then
                                return 0
                            end
                        end

                        return repOriginal(self, key, ...)
                    end
                end

                return true
            end

            -- Restores the game's own method. The saved original is used
            -- rather than whatever is currently installed, so repeated
            -- uninstalls cannot leave a wrapper in place.
            local function uninstallStats()

                if not Stats.installed then return end

                if Stats.class and Stats.original then
                    Stats.class.GetWithModifiers = Stats.original
                end

                if Stats.class and Stats.repOriginal then
                    Stats.class.GetReplicatedData = Stats.repOriginal
                end

                Stats.installed = false
                Stats.class = nil
                Stats.original = nil
                Stats.repOriginal = nil
                Stats.localData = nil
                Stats.overrides = {}
                Stats.repOverrides = nil
                Stats.mult = {}
                Stats.flag = {}
                Stats.activeCount = 0
                Stats.byPlayer = setmetatable({}, { __mode = "k" })
            end

            Stats.uninstall = uninstallStats
            getgenv().__Testing.COSStats = Stats

            -- Passive on purpose. The registry is what feeds the ESP its real
            -- species, health, weight and age, so it is installed whether or
            -- not any override is active. Without it the ESP falls back to the
            -- name scanners, which is exactly the guessing this replaces.
            installStats()

            local function getLocalRoot()
                local char = LocalPlayer.Character
                if not char then return nil end
                return char:FindFirstChild("HumanoidRootPart")
                    or char.PrimaryPart
                    or char:FindFirstChildWhichIsA("BasePart", true)
            end

            local function getRoot(model)
                if not model then return nil end
                return model:FindFirstChild("HumanoidRootPart")
                    or model.PrimaryPart
                    or model:FindFirstChild("RootPart")
                    or model:FindFirstChildWhichIsA("BasePart", true)
            end

            local function getValueFromContainer(container, names)
                if not container then return nil end

                for _, name in ipairs(names) do
                    local ok, value = pcall(function()
                        return container:GetAttribute(name)
                    end)

                    if ok and value ~= nil then
                        return value
                    end

                    local child = container:FindFirstChild(name)
                    if child and child:IsA("ValueBase") then
                        local ok2, value2 = pcall(function()
                            return child.Value
                        end)
                        if ok2 and value2 ~= nil then
                            return value2
                        end
                    end
                end

                return nil
            end

            local function getCreatureSpecies(character)
                if not character then return "Unknown species" end

                local player = Players:GetPlayerFromCharacter(character)

                local candidateNames = {
                    "CreatureName", "Creature", "SpeciesName", "Species",
                    "CreatureSpecies", "CurrentCreature", "CurrentSpecies",
                    "SpeciesId", "CreatureId", "StoredCreature", "CreatureData"
                }

                -- CoS can keep the active species data outside the character
                -- model, so check the Player as well as the character.
                local containers = { character }
                if player then table.insert(containers, player) end

                for _, container in ipairs(containers) do
                    local value = getValueFromContainer(container, candidateNames)
                    if value ~= nil then
                        local text = tostring(value)
                        if text ~= "" and text ~= player and text ~= character.Name then
                            return text
                        end
                    end

                    -- Also inspect direct child containers such as Data/Stats.
                    for _, child in ipairs(container:GetChildren()) do
                        local value2 = getValueFromContainer(child, candidateNames)
                        if value2 ~= nil then
                            local text2 = tostring(value2)
                            if text2 ~= "" and text2 ~= container.Name then
                                return text2
                            end
                        end
                    end
                end

                -- Some builds expose the species as a named child Model.
                -- Ignore the generic/player character containers.
                local generic = {
                    ["Character"] = true, ["CurrentCharacter"] = true,
                    ["HumanoidRootPart"] = true, ["Humanoid"] = true,
                    [player and player.Name or "__none__"] = true,
                }

                for _, obj in ipairs(character:GetChildren()) do
                    if obj:IsA("Model") and not generic[obj.Name] then
                        local n = obj.Name
                        if n ~= "" and #n > 1 then
                            return n
                        end
                    end
                end

                -- Last resort: use the character model name when it is not just
                -- the Roblox player name.
                if player and character.Name ~= player.Name then
                    return character.Name
                end

                return "Unknown species"
            end

            local function getNamedValueRecursive(root, names, maxDepth)
                if not root then return nil end

                maxDepth = maxDepth or 5
                local wanted = {}
                for _, name in ipairs(names) do
                    wanted[string.lower(name)] = true
                end

                local function inspect(instance)
                    for name in pairs(wanted) do
                        local ok, value = pcall(function()
                            return instance:GetAttribute(name)
                        end)
                        if ok and value ~= nil then
                            return value
                        end
                    end

                    if instance:IsA("ValueBase") then
                        local key = string.lower(instance.Name)
                        if wanted[key] then
                            local ok, value = pcall(function()
                                return instance.Value
                            end)
                            if ok and value ~= nil then
                                return value
                            end
                        end
                    end

                    for _, child in ipairs(instance:GetChildren()) do
                        local key = string.lower(child.Name)
                        if wanted[key] and child:IsA("ValueBase") then
                            local ok, value = pcall(function()
                                return child.Value
                            end)
                            if ok and value ~= nil then
                                return value
                            end
                        end
                    end

                    return nil
                end

                local direct = inspect(root)
                if direct ~= nil then return direct end

                local descendants = {}
                pcall(function()
                    descendants = root:GetDescendants()
                end)

                for _, obj in ipairs(descendants) do
                    local depth = 0
                    local current = obj
                    while current and current ~= root do
                        depth += 1
                        if depth > maxDepth then break end
                        current = current.Parent
                    end

                    if depth <= maxDepth then
                        local value = inspect(obj)
                        if value ~= nil then
                            return value
                        end
                    end
                end

                return nil
            end

            local function getAttributeRecursive(root, names, maxDepth)
                if not root then return nil end
                maxDepth = maxDepth or 5

                local wanted = {}
                for _, name in ipairs(names) do
                    wanted[string.lower(name)] = true
                end

                local function check(instance)
                    local ok, attributes = pcall(function()
                        return instance:GetAttributes()
                    end)

                    if ok then
                        for key, value in pairs(attributes) do
                            if wanted[string.lower(key)] and value ~= nil then
                                return value
                            end
                        end
                    end

                    return nil
                end

                local direct = check(root)
                if direct ~= nil then return direct end

                local descendants = {}
                pcall(function()
                    descendants = root:GetDescendants()
                end)

                for _, obj in ipairs(descendants) do
                    local depth = 0
                    local current = obj
                    while current and current ~= root do
                        depth += 1
                        if depth > maxDepth then break end
                        current = current.Parent
                    end

                    if depth <= maxDepth then
                        local value = check(obj)
                        if value ~= nil then return value end
                    end
                end

                return nil
            end

            local function getCreatureHealth(character)
                if not character then return nil, nil end

                -- Standard Roblox Humanoid fallback.
                local hum = character:FindFirstChildOfClass("Humanoid")
                if hum then
                    local hp, maxHp = hum.Health, hum.MaxHealth
                    if maxHp and maxHp > 0 then
                        return hp, maxHp
                    end
                end

                local healthNames = {
                    "Health", "CurrentHealth", "HP", "CurrentHP",
                    "HitPoints", "CurrentHitPoints"
                }

                local maxHealthNames = {
                    "MaxHealth", "MaximumHealth", "MaxHP",
                    "MaxHitPoints", "MaximumHitPoints"
                }

                -- CoS data can live in nested Data/Stats containers rather than
                -- directly on the character.
                local hp = getNamedValueRecursive(character, healthNames, 8)
                local maxHp = getNamedValueRecursive(character, maxHealthNames, 8)

                if hp == nil then
                    hp = getAttributeRecursive(character, healthNames, 8)
                end
                if maxHp == nil then
                    maxHp = getAttributeRecursive(character, maxHealthNames, 8)
                end

                hp = tonumber(hp)
                maxHp = tonumber(maxHp)

                if hp and maxHp and maxHp > 0 then
                    return hp, maxHp
                elseif hp then
                    return hp, hp
                end

                return nil, nil
            end

            local function getCreatureGrowth(character)
                if not character then return nil end

                local growthNames = {
                    "Growth", "GrowthPercent", "GrowthPercentage",
                    "Age", "AgePercent", "AgePercentage",
                    "CurrentAge", "CreatureAge", "GrowthStage",
                    "GrowthValue", "AgeValue"
                }

                local value = getNamedValueRecursive(character, growthNames, 8)
                if value == nil then
                    value = getAttributeRecursive(character, growthNames, 8)
                end

                if value == nil then return nil end

                -- Preserve useful percentage/age strings exactly when the game
                -- exposes them that way.
                local text = tostring(value)
                if text == "" then return nil end

                return text
            end

            -- Destroys only the two objects this script created, by name.
            --
            -- This used to sweep every value in the data table and destroy
            -- anything that was an Instance. That table also caches
            -- data.Character, which is the player's own Character model, so
            -- switching the ESP off deleted every other player's mesh. They
            -- stayed able to see and hit you while you could not see them at
            -- all, and it only recovered on their next respawn. A generic
            -- sweep over a table that mixes our objects with game objects
            -- cannot be made safe, so the created objects are named instead.
            -- data.Text needs no entry: it is a child of the billboard and
            -- goes with it.
            local function destroyESP(player)
                local data = C.espObjects[player]
                if not data then return end

                if data.Highlight then
                    pcall(function() data.Highlight:Destroy() end)
                end
                if data.Billboard then
                    pcall(function() data.Billboard:Destroy() end)
                end

                C.espObjects[player] = nil
            end

            local function createESP(player)
                if player == LocalPlayer or C.espObjects[player] then return end

                local data = {}

                local highlight = Instance.new("Highlight")
                highlight.Name = "COS_CreatureHighlight"
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillColor = PURPLE
                highlight.OutlineColor = WHITE
                highlight.FillTransparency = 0.78
                highlight.OutlineTransparency = 0.05
                highlight.Enabled = false
                highlight.Parent = CoreGui
                data.Highlight = highlight

                local billboard = Instance.new("BillboardGui")
                billboard.Name = "COS_CreatureInfo"
                billboard.Size = UDim2.fromOffset(230, 112)
                billboard.StudsOffset = Vector3.new(0, 4, 0)
                billboard.AlwaysOnTop = true
                billboard.MaxDistance = 2500
                billboard.Enabled = false
                billboard.Parent = CoreGui
                data.Billboard = billboard

                local text = Instance.new("TextLabel")
                text.Size = UDim2.fromScale(1, 1)
                text.BackgroundTransparency = 1
                text.Font = Enum.Font.Code
                text.TextSize = 13
                text.TextColor3 = WHITE
                text.TextStrokeTransparency = 0
                text.TextXAlignment = Enum.TextXAlignment.Center
                text.TextYAlignment = Enum.TextYAlignment.Top
                text.Parent = billboard
                data.Text = text
                data.Character = nil
                data.LastStatsAt = 0
                data.CachedSpecies = nil
                data.CachedHP = nil
                data.CachedMaxHP = nil
                data.CachedGrowth = nil
                data.CachedWeight = nil

                C.espObjects[player] = data
            end

            local function updateESPForPlayer(player)
                if player == LocalPlayer then return end

                local data = C.espObjects[player]

                if not C.espEnabled then
                    if data then
                        data.Highlight.Enabled = false
                        data.Billboard.Enabled = false
                    end
                    return
                end

                local character = player.Character
                local root = getRoot(character)
                local localRoot = getLocalRoot()

                if not character or not root or not localRoot then
                    if data then
                        data.Highlight.Enabled = false
                        data.Billboard.Enabled = false
                    end
                    return
                end

                local distance = (root.Position - localRoot.Position).Magnitude

                if distance > C.maxDistance then
                    if data then
                        data.Highlight.Enabled = false
                        data.Billboard.Enabled = false
                    end
                    return
                end

                local camera = workspace.CurrentCamera
                if camera then
                    local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
                    if screenPos.Z <= 0 or not onScreen then
                        if data then
                            data.Highlight.Enabled = false
                            data.Billboard.Enabled = false
                        end
                        return
                    end
                end

                createESP(player)
                data = C.espObjects[player]
                if not data then return end

                local lines = {}

                if C.showName then
                    table.insert(lines, player.DisplayName or player.Name)
                end

                -- Cache the expensive recursive CoS stat lookups. Position/UI
                -- updates can run frequently, but the underlying stat structure
                -- only needs to be inspected a few times per second.
                if data.Character ~= character then
                    data.Character = character
                    data.LastStatsAt = 0
                    data.CachedSpecies = nil
                    data.CachedHP = nil
                    data.CachedMaxHP = nil
                    data.CachedGrowth = nil
                    data.CachedWeight = nil
                end

                local now = os.clock()
                if now - (data.LastStatsAt or 0) >= 0.75 then
                    data.LastStatsAt = now

                    -- The registry is authoritative: Species, the two health
                    -- stats, Weight and Age all come straight off the game's
                    -- own per player CharacterData. The recursive name
                    -- scanners below are only the fallback for a player the
                    -- registry has not seen yet.
                    local instance = Stats.byPlayer[player]

                    if instance then
                        data.CachedSpecies = speciesOf(instance) or data.CachedSpecies
                        data.CachedHP = readStat(instance, "Health")
                        data.CachedMaxHP = readStat(instance, "MaxHealth")
                        data.CachedWeight = readStat(instance, "Weight")
                        data.CachedGrowth = readCached(instance, "Age")
                    else
                        data.CachedSpecies = getCreatureSpecies(character)
                        data.CachedHP, data.CachedMaxHP = getCreatureHealth(character)
                        data.CachedGrowth = getCreatureGrowth(character)
                        data.CachedWeight = nil
                    end
                end

                if C.showSpecies and data.CachedSpecies then
                    table.insert(lines, data.CachedSpecies)
                end

                if C.showDistance then
                    table.insert(lines, string.format("[%d studs]", math.floor(distance)))
                end

                if C.showHealth and data.CachedHP and data.CachedMaxHP and data.CachedMaxHP > 0 then
                    local hpPercent = math.clamp((data.CachedHP / data.CachedMaxHP) * 100, 0, 100)

                    -- absolute values are available now, so a bare percentage
                    -- would throw away the number that actually matters in a
                    -- fight. 435/435 says far more than 100%
                    table.insert(lines, string.format(
                        "HP: %d/%d  %d%%",
                        math.floor(data.CachedHP + 0.5),
                        math.floor(data.CachedMaxHP + 0.5),
                        math.floor(hpPercent + 0.5)
                    ))
                end

                if C.showWeight and data.CachedWeight then
                    local mine = readStat(Stats.localData, "Weight")
                    local weight = string.format("Weight: %d", math.floor(data.CachedWeight + 0.5))

                    -- GetWeightPercent is clamp(mine / theirs, 0, 3) and the
                    -- species data documents weight as scaling damage in both
                    -- directions, so the ratio is the fight relevant number
                    if mine and mine > 0 then
                        local ratio = math.clamp(mine / data.CachedWeight, 0, 3)
                        weight = weight .. string.format("  %.2fx", ratio)
                    end

                    table.insert(lines, weight)
                end

                if C.showGrowth and data.CachedGrowth then
                    table.insert(lines, "Age: " .. tostring(data.CachedGrowth))
                end

                data.Highlight.Adornee = character
                data.Highlight.Enabled = C.showHighlight
                data.Billboard.Adornee = root
                data.Text.Text = table.concat(lines, "\n")
                data.Billboard.Enabled = #lines > 0
            end

            local function updateAllESP()
                local localRoot = getLocalRoot()
                if not localRoot then return 0 end

                -- Avoid allocating/sorting a new distance table every update.
                -- CoS can have many players/creatures, so a simple bounded pass
                -- is noticeably cheaper while still respecting Max Tracked.
                local tracked = 0

                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local root = getRoot(player.Character)
                        if root then
                            local distance = (root.Position - localRoot.Position).Magnitude
                            if distance <= C.maxDistance and tracked < C.maxTracked then
                                tracked += 1
                                updateESPForPlayer(player)
                            else
                                local data = C.espObjects[player]
                                if data then
                                    data.Highlight.Enabled = false
                                    data.Billboard.Enabled = false
                                end
                            end
                        end
                    end
                end

                return tracked
            end

            -- Creature ESP
            local EspBox = Tabs.GameMods:AddLeftGroupbox("Creatures of Sonaria | Creature ESP")

            EspBox:AddToggle("COS_ESP_Enabled", {
                Text = "Creature ESP",
                Default = false,
                Callback = function(v)
                    C.espEnabled = v

                    if not v then
                        for player in pairs(C.espObjects) do
                            destroyESP(player)
                        end
                    end
                end,
            })

            EspBox:AddToggle("COS_ESP_Name", {
                Text = "Player Name",
                Default = true,
                Callback = function(v) C.showName = v end,
            })

            EspBox:AddToggle("COS_ESP_Species", {
                Text = "Creature / Species",
                Default = true,
                Callback = function(v) C.showSpecies = v end,
            })

            EspBox:AddToggle("COS_ESP_Distance", {
                Text = "Distance",
                Default = true,
                Callback = function(v) C.showDistance = v end,
            })

            EspBox:AddToggle("COS_ESP_Health", {
                Text = "Health",
                Default = true,
                Callback = function(v) C.showHealth = v end,
            })

            EspBox:AddToggle("COS_ESP_Growth", {
                Text = "Age / Growth",
                Default = true,
                Callback = function(v) C.showGrowth = v end,
            })

            EspBox:AddToggle("COS_ESP_Weight", {
                Text = "Weight",
                Default = true,
                Callback = function(v) C.showWeight = v end,
            })

            EspBox:AddToggle("COS_ESP_Highlight", {
                Text = "Highlight",
                Default = true,
                Callback = function(v) C.showHighlight = v end,
            })

            EspBox:AddSlider("COS_ESP_Distance", {
                Text = "Max Distance",
                Min = 50,
                Max = 2000,
                Default = 500,
                Rounding = 0,
                Callback = function(v) C.maxDistance = v end,
            })

            EspBox:AddSlider("COS_ESP_MaxTracked", {
                Text = "Max Tracked",
                Min = 5,
                Max = 75,
                Default = 50,
                Rounding = 0,
                Callback = function(v) C.maxTracked = v end,
            })

            EspBox:AddSlider("COS_ESP_RenderHz", {
                Text = "Render Hertz",
                Min = 4,
                Max = 30,
                Default = 10,
                Rounding = 0,
                Callback = function(v) C.renderHz = v end,
            })

            --==========================================================
            -- FOOD ESP (visual/read-only)
            --==========================================================
            -- CoS food nodes are not all named "Food". Some worlds use
            -- grass patches / plants / resource models, so this detector
            -- checks names, ancestors, attributes, Value objects and tags.
            local FOOD_KEYWORDS = {
                "food", "foodsource", "food source", "edible",
                "berry", "berries", "fruit", "mushroom", "meat",
                "fish", "carcass", "plantfood", "plant food",
                "grass", "grasspatch", "grass patch", "bush",
                "berrybush", "berry bush", "plant", "forage",
                "forageable", "resource", "foodnode", "food node"
            }

            local FOOD_TAGS = {
                "Food", "FoodSource", "FoodNode", "Edible", "Forage",
                "Forageable", "Resource", "Plant", "Grass"
            }

            local FOOD_ATTRIBUTE_NAMES = {
                "Food", "IsFood", "FoodSource", "IsFoodSource", "Edible",
                "IsEdible", "Forage", "Forageable", "Resource", "ResourceType",
                "FoodType", "FoodName", "PlantType"
            }

            local function lower(v)
                return string.lower(tostring(v or ""))
            end

            local function containsFoodKeyword(name)
                name = lower(name)
                for _, keyword in ipairs(FOOD_KEYWORDS) do
                    if string.find(name, keyword, 1, true) then
                        return true
                    end
                end
                return false
            end

            local function hasFoodTag(obj)
                for _, tag in ipairs(FOOD_TAGS) do
                    local ok, result = pcall(function()
                        return CollectionService:HasTag(obj, tag)
                    end)
                    if ok and result then
                        return true
                    end
                end
                return false
            end

            local function hasFoodAttribute(obj)
                if not obj then return false end

                for _, name in ipairs(FOOD_ATTRIBUTE_NAMES) do
                    local ok, value = pcall(function()
                        return obj:GetAttribute(name)
                    end)

                    if ok and value ~= nil then
                        if typeof(value) == "boolean" then
                            if value then return true end
                        else
                            local text = lower(value)
                            if text ~= "" and text ~= "false" and text ~= "0" then
                                return true
                            end
                        end
                    end
                end

                return false
            end

            local function hasFoodValueObject(obj)
                if not obj then return false end

                for _, name in ipairs(FOOD_ATTRIBUTE_NAMES) do
                    local child = obj:FindFirstChild(name)
                    if child and child:IsA("ValueBase") then
                        local value = child.Value
                        if typeof(value) == "boolean" and value then
                            return true
                        elseif value ~= nil and lower(value) ~= "false" and lower(value) ~= "0" then
                            return true
                        end
                    end
                end

                return false
            end

            local function findFoodAncestor(obj)
                local current = obj
                local depth = 0

                while current and depth < 7 do
                    if current:IsA("Model") or current:IsA("Folder") then
                        if containsFoodKeyword(current.Name)
                            or hasFoodTag(current)
                            or hasFoodAttribute(current)
                            or hasFoodValueObject(current) then
                            return current
                        end
                    end

                    current = current.Parent
                    depth += 1
                end

                return nil
            end

            local function looksLikeFood(obj)
                if not obj then return false end

                -- Direct name check.
                if containsFoodKeyword(obj.Name) then
                    return true
                end

                -- Game metadata / CollectionService tags.
                if hasFoodTag(obj) or hasFoodAttribute(obj) or hasFoodValueObject(obj) then
                    return true
                end

                -- A grass/food part is often a child of the actual resource model.
                if findFoodAncestor(obj) then
                    return true
                end

                return false
            end

            local function getFoodPart(obj)
                if obj:IsA("BasePart") then return obj end
                if obj:IsA("Model") then
                    return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                end
                return obj:FindFirstChildWhichIsA("BasePart", true)
            end

            local function getFoodRoot(obj)
                -- Prefer the actual resource model so a multi-part grass patch
                -- receives one marker/cham instead of one per mesh/part.
                local ancestor = findFoodAncestor(obj)
                if ancestor then return ancestor end

                if obj:IsA("Model") then return obj end
                return obj
            end

            local function destroyFoodESP(obj)
                local data = C.foodEspObjects[obj]
                if not data then return end

                if data.Highlight then
                    pcall(function() data.Highlight:Destroy() end)
                end
                if data.Billboard then
                    pcall(function() data.Billboard:Destroy() end)
                end

                C.foodEspObjects[obj] = nil
            end

            local function createFoodESP(obj, part)
                if C.foodEspObjects[obj] or not part then return end

                local data = {}

                -- Food chams: purely visual Highlight, no collision/physics changes.
                local highlight = Instance.new("Highlight")
                highlight.Name = "COS_FoodCham"
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillColor = Color3.fromRGB(120, 255, 140)
                highlight.OutlineColor = Color3.fromRGB(235, 255, 235)
                highlight.FillTransparency = 0.70
                highlight.OutlineTransparency = 0.05
                highlight.Enabled = C.foodChamsEnabled and C.foodEspEnabled

                if obj:IsA("Model") or obj:IsA("BasePart") then
                    highlight.Adornee = obj
                else
                    highlight.Adornee = part
                end

                highlight.Parent = CoreGui
                data.Highlight = highlight

                local gui = Instance.new("BillboardGui")
                gui.Name = "COS_FoodESP"
                gui.Size = UDim2.fromOffset(170, 40)
                gui.StudsOffset = Vector3.new(0, 2.5, 0)
                gui.AlwaysOnTop = true
                gui.MaxDistance = C.foodEspDistance
                gui.Enabled = true
                gui.Adornee = part
                gui.Parent = CoreGui

                local label = Instance.new("TextLabel")
                label.Size = UDim2.fromScale(1, 1)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.Code
                label.TextSize = 13
                label.TextColor3 = Color3.fromRGB(170, 255, 170)
                label.TextStrokeTransparency = 0
                label.Text = "FOOD\n" .. obj.Name
                label.Parent = gui

                data.Billboard = gui
                C.foodEspObjects[obj] = data
            end

            local function registerFoodCandidate(obj)
                if not obj then return end
                if not (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Folder")) then return end
                if looksLikeFood(obj) then
                    C.foodCandidates[obj] = true
                end
            end

            local function rebuildFoodCandidates()
                table.clear(C.foodCandidates)

                -- One initial scan when Food ESP is enabled. After this, the
                -- cache is maintained by DescendantAdded / tag signals instead
                -- of repeatedly walking the entire streamed map.
                for _, obj in ipairs(workspace:GetDescendants()) do
                    registerFoodCandidate(obj)
                end

                for _, tag in ipairs(FOOD_TAGS) do
                    local tagged = {}
                    pcall(function() tagged = CollectionService:GetTagged(tag) end)
                    for _, obj in ipairs(tagged) do
                        if obj and obj:IsDescendantOf(workspace) then
                            C.foodCandidates[obj] = true
                            local root = getFoodRoot(obj)
                            if root then C.foodCandidates[root] = true end
                        end
                    end
                end

                C.foodCandidatesInitialized = true
            end

            local function updateFoodESP()
                if not C.foodEspEnabled then
                    for obj in pairs(C.foodEspObjects) do destroyFoodESP(obj) end
                    return
                end

                if not C.foodCandidatesInitialized then
                    rebuildFoodCandidates()
                end

                local localRoot = getLocalRoot()
                if not localRoot then return end

                local seen = {}

                for obj in pairs(C.foodCandidates) do
                    if not obj or not obj.Parent or not obj:IsDescendantOf(workspace) then
                        C.foodCandidates[obj] = nil
                    else
                        local foodRoot = getFoodRoot(obj)
                        local part = getFoodPart(foodRoot) or getFoodPart(obj)

                        if foodRoot and part then
                            local distance = (part.Position - localRoot.Position).Magnitude
                            if distance <= C.foodEspDistance then
                                seen[foodRoot] = true
                                createFoodESP(foodRoot, part)

                                local data = C.foodEspObjects[foodRoot]
                                if data then
                                    data.Billboard.Adornee = part
                                    data.Billboard.MaxDistance = C.foodEspDistance
                                    data.Billboard.Enabled = true
                                    data.Highlight.Enabled = C.foodChamsEnabled and C.foodEspEnabled
                                    data.Highlight.Adornee = (foodRoot:IsA("Model") or foodRoot:IsA("BasePart")) and foodRoot or part
                                end
                            end
                        end
                    end
                end

                for obj in pairs(C.foodEspObjects) do
                    if not seen[obj] or not obj.Parent then
                        destroyFoodESP(obj)
                    end
                end
            end

            -- Keep the candidate cache current as CoS streams resource nodes in.
            Workspace.DescendantAdded:Connect(function(obj)
                if C.foodEspEnabled then
                    registerFoodCandidate(obj)
                end
            end)

            Workspace.DescendantRemoving:Connect(function(obj)
                C.foodCandidates[obj] = nil
                if C.foodEspObjects[obj] then
                    destroyFoodESP(obj)
                end
            end)

            for _, tag in ipairs(FOOD_TAGS) do
                pcall(function()
                    CollectionService:GetInstanceAddedSignal(tag):Connect(function(obj)
                        if C.foodEspEnabled and obj then
                            C.foodCandidates[obj] = true
                            local root = getFoodRoot(obj)
                            if root then C.foodCandidates[root] = true end
                        end
                    end)
                end)
            end

            local FoodBox = Tabs.GameMods:AddLeftGroupbox("ESP")
            FoodBox:AddToggle("COS_FoodESP", {
                Text = "ESP",
                Default = false,
                Callback = function(v)
                    C.foodEspEnabled = v
                    if v then
                        C.foodCandidatesInitialized = false
                    else
                        for obj in pairs(C.foodEspObjects) do destroyFoodESP(obj) end
                        table.clear(C.foodCandidates)
                        C.foodCandidatesInitialized = false
                    end
                end,
            })

            FoodBox:AddToggle("COS_FoodChams", {
                Text = "Chams",
                Default = true,
                Callback = function(v)
                    C.foodChamsEnabled = v
                    for _, data in pairs(C.foodEspObjects) do
                        if data.Highlight then
                            data.Highlight.Enabled = v and C.foodEspEnabled
                        end
                    end
                end,
            })

            FoodBox:AddSlider("COS_FoodDistance", {
                Text = "Max Distance",
                Min = 50,
                Max = 2000,
                Default = 500,
                Rounding = 0,
                Callback = function(v)
                    C.foodEspDistance = v
                    for _, data in pairs(C.foodEspObjects) do
                        if data.Billboard then data.Billboard.MaxDistance = v end
                    end
                end,
            })

            FoodBox:AddSlider("COS_FoodScanHz", {
                Text = "Scan Rate",
                Min = 1,
                Max = 10,
                Default = 2,
                Rounding = 0,
                Callback = function(v) C.foodEspHz = v end,
            })

            FoodBox:AddLabel("Includes plants, berries, grass, and resource patches.")

            -- Hitbox expander.
            --
            -- The per frame re-apply is Finder_Guy's mechanic and it is the
            -- part that actually matters: the game pushes the real size back
            -- down continuously, so a one shot set is undone within a frame
            -- or two and looks broken. That is kept exactly as it was.
            --
            -- What is grown is HumanoidRootPart, and that is measured rather
            -- than assumed. The model also carries a Part named Hitbox,
            -- Transparency 1 and the only part in the whole 155 part model
            -- with CanCollide set to true, which reads like the melee volume
            -- and is the obvious thing to grow instead. Tested in game: it
            -- visibly resizes but melee reach does not change, so the attack
            -- check does not read it. HumanoidRootPart is the part that
            -- actually works, so it is the only target.
            --
            -- That is not a workaround either. AttackHandler.Bite sizes an
            -- invisible probe part named HitPart out of Root.Size and then
            -- calls GetTouchingParts on it, so the root is genuinely where
            -- the attack volume comes from. The box comes out Root.Size.X * 2
            -- wide by Root.Size.Z * 0.75 deep, which is why it ends up so
            -- much wider than it is deep.
            --
            -- The cost of that is that the root is the anchor every
            -- interaction range in the game is measured from, so growing it
            -- also puts NPCs, items and prompts in reach. That is inherent to
            -- targeting the root and cannot be separated from it while keeping
            -- the reach that works.
            local HitboxBox = Tabs.GameMods:AddLeftGroupbox("Hitbox Expander")

            local hitboxState = {
                enabled = false,
                focusCamera = true,
                size = 200,
                character = nil,
                original = nil,
                cameraSubject = nil,
                status = nil,
                lastStatus = nil,
                rootConnection = nil,
            }

            -- resolves to the live part, or nil
            local function getTargetPart()

                local character = LocalPlayer.Character

                if not character then return nil end

                return character:FindFirstChild("HumanoidRootPart")

            end

            -- pristine sizes live on genv, keyed by character and part name,
            -- so the reference value survives the run being torn down. that is
            -- what lets Restore put the real size back even if the local state
            -- was lost while the part was still sitting at the expanded size
            local pristineStore = getgenv().__Testing.HitboxPristine

            if not pristineStore then

                pristineStore = {}
                getgenv().__Testing.HitboxPristine = pristineStore

            end

            -- remember the untouched part, once per character and once per
            -- target, so switching target does not capture a size this
            -- expander already wrote
            local function captureOriginal(part, character)

                if hitboxState.original
                    and hitboxState.character == character
                    and hitboxState.targetName == part.Name then

                    return

                end

                local key = tostring(character) .. "/" .. part.Name
                local cached = pristineStore[key]

                -- only trust a cached entry if it still carries every field
                -- this version records. entries written before a field was
                -- added come back with that field nil, and restoring a nil
                -- silently leaves the property at whatever it is now, which
                -- is how CastShadow used to get stuck off
                if cached
                    and cached.size ~= nil
                    and cached.transparency ~= nil
                    and cached.canCollide ~= nil
                    and cached.castShadow ~= nil then

                    hitboxState.character = character
                    hitboxState.targetName = part.Name
                    hitboxState.original = cached

                    return

                end

                -- never record an already expanded size as the pristine one.
                -- it means this part is still carrying a write from an
                -- earlier run or from before a target switch, and capturing
                -- it would make Restore put the expanded size back, leaving
                -- no way to undo the expander from the window
                local expanded = Vector3.new(
                    hitboxState.size,
                    hitboxState.size,
                    hitboxState.size
                )

                if (part.Size - expanded).Magnitude <= 0.01 then

                    return

                end

                local original = {
                    size = part.Size,
                    transparency = part.Transparency,
                    canCollide = part.CanCollide,
                    castShadow = part.CastShadow,
                }

                pristineStore[key] = original

                hitboxState.character = character
                hitboxState.targetName = part.Name
                hitboxState.original = original

            end

            -- single write path for the status label. applyHitbox runs on
            -- Heartbeat, so an unconditional SetText here is 60 redundant
            -- label relayouts a second for a string that only changes when
            -- the slider moves, and that shows up as jitter in the window
            local function setStatus(text)

                if not hitboxState.status then return end

                if hitboxState.lastStatus ~= text then

                    hitboxState.lastStatus = text
                    hitboxState.status:SetText(text)

                end

            end

            local function restoreHitbox()

                local character = hitboxState.character
                local part = character and character:FindFirstChild(hitboxState.targetName)

                if part and hitboxState.original then

                    part.Size = hitboxState.original.size
                    part.Transparency = hitboxState.original.transparency
                    part.CanCollide = hitboxState.original.canCollide
                    part.CastShadow = hitboxState.original.castShadow

                end

                if hitboxState.cameraSubject and hitboxState.cameraSubject.Parent then

                    Camera.CameraSubject = hitboxState.cameraSubject
                    Camera.CameraType = Enum.CameraType.Custom

                end

                hitboxState.character = nil
                hitboxState.original = nil
                hitboxState.cameraSubject = nil
                hitboxState.targetName = nil

                setStatus("Hitbox : off")

            end

            -- called on Heartbeat, so it must stay cheap. every write is
            -- guarded by a comparison, otherwise this spams property sets at
            -- 60hz for no reason and the resizing itself starts to stutter.
            local function applyHitbox()

                local part = getTargetPart()

                if not part then

                    setStatus("Hitbox : not found")

                    return false

                end

                captureOriginal(part, LocalPlayer.Character)

                local wanted = Vector3.new(hitboxState.size, hitboxState.size, hitboxState.size)

                if (part.Size - wanted).Magnitude > 0.01 then

                    part.Size = wanted

                end

                -- Transparency stays 1 on a real root, so 0.7 is what makes the
                -- expanded box actually visible. CastShadow has to be killed
                -- separately, since at 0.7 it still throws a shadow big enough
                -- to black out the whole area
                if math.abs(part.Transparency - 0.7) > 0.01 then

                    part.Transparency = 0.7

                end

                if part.CastShadow then

                    part.CastShadow = false

                end

                -- the root is the only part being grown and it never wants to
                -- collide, so unlike the Hitbox part this is unconditional
                if part.CanCollide then

                    part.CanCollide = false

                end

                setStatus(string.format(
                    "Hitbox : %.0f studs",
                    part.Size.Magnitude
                ))

                return true

            end

            -- needed because a 200 stud root swallows a camera parented to it
            local function focusOnHead()

                if not hitboxState.focusCamera then return end

                local character = LocalPlayer.Character

                if not character then return end

                local head = character:FindFirstChild("Head", true)
                    or character:FindFirstChild("MiddleBody", true)
                    or character:FindFirstChild("UpperBody", true)

                if not head or not head:IsA("BasePart") then return end

                -- stash on the first frame regardless of where the camera
                -- already is. guarding this on "subject is not the head"
                -- meant that when the game had already parked the camera on
                -- Head there was nothing recorded, and switching the toggle
                -- off then had no original subject to put back
                if not hitboxState.cameraSubject then

                    hitboxState.cameraSubject = Camera.CameraSubject

                end

                if Camera.CameraSubject ~= head then

                    Camera.CameraSubject = head
                    Camera.CameraType = Enum.CameraType.Custom

                end

            end

            local function tickHitbox()

                if not hitboxState.enabled then

                    if hitboxState.character then restoreHitbox() end

                    return

                end

                applyHitbox()
                focusOnHead()

            end

            hitboxState.status = HitboxBox:AddLabel("Hitbox : off")

            HitboxBox:AddToggle("COSHitboxExpand", {
                Text = "Extend Hitbox",
                Default = false,
                Callback = function(state)
                    hitboxState.enabled = state

                    if state then

                        applyHitbox()

                    else

                        restoreHitbox()

                    end
                end,
            })

            HitboxBox:AddSlider("COSHitboxSize", {
                Text = "Size",
                Min = 1,
                Max = 300,
                Default = 200,
                Rounding = 0,
                Callback = function(value)
                    hitboxState.size = value
                    applyHitbox()
                end,
            })

            HitboxBox:AddToggle("COSHitboxCamera", {
                Text = "Camera On Head",
                Default = true,
                Callback = function(state)
                    hitboxState.focusCamera = state

                    if not state and hitboxState.cameraSubject then

                        Camera.CameraSubject = hitboxState.cameraSubject
                        hitboxState.cameraSubject = nil

                    end
                end,
            })

            HitboxBox:AddButton("Reset", function()
                hitboxState.enabled = false
                restoreHitbox()
            end)

            -- the per frame re-apply. this is the part that makes it stick.
            hitboxState.rootConnection = RunService.Heartbeat:Connect(tickHitbox)

            -- independent teardown hook, invoked straight from the top of this
            -- file on the next run. it cannot be reached through the library
            -- Unload chain, because a throw anywhere in that body skips the
            -- rest of it and a surviving connection would pin the part at the
            -- expanded size for the rest of the session
            getgenv().__Testing.ForceRestore = function()

                if hitboxState.rootConnection then

                    hitboxState.rootConnection:Disconnect()
                    hitboxState.rootConnection = nil

                end

                pcall(restoreHitbox)

            end

            -- handle for driving and verifying the expander from outside the
            -- window, since the toggle's click target is buried in library
            -- internals and cannot be fired programmatically
            getgenv().TestingCOSHitbox = {
                state = hitboxState,
                apply = applyHitbox,
                restore = restoreHitbox,
                focus = focusOnHead,
                tick = tickHitbox,
            }

            --==========================================================
            -- STAT HOOK
            --
            -- Multipliers are read as "real value times this", and a slider
            -- sitting at its minimum of 1 installs no override at all, so the
            -- default state costs nothing and the game keeps reading its own
            -- numbers.
            --
            -- Everything here was kept only if something on the CLIENT
            -- actually reads it, and that bar is why the list is short.
            --
            -- Speed and FlySpeed are read by the ClientCharacter controller
            -- itself, at the sprint and flight setup, so they change how you
            -- actually move. CanSlowFallAtAge is read by the same controller
            -- in _getSoftLandingPower, so it changes how a fall is handled.
            -- Nightvision is only ever tested for truthiness and the lighting
            -- is rendered locally. No Ability Cooldown works on the replicated
            -- timestamps, which is the real gate, not the AbilityCooldown stat
            -- whose base is already 1.
            --
            -- The pool and the regen rate are separate levers and both are
            -- here. Stamina lives on the client: ClientCharacter builds
            -- p1.StaminaTracker itself and keeps LastSprintStaminaDrain,
            -- LastFlightStaminaDrain and LastSwimStaminaDrain on it, and
            -- Breath drives the tracker behind "if not self.IsLocal then
            -- return end".
            --
            -- The regen rate is the blunt one. With the real StaminaRegen of
            -- 5, a drain to 0 then read 0, 0, 0, 0, 0, 0 across 2.4s and
            -- never recovered; with the rate raised the same state refilled
            -- to 190 inside 0.25s and held 189, 188, 190, 190, 190, 189.
            -- GlideRegen rides the same path for the glide drain. Worth
            -- knowing that sprint drain is a separate tick, so an active
            -- sprint can still outpace the regen.
            --
            -- The pool raises the cap that StaminaTracker fills toward, and
            -- the current value climbs to meet it, so the effect settles in
            -- rather than applying instantly. Worth keeping in mind that the
            -- ability gates divide current by cap, GetStamina() against
            -- GetMaxStamina() / 4 for the 25% abilities and / 2 for the 50%
            -- ones, and that drains are also a fraction of the cap. Measured
            -- one second after a 3x, current read 195 against a cap of 570,
            -- so the ratio dips while the pool fills and the 50% abilities
            -- can be unavailable during that window.
            --
            -- Removed as decoration, having no client-side consumer:
            --
            --   Max Health    the HUD bar is the only thing reading it through
            --                 GetWithModifiers. Every other consumer uses the
            --                 raw Get, and real health is moved only by the
            --                 server via CharacterData:Set, which is what the
            --                 game's own admin CheatMenu calls. Scaling Health
            --                 alongside it kept the ratio intact, so all it
            --                 ever changed was the number on the bar.
            --   Damage Dealt  damage is computed in the server side module and
            --                 is never read by ClientCharacter.
            --   Hunger        the drain runs in WaterRegeneration.OnServerTick.
            --                 Appetite and ThirstAppetite are capacities, not
            --                 levels, so they were never the right lever.
            --
            -- Weight is the weakest of the survivors. It is read twice by
            -- ClientCharacter, but what those reads drive is unconfirmed, so
            -- treat it as display until proven otherwise.
            --==========================================================
            local StatBox = Tabs.GameMods:AddLeftGroupbox("Stat Hook")

            local hookStatus = StatBox:AddLabel("Hook : installing")

            StatBox:AddLabel("Multipliers. 1 leaves the value alone.")

            -- Widget ids are namespaced even though the stat names are not.
            -- This library persists configuration by id and restores it on
            -- load, and Speed, Weight, Stamina, MaxHealth, FlySpeed and
            -- DamageDealt are exactly the ids other menus use. Left bare, this
            -- groupbox silently inherited someone else's saved values and
            -- applied a 100x health and 20x weight multiplier that nobody
            -- asked for. The stat name stays the key in Stats.mult; only the
            -- widget id is prefixed.
            local function addMultiplier(stat, text, min, max, default)
                StatBox:AddSlider("COS_Stat_" .. stat, {
                    Text = text,
                    Min = min,
                    Max = max,
                    Default = default,
                    Rounding = 0,
                    Callback = function(value)
                        Stats.mult[stat] = value
                        recomputeOverrides()
                    end,
                })
            end

            addMultiplier("Weight", "Weight", 1, 20, 1)
            addMultiplier("Speed", "Speed", 1, 20, 1)
            addMultiplier("FlySpeed", "Fly Speed", 1, 20, 1)
            addMultiplier("Stamina", "Stamina", 1, 50, 1)

            StatBox:AddLabel("Toggles.")

            local function addFlag(flag, text)
                StatBox:AddToggle("COS_Stat_" .. flag, {
                    Text = text,
                    Default = false,
                    Callback = function(state)
                        Stats.flag[flag] = state or nil
                        recomputeOverrides()
                    end,
                })
            end

            addFlag("NoCooldown", "No Ability Cooldown")
            addFlag("NoStaminaDrain", "No Stamina Drain")
            addFlag("InfiniteGlide", "Infinite Glide Regen")
            addFlag("SlowFall", "Slow Fall At Any Age")
            addFlag("Nightvision", "Nightvision")

            StatBox:AddLabel("Real value is what the game reports.")

            local hookReadout = StatBox:AddLabel("Speed : —")

            StatBox:AddButton("Clear Overrides", function()
                -- The widgets are driven rather than just having the backing
                -- tables emptied. Clearing Stats.mult on its own left the
                -- sliders still reading their old multiplier, so the panel
                -- claimed an override that was no longer installed, and the
                -- next interaction with a slider would silently reinstate it.
                local options = getgenv().Options
                local toggles = getgenv().Toggles

                for _, stat in ipairs({ "Weight", "Speed", "FlySpeed", "Stamina" }) do
                    local widget = options and options["COS_Stat_" .. stat]

                    if widget then pcall(function() widget:SetValue(1) end) end
                end

                for _, flag in ipairs({ "NoCooldown", "NoStaminaDrain", "InfiniteGlide", "SlowFall", "Nightvision" }) do
                    local widget = toggles and toggles["COS_Stat_" .. flag]

                    if widget then pcall(function() widget:SetValue(false) end) end
                end

                Stats.mult = {}
                Stats.flag = {}
                recomputeOverrides()
            end)

            -- Only the writes that changed, so dragging a slider does not
            -- relayout the label 60 times a second
            local function setHookStatus(text)
                if Stats.lastHookStatus == text then return end
                Stats.lastHookStatus = text
                hookStatus:SetText(text)
            end

            local function updateStatHook()

                if not Stats.installed then
                    setHookStatus("Hook : unavailable in this build")
                    return
                end

                local instance = Stats.localData

                if not instance then
                    setHookStatus("Hook : waiting for character data")
                    hookReadout:SetText("Real value is what the game reports.")
                    return
                end

                setHookStatus(string.format(
                    "Hook : live   overrides : %d",
                    Stats.activeCount
                ))

                local parts = {}
                for _, stat in ipairs({ "Speed", "FlySpeed", "Weight", "Stamina" }) do
                    local real = readStat(instance, stat)

                    if real then
                        local shown = real
                        local override = Stats.overrides[stat]

                        if override then
                            shown = override
                            table.insert(parts, string.format(
                                "%s %d>%d",
                                stat,
                                math.floor(real + 0.5),
                                math.floor(shown + 0.5)
                            ))
                        else
                            table.insert(parts, string.format(
                                "%s %d",
                                stat,
                                math.floor(real + 0.5)
                            ))
                        end
                    end
                end

                local text = #parts > 0 and table.concat(parts, "   ") or "no stats read yet"

                if Stats.lastReadout ~= text then
                    Stats.lastReadout = text
                    hookReadout:SetText(text)
                end
            end

            --==========================================================
            -- SHARED MOVE HELPER
            --
            -- Every collector needs the same two things: glide to a point,
            -- and sleep without ignoring a cancel. They live here once for
            -- the newer loops, which is the point: the crystal loop grew its
            -- own inline copy of the glide and the shoom loop grew a
            -- different one, which is how the two drifted apart in the first
            -- place. The crystal loop still carries its original inline
            -- version because that is the copy that was verified end to end
            -- and the two are not interchangeable until it can be retested
            -- against a live server.
            --
            -- The glide is a smoothstep on os.clock rather than a
            -- TweenService tween. TweenService would need a connection
            -- handed to the Maid on every move and torn down again on every
            -- reload, and a tween can be stepped straight to its end state
            -- anyway, so the elapsed-time version is both cheaper and
            -- cancellable mid flight. isRunning is passed in rather than
            -- read from a registry so this stays independent of whichever
            -- collector is calling it.
            --==========================================================
            local Move = getgenv().__Testing.Move or {}

            getgenv().__Testing.Move = Move

            function Move.glide(character, isRunning, goal, duration)
                local root = character:FindFirstChild("HumanoidRootPart")

                if not root then return false end

                if duration and duration <= 0 then
                    character:PivotTo(CFrame.new(goal))
                    return true
                end

                local start = root.CFrame
                local finish = CFrame.new(goal)
                local began = os.clock()

                while isRunning() do
                    local alpha = (os.clock() - began) / (duration or 0.6)

                    if alpha >= 1 then
                        character:PivotTo(finish)
                        return true
                    end

                    -- smoothstep, so it eases in and out rather than sliding
                    -- at a constant rate the whole way
                    local eased = alpha * alpha * (3 - 2 * alpha)

                    character:PivotTo(start:Lerp(finish, eased))
                    task.wait(0.05)
                end

                return false
            end

            -- Cancellable sleep. A plain task.wait would keep a collector
            -- alive for up to its delay after the toggle went off, and since
            -- the next thing it does is move the character, that is visible.
            function Move.wait(isRunning, seconds)
                local deadline = os.clock() + seconds

                while isRunning() and os.clock() < deadline do
                    task.wait(0.1)
                end
            end

            --==========================================================
            -- REGION TRAVEL
            --
            -- Regions storage carries a RegionCenterPosition per region, and
            -- the region list itself is the set of folders under
            -- PlayerData.Missions.RegionMissions, which is 19 entries and
            -- always present once the data lands. Teleporting has already
            -- been shown to be acceptable to the server twice over, since
            -- both the shoom and crystal collects succeed after a glide, so
            -- this needs nothing new server side.
            --
            -- This is the enabler for the multi region shoom sweep below. It
            -- also stands on its own, because the region's own name is not
            -- otherwise reachable from the panel.
            --==========================================================
            local RegionBox = Tabs.GameMods:AddRightGroupbox("Region Travel")

            local regionStatus = RegionBox:AddLabel("Region : —")

            local regionList = {
                "Jungle", "Central Rockfaces", "Swamp Hill", "Desert",
                "Grassy Shoal", "Rocky Drop", "Mountains", "Seaweed Depths",
                "Forgotten Shores", "Shadow Isle", "Coral Reef", "Flower Cove",
                "Redwoods", "Pride Rocks", "Algae Sandbar", "Tundra", "Mesa",
                "Volcano Island", "Basalt Cave",
            }

            -- Read straight from the Regions storage when it is there, so the
            -- dropdown lists exactly the regions that can actually be
            -- travelled to rather than a hand kept copy that drifts. Falls
            -- back to the mission tree, then to the static list.
            do
                local discovered = {}
                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))

                if okSonar then
                    local okStorage, StorageUtils = pcall(Sonar, "StorageUtils")

                    if okStorage then
                        local okRegions, Regions = pcall(StorageUtils.Get, "Regions")

                        if okRegions and Regions then
                            -- Main and Aquatic can each hold a model with the
                            -- same name, Central Rockfaces being one, so this
                            -- goes through a seen set. Concatenating the two
                            -- folders listed that region twice and a dropdown
                            -- with a duplicate entry cannot be set cleanly.
                            local seen = {}

                            for _, section in ipairs({ "Main", "Aquatic" }) do
                                local folder = Regions:FindFirstChild(section)

                                if folder then
                                    for _, model in ipairs(folder:GetChildren()) do
                                        if model:IsA("Model") and not seen[model.Name] then
                                            seen[model.Name] = true
                                            table.insert(discovered, model.Name)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if #discovered == 0 then
                    local okWrapper, wrapper = pcall(function()
                        return Sonar("PlayerWrapper").GetClient()
                    end)

                    if okWrapper and wrapper and wrapper.PlayerData then
                        local missions = wrapper.PlayerData.Missions
                        local regionFolder = missions and missions:FindFirstChild("RegionMissions")

                        if regionFolder then
                            for _, child in ipairs(regionFolder:GetChildren()) do
                                if child:IsA("Folder") then table.insert(discovered, child.Name) end
                            end
                        end
                    end
                end

                if #discovered > 0 then
                    table.sort(discovered)
                    regionList = discovered
                end
            end

            local Travel = getgenv().__Testing.Travel or {}

            getgenv().__Testing.Travel = Travel

            Travel.tween = 0.8
            Travel.busy = false

            -- The region centre comes from the model the Regions storage
            -- holds, not from a data table. StorageUtils.Get("Regions")
            -- returns a ModuleScript whose children are Main, Aquatic and
            -- Hardcore folders, and Main holds one Model per region, 17 of
            -- them. Calling Get("Regions")() is a mistake and raises "attempt
            -- to call a Instance value", which is what made the first version
            -- of this report that every region had no centre.
            --
            -- The pivot is a usable target but the Y is the model's own origin
            -- and sits well below the surface for land regions, Jungle
            -- measuring y = -545. Dropping the character there would put it
            -- inside the terrain, so the target is lifted well clear and the
            -- character falls the rest of the way under its own physics.
            local function regionCenter(name)
                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))

                if not okSonar then return nil end

                local okStorage, StorageUtils = pcall(Sonar, "StorageUtils")

                if not okStorage then return nil end

                local okRegions, Regions = pcall(StorageUtils.Get, "Regions")

                if not okRegions or not Regions then return nil end

                local main = Regions:FindFirstChild("Main") or Regions:FindFirstChild("Aquatic")

                if not main then return nil end

                local model = main:FindFirstChild(name)

                if not model then return nil end

                local ok, pivot = pcall(function()
                    return model:GetPivot()
                end)

                if not ok or not pivot then return nil end

                return pivot.Position
            end

            RegionBox:AddDropdown("COS_Region_Pick", {
                Text = "Destination",
                Values = regionList,
                Default = regionList[1],
                Callback = function(value)
                    Travel.picked = value
                end,
            })

            RegionBox:AddSlider("COS_Region_Tween", {
                Text = "Glide Seconds",
                Min = 0,
                Max = 4,
                Default = 0.8,
                Rounding = 2,
                Callback = function(value)
                    Travel.tween = value
                end,
            })

            RegionBox:AddButton("Travel", function()
                if Travel.busy then return end

                local name = Travel.picked or regionList[1]
                local center = regionCenter(name)

                if not center then
                    regionStatus:SetText("Region : no centre for " .. tostring(name))
                    return
                end

                local character = game:GetService("Players").LocalPlayer.Character

                if not character then
                    regionStatus:SetText("Region : waiting for character")
                    return
                end

                Travel.busy = true
                regionStatus:SetText("Region : travelling to " .. name)

                task.spawn(function()
                    -- Land the character above the region and let its own
                    -- physics take it down, rather than teleporting to a
                    -- pivot that can be hundreds of studs under the floor.
                    Move.glide(character, function()
                        return Travel.busy
                    end, center + Vector3.new(0, 120, 0), Travel.tween)

                    Travel.busy = false
                    regionStatus:SetText("Region : " .. name)
                end)
            end)

            --==========================================================
            -- TOKENS
            --
            -- Two token systems, both shaped like the collectors that work.
            --
            --   Explorer Gacha tokens   tag "Token", the five variants out
            --                           of TokenCapsules, claimed with
            --                           GetSpawnedTokenRemote:InvokeServer()
            --                           and no arguments at all. The server
            --                           decides from its own spawn state,
            --                           so there is no CanCollect gate to
            --                           consult and no way to ask first.
            --   Spring Meadows tokens   tag "SpringMeadowsToken", claimed
            --                           with
            --                           ClaimSpringMeadowsTokenRemote:InvokeServer(name)
            --
            -- Both are one-at-a-time spawns that refresh on their own
            -- timers, so this waits for a spawn, glides to it and claims it
            -- before the next one replaces it. Explorer tokens are the ones
            -- worth running: the timed mission wants ten of them.
            --
            -- Verified on a GalaxyExplorerGachaToken 2679 studs out. The
            -- invoke returned true and the item count for that token went
            -- up, and the tag stayed populated because the next spawn
            -- arrived immediately, which is the refresh loop doing its job.
            --==========================================================
            local TokenBox = Tabs.GameMods:AddRightGroupbox("Tokens")

            local tokenStatus = TokenBox:AddLabel("Tokens : off")
            local tokenCount = TokenBox:AddLabel("Spawned : —")

            local Token = getgenv().__Testing.Token or {}

            getgenv().__Testing.Token = Token

            Token.running = false
            Token.teleport = true
            Token.tween = 0.7
            Token.delay = 1
            Token.collected = 0
            Token.inFlight = nil
            Token.deps = nil
            Token.stop = function()
                Token.running = false
            end

            local function setTokenStatus(text)
                if Token.lastStatus == text then return end
                Token.lastStatus = text
                tokenStatus:SetText(text)
            end

            local function setTokenCount(text)
                if Token.lastCount == text then return end
                Token.lastCount = text
                tokenCount:SetText(text)
            end

            -- GetRemoteFunction can yield forever when the named remote does
            -- not exist, which is exactly what it does for a seasonal event
            -- that is not running. A pcall cannot catch a yield, so a plain
            -- pcall here does not merely fail, it hangs the whole loop with
            -- the status still reading "starting". Measured:
            -- ClaimSpringMeadowsTokenRemote blocked indefinitely while
            -- GetSpawnedTokenRemote, CompletePartialMissionRemote,
            -- Lore2026CollectRecollection and ShoomPileCollected all
            -- resolved immediately.
            --
            -- So every optional remote is resolved on its own thread and given
            -- a deadline. Missing means absent, not fatal.
            local function probeRemote(getter, label)
                local done = false
                local result

                task.spawn(function()
                    local ok, value = pcall(getter)
                    result = (ok and value) or nil
                    done = true
                end)

                local deadline = os.clock() + 2

                while not done and os.clock() < deadline do
                    task.wait(0.05)
                end

                if not done then
                    if Token.deps then
                        Token.deps.missing = Token.deps.missing or {}
                        table.insert(Token.deps.missing, label)
                    end

                    return nil
                end

                return result
            end

            local function tokenDeps()
                if Token.deps then return Token.deps end

                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))

                if not okSonar then return nil end

                local okRemotes, RemoteUtils = pcall(Sonar, "RemoteUtils")

                if not okRemotes then return nil end

                -- Only the gacha capsule is required. Spring Meadows is a
                -- seasonal event, so its remote is treated as optional and
                -- the loop runs without it when it is not there.
                local gacha = probeRemote(function()
                    return RemoteUtils.GetRemoteFunction("GetSpawnedTokenRemote")
                end, "spring")

                if not gacha then return nil end

                local spring = probeRemote(function()
                    return RemoteUtils.GetRemoteFunction("ClaimSpringMeadowsTokenRemote")
                end, "spring")

                Token.deps = { Gacha = gacha, Spring = spring, missing = {} }

                return Token.deps
            end

            local function tokenTick()
                local deps = tokenDeps()

                if not deps then
                    setTokenStatus("Tokens : remotes unavailable")
                    return
                end

                local character = game:GetService("Players").LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")

                if not root then
                    setTokenStatus("Tokens : waiting for character")
                    return
                end

                local collection = game:GetService("CollectionService")

                -- Explorer tokens are the priority, so they are collected
                -- first. Spring Meadows only counts when its remote resolved,
                -- since without it the tag can be seen but not claimed.
                local gacha = collection:GetTagged("Token")
                local spring = deps.Spring and collection:GetTagged("SpringMeadowsToken") or {}

                setTokenCount(string.format("Spawned : %d gacha, %d spring", #gacha, #spring))

                if #gacha == 0 and #spring == 0 then
                    setTokenStatus("Tokens : waiting for a spawn")
                    return
                end

                if Token.inFlight then return end

                local instance, remote, name

                if #gacha > 0 then
                    instance = gacha[1]
                    remote = deps.Gacha
                else
                    instance = spring[1]
                    remote = deps.Spring
                    -- The spring remote is keyed by the token's own name.
                    name = instance.Name
                end

                if not instance or not remote then return end

                local key = name or instance.Name

                -- A token the server has already turned down stays tagged
                -- until the refresh timer replaces it, so without this the
                -- loop re-asks the same dead capsule on every single tick.
                if Token.declined and Token.declined[key] and Token.declined[key] > os.clock() then
                    setTokenStatus("Tokens : waiting on " .. key)
                    return
                end

                if Token.teleport then
                    Move.glide(character, function()
                        return Token.running
                    end, instance:GetPivot().Position + Vector3.new(0, 3, 0), Token.tween)

                    if not Token.running then return end

                    -- No gate to consult for the gacha capsule, and the
                    -- spring one is gated only by distance, so a short
                    -- settle is the only wait that buys anything.
                    Move.wait(function()
                        return Token.running
                    end, 0.5)

                    if not Token.running then return end
                end

                Token.inFlight = true

                task.spawn(function()
                    local okInvoke, result = pcall(function()
                        if name then
                            return remote:InvokeServer(name)
                        end

                        return remote:InvokeServer()
                    end)

                    Token.inFlight = nil

                    if not Token.running then return end

                    if not okInvoke then
                        -- A Luau error means this script handed the remote
                        -- something it would not take, which is a different
                        -- problem from the server declining and must not be
                        -- reported as a decline.
                        local detail = tostring(result):gsub("^.*:%d+: ", "")
                        Token.blocked = "error: " .. detail
                        setTokenStatus("Tokens : " .. Token.blocked)
                        return
                    end

                    if result then
                        Token.collected = Token.collected + 1
                        Token.declined = nil
                        setTokenStatus("Tokens : claimed " .. key)
                        return
                    end

                    -- The server returning nothing is a decline, which is the
                    -- normal answer while a capsule sits between spawns.
                    -- Reporting that as an error was wrong, and it buried the
                    -- real behaviour behind "error: nil".
                    Token.declined = Token.declined or {}
                    Token.declined[key] = os.clock() + 6
                    setTokenStatus("Tokens : server declined " .. key)
                end)

                setTokenStatus("Tokens : claiming " .. key)
            end

            local function tokenLoop()
                while Token.running do
                    pcall(tokenTick)

                    if not Token.running then break end

                    Move.wait(function()
                        return Token.running
                    end, Token.delay)
                end

                setTokenStatus("Tokens : off")
            end

            TokenBox:AddToggle("COS_Token_Auto", {
                Text = "Auto Collect",
                Default = false,
                Callback = function(state)
                    Token.running = state or nil

                    if not Token.running then
                        setTokenStatus("Tokens : off")
                        return
                    end

                    setTokenStatus("Tokens : starting")
                    task.spawn(tokenLoop)
                end,
            })

            TokenBox:AddToggle("COS_Token_Teleport", {
                Text = "Teleport To Token",
                Default = true,
                Callback = function(state)
                    Token.teleport = state or false
                end,
            })

            TokenBox:AddSlider("COS_Token_Tween", {
                Text = "Glide Seconds",
                Min = 0,
                Max = 3,
                Default = 0.7,
                Rounding = 2,
                Callback = function(value)
                    Token.tween = value
                end,
            })

            --==========================================================
            -- TRINKETS
            --
            -- Disaster trinkets are the third of the collectible family and
            -- follow the same shape, with one difference worth recording: the
            -- models are not named after their nodes. The clone is a generic
            -- TrinketModel parented to SpawnedTrinketModels and the identity
            -- lives on the spawn value, which is a BoolValue sitting in a
            -- folder called SpawnedTrinkets directly under the local player.
            -- Its Name is the node id the remote wants and its P attribute is
            -- the position, so the models can be ignored entirely and the
            -- spawn values read directly. That is both simpler and immune to
            -- the model and the value disagreeing.
            --
            -- This one is dormant right now: TrinketsService is not an active
            -- minigame this season, and asking Sonar for the module errors
            -- out because the game itself never instantiated it. So the
            -- service and the remote are both resolved inside a pcall and the
            -- loop reports that it is unavailable instead of throwing. If
            -- trinkets go live the same loop starts working with no change.
            --
            -- CanCollect answers true or a reason string, and the max
            -- activation distance the client uses is 50.
            --==========================================================
            local TrinketBox = Tabs.GameMods:AddRightGroupbox("Trinkets")

            local trinketStatus = TrinketBox:AddLabel("Trinkets : off")
            local trinketCount = TrinketBox:AddLabel("Spawned : —")

            local Trinket = getgenv().__Testing.Trinket or {}

            getgenv().__Testing.Trinket = Trinket

            Trinket.running = false
            Trinket.teleport = true
            Trinket.tween = 0.7
            Trinket.delay = 1.5
            Trinket.collected = 0
            Trinket.inFlight = nil
            Trinket.deps = nil
            Trinket.unavailable = false
            Trinket.stop = function()
                Trinket.running = false
            end

            local function setTrinketStatus(text)
                if Trinket.lastStatus == text then return end
                Trinket.lastStatus = text
                trinketStatus:SetText(text)
            end

            local function setTrinketCount(text)
                if Trinket.lastCount == text then return end
                Trinket.lastCount = text
                trinketCount:SetText(text)
            end

            local function trinketDeps()
                if Trinket.unavailable then return nil end
                if Trinket.deps then return Trinket.deps end

                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))

                if not okSonar then
                    Trinket.unavailable = true
                    return nil
                end

                -- The service only exists while the minigame is live, so this
                -- is allowed to fail and that is not an error condition.
                local okService, Service = pcall(Sonar, "TrinketsService")

                if not okService then
                    Trinket.unavailable = true
                    return nil
                end

                local okRemote, Remote = pcall(function()
                    return Sonar("RemoteUtils").GetRemoteEvent("TrinketCollectRemote")
                end)

                -- Same hazard as the spring token remote: a seasonal remote
                -- that does not exist can leave this call yielding, and a
                -- pcall will not catch a yield. Probed on its own thread with
                -- a deadline so an out of season trinket reports unavailable
                -- rather than freezing the loop.
                if not okRemote or not Remote then
                    Trinket.unavailable = true
                    return nil
                end

                local done = false
                local resolved

                task.spawn(function()
                    resolved = Remote
                    done = true
                end)

                -- RemoteEvent lookups are synchronous in practice, so this is
                -- a short settle rather than a real timeout.
                Move.wait(function()
                    return not done
                end, 0.5)

                if not done then
                    Trinket.unavailable = true
                    return nil
                end

                Trinket.deps = { Service = Service, Remote = resolved }

                return Trinket.deps
            end

            local function trinketTick()
                local deps = trinketDeps()

                if not deps then
                    setTrinketStatus("Trinkets : not an active minigame")
                    return
                end

                local character = game:GetService("Players").LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")

                if not root then
                    setTrinketStatus("Trinkets : waiting for character")
                    return
                end

                local folder = game:GetService("Players").LocalPlayer:FindFirstChild("SpawnedTrinkets")

                if not folder then
                    setTrinketCount("Spawned : 0")
                    setTrinketStatus("Trinkets : none spawned")
                    return
                end

                -- The spawn values are the truth here, not the models.
                local candidates = {}

                for _, value in ipairs(folder:GetChildren()) do
                    if value:IsA("BoolValue") and value.Value then
                        local position = value:GetAttribute("P")

                        if typeof(position) == "Vector3" then
                            local okVerdict, verdict = pcall(deps.Service.CanCollect, game:GetService("Players").LocalPlayer, value.Name)

                            if okVerdict and verdict == true then
                                table.insert(candidates, {
                                    name = value.Name,
                                    position = position,
                                    distance = (position - root.Position).Magnitude,
                                })
                            end
                        end
                    end
                end

                setTrinketCount(string.format("Spawned : %d", #candidates))

                if #candidates == 0 then
                    setTrinketStatus("Trinkets : nothing available")
                    return
                end

                table.sort(candidates, function(a, b)
                    return a.distance < b.distance
                end)

                local chosen = candidates[1]

                -- Skip one the server already turned down while it waits to
                -- despawn, rather than re-asking it every tick.
                if Trinket.declined and Trinket.declined[chosen.name] and Trinket.declined[chosen.name] > os.clock() then
                    setTrinketStatus("Trinkets : waiting on " .. chosen.name)
                    return
                end

                if Trinket.teleport then
                    Move.glide(character, function()
                        return Trinket.running
                    end, chosen.position + Vector3.new(0, 3, 0), Trinket.tween)

                    if not Trinket.running then return end

                    Move.wait(function()
                        return Trinket.running
                    end, 0.4)

                    if not Trinket.running then return end
                end

                local okVerdict, verdict = pcall(deps.Service.CanCollect, game:GetService("Players").LocalPlayer, chosen.name)

                if not okVerdict or verdict ~= true then
                    setTrinketStatus("Trinkets : " .. (type(verdict) == "string" and verdict or "unavailable"))
                    return
                end

                if Trinket.inFlight then return end

                Trinket.inFlight = true

                task.spawn(function()
                    local okInvoke, result = pcall(function()
                        return deps.Remote:InvokeServer(chosen.name)
                    end)

                    Trinket.inFlight = nil

                    if not Trinket.running then return end

                    if not okInvoke then
                        local detail = tostring(result):gsub("^.*:%d+: ", "")
                        setTrinketStatus("Trinkets : error: " .. detail)
                        return
                    end

                    if result then
                        Trinket.collected = Trinket.collected + 1
                        setTrinketStatus("Trinkets : took " .. chosen.name)
                    else
                        -- A decline, not an error. The trinket stays spawned
                        -- until it despawns, so back off rather than asking
                        -- again on the next tick.
                        Trinket.declined = Trinket.declined or {}
                        Trinket.declined[chosen.name] = os.clock() + 6
                        setTrinketStatus("Trinkets : server declined " .. chosen.name)
                    end
                end)

                setTrinketStatus("Trinkets : taking " .. chosen.name)
            end

            local function trinketLoop()
                while Trinket.running do
                    pcall(trinketTick)

                    if not Trinket.running then break end

                    Move.wait(function()
                        return Trinket.running
                    end, Trinket.delay)
                end

                setTrinketStatus("Trinkets : off")
            end

            TrinketBox:AddToggle("COS_Trinket_Auto", {
                Text = "Auto Collect",
                Default = false,
                Callback = function(state)
                    Trinket.running = state or nil

                    if not Trinket.running then
                        setTrinketStatus("Trinkets : off")
                        return
                    end

                    setTrinketStatus("Trinkets : starting")
                    task.spawn(trinketLoop)
                end,
            })

            TrinketBox:AddToggle("COS_Trinket_Teleport", {
                Text = "Teleport To Trinket",
                Default = true,
                Callback = function(state)
                    Trinket.teleport = state or false
                end,
            })

            --==========================================================
            -- SHOOM PILES
            --
            -- "Search N shoom piles" is the one piece of daily progression
            -- the client can genuinely move, and it moves it for real.
            -- ShoomPile.new builds a ProximityMenu whose Collect action
            -- asks ShoomPilesService.CanCollect first and only then calls
            -- the ShoomPileCollected RemoteFunction with Region, Id and
            -- IsEvent, so that is the whole of the pickup.
            --
            -- CanCollect is the entire gate and it answers true or a
            -- reason: TooFar, WrongRegion, RegionInactive, ShoomCollected,
            -- NotSpawned, DoesNotExist, MustOwnSpecies. MaxDistanceToCollect
            -- is 100 studs and the nearest live pile measured 677 away, so
            -- standing still there is nothing to collect at all. Teleporting
            -- is therefore the default and not a convenience.
            --
            -- Verified end to end on Grassy Shoal 6: teleported onto the
            -- pivot, CanCollect returned true, InvokeServer returned true,
            -- the pile hid itself, Collected.Value went true and the
            -- region's ShoomPilesCollected mission moved to 1 of 3. That is
            -- the server writing the value, not a local display change.
            --
            -- The wider mission tree is not reachable this way, and this
            -- groupbox does not pretend otherwise. MissionsService has an
            -- IncrementClientMission that is explicitly the client's entry
            -- point and it does fire SetMissionRemote, but 37 fires across
            -- all seven objective names, repeated over several rounds and
            -- including the player's own current region, left the entire
            -- tree byte for byte unchanged, so the server validates and
            -- discards. Progress stays server held.
            --==========================================================
            local ShoomBox = Tabs.GameMods:AddRightGroupbox("Shoom Piles")

            local shoomStatus = ShoomBox:AddLabel("Shooms : off")
            local shoomCount = ShoomBox:AddLabel("Piles : —")
            local shoomMission = ShoomBox:AddLabel("Mission : —")

            local Shoom = getgenv().__Testing.Shoom or {}

            getgenv().__Testing.Shoom = Shoom

            Shoom.running = false
            Shoom.teleport = true
            Shoom.tween = 0.6
            Shoom.delay = 1.2
            Shoom.collected = 0
            Shoom.blocked = nil
            Shoom.inFlight = nil
            Shoom.deps = nil
            Shoom.regions = {}
            Shoom.onlyRegion = nil
            Shoom.currentRegion = nil
            Shoom.stop = function()
                Shoom.running = false
            end

            -- Cancellable sleep. A plain task.wait here would keep the loop
            -- alive for up to the delay after the toggle went off, and since
            -- the next thing it does is move the character, that is visible.
            local function shoomWait(seconds)
                local deadline = os.clock() + seconds

                while Shoom.running and os.clock() < deadline do
                    task.wait(0.1)
                end
            end

            local function setShoomStatus(text)
                if Shoom.lastStatus == text then return end
                Shoom.lastStatus = text
                shoomStatus:SetText(text)
            end

            local function setShoomCount(text)
                if Shoom.lastCount == text then return end
                Shoom.lastCount = text
                shoomCount:SetText(text)
            end

            local function setShoomMission(text)
                if Shoom.lastMission == text then return end
                Shoom.lastMission = text
                shoomMission:SetText(text)
            end

            -- Resolved once and cached, because Sonar lookups and the remote
            -- handle are not free and this runs on a loop.
            local function shoomDeps()
                if Shoom.deps then return Shoom.deps end

                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))

                if not okSonar then return nil end

                local okPile, Pile = pcall(Sonar, "ShoomPile")
                local okService, Service = pcall(Sonar, "ShoomPilesService")
                local okRemotes, RemoteUtils = pcall(Sonar, "RemoteUtils")
                local okConstants, Constants = pcall(Sonar, "Constants")

                if not (okPile and okService and okRemotes and okConstants) then return nil end

                -- GetRemoteFunction takes its arguments as plain values, not
                -- as a method on RemoteUtils. Handing it the module table
                -- fails with "invalid argument #2 (string expected, got
                -- table)", which is what made the whole groupbox report
                -- itself unavailable.
                local okRemote, Remote = pcall(function()
                    return RemoteUtils.GetRemoteFunction("ShoomPileCollected")
                end)

                if not okRemote or not Remote then return nil end

                local constants = Constants.ShoomPileConstants or {}

                Shoom.deps = {
                    Pile = Pile,
                    Service = Service,
                    Remote = Remote,
                    MaxDistance = constants.MaxDistanceToCollect or 100,
                }

                return Shoom.deps
            end

            -- What the region mission for wherever the player is standing
            -- currently reads. Straight off the replicated value, so it is
            -- the server's number and not a tally kept by this script.
            local function readMissionProgress()
                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))

                if not okSonar then return nil end

                local okTracker, MinimapTracker = pcall(Sonar, "MinimapTracker")

                if not okTracker then return nil end

                local okRegion, region = pcall(MinimapTracker.GetCurrentRegion)

                if not okRegion or not region then return nil end

                local okWrapper, wrapper = pcall(function()
                    return Sonar("PlayerWrapper").GetClient()
                end)

                if not okWrapper or not wrapper then return nil end

                local missions = wrapper.PlayerData and wrapper.PlayerData.Missions

                if not missions then return nil end

                local regionFolder = missions:FindFirstChild("RegionMissions")

                if not regionFolder then return nil end

                local regionMission = regionFolder:FindFirstChild(region)

                if not regionMission then return nil end

                local value = regionMission:FindFirstChild("ShoomPilesCollected")

                if not value then return nil end

                local amount = value:FindFirstChild("Amount")
                local target = value:FindFirstChild("TargetAmount")

                return region, amount and amount.Value or 0, target and target.Value or 0
            end

            local function shoomTick()
                local deps = shoomDeps()

                if not deps then
                    setShoomStatus("Shooms : unavailable in this build")
                    return
                end

                local player = game:GetService("Players").LocalPlayer
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")

                if not root then
                    setShoomStatus("Shooms : waiting for character")
                    return
                end

                local region, amount, target = readMissionProgress()

                if region then
                    setShoomMission(string.format("Mission : %s %d/%d", region, amount, target))
                end

                -- Every pile the client currently knows about. The registry
                -- only holds spawned ones, and a pile hides itself once it
                -- is collected or once its region mission fills, so hidden
                -- is the game's own answer to "is there anything left here".
                local candidates = {}
                local total = 0

                for instance, pile in pairs(deps.Pile.ALL_SHOOM_PILES) do
                    total = total + 1

                    if not pile:IsHidden() then
                        local ok, pivot = pcall(function()
                            return instance:GetPivot()
                        end)

                        if ok and pivot then
                            table.insert(candidates, {
                                pile = pile,
                                pivot = pivot,
                                region = pile.Region,
                                id = pile.Id,
                                isEvent = pile.IsEvent,
                                distance = (pivot.Position - root.Position).Magnitude,
                            })
                        end
                    end
                end

                if total == 0 then
                    setShoomCount("Piles : none spawned today")
                    setShoomStatus("Shooms : nothing to collect")
                    Shoom.blocked = nil
                    return
                end

                if #candidates == 0 then
                    setShoomCount(string.format("Piles : %d/%d taken", total, total))
                    setShoomStatus("Shooms : all collected")
                    Shoom.blocked = nil
                    return
                end

                setShoomCount(string.format("Piles : %d of %d left", #candidates, total))

                -- Region filter. An empty selection sweeps everything, which
                -- is the old nearest-pile behaviour. A populated selection
                -- restricts collection to those regions, and a single choice
                -- is also stored on onlyRegion so a one-region run reads
                -- clearly on the status line.
                local wanted = Shoom.regions

                if wanted and #wanted > 0 then
                    local allowed = {}

                    for _, name in ipairs(wanted) do
                        allowed[name] = true
                    end

                    local filtered = {}

                    for _, candidate in ipairs(candidates) do
                        if allowed[candidate.region] then
                            table.insert(filtered, candidate)
                        end
                    end

                    candidates = filtered
                end

                if #candidates == 0 then
                    setShoomStatus("Shooms : nothing in the selected regions")
                    return
                end

                table.sort(candidates, function(a, b)
                    return a.distance < b.distance
                end)

                -- Nearest first, but a pile we are already in range of beats
                -- one that is merely closer on paper, and a blocked pile is
                -- skipped rather than retried forever.
                local target2 = candidates[1]

                for _, candidate in ipairs(candidates) do
                    if candidate.distance <= deps.MaxDistance * 0.5 then
                        target2 = candidate
                        break
                    end
                end

                -- Mark the region this pile belongs to so the sweep can walk
                -- through the active regions in turn rather than ping
                -- ponging between whichever happens to be nearest.
                Shoom.currentRegion = target2.region

                if Shoom.teleport and target2.distance > deps.MaxDistance * 0.5 then
                    Move.glide(character, function()
                        return Shoom.running
                    end, target2.pivot.Position + Vector3.new(0, 2, 0), Shoom.tween)

                    -- The server derives the region from position, so it needs
                    -- a moment to agree with us before CanCollect will say yes.
                    shoomWait(1.2)

                    if not Shoom.running then return end

                    root = character:FindFirstChild("HumanoidRootPart")

                    if not root then
                        setShoomStatus("Shooms : waiting for character")
                        return
                    end
                end

                local okVerdict, verdict = pcall(deps.Service.CanCollect, player, target2.region, target2.id, target2.isEvent)

                if not okVerdict or verdict ~= true then
                    -- CanCollect hands back the key of the reason table, and
                    -- TooFar here means our own teleport did not land.
                    Shoom.blocked = type(verdict) == "string" and verdict or "unavailable"
                    setShoomStatus("Shooms : " .. Shoom.blocked)
                    return
                end

                -- InvokeServer yields until the server answers, and a handler
                -- that throws without returning leaves it waiting forever.
                -- Doing it on its own thread behind an in flight flag means a
                -- wedged call can stall the collection, but it can never
                -- stall the loop or let the same pile be fired twice.
                if Shoom.inFlight then return end

                Shoom.inFlight = true

                task.spawn(function()
                    local okInvoke, result = pcall(function()
                        return deps.Remote:InvokeServer(target2.region, target2.id, target2.isEvent)
                    end)

                    Shoom.inFlight = nil

                    if not Shoom.running then return end

                    if okInvoke and result then
                        Shoom.collected = Shoom.collected + 1
                        Shoom.blocked = nil
                        setShoomStatus(string.format("Shooms : took pile %d in %s", target2.id, target2.region))
                    else
                        Shoom.blocked = "server refused"
                        setShoomStatus("Shooms : server refused")
                    end
                end)

                setShoomStatus(string.format("Shooms : taking pile %d in %s", target2.id, target2.region))
            end

            local function shoomLoop()
                while Shoom.running do
                    pcall(shoomTick)

                    if not Shoom.running then break end

                    shoomWait(Shoom.delay)
                end

                setShoomStatus("Shooms : off")
            end

            ShoomBox:AddToggle("COS_Shoom_Auto", {
                Text = "Auto Collect",
                Default = false,
                Callback = function(state)
                    Shoom.running = state or nil

                    if not Shoom.running then
                        setShoomStatus("Shooms : off")
                        return
                    end

                    setShoomStatus("Shooms : starting")
                    task.spawn(shoomLoop)
                end,
            })

            ShoomBox:AddToggle("COS_Shoom_Teleport", {
                Text = "Teleport To Pile",
                Default = true,
                Callback = function(state)
                    Shoom.teleport = state or false
                end,
            })

            -- Multi region sweep. Only about half the regions spawn piles on
            -- any given day and the region missions are per region, so
            -- visiting every active region in turn is what turns one region
            -- mission a day into several. The dropdown is multi select, so
            -- pick the regions to sweep. "All Regions" means no filter, which
            -- is the default and matches the old nearest-pile behaviour.
            ShoomBox:AddDropdown("COS_Shoom_Regions", {
                Text = "Sweep Regions",
                Values = (function()
                    local names = { "All Regions" }

                    for _, name in ipairs(regionList) do
                        table.insert(names, name)
                    end

                    return names
                end)(),
                Default = "All Regions",
                Multi = true,
                Callback = function(value)
                    local selected = {}

                    for name, on in pairs(value or {}) do
                        if on and name ~= "All Regions" then
                            table.insert(selected, name)
                        end
                    end

                    table.sort(selected)
                    Shoom.regions = selected
                    Shoom.onlyRegion = #selected == 1 and selected[1] or nil
                end,
            })

            ShoomBox:AddSlider("COS_Shoom_Tween", {
                Text = "Glide Seconds",
                Min = 0,
                Max = 3,
                Default = 0.6,
                Rounding = 2,
                Callback = function(value)
                    Shoom.tween = value
                end,
            })

            ShoomBox:AddSlider("COS_Shoom_Delay", {
                Text = "Seconds Between",
                Min = 0.4,
                Max = 5,
                Default = 1.2,
                -- Rounding is asserted by this library and there is no
                -- Increment field, so one decimal place is how the slider
                -- gets its fractions.
                Rounding = 1,
                Callback = function(value)
                    Shoom.delay = value
                end,
            })

            ShoomBox:AddButton("Reset Counter", function()
                Shoom.collected = 0
                setShoomStatus("Shooms : counter reset")
            end)

            --==========================================================
            -- MEMORY CRYSTALS
            --
            -- The Lore2026 event drops Memory Crystals around the map and
            -- they are the same shape as shoom piles: a CollectionService
            -- tag, a client gate, and a RemoteFunction the game expects the
            -- client to call once the gate says yes.
            --
            --   tag       Lore2026MemoryCrystal, on the spawned models
            --   gate      Lore2026RecollectionService.CanCollect(
            --               player, "Sotharkuz", nodeId)
            --   node id   the crystal's own Name, which is the spawn slot's
            --             id and is the same string the gate is handed
            --   remote    Lore2026CollectRecollection:InvokeServer(
            --               "Sotharkuz", nodeId)
            --
            -- The gate answers true or a reason table whose first entry is
            -- one of Locked, NotSpawned, TooFar or AlreadyCollected, and
            -- GetMaxCollectDistance is 80. Every crystal measured 800 to
            -- 3500 studs away, so all of them come back TooFar until we are
            -- standing on one, which makes the teleport the whole mechanism
            -- rather than a convenience.
            --
            -- That is also the first mistake here, worth keeping written
            -- down: choosing which crystal to go to by asking the gate
            -- first can never select anything, because the gate measures
            -- distance and every candidate is out of range. The loop sat on
            -- "Crystals : TooFar" with a collectible crystal 800 studs away
            -- and never once moved. The fix is to pick by distance and treat
            -- the gate as a post-move check, skipping only the reasons that
            -- moving cannot fix, which are AlreadyCollected, NotSpawned and
            -- Locked. TooFar is not a reason to skip, it is the reason to go.
            --
            -- Verified on node 1133_-411: teleported on, CanCollect flipped
            -- from TooFar to TRUE, InvokeServer returned true, the gate went
            -- to AlreadyCollected, and Lore_2026.SotharkuzRecollections
            -- went 3 to 4. That counter is the server's own IntValue, so
            -- this is a real collect and not a local display change.
            --
            -- There is a second collection in the same event, Rini, which
            -- drops Journal Scraps instead, and it is covered by the same
            -- loop because the only difference is the collection name and
            -- the counter it feeds.
            --
            -- One collect ends the day's crystals, and that is the event's
            -- own rule rather than a limit here: the Sotharkuz collection
            -- sets DespawnOthersOnPickup = true, so the first crystal taken
            -- takes the rest of them with it. Measured straight after a
            -- collect, the 50 tagged crystals went to 0 and the node reasons
            -- came back 18 NotSpawned against 1 AlreadyCollected. So this is
            -- a once-a-day pickup, not a sweep, and leaving the toggle on
            -- will sit at "nothing to collect" until the next roll.
            --
            -- Crystals are seeded per day. GetTimeSeed reported a
            -- CurrentSeed of 8 against a ResetIntervalSeconds of 86400, and
            -- which of the nineteen node slots actually spawns is decided
            -- server side: every place a spawn value is created in
            -- Lore2026RecollectionService is behind an IsServer guard, so the
            -- client only ever reads the outcome. That is why this loop
            -- polls the tag rather than trying to force a spawn, and why it
            -- is worth leaving enabled through a reset.
            --
            -- Reward is 50 per crystal and the counter is the event's own
            -- Lore_2026.SotharkuzRecollections, which this groupbox reads
            -- straight off PlayerData instead of tallying its own.
            --==========================================================
            local CrystalBox = Tabs.GameMods:AddRightGroupbox("Memory Crystals")

            local crystalStatus = CrystalBox:AddLabel("Crystals : off")
            local crystalCount = CrystalBox:AddLabel("Left : —")
            local crystalCounter = CrystalBox:AddLabel("Recollections : —")

            local Crystal = getgenv().__Testing.Crystal or {}

            getgenv().__Testing.Crystal = Crystal

            Crystal.running = false
            Crystal.teleport = true
            Crystal.tween = true
            Crystal.tweenTime = 0.6
            Crystal.delay = 0.9
            Crystal.collected = 0
            Crystal.blocked = nil
            Crystal.inFlight = nil
            Crystal.deps = nil
            Crystal.collection = "Sotharkuz"
            Crystal.stop = function()
                Crystal.running = false
            end

            local function crystalWait(seconds)
                local deadline = os.clock() + seconds

                while Crystal.running and os.clock() < deadline do
                    task.wait(0.1)
                end
            end

            local function setCrystalStatus(text)
                if Crystal.lastStatus == text then return end
                Crystal.lastStatus = text
                crystalStatus:SetText(text)
            end

            local function setCrystalCount(text)
                if Crystal.lastCount == text then return end
                Crystal.lastCount = text
                crystalCount:SetText(text)
            end

            local function setCrystalCounter(text)
                if Crystal.lastCounter == text then return end
                Crystal.lastCounter = text
                crystalCounter:SetText(text)
            end

            local function crystalDeps()
                if Crystal.deps then return Crystal.deps end

                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))

                if not okSonar then return nil end

                local okService, Service = pcall(Sonar, "Lore2026RecollectionService")
                local okRemotes, RemoteUtils = pcall(Sonar, "RemoteUtils")

                if not (okService and okRemotes) then return nil end

                local okRemote, Remote = pcall(function()
                    return RemoteUtils.GetRemoteFunction("Lore2026CollectRecollection")
                end)

                if not okRemote or not Remote then return nil end

                Crystal.deps = {
                    Service = Service,
                    Remote = Remote,
                    MaxDistance = Service.GetMaxCollectDistance and Service.GetMaxCollectDistance() or 80,
                }

                return Crystal.deps
            end

            -- Everything the loop needs about the chosen collection is read
            -- from the service rather than hardcoded, because the two
            -- collections differ in more than the name. Sotharkuz is tagged
            -- Lore2026MemoryCrystal and counts into SotharkuzRecollections,
            -- while Rini is tagged Lore2026JournalScrap, counts into
            -- RiniRecollections and records under JournalScrapsCollected.
            -- Reading Tag and CounterName off the collection data is what
            -- lets one loop and one dropdown cover both.
            local function crystalCollection()
                local deps = crystalDeps()

                if not deps then return nil end

                local ok, data = pcall(deps.Service.GetCollection, Crystal.collection)

                if not ok or type(data) ~= "table" then return nil end

                return {
                    name = Crystal.collection,
                    tag = data.Tag or "Lore2026MemoryCrystal",
                    counter = data.CounterName or "SotharkuzRecollections",
                    display = data.DisplayName or "Collectible",
                }
            end

            -- The event's own counter on PlayerData, so this reads the
            -- server's number rather than a tally kept here. The counter name
            -- comes from the collection, which is why Rini reads
            -- RiniRecollections rather than the crystal one.
            local function readRecollectionCount(counterName)
                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))

                if not okSonar then return nil end

                local okWrapper, wrapper = pcall(function()
                    return Sonar("PlayerWrapper").GetClient()
                end)

                if not okWrapper or not wrapper then return nil end

                local lore = wrapper.PlayerData and wrapper.PlayerData:FindFirstChild("Lore_2026")

                if not lore then return nil end

                local value = lore:FindFirstChild(counterName)

                if not value then return nil end

                return value.Value
            end

            local function crystalTick()
                local deps = crystalDeps()

                if not deps then
                    setCrystalStatus("Crystals : unavailable in this build")
                    return
                end

                local collection = crystalCollection()

                if not collection then
                    setCrystalStatus("Crystals : no such collection")
                    return
                end

                local player = game:GetService("Players").LocalPlayer
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")

                if not root then
                    setCrystalStatus("Crystals : waiting for character")
                    return
                end

                local count = readRecollectionCount(collection.counter)

                if count then
                    setCrystalCounter(string.format("Recollections : %d", count))
                end

                -- Only the Models are collectibles. The tag also lands on a
                -- child MeshPart named Target, which has no node id of its
                -- own and would hand the gate a name it cannot match.
                local tagged = game:GetService("CollectionService"):GetTagged(collection.tag)
                local candidates = {}

                for _, instance in ipairs(tagged) do
                    if instance:IsA("Model") then
                        local ok, pivot = pcall(function()
                            return instance:GetPivot()
                        end)

                        if ok and pivot then
                            table.insert(candidates, {
                                instance = instance,
                                id = instance.Name,
                                distance = (pivot.Position - root.Position).Magnitude,
                            })
                        end
                    end
                end

                if #candidates == 0 then
                    setCrystalCount("Left : none spawned")
                    setCrystalStatus(collection.display .. " : nothing to collect")
                    Crystal.blocked = nil
                    return
                end

                table.sort(candidates, function(a, b)
                    return a.distance < b.distance
                end)

                -- The gate is a distance check, so it cannot be used to pick
                -- a target before we have moved. Every crystal answered
                -- TooFar at 800 studs and further, which meant choosing on
                -- the gate alone never selected anything and the teleport
                -- below was unreachable, leaving the loop parked on "TooFar"
                -- while a perfectly collectible crystal sat 800 studs away.
                --
                -- So the only reasons worth skipping here are the ones that
                -- moving cannot fix: AlreadyCollected, NotSpawned and
                -- Locked. Everything else, TooFar included, is a candidate
                -- and gets sorted by distance like the shoom piles do.
                local reachable = {}

                for _, candidate in ipairs(candidates) do
                    local okVerdict, verdict = pcall(deps.Service.CanCollect, player, Crystal.collection, candidate.id)
                    local reason = nil

                    if not okVerdict then
                        reason = "unavailable"
                    elseif verdict == true then
                        reason = nil
                    elseif type(verdict) == "table" then
                        reason = tostring(verdict[1])
                    else
                        reason = "unavailable"
                    end

                    if reason ~= "AlreadyCollected" and reason ~= "NotSpawned" and reason ~= "Locked" then
                        table.insert(reachable, {
                            candidate = candidate,
                            reason = reason,
                        })
                    elseif reason and reason ~= "TooFar" then
                        Crystal.blocked = reason
                    end
                end

                if #reachable == 0 then
                    setCrystalCount(string.format("Left : %d, none available", #candidates))
                    setCrystalStatus("Crystals : " .. (Crystal.blocked or "nothing available"))
                    return
                end

                table.sort(reachable, function(a, b)
                    return a.candidate.distance < b.candidate.distance
                end)

                -- Already within range beats merely closer on paper, the
                -- same preference the shoom loop uses.
                local target3 = reachable[1].candidate

                for _, entry in ipairs(reachable) do
                    if entry.candidate.distance <= deps.MaxDistance * 0.5 then
                        target3 = entry.candidate
                        break
                    end
                end

                if Crystal.teleport and target3.distance > deps.MaxDistance * 0.5 then
                    local goal = target3.instance:GetPivot().Position + Vector3.new(0, 3, 0)

                    if Crystal.tween and Crystal.tweenTime > 0 then
                        -- Glide rather than snap, so the move reads as travel
                        -- instead of a teleport. Driven by elapsed time off
                        -- the instance clock rather than TweenService, which
                        -- would need a connection torn down again on every
                        -- run and can be stepped straight to its end state
                        -- anyway.
                        local start = root.CFrame
                        local duration = Crystal.tweenTime
                        local began = os.clock()

                        while Crystal.running do
                            local alpha = (os.clock() - began) / duration

                            if alpha >= 1 then
                                character:PivotTo(CFrame.new(goal))
                                break
                            end

                            -- smoothstep, so it eases in and out rather than
                            -- sliding at a constant rate
                            local eased = alpha * alpha * (3 - 2 * alpha)
                            character:PivotTo(start:Lerp(CFrame.new(goal), eased))

                            task.wait(0.05)
                        end
                    else
                        character:PivotTo(CFrame.new(goal))
                    end

                    crystalWait(0.5)

                    if not Crystal.running then return end

                    root = character:FindFirstChild("HumanoidRootPart")

                    if not root then
                        setCrystalStatus("Crystals : waiting for character")
                        return
                    end
                end

                -- Re-ask now that we are standing on it. This is the only
                -- place the gate can be satisfied, because it measures
                -- distance against our own position.
                local okVerdict, verdict = pcall(deps.Service.CanCollect, player, Crystal.collection, target3.id)

                if not okVerdict or verdict ~= true then
                    Crystal.blocked = type(verdict) == "table" and tostring(verdict[1]) or "unavailable"
                    setCrystalStatus("Crystals : " .. Crystal.blocked)
                    return
                end

                -- Same reasoning as the shoom loop. InvokeServer yields
                -- until the server answers and a handler that throws without
                -- returning leaves it waiting, so it runs behind an in flight
                -- flag on its own thread.
                if Crystal.inFlight then return end

                Crystal.inFlight = true

                task.spawn(function()
                    local okInvoke, result = pcall(function()
                        return deps.Remote:InvokeServer(Crystal.collection, target3.id)
                    end)

                    Crystal.inFlight = nil

                    if not Crystal.running then return end

                    if okInvoke and result then
                        Crystal.collected = Crystal.collected + 1
                        Crystal.blocked = nil
                        setCrystalStatus(string.format("Crystals : took %s", target3.id))
                    else
                        -- Show the actual error rather than a flat "refused".
                        -- A wrong argument name inside this pcall used to
                        -- report the same thing as a server rejection, which
                        -- is indistinguishable from a real one and left the
                        -- loop claiming "taking" forever with nothing
                        -- collected. A Luau error means this script is wrong,
                        -- a clean false means the server said no.
                        local detail = tostring(result):gsub("^.*:%d+: ", "")
                        Crystal.blocked = "error: " .. detail
                        setCrystalStatus("Crystals : " .. Crystal.blocked)
                    end
                end)

                setCrystalStatus(string.format("Crystals : taking %s", target3.id))
            end

            local function crystalLoop()
                while Crystal.running do
                    pcall(crystalTick)

                    if not Crystal.running then break end

                    crystalWait(Crystal.delay)
                end

                setCrystalStatus("Crystals : off")
            end

            CrystalBox:AddToggle("COS_Crystal_Auto", {
                Text = "Auto Collect",
                Default = false,
                Callback = function(state)
                    Crystal.running = state or nil

                    if not Crystal.running then
                        setCrystalStatus("Crystals : off")
                        return
                    end

                    setCrystalStatus("Crystals : starting")
                    task.spawn(crystalLoop)
                end,
            })

            -- The event has two collections and they are the same service,
            -- the same gate and the same remote. Sotharkuz drops the Memory
            -- Crystals and Rini drops the Journal Scraps, so the only real
            -- difference is the name handed to CanCollect and
            -- InvokeServer. Switching it here means the same loop covers
            -- both without a second groupbox.
            CrystalBox:AddDropdown("COS_Crystal_Collection", {
                Text = "Collection",
                Values = { "Sotharkuz", "Rini" },
                Default = "Sotharkuz",
                Callback = function(value)
                    Crystal.collection = value
                end,
            })

            CrystalBox:AddToggle("COS_Crystal_Teleport", {
                Text = "Teleport To Crystal",
                Default = true,
                Callback = function(state)
                    Crystal.teleport = state or false
                end,
            })

            -- A snap reads as a teleport; a short glide reads as travel.
            -- 0 is the snap, which is also what the shoom piles still do.
            CrystalBox:AddSlider("COS_Crystal_Tween", {
                Text = "Glide Seconds",
                Min = 0,
                Max = 3,
                Default = 0.6,
                Rounding = 2,
                Callback = function(value)
                    Crystal.tweenTime = value
                    Crystal.tween = value > 0
                end,
            })

            CrystalBox:AddSlider("COS_Crystal_Delay", {
                Text = "Seconds Between",
                Min = 0.3,
                Max = 5,
                Default = 0.9,
                Rounding = 1,
                Callback = function(value)
                    Crystal.delay = value
                end,
            })

            --==========================================================
            -- INVENTORY
            --
            -- Everything here is a straight read of the replicated PlayerData
            -- ScreenGui, so there is nothing to guess about and nothing that
            -- can fail. It exists because the game has no way to show you a
            -- full list without opening a menu and paging through it, and
            -- because StorageCap reads as a bare 5 with no context, which is
            -- the kind of number that invites a wrong assumption.
            --
            -- What the folders actually are, measured rather than assumed:
            --
            --   Storage        0 children on a fresh account, IntValues
            --                  named by resource once you hold any
            --   Items          36 IntValues, the token and consumable counts
            --   GachaSeeds     30 IntValues
            --   Unlocks        471 IntValues, the species collection, of
            --                  which 24 were non zero
            --   Titles         13 BoolValues
            --   MiscItems      15 children
            --   StorageCap     5
            --
            -- StorageCap is almost certainly a count of storage pages rather
            -- than an item capacity, since it is 5 while Storage holds
            -- nothing and Items holds 36 separate entries. The label says
            -- "pages" and does not claim otherwise.
            --
            -- That is a record of what PlayerData carries, not of what the
            -- panel offers. Four of the seven are listed as collections and
            -- the reasons the other three are not are on invCategories below.
            --
            -- The entry dropdown is capped and filtered on purpose. Unlocks
            -- has 471 entries, and handing that to AddDropdown would build
            -- 471 buttons in the scrolling list on every rebuild. The default
            -- is non zero only, which turns Unlocks into 24, and the cap is
            -- reported in the label rather than silently truncating.
            --==========================================================
            local InvBox = Tabs.GameMods:AddRightGroupbox("Inventory")

            local invCoins = InvBox:AddLabel("Coins : —")
            local invSummary = InvBox:AddLabel("—")
            local invEntry = InvBox:AddLabel("Entry : —")

            local Inv = getgenv().__Testing.Inventory or {}

            getgenv().__Testing.Inventory = Inv

            Inv.category = "Tokens"
            Inv.nonZero = true
            Inv.values = {}
            Inv.names = {}
            Inv.pick = nil

            -- The readable collections, in the order they are most likely to
            -- be wanted.
            --
            -- Three of the seven PlayerData folders are not listed, and all
            -- three were dropped for the same reason: nothing in them is an
            -- item, so every row came back iconless.
            --
            --   Storage      0 children on this account. It is a set of
            --                 resource pages, not a collection, and
            --                 StorageCap is a count of those pages.
            --   GachaSeeds   30 IntValue counters named Master, Random,
            --                 Session, Tikit, Boosted and so on. Currency
            --                 tallies, not seeds, despite the folder name.
            --   Titles       13 BoolValues for cosmetic name labels. The game
            --                 gives them no asset at all, so ItemUtils and
            --                 GetObjectFromName both error on every one.
            --
            -- Species is the 471 entry collection and was previously called
            -- Species Unlocks, which is the folder's own name rather than what
            -- it holds. It reads as "things you have unlocked" in a list that
            -- is otherwise all owned items, and the game's own screen calls it
            -- Species, so the label matches that instead. Tokens is the same
            -- story: the folder is PlayerData.Items but the game calls that
            -- screen MyTokens, so the label follows the game.
            --
            -- Palettes is SpecialPalettes, which holds 118 of them and is the
            -- folder the game's own Palettes screen reads. Held-only reduces
            -- it to the six actually owned, and those six match the game's
            -- list exactly: Tinted 2, SweetDreams 2, Matcha, LandSeaSky,
            -- Paradox and MistyRose at 1 each.
            --
            -- Currency is the odd one out and is the reason invEntryList
            -- exists. It is not a folder. Coins, TimePoints, Tikits and
            -- TikitPoints are top level scalars sitting beside the folders on
            -- PlayerData, which is why a folder-only reader can show a
            -- collection but never a balance.
            --
            -- MaterialPalettes is deliberately not listed. It holds 136
            -- entries with SIG_ and MTL_ prefixes and none of them resolve
            -- through ItemUtils, so it would be 136 iconless rows.
            local invCategories = {
                { label = "Tokens", folder = "Items" },
                { label = "Currency", values = { { key = "Coins", label = "Shooms" }, "TimePoints", "Tikits", "TikitPoints" } },
                { label = "Species", folder = "Unlocks" },
                { label = "Palettes", folder = "SpecialPalettes" },
                { label = "Misc Items", folder = "MiscItems" },
                { label = "Plushies", folder = "Plushies" },
            }

            local invCategoryNames = {}

            for _, entry in ipairs(invCategories) do
                table.insert(invCategoryNames, entry.label)
            end

            local function invPlayerData()
                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))

                if not okSonar then return nil end

                local okWrapper, wrapper = pcall(function()
                    return Sonar("PlayerWrapper").GetClient()
                end)

                if not okWrapper or not wrapper then return nil end

                return wrapper.PlayerData
            end

            local function invWrite(label, text)
                if label.Text ~= text then label:SetText(text) end
            end

            -- The entries behind a category, shared by the panel and the
            -- pop-out so the two can never disagree about what a collection
            -- holds.
            --
            -- Two source kinds, because PlayerData is not uniform. Most
            -- collections are a Folder of IntValues named after the thing, so
            -- the folder's children are the entries. Currency is not a folder
            -- at all: Coins, TimePoints, Tikits and TikitPoints are top level
            -- scalars sitting beside the folders rather than inside one,
            -- which is exactly why a folder-only reader can never show a
            -- balance. So an entry either names a folder or names the
            -- individual values to read.
            local function invEntryList(category)
                local pd = invPlayerData()
                local out = {}

                if not pd then return out, nil end

                local spec

                for _, entry in ipairs(invCategories) do
                    if entry.label == category then
                        spec = entry
                        break
                    end
                end

                if not spec then return out, pd end

                -- Reads one holder's value defensively. The read has to happen
                -- inside the pcall rather than at the call site, because a
                -- folder child is not guaranteed to be a value at all:
                -- SavedColors holds Folders and touching .Value on one raises,
                -- which would take the whole scan down rather than skipping
                -- the one bad row.
                local function add(name, holder)
                    local ok, value = pcall(function()
                        return holder.Value
                    end)

                    value = ok and value or 0

                    if type(value) == "boolean" then
                        value = value and 1 or 0
                    end

                    if type(value) ~= "number" then value = 0 end

                    table.insert(out, { name = name, value = value })
                end

                if spec.folder then
                    local folder = pd:FindFirstChild(spec.folder)

                    if folder then
                        for _, child in ipairs(folder:GetChildren()) do
                            add(child.Name, child)
                        end
                    end
                elseif spec.values then
                    -- Each entry is a PlayerData key, or a table when the key
                    -- and the name to show differ. Coins is the one that does:
                    -- the game calls its main currency Shooms and its own
                    -- currency screen reads "Shooms x5,186" off a Coins value
                    -- of 5186. Reading it as Coins is correct and looking the
                    -- icon up as Shooms is what finds the art, because Coins
                    -- has no entry in ItemUtils at all while Shooms returns
                    -- rbxassetid://9009086352. Showing the raw key would have
                    -- given a nameless letter where the game shows a coin.
                    for _, item in ipairs(spec.values) do
                        local key, label = item, item

                        if type(item) == "table" then
                            key = item.key
                            label = item.label or item.key
                        end

                        add(label, pd:FindFirstChild(key) or { Value = 0 })
                    end
                end

                return out, pd
            end

            -- Rebuilds the entry list for the chosen category. The order is
            -- by count and then name, so whatever you actually care about is
            -- at the top instead of alphabetical noise, and the cap is
            -- reported rather than silently truncating.
            local function invScan()
                local entries = invEntryList(Inv.category)

                Inv.values = {}
                Inv.names = {}
                Inv.total = #entries
                Inv.nonZeroCount = 0
                Inv.truncated = 0

                local held = {}

                for _, entry in ipairs(entries) do
                    Inv.values[entry.name] = entry.value

                    if entry.value > 0 then
                        Inv.nonZeroCount = Inv.nonZeroCount + 1
                        table.insert(held, entry)
                    end
                end

                table.sort(held, function(a, b)
                    if a.value == b.value then return a.name < b.name end
                    return a.value > b.value
                end)

                -- Held only, but never to the point of an empty dropdown. An
                -- account with nothing in a folder gets the full list instead,
                -- which is more use than a blank selector.
                local list = held

                if not Inv.nonZero or #held == 0 then
                    list = {}

                    for _, entry in ipairs(entries) do
                        table.insert(list, entry)
                    end

                    table.sort(list, function(a, b)
                        if a.value == b.value then return a.name < b.name end
                        return a.value > b.value
                    end)
                end

                local cap = 60
                local count = math.min(#list, cap)

                if #list > count then
                    Inv.truncated = #list - count
                end

                for i = 1, count do
                    Inv.names[i] = list[i].name
                end
            end

            -- The library builds one button per dropdown value, so Unlocks at
            -- 471 entries would rebuild 471 GUI objects on every category
            -- change. SetValues swaps the list in place instead.
            local function invRefresh()
                invScan()

                local widget = getgenv().Options["COS_Inv_Entry"]

                if not widget then return end

                local names = Inv.names

                if #names == 0 then
                    names = { "—" }
                end

                pcall(function()
                    widget:SetValues(names)
                end)

                if Inv.pick and not Inv.values[Inv.pick] then
                    Inv.pick = nil
                end
            end

            -- Forward declared because every widget callback below calls it.
            -- Declaring it as a local function further down would leave those
            -- closures resolving a global of the same name, which is nil, so
            -- switching collection would throw instead of updating.
            local invUpdate

            InvBox:AddDropdown("COS_Inv_Category", {
                Text = "Collection",
                Values = invCategoryNames,
                -- By name, not by index. This was invCategoryNames[2] to skip
                -- past Storage, so dropping Storage quietly moved the default
                -- to Misc Items and the panel opened on the wrong collection.
                Default = "Tokens",
                Callback = function(value)
                    Inv.category = value
                    invRefresh()
                    invUpdate()
                end,
            })

            InvBox:AddDropdown("COS_Inv_Entry", {
                Text = "Entry",
                -- Populated on the first refresh. An empty list is legal for
                -- this library as long as AllowNull is set, which is what
                -- keeps a fresh account with an empty Storage folder from
                -- throwing during construction.
                Values = { "—" },
                AllowNull = true,
                Callback = function(value)
                    Inv.pick = value
                    invUpdate()
                end,
            })

            InvBox:AddToggle("COS_Inv_NonZero", {
                Text = "Held Only",
                Default = true,
                Callback = function(state)
                    Inv.nonZero = state or false
                    invRefresh()
                    invUpdate()
                end,
            })

            InvBox:AddButton("Refresh", function()
                invRefresh()
                invUpdate()
            end)

            invUpdate = function()
                local pd = invPlayerData()

                if not pd then
                    invWrite(invCoins, "Coins : waiting")
                    return
                end

                local coins = pd:FindFirstChild("Coins")
                local points = pd:FindFirstChild("TimePoints")
                local tikits = pd:FindFirstChild("Tikits")

                local parts = {}

                if coins then table.insert(parts, "Coins " .. tostring(coins.Value)) end
                if points then table.insert(parts, "TP " .. tostring(points.Value)) end
                if tikits and tikits.Value > 0 then table.insert(parts, "Tikit " .. tostring(tikits.Value)) end

                invWrite(invCoins, table.concat(parts, "   ") or "Coins : —")

                local text

                if Inv.total == nil then
                    text = "—"
                else
                    text = string.format("%s : %d held of %d", Inv.category, Inv.nonZeroCount or 0, Inv.total or 0)

                    if Inv.truncated and Inv.truncated > 0 then
                        text = text .. string.format("   (+%d more)", Inv.truncated)
                    end
                end

                invWrite(invSummary, text)

                if Inv.pick and Inv.values[Inv.pick] ~= nil then
                    local value = Inv.values[Inv.pick]
                    invWrite(invEntry, string.format("Entry : %s = %s", Inv.pick, tostring(value)))
                else
                    local best, bestValue

                    for name, value in pairs(Inv.values) do
                        if type(value) == "number" and (not bestValue or value > bestValue) then
                            best, bestValue = name, value
                        end
                    end

                    if best then
                        invWrite(invEntry, string.format("Top : %s = %d", best, bestValue))
                    else
                        invWrite(invEntry, "Entry : nothing held")
                    end
                end
            end

            invScan()
            invRefresh()

            getgenv().__Testing.Inventory = Inv

            --==========================================================
            -- INVENTORY POP-OUT
            --
            -- Same shell as ChatLogger: one bordered frame, Code font, an
            -- accent divider under the title, and colours pulled live from
            -- ThemeManager / Library rather than a fixed palette, so it
            -- tracks the menu instead of sitting next to it looking foreign.
            --
            -- Icons come from ItemUtils.GetItemFromName(name).Image, which is
            -- where the game resolves every item thumbnail, so these are the
            -- same pictures the inventory screen uses. The row also carries
            -- ForcedDisplayName, so a name can be prettified the way the game
            -- does instead of being shown raw.
            --
            -- It lives in its own ScreenGui and nothing here touches the
            -- library's, because the library's ScreenGui is destroyed on every
            -- reload and this window has to survive independently of whether
            -- the menu happens to be open.
            --==========================================================
            local Pop = getgenv().__Testing.InventoryPop or {}

            getgenv().__Testing.InventoryPop = Pop

            Pop.open = false
            Pop.category = "Tokens"
            Pop.nonZero = true
            Pop.cap = 180

            local function popWrite(label, text)
                -- Guarded on purpose. A stale reference here threw "SetText
                -- is not a valid member of TextLabel" and took the whole
                -- render down with it, because the window can be destroyed
                -- and rebuilt underneath the registry. The instance still
                -- resolves in the tree by name, which is what makes it
                -- confusing, but the reference held in Pop is a different
                -- object to the one that was destroyed.
                if label and typeof(label) == "Instance" and label.Parent and label.Text ~= text then
                    pcall(function()
                        label.Text = text
                    end)
                end
            end

            -- Forward declared for the same reason as invUpdate. The close
            -- button and the held only button are wired inside popBuild, so
            -- at that point these names are not yet locals and would resolve
            -- to globals, which are nil. Clicking close would throw and the
            -- toggle would do nothing at all.
            local popRender
            local popClose

            -- Theme read the way ChatLogger reads it: a bounded search through
            -- ThemeManager and Library for the first Color3 under a set of
            -- plausible key names. Each source is searched for all five roles
            -- rather than one role per source, because whichever object the
            -- library exposes is not the same one the theme manager does, and
            -- taking the first source that answers for every role is what
            -- makes this robust to either being unavailable.
            local function popGetThemeColors()
                local function isColor3(value)
                    return typeof(value) == "Color3"
                end

                local function getColor(root, keys, depth, visited)
                    if type(root) ~= "table" or depth < 0 then
                        return nil
                    end
                    visited = visited or {}
                    if visited[root] then
                        return nil
                    end
                    visited[root] = true
                    for _, key in ipairs(keys) do
                        local value = rawget(root, key)
                        if isColor3(value) then
                            return value
                        end
                    end
                    if depth == 0 then
                        return nil
                    end
                    for _, value in pairs(root) do
                        if type(value) == "table" then
                            local found = getColor(value, keys, depth - 1, visited)
                            if found then
                                return found
                            end
                        end
                    end
                    return nil
                end

                local sources = { ThemeManager, Library }
                local background, main, accent, outline, font

                for _, source in ipairs(sources) do
                    if not background then
                        background = getColor(source, { "BackgroundColor", "Background", "MainColor", "Main" }, 3)
                    end
                    if not main then
                        main = getColor(source, { "MainColor", "Main", "ElementColor", "BackgroundColor" }, 3)
                    end
                    if not accent then
                        accent = getColor(source, { "AccentColor", "Accent", "HighlightColor", "Highlight" }, 3)
                    end
                    if not outline then
                        outline = getColor(source, { "OutlineColor", "Outline", "BorderColor", "Border" }, 3)
                    end
                    if not font then
                        font = getColor(source, { "FontColor", "TextColor", "ForegroundColor" }, 3)
                    end
                end

                return {
                    Background = background or Color3.fromRGB(25, 20, 25),
                    Main = main or Color3.fromRGB(35, 25, 35),
                    Accent = accent or Color3.fromRGB(210, 70, 150),
                    Outline = outline or Color3.fromRGB(70, 55, 70),
                    Font = font or Color3.fromRGB(235, 235, 235),
                    Track = Color3.fromRGB(160, 150, 160),
                }
            end

            local PopCol = popGetThemeColors()

            local PopText = 14

            local function popClearRefs()
                Pop.gui = nil
                Pop.window = nil
                Pop.title = nil
                Pop.summary = nil
                Pop.heldBtn = nil
                Pop.scroll = nil
                Pop.grid = nil
                Pop.tabs = nil
                Pop.tabsLayout = nil
                Pop.tabRules = nil
                Pop.tabButtons = nil
                Pop.closeBtn = nil
                Pop.divider = nil
                Pop.content = nil
            end

            -- Repaints every themed property from a fresh read of the theme.
            -- Held in one function rather than inline in the poll so the build
            -- and the poll cannot drift apart, which is what would happen the
            -- moment one of them gained a property the other did not.
            local function popApplyTheme()
                PopCol = popGetThemeColors()

                if not Pop.window then return end

                pcall(function()
                    Pop.window.BackgroundColor3 = PopCol.Background
                    Pop.window.BorderColor3 = PopCol.Accent
                end)
                if Pop.title then
                    pcall(function() Pop.title.TextColor3 = PopCol.Font end)
                end
                if Pop.closeBtn then
                    pcall(function()
                        Pop.closeBtn.BackgroundColor3 = PopCol.Main
                        Pop.closeBtn.BorderColor3 = PopCol.Outline
                        Pop.closeBtn.TextColor3 = PopCol.Font
                    end)
                end
                if Pop.divider then
                    pcall(function() Pop.divider.BackgroundColor3 = PopCol.Accent end)
                end
                if Pop.scroll then
                    pcall(function()
                        Pop.scroll.BackgroundColor3 = PopCol.Background
                        Pop.scroll.BorderColor3 = PopCol.Outline
                        Pop.scroll.ScrollBarImageColor3 = PopCol.Accent
                    end)
                end
                if Pop.content then
                    pcall(function()
                        Pop.content.BackgroundColor3 = PopCol.Background
                        Pop.content.BorderColor3 = PopCol.Outline
                    end)
                end
                if Pop.summary then
                    pcall(function() Pop.summary.TextColor3 = PopCol.Font end)
                end
                if Pop.heldBtn then
                    pcall(function()
                        Pop.heldBtn.BackgroundColor3 = PopCol.Main
                        Pop.heldBtn.BorderColor3 = PopCol.Outline
                        Pop.heldBtn.TextColor3 = PopCol.Font
                    end)
                end
                if Pop.tabButtons then
                    for label, button in pairs(Pop.tabButtons) do
                        local active = label == Pop.category
                        pcall(function()
                            button.TextColor3 = active and PopCol.Font or PopCol.Track
                            button.BackgroundColor3 = PopCol.Main
                            button.BorderColor3 = PopCol.Outline
                        end)
                        if Pop.tabRules and Pop.tabRules[label] then
                            pcall(function()
                                Pop.tabRules[label].BackgroundColor3 = PopCol.Accent
                                Pop.tabRules[label].Visible = active
                            end)
                        end
                    end
                end
            end

            local function popBuild()
                -- Sweep every window by name before making a new one, not
                -- just the one this registry happens to be holding. An earlier
                -- run's window can be orphaned, because teardown can only
                -- destroy what the registry knows about, and once one is
                -- orphaned the registry reference points somewhere else
                -- entirely.
                for _, existing in ipairs(game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui"):GetChildren()) do
                    if existing.Name == "COSInventoryWindow" then
                        pcall(function() existing:Destroy() end)
                    end
                end

                for _, existing in ipairs(CoreGui:GetChildren()) do
                    if existing.Name == "COSInventoryWindow" then
                        pcall(function() existing:Destroy() end)
                    end
                end

                popClearRefs()
                PopCol = popGetThemeColors()

                local player = game:GetService("Players").LocalPlayer
                local gui = Instance.new("ScreenGui")
                gui.Name = "COSInventoryWindow"
                gui.ResetOnSpawn = false
                gui.IgnoreGuiInset = true
                gui.DisplayOrder = 500
                gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                gui.Parent = CoreGui

                local window = Instance.new("Frame")
                window.Name = "Window"
                window.Size = UDim2.fromOffset(700, 520)
                window.Position = UDim2.new(0.5, -350, 0.5, -260)
                window.BackgroundColor3 = PopCol.Background
                window.BorderSizePixel = 1
                window.BorderColor3 = PopCol.Accent
                window.Active = true
                window.Parent = gui

                local title = Instance.new("TextLabel")
                title.Name = "Title"
                title.Size = UDim2.new(1, -44, 0, 30)
                title.Position = UDim2.fromOffset(8, 2)
                title.BackgroundTransparency = 1
                title.Text = "Inventory"
                title.Font = Enum.Font.Code
                title.TextSize = 16
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.TextColor3 = PopCol.Font
                title.Parent = window

                local close = Instance.new("TextButton")
                close.Name = "Close"
                close.Size = UDim2.fromOffset(28, 24)
                close.Position = UDim2.new(1, -32, 0, 4)
                close.BackgroundColor3 = PopCol.Main
                close.BorderSizePixel = 1
                close.BorderColor3 = PopCol.Outline
                close.Text = "X"
                close.Font = Enum.Font.Code
                close.TextSize = 14
                close.TextColor3 = PopCol.Font
                close.Parent = window
                close.MouseButton1Click:Connect(function()
                    popClose()
                end)

                local divider = Instance.new("Frame")
                divider.Name = "Divider"
                divider.Size = UDim2.new(1, -16, 0, 1)
                divider.Position = UDim2.fromOffset(8, 31)
                divider.BackgroundColor3 = PopCol.Accent
                divider.BorderSizePixel = 0
                divider.Parent = window

                -- Drag by the title, and by the top strip of the frame
                -- itself so grabbing just below the text still moves it.
                -- Driven by InputDelta rather than tracking the mouse
                -- absolutely, so the window keeps moving even if the cursor
                -- leaves the title mid drag.
                do
                    local dragging, dragStart, startPos = false, nil, nil
                    local function beginDrag(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = true
                            dragStart = input.Position
                            startPos = window.Position
                        end
                    end
                    title.InputBegan:Connect(beginDrag)
                    window.InputBegan:Connect(function(input)
                        if input.Position.Y - window.AbsolutePosition.Y <= 34 then
                            beginDrag(input)
                        end
                    end)
                    UserInputService.InputChanged:Connect(function(input)
                        if not dragging then return end
                        if input.UserInputType == Enum.UserInputType.MouseMovement
                            or input.UserInputType == Enum.UserInputType.Touch then
                            local d = input.Position - dragStart
                            window.Position = UDim2.new(
                                startPos.X.Scale, startPos.X.Offset + d.X,
                                startPos.Y.Scale, startPos.Y.Offset + d.Y
                            )
                        end
                    end)
                    UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = false
                        end
                    end)
                end

                local tabs = Instance.new("Frame")
                tabs.Name = "Tabs"
                tabs.Position = UDim2.fromOffset(8, 38)
                tabs.Size = UDim2.new(1, -16, 0, 26)
                tabs.BackgroundTransparency = 1
                tabs.Parent = window

                local tabsLayout = Instance.new("UIListLayout")
                tabsLayout.FillDirection = Enum.FillDirection.Horizontal
                tabsLayout.Padding = UDim.new(0, 4)
                tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
                tabsLayout.Parent = tabs

                local summary = Instance.new("TextLabel")
                summary.Name = "Summary"
                summary.Position = UDim2.fromOffset(10, 68)
                summary.Size = UDim2.new(1, -120, 0, 18)
                summary.BackgroundTransparency = 1
                summary.TextColor3 = PopCol.Font
                summary.TextSize = PopText
                summary.Font = Enum.Font.Code
                summary.TextXAlignment = Enum.TextXAlignment.Left
                summary.Text = ""
                summary.Parent = window

                local heldBtn = Instance.new("TextButton")
                heldBtn.Name = "HeldOnly"
                heldBtn.AnchorPoint = Vector2.new(1, 0)
                heldBtn.Position = UDim2.new(1, -10, 0, 66)
                heldBtn.Size = UDim2.fromOffset(100, 20)
                heldBtn.BackgroundColor3 = PopCol.Main
                heldBtn.BorderSizePixel = 1
                heldBtn.BorderColor3 = PopCol.Outline
                heldBtn.TextColor3 = PopCol.Font
                heldBtn.TextSize = 13
                heldBtn.Font = Enum.Font.Code
                heldBtn.Text = "Held only: on"
                heldBtn.Parent = window

                local content = Instance.new("Frame")
                content.Name = "Content"
                content.Position = UDim2.fromOffset(8, 90)
                content.Size = UDim2.new(1, -16, 1, -98)
                content.BackgroundColor3 = PopCol.Background
                content.BorderSizePixel = 1
                content.BorderColor3 = PopCol.Outline
                content.Parent = window

                local scroll = Instance.new("ScrollingFrame")
                scroll.Name = "Grid"
                scroll.Position = UDim2.fromOffset(6, 6)
                scroll.Size = UDim2.new(1, -12, 1, -12)
                scroll.BackgroundColor3 = PopCol.Background
                scroll.BorderSizePixel = 0
                scroll.ScrollBarThickness = 6
                scroll.ScrollBarImageColor3 = PopCol.Accent
                scroll.ScrollingDirection = Enum.ScrollingDirection.Y
                scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
                scroll.CanvasSize = UDim2.new()
                scroll.Parent = content

                local grid = Instance.new("UIGridLayout")
                grid.CellSize = UDim2.fromOffset(210, 44)
                grid.CellPadding = UDim2.fromOffset(4, 4)
                grid.SortOrder = Enum.SortOrder.LayoutOrder
                grid.Parent = scroll

                Pop.gui = gui
                Pop.window = window
                Pop.title = title
                Pop.closeBtn = close
                Pop.divider = divider
                Pop.summary = summary
                Pop.heldBtn = heldBtn
                Pop.scroll = scroll
                Pop.grid = grid
                Pop.tabs = tabs
                Pop.tabsLayout = tabsLayout
                Pop.content = content

                heldBtn.MouseButton1Click:Connect(function()
                    Pop.nonZero = not Pop.nonZero
                    heldBtn.Text = "Held only: " .. (Pop.nonZero and "on" or "off")
                    popRender()
                end)

                for order, entry in ipairs(invCategories) do
                    local button = Instance.new("TextButton")
                    button.LayoutOrder = order
                    button.AutomaticSize = Enum.AutomaticSize.X
                    button.Size = UDim2.fromOffset(0, 24)
                    button.BackgroundColor3 = PopCol.Main
                    button.BorderSizePixel = 1
                    button.BorderColor3 = PopCol.Outline
                    button.Text = "  " .. entry.label .. "  "
                    button.TextColor3 = PopCol.Track
                    button.TextSize = 13
                    button.Font = Enum.Font.Code
                    button.AutoButtonColor = false
                    button.Parent = tabs

                    local rule = Instance.new("Frame")
                    rule.Name = "Rule"
                    rule.Size = UDim2.new(1, 0, 0, 2)
                    rule.Position = UDim2.new(0, 0, 1, -2)
                    rule.BackgroundColor3 = PopCol.Accent
                    rule.BorderSizePixel = 0
                    rule.Visible = false
                    rule.ZIndex = 2
                    rule.Parent = button

                    button.MouseButton1Click:Connect(function()
                        Pop.category = entry.label
                        popRender()
                    end)

                    Pop.tabRules = Pop.tabRules or {}
                    Pop.tabRules[entry.label] = rule
                    Pop.tabButtons = Pop.tabButtons or {}
                    Pop.tabButtons[entry.label] = button
                end

                -- Live theme follow, same cadence as ChatLogger: four times a
                -- second is plenty for a visual sync and costs nothing next to
                -- doing it every frame. Disconnected and rebuilt on every
                -- build so a reopen cannot leave two polls running.
                if Pop.themeConnection then
                    pcall(function() Pop.themeConnection:Disconnect() end)
                end
                Pop.themeConnection = RunService.Heartbeat:Connect(function()
                    if not Pop.window then return end
                    Pop._themeAccum = (Pop._themeAccum or 0) + 1 / 60
                    if Pop._themeAccum < 0.25 then return end
                    Pop._themeAccum = 0
                    pcall(popApplyTheme)
                end)

                return Pop
            end

            -- The pop-out reads through the same invEntryList the panel uses
            -- rather than resolving the folder itself. It used to look the
            -- category up and hand back an Instance, which cannot express the
            -- Currency tab at all because that one is a set of named scalars
            -- rather than a folder, and it would have reported "No such
            -- collection" for it.
            local function popEntries()
                return invEntryList(Pop.category)
            end

            -- Two lookups, not one, and the second one is the fix.
            --
            -- GetItemFromName only answers for things the game models as
            -- items. It returns nil for every species, so the whole Species
            -- Unlocks tab came out as blank tiles: 24 of them, including
            -- Aesmir, Buukon and Euvias. GetObjectFromName is the wider
            -- resolver and does answer, returning the creature data
            -- including Image and HighResolutionImage. So the item lookup runs
            -- first because it is the cheaper of the two, and the object
            -- lookup is the fallback that actually covers species.
            --
            -- What still has no art anywhere, and is left to the initial
            -- rather than given a fake picture: Titles, which are cosmetic
            -- name labels the game never gives an asset, and GachaSeeds,
            -- which is not a collection of seeds at all but thirty
            -- IntValue counters named Master, Random, Session, Tikit,
            -- Boosted and so on. Neither is an item, so neither has an
            -- image, and drawing one would be inventing data.
            local function popItemInfo(name)
                local okSonar, Sonar = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Sonar"))
                if not okSonar then return nil end
                local ok, ItemUtils = pcall(Sonar, "ItemUtils")
                if not ok then return nil end

                local okItem, item = pcall(ItemUtils.GetItemFromName, name)
                if okItem and type(item) == "table" then return item end

                local okObject, object = pcall(ItemUtils.GetObjectFromName, name)
                if okObject and type(object) == "table" then return object end

                return nil
            end

            local function popCard(name, value)
                local colors = PopCol
                local card = Instance.new("Frame")
                card.LayoutOrder = Pop.cardOrder or 0
                card.Size = UDim2.fromOffset(210, 44)
                card.BackgroundColor3 = colors.Main
                card.BorderSizePixel = 1
                card.BorderColor3 = colors.Outline
                card.Parent = Pop.scroll

                if value > 0 then
                    local strip = Instance.new("Frame")
                    strip.Size = UDim2.new(0, 2, 1, 0)
                    strip.BackgroundColor3 = colors.Accent
                    strip.BorderSizePixel = 0
                    strip.Parent = card
                end

                local icon = Instance.new("ImageLabel")
                icon.Position = UDim2.fromOffset(8, 4)
                icon.Size = UDim2.fromOffset(36, 36)
                icon.BackgroundColor3 = colors.Background
                icon.BorderSizePixel = 1
                icon.BorderColor3 = colors.Outline
                icon.ScaleType = Enum.ScaleType.Fit
                icon.Parent = card

                local info = popItemInfo(name)

                if info and info.Image then
                    icon.Image = info.Image
                elseif info and type(info.Colors) == "table" then
                    -- A palette is a set of colours rather than a picture, so
                    -- there is no thumbnail to show and the game's own palette
                    -- screen draws swatches for the same reason. Sweet Dreams,
                    -- Tinted, Matcha, Land Sea Sky, Paradox and Misty Rose all
                    -- carry twelve Colors and no Image at all, which is why
                    -- this tab was a column of letters until now. Sorted by
                    -- key so the swatch order is stable between renders rather
                    -- than following pairs() ordering.
                    icon.Image = ""
                    icon.ImageTransparency = 1

                    local order = {}

                    for key in pairs(info.Colors) do
                        if typeof(info.Colors[key]) == "Color3" then
                            order[#order+1] = key
                        end
                    end

                    table.sort(order, function(a, b)
                        return tostring(a) < tostring(b)
                    end)

                    local columns = 4
                    local count = #order
                    local cellWidth = 34 / columns
                    local cellHeight = 34 / math.max(1, math.ceil(count / columns))

                    for i, key in ipairs(order) do
                        local swatch = Instance.new("Frame")
                        swatch.Name = "Swatch"
                        swatch.Size = UDim2.fromOffset(cellWidth, cellHeight)
                        swatch.Position = UDim2.fromOffset(
                            1 + ((i - 1) % columns) * cellWidth,
                            1 + math.floor((i - 1) / columns) * cellHeight
                        )
                        swatch.BorderSizePixel = 0
                        swatch.BackgroundColor3 = info.Colors[key]
                        swatch.ZIndex = icon.ZIndex + 1
                        swatch.Parent = icon
                    end
                else
                    -- No art exists for this one, so show the initial rather
                    -- than a flat tile. The tile read as a broken image and
                    -- was indistinguishable from the species bug above, which
                    -- is exactly the problem this is meant to make visible:
                    -- a letter is honest, a placeholder is not.
                    icon.Image = ""
                    icon.ImageTransparency = 1

                    local initial = Instance.new("TextLabel")
                    initial.Name = "Initial"
                    initial.Size = UDim2.fromScale(1, 1)
                    initial.BackgroundTransparency = 1
                    initial.Text = string.sub(string.upper(name), 1, 1)
                    initial.TextColor3 = colors.Track
                    initial.TextSize = 18
                    initial.Font = Enum.Font.Code
                    initial.TextXAlignment = Enum.TextXAlignment.Center
                    initial.TextYAlignment = Enum.TextYAlignment.Center
                    initial.ZIndex = icon.ZIndex + 1
                    initial.Parent = icon
                end

                local label = Instance.new("TextLabel")
                label.Position = UDim2.fromOffset(52, 4)
                label.Size = UDim2.new(1, -60, 0, 18)
                label.BackgroundTransparency = 1
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.TextSize = 13
                label.Font = Enum.Font.Code
                label.TextColor3 = colors.Font
                label.TextTruncate = Enum.TextTruncate.AtEnd
                if info and (info.ForcedDisplayName or info.Name) then
                    label.Text = info.ForcedDisplayName or info.Name
                else
                    label.Text = name
                end
                label.Parent = card

                local count = Instance.new("TextLabel")
                count.Position = UDim2.fromOffset(52, 22)
                count.Size = UDim2.new(1, -60, 0, 16)
                count.BackgroundTransparency = 1
                count.TextXAlignment = Enum.TextXAlignment.Left
                count.TextSize = 12
                count.Font = Enum.Font.Code
                count.TextColor3 = value > 0 and colors.Accent or colors.Track
                count.Text = "x" .. tostring(value)
                count.Parent = card

                return card
            end

            popRender = function()
                if not Pop.gui or not Pop.open then return end

                local entries, pd = popEntries()

                for _, child in ipairs(Pop.scroll:GetChildren()) do
                    if child:IsA("Frame") then child:Destroy() end
                end

                if not pd then
                    popWrite(Pop.summary, "Player data unavailable")
                    return
                end

                if #entries == 0 then
                    popWrite(Pop.summary, "Nothing in " .. Pop.category)
                    return
                end

                table.sort(entries, function(a, b)
                    if a.value == b.value then return a.name < b.name end
                    return a.value > b.value
                end)

                local total = #entries
                local held = 0

                for _, entry in ipairs(entries) do
                    if entry.value > 0 then held = held + 1 end
                end

                local list = entries

                if Pop.nonZero then
                    local filtered = {}

                    for _, entry in ipairs(entries) do
                        if entry.value > 0 then table.insert(filtered, entry) end
                    end

                    if #filtered > 0 then list = filtered end
                end

                local shown = math.min(#list, Pop.cap)
                local order = 0

                for i = 1, shown do
                    order = order + 1
                    Pop.cardOrder = order
                    popCard(list[i].name, list[i].value)
                end

                local coins = pd and pd:FindFirstChild("Coins")

                popWrite(Pop.title, "Inventory  " .. Pop.category)

                -- Show the rule under whichever tab is active and hide it on
                -- the rest. Kept in a table keyed by label at build time
                -- because the tab buttons are created once and never
                -- rebuilt, unlike the cards.
                if Pop.tabRules then
                    for label, rule in pairs(Pop.tabRules) do
                        local active = label == Pop.category
                        pcall(function()
                            rule.Visible = active
                            rule.BackgroundColor3 = PopCol.Accent
                        end)
                        if Pop.tabButtons and Pop.tabButtons[label] then
                            pcall(function()
                                Pop.tabButtons[label].TextColor3 = active and PopCol.Font or PopCol.Track
                                Pop.tabButtons[label].BackgroundColor3 = PopCol.Main
                                Pop.tabButtons[label].BorderColor3 = PopCol.Outline
                            end)
                        end
                    end
                end

                local text = string.format("%d held of %d", held, total)

                if #list > shown then
                    text = text .. string.format("   showing %d, +%d more", shown, #list - shown)
                end

                if coins then
                    text = "Coins " .. tostring(coins.Value) .. "      " .. text
                end

                popWrite(Pop.summary, text)
            end

            popClose = function()
                Pop.open = false
                if Pop.themeConnection then
                    pcall(function() Pop.themeConnection:Disconnect() end)
                    Pop.themeConnection = nil
                end
                pcall(function()
                    if Pop.gui then Pop.gui:Destroy() end
                end)
                for _, existing in ipairs(CoreGui:GetChildren()) do
                    if existing.Name == "COSInventoryWindow" then
                        pcall(function() existing:Destroy() end)
                    end
                end
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                if pg then
                    for _, existing in ipairs(pg:GetChildren()) do
                        if existing.Name == "COSInventoryWindow" then
                            pcall(function() existing:Destroy() end)
                        end
                    end
                end
                popClearRefs()
            end

            function popOpen()
                if Pop.open then
                    popClose()
                    return
                end

                popBuild()

                Pop.open = true
                popRender()
            end

            InvBox:AddButton("Open Pop Out", function()
                popOpen()
            end)

            -- Exposed on the registry as well as being wired to the button,
            -- because the library binds its buttons through InputBegan on an
            -- unexposed table, so there is no way to press one from outside
            -- and no way to bind one to a key later. Holding the functions
            -- here makes the window reachable from a keybind and makes it
            -- possible to verify it without a mouse.
            --
            -- The close BUTTON lives on Pop.closeBtn, not Pop.close. Both were
            -- called close at one point, and popBuild assigns the button
            -- after this line has already assigned the function, so the first
            -- open silently replaced the function with a TextButton and
            -- every later Pop.close() died with "attempt to call a Instance
            -- value". The button key and the function key have to stay
            -- distinct or the teardown handle stops working the first time
            -- the window is opened.
            Pop.toggle = popOpen
            Pop.close = popClose
            Pop.render = popRender


            -- Server / world information
            local ServerBox = Tabs.GameMods:AddLeftGroupbox("Server Info")
            local serverStatus = ServerBox:AddLabel("Players : —")
            local serverIdLabel = ServerBox:AddLabel("Job ID : " .. tostring(game.JobId))
            ServerBox:AddLabel("Place ID : 5233782396")
            ServerBox:AddLabel("Sonaria creature survival")

            local function updateServerInfo()
                local count = #Players:GetPlayers()
                local maxPlayers = Players.MaxPlayers or 0

                pcall(function()
                    serverStatus:SetText(string.format(
                        "Players : %d/%d",
                        count,
                        maxPlayers
                    ))
                end)
            end

            getgenv().TestingCOSFoodCleanup = function()

                -- expander teardown runs first, ahead of the food ESP work
                -- below, so a throw in that loop cannot leave the Heartbeat
                -- connection alive
                if hitboxState.rootConnection then
                    hitboxState.rootConnection:Disconnect()
                    hitboxState.rootConnection = nil
                end

                pcall(restoreHitbox)

                -- the stat wrapper is a replaced game function, so leaving it
                -- installed is the one leak that compounds across reloads
                pcall(uninstallStats)
                getgenv().__Testing.COSStats = nil

                -- the shoom loop moves the character, so it has to be told to
                -- stop rather than left to notice the flag on its own
                pcall(function()
                    local shoom = getgenv().__Testing.Shoom

                    if shoom and shoom.stop then
                        shoom.stop()
                    end
                end)

                pcall(function()
                    local crystal = getgenv().__Testing.Crystal

                    if crystal and crystal.stop then
                        crystal.stop()
                    end
                end)

                -- the token and trinket collectors move the character too, so
                -- they are told to stop here rather than left to notice
                pcall(function()
                    for _, name in ipairs({ "Token", "Trinket" }) do
                        local state = getgenv().__Testing[name]

                        if state and state.stop then
                            state.stop()
                        end
                    end

                    local travel = getgenv().__Testing.Travel

                    if travel then travel.busy = false end
                end)

                getgenv().__Testing.Shoom = nil
                getgenv().__Testing.Crystal = nil
                getgenv().__Testing.Token = nil
                getgenv().__Testing.Trinket = nil
                getgenv().__Testing.Travel = nil

                -- the pop out window is its own ScreenGui, not part of the
                -- library, so the Unload chain never reaches it and it has to
                -- be destroyed by name. Sweeping by name rather than
                -- following the registry reference is what catches an orphan
                -- left by an earlier run. It is parented to CoreGui, so that
                -- is where the sweep has to look; PlayerGui is swept too
                -- because older runs of this file parented it there and an
                -- orphan from before would otherwise survive every reload.
                pcall(function()
                    for _, container in ipairs({ CoreGui, LocalPlayer:FindFirstChild("PlayerGui") }) do
                        if container then
                            for _, existing in ipairs(container:GetChildren()) do
                                if existing.Name == "COSInventoryWindow" then
                                    existing:Destroy()
                                end
                            end
                        end
                    end
                end)

                getgenv().__Testing.InventoryPop = nil

                getgenv().TestingCOSHitbox = nil
                getgenv().__Testing.ForceRestore = nil

                for obj in pairs(C.foodEspObjects) do
                    destroyFoodESP(obj)
                end
                C.foodEspObjects = {}
                table.clear(C.foodCandidates)
                C.foodCandidatesInitialized = false

                -- the creature ESP parents to CoreGui directly rather than to
                -- the library's ScreenGui, so the Unload chain does not reach
                -- it and it survived every reload as a growing pile of
                -- Highlights and Billboards
                for player in pairs(C.espObjects) do
                    destroyESP(player)
                end
                C.espObjects = {}
            end

            Players.PlayerRemoving:Connect(function(player)
                destroyESP(player)
            end)

            Players.PlayerAdded:Connect(function()
                -- ESP refreshes automatically on the next heartbeat.
            end)

            RunService.Heartbeat:Connect(function(dt)
                C.scanAccum += dt

                local interval = 1 / math.max(5, C.renderHz)
                if C.scanAccum < interval then
                    return
                end

                C.scanAccum = 0

                updateAllESP()
                updateServerInfo()

                -- reads the registry, which is installed on load and already
                -- fed by whatever the game is doing this frame, so it costs
                -- nothing beyond the reads themselves
                updateStatHook()

                C.foodScanAccum += interval
                local foodInterval = 1 / math.max(1, C.foodEspHz)
                if C.foodScanAccum >= foodInterval then
                    C.foodScanAccum = 0
                    updateFoodESP()
                end
            end)
        end
    end


    SetupCreaturesOfSonaria()
end
