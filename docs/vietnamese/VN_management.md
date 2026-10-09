# Dotfiles của tôi được quản lý như thế nào?

Bản tiếng Anh: [Management](../management.md).

Tài liệu này giải thích chi tiết cách HakuSpace triển khai và quản lý dotfiles an toàn trong máy tính của bạn. Chúng tôi sử dụng **Cơ chế Triển khai Lai (Hybrid Deployment)** để mang lại trải nghiệm tốt nhất.

## 1. Kiến trúc Cốt lõi

Thư mục gốc chứa toàn bộ cấu hình chuẩn (BASE) nằm tại `src/home/`:

```text
Repository                         Máy của bạn
-----------                        ---------
src/home/.config/*       ------->  ~/.config/*
src/core/*               ------->  ~/.local/bin/*
src/home/hakucfg/*       --copy->  ~/hakucfg/*
```

Khi cài đặt HakuSpace, bạn sẽ được quyền chọn 1 trong 2 cơ chế để phân phối cấu hình (`.config`) và các script (`core`):

### Chế độ 1: Symlink (Khuyên dùng)
Chế độ này sử dụng kỹ thuật **Deep Symlinking** (tương tự như công cụ GNU Stow nổi tiếng).
Thay vì link cả một thư mục lớn (như `~/.config/hypr`), hệ thống sẽ tạo các thư mục thật và chỉ tạo symlink cho từng file cụ thể bên trong.

- **Ưu điểm:** 
  - Khi các phần mềm tạo ra rác, cache, file log hay file trạng thái vào thư mục cấu hình của chúng, những file rác đó sẽ nằm lại trên máy của bạn thành các file thật. Chúng KHÔNG chui ngược vào Git repo làm bẩn lịch sử git của bạn.
  - Khi bạn chỉnh sửa cấu hình ở `~/.config`, file trong Git repo sẽ tự động cập nhật ngay lập tức.
- **Nhược điểm:** 
  - Nếu bạn tạo một file hoàn toàn mới trong `~/.config`, bạn phải tự copy file đó vào thư mục HakuSpace repo và chạy lại `update.sh` để biến nó thành symlink.

### Chế độ 2: Copy (Truyền thống)
Chế độ này đơn giản là copy đứt đoạn toàn bộ file từ Repo ra máy của bạn.

- **Ưu điểm:** Đơn giản, dễ hiểu, an toàn tuyệt đối.
- **Nhược điểm:** Mọi chỉnh sửa của bạn ở `~/.config` sẽ KHÔNG cập nhật vào Git repo. Bạn phải tự tay copy ngược lại vào Repo nếu muốn lưu trữ thay đổi.

Lựa chọn của bạn sẽ được lưu tại `~/.local/state/hakuspace/deploy_mode`. Các script `update.sh` và `rollback.sh` sau này sẽ tự động đọc file này để hành xử cho đúng.

## 2. Các Quy Tắc Đặc Biệt

Để tránh việc các phần mềm phá hỏng Repo của bạn, một số cấu hình tuân theo bộ quy tắc cực kỳ nghiêm ngặt:

### Nhóm `ONCE_CONFIGS` (Luôn Copy 1 lần)
Các phần mềm như Thunar, xfce4, mpv, btop... có thói quen tự ý ghi đè file cấu hình khi bạn thay đổi cài đặt bằng giao diện UI của chúng.
Nếu dùng symlink, chúng sẽ làm đứt symlink hoặc ghi đè file hỏng vào Repo. Do đó, các cấu hình này **LUÔN LUÔN** được triển khai bằng cơ chế Copy đứt đoạn. Hơn nữa, `update.sh` sẽ **bỏ qua (skip)** không bao giờ update ghi đè lại các cấu hình này, nhằm bảo vệ những tinh chỉnh cá nhân của bạn.

### Thư mục `hakucfg` (Không gian của riêng bạn)
HakuSpace được thiết kế để không bao giờ "dẫm đạp" lên dữ liệu cá nhân của bạn. Thư mục `~/hakucfg/` là nơi để bạn chứa các biến môi trường, tự khởi chạy (autostart) và các custom script riêng. Thư mục này được triển khai theo cơ chế Copy 1 lần và để yên đó vĩnh viễn.

## 3. Các Script Quản Trị

Chúng tôi cung cấp 3 công cụ chính để bạn quản trị hệ thống của mình:

### `install.sh`
Dành cho lần cài đặt đầu tiên. Nó sẽ hỏi bạn chọn Window Manager và Chế độ triển khai (Symlink/Copy), sau đó rải toàn bộ cấu hình ra máy.

### `update.sh`
Mỗi khi bạn lấy bản cập nhật mới từ GitHub của HakuSpace, hãy chạy `update.sh`. Nó sẽ tự đọc cấu hình cũ của bạn (Symlink hay Copy) và đồng bộ bản cập nhật ra ngoài máy một cách hoàn hảo, đồng thời né tránh an toàn nhóm `ONCE_CONFIGS`.

### `rollback.sh`
An toàn là trên hết! Trước khi bất kỳ file nào bị `install.sh` hay `update.sh` ghi đè lên, file gốc của bạn sẽ được cất gọn vào `~/.backup/Backup_<thời_gian>`.
Nếu bản cập nhật làm lỗi máy, hãy chạy `rollback.sh`:
- Nó sẽ quét cực kỳ thông minh qua `~/.config` và `~/.local/bin`.
- Nó chủ động xoá bỏ các symlink của HakuSpace (nếu có) trước khi khôi phục, nhằm chống lại hiệu ứng "dereference" tai hại có thể làm xoá nhầm file gốc trong Repo.
- Khôi phục chính xác các file cũ về đúng vị trí.

### `doctor.sh` (Bác sĩ toàn vẹn)
Nếu hệ thống có gì đó sai sai, hãy chạy `./doctor.sh`.
Nếu bạn đang dùng chế độ Symlink, bác sĩ sẽ quét toàn bộ `~/.config` và `~/.local/bin` để tìm:
- **Symlink bị gãy (Broken):** Những symlink trỏ vào khoảng không do file gốc bị xoá.
- **File bị ghi đè (Overwritten):** Đôi khi bạn vô tình mở file cấu hình bằng một text editor không hỗ trợ symlink, rồi lỡ tay bấm Lưu. Text editor đó sẽ bẻ gãy symlink và tạo ra một file thật. Bác sĩ sẽ phát hiện ra điều này và nhắc bạn chạy `update.sh` để khôi phục symlink.
