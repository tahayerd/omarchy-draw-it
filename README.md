# Draw-It — Omarchy Screen Drawing Plugin

A lightweight, seamless screen drawing and annotation plugin for Omarchy Linux and Hyprland.
Left-click the bar icon or press your custom shortcut to draw directly on top of your screen. Left-click draws smooth brush strokes, right-click erases intersecting strokes, and right-clicking the status bar icon opens a rich settings panel.

## Features

- **Direct Screen Annotation**: Transparent layer-shell overlay that lets you draw freely over any window or workspace.
- **Natural Interaction**:
  - **Left-Click + Drag**: Freehand drawing with smooth lines.
  - **Right-Click + Drag**: Precision stroke eraser that carves and erases only the exact segment passed over (splits and cuts lines instead of deleting the whole drawing).
  - **Right-Click on Bar Icon**: Opens the settings panel to change color, line thickness, eraser radius, and preferences.
- **Keyboard Navigation**:
  - `Esc` or `Q` — Exit drawing mode.
  - `C` — Clear entire canvas.
  - `U` or `Ctrl + Z` — Undo last action.
  - `Ctrl + Y` or `Ctrl + Shift + Z` — Redo action.
  - `[` / `]` — Decrease / Increase line thickness.
  - `1`–`9` — Quick-switch between preset colors (Red, Green, Blue, Yellow, Orange, Purple, Cyan, White, Black).
- **Multi-Monitor Support**: Automatically projects onto all connected outputs via Quickshell variants.
- **Full IPC Support**: Easily bind shortcuts in Hyprland without launching extra daemons or cold processes.

---

## Install

```sh
omarchy plugin add https://github.com/taha/omarchy-draw-it.git --enable
```

Place it on your bar (e.g. `right` section) and restart the shell:

```sh
omarchy bar move io.github.taha.draw-it --section right
omarchy restart shell
```

### Local Development / Manual Installation

If developing locally, copy the plugin directory into your Omarchy plugins folder:

```sh
mkdir -p ~/.config/omarchy/plugins/io.github.taha.draw-it
rsync -av --delete --exclude .git ./ ~/.config/omarchy/plugins/io.github.taha.draw-it/
omarchy plugin enable io.github.taha.draw-it right
omarchy restart shell
```

---

## Usage

- **Left Click on Bar Icon**: Toggles screen drawing mode on / off.
- **Right Click on Bar Icon**: Opens the Draw-It settings panel.
- **SUPER + ALT + D** (or your bound shortcut): Toggles drawing mode at any time. Closing the overlay **never clears your drawings** — they stay in memory, so you can draw, hide the overlay to use the screen normally, then press the shortcut again to keep drawing from where you left off.

### In Drawing Mode:

| Key / Mouse | Action |
|---|---|
| **Left Click + Drag** | Draw freehand strokes |
| **Right Click + Drag** | Erase only the exact parts touched by the eraser (carving/partial erase) |
| `Esc`, `Q` | Exit drawing mode |
| `C` | Clear all drawings |
| `U` / `Ctrl + Z` | Undo last stroke or erasure |
| `Ctrl + Y` / `Ctrl + Shift + Z` | Redo |
| `[` / `]` | Decrease / Increase brush thickness |
| `1`–`9` | Quick-select preset colors (1: Red, 2: Green, 3: Blue, 4: Yellow, 5: Orange, 6: Purple, 7: Cyan, 8: White, 9: Black) |

---

## Hyprland Shortcut Configuration

Bind a shortcut in `~/.config/hypr/bindings.lua` (or `bindings.conf`) to toggle screen drawing from anywhere:

### `~/.config/hypr/bindings.lua`:
```lua
o.bind("SUPER + ALT + D", "Screen Draw",
  "omarchy-shell io.github.taha.draw-it toggle")
```

### Or `~/.config/hypr/bindings.conf`:
```ini
bind = SUPER ALT, D, exec, omarchy-shell io.github.taha.draw-it toggle
```

---

## IPC Commands

The plugin exposes full IPC control via `omarchy-shell`:

```sh
omarchy-shell io.github.taha.draw-it toggle           # Toggle drawing mode on/off
omarchy-shell io.github.taha.draw-it start            # Open drawing overlay
omarchy-shell io.github.taha.draw-it stop             # Close drawing overlay
omarchy-shell io.github.taha.draw-it clear            # Clear all current strokes
omarchy-shell io.github.taha.draw-it undo             # Undo last stroke
omarchy-shell io.github.taha.draw-it redo             # Redo last stroke
omarchy-shell io.github.taha.draw-it settings         # Open the settings panel
omarchy-shell io.github.taha.draw-it setColor "#1890ff" # Change drawing color
omarchy-shell io.github.taha.draw-it setWidth 6       # Change line thickness
omarchy-shell io.github.taha.draw-it status           # Check if currently active ("drawing" / "idle")
```

---

## Settings

Settings can be adjusted through the widget's right-click popup or configured in `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.taha.draw-it",
  "icon": "󰏫",
  "defaultColor": "#ff4d4f",
  "defaultWidth": 4,
  "eraserRadius": 18,
  "clearOnExit": false
}
```

| Key | Default | Description |
|---|---|---|
| `icon` | `󰏫` | Nerd Font glyph displayed on the Omarchy status bar |
| `defaultColor` | `#ff4d4f` | Initial brush color |
| `defaultWidth` | `4` | Initial line thickness in pixels (1–30) |
| `eraserRadius` | `18` | Radius of the right-click eraser circle in pixels |
| `clearOnExit` | `false` | When true, drawings are wiped automatically when drawing mode closes |

---

## Validation & Testing

Validate manifest schema:

```sh
omarchy plugin validate .
```

---

## Removal

```sh
omarchy plugin remove io.github.taha.draw-it
```

---

## License

MIT — see [LICENSE](LICENSE).
