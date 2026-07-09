local FRAMEWORK_NAME = "No comment"
local VERSION = "1.0.0"

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ReusingFramework = shared.NoComment
	and shared.NoComment.__version
	and shared.NoComment.Gui
	and shared.NoComment.Gui.Parent == PlayerGui

local Framework

if ReusingFramework then
	Framework = shared.NoComment
else
	Framework = {
		__version = VERSION,
		Name = FRAMEWORK_NAME,
		Ready = false,
		Windows = {},
		Plugins = {},
		Modules = {},
		Controls = {},
		Config = {},
		Theme = {},
		Signals = {},
		RecentControls = {},
		FavoriteControls = {},
	}

	shared.NoComment = Framework

--// Utility

local Util = {}

function Util.SafeCall(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end

	local ok, result = xpcall(fn, debug.traceback, ...)
	if not ok then
		warn("[No comment callback error]:", result)
		return nil
	end

	return result
end

function Util.New(className, props, children)
	local inst = Instance.new(className)

	for k, v in pairs(props or {}) do
		inst[k] = v
	end

	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end

	return inst
end

function Util.ClampToViewport(frame, minVisible)
	local camera = workspace.CurrentCamera
	if not camera then return end

	minVisible = minVisible or 48

	local viewport = camera.ViewportSize
	local pos = frame.AbsolutePosition
	local size = frame.AbsoluteSize

	-- allow hanging off-screen as long as `minVisible` px stay reachable
	local x = math.clamp(pos.X, minVisible - size.X, viewport.X - minVisible)
	-- keep the header at/below the top edge so it stays draggable
	local y = math.clamp(pos.Y, 0, viewport.Y - minVisible)

	if x ~= pos.X or y ~= pos.Y then
		frame.Position = UDim2.fromOffset(x, y)
	end
end

function Util.Round(n, places)
	local mult = 10 ^ (places or 0)
	return math.floor(n * mult + 0.5) / mult
end

function Util.FuzzyMatch(query, text)
	query = string.lower(query or "")
	text = string.lower(text or "")

	if query == "" then
		return true, 0
	end

	local score = 0
	local qi = 1

	for i = 1, #text do
		if string.sub(text, i, i) == string.sub(query, qi, qi) then
			score += 1
			qi += 1
			if qi > #query then
				return true, score
			end
		end
	end

	return false, score
end

Framework.Util = Util

--// Signal

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		_connections = {},
		_destroyed = false,
	}, Signal)
end

function Signal:Connect(fn)
	if self._destroyed then
		return { Disconnect = function() end }
	end

	local connection = {
		Connected = true,
		_fn = fn,
	}

	function connection:Disconnect()
		self.Connected = false
	end

	table.insert(self._connections, connection)
	return connection
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		Util.SafeCall(fn, ...)
	end)
	return conn
end

function Signal:Fire(...)
	if self._destroyed then return end

	for _, conn in ipairs(table.clone(self._connections)) do
		if conn.Connected then
			Util.SafeCall(conn._fn, ...)
		end
	end
end

function Signal:Destroy()
	self._destroyed = true
	table.clear(self._connections)
end

Framework.Signal = Signal

--// Maid

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
	table.insert(self._tasks, task)
	return task
end

function Maid:Clean()
	for _, task in ipairs(self._tasks) do
		if typeof(task) == "RBXScriptConnection" then
			task:Disconnect()
		elseif typeof(task) == "Instance" then
			task:Destroy()
		elseif type(task) == "table" and task.Destroy then
			task:Destroy()
		elseif type(task) == "function" then
			Util.SafeCall(task)
		end
	end

	table.clear(self._tasks)
end

Framework.Maid = Maid

--// Theme Engine

local Themes = {
	Dark = {
		Background = Color3.fromRGB(18, 18, 22),
		Panel = Color3.fromRGB(28, 29, 36),
		Panel2 = Color3.fromRGB(38, 40, 50),
		Stroke = Color3.fromRGB(70, 75, 90),
		Text = Color3.fromRGB(240, 242, 247),
		MutedText = Color3.fromRGB(165, 170, 185),
		Accent = Color3.fromRGB(125, 95, 255),
		Accent2 = Color3.fromRGB(50, 190, 255),
		Danger = Color3.fromRGB(255, 88, 88),
		Success = Color3.fromRGB(80, 220, 145),
		Warning = Color3.fromRGB(255, 190, 80),
	},
	Light = {
		Background = Color3.fromRGB(244, 246, 250),
		Panel = Color3.fromRGB(255, 255, 255),
		Panel2 = Color3.fromRGB(235, 238, 245),
		Stroke = Color3.fromRGB(205, 210, 222),
		Text = Color3.fromRGB(20, 24, 32),
		MutedText = Color3.fromRGB(90, 96, 112),
		Accent = Color3.fromRGB(100, 80, 240),
		Accent2 = Color3.fromRGB(30, 145, 220),
		Danger = Color3.fromRGB(220, 60, 60),
		Success = Color3.fromRGB(40, 165, 95),
		Warning = Color3.fromRGB(220, 150, 40),
	}
}

Framework.Theme.Name = "Dark"
Framework.Theme.Values = table.clone(Themes.Dark)
Framework.Theme.Changed = Signal.new()

function Framework.SetTheme(nameOrTable)
	if type(nameOrTable) == "string" and Themes[nameOrTable] then
		Framework.Theme.Name = nameOrTable
		Framework.Theme.Values = table.clone(Themes[nameOrTable])
	elseif type(nameOrTable) == "table" then
		for k, v in pairs(nameOrTable) do
			Framework.Theme.Values[k] = v
		end
		Framework.Theme.Name = "Custom"
	end

	Framework.Theme.Changed:Fire(Framework.Theme.Values)
end

local function ApplyCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function ApplyStroke(parent, color, thickness, transparency)
	return Util.New("UIStroke", {
		Color = color or Framework.Theme.Values.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

--// Root GUI

local old = PlayerGui:FindFirstChild("NoCommentGui")
if old then old:Destroy() end

local ScreenGui = Util.New("ScreenGui", {
	Name = "NoCommentGui",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 2147483000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = PlayerGui,
})

Framework.Gui = ScreenGui

local Root = Util.New("Frame", {
	Name = "Root",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Parent = ScreenGui,
})

--// Animator

local Animator = {
	Cache = {},
}

function Animator.Tween(obj, info, props)
	local tween = TweenService:Create(obj, info, props)
	tween:Play()
	return tween
end

function Animator.FadeIn(obj, duration)
	obj.Visible = true
	obj.BackgroundTransparency = 1
	return Animator.Tween(obj, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0,
	})
end

function Animator.Pop(obj)
	obj.Size = UDim2.fromScale(0.96, 0.96)
	return Animator.Tween(obj, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1, 1),
	})
end

Framework.Animator = Animator

--// Config Manager

local ConfigManager = {
	Profiles = {},
	ActiveProfile = "Default",
	Changed = Signal.new(),
}

function ConfigManager:Get()
	self.Profiles[self.ActiveProfile] = self.Profiles[self.ActiveProfile] or {
		Windows = {},
		Controls = {},
		Theme = "Dark",
	}
	return self.Profiles[self.ActiveProfile]
end

function ConfigManager:Set(path, value)
	local cfg = self:Get()
	cfg[path] = value
	self.Changed:Fire(cfg)
end

function ConfigManager:Export()
	return HttpService:JSONEncode(self.Profiles)
end

function ConfigManager:Import(json)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)

	if ok and type(data) == "table" then
		self.Profiles = data
		self.Changed:Fire(self:Get())
		return true
	end

	return false
end

Framework.ConfigManager = ConfigManager

--// Notification Manager

local Notifications = Util.New("Frame", {
	Name = "Notifications",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(330, 600),
	BackgroundTransparency = 1,
	Parent = Root,
})

Util.New("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 10),
	Parent = Notifications,
})

local NotificationManager = {
	Queue = {},
}

function NotificationManager.Notify(opts)
	opts = opts or {}

	local theme = Framework.Theme.Values

	local item = Util.New("Frame", {
		Name = "Notification",
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Panel,
		BackgroundTransparency = 0.04,
		Parent = Notifications,
	})

	ApplyCorner(item, 12)
	ApplyStroke(item, theme.Stroke, 1, 0.25)

	local pad = Util.New("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = item,
	})

	local title = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBold,
		Text = opts.Title or FRAMEWORK_NAME,
		TextColor3 = theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = item,
	})

	local body = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		Text = opts.Text or "",
		TextColor3 = theme.MutedText,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = item,
	})

	item.Position = UDim2.fromOffset(40, 0)
	item.BackgroundTransparency = 1

	Animator.Tween(item, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 0.04,
	})

	task.delay(opts.Duration or 4, function()
		if item.Parent then
			local t = Animator.Tween(item, TweenInfo.new(0.2), {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(40, 0),
			})
			t.Completed:Once(function()
				if item then item:Destroy() end
			end)
		end
	end)

	return item
end

Framework.Notify = NotificationManager.Notify
Framework.NotificationManager = NotificationManager

--// Control base

local function TrackControl(control)
	table.insert(Framework.Controls, control)
	table.insert(Framework.RecentControls, 1, control)
	if #Framework.RecentControls > 50 then
		table.remove(Framework.RecentControls)
	end
end

local function CreateControlApi(frame, defaultValue)
	local value = defaultValue
	local changed = Signal.new()

	local api = {
		Instance = frame,
		Changed = changed,
		Default = defaultValue,
	}

	function api:Get()
		return value
	end

	function api:Set(v, silent)
		value = v
		if not silent then
			changed:Fire(v)
		end
	end

	function api:Reset()
		self:Set(defaultValue)
	end

	function api:Destroy()
		changed:Destroy()
		if frame then frame:Destroy() end
	end

	TrackControl(api)
	return api
end

--// Section API

local Section = {}
Section.__index = Section

function Section:AddLabel(text)
	local theme = Framework.Theme.Values

	local label = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.Gotham,
		Text = text or "Label",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.Content,
	})

	return CreateControlApi(label, text)
end

function Section:AddParagraph(titleText, bodyText)
	local theme = Framework.Theme.Values

	local frame = Util.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.Content,
	})

	Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBold,
		Text = titleText or "Paragraph",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		Text = bodyText or "",
		TextColor3 = theme.MutedText,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	return CreateControlApi(frame, bodyText)
end

function Section:AddDivider()
	local theme = Framework.Theme.Values

	local line = Util.New("Frame", {
		BackgroundColor3 = theme.Stroke,
		BackgroundTransparency = 0.25,
		Size = UDim2.new(1, 0, 0, 1),
		Parent = self.Content,
	})

	return CreateControlApi(line, nil)
end

function Section:AddButton(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values

	local button = Util.New("TextButton", {
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = theme.Panel2,
		Text = opts.Text or opts.Title or "Button",
		Font = Enum.Font.GothamMedium,
		TextColor3 = theme.Text,
		TextSize = 13,
		Parent = self.Content,
	})

	ApplyCorner(button, 8)
	ApplyStroke(button, theme.Stroke, 1, 0.35)

	button.MouseEnter:Connect(function()
		Animator.Tween(button, TweenInfo.new(0.12), { BackgroundColor3 = theme.Accent })
	end)

	button.MouseLeave:Connect(function()
		Animator.Tween(button, TweenInfo.new(0.12), { BackgroundColor3 = theme.Panel2 })
	end)

	button.Activated:Connect(function()
		Util.SafeCall(opts.Callback)
	end)

	return CreateControlApi(button, false)
end

function Section:AddToggle(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values

	local frame = Util.New("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = self.Content,
	})

	local label = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -56, 1, 0),
		Font = Enum.Font.Gotham,
		Text = opts.Text or opts.Title or "Toggle",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local button = Util.New("TextButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(46, 24),
		BackgroundColor3 = theme.Panel2,
		Text = "",
		Parent = frame,
	})

	ApplyCorner(button, 999)

	local knob = Util.New("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = theme.MutedText,
		Parent = button,
	})

	ApplyCorner(knob, 999)

	local api = CreateControlApi(frame, opts.Default == true)

	local function render(v)
		Animator.Tween(button, TweenInfo.new(0.16), {
			BackgroundColor3 = v and theme.Accent or theme.Panel2,
		})
		Animator.Tween(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quint), {
			Position = v and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
			BackgroundColor3 = v and Color3.new(1, 1, 1) or theme.MutedText,
		})
	end

	local oldSet = api.Set
	function api:Set(v, silent)
		oldSet(self, v == true, silent)
		render(v == true)
		Util.SafeCall(opts.Callback, v == true)
	end

	button.Activated:Connect(function()
		api:Set(not api:Get())
	end)

	render(api:Get())

	return api
end

function Section:AddSlider(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values

	local min = opts.Min or 0
	local max = opts.Max or 100
	local default = math.clamp(opts.Default or min, min, max)

	local frame = Util.New("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		Parent = self.Content,
	})

	local label = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.Gotham,
		Text = opts.Text or opts.Title or "Slider",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local valueLabel = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(70, 20),
		Font = Enum.Font.GothamMedium,
		TextColor3 = theme.MutedText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})

	local bar = Util.New("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = theme.Panel2,
		Parent = frame,
	})

	ApplyCorner(bar, 999)

	local fill = Util.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Accent,
		Parent = bar,
	})

	ApplyCorner(fill, 999)

	local api = CreateControlApi(frame, default)
	local dragging = false

	local function render(v)
		local alpha = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		valueLabel.Text = tostring(Util.Round(v, opts.Precision or 0))
	end

	local function setFromX(x)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
		local raw = min + (max - min) * alpha
		local step = opts.Step or 1
		local val = math.clamp(math.round(raw / step) * step, min, max)
		api:Set(val)
	end

	local oldSet = api.Set
	function api:Set(v, silent)
		v = math.clamp(tonumber(v) or min, min, max)
		oldSet(self, v, silent)
		render(v)
		Util.SafeCall(opts.Callback, v)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)

	render(default)
	return api
end

function Section:AddTextbox(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values

	local box = Util.New("TextBox", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = theme.Panel2,
		PlaceholderText = opts.Placeholder or "",
		Text = opts.Default or "",
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextColor3 = theme.Text,
		PlaceholderColor3 = theme.MutedText,
		TextSize = 13,
		Parent = self.Content,
	})

	ApplyCorner(box, 8)
	ApplyStroke(box, theme.Stroke, 1, 0.35)

	local api = CreateControlApi(box, opts.Default or "")

	local oldSet = api.Set
	function api:Set(v, silent)
		v = tostring(v or "")
		oldSet(self, v, silent)
		box.Text = v
		Util.SafeCall(opts.Callback, v)
	end

	box.FocusLost:Connect(function()
		api:Set(box.Text)
	end)

	return api
end

function Section:AddDropdown(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values
	local values = opts.Values or opts.Options or {}

	local button = Util.New("TextButton", {
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = theme.Panel2,
		Text = "",
		Parent = self.Content,
	})

	ApplyCorner(button, 8)
	ApplyStroke(button, theme.Stroke, 1, 0.35)

	local label = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Font = Enum.Font.Gotham,
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(opts.Default or values[1] or "Select"),
		Parent = button,
	})

	local api = CreateControlApi(button, opts.Default or values[1])

	local popup

	local function close()
		if popup then
			popup:Destroy()
			popup = nil
		end
	end

	button.Activated:Connect(function()
		if popup then close() return end

		popup = Util.New("Frame", {
			Name = "DropdownPopup",
			Position = UDim2.fromOffset(button.AbsolutePosition.X, button.AbsolutePosition.Y + button.AbsoluteSize.Y + 4),
			Size = UDim2.fromOffset(button.AbsoluteSize.X, math.min(180, #values * 32)),
			BackgroundColor3 = theme.Panel,
			Parent = Root,
			ZIndex = 10000,
		})

		ApplyCorner(popup, 8)
		ApplyStroke(popup, theme.Stroke, 1, 0.25)

		Util.New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = popup,
		})

		for _, value in ipairs(values) do
			local option = Util.New("TextButton", {
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
				Text = tostring(value),
				Font = Enum.Font.Gotham,
				TextColor3 = theme.Text,
				TextSize = 13,
				Parent = popup,
				ZIndex = 10001,
			})

			option.Activated:Connect(function()
				api:Set(value)
				close()
			end)
		end
	end)

	local oldSet = api.Set
	function api:Set(v, silent)
		oldSet(self, v, silent)
		label.Text = tostring(v)
		Util.SafeCall(opts.Callback, v)
	end

	return api
end

function Section:AddProgress(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values

	local frame = Util.New("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = self.Content,
	})

	local bar = Util.New("Frame", {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = theme.Panel2,
		Parent = frame,
	})

	ApplyCorner(bar, 999)

	local fill = Util.New("Frame", {
		Size = UDim2.fromScale(opts.Default or 0, 1),
		BackgroundColor3 = opts.Color or theme.Accent,
		Parent = bar,
	})

	ApplyCorner(fill, 999)

	local api = CreateControlApi(frame, opts.Default or 0)

	local oldSet = api.Set
	function api:Set(v, silent)
		v = math.clamp(tonumber(v) or 0, 0, 1)
		oldSet(self, v, silent)
		Animator.Tween(fill, TweenInfo.new(0.18), {
			Size = UDim2.fromScale(v, 1),
		})
	end

	return api
end

function Section:AddCheckbox(opts)
	opts = opts or {}
	return self:AddToggle(opts)
end

function Section:AddRadio(opts)
	opts = opts or {}
	return self:AddDropdown(opts)
end

function Section:AddBadge(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values

	local label = Util.New("TextLabel", {
		Size = UDim2.new(0, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = opts.Color or theme.Accent,
		Text = "  " .. tostring(opts.Text or "Badge") .. "  ",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 12,
		Parent = self.Content,
	})

	ApplyCorner(label, 999)
	return CreateControlApi(label, opts.Text)
end

function Section:AddColorPicker(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values

	local current = opts.Default or theme.Accent

	local button = Util.New("TextButton", {
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = theme.Panel2,
		Text = opts.Text or opts.Title or "Color",
		Font = Enum.Font.Gotham,
		TextColor3 = theme.Text,
		TextSize = 13,
		Parent = self.Content,
	})

	ApplyCorner(button, 8)

	local swatch = Util.New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = current,
		Parent = button,
	})

	ApplyCorner(swatch, 6)

	local api = CreateControlApi(button, current)

	local oldSet = api.Set
	function api:Set(v, silent)
		if typeof(v) == "Color3" then
			oldSet(self, v, silent)
			swatch.BackgroundColor3 = v
			Util.SafeCall(opts.Callback, v)
		end
	end

	button.Activated:Connect(function()
		local h, s, v = current:ToHSV()
		h = (h + 0.08) % 1
		current = Color3.fromHSV(h, s, v)
		api:Set(current)
	end)

	return api
end

-- aliases / simple implementations
Section.AddRangeSlider = Section.AddSlider
Section.AddMultiSelect = Section.AddDropdown
Section.AddKeybind = Section.AddTextbox
Section.AddTreeView = Section.AddParagraph
Section.AddImageButton = Section.AddButton
Section.AddTooltip = Section.AddParagraph
Section.AddRichText = Section.AddParagraph

--// Tab API

local Tab = {}
Tab.__index = Tab

function Tab:AddSection(title)
	local theme = Framework.Theme.Values

	local sectionFrame = Util.New("Frame", {
		Name = title or "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Panel,
		Parent = self.Content,
	})

	ApplyCorner(sectionFrame, 10)
	ApplyStroke(sectionFrame, theme.Stroke, 1, 0.45)

	Util.New("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = sectionFrame,
	})

	local layout = Util.New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = sectionFrame,
	})

	local header = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBold,
		Text = title or "Section",
		TextColor3 = theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = -100,
		Parent = sectionFrame,
	})

	local section = setmetatable({
		Frame = sectionFrame,
		Content = sectionFrame,
		Title = title,
	}, Section)

	table.insert(self.Sections, section)
	return section
end

--// Window API

local Window = {}
Window.__index = Window

local nextZ = 20

local function focusWindow(win)
	nextZ += 1
	win.Frame.ZIndex = nextZ
	win.Body.ZIndex = nextZ
	win.Header.ZIndex = nextZ + 1
end

function Window:AddTab(title)
	local theme = Framework.Theme.Values

	local tabButton = Util.New("TextButton", {
		AutoButtonColor = false,
		Size = UDim2.new(1, -8, 0, 34),
		BackgroundColor3 = theme.Panel2,
		Text = title or "Tab",
		Font = Enum.Font.GothamMedium,
		TextColor3 = theme.Text,
		TextSize = 13,
		Parent = self.Sidebar,
	})

	ApplyCorner(tabButton, 8)

	local scroll = Util.New("ScrollingFrame", {
		Name = title or "Tab",
		Visible = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		Parent = self.TabHost,
	})

	Util.New("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = scroll,
	})

	Util.New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
		Parent = scroll,
	})

	local tab = setmetatable({
		Window = self,
		Button = tabButton,
		Content = scroll,
		Sections = {},
		Title = title,
	}, Tab)

	table.insert(self.Tabs, tab)

	local function selectTab()
		for _, t in ipairs(self.Tabs) do
			t.Content.Visible = false
			t.Button.BackgroundColor3 = theme.Panel2
		end

		tab.Content.Visible = true
		tabButton.BackgroundColor3 = theme.Accent
		self.ActiveTab = tab
	end

	tabButton.Activated:Connect(selectTab)

	if #self.Tabs == 1 then
		selectTab()
	end

	return tab
end

function Window:Minimize()
	self.Minimized = not self.Minimized

	self.Body.Visible = not self.Minimized
	self.ResizeHandle.Visible = not self.Minimized

	if self.Minimized then
		self.Frame.Size = UDim2.fromOffset(self.Frame.AbsoluteSize.X, 44)
	else
		self.Frame.Size = self.LastSize or UDim2.fromOffset(680, 460)
	end
end

function Window:Maximize()
	if self.Maximized then
		self.Maximized = false
		self.Frame.Position = self.RestorePosition or UDim2.fromOffset(100, 100)
		self.Frame.Size = self.RestoreSize or UDim2.fromOffset(680, 460)
	else
		self.Maximized = true
		self.RestorePosition = self.Frame.Position
		self.RestoreSize = self.Frame.Size
		self.Frame.Position = UDim2.fromOffset(16, 16)
		self.Frame.Size = UDim2.new(1, -32, 1, -32)
	end
end

function Window:Close()
	self.Maid:Clean()
	self.Frame:Destroy()
	Framework.Windows[self.Id] = nil
end

function Framework.CreateWindow(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values

	local id = opts.Id or HttpService:GenerateGUID(false)

	if Framework.Windows[id] then
	
		return Framework.Windows[id]
	end

	local maid = Maid.new()

	local frame = Util.New("Frame", {
		Name = "Window_" .. tostring(id),
		Position = opts.Position or UDim2.fromOffset(120 + (#Framework.Windows * 24), 100 + (#Framework.Windows * 24)),
		Size = opts.Size or UDim2.fromOffset(680, 460),
		BackgroundColor3 = theme.Background,
		ClipsDescendants = true,
		Parent = Root,
		ZIndex = nextZ,
	})

	ApplyCorner(frame, 14)
	ApplyStroke(frame, theme.Stroke, 1, 0.2)

	local shadow = Util.New("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = "rbxassetid://1316045217",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.55,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		Position = UDim2.fromOffset(-18, -18),
		Size = UDim2.new(1, 36, 1, 36),
		ZIndex = frame.ZIndex - 1,
		Parent = frame,
	})

	local header = Util.New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = theme.Panel,
		Parent = frame,
		ZIndex = frame.ZIndex + 1,
	})

	local title = Util.New("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -140, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = opts.Title or "Window",
		TextColor3 = theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
		ZIndex = header.ZIndex + 1,
	})

	local closeButton = Util.New("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = theme.Danger,
		Text = "×",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 18,
		AutoButtonColor = false,
		Parent = header,
		ZIndex = header.ZIndex + 2,
	})
	ApplyCorner(closeButton, 999)

	local maxButton = Util.New("TextButton", {
		Name = "Maximize",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -44, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = theme.Panel2,
		Text = "□",
		Font = Enum.Font.GothamBold,
		TextColor3 = theme.Text,
		TextSize = 13,
		AutoButtonColor = false,
		Parent = header,
		ZIndex = header.ZIndex + 2,
	})
	ApplyCorner(maxButton, 999)

	local minButton = Util.New("TextButton", {
		Name = "Minimize",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -76, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = theme.Panel2,
		Text = "–",
		Font = Enum.Font.GothamBold,
		TextColor3 = theme.Text,
		TextSize = 18,
		AutoButtonColor = false,
		Parent = header,
		ZIndex = header.ZIndex + 2,
	})
	ApplyCorner(minButton, 999)

	local body = Util.New("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		Parent = frame,
		ZIndex = frame.ZIndex,
	})

	local sidebar = Util.New("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, opts.SidebarWidth or 150, 1, 0),
		BackgroundColor3 = theme.Panel,
		Parent = body,
		ZIndex = body.ZIndex + 1,
	})

	Util.New("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = sidebar,
	})

	Util.New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = sidebar,
	})

	local tabHost = Util.New("Frame", {
		Name = "TabHost",
		Position = UDim2.fromOffset(opts.SidebarWidth or 150, 0),
		Size = UDim2.new(1, -(opts.SidebarWidth or 150), 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
		ZIndex = body.ZIndex + 1,
	})

	local resizeHandle = Util.New("TextButton", {
		Name = "ResizeHandle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Text = "◢",
		Font = Enum.Font.GothamBold,
		TextColor3 = theme.MutedText,
		TextSize = 14,
		AutoButtonColor = false,
		Parent = frame,
		ZIndex = frame.ZIndex + 5,
	})

	local win = setmetatable({
		Id = id,
		Title = opts.Title or "Window",
		Frame = frame,
		Header = header,
		Body = body,
		Sidebar = sidebar,
		TabHost = tabHost,
		ResizeHandle = resizeHandle,
		Tabs = {},
		ActiveTab = nil,
		Maid = maid,
		Minimized = false,
		Maximized = false,
		LastSize = opts.Size or UDim2.fromOffset(680, 460),
	}, Window)

	Framework.Windows[id] = win

	-- dragging
	local dragging = false
	local dragStart: Vector2? = nil
	local startPos: UDim2? = nil

	maid:Give(header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			focusWindow(win)
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end))

	maid:Give(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				Util.ClampToViewport(frame)
			end
		end
	end))

	maid:Give(UserInputService.InputChanged:Connect(function(input)
		if dragging and dragStart and startPos and not win.Maximized then
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - dragStart
				frame.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end
	end))

	-- resizing
	local resizing = false
	local resizeStart: Vector2? = nil
	local startSize: Vector2? = nil

	maid:Give(resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			focusWindow(win)
			resizing = true
			resizeStart = input.Position
			startSize = frame.AbsoluteSize
		end
	end))

	maid:Give(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if resizing then
				resizing = false
				win.LastSize = frame.Size
				Util.ClampToViewport(frame)
			end
		end
	end))

	maid:Give(UserInputService.InputChanged:Connect(function(input)
		if resizing and resizeStart and startSize and not win.Maximized then
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - resizeStart
				local width = math.max(360, startSize.X + delta.X)
				local height = math.max(260, startSize.Y + delta.Y)
				frame.Size = UDim2.fromOffset(width, height)
			end
		end
	end))

	maid:Give(frame.InputBegan:Connect(function()
		focusWindow(win)
	end))

	maid:Give(closeButton.Activated:Connect(function()
		win:Close()
	end))

	maid:Give(minButton.Activated:Connect(function()
		win:Minimize()
	end))

	maid:Give(maxButton.Activated:Connect(function()
		win:Maximize()
	end))

	-- theme updates
	maid:Give(Framework.Theme.Changed:Connect(function(newTheme)
		frame.BackgroundColor3 = newTheme.Background
		header.BackgroundColor3 = newTheme.Panel
		sidebar.BackgroundColor3 = newTheme.Panel
		title.TextColor3 = newTheme.Text
		minButton.BackgroundColor3 = newTheme.Panel2
		maxButton.BackgroundColor3 = newTheme.Panel2
		minButton.TextColor3 = newTheme.Text
		maxButton.TextColor3 = newTheme.Text
		closeButton.BackgroundColor3 = newTheme.Danger
		resizeHandle.TextColor3 = newTheme.MutedText
	end))

	Util.ClampToViewport(frame)
	focusWindow(win)

	frame.Size = UDim2.fromOffset(620, 410)
	Animator.Tween(frame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = opts.Size or UDim2.fromOffset(680, 460),
	})

	return win
end

Framework.NewWindow = Framework.CreateWindow

--// Command Palette / Search Manager

local SearchManager = {
	History = {},
	Visible = false,
}

local paletteOverlay = Util.New("Frame", {
	Name = "CommandPaletteOverlay",
	Visible = false,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	Size = UDim2.fromScale(1, 1),
	Parent = Root,
	ZIndex = 50000,
})

local palette = Util.New("Frame", {
	Name = "CommandPalette",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 90),
	Size = UDim2.fromOffset(560, 420),
	BackgroundColor3 = Framework.Theme.Values.Panel,
	Parent = paletteOverlay,
	ZIndex = 50001,
})

ApplyCorner(palette, 14)
ApplyStroke(palette, Framework.Theme.Values.Stroke, 1, 0.2)

local searchBox = Util.New("TextBox", {
	Name = "Search",
	Position = UDim2.fromOffset(14, 14),
	Size = UDim2.new(1, -28, 0, 42),
	BackgroundColor3 = Framework.Theme.Values.Panel2,
	ClearTextOnFocus = false,
	PlaceholderText = "Search commands, windows, controls...",
	Text = "",
	Font = Enum.Font.Gotham,
	TextColor3 = Framework.Theme.Values.Text,
	PlaceholderColor3 = Framework.Theme.Values.MutedText,
	TextSize = 15,
	Parent = palette,
	ZIndex = 50002,
})

ApplyCorner(searchBox, 10)

local results = Util.New("ScrollingFrame", {
	Name = "Results",
	Position = UDim2.fromOffset(14, 66),
	Size = UDim2.new(1, -28, 1, -80),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromOffset(0, 0),
	Parent = palette,
	ZIndex = 50002,
})

Util.New("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
	Parent = results,
})

local function clearResults()
	for _, child in ipairs(results:GetChildren()) do
		if child:IsA("GuiButton") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

function SearchManager.Refresh(query)
	clearResults()

	local items = {}

	for _, win in pairs(Framework.Windows) do
		table.insert(items, {
			Label = "Focus window: " .. win.Title,
			Action = function()
				focusWindow(win)
				win.Frame.Visible = true
			end,
		})
	end

	for _, control in ipairs(Framework.Controls) do
		local name = control.Instance and control.Instance.Name or "Control"
		table.insert(items, {
			Label = "Control: " .. name,
			Action = function()
				if control.Instance then
					control.Instance.Visible = true
				end
			end,
		})
	end

	table.insert(items, {
		Label = "Switch theme: Dark",
		Action = function() Framework.SetTheme("Dark") end,
	})

	table.insert(items, {
		Label = "Switch theme: Light",
		Action = function() Framework.SetTheme("Light") end,
	})

	table.insert(items, {
		Label = "Export config",
		Action = function()
			Framework.Notify({
				Title = "Config exported",
				Text = ConfigManager:Export(),
				Duration = 8,
			})
		end,
	})

	query = query or ""

	for _, item in ipairs(items) do
		local ok = Util.FuzzyMatch(query, item.Label)
		if ok then
			local button = Util.New("TextButton", {
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Framework.Theme.Values.Panel2,
				Text = item.Label,
				Font = Enum.Font.Gotham,
				TextColor3 = Framework.Theme.Values.Text,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = results,
				ZIndex = 50003,
			})

			ApplyCorner(button, 8)

			button.Activated:Connect(function()
				table.insert(SearchManager.History, 1, item.Label)
				SearchManager.Hide()
				Util.SafeCall(item.Action)
			end)
		end
	end
end

function SearchManager.Show()
	SearchManager.Visible = true
	paletteOverlay.Visible = true
	searchBox.Text = ""
	SearchManager.Refresh("")
	task.defer(function()
		searchBox:CaptureFocus()
	end)
end

function SearchManager.Hide()
	SearchManager.Visible = false
	paletteOverlay.Visible = false
	searchBox:ReleaseFocus()
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	SearchManager.Refresh(searchBox.Text)
end)

paletteOverlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and input.Target == paletteOverlay then
		SearchManager.Hide()
	end
end)

Framework.SearchManager = SearchManager
Framework.CommandPalette = SearchManager

--// Context Menus / Modals

function Framework.ContextMenu(items, position)
	local theme = Framework.Theme.Values

	local menu = Util.New("Frame", {
		Name = "ContextMenu",
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(220, math.max(32, #items * 32)),
		BackgroundColor3 = theme.Panel,
		Parent = Root,
		ZIndex = 40000,
	})

	ApplyCorner(menu, 8)
	ApplyStroke(menu, theme.Stroke, 1, 0.25)

	Util.New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})

	for _, item in ipairs(items or {}) do
		local button = Util.New("TextButton", {
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			Text = item.Text or item.Title or "Item",
			Font = Enum.Font.Gotham,
			TextColor3 = theme.Text,
			TextSize = 13,
			Parent = menu,
			ZIndex = 40001,
		})

		button.Activated:Connect(function()
			menu:Destroy()
			Util.SafeCall(item.Callback)
		end)
	end

	task.defer(function()
		Util.ClampToViewport(menu)
	end)

	return menu
end

function Framework.Modal(opts)
	opts = opts or {}
	local theme = Framework.Theme.Values

	local overlay = Util.New("Frame", {
		Name = "ModalOverlay",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Parent = Root,
		ZIndex = 45000,
	})

	local modal = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = opts.Size or UDim2.fromOffset(420, 220),
		BackgroundColor3 = theme.Panel,
		Parent = overlay,
		ZIndex = 45001,
	})

	ApplyCorner(modal, 14)
	ApplyStroke(modal, theme.Stroke, 1, 0.2)

	Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 16),
		Size = UDim2.new(1, -36, 0, 28),
		Font = Enum.Font.GothamBold,
		Text = opts.Title or "Modal",
		TextColor3 = theme.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = modal,
		ZIndex = 45002,
	})

	Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 54),
		Size = UDim2.new(1, -36, 1, -110),
		Font = Enum.Font.Gotham,
		Text = opts.Text or "",
		TextColor3 = theme.MutedText,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = modal,
		ZIndex = 45002,
	})

	local ok = Util.New("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(100, 36),
		BackgroundColor3 = theme.Accent,
		Text = opts.ConfirmText or "OK",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 13,
		AutoButtonColor = false,
		Parent = modal,
		ZIndex = 45002,
	})

	ApplyCorner(ok, 8)

	ok.Activated:Connect(function()
		overlay:Destroy()
		Util.SafeCall(opts.Callback)
	end)

	Animator.Pop(modal)
	return overlay
end

--// Plugin Manager

local PluginManager = {
	Registered = {},
}

function PluginManager.Register(name, plugin)
	if not name or PluginManager.Registered[name] then
		return PluginManager.Registered[name]
	end

	PluginManager.Registered[name] = plugin

	if type(plugin) == "table" and type(plugin.Init) == "function" then
		Util.SafeCall(plugin.Init, Framework)
	elseif type(plugin) == "function" then
		Util.SafeCall(plugin, Framework)
	end

	return plugin
end

function PluginManager.Get(name)
	return PluginManager.Registered[name]
end

Framework.PluginManager = PluginManager
Framework.RegisterPlugin = PluginManager.Register

--// Runtime module system

function Framework.RegisterModule(name, module)
	if not name then return nil end
	if Framework.Modules[name] then
		return Framework.Modules[name]
	end

	Framework.Modules[name] = module

	if type(module) == "table" and type(module.Init) == "function" then
		Util.SafeCall(module.Init, Framework)
	end

	return module
end

function Framework.GetModule(name)
	return Framework.Modules[name]
end

--// Input Manager

local InputManager = {
	Binds = {},
}

function InputManager.Bind(actionName, keyCode, callback)
	if InputManager.Binds[actionName] then
		ContextActionService:UnbindAction(actionName)
	end

	InputManager.Binds[actionName] = {
		KeyCode = keyCode,
		Callback = callback,
	}

	ContextActionService:BindAction(actionName, function(_, state)
		if state == Enum.UserInputState.Begin then
			Util.SafeCall(callback)
		end
	end, false, keyCode)
end

function InputManager.Unbind(actionName)
	InputManager.Binds[actionName] = nil
	ContextActionService:UnbindAction(actionName)
end

Framework.InputManager = InputManager

InputManager.Bind("NoCommentCommandPalette", Enum.KeyCode.F1, function()
	if SearchManager.Visible then
		SearchManager.Hide()
	else
		SearchManager.Show()
	end
end)

InputManager.Bind("NoCommentEscape", Enum.KeyCode.Escape, function()
	if SearchManager.Visible then
		SearchManager.Hide()
	end
end)

--// Settings page

function Framework.CreateSettingsWindow()
	local win = Framework.CreateWindow({
		Id = "NoCommentSettings",
		Title = "No comment Settings",
		Size = UDim2.fromOffset(620, 430),
	})

	local tab = win:AddTab("Settings")
	local appearance = tab:AddSection("Appearance")
	appearance:AddDropdown({
		Text = "Theme",
		Values = { "Dark", "Light" },
		Default = Framework.Theme.Name,
		Callback = function(value)
			Framework.SetTheme(value)
		end,
	})

	appearance:AddButton({
		Text = "Open command palette",
		Callback = function()
			SearchManager.Show()
		end,
	})

	local config = tab:AddSection("Configuration")
	config:AddButton({
		Text = "Export profile to notification",
		Callback = function()
			Framework.Notify({
				Title = "Exported profile",
				Text = ConfigManager:Export(),
				Duration = 8,
			})
		end,
	})

	config:AddTextbox({
		Placeholder = "Paste JSON config and press Enter/click away",
		Callback = function(text)
			if text ~= "" then
				local ok = ConfigManager:Import(text)
				Framework.Notify({
					Title = ok and "Config imported" or "Invalid config",
					Text = ok and "Profile data loaded." or "Could not parse JSON.",
				})
			end
		end,
	})

	return win
end

--// Startup animation

local function Startup()
	local theme = Framework.Theme.Values

	local splash = Util.New("Frame", {
		Name = "Startup",
		BackgroundColor3 = theme.Background,
		Size = UDim2.fromScale(1, 1),
		Parent = Root,
		ZIndex = 90000,
	})

	local logo = Util.New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 90),
		BackgroundTransparency = 1,
		Text = FRAMEWORK_NAME,
		Font = Enum.Font.GothamBlack,
		TextColor3 = theme.Text,
		TextTransparency = 1,
		TextSize = 42,
		Parent = splash,
		ZIndex = 90001,
	})

	local accent = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 48),
		Size = UDim2.fromOffset(0, 4),
		BackgroundColor3 = theme.Accent,
		Parent = splash,
		ZIndex = 90001,
	})
	ApplyCorner(accent, 999)

	Animator.Tween(logo, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.48),
	})

	Animator.Tween(accent, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(220, 4),
	})

	task.delay(1.05, function()
		local t1 = Animator.Tween(logo, TweenInfo.new(0.25), {
			TextTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.45),
		})

		Animator.Tween(splash, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
		})

		t1.Completed:Once(function()
			if splash then
				splash:Destroy()
			end
		end)
	end)
end

--// Public aliases

Framework.WindowManager = {
	CreateWindow = Framework.CreateWindow,
	GetWindow = function(id)
		return Framework.Windows[id]
	end,
	CloseAll = function()
		for _, win in pairs(table.clone(Framework.Windows)) do
			win:Close()
		end
	end,
}

Framework.IconManager = {
	Get = function(name)
		return tostring(name or "")
	end,
}

Framework.FontManager = {
	Default = Enum.Font.Gotham,
	Bold = Enum.Font.GothamBold,
	Black = Enum.Font.GothamBlack,
}

Framework.StateManager = {
	Set = function(key, value)
		Framework.Config[key] = value
	end,
	Get = function(key, default)
		if Framework.Config[key] == nil then
			return default
		end
		return Framework.Config[key]
	end,
}

function Framework.Destroy()
	for _, win in pairs(table.clone(Framework.Windows)) do
		win:Close()
	end

	if Framework.Gui then
		Framework.Gui:Destroy()
	end

	if shared.NoComment == Framework then
		shared.NoComment = nil
	end
end

Framework.Unload = Framework.Destroy

Framework.Ready = true
Framework.Signals.Ready = Framework.Signals.Ready or Signal.new()
Framework.Signals.Ready:Fire(Framework)

	Startup()

	task.delay(1.25, function()
		Framework.Notify({
			Title = "No comment",
			Text = "Framework initialized. Press F1 for the command palette.",
			Duration = 4,
		})
	end)
end

shared.Framework = Framework
Framework.Gui:SetAttribute("FrameworkReady", true)
return Framework

