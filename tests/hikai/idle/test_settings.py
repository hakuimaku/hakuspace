#!/usr/bin/env python3
"""Validate native idle migration, patching, and fail-safe timeout ordering."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

# Reuse the deployed controller without writing installed preferences.
ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("idle_settings_ctl", ROOT / "src/core/backend/user/hikai_settings_ctl.py")
ctl = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ctl)


class IdleSettingsTests(unittest.TestCase):
    """Keep all preference writes in a temporary canonical path."""

    def test_v7_migration_preserves_choices(self):
        """Inject independent native defaults without parsing the Classic config."""
        original = copy.deepcopy(ctl.DEFAULTS)
        original.pop("idle")
        original["version"] = 7
        original["appearance"]["baseRadius"] = 18
        original["dock"]["iconSize"] = 48
        snapshot = copy.deepcopy(original)
        values, migrated = ctl.migrate(original)
        self.assertTrue(migrated)
        self.assertEqual(original, snapshot)
        self.assertEqual(values["appearance"], original["appearance"])
        self.assertEqual(values["dock"], original["dock"])
        self.assertEqual(values["idle"], ctl.DEFAULTS["idle"])
        self.assertEqual(ctl.migrate(values), (values, False))

    def test_invalid_types_ranges_and_keys(self):
        """Reject unknown keys, loose boolean types, out-of-range numeric fields, and non-multiples of 10."""
        for patch_value in ({"unknown": True}, {"enabled": 1}, {"dimTimeout": True},
                            {"dimTimeout": 9}, {"dimTimeout": 11}, {"suspendTimeout": 86401}, {"dimPercent": 0},
                            {"dimPercent": 101}, {"respectAppInhibitors": "true"}):
            with self.subTest(value=patch_value), self.assertRaises(ValueError):
                ctl.validate({"idle": patch_value}, partial=True)

    def test_merged_ordering_and_disabled_stages(self):
        """Timeouts must be multiples of 10, while stages can be set to independent round timeouts."""
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, HAKUSPACE_HIKAI_SETTINGS_FILE=tmp + "/hikai-shell.json"):
            def write(idle):
                """Submit an idle-only partial patch through the public API."""
                with patch.dict(os.environ, HAKUSPACE_HIKAI_SETTINGS_JSON=json.dumps({"idle": idle})):
                    return ctl.run("write")["values"]
            values = write({"dimPercent": 12})
            self.assertEqual(values["idle"]["dimTimeout"], 300)
            original = Path(tmp + "/hikai-shell.json").read_bytes()
            for idle in ({"lockTimeout": 201}, {"dimTimeout": 405}, {"suspendTimeout": 307}):
                with self.subTest(idle=idle), self.assertRaises(ValueError):
                    write(idle)
                self.assertEqual(Path(tmp + "/hikai-shell.json").read_bytes(), original)
            # Equal or non-increasing round timeouts are accepted
            values = write({"dimTimeout": 10, "lockTimeout": 10})
            self.assertEqual(values["idle"]["dimTimeout"], 10)
            self.assertEqual(values["idle"]["lockTimeout"], 10)
            values = write({"dimEnabled": False, "lockTimeout": 120, "displayOffTimeout": 180, "suspendTimeout": 600})
            self.assertEqual(values["idle"]["dimPercent"], 12)
            self.assertEqual(values["appearance"], ctl.DEFAULTS["appearance"])


if __name__ == "__main__":
    unittest.main()
