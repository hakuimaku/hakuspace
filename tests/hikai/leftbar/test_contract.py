#!/usr/bin/env python3
"""Check Leftbar migration, rollback and the public layout compatibility API."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

# Exercise production persistence against disposable settings and boolean state.
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "src/core/backend/user"))
import hikai_settings_ctl as settings
import hikai_chrome_state_ctl as chrome


class LayoutContract(unittest.TestCase):
    """Keep each transaction independent from the installed desktop."""

    def setUp(self):
        """Seed a Hikai HOME with independent module and Dock preferences."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.path = self.home / "hakucfg/hikai/hikai-shell.json"
        self.path.parent.mkdir(parents=True)
        self.state = self.home / ".local/state/hakuspace/state"
        self.state.mkdir(parents=True)
        (self.state / "[shell].backend").write_text("hikai\n")
        self.taskbar = self.state / "[desktop].taskbar.requested"
        self.taskbar.write_text("0\n")
        self.values = copy.deepcopy(settings.DEFAULTS)
        self.values["topbar"].update(center=False, cava=False)
        self.path.write_text(json.dumps(self.values))
        self.env = patch.dict(os.environ, HOME=str(self.home), HAKUSPACE_HIKAI_SETTINGS_FILE=str(self.path))
        self.env.start()
        self.addCleanup(self.env.stop)

    def command(self, *args):
        """Use the same facade as Settings and user keybindings."""
        return subprocess.run(["bash", str(ROOT / "src/core/facade/taskbar_manager.sh"), *args],
                              capture_output=True, text=True)

    def test_v10_migration_preserves_preferences(self):
        """Old documents default to Top Bar without resetting module switches."""
        legacy = copy.deepcopy(self.values)
        legacy.pop("chrome")
        legacy["version"] = 10
        self.path.write_text(json.dumps(legacy))
        original = self.path.read_bytes()
        result = settings.run("read")
        self.assertEqual(result["values"], self.values)
        self.assertTrue(result["needsMigration"])
        self.assertEqual(self.path.read_bytes(), original)

    def test_repeated_switches_and_toggle_retain_left_edge(self):
        """Taskbar toggles restore the selected status edge through repeated reloads."""
        for _ in range(10):
            for layout in ("leftbar", "taskbar", "topbar", "leftbar"):
                result = self.command("--layout", layout)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.taskbar.read_text().strip(), "1" if layout == "taskbar" else "0")
            for enabled in ("1", "0"):
                self.assertEqual(self.command("--toggle").returncode, 0)
                self.assertEqual(self.taskbar.read_text().strip(), enabled)
                self.assertEqual(settings.run("read")["values"]["chrome"]["statusEdge"], "left")
            self.assertEqual(settings.run("read")["values"]["topbar"], self.values["topbar"])

    def test_layout_cycle_switches_between_top_and_left_excluding_taskbar(self):
        """Layout cycling toggles status edges without including Taskbar in the cycle."""
        self.assertEqual(settings.run("read")["values"]["chrome"]["statusEdge"], "top")
        self.assertEqual(self.taskbar.read_text().strip(), "0")

        # Topbar -> Leftbar
        result = self.command("--layout", "cycle")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(settings.run("read")["values"]["chrome"]["statusEdge"], "left")
        self.assertEqual(self.taskbar.read_text().strip(), "0")

        # Leftbar -> Topbar
        result = self.command("--layout", "cycle")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(settings.run("read")["values"]["chrome"]["statusEdge"], "top")
        self.assertEqual(self.taskbar.read_text().strip(), "0")

        # If Taskbar is enabled, cycling exits taskbar to the next status bar (left)
        self.command("--layout", "taskbar")
        self.assertEqual(self.taskbar.read_text().strip(), "1")
        result = self.command("--layout", "cycle")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(settings.run("read")["values"]["chrome"]["statusEdge"], "left")
        self.assertEqual(self.taskbar.read_text().strip(), "0")

        # In Classic mode, layout cycling is rejected
        (self.state / "[shell].backend").write_text("classic\n")
        result = self.command("--layout", "cycle")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Layout cycling is available in Hikai only", result.stderr)
        (self.state / "[shell].backend").write_text("hikai\n")

    def test_second_write_failure_rolls_back(self):
        """A failed boolean publication restores both fields before reporting failure."""
        with patch.object(chrome, "write_state", side_effect=[OSError("write failed"), None]):
            with self.assertRaises(OSError):
                chrome.set_layout("leftbar")
        self.assertEqual(settings.run("read")["values"], self.values)
        self.assertEqual(self.taskbar.read_text(), "0\n")
        self.assertTrue(json.loads((self.state / "[migration].hikai-layout-v11.json").read_text())["complete"])

    def test_publication_failures_restore_the_previous_pair(self):
        """Failures in either settings publication or journal completion remain recoverable."""
        for boundary in ("settings", "complete"):
            original = chrome.replace_file
            failed = False

            def publish(fd, name, values, mode):
                """Fail one selected boundary while allowing the guarded rollback to finish."""
                nonlocal failed
                matches = name == self.path.name if boundary == "settings" else values.get("complete") is True
                if matches and not failed:
                    failed = True
                    raise OSError("publication failed")
                return original(fd, name, values, mode)

            with self.subTest(boundary=boundary), patch.object(chrome, "replace_file", side_effect=publish):
                with self.assertRaises(OSError):
                    chrome.set_layout("leftbar")
            self.assertEqual(settings.run("read")["values"], self.values)
            self.assertEqual(self.taskbar.read_text(), "0\n")

    def test_crash_journal_recovers_at_startup(self):
        """Restart recovers an interrupted pair without reverting later module edits."""
        values = copy.deepcopy(self.values)
        values["chrome"]["statusEdge"] = "left"
        values["topbar"]["clock"] = False
        self.path.write_text(json.dumps(values))
        self.taskbar.write_text("1\n")
        (self.state / "[migration].hikai-layout-v11.json").write_text(json.dumps(
            {"complete": False, "edge": "top", "taskbar": False}))
        chrome.migrate()
        self.assertEqual(settings.run("read")["values"]["chrome"]["statusEdge"], "top")
        self.assertFalse(settings.run("read")["values"]["topbar"]["clock"])
        self.assertEqual(self.taskbar.read_text(), "0\n")

    def test_invalid_edge_and_classic_reject_leftbar(self):
        """Invalid values never replace preferences or leak Leftbar into Classic."""
        for edge in ("bottom", "LEFT", 1, None):
            with self.assertRaises(ValueError):
                settings.validate({"chrome": {"statusEdge": edge}}, partial=True)
        self.assertEqual(self.command("--layout", "sideways").returncode, 2)
        (self.state / "[shell].backend").write_text("classic\n")
        self.assertEqual(self.command("--layout", "leftbar").returncode, 2)
        self.assertEqual(settings.run("read")["values"], self.values)
        self.assertEqual(self.taskbar.read_text(), "0\n")


if __name__ == "__main__":
    unittest.main()
