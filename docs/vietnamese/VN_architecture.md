# HakuSpace hoạt động như thế nào?

> Đây là nội dung do AI tạo ra. Có thể không chính xác hoặc chưa đầy đủ. Nhưng tôi đã xem xét và đảm bảo rằng nó chính xác.

Tài liệu này giúp bạn hiểu nhanh HakuSpace được sắp xếp và vận hành ra sao. Nội dung gồm bố cục repository, những file nào do HakuSpace quản lý và vai trò của từng script chính.

Muốn tìm hiểu kỹ hơn về cách sao chép cấu hình, sao lưu và rollback, bạn xem [Quản lý dotfiles bằng cách sao chép](VN_dotfiles-copy-management.md).

## Bố cục repository

```text
hakuspace (root)
├── assets/                    # Tài nguyên tĩnh, bao gồm tùy chỉnh Firefox
├── docs/                      # Tài liệu kiến trúc, thiết lập và dotfiles
├── nix/                       # Cấu hình NixOS và các template flake
├── scripts/                   # Biến và hàm dùng chung cho shell
├── install.sh                 # Thiết lập lần đầu và triển khai cấu hình
├── update.sh                  # Cập nhật repository, package và cấu hình
├── rollback.sh                # Khôi phục một bản sao lưu cấu hình đã chọn
└── src/
    ├── home/                  # Template cấu hình thư mục home được quản lý bằng phiên bản
    │   ├── .config/           # Mặc định cho ứng dụng và window manager
    │   ├── .local/bin/        # Các script trong home được quản lý
    │   ├── hakuspace-control/ # Template điều khiển tùy chỉnh mặc định
    │   └── .nanorc            # Cấu hình Nano
    └── packages/              # Danh sách package được nhóm theo mục đích và WM
```

## Quyền sở hữu cấu hình

HakuSpace sử dụng các file được sao chép thông thường. Nó không sử dụng Stow, symbolic link, Git worktree hay cơ chế đồng bộ trực tiếp.

```text
Nguồn trong repository                Cấu hình đã chép vào máy
------------------------              -------------------------------
src/home/.config/*        --copy-->   ~/.config/*
src/home/.local/bin/*     --copy-->   ~/.local/bin/*
src/home/.nanorc          --copy-->   ~/.nanorc
src/home/hakuspace-control/*
                           --copy-->   ~/hakuspace-control/*
```

- `src/home/` chứa các cấu hình nền được quản lý bằng phiên bản. Các bản sao đã cài vào máy có thể bị thay thế trong những lần cài đặt hoặc cập nhật sau.
- `~/hakuspace-control/` là nơi bạn đặt các thiết lập riêng, nếu template cấu hình tương ứng có hỗ trợ.
- `~/.config` và `~/.local` có thể còn chứa file của bạn hoặc của ứng dụng khác. HakuSpace chỉ quản lý những đường dẫn mà script triển khai.
- Sửa bản sao đã triển khai không làm thay đổi repository. Ngược lại, sửa file trong repository cũng chưa ảnh hưởng đến phiên hiện tại cho đến khi bạn chạy install hoặc update.

Xem [Quản lý dotfiles bằng cách sao chép](VN_dotfiles-copy-management.md) để biết chi tiết về cách sao chép, cấu trúc bản sao lưu, quy tắc tùy chỉnh và hành vi của các script.

## Trách nhiệm của các script chính

### `install.sh`

Đây là script bạn chạy khi thiết lập lần đầu. Script có thể cài dependency và package, tạo thư mục cần thiết, chép cấu hình nền cùng file của window manager bạn chọn, tạo cấu hình chỉ cài một lần, chép các script và khởi tạo `~/hakuspace-control`. Script cũng có thể thực hiện một số thiết lập hệ thống tùy chọn.

Các đường dẫn đang được HakuSpace quản lý sẽ được sao lưu vào `~/.backup/` trước khi bị ghi đè.

### `update.sh`

Đây là script dùng để bảo trì. Script có thể cập nhật repository lên bản mới nhất hoặc bản ổn định, rồi chép lại cấu hình và các script được quản lý. Trong lần update thông thường, các cấu hình nằm trong `ONCE_CONFIGS` được giữ nguyên. Những file nền được quản lý khác có thể bị ghi đè nếu bạn đã sửa trực tiếp.

Mỗi lần chạy sẽ tạo một bản sao lưu có dấu thời gian trong `~/.backup/`, chỉ gồm những đường dẫn bị ảnh hưởng bởi lần chạy đó.

### `rollback.sh`

Đây là script dùng để khôi phục. Bạn chọn một thư mục sao lưu `~/.backup/Backup_*`, sau đó script chuyển các đường dẫn đang được quản lý vào thư mục an toàn `~/.backup/Rollback_Backup_*` rồi khôi phục bản sao lưu bạn chọn.

Rollback chỉ xóa những đường dẫn mà installer và updater biết đến. Các file và thư mục không liên quan trong `~/.config` và `~/.local` vẫn được giữ nguyên.

## Luồng triển khai

```text
Mặc định trong repository
        │
        ▼
install.sh / update.sh
        │
        ├── sao lưu các đích được quản lý hiện có
        └── sao chép cấu hình được chọn vào $HOME
                    │
                    ▼
              ~/.backup/Backup_*

Bản sao lưu đã chọn
        │
        ▼
rollback.sh
        │
        ├── chuyển các đích hiện tại sang nơi khác
        └── khôi phục các file và thư mục đã chọn
                    │
                    ▼
          ~/.backup/Rollback_Backup_*
```

Repository không bị thay đổi trong quá trình cài đặt, cập nhật hay rollback. Các script chỉ quản lý những bản sao độc lập trong thư mục home của bạn.

## Bản đồ tài liệu

- [Quản lý dotfiles bằng cách sao chép](VN_dotfiles-copy-management.md): cách sao chép, helper, cấu trúc sao lưu, hành vi install/update/rollback, ví dụ và các đánh đổi.
- [Cài đặt trên Fedora](VN_Fedora_Guide.md): hướng dẫn thiết lập dành riêng cho Fedora.
- [Mã nguồn project](../../src/): template cấu hình và manifest package được quản lý bằng phiên bản.
