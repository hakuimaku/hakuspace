#!/usr/bin/env python3
"""Exercise the seven Quick Actions toggles with isolated backend fixtures."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "src/core/backend/system/quick_actions_ctl.py"


class QuickActionsControllerTest(unittest.TestCase):
    def test_status_facades_do_not_create_state(self):
        scripts = {
            "taskbar_manual_state": ROOT / "src/core/facade/taskbar_manager.sh",
            "desktop_icons_state": ROOT / "src/core/app/desktop-icons/desktop_icons_manager.sh",
        }
        cava = ROOT / "src/core/app/cava-layer/cava_manager.sh"
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            env = {**os.environ, "HOME": str(home)}
            state_dir = home / ".local/state/hakuspace/state"
            for script in scripts.values():
                result = subprocess.run([script, "--status"], env=env, capture_output=True, text=True)
                self.assertEqual((result.returncode, result.stdout), (0, "disabled\n"))
            result = subprocess.run([cava, "--status"], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)
            self.assertIn(result.stdout, ("enabled\n", "disabled\n"))
            self.assertFalse((home / ".local").exists())
            state_dir.mkdir(parents=True)
            for name, script in scripts.items():
                state_file = state_dir / name
                state_file.write_text("1\n", encoding="utf-8")
                result = subprocess.run([script, "--status"], env=env, capture_output=True, text=True)
                self.assertEqual((result.returncode, result.stdout), (0, "enabled\n"))
                self.assertEqual(state_file.read_text(), "1\n")

    def test_status_and_toggles_use_backend_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bin_dir = root / "bin"
            state_dir = root / "state"
            bin_dir.mkdir()
            state_dir.mkdir()
            fixture = """#!/bin/sh
name=${0##*/}
state=$TEST_STATE_DIR/$name
read -r current < "$state"
case "$name" in
    nmcli)
        if [ "$3" = "on" ]; then echo 1 > "$state"; exit 0; fi
        if [ "$3" = "off" ]; then echo 0 > "$state"; exit 0; fi
        if [ "$current" = 1 ]; then echo enabled; else echo disabled; fi ;;
    bluetoothctl)
        if [ "$1" = power ]; then
            if [ "$2" = on ]; then echo 1 > "$state"; else echo 0 > "$state"; fi
        elif [ "$current" = 1 ]; then echo 'Powered: yes'; else echo 'Powered: no'; fi ;;
    idle_inhibit.sh|nightlight_toggle.sh)
        if [ "$1" = --check ]; then
            if [ "$current" = 1 ]; then echo enabled; exit 0; fi
            if [ "$name" = idle_inhibit.sh ]; then echo Allowed; else echo disabled; fi
            exit 1
        fi
        if [ "$current" = 1 ]; then echo 0 > "$state"; else echo 1 > "$state"; fi ;;
    taskbar_manager.sh|desktop_icons_manager.sh|cava_manager.sh)
        if [ "$1" = --status ]; then
            if [ "$current" = 1 ]; then echo enabled; else echo disabled; fi
        elif [ "$current" = 1 ]; then echo 0 > "$state"; else echo 1 > "$state"; fi ;;
esac
"""
            names = ("nmcli", "bluetoothctl", "hypridle", "hyprsunset",
                     "idle_inhibit.sh", "nightlight_toggle.sh", "taskbar_manager.sh",
                     "desktop_icons_manager.sh", "cava_manager.sh")
            for name in names:
                path = bin_dir / name
                path.write_text(fixture, encoding="utf-8")
                path.chmod(0o755)
                (state_dir / name).write_text("0\n", encoding="utf-8")
            env = {**os.environ, "PATH": str(bin_dir) + os.pathsep + "/bin",
                   "TEST_STATE_DIR": str(state_dir),
                   "HAKUSPACE_QUICK_ACTIONS_BIN_DIR": str(bin_dir),
                   "XDG_CURRENT_DESKTOP": "Hyprland"}

            def call(*args):
                return subprocess.run([sys.executable, CONTROLLER, *args], env=env,
                                      capture_output=True, text=True, check=False)

            keys = ("wifi", "bluetooth", "idleInhibit", "nightLight",
                    "taskbar", "desktopIcons", "cava")
            before = {name: (state_dir / name).read_text() for name in names}
            initial = json.loads(call("status").stdout)
            self.assertEqual(list(initial), list(keys))
            self.assertTrue(all(item == {"available": True, "enabled": False}
                                for item in initial.values()))
            self.assertEqual(before, {name: (state_dir / name).read_text() for name in names})
            for key in keys:
                self.assertEqual(call("toggle", key).returncode, 0, key)
                self.assertTrue(json.loads(call("status").stdout)[key]["enabled"], key)
                self.assertEqual(call("toggle", key).returncode, 0, key)
                self.assertFalse(json.loads(call("status").stdout)[key]["enabled"], key)
            self.assertEqual(call("toggle", "unknown").returncode, 2)


if __name__ == "__main__":
    unittest.main()
