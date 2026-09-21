# Quản lý Dotfiles như thế nào?

Bản tiếng Anh: [Management](../management.md).

Tài liệu này giải thích cách HakuSpace cài đặt dotfiles an toàn vào máy bạn. Hệ thống dùng cơ chế **Hybrid Deployment**, nghĩa là bạn có thể chọn cách quản lý file!

## 1. Cách hoạt động

Repo chứa các file config gốc ở `src/home/`:

```text
Repository                         Máy của bạn
-----------                        ---------
src/home/.config/*       ------->  ~/.config/*
src/core/*               ------->  ~/.local/bin/*
src/home/hakucfg/*       --copy->  ~/hakucfg/*
```

Khi cài đặt, bạn chọn 1 trong 2 chế độ cho `.config` và các script `core`:

### Chế độ 1: Symlink (Khuyên dùng)
Dùng **Deep Symlinking** (giống GNU Stow).
Thay vì link nguyên thư mục (như `~/.config/hypr`), hệ thống tạo thư mục thật và chỉ symlink các file bên trong.

- **Ưu điểm:** 
  - Mấy file rác (cache, logs) của app sẽ nằm yên trên máy bạn, không bị chui vào Git repo làm bẩn lịch sử.
  - Bạn sửa file ở `~/.config` là nó tự cập nhật luôn vào Git repo.
- **Nhược điểm:** 
  - Nếu bạn tạo file mới toanh ở `~/.config`, bạn phải tự move nó vào Repo rồi chạy lại `update.sh` để link.

### Chế độ 2: Copy (Truyền thống)
Copy đứt đoạn toàn bộ file từ Repo ra máy bạn.

- **Ưu điểm:** Cực kỳ đơn giản, an toàn.
- **Nhược điểm:** Bạn sửa file ở `~/.config` sẽ không lưu vào Git repo. Bạn phải tự copy ngược lại nếu muốn lưu.

Chế độ bạn dùng không được lưu vào file trạng thái nào cả; thay vào đó, `update.sh` sẽ quét tự động (heuristically) cấu hình trong `~/.config` để nhận diện xem bạn đang dùng symlink hay copy, rồi tự động đồng bộ theo đúng phương pháp đó.

## 2. Luật đặc biệt

Không phải cái gì cũng symlink đâu. Để tránh app làm hỏng Repo của bạn, có vài luật như sau:

### `ONCE_CONFIGS` (Luôn Copy)
Mấy app như Thunar, xfce4, mpv, btop hay có trò tự ghi đè file config khi bạn chỉnh UI.
Để tránh đứt symlink, các config này **LUÔN** được copy đứt đoạn, dù bạn chọn chế độ nào. Hơn nữa, `update.sh` sẽ **bỏ qua** không update tụi nó để giữ lại các tùy chỉnh cá nhân của bạn!

### `hakucfg` (Không gian riêng của bạn)
HakuSpace không đụng vào đồ cá nhân của bạn. `~/hakucfg/` là nơi chứa biến môi trường, autostart và script riêng của bạn. Nó luôn được Copy một lần và để yên đó vĩnh viễn.

## 3. Các Script quản lý

Có 3 script chính để bạn lo liệu mọi thứ:

### `install.sh`
Chạy lần đầu. Nó sẽ hỏi bạn chọn Window Manager và chế độ (Symlink/Copy), rồi cài đặt mọi thứ.

### `update.sh`
Mỗi khi kéo update mới từ GitHub, chạy cái này. Nó tự biết bạn đang dùng chế độ nào và đồng bộ update ra máy (tất nhiên là né `ONCE_CONFIGS` ra!).

### `rollback.sh`
An toàn là bạn! Trước khi ghi đè gì, HakuSpace luôn backup ra `~/.backup/Backup_<thời_gian>`.
Lỡ update bị lỗi thì cứ chạy `rollback.sh`:
- Quét nhanh `~/.config` và `~/.local/bin`.
- Xóa an toàn các symlink để tránh lỡ tay xóa nhầm file gốc trong Repo.
- Khôi phục file cũ về đúng chỗ cũ.

### `doctor.sh` (Bác sĩ)
Nếu máy có vấn đề, hãy chạy `./doctor.sh`.
Nếu bạn đang dùng Symlink, bác sĩ sẽ quét để tìm:
- **Symlink gãy:** Mấy file gốc bị xóa mất.
- **File bị ghi đè:** Lỡ bạn mở symlink bằng text editor rồi lưu đè thành file thật, bác sĩ sẽ báo liền và nhắc bạn chạy `update.sh` để sửa.

---
**Tiếp theo:** [Thư viện Lõi (Core Libraries)](../core/lib.md) ➡️
