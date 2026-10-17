#!/usr/bin/env python3
"""Exercise the shell preference contract without modifying installed settings."""
import importlib.util
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Keep standalone test runs from creating bytecode inside the deployable source tree.
sys.dont_write_bytecode = True

# Import the same controller used by the deployed shell.
ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "src/core/backend/user/hikai_settings_ctl.py"
SPEC = importlib.util.spec_from_file_location("hikai_settings_ctl", CONTROLLER)
ctl = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ctl)


class ShellSettingsTests(unittest.TestCase):
    """Keep each test inside a disposable canonical directory."""

    def setUp(self):
        """Create an isolated HOME override for backend operations."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "hakucfg/hikai-shell.json"
        self.environment = patch.dict(os.environ, HAKUSPACE_HIKAI_SETTINGS_FILE=str(self.path))
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def write(self, payload):
        """Submit a nested patch through the public payload environment variable."""
        with patch.dict(os.environ, HAKUSPACE_HIKAI_SETTINGS_JSON=json.dumps(payload)):
            return ctl.run("write")["values"]

    def test_missing_and_valid_read_check(self):
        """Missing files stay absent until the first write."""
        self.assertEqual(ctl.run("read")["values"], ctl.DEFAULTS)
        self.assertEqual(ctl.run("check")["values"], ctl.DEFAULTS)
        self.assertFalse(self.path.parent.exists())
        self.write({"appearance": {"baseRadius": 20}})
        self.assertEqual(ctl.run("read")["values"]["appearance"]["baseRadius"], 20)
        self.assertTrue(ctl.run("check")["ok"])
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o600)

    def test_multiple_fields_preserve_values_and_reset(self):
        """Patches retain unrelated preferences; reset persists the full defaults."""
        self.write({"appearance": {"baseRadius": 20, "surfaceTone": "soft"}, "topbar": {"tray": False}})
        values = self.write({"topbar": {"clock": False}})
        self.assertEqual(values["appearance"], {"baseRadius": 20, "surfaceTone": "soft"})
        self.assertFalse(values["topbar"]["tray"])
        self.assertFalse(values["topbar"]["clock"])
        self.assertTrue(values["topbar"]["notifications"])
        self.assertEqual(ctl.run("reset")["values"], ctl.DEFAULTS)
        self.assertEqual(ctl.run("read")["values"], ctl.DEFAULTS)

    def test_invalid_patch_never_changes_disk(self):
        """Exact types, schema version, enum and radius bounds are mandatory."""
        self.write({})
        original = self.path.read_bytes()
        patches = [{"appearance": {"baseRadius": value}} for value in (3, 25, True, 12.0, "12", None)]
        patches += [{"topbar": {"tray": value}} for value in (0, 1, "false", None)]
        patches += [{"roundedScreen": {"radius": value}} for value in (-1, 25, True, 20.0, "20", None)]
        patches += [{"roundedScreen": {"borderThickness": value}} for value in (-1, 7, True, 4.0, "4", None)]
        patches += [{"appearance": {"surfaceTone": "black"}}, {"version": True}, {"version": 3}, {"version": 1},
                    {"appearance": []}, {"topbar": {"logo": False}}, {"unknown": 1}, []]
        for payload in patches:
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                self.write(payload)
            self.assertEqual(self.path.read_bytes(), original)

    def test_invalid_document_and_payload(self):
        """Malformed or incomplete documents report failure without replacement."""
        self.path.parent.mkdir()
        for content in ("{broken", "[]", '{"version": 1}', json.dumps(dict(ctl.DEFAULTS, version=3))):
            self.path.write_text(content)
            for action in ("read", "check", "reset"):
                with self.subTest(action=action, content=content), self.assertRaises(ValueError):
                    ctl.run(action)
            self.assertEqual(self.path.read_text(), content)
        self.path.write_text(json.dumps(ctl.DEFAULTS))
        with patch.dict(os.environ, HAKUSPACE_HIKAI_SETTINGS_JSON="{broken"), self.assertRaises(ValueError):
            ctl.run("write")

    def test_symlink_and_nonregular_rejected(self):
        """Neither file symlinks, directory symlinks nor FIFOs can redirect reads/writes."""
        self.path.parent.mkdir()
        target = Path(self.temp.name) / "other.json"
        target.write_text(json.dumps(ctl.DEFAULTS))
        for dangling in (False, True):
            self.path.symlink_to(target if not dangling else target.with_suffix(".missing"))
            for action in ("read", "write", "check", "reset"):
                with self.assertRaises((OSError, ValueError)):
                    ctl.run(action)
            self.path.unlink()
        os.mkfifo(self.path)
        with self.assertRaises(ValueError):
            ctl.run("read")
        self.path.unlink()
        self.path.parent.rmdir()
        self.path.parent.symlink_to(Path(self.temp.name), target_is_directory=True)
        with self.assertRaises(OSError):
            ctl.run("reset")
        self.assertEqual(json.loads(target.read_text()), ctl.DEFAULTS)

    def test_atomic_replacement_and_failure_cleanup(self):
        """Open readers retain the old inode and failed replacements leave no temp file."""
        self.write({})
        self.path.chmod(0o640)
        with self.path.open() as old:
            inode = os.fstat(old.fileno()).st_ino
            self.write({"appearance": {"baseRadius": 24}})
            self.assertNotEqual(inode, self.path.stat().st_ino)
            self.assertEqual(json.load(old), ctl.DEFAULTS)
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o640)
        original = self.path.read_bytes()
        with patch.object(ctl.os, "replace", side_effect=OSError("test failure")), self.assertRaises(OSError):
            self.write({"appearance": {"baseRadius": 4}})
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(list(self.path.parent.iterdir()), [self.path])

    def test_cli_response(self):
        """The executable returns JSON on success and diagnostics on failure."""
        result = subprocess.run([str(CONTROLLER), "read"], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["values"], ctl.DEFAULTS)
        result = subprocess.run([str(CONTROLLER), "invalid"], text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_v1_migration_without_read_writes(self):
        """Read/check migrate in memory; the next explicit Apply persists version 2."""
        self.path.parent.mkdir()
        legacy = {"version": 1, "appearance": {"baseRadius": 24, "surfaceTone": "soft"}, "topbar": {"tray": False}}
        self.path.write_text(json.dumps(legacy))
        original = self.path.read_bytes()
        for action in ("read", "check"):
            data = ctl.run(action)
            self.assertTrue(data["needsMigration"])
            self.assertEqual(data["values"]["version"], 2)
            self.assertEqual(data["values"]["roundedScreen"], {"radius": 20, "borderThickness": 4})
            self.assertEqual(data["values"]["appearance"], legacy["appearance"])
            self.assertFalse(data["values"]["topbar"]["tray"])
            self.assertTrue(data["values"]["topbar"]["clock"])
            self.assertEqual(self.path.read_bytes(), original)
        self.write({})
        self.assertEqual(json.loads(self.path.read_text())["version"], 2)
        self.assertFalse(ctl.run("read")["needsMigration"])

    def test_rounded_ranges_and_independence(self):
        """Screen geometry accepts its full ranges without changing component radius."""
        for radius in (0, 4, 20, 24):
            for border in (0, 1, 4, 6):
                values = self.write({"roundedScreen": {"radius": radius, "borderThickness": border}})
                self.assertEqual(values["roundedScreen"], {"radius": radius, "borderThickness": border})
                self.assertEqual(values["appearance"]["baseRadius"], 12)


if __name__ == "__main__":
    unittest.main()
