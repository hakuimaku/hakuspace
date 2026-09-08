# HakuSpace hoạt động như thế nào?

Xem bản tiếng Anh [Architecture](../architecture.md).

Đây là tài liệu tổng quan để *bạn* và *AI* hiểu dotfiles của tôi có gì và cách chúng được triển khai vô máy bạn.

## Bố cục repository

```text
hakuspace (root)
├── assets/                    # Chứa các assets ngoài, sẽ không copy vô máy bạn
├── docs/                      # Chứa documents cho project
├── nix/                       # Chứa cấu hình NixOS và các template flake
│
├── scripts/                   # Chứa các script helper
├── install.sh                 # Script cài đặt dotfiles lần đầu
├── update.sh                  # Script cập nhật dotfiles
├── rollback.sh                # Script khôi phục dotfiles từ bản sao lưu
│
└── src/
    ├── home/                  # Thư mục chính chứa các file dot
    │   ├── .config/           # Các file cấu hình trong ~/.config
    │   ├── .local/bin/        # Các script tạo nên hakuspace trong ~/.local/bin
    │   └── hakucfg/           # Template cho thư mục custom hakuspace
    │   
    └── packages/              # Danh sách package được nhóm để cài đặt
```

## Dotfiles được quản lý kiểu gì?

HakuSpace sử dụng các file được sao chép thông thường. Nó không sử dụng Stow, symbolic link, Git worktree hay cơ chế đồng bộ trực tiếp.

- `src/home/` là nơi giả lập lại thư mục home của bạn, xem các cấu hình và script trong đây. Đây là BASE config.
- `~/hakucfg/` là nơi bạn đặt các file cấu hình cá nhân, ở trong repo nó là template để pull về máy bạn. Đây là CUSTOM config.
- Sửa bản sao đã triển khai không làm thay đổi repository. Ngược lại, sửa file trong repository cũng chưa ảnh hưởng đến phiên hiện tại cho đến khi bạn chạy install hoặc update.

## Dùng dotfiles của tôi như thế nào?

### `install.sh`

- Đây là script chạy lần đầu để cài đặt dotfiles. Các lần sau bạn chạy lại thì cũng được thôi nhưng không recommended.
- Nó sẽ làm gì?
  - Cài đặt các package cần thiết.
  - Tạo các thư mục cần thiết.
  - Chép các file cấu hình và script từ repository vào máy bạn.
  - Khởi tạo các cấu hình chỉ chạy một lần, ONE_CONFIGS.
  - Khởi tạo `~/hakucfg` nếu chưa có.
  - Thực hiện các bước cài đặt hệ thống tùy chọn để setup hakuspace cho lần đầu tiên bạn vào.
- Script cũng tạo backup cho các file bị ghi đè khi cài đặt nên bạn đừng lo mất cấu hình, chỉ cần vào `~/.backup/` là sẽ thấy các bản backup timestamped.

### `update.sh`

- Đây là script chạy để cập nhật dotfiles.
- Nó sẽ làm gì?
  - Cập nhật repository lên phiên bản mới nhất hoặc ổn định.
  - Chép các file cấu hình và script từ repository vào máy bạn.
  - Giữ nguyên các cấu hình trong ONE_CONFIGS, còn các file khác thì sẽ bị ghi đè.
- Script cũng tạo backup cho các file bị ghi đè khi cập nhật nên bạn đừng lo mất cấu hình, chỉ cần vào `~/.backup/` là sẽ thấy các bản backup timestamped.

### `rollback.sh`

- Đây là script chạy để khôi phục dotfiles từ bản backup.
- Nó sẽ làm gì?
  - Chuyển các file hiện tại sang ~/backup/Rollback_Backup_*.
  - Khôi phục các file và thư mục đã chọn từ bản backup.
- Chỉ khôi phục các file và thư mục được quản lý bởi install.sh và update.sh, các file khác trong ~/.config và ~/.local sẽ được giữ nguyên.

Xem tiếp: [Management](VN_management.md) để hiểu cách dotfiles được triển khai và quản lý trong thư mục home của bạn một cách an toàn nhất.
