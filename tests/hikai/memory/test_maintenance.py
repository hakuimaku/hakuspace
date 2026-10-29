#!/usr/bin/env python3
"""Validate sparse telemetry, persistent loop guards and the real QML maintenance engine."""
import importlib.util
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

# Import the same helpers used in source and flattened installations.
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "src/core/lib"))
spec = importlib.util.spec_from_file_location("memory_ctl", ROOT / "src/core/backend/system/hikai_memory_ctl.py")
ctl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ctl)


class MaintenanceChecks(unittest.TestCase):
    """Keep effects limited to temporary state and a private Quickshell PID."""

    def test_version_guard(self):
        for text in ("", "Quickshell 0.3.1", "Quickshell 0.3", "Quickshell 0.3.2-dev", "Python 3.14.0"):
            self.assertFalse(ctl.version_guard(text)["recycleEligible"], text)
        for text in ("Quickshell 0.3.2 (revision abc)", "Quickshell 0.4.0", "Quickshell 1.0.0"):
            self.assertTrue(ctl.version_guard(text)["recycleEligible"], text)

    def test_registered_path(self):
        result = subprocess.run(["bash", "-c", 'source "$1"; haku_state_path shell.memory-maintenance.json',
            "memory-test", str(ROOT / "src/core/lib/haku_state.sh")], capture_output=True, text=True, check=True)
        self.assertEqual(Path(result.stdout.strip()), ctl.state_path("shell.memory-maintenance.json"))

    def test_persisted_loop_guard(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "state.json"
            self.assertEqual(ctl.reserve(path, 100, 1000, 2, now=1000)["recycleCount"], 1)
            for now in (1001, 999):
                with self.assertRaises(ValueError):
                    ctl.reserve(path, 100, 1000, 2, now=now)
            self.assertEqual(ctl.reserve(path, 100, 1000, 2, now=1100)["recycleCount"], 2)
            with self.assertRaises(ValueError):
                ctl.reserve(path, 100, 1000, 2, now=1200)
            self.assertEqual(ctl.reserve(path, 100, 1000, 2, now=2200)["recycleCount"], 3)
            path.write_text('{"bad":true}')
            with self.assertRaises(ValueError):
                ctl.reserve(path, 100, 1000, 2, now=3300)

    def test_fd_growth_and_classification(self):
        before = ctl.sample(os.getpid(), gpu=False)
        pipes = [os.pipe() for _ in range(40)]
        try:
            after = ctl.sample(os.getpid(), classify=True, gpu=False)
            self.assertGreaterEqual(after["fdCount"] - before["fdCount"], 80)
            self.assertGreaterEqual(after["fdClasses"]["pipe"], 80)
            self.assertIsNone(after["gpuResidentKiB"])
            self.assertNotIn("fdClasses", before)
        finally:
            for pair in pipes:
                for descriptor in pair:
                    os.close(descriptor)
        self.assertEqual(ctl.sample(os.getpid(), gpu=False)["fdCount"], before["fdCount"])

    def test_concurrent_reservations(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "state.json"
            # All competing generations must observe the same persisted cooldown.
            def attempt(_):
                try:
                    ctl.reserve(path, 100, 1000, 2, now=1000)
                    return True
                except ValueError:
                    return False
            with ThreadPoolExecutor(max_workers=4) as workers:
                self.assertEqual(sum(workers.map(attempt, range(4))), 1)

    def test_damaged_state_keeps_telemetry(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / ".local/state/hakuspace/state/[shell].memory-maintenance.json"
            path.parent.mkdir(parents=True)
            path.write_text("broken json")
            result = subprocess.run([sys.executable, str(ROOT / "src/core/backend/system/hikai_memory_ctl.py"),
                "sample", str(os.getpid()), "--initialize"], env={**os.environ, "HOME": temporary},
                capture_output=True, text=True, timeout=5, check=True)
            value = json.loads(result.stdout)
            self.assertGreater(value["rssKiB"], 0)
            self.assertFalse(value["protectionReady"])

    def test_qml_runtime(self):
        with tempfile.TemporaryDirectory(prefix="hikai-maintenance-test-") as temporary:
            work = Path(temporary)
            shell = work / "src/home/.config/quickshell/hakuspace"
            shutil.copytree(ROOT / "src/home/.config/quickshell/hakuspace", shell)
            shutil.copytree(ROOT / "src/core", work / "src/core", ignore=shutil.ignore_patterns("__pycache__"))
            shutil.copy(ROOT / "tests/hikai/memory/harness/maintenance.qml", shell / "shell.qml")
            runtime = work / "runtime"
            runtime.mkdir(mode=0o700)
            environment = {**os.environ, "HOME": str(work), "XDG_CONFIG_HOME": str(work / "config"),
                           "XDG_CACHE_HOME": str(work / "cache"), "XDG_RUNTIME_DIR": str(runtime),
                           "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "QS_NO_RELOAD_POPUP": "1"}
            for key in ("DISPLAY", "WAYLAND_DISPLAY", "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6"):
                environment.pop(key, None)
            with (work / "qs.log").open("w+") as log:
                process = subprocess.Popen(["quickshell", "-p", str(shell)], env=environment, stdout=log, stderr=log)
                # Every IPC request is selected by the private child's PID.
                def ipc(target, method, *args):
                    return subprocess.check_output(["quickshell", "ipc", "--pid", str(process.pid), "call", target, method, *args],
                                                   env=environment, text=True, stderr=subprocess.DEVNULL, timeout=5).strip()

                def wait_for(predicate, timeout=8):
                    deadline = time.monotonic() + timeout
                    while time.monotonic() < deadline:
                        if process.poll() is not None:
                            log.seek(0)
                            self.fail(log.read())
                        try:
                            status = json.loads(ipc("memory", "status"))
                            if predicate(status):
                                return status
                        except (subprocess.CalledProcessError, json.JSONDecodeError):
                            pass
                        time.sleep(0.04)
                    log.seek(0)
                    self.fail("maintenance wait timed out: " + json.dumps(locals().get("status")) + "\n" + log.read())

                try:
                    startup = wait_for(lambda s: s["state"] == "warming-up")
                    self.assertEqual(startup["gcCount"], 0)
                    self.assertIn("rejected", ipc("memory", "collect"))
                    normal = wait_for(lambda s: s["state"] == "normal" and s["maintenanceSafe"])
                    self.assertGreater(normal["rssMiB"], 0)
                    self.assertGreater(json.loads(ipc("memory", "baseline"))["rssMiB"], 0)
                    self.assertEqual(normal["gcCount"], 0)
                    self.assertEqual(ipc("memory", "collect"), "scheduled")
                    manual = wait_for(lambda s: s["gcCount"] == 1 and s["postGc"] is not None)
                    self.assertIsNotNone(manual["lastGcFreedMiB"])
                    self.assertEqual(manual["gcIneffective"], manual["lastGcFreedMiB"] < 20)
                    ipc("maintenanceTest", "safe", "false")
                    ipc("maintenanceTest", "pressure")
                    deferred = wait_for(lambda s: s["state"] == "gc-pending")
                    self.assertEqual(deferred["gcCount"], 1)
                    self.assertIn("unsafe", ipc("memory", "collect"))
                    self.assertIn("unsafe", ipc("memory", "recycle"))
                    ipc("maintenanceTest", "safe", "true")
                    result = wait_for(lambda s: s["gcCount"] == 2 and s["postGc"] is not None)
                    self.assertEqual(result["gcCount"], 2)
                    self.assertGreaterEqual(result["postGc"]["at"] - result["preGc"]["at"], 200)
                    basis = result["gcMetric"] + "MiB"
                    self.assertAlmostEqual(result["lastGcFreedMiB"], result["preGc"][basis] - result["postGc"][basis])
                    self.assertIn("cooldown", ipc("memory", "collect"))
                    self.assertEqual(result["recycleCount"], 0)
                    # Expired evidence under hard pressure retries GC before the ineffective backoff expires.
                    retried = wait_for(lambda s: s["gcCount"] == 3 and s["postGc"] is not None)
                    self.assertGreaterEqual(retried["lastGcAt"] - result["lastGcAt"], 2000)
                    self.assertLess(retried["lastGcAt"] - result["lastGcAt"], 4000)
                    ipc("maintenanceTest", "allowRecycle")
                    reloaded = wait_for(lambda s: s["recycleCount"] == 1 and s["state"] == "normal")
                    self.assertEqual(reloaded["gcCount"], 0)
                    self.assertGreater(reloaded["lastRecycleTimestamp"], 0)
                    ipc("maintenanceTest", "allowRecycle")
                    self.assertIn("cooldown", ipc("memory", "recycle"))
                    # FD pressure takes precedence over heap collection, including manual IPC.
                    ipc("maintenanceTest", "fdGrowth")
                    anomaly = wait_for(lambda s: s["state"] == "fd-growth" and bool(s["fdClasses"]))
                    self.assertEqual(anomaly["gcCount"], 0)
                    self.assertIn("fd-growth", ipc("memory", "collect"))
                    self.assertLessEqual(len(anomaly["history"]), 24)
                    # Persistent anomalies refresh their descriptor categories without triggering GC.
                    refreshed = wait_for(lambda s: s["fdClassifiedAt"] > anomaly["fdClassifiedAt"])
                    self.assertGreaterEqual(refreshed["fdClassifiedAt"] - anomaly["fdClassifiedAt"], 1200)
                    self.assertEqual(refreshed["state"], "fd-growth")
                    self.assertEqual(refreshed["gcCount"], 0)
                    ipc("maintenanceTest", "clearPressure")
                    wait_for(lambda s: s["state"] == "normal" and s["maintenanceSafe"])
                    time.sleep(5)
                    wait_for(lambda s: ipc("memory", "recycle") == "scheduled")
                    wait_for(lambda s: s["recycleCount"] == 2 and s["state"] == "normal")
                    ipc("maintenanceTest", "stop")
                    disabled = wait_for(lambda s: s["state"] == "disabled")
                    time.sleep(0.4)
                    self.assertEqual(json.loads(ipc("memory", "status"))["sampleAt"], disabled["sampleAt"])
                finally:
                    process.terminate()
                    process.wait(timeout=10)
                log.seek(0)
                output = log.read()
                for error in ("TypeError", "ReferenceError", "Binding loop", "Failed to load configuration"):
                    self.assertNotIn(error, output)


if __name__ == "__main__":
    unittest.main()
