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
- Tự động tạo các file mẫu nếu chưa có, bảo vệ tuyệt đối các file bạn đã chỉnh sửa.
- Tự động kiểm tra phiên bản của `setting.sh` để nhắc bạn cập nhật khi có bản mới.

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

Bạn không bao giờ cần phải mở `install.sh` để copy từng dòng lệnh. Bạn có thể sử dụng các module độc lập một cách tiện lợi:

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
**Tiếp theo:** [Thư viện Lõi (Core Libraries)](../core/lib.md) ➡️
