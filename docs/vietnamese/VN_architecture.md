# HakuSpace hoạt động như thế nào?

Xem bản tiếng Anh: [Architecture](../architecture.md).

Đây là tổng quan nhanh để *bạn* nắm được repo này có gì và nó chui vào máy bạn kiểu gì.

## Bố cục Repo

```text
hakuspace (root)
├── assets/                    # Mấy thứ lặt vặt bên ngoài, không copy vào máy bạn
├── docs/                      # Tài liệu hướng dẫn
├── nix/                       # Cấu hình NixOS
├── scripts/                   # Các module hỗ trợ cho bộ cài / cập nhật
├── tests/                     # Bộ test tự động
│
├── install.sh                 # Script cài đặt lần đầu
├── update.sh                  # Script cập nhật
├── link.sh                    # Script nối symlink cho từng module lẻ
├── unlink.sh                  # Script gỡ symlink an toàn
├── packages.sh                # Script cài từng nhóm package
├── rollback.sh                # Script khôi phục backup
├── doctor.sh                  # Bác sĩ kiểm tra lỗi symlink
│
└── src/
    ├── core/                  # Script của HakuSpace; sẽ được link/copy phẳng vào ~/.local/bin
    ├── home/                  # Chứa toàn bộ file dot
    │   ├── .config/           # Cấu hình cho ~/.config (quickshell, hypr, niri, waybar, ...)
    │   ├── .local/            # Cấu hình và state cho ~/.local
    │   ├── .themes/           # Chứa các theme tùy chỉnh cho ~/.themes
    │   └── hakucfg/           # Template cho cấu hình cá nhân của bạn
    │
    └── packages/              # Danh sách app cần cài
```

Cài visual thông thường dùng source clone tạm; sau build/validate/install source
được xóa, kể cả khi lỗi hoặc nhận INT/TERM. GTK, icons và cursor đã cài vẫn được
sử dụng độc lập. Developer có thể cấu hình `HAKU_CURSOR_SOURCE`,
`HAKU_GTK_THEME_SOURCE`, `HAKU_ICON_THEME_SOURCE` tại những vị trí riêng; các source
này được giữ nguyên và developer tự quản lý Git. Xem [cài visual và phát triển](../visual-setup.md).
`hakuspace-archive` chỉ cung cấp wallpaper. Cleanup không xóa repo local/nested
có sẵn. State tập trung chỉ giữ đường dẫn source dev được cấu hình và cờ retry
appearance; không ghi nhớ đường dẫn staging tạm.

## Hai chế độ giao diện: `Hikai` & `Classic`

HakuSpace hiện có 2 chế độ giao diện (shell) để bạn đổi qua lại bất cứ lúc nào mà vẫn giữ nguyên màu sắc và thiết lập cá nhân:

- **Hikai (Quickshell):** Chế độ shell của HakuSpace dựa trên Quickshell. Xem [Hikai](hikai.md) để hiểu kiến trúc và các nguyên tắc tổ chức.
- **Classic (Waybar + Rofi + SwayNC):** Bộ giao diện truyền thống đời đầu của HakuSpace. Vẫn được giữ nguyên để bạn đổi gió hoặc quay về bất cứ khi nào cần (chỉ cần bấm phím khẩn cấp `SUPER + ESCAPE` hoặc chạy `haku_backend.sh --toggle`).

Để hai giao diện này xài chung tính năng mà không phải viết lại code hai lần, đống script trong `src/core/` được chia làm 3 lớp gọn gàng (dù lúc cài ra máy thì tất cả đều nằm chung trong `~/.local/bin`):
- **`facade/`**: Những câu lệnh quen thuộc gắn với phím tắt (như `record.sh`, `wallpaper_select.sh`). Nó tự nhìn xem bạn đang ở Hikai hay Classic để gọi giao diện tương ứng.
- **`frontend/classic/`**: Chuyên bật các menu Rofi khi bạn đang dùng chế độ Classic.
- **`backend/`**: Phần "não" xử lý ngầm bên dưới (`*_ctl.sh`, `*.py`), dùng chung cho cả Hikai lẫn Classic.

## Dotfiles được quản lý ra sao?

HakuSpace dùng cơ chế **Hybrid (Lai)**: bạn được chọn giữa **Deep Symlink** hoặc **Copy truyền thống**.
(Hệ thống tự làm hết, không cần dùng Stow hay Git worktree).

- `src/home/` là bản giả lập thư mục home của bạn. Đây là BASE config.
- `~/hakucfg/` là chỗ chứa config riêng của bạn. Đây là CUSTOM config.
- Tùy vào lựa chọn lúc cài, file của bạn sẽ được symlink (sửa file là tự update vào repo) hoặc copy (sửa file thì giữ nguyên ở máy).

## Dùng bộ Dotfiles này kiểu gì?

### `install.sh` (Cài đặt mới)
- Kịch bản chạy lần đầu tiên. Bộ cài tự động được thiết kế tập trung cho Arch/yay. Dưới đây là luồng hoạt động chi tiết của nó:
  - **Phase 1: Thu thập thông tin:** Hỏi bạn chọn Window Manager (Hyprland, Niri, Mango, Labwc) và chốt luôn cơ chế deploy (Symlink hay Copy).
  - **Phase 2: Kiểm tra dependencies & Cài package:** Kiểm tra yay, đọc danh sách package trong `src/packages/` và cài đặt nhóm package cho các WM đã chọn. (Phần tích hợp NixOS chỉ kích hoạt khi phát hiện lệnh `nixos-rebuild`; hướng dẫn cho Fedora và NixOS hiện là bản cũ/không còn được bảo trì).
  - **Phase 3: Triển khai (Core Logic):**
    - Tạo các thư mục nền tảng, rải các file cấu hình cơ bản từ `src/home/.config/` và `src/core/` ra máy bạn theo đúng chế độ Symlink/Copy đã chọn.
    - Xử lý nhóm `ONCE_CONFIGS` (chỉ copy đứt đoạn 1 lần, không bao giờ symlink).
    - Tạo thư mục cá nhân `~/hakucfg` từ template nếu bạn chưa có.
  - **Phase 4: Hậu kỳ:** Cài visual software từ source tạm (`scripts/setup.sh setup`) và wallpaper (`scripts/assets.sh`) bằng hai bước riêng, khởi tạo state, đồng bộ `~/hakucfg`, set quyền thực thi cho script, đổi shell mặc định sang Fish, và thiết lập Display Manager.

### `update.sh` (Cập nhật hệ thống)
- Chạy mỗi khi bạn kéo source mới từ GitHub về.
  - **Phase 1: Cập nhật Repo:** Hỏi bạn muốn cập nhật repository theo nhánh LATEST (`main`) hay STABLE (tag mới nhất).
  - **Phạm vi:** Updater này cập nhật dotfiles, package và cấu hình HakuSpace. Không tự pull/build/cài các repo visual. Các lệnh trong [visual setup](../visual-setup.md) chỉ là công cụ tùy chọn để quản lý và phát triển những dự án đó riêng biệt.
  - **Phase 2: Backup & Nhận diện Mode:** Giống hệt cài đặt mới, nó luôn tạo lối thoát an toàn ở `~/.backup/`. Sau đó quét cấu hình hiện tại để tự nhận diện xem bạn đang dùng Symlink hay Copy.
  - **Phase 3: Cập nhật thông minh:**
    - Deploy lại toàn bộ file theo đúng chế độ tự nhận diện được.
    - Tự động **Bỏ qua (Skip)** nhóm `ONCE_CONFIGS` để không làm bay mất các tùy chỉnh giao diện (như màu mè của Thunar hay setting btop) mà bạn đã hì hục chỉnh tay.
    - **Không tự ý ghi đè cấu hình cá nhân `~/hakucfg`:** File mẫu thiếu sẽ được bổ sung, còn `setting.sh` chỉ được nâng version khi người dùng xác nhận (kèm backup tự động).
    - Lưu ý: script tự động bỏ qua nhóm package `OPTIONAL` (chỉ hỏi lúc cài mới).

### `link.sh`, `unlink.sh` & `packages.sh` (Thao tác lẻ từng món)
- Không muốn chạy nguyên bộ cài đặt đồ sộ? Bạn có thể gọi lẻ từng công cụ bất cứ lúc nào:
  - **`packages.sh`:** Cài riêng nhóm phần mềm bạn cần (ví dụ `./packages.sh core niri`).
  - **`link.sh`:** Nối symlink riêng cho từng món (ví dụ `./link.sh quickshell core`) hoặc nối tất cả (`./link.sh --all`).
  - **`unlink.sh`:** Gỡ sạch các symlink của HakuSpace mà tuyệt đối không đụng vào file thật hay dữ liệu cá nhân của bạn.

### `rollback.sh` (Quay xe khi lỗi)
- Chạy khi bạn hối hận vì update hoặc lỡ tay phá hỏng gì đó.
  - **Phase 1: Chọn Backup:** Hiện danh sách các bản backup trong `~/.backup/` để bạn chọn (mặc định lấy bản mới nhất).
  - **Phase 2: Dọn dẹp an toàn:**
    - Xóa cẩn thận các symlink của HakuSpace hiện tại để tránh bị lọt (dereference) xóa nhầm file gốc trong Repo.
  - **Phase 3: Khôi phục:** Chép ngược lại toàn bộ file từ thư mục Backup bạn chọn về đúng vị trí cũ trong `~/.config` và `~/.local/bin`.

### `doctor.sh` (Bác sĩ bắt bệnh)
- Công cụ kiểm tra sức khỏe của dotfiles (chỉ đọc, không tự ý sửa file), cực kỳ xịn nếu bạn dùng chế độ Symlink.
  - **Quét Symlink gãy:** Đi từng ngóc ngách trong `~/.config` và `~/.local/bin`, nếu thấy symlink nào trỏ vào hư không (do bạn xóa nhầm file gốc), nó sẽ in ra màu đỏ chót.
  - **Quét File bị ghi đè (Overwritten):** Dò xem có file nào đáng lý phải là symlink nhưng lại biến thành file thật (thường do text editor của bạn tự động ngắt symlink khi bấm Lưu). Bác sĩ sẽ chỉ mặt điểm tên và hướng dẫn bạn câu lệnh để nối lại symlink.

## Mục Lục (Khám phá sâu hơn)

Để hiểu rõ cặn kẽ cách HakuSpace vận hành "dưới gầm xe", bạn có thể đọc các tài liệu sau theo thứ tự:

1. **[Cơ chế Quản lý (Management)](VN_management.md)**: Hiểu cách hệ thống cài đặt an toàn (Symlink vs Copy), cài lẻ từng module và cách gỡ cài đặt sạch sẽ.
2. **[Thư viện Lõi (Core Libs)](../core/lib.md)**: Quản lý State tập trung, kết nối Hikai/Classic và điều hướng đa Window Manager.
3. **[Động cơ Theme (Theme Engine)](../core/theme.md)**: Cách hệ thống bóc tách màu từ hình nền và đồng bộ màu cho cả giao diện lẫn bộ icon.
4. **[Quản lý Hệ thống (System)](../core/sys.md)**: Các script khoá màn hình, chống tắt màn hình thông minh, và menu nguồn.
5. **[Công cụ Tiện ích (Utilities)](../core/util.md)**: Các công cụ dùng hàng ngày (chụp/quay màn hình, lọc ánh sáng xanh, clipboard).
6. **[Haku Menu (Menu)](../core/menu.md)**: Giải phẫu menu trung tâm trên cả Rofi lẫn Quickshell.
7. **[Ứng dụng Nhỏ (Mini-Apps)](../core/app.md)**: Các app xịn xò tự code (Taskbar, Desktop Icons, Rounded Screen, Edge Trigger, Cava Underbar).
8. **[Tích hợp NixOS](../nixos.md)**: Chi tiết chế độ Offline và Online Flake cho người dùng NixOS.
