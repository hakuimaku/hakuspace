#!/usr/bin/env python3
"""Exercise chrome state migration and independent controllers in disposable homes."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src/core/backend/user"))
import hikai_chrome_state_ctl as chrome
import hikai_settings_ctl as settings


class ChromeStateTests(unittest.TestCase):
    """Keep migration and manager calls away from the installed session."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.path = self.home / "hakucfg/hikai/hikai-shell.json"
        self.state = self.home / ".local/state/hakuspace/state"
        self.path.parent.mkdir(parents=True)
        self.state.mkdir(parents=True)
        environment = patch.dict(os.environ, HOME=str(self.home), HAKUSPACE_HIKAI_SETTINGS_FILE=str(self.path))
        environment.start()
        self.addCleanup(environment.stop)

    def document(self, style, enabled):
        """Seed the old shared feature with explicit nondefault preferences."""
        values = copy.deepcopy(settings.DEFAULTS)
        values["version"] = 5
        values["dock"].update(style=style, iconSize=64, visibilityMode="always", exclusiveSpace=True)
        self.path.write_text(json.dumps(values))
        (self.state / "taskbar_manual_state").write_text(str(enabled))
        return values

    def assert_states(self, taskbar, dockbar):
        """Read both canonical files after migration or toggles."""
        self.assertEqual((self.state / "taskbar_manual_state").read_text().strip(), str(taskbar))
        self.assertEqual((self.state / "dockbar_manual_state").read_text().strip(), str(dockbar))

    def test_mapping_and_idempotence(self):
        """Legacy Full and compact choices survive, then independent edits stay intact."""
        for style, old, taskbar, dockbar in (("bar", 1, 1, 0), ("dock", 1, 0, 1), ("bar", 0, 0, 0), ("dock", 0, 0, 0)):
            with self.subTest(style=style, old=old):
                (self.state / "chrome-state-v6.json").unlink(missing_ok=True)
                original = self.document(style, old)
                chrome.migrate()
                self.assert_states(taskbar, dockbar)
                expected = original["dock"]
                del expected["style"]
                result = json.loads(self.path.read_text())
                self.assertEqual(result["version"], 6)
                self.assertEqual(result["dock"], expected)
                (self.state / "taskbar_manual_state").write_text("1\n")
                (self.state / "dockbar_manual_state").write_text("1\n")
                snapshot = self.path.read_bytes()
                chrome.migrate()
                self.assert_states(1, 1)
                self.assertEqual(self.path.read_bytes(), snapshot)

    def test_interrupted_migration_resumes_journal(self):
        """A crash between the two state writes cannot reinterpret the old mode."""
        self.document("dock", 1)
        with patch.object(chrome, "write_state", side_effect=[None, OSError("interrupted")]):
            with self.assertRaises(OSError):
                chrome.migrate()
        self.assertEqual(json.loads(self.path.read_text())["version"], 6)
        chrome.migrate()
        self.assert_states(0, 1)

    def test_invalid_files_do_not_mutate_state(self):
        """Bad settings and symlinked state entries stop the upgrade safely."""
        self.document("bar", 1)
        self.path.write_text("{broken")
        with self.assertRaises(ValueError):
            chrome.migrate()
        self.assertFalse((self.state / "chrome-state-v6.json").exists())
        self.document("bar", 1)
        outside = self.home / "outside"
        outside.write_text("1")
        (self.state / "taskbar_manual_state").unlink()
        (self.state / "taskbar_manual_state").symlink_to(outside)
        with self.assertRaises(OSError):
            chrome.migrate()
        self.assertEqual(outside.read_text(), "1")

    def test_independent_controllers(self):
        """Taskbar and Dockbar toggles touch only their own requested feature."""
        self.document("bar", 1)
        chrome.migrate()
        (self.state / "shell_backend").write_text("hikai\n")
        for name, args, expected in (("dockbar", ["--enable"], (1, 1)),
                                     ("taskbar", ["--toggle"], (0, 1)),
                                     ("dockbar", ["--toggle"], (0, 0)),
                                     ("taskbar", ["--toggle"], (1, 0))):
            result = subprocess.run([ROOT / f"src/core/facade/{name}_manager.sh", *args], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_states(*expected)

    def test_supervisor_migrates_before_shell_start(self):
        """Login and backend switching share one migration gate before spawning QML."""
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        supervisor = bin_dir / "qs_supervisor.sh"
        supervisor.write_text((ROOT / "src/core/sys/qs_supervisor.sh").read_text())
        (bin_dir / "haku_backend_lib.sh").write_text(
            'QS_BACKEND_NAME=hikai\nhaku_runtime_dir() { echo "$HOME"; }\n'
            'haku_backend_is() { test ! -f "$HOME/stopped"; }\nhaku_qs_alive() { return 1; }\n')
        for name, body in (("hikai_chrome_state_ctl.py", 'echo migrate >> "$HOME/order"'),
                           ("qs", 'echo shell >> "$HOME/order"\ntouch "$HOME/stopped"')):
            script = bin_dir / name
            script.write_text("#!/bin/sh\n" + body + "\n")
            script.chmod(0o755)
        result = subprocess.run(["bash", supervisor], env={**os.environ, "PATH": str(bin_dir) + ":" + os.environ["PATH"]},
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "order").read_text(), "migrate\nshell\n")


if __name__ == "__main__":
    unittest.main()
