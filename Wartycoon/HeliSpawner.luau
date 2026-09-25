local Mounts = {}


function Mounts.new(args)

    local self = setmetatable({}, { __index = Mounts })

    self.Tabs = args.Tabs

    self.ReplicatedStorage = args.ReplicatedStorage or game:GetService("ReplicatedStorage")

    self.Workspace = args.Workspace or game:GetService("Workspace")

    self.LocalPlayer = args.LocalPlayer or game:GetService("Players").LocalPlayer

    self.destroyed = false

    return self

end


function Mounts:Destroy()
    self.destroyed = true

end


function Mounts:Init()

    if not self.Tabs or not self.Tabs.GameMods then

        warn("[Mounts] no Tabs.GameMods, skipping")

        return

    end

    local ReplicatedStorage = self.ReplicatedStorage
    local Workspace = self.Workspace
    local LocalPlayer = self.LocalPlayer

    local MountBox = self.Tabs.GameMods:AddRightGroupbox("Mounts")

    self.statusLabel = MountBox:AddLabel("Status : Idle")

    self.infoLabel = MountBox:AddLabel("Helicopters : scanning")

    local function getMountServiceParts()
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        local knit = packages and packages:FindFirstChild("Knit")
        local services = knit and knit:FindFirstChild("Services")
        if not services then return nil, nil end
        return services:FindFirstChild("MountService"),
               services:FindFirstChild("MountInfoService")
    end

    local function buildMountList()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local tables = modules and modules:FindFirstChild("Tables")
        local ok, data = pcall(require, tables)

        if not ok or type(data) ~= "table" or type(data.HelicopterNames) ~= "table" then
            return { "(none)" }
        end

        local names = {}
        for name in pairs(data.HelicopterNames) do table.insert(names, name) end
        table.sort(names, function(a, b)
            local oa = data.HelicopterOrder[a] or math.huge
            local ob = data.HelicopterOrder[b] or math.huge
            if oa == ob then return a < b end
            return oa < ob
        end)

        return names

    end
    self.allMounts = buildMountList()
    self.mountList = self.allMounts
    self.mountOwned = {}
    self.mountOwnerCache = setmetatable({}, { __mode = "k" })
    self.selectedMount = nil

    self.mountDropdown = MountBox:AddDropdown("WarMountSelect", {

        Text = "Helicopter", Default = 1, Values = self.mountList,

        Callback = function(v)
            if type(v) == "number" then v = self.mountList[v] end
            self.selectedMount = v
        end,

    })

    local function selectedMount()
        local value = self.mountDropdown and self.mountDropdown.Value
        if type(value) == "number" then value = self.mountList[value] end
        if not value or not table.find(self.mountList, value) then
            value = self.selectedMount
        end
        return value
    end
    local function mountIsOwned(name)
        if self.mountOwned[name] ~= nil then
            return self.mountOwned[name]
        end

        if self.mountController then
            local ok, status = pcall(self.mountController.PlayerOwnsMount, self.mountController, name)
            if ok and type(status) == "string" then
                self.mountOwned[name] = status == "Owned"
                return self.mountOwned[name]
            end
            return nil
        end

        local rf = self.mountInfoRf
        if rf and rf.PlayerOwnsMount then
            local remote = rf.PlayerOwnsMount
            local ok, status = pcall(remote.InvokeServer, remote, name)
            if ok and type(status) == "string" then
                self.mountOwned[name] = status == "Owned"
                return self.mountOwned[name]
            end
        end

        return nil

    end

    local function refreshMountOwnership()
        local owned, known = 0, 0
        for _, name in ipairs(self.allMounts) do
            if mountIsOwned(name) then owned = owned + 1 end
            if self.mountOwned[name] ~= nil then known = known + 1 end
        end
        if known == 0 then
            self.infoLabel:SetText(("Helicopters : %d"):format(#self.allMounts))
        else
            self.infoLabel:SetText(("Owned : %d / %d"):format(owned, #self.allMounts))
        end
    end

    local function refreshMountOptions()
        local owned = {}
        for _, name in ipairs(self.allMounts) do
            if self.mountOwned[name] == true then table.insert(owned, name) end
        end

        if #owned == 0 then
            self.mountList = { "(none)" }
            pcall(function() self.mountDropdown:SetValues(self.mountList) end)
            return
        end

        self.mountList = owned
        pcall(function() self.mountDropdown:SetValues(owned) end)
        if not table.find(owned, self.selectedMount) then
            self.selectedMount = owned[1]
            if type(self.mountDropdown.SetValue) == "function" then
                pcall(function() self.mountDropdown:SetValue(owned[1]) end)
            end
        end

    end

    local function mountOutCount(name)
        local systems = Workspace:FindFirstChild("Game Systems")
        local bay = systems and systems:FindFirstChild("Helicopter Workspace")
        if not bay then return 0 end
        local rf = self.mountService and self.mountService.RF
        if not rf or not rf.GetOwnerPlayer then return 0 end

        local remote = rf.GetOwnerPlayer
        local total = 0
        for _, model in ipairs(bay:GetChildren()) do
            if model:IsA("Model") and model.Name == name then
                if self.mountOwnerCache[model] == nil then
                    local ok, owner = pcall(remote.InvokeServer, remote, model)
                    self.mountOwnerCache[model] = ok and owner == LocalPlayer or false
                end
                if self.mountOwnerCache[model] then total = total + 1 end
            end
        end
        return total
    end

    MountBox:AddButton("Spawn Mount", function()

        task.spawn(function()

            if self.destroyed then return end

            local name = selectedMount()

            if not name or name == "(none)" then
                self.statusLabel:SetText("Status : pick a helicopter")
                return
            end

            if not self.spawnMount then
                self.statusLabel:SetText("Status : SpawnMount missing")
                return
            end

            if mountIsOwned(name) == false then
                self.statusLabel:SetText("Status : not owned, server refuses")
                return
            end

            if mountOutCount(name) > 0 then
                self.statusLabel:SetText("Status : " .. name .. " already out")
                return
            end

            self.statusLabel:SetText("Status : spawning " .. name)

            pcall(function() self.spawnMount:FireServer(name) end)
            task.wait(2.5)

            if self.destroyed then return end

            if mountOutCount(name) > 0 then
                self.statusLabel:SetText("Status : " .. name .. " spawned")
            else
                self.statusLabel:SetText("Status : " .. name .. " refused")
            end

        end)

    end)

    MountBox:AddButton("Refresh List", function()

        task.spawn(function()

            if self.destroyed then return end
            table.clear(self.mountOwned)
            self.allMounts = buildMountList()
            refreshMountOwnership()
            refreshMountOptions()

        end)

    end)

    MountBox:AddLabel("Server keeps one mount out at a time.")

    task.spawn(function()

        if self.destroyed then return end

        self.mountService, self.mountInfoService = getMountServiceParts()

        local re = self.mountService and self.mountService:FindFirstChild("RE")
        local info = self.mountInfoService and self.mountInfoService:FindFirstChild("RF")

        self.spawnMount = re and re:FindFirstChild("SpawnMount")
        self.mountInfoRf = info
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        local knitModule = packages and packages:FindFirstChild("Knit")
        local ok, knit = pcall(require, knitModule)
        if ok and type(knit) == "table" then
            local okController, controller = pcall(knit.GetController, "MountInfoController")
            self.mountController = okController and controller or nil
        end

        if not self.spawnMount then
            self.infoLabel:SetText("Helicopters : SpawnMount missing")
            return
        end

        refreshMountOwnership()
        for _ = 1, 10 do

            if self.destroyed then return end

            task.wait(1.5)

            local known = 0
            for _, mount in ipairs(self.allMounts) do
                if self.mountOwned[mount] ~= nil then known = known + 1 end
            end

            if known > 0 then
                refreshMountOwnership()
                refreshMountOptions()
                break
            end

        end

    end)

end


return Mounts
