#!/usr/bin/env python3
"""Check private lock profiling boundaries and native power/PAM report contracts."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

# Load the existing profiler without starting a compositor at import time.
ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("lock_profile", ROOT / "tools/profiling/hikai_memory_soak.py")
profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profile)


class LockProfileChecks(unittest.TestCase):
    """Use only disposable lock sessions; never send power requests to the main display."""

    def test_power_rejects_nonprivate_display(self):
        with patch.dict(os.environ, {"XDG_RUNTIME_DIR": "/tmp/private-lock-test", "WAYLAND_DISPLAY": "/run/user/1000/wayland-1",
                                    "HAKUSPACE_MEMORY_SHELL": "/tmp/private-lock-test/shell.qml"}):
            with self.assertRaisesRegex(RuntimeError, "private compositor"):
                profile.set_display_power(False)

    def test_native_profile_contract(self):
        with tempfile.TemporaryDirectory(prefix="hikai-lock-profile-test-") as temporary:
            output = Path(temporary) / "profile.json"
            result = subprocess.run([sys.executable, str(ROOT / "tools/profiling/hikai_memory_soak.py"),
                "--headless", "--lock-profile", "normal", "--output", str(output),
                "--warmup", "4", "--seconds", "0.2", "--interval", "0.1", "--cycles", "0",
                "--lock-off-seconds", "0.4", "--lock-repeats", "1", "--settle", "0.2"],
                capture_output=True, text=True, timeout=45)
            log = output.with_suffix(".log").read_text() if output.with_suffix(".log").exists() else ""
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr + log)
            report = json.loads(output.read_text())
            self.assertTrue(report["complete"])
            self.assertTrue(report["displayOffFrozen"])
            phases = {sample["phase"]: sample for sample in report["samples"]}
            for surface in phases["display-off-settled"]["runtime"]["surfaces"]:
                self.assertFalse(surface["idleAnimationRunning"])
                self.assertFalse(surface["displayActive"])
                self.assertTrue(surface["quiescent"])
            self.assertFalse(phases["unlocked-initial"]["runtime"]["lock"]["locked"])
            for phase in ("display-off", "display-off-settled", "display-on", "lock-repeated"):
                state = phases[phase]["runtime"]
                self.assertTrue(state["lock"]["locked"] and state["lock"]["secure"])
                self.assertEqual(len(state["surfaces"]), 2)
            self.assertEqual(phases["lock-released"]["runtime"]["surfaces"], [])
            self.assertEqual(phases["display-off"]["runtime"]["lock"]["lockSessionId"],
                             phases["display-on"]["runtime"]["lock"]["lockSessionId"])
            self.assertGreater(phases["lock-repeated"]["runtime"]["lock"]["lockSessionId"],
                               phases["display-on"]["runtime"]["lock"]["lockSessionId"])


if __name__ == "__main__":
    unittest.main()
