# HakuSpace hoạt động như thế nào?

Xem bản tiếng Anh: [Architecture](../architecture.md).

Đây là tổng quan nhanh để *bạn* nắm được repo này có gì và nó chui vào máy bạn kiểu gì.

## Bố cục Repo

```text
hakuspace (root)
├── assets/                    # Mấy thứ lặt vặt bên ngoài, không copy vào máy bạn
├── docs/                      # Tài liệu hướng dẫn
├── nix/                       # Cấu hình NixOS
│
├── scripts/                   # Script hỗ trợ
├── install.sh                 # Script cài đặt lần đầu
├── update.sh                  # Script cập nhật
├── rollback.sh                # Script khôi phục backup
├── doctor.sh                  # Bác sĩ kiểm tra lỗi symlink
│
└── src/
    ├── core/                  # Script của HakuSpace; sẽ được link/copy vào ~/.local/bin
    ├── home/                  # Chứa toàn bộ file dot
    │   ├── .config/           # Cấu hình cho ~/.config
    │   ├── .local/            # Cấu hình và state cho ~/.local
    │   ├── .themes/           # Chứa các theme tùy chỉnh cho ~/.themes
    │   └── hakucfg/           # Template cho cấu hình cá nhân của bạn
    │   
    └── packages/              # Danh sách app cần cài
```

## Dotfiles được quản lý ra sao?

HakuSpace dùng cơ chế **Hybrid (Lai)**: bạn được chọn giữa **Deep Symlink** hoặc **Copy truyền thống**.
(Hệ thống tự làm hết, không cần dùng Stow hay Git worktree).

- `src/home/` là bản giả lập thư mục home của bạn. Đây là BASE config.
- `~/hakucfg/` là chỗ chứa config riêng của bạn. Đây là CUSTOM config.
- Tùy vào lựa chọn lúc cài, file của bạn sẽ được symlink (sửa file là tự update vào repo) hoặc copy (sửa file thì giữ nguyên ở máy).

## Dùng bộ Dotfiles này kiểu gì?

### `install.sh` (Cài đặt mới)
- Kịch bản chạy lần đầu tiên. Dưới đây là luồng hoạt động chi tiết của nó:
  - **Phase 1: Thu thập thông tin:** Nó sẽ hỏi bạn đang dùng distro nào (Arch/Fedora), muốn xài Window Manager nào (Hyprland, Niri, Mango, Labwc) và chốt luôn cơ chế deploy (Symlink hay Copy).
  - **Phase 2: Backup:** Nó quét những file sắp bị ghi đè trong `~/.config` và `~/.local/bin`, gom gọn vào `~/.backup/Backup_<timestamp>`.
  - **Phase 3: Cài package:** Đọc các file text trong `src/packages/` và gọi trình quản lý gói để cài.
  - **Phase 4: Triển khai (Core Logic):**
    - Rải các file cấu hình cơ bản từ `src/home/.config/` và `src/core/` ra máy bạn theo đúng chế độ Symlink/Copy đã chọn.
    - Xử lý nhóm `ONCE_CONFIGS` (chỉ copy đứt đoạn 1 lần, không bao giờ symlink).
    - Tạo thư mục cá nhân `~/hakucfg` từ template nếu bạn chưa có.
  - **Phase 5: Hậu kỳ:** Set quyền thực thi cho script, đổi shell mặc định sang Fish, và dọn dẹp cache cũ.

### `update.sh` (Cập nhật hệ thống)
- Chạy mỗi khi bạn kéo source mới từ GitHub về.
  - **Phase 1: Nhận diện:** Nó tự động đọc file `~/.local/state/hakuspace/deploy_mode` để nhớ lại trước đây bạn cài bằng Symlink hay Copy.
  - **Phase 2: Khởi tạo Backup:** Giống hệt cài đặt mới, nó luôn tạo lối thoát an toàn ở `~/.backup/`.
  - **Phase 3: Cập nhật thông minh:**
    - Deploy lại toàn bộ file theo đúng chế độ bạn đã chọn.
    - Tự động **Bỏ qua (Skip)** nhóm `ONCE_CONFIGS` để không làm bay mất các tùy chỉnh giao diện (như màu mè của Thunar hay setting btop) mà bạn đã hì hục chỉnh tay.
    - Mặc kệ và không đụng vào `~/hakucfg/` của bạn.

### `rollback.sh` (Quay xe khi lỗi)
- Chạy khi bạn hối hận vì update hoặc lỡ tay phá hỏng gì đó.
  - **Phase 1: Chọn Backup:** Hiện danh sách các bản backup trong `~/.backup/` để bạn chọn (mặc định lấy bản mới nhất).
  - **Phase 2: Dọn dẹp an toàn:**
    - Xóa cẩn thận các symlink của HakuSpace hiện tại để tránh bị lọt (dereference) xóa nhầm file gốc trong Repo.
  - **Phase 3: Khôi phục:** Chép ngược lại toàn bộ file từ thư mục Backup bạn chọn về đúng vị trí cũ trong `~/.config` và `~/.local/bin`. 

### `doctor.sh` (Bác sĩ bắt bệnh)
- Công cụ kiểm tra sức khỏe của dotfiles, cực kỳ xịn nếu bạn dùng chế độ Symlink.
  - **Quét Symlink gãy:** Đi từng ngóc ngách trong `~/.config` và `~/.local/bin`, nếu thấy symlink nào trỏ vào hư không (do bạn xóa nhầm file gốc), nó sẽ in ra màu đỏ chót.
  - **Quét File bị ghi đè (Overwritten):** Dò xem có file nào đáng lý phải là symlink nhưng lại biến thành file thật (thường do text editor của bạn tự động ngắt symlink khi bấm Lưu). Bác sĩ sẽ chỉ mặt điểm tên và khuyên bạn chạy `update.sh` để nối lại symlink.

Xem tiếp: [Management](VN_management.md) để hiểu sâu hơn về độ an toàn của hệ thống nhé!
