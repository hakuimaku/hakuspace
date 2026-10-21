<div align="center">

# Haku Space
Wayland dotfiles and desktop shell for Hyprland / Niri / MangoWM / Labwc

**Classic** (Waybar / Rofi / SwayNC) + **Hikai** (Quickshell)

*Haku (ハク) is the very highest Value, the manifestation of a wish. It means "the shape of a soul," "that which is irreplaceable."*
    <div align="right">
        <i>- Made in Abyss -</i>
    </div>

</div>

<p align="center">
    <a href="https://github.com/hyprwm/Hyprland"><img alt="Hyprland" src="https://img.shields.io/badge/-Hyprland-%23212121?style=for-the-badge&logo=wayland&logoColor=%23FFFFFF&labelColor=%23000000"></a>&nbsp;
    <a href="https://github.com/YaLTeR/niri"><img alt="Niri" src="https://img.shields.io/badge/-Niri-%23212121?style=for-the-badge&logo=wayland&logoColor=%23FFFFFF&labelColor=%23000000"></a>&nbsp;
    <a href="https://github.com/mangowm/mango"><img alt="MangoWM" src="https://img.shields.io/badge/-MangoWM-%23212121?style=for-the-badge&logo=wayland&logoColor=%23FFFFFF&labelColor=%23000000"></a>&nbsp;
    <a href="https://github.com/labwc/labwc"><img alt="Labwc" src="https://img.shields.io/badge/-Labwc-%23212121?style=for-the-badge&logo=wayland&logoColor=%23FFFFFF&labelColor=%23000000"></a>&nbsp;
    <br />
    <a href="https://github.com/hakuimaku/hakuspace/commits/main"><img alt="Last Commit" src="https://img.shields.io/github/last-commit/hakuimaku/hakuspace?style=for-the-badge&label=Last%20Commit&labelColor=%23000000&color=%23212121&logo=git&logoColor=%23FFFFFF"></a>&nbsp;
    <a href="https://github.com/hakuimaku/hakuspace/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/hakuimaku/hakuspace?style=for-the-badge&label=Stars&labelColor=%23000000&color=%23212121&logo=github&logoColor=%23FFFFFF"></a>&nbsp;
    <a href="https://github.com/hakuimaku/hakuspace"><img alt="Repo Size" src="https://img.shields.io/github/repo-size/hakuimaku/hakuspace?style=for-the-badge&label=Repo%20Size&labelColor=%23000000&color=%23212121&logo=github&logoColor=%23FFFFFF"></a>
</p>

| <img width="1920" height="1080" alt="screenshot_2026-10-16_20-13-32" src="https://github.com/user-attachments/assets/a5fa45ea-35fc-45fb-bc9c-26cb981a48d9" /> | <img width="1920" height="1080" alt="screenshot_2026-10-16_18-36-19" src="https://github.com/user-attachments/assets/636d0b55-b1ea-4de7-a241-e3053e545f20" /> |
|--|--|
| <img width="1920" height="1080" alt="screenshot_2026-09-29_16-13-28" src="https://github.com/user-attachments/assets/69ce3bf5-3dd0-43a9-aa7f-d12fd488dfb9" /> | <img width="1920" height="1080" alt="screenshot_2026-09-29_16-12-47" src="https://github.com/user-attachments/assets/f429c5b6-9694-4ed6-9aa6-a87d25f8247a" /> |

## Welcome to Haku Space

<div align="center">

[Installation](#installation-guide) - [Update](#update-haku-space) - [Packages](#programs) - [Keybinding](#keybinding) - [Troubleshooting](#troubleshooting) - [Docs](#documentation) - [Contributing](#contributing) - [Credits](#credits)

*Need help or want to chat? Join our Discord server or follow us on TikTok for showcase videos!*

[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Juuun8sXsN) [![TikTok](https://img.shields.io/badge/TikTok-000000?style=for-the-badge&logo=tiktok&logoColor=white)](https://www.tiktok.com/@hakuimaku2372)

</div>

- **Dual Shell Modes**: Keep the proven **Classic** stack (Waybar / Rofi / SwayNC) or switch to **Hikai**, the native Quickshell desktop shell.
- **Multi-WM Support**: Hyprland, Niri, MangoWM, and Labwc share the same HakuSpace scripts, state, themes, and user customization layer.
- **Arch Linux Focused**: Currently developed and tested exclusively on **Arch Linux** (legacy guides for [NixOS](#nixos-configuration) and [Fedora](docs/fedora_guide.md) are kept for reference, but are not actively tested).
- **Modular Management**: Install, update, link, unlink, diagnose, and roll back individual modules safely.
- **Extensible**: Highly customizable via `~/hakucfg` without touching the main repo files.
- See Guide for: [Arch Linux](#installation-guide) | [NixOS (Outdated)](#nixos-configuration) | [Fedora (Outdated)](docs/fedora_guide.md)

---

## Shell Modes

Haku Space provides two interchangeable desktop shells. Your chosen mode is saved automatically and restored on your next login.

### Hikai - Quickshell Native
**Hikai** is HakuSpace's Quickshell-based shell mode. See [Hikai](docs/hikai.md) for its architecture and design contracts.

### Classic - Waybar / Rofi / SwayNC
**Classic** keeps the original Haku Space experience: Waybar, Rofi menus, SwayNC, and the script-driven workflow. You can switch between Hikai and Classic anytime:

```bash
~/.local/bin/haku_backend.sh set hikai
~/.local/bin/haku_backend.sh set classic
~/.local/bin/haku_backend.sh --toggle
~/.local/bin/haku_backend.sh --verify
```

You can also press **`SUPER + ESCAPE`** at any time as an emergency shortcut to switch back to Classic.

---

## Key Features

* **User Configuration (`~/hakucfg`)**: Stores your personal configs separately from the base files.
* **Accent Colors**: Synced across configured applications and icon themes.
* **Smart Accent Color**: Automatically generates the accent color based on your current wallpaper.
* **Flexible Waybar Layouts**: Supports 7 styles in Classic mode: `top`, `left`, `coredge`, `minimal`, `neon`, `island`, `legacy`.
* **Wallpaper Automation**: Supports both static (`awww`) and lively video (`mpvpaper`) wallpapers, with optional auto-rotation every 5 minutes.
* **Taskbar (Classic)**: A secondary Waybar with `wlr/taskbar` that lets you pin applications like a dock.
* **Haku Space Built-in Mini-Apps**:
  * **Unique Cava Underbar**: *Built-in*, dynamic audio visualizer waves seamlessly layered beneath your bar.
  * **Desktop Icons**: *Built-in*, items in `~/Desktop` are rendered directly on your desktop with drag-and-drop support.
  * **Rounded Screen Corners**: *Built-in*, smooth rounded corners and frame around your screen.
  * **Edge Trigger**: *Built-in*, hover your mouse at the screen edges to quickly pop up menus or panels.

> [!note]
> HakuSpace is modular: features that aren't enabled don't stay running in the background, keeping resource usage light!

> [!tip]
> See the RAM breakdown in the [Performance](#performance) section below.

---

## Programs

<div align="center">

See more information in: [pkg-core](src/packages/pkg-core.txt) | [pkg-service](src/packages/pkg-service.txt) | [pkg-optional](src/packages/pkg-optional.txt)

Specific packages for each WM: [pkg-hyprland](src/packages/pkg-hyprland.txt) | [pkg-niri](src/packages/pkg-niri.txt) | [pkg-mango](src/packages/pkg-mango.txt) | [pkg-labwc](src/packages/pkg-labwc.txt)

</div>

| Component | Programs |
|---|---|
| Shell Runtime | [Quickshell](https://quickshell.org/) |
| Classic Tools | [Waybar](https://github.com/alexays/waybar), [Rofi](https://github.com/davatorium/rofi), [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) |
| Terminal | [Kitty](https://github.com/kovidgoyal/kitty) |
| Shell | [Fish](https://fishshell.com/) + [Starship](https://starship.rs/) |
| File Manager | [Thunar](https://docs.xfce.org/xfce/thunar/start) |
| Wallpaper | [Awww](https://codeberg.org/LGFae/awww) + `mpvpaper` |
| Idle Management | [Hypridle](https://github.com/hyprwm/Hypridle) |
| Screen Lock | [Hyprlock](https://github.com/hyprwm/hyprlock) |
| Screen Recording | [wl-screenrec](https://github.com/russelltg/wl-screenrec) |
| Editor | [VS Code](https://code.visualstudio.com/) (replaceable) |
| Browser | [Firefox](https://www.firefox.com/en-US/) (replaceable) |
| Display Manager (Default) | [Ly](https://codeberg.org/fairyglade/ly#systemd) |

> XDG Desktop Portal: GTK by default, but each WM will use its specific, recommended portal according to its official wiki (Hyprland uses Hyprland, Niri uses GNOME, and MangoWM/Labwc use wlr).

> Accent Color based on wallpaper using [python-colorthief](https://github.com/fengsp/color-thief-py).

---

## Installation Guide

> [!warning]
> **Notice for Fedora & NixOS users:** Development and testing focus on **Arch Linux**. The Fedora and NixOS setups are legacy and unsupported. See the retained [Fedora Guide](docs/fedora_guide.md) and [NixOS notes](#nixos-configuration) for reference.

### Prerequisites

- You have completed the installation of Arch Linux (or a derivative distribution).
- You have installed and configured essential utilities such as Wi-Fi, Bluetooth, Audio, and the necessary hardware drivers.
- You are comfortable reading configuration files and scripts to customize this dotfiles project.

### Clone Haku Space

Stable release (recommended):

```bash
cd ~
git clone --depth 1 --branch v26.10-1 https://github.com/hakuimaku/hakuspace.git ~/hakuspace
cd ~/hakuspace
```

If you prefer the **latest changes**:

```bash
cd ~
git clone https://github.com/hakuimaku/hakuspace.git ~/hakuspace
cd ~/hakuspace
```

### Method 1 - Automatic Installation (`install.sh`)

This is the recommended method for a complete Haku Space setup. The installer lets you select your Window Manager and deployment mode, then orchestrates the package, config, core-script, state, asset, shell, display-manager, desktop-default, and diagnostic modules for you.

```bash
cd ~/hakuspace
chmod +x install.sh
./install.sh
```

After the installer finishes, restart your computer and log in to **Hyprland**, **Niri**, **MangoWM**, or **Labwc**.

### Method 2 - Manual / Modular Installation

Use this method if you want full control over which package groups and configuration modules are installed. You can inspect the available targets first:

```bash
cd ~/hakuspace
./packages.sh --list
./link.sh --list
```

#### Full Haku Space, module by module

The example below installs Niri. Replace `niri` with `hyprland`, `mango`, or `labwc` as needed. You can also pass more than one WM group/module.

```bash
cd ~/hakuspace

# 1. Bootstrap/check the installer dependencies (Arch/yay flow)
./scripts/dependencies.sh

# 2. Review and install package groups
./packages.sh --plan core service optional niri
./packages.sh core service optional niri

# 3. Create the base directories
./scripts/directories.sh

# 4. Install configs that are intentionally copied only once
./scripts/once_configs.sh

# 5. Deploy common configs + core scripts + your WM config
./link.sh --all niri

# 6. Optional: install Haku Space icons/themes/wallpapers
./scripts/assets.sh

# 7. Initialize Haku Space state and user overrides
./scripts/state.sh init
./scripts/hakucfg.sh sync

# 8. Optional system integration used by the full installer
./scripts/shell_setup.sh
./scripts/display_manager.sh
./scripts/desktop_defaults.sh

# 9. Verify the installation
./doctor.sh
```

`./link.sh --all` deploys all registered common configs and the scripts from `src/core` into `~/.local/bin`. If you want an even smaller setup, link only the modules you need instead, for example:

```bash
./link.sh quickshell kitty core niri
```

> [!note]
> `optional`, assets, shell setup, display-manager setup, and desktop defaults are not required for every manual installation. Skip the modules you do not want.

#### Quickshell only - Hikai mode

If you already have a supported Wayland compositor configured and only want the Haku Space **Quickshell / Hikai** interface, you do not need to deploy all Haku Space configs or replace your WM configuration.

```bash
cd ~/hakuspace

# 1. Install the core package group.
#    Quickshell is expected to be included in pkg-core.txt.
./scripts/dependencies.sh
./packages.sh --plan core
./packages.sh core

# 2. Create base directories and deploy only Quickshell + Haku Space core scripts
./scripts/directories.sh
./link.sh quickshell core

# 3. Initialize the state/config data used by Hikai
./scripts/state.sh init
./scripts/hakucfg.sh sync

# 4. Start Hikai now and verify it
~/.local/bin/haku_backend.sh set hikai
~/.local/bin/haku_backend.sh --verify
```

If you keep your **own** WM configuration instead of linking a Haku Space WM module, add this command to your compositor's autostart so the selected Hikai backend starts again on future sessions:

```bash
~/.local/bin/session_start.sh --early
```

Haku Space's bundled Hyprland, Niri, MangoWM, and Labwc configs already call this startup hook, so no extra step is needed when you use those configs.

> [!important]
> Hikai depends on the scripts deployed by the `core` module. Linking only `quickshell` is not enough for the full Haku Space Hikai experience.

### After Installation

1. **Change the GTK theme**
   - Open `GTK Settings` from the Rofi App Menu (`SUPER + Space`).
   - Change the theme, icons, and mouse cursor to your preference.

2. **Install `waybar-cava` if you use the Classic Waybar cava module**

   ```bash
   yay -S waybar-cava
   ```

3. **Allow the local root user to access X/Xwayland display when needed**

   ```bash
   xhost +si:localuser:root
   ```

   This allows local root GUI applications such as `GParted` to connect to the current user's X/Xwayland display.

---

## Dotfiles Management

Haku Space manages your dotfiles safely without needing Stow or Git worktrees:
- **Deployment Modes**: Choose between **Deep Symlink** (default - links individual files so edits sync immediately while keeping `~/.config` folders real) or **Copy** mode.
- **Install-only configs**: Apps like Thunar, btop, and cava rewrite their own configs, so Haku Space copies them only once on install and never overwrites them on update.
- **Safe Customization**: `~/hakucfg` is preserved by default. Missing templates are seeded, and version-mismatched `setting.sh` is only replaced after confirmation.

See the full breakdown in: [Management & Deployment](docs/management.md)

### Available Commands

| Command | Description |
|---|---|
| `./install.sh` | Full automatic installation profile |
| `./update.sh` | Full automatic update profile |
| `./link.sh [modules]` | Link specific modules (e.g. `./link.sh quickshell niri core`) or `./link.sh --all` |
| `./unlink.sh [modules]` | Safely remove tracked symlinks without touching user data (`./unlink.sh --all`) |
| `./packages.sh [groups]` | Install package groups (e.g. `./packages.sh core niri`) or `./packages.sh --all` |
| `./doctor.sh` | Read-only integrity check and troubleshooting instructions |
| `./rollback.sh` | Restore previous configuration backups safely |

### Update Haku Space
Simply run the `update.sh` script in the hakuspace folder. This will safely update the core files while preserving your personal settings in `~/hakucfg`.
```bash
cd ~/hakuspace
./update.sh
```

### Rollback & Uninstall Haku Space
If an update breaks something, or you want to restore your previous configs from `~/.backup/`:
```bash
cd ~/hakuspace
./rollback.sh
```

If you installed in **Symlink mode** and want to cleanly remove Haku Space symlinks without deleting your real files:
```bash
./unlink.sh --all niri   # Replace with the WM(s) you installed: hyprland niri mango labwc
```

> [!important]
> Do **not** manually delete everything in `~/.local/bin` or wipe entire `~/.config` folders! Read the full step-by-step **[Uninstall Guide in `docs/management.md`](docs/management.md#6-uninstalling-hakuspace)** to safely clean up runtime state, optional assets, and Copy-mode files.

---

## Visual Ecosystem

Haku Space comes with its own matching visual suite installed via `hakuspace-archive` (`./scripts/assets.sh`):
- **[Haku Cursor](https://github.com/hakuimaku/haku-cursor)** (default: `Haku-Dark`, size `24`)
- **[Hikaide GTK](https://github.com/hakuimaku/hikade-gtk-theme)** (default: `Hikaide`)
- **[Hikaide-Symbols](https://github.com/hakuimaku/hikaide-symbols)** (automatically recolored to match your active wallpaper/theme accent color!)

Want to use a different cursor variant or your own icon pack? Just create or edit `~/.config/hakuspace/appearance.env`:

```bash
HAKU_ICON_THEME=Hikaide-Symbols   # or another theme like Papirus-Dark, or 'system'
HAKU_ICON_ACCENT_MODE=auto       # auto | on | off
HAKU_CURSOR_THEME=Haku-Dark      # e.g. Haku-Light, Haku-Blue, Haku-Pink
HAKU_CURSOR_SIZE=24
```

You can also control your accent color and check your visual setup from the terminal:

```bash
~/.local/bin/theme_ctl.sh set-accent '#AC7994'
~/.local/bin/theme_ctl.sh apply
~/.local/bin/appearance_ctl.sh status
```

To see how the internal icon recoloring engine (`haku_icon_accent.py`) and theme controllers work under the hood, check out **[Theming Engine & Visual Ecosystem](docs/core/theme.md#visual-ecosystem-icons-gtk--cursor-sync)**.

---

## Performance

The figures below are **Classic-stack measurements** from a system with **16GB RAM**, kept as a rough reference:

- **Fresh Arch Linux + Dotfiles (Base):** ~1.1 GB RAM
- **Taskbar enabled:** +77 MB
- **Desktop Icons enabled:** +100 MB
- **Cava Underbar enabled:** +100 MB (High CPU usage)
- **Rounded Screen enabled:** +70 MB
- **Edge Trigger enabled:** +60 MB

**Total:** If you use all the built-in mini-apps simultaneously, it will consume at least **~1.5 GB RAM** upon startup.

> [!note]
> During your actual workflow, RAM consumption will naturally expand further depending on the applications you use and your specific needs.

---

## NixOS Configuration

> [!warning]
> NixOS integration is currently legacy and unsupported. The retained `scripts/nixos.sh` / `nix/` implementation is kept for reference, but the current Arch-focused automatic installer does not provide a working NixOS installation path.

See [NixOS Integration](docs/nixos.md) for the retained legacy design.

---

## Plugin Configuration (Hyprland Only)

You can immediately use the plugins that I have pre-configured. Simply install and enable them using the commands below (or tweak them as you like in `plugin.lua`).

* **[hyprexpo](https://github.com/sandwichfarm/hyprexpo)** - Overview layout for your workspaces.
* **[hypr-dynamic-cursors](https://github.com/VirtCode/hypr-dynamic-cursors)** - Smooth, physics-based dynamic cursor effects.

```bash
hyprpm update

hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors

hyprpm add https://github.com/sandwichfarm/hyprexpo
hyprpm enable hyprexpo

hyprpm reload
```
Read the Wiki for more info: https://wiki.hypr.land/Plugins/Using-Plugins/

See more in `~/hakucfg/wm/hyprland-custom.lua` or [here](src/home/hakucfg/wm/hyprland-custom.lua#L33) for guide.

---

## Keybinding

- See more keybinding in: [Hyprland](src/home/.config/hypr/config/keybinding.lua) | [Niri](src/home/.config/niri/keybinds.kdl) | [MangoWM](src/home/.config/mango/bind.conf) | [Labwc](src/home/.config/labwc/rc.xml#L267)
- Common Hotkeys:

| Bind | Function |
|------|----------|
| SUPER + Space | App Menu (Launcher) |
| SUPER + Q | Open Kitty Terminal |
| SUPER + C | Kill / Close Focus Window |
| SUPER + E | Open File Manager |
| SUPER + B | Open Browser |
| SUPER + / | Open Emoji Menu |
| SUPER + TAB | Open Haku Menu |
| SUPER + N | Open Notification Center (routes to active backend) |
| SUPER + ESCAPE | Emergency switch to Classic backend |
| SUPER + V | Open Clipboard History |
| SUPER + SHIFT + V | Wipe Clipboard History |
| SUPER + P | Screenshot |
| SUPER + SHIFT + P | Fullscreen Screenshot |
| SUPER + F11 | Record Screen |
| SUPER + T | Toggle Cava Underbar |
| SUPER + Y | Wallpaper Select |
| SUPER + SHIFT + Y | Change Theme |
| SUPER + SHIFT + E | Exit Session |
| SUPER + SHIFT + Q | Power Menu / Shutdown |
| SUPER + Z | Toggle Taskbar (Classic) |
| SUPER + SHIFT + Z | Cycle Waybar Mode |
| SUPER + CTRL + Z | Toggle Waybar |
| SUPER + W | Toggle Floating Window (Hyprland, Niri, MangoWM) |
| SUPER + F | Maximize / Fullscreen Window |
| SUPER + SHIFT + F | Fullscreen Window (Hyprland, Niri, MangoWM) |
| SUPER + A / S | Focus Left / Right Window (or Arrow keys) |
| SUPER + SHIFT + A / S | Move / Swap Window Left / Right |
| SUPER + 1..9 | Switch Workspace |
| SUPER + SHIFT + 1..9 | Move Window to Workspace |

- Specific Window Manager Keybindings:

| Window Manager | Bind | Function |
|---|---|---|
| **Hyprland** | SUPER + D / SHIFT + D | Scroller Column Resize (+0.1 / -0.1) |
| | SUPER + L | Cycle Layout (scrolling, dwindle, master) |
| | SUPER + X | Toggle Special Workspace (Scratchpad) |
| | SUPER + F1 | Toggle No-gap Mode |
| | SUPER + U / = / - | Cursor Zoom |
| **Niri** | SUPER + G | Toggle Overview |
| | SUPER + D / SHIFT + D | Set Column Width (+10% / -10%) |
| | SUPER + M / ALT + F | Maximize Window to Edges |
| | Mod + Shift + / | Show Hotkey Overlay |
| **MangoWM** | SUPER + G / ALT + TAB | Toggle Overview |
| | SUPER + D | Switch Proportion Preset |
| | SUPER + ALT + R | Reload Config |
| | SUPER + SHIFT + Arrows | Focus Monitor |
| | SUPER + ALT + Arrows | Tag Window to Monitor |
| | CTRL + ALT + Delete | Quit MangoWM |
| **Labwc** | SUPER + M | Toggle Maximize |
| | SUPER + S | Iconify (Minimize) |
| | SUPER + D | Toggle Show Desktop |
| | SUPER + F | Toggle Fullscreen |
| | ALT + GRAVE ( \` ) | Open Client Menu |
| | ALT + Tab / SHIFT + Tab | Next / Previous Window |
| | ALT + WASD / SHIFT + WASD | Resize Window (+20% / -20%) |
| | SUPER + Arrows | Snap Window to Edge |

---

## Assets Located

- Custom config (your personal changes): `~/hakucfg`
- Hakuspace state folder: `~/.local/state/hakuspace`
- Icons: `~/.icons`
- Themes: `~/.themes`
- All hakuspace scripts: `~/.local/bin`
- Fastfetch logo: `~/.config/fastfetch`
- Wallpapers: `~/Pictures/Wallpapers`
- Lively wallpapers: `~/Videos/Wallpapers`

---

## Documentation

Want to understand how HakuSpace works under the hood? We've written comprehensive documentation explaining the internal architecture, scripts, and theming engine.

- [Architecture Overview](docs/architecture.md) (**Start Here!**)
- [Management & Deployment](docs/management.md)
- [Core Script Structure](src/core/README.md)
- [The Core Libraries](docs/core/lib.md)
- [Theming Engine & Visual Ecosystem](docs/core/theme.md)
- [System Scripts](docs/core/sys.md)
- [Utilities](docs/core/util.md)
- [Haku Menu](docs/core/menu.md)
- [Mini-Apps (Taskbar, Desktop Icons, Rounded Screen, Edge Trigger, Cava)](docs/core/app.md)
- [NixOS Integration](docs/nixos.md)
- [Hikai](docs/hikai.md)

---

## Troubleshooting

**Hikai / Quickshell issues**:
- Check if Hikai is running properly:
  ```bash
  ~/.local/bin/haku_backend.sh --check
  ~/.local/bin/haku_backend.sh --verify
  ```
- If Hikai fails to start, switch back to Classic with `~/.local/bin/haku_backend.sh set classic` or press **`SUPER + ESCAPE`**.
- Quickshell runtime logs are saved in `${XDG_RUNTIME_DIR}/hakuspace/`.

**Waybar / Classic issues**:
- **Waybar clock**: Set your timezone and locale manually in the Waybar configuration to ensure the clock displays correctly.
- **Waybar cava module**: Install `waybar-cava` if you want to use the Cava module inside Classic Waybar.

**My dotfiles issues**:
- Run `./doctor.sh` to check for broken symlinks or overwritten config files, and use `./rollback.sh` if an update causes issues.
- Some features might still be missing since I mainly tested this setup for **my personal use**. If you need more than what's provided, you can customize it in `~/hakucfg`.
- If you don't want to use certain apps (like `wl-screenrec`, `thunar`, `ly`, etc.), you can replace them with alternatives - just keep in mind some apps are tightly integrated into my scripts.
- If you encounter any **issues** during installation or configuration, feel free to ask on my [TikTok](https://www.tiktok.com/@hakuimaku2372), open an issue on GitHub, or join my [Discord](https://discord.gg/Juuun8sXsN)!

---

## Contributing

- This is a personal dotfiles configuration. Feel free to fork and adapt it to your needs!
- Just make **Pull Requests** if you want to contribute to this project. I will review and merge them if they are useful for everyone.
- Tiktok / See more showcase: [@hakuimaku2372](https://www.tiktok.com/@hakuimaku2372)
- Discord: [haku-shell](https://discord.gg/Juuun8sXsN)

| Contributor | Role |
|-------------|-------------|
| [hakuimaku](https://github.com/hakuimaku) | The Author |
| You | ... |

---

## Credits

See **hakuspace-archive** for the assets used in this project: [hakuspace-archive](https://github.com/hakuimaku/hakuspace-archive)

---

## License
MIT License
