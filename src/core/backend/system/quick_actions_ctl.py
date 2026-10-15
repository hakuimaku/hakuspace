#!/usr/bin/env python3
"""Read and toggle Sidebar Quick Actions through existing system owners."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


BIN_DIR = Path(os.environ.get("HAKUSPACE_QUICK_ACTIONS_BIN_DIR", Path.home() / ".local/bin"))
SCRIPTS = {
    "idleInhibit": ("idle_inhibit.sh", "--check", "--toggle"),
    "nightLight": ("nightlight_toggle.sh", "--check", None),
    "taskbar": ("taskbar_manager.sh", "--status", "--toggle"),
    "desktopIcons": ("desktop_icons_manager.sh", "--status", "--toggle"),
    "cava": ("cava_manager.sh", "--status", "toggle"),
}


# Keep failed or missing backends unavailable instead of guessing their state.
def command(argv, capture=True):
    try:
        output = subprocess.PIPE if capture else subprocess.DEVNULL
        return subprocess.run(argv, stdout=output, stderr=output, text=True, timeout=8, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None


# Read one authoritative state without mutating it.
def state(key):
    if key == "wifi":
        result = command(["nmcli", "radio", "wifi"]) if shutil.which("nmcli") else None
        value = result.stdout.strip().lower() if result and result.returncode == 0 else ""
        return {"available": value in ("enabled", "disabled"), "enabled": value == "enabled"}
    if key == "bluetooth":
        result = command(["bluetoothctl", "show"]) if shutil.which("bluetoothctl") else None
        powered = next((line.split(":", 1)[1].strip().lower() for line in result.stdout.splitlines()
                        if line.strip().startswith("Powered:")), "") if result and result.returncode == 0 else ""
        return {"available": powered in ("yes", "no"), "enabled": powered == "yes"}
    name, check_arg, _ = SCRIPTS[key]
    path = BIN_DIR / name
    if not path.is_file() or (key == "idleInhibit" and not shutil.which("hypridle")):
        return {"available": False, "enabled": False}
    if key == "nightLight":
        helper = "hyprsunset" if os.environ.get("XDG_CURRENT_DESKTOP") == "Hyprland" else "gammastep"
        if not shutil.which(helper):
            return {"available": False, "enabled": False}
    result = command([str(path), check_arg])
    if result is None:
        return {"available": False, "enabled": False}
    if key in ("idleInhibit", "nightLight"):
        valid_off = ("Allowed" if key == "idleInhibit" else "disabled") in result.stdout
        return {"available": result.returncode == 0 or (result.returncode == 1 and valid_off),
                "enabled": result.returncode == 0}
    value = result.stdout.strip().lower() if result.returncode == 0 else ""
    return {"available": value in ("enabled", "disabled"), "enabled": value == "enabled"}


# Toggle only a known, available action and let the caller refresh its state.
def toggle(key):
    current = state(key)
    if not current["available"]:
        print(f"quick-actions: {key} unavailable", file=sys.stderr)
        return 1
    if key == "wifi":
        argv = ["nmcli", "radio", "wifi", "off" if current["enabled"] else "on"]
    elif key == "bluetooth":
        argv = ["bluetoothctl", "power", "off" if current["enabled"] else "on"]
    else:
        name, _, toggle_arg = SCRIPTS[key]
        argv = [str(BIN_DIR / name)] + ([toggle_arg] if toggle_arg else [])
    result = command(argv, capture=False)
    if result is None or result.returncode != 0:
        print(f"quick-actions: could not toggle {key}", file=sys.stderr)
        return 1
    return 0


# Keep the CLI small so QML reads one snapshot after each completed toggle.
def main():
    keys = ("wifi", "bluetooth", *SCRIPTS)
    if sys.argv[1:] == ["status"]:
        print(json.dumps({key: state(key) for key in keys}))
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == "toggle" and sys.argv[2] in keys:
        return toggle(sys.argv[2])
    print("Usage: quick_actions_ctl.py status | toggle KEY", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
