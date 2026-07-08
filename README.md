# No-Comment-Framework
A modern, modular Roblox UI framework built entirely with **LocalScripts**.

## Features

- Runtime extensibility
- Modular architecture
- Theme system
- Plugin and module support
- Config import/export
- Command palette
- State manager
- Input manager
- Context menus
- Notifications
- Safe callback handling
- Zero external dependencies

---

# Installation

Place the main framework inside a single **LocalScript** in:

```text
StarterPlayer
└── StarterPlayerScripts
    └── NoComment
```

Access the framework from any other LocalScript:

```lua
local UI = shared.NoComment

while not UI or not UI.Ready do
	task.wait()
	UI = shared.NoComment
end
```

---

# Creating Windows

Create a new window. If a window with the same `Id` already exists, the existing instance is returned.

```lua
local win = UI.CreateWindow({
	Id = "MainMenu",
	Title = "Main Menu",
	Size = UDim2.fromOffset(720, 480),
	Position = UDim2.fromOffset(120, 100),
})
```

### Window Methods

```lua
win:Minimize()
win:Maximize()
win:Close()
```

---

# Tabs & Sections

## Create a Tab

```lua
local tab = win:AddTab("Home")
local section = tab:AddSection("Main Section")
```

## Add to an Existing Window

```lua
local win = UI.Windows["Demo"]

local tab = win:AddTab("External Tab")
local section = tab:AddSection("Added Later")
```

## Add to an Existing Tab

```lua
local targetTab

for _, tab in ipairs(win.Tabs) do
	if tab.Title == "Home" then
		targetTab = tab
		break
	end
end

if targetTab then
	targetTab:AddSection("New Section")
end
```

---

# Controls

Every control returns an API object.

```lua
control:Get()
control:Set(value)
control:Reset()

control.Changed:Connect(function(value)
	print(value)
end)

control:Destroy()
```

## Available Controls

| Control | Method |
|---------|--------|
| Label | `AddLabel()` |
| Paragraph | `AddParagraph()` |
| Divider | `AddDivider()` |
| Button | `AddButton()` |
| Toggle | `AddToggle()` |
| Checkbox | `AddCheckbox()` |
| Slider | `AddSlider()` |
| Range Slider | `AddRangeSlider()` |
| Textbox | `AddTextbox()` |
| Dropdown | `AddDropdown()` |
| Radio | `AddRadio()` |
| Multi Select | `AddMultiSelect()` |
| Progress Bar | `AddProgress()` |
| Badge | `AddBadge()` |
| Color Picker | `AddColorPicker()` |

---

# Aliases

The following methods are currently aliases:

```lua
AddKeybind()      -- Textbox
AddTreeView()     -- Paragraph
AddImageButton()  -- Button
AddTooltip()      -- Paragraph
AddRichText()     -- Paragraph
```

---

# Notifications

```lua
UI.Notify({
	Title = "Saved",
	Text = "Your settings were saved.",
	Duration = 4,
})
```

---

# Themes

Use a built-in theme:

```lua
UI.SetTheme("Dark")
UI.SetTheme("Light")
```

Create a custom theme:

```lua
UI.SetTheme({
	Accent = Color3.fromRGB(255, 80, 120),
	Panel = Color3.fromRGB(24, 24, 30),
})
```

Common theme fields:

```
Background
Panel
Panel2
Stroke
Text
MutedText
Accent
Accent2
Danger
Success
Warning
```

Listen for changes:

```lua
UI.Theme.Changed:Connect(function(theme)
	print(theme)
end)
```

---

# Command Palette

Open:

```lua
UI.CommandPalette.Show()
```

Close:

```lua
UI.CommandPalette.Hide()
```

Default shortcut:

```
F1
```

The command palette can search windows, controls, theme actions, and config actions.

---

# Settings Window

```lua
UI.CreateSettingsWindow()
```

Includes theme switching and configuration import/export.

---

# Modal Dialogs

```lua
UI.Modal({
	Title = "Confirm",
	Text = "Are you sure?",
	ConfirmText = "OK",
	Callback = function()
		print("Confirmed")
	end,
})
```

---

# Context Menus

```lua
local UserInputService = game:GetService("UserInputService")

UI.ContextMenu({
	{
		Text = "Notify",
		Callback = function()
			UI.Notify({ Text = "Clicked." })
		end,
	},
	{
		Text = "Settings",
		Callback = function()
			UI.CreateSettingsWindow()
		end,
	},
}, UserInputService:GetMouseLocation())
```

---

# Modules

Register a module:

```lua
UI.RegisterModule("MathTools", {
	Init = function(UI)
		print("Loaded")
	end,

	Add = function(a, b)
		return a + b
	end,
})
```

Retrieve it later:

```lua
local MathTools = UI.GetModule("MathTools")

print(MathTools.Add(2, 3))
```

---

# Plugins

Table plugin:

```lua
UI.RegisterPlugin("ExamplePlugin", {
	Init = function(UI)
		UI.Notify({
			Title = "Plugin",
			Text = "Plugin loaded.",
		})
	end,
})
```

Function plugin:

```lua
UI.RegisterPlugin("QuickPlugin", function(UI)
	print("Plugin loaded")
end)
```

---

# State Manager

```lua
UI.StateManager.Set("CoinsVisible", true)

local visible = UI.StateManager.Get("CoinsVisible", false)
```

---

# Config Manager

Export:

```lua
local json = UI.ConfigManager:Export()
```

Import:

```lua
local ok = UI.ConfigManager:Import(json)
```

---

# Input Manager

Bind:

```lua
UI.InputManager.Bind("OpenMenu", Enum.KeyCode.RightShift, function()
	local win = UI.Windows["MainMenu"]

	if win then
		win.Frame.Visible = not win.Frame.Visible
	end
end)
```

Unbind:

```lua
UI.InputManager.Unbind("OpenMenu")
```

Built-in shortcuts:

| Key | Action |
|------|--------|
| F1 | Open Command Palette |
| Escape | Close Command Palette |

---

# Window Manager

```lua
local win = UI.WindowManager.GetWindow("MainMenu")

UI.WindowManager.CloseAll()
```

---

# Safe Callbacks

Callbacks are automatically wrapped with `xpcall()`, preventing errors from stopping the framework.

```lua
section:AddButton({
	Text = "Error Test",
	Callback = function()
		error("Test error")
	end,
})
```

---

# Recommended Runtime Pattern

```lua
local UI = shared.NoComment

while not UI or not UI.Ready do
	task.wait()
	UI = shared.NoComment
end

local win = UI.CreateWindow({
	Id = "MyRuntimeMenu",
	Title = "Runtime Menu",
})

local tab = win:AddTab("Main")
local section = tab:AddSection("Controls")

section:AddButton({
	Text = "Hello",
	Callback = function()
		UI.Notify({
			Title = "Hello",
			Text = "Added from another LocalScript.",
		})
	end,
})
```

Any LocalScript can safely create windows, tabs, sections, controls, plugins, and modules at runtime without modifying the original framework.
