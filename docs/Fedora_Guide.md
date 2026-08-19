# Fedora - Haku Space Installation Guide

## Prerequisites
- Who wants to use Haku Space on Fedora :)
- A computer with Fedora installed.
- This installation guide assumes you have basic knowledge of using the terminal and installing software on Fedora.
- I'm using Fedora Workstation 44, this guide was written for this version.

---

## Before Installation
- Weak dependencies are packages that are not strictly required when installing a package. Follow my installation guide, weak dependencies are the bloatware, not useful.
- If you don't want to install weak dependency packages:
```bash
sudo nano /etc/dnf/dnf.conf
```
And add this to `[main]`:
```bash
install_weak_deps=False
```

> See more information: [here](https://docs.fedoraproject.org/en-US/packaging-guidelines/WeakDependencies/#_weak_dependencies)
> 
> After installation, you can remove that line from `/etc/dnf/dnf.conf` to install weak dependency packages again.

---

# Installation Steps

## 1. **Update your system**:
Open a terminal and run the following command to ensure your system is up to date:

```bash
sudo dnf upgrade --refresh
```

---

## 2. **Install Packages**: 

### A-1. Install Niri:

Install niri from the COPR repository `yalter/niri`:
```bash
sudo dnf copr enable yalter/niri
sudo dnf install niri gammastep
```

Install niri-float-sticky (For Cava Underbar):
```bash
sudo dnf install golang
go install github.com/probeldev/niri-float-sticky@latest
```

### A-2. Install Hyprland:

Install hyprland from the COPR repository `lionheartp/Hyprland`:
```bash
sudo dnf copr enable lionheartp/Hyprland
sudo dnf install hyprland hyprsunset hyprland-guiutils
```

### A-3. Install Mango:

```bash
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
sudo dnf install mangowm gammastep
```

### A-4. Install Labwc:

```bash
sudo dnf install labwc gammastep
```

---

### B. Install XDG Desktop Portal and related packages:
Install common XDG Desktop Portal packages:
```bash
sudo dnf install xdg-desktop-portal xdg-desktop-portal-gtk xdg-utils mate-polkit gnome-keyring
```

- For **Niri**:
```bash
sudo dnf install xdg-desktop-portal-gnome
```

- For **Hyprland**:
```bash
sudo dnf install xdg-desktop-portal-hyprland
```

- For **Mango** & **Labwc**:
```bash
sudo dnf install xdg-desktop-portal-wlr
```

---

### C. Install Haku Space **Core** packages:

- **Install the following packages for Haku Space** (`scottames/awww`, `solopasha/hyprland`, `atim/starship`):
```bash
sudo dnf install waybar rofi swaync kitty fastfetch fish direnv zoxide eza

sudo dnf copr enable scottames/awww
sudo dnf install awww

sudo dnf copr enable solopasha/hyprland
sudo dnf install mpvpaper hypridle hyprlock
sudo dnf install nwg-look

sudo dnf copr enable atim/starship
sudo dnf install starship
```

- **Install core packages for my scripts**:
```bash
sudo dnf install jq ImageMagick python3-gobject gtk-layer-shell

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
> Install **nerd font** to see **icons** for my shell.
> 
> Download **jetbrains nerd font** here: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip

```bash
# Make sure you install that font located in ~/Downloads/JetBrainsMono.zip
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

---

## 3. Install Haku Space Configurations

Simply follow the instructions in the [Installation Guide](https://github.com/hakuimaku/hakuspace#-3)

---

Restart your computer to apply the changes and start using Haku Space on Fedora!
