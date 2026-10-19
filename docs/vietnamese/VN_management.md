# Quản lý Dotfiles như thế nào?

Bản tiếng Anh: [Management](../management.md).

Tài liệu này giải thích kiến trúc và bộ công cụ quản lý dotfiles dạng module (modular) của HakuSpace.

---

## 1. Kiến trúc Modular

HakuSpace sử dụng kiến trúc CLI phân tách module rõ ràng. Các script ở thư mục gốc (`install.sh` và `update.sh`) chỉ đóng vai trò điều phối (orchestration), gọi trực tiếp các module chuyên trách nằm trong thư mục `scripts/`.

Mọi tác vụ đều có thể chạy tự động qua bộ cài đặt hoặc chạy độc lập bằng các câu lệnh dòng lệnh (CLI).

```text
install.sh / update.sh
        │
        │ chỉ điều phối
        ▼
   scripts/*.sh
        │
        ├── registry.sh       (Nguồn dữ liệu chuẩn duy nhất cho các target)
        ├── runtime.sh        (Quản lý Run ID & thư mục backup dùng chung)
        └── filesystem.sh     (Các thao tác file & backup trung lập)
```

### Thư mục Backup dùng chung (Shared Runtime Context)
Mỗi khi bạn chạy `install.sh`, `update.sh` hoặc bất kỳ script độc lập nào, module `scripts/runtime.sh` sẽ tạo một biến `BACKUP_DIR` duy nhất cho toàn bộ phiên chạy đó. Mọi tiến trình con sẽ tự động dùng chung thư mục này, không sinh ra nhiều thư mục backup lộn xộn.

---

## 2. Các chế độ triển khai (Deployment Modes)

HakuSpace hỗ trợ 2 chế độ triển khai:

### Chế độ 1: Deep Symlink (Mặc định & Khuyên dùng)
Được quản lý thông qua `./link.sh` và `scripts/link.sh`.
- **Thư mục thật**: Các thư mục đích (như `~/.config/quickshell`) vẫn là thư mục thật, không phải symlink dạng thư mục.
- **Symlink từng file**: Chỉ các file cấu hình được theo dõi mới được symlink từ `src/home/`.
- **Cách ly dữ liệu**: File cache, log và dữ liệu sinh ra khi chạy app sẽ nằm nguyên tại máy cá nhân, không làm bẩn Git repo.
- **Đồng bộ tức thì**: Chỉnh sửa file ở `~/.config` sẽ lập tức cập nhật vào repo.

### Chế độ 2: Copy Truyền thống (Legacy Copy)
Được quản lý thông qua `scripts/legacy_copy.sh`.
- Copy trực tiếp file từ repo vào thư mục máy người dùng.
- An toàn và tách biệt khỏi Git, nhưng các thay đổi bạn thực hiện ở `~/.config` sẽ không tự đồng bộ ngược lại repo.
- Giữ nguyên cơ chế cũ tương thích mà không thay đổi hành vi.

Script `update.sh` và `doctor.sh` sẽ tự động nhận diện chế độ Symlink hay Copy thông qua `scripts/deploy_mode.sh`.

---

## 3. Các mục tiêu đặc biệt & Vòng đời (Lifecycles)

### `ONCE_CONFIGS` (Chỉ Copy một lần khi cài đặt)
Các ứng dụng như Thunar, xfce4, mpv, btop, cava, mimeapps.list thường xuyên ghi đè trạng thái vào file cấu hình khi chạy.
- Các file này **luôn được copy thật** khi cài đặt lần đầu (`scripts/once_configs.sh`).
- Chúng **không bao giờ được symlink** và **không bị ghi đè** khi chạy `./update.sh`.

### `~/hakucfg` (Không gian tùy biến cá nhân)
Mọi thiết lập cá nhân của bạn (autostart, biến môi trường, theme riêng) nằm tại `~/hakucfg/`.
- Quản lý bởi `scripts/hakucfg.sh`.
- Cấu hình riêng của Quickshell nằm tại `~/hakucfg/hikai/hikai-shell.json`. Sync chuyển file cũ ở thư mục gốc khi chưa có file đích; nếu cả hai cùng tồn tại thì giữ nguyên cả hai và dùng file trong `hikai/`. Cấu hình dùng chung Classic/Hikai giữ đường dẫn chung.
- Không tự ý ghi đè cấu hình cá nhân; file mẫu thiếu sẽ được bổ sung, còn `setting.sh` chỉ được nâng version khi người dùng xác nhận (kèm backup tự động).

### `~/.local/state/hakuspace` (Trạng thái hệ thống)
Chứa style động, theme và cache runtime.
- Khởi tạo qua `scripts/state.sh init`.
- Kiểm tra tính toàn vẹn (chỉ đọc) qua `scripts/state.sh check`.

---

## 4. Các lệnh CLI chính tại thư mục gốc

| Câu lệnh | Mục đích |
|---|---|
| `./install.sh` | Cài đặt tự động toàn diện theo profile |
| `./update.sh` | Cập nhật tự động toàn diện theo profile |
| `./link.sh [modules]` | Tạo Deep Symlink cho từng module hoặc toàn bộ |
| `./unlink.sh [modules]` | Gỡ bỏ an toàn các symlink thuộc HakuSpace |
| `./packages.sh [groups]` | Cài đặt các nhóm package qua pacman/yay |
| `./doctor.sh` | Chẩn đoán toàn diện hệ thống (chế độ chỉ đọc) |
| `./rollback.sh` | Khôi phục lại cấu hình từ bản backup trước đó |

---

## 5. Hướng dẫn sử dụng thủ công (Manual Workflow)

Bạn không bao giờ cần phải mở `install.sh` để copy từng dòng lệnh. Bạn có thể sử dụng các module độc lập một cách tiện lợi (xem hướng dẫn cài đặt từng bước đầy đủ tại [Installation Guide trong README.md](../../README.md#method-2--manual--modular-installation)):

### Cài đặt Packages
```bash
./packages.sh core
./packages.sh service
./packages.sh niri
./packages.sh --list
```

### Link Cấu hình
```bash
# Link từng thành phần riêng lẻ
./link.sh quickshell
./link.sh kitty
./link.sh niri
./link.sh core

# Link toàn bộ cấu hình nền tảng
./link.sh --all

# Xem danh sách các module có sẵn
./link.sh --list
```

### Gỡ bỏ Symlink (Unlink an toàn)
`./unlink.sh` chỉ xóa các symlink được xác nhận là thuộc về HakuSpace. Nó **không bao giờ** xóa file thật của người dùng, symlink ngoại lai hay dữ liệu ứng dụng:
```bash
./unlink.sh quickshell
./unlink.sh niri
./unlink.sh core
./unlink.sh --all
```

### Khởi tạo State & Hakucfg
```bash
scripts/state.sh init
scripts/hakucfg.sh sync
```

### Chẩn đoán lỗi với Doctor
`./doctor.sh` hoạt động hoàn toàn ở chế độ chỉ đọc (read-only) và không bao giờ tự ý sửa đổi file trên máy bạn. Script sẽ quét tìm symlink gãy, file bị ghi đè, và chỉ dẫn câu lệnh chính xác để khắc phục:
```bash
./doctor.sh
```

---

## 6. Gỡ cài đặt HakuSpace (Uninstalling)

HakuSpace không dùng script gỡ cài đặt xóa trắng một lần. Quy trình gỡ an toàn phụ thuộc vào chế độ triển khai bạn đã chọn.

> [!IMPORTANT]
> `./unlink.sh` chỉ dành cho **Deep Symlink mode**. Script chỉ xóa các symlink được xác minh thuộc về HakuSpace và bảo toàn tuyệt đối file thật, symlink ngoài luồng và dữ liệu người dùng. **Không** tự ý xóa trắng `~/.local/bin` hay toàn bộ thư mục trong `~/.config`.

### 1. Khôi phục cấu hình cũ (Khuyên dùng nếu có bản backup)
```bash
cd ~/hakuspace
./rollback.sh
```
Chọn bản backup trước khi cài HakuSpace để khôi phục các file cấu hình về trạng thái ban đầu.

### 2. Gỡ bỏ Symlink của HakuSpace
Với **Symlink mode**, gỡ từng module hoặc toàn bộ module chung kèm Window Manager đã cài:
```bash
./unlink.sh quickshell
./unlink.sh niri
./unlink.sh core

# Gỡ toàn bộ cấu hình chung + WM tương ứng
./unlink.sh --all niri
./unlink.sh --all hyprland niri mango labwc
```
Với **Copy mode**, hãy dùng `./rollback.sh` hoặc tự kiểm tra các thư mục cấu hình thủ công.

### 3. Dọn dẹp dữ liệu Runtime & Cá nhân
```bash
rm -rf ~/.local/state/hakuspace
rm -rf ~/.local/share/hakuspace
```
- **`~/hakucfg`** chứa tùy chỉnh cá nhân và không bị xóa tự động. Chỉ xóa (`rm -rf ~/hakucfg`) sau khi bạn đã sao lưu những thay đổi cần giữ lại.
- **`ONCE_CONFIGS`** (`Thunar`, `xfce4`, `mpv`, `btop`, `cava`, `mimeapps.list`) là các file copy thật, nên khôi phục từ backup hoặc kiểm tra riêng từng phần.

### 4. Packages & Thiết lập hệ thống
Kiểm tra danh sách gói trước khi gỡ thủ công bằng chính công cụ của repo:
```bash
./packages.sh --list
./packages.sh --dry-run core service niri
```
Đồng thời kiểm tra lại login shell mặc định (Fish), display manager (Ly), desktop defaults và cấu hình `/etc/nixos` nếu có sử dụng.

### 5. Dọn dẹp Assets
```bash
rm -rf ~/hakuspace-archive
```
Chỉ xóa các icon/theme/wallpaper thuộc HakuSpace trong `~/.icons`, `~/.themes`, `~/Pictures/Wallpapers`.

### 6. Xóa Repository (BƯỚC CUỐI CÙNG)
Sau khi đã hoàn tất các bước trên và kiểm tra hệ thống ổn định:
```bash
rm -rf ~/hakuspace
```
Giữ lại `~/.backup/Backup_*` cho đến khi chắc chắn không cần khôi phục nữa.

---
**Tiếp theo:** [Thư viện Lõi (Core Libraries)](../core/lib.md) ➡️
