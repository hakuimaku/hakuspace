#!/usr/bin/env python3
"""Check idle ownership with the existing disposable session process model."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import time
import unittest

# Reuse deployment fixtures without running unrelated transition cases.
SPEC = importlib.util.spec_from_file_location("transition_fixture", Path(__file__).resolve().parents[2] / "shell/backend_transition/test_transition.py")
fixture = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fixture)


class IdleOwnershipTests(unittest.TestCase):
    """Exercise daemon reconciliation and both shell handoff directions."""

    def setUp(self):
        """Build a private HOME whose process commands cannot affect the desktop."""
        self.session = fixture.BackendTransitionTest()
        self.session.setUp()
        self.addCleanup(self.session.doCleanups)

    def reconcile(self, success=True):
        """Run the real ownership controller against inert daemon commands."""
        result = subprocess.run([self.session.bin / "idle_backend_ctl.sh", "reconcile"],
                                env=self.session.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode == 0, success, result.stderr)

    def test_classic_is_idempotent_and_repairs_duplicates(self):
        """Classic retains exactly one owner, including after duplicate startup."""
        self.session.prepare("classic")
        self.reconcile()
        self.reconcile()
        path = self.session.root / "model.json"
        model = json.loads(path.read_text())
        model["procs"].append("hypridle")
        path.write_text(json.dumps(model))
        self.reconcile()
        self.assertEqual(json.loads(path.read_text())["procs"].count("hypridle"), 1)

    def test_hikai_removes_daemon(self):
        """Hikai reconciliation removes stale Classic ownership."""
        self.session.prepare("classic")
        (self.session.state / "[shell].backend").write_text("hikai\n")
        self.reconcile()
        self.reconcile()
        self.assertNotIn("hypridle", json.loads((self.session.root / "model.json").read_text())["procs"])

    def test_missing_classic_daemon_fails_clearly(self):
        """A private PATH guarantees the test cannot launch a host hypridle binary."""
        self.session.prepare("hikai")
        (self.session.state / "[shell].backend").write_text("classic\n")
        (self.session.bin / "hypridle").unlink()
        for name in ("bash", "python3", "dirname", "mkdir", "flock", "id", "wc", "cat", "grep", "jq"):
            (self.session.bin / name).symlink_to(shutil.which(name))
        self.session.env["PATH"] = str(self.session.bin)
        self.reconcile(success=False)

    def test_switch_and_rollback(self):
        """Switching and failed Hikai preparation restore the correct idle owner."""
        for failure in ("", "showChrome"):
            with self.subTest(failure=failure):
                self.session.prepare("classic", failure)
                self.session.run_cli("set", "hikai", success=not failure)
                self.session.assert_backend("classic" if failure else "hikai")
                if not failure:
                    self.session.run_cli("set", "classic")
                    self.session.assert_backend("classic")

    def test_crashed_runtime_recovers_classic_idle(self):
        """Emergency recovery restores the Classic daemon after the runtime disappears."""
        self.session.prepare("hikai")
        path = self.session.root / "model.json"
        model = json.loads(path.read_text())
        model["procs"].remove("qs")
        model["owner"] = ""
        path.write_text(json.dumps(model))
        self.session.run_cli("--recover")
        self.session.assert_backend("classic")

    def test_supervisor_crash_loop_launches_idle_recovery(self):
        """Run three inert runtime crashes through the real detached fallback path."""
        self.session.env["QT_QPA_PLATFORM"] = "xcb"
        self.session.prepare("hikai")
        path = self.session.root / "model.json"
        model = json.loads(path.read_text())
        model["procs"].remove("qs")
        model["owner"] = ""
        path.write_text(json.dumps(model))
        shutil.copy2(Path(__file__).resolve().parents[3] / "src/core/sys/qs_supervisor.sh", self.session.bin)
        launcher = self.session.bin / "wallpaper_ctl.py"
        launcher.write_text("import os\nfrom pathlib import Path\n"
                            "Path(os.environ['MOCK_ROOT'], 'runtime-platform').write_text(os.environ.get('QT_QPA_PLATFORM', ''))\n"
                            "raise SystemExit(1)\n")
        (self.session.bin / "setsid").unlink()
        (self.session.bin / "setsid").symlink_to(shutil.which("setsid"))
        result = subprocess.run(["bash", self.session.bin / "qs_supervisor.sh"], env=self.session.env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual((self.session.root / "runtime-platform").read_text(), "wayland")
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            model = json.loads(path.read_text())
            if model["owner"] == "swaync" and model["procs"].count("hypridle") == 1 and "waybar" in model["procs"]:
                break
            time.sleep(0.05)
        self.session.assert_backend("classic")


if __name__ == "__main__":
    unittest.main()
