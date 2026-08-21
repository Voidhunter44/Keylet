# Keylet / Universal Modifier Controller

**Hold any combination of keyboard keys with a single toggle.** A floating, always-on-top widget lets you lock modifier keys (or any keys) without physically holding them down.

![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0-blue) ![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-brightgreen) 

---

## Features

- **Multiple Profiles** — Create unlimited shortcut profiles, each with its own held keys and activation hotkey
- **Floating Widget** — Always-on-top dark-themed widget with rounded corners that doesn't steal focus
- **One-Click Toggle** — Hold/release any key combination instantly
- **Keyboard Shortcuts** — Assign a unique hotkey to each profile for hands-free toggling
- **4 Size Modes** — Extra Small (row of square buttons), Small, Medium, Large
- **Non-Intrusive** — Widget uses `WS_EX_NOACTIVATE` — clicking it won't interrupt your typing
- **Draggable** — Move the widget anywhere on screen; position persists across sessions
- **Customizable Display** — Show/hide status, profile names, key combos, or toggle buttons
- **System Tray** — Minimize to tray, quick access to all functions
- **Settings Saved** — INI-based configuration persists all preferences automatically

---

## Widget Sizes

| Extra Small | Small | Medium | Large |
|:-----------:|:-----:|:------:|:-----:|
| Row of ▶/■ square buttons | Compact cards | Standard cards | Full-size cards |
| One per profile | Status + Keys + Button | Status + Keys + Button | Status + Keys + Button |

---

## Getting Started

### Requirements

- **Windows 10 or 11**
- **[AutoHotkey v2.0+](https://www.autohotkey.com/v2/)** installed

### Installation

1. Download or clone this repository
2. Run `Universal_Modifier_Controller.ahk`
3. The settings window and floating widget appear automatically

### Quick Start

1. **Default profile**: Ctrl + Alt, toggled with `Ctrl+Alt+Space`
2. Click **"Turn ON"** on the widget to hold those keys
3. Click **"Turn OFF"** (or press `Ctrl+Alt+Space` again) to release
4. Open settings to add more profiles, change keys, or assign hotkeys

---

## Usage

### Adding a New Profile

1. Open settings (tray icon → "Open settings", or click ☰ on widget)
2. Go to the **Profiles** tab
3. Click **"+ Add"**
4. Give it a name (e.g. "Gaming Mode")
5. Click **"Record keys"** and press the keys you want held
6. Optionally click **"Record hotkey"** to assign an activation shortcut
7. The new profile's button appears on the widget automatically

### Widget Controls

| Action | Result |
|--------|--------|
| Click a toggle button | Hold/release that profile's keys |
| Click ☰ | Open context menu with all options |
| Drag empty area | Move widget |
| Minimize settings | Settings goes to tray |

### Keyboard Shortcuts

Each profile can have its own global hotkey. Press it anywhere to toggle that profile's keys on/off.

---

## Important Notes

### Modifier Keys & System Behavior

When modifier keys are held (e.g. Ctrl+Alt), Windows changes how it interprets other input:

- **Scroll wheel** → May zoom instead of scroll (Ctrl+Scroll = Zoom in most apps)
- **Mouse clicks** → May trigger alternate actions (Ctrl+Click = new tab, etc.)
- **Keyboard** → Shortcuts may fire unexpectedly

**This is normal Windows behavior, not a bug.** Choose your held keys carefully — holding non-modifier keys (like `A`, `D`, `Space`) avoids these side effects.

### The Widget Doesn't Steal Focus

The widget uses `WS_EX_NOACTIVATE`, meaning:
- You can type in other apps while the widget is visible
- Clicking the widget doesn't deactivate your current window
- Scroll wheel works normally in other apps (when keys aren't held)

---

## Architecture

```
Universal_Modifier_Controller.ahk   (single-file script)
UniversalModifierController.ini      (auto-generated config)
```

### Technical Highlights

- **WM_NCHITTEST** — Custom hit-testing for draggable borderless window with clickable buttons
- **WS_EX_NOACTIVATE** — Widget never steals input focus
- **DWM Rounded Corners** — Native on Windows 11, `CreateRoundRectRgn` fallback on Windows 10
- **Function.Bind()** — Avoids AHK v2 closure variable capture bugs in loops
- **Tab3 Control** — Organized settings without scroll overflow
- **INI Persistence** — All profiles, positions, and preferences saved automatically

---

## Configuration

Settings are stored in `UniversalModifierController.ini` (created automatically in the script directory):

```ini
[Widget]
Size=Medium
ShowStatus=1
ShowName=1
ShowKeys=1
ShowToggle=1
PosX=1200
PosY=120

[Profiles]
Count=2

[Profile1]
Name=Ctrl + Alt
ActionKeys=LControl,LAlt
Hotkey=^!Space

[Profile2]
Name=Shift Hold
ActionKeys=LShift
Hotkey=^!s
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Script won't start | Ensure AutoHotkey **v2** is installed (not v1) |
| Widget invisible | Check taskbar for the AHK tray icon → "Show widget" |
| Hotkey doesn't work | May conflict with another app; record a different combination |
| Keys stuck after crash | Run script again → "Release all keys", or press Ctrl+Alt+Del |
| Scroll/zoom weird | That's your held modifiers affecting the OS; release them first |

---

## Changelog

### v3.3 (Current)
- Added a micro size button, new compact option even smaller than Extra Small
- Split buttons into separate draggable widgets option

### v3.2
- All keys now recordable (Enter, Escape, etc. no longer blocked)
- Snap together / separate option for button layout spacing
- Fixed tab content spacing and alignment
- Visual dividers between settings sections
- Added Fn key documentation (hardware-level limitation)
- Expanded DisplayKeyName with Enter, Escape, Tab, Delete, Insert, Home, End

### v3.1
- Multiple shortcut profiles with independent toggle buttons
- Tab-based settings GUI (no scroll overflow)
- Function.Bind() for stable closure behavior
- Named callbacks for menu items (no variable capture bugs)

### v2.3
- WS_EX_NOACTIVATE — widget doesn't steal focus
- Extra Small mode (square button)
- DPI awareness

### v2.2
- WM_NCHITTEST for drag + click handling
- Solid visible dark background

### v2.0
- Complete rewrite fixing 25 bugs from v1
- Rounded corners, position persistence, DPI awareness
