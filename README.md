| <img width="1920" height="1080" alt="screenshot_2026-06-23_15-38-16" src="https://github.com/user-attachments/assets/8393b504-9932-4325-80c2-3b8307f1ab57" /> | <img width="1920" height="1080" alt="20260618_074132" src="https://github.com/user-attachments/assets/5cb478b4-51b4-4db2-af11-5fb0b07fec58" /> |
|---|---|
| <img width="1920" height="1080" alt="screenshot_2026-06-25_07-47-03" src="https://github.com/user-attachments/assets/62b0470f-6a5f-4ad3-abe5-391e7a5bed0d" /> | <img width="1920" height="1080" alt="screenshot_2026-06-25_07-55-46" src="https://github.com/user-attachments/assets/6cea11a9-af14-4ac5-8729-c161be4578e0" /> |



# 🌆 HakuSpace - Dotfiles for Hyprland and Niri

[![Hyprland](https://img.shields.io/badge/Hyprland-orange)](https://github.com/hyprwm/hyprland) [![Niri](https://img.shields.io/badge/Niri-purple)](https://github.com/niri-wm/niri) [![Arch Linux](https://img.shields.io/badge/Arch-Linux-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org) [![Dotfiles](https://img.shields.io/badge/Dotfiles-HakuSpace-ff69b4)](https://github.com/hakuimaku/hakuspace) [![License: MIT](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT)

**Welcome to Haku Space! Simple — Clean — Beautiful**

- **HakuSpace** is an optimized dotfiles collection supporting both **Hyprland** and **Niri** on Arch Linux.
- **Easy to extend and customize to fit your needs!**

---

## ✨ Key Features

* **Smart Accent Colors:** Automatically generates the accent color palette based on your current wallpaper.
* **Flexible Waybar Layouts:** Supports two standard layouts: **Left** and **Top**. *(Note: Niri currently only supports the Top layout).*
* **Unique Cava Underbar:** Dynamic audio visualizer waves seamlessly layered directly beneath the Waybar.
* **Wallpaper Automation** Wallpapers change automatically every 5 minutes (customizable in the `random_wallpaper.sh` script).
* **Unified Aesthetic:** Handcrafted and polished configurations for Waybar, Rofi, Swaync and Thunar theme *100% beautiful for real. :)*

---

## 🛠️ Installation Guide

> **Prerequisites:** You need a pre-installed Arch Linux or an Arch-based Linux Distro (A fresh install is highly recommended). If you already have an existing WM or DE configuration, it is best to only reference the configs in HakuSpace rather than running the installation script directly over your system.

### 1. Clone the Stable Release (Recommended)
Run the following commands to clone the stable release version `v2.0.1`:
```bash
cd ~
git clone --depth 1 --branch v2.0.1 https://github.com/hakuimaku/hakuspace.git

```

If you prefer to experience the latest changes (Latest Git), you can clone the default branch instead:
```bash
cd ~
git clone https://github.com/hakuimaku/hakuspace.git

```

Swith to the `hakuspace` directory:
```bash
cd hakuspace
```

### 2. Navigate to the appropriate directory based on your window manager choice:
If you are using **Hyprland**, execute the following commands:
```bash
cd hyprland
```
If you are using **Niri**, execute the following commands:
```bash
cd niri
```

### 3. Run the Installation Script

```bash
./install.sh
```

### 4. Complete the Installation
After running the installation script, restart your computer and log in to either **Hyprland** or **Niri** to experience the new setup.

### 5. Change GTK theme
- Go to `GTK Settings` in Rofi App Menu.
- Change the theme, icons, and mouse cursor for a better aesthetic.

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
Read Wiki for more info: https://wiki.hypr.land/Plugins/Using-Plugins/

1) Uncomment the plugin loading line in `hyprland.lua` to load the plugin configuration on startup
2) Make sure to set the correct permissions for the plugin binary (if needed) using `hl.permission` in `hyprland.lua`
3) Uncomment `hl.exec_cmd("hyprpm reload -n")` in `autostart.lua` to automatically reload Hyprland when plugins are enabled/disabled
4) Customize the plugin configuration in `plugin.lua` as needed

## 📁 Assets located
- Icons: `~/.icons`
- Themes: `~/.themes`
- User scripts: `~/.local/bin`
- Fastfetch logo: `~/.config/fastfetch/`
- Wallpapers: `~/Pictures/Wallpapers`
- Lively wallpapers: `~/Videos/Wallpapers`
- Lively wallpaper thumbnail: in folder Preview `~/Videos/Wallpapers/Preview` and add image .jpg/.png (same name with video) to appear thumbnail in rofi select menu if you want to use lively wallpaper

## 🎶 Just chill
> Currently, `haku.sh` is only available for Hyprland.
- Open your terminal on Workspace 1 and type `haku.sh` for a little surprise. To close them, just append the 'clear' argument (e.g., `haku.sh clear`).
- Cava Underbar: To toggle a Cava visualizer right below Waybar, select Cava Underbar from the Haku Menu. It automatically hides during fullscreen and reappears when you exit. To disable it completely, just toggle it again in the Haku Menu.


# 🐞 Troubleshooting
- Currently, my custom `gtk.css` is only compatible with **GTK 3** and only supports **Dark Mode**. If you are using Light Mode, you may encounter some issues with the appearance of GTK applications **(Thunar)**.
- **Waybar clock**: You should set your timezone and locale manually in waybar configuration to ensure the clock displays correctly.
- If you encounter any issues during installation or configuration, just ask me in some video on my [Tiktok](https://www.tiktok.com/@hakuimaku2372) or open an issue on GitHub. I will do my best to help you out.


# 📦 Contributing

- This is a personal dotfiles configuration. Feel free to fork and adapt it to your needs!
- tiktok: [@hakuimaku2372](https://www.tiktok.com/@hakuimaku2372)

---
*Themes, Icons and Wallpapers used in Haku Space:*
- Theme: [Midnight-Gray](https://www.gnome-look.org/p/1273208)
- Icons: [Tela-circle-black](https://www.gnome-look.org/p/1359276)
- Mouse Cursor: [Bibata-Modern-Ice](https://www.gnome-look.org/p/1197198)
- Wallpapers Artists:
  - [zrxrevolutionz](https://www.deviantart.com/zrxrevolutionz)
  - [かづいせ](https://www.pixiv.net/en/users/1031168)
  - [airfish 空气鱼](https://www.pixiv.net/en/users/67512705)
  - [Android/アンドロイド](https://www.pixiv.net/en/users/67750556)
  - [Roby0174](https://www.deviantart.com/roby0174)


## 🎨 Happy Ricing!
