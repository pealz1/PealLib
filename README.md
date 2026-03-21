<div align="center">

# PealLib

**A modern, feature-rich UI library for Roblox**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/pealz1/PealLib?style=flat&color=yellow)](https://github.com/pealz1/PealLib/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/pealz1/PealLib?style=flat&color=green)](https://github.com/pealz1/PealLib/network)
[![Docs](https://img.shields.io/badge/docs-pealz1.github.io%2FPealLib-purple)](https://pealz1.github.io/PealLib)

Build professional, fully-featured interfaces with minimal code.
Inspired by Matcha & Linoria — rebuilt with more power and polish.

<img src="https://i.imgur.com/qs0Hqc6.png" width="700" alt="PealLib Interface Preview" />

</div>

---

## Quick Start

```lua
local repo = 'https://raw.githubusercontent.com/pealz1/PealLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()
```

```lua
-- Create a window
local Window = Library:CreateWindow({
    Title = 'My Script Hub',
    Center = true,
    AutoShow = true
})

-- Add a tab with some controls
local Tab = Window:AddTab('Main')
local Box = Tab:AddLeftGroupbox('Features')

Box:AddToggle('AimAssist', { Text = 'Aim Assist', Default = false })
Box:AddSlider('Speed',     { Text = 'Walk Speed', Default = 16, Min = 0, Max = 100, Rounding = 0 })
Box:AddDropdown('Mode',    { Text = 'Mode', Values = {'Legit', 'Rage', 'Custom'}, Default = 1 })

-- Read values anywhere
print(Toggles.AimAssist.Value)  -- true / false
print(Options.Speed.Value)      -- 16
print(Options.Mode.Value)       -- "Legit"
```

> **[Full documentation](https://pealz1.github.io/PealLib)**

---

## Features

| Category | What you get |
|----------|-------------|
| **UI Elements** | Toggles, sliders, dropdowns (single & multi), text inputs, buttons, color pickers, keybind pickers, labels, dividers, cards, rows |
| **Layout** | Tabs, left/right groupboxes, nested tabboxes, auto-scrolling overflow, dependency boxes for conditional visibility |
| **Themes** | 8 built-in themes (Default, BBot, Fatality, Jester, Mint, Tokyo Night, Ubuntu, Quartz) + create & save custom themes |
| **Config System** | Save & load all UI state to disk — toggles, sliders, dropdowns, keybinds, colors, inputs — with autoload support |
| **Extras** | Notifications, watermarks, tooltips, popout windows, drag-and-drop, touch input support |

---

## UI Elements

<details>
<summary><b>Toggle</b></summary>

```lua
Box:AddToggle('MyToggle', {
    Text = 'Enable Feature',
    Default = false,
    Tooltip = 'Turns the feature on or off',
    Callback = function(value)
        print('Toggled:', value)
    end
})
```
</details>

<details>
<summary><b>Slider</b></summary>

```lua
Box:AddSlider('MySlider', {
    Text = 'Speed',
    Default = 50,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = '%',
    Callback = function(value)
        print('Slider:', value)
    end
})
```
</details>

<details>
<summary><b>Dropdown</b></summary>

```lua
-- Single select
Box:AddDropdown('MyDropdown', {
    Text = 'Select Mode',
    Values = {'Option A', 'Option B', 'Option C'},
    Default = 1,
    Callback = function(value)
        print('Selected:', value)
    end
})

-- Multi select
Box:AddDropdown('MultiDrop', {
    Text = 'Select Multiple',
    Values = {'Red', 'Green', 'Blue'},
    Multi = true,
    Default = 'Red',
})
```
</details>

<details>
<summary><b>Input</b></summary>

```lua
Box:AddInput('MyInput', {
    Text = 'Username',
    Default = '',
    Placeholder = 'Enter username...',
    MaxLength = 32,
    Callback = function(value)
        print('Input:', value)
    end
})
```
</details>

<details>
<summary><b>Color Picker</b></summary>

```lua
Box:AddLabel('Pick a color'):AddColorPicker('MyColor', {
    Default = Color3.fromRGB(255, 0, 0),
    Title = 'Choose Color',
    Transparency = 0,
    Callback = function(value)
        print('Color:', value)
    end
})
```
</details>

<details>
<summary><b>Keybind</b></summary>

```lua
Box:AddLabel('Trigger Key'):AddKeyPicker('MyKeybind', {
    Default = 'MB2',
    Mode = 'Toggle',    -- 'Always' | 'Toggle' | 'Hold'
    Text = 'Trigger',
    Callback = function(state)
        print('Key state:', state)
    end
})
```
</details>

<details>
<summary><b>Button</b></summary>

```lua
Box:AddButton({
    Text = 'Click Me',
    Func = function()
        print('Clicked!')
    end,
    Tooltip = 'Does something cool'
})
```
</details>

---

## Themes & Configs

```lua
-- Setup managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()

-- Add settings UI to a tab
local SettingsTab = Window:AddTab('Settings')
ThemeManager:ApplyToTab(SettingsTab)
SaveManager:BuildConfigSection(SettingsTab)

-- Auto-load saved config on start
SaveManager:LoadAutoloadConfig()
```

**Built-in Themes:** Default, BBot, Fatality, Jester, Mint, Tokyo Night, Ubuntu, Quartz

---

## Project Structure

```
PealLib/
├── Library.lua              -- Core UI library
├── Example.lua              -- Full usage example
├── addons/
│   ├── ThemeManager.lua     -- Theme system
│   └── SaveManager.lua      -- Config persistence
└── docs/                    -- Documentation site source
```

---

## Documentation

Full API reference and guides are available at **[pealz1.github.io/PealLib](https://pealz1.github.io/PealLib)**.

Or check out the [Example.lua](Example.lua) for a hands-on walkthrough of every feature.

---

## Contributors

| Who | Role |
|-----|------|
| **Pealz** | Main developer |
| **Mental** | Bug fixes & features |
| **Inori** | Original creator ([LinoriaLib](https://github.com/violin-suzutsuki/LinoriaLib)) |

---

## License

MIT License — see [LICENSE](LICENSE) for details.
