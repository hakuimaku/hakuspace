#!/usr/bin/env python3
"""Exercise the seven Quick Actions toggles with isolated backend fixtures."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
import shutil


ROOT = Path(__file__).resolve().parents[3]
CONTROLLER = ROOT / "src/core/backend/system/quick_actions_ctl.py"


class QuickActionsControllerTest(unittest.TestCase):
    def test_status_facades_do_not_create_state(self):
        scripts = {
            "[desktop].taskbar.requested": ROOT / "src/core/facade/taskbar_manager.sh",
            "[desktop].dockbar.requested": ROOT / "src/core/facade/dockbar_manager.sh",
            "[desktop].icons.enabled": ROOT / "src/core/app/desktop-icons/desktop_icons_manager.sh",
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
        if [ "$current" = 1 ]; then echo 0 > "$state"; else echo 1 > "$state"; fi
        if [ "$name" = nightlight_toggle.sh ]; then sleep 2 & fi ;;
    taskbar_manager.sh|dockbar_manager.sh|desktop_icons_manager.sh|cava_manager.sh)
        if [ "$1" = --status ]; then
            if [ "$current" = 1 ]; then echo enabled; else echo disabled; fi
        elif [ "$current" = 1 ]; then echo 0 > "$state"; else echo 1 > "$state"; fi ;;
esac
"""
            names = ("nmcli", "bluetoothctl", "hyprsunset",
                     "idle_inhibit.sh", "nightlight_toggle.sh", "taskbar_manager.sh", "dockbar_manager.sh",
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
                    "taskbar", "dockbar", "desktopIcons", "cava")
            before = {name: (state_dir / name).read_text() for name in names}
            initial = json.loads(call("status").stdout)
            self.assertEqual(list(initial), list(keys))
            self.assertTrue(all(item == {"available": True, "enabled": False}
                                for item in initial.values()))
            self.assertEqual(before, {name: (state_dir / name).read_text() for name in names})
            for key in keys:
                started = time.monotonic()
                self.assertEqual(call("toggle", key).returncode, 0, key)
                if key == "nightLight":
                    self.assertLess(time.monotonic() - started, 1.5)
                snapshot = json.loads(call("status").stdout)
                self.assertTrue(snapshot[key]["enabled"], key)
                if key == "taskbar":
                    self.assertFalse(snapshot["dockbar"]["available"])
                    self.assertEqual(call("toggle", "dockbar").returncode, 1)
                    self.assertEqual((state_dir / "dockbar_manager.sh").read_text(), "0\n")
                self.assertEqual(call("toggle", key).returncode, 0, key)
                self.assertFalse(json.loads(call("status").stdout)[key]["enabled"], key)
            self.assertEqual(call("toggle", "dockbar").returncode, 0)
            self.assertEqual(call("toggle", "taskbar").returncode, 0)
            self.assertEqual(json.loads(call("status").stdout)["dockbar"], {"available": False, "enabled": True})
            self.assertEqual(call("toggle", "taskbar").returncode, 0)
            self.assertEqual(json.loads(call("status").stdout)["dockbar"], {"available": True, "enabled": True})
            self.assertEqual(call("toggle", "unknown").returncode, 2)

    def test_theme_chrome_actions_route_to_distinct_managers(self):
        """Theme actions use separate owners and reject unavailable native Dockbar toggles."""
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            bin_dir = home / ".local/bin"
            bin_dir.mkdir(parents=True)
            state = home / ".local/state/hakuspace/state"
            state.mkdir(parents=True)
            for source in (ROOT / "src/core/menu/hm_theme.sh", ROOT / "src/core/lib/haku_theme.sh",
                           ROOT / "src/core/lib/haku_state.sh", ROOT / "src/core/theme/accent_palette.py"):
                shutil.copy2(source, bin_dir / source.name)
            log = home / "calls"
            for feature in ("taskbar", "dockbar"):
                manager = bin_dir / (feature + "_manager.sh")
                manager.write_text('#!/bin/sh\nprintf "%s\\n" "${0##*/} $*" >> "$HOME/calls"\n')
                manager.chmod(0o755)
            environment = {**os.environ, "HOME": str(home)}

            def invoke(label):
                subprocess.run(["bash", bin_dir / "hm_theme.sh", label], env=environment, check=True)

            (state / "[shell].backend").write_text("hikai\n")
            (state / "[desktop].taskbar.requested").write_text("0\n")
            invoke("Taskbar Mode")
            invoke("Dockbar")
            deadline = time.monotonic() + 2
            while (not log.exists() or len(log.read_text().splitlines()) < 2) and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertCountEqual(log.read_text().splitlines(), ["taskbar_manager.sh --toggle", "dockbar_manager.sh --toggle"])
            log.unlink()
            (state / "[desktop].taskbar.requested").write_text("1\n")
            invoke("Dockbar")
            (state / "[shell].backend").write_text("classic\n")
            invoke("Dockbar")
            time.sleep(0.05)
            self.assertFalse(log.exists())


if __name__ == "__main__":
    unittest.main()
