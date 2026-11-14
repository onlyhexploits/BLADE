--[[
	BladeUI: single-file Roblox UI library (Rayfield/Fluent style API).

	Returns the Library table, so either of these works:
		local Library = require(game:GetService("ReplicatedStorage"):WaitForChild("Library"))
		local Library = loadstring(game:HttpGet("<raw url of this file>"))()

	Components (Window, TabList, Breadcrumb, TopBar, Section, Row, Toggle, Dropdown,
	MultiDropdown, Slider, DualSlider, ConfigPanel) live in the blocks below. Every
	block reads its colors and fonts from the shared Theme object, so Window:SetTheme()
	restyles the whole tree without rebuilding it.
]]

local Modules = {}
local Loaded = {}

local function Require(name)
	local cached = Loaded[name]
	if cached ~= nil then
		return cached
	end
	local loader = Modules[name]
	assert(loader, "BladeUI: missing module " .. name)
	local result = loader()
	Loaded[name] = result
	return result
end

Modules.Util = function()
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local Util = {}

	local Defaults = {
		Frame = { BorderSizePixel = 0 },
		TextLabel = {
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
		},
		TextButton = {
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
		},
		TextBox = {
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
		},
		ImageLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
		ScrollingFrame = { BorderSizePixel = 0, BackgroundTransparency = 1 },
	}

	local Signal = {}
	Signal.__index = Signal

	function Signal.new()
		return setmetatable({ _connections = {} }, Signal)
	end

	function Signal:Connect(handler)
		local signal = self
		local connection = { Handler = handler, Connected = true }
		function connection.Disconnect()
			connection.Connected = false
			for index, item in ipairs(signal._connections) do
				if item == connection then
					table.remove(signal._connections, index)
					break
				end
			end
		end
		table.insert(self._connections, connection)
		return connection
	end

	function Signal:Fire(...)
		local snapshot = {}
		for index, connection in ipairs(self._connections) do
			snapshot[index] = connection
		end
		for _, connection in ipairs(snapshot) do
			if connection.Connected then
				connection.Handler(...)
			end
		end
	end

	Util.Signal = Signal

	function Util.Create(className, properties, children)
		local instance = Instance.new(className)
		local defaults = Defaults[className]
		if defaults then
			for key, value in pairs(defaults) do
				instance[key] = value
			end
		end
		local parent
		for key, value in pairs(properties or {}) do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
		for _, child in ipairs(children or {}) do
			child.Parent = instance
		end
		if parent then
			instance.Parent = parent
		end
		return instance
	end

	function Util.Tween(instance, properties, duration, style, direction)
		local info = TweenInfo.new(
			duration or 0.16,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		)
		local tween = TweenService:Create(instance, info, properties)
		tween:Play()
		return tween
	end

	function Util.Apply(instance, properties, animate, duration)
		if animate then
			return Util.Tween(instance, properties, duration)
		end
		for key, value in pairs(properties) do
			instance[key] = value
		end
		return nil
	end

	function Util.Clamp(value, low, high)
		return math.max(low, math.min(high, value))
	end

	function Util.Decimals(increment)
		local decimals = 0
		while decimals < 6 do
			local scaled = increment * 10 ^ decimals
			if math.abs(scaled - math.floor(scaled + 0.5)) < 1e-7 then
				break
			end
			decimals = decimals + 1
		end
		return decimals
	end

	function Util.Snap(value, minimum, maximum, increment)
		local steps = math.floor((value - minimum) / increment + 0.5)
		local snapped = minimum + steps * increment
		snapped = tonumber(string.format("%." .. Util.Decimals(increment) .. "f", snapped))
		return Util.Clamp(snapped, minimum, maximum)
	end

	function Util.Format(value, increment, suffix)
		return string.format("%." .. Util.Decimals(increment) .. "f", value) .. (suffix or "")
	end

	function Util.Copy(list)
		local copy = {}
		for index, item in ipairs(list) do
			copy[index] = item
		end
		return copy
	end

	function Util.DeepCopy(value)
		if type(value) ~= "table" then
			return value
		end
		local copy = {}
		for key, item in pairs(value) do
			copy[key] = Util.DeepCopy(item)
		end
		return copy
	end

	function Util.Merge(base, extra)
		local result = {}
		for key, value in pairs(base) do
			result[key] = value
		end
		for key, value in pairs(extra or {}) do
			result[key] = value
		end
		return result
	end

	function Util.IndexOf(list, value)
		for index, item in ipairs(list) do
			if item == value then
				return index
			end
		end
		return nil
	end

	function Util.Disconnect(connections)
		for index = #connections, 1, -1 do
			connections[index]:Disconnect()
			connections[index] = nil
		end
	end

	function Util.Trim(text)
		return (text:gsub("^%s+", ""):gsub("%s+$", ""))
	end

	function Util.ResolveImage(icon)
		if type(icon) == "number" then
			return "rbxassetid://" .. icon
		end
		if type(icon) ~= "string" or icon == "" then
			return nil
		end
		if icon:match("^%d+$") then
			return "rbxassetid://" .. icon
		end
		if icon:find("://", 1, true) then
			return icon
		end
		return nil
	end

	function Util.Pointer(input)
		return Vector2.new(input.Position.X, input.Position.Y)
	end

	-- Starts a drag on InputBegan over `handle`, then follows the pointer globally
	-- until the same button or finger is released. Pointer positions are always
	-- compared as deltas so GUI inset differences cancel out.
	function Util.Drag(handle, callbacks)
		local connections = {}
		local active = false
		table.insert(connections, handle.InputBegan:Connect(function(input)
			if active then
				return
			end
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
				return
			end
			if callbacks.CanBegin and not callbacks.CanBegin() then
				return
			end
			active = true
			local origin = Util.Pointer(input)
			if callbacks.Began then
				callbacks.Began(origin, input)
			end
			local moved, released
			moved = UserInputService.InputChanged:Connect(function(changed)
				local changedKind = changed.UserInputType
				if changedKind == Enum.UserInputType.MouseMovement or changedKind == Enum.UserInputType.Touch then
					if callbacks.Changed then
						callbacks.Changed(Util.Pointer(changed), origin, changed)
					end
				end
			end)
			released = UserInputService.InputEnded:Connect(function(ended)
				if ended == input or ended.UserInputType == kind then
					active = false
					moved:Disconnect()
					released:Disconnect()
					if callbacks.Ended then
						callbacks.Ended()
					end
				end
			end)
		end))
		return {
			Disconnect = function()
				for _, connection in ipairs(connections) do
					connection:Disconnect()
				end
			end,
		}
	end

	-- Soft shadow built from stacked translucent rounded frames, so it needs no image asset.
	function Util.Shadow(parent, theme, layers, spread)
		local holder = Util.Create("Frame", {
			Name = "Shadow",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			Parent = parent,
		})
		for index = 1, layers do
			local grow = index * spread
			local layer = Util.Create("Frame", {
				Name = "Layer",
				Size = UDim2.new(1, grow * 2, 1, grow * 2),
				Position = UDim2.fromOffset(-grow, -grow + 8),
				BackgroundTransparency = 0.95,
				Parent = holder,
			})
			theme:Style(layer, { BackgroundColor3 = "Shadow" })
			local corner = Util.Create("UICorner", { Parent = layer })
			theme:Style(corner, {
				CornerRadius = function(tokens)
					return UDim.new(0, tokens.RadiusPanel + grow)
				end,
			})
		end
		return holder
	end

	return Util
end

Modules.Theme = function()
	local Util = Require("Util")

	local Theme = {}
	Theme.__index = Theme

	local Purple = {
		Accent = "#6C5CE7",
		Background = "#0D0D12",
		Panel = "#131318",
		Card = "#1A1A22",
		Control = "#23232D",
		Text = "#FFFFFF",
		TextMuted = "#8A8A94",
		Stroke = "#232329",
		Track = "#2B2B36",
		Thumb = "#FFFFFF",
		ThumbOff = "#5A5A66",
		Danger = "#F25F5C",
		Scrim = "#000000",
		ScrimTransparency = 0.45,
		Shadow = "#000000",
		RadiusControl = 8,
		RadiusCard = 12,
		RadiusPanel = 16,
		TextSize = 12,
		TextSizeSmall = 11,
		TextSizeLarge = 13,
		TextSizeTitle = 20,
		Font = "GothamSSm",
	}

	function Theme.Extend(base, overrides)
		local result = {}
		for key, value in pairs(base) do
			result[key] = value
		end
		for key, value in pairs(overrides) do
			result[key] = value
		end
		return result
	end

	Theme.Presets = {
		Purple = Purple,
		Crimson = Theme.Extend(Purple, { Accent = "#E5484D" }),
		Ocean = Theme.Extend(Purple, {
			Accent = "#2D9CDB",
			Background = "#0B0F14",
			Panel = "#10151C",
			Card = "#161C25",
			Control = "#1F2733",
			Stroke = "#1F2733",
			Track = "#27313F",
		}),
	}

	local function ToColor(value)
		if type(value) == "string" and value:sub(1, 1) == "#" then
			return Color3.fromHex(value)
		end
		return value
	end

	local function MakeFont(family, weight)
		local ok, font = pcall(Font.fromName, family, weight)
		if ok and font then
			return font
		end
		return Font.fromEnum(Enum.Font.Gotham)
	end

	function Theme.new(source)
		local self = setmetatable({}, Theme)
		self.Tokens = {}
		self.Name = "Purple"
		self.Changed = Util.Signal.new()
		-- Weak keys so destroyed instances drop out of the binding table on their own.
		self._bound = setmetatable({}, { __mode = "k" })
		self:Apply(source or "Purple")
		return self
	end

	function Theme:Apply(source)
		local overrides = source
		if type(source) == "string" then
			overrides = Theme.Presets[source]
			assert(overrides, "BladeUI: unknown theme '" .. source .. "'")
			self.Name = source
		else
			self.Name = source.Name or "Custom"
		end
		local tokens = {}
		for key, value in pairs(Purple) do
			tokens[key] = ToColor(value)
		end
		for key, value in pairs(overrides) do
			tokens[key] = ToColor(value)
		end
		tokens.FontRegular = MakeFont(tokens.Font, Enum.FontWeight.Regular)
		tokens.FontMedium = MakeFont(tokens.Font, Enum.FontWeight.Medium)
		tokens.FontSemibold = MakeFont(tokens.Font, Enum.FontWeight.SemiBold)
		tokens.FontBold = MakeFont(tokens.Font, Enum.FontWeight.Bold)
		self.Tokens = tokens
		for instance, bindings in pairs(self._bound) do
			for property, key in pairs(bindings) do
				local value = self:Resolve(key)
				if value ~= nil then
					pcall(function()
						instance[property] = value
					end)
				end
			end
		end
		self.Changed:Fire(tokens)
	end

	function Theme:Resolve(key)
		local kind = type(key)
		if kind == "function" then
			return key(self.Tokens, self)
		end
		if kind == "string" then
			return self.Tokens[key]
		end
		return key
	end

	function Theme:Style(instance, map)
		local bindings = self._bound[instance]
		if not bindings then
			bindings = {}
			self._bound[instance] = bindings
		end
		for property, key in pairs(map) do
			bindings[property] = key
			local value = self:Resolve(key)
			if value ~= nil then
				instance[property] = value
			end
		end
		return instance
	end

	function Theme:Text(label, color, font, size)
		return self:Style(label, {
			TextColor3 = color or "Text",
			FontFace = font or "FontMedium",
			TextSize = size or "TextSize",
		})
	end

	function Theme:Corner(parent, token)
		local corner = Instance.new("UICorner")
		self:Style(corner, {
			CornerRadius = function(tokens)
				return UDim.new(0, tokens[token])
			end,
		})
		corner.Parent = parent
		return corner
	end

	function Theme:Stroke(parent, token, thickness)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = thickness or 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		self:Style(stroke, { Color = token or "Stroke" })
		stroke.Parent = parent
		return stroke
	end

	function Theme:Subscribe(listener)
		return self.Changed:Connect(listener)
	end

	return Theme
end

Modules.Icons = function()
	local Util = Require("Util")

	local Icons = {}
	Icons.__index = Icons

	-- Glyphs live on a 24x24 grid. Each part is a line, filled dot, ring or rounded box.
	local function L(x1, y1, x2, y2, weight)
		return { "line", x1, y1, x2, y2, weight }
	end

	local function D(cx, cy, radius)
		return { "dot", cx, cy, radius }
	end

	local function C(cx, cy, radius, weight)
		return { "ring", cx, cy, radius, weight }
	end

	local function B(x, y, width, height, radius, weight)
		return { "box", x, y, width, height, radius, weight }
	end

	local Glyphs = {
		["check"] = { L(4.5, 12.5, 9.5, 17.5), L(9.5, 17.5, 19.5, 7) },
		["close"] = { L(6, 6, 18, 18), L(18, 6, 6, 18) },
		["chevron-down"] = { L(6, 9.5, 12, 15.5), L(12, 15.5, 18, 9.5) },
		["chevron-right"] = { L(9.5, 6, 15.5, 12), L(15.5, 12, 9.5, 18) },
		["arrow-right"] = { L(4, 12, 20, 12), L(14, 6, 20, 12), L(14, 18, 20, 12) },
		["plus"] = { L(5, 12, 19, 12), L(12, 5, 12, 19) },
		["search"] = { C(10.5, 10.5, 6.5), L(15.5, 15.5, 20.5, 20.5) },
		["sort"] = { L(4, 6.5, 20, 6.5), L(7, 12, 17, 12), L(10, 17.5, 14, 17.5) },
		["list"] = {
			L(9, 6.5, 20, 6.5), L(9, 12, 20, 12), L(9, 17.5, 20, 17.5),
			D(4.5, 6.5, 1.2), D(4.5, 12, 1.2), D(4.5, 17.5, 1.2),
		},
		["pencil"] = { L(7.5, 16.5, 17.5, 6.5, 3.5), L(3.5, 20.5, 7.5, 16.5, 2), L(13, 21, 21, 21, 1.6) },
		["trash"] = {
			L(4, 6, 20, 6), L(9.5, 3.5, 14.5, 3.5),
			B(6.5, 7, 11, 13.5, 2.5),
			L(10, 11.5, 10, 17), L(14, 11.5, 14, 17),
		},
		["dots"] = { D(5, 12, 1.7), D(12, 12, 1.7), D(19, 12, 1.7) },
		["folder"] = { B(3, 8.5, 18, 10.5, 2.5), L(4, 6.6, 9.5, 6.6, 2.2) },
		["grip"] = { L(19, 9, 9, 19, 1.8), L(19, 14.5, 14.5, 19, 1.8) },
		["bolt"] = {
			L(13, 2.5, 4.5, 13.5), L(4.5, 13.5, 11.5, 13.5), L(11.5, 13.5, 10.5, 21.5),
			L(10.5, 21.5, 19.5, 10), L(19.5, 10, 12.5, 10), L(12.5, 10, 13, 2.5),
		},
		["target"] = { C(12, 12, 9), C(12, 12, 4.8), D(12, 12, 1.4) },
		["eye"] = { B(2.5, 7, 19, 10, 5), D(12, 12, 2.6) },
		["menu"] = { L(4, 7, 20, 7), L(4, 12, 20, 12), L(4, 17, 20, 17) },
		["wind"] = { L(3, 8, 14, 8), L(3, 12.5, 19, 12.5), L(3, 17, 11, 17) },
		["camera"] = { B(3, 6.5, 18, 13, 3), C(12, 13, 3.2) },
		["palette"] = { C(12, 12, 9), D(8.5, 10, 1.4), D(12, 7.5, 1.4), D(15.5, 10, 1.4), D(15.2, 14.8, 1.4) },
		["cart"] = {
			L(3, 4.5, 5.5, 4.5), L(5.5, 4.5, 8, 14.5), L(8, 14.5, 18.5, 14.5),
			L(18.5, 14.5, 20.5, 7.5), L(20.5, 7.5, 6.5, 7.5),
			D(9.5, 19, 1.5), D(17, 19, 1.5),
		},
	}

	local function Atan2(y, x)
		if math.atan2 then
			return math.atan2(y, x)
		end
		return math.atan(y, x)
	end

	local function Build(self, part, scale, multiplier)
		local kind = part[1]
		if kind == "line" then
			local x1, y1, x2, y2 = part[2], part[3], part[4], part[5]
			local weight = (part[6] or 2) * multiplier
			local dx, dy = x2 - x1, y2 - y1
			local length = math.sqrt(dx * dx + dy * dy)
			local frame = Util.Create("Frame", {
				Name = "Line",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset((x1 + x2) / 2 * scale, (y1 + y2) / 2 * scale),
				Size = UDim2.fromOffset((length + weight) * scale, weight * scale),
				Rotation = math.deg(Atan2(dy, dx)),
				Parent = self.Frame,
			})
			Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
			table.insert(self.Fills, frame)
		elseif kind == "dot" then
			local diameter = part[4] * 2 * scale
			local frame = Util.Create("Frame", {
				Name = "Dot",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(part[2] * scale, part[3] * scale),
				Size = UDim2.fromOffset(diameter, diameter),
				Parent = self.Frame,
			})
			Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
			table.insert(self.Fills, frame)
		elseif kind == "ring" then
			local weight = (part[5] or 2) * multiplier
			local diameter = (part[4] * 2 - weight) * scale
			local frame = Util.Create("Frame", {
				Name = "Ring",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(part[2] * scale, part[3] * scale),
				Size = UDim2.fromOffset(diameter, diameter),
				BackgroundTransparency = 1,
				Parent = self.Frame,
			})
			Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
			local stroke = Util.Create("UIStroke", {
				Thickness = weight * scale,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = frame,
			})
			table.insert(self.Strokes, stroke)
		elseif kind == "box" then
			local x, y, width, height = part[2], part[3], part[4], part[5]
			local radius = part[6] or 0
			local weight = (part[7] or 2) * multiplier
			local frame = Util.Create("Frame", {
				Name = "Box",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset((x + width / 2) * scale, (y + height / 2) * scale),
				Size = UDim2.fromOffset((width - weight) * scale, (height - weight) * scale),
				BackgroundTransparency = 1,
				Parent = self.Frame,
			})
			Util.Create("UICorner", {
				CornerRadius = UDim.new(0, math.max(radius - weight / 2, 0) * scale),
				Parent = frame,
			})
			local stroke = Util.Create("UIStroke", {
				Thickness = weight * scale,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = frame,
			})
			table.insert(self.Strokes, stroke)
		end
	end

	function Icons.Has(name)
		return name ~= nil and Glyphs[name] ~= nil
	end

	-- `centered` is for icons placed in a plain parent. Inside a UIListLayout leave it off,
	-- because an AnchorPoint of 0.5 would shift the icon away from its layout slot.
	function Icons.new(theme, name, size, token, parent, centered, weight)
		local glyph = Glyphs[name]
		assert(glyph, "BladeUI: unknown icon '" .. tostring(name) .. "'")
		local self = setmetatable({ Theme = theme, Fills = {}, Strokes = {} }, Icons)
		self.Frame = Util.Create("Frame", {
			Name = "Icon_" .. name,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size, size),
			Parent = parent,
		})
		if centered then
			self.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
			self.Frame.Position = UDim2.fromScale(0.5, 0.5)
		end
		for _, part in ipairs(glyph) do
			Build(self, part, size / 24, weight or 1)
		end
		self:SetToken(token or "Text")
		return self
	end

	function Icons:SetToken(token)
		self.Token = token
		for _, frame in ipairs(self.Fills) do
			self.Theme:Style(frame, { BackgroundColor3 = token })
		end
		for _, stroke in ipairs(self.Strokes) do
			self.Theme:Style(stroke, { Color = token })
		end
	end

	function Icons:Destroy()
		self.Frame:Destroy()
	end

	return Icons
end

Modules.Overlay = function()
	local UserInputService = game:GetService("UserInputService")

	local Util = Require("Util")

	local Overlay = {}
	Overlay.__index = Overlay

	function Overlay.new(ctx, root)
		local theme = ctx.Theme
		local self = setmetatable({}, Overlay)
		self.Ctx = ctx
		self.Current = nil
		self._token = 0
		self._connections = {}

		-- ZIndex order inside Root: Body 1, Scrim 2, Sidebar 3, PopupLayer 4.
		-- The sidebar sits above the scrim on purpose so it stays undimmed.
		self.Scrim = Util.Create("TextButton", {
			Name = "Scrim",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 2,
			Parent = root,
		})
		theme:Style(self.Scrim, { BackgroundColor3 = "Scrim" })
		theme:Corner(self.Scrim, "RadiusPanel")

		self.Layer = Util.Create("Frame", {
			Name = "PopupLayer",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = root,
		})

		table.insert(self._connections, self.Scrim.MouseButton1Click:Connect(function()
			self:Close()
		end))
		table.insert(self._connections, UserInputService.InputBegan:Connect(function(input)
			if self.Current and input.KeyCode == Enum.KeyCode.Escape then
				self:Close()
			end
		end))
		return self
	end

	function Overlay:IsOpen()
		return self.Current ~= nil
	end

	function Overlay:_Place(panel, anchor, options)
		local layerPosition = self.Layer.AbsolutePosition
		local layerSize = self.Layer.AbsoluteSize
		local anchorPosition = anchor.AbsolutePosition - layerPosition
		local anchorSize = anchor.AbsoluteSize
		local width = panel.Size.X.Offset
		local height = panel.Size.Y.Offset
		local gap = options.Gap or 8

		local x = anchorPosition.X
		if options.Align ~= "Left" then
			x = anchorPosition.X + anchorSize.X - width
		end
		local y = anchorPosition.Y + anchorSize.Y + gap
		if y + height > layerSize.Y - 8 then
			y = anchorPosition.Y - height - gap
		end
		x = Util.Clamp(x, 8, math.max(8, layerSize.X - width - 8))
		y = Util.Clamp(y, 8, math.max(8, layerSize.Y - height - 8))

		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = UDim2.fromOffset(x, y)
	end

	-- panel needs an offset-based Size so it can be placed and flipped before layout runs.
	function Overlay:Open(panel, anchor, options)
		options = options or {}
		if self.Current then
			self:Close()
		end
		self._token = self._token + 1
		self.Current = {
			Panel = panel,
			OnClose = options.OnClose,
			Persistent = options.Persistent,
		}
		self.Scrim.Visible = true
		Util.Tween(self.Scrim, { BackgroundTransparency = self.Ctx.Theme.Tokens.ScrimTransparency }, 0.18)
		panel.Parent = self.Layer
		self:_Place(panel, anchor, options)

		local scale = panel:FindFirstChildOfClass("UIScale")
		if not scale then
			scale = Util.Create("UIScale", { Parent = panel })
		end
		scale.Scale = 0.95
		Util.Tween(scale, { Scale = 1 }, 0.16, Enum.EasingStyle.Back)
	end

	function Overlay:Close()
		local current = self.Current
		if not current then
			return
		end
		self.Current = nil
		self._token = self._token + 1
		local token = self._token
		Util.Tween(self.Scrim, { BackgroundTransparency = 1 }, 0.14)
		task.delay(0.14, function()
			if self._token == token then
				self.Scrim.Visible = false
			end
		end)
		if current.Persistent then
			current.Panel.Parent = nil
		else
			current.Panel:Destroy()
		end
		if current.OnClose then
			current.OnClose()
		end
	end

	function Overlay:Destroy()
		Util.Disconnect(self._connections)
	end

	return Overlay
end

Modules.Row = function()
	local Util = Require("Util")

	local Row = {}
	Row.__index = Row

	function Row.new(ctx, section, config)
		local theme = ctx.Theme
		local layout = ctx.Layout
		local self = setmetatable({}, Row)
		self.Ctx = ctx
		self.Section = section
		self.Name = config.Name or "Unnamed"
		self.Flag = config.Flag
		self.Callback = config.Callback
		self.Changed = Util.Signal.new()
		self.Savable = true
		self._connections = {}
		self._disabled = false
		self._hidden = false
		self._filtered = false

		self.Frame = Util.Create("Frame", {
			Name = "Row",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, layout.RowHeight),
			LayoutOrder = section:NextOrder(),
			Parent = section.Body,
		})

		self.Label = Util.Create("TextLabel", {
			Name = "Label",
			Text = self.Name,
			Position = UDim2.fromOffset(layout.RowPadding, 0),
			Size = UDim2.new(1, -layout.RowPadding * 2, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = self.Frame,
		})
		theme:Style(self.Label, {
			TextColor3 = "TextMuted",
			FontFace = "FontMedium",
			TextSize = "TextSize",
		})

		self.Control = Util.Create("Frame", {
			Name = "Control",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -layout.RowPadding, 0.5, 0),
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Parent = self.Frame,
		})
		Util.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
			Parent = self.Control,
		})

		self.Divider = Util.Create("Frame", {
			Name = "Divider",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, -layout.RowPadding * 2, 0, 1),
			Parent = self.Frame,
		})
		theme:Style(self.Divider, { BackgroundColor3 = "Stroke" })

		-- Inset from the edges so the dimming never pokes out past the card's rounded corners.
		self.Shield = Util.Create("TextButton", {
			Name = "Shield",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -12, 1, -8),
			BackgroundTransparency = 0.45,
			Visible = false,
			ZIndex = 20,
			Parent = self.Frame,
		})
		theme:Style(self.Shield, { BackgroundColor3 = "Card" })

		self:_Own(self.Control:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_FitLabel()
		end))
		self:_FitLabel()

		if config.Disabled then
			self:SetDisabled(true)
		end
		return self
	end

	function Row:_FitLabel()
		local layout = self.Ctx.Layout
		local used = self.Control.AbsoluteSize.X + layout.RowPadding * 2 + 8
		self.Label.Size = UDim2.new(1, -used, 1, 0)
	end

	function Row:_Own(connection)
		table.insert(self._connections, connection)
		return connection
	end

	function Row:_Fire(...)
		self.Changed:Fire(...)
		if self.Callback then
			task.spawn(self.Callback, ...)
		end
		self.Ctx.Window:_NotifyChanged(self)
	end

	function Row:IsShown()
		return not self._hidden and not self._filtered
	end

	function Row:_UpdateVisibility()
		self.Frame.Visible = self:IsShown()
		self.Section:_RefreshDividers()
	end

	function Row:SetVisible(state)
		self._hidden = not state
		self:_UpdateVisibility()
	end

	function Row:_SetFiltered(state)
		self._filtered = state
		self.Frame.Visible = self:IsShown()
	end

	function Row:SetName(name)
		self.Name = name
		self.Label.Text = name
	end

	function Row:SetDisabled(state)
		self._disabled = state and true or false
		self.Shield.Visible = self._disabled
	end

	function Row:IsDisabled()
		return self._disabled
	end

	function Row:Destroy()
		Util.Disconnect(self._connections)
		self.Section:_Remove(self)
		self.Frame:Destroy()
	end

	return Row
end

Modules.Toggle = function()
	local Util = Require("Util")
	local Row = Require("Row")
	local Icons = Require("Icons")

	local Toggle = setmetatable({}, { __index = Row })
	Toggle.__index = Toggle

	function Toggle.new(ctx, section, config)
		local theme = ctx.Theme
		local self = setmetatable(Row.new(ctx, section, config), Toggle)
		self._value = config.Default == true

		if config.OnMore then
			self.More = Util.Create("TextButton", {
				Name = "More",
				Size = UDim2.fromOffset(24, 24),
				LayoutOrder = 1,
				Parent = self.Control,
			})
			self.MoreIcon = Icons.new(theme, "dots", 18, "TextMuted", self.More, true)
			self:_Own(self.More.MouseButton1Click:Connect(function()
				if not self._disabled then
					config.OnMore(self)
				end
			end))
		end

		self.Track = Util.Create("TextButton", {
			Name = "Track",
			Size = UDim2.fromOffset(34, 18),
			BackgroundTransparency = 0,
			LayoutOrder = 2,
			Parent = self.Control,
		})
		Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self.Track })
		self.Thumb = Util.Create("Frame", {
			Name = "Thumb",
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Parent = self.Track,
		})
		Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self.Thumb })

		-- The label brightens while the toggle is on, so its color binding reads the state.
		theme:Style(self.Label, {
			TextColor3 = function(tokens)
				return self._value and tokens.Text or tokens.TextMuted
			end,
		})

		self:_Own(self.Track.MouseButton1Click:Connect(function()
			if not self._disabled then
				self:Set(not self._value)
			end
		end))
		self:_Own(theme:Subscribe(function()
			self:_Render(false)
		end))
		self:_Render(false)
		return self
	end

	function Toggle:_Render(animate)
		local tokens = self.Ctx.Theme.Tokens
		local on = self._value
		Util.Apply(self.Track, { BackgroundColor3 = on and tokens.Accent or tokens.Track }, animate, 0.16)
		Util.Apply(self.Thumb, {
			Position = UDim2.new(0, on and 19 or 3, 0.5, 0),
			BackgroundColor3 = on and tokens.Thumb or tokens.ThumbOff,
		}, animate, 0.16)
		Util.Apply(self.Label, { TextColor3 = on and tokens.Text or tokens.TextMuted }, animate, 0.16)
	end

	function Toggle:Get()
		return self._value
	end

	function Toggle:Set(value, silent)
		self._value = value and true or false
		self:_Render(true)
		if not silent then
			self:_Fire(self._value)
		end
	end

	return Toggle
end

Modules.Dropdown = function()
	local Util = Require("Util")
	local Row = Require("Row")
	local Icons = Require("Icons")

	local Dropdown = setmetatable({}, { __index = Row })
	Dropdown.__index = Dropdown

	local ItemHeight = 28

	-- `class` lets MultiDropdown reuse this constructor and override the selection hooks below.
	function Dropdown.new(ctx, section, config, class)
		local theme = ctx.Theme
		local self = setmetatable(Row.new(ctx, section, config), class or Dropdown)
		self.Options = Util.Copy(config.Options or {})
		self._value = self:_Normalize(config.Default)
		self._items = nil
		self._open = false

		self.Button = Util.Create("TextButton", {
			Name = "Button",
			Size = UDim2.new(0, 0, 0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			LayoutOrder = 1,
			Parent = self.Control,
		})
		theme:Style(self.Button, { BackgroundColor3 = "Control" })
		theme:Corner(self.Button, "RadiusControl")
		Util.Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 8),
			Parent = self.Button,
		})
		Util.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			Parent = self.Button,
		})

		self.Value = Util.Create("TextLabel", {
			Name = "Value",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1,
			Parent = self.Button,
		})
		theme:Text(self.Value, "Text", "FontMedium", "TextSize")
		Util.Create("UISizeConstraint", { MinSize = Vector2.new(40, 0), Parent = self.Value })

		self.Chevron = Icons.new(theme, "chevron-down", 14, "TextMuted", self.Button)
		self.Chevron.Frame.LayoutOrder = 2

		self:_Own(self.Button.MouseButton1Click:Connect(function()
			self:Open()
		end))
		self:_Render()
		return self
	end

	function Dropdown:_Normalize(value)
		if Util.IndexOf(self.Options, value) then
			return value
		end
		return self.Options[1]
	end

	function Dropdown:_Display()
		return tostring(self._value or "None")
	end

	function Dropdown:_IsSelected(option)
		return option == self._value
	end

	function Dropdown:_Choose(option)
		self:Set(option)
		self:Close()
	end

	function Dropdown:_Render()
		self.Value.Text = self:_Display()
		if self._items then
			for option in pairs(self._items) do
				self:_RefreshItem(option)
			end
		end
	end

	function Dropdown:_RefreshItem(option)
		local item = self._items and self._items[option]
		if not item then
			return
		end
		local tokens = self.Ctx.Theme.Tokens
		local selected = self:_IsSelected(option)
		item.Check.Frame.Visible = selected
		item.Button.BackgroundTransparency = selected and 0 or (item.Hover and 0.6 or 1)
		item.Text.TextColor3 = (selected or item.Hover) and tokens.Text or tokens.TextMuted
	end

	function Dropdown:_BuildItem(panel, option, index)
		local theme = self.Ctx.Theme
		local button = Util.Create("TextButton", {
			Name = "Option",
			Size = UDim2.new(1, 0, 0, ItemHeight),
			LayoutOrder = index,
			Parent = panel,
		})
		theme:Style(button, { BackgroundColor3 = "Control" })
		theme:Corner(button, "RadiusControl")

		local check = Icons.new(theme, "check", 14, "Accent", button)
		check.Frame.AnchorPoint = Vector2.new(0, 0.5)
		check.Frame.Position = UDim2.new(0, 9, 0.5, 0)

		local text = Util.Create("TextLabel", {
			Name = "Text",
			Text = tostring(option),
			Position = UDim2.fromOffset(32, 0),
			Size = UDim2.new(1, -40, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = button,
		})
		theme:Text(text, "TextMuted", "FontMedium", "TextSize")

		local item = { Button = button, Check = check, Text = text, Hover = false }
		button.MouseEnter:Connect(function()
			item.Hover = true
			self:_RefreshItem(option)
		end)
		button.MouseLeave:Connect(function()
			item.Hover = false
			self:_RefreshItem(option)
		end)
		button.MouseButton1Click:Connect(function()
			self:_Choose(option)
		end)
		return item
	end

	function Dropdown:Open()
		if self._disabled or self._open or #self.Options == 0 then
			return
		end
		local theme = self.Ctx.Theme
		local width = math.max(self.Button.AbsoluteSize.X, 152)
		local height = #self.Options * ItemHeight + 12

		-- Active makes the panel swallow clicks so they never reach the scrim and close it.
		local panel = Util.Create("Frame", {
			Name = "DropdownPanel",
			Size = UDim2.fromOffset(width, height),
			Active = true,
		})
		theme:Style(panel, { BackgroundColor3 = "Panel" })
		theme:Corner(panel, "RadiusCard")
		theme:Stroke(panel, "Stroke", 1)
		Util.Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			Parent = panel,
		})
		Util.Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = panel,
		})

		self._items = {}
		for index, option in ipairs(self.Options) do
			self._items[option] = self:_BuildItem(panel, option, index)
		end
		self._open = true
		self:_Render()
		self.Ctx.Overlay:Open(panel, self.Button, {
			Align = "Right",
			OnClose = function()
				self._open = false
				self._items = nil
			end,
		})
	end

	function Dropdown:Close()
		if self._open then
			self.Ctx.Overlay:Close()
		end
	end

	function Dropdown:Get()
		return self._value
	end

	function Dropdown:Set(value, silent)
		if Util.IndexOf(self.Options, value) == nil then
			return
		end
		self._value = value
		self:_Render()
		if not silent then
			self:_Fire(self._value)
		end
	end

	function Dropdown:SetOptions(options, default)
		self.Options = Util.Copy(options)
		if default == nil then
			default = self._value
		end
		self._value = self:_Normalize(default)
		self:_Render()
	end

	return Dropdown
end

Modules.MultiDropdown = function()
	local Util = Require("Util")
	local Dropdown = Require("Dropdown")

	local MultiDropdown = setmetatable({}, { __index = Dropdown })
	MultiDropdown.__index = MultiDropdown

	function MultiDropdown.new(ctx, section, config)
		return Dropdown.new(ctx, section, config, MultiDropdown)
	end

	-- Keeps only known options and returns them in option order, so equal selections compare equal.
	function MultiDropdown:_Normalize(values)
		local wanted = {}
		for _, value in ipairs(values or {}) do
			wanted[value] = true
		end
		local ordered = {}
		for _, option in ipairs(self.Options) do
			if wanted[option] then
				table.insert(ordered, option)
			end
		end
		return ordered
	end

	function MultiDropdown:_Display()
		local count = #self._value
		if count == 0 then
			return "None"
		end
		if count == 1 then
			return tostring(self._value[1])
		end
		return tostring(self._value[1]) .. ", +" .. (count - 1)
	end

	function MultiDropdown:_IsSelected(option)
		return Util.IndexOf(self._value, option) ~= nil
	end

	function MultiDropdown:_Choose(option)
		local selection = Util.Copy(self._value)
		local index = Util.IndexOf(selection, option)
		if index then
			table.remove(selection, index)
		else
			table.insert(selection, option)
		end
		self:Set(selection)
	end

	function MultiDropdown:Get()
		return Util.Copy(self._value)
	end

	function MultiDropdown:Set(values, silent)
		self._value = self:_Normalize(values)
		self:_Render()
		if not silent then
			self:_Fire(self:Get())
		end
	end

	return MultiDropdown
end

Modules.Slider = function()
	local Util = Require("Util")
	local Row = Require("Row")

	local Slider = setmetatable({}, { __index = Row })
	Slider.__index = Slider

	-- The three builders below are shared with DualSlider.
	function Slider.BuildValue(row, parent, width, alignment, order)
		local label = Util.Create("TextLabel", {
			Name = "Value",
			Size = UDim2.fromOffset(width, 18),
			TextXAlignment = alignment or Enum.TextXAlignment.Right,
			LayoutOrder = order or 1,
			Parent = parent,
		})
		row.Ctx.Theme:Text(label, "Text", "FontMedium", "TextSize")
		return label
	end

	function Slider.BuildTrack(row, parent, width, order)
		local theme = row.Ctx.Theme
		local track = Util.Create("Frame", {
			Name = "Track",
			Size = UDim2.fromOffset(width, 4),
			BackgroundTransparency = 0,
			LayoutOrder = order or 2,
			Parent = parent,
		})
		theme:Style(track, { BackgroundColor3 = "Track" })
		Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

		local fill = Util.Create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			Parent = track,
		})
		theme:Style(fill, { BackgroundColor3 = "Accent" })
		Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })

		local hit = Util.Create("TextButton", {
			Name = "Hit",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 14, 0, 24),
			ZIndex = 3,
			Parent = track,
		})
		return track, fill, hit
	end

	function Slider.BuildThumb(row, track, name)
		local thumb = Util.Create("Frame", {
			Name = name or "Thumb",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(12, 12),
			ZIndex = 2,
			BackgroundTransparency = 0,
			Parent = track,
		})
		row.Ctx.Theme:Style(thumb, { BackgroundColor3 = "Thumb" })
		Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = thumb })
		return thumb
	end

	function Slider.IsWhole(...)
		for _, value in ipairs({ ... }) do
			if value % 1 ~= 0 then
				return false
			end
		end
		return true
	end

	function Slider.new(ctx, section, config)
		local self = setmetatable(Row.new(ctx, section, config), Slider)
		self.Min = config.Min or 0
		self.Max = config.Max or 100
		self.Increment = config.Increment or (Slider.IsWhole(self.Min, self.Max, config.Default or 0) and 1 or 0.1)
		self.Suffix = config.Suffix or ""
		self._value = Util.Snap(config.Default or self.Min, self.Min, self.Max, self.Increment)

		-- Extra right margin keeps the thumb from touching the card edge at the maximum.
		self.Control.Position = UDim2.new(1, -(ctx.Layout.RowPadding + 6), 0.5, 0)
		self.ValueLabel = Slider.BuildValue(self, self.Control, 52, Enum.TextXAlignment.Right, 1)
		self.Track, self.Fill, self.Hit = Slider.BuildTrack(self, self.Control, ctx.Layout.TrackWidth, 2)
		self.Thumb = Slider.BuildThumb(self, self.Track)

		self:_Own(Util.Drag(self.Hit, {
			CanBegin = function()
				return not self._disabled
			end,
			Began = function(pointer)
				self.Section.Tab:SetScrollLocked(true)
				self:_FromPointer(pointer)
			end,
			Changed = function(pointer)
				self:_FromPointer(pointer)
			end,
			Ended = function()
				self.Section.Tab:SetScrollLocked(false)
			end,
		}))
		self:_Own(ctx.Theme:Subscribe(function()
			self:_Render(false)
		end))
		self:_Render(false)
		return self
	end

	function Slider:_Alpha()
		return (self._value - self.Min) / math.max(self.Max - self.Min, 1e-9)
	end

	function Slider:_FromPointer(pointer)
		local width = math.max(self.Track.AbsoluteSize.X, 1)
		local alpha = Util.Clamp((pointer.X - self.Track.AbsolutePosition.X) / width, 0, 1)
		local value = Util.Snap(self.Min + alpha * (self.Max - self.Min), self.Min, self.Max, self.Increment)
		if value ~= self._value then
			self._value = value
			self:_Render(false)
			self:_Fire(value)
		end
	end

	function Slider:_Render(animate)
		local alpha = self:_Alpha()
		self.ValueLabel.Text = Util.Format(self._value, self.Increment, self.Suffix)
		Util.Apply(self.Fill, { Size = UDim2.fromScale(alpha, 1) }, animate, 0.12)
		Util.Apply(self.Thumb, { Position = UDim2.fromScale(alpha, 0.5) }, animate, 0.12)
	end

	function Slider:Get()
		return self._value
	end

	function Slider:Set(value, silent)
		self._value = Util.Snap(tonumber(value) or self.Min, self.Min, self.Max, self.Increment)
		self:_Render(true)
		if not silent then
			self:_Fire(self._value)
		end
	end

	return Slider
end

Modules.DualSlider = function()
	local Util = Require("Util")
	local Row = Require("Row")
	local Slider = Require("Slider")

	local DualSlider = setmetatable({}, { __index = Row })
	DualSlider.__index = DualSlider

	local function BuildBubble(self, thumb)
		local theme = self.Ctx.Theme
		local frame = Util.Create("Frame", {
			Name = "Bubble",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -6),
			Size = UDim2.new(0, 0, 0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			Visible = false,
			ZIndex = 6,
			Parent = thumb,
		})
		theme:Style(frame, { BackgroundColor3 = "Control" })
		theme:Corner(frame, "RadiusControl")
		Util.Create("UIPadding", {
			PaddingLeft = UDim.new(0, 7),
			PaddingRight = UDim.new(0, 7),
			Parent = frame,
		})
		local text = Util.Create("TextLabel", {
			Name = "Text",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 7,
			Parent = frame,
		})
		theme:Text(text, "Text", "FontMedium", "TextSizeSmall")
		return { Frame = frame, Text = text }
	end

	function DualSlider.new(ctx, section, config)
		local theme = ctx.Theme
		local self = setmetatable(Row.new(ctx, section, config), DualSlider)
		self.Min = config.Min or 0
		self.Max = config.Max or 100
		local defaults = config.Default or { self.Min, self.Max }
		local first = defaults[1] or self.Min
		local second = defaults[2] or self.Max
		self.Increment = config.Increment or (Slider.IsWhole(self.Min, self.Max, first, second) and 1 or 0.1)
		self.Suffix = config.Suffix or ""
		local range = self.Max - self.Min
		self.MinDistance = math.max(
			self.Increment,
			Util.Snap(config.MinDistance or range * 0.05, 0, range, self.Increment)
		)
		self._low, self._high = self:_Constrain(first, second)
		self._active = nil

		self.Control.Position = UDim2.new(1, -(ctx.Layout.RowPadding + 6), 0.5, 0)

		self.Values = Util.Create("Frame", {
			Name = "Values",
			Size = UDim2.new(0, 0, 0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = self.Control,
		})
		Util.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
			Parent = self.Values,
		})
		self.LowLabel = Slider.BuildValue(self, self.Values, 30, Enum.TextXAlignment.Right, 1)
		self.Separator = Util.Create("TextLabel", {
			Name = "Separator",
			Text = config.Separator or ctx.Layout.RangeSeparator,
			Size = UDim2.fromOffset(14, 18),
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
			Parent = self.Values,
		})
		theme:Text(self.Separator, "TextMuted", "FontMedium", "TextSize")
		self.HighLabel = Slider.BuildValue(self, self.Values, 30, Enum.TextXAlignment.Left, 3)

		self.Track, self.Fill, self.Hit = Slider.BuildTrack(self, self.Control, ctx.Layout.TrackWidth, 2)
		self.LowThumb = Slider.BuildThumb(self, self.Track, "LowThumb")
		self.HighThumb = Slider.BuildThumb(self, self.Track, "HighThumb")
		self.LowBubble = BuildBubble(self, self.LowThumb)
		self.HighBubble = BuildBubble(self, self.HighThumb)

		self:_Own(Util.Drag(self.Hit, {
			CanBegin = function()
				return not self._disabled
			end,
			Began = function(pointer)
				self:_PickThumb(pointer)
				self.Section.Tab:SetScrollLocked(true)
				self:_Move(pointer)
			end,
			Changed = function(pointer)
				self:_Move(pointer)
			end,
			Ended = function()
				self:_ReleaseThumb()
				self.Section.Tab:SetScrollLocked(false)
			end,
		}))
		self:_Own(theme:Subscribe(function()
			self:_Render(false)
		end))
		self:_Render(false)
		return self
	end

	function DualSlider:_Alpha(value)
		return (value - self.Min) / math.max(self.Max - self.Min, 1e-9)
	end

	function DualSlider:_AlphaAt(pointer)
		local width = math.max(self.Track.AbsoluteSize.X, 1)
		return Util.Clamp((pointer.X - self.Track.AbsolutePosition.X) / width, 0, 1)
	end

	-- Keeps both values on the grid, ordered, and at least MinDistance apart.
	function DualSlider:_Constrain(low, high)
		low = Util.Snap(tonumber(low) or self.Min, self.Min, self.Max, self.Increment)
		high = Util.Snap(tonumber(high) or self.Max, self.Min, self.Max, self.Increment)
		if low > high then
			low, high = high, low
		end
		if high - low < self.MinDistance then
			if low + self.MinDistance <= self.Max then
				high = low + self.MinDistance
			else
				high = self.Max
				low = high - self.MinDistance
			end
		end
		return low, high
	end

	-- The thumb closest to the pointer wins. On an exact tie the pointer side decides.
	function DualSlider:_PickThumb(pointer)
		local alpha = self:_AlphaAt(pointer)
		local lowAlpha = self:_Alpha(self._low)
		local highAlpha = self:_Alpha(self._high)
		local lowDistance = math.abs(alpha - lowAlpha)
		local highDistance = math.abs(alpha - highAlpha)
		if lowDistance == highDistance then
			self._active = alpha < lowAlpha and "Low" or "High"
		else
			self._active = lowDistance < highDistance and "Low" or "High"
		end
		local thumb = self._active == "Low" and self.LowThumb or self.HighThumb
		local other = self._active == "Low" and self.HighThumb or self.LowThumb
		thumb.ZIndex = 3
		other.ZIndex = 2
		local bubble = self._active == "Low" and self.LowBubble or self.HighBubble
		bubble.Frame.Visible = true
	end

	function DualSlider:_ReleaseThumb()
		self._active = nil
		self.LowBubble.Frame.Visible = false
		self.HighBubble.Frame.Visible = false
	end

	function DualSlider:_Move(pointer)
		if not self._active then
			return
		end
		local value = Util.Snap(
			self.Min + self:_AlphaAt(pointer) * (self.Max - self.Min),
			self.Min,
			self.Max,
			self.Increment
		)
		local low, high = self._low, self._high
		if self._active == "Low" then
			low = Util.Clamp(value, self.Min, high - self.MinDistance)
		else
			high = Util.Clamp(value, low + self.MinDistance, self.Max)
		end
		if low ~= self._low or high ~= self._high then
			self._low, self._high = low, high
			self:_Render(false)
			self:_Fire({ low, high }, low, high)
		end
	end

	function DualSlider:_Render(animate)
		local lowAlpha = self:_Alpha(self._low)
		local highAlpha = self:_Alpha(self._high)
		local lowText = Util.Format(self._low, self.Increment, self.Suffix)
		local highText = Util.Format(self._high, self.Increment, self.Suffix)
		self.LowLabel.Text = lowText
		self.HighLabel.Text = highText
		self.LowBubble.Text.Text = lowText
		self.HighBubble.Text.Text = highText
		Util.Apply(self.Fill, {
			Position = UDim2.fromScale(lowAlpha, 0),
			Size = UDim2.fromScale(highAlpha - lowAlpha, 1),
		}, animate, 0.12)
		Util.Apply(self.LowThumb, { Position = UDim2.fromScale(lowAlpha, 0.5) }, animate, 0.12)
		Util.Apply(self.HighThumb, { Position = UDim2.fromScale(highAlpha, 0.5) }, animate, 0.12)
	end

	function DualSlider:Get()
		return { self._low, self._high }
	end

	function DualSlider:Set(values, silent)
		values = values or {}
		self._low, self._high = self:_Constrain(values[1], values[2])
		self:_Render(true)
		if not silent then
			self:_Fire({ self._low, self._high }, self._low, self._high)
		end
	end

	return DualSlider
end

Modules.Label = function()
	local Util = Require("Util")
	local Row = Require("Row")

	local Label = setmetatable({}, { __index = Row })
	Label.__index = Label

	function Label.new(ctx, section, config)
		local self = setmetatable(Row.new(ctx, section, config), Label)
		self.Savable = false
		self.Control:Destroy()

		self.Frame.Size = UDim2.new(1, 0, 0, 0)
		self.Frame.AutomaticSize = Enum.AutomaticSize.Y

		-- Padding lives on the label itself so the automatic height includes it.
		Util.Create("UIPadding", {
			PaddingTop = UDim.new(0, 13),
			PaddingBottom = UDim.new(0, 13),
			Parent = self.Label,
		})
		self.Label.Position = UDim2.fromOffset(ctx.Layout.RowPadding, 0)
		self.Label.Size = UDim2.new(1, -ctx.Layout.RowPadding * 2, 0, 0)
		self.Label.AutomaticSize = Enum.AutomaticSize.Y
		self.Label.TextWrapped = true
		self.Label.TextTruncate = Enum.TextTruncate.None
		self.Label.TextYAlignment = Enum.TextYAlignment.Top
		self._text = config.Text or config.Name or ""
		self.Label.Text = self._text
		return self
	end

	function Label:Get()
		return self._text
	end

	function Label:Set(text)
		self._text = tostring(text)
		self.Label.Text = self._text
	end

	return Label
end

Modules.Section = function()
	local Util = Require("Util")
	local Toggle = Require("Toggle")
	local Dropdown = Require("Dropdown")
	local MultiDropdown = Require("MultiDropdown")
	local Slider = Require("Slider")
	local DualSlider = Require("DualSlider")
	local Label = Require("Label")

	local Section = {}
	Section.__index = Section

	function Section.new(ctx, tab, name, side, column, order)
		local theme = ctx.Theme
		local self = setmetatable({}, Section)
		self.Ctx = ctx
		self.Tab = tab
		self.Name = name
		self.Side = side
		self.Rows = {}
		self._order = 0

		self.Frame = Util.Create("Frame", {
			Name = "Section",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = column,
		})
		Util.Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			Parent = self.Frame,
		})

		self.Header = Util.Create("TextLabel", {
			Name = "Header",
			Text = name,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 1,
			Parent = self.Frame,
		})
		Util.Create("UIPadding", { PaddingLeft = UDim.new(0, 2), Parent = self.Header })
		theme:Text(self.Header, "Text", "FontBold", "TextSizeLarge")

		self.Body = Util.Create("Frame", {
			Name = "Card",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0,
			LayoutOrder = 2,
			Parent = self.Frame,
		})
		theme:Style(self.Body, { BackgroundColor3 = "Card" })
		theme:Corner(self.Body, "RadiusCard")
		Util.Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = self.Body,
		})
		return self
	end

	function Section:NextOrder()
		self._order = self._order + 1
		return self._order
	end

	function Section:_Add(class, config)
		local control = class.new(self.Ctx, self, config)
		table.insert(self.Rows, control)
		self.Tab:_AddHeight(self.Side, self.Ctx.Layout.RowHeight)
		self:_RefreshDividers()
		if control.Savable then
			self.Tab.Window:_Register(control)
		end
		return control
	end

	function Section:_Remove(row)
		local index = Util.IndexOf(self.Rows, row)
		if index then
			table.remove(self.Rows, index)
		end
		self.Tab.Window:_Unregister(row)
		self:_RefreshDividers()
	end

	function Section:AddToggle(config)
		return self:_Add(Toggle, config)
	end

	function Section:AddDropdown(config)
		return self:_Add(Dropdown, config)
	end

	function Section:AddMultiDropdown(config)
		return self:_Add(MultiDropdown, config)
	end

	function Section:AddSlider(config)
		return self:_Add(Slider, config)
	end

	function Section:AddDualSlider(config)
		return self:_Add(DualSlider, config)
	end

	function Section:AddLabel(config)
		if type(config) == "string" then
			config = { Text = config }
		end
		return self:_Add(Label, Util.Merge(config, { Name = config.Name or config.Text }))
	end

	function Section:SetName(name)
		self.Name = name
		self.Header.Text = name
	end

	-- The last visible row never draws its divider, so the card ends cleanly.
	function Section:_RefreshDividers()
		local last
		for _, row in ipairs(self.Rows) do
			if row:IsShown() then
				row.Divider.Visible = true
				last = row
			end
		end
		if last then
			last.Divider.Visible = false
		end
	end

	-- A section whose own name matches shows all of its rows.
	function Section:ApplyFilter(query)
		local needle = query:lower()
		local sectionMatches = needle == "" or self.Name:lower():find(needle, 1, true) ~= nil
		local anyShown = false
		for _, row in ipairs(self.Rows) do
			local matches = sectionMatches or row.Name:lower():find(needle, 1, true) ~= nil
			row:_SetFiltered(not matches)
			if matches then
				anyShown = true
			end
		end
		self.Frame.Visible = anyShown or (#self.Rows == 0 and sectionMatches)
		self:_RefreshDividers()
	end

	return Section
end

Modules.Tab = function()
	local Util = Require("Util")
	local Section = Require("Section")

	local Tab = {}
	Tab.__index = Tab

	local ColumnGap = 14
	local SectionOverhead = 22 + 6 + ColumnGap

	function Tab.new(ctx, window, config)
		local theme = ctx.Theme
		local self = setmetatable({}, Tab)
		self.Ctx = ctx
		self.Window = window
		self.Name = config.Name or "Tab"
		self.Icon = config.Icon
		self.PageName = nil
		self.Sections = {}
		self._order = 0
		self._heights = { Left = 0, Right = 0 }
		self._connections = {}

		self.Page = Util.Create("ScrollingFrame", {
			Name = "Page_" .. self.Name,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 3,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Visible = false,
			Parent = window.Pages,
		})
		theme:Style(self.Page, { ScrollBarImageColor3 = "Track" })
		Util.Create("UIPadding", { PaddingRight = UDim.new(0, 14), Parent = self.Page })

		self.Left = Util.Create("Frame", {
			Name = "Left",
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -ColumnGap / 2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = self.Page,
		})
		self.Right = Util.Create("Frame", {
			Name = "Right",
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, ColumnGap / 2, 0, 0),
			Size = UDim2.new(0.5, -ColumnGap / 2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = self.Page,
		})
		local leftLayout = Util.Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ColumnGap),
			Parent = self.Left,
		})
		local rightLayout = Util.Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ColumnGap),
			Parent = self.Right,
		})

		-- Canvas height is driven by the taller column, plus room for the bottom fade.
		local function FitCanvas()
			local height = math.max(leftLayout.AbsoluteContentSize.Y, rightLayout.AbsoluteContentSize.Y)
			self.Page.CanvasSize = UDim2.fromOffset(0, height + 40)
		end
		table.insert(self._connections, leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(FitCanvas))
		table.insert(self._connections, rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(FitCanvas))
		return self
	end

	function Tab:_AddHeight(side, amount)
		self._heights[side] = self._heights[side] + amount
	end

	-- `side` is "Left" or "Right". Without it the section goes to whichever column is shorter so far.
	function Tab:CreateSection(config, side)
		local name = config
		if type(config) == "table" then
			name = config.Name
			side = config.Side or side
		end
		if side ~= "Left" and side ~= "Right" then
			side = self._heights.Left <= self._heights.Right and "Left" or "Right"
		end
		self._order = self._order + 1
		local section = Section.new(self.Ctx, self, name or "Section", side, self[side], self._order)
		self._heights[side] = self._heights[side] + SectionOverhead
		table.insert(self.Sections, section)
		return section
	end

	function Tab:SetPage(name)
		self.PageName = name
		if self.Window.ActiveTab == self then
			self.Window.Breadcrumb:Set(self)
		end
	end

	function Tab:GetPageName()
		if self.PageName then
			return self.PageName
		end
		local first = self.Sections[1]
		return first and first.Name or ""
	end

	function Tab:ApplyFilter(query)
		for _, section in ipairs(self.Sections) do
			section:ApplyFilter(query)
		end
	end

	function Tab:SetScrollLocked(locked)
		self.Page.ScrollingEnabled = not locked
	end

	function Tab:Destroy()
		Util.Disconnect(self._connections)
		self.Page:Destroy()
	end

	return Tab
end

Modules.TabList = function()
	local Util = Require("Util")
	local Icons = Require("Icons")

	local TabList = {}
	TabList.__index = TabList

	local ItemHeight = 30
	local ItemGap = 2

	function TabList.new(ctx, window, parent, config)
		local theme = ctx.Theme
		local layout = ctx.Layout
		local self = setmetatable({}, TabList)
		self.Ctx = ctx
		self.Window = window
		self.Items = {}

		-- Sits flush against the window's left edge (SidebarOverhang equals SidebarWidth), no overlap.
		self.Frame = Util.Create("Frame", {
			Name = "Sidebar",
			Position = UDim2.fromOffset(-layout.SidebarOverhang, layout.SidebarInset),
			Size = UDim2.new(0, layout.SidebarWidth, 1, -layout.SidebarInset * 2),
			ZIndex = 3,
			Parent = parent,
		})
		theme:Style(self.Frame, { BackgroundColor3 = "Panel" })
		theme:Corner(self.Frame, "RadiusPanel")
		theme:Stroke(self.Frame, "Stroke", 1)

		self.Logo = Util.Create("Frame", {
			Name = "Logo",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 52),
			Parent = self.Frame,
		})
		local logoImage = Util.ResolveImage(config.Logo)
		if logoImage then
			Util.Create("ImageLabel", {
				Name = "Mark",
				Image = logoImage,
				Position = UDim2.fromOffset(16, 15),
				Size = UDim2.fromOffset(22, 22),
				Parent = self.Logo,
			})
		else
			local mark = Icons.new(theme, "bolt", 22, "Accent", self.Logo)
			mark.Frame.Position = UDim2.fromOffset(16, 15)
		end
		self.Title = Util.Create("TextLabel", {
			Name = "Title",
			Text = config.Title or "",
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(1, -54, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = self.Logo,
		})
		theme:Text(self.Title, "Text", "FontBold", "TextSizeTitle")

		self.Nav = Util.Create("Frame", {
			Name = "Nav",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 56),
			Size = UDim2.new(1, 0, 1, -122),
			Parent = self.Frame,
		})
		Util.Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ItemGap),
			Parent = self.Nav,
		})

		self.Footer = Util.Create("Frame", {
			Name = "Footer",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -12),
			Size = UDim2.new(1, 0, 0, 40),
			Parent = self.Frame,
		})
		self.Avatar = Util.Create("Frame", {
			Name = "Avatar",
			Position = UDim2.fromOffset(14, 3),
			Size = UDim2.fromOffset(34, 34),
			Parent = self.Footer,
		})
		theme:Style(self.Avatar, { BackgroundColor3 = "Background" })
		Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self.Avatar })
		theme:Stroke(self.Avatar, "Stroke", 1)
		self.AvatarInitial = Util.Create("TextLabel", {
			Name = "Initial",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = self.Avatar,
		})
		theme:Text(self.AvatarInitial, "Text", "FontBold", "TextSizeLarge")
		self.AvatarImage = Util.Create("ImageLabel", {
			Name = "Image",
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Parent = self.Avatar,
		})
		Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self.AvatarImage })
		self.ProfileName = Util.Create("TextLabel", {
			Name = "Name",
			Position = UDim2.fromOffset(58, 3),
			Size = UDim2.new(1, -66, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = self.Footer,
		})
		theme:Text(self.ProfileName, "Text", "FontSemibold", "TextSize")
		self.ProfileSubtitle = Util.Create("TextLabel", {
			Name = "Subtitle",
			Position = UDim2.fromOffset(58, 21),
			Size = UDim2.new(1, -66, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = self.Footer,
		})
		theme:Text(self.ProfileSubtitle, "TextMuted", "FontRegular", "TextSizeSmall")
		self:SetProfile(config.Profile or {})

		self._subscription = theme:Subscribe(function()
			for _, item in ipairs(self.Items) do
				self:_Paint(item, false)
			end
		end)
		return self
	end

	function TabList:SetProfile(profile)
		local name = profile.Name or ""
		local subtitle = profile.Subtitle or ""
		self.ProfileName.Text = name
		self.ProfileSubtitle.Text = subtitle
		self.AvatarInitial.Text = name:sub(1, 1):upper()
		local image = Util.ResolveImage(profile.Avatar)
		self.AvatarImage.Visible = image ~= nil
		if image then
			self.AvatarImage.Image = image
		end
		self.Footer.Visible = name ~= "" or subtitle ~= ""
	end

	function TabList:SetTitle(title)
		self.Title.Text = title
	end

	function TabList:_Paint(item, animate)
		local tokens = self.Ctx.Theme.Tokens
		local active = item.Active
		local color = active and tokens.Text or tokens.TextMuted
		Util.Apply(item.Pill, {
			BackgroundTransparency = active and 0 or (item.Hover and 0.65 or 1),
		}, animate, 0.14)
		Util.Apply(item.Label, { TextColor3 = color }, animate, 0.14)
		Util.Apply(item.Bar, {
			BackgroundTransparency = active and 0 or 1,
			Size = UDim2.fromOffset(3, active and 16 or 6),
		}, animate, 0.16)
		if item.Icon then
			item.Icon:SetToken(active and "Text" or "TextMuted")
		end
		if item.Image then
			Util.Apply(item.Image, { ImageColor3 = color }, animate, 0.14)
		end
	end

	function TabList:AddTab(tab)
		local theme = self.Ctx.Theme
		local item = { Tab = tab, Active = false, Hover = false }

		item.Button = Util.Create("TextButton", {
			Name = "Nav_" .. tab.Name,
			Size = UDim2.new(1, 0, 0, ItemHeight),
			LayoutOrder = #self.Items + 1,
			Parent = self.Nav,
		})
		item.Pill = Util.Create("Frame", {
			Name = "Pill",
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, 0),
			BackgroundTransparency = 1,
			Parent = item.Button,
		})
		theme:Style(item.Pill, { BackgroundColor3 = "Control" })
		theme:Corner(item.Pill, "RadiusControl")

		item.Bar = Util.Create("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 6),
			BackgroundTransparency = 1,
			Parent = item.Button,
		})
		theme:Style(item.Bar, { BackgroundColor3 = "Accent" })
		Util.Create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = item.Bar })

		if Icons.Has(tab.Icon) then
			item.Icon = Icons.new(theme, tab.Icon, 16, "TextMuted", item.Pill)
			item.Icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
			item.Icon.Frame.Position = UDim2.new(0, 12, 0.5, 0)
		else
			local image = Util.ResolveImage(tab.Icon)
			if image then
				item.Image = Util.Create("ImageLabel", {
					Name = "Icon",
					Image = image,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 12, 0.5, 0),
					Size = UDim2.fromOffset(16, 16),
					Parent = item.Pill,
				})
			end
		end

		local hasIcon = item.Icon ~= nil or item.Image ~= nil
		item.Label = Util.Create("TextLabel", {
			Name = "Label",
			Text = tab.Name,
			Position = UDim2.fromOffset(hasIcon and 36 or 14, 0),
			Size = UDim2.new(1, hasIcon and -44 or -22, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = item.Pill,
		})
		theme:Style(item.Label, { FontFace = "FontMedium", TextSize = "TextSize" })

		item.Button.MouseEnter:Connect(function()
			item.Hover = true
			self:_Paint(item, true)
		end)
		item.Button.MouseLeave:Connect(function()
			item.Hover = false
			self:_Paint(item, true)
		end)
		item.Button.MouseButton1Click:Connect(function()
			self.Window:SelectTab(tab)
		end)

		table.insert(self.Items, item)
		self:_Paint(item, false)
		return item
	end

	function TabList:Select(tab)
		for _, item in ipairs(self.Items) do
			item.Active = item.Tab == tab
			self:_Paint(item, true)
		end
	end

	function TabList:Destroy()
		if self._subscription then
			self._subscription:Disconnect()
		end
	end

	return TabList
end

Modules.Breadcrumb = function()
	local Util = Require("Util")
	local Icons = Require("Icons")

	local Breadcrumb = {}
	Breadcrumb.__index = Breadcrumb

	function Breadcrumb.new(ctx, parent)
		local theme = ctx.Theme
		local self = setmetatable({}, Breadcrumb)
		self.Ctx = ctx

		self.Frame = Util.Create("Frame", {
			Name = "Breadcrumb",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, ctx.Layout.BreadcrumbTop),
			Size = UDim2.new(1, -2, 0, 20),
			Parent = parent,
		})
		Util.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			Parent = self.Frame,
		})

		self.IconSlot = Util.Create("Frame", {
			Name = "IconSlot",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(16, 16),
			LayoutOrder = 1,
			Parent = self.Frame,
		})
		self.TabLabel = Util.Create("TextLabel", {
			Name = "Tab",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
			Parent = self.Frame,
		})
		theme:Text(self.TabLabel, "Text", "FontMedium", "TextSize")

		self.Arrow = Icons.new(theme, "arrow-right", 14, "TextMuted", self.Frame)
		self.Arrow.Frame.LayoutOrder = 3

		self.PageLabel = Util.Create("TextLabel", {
			Name = "Page",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 4,
			Parent = self.Frame,
		})
		theme:Text(self.PageLabel, "TextMuted", "FontMedium", "TextSize")
		return self
	end

	function Breadcrumb:Set(tab)
		local theme = self.Ctx.Theme
		for _, child in ipairs(self.IconSlot:GetChildren()) do
			child:Destroy()
		end
		local hasIcon = false
		if Icons.Has(tab.Icon) then
			Icons.new(theme, tab.Icon, 16, "Text", self.IconSlot)
			hasIcon = true
		else
			local image = Util.ResolveImage(tab.Icon)
			if image then
				local label = Util.Create("ImageLabel", {
					Name = "Icon",
					Image = image,
					Size = UDim2.fromScale(1, 1),
					Parent = self.IconSlot,
				})
				theme:Style(label, { ImageColor3 = "Text" })
				hasIcon = true
			end
		end
		self.IconSlot.Visible = hasIcon
		self.TabLabel.Text = tab.Name

		local page = tab:GetPageName()
		self.PageLabel.Text = page
		self.PageLabel.Visible = page ~= ""
		self.Arrow.Frame.Visible = page ~= ""
	end

	return Breadcrumb
end

Modules.TopBar = function()
	local Util = Require("Util")
	local Icons = Require("Icons")

	local TopBar = {}
	TopBar.__index = TopBar

	function TopBar.new(ctx, parent, config)
		local theme = ctx.Theme
		local layout = ctx.Layout
		local self = setmetatable({}, TopBar)
		self.Ctx = ctx
		self.Changed = Util.Signal.new()
		self._connections = {}
		self._pillCallback = nil
		self._content = nil

		self.Frame = Util.Create("Frame", {
			Name = "TopBar",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, layout.TopBarTop),
			Size = UDim2.new(1, 0, 0, layout.TopBarHeight),
			ZIndex = 2,
			Parent = parent,
		})

		self.SearchFrame = Util.Create("Frame", {
			Name = "Search",
			Size = UDim2.new(0, layout.SearchWidth, 1, 0),
			BackgroundTransparency = 0,
			Parent = self.Frame,
		})
		theme:Style(self.SearchFrame, { BackgroundColor3 = "Card" })
		theme:Corner(self.SearchFrame, "RadiusCard")
		self.SearchStroke = theme:Stroke(self.SearchFrame, "Card", 1)

		local magnifier = Icons.new(theme, "search", 16, "TextMuted", self.SearchFrame)
		magnifier.Frame.AnchorPoint = Vector2.new(0, 0.5)
		magnifier.Frame.Position = UDim2.new(0, 14, 0.5, 0)

		self.SearchBox = Util.Create("TextBox", {
			Name = "Input",
			PlaceholderText = config.SearchPlaceholder or "Search element",
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, -52, 1, 0),
			Parent = self.SearchFrame,
		})
		theme:Text(self.SearchBox, "Text", "FontMedium", "TextSize")
		theme:Style(self.SearchBox, { PlaceholderColor3 = "TextMuted" })

		table.insert(self._connections, self.SearchBox.Focused:Connect(function()
			theme:Style(self.SearchStroke, { Color = "Accent" })
		end))
		table.insert(self._connections, self.SearchBox.FocusLost:Connect(function()
			theme:Style(self.SearchStroke, { Color = "Card" })
		end))
		table.insert(self._connections, self.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
			self.Changed:Fire(self.SearchBox.Text)
		end))

		self.Pill = Util.Create("TextButton", {
			Name = "Pill",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			Parent = self.Frame,
		})
		theme:Style(self.Pill, { BackgroundColor3 = "Card" })
		theme:Corner(self.Pill, "RadiusCard")
		Util.Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 14),
			Parent = self.Pill,
		})
		Util.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
			Parent = self.Pill,
		})
		self.PillText = Util.Create("TextLabel", {
			Name = "Text",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1,
			Parent = self.Pill,
		})
		theme:Text(self.PillText, "Text", "FontMedium", "TextSize")
		self.PillIcon = Icons.new(theme, "folder", 16, "TextMuted", self.Pill)
		self.PillIcon.Frame.LayoutOrder = 2

		table.insert(self._connections, self.Pill.MouseButton1Click:Connect(function()
			if self._pillCallback then
				self._pillCallback()
			end
		end))
		self:SetPill(config.Pill or {})
		return self
	end

	-- Text, Icon (a built-in glyph name, or false to hide it) and Callback are all optional.
	-- Content is any GuiObject that replaces the default text and icon.
	function TopBar:SetPill(options)
		local theme = self.Ctx.Theme
		if options.Text ~= nil then
			self.PillText.Text = options.Text
		end
		if options.Callback ~= nil then
			self._pillCallback = options.Callback
		end
		if options.Icon ~= nil then
			self.PillIcon:Destroy()
			if options.Icon then
				self.PillIcon = Icons.new(theme, options.Icon, 16, "TextMuted", self.Pill)
				self.PillIcon.Frame.LayoutOrder = 2
			else
				self.PillIcon = Icons.new(theme, "folder", 16, "TextMuted", self.Pill)
				self.PillIcon.Frame.LayoutOrder = 2
				self.PillIcon.Frame.Visible = false
			end
		end
		if options.Content then
			if self._content then
				self._content:Destroy()
			end
			self._content = options.Content
			self._content.LayoutOrder = 1
			self._content.Parent = self.Pill
			self.PillText.Visible = false
			self.PillIcon.Frame.Visible = false
		end
	end

	function TopBar:SetPillText(text)
		self.PillText.Text = text
	end

	function TopBar:GetQuery()
		return self.SearchBox.Text
	end

	function TopBar:Destroy()
		Util.Disconnect(self._connections)
	end

	return TopBar
end

Modules.ConfigPanel = function()
	local Util = Require("Util")
	local Icons = Require("Icons")

	local ConfigPanel = {}
	ConfigPanel.__index = ConfigPanel

	local SortModes = { "Created", "A-Z", "Z-A" }
	local EntryHeight = 38
	local EntryGap = 7
	local PanelWidth = 260
	local PanelHeight = 334
	local DefaultName = "New config"

	-- config.Storage = { Read = function() return snapshot end, Write = function(snapshot) end }
	-- lets the host persist presets however it likes (DataStore, writefile, remote).
	function ConfigPanel.new(ctx, window, config)
		config = config or {}
		local self = setmetatable({}, ConfigPanel)
		self.Ctx = ctx
		self.Window = window
		self.Entries = {}
		self.Active = nil
		self.Query = ""
		self.SortMode = 1
		self.AutoSave = config.AutoSave ~= false
		self.Storage = config.Storage
		self.Changed = Util.Signal.new()
		self._connections = {}
		self._saveToken = 0
		self._applying = false
		self:_Build()

		if self.Storage and self.Storage.Read then
			local ok, snapshot = pcall(self.Storage.Read)
			if ok and type(snapshot) == "table" then
				self:Import(snapshot)
			end
		end

		table.insert(self._connections, window.Changed:Connect(function()
			if self.AutoSave and self.Active and not self._applying then
				self:_QueueSave()
			end
		end))
		return self
	end

	function ConfigPanel:_Build()
		local theme = self.Ctx.Theme

		-- Active makes the panel swallow clicks so they never reach the scrim and close it.
		self.Panel = Util.Create("Frame", {
			Name = "ConfigPanel",
			Size = UDim2.fromOffset(PanelWidth, PanelHeight),
			Active = true,
		})
		theme:Style(self.Panel, { BackgroundColor3 = "Panel" })
		theme:Corner(self.Panel, "RadiusPanel")
		theme:Stroke(self.Panel, "Stroke", 1)

		local chip = Util.Create("Frame", {
			Name = "Chip",
			Position = UDim2.fromOffset(12, 11),
			Size = UDim2.new(0, 0, 0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			Parent = self.Panel,
		})
		theme:Style(chip, { BackgroundColor3 = "Card" })
		theme:Corner(chip, "RadiusControl")
		Util.Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 12),
			Parent = chip,
		})
		Util.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			Parent = chip,
		})
		local chipIcon = Icons.new(theme, "list", 16, "TextMuted", chip)
		chipIcon.Frame.LayoutOrder = 1
		local chipText = Util.Create("TextLabel", {
			Name = "Title",
			Text = "Presets",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
			Parent = chip,
		})
		theme:Text(chipText, "Text", "FontMedium", "TextSize")

		self.AddButton = Util.Create("TextButton", {
			Name = "Add",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 11),
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 0,
			Parent = self.Panel,
		})
		theme:Style(self.AddButton, { BackgroundColor3 = "Card" })
		theme:Corner(self.AddButton, "RadiusControl")
		Icons.new(theme, "plus", 16, "Text", self.AddButton, true)
		table.insert(self._connections, self.AddButton.MouseButton1Click:Connect(function()
			self:Add(nil, nil, true)
		end))

		local divider = Util.Create("Frame", {
			Name = "Divider",
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = self.Panel,
		})
		theme:Style(divider, { BackgroundColor3 = "Stroke" })

		local search = Util.Create("Frame", {
			Name = "Search",
			Position = UDim2.fromOffset(12, 64),
			Size = UDim2.new(1, -62, 0, 32),
			BackgroundTransparency = 0,
			Parent = self.Panel,
		})
		theme:Style(search, { BackgroundColor3 = "Card" })
		theme:Corner(search, "RadiusControl")
		local magnifier = Icons.new(theme, "search", 14, "TextMuted", search)
		magnifier.Frame.AnchorPoint = Vector2.new(0, 0.5)
		magnifier.Frame.Position = UDim2.new(0, 11, 0.5, 0)
		self.SearchBox = Util.Create("TextBox", {
			Name = "Input",
			PlaceholderText = "Search",
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -42, 1, 0),
			Parent = search,
		})
		theme:Text(self.SearchBox, "Text", "FontMedium", "TextSize")
		theme:Style(self.SearchBox, { PlaceholderColor3 = "TextMuted" })
		table.insert(self._connections, self.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
			self.Query = self.SearchBox.Text
			self:_Rebuild()
		end))

		self.SortButton = Util.Create("TextButton", {
			Name = "Sort",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 64),
			Size = UDim2.fromOffset(32, 32),
			BackgroundTransparency = 0,
			Parent = self.Panel,
		})
		theme:Style(self.SortButton, { BackgroundColor3 = "Card" })
		theme:Corner(self.SortButton, "RadiusControl")
		self.SortIcon = Icons.new(theme, "sort", 16, "TextMuted", self.SortButton, true)
		table.insert(self._connections, self.SortButton.MouseButton1Click:Connect(function()
			self.SortMode = self.SortMode % #SortModes + 1
			self.SortIcon:SetToken(self.SortMode == 1 and "TextMuted" or "Accent")
			self:_Rebuild()
		end))

		self.List = Util.Create("ScrollingFrame", {
			Name = "List",
			Position = UDim2.fromOffset(12, 108),
			Size = UDim2.new(1, -24, 1, -120),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 3,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			Parent = self.Panel,
		})
		theme:Style(self.List, { ScrollBarImageColor3 = "Track" })
		Util.Create("UIPadding", { PaddingRight = UDim.new(0, 8), Parent = self.List })
		Util.Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, EntryGap),
			Parent = self.List,
		})
	end

	function ConfigPanel:_Visible()
		local needle = self.Query:lower()
		local list = {}
		for _, entry in ipairs(self.Entries) do
			if needle == "" or entry.Name:lower():find(needle, 1, true) then
				table.insert(list, entry)
			end
		end
		if self.SortMode == 2 then
			table.sort(list, function(a, b)
				return a.Name:lower() < b.Name:lower()
			end)
		elseif self.SortMode == 3 then
			table.sort(list, function(a, b)
				return a.Name:lower() > b.Name:lower()
			end)
		end
		return list
	end

	function ConfigPanel:_Rebuild()
		for _, child in ipairs(self.List:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local visible = self:_Visible()
		for index, entry in ipairs(visible) do
			self:_BuildEntry(entry, index)
		end
		self.List.CanvasSize = UDim2.fromOffset(0, #visible * (EntryHeight + EntryGap))
	end

	function ConfigPanel:_BuildEntry(entry, index)
		local theme = self.Ctx.Theme
		local active = entry == self.Active

		local row = Util.Create("TextButton", {
			Name = "Entry",
			Size = UDim2.new(1, 0, 0, EntryHeight),
			BackgroundTransparency = 0,
			LayoutOrder = index,
			Parent = self.List,
		})
		theme:Style(row, { BackgroundColor3 = active and "Control" or "Card" })
		theme:Corner(row, "RadiusControl")

		local label = Util.Create("TextLabel", {
			Name = "Name",
			Text = entry.Name,
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -92, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		theme:Text(label, "Text", "FontMedium", "TextSize")
		local edit = Util.Create("TextBox", {
			Name = "Edit",
			Text = entry.Name,
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -92, 1, 0),
			Visible = false,
			Parent = row,
		})
		theme:Text(edit, "Text", "FontMedium", "TextSize")

		local renameButton = Util.Create("TextButton", {
			Name = "Rename",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -40, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			Parent = row,
		})
		local pencil = Icons.new(theme, "pencil", 16, active and "Text" or "TextMuted", renameButton, true)
		local deleteButton = Util.Create("TextButton", {
			Name = "Delete",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			Parent = row,
		})
		local trash = Icons.new(theme, "trash", 16, active and "Danger" or "TextMuted", deleteButton, true)

		local hover = false
		local function Emphasize()
			local tokens = theme.Tokens
			local on = active or hover
			pencil:SetToken(on and "Text" or "TextMuted")
			trash:SetToken(on and "Danger" or "TextMuted")
			row.BackgroundColor3 = on and tokens.Control or tokens.Card
		end

		row.MouseEnter:Connect(function()
			hover = true
			Emphasize()
		end)
		row.MouseLeave:Connect(function()
			hover = false
			Emphasize()
		end)
		row.MouseButton1Click:Connect(function()
			self:Select(entry)
		end)
		renameButton.MouseButton1Click:Connect(function()
			label.Visible = false
			edit.Text = entry.Name
			edit.Visible = true
			edit:CaptureFocus()
		end)
		edit.FocusLost:Connect(function()
			local text = Util.Trim(edit.Text)
			edit.Visible = false
			label.Visible = true
			if text ~= "" and text ~= entry.Name then
				self:Rename(entry, text)
			end
		end)
		deleteButton.MouseButton1Click:Connect(function()
			self:Remove(entry)
		end)
	end

	function ConfigPanel:_UniqueName(base)
		local taken = {}
		for _, entry in ipairs(self.Entries) do
			taken[entry.Name] = true
		end
		if not taken[base] then
			return base
		end
		local number = 2
		while taken[base .. " " .. number] do
			number = number + 1
		end
		return base .. " " .. number
	end

	function ConfigPanel:_Activate(entry)
		self.Active = entry
		self.Window.TopBar:SetPillText(entry.Name)
		self:_Rebuild()
		self:_Persist()
		self.Changed:Fire(entry)
	end

	function ConfigPanel:Add(name, data, select)
		local entry = {
			Name = name or self:_UniqueName(DefaultName),
			Data = data and Util.DeepCopy(data) or self.Window:SaveConfig(),
		}
		table.insert(self.Entries, entry)
		if select then
			self:_Activate(entry)
		else
			self:_Rebuild()
			self:_Persist()
			self.Changed:Fire(entry)
		end
		return entry
	end

	function ConfigPanel:Select(entry)
		self._applying = true
		self.Window:LoadConfig(entry.Data)
		self._applying = false
		self:_Activate(entry)
	end

	function ConfigPanel:Rename(entry, name)
		entry.Name = name
		if entry == self.Active then
			self.Window.TopBar:SetPillText(name)
		end
		self:_Rebuild()
		self:_Persist()
		self.Changed:Fire(entry)
	end

	function ConfigPanel:Remove(entry)
		local index = Util.IndexOf(self.Entries, entry)
		if not index then
			return
		end
		table.remove(self.Entries, index)
		if self.Active == entry then
			self.Active = nil
		end
		self:_Rebuild()
		self:_Persist()
		self.Changed:Fire(nil)
	end

	function ConfigPanel:Export()
		local entries = {}
		local activeIndex
		for index, entry in ipairs(self.Entries) do
			entries[index] = { Name = entry.Name, Data = Util.DeepCopy(entry.Data) }
			if entry == self.Active then
				activeIndex = index
			end
		end
		return { Active = activeIndex, Entries = entries }
	end

	function ConfigPanel:Import(snapshot)
		self.Entries = {}
		self.Active = nil
		for index, saved in ipairs(snapshot.Entries or {}) do
			local entry = {
				Name = tostring(saved.Name or DefaultName),
				Data = Util.DeepCopy(saved.Data or {}),
			}
			table.insert(self.Entries, entry)
			if snapshot.Active == index then
				self.Active = entry
			end
		end
		if self.Active and self.Window.TopBar then
			self.Window.TopBar:SetPillText(self.Active.Name)
		end
		self:_Rebuild()
		self.Changed:Fire(self.Active)
	end

	function ConfigPanel:_Persist()
		if self.Storage and self.Storage.Write then
			local ok, err = pcall(self.Storage.Write, self:Export())
			if not ok then
				warn("BladeUI: config storage write failed: " .. tostring(err))
			end
		end
	end

	-- Control changes are batched so dragging a slider writes the active preset once, not per tick.
	function ConfigPanel:_QueueSave()
		self._saveToken = self._saveToken + 1
		local token = self._saveToken
		task.delay(0.6, function()
			if token == self._saveToken and self.Active then
				self.Active.Data = self.Window:SaveConfig()
				self:_Persist()
			end
		end)
	end

	function ConfigPanel:Destroy()
		Util.Disconnect(self._connections)
		self.Panel:Destroy()
	end

	return ConfigPanel
end

Modules.Window = function()
	local UserInputService = game:GetService("UserInputService")

	local Util = Require("Util")
	local Theme = Require("Theme")
	local Icons = Require("Icons")
	local Overlay = Require("Overlay")
	local TopBar = Require("TopBar")
	local Breadcrumb = Require("Breadcrumb")
	local TabList = Require("TabList")
	local Tab = Require("Tab")
	local ConfigPanel = Require("ConfigPanel")

	local Window = {}
	Window.__index = Window

	local DefaultLayout = {
		Width = 654,
		Height = 500,
		MinWidth = 574,
		MinHeight = 440,
		MaxWidth = 1400,
		MaxHeight = 900,
		SidebarWidth = 172,
		SidebarOverhang = 172,
		SidebarInset = 12,
		ContentLeft = 12,
		ContentRight = 12,
		TopBarTop = 12,
		TopBarHeight = 38,
		SearchWidth = 284,
		BreadcrumbTop = 62,
		PageTop = 94,
		PageBottom = 14,
		RowHeight = 44,
		RowPadding = 12,
		TrackWidth = 104,
		RangeSeparator = "↔",
	}

	local function ResolveParent(config)
		if config.Parent then
			return config.Parent
		end
		return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	end

	function Window.new(library, config)
		local self = setmetatable({}, Window)
		self.Library = library
		self.Title = config.Title or "Window"
		self.Tabs = {}
		self.Flags = {}
		self.ActiveTab = nil
		self.Changed = Util.Signal.new()
		self._connections = {}
		self.Theme = Theme.new(config.Theme or "Purple")
		local theme = self.Theme

		local size = config.Size or Vector2.new(DefaultLayout.Width, DefaultLayout.Height)
		local layout = Util.Merge(DefaultLayout, { Width = size.X, Height = size.Y })
		local ctx = { Window = self, Theme = theme, Layout = layout, Library = library }
		self.Ctx = ctx

		self.Gui = Util.Create("ScreenGui", {
			Name = "BladeUI_" .. self.Title,
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = config.DisplayOrder or 100,
			Parent = ResolveParent(config),
		})

		-- Root is the window body only. The sidebar sits flush against its left edge, so Root is
		-- nudged right by half the sidebar width to center the pair. Dragging only touches the offset.
		self.Root = Util.Create("Frame", {
			Name = "Root",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, layout.SidebarOverhang / 2, 0.5, 0),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundTransparency = 1,
			Parent = self.Gui,
		})
		Util.Shadow(self.Root, theme, 8, 3)

		self.Body = Util.Create("Frame", {
			Name = "Body",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			Parent = self.Root,
		})
		theme:Style(self.Body, { BackgroundColor3 = "Background" })
		theme:Corner(self.Body, "RadiusPanel")
		theme:Stroke(self.Body, "Stroke", 1)

		self.Content = Util.Create("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(layout.ContentLeft, 0),
			Size = UDim2.new(1, -(layout.ContentLeft + layout.ContentRight), 1, 0),
			Parent = self.Body,
		})
		self.DragArea = Util.Create("Frame", {
			Name = "DragArea",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, layout.PageTop - 4),
			ZIndex = 0,
			Parent = self.Content,
		})

		self.TopBar = TopBar.new(ctx, self.Content, {
			SearchPlaceholder = config.SearchPlaceholder,
			Pill = Util.Merge({
				Text = "Presets",
				Callback = function()
					self:OpenConfigs()
				end,
			}, config.Pill),
		})
		self.Breadcrumb = Breadcrumb.new(ctx, self.Content)
		self.Pages = Util.Create("Frame", {
			Name = "Pages",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, layout.PageTop),
			Size = UDim2.new(1, 0, 1, -(layout.PageTop + layout.PageBottom)),
			Parent = self.Content,
		})

		self.Fade = Util.Create("Frame", {
			Name = "Fade",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -layout.PageBottom),
			Size = UDim2.new(1, 0, 0, 36),
			ZIndex = 5,
			Parent = self.Content,
		})
		theme:Style(self.Fade, { BackgroundColor3 = "Background" })
		Util.Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Parent = self.Fade,
		})

		self.TabList = TabList.new(ctx, self, self.Root, {
			Title = self.Title,
			Logo = config.Logo,
			Profile = config.Profile,
		})
		self.Overlay = Overlay.new(ctx, self.Root)
		ctx.Overlay = self.Overlay
		self.Configs = ConfigPanel.new(ctx, self, config.Configs)

		self.Grip = Util.Create("Frame", {
			Name = "Grip",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -4),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			ZIndex = 10,
			Parent = self.Body,
		})
		Icons.new(theme, "grip", 14, "Track", self.Grip, true)

		self:_AttachDrag(self.DragArea)
		self:_AttachDrag(self.TabList.Logo)
		self:_AttachResize()

		table.insert(self._connections, self.TopBar.Changed:Connect(function(query)
			self:ApplyFilter(query)
		end))
		if config.ToggleKey then
			table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
				if not processed and input.KeyCode == config.ToggleKey then
					self:Toggle()
				end
			end))
		end
		return self
	end

	function Window:_AttachDrag(handle)
		local startPosition
		table.insert(self._connections, Util.Drag(handle, {
			Began = function()
				self.Overlay:Close()
				startPosition = self.Root.Position
			end,
			Changed = function(pointer, origin)
				local delta = pointer - origin
				self.Root.Position = UDim2.new(
					startPosition.X.Scale,
					startPosition.X.Offset + delta.X,
					startPosition.Y.Scale,
					startPosition.Y.Offset + delta.Y
				)
			end,
		}))
	end

	function Window:_AttachResize()
		local layout = self.Ctx.Layout
		local startSize, startPosition
		table.insert(self._connections, Util.Drag(self.Grip, {
			Began = function()
				self.Overlay:Close()
				startSize = self.Root.AbsoluteSize
				startPosition = self.Root.Position
			end,
			Changed = function(pointer, origin)
				local delta = pointer - origin
				local width = Util.Clamp(startSize.X + delta.X, layout.MinWidth, layout.MaxWidth)
				local height = Util.Clamp(startSize.Y + delta.Y, layout.MinHeight, layout.MaxHeight)
				self.Root.Size = UDim2.fromOffset(width, height)
				-- Half the growth is added to the centre so the top-left corner stays where it was.
				self.Root.Position = UDim2.new(
					startPosition.X.Scale,
					startPosition.X.Offset + (width - startSize.X) / 2,
					startPosition.Y.Scale,
					startPosition.Y.Offset + (height - startSize.Y) / 2
				)
			end,
		}))
	end

	function Window:CreateTab(name, icon)
		local tab = Tab.new(self.Ctx, self, { Name = name, Icon = icon })
		table.insert(self.Tabs, tab)
		self.TabList:AddTab(tab)
		if not self.ActiveTab then
			self:SelectTab(tab)
		end
		return tab
	end

	function Window:SelectTab(tab)
		if self.ActiveTab == tab then
			return
		end
		self.Overlay:Close()
		if self.ActiveTab then
			self.ActiveTab.Page.Visible = false
		end
		self.ActiveTab = tab
		tab.Page.Visible = true
		self.TabList:Select(tab)
		self.Breadcrumb:Set(tab)
		tab:ApplyFilter(self.TopBar:GetQuery())
	end

	function Window:ApplyFilter(query)
		for _, tab in ipairs(self.Tabs) do
			tab:ApplyFilter(query)
		end
	end

	function Window:OpenConfigs()
		self.Overlay:Open(self.Configs.Panel, self.TopBar.Pill, { Align = "Right", Persistent = true })
	end

	function Window:SetPill(options)
		self.TopBar:SetPill(options)
	end

	function Window:SetProfile(profile)
		self.TabList:SetProfile(profile)
	end

	function Window:SetTheme(source)
		self.Theme:Apply(source)
	end

	function Window:_Register(control)
		local section = control.Section
		local base = control.Flag or (section.Tab.Name .. "/" .. section.Name .. "/" .. control.Name)
		local flag = base
		local number = 2
		while self.Flags[flag] do
			flag = base .. " #" .. number
			number = number + 1
		end
		control.Flag = flag
		self.Flags[flag] = control
	end

	function Window:_Unregister(control)
		if control.Flag and self.Flags[control.Flag] == control then
			self.Flags[control.Flag] = nil
		end
	end

	function Window:_NotifyChanged(control)
		self.Changed:Fire(control)
	end

	function Window:SaveConfig()
		local data = {}
		for flag, control in pairs(self.Flags) do
			data[flag] = control:Get()
		end
		return data
	end

	function Window:LoadConfig(data, silent)
		for flag, value in pairs(data) do
			local control = self.Flags[flag]
			if control then
				control:Set(value, silent)
			end
		end
	end

	function Window:SetVisible(state)
		if not state then
			self.Overlay:Close()
		end
		self.Root.Visible = state
	end

	function Window:IsVisible()
		return self.Root.Visible
	end

	function Window:Toggle()
		self:SetVisible(not self.Root.Visible)
	end

	function Window:Destroy()
		Util.Disconnect(self._connections)
		self.Overlay:Destroy()
		self.TopBar:Destroy()
		self.TabList:Destroy()
		self.Configs:Destroy()
		self.Gui:Destroy()
		local windows = self.Library.Windows
		local index = Util.IndexOf(windows, self)
		if index then
			table.remove(windows, index)
		end
	end

	return Window
end

Modules.init = function()
	local Theme = Require("Theme")
	local Util = Require("Util")
	local Icons = Require("Icons")
	local Window = Require("Window")

	local Library = {
		Version = "1.0.0",
		Themes = Theme.Presets,
		Util = Util,
		Icons = Icons,
		Windows = {},
	}

	function Library:CreateWindow(config)
		local window = Window.new(self, config or {})
		table.insert(self.Windows, window)
		return window
	end

	-- Accepts a full token table. Anything left out falls back to the Purple defaults.
	function Library:RegisterTheme(name, tokens)
		Theme.Presets[name] = tokens
	end

	function Library:Destroy()
		for index = #self.Windows, 1, -1 do
			self.Windows[index]:Destroy()
		end
	end

	return Library
end

return Require("init")
