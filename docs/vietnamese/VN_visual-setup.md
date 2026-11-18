# Cài đặt và phát triển bộ giao diện (Visual)

HakuSpace quản lý hai họ giao diện theo từng chế độ shell thông qua `scripts/setup.sh`:
- **Hikai:** `Hikaide` / `Hikaide-Light` (GTK), `Hikaide-Symbols` / `Hikaide-Symbols-Light` (icons), `Haku-*` (cursor).
- **Classic:** `Cassettk` (GTK), `Cassetton` (icons), `Cassettsor` (cursor).

Người dùng thông thường chỉ giữ các tài nguyên đã cài đặt tại `~/.themes` và `~/.icons`: mã nguồn được tải tạm thời, biên dịch, kiểm chứng, cài đặt rồi tự động dọn dẹp.

```bash
./scripts/setup.sh setup
./scripts/setup.sh status
./scripts/setup.sh verify
```

## Chuyển đổi chế độ và thông báo đăng xuất cho Cursor

Khi lựa chọn hiện tại thuộc họ được quản lý (`Hikaide*` hoặc `Cassett*`), chuyển đổi giữa **Hikai** và **Classic** sẽ tự động chuyển GTK, bộ biểu tượng, symlink override `~/.config/gtk-4.0/gtk.css` và con trỏ chuột sang họ tương ứng của chế độ đích. Các theme hoặc con trỏ của bên thứ ba được giữ nguyên. Nếu thiếu tài nguyên của họ đích, hệ thống cảnh báo và giữ nguyên trạng thái hiện tại để tránh tình trạng nửa Hikaide nửa Cassett.

Khi tên con trỏ chuột thực sự thay đổi giữa hai chế độ (`Haku-*` ↔ `Cassettsor`), hệ thống cập nhật `gsettings`, ghi `~/.config/environment.d/90-hakuspace-cursor.conf`, gọi `hyprctl setcursor` nếu đang chạy Hyprland, và gửi thông báo sau khi dịch vụ thông báo của chế độ đích (`SwayNC` ở Classic hoặc `Quickshell` ở Hikai) đã sẵn sàng:
- Biến `XCURSOR_THEME` trong `environment.d` chỉ được đọc khi khởi động phiên đăng nhập; các ứng dụng đang mở và XWayland giữ lại con trỏ cũ.
- Hyprland đổi được ngay con trỏ của compositor qua `hyprctl setcursor`, trong khi Niri, MangoWM và labwc không có lệnh tương đương ở thời điểm chạy nên cần đăng xuất và đăng nhập lại để áp dụng đồng nhất cho mọi ứng dụng.

## Nguồn phát triển cục bộ

Có thể chỉ định đường dẫn tuyệt đối tới các repo cục bộ khi phát triển:

| Thành phần | Biến môi trường nguồn |
| --- | --- |
| `cursor` | `HAKU_CURSOR_SOURCE` |
| `gtk` | `HAKU_GTK_THEME_SOURCE` |
| `symbols` | `HAKU_ICON_THEME_SOURCE` |
| `cassettk` | `CASSETTK_SOURCE` |
| `cassetton` | `CASSETTON_SOURCE` |
| `cassettsor` | `CASSETTSOR_SOURCE` |
