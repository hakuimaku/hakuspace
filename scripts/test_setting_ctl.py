#!/usr/bin/env python3
"""Deterministic tests for the installed setting.sh controller."""
import json
import os
import re
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "src/core/backend/user/setting_ctl.py"
TEMPLATE = ROOT / "src/home/hakucfg/setting.sh"


class SettingCtlTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "setting.sh"
        shutil.copyfile(TEMPLATE, self.path)
        self.path.chmod(0o755)

    def call(self, action, payload=None, success=True):
        env = dict(os.environ, HAKUSPACE_SETTING_FILE=str(self.path))
        if payload is not None:
            env["HAKUSPACE_SETTINGS_JSON"] = json.dumps(payload)
        result = subprocess.run([str(CONTROLLER), action], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return json.loads(result.stdout) if success else result.stderr

    def test_read_canonical(self):
        data = self.call("read")
        self.assertEqual(len(data["values"]), 18)
        self.assertEqual(data["settingVersion"], "26.09-2")
        self.assertEqual(data["values"]["WAYBAR_MODE_USER"], [])
        assignments = set(re.findall(r"^([A-Z_]+)=", TEMPLATE.read_text(), re.M))
        self.assertEqual(set(data["values"]), assignments - {"SETTING_VERSION"})
        self.assertEqual(data["values"]["EXIT_APP_LIST_USER"], [])
        self.assertEqual(data["values"]["SCREENSHOT_DIR"], "$HOME/Pictures/Screenshots")
        self.call("check")
        catalog = (ROOT / "src/home/.config/quickshell/hakuspace/services/SettingsStore.qml").read_text()
        self.assertEqual(set(re.findall(r'key: "([A-Z_]+)"', catalog)), set(data["values"]))
        self.assertIn('group: "Haku Widget"', catalog)
        self.assertIn('readonly property var groups: ["General"]', catalog)

    def test_writes_and_preservation(self):
        original = self.path.read_text()
        self.path.write_text(original + '\nCUSTOM="safe"\n# keep me\ncustom_fn() { :; }\n')
        before = self.path.read_text()
        payload = {
            "WELCOME_MSG": False, "NIGHT_LIGHT_TEMPERATURE": 4200,
            "RAM_THRESHOLD_MB": 512, "ACCENT_COLOR_MODE": "saturated",
            "SCREENSHOT_DIR": '$HOME/Pictures/a b # c',
            "AWWW_OPTS": 'spaces # "quotes" $USER `date` \\ fine',
            "REC_OPTS": "", "EXIT_APP_LIST_USER": ["one", "two words", 'a"$`\\b'],
            "WAYBAR_MODE_USER": ["custom", "theme with spaces", 'a"$`\\b'],
        }
        data = self.call("write", payload)
        self.assertEqual({key: data["values"][key] for key in payload}, payload)
        self.assertIn('WALL_MPV_DIR="$HOME/Videos/Wallpapers" # For lively wallpaper videos', self.path.read_text())
        self.assertTrue(self.path.read_text().endswith('\nCUSTOM="safe"\n# keep me\ncustom_fn() { :; }\n'))
        self.assertIn('WALL_INTERVAL=300 # Interval in seconds', self.path.read_text())
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o755)
        self.assertEqual(subprocess.run(["bash", "-n", str(self.path)]).returncode, 0)
        self.assertNotEqual(before, self.path.read_text())
        self.assertEqual(self.call("read")["values"]["EXIT_APP_LIST_USER"], payload["EXIT_APP_LIST_USER"])
        self.call("write", {"EXIT_APP_LIST_USER": []})
        self.assertEqual(self.call("read")["values"]["EXIT_APP_LIST_USER"], [])

    def test_inline_comment_and_unchanged_lines(self):
        before = self.path.read_text()
        self.call("write", {"WALL_INTERVAL": 420})
        self.assertEqual(self.path.read_text(), before.replace("WALL_INTERVAL=300 #", "WALL_INTERVAL=420 #"))

    def test_unsupported_waybar_is_preserved(self):
        self.path.write_text(self.path.read_text().replace("WAYBAR_MODE_USER=()", "WAYBAR_MODE_USER=$(printf custom)"))
        before = self.path.read_text()
        self.call("write", {"WELCOME_MSG": False})
        self.assertEqual(self.path.read_text(), before.replace("WELCOME_MSG=true", "WELCOME_MSG=false"))

    def test_invalid_does_not_write(self):
        before = self.path.read_bytes()
        for payload in ({"ACCENT_COLOR_MODE": "wrong"}, {"NIGHT_LIGHT_TEMPERATURE": 0},
                        {"WELCOME_MSG": "false"}, {"SETTING_VERSION": "x"}, {"UNKNOWN": 1},
                        {"WAYBAR_MODE_USER": "custom"},
                        {"REC_COMMAND": "foo\nbar"}, {"REC_COMMAND": ""}, {"REC_OPTS": "bad\0value"}):
            self.call("write", payload, False)
            self.assertEqual(self.path.read_bytes(), before)

    def test_missing_unsupported_and_duplicates(self):
        self.path.write_text(self.path.read_text().replace("WELCOME_MSG=true", "# WELCOME_MSG=true"))
        self.assertIn("WELCOME_MSG", self.call("read")["missingKeys"])
        self.call("write", {"WELCOME_MSG": False}, False)
        self.path.write_text(self.path.read_text().replace("WALL_INTERVAL=300", "WALL_INTERVAL=$(date)"))
        self.assertIn("WALL_INTERVAL", self.call("read")["unsupportedKeys"])
        self.call("check", success=False)
        self.call("write", {"WALL_INTERVAL": 500}, False)
        self.path.write_text(self.path.read_text() + "\nRAM_THRESHOLD_MB=400\n")
        self.assertIn("RAM_THRESHOLD_MB", self.call("read")["duplicateKeys"])
        self.call("write", {"REC_OPTS": "hello"}, False)

    def test_bash_syntax_failure_is_atomic(self):
        self.path.write_text(self.path.read_text() + "\nif then\n")
        before = self.path.read_bytes()
        self.call("write", {"WELCOME_MSG": False}, False)
        self.assertEqual(self.path.read_bytes(), before)
        self.call("check", success=False)

    def test_unquoted_home_expression(self):
        self.path.write_text(self.path.read_text().replace('SCREENSHOT_DIR="$HOME/Pictures/Screenshots"', 'SCREENSHOT_DIR=${HOME}/Pictures/Screenshots'))
        self.assertEqual(self.call("read")["values"]["SCREENSHOT_DIR"], '${HOME}/Pictures/Screenshots')

    def test_literal_home_stays_literal(self):
        self.path.write_text(self.path.read_text().replace('SCREENSHOT_DIR="$HOME/Pictures/Screenshots"', "SCREENSHOT_DIR='$HOME/literal'"))
        self.call("write", {"SCREENSHOT_DIR": "$HOME/changed"})
        self.assertIn('SCREENSHOT_DIR="\\$HOME/changed"', self.path.read_text())

    def test_crlf_invalid_file_is_untouched(self):
        before = self.path.read_bytes().replace(b"\n", b"\r\n")
        self.path.write_bytes(before)
        self.call("write", {"WELCOME_MSG": False}, False)
        self.assertEqual(self.path.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
