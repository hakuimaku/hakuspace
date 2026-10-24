#!/usr/bin/env python3
"""Verify Hikai configuration deployment and migration inside disposable homes."""
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]


class HikaiConfigTests(unittest.TestCase):
    """Run the real installer and controllers without touching installed settings."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / "hakucfg"
        self.config.mkdir()
        self.hikai = self.config / "hikai"
        self.env = {**os.environ, "HOME": str(self.home), "HAKU_DIR": str(ROOT),
                    "BACKUP_DIR": str(self.home / "backups"), "PYTHONDONTWRITEBYTECODE": "1"}
        self.env.pop("HAKUSPACE_HIKAI_SETTINGS_FILE", None)
        self.defaults = self.controller("hikai_settings_ctl.py", "read")["values"]

    def controller(self, name, *args):
        """Read the deployed CLI response using its default HOME-relative location."""
        result = subprocess.run([str(ROOT / "src/core/backend/user" / name), *args],
                                env=self.env, text=True, capture_output=True, check=True)
        return json.loads(result.stdout)

    def sync(self, success=True):
        """Exercise template seeding and migration through the public sync command."""
        result = subprocess.run(["bash", str(ROOT / "scripts/hakucfg.sh"), "sync", "--yes"],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def test_fresh_install_and_default_paths(self):
        self.sync()
        self.assertTrue(self.hikai.is_dir())
        result = self.controller("hikai_settings_ctl.py", "read")
        self.assertEqual(result["path"], str(self.hikai / "hikai-shell.json"))
        self.assertEqual(result["values"], self.defaults)
        self.assertFalse((self.hikai / "hikai-shell.json").exists())

    def test_migration_preserves_content_modes_and_subsequent_writes(self):
        settings = {**self.defaults, "appearance": {"baseRadius": 18, "surfaceTone": "soft"}}
        old = self.config / "hikai-shell.json"
        old.write_text(json.dumps(settings, indent=3) + "\n")
        old.chmod(0o640)
        original = {path.name: path.read_bytes() for path in self.config.iterdir()}
        self.sync()
        self.sync()
        for name, contents in original.items():
            self.assertFalse((self.config / name).exists())
            self.assertEqual((self.hikai / name).read_bytes(), contents)
            self.assertEqual(stat.S_IMODE((self.hikai / name).stat().st_mode), 0o640)
        self.assertEqual(self.controller("hikai_settings_ctl.py", "read")["values"], settings)
        self.env["HAKUSPACE_HIKAI_SETTINGS_JSON"] = '{"dock":{"hoverScale":37}}'
        self.assertEqual(self.controller("hikai_settings_ctl.py", "write")["values"]["dock"]["hoverScale"], 37)
        self.assertFalse((self.config / "hikai-shell.json").exists())

    def test_existing_destinations_take_precedence_without_deleting_legacy(self):
        self.hikai.mkdir()
        (self.config / "hikai-shell.json").write_text("legacy content")
        (self.hikai / "hikai-shell.json").write_text("existing destination")
        self.sync()
        self.assertEqual((self.config / "hikai-shell.json").read_text(), "legacy content")
        self.assertEqual((self.hikai / "hikai-shell.json").read_text(), "existing destination")

    def test_symlinked_directory_is_not_migrated(self):
        outside = self.home / "outside"
        outside.mkdir()
        self.hikai.symlink_to(outside, target_is_directory=True)
        (self.config / "hikai-shell.json").write_text("legacy")
        self.sync(success=False)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual((self.config / "hikai-shell.json").read_text(), "legacy")

    def test_symlinked_settings_are_not_migrated_or_overwritten(self):
        outside = self.home / "outside.json"
        outside.write_text("preserve")
        legacy = self.config / "hikai-shell.json"
        legacy.symlink_to(outside)
        self.sync(success=False)
        self.assertTrue(legacy.is_symlink())
        legacy.unlink()
        destination = self.hikai / "hikai-shell.json"
        destination.symlink_to(outside)
        self.sync(success=False)
        self.assertTrue(destination.is_symlink())
        self.assertEqual(outside.read_text(), "preserve")


if __name__ == "__main__":
    unittest.main()
