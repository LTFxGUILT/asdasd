
--[[
  ChatLogger - fixed hooks for TextChatService + legacy chat
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local ChatLogger = {}
ChatLogger.__index = ChatLogger

local function disconnect(connection)
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

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

function ChatLogger.new(options)
    options = options or {}
    local self = setmetatable({}, ChatLogger)
    self.Tabs = options.Tabs
    self.Toggles = options.Toggles or {}
    self.Library = options.Library
    self.ThemeManager = options.ThemeManager
    assert(self.Tabs and self.Tabs.Misc, "[ChatLogger] Tabs.Misc is required")
    assert(self.Library, "[ChatLogger] Library is required")
    self.Enabled = false
    self.MaxLines = 100
    self.Opacity = 0.90
    self.SizeScale = 1
    self.Lines = {}
    self.Gui = nil
    self.Frame = nil
    self.Title = nil
    self.Close = nil
    self.Divider = nil
    self.Scroll = nil
    self.Label = nil
    self.TextConnection = nil
    self.ChannelConnections = {}
    self.PlayerAddedConnection = nil
    self.PlayerConnections = {}
    self.ThemeConnection = nil
    self.UnloadConnection = nil
    self.Initialized = false
    return self
end

function ChatLogger:_getThemeColors()
    local theme = self.ThemeManager
    local library = self.Library
    local sources = { theme, library }
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
    }
end

function ChatLogger:ApplyTheme()
    if not self.Frame then
        return
    end
    local colors = self:_getThemeColors()
    self.Frame.BackgroundColor3 = colors.Background
    self.Frame.BorderColor3 = colors.Accent
    if self.Title then
        self.Title.TextColor3 = colors.Font
    end
    if self.Close then
        self.Close.BackgroundColor3 = colors.Main
        self.Close.BorderColor3 = colors.Outline
        self.Close.TextColor3 = colors.Font
    end
    if self.Divider then
        self.Divider.BackgroundColor3 = colors.Accent
    end
    if self.Scroll then
        self.Scroll.BackgroundColor3 = colors.Background
        self.Scroll.BorderColor3 = colors.Outline
        self.Scroll.ScrollBarImageColor3 = colors.Accent
    end
    if self.Label then
        self.Label.TextColor3 = colors.Font
    end
end

function ChatLogger:ApplyVisuals()
    if not self.Frame then
        return
    end
    local width = math.floor(430 * self.SizeScale)
    local height = math.floor(330 * self.SizeScale)
    local transparency = 1 - self.Opacity
    self.Frame.Size = UDim2.fromOffset(width, height)
    self.Frame.Position = UDim2.new(1, -width - 20, 0.5, -math.floor(height / 2))
    self.Frame.BackgroundTransparency = transparency
    if self.Scroll then
        self.Scroll.BackgroundTransparency = transparency
    end
    self:ApplyTheme()
end

function ChatLogger:UpdateLog()
    if not self.Label or not self.Scroll then
        return
    end
    self.Label.Text = #self.Lines > 0 and table.concat(self.Lines, "\n") or "No messages logged."
    task.defer(function()
        if not self.Scroll or not self.Label then
            return
        end
        local height = self.Label.TextBounds.Y + 12
        self.Scroll.CanvasSize = UDim2.fromOffset(0, height)
        self.Scroll.CanvasPosition = Vector2.new(
            0,
            math.max(0, self.Scroll.CanvasSize.Y.Offset - self.Scroll.AbsoluteWindowSize.Y)
        )
    end)
end

function ChatLogger:AddMessage(name, message)
    if type(message) ~= "string" or message == "" then
        return
    end
    -- strip rich text tags if any
    message = message:gsub("<[^>]+>", "")
    if message == "" then
        return
    end
    table.insert(self.Lines, "[" .. tostring(name) .. "] " .. message)
    while #self.Lines > self.MaxLines do
        table.remove(self.Lines, 1)
    end
    self:UpdateLog()
end

function ChatLogger:Clear()
    table.clear(self.Lines)
    self:UpdateLog()
end

function ChatLogger:_nameFromSource(source)
    if not source then
        return "System"
    end
    local ok, player = pcall(function()
        return Players:GetPlayerByUserId(source.UserId)
    end)
    if ok and player then
        local name = player.DisplayName
        if not name or name == "" then
            name = player.Name
        end
        return name
    end
    if source.Name and source.Name ~= "" then
        return source.Name
    end
    return "System"
end

function ChatLogger:_onTextChatMessage(message)
    if not message then
        return
    end
    local text = message.Text
    if type(text) ~= "string" or text == "" then
        return
    end
    -- Status messages still useful; keep them
    local name = self:_nameFromSource(message.TextSource)
    self:AddMessage(name, text)
end

function ChatLogger:_hookChannel(channel)
    if not channel or self.ChannelConnections[channel] then
        return
    end
    if not channel:IsA("TextChannel") then
        return
    end
    local ok, conn = pcall(function()
        return channel.MessageReceived:Connect(function(message)
            self:_onTextChatMessage(message)
        end)
    end)
    if ok and conn then
        self.ChannelConnections[channel] = conn
    end
end

function ChatLogger:_connectPlayer(player)
    if self.PlayerConnections[player] then
        disconnect(self.PlayerConnections[player])
    end
    -- Legacy path (still fires in some places)
    local ok, conn = pcall(function()
        return player.Chatted:Connect(function(message)
            local name = player.DisplayName
            if not name or name == "" then
                name = player.Name
            end
            self:AddMessage(name, message)
        end)
    end)
    if ok and conn then
        self.PlayerConnections[player] = conn
    end
end

function ChatLogger:_disconnectPlayers()
    for player, connection in pairs(self.PlayerConnections) do
        disconnect(connection)
        self.PlayerConnections[player] = nil
    end
    for channel, connection in pairs(self.ChannelConnections) do
        disconnect(connection)
        self.ChannelConnections[channel] = nil
    end
end

function ChatLogger:_InstallChatHooks()
    -- 1) Legacy Player.Chatted
    for _, player in ipairs(Players:GetPlayers()) do
        self:_connectPlayer(player)
    end
    self.PlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
        self:_connectPlayer(player)
    end)

    -- 2) TextChatService.MessageReceived (modern default)
    pcall(function()
        self.TextConnection = TextChatService.MessageReceived:Connect(function(message)
            self:_onTextChatMessage(message)
        end)
    end)

    -- 3) Every TextChannel under TextChatService
    pcall(function()
        local function scan(root)
            for _, inst in ipairs(root:GetDescendants()) do
                if inst:IsA("TextChannel") then
                    self:_hookChannel(inst)
                end
            end
        end
        scan(TextChatService)
        TextChatService.DescendantAdded:Connect(function(inst)
            if inst:IsA("TextChannel") then
                self:_hookChannel(inst)
            end
        end)
    end)

    -- 4) Optional: OnIncomingMessage callback chain (does not replace others)
    pcall(function()
        local previous = TextChatService.OnIncomingMessage
        TextChatService.OnIncomingMessage = function(message)
            pcall(function()
                self:_onTextChatMessage(message)
            end)
            if typeof(previous) == "function" then
                return previous(message)
            end
            return nil
        end
    end)
end

function ChatLogger:CreatePopout()
    self:DestroyPopout()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TestingChatLogger"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui
    self.Gui = gui

    local frame = Instance.new("Frame")
    frame.Name = "Logger"
    frame.Size = UDim2.fromOffset(430, 330)
    frame.Position = UDim2.new(1, -450, 0.5, -165)
    frame.BorderSizePixel = 1
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    self.Frame = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -44, 0, 30)
    title.Position = UDim2.fromOffset(8, 2)
    title.BackgroundTransparency = 1
    title.Text = "Chat Logger"
    title.Font = Enum.Font.Code
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    self.Title = title

    local close = Instance.new("TextButton")
    close.Name = "Close"
    close.Size = UDim2.fromOffset(28, 24)
    close.Position = UDim2.new(1, -32, 0, 4)
    close.BorderSizePixel = 1
    close.Text = "X"
    close.Font = Enum.Font.Code
    close.TextSize = 14
    close.Parent = frame
    self.Close = close
    close.MouseButton1Click:Connect(function()
        self.Enabled = false
        self:DestroyPopout()
        pcall(function()
            local toggle = self.Toggles["ChatLoggerEnabled"]
            if toggle and toggle.SetValue then
                toggle:SetValue(false)
            end
        end)
    end)

    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Size = UDim2.new(1, -16, 0, 1)
    divider.Position = UDim2.fromOffset(8, 31)
    divider.BorderSizePixel = 0
    divider.Parent = frame
    self.Divider = divider

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Messages"
    scroll.Size = UDim2.new(1, -16, 1, -48)
    scroll.Position = UDim2.fromOffset(8, 40)
    scroll.BorderSizePixel = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.fromOffset(0, 0)
    scroll.Parent = frame
    self.Scroll = scroll

    local label = Instance.new("TextLabel")
    label.Name = "Log"
    label.Size = UDim2.new(1, -12, 0, 0)
    label.Position = UDim2.fromOffset(6, 6)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.Text = "No messages logged."
    label.Font = Enum.Font.Code
    label.TextSize = 14
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Parent = scroll
    self.Label = label

    self:ApplyVisuals()
    self:UpdateLog()
end

function ChatLogger:DestroyPopout()
    if self.Gui then
        pcall(function()
            self.Gui:Destroy()
        end)
    end
    self.Gui = nil
    self.Frame = nil
    self.Title = nil
    self.Close = nil
    self.Divider = nil
    self.Scroll = nil
    self.Label = nil
end

function ChatLogger:SetEnabled(value)
    self.Enabled = value == true
    if self.Enabled then
        self:CreatePopout()
    else
        self:DestroyPopout()
    end
end

function ChatLogger:_InstallControls()
    local box
    if self.Tabs.Misc.AddLeftGroupbox then
        box = self.Tabs.Misc:AddLeftGroupbox("Chat Logger")
    elseif self.Tabs.Misc.AddGroupbox then
        box = self.Tabs.Misc:AddGroupbox({ Side = 1, Name = "Chat Logger" })
    else
        box = self.Tabs.Misc:AddRightGroupbox("Chat Logger")
    end

    local function addToggle(flag, opts)
        local t = box:AddToggle(flag, opts)
        self.Toggles[flag] = t
        return t
    end

    addToggle("ChatLoggerEnabled", {
        Text = "Pop Out Chat Logger",
        Default = false,
        Callback = function(value)
            self:SetEnabled(value)
        end,
    })
    box:AddSlider("ChatLoggerMaxLines", {
        Text = "Max Lines",
        Min = 10,
        Max = 250,
        Rounding = 0,
        Default = 100,
        Callback = function(value)
            self.MaxLines = value
            while #self.Lines > self.MaxLines do
                table.remove(self.Lines, 1)
            end
            self:UpdateLog()
        end,
    })
    box:AddSlider("ChatLoggerOpacity", {
        Text = "Opacity",
        Min = 20,
        Max = 100,
        Rounding = 0,
        Default = 90,
        Callback = function(value)
            self.Opacity = value / 100
            self:ApplyVisuals()
        end,
    })
    box:AddSlider("ChatLoggerSize", {
        Text = "Size",
        Min = 60,
        Max = 150,
        Rounding = 0,
        Default = 100,
        Callback = function(value)
            self.SizeScale = value / 100
            self:ApplyVisuals()
        end,
    })
    box:AddButton("Clear Log", function()
        self:Clear()
    end)
end

function ChatLogger:_InstallThemeUpdater()
    self.ThemeConnection = RunService.Heartbeat:Connect(function()
        if not self.Frame then
            return
        end
        self._ThemeAccumulator = (self._ThemeAccumulator or 0) + 1 / 60
        if self._ThemeAccumulator < 0.25 then
            return
        end
        self._ThemeAccumulator = 0
        pcall(function()
            self:ApplyTheme()
        end)
    end)
end

function ChatLogger:_InstallUnload()
    self.UnloadConnection = self.Library:OnUnload(function()
        self:Destroy()
    end)
end

function ChatLogger:Init()
    if self.Initialized then
        return self
    end
    self.Initialized = true
    self:_InstallControls()
    self:_InstallChatHooks()
    self:_InstallThemeUpdater()
    self:_InstallUnload()
    return self
end

function ChatLogger:Destroy()
    self.Enabled = false
    disconnect(self.TextConnection)
    disconnect(self.PlayerAddedConnection)
    disconnect(self.ThemeConnection)
    self.TextConnection = nil
    self.PlayerAddedConnection = nil
    self.ThemeConnection = nil
    self:_disconnectPlayers()
    self:DestroyPopout()
    self.Initialized = false
end

return ChatLogger
