# <h1 style="color:#ff69b4;">🎨 Haku Dotfiles</h1>

[![Hyprland](https://img.shields.io/badge/Hyprland-0.55-orange)](https://github.com/hakuimaku/hakuspace) [![Arch Linux](https://img.shields.io/badge/Arch-Linux-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org) [![Dotfiles](https://img.shields.io/badge/Dotfiles-HakuSpace-ff69b4)](https://github.com/hakuimaku/hakuspace) [![License: MIT](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT)

- **For now, HakuSpace is using hyprland 0.55 !!**
- 📖 See Wiki:

<h2 style="color:#1abc9c;">OVERVIEW</h2>

| Screenshot Capture | Description |
|---|-----|
| <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/4640efd9-ec98-46bf-a5d1-19381020a1f3" /> | Overview |
| <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/54aa6a29-f6db-4efe-b52e-d75bca75ebef" /> | Haku Menu |
| <img width="1920" height="1080" alt="20260511_113021" src="https://github.com/user-attachments/assets/fb412e1d-44f3-4af0-8139-c0f6638bcb2a" /> | `haku` - Haku Space |
| <img width="1920" height="1080" alt="20260511_113038" src="https://github.com/user-attachments/assets/3009759a-e57a-4b1f-bdd3-5f1014686541" /> | `hakunet` - Haku Space

---
<h2 style="color:#1abc9c;">WELCOME TO HAKU SPACE! A minimal and clean dotfile configuration for Arch Linux with Hyprland</h2>

Include: Waybar, Rofi, Kitty, Zsh, Zen Browser, Networkmanager, Nemo, power-profile-daemon, ...
Use ly for login.
Recommend Monitor eDP-1, 1080p (because in hyprland.lua, Haku Space I use). You can change it manually at monitor in ~/.config/hypr/hyprland.lua.

<h2 style="color:#1abc9c;">📋 Prerequisites</h2>

- **Arch Linux** installed and configured
- **Hyprland** (0.55.x)
- Basic knowledge of shell configuration and file permissions

- ⚠️ **Strongly Recommendation:** Manually copy configurations rather than using the automated installer. Review `pkg.txt` to select which packages to install.
- If it is your first time installing arch, just use install.sh script to quick setup


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
