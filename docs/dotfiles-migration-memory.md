# Dotfiles migration plan (copy -> hybrid symlink)

Date: 2026-07-05
Owner: Haku (`hakuimaku`)
Repo: `hakuimaku/hakuspace`

## Goal
Chuyển installer dotfiles từ cơ chế **copy toàn bộ config** sang **hybrid**:
- **Symlink** cho các thư mục cấu hình hoạt động thường xuyên để nhận cập nhật ngay sau `git pull`.
- **Copy** cho assets tĩnh/nặng như wallpapers, icons, themes.
- Có cơ chế **backup an toàn** trước khi ghi đè.

## Scope quyết định hiện tại

### 1) Nhóm dùng symlink
Các target trong home (ví dụ):
- `~/.config/waybar`
- `~/.config/rofi`
- `~/.config/hypr`
- `~/.local/bin`

> Nguyên tắc: link theo từng app/thư mục cụ thể, **không** symlink cả `~/.config`.

### 2) Nhóm vẫn dùng copy (hybrid)
- `~/Pictures/Wallpapers`
- Icons
- Themes
- Các asset tương tự (tĩnh, dung lượng lớn, không cần live-link)

## Backup strategy

Khi chạy `install.sh`, nếu target tồn tại thì backup trước khi thao tác:
- Tạo thư mục backup theo timestamp:
  - `~/Backup_YYYY-MM-DD_HH-MM-SS/`
- Mirror cấu trúc theo loại:
  - `config/waybar`
  - `config/rofi`
  - `local/bin/script.sh`

Ví dụ:
- `~/Backup_2026-07-05_21-40-12/config/waybar`
- `~/Backup_2026-07-05_21-40-12/local/bin`

## Hành vi install.sh mong muốn (idempotent)

1. Nếu target **đã là symlink đúng** tới repo -> `SKIP`.
2. Nếu target tồn tại và **không phải symlink đúng** -> `BACKUP` rồi tạo symlink mới.
3. Nếu target là symlink nhưng **trỏ sai** -> backup/unlink symlink cũ, tạo lại symlink đúng.
4. Trước khi link/copy luôn `mkdir -p` thư mục cha.
5. In log rõ ràng theo nhãn:
   - `[BACKUP]`
   - `[LINK]`
   - `[COPY]`
   - `[SKIP]`

## Các quyết định mở (cần chốt sau)
- Chính sách khi chạy installer nhiều lần: backup mọi lần hay chỉ backup khi có thay đổi?
- Xử lý xung đột trong `~/.local/bin` nếu user có script riêng.
- Có cần `--dry-run`, `--force`, `--restore`, `--uninstall` không.
- Có nên bỏ qua copy assets nếu checksum không đổi để tiết kiệm dung lượng/thời gian.

## Deliverables đề xuất
1. Cập nhật `install.sh` theo hybrid logic ở trên.
2. Thêm file cấu hình mapping (optional) để khai báo danh sách link/copy dễ maintain.
3. Bổ sung README:
   - Cách cài
   - Cách rerun an toàn
   - Vị trí backup
   - Cách restore thủ công

## Prompt memory note
File này dùng làm memory cho các prompt kế tiếp về migration dotfiles trong repo `hakuimaku/hakuspace`.
