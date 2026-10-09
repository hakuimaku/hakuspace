<div align="center">

# Haku Space
Arch Linux dotfiles for Hyprland / Niri / MangoWM

</div>

<p align="center">
    <a href="https://github.com/hyprwm/Hyprland"><img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-%231f1f1f?style=for-the-badge&logo=wayland&logoColor=%231f1f1f&labelColor=%2368818f&color=%231f1f1f"></a>&nbsp;
    <a href="https://github.com/YaLTeR/niri"><img alt="Niri" src="https://img.shields.io/badge/Niri-%231f1f1f?style=for-the-badge&logo=wayland&logoColor=%231f1f1f&labelColor=%2368818f&color=%231f1f1f"></a>&nbsp;
    <a href="https://github.com/mangowm/mango"><img alt="MangoWM" src="https://img.shields.io/badge/MangoWM-%231f1f1f?style=for-the-badge&logo=wayland&logoColor=%231f1f1f&labelColor=%2368818f&color=%231f1f1f"></a>&nbsp;
    <a href="https://archlinux.org/"><img alt="Arch Linux" src="https://img.shields.io/badge/Arch%20Linux-%231f1f1f?style=for-the-badge&logo=archlinux&logoColor=%231f1f1f&labelColor=%2368818f&color=%231f1f1f"></a>&nbsp;
    <a href="https://github.com/hakuimaku/hakuspace/commits/main"><img alt="Last Commit" src="https://img.shields.io/github/last-commit/hakuimaku/hakuspace?style=for-the-badge&label=Last%20Commit&labelColor=%2368818f&color=%231f1f1f&logo=git&logoColor=%231f1f1f"></a>&nbsp;
    <a href="https://github.com/hakuimaku/hakuspace/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/hakuimaku/hakuspace?style=for-the-badge&label=Stars&labelColor=%2368818f&color=%231f1f1f&logo=github&logoColor=%231f1f1f"></a>&nbsp;
    <a href="https://github.com/hakuimaku/hakuspace"><img alt="Repo Size" src="https://img.shields.io/github/repo-size/hakuimaku/hakuspace?style=for-the-badge&label=Repo%20Size&labelColor=%2368818f&color=%231f1f1f&logo=github&logoColor=%231f1f1f">
</p>

| <img width="1920" height="1080" alt="screenshot_2026-07-16_10-54-36" src="https://github.com/user-attachments/assets/50b76a8d-c18b-481e-9c00-8f0c4058a3b3" /> | <img width="1920" height="1080" alt="screenshot_2026-07-16_10-55-31" src="https://github.com/user-attachments/assets/5ff87ffb-89bd-458e-9b0d-8ed959aa4e26" /> |
|--|--|
| <img width="1920" height="1080" alt="screenshot_2026-07-16_10-57-36" src="https://github.com/user-attachments/assets/02050014-7041-4a92-aa94-cef9a00c0592" /> | <img width="1920" height="1080" alt="screenshot_2026-07-08_20-00-14" src="https://github.com/user-attachments/assets/f3e86070-14a3-4abd-8b99-c3c68ffb71dc" /> |

## <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Welcome+to+Haku+Space" alt="Typing SVG" />

- Installation: [here](https://github.com/hakuimaku/hakuspace#-3)
- Update: [here](https://github.com/hakuimaku/hakuspace#-update-haku-space-to-lastest-version)
- Packages: [here](https://github.com/hakuimaku/hakuspace#-2)
- Keybinding: [here](https://github.com/hakuimaku/hakuspace#-5)

Overview:
- **HakuSpace** is a dotfiles project for **Arch Linux**, supporting **Hyprland**, **Niri**, and **MangoWM**.  
- The main user interaction layer is built around **Rofi**, **Waybar**, and **SwayNC**, while most core behavior is powered by custom scripts in `hakuspace/common/local/bin`.  
- It has grown into a DE-like experience, though it is still actively evolving.  
- Designed to be easy to extend and customize for your own workflow.

---

## <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Key+Features" alt="Typing SVG" />

* **Smart Accent Colors:** Automatically generates the accent color palette based on your current wallpaper.
* **Flexible Waybar Layouts:** Supports two standard layouts: **Left** and **Top**.
* **Unique Cava Underbar:** Dynamic audio visualizer waves seamlessly layered directly beneath the Waybar.
* **Wallpaper Automation:** Wallpapers change automatically every 5 minutes (customizable in the `random_wallpaper.sh` script).
* **Unified Aesthetic:** Handcrafted and polished configurations for Waybar, Rofi, Swaync and Thunar theme *100% beautiful for real. :)*

---

## <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Programs" alt="Typing SVG" />

<div align="center">
  
See more information in: [pkg-core](https://github.com/hakuimaku/hakuspace/blob/main/common/pkg-core.txt) | [pkg-service](https://github.com/hakuimaku/hakuspace/blob/main/common/pkg-service.txt) | [pkg-optional](https://github.com/hakuimaku/hakuspace/blob/main/common/pkg-optional.txt)

</div>

| Component | Program |
|---|---|
| Terminal | [Kitty](https://github.com/kovidgoyal/kitty) |
| App Launcher | [Rofi](https://github.com/davatorium/rofi) |
| Status Bar | [Waybar](https://github.com/alexays/waybar) |
| Shell | [Zsh](https://ohmyz.sh/) |
| File Manager | [Thunar](https://docs.xfce.org/xfce/thunar/start) |
| Notifications & Control Center | [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) |
| Wallpaper | [Awww](https://codeberg.org/LGFae/awww) |
| Idle Management | [Hypridle](https://github.com/hyprwm/hypridle) |
| Screen Lock | [Hyprlock](https://github.com/hyprwm/hyprlock) |
| Login Menu | [Ly](https://github.com/fairyglade/ly) |
| Editor | [VS Code](https://code.visualstudio.com/) |
| Browser | [Zen](https://zen-browser.app/) |
| Screen Recording | [Wl-screenrec](https://github.com/russelltg/wl-screenrec) |
| Display Manager | [Ly](https://codeberg.org/fairyglade/ly#systemd) |

> XDG Desktop Portal: GTK by default, but each WM will use its specific, recommended portal according to its official wiki (hyprland uses hyprland, niri uses gnome, and mangowm uses wlr).

> Accent Color based on wallpaper using [python-colorthief](https://github.com/fengsp/color-thief-py)

---

## <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Installation+Guide" alt="Typing SVG" />

> [!Important]
> **Prerequisites:** You need a pre-installed Arch Linux or an Arch-based Linux Distro (A fresh install is highly recommended). If you already have an existing WM or DE configuration, it is best to only reference the configs in HakuSpace rather than running the installation script directly over your system.

### 1. Clone the Dotfiles
If you prefer to experience the **lastest changes** (Lastest Git), you can clone the main branch:
```bash
cd ~
git clone https://github.com/hakuimaku/hakuspace.git

```

If you prefer the version I've tested, clone the **stable** release version `v2.1.5` (lastest):
```bash
cd ~
git clone --depth 1 --branch v2.1.5 https://github.com/hakuimaku/hakuspace.git

```

Switch to the `hakuspace` directory:
```bash
cd hakuspace
```

### 2. Run the Installation Script

```bash
chmod +x install.sh
./install.sh
```

### 3. Complete the Installation
After running the installation script, restart your computer and log in to either **Hyprland**, **Niri** or **Mango** to experience the new setup.

---

### 4. After Installation
1) Change the GTK theme:
- Go to `GTK Settings` in Rofi App Menu.
- Change the theme, icons, and mouse cursor for a better aesthetic.

2) **Install additional packages**:

| waybar-git | waybar-cava |
|------------|-------------|
| `waybar-git` is a lastest git version of Waybar, which is supporting `mango/workspaces` module if you're using MangoWM. And fix `hyprland/workspaces` switching if you're using Hyprland. |  `waybar-cava` is a plugin for Waybar that provides a visualizer for audio output. My waybar top needs this to work properly (cava module). |

3) Allow Local Root User to Access X/Xwayland Display
```bash
xhost +si:localuser:root
```
Grants the local root user permission to connect to and launch graphical (GUI) applications (like `GParted`) within the current user's active X server or Xwayland session.


### 🔽 Update Haku Space to lastest version
1. Get the lastest version
- Git pull for the lastest git.
``` bash
cd ~/hakuspace
git pull origin main
```

- Git fetch for the lastest stable release.
``` bash
cd ~/hakuspace
git fetch --tags
LATEST_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))
git checkout $LATEST_TAG
```

2. Update
- Run `update.sh` script in hakuspace folder.
``` bash
cd ~/hakuspace
chmod +x update.sh
./update.sh
```

### 🗑 Uninstall Haku Space
> (WM: The Window Manager you are currently using, e.g., hyprland, niri, mango).

My dotfiles are very clean. You just need to check the config folders that were copied from common and specific WM in `~/hakuspace`, then delete them from `~/.config` (During installation, the `install.sh` script automatically created a **backup** of your existing configuration files so you can backup your old config).
- Remove all scripts located in `~/.local/bin`.
- Delete the auto-generated files in `~/.local/state/haku_theme`.
- If necessary, you can also remove the icons and themes inside `~/.icons` and `~/.themes`.
- Review `pkg-core.txt`, `pkg-service.txt`, `pkg-optional.txt` (in hakuspace/common) and `pkg-WM.txt` (in hakuspace/WM) to uninstall any unnecessary packages.
- Finally, you can completely delete the `~/hakuspace` directory.

---

## <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Plugin+Configuration+(Hyprland+Only)" alt="Typing SVG" />

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

1) Uncomment the plugin loading line in `hyprland.lua` to load the plugin configuration on startup
2) Make sure to set the correct permissions for the plugin binary (if needed) using `hl.permission` in `hyprland.lua`
3) Uncomment `hl.exec_cmd("hyprpm reload -n")` in `autostart.lua` to automatically reload Hyprland when plugins are enabled/disabled
4) Customize the plugin configuration in `plugin.lua` as needed

---

## <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Keybinding" alt="Typing SVG" />

- See more keybinding in: [Hyprland](https://github.com/hakuimaku/hakuspace/blob/main/hyprland/config/hypr/config/keybinding.lua) | [Niri](https://github.com/hakuimaku/hakuspace/blob/main/niri/config/niri/keybinds.kdl) | [MangoWM](https://github.com/hakuimaku/hakuspace/blob/main/mango/config/mango/bind.conf)
- Hotkeys:

| Bind | Function |
|------|----------|
| SUPER + Q | Open Kitty Terminal |
| SUPER + C | Kill Focus Window |
| SUPER + TAB | Open Menu |
| SUPER + R | App Menu |
| SUPER + P | Screenshot |
| SUPER + A/S | Focus Left/Right Window |
| SUPER + Y | Wallpaper Select |
| SUPPER + SHIFT + Y | Lively Wallpaper Select |

---

## <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Assets+located" alt="Typing SVG" />

- Icons: `~/.icons`
- Themes: `~/.themes`
- All hakuspace scripts: `~/.local/bin`
- Fastfetch logo: `~/.config/fastfetch/`
- Wallpapers: `~/Pictures/Wallpapers`
- Lively wallpapers: `~/Videos/Wallpapers`
- Lively wallpaper thumbnail: in folder Preview `~/Videos/Wallpapers/Preview` and add image .jpg/.png (same name with video) to make the thumbnail appear in rofi select menu if you want to use lively wallpaper
- Haku Theme for waybar, rofi,... (includes accent_color, font, font size): `~/.local/state/haku_theme`
- State files for  waybar current mode: `~/.local/state/haku_theme`

---

## <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Just+chill" alt="Typing SVG" />

- Open your terminal on Workspace 1 and type `haku` for a little surprise. To close them, just append the '--clear' argument (e.g., `haku --clear`).
- Cava Underbar: To toggle a Cava visualizer right below Waybar, select Cava Underbar from the Haku Menu. It automatically hides during fullscreen and reappears when you exit. To disable it completely, just toggle it again in the Haku Menu.

---

# <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Troubleshooting" alt="Typing SVG" />

Waybar bugs:
- **Waybar clock**: You should set your timezone and locale manually in waybar configuration to ensure the clock displays correctly.
- **Waybar cava module**: If you encounter issues with the Cava module in Waybar, ensure that you have installed `waybar-cava` and that it is properly configured in your Waybar config file.
- If clicking on **workspaces in Waybar** on Hyprland doesn't switch them, please install `waybar-git`. This bug has already been fixed by the author in the latest upstream version.
- The **MangoWM workspaces** module for waybar is still under active development. if you want to use it, you'll need to install `waybar-git` (though please note it still has a few bugs).

My dotfiles bugs:
- Currently, my custom `gtk.css` is only compatible with **GTK 3** and only supports **Dark Mode**. If you are using Light Mode, you may encounter some issues with the appearance of GTK applications **(Thunar)**. If you don't want to use my thunar theme, remove `gtk.css` in `~/.config/gtk-3.0/`.
- **Cava Underbar in Niri** does not support the no-focus rule. As a result, you might accidentally move it from its original position or close it by mistake.
- Some features might still be missing since I only tested this setup for **my personal use**. If you need more than what's provided, you'll need to install and configure those parts manually.
- If you don't want to use certain apps (like `wl-screenrec`, `thunar`, `ly` etc.), you can easily remove and replace them with alternatives. However, some apps are deeply integrated into my scripts or configs, so removing them may break functionality or cause those scripts/configs to stop working.
- If you find that **the script isn't working**, run it directly in the terminal to see what the error is.
- If you encounter any issues during installation or configuration, just ask me in some video on my [Tiktok](https://www.tiktok.com/@hakuimaku2372) or open an issue on GitHub. I will do my best to help you out.

---

# <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Contributing" alt="Typing SVG" />

- This is a personal dotfiles configuration. Feel free to fork and adapt it to your needs!
- tiktok / See more showcase: [@hakuimaku2372](https://www.tiktok.com/@hakuimaku2372)

---

## <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=32&pause=4000&color=68818F&center=false&vCenter=false&repeat=true&width=900&lines=Credits" alt="Typing SVG" />

See **hakuspace-archive** for the assets used in this project: [hakuspace-archive](https://github.com/hakuimaku/hakuspace-archive)

