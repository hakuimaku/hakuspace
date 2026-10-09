# Kiến trúc HakuSpace

Đây là tài liệu tổng quan của repository HakuSpace. Tài liệu mô tả bố cục repository, ranh giới quyền sở hữu và trách nhiệm của các script chính.

Để xem giải thích đầy đủ về cơ chế triển khai bằng cách sao chép, các helper sao lưu, các đích được quản lý và hành vi rollback, hãy xem [Quản lý sao chép dotfiles](../dotfiles-copy-management.md).

## Bố cục repository

```text
hakuspace (root)
├── assets/                    # Tài nguyên tĩnh, bao gồm tùy chỉnh Firefox
├── docs/                      # Tài liệu kiến trúc, thiết lập và dotfiles
├── nix/                       # Cấu hình NixOS và các template flake
├── scripts/                   # Biến và hàm dùng chung cho shell
├── install.sh                # Thiết lập lần đầu và triển khai cấu hình
├── update.sh                 # Cập nhật repository, package và cấu hình
├── rollback.sh               # Khôi phục một bản sao lưu cấu hình đã chọn
└── src/
    ├── home/                 # Template cấu hình thư mục home được quản lý bằng phiên bản
    │   ├── .config/           # Mặc định cho ứng dụng và window manager
    │   ├── .local/bin/        # Script người dùng được quản lý
    │   ├── hakuspace-control/ # Template điều khiển tùy chỉnh mặc định
    │   └── .nanorc            # Cấu hình Nano
    └── packages/              # Danh sách package được nhóm theo mục đích và WM
```

## Quyền sở hữu cấu hình

HakuSpace sử dụng các file được sao chép thông thường. Nó không sử dụng Stow, symbolic link, Git worktree hay cơ chế đồng bộ trực tiếp.

```text
Nguồn trong repository                Cấu hình người dùng đã triển khai
------------------------              -------------------------------
src/home/.config/*        --copy-->   ~/.config/*
src/home/.local/bin/*     --copy-->   ~/.local/bin/*
src/home/.nanorc          --copy-->   ~/.nanorc
src/home/hakuspace-control/*
                           --copy-->   ~/hakuspace-control/*
```

- `src/home/` chứa các mặc định nền được quản lý bằng phiên bản. Những file đã triển khai có thể bị thay thế trong các lần cài đặt hoặc cập nhật sau.
- `~/hakuspace-control/` là vị trí chính dành cho các thiết lập riêng của người dùng được các template cấu hình hỗ trợ.
- `~/.config` và `~/.local` có thể chứa file của người dùng hoặc ứng dụng không liên quan. HakuSpace chỉ quản lý các đích được script triển khai.
- Chỉnh sửa file đã triển khai không cập nhật repository. Chỉnh sửa file trong repository cũng không ảnh hưởng đến session đang chạy cho đến khi file được triển khai.

Xem [Quản lý sao chép dotfiles](../dotfiles-copy-management.md) để biết về ngữ nghĩa sao chép, cấu trúc sao lưu, quy tắc tùy chỉnh và hành vi chi tiết của các script.

## Trách nhiệm của các script chính

### `install.sh`

Điểm bắt đầu cho thiết lập lần đầu. Script có thể cài dependency và package, tạo các thư mục cần thiết, triển khai cấu hình nền và file của window manager được chọn, khởi tạo cấu hình chỉ cài một lần, triển khai script, khởi tạo `~/hakuspace-control` và thực hiện thiết lập hệ thống tùy chọn.

Các đích được quản lý hiện có sẽ được sao lưu vào `~/.backup/` trước khi bị ghi đè.

### `update.sh`

Điểm vào cho việc bảo trì. Script có thể cập nhật repository lên phiên bản mới nhất hoặc ổn định, sau đó triển khai lại cấu hình và script được quản lý. Script giữ nguyên các cấu hình nằm trong `ONCE_CONFIGS` trong các lần cập nhật thông thường, còn chỉnh sửa trực tiếp vào các file nền được quản lý khác có thể bị ghi đè.

Mỗi lần triển khai tạo một điểm khôi phục có dấu thời gian trong `~/.backup/`, chứa các đích bị ảnh hưởng bởi thao tác đó.

### `rollback.sh`

Điểm vào cho việc khôi phục. Script cho phép người dùng chọn một thư mục sao lưu `~/.backup/Backup_*` trước đó, chuyển các đích hiện đang được quản lý vào thư mục an toàn `~/.backup/Rollback_Backup_*`, rồi khôi phục bản sao lưu đã chọn.

Rollback chỉ xóa các đích mà installer và updater biết đến. Các file và thư mục không liên quan trong `~/.config` và `~/.local` được giữ nguyên.

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

Repository không bị thay đổi trong quá trình triển khai và rollback. Các script này quản lý những bản sao độc lập trong thư mục home của người dùng.

## Bản đồ tài liệu

- [Quản lý sao chép dotfiles](../dotfiles-copy-management.md): ngữ nghĩa sao chép chi tiết, helper, cấu trúc sao lưu, hành vi install/update/rollback, ví dụ và các đánh đổi.
- [Hướng dẫn Fedora](../Fedora_Guide.md): hướng dẫn thiết lập dành riêng cho Fedora.
- [Mã nguồn project](../../src/): template cấu hình và manifest package được quản lý bằng phiên bản.
