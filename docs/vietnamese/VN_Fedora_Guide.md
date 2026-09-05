# Fedora - Hướng dẫn cài đặt Haku Space

## Điều kiện tiên quyết
- Những ai muốn sử dụng Haku Space trên Fedora :)
- Một máy tính đã cài Fedora.
- Hướng dẫn này giả định bạn có kiến thức cơ bản về sử dụng terminal và cài đặt phần mềm trên Fedora.
- Người viết đang sử dụng Fedora Workstation 44; hướng dẫn này được viết cho phiên bản đó.

---

## Trước khi cài đặt
- Weak dependency là các package không bắt buộc để cài một package. Theo người viết, chúng là các package không cần thiết và gây thừa.
- Nếu không muốn cài weak dependency:
```bash
sudo nano /etc/dnf/dnf.conf
```

Thêm dòng sau vào phần `[main]`:
```bash
install_weak_deps=False
```

> Xem thêm thông tin: [tại đây](https://docs.fedoraproject.org/en-US/packaging-guidelines/WeakDependencies/#_weak_dependencies)
>
> Sau khi cài đặt xong, bạn có thể xóa dòng đó khỏi `/etc/dnf/dnf.conf` để tiếp tục cài các weak dependency khi cần.

---

# Các bước cài đặt

## 1. **Cập nhật hệ thống**:
Mở terminal và chạy lệnh sau để đảm bảo hệ thống được cập nhật:

```bash
sudo dnf upgrade --refresh
```

---

## 2. **Cài đặt package**:

### A-1. Cài đặt Niri:

Cài Niri từ repository COPR `yalter/niri`:
```bash
sudo dnf copr enable yalter/niri
sudo dnf install niri gammastep
```

### A-2. Cài đặt Hyprland:

Cài Hyprland từ repository COPR `lionheartp/Hyprland`:
```bash
sudo dnf copr enable lionheartp/Hyprland
sudo dnf install hyprland hyprsunset hyprland-guiutils
```

### A-3. Cài đặt Mango:

```bash
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
sudo dnf install mangowm gammastep
```

### A-4. Cài đặt Labwc:

```bash
sudo dnf install labwc gammastep
```

---

### B. Cài đặt XDG Desktop Portal và các package liên quan:
Cài đặt các package XDG Desktop Portal dùng chung:
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

### C. Cài đặt các package **cốt lõi** của Haku Space:

- **Cài các package sau cho Haku Space** (`scottames/awww`, `solopasha/hyprland`, `atim/starship`):
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

- **Cài các package cốt lõi cho các script của Haku Space**:
```bash
sudo dnf install jq ImageMagick python3-gobject gtk-layer-shell vte291

sudo dnf install python3-pip
pip install colorthief
```

- **Cài các tool tiện ích**:
```bash
sudo dnf install wl-clipboard cliphist cliphist slurp mpv imv
```

- **Cài file manager và các tool liên quan**:
```bash
sudo dnf install thunar thunar-archive-plugin thunar-volman file-roller gvfs gvfs-mtp tumbler ffmpegthumbnailer 7zip unrar unzip zip
```

- **Cài font**:
```bash
sudo dnf install google-noto-sans-cjk-fonts google-noto-emoji-fonts google-noto-fonts-common
```

> [!important]
> Hãy cài **Nerd Font** để hiển thị **icon** cho shell.
>
> Tải **JetBrains Nerd Font** tại đây: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip

```bash
# Đảm bảo file font nằm tại ~/Downloads/JetBrainsMono.zip
unzip ~/Downloads/JetBrainsMono.zip -d ~/Downloads/JetBrainsMono
mkdir -p ~/.local/share/fonts
sudo cp -r ~/Downloads/JetBrainsMono ~/.local/share/fonts
```

- **Cài các package tùy chọn**:

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

## 3. Cài đặt cấu hình Haku Space

Hãy làm theo hướng dẫn trong [Hướng dẫn cài đặt](../../README.md#installation-guide)

---

Khởi động lại máy tính để áp dụng các thay đổi và bắt đầu sử dụng Haku Space trên Fedora!
