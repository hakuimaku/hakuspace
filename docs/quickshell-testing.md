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
- **Notification Daemon:** Because `swaync` is blocked, there is currently no notification daemon displayed on the desktop in M0-M1. This feature will be rewritten in M3.
- **Launcher (Super+R) & Notif (Super+N):** Temporarily disabled in QS mode because the corresponding IPC launcher/notif is not yet implemented. The Launcher/Notif UI will be developed in M4.
- **TopBar, Cava, Logo:** Currently just stubs or displaying placeholders due to missing data fetching logic (M2-M4).

> **Emergency Note:** The `Super+Esc` hotkey operates independently of any backend and can always be used to exit Hikai mode and return to Classic.

### M1 Additional Checks (Review 3):
1. **Live Reload Theme**: Change the accent using `change_theme.sh`; the colors of the bar and components must update immediately (without restarting QS).
2. **Live Reload State**: Run `echo 1 > ~/.local/state/hakuspace/state/waybar_manual_state` (or opaque_theme_state, rounded_screen_state); the QS UI must react instantly by toggling the module.
3. **Clean Logs**: Check `cat /run/user/1000/quickshell/by-id/*/log.qslog` and ensure there are no `TypeError`, `ReferenceError`, or singleton errors immediately after startup.
