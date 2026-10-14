<div align="center">

# Haku Space
Hyprland / Niri / MangoWM / Labwc dotfiles for Arch / Fedora / NixOS

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

- Multi-WM Support: Hyprland, Niri, MangoWM, Labwc with seamless switching between window managers.
- Multi-Distro Support: Have been tested on Arch, Fedora, Nixos.
- DE-like Experience: Modular UI powered by Rofi, Waybar, SwayNC, and custom scripts.
- Extensible: Highly customizable and easy to adapt to your own workflow.
- See Guide for: [Arch Linux](#installation-guide) | [NixOS](#nixos-configuration) | [Fedora](docs/fedora_guide.md)

---

## Key Features

* **Control Center**: `~/hakucfg` this directory stores your custom configs so you don't have to touch the main ones, giving you much more freedom to customize.
* **Accent Colors**: Synced across **Waybar**, **Rofi**, **Kitty**, **Swaync**,... giving your setup a **Super Clean** and **Cohesive Vibe**!
* **Smart Accent Color**: Automatically generates the accent color based on your current wallpaper.
* **Flexible Waybar Layouts**: Support 7 styles: `top`, `left`, `coredge`, `minimal`, `neon`, `island`, `legacy`.
* **Wallpaper Automation**: Wallpapers change automatically every 5 minutes.
* **Taskbar**: Another Waybar with `wlr/taskbar` module, can pin applications, looking like a Taskbar or Dock.
* **Haku Space**, Include aesthetic features: 
  * **Unique Cava Underbar**: *Built-in*, Dynamic audio visualizer waves seamlessly layered directly beneath the Waybar.
  * **Desktop Icons**: *Built-in*, Items in folder `~/Desktop` will be shown on Desktop.
  * **Rounded Screen Corners**: *Built-in*, Rounded corners for your screen, with a smooth and elegant look.
  * **Edge Trigger**: *Built-in*, Hover your mouse at the screen edges to quickly launch menus or applications.

> [!note]
> My dotfiles are powered by scripts; if you're not using them, there's no impact on your performance!

> [!tip]
> See performance breakdown in [Performance](#performance) section.

---

## Programs

<div align="center">
  
See more information in: [pkg-core](src/packages/pkg-core.txt) | [pkg-service](src/packages/pkg-service.txt) | [pkg-optional](src/packages/pkg-optional.txt)

Specific packages for each WM: [pkg-hyprland](src/packages/pkg-hyprland.txt) | [pkg-niri](src/packages/pkg-niri.txt) | [pkg-mango](src/packages/pkg-mango.txt) | [pkg-labwc](src/packages/pkg-labwc.txt)

</div>

| Component | Program |
|---|---|
| Terminal | [Kitty](https://github.com/kovidgoyal/kitty) |
| App Launcher | [Rofi](https://github.com/davatorium/rofi) |
| Status Bar | [Waybar](https://github.com/alexays/waybar) |
| Shell | [Fish](https://fishshell.com/) + [Starship](https://starship.rs/) |
| File Manager | [Thunar](https://docs.xfce.org/xfce/thunar/start) |
| Notifications & Control Center | [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) |
| Wallpaper | [Awww](https://codeberg.org/LGFae/awww) |
| Idle Management | [Hypridle](https://github.com/hyprwm/hypridle) |
| Screen Lock | [Hyprlock](https://github.com/hyprwm/hyprlock) |
| Editor | [VS Code](https://code.visualstudio.com/) |
| Browser | [Firefox](https://www.firefox.com/en-US/) |
| Screen Recording | [Wl-screenrec](https://github.com/russelltg/wl-screenrec) |
| Display Manager (Default) | [Ly](https://codeberg.org/fairyglade/ly#systemd) |

> XDG Desktop Portal: GTK by default, but each WM will use its specific, recommended portal according to its official wiki (hyprland uses hyprland, niri uses gnome, and mangowm/labwc uses wlr).

> Accent Color based on wallpaper using [python-colorthief](https://github.com/fengsp/color-thief-py)

---

## Installation Guide

> [!tip]
> For Fedora users, you should follow the [Fedora Guide](docs/fedora_guide.md). The package module currently uses `yay`, so package installation on non-Arch distributions must follow the distro-specific setup first.

### Prerequisites

- You have completed the installation of Arch, Fedora, NixOS, or a derivative distribution.
- You have installed and configured essential utilities such as Wi-Fi, Bluetooth, Audio, and the necessary hardware drivers.
- You are familiar with configuring the system via **code**, as Haku Space does **not** provide a central graphical settings GUI.

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
- **Deployment Mode**: Files are automatically managed via **Deep Symlink** (default, allowing instant updates when source files change) or **Copy** mode during installation.
- **Customization**: All your personal tweaks should be done inside the `~/hakucfg` directory, keeping the core system clean and untouched.

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

Haku Space is designed to balance aesthetic features and resource efficiency. Below is the RAM usage breakdown based on a system with **16GB RAM**:

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

---

## Troubleshooting

**Waybar issues**:
- **Waybar clock**: You should set your timezone and locale manually in waybar configuration to ensure the clock displays correctly.
- **Waybar cava module**: If you encounter issues with the Cava module in Waybar, ensure that you have installed `waybar-cava` and that it is properly configured in your Waybar config file.
- Waybar use `ext/workspaces` for **Multi-WMs** setup.

**My dotfiles issues**:
- Some features might still be missing since I only tested this setup for **my personal use**. If you need more than what's provided, you'll need to install and configure those parts manually.
- If you don't want to use certain apps (like `wl-screenrec`, `thunar`, `ly` etc.), you can easily remove and replace them with alternatives. However, some apps are deeply integrated into my scripts or configs, so removing them may break functionality or cause those scripts/configs to stop working.
- If you find that **the script isn't working**, run it directly in the terminal to see what the error is.
- If you encounter any **issues** during installation or configuration, just ask me in some video on my [Tiktok](https://www.tiktok.com/@hakuimaku2372), open an issue on GitHub or Join my [Discord](https://discord.gg/Juuun8sXsN) to get more help!. I will do my best to help you out.

If you're using **Fedora**:
- Swaync service may automatically start on Fedora. Which can **cause issues when startup**. To fix this, you can disable the Swaync service by running the following command:
```bash
systemctl --user disable swaync.service
```

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
