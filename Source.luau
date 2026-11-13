local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Library = {}
Library.__index = Library
Library.Version = "1.0.0"

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local TAB_HEIGHT = 38
local TAB_GAP = 4
local SIDEBAR_WIDTH = 188
local TOPBAR_HEIGHT = 36
local GUTTER = 12

local Speed = {
    Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Normal = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Slow = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Spring = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

local Fonts = {
    Regular = Enum.Font.Gotham,
    Medium = Enum.Font.GothamMedium,
    Bold = Enum.Font.GothamBold,
}

Library.Themes = {
    Dark = {
        Window = Color3.fromRGB(10, 10, 13),
        Panel = Color3.fromRGB(18, 18, 22),
        Row = Color3.fromRGB(27, 27, 32),
        RowHover = Color3.fromRGB(35, 35, 41),
        Stroke = Color3.fromRGB(43, 43, 50),
        Text = Color3.fromRGB(240, 242, 248),
        SubText = Color3.fromRGB(132, 135, 150),
        Muted = Color3.fromRGB(92, 95, 110),
        Accent = Color3.fromRGB(44, 142, 255),
        Track = Color3.fromRGB(50, 50, 58),
        Chip = Color3.fromRGB(20, 20, 25),
        Knob = Color3.fromRGB(228, 231, 240),
        Tint = 0.3,
    },
    Light = {
        Window = Color3.fromRGB(233, 235, 241),
        Panel = Color3.fromRGB(245, 246, 250),
        Row = Color3.fromRGB(255, 255, 255),
        RowHover = Color3.fromRGB(240, 242, 247),
        Stroke = Color3.fromRGB(214, 217, 226),
        Text = Color3.fromRGB(24, 26, 33),
        SubText = Color3.fromRGB(106, 110, 126),
        Muted = Color3.fromRGB(152, 156, 170),
        Accent = Color3.fromRGB(30, 118, 240),
        Track = Color3.fromRGB(207, 210, 221),
        Chip = Color3.fromRGB(231, 233, 240),
        Knob = Color3.fromRGB(255, 255, 255),
        Tint = 0.16,
    },
}

local function buildThemes(accent)
    local themes = {}
    for name, tokens in pairs(Library.Themes) do
        local copy = {}
        for token, value in pairs(tokens) do
            copy[token] = value
        end
        if accent then
            copy.Accent = accent
        end
        copy.RowOn = copy.Row:Lerp(copy.Accent, copy.Tint)
        themes[name] = copy
    end
    return themes
end

local function create(className, properties)
    local instance = Instance.new(className)
    if instance:IsA("GuiObject") then
        instance.BorderSizePixel = 0
    end
    if className == "TextButton" then
        instance.AutoButtonColor = false
        instance.Text = ""
    end
    for property, value in pairs(properties) do
        if property ~= "Parent" then
            instance[property] = value
        end
    end
    instance.Parent = properties.Parent
    return instance
end

local function round(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius),
        Parent = parent,
    })
end

local function outline(parent, thickness, transparency)
    return create("UIStroke", {
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function pad(parent, top, right, bottom, left)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, top),
        PaddingRight = UDim.new(0, right),
        PaddingBottom = UDim.new(0, bottom),
        PaddingLeft = UDim.new(0, left),
        Parent = parent,
    })
end

local function stack(parent, gap)
    return create("UIListLayout", {
        Padding = UDim.new(0, gap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

local function text(properties)
    if properties.BackgroundTransparency == nil then
        properties.BackgroundTransparency = 1
    end
    properties.Font = properties.Font or Fonts.Regular
    properties.TextSize = properties.TextSize or 13
    properties.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
    properties.TextTruncate = properties.TextTruncate or Enum.TextTruncate.AtEnd
    return create("TextLabel", properties)
end

local function play(instance, info, goal)
    local tween = TweenService:Create(instance, info, goal)
    tween:Play()
    return tween
end

local function apply(instance, animated, goal, info)
    if animated then
        play(instance, info or Speed.Normal, goal)
    else
        for property, value in pairs(goal) do
            instance[property] = value
        end
    end
end

local function fire(callback, ...)
    if type(callback) == "function" then
        task.spawn(callback, ...)
    end
end

local function iconAsset(icon)
    if type(icon) == "number" then
        return "rbxassetid://" .. icon
    end
    return icon
end

local function decimalsOf(number)
    local fraction = string.match(tostring(number), "%.(%d+)")
    return fraction and #fraction or 0
end

local function isPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function drawCross(parent, length, thickness)
    local bars = {}
    for _, angle in ipairs({45, -45}) do
        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(length, thickness),
            Rotation = angle,
            Parent = parent,
        })
        round(bar, math.floor(thickness / 2))
        table.insert(bars, bar)
    end
    return bars
end

local function drawChevron(parent)
    local holder = create("Frame", {
        Name = "Chevron",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(14, 14),
        Parent = parent,
    })
    local arms = {}
    for _, spec in ipairs({{45, 5}, {-45, 9}}) do
        local arm = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(spec[2], 7),
            Size = UDim2.fromOffset(6, 2),
            Rotation = spec[1],
            Parent = holder,
        })
        round(arm, 1)
        table.insert(arms, arm)
    end
    return holder, arms
end

local function previewOf(window, name)
    if name == "System" then
        local light = window.Themes.Light
        local dark = window.Themes.Dark
        return light.Window, dark.Window, dark.Track, dark.Text
    end
    local theme = window.Themes[name] or window.Theme
    return theme.Window, nil, theme.Track, theme.Text
end

function Window:Register(anchor, painter)
    local function wrapped(animated)
        if not anchor.Parent then
            return false
        end
        painter(animated)
        return true
    end
    table.insert(self.Painters, wrapped)
    wrapped(false)
    return wrapped
end

function Window:Bind(instance, tokens)
    return self:Register(instance, function(animated)
        local goal = {}
        for property, token in pairs(tokens) do
            goal[property] = self.Theme[token]
        end
        apply(instance, animated, goal, Speed.Normal)
    end)
end

function Window:Connect(signal, handler)
    local connection = signal:Connect(handler)
    table.insert(self.Connections, connection)
    return connection
end

function Window:ResolveTheme(name)
    if name == "System" then
        local hour = DateTime.now():ToLocalTime().Hour
        return self.Themes[(hour >= 7 and hour < 19) and "Light" or "Dark"]
    end
    return self.Themes[name]
end

function Window:SetTheme(name)
    local theme = self:ResolveTheme(name)
    if not theme then
        return false
    end
    self.ThemeName = name
    self.Theme = theme
    local alive = {}
    for _, painter in ipairs(self.Painters) do
        if painter(true) then
            table.insert(alive, painter)
        end
    end
    self.Painters = alive
    return true
end

function Window:MakeDraggable(handle)
    local active
    local origin
    local start

    handle.InputBegan:Connect(function(input)
        if isPointer(input) then
            active = input
            origin = input.Position
            start = self.Root.Position
        end
    end)

    self:Connect(UserInputService.InputChanged, function(input)
        if active and (input == active or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - origin
            self.Root.Position = UDim2.new(
                start.X.Scale,
                start.X.Offset + delta.X,
                start.Y.Scale,
                start.Y.Offset + delta.Y
            )
        end
    end)

    self:Connect(UserInputService.InputEnded, function(input)
        if active and isPointer(input) and input.UserInputType == active.UserInputType then
            active = nil
        end
    end)
end

function Window:SetVisible(visible)
    if self.Destroyed or self.Visible == visible then
        return
    end
    self.Visible = visible
    if visible then
        self.Root.Visible = true
        play(self.Root, Speed.Normal, {GroupTransparency = 0})
        play(self.Scale, Speed.Normal, {Scale = 1})
    else
        play(self.Root, Speed.Fast, {GroupTransparency = 1})
        play(self.Scale, Speed.Fast, {Scale = 0.96})
        task.delay(Speed.Fast.Time, function()
            if not self.Visible and not self.Destroyed then
                self.Root.Visible = false
            end
        end)
    end
end

function Window:Toggle()
    self:SetVisible(not self.Visible)
end

function Window:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true
    for _, connection in ipairs(self.Connections) do
        connection:Disconnect()
    end
    self.Connections = {}
    play(self.Root, Speed.Fast, {GroupTransparency = 1})
    play(self.Scale, Speed.Fast, {Scale = 0.94})
    task.delay(Speed.Fast.Time + 0.05, function()
        self.Gui:Destroy()
    end)
    fire(self.OnClose)
end

function Window:SelectTab(tab, instant)
    if self.ActiveTab == tab then
        return
    end
    local previous = self.ActiveTab
    if previous then
        previous.Active = false
        previous.Page.Visible = false
        previous.Paint(true)
    end
    self.ActiveTab = tab
    tab.Active = true
    tab.Paint(not instant)
    tab.Page.Visible = true
    tab.RefreshCanvas()
    self.PageTitle.Text = tab.Name
    apply(
        self.Indicator,
        not instant,
        {Position = UDim2.fromOffset(0, (tab.Index - 1) * (TAB_HEIGHT + TAB_GAP))},
        Speed.Normal
    )
    if not instant then
        tab.Page.Position = UDim2.fromOffset(0, 16)
        play(tab.Page, Speed.Normal, {Position = UDim2.fromOffset(0, 0)})
    end
end

function Window:AddTab(first, second)
    local config = type(first) == "table" and first or {Name = first, Icon = second}
    local name = tostring(config.Name or config.Title or "Tab")
    local index = #self.Tabs + 1

    local tab = setmetatable({
        Window = self,
        Name = name,
        Index = index,
        Active = false,
        CardCount = 0,
    }, Tab)

    local button = create("TextButton", {
        Name = name,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
        LayoutOrder = index,
        Parent = self.TabButtons,
    })

    local iconHolder = create("Frame", {
        Name = "Icon",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 9),
        Size = UDim2.fromOffset(20, 20),
        Parent = button,
    })

    local iconStroke
    local iconObject
    local image = iconAsset(config.Icon)
    if image then
        iconObject = create("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = image,
            Parent = iconHolder,
        })
    else
        round(iconHolder, 6)
        iconStroke = outline(iconHolder, 1.5)
        iconObject = text({
            Size = UDim2.fromScale(1, 1),
            Text = string.upper(string.sub(name, 1, 1)),
            Font = Fonts.Bold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = iconHolder,
        })
    end

    local nameLabel = text({
        Name = "Name",
        Position = UDim2.fromOffset(44, 0),
        Size = UDim2.new(1, -52, 1, 0),
        Text = name,
        Font = Fonts.Medium,
        TextSize = 14,
        Parent = button,
    })

    local hovered = false
    tab.Paint = function(animated)
        local theme = self.Theme
        local color = tab.Active and theme.Text or (hovered and theme.SubText or theme.Muted)
        apply(nameLabel, animated, {TextColor3 = color}, Speed.Fast)
        if iconStroke then
            apply(iconStroke, animated, {Color = color}, Speed.Fast)
            apply(iconObject, animated, {TextColor3 = color}, Speed.Fast)
        else
            apply(iconObject, animated, {ImageColor3 = color}, Speed.Fast)
        end
    end
    self:Register(button, tab.Paint)

    button.MouseEnter:Connect(function()
        hovered = true
        tab.Paint(true)
    end)
    button.MouseLeave:Connect(function()
        hovered = false
        tab.Paint(true)
    end)
    button.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)

    local page = create("ScrollingFrame", {
        Name = name,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 3,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        Parent = self.Pages,
    })
    self:Bind(page, {ScrollBarImageColor3 = "Muted"})

    local function column(columnName, position)
        local holder = create("Frame", {
            Name = columnName,
            BackgroundTransparency = 1,
            Position = position,
            Size = UDim2.new(0.5, -12, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = page,
        })
        stack(holder, GUTTER)
        return holder
    end

    local left = column("Left", UDim2.fromOffset(2, 2))
    local right = column("Right", UDim2.new(0.5, 2, 0, 2))

    tab.Page = page
    tab.Left = left
    tab.Right = right
    tab.RefreshCanvas = function()
        local height = math.max(left.AbsoluteSize.Y, right.AbsoluteSize.Y) / self.Scale.Scale
        page.CanvasSize = UDim2.fromOffset(0, height + GUTTER + 2)
    end
    left:GetPropertyChangedSignal("AbsoluteSize"):Connect(tab.RefreshCanvas)
    right:GetPropertyChangedSignal("AbsoluteSize"):Connect(tab.RefreshCanvas)

    table.insert(self.Tabs, tab)
    if index == 1 then
        self:SelectTab(tab, true)
    end
    return tab
end

function Tab:Select()
    self.Window:SelectTab(self)
end

function Tab:AddSection(first, second)
    local config = type(first) == "table" and first or {Title = first, Side = second}
    local side = string.lower(tostring(config.Side or config.side or "Left"))
    local window = self.Window
    self.CardCount = self.CardCount + 1

    local card = create("Frame", {
        Name = "Section",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self.CardCount,
        Parent = side == "right" and self.Right or self.Left,
    })
    round(card, 20)
    pad(card, 12, 12, 12, 12)
    stack(card, 8)
    window:Bind(card, {BackgroundColor3 = "Panel"})
    window:Bind(outline(card, 1), {Color = "Stroke"})

    local section = setmetatable({
        Window = window,
        Tab = self,
        Card = card,
        Page = self.Page,
        Order = 0,
    }, Section)

    local title = config.Title or config.title
    if title and title ~= "" then
        section.Order = 1
        window:Bind(text({
            Name = "Title",
            Size = UDim2.new(1, 0, 0, 22),
            Text = tostring(title),
            Font = Fonts.Medium,
            TextSize = 15,
            LayoutOrder = 1,
            Parent = card,
        }), {TextColor3 = "Text"})
    end

    return section
end

local function createRow(section, title, description, clickable, controlWidth)
    local window = section.Window
    local hasDescription = type(description) == "string" and description ~= ""
    local height = hasDescription and 52 or 42
    local titleSize = UDim2.new(1, -(controlWidth + 38), 0, hasDescription and 18 or height)
    section.Order = section.Order + 1

    local row = create("Frame", {
        Name = tostring(title),
        Size = UDim2.new(1, 0, 0, height),
        ClipsDescendants = true,
        LayoutOrder = section.Order,
        Parent = section.Card,
    })
    round(row, 14)
    local rowStroke = outline(row, 1, 0.45)

    local header = create(clickable and "TextButton" or "Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height),
        Parent = row,
    })

    local titleLabel = text({
        Name = "Title",
        Position = UDim2.fromOffset(14, hasDescription and 9 or 0),
        Size = titleSize,
        Text = tostring(title),
        Font = Fonts.Medium,
        TextSize = 14,
        Parent = header,
    })
    window:Bind(titleLabel, {TextColor3 = "Text"})

    local descriptionLabel
    if hasDescription then
        descriptionLabel = text({
            Name = "Description",
            Position = UDim2.fromOffset(14, 28),
            Size = UDim2.new(1, -(controlWidth + 38), 0, 14),
            Text = description,
            TextSize = 11,
            Parent = header,
        })
        window:Bind(descriptionLabel, {TextColor3 = "SubText"})
    end

    window:Bind(rowStroke, {Color = "Stroke"})

    local hovered = false
    local highlighted = false

    local function paintRow(animated)
        local theme = window.Theme
        local color = highlighted and theme.RowOn or (hovered and theme.RowHover or theme.Row)
        apply(row, animated, {BackgroundColor3 = color}, Speed.Fast)
    end
    window:Register(row, paintRow)

    if clickable then
        header.MouseEnter:Connect(function()
            hovered = true
            paintRow(true)
        end)
        header.MouseLeave:Connect(function()
            hovered = false
            paintRow(true)
        end)
    end

    return {
        Row = row,
        Header = header,
        Title = titleLabel,
        Description = descriptionLabel,
        Height = height,
        SetActive = function(value, animated)
            highlighted = value
            paintRow(animated)
        end,
    }
end

function Section:AddToggle(title, description, default, callback)
    local window = self.Window
    local item = createRow(self, title, description, true, 40)
    local state = default == true

    local track = create("Frame", {
        Name = "Track",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(40, 22),
        Parent = item.Header,
    })
    round(track, 11)

    local knob = create("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        Parent = track,
    })
    round(knob, 8)

    local function paint(animated)
        local theme = window.Theme
        apply(track, animated, {BackgroundColor3 = state and theme.Accent or theme.Track}, Speed.Normal)
        apply(knob, animated, {BackgroundColor3 = theme.Knob}, Speed.Normal)
        apply(
            knob,
            animated,
            {Position = state and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)},
            Speed.Spring
        )
    end
    window:Register(track, paint)
    item.SetActive(state, false)

    local function set(value, silent)
        state = value == true
        paint(true)
        item.SetActive(state, true)
        if not silent then
            fire(callback, state)
        end
    end

    item.Header.MouseButton1Click:Connect(function()
        set(not state)
    end)

    task.defer(fire, callback, state)

    local object = {}
    function object:Set(value, silent)
        set(value, silent)
    end
    function object:Get()
        return state
    end
    return object
end

function Section:AddSlider(title, description, min, max, default, callback, increment)
    local window = self.Window
    local page = self.Page
    min = min or 0
    max = max or 100
    increment = increment or 1
    local decimals = decimalsOf(increment)
    local item = createRow(self, title, description, false, 116)

    local bar = create("TextButton", {
        Name = "Bar",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(116, 22),
        ClipsDescendants = true,
        Parent = item.Header,
    })
    round(bar, 11)

    local fill = create("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        Parent = bar,
    })
    round(fill, 11)

    local valueLabel = text({
        Name = "Value",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -3, 0.5, 0),
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 0,
        Text = "",
        Font = Fonts.Medium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Parent = bar,
    })
    round(valueLabel, 8)
    pad(valueLabel, 0, 7, 0, 7)

    window:Register(bar, function(animated)
        local theme = window.Theme
        apply(bar, animated, {BackgroundColor3 = theme.Track}, Speed.Fast)
        apply(fill, animated, {BackgroundColor3 = theme.Accent}, Speed.Fast)
        apply(valueLabel, animated, {BackgroundColor3 = theme.Chip, TextColor3 = theme.Text}, Speed.Fast)
    end)

    local function snap(raw)
        raw = math.clamp(raw, min, max)
        raw = min + math.floor((raw - min) / increment + 0.5) * increment
        raw = math.clamp(raw, min, max)
        return tonumber(string.format("%." .. decimals .. "f", raw))
    end

    local value = snap(default or min)

    local function render(animated)
        local alpha = max > min and (value - min) / (max - min) or 0
        valueLabel.Text = string.format("%." .. decimals .. "f", value)
        apply(fill, animated, {Size = UDim2.fromScale(alpha, 1)}, Speed.Fast)
    end
    render(false)

    local function set(raw, silent)
        local snapped = snap(raw)
        if snapped == value then
            return
        end
        value = snapped
        render(true)
        if not silent then
            fire(callback, value)
        end
    end

    local dragging = false

    local function drag(positionX)
        local alpha = math.clamp((positionX - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        set(min + (max - min) * alpha)
    end

    bar.InputBegan:Connect(function(input)
        if isPointer(input) then
            dragging = true
            page.ScrollingEnabled = false
            drag(input.Position.X)
        end
    end)

    window:Connect(UserInputService.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            drag(input.Position.X)
        end
    end)

    window:Connect(UserInputService.InputEnded, function(input)
        if dragging and isPointer(input) then
            dragging = false
            page.ScrollingEnabled = true
        end
    end)

    task.defer(fire, callback, value)

    local object = {}
    function object:Set(raw, silent)
        set(raw, silent)
    end
    function object:Get()
        return value
    end
    return object
end

function Section:AddButton(title, description, callback, buttonText)
    local window = self.Window
    local item = createRow(self, title, description, true, 64)

    local pill = text({
        Name = "Action",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(64, 26),
        BackgroundTransparency = 0,
        Text = buttonText or "Run",
        Font = Fonts.Medium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = item.Header,
    })
    round(pill, 13)

    window:Register(pill, function(animated)
        local theme = window.Theme
        apply(pill, animated, {BackgroundColor3 = theme.Chip, TextColor3 = theme.Text}, Speed.Fast)
    end)

    item.Header.MouseButton1Click:Connect(function()
        pill.BackgroundColor3 = window.Theme.Accent
        play(pill, Speed.Slow, {BackgroundColor3 = window.Theme.Chip})
        fire(callback)
    end)

    local object = {}
    function object:SetText(value)
        item.Title.Text = value
    end
    function object:Fire()
        fire(callback)
    end
    return object
end

function Section:AddDropdown(title, description, options, default, callback)
    local window = self.Window
    options = options or {}
    local item = createRow(self, title, description, true, 112)

    local current = default
    if current == nil then
        current = options[1]
    end
    local open = false
    local hoveredOption
    local buttons = {}
    local listHeight = 0

    local chip = create("Frame", {
        Name = "Value",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(104, 26),
        Parent = item.Header,
    })
    round(chip, 13)

    local chipLabel = text({
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -34, 1, 0),
        Text = tostring(current or ""),
        Font = Fonts.Medium,
        TextSize = 12,
        Parent = chip,
    })

    local chevron, arms = drawChevron(chip)
    chevron.Position = UDim2.new(1, -14, 0.5, 0)

    local holder = create("ScrollingFrame", {
        Name = "Options",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, item.Height),
        Size = UDim2.new(1, -16, 0, 0),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = item.Row,
    })
    stack(holder, 4)
    window:Bind(holder, {ScrollBarImageColor3 = "Muted"})

    window:Register(chip, function(animated)
        local theme = window.Theme
        apply(chip, animated, {BackgroundColor3 = theme.Chip}, Speed.Fast)
        apply(chipLabel, animated, {TextColor3 = theme.Text}, Speed.Fast)
        for _, arm in ipairs(arms) do
            apply(arm, animated, {BackgroundColor3 = theme.SubText}, Speed.Fast)
        end
    end)

    local function paintOptions(animated)
        local theme = window.Theme
        for name, button in pairs(buttons) do
            local selected = name == current
            local transparency = selected and 0 or (hoveredOption == name and 0.4 or 1)
            apply(button, animated, {
                BackgroundColor3 = theme.Chip,
                BackgroundTransparency = transparency,
                TextColor3 = selected and theme.Accent or theme.SubText,
            }, Speed.Fast)
        end
    end
    window:Register(holder, paintOptions)

    local function setOpen(value)
        open = value
        local target = value and (item.Height + listHeight + 10) or item.Height
        play(item.Row, Speed.Normal, {Size = UDim2.new(1, 0, 0, target)})
        play(chevron, Speed.Normal, {Rotation = value and 180 or 0})
    end

    local function choose(name, silent)
        current = name
        chipLabel.Text = tostring(name)
        paintOptions(true)
        if not silent then
            fire(callback, name)
        end
    end

    local function build()
        for _, button in pairs(buttons) do
            button:Destroy()
        end
        buttons = {}
        for index, name in ipairs(options) do
            local button = create("TextButton", {
                Name = tostring(name),
                Size = UDim2.new(1, 0, 0, 30),
                Text = tostring(name),
                Font = Fonts.Medium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = index,
                Parent = holder,
            })
            round(button, 9)
            pad(button, 0, 10, 0, 10)
            button.MouseEnter:Connect(function()
                hoveredOption = name
                paintOptions(true)
            end)
            button.MouseLeave:Connect(function()
                if hoveredOption == name then
                    hoveredOption = nil
                    paintOptions(true)
                end
            end)
            button.MouseButton1Click:Connect(function()
                choose(name)
                setOpen(false)
            end)
            buttons[name] = button
        end
        local visible = math.min(#options, 5)
        listHeight = visible * 30 + math.max(visible - 1, 0) * 4
        holder.Size = UDim2.new(1, -16, 0, listHeight)
        holder.ScrollingEnabled = #options > 5
        if open then
            play(item.Row, Speed.Normal, {Size = UDim2.new(1, 0, 0, item.Height + listHeight + 10)})
        end
        paintOptions(false)
    end
    build()

    item.Header.MouseButton1Click:Connect(function()
        setOpen(not open)
    end)

    if current ~= nil then
        task.defer(fire, callback, current)
    end

    local object = {}
    function object:Set(name, silent)
        choose(name, silent)
    end
    function object:Get()
        return current
    end
    function object:Refresh(newOptions, keepCurrent)
        options = newOptions or {}
        if not (keepCurrent and table.find(options, current)) then
            current = options[1]
            chipLabel.Text = tostring(current or "")
        end
        build()
    end
    return object
end

function Section:AddThemeSelector(title, options, callback)
    local window = self.Window
    options = options or {"Light", "Dark", "System"}
    local count = math.max(#options, 1)
    self.Order = self.Order + 1

    local container = create("Frame", {
        Name = "ThemeSelector",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 106),
        LayoutOrder = self.Order,
        Parent = self.Card,
    })

    window:Bind(text({
        Name = "Title",
        Position = UDim2.fromOffset(2, 0),
        Size = UDim2.new(1, -4, 0, 20),
        Text = tostring(title or "Theme"),
        Font = Fonts.Medium,
        TextSize = 14,
        Parent = container,
    }), {TextColor3 = "Text"})

    local tiles = create("Frame", {
        Name = "Tiles",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 28),
        Size = UDim2.new(1, 0, 0, 78),
        Parent = container,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tiles,
    })

    local strokes = {}
    local selected = table.find(options, window.ThemeName) and window.ThemeName or options[1]

    local function paintTiles(animated)
        local theme = window.Theme
        for name, stroke in pairs(strokes) do
            local isSelected = name == selected
            apply(stroke, animated, {
                Color = isSelected and theme.Accent or theme.Stroke,
                Thickness = isSelected and 2 or 1,
            }, Speed.Normal)
        end
    end

    local function choose(name, silent)
        if not strokes[name] then
            return
        end
        selected = name
        paintTiles(true)
        window:SetTheme(name)
        if not silent then
            fire(callback, name)
        end
    end

    for index, name in ipairs(options) do
        local first, second, pillColor, pillTextColor = previewOf(window, name)

        local tile = create("TextButton", {
            Name = tostring(name),
            BackgroundColor3 = second and Color3.new(1, 1, 1) or first,
            Size = UDim2.new(1 / count, -math.ceil(8 * (count - 1) / count), 1, 0),
            LayoutOrder = index,
            Parent = tiles,
        })
        round(tile, 16)

        if second then
            create("UIGradient", {
                Rotation = 35,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, first),
                    ColorSequenceKeypoint.new(0.5, first),
                    ColorSequenceKeypoint.new(0.501, second),
                    ColorSequenceKeypoint.new(1, second),
                }),
                Parent = tile,
            })
        end

        strokes[name] = outline(tile, 1)

        local pill = text({
            Name = "Label",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0.74, 0, 0, 24),
            BackgroundTransparency = 0,
            BackgroundColor3 = pillColor,
            Text = tostring(name),
            TextColor3 = pillTextColor,
            Font = Fonts.Medium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = tile,
        })
        round(pill, 12)

        tile.MouseButton1Click:Connect(function()
            choose(name)
        end)
    end

    window:Register(tiles, paintTiles)

    local object = {}
    function object:Set(name, silent)
        choose(name, silent)
    end
    function object:Get()
        return selected
    end
    return object
end

function Section:AddLabel(title, description)
    local item = createRow(self, title, description, false, 0)
    local object = {}
    function object:SetText(value)
        item.Title.Text = value
    end
    function object:SetDescription(value)
        if item.Description then
            item.Description.Text = value
        end
    end
    return object
end

function Library:CreateWindow(config)
    config = config or {}
    local themes = buildThemes(config.Accent)
    local window = setmetatable({
        Themes = themes,
        Painters = {},
        Connections = {},
        Tabs = {},
        ActiveTab = nil,
        Visible = true,
        Destroyed = false,
        OnClose = config.OnClose,
    }, Window)

    window.ThemeName = config.Theme or "Dark"
    window.Theme = window:ResolveTheme(window.ThemeName) or themes.Dark

    local title = tostring(config.Title or "Window")
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local wanted = config.Size or Vector2.new(860, 540)
    local size = Vector2.new(math.min(wanted.X, viewport.X - 24), math.min(wanted.Y, viewport.Y - 24))

    local guiName = config.Name or "NebulaUI"
    local container = config.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")
    local existing = container:FindFirstChild(guiName)
    if existing then
        existing:Destroy()
    end

    local gui = create("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = container,
    })

    local root = create("CanvasGroup", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size.X, size.Y),
        GroupTransparency = 1,
        Active = true,
        Parent = gui,
    })
    local scale = create("UIScale", {
        Scale = 0.94,
        Parent = root,
    })
    round(root, 24)
    window:Bind(root, {BackgroundColor3 = "Window"})
    window:Bind(outline(root, 1), {Color = "Stroke"})

    window.Gui = gui
    window.Root = root
    window.Scale = scale

    local sidebar = create("Frame", {
        Name = "Sidebar",
        Position = UDim2.fromOffset(GUTTER, GUTTER),
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -GUTTER * 2),
        Parent = root,
    })
    round(sidebar, 20)
    window:Bind(sidebar, {BackgroundColor3 = "Panel"})
    window:Bind(outline(sidebar, 1), {Color = "Stroke"})

    local profile = create("Frame", {
        Name = "Profile",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 14),
        Size = UDim2.new(1, -28, 0, 40),
        Parent = sidebar,
    })

    local avatar = create("Frame", {
        Name = "Avatar",
        Position = UDim2.fromOffset(0, 2),
        Size = UDim2.fromOffset(36, 36),
        Parent = profile,
    })
    round(avatar, 18)
    window:Bind(avatar, {BackgroundColor3 = "Chip"})
    window:Bind(outline(avatar, 1), {Color = "Stroke"})

    local avatarImage = iconAsset(config.Icon)
    if avatarImage then
        create("ImageLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(22, 22),
            Image = avatarImage,
            Parent = avatar,
        })
    else
        window:Bind(text({
            Size = UDim2.fromScale(1, 1),
            Text = string.upper(string.sub(title, 1, 1)),
            Font = Fonts.Bold,
            TextSize = 17,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = avatar,
        }), {TextColor3 = "Accent"})
    end

    window:Bind(text({
        Name = "Title",
        Position = UDim2.fromOffset(48, 3),
        Size = UDim2.new(1, -48, 0, 18),
        Text = title,
        Font = Fonts.Medium,
        TextSize = 15,
        Parent = profile,
    }), {TextColor3 = "Text"})

    window:Bind(text({
        Name = "Subtitle",
        Position = UDim2.fromOffset(48, 22),
        Size = UDim2.new(1, -48, 0, 14),
        Text = tostring(config.Subtitle or ""),
        TextSize = 11,
        Parent = profile,
    }), {TextColor3 = "SubText"})

    local tabScroll = create("ScrollingFrame", {
        Name = "Tabs",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 72),
        Size = UDim2.new(1, -20, 1, -84),
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = sidebar,
    })

    local indicator = create("Frame", {
        Name = "Indicator",
        Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
        ZIndex = 1,
        Parent = tabScroll,
    })
    round(indicator, 13)
    window:Bind(indicator, {BackgroundColor3 = "Row"})
    window:Bind(outline(indicator, 1), {Color = "Stroke"})

    local indicatorBar = create("Frame", {
        Name = "Bar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 5, 0.5, 0),
        Size = UDim2.fromOffset(3, 16),
        Parent = indicator,
    })
    round(indicatorBar, 2)
    window:Bind(indicatorBar, {BackgroundColor3 = "Accent"})

    local tabButtons = create("Frame", {
        Name = "Buttons",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 2,
        Parent = tabScroll,
    })
    stack(tabButtons, TAB_GAP)
    tabButtons:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        tabScroll.CanvasSize = UDim2.fromOffset(0, tabButtons.AbsoluteSize.Y / scale.Scale)
    end)

    local body = create("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(SIDEBAR_WIDTH + GUTTER * 2, GUTTER),
        Size = UDim2.new(1, -(SIDEBAR_WIDTH + GUTTER * 3), 1, -GUTTER * 2),
        Parent = root,
    })

    local topbar = create("Frame", {
        Name = "Topbar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT),
        Parent = body,
    })

    local pageTitle = text({
        Name = "PageTitle",
        Position = UDim2.fromOffset(4, 0),
        Size = UDim2.new(1, -48, 1, 0),
        Text = "",
        Font = Fonts.Bold,
        TextSize = 17,
        Parent = topbar,
    })
    window:Bind(pageTitle, {TextColor3 = "Text"})

    local closeButton = create("TextButton", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -2, 0.5, 0),
        Size = UDim2.fromOffset(32, 32),
        Parent = topbar,
    })
    round(closeButton, 16)
    local closeStroke = outline(closeButton, 1)
    local crossBars = drawCross(closeButton, 12, 2)
    local closeHovered = false
    local paintClose = window:Register(closeButton, function(animated)
        local theme = window.Theme
        apply(closeButton, animated, {BackgroundColor3 = closeHovered and theme.RowHover or theme.Row}, Speed.Fast)
        apply(closeStroke, animated, {Color = theme.Stroke}, Speed.Fast)
        for _, bar in ipairs(crossBars) do
            apply(bar, animated, {BackgroundColor3 = closeHovered and theme.Text or theme.SubText}, Speed.Fast)
        end
    end)
    closeButton.MouseEnter:Connect(function()
        closeHovered = true
        paintClose(true)
    end)
    closeButton.MouseLeave:Connect(function()
        closeHovered = false
        paintClose(true)
    end)
    closeButton.MouseButton1Click:Connect(function()
        window:Destroy()
    end)

    local pages = create("Frame", {
        Name = "Pages",
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Position = UDim2.fromOffset(0, TOPBAR_HEIGHT + 8),
        Size = UDim2.new(1, 0, 1, -(TOPBAR_HEIGHT + 8)),
        Parent = body,
    })

    window.TabButtons = tabButtons
    window.Indicator = indicator
    window.PageTitle = pageTitle
    window.Pages = pages

    window:MakeDraggable(topbar)
    window:MakeDraggable(profile)

    if config.ToggleKey then
        window:Connect(UserInputService.InputBegan, function(input, processed)
            if not processed and input.KeyCode == config.ToggleKey then
                window:Toggle()
            end
        end)
    end

    play(root, Speed.Slow, {GroupTransparency = 0})
    play(scale, Speed.Slow, {Scale = 1})

    return window
end

return Library
