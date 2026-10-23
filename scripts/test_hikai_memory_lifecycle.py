#!/usr/bin/env python3
"""Exercise lifecycle, notification bounds and poll coalescing in an isolated QML engine."""
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from hikai_memory_soak import plateau, sample

# Keep generated preferences, logs and socket files outside the checkout.
ROOT = Path(__file__).resolve().parents[1]


class MemoryChecks(unittest.TestCase):
    """Check sampler math and the production QML lifecycle contracts."""

    def test_sampler(self):
        values = sample(os.getpid())
        self.assertGreater(values["rssKiB"], 0)
        self.assertGreater(values["fdCount"], 0)
        self.assertGreater(values["threadCount"], 0)
        self.assertEqual(plateau([{"phase": "idle", "elapsedSec": 0, "pssKiB": 100},
                                  {"phase": "idle", "elapsedSec": 60, "pssKiB": 110}], "pssKiB"), 10)
        self.assertIsNone(plateau([], "pssKiB"))

    def test_dynamic_owners(self):
        # These owners either destroy children explicitly or die with the configuration.
        owners = {
            "services/WM/WM.qml": ("root",),
            "components/actionmenu/ActionMenuSurface.qml": ("pageStackHost", "morphChildHost"),
            "components/wallpaper/NativeWallpaperWindow.qml": ("root.contentItem",),
        }
        shell = ROOT / "src/home/.config/quickshell/hakuspace"
        for path in shell.rglob("*.qml"):
            source = path.read_text()
            creations = re.findall(r"\bcreateObject\(\s*([\w.]+)", source)
            self.assertNotIn("Qt.createQmlObject", source, str(path))
            if not creations:
                continue
            relative = str(path.relative_to(shell))
            self.assertIn(relative, owners, "Document the new dynamic owner: " + relative)
            for owner in creations:
                self.assertIn(owner, owners[relative], relative)

    def test_qml_lifecycles(self):
        with tempfile.TemporaryDirectory(prefix="hikai-memory-test-") as temporary:
            work = Path(temporary)
            shell = work / "shell"
            shutil.copytree(ROOT / "src/home/.config/quickshell/hakuspace", shell)
            shutil.copy(ROOT / "scripts/hikai_memory_lifecycle_harness.qml", shell / "shell.qml")
            runtime = work / "runtime"
            runtime.mkdir(mode=0o700)
            environment = {**os.environ, "HOME": str(work), "XDG_CONFIG_HOME": str(work / "config"),
                           "XDG_CACHE_HOME": str(work / "cache"), "XDG_RUNTIME_DIR": str(runtime),
                           "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"}
            for key in ("DISPLAY", "WAYLAND_DISPLAY", "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6"):
                environment.pop(key, None)
            result = subprocess.run(["dbus-run-session", "--", "quickshell", "-p", str(shell)],
                                    env=environment, capture_output=True, text=True, timeout=20)
            log = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, log)
            self.assertIn("Hikai memory lifecycle checks passed", log)
            for error in ("TypeError", "ReferenceError", "Binding loop", "Failed to load configuration"):
                self.assertNotIn(error, log)


if __name__ == "__main__":
    unittest.main()
