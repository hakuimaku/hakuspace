# <h1 style="color:#ff69b4;">🎨 Haku Dotfiles</h1>

[![Hyprland](https://img.shields.io/badge/Hyprland-0.55-orange)](https://github.com/hyprwm/hyprland) [![Arch Linux](https://img.shields.io/badge/Arch-Linux-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org) [![Dotfiles](https://img.shields.io/badge/Dotfiles-HakuSpace-ff69b4)](https://github.com/hakuimaku/hakuspace) [![License: MIT](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT)

- **For now, HakuSpace is using hyprland 0.55 !!**
- 📖 See Wiki: https://github.com/hakuimaku/hakuspace/wiki

<h2 style="color:#1abc9c;">OVERVIEW</h2>

| Screenshot Capture | Description |
|---|-----|
| <img width="1920" height="1080" alt="20260522_105620" src="https://github.com/user-attachments/assets/e4695ad0-e810-4dc3-bdb0-1318ba6c9c02" /> | Overview |
| <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/380c469a-47e9-45a9-818d-4272da67be17" /> | Haku Menu |
| <img width="1920" height="1080" alt="20260522_105644" src="https://github.com/user-attachments/assets/3c86544a-35df-45ff-af02-86f352283a1d" /> | `haku` - Haku Space |
| <img width="1920" height="1080" alt="20260522_105653" src="https://github.com/user-attachments/assets/775e255e-4c69-49f8-92d9-d264f22fb15b" /> | `hakunet` - Haku Space |
| <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/68884fed-c204-4191-b756-f4afa945146d" /> | Nemo - File Manager |


---
<h2 style="color:#1abc9c;">WELCOME TO HAKU SPACE! A minimal and clean dotfile configuration for Arch Linux with Hyprland</h2>

- Include: Waybar, Rofi, Kitty, Zsh, Zen Browser, Networkmanager, Nemo, power-profile-daemon, ...
Use ly for login.
- For more infomation: [Here](https://github.com/hakuimaku/hakuspace/wiki/Important-Note#1-core-services)
- Recommend Monitor eDP-1, 1080p (because in hyprland.lua, Haku Space I use). You can change it manually at monitor in ~/.config/hypr/hyprland.lua.

<h2 style="color:#1abc9c;">📋 Prerequisites</h2>

- **Arch Linux** installed and configured
- **Hyprland** (0.55.x)
- Basic knowledge of shell configuration and file permissions

- ⚠️ **Strongly Recommendation:** Manually copy configurations rather than using the automated installer. Review `pkg.txt` to select which packages to install.
- If it is your first time installing arch, just use install.sh script to quick setup

---

<h2 style="color:#1abc9c;">✨ Features</h2>

- Minimal and clean design
- Custom Hyprland configuration with animations and rules
- Easy-to-use: Rofi menu, Nemo file manager, Waybar status bar, and more
- Color will change based on your env.lua file or your wallpaper (using pywal)
- Fonts will update based on your env.lua file or via the Change Theme option in the Haku Menu
- **Easy to extend and customize to fit your needs**

---

<h2 style="color:#1abc9c;">🚀 Installation</h2>

<h3 style="color:#ff8c00;">Step 1: Clone the Repository</h3>

```bash
cd ~
git clone https://github.com/hakuimaku/hakuspace.git
```

<h3 style="color:#ff8c00;">Step 2: Navigate to Directory</h3>

```bash
cd hakuspace
```

<h3 style="color:#ff8c00;">Step 3: Run Installer</h3>
> ⚠️ **Review the script carefully before running**

```bash
./install.sh
```

<h3 style="color:#ff8c00;">Step 4: Reboot</h3>

```bash
reboot
```

---

<h2 style="color:#1abc9c;">🐛 Troubleshooting</h2>

If configurations don't work:
1. Check Hyprland version compatibility (should be 0.55.x)
2. Verify file permissions with `ls -la ~/.local/bin`
3. Check config file paths are correctly set
4. Review individual config files for syntax errors
5. If module clock on waybar doesn't work. Make sure you have set Timezone, Locale for Arch linux
6. Lively Wallpaper by SUPER SHIFT + Y didn't have thumbnail?
   > Create folder Preview (~/Videos/Wallpapers/Preview) and add image .jpg/.png (same name with video) to appear thumbnail in rofi select menu

# <h2 style="color:#1abc9c;">📦 Contributing</h2>

- This is a personal dotfile configuration. Feel free to fork and adapt it to your needs!
- tiktok: @hakuimaku2372

---

**Happy Ricing! 🎨**
