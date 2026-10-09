# Fedora - Cài đặt HakuSpace

## Điều kiện tiên quyết
- Ai muốn dùng HakuSpace trên Fedora :)
- Một máy tính đã cài Fedora Workstation.
- Bạn biết những thao tác terminal cơ bản và cách cài phần mềm trên Fedora.
- Hướng dẫn này được viết và kiểm thử trên Fedora Workstation 44. Các phiên bản khác có thể có tên package hoặc cách cài hơi khác.

---

## Trước khi cài đặt
- Weak dependency là các package không bắt buộc để cài một package khác. Nếu muốn hệ thống gọn hơn, bạn có thể tắt việc tự động cài chúng:
- Nếu không muốn cài weak dependency:
```bash
sudo nano /etc/dnf/dnf.conf
```

Thêm dòng sau vào phần `[main]`:
```bash
install_weak_deps=False
```

> Xem thêm: [Fedora Packaging Guidelines - Weak Dependencies](https://docs.fedoraproject.org/en-US/packaging-guidelines/WeakDependencies/#_weak_dependencies)
>
> Cài xong HakuSpace, bạn có thể xóa dòng này khỏi `/etc/dnf/dnf.conf` nếu muốn Fedora cài weak dependency như mặc định.

---

# Bắt đầu cài đặt

## 1. Cập nhật hệ thống
Mở terminal và chạy lệnh sau:

```bash
sudo dnf upgrade --refresh
```

---

## 2. Cài các package cần thiết

### A-1. Niri

Cài Niri từ repository COPR `yalter/niri`:
```bash
sudo dnf copr enable yalter/niri
sudo dnf install niri gammastep
```

### A-2. Hyprland

Cài Hyprland từ repository COPR `lionheartp/Hyprland`:
```bash
sudo dnf copr enable lionheartp/Hyprland
sudo dnf install hyprland hyprsunset hyprland-guiutils
```

### A-3. Mango

```bash
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
sudo dnf install mangowm gammastep
```

### A-4. Labwc

```bash
sudo dnf install labwc gammastep
```

---

### B. XDG Desktop Portal và package liên quan
Cài các package dùng chung trước:
```bash
sudo dnf install xdg-desktop-portal xdg-desktop-portal-gtk xdg-utils mate-polkit gnome-keyring
```

- Với **Niri**:
```bash
sudo dnf install xdg-desktop-portal-gnome
```

- Với **Hyprland**:
```bash
sudo dnf install xdg-desktop-portal-hyprland
```

- Với **Mango** và **Labwc**:
```bash
sudo dnf install xdg-desktop-portal-wlr
```

---

### C. Package **cốt lõi** của HakuSpace

- **Cài các package chính của HakuSpace** (`scottames/awww`, `solopasha/hyprland`, `atim/starship`):
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

- **Cài dependency cho các script của HakuSpace**:
```bash
sudo dnf install jq ImageMagick python3-gobject gtk-layer-shell vte291

sudo dnf install python3-pip
pip install colorthief
```

- **Tool tiện ích**:
```bash
sudo dnf install wl-clipboard cliphist cliphist slurp mpv imv
```

- **File manager và tool liên quan**:
```bash
sudo dnf install thunar thunar-archive-plugin thunar-volman file-roller gvfs gvfs-mtp tumbler ffmpegthumbnailer 7zip unrar unzip zip
```

- **Font**:
```bash
sudo dnf install google-noto-sans-cjk-fonts google-noto-emoji-fonts google-noto-fonts-common
```

> [!important]
> Bạn cần cài **Nerd Font** để shell hiển thị đúng **icon**.
>
> Tải **JetBrains Nerd Font** tại đây: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip

```bash
# Đảm bảo file font nằm tại ~/Downloads/JetBrainsMono.zip
unzip ~/Downloads/JetBrainsMono.zip -d ~/Downloads/JetBrainsMono
mkdir -p ~/.local/share/fonts
sudo cp -r ~/Downloads/JetBrainsMono ~/.local/share/fonts
```

- **Package tùy chọn**:

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
> Xem thêm các package tùy chọn: [tại đây](../../src/packages/pkg-optional.txt)

---

## 3. Cài cấu hình HakuSpace

Làm theo [Hướng dẫn cài đặt](../../README.md#installation-guide) trong README chính.

---

Sau khi cài xong, hãy khởi động lại máy để áp dụng thay đổi rồi đăng nhập vào window manager bạn đã chọn.
