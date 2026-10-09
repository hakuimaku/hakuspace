# HakuSpace Quickshell Testing Guide

This document tracks features that are currently implemented or disabled when running the Hikai backend, along with commands to verify the state of the system.

## Phase M0-M1: Environment & State

### 1. Independent Script Guards Verification
The manager scripts are not allowed to run Waybar, Taskbar, or Python scripts when in Hikai mode.

**Test Commands:**
```bash
~/.local/bin/haku_backend.sh set hikai

# Test running the managers
~/.local/bin/waybar_manager.sh --startup
~/.local/bin/taskbar_manager.sh --startup
~/.local/bin/rounded_screen_manager.sh --startup
~/.local/bin/edge_trigger_manager.sh --startup

# Check if any processes leaked through (Output must be EMPTY)
pgrep -x waybar
pgrep -x taskbar
pgrep -f '\.py'
```

### 2. Backend State Verification
Check if the state file saves correctly and the verify command passes.
**Test Command:**
```bash
~/.local/bin/haku_backend.sh --verify
```
Expected output: `Verification passed.` with no warnings about `swaync` or other running managers.

### 3. Haku Space Mode Script Integrity
Ensure the script uses the correct shebang and the logic works properly.
```bash
head -1 src/core/theme/haku_space_mode.sh
# Expected output: #!/usr/bin/env bash
```

### 4. Haku Pick (Picker) Verification
The Picker has been transitioned to a QML Overlay UI via Hikai IPC.
```bash
printf 'Option A\nOption B\nOption C\n' | ~/.local/bin/haku_pick.sh --prompt "Test Picker"
```
When executed, a Picker UI will pop up in the center of the screen. Select an Option using the arrow keys and Enter. The terminal will print the selected result. Pressing Esc will exit with code 1.

### 5. Features Temporarily Missing in QS mode (Hikai)
- **Notification Daemon:** swaync is temporarily allowed in Hikai mode and handles notifications until M3.
- **Launcher (Super+R) & Notif (Super+N):** Temporarily disabled in QS mode because the corresponding IPC launcher/notif is not yet implemented. The Launcher/Notif UI will be developed in M4.
- **TopBar, Cava, Logo:** Currently just stubs or displaying placeholders due to missing data fetching logic (M2-M4).

> **Emergency Note:** The `Super+Esc` hotkey operates independently of any backend and can always be used to exit Hikai mode and return to Classic.

### M1 Additional Checks (Review 3):
1. **Live Reload Theme**: Change the accent using `change_theme.sh`; the colors of the bar and components must update immediately (without restarting QS).
2. **Live Reload State**: Run `echo 1 > ~/.local/state/hakuspace/state/waybar_manual_state` (or opaque_theme_state, rounded_screen_state); the QS UI must react instantly by toggling the module.
3. **Clean Logs**: Check `cat /run/user/1000/quickshell/by-id/*/log.qslog` and ensure there are no `TypeError`, `ReferenceError`, or singleton errors immediately after startup.
4. **Picker Consecutive Execution**: Run the picker test (`printf 'A\nB\n' | haku_pick.sh --prompt "Test"`), select an option. Immediately run it again and select another option. Both must print the selected result correctly without hanging. Ensure `pgrep -af 'haku_pick'` is empty afterwards.
5. **Picker Resource Cleanup**: After using the picker, run `ls $XDG_RUNTIME_DIR/hakuspace`. There should be no leftover FIFO files (e.g., `picker_fifo_*`) or strange regular files created by mistake.

> **M3 Condition Check:** At M3, Quickshell's NotificationServer MUST acquire the D-Bus name `org.freedesktop.Notifications` *before* killing swaync and removing `QS_ALLOW_SWAYNC=1`. Once done, `--verify` will strictly block swaync again.

## M2.0 & M2.1 Cava and Workspaces Testing (Blind Coding)

**1. Cava Widget Test**
- Bật nhạc hoặc bất kỳ âm thanh nào trên hệ thống.
- Nhìn vào TopBar ở giữa màn hình (Center).
- Cava widget (icon nốt nhạc `󰎆`) phải hiện lên với các vạch nhảy lên xuống theo nhạc.
- Nếu không có âm thanh hoặc quá yên tĩnh, widget có thể ẩn. Hãy bật nhạc to lên một chút.
- Kiểm tra log `tail -f $XDG_RUNTIME_DIR/hakuspace/qs.log` xem có lỗi "Cava error" nào không (để test defensive coding).

**2. Workspaces Test**
- Mở nhiều ứng dụng và di chuyển qua các workspace (từ 1 đến 5).
- Nhìn vào TopBar bên trái (cạnh Logo).
- Viên nhộng (Workspace Pill) tương ứng với workspace hiện tại (focused) phải đổi màu sang màu nổi bật (`Theme.surfaceHi` và viền `Theme.accent`).
- Các workspace có ứng dụng đang mở (active) sẽ sáng hơn các workspace trống.
- Click chuột vào một viên nhộng bất kỳ để xem nó có chuyển workspace thành công không.
- Test trên **Hyprland** (bình thường). Nếu rảnh hãy test trên **Niri** (tự cài `niri` và chạy thử) xem `niri msg` event-stream có parse đúng không.

## M2.3 Monitor and Settings Groups Testing

**1. Monitor Group Test (CPU, RAM, Temp)**
- Click vào nút Monitor trên TopBar (phía phải màn hình, icon ``).
- Drawer sẽ mở ra từ phải sang trái. Icon mũi tên sẽ chuyển thành ``.
- Đảm bảo các ô chứa CPU, RAM, Temp hiển thị số liệu thực (so sánh bằng cách chạy lệnh `btop` hoặc `top` ở terminal).
- Click một lần nữa vào nút Monitor để đóng Drawer. Hãy đảm bảo Drawer mượt mà trượt lại vào góc phải.
- Kiểm tra lại bằng `top`: khi đóng, tiến trình poll của `SysStats` phải ngừng, không ăn CPU.

**2. Settings Group Test**
- Click vào nút Settings trên TopBar (icon ``).
- Drawer mở ra hiển thị các module: Độ sáng (Brightness), Âm thanh (Volume), Pin (Battery), và Power Profile.
- Nếu bạn chạy trên máy tính bàn, ô Độ sáng và Pin có thể tự động ẩn. Điều này là hoàn toàn bình thường.
- Thử cuộn chuột lên/xuống (scroll) trên ô Âm thanh. Âm thanh hệ thống phải thay đổi tương ứng. Click trái để Mute/Unmute. Click phải để mở `pavucontrol`.
- Thử cuộn chuột trên ô Độ sáng (nếu có). Độ sáng màn hình phải thay đổi.
- Thử click trái vào ô Power Profile (nếu có). Profile hệ thống phải thay đổi quay vòng (ví dụ từ `performance` sang `balanced`).
