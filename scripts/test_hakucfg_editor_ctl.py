#!/usr/bin/env python3
"""Safety and persistence checks for the Config tab controller."""
import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "src/core/backend/user/hakucfg_editor_ctl.py"


class ConfigControllerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name) / "hakucfg"
        (self.base / "wm").mkdir(parents=True)
        (self.base / "config/waybar/mybar").mkdir(parents=True)
        (self.base / "config/rofi").mkdir()
        self.wm = self.base / "wm/niri-custom.kdl"
        self.wm.write_text('layout {\n  gaps 8 // $HOME # "quoted"\n}\n')
        self.kitty = self.base / "config/kitty.conf"
        self.kitty.write_text("font_size 12\n")
        (self.base / "config/waybar/mybar/config").write_text("{}\n")
        (self.base / "config/rofi/custom.rasi").write_text("* {}\n")

    def call(self, action, file_id=None, env=None, success=True):
        run_env = dict(os.environ, HAKUSPACE_HAKUCFG_ROOT=str(self.base))
        if env:
            run_env.update(env)
        argv = [str(CONTROLLER), action] + ([file_id] if file_id is not None else [])
        result = subprocess.run(argv, env=run_env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return json.loads(result.stdout) if success else result.stderr

    def test_list_recursive_sorted_and_refresh(self):
        result = self.call("list")
        self.assertEqual([item["id"] for item in result["files"]], [
            "wm/niri-custom.kdl", "config/kitty.conf", "config/rofi/custom.rasi",
            "config/waybar/mybar/config"])
        (self.base / "config/waybar/mybar/style.css").write_text("body {}\n")
        self.assertIn("config/waybar/mybar/style.css", [item["id"] for item in self.call("list")["files"]])
        self.assertEqual(self.call("check")["root"], str(self.base))

    def test_read_exact_and_rejections(self):
        data = self.call("read", "wm/niri-custom.kdl")
        self.assertEqual(data["content"], self.wm.read_text())
        self.assertTrue(data["revision"].startswith("sha256:"))
        for file_id in ("../setting.sh", "wm/../../.ssh/config", "config/../../../etc/passwd",
                        "/etc/passwd", "file:///etc/passwd", "wm//niri-custom.kdl", "wm/./niri-custom.kdl"):
            self.call("read", file_id, success=False)
        (self.base / "config/link").symlink_to(self.wm)
        (self.base / "wm/linked-dir").symlink_to(self.base / "config", target_is_directory=True)
        self.call("read", "config/link", success=False)
        self.call("read", "wm/linked-dir/kitty.conf", success=False)
        self.assertNotIn("config/link", [item["id"] for item in self.call("list")["files"]])
        self.assertNotIn("wm/linked-dir/kitty.conf", [item["id"] for item in self.call("list")["files"]])
        os.mkfifo(self.base / "wm/pipe")
        self.call("read", "wm/pipe", success=False)
        (self.base / "wm/binary").write_bytes(b"a\0b")
        (self.base / "wm/invalid").write_bytes(b"\xff")
        (self.base / "wm/huge").write_bytes(b"a" * (96 * 1024 + 1))
        for name in ("binary", "invalid", "huge"):
            self.call("read", "wm/" + name, success=False)
        listed = self.call("list")
        self.assertEqual(listed["skippedCount"], 6)

    def test_write_revision_mode_and_literal_text(self):
        self.wm.chmod(0o755)
        old = self.call("read", "wm/niri-custom.kdl")
        draft = '\t$HOME # "quote" { } // literal\nsecond line\n'
        saved = self.call("write", "wm/niri-custom.kdl", {
            "HAKUSPACE_CONFIG_TEXT": draft,
            "HAKUSPACE_CONFIG_EXPECTED_REVISION": old["revision"]})
        self.assertEqual(self.wm.read_text(), draft)
        self.assertEqual(saved["content"], draft)
        self.assertEqual(saved["revision"], self.call("read", "wm/niri-custom.kdl")["revision"])
        self.assertEqual(stat.S_IMODE(self.wm.stat().st_mode), 0o755)
        self.assertEqual(self.kitty.read_text(), "font_size 12\n")
        self.call("write", "wm/niri-custom.kdl", {
            "HAKUSPACE_CONFIG_TEXT": "stale", "HAKUSPACE_CONFIG_EXPECTED_REVISION": old["revision"]}, False)
        self.assertEqual(self.wm.read_text(), draft)

    def test_write_invalid_payload_is_atomic(self):
        old = self.call("read", "config/kitty.conf")
        before = self.kitty.read_bytes()
        env = {"HAKUSPACE_CONFIG_EXPECTED_REVISION": old["revision"]}
        for file_id, text in (("../setting.sh", "x"),):
            self.call("write", file_id, dict(env, HAKUSPACE_CONFIG_TEXT=text), False)
            self.assertEqual(self.kitty.read_bytes(), before)
        (self.base / "config/link").symlink_to(self.kitty)
        self.call("write", "config/link", dict(env, HAKUSPACE_CONFIG_TEXT="x"), False)
        spec = importlib.util.spec_from_file_location("editor_ctl", CONTROLLER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for invalid_text in ("a\0b", "a" * (96 * 1024 + 1)):
            with patch.object(module.os, "environ", dict(HAKUSPACE_HAKUCFG_ROOT=str(self.base),
                                                       HAKUSPACE_CONFIG_TEXT=invalid_text,
                                                       HAKUSPACE_CONFIG_EXPECTED_REVISION=old["revision"])):
                with self.assertRaises(ValueError):
                    module.write_file("config/kitty.conf")
            self.assertEqual(self.kitty.read_bytes(), before)
        with patch.dict(os.environ, HAKUSPACE_HAKUCFG_ROOT=str(self.base),
                        HAKUSPACE_CONFIG_TEXT="new", HAKUSPACE_CONFIG_EXPECTED_REVISION=old["revision"]):
            with patch.object(module.os, "replace", side_effect=OSError("commit failed")):
                with self.assertRaises(OSError):
                    module.write_file("config/kitty.conf")
        self.assertEqual(self.kitty.read_bytes(), before)
        self.assertEqual(list((self.base / "config").glob(".hakucfg-editor-*")), [])

    def test_external_change_conflict(self):
        old = self.call("read", "config/kitty.conf")
        self.kitty.write_text("external edit\n")
        error = self.call("write", "config/kitty.conf", {
            "HAKUSPACE_CONFIG_TEXT": "draft\n",
            "HAKUSPACE_CONFIG_EXPECTED_REVISION": old["revision"]}, False)
        self.assertIn("conflict:", error)
        self.assertEqual(self.kitty.read_text(), "external edit\n")

    def test_open_vscode_exact_argv_and_missing_executable(self):
        target = self.base / "config/file with spaces.conf"
        target.write_text("x\n")
        output = Path(self.temp.name) / "argv.json"
        fake = Path(self.temp.name) / "fake-code"
        fake.write_text('#!/usr/bin/env python3\nimport json,sys\nfrom pathlib import Path\nPath(' + repr(str(output)) + ').write_text(json.dumps(sys.argv[1:]))\n')
        fake.chmod(0o755)
        self.call("open-vscode", "config/file with spaces.conf", {"HAKUSPACE_CODE_BIN": str(fake)})
        for _ in range(50):
            if output.exists():
                break
            time.sleep(0.02)
        self.assertEqual(json.loads(output.read_text()), ["--reuse-window", str(target)])
        output.unlink()
        self.call("open-vscode", "../setting.sh", {"HAKUSPACE_CODE_BIN": str(fake)}, False)
        self.assertFalse(output.exists())
        self.call("open-vscode", "config/kitty.conf", {"HAKUSPACE_CODE_BIN": "/missing/code"}, False)

    def test_approved_root_symlink_rejected(self):
        outside = Path(self.temp.name) / "outside"
        outside.mkdir()
        (self.base / "wm/niri-custom.kdl").unlink()
        (self.base / "wm").rmdir()
        (self.base / "wm").symlink_to(outside, target_is_directory=True)
        self.call("check", success=False)
        self.call("list", success=False)


if __name__ == "__main__":
    unittest.main()
