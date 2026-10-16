<div align="center">

# Haku Space
Wayland dotfiles and desktop shell for Hyprland / Niri / MangoWM / Labwc

**Classic** (Waybar / Rofi / SwayNC) + **Hikai** (Quickshell)

*Haku (ハク) is the very highest Value, the manifestation of a wish. It means "the shape of a soul," "that which is irreplaceable."*
    <div align="right">
        <i>⸻ Made in Abyss ⸻</i>
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

| <img width="1920" height="1080" alt="screenshot_2026-09-29_16-13-28" src="https://github.com/user-attachments/assets/69ce3bf5-3dd0-43a9-aa7f-d12fd488dfb9" /> | <img width="1920" height="1080" alt="screenshot_2026-09-29_16-12-47" src="https://github.com/user-attachments/assets/f429c5b6-9694-4ed6-9aa6-a87d25f8247a" /> |
|--|--|
| <img width="1920" height="1080" alt="screenshot_2026-09-23_15-52-55" src="https://github.com/user-attachments/assets/b87cd87d-f9da-4e32-8b0d-5b948dd55c19" /> | <img width="1920" height="1080" alt="screenshot_2026-09-23_15-43-51" src="https://github.com/user-attachments/assets/aba0fcdd-b063-451a-bf1f-7c77e879c0a8" /> |

## Welcome to Haku Space

<div align="center">

[Installation](#installation-guide) ─ [Update](#update-haku-space) ─ [Packages](#programs) ─ [Keybinding](#keybinding) ─ [Troubleshooting](#troubleshooting) ─ [Docs](#documentation) ─ [Contributing](#contributing) ─ [Credits](#credits)

*Need help or want to chat? Join our Discord server or follow us on TikTok for showcase videos!*

[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Juuun8sXsN) [![TikTok](https://img.shields.io/badge/TikTok-000000?style=for-the-badge&logo=tiktok&logoColor=white)](https://www.tiktok.com/@hakuimaku2372)

</div>

- **Dual shell modes**: keep the proven **Classic** stack or switch to **Hikai**, the native Quickshell desktop shell.
- **Multi-WM support**: Hyprland, Niri, MangoWM, and Labwc configs share the same HakuSpace scripts, state, theme, and user overrides.
- **Multi-distro support**: developed for Arch and also used with Fedora / NixOS-specific setup paths.
- **Modular dotfiles management**: install, update, link, unlink, diagnose, and roll back individual modules instead of treating the repository as one giant config copy.
- **User-owned customization**: `~/hakucfg` remains separate from the managed base so updates can evolve without overwriting personal settings.
- See Guide for: [Arch Linux](#installation-guide) | [NixOS](#nixos-configuration) | [Fedora](docs/fedora_guide.md)

## Visual ecosystem

[Haku Cursor](https://github.com/hakuimaku/haku-cursor),
[Hikaide GTK](https://github.com/hakuimaku/hikade-gtk-theme), and optional
[Hikaide-Symbols](https://github.com/hakuimaku/hikaide-symbols) are installed by
`hakuspace-archive`. HakuSpace owns appearance selection, canonical accent state
and the internal safe recoloring engine. There is no external accent executable
or source checkout required at runtime.

```text
Theme UI / wallpaper / CLI → theme_ctl → state.env
                                    → gen_style / apply_style
                                    → appearance_ctl → haku_icon_accent.py
                                                     → configured icon theme
```

`scripts/assets.sh` installs/updates the three visual sources and wallpapers via
`~/hakuspace-archive`, verifies/selects configured appearance, then reconciles the
current accent. `--dry-run` describes the sequence. For local tests,
`HAKUSPACE_ARCHIVE_SOURCE` selects an archive checkout without pulling it; the
archive accepts `HAKU_CURSOR_SOURCE`, `HAKU_GTK_THEME_SOURCE` and
`HAKU_ICON_THEME_SOURCE`. Production paths still use HOME and the XDG cache.
Archive/source caches can be deleted after installation.

The only canonical accent is `ACCENT_COLOR` in
`~/.local/state/hakuspace/state/state.env`. Classic, Hikai, wallpaper extraction
and the CLI use the same controller. `set-accent` saves state, renders/reloads
consumers, then synchronizes icons according to appearance policy. `apply`
reconciles icons after reinstall/restore even if canonical accent has not changed.
`set-font` and `set-size` do not recolor icons. `gen_style.sh` only renders; custom
scripts must use controller commands to mutate state.

```bash
~/.local/bin/appearance_ctl.sh status
~/.local/bin/appearance_ctl.sh verify
~/.local/bin/appearance_ctl.sh apply
~/.local/bin/theme_ctl.sh set-accent '#AC7994'
~/.local/bin/theme_ctl.sh apply
```

Defaults live in `src/core/lib/haku_appearance.sh`. Set environment variables or
`${XDG_CONFIG_HOME:-$HOME/.config}/hakuspace/appearance.env`:

```bash
HAKU_ICON_THEME=Hikaide-Symbols   # default: select the installed icon theme
# HAKU_ICON_THEME=Papirus-Dark    # select another installed theme
# HAKU_ICON_THEME=system          # leave the desktop icon-theme setting alone
HAKU_ICON_ACCENT_MODE=auto       # default: only managed Hikaide-Symbols
# HAKU_ICON_ACCENT_MODE=on        # opt in to safe recoloring of a user-owned theme
# HAKU_ICON_ACCENT_MODE=off       # never recolor icons
```

`system` always disables icon synchronization. `auto` leaves other themes and
unmanaged Hikaide-Symbols untouched. `on` uses the internal scanner against the
theme under `HAKU_ICON_DIR` (default `~/.icons`); static/GTK-symbolic themes report
`not-applicable` and succeed. Third-party themes installed in standard XDG/system
icon locations remain selectable; system-wide files are never recolored.

`verify` checks configured assets: `system` does not require an icon theme;
a configured missing theme fails verification. Normal theme changes warn and
continue when optional icons are missing. `HAKUSPACE_STRICT_ASSETS=1` makes genuine
asset/engine failures nonzero at the controller boundary, while disabled,
external and not-applicable integrations still succeed. Filesystem/backup safety
errors remain nonzero from `appearance_ctl sync-accent`; core state and rendered
outputs are never rolled back. A missing internal engine is a broken HakuSpace
deployment, reported by `verify`, rather than an optional external dependency.

The standard-library-only engine is `src/core/app/icon-accent/haku_icon_accent.py`,
deployed flat to `~/.local/bin/haku_icon_accent.py` in Copy or Deep Symlink mode.
Its CLI supports `inspect`, `status`, `set --dry-run`, `set`, and `restore`:

```bash
python3 ~/.local/bin/haku_icon_accent.py --icons-dir ~/.icons status Hikaide-Symbols
python3 ~/.local/bin/haku_icon_accent.py --icons-dir ~/.icons restore Hikaide-Symbols
# Reapply canonical accent after a manual restore:
~/.local/bin/theme_ctl.sh apply
```

Original backups remain under `${XDG_STATE_HOME:-$HOME/.local/state}/icon-accent/`
with the same checksums/format. Archive update removes the old two installed
engine files only if both match its complete checksum receipt; modified,
symlinked or unmanaged files are preserved with a warning. This cleanup runs at
installation time, never every session.

GTK/cursor defaults are Hikaide, **Haku-Dark** and size 24. Cursor assets install
at `~/.icons/$HAKU_CURSOR_THEME`. Select an exact theme in appearance.env:

```bash
HAKU_CURSOR_THEME=Haku-Dark
HAKU_CURSOR_SIZE=24
# HAKU_CURSOR_THEME=Haku-Light
# Optional colour variants: Haku-Blue, Haku-Blue-Light, Haku-Pink, Haku-Pink-Light
```

`HAKU_GTK_THEME`, `HAKU_CURSOR_THEME` and `HAKU_CURSOR_SIZE` override selection.
The archive builds only the selected style and installs its exact directory;
it does not install or replace the sibling dark/light variant. Upstream animation
defaults remain unchanged. For one compatibility cycle, deprecated
`HAKU_CURSOR_PALETTE=blue` still resolves to Haku-Blue (dark variant).
Resolution is explicit theme → legacy palette → Haku-Dark; prefer the exact theme
setting for new configuration. Existing managed cursor installations in the old
XDG location are left intact, and runtime can still discover them as a fallback.

Cursor selection writes managed `environment.d/90-hakuspace-cursor.conf`;
Hyprland gets a best-effort live setter, while Niri/MangoWM use the next session's
imported environment. No global `GTK_THEME`, cursor rebuild-on-accent, CSS
injection, watcher or daemon is added.
Reopen applications to refresh cached icons; file managers are not killed.

See the [V2 report](docs/task/HAKUSPACE_INTERNAL_ICON_ACCENT_V2_REPORT.md) for
parity, migration, deployment and integration results. The
[V1 report](docs/task/HAKUSPACE_VISUAL_ECOSYSTEM_INTEGRATION_REPORT.md) is historical;
its external-engine architecture is superseded by V2.

## Shell Modes

HakuSpace now has two interchangeable desktop-shell backends. The selected backend is stored in HakuSpace state and restored by `session_start.sh --early` on the next compositor session.

### Hikai — Quickshell native

**Hikai** is the new Quickshell-based HakuSpace interface. In Hikai mode, Quickshell owns the main desktop UI instead of running the Classic Waybar/Rofi/SwayNC stack in parallel.

Current Hikai surfaces include:

- **Top bar** with workspace state, active-window title, tray, clock, system information, notification state, recorder state, and settings entry points.
- **Navigation layer** that opens the Dashboard, Sidebar, and Settings surfaces with the shared HakuSpace motion / Flare visual language.
- **Dashboard** with profile information, media controls, Cava visualization, calendar, CPU/RAM/GPU metrics, and mounted-storage information.
- **Sidebar** with quick actions, clipboard access, pinned applications, temporary notes, and shortcut management.
- **Native notifications** through `org.freedesktop.Notifications`, including popup/history handling, replacement IDs, timeout/close behavior, DND, persistence across Quickshell reloads, and a native Notification Center.
- **Native Haku Menu / wallpaper / action layers**, plus volume and brightness OSDs, rounded-screen rendering, tray menus, theme controls, and the Hikai Settings UI.
- **Settings and config editing** for supported `~/hakucfg/setting.sh` options plus a built-in configuration browser/editor and system information page.
- **WM-aware workspaces** for Hyprland, Niri, and MangoWM through dedicated Quickshell backends.

> [!note]
> Labwc itself remains a supported HakuSpace compositor, but Hikai workspace loading is currently disabled on Labwc because the ext-workspace path is unstable with the Quickshell version targeted by this branch. Other Hikai surfaces can still run.

### Classic — Waybar / Rofi / SwayNC

**Classic** keeps the previous HakuSpace desktop stack: Waybar, Rofi menus, SwayNC, and the existing script-driven mini-apps. It remains available as a compatibility/fallback backend rather than being removed by the Quickshell migration.

Switch between backends at runtime:

```bash
~/.local/bin/haku_backend.sh set hikai
~/.local/bin/haku_backend.sh set classic
~/.local/bin/haku_backend.sh --toggle
~/.local/bin/haku_backend.sh --verify
```

The bundled WM configs also bind **`SUPER + ESCAPE`** as an emergency return to Classic.

---

## Key Features

* **Hikai + Classic backends**: Use the Quickshell-native Hikai experience or keep the mature Classic stack; shared facade scripts route common actions to the active backend.
* **HakuSpace Settings**: Hikai provides a native Settings surface for supported HakuSpace options, config editing, and system/repository information. `~/hakucfg` remains the source of user-owned customization.
* **Shared theming**: Accent colors, typography, radius tokens, and generated state are reused across Hikai and Classic components where applicable.
* **Smart accent color**: Generate an accent from the active wallpaper with multiple extraction modes.
* **Wallpaper system**: Static and lively wallpaper workflows, automatic rotation, picker UIs, and shared theme refresh behavior.
* **Workspace integration**: Dedicated Hikai workspace models for Hyprland, Niri, and MangoWM, including compositor-specific active/focused/occupied semantics.
* **Native desktop services in Hikai**: Notifications, tray UI, media state, audio/brightness control, system statistics, recorder state, persistent text/avatar data, and IPC-backed shell actions.
* **Classic layouts remain available**: Waybar layouts such as `top`, `left`, `coredge`, `minimal`, `neon`, `island`, and `legacy`, plus the Classic Rofi/SwayNC workflow.
* **Desktop extras**: Cava underbar, Desktop Icons, Rounded Screen, Edge Trigger, taskbar/dock workflow, screenshots, recording, clipboard tools, and session/power actions.
* **Safer dotfiles lifecycle**: Deep Symlink or Copy deployment, centralized target registry, install-only configs, per-run backups, diagnostics, rollback, and safe unlinking.

> [!note]
> HakuSpace is modular. Features that are not enabled do not need to stay running, and Hikai replaces several Classic UI processes instead of stacking another complete shell on top of them.

> [!tip]
> The [Performance](#performance) numbers below are historical Classic-stack measurements; Hikai uses a different process model and should be measured separately.

---

## Programs

<div align="center">

See more information in: [pkg-core](src/packages/pkg-core.txt) | [pkg-service](src/packages/pkg-service.txt) | [pkg-optional](src/packages/pkg-optional.txt)

Specific packages for each WM: [pkg-hyprland](src/packages/pkg-hyprland.txt) | [pkg-niri](src/packages/pkg-niri.txt) | [pkg-mango](src/packages/pkg-mango.txt) | [pkg-labwc](src/packages/pkg-labwc.txt)

</div>

| Component | Hikai | Classic / Shared |
|---|---|---|
| Desktop shell / status UI | [Quickshell](https://quickshell.org/) | [Waybar](https://github.com/alexays/waybar) |
| App launcher / menus | Native Haku Menu, Action Menu, picker surfaces | [Rofi](https://github.com/davatorium/rofi) |
| Notifications | Native Quickshell `NotificationServer` + HakuSpace Center | [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) |
| System tray | Native Quickshell tray + tray menus | Waybar tray |
| Terminal | [Kitty](https://github.com/kovidgoyal/kitty) | Shared |
| Shell | [Fish](https://fishshell.com/) + [Starship](https://starship.rs/) | Shared |
| File Manager | [Thunar](https://docs.xfce.org/xfce/thunar/start) | Shared |
| Wallpaper | [Awww](https://codeberg.org/LGFae/awww) + `mpvpaper` | Shared |
| Idle Management | [Hypridle](https://github.com/hyprwm/Hypridle) | Shared |
| Screen Lock | [Hyprlock](https://github.com/hyprwm/hyprlock) | Shared |
| Screen Recording | [wl-screenrec](https://github.com/russelltg/wl-screenrec) | Shared |
| Editor | [VS Code](https://code.visualstudio.com/) | Shared / replaceable |
| Browser | [Firefox](https://www.firefox.com/en-US/) | Shared / replaceable |
| Display Manager (Default) | [Ly](https://codeberg.org/fairyglade/ly#systemd) | Shared |

> [!note]
> The public HakuSpace scripts are increasingly backend-neutral. Commands such as notification, wallpaper, launcher, recording, power/session, and theme actions are routed through facade/controller layers so keybindings do not need separate Hikai and Classic commands.

> XDG Desktop Portal: GTK by default, but each WM will use its specific, recommended portal according to its official wiki (Hyprland uses Hyprland, Niri uses GNOME, and MangoWM/Labwc use wlr).

> Accent color generation uses [python-colorthief](https://github.com/fengsp/color-thief-py).
---

## Installation Guide

> [!tip]
> For Fedora users, you should follow the [Fedora Guide](docs/fedora_guide.md). The package module currently uses `yay`, so package installation on non-Arch distributions must follow the distro-specific setup first.

### Prerequisites

- You have completed the installation of Arch, Fedora, NixOS, or a derivative distribution.
- You have installed and configured essential utilities such as Wi-Fi, Bluetooth, Audio, and the necessary hardware drivers.
- You are comfortable reading configuration files and scripts. Hikai now includes a native Settings/config editor for supported options, but HakuSpace is still a dotfiles project rather than a fully graphical desktop control center.

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

### Method 1 — Automatic Installation (`install.sh`)

This is the recommended method for a complete Haku Space setup. The installer lets you select your Window Manager and deployment mode, then orchestrates the package, config, core-script, state, asset, shell, display-manager, desktop-default, and diagnostic modules for you.

```bash
cd ~/hakuspace
chmod +x install.sh
./install.sh
```

After the installer finishes, restart your computer and log in to **Hyprland**, **Niri**, **MangoWM**, or **Labwc**.

### Method 2 — Manual / Modular Installation

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

#### Quickshell only — Hikai mode

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
   - Open `GTK Settings` from the Rofi App Menu (`SUPER + R`).
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

## Dotfiles Management

Haku Space provides modular scripts to safely manage your dotfiles using a flexible, composable mechanism:
- **Thin orchestrators**: `install.sh` and `update.sh` coordinate reusable modules under `scripts/` instead of containing all filesystem/package logic themselves.
- **Single target registry**: `scripts/registry.sh` is the common source of truth used by link/unlink/update/diagnostic workflows.
- **Deployment Mode**: Files are managed via **Deep Symlink** (default, per-file links that preserve real destination directories) or **Copy** mode.
- **Safe lifecycle**: A shared runtime context keeps one backup location per operation; `doctor.sh`, `rollback.sh`, and `unlink.sh` provide read-only diagnosis, restoration, and ownership-aware cleanup.
- **Install-only configs**: Application-managed configs such as Thunar/btop/cava are copied once and are intentionally skipped by later updates.
- **Customization**: Personal tweaks live inside `~/hakucfg`; sync seeds missing templates while preserving user-modified values.
- **Core script architecture**: user-facing compatibility facades are separated from headless backend/controllers and Classic-only frontends, allowing Hikai to reuse the same operations without depending on Rofi.

See more in: [Management & Deployment](docs/management.md)

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

### Manual / Modular Installation
For the complete module-by-module flow, including the **Quickshell-only / Hikai** setup, see [Method 2 — Manual / Modular Installation](#method-2--manual--modular-installation) above.

### Update Haku Space
Simply run the `update.sh` script in the hakuspace folder. This will safely update the core files while preserving your personal settings in `~/hakucfg`.
```bash
cd ~/hakuspace
./update.sh
```

### Rollback Haku Space
Restore files from a backup created by `install.sh` or `update.sh`.
```bash
cd ~/hakuspace
./rollback.sh
```
If multiple backups are available, the newest one is selected by pressing Enter.

### Uninstall Haku Space
Haku Space does not use a destructive one-shot uninstaller. The safest removal path depends on the deployment mode you selected during installation.

> [!important]
> `./unlink.sh` is for **Deep Symlink mode only**. It removes only symlinks verified to belong to Haku Space and preserves real files, foreign symlinks, and application-generated data. Do **not** delete everything in `~/.local/bin` or entire config directories manually.

#### 1. Restore an older configuration (recommended when available)
If you want to restore configuration files that existed before a Haku Space install/update, use a suitable backup:

```bash
cd ~/hakuspace
./rollback.sh
```

Choose the backup you actually want to restore. The newest backup may simply be from a recent Haku Space update rather than your pre-Haku Space configuration.

`rollback.sh` restores managed configuration destinations only. It does not uninstall packages or automatically revert system-level choices such as your login shell, display manager, desktop defaults, or NixOS configuration.

#### 2. Remove Haku Space symlinks
For a **Symlink mode** installation, you can unlink individual modules:

```bash
./unlink.sh quickshell
./unlink.sh niri
./unlink.sh core
```

Or remove all common Haku Space links plus the Window Manager modules you installed:

```bash
# Example: Niri installation
./unlink.sh --all niri

# If you installed several/all supported WMs
./unlink.sh --all hyprland niri mango labwc
```

Use `./unlink.sh --list` to see the available module names.

> [!note]
> `--all` removes the registered **base configs and core scripts**. Window Manager-specific configs are separate modules, so include the relevant WM name(s) as shown above.

For a **Copy mode** installation, `unlink.sh` does not remove copied files. Use `./rollback.sh` when an appropriate backup exists. If no suitable backup exists, review copied configs manually instead of deleting whole directories, because they may now contain your own files or application-generated data.

#### 3. Clean up Haku Space runtime/user data
The runtime state directory is generated by Haku Space and can be removed after you are finished using it:

```bash
rm -rf ~/.local/state/hakuspace
rm -rf ~/.local/share/hakuspace
```

`~/hakucfg` contains your personal customizations and is intentionally **not** removed automatically. Keep it if you may reinstall Haku Space later; remove it manually only after backing up anything you want to preserve.

The install-once configs (`Thunar`, `xfce4`, `mpv`, `btop`, `cava`, and `mimeapps.list`) are real copied files, not managed symlinks. `unlink.sh` intentionally leaves them alone. Prefer restoring them from a suitable Haku Space backup; otherwise review them individually before removing anything.

#### 4. Optional assets and repository cleanup
If you installed the optional `hakuspace-archive`, the cloned repository can be removed separately:

```bash
rm -rf ~/hakuspace-archive
```

The archive setup may also have installed Haku Space icons, themes, cursors, or wallpapers into your home directories. Remove only the Haku Space assets you recognize; do not delete the entire `~/.icons`, `~/.themes`, or `~/Pictures/Wallpapers` directories because they may contain unrelated user files.

After you have restored/unlinked everything you need and verified your setup, you may remove the Haku Space repository itself:

```bash
rm -rf ~/hakuspace
```

Keep `~/.backup/Backup_*` / `Rollback_Backup_*` until you are sure you no longer need to restore anything.

For the custom `~/hakucfg` directory, remove it only after you have backed up any personal changes you want to keep. If you are certain you no longer need it, remove it with:

```bash
rm -rf ~/hakucfg
```

#### 5. Packages and system settings
Package removal is intentionally manual because some packages may have existed before Haku Space or may be used by other applications. You can inspect the package groups before deciding what to remove:

```bash
./packages.sh --list
./packages.sh --dry-run core service niri   # example
```

You can also review the files in `src/packages/`. Remove only packages you are certain you no longer need.

Haku Space currently does not provide an automatic rollback for every system-level choice made during installation. If applicable, also review and restore your preferred:

- default login shell (the installer may switch it to Fish);
- display manager / TTY service configuration (for example, LY);
- desktop defaults such as dark color preference and Thunar file-manager association;
- NixOS integration under `/etc/nixos`.

---

## Performance

Haku Space is designed to balance aesthetic features and resource efficiency. The figures below are **older Classic-stack measurements** from a system with **16GB RAM**; they are kept as a rough reference and are not a current Hikai benchmark:

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

> [!important]
> I've not maintained the NixOS version. Every bugs will not be fixed.

See the main configuration file at [hakuspace-config.nix](nix/hakuspace-config.nix)

> [!note]
> My dotfiles do not use `home-manager` feature rn. I'm not currently using NixOS, next time I use it again, I will develop home-manager feature for NixOS. Or you can contribute it :D
>
> Manage dotfiles by run `install.sh` and `update.sh` script. `hakuspace-config.nix` just a basic setup packages and programs.

* Simply clone this repository and run the `install.sh` script exactly as outlined [above](#installation-guide).
* You can use either method: online remote via [flake.nix](nix/flake.nix.example) or offline by directly importing `hakuspace-config.nix` into your `configuration.nix` (2 modes already have install flow in script `install.sh`).
* `hakuspace-config.nix` does not set a display manager by default, as it may conflict with your existing display manager.
* 2 current options in `hakuspace-config.nix` that you can enable/disable in your `configuration.nix`:

```nix
{
  hakuspace = {
    enable = true; # Enable the full hakuspace config
    enableFishShell = true; # Enable Fish shell
  };
}

```

> [!important]
> Nixpkgs I use is stable, which still install **hypridle** v0.1.7.
> Please install **hyprilde** unstable nixpkgs for v0.1.8 (to use my [idle_inhibit.sh](src/core/sys/idle_inhibit.sh) script).

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

- See more keybinding in: [Hyprland](src/home/.config/hypr/config/keybinding.lua) | [Niri](src/home/.config/niri/keybinds.kdl) | [MangoWM](src/home/.config/mango/bind.conf) | [Labwc](src/home/.config/labwc/rc.xml#L263)
- Hotkeys:

| Bind | Function |
|------|----------|
| SUPER + Q | Open Kitty Terminal |
| SUPER + C | Kill Focus Window |
| SUPER + TAB | Open Menu |
| SUPER + GRAVE | Toggle Hikai Navigation |
| SUPER + N | Open Notification Center (routes to active backend) |
| SUPER + ESCAPE | Emergency switch to Classic backend |
| SUPER + R | App Menu |
| SUPER + W | Toggle Taskbar |
| SUPER + P | Screenshot |
| SUPER + Z | Toggle Floating |
| SUPER + V | Open Clipboard History |
| SUPER + A/S | Focus Left/Right Window |
| SUPER + Y | Wallpaper Select |
| SUPER + SHIFT + Y | Lively Wallpaper Select |
| SUPER + SHIFT + W | Cycle Waybar Mode |
| SUPER + L | Cycle Hyprland Layout (Hyprland Only) |
| SUPER + SHIFT + D | Switch Focus Between Tiling and Floating (Niri Only) |
| SUPER + O | Toggle Overlay (MangoWM Only) |
| SUPER + X | Toggle Special Workspace (Hyprland), Overview (Niri), or Scratchpad (MangoWM) |

- Labwc:

| Bind | Function |
|------|----------|
| SUPER + Space | Open Root Menu |
| SUPER + X | Open Client Menu |
| ALT + ` | Open Combined Client Menu |
| SUPER + A | Maximize |
| SUPER + S | Iconify |
| SUPER + D | Show Desktop |
| SUPER + Z | Shrink Size Window (-10%) |

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
- [The Core Libraries](docs/core/lib.md)
- [Theming Engine](docs/core/theme.md)
- [System Scripts](docs/core/sys.md)
- [Utilities](docs/core/util.md)
- [Haku Menu](docs/core/menu.md)
- [Mini-Apps (Taskbar, Desktop Icons, Rounded Screen, Edge Trigger)](docs/core/app.md)
- [Quickshell / Hikai Master Plan](docs/task/HAKUSPACE_QUICKSHELL_PLAN.md)
- [Quickshell Style Guide](docs/task/QUICKSHELL_STYLE.md)
- [Quickshell Testing Guide](docs/task/QUICKSHELL_TESTING.md)

---

## Troubleshooting

**Hikai / Quickshell checks**:

```bash
~/.local/bin/haku_backend.sh --check
~/.local/bin/haku_backend.sh --verify
qs -c hakuspace ipc call shell ping
```

- `haku_backend.sh --verify` checks that Quickshell is alive in Hikai mode, the Classic UI processes are not running, and Quickshell owns `org.freedesktop.Notifications`.
- If Hikai cannot start cleanly, return to the fallback stack with `~/.local/bin/haku_backend.sh set classic` or use the bundled **`SUPER + ESCAPE`** binding.
- Hikai workspace integration is currently implemented for Hyprland, Niri, and MangoWM. Labwc uses the null workspace backend for now because ext-workspace is unstable with the targeted Quickshell version.
- Runtime Quickshell logs are written under `${XDG_RUNTIME_DIR}/hakuspace/` by the supervisor/backend helpers.

**Classic / Waybar checks**:
- **Waybar clock**: set your timezone and locale manually in the Waybar configuration if the clock is incorrect.
- **Waybar cava module**: install `waybar-cava` if you use the Classic Waybar Cava module.
- Classic uses Waybar/Rofi/SwayNC; these processes are intentionally stopped when Hikai is active.

**Dotfiles / deployment checks**:
- Run `./doctor.sh` for a read-only integrity scan of managed configs and symlinks.
- Use `./link.sh --list` / `./packages.sh --list` to inspect the modules and package groups known to the current repository.
- If an update causes a configuration regression, use `./rollback.sh` and select the appropriate backup instead of deleting managed directories manually.
- Some applications are deeply integrated with HakuSpace scripts. Replacing packages such as `wl-screenrec`, `thunar`, or `ly` may require updating the corresponding controller/configuration.

If you're using **Fedora** and a user `swaync.service` automatically restarts SwayNC, it can conflict with Hikai's native notification ownership. Disable that service if needed:

```bash
systemctl --user disable swaync.service
```

If you encounter an installation or configuration issue, open a GitHub issue or ask in the project [Discord](https://discord.gg/Juuun8sXsN).

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
