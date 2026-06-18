# <h1 style="color:#ff69b4;">🎨 Haku Dotfiles</h1>

[![Hyprland](https://img.shields.io/badge/Hyprland-0.55-orange)](https://github.com/hyprwm/hyprland) [![Arch Linux](https://img.shields.io/badge/Arch-Linux-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org) [![Dotfiles](https://img.shields.io/badge/Dotfiles-HakuSpace-ff69b4)](https://github.com/hakuimaku/hakuspace) [![License: MIT](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT)

- **For now, HakuSpace is using hyprland 0.55 !!**
- 📖 See Wiki: https://github.com/hakuimaku/hakuspace/wiki

<h2 style="color:#1abc9c;">OVERVIEW</h2>

| <img width="1920" height="1080" alt="20260616_122304" src="https://github.com/user-attachments/assets/debf37dc-2d41-4bec-9c64-897940990a0e" /> | <img width="1920" height="1080" alt="20260616_122449" src="https://github.com/user-attachments/assets/68673d63-0735-4be8-83a5-0ff68807f498" /> |
|---|---|
| <img width="1920" height="1080" alt="20260616_121854" src="https://github.com/user-attachments/assets/0e71b444-2709-4120-8b3c-8eca03d9ba4c" /> | <img width="1920" height="1080" alt="20260616_122126" src="https://github.com/user-attachments/assets/0743854f-a7d0-4217-a85e-784f75e7ca75" /> |
| <img width="1920" height="1080" alt="20260616_121922" src="https://github.com/user-attachments/assets/05c24625-b900-4798-a7a7-142588bc3f07" /> | <img width="1920" height="1080" alt="20260616_122629" src="https://github.com/user-attachments/assets/12b079ca-4ce6-42dc-83f0-95b34ea5873b" /> |

> Note: Some wallpapers shown in the overview screenshots are not included in the dotfiles


---
<h2 style="color:#1abc9c;">WELCOME TO HAKU SPACE! A minimal and clean dotfile configuration for Arch Linux with Hyprland</h2>

- Include: Waybar, Rofi, Kitty, Zsh, Zen Browser, Networkmanager, Nemo, power-profile-daemon, ...
Use ly for login.
- For more infomation: [Here](https://github.com/hakuimaku/hakuspace/wiki/Important-Note#1-core-services)

<h2 style="color:#1abc9c;">📋 Prerequisites</h2>

- **Arch Linux** installed and configured
- **Hyprland** (0.55.x)
- Basic knowledge of shell configuration and file permissions
- Preview pack will be installed before installing hakuspace in **pkg.txt** if needed
- Package categories are documented in [pkg-notes.md](pkg-notes.md)

---

<h2 style="color:#1abc9c;">✨ Features</h2>

- Minimal and clean design
- Custom Hyprland configuration with animations and rules
- Easy-to-use: Rofi menu, Nemo file manager, Waybar status bar, and more
- Color will change based on your wallpaper
- 2 mode Waybar Left or Top
- **Easy to extend and customize to fit your needs**

---

<h2 style="color:#1abc9c;">🚀 Installation</h2>

Follow these steps to install the Hakuspace desktop environment on your system. It is highly recommended to run this on a fresh Arch Linux installation.

<h3 style="color:#ff8c00;">Step 1: Clone the Repository (Stable Release)</h3>

Clone the official `v1.0.0` stable release

```bash
cd ~
git clone --depth 1 --branch v1.0.0 https://github.com/hakuimaku/hakuspace.git
```

Switch to the cloned directory:

```bash
cd hakuspace
```
<h3 style="color:#ff8c00;">Step 2: Make Script Executable</h3>

Make sure the script is executable and run it to start the automatic package installation and configuration setup:

```bash
chmod +x install.sh
./install.sh
```

<h3 style="color:#ff8c00;">Step 3: Clean Up and Reboot</h3>

Once the installation is complete, you can safely remove the temporary setup directory and reboot your system to log into your new environment:

```bash
cd ~ && rm -rf hakuspace
reboot
```

---

<h2 style="color:#1abc9c;">🐛 Troubleshooting</h2>

If configurations don't work:
1. Check Hyprland version compatibility (should be 0.55.x)
2. Verify file permissions with `ls -la ~/.local/bin`
3. Check config file paths are correctly set
4. Review individual config files for syntax errors
5. **If module clock on waybar doesn't work. Make sure you have set Timezone, Locale for Arch linux (And change in waybar config too)**
6. Lively Wallpaper by SUPER SHIFT + Y didn't have thumbnail?
   > Create folder Preview (~/Videos/Wallpapers/Preview) and add image .jpg/.png (same name with video) to appear thumbnail in rofi select menu

# <h2 style="color:#1abc9c;">📦 Contributing</h2>

- This is a personal dotfile configuration. Feel free to fork and adapt it to your needs!
- tiktok: @hakuimaku2372

---
*Themes, Icons and Wallpapers used in Haku Space:*
- Theme: [BlackAndWhite](https://www.gnome-look.org/p/2010116)
- Theme: [Magnetic-Dark](https://www.gnome-look.org/p/2093088)
- Theme: [Midnight-Gray](https://www.gnome-look.org/p/1273208)
- Icons: [Tela-circle-black](https://www.gnome-look.org/p/1359276)
- Mouse Cursor: [lliurex-cursors](https://www.gnome-look.org/p/999908)
- Wallpapers Artists:
  - [zrxrevolutionz](https://www.deviantart.com/zrxrevolutionz)
  - [かづいせ](https://www.pixiv.net/en/users/1031168)
  - [airfish](https://www.pixiv.net/en/users/67512705)
- Fastfetch logo (Old, I was used it before) - I couldn't find the artist, I found it on [Internet](https://store.line.me/stickershop/product/5198750/en)

# **Happy Ricing! 🎨**
