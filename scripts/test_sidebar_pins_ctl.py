#!/usr/bin/env python3
"""Check Sidebar pin validation and argv based launching."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE_PATH = Path(__file__).resolve().parents[1] / "src/core/backend/user/sidebar_pins_ctl.py"
SPEC = importlib.util.spec_from_file_location("sidebar_pins_ctl", MODULE_PATH)
PINS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PINS)


class SidebarPinsTest(unittest.TestCase):
    def test_missing_and_malformed_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(PINS, "CONFIG", Path(tmp) / "pins.json"):
                self.assertEqual(PINS.load_pins(), [])
                PINS.CONFIG.write_text(json.dumps([
                    {"label": "Good", "command": ["xdg-open", "/tmp/space here"]},
                    {"label": "Target", "target": "https://example.com/a b"},
                    {"label": "Bad", "command": "touch /tmp/unsafe"},
                    {"label": "", "command": ["true"]},
                ]), encoding="utf-8")
                pins = PINS.load_pins()
                self.assertEqual(len(pins), 2)
                self.assertEqual(pins[0]["command"][1], "/tmp/space here")
                self.assertEqual(pins[1]["command"], ["xdg-open", "https://example.com/a b"])

    def test_launch_preserves_arguments(self):
        pin = {"command": ["xdg-open", "$HOME/a file"], "cwd": "~/work"}
        with patch.object(PINS.subprocess, "Popen") as spawn:
            PINS.launch(pin)
            args, kwargs = spawn.call_args
            self.assertEqual(args[0], ["xdg-open", str(Path.home() / "a file")])
            self.assertEqual(kwargs["cwd"], str(Path.home() / "work"))

    def test_add_is_atomic_and_rejects_duplicates_and_invalid_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "pins.json"
            target = Path(tmp) / "my file.txt"
            target.write_text("hello", encoding="utf-8")
            config.write_text(json.dumps([{"label": "Old", "command": ["true"], "extra": 7}]))
            with patch.object(PINS, "CONFIG", config):
                PINS.add_pin("file", str(target))
                data = json.loads(config.read_text())
                self.assertEqual(data[0]["extra"], 7)
                self.assertEqual(data[1]["command"], ["xdg-open", str(target)])
                with self.assertRaises(ValueError):
                    PINS.add_pin("file", str(target))
                config.write_text(json.dumps([{"label": "Legacy", "command": ["xdg-open", str(target)]}]))
                with self.assertRaises(ValueError):
                    PINS.add_pin("file", str(target))
                desktop = Path(tmp) / "sample.desktop"
                desktop.write_text("[Desktop Entry]\nName=Sample App\nIcon=sample-app\n", encoding="utf-8")
                PINS.add_pin("app", str(desktop))
                saved_app = json.loads(config.read_text())[-1]
                self.assertEqual(saved_app["label"], "Sample App")
                self.assertEqual(saved_app["icon"], "sample-app")
                saved_app["icon"] = "󰀻"
                config.write_text(json.dumps([saved_app]), encoding="utf-8")
                self.assertEqual(PINS.load_pins()[0]["icon"], "sample-app")
                folder = Path(tmp) / "folder"
                folder.mkdir()
                PINS.add_pin("folder", str(folder))
                self.assertEqual(json.loads(config.read_text())[-1]["kind"], "folder")
                with self.assertRaises(ValueError):
                    PINS.add_pin("folder", str(target))
                config.write_text("broken json")
                with self.assertRaises(ValueError):
                    PINS.add_pin("file", str(target))
                self.assertEqual(config.read_text(), "broken json")


if __name__ == "__main__":
    unittest.main()
