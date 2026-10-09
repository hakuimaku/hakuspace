# HakuSpace Mini-Apps (src/core/app)

The `src/core/app/` directory houses custom mini-applications built specifically for HakuSpace. Instead of relying on heavy standalone applications, HakuSpace creates native-feeling desktop widgets by cleverly combining existing Linux tools with custom bash and Python scripts.

Currently, the following mini-apps are available:
- [**Taskbar**](#the-taskbar-srccoreapptaskbar)
- [**Desktop Icons**](#desktop-icons-srccoreappdesktop-icons)
- [**Cava Underbar**](#cava-underbar-srccoreappcava-layer)

---

## The Taskbar (`src/core/app/taskbar`)

The Taskbar is a Windows-style taskbar that sits at the bottom of your screen. Interestingly, it is not a standalone program! Under the hood, it is actually a highly customized, secondary instance of **Waybar** running a specific configuration (`~/.config/waybar/taskbar/config`). 

Because it runs independently from your main top status bar, it has its own dedicated management system.

### `taskbar_manager.sh` (The Control Center)
This is the master script that controls the Taskbar's lifecycle and settings. It acts as the bridge between the Rofi `Haku Menu` and the underlying Waybar process.

- **State Management:** It uses `~/.local/state/hakuspace/` to remember if you turned the Taskbar on or off (`taskbar_manual_state`). When you reboot, passing `--startup` to this script ensures your Taskbar returns exactly as you left it.
- **The Master Switch (`--toggle`):** This command completely enables or disables the Taskbar. 
- **Taskbar App Name (`--app-name`):** Toggles whether the Taskbar displays application names next to icons. It achieves this by dynamically parsing and rewriting a JSON state file (`taskbar-theme`).
- **Icon Sizing (`--icon-size`):** Prompts you via a Rofi text input to enter a custom pixel size, rather than cycling through fixed sizes, and updates the Waybar configuration on the fly.

### `taskbar_geticon.sh` (The Icon Fetcher)
The Taskbar needs to display the correct icons for your pinned applications.
- **What it does:** It reads your personal list of pinned apps from `~/hakucfg/config/taskbar_pin_apps`. 
- **Icon Resolution:** Since Linux apps don't always have straightforward icon paths, this script hunts through your `/usr/share/icons/`, `~/.local/share/icons/`, and current GTK icon theme to find the highest resolution SVG or PNG that matches the app's desktop entry, ensuring your dock always looks crisp. 
- **Caching & Theme Detection:** It intelligently caches the resolved icons and accurately detects your current GTK theme to speed up fetching times and provide better matching for dynamically changing themes.

---

## Desktop Icons (`src/core/app/desktop-icons`)

One of the biggest sacrifices when moving from traditional Desktop Environments (like XFCE or KDE) to modern Wayland compositors (like Hyprland or Niri) is losing your desktop icons. HakuSpace solves this by bringing them back with a fully native, Wayland-compatible desktop icon renderer!

### `desktop_icons.py` (The Engine)
This is a surprisingly powerful Python application built on top of `GtkLayerShell` and `Cairo`. Instead of being a normal window, it draws itself directly onto the background layer of your screen, sitting quietly beneath all your other windows.

- **Full Interactivity:** It isn't just a static picture! It supports double-clicking to launch apps, dragging boxes to multi-select, holding `Ctrl` to select specific files, and even keyboard shortcuts like `Ctrl+C` (Copy) and `Ctrl+X` (Cut). Added interactive options enhance how HakuSpace elements are managed.
- **Drag & Drop:** It natively integrates with Wayland's Drag and Drop API. 
  - You can drag files from Thunar (or any file manager) straight onto your desktop. 
  - You can freely drag icons around to rearrange them. The grid positions are automatically saved to a `positions.json` file so they stay exactly where you left them after a reboot!
- **Auto Arrange:** Tired of messy desktops? The application now features an Auto Arrange mode (enabled by default) that automatically snaps your icons into a neat grid, ensuring your desktop always looks organized.
- **Customizable Actions:** By default, dragging a file *onto* the desktop copies it, while dragging a file *off* the desktop cuts it. You can change this behavior (e.g., creating symlinks instead of copying) in its configuration file.

### `desktop_icons_manager.sh` (The Launcher)
Just like the Taskbar, the Desktop Icons app has its own manager script that links to the Haku Menu.
- **What it does:** It tracks the ON/OFF state of the desktop icons in `~/.local/state/hakuspace/desktop_icons_state`.
- **Usage:** You can use `--toggle` to instantly show or hide all your icons, `--reload` to refresh the grid (useful if you just pasted a new file via the terminal), or `--startup` to automatically launch the python engine when you log in.

### Configuration
You can customize almost everything about how your icons look and behave.
- **Where:** Check `~/hakucfg/config/desktop-icons/desktop-icons.conf`.
- **Options:** You can change the icon size, sorting method (by name, date, size), whether to show hidden files, or toggle the visibility of special system folders like `Home`, `Trash`, and `Computer`.

---

## Cava Underbar (`src/core/app/cava-layer`)

If you like having an audio visualizer on your desktop, you've probably used `cava`. Normally, it runs inside a regular terminal window. HakuSpace takes it to the next level by embedding `cava` directly into the background of your screen, sitting just above your wallpaper but below your windows, acting as a dynamic "Underbar".

### `cava_layer.py` (The VTE Wrapper)
This Python script uses `GtkLayerShell` and `VTE` (Virtual Terminal Emulator).
- **Background Embedding:** It creates a borderless, completely transparent, and click-through terminal window, anchoring it to the bottom of your screen using the Wayland layer-shell protocol.
- **Theme Syncing:** It dynamically parses your `~/.config/kitty/kitty.conf` to extract your current foreground, background, and accent colors, ensuring the visualizer perfectly matches your overall system theme.
- **Running Cava:** It quietly spawns the actual `cava` C-binary inside this invisible terminal window to process your audio streams.

### `cava_manager.sh` (The Process Controller)
Because the Python script acts as a background daemon, it needs a manager to handle its lifecycle.
- **Toggling:** You can use `cava_manager.sh toggle` (which is mapped in the Haku Menu's Theme tab) to spawn or gracefully kill the visualizer process and its PID file.
- **Live Reloading:** When you change your system's accent color (via `gen_style.sh`), you don't want the audio visualizer to stutter, drop frames, or restart. Calling `cava_manager.sh reload` sends a specific UNIX signal (`SIGUSR1`) to the Python daemon. The script intercepts this signal, re-reads the Kitty configuration, and instantly updates the visualizer's colors on the fly without ever interrupting the live audio stream!



---
**Previous:** [Haku Menu](menu.md) | **Home:** [Architecture Overview](../architecture.md)
