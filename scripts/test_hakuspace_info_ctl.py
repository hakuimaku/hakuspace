#!/usr/bin/env python3
"""Deterministic read-only Info controller checks."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CONTROLLER = Path(__file__).resolve().parents[1] / "src/core/backend/system/hakuspace_info_ctl.py"


class InfoControllerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base_env = dict(os.environ)
        for key in ("GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"):
            self.base_env.pop(key, None)
        self.base = Path(self.temp.name)
        self.repo = self.base / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Test User")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        (self.repo / "file.txt").write_text("one\n")
        self.git("add", "file.txt")
        self.git("commit", "-qm", "first")
        self.release = self.base / "os-release"
        self.release.write_text('PRETTY_NAME="Test Linux 1"\nID=test\nVERSION_ID="1"\n')

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], env=self.base_env, text=True).strip()

    def read(self, override=None, env=None):
        variables = dict(self.base_env, HAKUSPACE_REPO_ROOT=str(self.repo if override is None else override),
                         HAKUSPACE_OS_RELEASE_FILE=str(self.release))
        if env:
            variables.update(env)
        result = subprocess.run([sys.executable, str(CONTROLLER), "read"], env=variables,
                                capture_output=True, text=True, check=True)
        return json.loads(result.stdout)

    def hardware_roots(self):
        proc = self.base / "proc"
        sys_root = self.base / "sys"
        proc.mkdir()
        sys_root.mkdir()
        return proc, sys_root, {"HAKUSPACE_PROC_ROOT": str(proc), "HAKUSPACE_SYS_ROOT": str(sys_root)}

    def put(self, root, relative, value):
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)

    def test_clean_repo_no_tag_and_hashes(self):
        data = self.read()
        repo = data["repo"]
        self.assertTrue(repo["detected"])
        self.assertEqual(repo["path"], str(self.repo))
        self.assertEqual(repo["commitFull"], self.git("rev-parse", "HEAD"))
        self.assertEqual(repo["commit"], self.git("rev-parse", "--short=8", "HEAD"))
        self.assertEqual(repo["version"], repo["commit"])
        self.assertEqual(repo["branch"], self.git("branch", "--show-current"))
        self.assertEqual(repo["exactTag"], "")
        self.assertFalse(repo["dirty"])
        self.assertRegex(repo["commitDate"], r"^\d{4}-\d\d-\d\d$")

    def test_exact_tag_and_commit_after_tag(self):
        self.git("tag", "v1.2.3")
        tagged = self.read()["repo"]
        self.assertEqual(tagged["exactTag"], "v1.2.3")
        self.assertEqual(tagged["version"], "v1.2.3")
        (self.repo / "file.txt").write_text("two\n")
        self.git("commit", "-qam", "second")
        later = self.read()["repo"]
        self.assertEqual(later["exactTag"], "")
        self.assertRegex(later["version"], r"^v1\.2\.3-1-g[0-9a-f]+$")

    def test_tracked_and_untracked_dirty(self):
        (self.repo / "file.txt").write_text("modified\n")
        self.assertTrue(self.read()["repo"]["dirty"])
        self.assertTrue(self.read()["repo"]["version"].endswith("-dirty"))
        (self.repo / "file.txt").write_text("one\n")
        (self.repo / "extra.txt").write_text("new\n")
        self.assertTrue(self.read()["repo"]["dirty"])

    def test_detached_nested_and_invalid_candidate(self):
        nested = self.repo / "nested/deeper"
        nested.mkdir(parents=True)
        self.assertEqual(self.read(nested)["repo"]["path"], str(self.repo))
        self.git("checkout", "-q", "--detach", "HEAD")
        self.assertEqual(self.read(nested)["repo"]["branch"], "detached")
        missing = self.read(self.base / "not-a-repo")["repo"]
        self.assertFalse(missing["detected"])
        self.assertEqual(missing["version"], "Not detected")

    def test_missing_git_degrades_without_crash(self):
        data = self.read(env={"PATH": str(self.base / "no-binaries")})
        self.assertFalse(data["repo"]["detected"])
        self.assertEqual(data["repo"]["version"], "Not detected")
        self.assertEqual(data["system"]["distroPretty"], "Test Linux 1")

    def test_os_release_partial_and_malformed(self):
        data = self.read()["system"]
        self.assertEqual((data["distroPretty"], data["distroId"], data["distroVersion"]),
                         ("Test Linux 1", "test", "1"))
        self.release.write_text('PRETTY_NAME="unclosed\nID=partial\nBROKEN\nVERSION_ID=\n')
        data = self.read()["system"]
        self.assertEqual(data["distroPretty"], "")
        self.assertEqual(data["distroId"], "partial")
        self.assertEqual(data["distroVersion"], "")
        self.release.unlink()
        self.assertEqual(self.read()["system"]["distroId"], "")

    def test_hardware_cpu_memory_and_dmi(self):
        proc, sys_root, env = self.hardware_roots()
        self.put(proc, "cpuinfo", "\n\n".join(
            f"processor : {index}\nmodel name : Test CPU\nvendor_id : Test Vendor\n"
            f"physical id : {index // 2}\ncore id : {index % 2}" for index in range(4)))
        self.put(proc, "meminfo", "MemTotal: 32768000 kB\nMemFree: 100 kB\n")
        self.put(sys_root, "class/dmi/id/sys_vendor", "Test Manufacturer\n")
        self.put(sys_root, "class/dmi/id/product_name", "Test Laptop\n")
        self.put(sys_root, "class/dmi/id/product_version", "Revision A\n")
        self.put(sys_root, "class/dmi/id/product_serial", "PRIVATE-SERIAL\n")
        self.put(sys_root, "devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq", "5100000\n")
        hardware = self.read(env=env)["hardware"]
        self.assertEqual(hardware["device"], {"manufacturer": "Test Manufacturer", "model": "Test Laptop", "version": "Revision A"})
        self.assertEqual(hardware["cpu"], {"model": "Test CPU", "vendor": "Test Vendor", "threads": 4,
                                           "physicalCores": 4, "maxFrequencyHz": 5100000000})
        self.assertEqual(hardware["memory"]["totalBytes"], 32768000 * 1024)
        self.assertNotIn("PRIVATE-SERIAL", json.dumps(hardware))

    def test_hardware_gpu_and_storage_without_optional_commands(self):
        _, sys_root, env = self.hardware_roots()
        self.put(sys_root, "class/drm/card0/device/vendor", "0x1002\n")
        self.put(sys_root, "class/drm/card0/device/device", "0x15bf\n")
        self.put(sys_root, "class/drm/card0/device/mem_info_vram_total", "536870912\n")
        self.put(sys_root, "class/drm/card0/device/uevent", "DRIVER=amdgpu\n")
        self.put(sys_root, "class/drm/card0-DP-1/device/vendor", "0x1002\n")
        self.put(sys_root, "block/nvme0n1/size", "2000000\n")
        self.put(sys_root, "block/nvme0n1/device/model", "Test NVMe\n")
        self.put(sys_root, "block/nvme0n1/queue/rotational", "0\n")
        self.put(sys_root, "block/sda/size", "4000000\n")
        self.put(sys_root, "block/sda/queue/rotational", "1\n")
        for name in ("loop0", "ram0", "zram0", "dm-0", "md0"):
            self.put(sys_root, f"block/{name}/size", "1000\n")
        hardware = self.read(env=dict(env, PATH=str(self.base / "no-binaries")))["hardware"]
        self.assertEqual(hardware["gpus"], [{"name": "AMD GPU", "vendor": "AMD", "driver": "amdgpu", "vramBytes": 536870912}])
        self.assertEqual(hardware["storage"], [
            {"name": "nvme0n1", "capacityBytes": 1024000000, "model": "Test NVMe", "rotational": False},
            {"name": "sda", "capacityBytes": 2048000000, "rotational": True}])

    def test_hardware_missing_sources_degrade(self):
        _, _, env = self.hardware_roots()
        data = self.read(env=env)
        self.assertTrue(data["ok"])
        self.assertEqual(data["hardware"], {"device": {}, "cpu": {}, "memory": {}, "gpus": [], "storage": []})


if __name__ == "__main__":
    unittest.main()
