# Cài đặt và phát triển bộ giao diện (Visual)

HakuSpace quản lý hai họ giao diện theo từng chế độ shell thông qua `scripts/setup.sh`:
- **Hikai:** `Hikaide` / `Hikaide-Light` (GTK), `Hikaide-Symbols` / `Hikaide-Symbols-Light` (icons), `Haku-Dark` / `Haku-Light` (cursor).
- **Classic:** `Cassettk` (GTK), `Cassetton` (icons), `Cassettsor` (cursor).

Người dùng thông thường chỉ giữ các tài nguyên đã cài đặt tại `~/.themes` và `~/.icons`: mã nguồn được tải tạm thời, biên dịch, kiểm chứng, cài đặt rồi tự động dọn dẹp.

```bash
./scripts/setup.sh setup
./scripts/setup.sh status
./scripts/setup.sh verify
```

## Chuyển đổi chế độ và đồng bộ Cursor

Khi lựa chọn hiện tại thuộc họ được quản lý (`Hikaide*` hoặc `Cassett*`), chuyển đổi giữa **Hikai** và **Classic** sẽ tự động chuyển GTK, bộ biểu tượng, symlink override `~/.config/gtk-4.0/gtk.css` và con trỏ chuột sang họ tương ứng của chế độ đích. Khi đổi chế độ Dark/Light trong Hikai, `Haku-*` cũng tự chuyển giữa `Haku-Dark` và `Haku-Light` nếu biến thể đích đã được cài đặt. Các theme hoặc con trỏ của bên thứ ba được giữ nguyên. Nếu thiếu tài nguyên của họ đích, hệ thống cảnh báo và giữ nguyên trạng thái hiện tại để tránh tình trạng nửa Hikaide nửa Cassett.

Khi tên con trỏ chuột thay đổi (`Haku-Dark` / `Haku-Light` ↔ `Cassettsor`), hệ thống cập nhật đồng bộ `gsettings`, `~/.icons/default/index.theme`, GTK `settings.ini` (khi đang dùng họ GTK/icon được quản lý), `~/.config/environment.d/90-hakuspace-cursor.conf`, `~/.config/labwc/environment.d/90-hakuspace-cursor.env`, môi trường `systemd --user` / D-Bus và cấu hình của 4 WM (`niri-style.kdl`, `hyprland-style.lua`, `mangowm-style.conf`) rồi reload compositor tương ứng.

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
