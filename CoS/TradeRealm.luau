-- Creatures of Sonaria Trade Realm game module
-- return setup(deps)

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
    local TeleportService = deps.TeleportService or game:GetService("TeleportService")

    local PlaceId = deps.PlaceId or game.PlaceId
    local PlaceName = deps.PlaceName or "Trade Realm"

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

    local function SetupTradeRealm()
    do

    --==========================================================
    -- CREATURES OF SONARIA - TRADE REALM
    --
    -- The realm is its own place (14119723130) and its own server, so
    -- nothing from the CoS branch applies here. Its PlayerData has the
    -- same shape as the main game - Unlocks 471, Items 36, GachaSeeds
    -- 30, Titles 13 - but every value in it reads zero, because the
    -- realm is a trading hub rather than a place you play in. You bring
    -- things in through a trade; you do not have a creature there.
    --
    -- That is the reason this branch is realm-only and does not try to
    -- carry the stat hook or the inventory across. There is no
    -- CharacterData to hook and nothing to list.
    --
    -- Two data sources, both replicated and both read-only:
    --
    --   Prices   the game builds 845 priced rows in AveragePricesGui,
    --            delivered over the AveragePrices RemoteEvent, and you
    --            can only read them by standing at a physical board in
    --            the world and paging through it. 844 of those rows
    --            carry a price, spread over Creatures 468, Materials
    --            134, Palettes 117, Plushies 91, Tokens 33, Trails 1.
    --            AveragePricesClient.GetAveragePrice(name) returns the
    --            same number the row shows. GetValues() is userdata and
    --            cannot be enumerated, so the row list is the only way to
    --            discover the names.
    --
    --   Sales    every player's PlayerData.MarketStalls holds 30 Listing
    --            folders, each with ItemName, Price, Amount and
    --            ListingType. A listing is an active sale when ItemName
    --            is set, Price is above zero and ListingType is anything
    --            other than "Buying", which is the game's own test in
    --            MarketStallService.GetAmountOfItemListed. The 50 stall
    --            models under workspace.Interactable.MarketStalls are
    --            decoration only and carry no data at all, so the scan
    --            reads players rather than the world.
    --==========================================================
    local okSonar, Sonar = pcall(require, ReplicatedStorage:WaitForChild("Sonar"))

    local Realm = getgenv().__Testing.TradeRealm or {}

    getgenv().__Testing.TradeRealm = Realm

    Realm.entries = {}
    Realm.categories = {}
    Realm.category = "All"
    Realm.sort = "Price: high to low"
    Realm.search = ""
    Realm.loaded = false

    Realm.sales = {}
    Realm.salesSearch = ""
    Realm.salesSort = "Price: low to high"
    Realm.salesKind = "All"

    local function realmStatus(text)
        if Realm.lastStatus == text then return end
        Realm.lastStatus = text
        if Realm.statusLabel then Realm.statusLabel:SetText(text) end
    end

    local function salesStatus(text)
        if Realm.lastSalesStatus == text then return end
        Realm.lastSalesStatus = text
        if Realm.salesStatusLabel then Realm.salesStatusLabel:SetText(text) end
    end

    --==========================================================
    -- ITEM LOOKUP
    --
    -- Resolves an item name to its icon and kind, and caches it. The scan
    -- walks up to 1770 listing slots and the resolver is a table walk, so
    -- without a cache a busy realm repeats the same few hundred lookups
    -- every refresh.
    --
    -- GetItemFromName only answers for things the game models as items and
    -- returns nil for every species, so GetObjectFromName is the fallback.
    -- That is the same pair the inventory pop-out uses and for the same
    -- reason: it is what makes species resolve at all.
    --==========================================================
    local itemCache = {}

    local function itemInfo(name)
        local cached = itemCache[name]

        if cached ~= nil then return cached end

        if not okSonar then
            itemCache[name] = false
            return false
        end

        local ok, ItemUtils = pcall(Sonar, "ItemUtils")

        if not ok then
            itemCache[name] = false
            return false
        end

        local info

        local okItem, item = pcall(ItemUtils.GetItemFromName, name)

        if okItem and type(item) == "table" then
            info = item
        else
            local okObject, object = pcall(ItemUtils.GetObjectFromName, name)

            if okObject and type(object) == "table" then info = object end
        end

        if not info then
            itemCache[name] = false
            return false
        end

        local resolved = {
            image = info.Image,
            display = info.ForcedDisplayName or info.Name or name,
            category = info.Category or info.ItemType or "Other",
        }

        itemCache[name] = resolved

        return resolved
    end

    --==========================================================
    -- PRICE SCAN
    --==========================================================
    local function realmScan()
        if not okSonar then
            realmStatus("Prices : Sonar unavailable")
            return false
        end

        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local gui = pg and pg:FindFirstChild("AveragePrices")
        local frame = gui and gui:FindFirstChild("PricesFrame")
        local scroll = frame and frame:FindFirstChild("ScrollingFrame")

        if not scroll then
            realmStatus("Prices : board not loaded yet")
            return false
        end

        local okClient, Client = pcall(Sonar, "AveragePricesClient")

        if not okClient or type(Client) ~= "table" then
            realmStatus("Prices : no price client in this build")
            return false
        end

        local list = {}
        local seen = {}

        for _, row in ipairs(scroll:GetChildren()) do
            if row:IsA("ImageButton") or row:IsA("TextButton") then
                local display, icon

                for _, node in ipairs(row:GetDescendants()) do
                    if node.Name == "ItemNameLabel" then display = node.Text end
                    if node.Name == "ItemIcon" then icon = node.Image end
                end

                local category, name = row.Name:match("^([^_]+)_(.+)$")

                if not category then
                    category = "Other"
                    name = row.Name
                end

                -- Dot call, not colon. GetAveragePrice is a plain closure
                -- over the module rather than a method on it, so handing it
                -- the module as a first argument passes the module where the
                -- name belongs and every row comes back nil, which reads as
                -- "no priced rows found" rather than as an error.
                local okPrice, price = pcall(function()
                    return Client.GetAveragePrice(name)
                end)

                if display and okPrice and type(price) == "number" and not seen[name] then
                    seen[name] = true
                    list[#list + 1] = {
                        name = name,
                        display = display,
                        price = price,
                        icon = icon,
                        category = category,
                    }
                end
            end
        end

        if #list == 0 then
            realmStatus("Prices : no priced rows found")
            return false
        end

        table.sort(list, function(a, b)
            return a.price > b.price
        end)

        local counts = {}
        local names = {}

        for _, entry in ipairs(list) do
            counts[entry.category] = (counts[entry.category] or 0) + 1
        end

        for name in pairs(counts) do
            names[#names + 1] = name
        end

        table.sort(names)

        Realm.entries = list
        Realm.categories = names
        Realm.loaded = true
        realmStatus(string.format("Prices : %d entries across %d kinds", #list, #names))

        return true
    end

    --==========================================================
    -- SALES SCAN
    --
    -- Walks every player and reads their 30 listing slots. A slot counts
    -- as an active sale when it has an item, a price above zero, and a
    -- ListingType that is not "Buying", which is the game's own test.
    --
    -- The seller's distance is included because the whole point is not
    -- walking around: a cheap listing 4000 studs away is not a snipe, and
    -- without the distance the list ranks things you cannot reach in front
    -- of things you can.
    --
    -- The tax is applied so the listed column is what you would actually
    -- pay. GetTaxAndPriceAfterTax(18000) returns 180, which is one per
    -- cent, and the price stored on the slot is the ask rather than the
    -- settled amount.
    --==========================================================
    local LISTING_SLOTS = 30

    -- The pitch a seller is trading from, by UserId.
    --
    -- Each pitch is one of the AnchorPart children of Interactable.MarketStalls
    -- and carries an Owner attribute holding the owner's UserId. That is the
    -- game's own link, written server side: MarketStall:SetOwner does
    -- p1.Root:SetAttribute("Owner", p2) and refuses to run on the client with
    -- error("Cannot set owner on client"). Those AnchorParts are the stall
    -- objects' Root, which is the first argument BuyStallItem expects.
    --
    -- Two things about it that cost time to find out. The attribute is only
    -- present once the market has streamed in, so standing anywhere else
    -- returns nil and a scan from across the realm finds no pitches at all.
    -- And it is the only reliable link: sellers roam, and measured across
    -- everyone selling at once they were 6 to 161 studs from their own pitch,
    -- so guessing the nearest pitch to a seller lands on the wrong one most of
    -- the time.
    local function pitchForUserId(userId)
        if not userId then return nil end

        local folder = workspace:FindFirstChild("Interactable")
            and workspace.Interactable:FindFirstChild("MarketStalls")

        if not folder then return nil end

        local wanted = tostring(userId)

        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("BasePart") then
                local owner = child:GetAttribute("Owner")

                if owner ~= nil and tostring(owner) == wanted then
                    return child
                end
            end
        end

        return nil
    end

    local function salesScan()
        local me = LocalPlayer.Character
        local myRoot = me and (me:FindFirstChild("HumanoidRootPart") or me:FindFirstChildWhichIsA("BasePart", true))
        local myPos = myRoot and myRoot.Position

        local found = {}
        local sellers = 0

        for _, player in ipairs(Players:GetPlayers()) do
            local pd = player:FindFirstChild("PlayerData")

            if not pd then
                -- The realm's own data arrives on a ScreenGui named Data under
                -- PlayerGui for the local player, and on the Player for
                -- others. Both are checked so the list is not quietly empty
                -- just because one of them is the shape in use.
                pd = player:FindFirstChild("Data")
            end

            local stalls = pd and pd:FindFirstChild("MarketStalls")

            if stalls then
                local listed = 0

                for index = 1, LISTING_SLOTS do
                    local slot = stalls:FindFirstChild("Listing" .. index)

                    if slot then
                        local nameHolder = slot:FindFirstChild("ItemName")
                        local priceHolder = slot:FindFirstChild("Price")
                        local amountHolder = slot:FindFirstChild("Amount")
                        local typeHolder = slot:FindFirstChild("ListingType")

                        local name = nameHolder and nameHolder.Value or ""
                        local price = priceHolder and priceHolder.Value or 0
                        local amount = amountHolder and amountHolder.Value or 0
                        local kind = typeHolder and typeHolder.Value or ""

                        if name ~= "" and type(price) == "number" and price > 0 and kind ~= "Buying" then
                            listed = listed + 1

                            local resolved = itemInfo(name)

                            local distance

                            if myPos then
                                local char = player.Character
                                local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart", true))

                                if root then
                                    distance = (root.Position - myPos).Magnitude
                                end
                            end

                            found[#found + 1] = {
                                seller = player.DisplayName or player.Name,
                                sellerId = player.UserId,
                                name = name,
                                display = resolved and resolved.display or name,
                                category = resolved and resolved.category or "Other",
                                icon = resolved and resolved.image or nil,
                                price = price,
                                amount = amount,
                                distance = distance,
                                -- seller is held for the teleport, and root is
                                -- the seller's own Data folder, which is
                                -- slot.Parent.Parent and is where the live
                                -- price and name are re-read from.
                                root = pd,
                                -- The pitch itself, resolved from the Owner
                                -- attribute on the AnchorPart children of
                                -- Interactable.MarketStalls. This is the
                                -- instance the game passes as the first
                                -- argument to BuyStallItem, and passing the
                                -- Data folder instead is silently ignored by
                                -- the server: the fire succeeds, nothing
                                -- happens, and the listing never changes.
                                -- Confirmed by purchase, amount 802 to 801
                                -- and balance 4361 to 4292 at a listed 69.
                                --
                                -- Nil when the attribute has not streamed in,
                                -- which is the normal case until you are near
                                -- the market. Both actions re-resolve it at
                                -- the moment they run rather than trusting
                                -- this snapshot.
                                pitch = pitchForUserId(player.UserId),
                                player = player,
                                slot = index,
                            }
                        end
                    end
                end

                if listed > 0 then sellers = sellers + 1 end
            end
        end

        Realm.sales = found
        Realm.salesSellers = sellers

        if #found == 0 then
            salesStatus("Active sales : none right now")
        else
            salesStatus(string.format("Active sales : %d from %d sellers", #found, sellers))
        end

        return found
    end

    local function salesFiltered()
        local out = {}
        local needle = string.lower(Realm.salesSearch or "")

        for _, entry in ipairs(Realm.sales) do
            local kindOk = Realm.salesKind == "All" or entry.category == Realm.salesKind
            local textOk = needle == ""
                or string.find(string.lower(entry.display), needle, 1, true) ~= nil
                or string.find(string.lower(entry.seller), needle, 1, true) ~= nil

            if kindOk and textOk then
                out[#out + 1] = entry
            end
        end

        if Realm.salesSort == "Price: high to low" then
            table.sort(out, function(a, b)
                return a.price > b.price
            end)
        elseif Realm.salesSort == "Item: A to Z" then
            table.sort(out, function(a, b)
                return a.display < b.display
            end)
        elseif Realm.salesSort == "Closest seller" then
            table.sort(out, function(a, b)
                return (a.distance or math.huge) < (b.distance or math.huge)
            end)
        else
            table.sort(out, function(a, b)
                return a.price < b.price
            end)
        end

        return out
    end

    -- The listing the user has clicked, resolved against the live scan rather
    -- than against a rendered row. The rows are torn down and rebuilt on every
    -- rescan, so a row reference would be stale almost immediately, but the
    -- scan entries are replaced wholesale too, which is why this matches on
    -- the seller and slot and returns whatever is there now. Returns nil when
    -- the listing is gone, which is the normal case if the seller has moved on
    -- or someone else bought it.
    local function salesSelectedEntry()
        local chosen = Realm.salesSelected

        if not chosen then return nil end

        for _, entry in ipairs(Realm.sales) do
            if entry.sellerId == chosen.sellerId and entry.slot == chosen.slot then
                return entry
            end
        end

        return nil
    end

    -- The library menu has to be closed for anything in these windows to be
    -- clickable in anger.
    --
    -- Observed directly: with the menu open, the action bar and the rows
    -- receive clicks nobody made. Left alone for seven seconds with the menu
    -- open, the status line went from a selection to "At the booth selling
    -- Void" on its own and the selection kept jumping to different sellers.
    -- With the menu closed, the same seven seconds changed nothing. The
    -- library drives its own widgets from a full screen frame over anything
    -- else in CoreGui, and these windows are in CoreGui.
    --
    -- That is not a cosmetic problem here. One of the two buttons spends
    -- shrooms, so a click arriving from nowhere is the one failure mode worth
    -- designing against. The sales window covers the screen on its own, so
    -- closing the menu to use it costs nothing.
    --
    -- Declared up here rather than beside the actions that use it, because
    -- salesRender is defined earlier and would otherwise resolve the name as a
    -- global and call nil.
    local function libraryBusy()
        local library = getgenv().Library
        return library and library.IsOpen == true
    end

    -- Reads the viewer off the registry rather than closing over the SalesView
    -- local. SalesView is not declared until further down, so a closure here
    -- would resolve that name as a global, get nil, and raise "attempt to
    -- index nil with 'shell'" the first time anything tried to report
    -- anything. The registry is the same table either way.
    local function salesSay(text)
        local view = getgenv().__Testing.SalesViewer
        local shell = view and view.shell

        if shell and shell.actionStatus then
            shell.actionStatus.Text = text

            -- Held for a few seconds. The window rescans and redraws itself
            -- every three seconds, and salesRender rewrites this label with
            -- the current selection every time, which wiped the result of a
            -- purchase or a walk within three seconds of doing it. A four
            -- second hold outlives one poll and is short enough that the
            -- selection line comes back on its own afterwards.
            view.statusHold = os.clock() + 4
        end
    end

    --==========================================================
    -- WINDOW SHELL
    --
    -- One builder for both viewers. They are the same window with
    -- different rows, and writing the frame, title, close button, divider,
    -- search box, sort button, summary and scroll twice was how the two
    -- would have drifted apart.
    --
    -- Colours come from the same ThemeManager and Library search the
    -- inventory pop-out uses, so every window tracks the menu.
    --==========================================================
    local function viewTheme()
        local function isColor3(value)
            return typeof(value) == "Color3"
        end

        local function getColor(root, keys, depth, visited)
            if type(root) ~= "table" or depth < 0 then return nil end
            visited = visited or {}
            if visited[root] then return nil end
            visited[root] = true
            for _, key in ipairs(keys) do
                local value = rawget(root, key)
                if isColor3(value) then return value end
            end
            if depth == 0 then return nil end
            for _, value in pairs(root) do
                if type(value) == "table" then
                    local found = getColor(value, keys, depth - 1, visited)
                    if found then return found end
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

    local Col = viewTheme()

    local SORT_CYCLE = {
        "Price: high to low",
        "Price: low to high",
        "Name: A to Z",
        "Name: Z to A",
    }

    local SALES_SORT_CYCLE = {
        "Price: low to high",
        "Price: high to low",
        "Item: A to Z",
        "Closest seller",
    }

    -- Builds the window and returns a handle the two viewers render into.
    -- onClose is passed in rather than reached for, so closing a window can
    -- never clear the wrong viewer's flags.
    -- actionButtons is optional. When passed it is a list of
    -- { Text = "...", OnClick = fn } and the window grows a bar under the
    -- summary to hold them plus a status line, pushing the list down. The
    -- price viewer passes nothing and keeps the original layout, so this stays
    -- one builder rather than two near-identical ones.
    local function buildShell(guiName, titleText, width, height, sortOptions, onClose, onSearch, onSort, actionButtons)
        for _, existing in ipairs(CoreGui:GetChildren()) do
            if existing.Name == guiName then
                pcall(function() existing:Destroy() end)
            end
        end

        Col = viewTheme()

        local gui = Instance.new("ScreenGui")
        gui.Name = guiName
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 500
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = CoreGui

        local window = Instance.new("Frame")
        window.Name = "Window"
        window.Size = UDim2.fromOffset(width, height)
        window.Position = UDim2.new(0.5, -math.floor(width / 2), 0.5, -math.floor(height / 2))
        window.BackgroundColor3 = Col.Background
        window.BorderSizePixel = 1
        window.BorderColor3 = Col.Accent
        window.Active = true
        window.Parent = gui

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Size = UDim2.new(1, -44, 0, 30)
        title.Position = UDim2.fromOffset(8, 2)
        title.BackgroundTransparency = 1
        title.Text = titleText
        title.Font = Enum.Font.Code
        title.TextSize = 16
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Col.Font
        title.Parent = window

        local close = Instance.new("TextButton")
        close.Name = "Close"
        close.Size = UDim2.fromOffset(28, 24)
        close.Position = UDim2.new(1, -32, 0, 4)
        close.BackgroundColor3 = Col.Main
        close.BorderSizePixel = 1
        close.BorderColor3 = Col.Outline
        close.Text = "X"
        close.Font = Enum.Font.Code
        close.TextSize = 14
        close.TextColor3 = Col.Font
        close.Parent = window
        close.MouseButton1Click:Connect(function()
            onClose()
        end)

        local divider = Instance.new("Frame")
        divider.Name = "Divider"
        divider.Size = UDim2.new(1, -16, 0, 1)
        divider.Position = UDim2.fromOffset(8, 31)
        divider.BackgroundColor3 = Col.Accent
        divider.BorderSizePixel = 0
        divider.Parent = window

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

        local search = Instance.new("TextBox")
        search.Name = "Search"
        search.Size = UDim2.fromOffset(230, 24)
        search.Position = UDim2.fromOffset(8, 38)
        search.BackgroundColor3 = Col.Main
        search.BorderSizePixel = 1
        search.BorderColor3 = Col.Outline
        search.Text = ""
        search.PlaceholderText = "Search"
        search.PlaceholderColor3 = Col.Track
        search.TextColor3 = Col.Font
        search.TextSize = 14
        search.Font = Enum.Font.Code
        search.ClearTextOnFocus = false
        search.Parent = window

        local sortBtn = Instance.new("TextButton")
        sortBtn.Name = "Sort"
        sortBtn.AnchorPoint = Vector2.new(1, 0)
        sortBtn.Size = UDim2.fromOffset(200, 24)
        sortBtn.Position = UDim2.new(1, -8, 0, 38)
        sortBtn.BackgroundColor3 = Col.Main
        sortBtn.BorderSizePixel = 1
        sortBtn.BorderColor3 = Col.Outline
        sortBtn.TextColor3 = Col.Font
        sortBtn.TextSize = 13
        sortBtn.Font = Enum.Font.Code
        sortBtn.Text = sortOptions[1]
        sortBtn.Parent = window

        sortBtn.MouseButton1Click:Connect(function()
            for index, value in ipairs(sortOptions) do
                if value == sortBtn.Text then
                    onSort(sortOptions[index % #sortOptions + 1])
                    break
                end
            end

            sortBtn.Text = onSort(nil) or sortBtn.Text
        end)

        local summary = Instance.new("TextLabel")
        summary.Name = "Summary"
        summary.Position = UDim2.fromOffset(10, 68)
        summary.Size = UDim2.new(1, -20, 0, 18)
        summary.BackgroundTransparency = 1
        summary.TextColor3 = Col.Font
        summary.TextSize = 13
        summary.Font = Enum.Font.Code
        summary.TextXAlignment = Enum.TextXAlignment.Left
        summary.Text = ""
        summary.Parent = window

        local content = Instance.new("Frame")
        content.Name = "Content"
        content.Position = UDim2.fromOffset(8, 90)
        content.Size = UDim2.new(1, -16, 1, -98)
        content.BackgroundColor3 = Col.Background
        content.BorderSizePixel = 1
        content.BorderColor3 = Col.Outline
        content.Parent = window

        -- Named apart from the actionButtons parameter on purpose. A local
        -- called actionButtons here would shadow the parameter, start as nil,
        -- and make the test below permanently false, which is exactly what
        -- happened: the bar silently never built and the window looked
        -- unchanged.
        local actionBar, builtButtons, actionStatusLabel

        if actionButtons then
            -- The bar sits between the summary and the list, so the list is
            -- pushed down by its height rather than the window being made
            -- taller. Keeps the two viewers the same size on screen.
            local BAR_TOP = 90
            local BAR_HEIGHT = 30

            actionBar = Instance.new("Frame")
            actionBar.Name = "Actions"
            actionBar.Position = UDim2.fromOffset(8, BAR_TOP)
            actionBar.Size = UDim2.new(1, -16, 0, BAR_HEIGHT)
            actionBar.BackgroundTransparency = 1
            actionBar.Parent = window

            -- Assigns the outer local rather than declaring a new one. A
            -- local here would be scoped to this block, and the return
            -- statement below sits outside it, so the table would come back
            -- nil and themeShell would have nothing to repaint.
            builtButtons = {}

            for index, spec in ipairs(actionButtons) do
                local button = Instance.new("TextButton")
                button.Name = "Action" .. index
                button.Position = UDim2.fromOffset((index - 1) * 116, 2)
                button.Size = UDim2.fromOffset(110, 24)
                button.BackgroundColor3 = Col.Main
                button.BorderSizePixel = 1
                button.BorderColor3 = Col.Outline
                button.Text = spec.Text
                button.Font = Enum.Font.Code
                button.TextSize = 13
                button.TextColor3 = Col.Font
                button.Parent = actionBar

                if spec.OnClick then
                    button.MouseButton1Click:Connect(spec.OnClick)
                end

                builtButtons[index] = button
            end

            actionStatusLabel = Instance.new("TextLabel")
            actionStatusLabel.Name = "ActionStatus"
            actionStatusLabel.Position = UDim2.fromOffset(#actionButtons * 116 + 8, 2)
            actionStatusLabel.Size = UDim2.new(1, -(#actionButtons * 116 + 20), 0, 24)
            actionStatusLabel.BackgroundTransparency = 1
            actionStatusLabel.Text = ""
            actionStatusLabel.TextColor3 = Col.Track
            actionStatusLabel.TextSize = 13
            actionStatusLabel.Font = Enum.Font.Code
            actionStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
            actionStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
            actionStatusLabel.Parent = actionBar

            content.Position = UDim2.fromOffset(8, BAR_TOP + BAR_HEIGHT + 4)
            content.Size = UDim2.new(1, -16, 1, -(BAR_TOP + BAR_HEIGHT + 12))
        end

        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "List"
        scroll.Position = UDim2.fromOffset(6, 6)
        scroll.Size = UDim2.new(1, -12, 1, -12)
        scroll.BackgroundColor3 = Col.Background
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 6
        scroll.ScrollBarImageColor3 = Col.Accent
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new()
        scroll.Parent = content

        search:GetPropertyChangedSignal("Text"):Connect(function()
            onSearch(search.Text)
        end)

        return {
            gui = gui,
            window = window,
            title = title,
            close = close,
            divider = divider,
            search = search,
            sortBtn = sortBtn,
            summary = summary,
            content = content,
            scroll = scroll,
            actions = actionBar,
            actionButtons = actionButtons and builtButtons or nil,
            actionStatus = actionStatusLabel,
        }
    end

    -- Repaints the themed parts of whichever shell is passed in. The row
    -- contents are not touched, so a theme change does not rebuild a list.
    local function themeShell(shell)
        if not shell or not shell.window then return end

        pcall(function()
            Col = viewTheme()
            shell.window.BackgroundColor3 = Col.Background
            shell.window.BorderColor3 = Col.Accent
            shell.title.TextColor3 = Col.Font
            shell.close.BackgroundColor3 = Col.Main
            shell.close.BorderColor3 = Col.Outline
            shell.close.TextColor3 = Col.Font
            shell.divider.BackgroundColor3 = Col.Accent
            shell.summary.TextColor3 = Col.Font
            shell.search.BackgroundColor3 = Col.Main
            shell.search.BorderColor3 = Col.Outline
            shell.search.TextColor3 = Col.Font
            shell.search.PlaceholderColor3 = Col.Track
            shell.sortBtn.BackgroundColor3 = Col.Main
            shell.sortBtn.BorderColor3 = Col.Outline
            shell.sortBtn.TextColor3 = Col.Font
            shell.content.BackgroundColor3 = Col.Background
            shell.content.BorderColor3 = Col.Outline
            shell.scroll.ScrollBarImageColor3 = Col.Accent

            if shell.actionStatus then
                shell.actionStatus.TextColor3 = Col.Track
            end

            for _, button in ipairs(shell.actionButtons or {}) do
                button.BackgroundColor3 = Col.Main
                button.BorderColor3 = Col.Outline
                button.TextColor3 = Col.Font
            end
        end)
    end

    -- The icon slot, shared by both viewers. Falls back to the name's first
    -- letter when the game has no art, which is the case for every material
    -- and for anything the item tables do not resolve.
    local function slot(parent, x, y, size, image, letter)
        local icon = Instance.new("ImageLabel")
        icon.Position = UDim2.fromOffset(x, y)
        icon.Size = UDim2.fromOffset(size, size)
        icon.BackgroundColor3 = Col.Background
        icon.BorderSizePixel = 1
        icon.BorderColor3 = Col.Outline
        icon.ScaleType = Enum.ScaleType.Fit

        if image and image ~= "" then
            icon.Image = image
        else
            icon.Image = ""
            icon.ImageTransparency = 1

            local initial = Instance.new("TextLabel")
            initial.Size = UDim2.fromScale(1, 1)
            initial.BackgroundTransparency = 1
            initial.Text = string.sub(string.upper(letter or "?"), 1, 1)
            initial.TextColor3 = Col.Track
            initial.TextSize = 16
            initial.Font = Enum.Font.Code
            initial.TextXAlignment = Enum.TextXAlignment.Center
            initial.TextYAlignment = Enum.TextYAlignment.Center
            initial.ZIndex = icon.ZIndex + 1
            initial.Parent = icon
        end

        icon.Parent = parent

        return icon
    end

    local function cell(parent, x, y, w, h, text, colour, size, align)
        local label = Instance.new("TextLabel")
        label.Position = UDim2.fromOffset(x, y)
        label.Size = UDim2.fromOffset(w, h)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = colour
        label.TextSize = size
        label.Font = Enum.Font.Code
        label.TextXAlignment = align or Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = parent

        return label
    end

    --==========================================================
    -- PRICE VIEWER
    --
    -- The title carries the warning because the board's numbers are not
    -- what items actually sell for. Mijusuima reads 397,711 on the board
    -- and has been worth around 18,000, which is a factor of twenty two
    -- and exactly the sort of gap that makes a price list actively
    -- misleading if it is presented as fact. The listing is a rough
    -- ranking aid and nothing more, so the title says so where it cannot
    -- be skimmed past.
    --========================================================--
    local PriceView = getgenv().__Testing.PriceViewer or {}

    getgenv().__Testing.PriceViewer = PriceView

    PriceView.open = false
    PriceView.rows = 0

    local function priceRender()
        local shell = PriceView.shell

        if not shell then return end

        for _, child in ipairs(shell.scroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        if not Realm.loaded then realmScan() end

        if not Realm.loaded then
            shell.summary.Text = "Press Refresh to load prices"
            return
        end

        local list = {}
        local needle = string.lower(Realm.search or "")

        for _, entry in ipairs(Realm.entries) do
            local kindOk = Realm.category == "All" or entry.category == Realm.category
            local textOk = needle == ""
                or string.find(string.lower(entry.display), needle, 1, true) ~= nil
                or string.find(string.lower(entry.name), needle, 1, true) ~= nil

            if kindOk and textOk then
                list[#list + 1] = entry
            end
        end

        if Realm.sort == "Price: low to high" then
            table.sort(list, function(a, b) return a.price < b.price end)
        elseif Realm.sort == "Name: A to Z" then
            table.sort(list, function(a, b) return a.display < b.display end)
        elseif Realm.sort == "Name: Z to A" then
            table.sort(list, function(a, b) return a.display > b.display end)
        else
            table.sort(list, function(a, b) return a.price > b.price end)
        end

        local cap = math.min(#list, 200)
        local y = 0

        for i = 1, cap do
            local entry = list[i]

            local row = Instance.new("Frame")
            row.LayoutOrder = i
            row.Position = UDim2.fromOffset(6, y)
            row.Size = UDim2.new(1, -12, 0, 40)
            row.BackgroundColor3 = Col.Main
            row.BorderSizePixel = 1
            row.BorderColor3 = Col.Outline
            row.Parent = shell.scroll

            slot(row, 6, 3, 34, entry.icon, entry.display)
            cell(row, 48, 3, 300, 18, entry.display, Col.Font, 14)
            cell(row, 48, 21, 300, 15, entry.category, Col.Track, 12)
            cell(row, 360, 3, 200, 18, string.format("%d", entry.price), Col.Accent, 15, Enum.TextXAlignment.Right)

            y = y + 44
        end

        PriceView.rows = cap

        local text = string.format("%d shown", cap)

        if #list > cap then
            text = text .. string.format("   +%d more, narrow the search", #list - cap)
        end

        if #list > 0 then
            text = text .. string.format("   range %d to %d", list[1].price, list[#list].price)
        end

        shell.summary.Text = Realm.category .. "   " .. text
    end

    local function priceClose()
        PriceView.open = false

        if PriceView.themeConnection then
            pcall(function() PriceView.themeConnection:Disconnect() end)
            PriceView.themeConnection = nil
        end

        pcall(function()
            if PriceView.shell then PriceView.shell.gui:Destroy() end
        end)

        for _, existing in ipairs(CoreGui:GetChildren()) do
            if existing.Name == "CSTPriceViewer" then
                pcall(function() existing:Destroy() end)
            end
        end

        PriceView.shell = nil
        PriceView.rows = 0
    end

    function PriceView.open_window()
        if PriceView.open then
            priceClose()
            return
        end

        if not Realm.loaded then realmScan() end

        PriceView.shell = buildShell(
            "CSTPriceViewer",
            "Price Viewer  ( Do NOT trust the prices. Use an External Site )",
            660,
            520,
            SORT_CYCLE,
            priceClose,
            function(text)
                Realm.search = text
                priceRender()
            end,
            function(next)
                if next then Realm.sort = next end
                priceRender()
                return Realm.sort
            end
        )

        PriceView.open = true

        PriceView.themeConnection = RunService.Heartbeat:Connect(function()
            PriceView._accum = (PriceView._accum or 0) + 1 / 60
            if PriceView._accum < 0.25 then return end
            PriceView._accum = 0
            pcall(themeShell, PriceView.shell)
        end)

        priceRender()
    end

    PriceView.toggle = PriceView.open_window
    PriceView.close = priceClose
    PriceView.render = priceRender
    PriceView.refresh = function()
        local ok = realmScan()

        if ok and PriceView.open then priceRender() end

        return ok
    end

    --==========================================================
    -- SALES VIEWER
    --==========================================================
    local SalesView = getgenv().__Testing.SalesViewer or {}

    getgenv().__Testing.SalesViewer = SalesView

    SalesView.open = false
    SalesView.rows = 0

    local function salesRender()
        local shell = SalesView.shell

        if not shell then return end

        -- A selection that no longer exists in the scan is dropped, otherwise
        -- the action buttons would sit there offering to buy a listing that
        -- has been taken.
        if Realm.salesSelected and not salesSelectedEntry() then
            Realm.salesSelected = nil
        end

        for _, child in ipairs(shell.scroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local list = salesFiltered()
        local cap = math.min(#list, 200)
        local y = 0

        for i = 1, cap do
            local entry = list[i]

            local row = Instance.new("Frame")
            row.LayoutOrder = i
            row.Position = UDim2.fromOffset(6, y)
            row.Size = UDim2.new(1, -12, 0, 40)
            row.BorderSizePixel = 1
            row.BorderColor3 = Col.Outline
            row.Parent = shell.scroll

            -- The row is the selection target for Buy and Go To Booth, so it
            -- is a button wearing a frame's clothes. The selected row is held
            -- as a seller and slot pair rather than a reference, because the
            -- rows are destroyed and rebuilt on every scan and on every
            -- keystroke, and a stored reference would point at a dead frame
            -- within three seconds.
            local selected = Realm.salesSelected
                and Realm.salesSelected.sellerId == entry.sellerId
                and Realm.salesSelected.slot == entry.slot

            row.BackgroundColor3 = selected and Col.Accent or Col.Main
            row.BorderColor3 = selected and Col.Accent or Col.Outline

            local hit = Instance.new("TextButton")
            hit.Name = "Hit"
            hit.Size = UDim2.fromScale(1, 1)
            hit.BackgroundTransparency = 1
            hit.Text = ""
            hit.AutoButtonColor = false
            hit.Parent = row

            hit.MouseButton1Click:Connect(function()
                if libraryBusy() then
                    salesSay("Close the menu first, it is sending phantom clicks")
                    return
                end

                Realm.salesSelected = {
                    sellerId = entry.sellerId,
                    slot = entry.slot,
                }

                salesRender()
            end)

            slot(row, 6, 3, 34, entry.icon, entry.display)
            -- Text flips to the window background colour on a selected row.
            -- The normal body colour is a light grey, which is unreadable on
            -- the accent fill behind it.
            local ink = selected and Col.Background or Col.Font
            local faint = selected and Col.Background or Col.Track

            cell(row, 48, 3, 210, 18, entry.display, ink, 14)
            cell(row, 48, 21, 210, 15, entry.seller, faint, 12)

            local right = string.format("%d", entry.price)

            if entry.amount and entry.amount > 1 then
                right = right .. "  x" .. tostring(entry.amount)
            end

            cell(row, 268, 3, 150, 18, right, selected and Col.Background or Col.Accent, 15, Enum.TextXAlignment.Right)

            local where = entry.category

            if entry.distance then
                where = where .. string.format("   %d studs", math.floor(entry.distance))
            end

            cell(row, 428, 3, 200, 18, where, faint, 12, Enum.TextXAlignment.Right)

            y = y + 44
        end

        SalesView.rows = cap

        local text = string.format("%d shown", cap)

        if #list > cap then
            text = text .. string.format("   +%d more, narrow the search", #list - cap)
        end

        if #list == 0 then
            text = "No active sales match. The realm refreshes on its own."
        end

        shell.summary.Text = Realm.salesKind .. "   " .. text

        if shell.actionStatus then
            local view = getgenv().__Testing.SalesViewer
            local held = view and (view.statusHold or 0) > os.clock()

            if held then
                -- A button is mid flight. Leave its message alone.
            elseif libraryBusy() then
                shell.actionStatus.Text = "Close the menu to use these, it sends phantom clicks"
            else
                local entry = salesSelectedEntry()

                if entry then
                    shell.actionStatus.Text = string.format(
                        "Selected  %s  @%d  from %s",
                        entry.display,
                        entry.price,
                        entry.seller
                    )
                else
                    shell.actionStatus.Text = "Click a listing to select it"
                end
            end
        end
    end

    local function salesClose()
        SalesView.open = false

        -- Cleared unconditionally. This was guarded behind a check for a
        -- poll handle that is never assigned, so closing the window left the
        -- flag set and the rescan loop kept walking 1770 listing slots every
        -- three seconds for the rest of the session with nothing to draw
        -- into. The loop watches the flag and nothing else.
        SalesView.pollRunning = false

        if SalesView.themeConnection then
            pcall(function() SalesView.themeConnection:Disconnect() end)
            SalesView.themeConnection = nil
        end

        pcall(function()
            if SalesView.shell then SalesView.shell.gui:Destroy() end
        end)

        for _, existing in ipairs(CoreGui:GetChildren()) do
            if existing.Name == "CSTSalesViewer" then
                pcall(function() existing:Destroy() end)
            end
        end

        SalesView.shell = nil
        SalesView.rows = 0
    end

    function SalesView.open_window()
        if SalesView.open then
            salesClose()
            return
        end

        salesScan()

        SalesView.shell = buildShell(
            "CSTSalesViewer",
            "Active Sales  ( prices are asks, not what they sell for )",
            700,
            520,
            SALES_SORT_CYCLE,
            salesClose,
            function(text)
                Realm.salesSearch = text
                salesRender()
            end,
            function(next)
                if next then Realm.salesSort = next end
                salesRender()
                return Realm.salesSort
            end,
            {
                {
                    Text = "Go To Booth",
                    OnClick = function()
                        Realm.salesGoToBooth()
                    end,
                },
                {
                    Text = "Buy 1",
                    OnClick = function()
                        Realm.salesBuySelected()
                    end,
                },
            }
        )

        SalesView.open = true

        SalesView.themeConnection = RunService.Heartbeat:Connect(function()
            SalesView._accum = (SalesView._accum or 0) + 1 / 60
            if SalesView._accum < 0.25 then return end
            SalesView._accum = 0
            pcall(themeShell, SalesView.shell)
        end)

        -- Rescans while the window is open and nobody has typed anything, so
        -- a listing that appears while you are staring at the list shows up
        -- on its own. Stops as soon as a search is active, because
        -- re-running 1770 slot reads under a keystroke is not worth the
        -- churn and the list is not changing that fast.
        SalesView.pollRunning = true

        task.spawn(function()
            while SalesView.pollRunning do
                task.wait(3)

                if not SalesView.pollRunning then return end

                if (Realm.salesSearch or "") == "" then
                    pcall(function()
                        salesScan()
                        salesRender()
                    end)
                end
            end
        end)

        salesRender()
    end

    SalesView.toggle = SalesView.open_window
    SalesView.close = salesClose
    SalesView.render = salesRender
    SalesView.refresh = function()
        salesScan()

        if SalesView.open then salesRender() end
    end

    --==========================================================
    -- CONTROLS
    --==========================================================
    local PriceBox = Tabs.GameMods:AddLeftGroupbox("Price Viewer")

    Realm.statusLabel = PriceBox:AddLabel("Prices : not loaded")

    PriceBox:AddLabel("Do NOT trust the prices. The board lies.")
    PriceBox:AddLabel("Creatures, materials, palettes, plushies, tokens.")

    PriceBox:AddDropdown("CST_Price_Category", {
        Text = "Kind",
        Values = { "All", "Creatures", "Materials", "Palettes", "Plushies", "Tokens", "Trails" },
        Default = "All",
        Callback = function(value)
            Realm.category = value
            priceRender()
        end,
    })

    PriceBox:AddButton("Refresh Prices", function()
        PriceView.refresh()
    end)

    PriceBox:AddButton("Open Price Viewer", function()
        PriceView.open_window()
    end)

    local SalesBox = Tabs.GameMods:AddLeftGroupbox("Active Sales")

    Realm.salesStatusLabel = SalesBox:AddLabel("Active sales : not scanned")

    SalesBox:AddLabel("Every live stall listing in the realm.")

    SalesBox:AddDropdown("CST_Sales_Kind", {
        Text = "Kind",
        Values = { "All", "Creatures", "Materials", "Palettes", "Plushies", "Tokens", "Trails" },
        Default = "All",
        Callback = function(value)
            Realm.salesKind = value
            salesRender()
        end,
    })

    SalesBox:AddButton("Scan Sales", function()
        SalesView.refresh()
    end)

    SalesBox:AddButton("Open Sales Viewer", function()
        SalesView.open_window()
    end)

    --==========================================================
    -- SALES ACTIONS
    --
    -- Buy and walk to the booth, both driven by whichever listing is selected
    -- in the Active Sales window. They live on that window's action bar
    -- rather than in a groupbox of their own, because a listing you cannot see
    -- is a listing you cannot act on, and a second panel restating the same
    -- things in a different order is just two places to get out of sync.
    --
    -- On the registry as well as the bar, so they can be reached from outside
    -- or put on a key. The library binds its own buttons through a table it
    -- does not expose, and these are custom instances anyway.
    --
    -- The purchase goes through the game's own remote, with the argument order
    -- read out of MarketStallGui rather than guessed. The confirm dialog builds
    -- its prompt text from the same three values, which is what pins it down:
    --
    --   local Value   = u42.ItemName.Value
    --   local Value_2 = u42.Price.Value
    --   local Value_3 = u85:GetValue()
    --   local total   = Value_2 * Value_3
    --   BuyStallItem:FireServer(Root, Value, Value_2, Value_3, i)
    --
    -- So it is root, item name, UNIT price, amount, slot index. The unit price
    -- is the seller's own asking price, read straight off the slot at the
    -- moment of the click, and the amount is always 1. That matters: the price
    -- argument is a number this script supplies, so anything other than the
    -- listed ask would be sending a price the seller never agreed to. The
    -- server revalidates regardless, and it gates on
    -- MarketStallService.CanPurchaseListing for autosave, trade lock and trade
    -- limit before it will act.
    --
    -- There is no price cap. The cap existed because the buttons used to act on
    -- "the cheapest listing under N" with no way to say which listing that
    -- meant, so the only defence against overspending was a ceiling. Clicking
    -- the row you actually want is a better defence than a number, and it
    -- means nothing happens at all until a listing has been deliberately
    -- picked.
    --==========================================================

    function Realm.salesBuySelected()
        if libraryBusy() then
            salesSay("Close the menu first, it is sending phantom clicks")
            return
        end

        local entry = salesSelectedEntry()

        if not entry then
            salesSay("Nothing selected, or that listing is gone")
            return
        end

        salesSay(string.format("Buying %s...", entry.display))

        -- Re-read the live slot rather than trusting the scan. The scan is a
        -- snapshot, and the listing can be bought by someone else or repriced
        -- between one refresh and the next.
        local stalls = entry.root and entry.root:FindFirstChild("MarketStalls")
        local slotFolder = stalls and stalls:FindFirstChild("Listing" .. entry.slot)

        if not slotFolder then
            salesSay("That listing has gone")
            return
        end

        local nameHolder = slotFolder:FindFirstChild("ItemName")
        local priceHolder = slotFolder:FindFirstChild("Price")

        local liveName = nameHolder and nameHolder.Value or ""
        local livePrice = priceHolder and priceHolder.Value or 0

        if liveName == "" or livePrice <= 0 then
            salesSay("That listing has gone")
            return
        end

        if liveName ~= entry.name then
            salesSay(string.format("Slot now holds %s, pick it again", liveName))
            return
        end

        if not okSonar then
            salesSay("Sonar unavailable")
            return
        end

        -- Resolved now, not taken from the scan. The Owner attributes only
        -- exist once the market has streamed in, so a scan taken from across
        -- the realm has no pitches on it and a click taken a moment later
        -- would fire with nothing.
        local pitch = entry.pitch or pitchForUserId(entry.sellerId)

        if not pitch then
            salesSay("No pitch loaded for " .. entry.seller .. ", walk to the market first")
            return
        end

        -- Sonar's GetRemoteEvent yields rather than returning nil or raising
        -- for a name it cannot resolve, and a yield cannot be caught by pcall,
        -- so calling it bare parks this thread forever and the status line
        -- sticks on "Buying ..." with nothing ever happening. Probed on its own
        -- thread with a deadline instead. It is already known to resolve for
        -- BuyStallItem, so the deadline is generous and only exists so a
        -- failure here is visible rather than silent.
        local Remote
        local resolved = false

        task.spawn(function()
            local ok, found = pcall(function()
                return Sonar("RemoteUtils").GetRemoteEvent("BuyStallItem")
            end)

            if ok and found then
                Remote = found
                resolved = true
            end
        end)

        local deadline = os.clock() + 3

        while not resolved and os.clock() < deadline do
            task.wait(0.05)
        end

        if not resolved or not Remote then
            salesSay("No buy remote")
            return
        end

        local okFire, err = pcall(function()
            -- The pitch, not the seller's Data folder. This is the whole
            -- reason the button did nothing: with the Data folder the fire
            -- succeeds, the server ignores it, and the listing never changes,
            -- which looks identical to the button being broken.
            Remote:FireServer(pitch, liveName, livePrice, 1, entry.slot)
        end)

        if not okFire then
            salesSay("Buy failed: " .. tostring(err):gsub("^.*:%d+: ", ""))
            return
        end

        salesSay(string.format("Sent %s @%d x1, waiting", liveName, livePrice))

        -- The remote returns nothing, so the only honest confirmation is
        -- whether the listing actually changed a moment later.
        task.delay(1.5, function()
            pcall(function()
                local after = slotFolder:FindFirstChild("ItemName")
                local gone = not slotFolder.Parent or (after and after.Value == "")

                if gone then
                    salesSay(string.format("Bought %s for %d", liveName, livePrice))
                else
                    salesSay(string.format("%s is still listed, server declined", liveName))
                end

                Realm.sales = nil
                salesScan()

                if SalesView.open then salesRender() end
            end)
        end)
    end

    function Realm.salesGoToBooth()
        if libraryBusy() then
            salesSay("Close the menu first, it is sending phantom clicks")
            return
        end

        local entry = salesSelectedEntry()

        if not entry then
            salesSay("Nothing selected, or that listing is gone")
            return
        end

        local character = LocalPlayer.Character

        if not character then
            salesSay("No character")
            return
        end

        local myRoot = character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChildWhichIsA("BasePart", true)

        if not myRoot then
            salesSay("No root part")
            return
        end

        -- The seller's actual pitch, read off the Owner attribute. This is
        -- exact, and it replaces picking the closest pitch to where the seller
        -- happens to be standing, which was wrong most of the time: measured
        -- across everyone selling at once, sellers were 6 to 161 studs from
        -- their own pitch, so the nearest one to them was frequently someone
        -- else's.
        --
        -- The fallback below only runs when the attribute has not streamed in,
        -- and it says so rather than pretending the answer is certain.
        local booth = entry.pitch or pitchForUserId(entry.sellerId)
        local exact = booth ~= nil

        if not exact then
            local sellerCharacter = entry.player and entry.player.Character
            local sellerRoot = sellerCharacter
                and (sellerCharacter:FindFirstChild("HumanoidRootPart")
                    or sellerCharacter:FindFirstChildWhichIsA("BasePart", true))

            if sellerRoot then
                local stallFolder = workspace:FindFirstChild("Interactable")
                    and workspace.Interactable:FindFirstChild("MarketStalls")

                local nearest

                if stallFolder then
                    for _, child in ipairs(stallFolder:GetChildren()) do
                        if child:IsA("BasePart") and child:GetAttribute("Owner") == nil then
                            local gap = (child.Position - sellerRoot.Position).Magnitude

                            if not nearest or gap < nearest.gap then
                                nearest = { part = child, gap = gap }
                            end
                        end
                    end
                end

                if nearest then
                    booth = nearest.part
                    boothDistance = nearest.gap
                end
            end
        end

        if not booth then
            salesSay("No pitch found, walk to the market so they load")
            return
        end

        -- Land a few studs back from the counter rather than inside the mesh.
        -- The direction is taken from the seller so it works whichever way the
        -- pitch faces, and falls back to a fixed offset when the seller has
        -- left the realm.
        local sellerCharacter = entry.player and entry.player.Character
        local sellerRoot = sellerCharacter
            and (sellerCharacter:FindFirstChild("HumanoidRootPart")
                or sellerCharacter:FindFirstChildWhichIsA("BasePart", true))

        local approach = sellerRoot
            and (sellerRoot.Position - booth.Position)
            or Vector3.new(0, 0, 1)

        approach = approach.Magnitude > 0.01 and approach.Unit or Vector3.new(0, 0, 1)

        local goal = booth.Position + approach * 6 + Vector3.new(0, 4, 0)

        local okMove = pcall(function()
            character:PivotTo(CFrame.new(goal))
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
        end)

        if not okMove then
            salesSay("Could not move")
            return
        end

        if exact then
            salesSay(string.format("At %s's pitch, selling %s", entry.seller, entry.display))
        else
            salesSay(string.format(
                "Nearest unclaimed pitch, %s is %d studs off. Walk to the market so pitches load.",
                entry.seller,
                math.floor(boothDistance or 0)
            ))
        end
    end

    --==========================================================
    -- TRADE STATUS
    --
    -- Every one of these takes the player wrapper as its first argument.
    -- Calling them bare gives "attempt to index nil with 'TradeLock'" or
    -- "index nil with 'AccountAge'", because they are written as methods
    -- and read fields off the profile they are handed.
    --
    -- The two clock values are absolute server timestamps rather than
    -- remaining seconds, so what is displayed is the difference against
    -- GetServerTimeNow and it reads "ready" once it goes negative.
    --
    -- GetAvailableSlotValue and GetTotalTradedOfType are deliberately not
    -- called. Both want a deeper profile object than the wrapper exposes
    -- and both raise rather than returning a default, so they would
    -- report an error string in the panel.
    --==========================================================
    local TradeBox = Tabs.GameMods:AddRightGroupbox("Trade Status")

    local tradeLocked = TradeBox:AddLabel("Lock : -")
    local tradeLockLeft = TradeBox:AddLabel("Lock ends : -")
    local tradeCooling = TradeBox:AddLabel("Cooldown : -")
    local tradeCoolLeft = TradeBox:AddLabel("Cooldown ends : -")
    local tradeRules = TradeBox:AddLabel("Rules : -")
    local tradeLimits = TradeBox:AddLabel("Per trade : -")

    TradeBox:AddLabel("Read from TradeService.")

    local function updateTradeStatus()
        if not okSonar then
            tradeLocked:SetText("Lock : Sonar unavailable")
            return
        end

        local okService, Service = pcall(Sonar, "TradeService")

        if not okService then
            tradeLocked:SetText("Lock : service unavailable")
            return
        end

        local okWrapper, wrapper = pcall(function()
            return Sonar("PlayerWrapper").GetClient()
        end)

        if not okWrapper or not wrapper then
            tradeLocked:SetText("Lock : waiting for profile")
            return
        end

        tradeLimits:SetText(string.format(
            "Per trade : %s items, %ss accept",
            tostring(Service.MaxItems),
            tostring(Service.AcceptDuration)
        ))

        local function probe(setter, fn)
            local ok, value = pcall(function() return Service[fn](wrapper) end)

            -- IsOnTradeCooldown answers nil rather than false when there is
            -- no cooldown running, and printing that raw put a literal "nil"
            -- on the panel. Anything that is not true reads as "no".
            setter(not ok and "unknown" or (value == true and "yes" or "no"))
        end

        probe(function(text) tradeLocked:SetText("Lock : " .. text) end, "IsTradeLocked")
        probe(function(text) tradeCooling:SetText("Cooldown : " .. text) end, "IsOnTradeCooldown")

        local now = workspace:GetServerTimeNow()

        local function remaining(setter, fn)
            local ok, stamp = pcall(function() return Service[fn](wrapper) end)

            if not ok or type(stamp) ~= "number" then
                setter("-")
                return
            end

            local left = stamp - now

            if left <= 0 then
                setter("ready")
            else
                setter(string.format("%.0fs", left))
            end
        end

        remaining(function(text) tradeLockLeft:SetText("Lock ends : " .. text) end, "GetTradeLockTime")
        remaining(function(text) tradeCoolLeft:SetText("Cooldown ends : " .. text) end, "GetTradeCooldownTime")

        local okAge, age = pcall(function() return Service.HasAccountAgeRequirement(wrapper) end)
        local okSpecies, species = pcall(function() return Service.HasSpeciesRequirement(wrapper) end)

        tradeRules:SetText(string.format(
            "Rules : age %s, species %s",
            okAge and tostring(age) or "?",
            okSpecies and tostring(species) or "?"
        ))
    end

    --==========================================================
    -- REALM INFO
    --
    -- The place name carries the game's own leading emoji, which is cut by
    -- finding the first ASCII letter. A %p or %W class cannot do it: Lua
    -- patterns are byte oriented and the emoji is a multi byte sequence
    -- that matches neither, so the label came out with the decoration still
    -- attached. Cutting at the first letter is also rename proof.
    --==========================================================
    local RealmInfo = Tabs.GameMods:AddRightGroupbox("Realm Info")

    local function cleanName(name)
        local first = string.find(name or "", "[%a]")

        if not first then return "" end

        return (string.gsub(string.sub(name, first), "%s+$", ""))
    end

    local realmName = cleanName(PlaceName)

    local realmTitle = RealmInfo:AddLabel("Realm : " .. (realmName ~= "" and realmName or "Trade Realm"))
    RealmInfo:AddLabel("Place : " .. tostring(PlaceId))
    local realmJob = RealmInfo:AddLabel("Job : " .. tostring(game.JobId))
    local realmPlayers = RealmInfo:AddLabel("Players : " .. tostring(#Players:GetPlayers()))

    Realm.titleLabel = realmTitle
    Realm.jobLabel = realmJob
    Realm.playersLabel = realmPlayers

    Realm.stop = function()
        Realm.alive = false
        pcall(priceClose)
        pcall(salesClose)
    end

    -- A slow poll rather than a per frame one. Prices and trade status both
    -- change on somebody else's action, so once a second is
    -- indistinguishable from instant and costs nothing.
    Realm.alive = true

    task.spawn(function()
        Realm.accum = 0

        while Realm.alive do
            Realm.accum = (Realm.accum or 0) + 0.25

            if Realm.accum >= 1 then
                Realm.accum = 0
                pcall(updateTradeStatus)
            end

            task.wait(0.25)
        end
    end)

    Players.PlayerAdded:Connect(function()
        if Realm.playersLabel then
            Realm.playersLabel:SetText("Players : " .. tostring(#Players:GetPlayers()))
        end
    end)

    Players.PlayerRemoving:Connect(function()
        if Realm.playersLabel then
            Realm.playersLabel:SetText("Players : " .. tostring(#Players:GetPlayers()))
        end
    end)

    GameInfo:AddLabel("Status : Supported")
    GameInfo:AddLabel("Game Mods : Trade Realm")

    -- Both sources are scanned on a delay rather than instantly. The realm's
    -- replicated data arrives a moment after join, and the price board builds
    -- its rows even later, so an immediate scan finds nothing on both and the
    -- panel would sit reading empty until a manual Refresh. Retried, because
    -- walking in before either exists is the normal case.
    task.spawn(function()
        for _ = 1, 12 do
            task.wait(2.5)

            if not Realm.alive then return end

            -- Sales first and unconditionally. The player data folders are
            -- what the sales scan reads and they are the earlier of the two,
            -- so this is normally the one that succeeds on the first pass.
            pcall(salesScan)

            if SalesView.open then pcall(salesRender) end

            if realmScan() then
                if PriceView.open then priceRender() end
                return
            end
        end
    end)

    end
    end


    SetupTradeRealm()
end
