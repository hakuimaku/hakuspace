#!/usr/bin/env python3
"""Exercise config transactions and explicit runtime targets in disposable homes."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("editor", ROOT / "src/core/backend/user/hakucfg_editor_ctl.py")
editor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(editor)


class Transactions(unittest.TestCase):
    """Never connect a test reload to the running desktop."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / "hakucfg/wm/niri-custom.kdl"
        self.config.parent.mkdir(parents=True)
        self.config.write_text("old\n")
        self.env = patch.dict(os.environ, HOME=str(self.home), XDG_STATE_HOME=str(self.home / "state"),
                              HAKUSPACE_HAKUCFG_ROOT=str(self.home / "hakucfg"), XDG_CURRENT_DESKTOP="niri",
                              HAKUSPACE_CONFIG_TEXT="new\n")
        self.env.start()
        self.addCleanup(self.env.stop)
        os.environ["HAKUSPACE_CONFIG_EXPECTED_REVISION"] = editor.read_file("wm/niri-custom.kdl")["revision"]

    def test_save_backup_and_restore(self):
        """Successful reloads update the revision and retain the previous bytes."""
        with patch.object(editor, "validate_candidate", return_value={"validatorUnavailable": True}), patch.object(editor, "reload_file"):
            result = editor.save_reload("wm/niri-custom.kdl")
            self.assertEqual(self.config.read_text(), "new\n")
            self.assertTrue(result["backupAvailable"])
            os.environ["HAKUSPACE_CONFIG_EXPECTED_REVISION"] = result["revision"]
            restored = editor.save_reload("wm/niri-custom.kdl", restore=True)
            self.assertEqual(restored["content"], "old\n")
            self.assertEqual(self.config.read_text(), "old\n")

    def test_validation_failure_never_changes_original(self):
        """Validation runs before candidate bytes replace the live config."""
        with patch.object(editor, "validate_candidate", side_effect=ValueError("validation failed")), patch.object(editor, "reload_file") as reload:
            with self.assertRaisesRegex(ValueError, "validation failed"):
                editor.save_reload("wm/niri-custom.kdl")
            reload.assert_not_called()
        self.assertEqual(self.config.read_text(), "old\n")

    def test_failed_reload_restores_bytes_and_reloads_previous(self):
        """Rollback preserves permissions and does not confirm the failed candidate."""
        self.config.chmod(0o640)
        with patch.object(editor, "validate_candidate", return_value={}), patch.object(editor, "reload_file", side_effect=[ValueError("reload failed"), None]) as reload:
            with self.assertRaisesRegex(ValueError, "previous file restored and reloaded"):
                editor.save_reload("wm/niri-custom.kdl")
            self.assertEqual(reload.call_count, 2)
        self.assertEqual(self.config.read_text(), "old\n")
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o640)

    def test_reload_timeout_rolls_back(self):
        """Timeouts follow the same guarded rollback path as command errors."""
        with patch.object(editor, "validate_candidate", return_value={}), patch.object(editor, "reload_file", side_effect=[subprocess.TimeoutExpired("reload", 15), None]):
            with self.assertRaisesRegex(ValueError, "previous file restored"):
                editor.save_reload("wm/niri-custom.kdl")
        self.assertEqual(self.config.read_text(), "old\n")

    def test_conflict_still_rejected(self):
        """External edits win over stale editor revisions."""
        self.config.write_text("external\n")
        with self.assertRaisesRegex(ValueError, "conflict:"):
            editor.save_reload("wm/niri-custom.kdl")
        self.assertEqual(self.config.read_text(), "external\n")

    def test_rollback_does_not_overwrite_concurrent_edit(self):
        """An external write during reload is retained with a recoverable backup."""
        def reload(_):
            self.config.write_text("external\n")
            raise ValueError("reload failed")
        with patch.object(editor, "validate_candidate", return_value={}), patch.object(editor, "reload_file", side_effect=reload):
            with self.assertRaisesRegex(ValueError, "rollback failed: conflict:"):
                editor.save_reload("wm/niri-custom.kdl")
        self.assertEqual(self.config.read_text(), "external\n")

    def test_niri_candidate_validation_and_unavailable(self):
        """Unavailable validators are distinguished from invalid configuration."""
        with patch.object(editor.shutil, "which", return_value=None):
            self.assertTrue(editor.validate_candidate("wm/niri-custom.kdl", "new")["validatorUnavailable"])
        with patch.object(editor.shutil, "which", return_value="niri"), patch.object(editor.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "parse error")):
            with self.assertRaisesRegex(ValueError, "validation failed: parse error"):
                editor.validate_candidate("wm/niri-custom.kdl", "new")
        self.assertEqual(self.config.read_text(), "old\n")
        self.assertFalse(list(self.config.parent.glob(".hakucfg-validate-*")))

    def test_explicit_runtime_setters(self):
        """Repeated targets preserve requested state without launching desktop processes."""
        state = self.home / ".local/state/hakuspace/state"
        state.mkdir(parents=True)
        (state / "[shell].backend").write_text("hikai\n")
        env = dict(os.environ, CAVA_PIDFILE=str(self.home / "cava.pid"))
        cases = [("src/core/facade/taskbar_manager.sh", ["--layout", "taskbar"], "[desktop].taskbar.requested", "1"),
                 ("src/core/facade/taskbar_manager.sh", ["--layout", "topbar"], "[desktop].taskbar.requested", "0"),
                 ("src/core/app/cava-layer/cava_manager.sh", ["--enabled", "on"], "[cava].enabled", "1"),
                 ("src/core/app/cava-layer/cava_manager.sh", ["--enabled", "off"], "[cava].enabled", "0"),
                 ("src/core/app/cava-layer/cava_manager.sh", ["--dynamic", "on"], "[cava].dynamic-position", "1"),
                 ("src/core/app/cava-layer/cava_manager.sh", ["--dynamic", "off"], "[cava].dynamic-position", "0"),
                 ("src/core/sys/idle_inhibit.sh", ["--set", "on"], "[system].idle-inhibit.enabled", "1"),
                 ("src/core/sys/idle_inhibit.sh", ["--set", "off"], "[system].idle-inhibit.enabled", "0")]
        for script, args, filename, expected in cases:
            for _ in range(2):
                result = subprocess.run(["bash", str(ROOT / script), *args], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((state / filename).read_text().strip(), expected)


if __name__ == "__main__":
    unittest.main()
