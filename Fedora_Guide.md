# Fedora - Haku Space Installation Guide

> [!important]
> Currently, this guide only helps you with install **Niri** WM. If you want to install Hyprland/Mango, you may want to install packages from: [Hyprland](https://github.com/hakuimaku/hakuspace/blob/main/hyprland/pkg-hyprland.txt) | [Mango](https://github.com/hakuimaku/hakuspace/blob/main/mango/pkg-mango.txt)

## Prerequisites
- Who wants to use Niri on Fedora :)
- A computer with Fedora installed.
- This installation guide assumes you have basic knowledge of using the terminal and installing software on Fedora.
- I'm using Fedora Workstation 44, this guide I written for this version.

---

# Installation Steps

## 1. **Update your system**:
Open a terminal and run the following command to ensure your system is up to date:

```bash
sudo dnf update -y
```

---

## 2. **Install Packages**: 

### A. Install Niri:

Install niri & gammastep from the COPR repository `yalter/niri`:
```bash
sudo dnf copr enable yalter/niri
sudo dnf install niri gammastep
```

Install niri-float-sticky (For Cava Underbar):
```bash
sudo dnf install golang
go install github.com/probeldev/niri-float-sticky@latest
```

### B. Install XDG Desktop Portal and related packages:
```bash
sudo dnf install xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-utils mate-polkit gnome-keyring
```

### C. Install ly (Display Manager):
```bash
sudo dnf install ly
```

Activate ly service

> [!important]
> If you want to use ly as your display manager, you need to enable it.
> I recommend you to use `tty2` for ly, because `tty1` is used by the gdm (or other display manager) by default.
> If you want to use ly on `tty1`, you need to disable gdm (or other display manager) first.

```bash
sudo systemctl enable ly@tty2.service
sudo systemctl disable getty@tty2.service
```

How to switch between display managers: `ctrl + alt + f1` for gdm, `ctrl + alt + f2` for ly.

### D. Install Haku Space **Core** packages:

- **Install the following packages for Haku Space** (`scottames/awww`, `solopasha/hyprland`):
```bash
sudo dnf install waybar rofi swaync kitty fastfetch zsh

sudo dnf copr enable scottames/awww
sudo dnf install awww

sudo dnf copr enable solopasha/hyprland
sudo dnf install mpvpaper hypridle hyprlock
sudo dnf install nwg-look
```

- **Install core packages for my scripts**:
```bash
sudo dnf install jq ImageMagick

sudo dnf install python3-pip
pip install colorthief
```

- **Install utility tools** (`tofik/sway`):
```bash
sudo dnf install wl-clipboard cliphist cliphist slurp mpv imv

sudo dnf copr enable tofik/sway
sudo dnf install sway-audio-idle-inhibit
```

- **Install file manager & tools**:
```bash
sudo dnf install thunar thunar-archive-plugin thunar-volman file-roller gvfs gvfs-mtp tumbler ffmpegthumbnailer 7zip unrar unzip zip
```

- **Install fonts**:
```bash
sudo dnf install google-noto-sans-cjk-fonts google-noto-emoji-fonts google-noto-fonts-common
```

> [!important]
> Install **nerd font** to see **icons** for my shell
> Download **jetbrains nerd font** here: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip

```bash
unzip ~/Downloads/JetBrainsMono.zip -d ~/Downloads/JetBrainsMono
mkdir -p ~/.local/share/fonts
sudo cp -r ~/Downloads/JetBrainsMono ~/.local/share/fonts
```

- **Install optional packages**:
Zen Browser (`sneexy/zen-browser`):
```bash
sudo dnf copr enable sneexy/zen-browser
sudo dnf install zen-browser
```
VS Code:
```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
sudo dnf install code
```

> [!tip]
> See more optional packages: [here](https://github.com/hakuimaku/hakuspace/blob/main/common/pkg-optional.txt)

## 3. Install Haku Space Configurations

Clone my Haku Space repository to your home directory:
```bash
git clone https://github.com/hakuimaku/hakuspace.git ~/hakuspace
cd ~/hakuspace
```

Run the installation script to set up Haku Space configurations:
```bash
chmod +x install.sh
./install.sh
```

> [!tip]
> Follow the prompts to complete the installation process.
> Skip step 1, 2.
> In step 8, you can skip `enable ly service and disable getty` if you don't want to use ly display manager or use ly on `tty2`.

Restart your computer to apply the changes and start using Haku Space on Fedora!
