<div align="center">

# Haku Space
Hyprland / Niri / MangoWM / Labwc dotfiles for Arch / Fedora / NixOS

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

| <img width="1920" height="1080" alt="screenshot_2026-08-29_14-26-24" src="https://github.com/user-attachments/assets/1e0dc63a-22ee-482a-9902-9d458bb67e35" /> | <img width="1920" height="1080" alt="screenshot_2026-08-25_06-52-48" src="https://github.com/user-attachments/assets/c3ca125c-12f5-49d8-afd3-1aa68b64c8fe" /> |
|--|--|
| <img width="1920" height="1080" alt="screenshot_2026-08-25_07-03-04" src="https://github.com/user-attachments/assets/8c599b1a-6947-4ce3-a511-37645a0eda5b" /> | <img width="1920" height="1080" alt="screenshot_2026-08-25_07-04-51" src="https://github.com/user-attachments/assets/dd0abd39-a7e7-41dd-aaff-4f8422894622" /> |

## Welcome to Haku Space

<div align="center">

[Installation](#installation-guide) ─ [Update](#update-haku-space) ─ [Packages](#programs) ─ [Keybinding](#keybinding) ─ [Troubleshooting](#troubleshooting)

*Need help or want to chat? Join our Discord server or follow us on TikTok for showcase videos!*

[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Juuun8sXsN) [![TikTok](https://img.shields.io/badge/TikTok-000000?style=for-the-badge&logo=tiktok&logoColor=white)](https://www.tiktok.com/@hakuimaku2372)

</div>

- Multi-WM Support: Hyprland, Niri, MangoWM, Labwc with seamless switching between window managers.
- Multi-Distro Support: Have been tested on Arch, Fedora, Nixos.
- DE-like Experience: Modular UI powered by Rofi, Waybar, SwayNC, and custom scripts.
- Extensible: Highly customizable and easy to adapt to your own workflow.
- See Guide for: [Arch Linux](#installation-guide) | [NixOS](#nixos-configuration) | [Fedora](docs/Fedora_Guide.md)

---

## Key Features

* **Control Center**: `~/hakuspace-control` this directory stores your custom configs so you don't have to touch the main ones, giving you much more freedom to customize.
* **Accent Colors**: Synced across **Waybar**, **Rofi**, **Kitty**, **Swaync**,... giving your setup a **Super Clean** and **Cohesive Vibe**!
* **Smart Accent Color:** Automatically generates the accent color based on your current wallpaper.
* **Flexible Waybar Layouts:** Support 7 styles: `top`, `left`, `coredge`, `minimal`, `full`, `neon`, `island`.
* **Unique Cava Underbar:** Dynamic audio visualizer waves seamlessly layered directly beneath the Waybar.
* **Wallpaper Automation:** Wallpapers change automatically every 5 minutes.
* **Dockbar:** Built-in, Another Waybar with `wlr/taskbar` module, can pin applications, looking like a Taskbar or Dock.
* **Desktop Icons** *(experimental)*: Built-in, Items in folder `~/Desktop` will be shown on Desktop (still bugs btw).

> [!note]
> My dotfiles are powered by scripts; if you're not using them, there's no impact on your performance!

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
> For Fedora users, you should follow the [Fedora Guide](docs/Fedora_Guide.md)

### 0. Prerequisites:

- You have completed the installation of Arch, Fedora, and NixOS (or derivative distros)
- You have installed and configured essential utilities such as Wi-Fi, Bluetooth, Audio,... and necessary hardware drivers.
- You are familiar with configuring the system via **code**, as my dotfiles do NOT have a central graphical settings GUI.

### 1. Clone the Dotfiles
- Stable Release (Recommended):
```bash
cd ~
git clone --depth 1 --branch v2.3.0 https://github.com/hakuimaku/hakuspace.git ~/hakuspace

```
- If you prefer to experience the **lastest changes**:
```bash
cd ~
git clone https://github.com/hakuimaku/hakuspace.git ~/hakuspace

```

### 2. Run the Installation Script

```bash
cd hakuspace
chmod +x install.sh
./install.sh
```

### 3. Complete the Installation
After running the installation script, restart your computer and log in to either **Hyprland**, **Niri**, **Mango** or **Labwc** to experience the new setup.

### 4. After Installation
1) Change the GTK theme:
- Go to `GTK Settings` in Rofi App Menu (SUPER + R).
- Change the theme, icons, and mouse cursor for a better aesthetic.

2) **Install additional packages**:

`waybar-cava` is a plugin for Waybar that provides a visualizer for audio output. My waybar top needs this to work properly (cava module).

```bash
yay -S waybar-cava
```

3) Allow Local Root User to Access X/Xwayland Display
```bash
xhost +si:localuser:root
```
Grants the local root user permission to connect to and launch graphical (GUI) applications (like `GParted`) within the current user's active X server or Xwayland session.


### Update Haku Space
Simply run `update.sh` script in hakuspace folder.
``` bash
cd ~/hakuspace
chmod +x update.sh
./update.sh
```

### Rollback Haku Space
Restore files from a backup created by `install.sh` or `update.sh`.
``` bash
cd ~/hakuspace
chmod +x rollback.sh
./rollback.sh
```
If multiple backups are available, the newest one is selected by pressing Enter.

### Uninstall Haku Space
> (WM: The Window Manager you are currently using, e.g., hyprland, niri, mango).

- Run `rollback.sh` to restore your previous configuration.
- Remove all scripts located in `~/.local/bin`.
- Delete the auto-generated files in `~/.local/state/haku_theme`.
- If necessary, you can also remove the icons and themes inside `~/.icons` and `~/.themes`.
- Review `pkg-core.txt`, `pkg-service.txt`, `pkg-optional.txt` (in hakuspace/common) and `pkg-WM.txt` (in hakuspace/WM) to uninstall any unnecessary packages.

---

## NixOS Configuration

See the main configuration file at [hakuspace-config.nix](nix/hakuspace-config.nix)

> [!note]
> My dotfiles do not use `home-manager` feature (because my dots are not only for symlink-based dotfiles managers).
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
> Please install **hyprilde** unstable nixpkgs for v0.1.8 (to use my [idle_inhibit.sh](src/home/.local/bin/idle_inhibit.sh) script).

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

See more in `~/hakuspace-control/hyprland-custom.lua` for guide.

---

## Keybinding

- See more keybinding in: [Hyprland](src/home/.config/hypr/config/keybinding.lua) | [Niri](src/home/.config/niri/keybinds.kdl) | [MangoWM](src/home/.config/mango/bind.conf) | [Labwc](src/home/.config/labwc/rc.xml#L263)
- Hotkeys:

| Bind | Function |
|------|----------|
| SUPER + Q | Open Kitty Terminal |
| SUPER + C | Kill Focus Window |
| SUPER + TAB | Open Menu |
| SUPER + R | App Menu |
| SUPER + W | Toggle Dockbar |
| SUPER + P | Screenshot |
| SUPER + Z | Toggle Floating |
| SUPER + V | Open Clipboard History |
| SUPER + A/S | Focus Left/Right Window |
| SUPER + Y | Wallpaper Select |
| SUPER + SHIFT + Y | Lively Wallpaper Select |
| SUPER + SHIFT + W | Cycle Waybar Mode |
| SUPER + X | Cycle Hyprland Layout (Hyprland Only) |
| SUPER + ` | Open Special Workspace - For VS Code (Hyprland Only) |
| SUPER + ` | Open Niri Overview |

- Labwc:

| Bind | Function |
|------|----------|
| SUPER + Space | Open Root Menu |
| SUPER + ` | Open Client Menu |
| ALT + ` | Open Combined Client Menu |
| SUPER + A | Maximize |
| SUPER + S | Iconify |
| SUPER + D | Show Desktop |
| SUPER + Z | Shrink Size Window (-10%) |
| SUPER + X | Resize By Mouse |

---

## Assets Located

- Custom config (your personal changes): `~/hakuspace-control`
- State file & Haku Theme for waybar, rofi,... (includes accent_color, font, font size): `~/.local/state/haku_theme`
- Icons: `~/.icons`
- Themes: `~/.themes`
- All hakuspace scripts: `~/.local/bin`
- Fastfetch logo: `~/.config/fastfetch`
- Wallpapers: `~/Pictures/Wallpapers`
- Lively wallpapers: `~/Videos/Wallpapers`

---

# Troubleshooting

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

# Contributing

- This is a personal dotfiles configuration. Feel free to fork and adapt it to your needs!
- See Documentation for more knowledge of my setup: [Architecture](docs/architecture.md)
- Tiktok / See more showcase: [@hakuimaku2372](https://www.tiktok.com/@hakuimaku2372)
- Discord: [haku-shell](https://discord.gg/Juuun8sXsN)

---

# Credits

See **hakuspace-archive** for the assets used in this project: [hakuspace-archive](https://github.com/hakuimaku/hakuspace-archive)
