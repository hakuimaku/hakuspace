#!/usr/bin/env python3
"""Exercise chrome state migration and independent controllers in disposable homes."""
import copy
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "src/core/backend/user"))
import hikai_chrome_state_ctl as chrome
import hikai_settings_ctl as settings


class ChromeStateTests(unittest.TestCase):
    """Keep migration and manager calls away from the installed session."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.path = self.home / "hakucfg/hikai/hikai-shell.json"
        self.state = self.home / ".local/state/hakuspace/state"
        self.path.parent.mkdir(parents=True)
        self.state.mkdir(parents=True)
        environment = patch.dict(os.environ, HOME=str(self.home),
                                 XDG_STATE_HOME=str(self.home / ".local/state"),
                                 XDG_CACHE_HOME=str(self.home / ".cache"),
                                 XDG_CONFIG_HOME=str(self.home / ".config"),
                                 XDG_RUNTIME_DIR=str(self.home / "runtime"),
                                 HAKUSPACE_HIKAI_SETTINGS_FILE=str(self.path))
        environment.start()
        self.addCleanup(environment.stop)

    def schema(self, version, style="dock"):
        """Reconstruct each source schema without fields introduced by later versions."""
        values = copy.deepcopy(settings.DEFAULTS)
        values["version"] = version
        if version < 11:
            values.pop("chrome")
        if version < 10:
            for key in ("powerProfile", "wallpaperWorkspace"):
                values["topbar"].pop(key)
        if version < 8:
            values.pop("idle")
        if version < 7:
            values["appearance"].pop("colorMode")
        if version < 3:
            values.pop("dock")
            if version == 1:
                values.pop("roundedScreen")
        else:
            values["dock"].update(iconSize=64, visibilityMode="always", exclusiveSpace=True)
            if version < 5:
                for key in ("showTrash", "showDevices"):
                    values["dock"].pop(key)
                if version == 3:
                    for key in ("hoverLift", "hoverScale"):
                        values["dock"].pop(key)
            elif version == 5:
                values["dock"]["style"] = style
        return values

    def document(self, style, enabled, version=5):
        """Seed valid source preferences and the old shared feature request."""
        values = self.schema(version, style)
        self.path.write_text(json.dumps(values))
        (self.state / "[desktop].taskbar.requested").write_text(str(enabled))
        return values

    def test_current_schema_without_journal_preserves_taskbar_through_cli(self):
        """A fresh Chrome journal must never reinterpret valid v10 independent state."""
        original = self.document("dock", 1, settings.DEFAULTS["version"])
        (self.state / "[desktop].dockbar.requested").write_text("0\n")
        for _ in range(3):
            result = subprocess.run([sys.executable, str(ROOT / "src/core/backend/user/hikai_chrome_state_ctl.py"), "migrate"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_states(1, 0)
            self.assertEqual(json.loads(self.path.read_text()), original)

    def test_split_schemas_preserve_all_independent_state_pairs(self):
        """Every supported post-split source keeps both on/off requests without a journal."""
        for version in range(6, settings.DEFAULTS["version"] + 1):
            for taskbar, dockbar in ((0, 0), (0, 1), (1, 0), (1, 1)):
                with self.subTest(version=version, taskbar=taskbar, dockbar=dockbar):
                    (self.state / "[migration].hikai-chrome-v6.json").unlink(missing_ok=True)
                    original = self.document("dock", taskbar, version)
                    (self.state / "[desktop].dockbar.requested").write_text(str(dockbar))
                    expected, _ = settings.migrate(original)
                    chrome.migrate()
                    self.assert_states(taskbar, dockbar)
                    self.assertEqual(json.loads(self.path.read_text()), expected)

    def test_pre_split_schemas_convert_only_the_shared_request(self):
        """Schemas without Dock style retain the historical compact interpretation."""
        for version in range(1, 6):
            for enabled in (0, 1):
                for style in (("dock", "bar") if version == 5 else ("dock",)):
                    with self.subTest(version=version, enabled=enabled, style=style):
                        (self.state / "[migration].hikai-chrome-v6.json").unlink(missing_ok=True)
                        original = self.document(style, enabled, version)
                        expected, _ = settings.migrate(original)
                        chrome.migrate()
                        self.assert_states(int(enabled and style == "bar"), int(enabled and style == "dock"))
                        self.assertEqual(json.loads(self.path.read_text()), expected)

    def test_missing_preferences_do_not_imply_a_legacy_layout(self):
        """Default-only installations have no source-schema evidence for conversion."""
        for taskbar, dockbar in ((0, 0), (0, 1), (1, 0), (1, 1)):
            with self.subTest(taskbar=taskbar, dockbar=dockbar):
                self.path.unlink(missing_ok=True)
                (self.state / "[migration].hikai-chrome-v6.json").unlink(missing_ok=True)
                (self.state / "[desktop].taskbar.requested").write_text(str(taskbar))
                (self.state / "[desktop].dockbar.requested").write_text(str(dockbar))
                chrome.migrate()
                self.assert_states(taskbar, dockbar)

    def assert_states(self, taskbar, dockbar):
        """Read both canonical files after migration or toggles."""
        self.assertEqual((self.state / "[desktop].taskbar.requested").read_text().strip(), str(taskbar))
        self.assertEqual((self.state / "[desktop].dockbar.requested").read_text().strip(), str(dockbar))

    def test_mapping_and_idempotence(self):
        """Legacy Full and compact choices survive, then independent edits stay intact."""
        for style, old, taskbar, dockbar in (("bar", 1, 1, 0), ("dock", 1, 0, 1), ("bar", 0, 0, 0), ("dock", 0, 0, 0)):
            with self.subTest(style=style, old=old):
                (self.state / "[migration].hikai-chrome-v6.json").unlink(missing_ok=True)
                original = self.document(style, old)
                chrome.migrate()
                self.assert_states(taskbar, dockbar)
                expected = original["dock"]
                del expected["style"]
                result = json.loads(self.path.read_text())
                self.assertEqual(result["version"], settings.DEFAULTS["version"])
                self.assertEqual(result["dock"], expected)
                (self.state / "[desktop].taskbar.requested").write_text("1\n")
                (self.state / "[desktop].dockbar.requested").write_text("1\n")
                snapshot = self.path.read_bytes()
                chrome.migrate()
                self.assert_states(1, 1)
                self.assertEqual(self.path.read_bytes(), snapshot)

    def test_interrupted_migration_resumes_journal(self):
        """Retry each publication boundary using journal targets, even after schema upgrade."""
        journal_path = self.state / "[migration].hikai-chrome-v6.json"
        replace_file, write_state = chrome.replace_file, chrome.write_state
        for version in (5, settings.DEFAULTS["version"]):
            for boundary in ("settings", "taskbar", "dockbar", "complete"):
                with self.subTest(version=version, boundary=boundary):
                    journal_path.unlink(missing_ok=True)
                    self.document("dock", 1, version)
                    (self.state / "[desktop].dockbar.requested").write_text("0\n")

                    def publish(parent_fd, name, values, mode):
                        """Interrupt settings or completion after the pending journal is durable."""
                        if (boundary == "settings" and name == self.path.name
                                or boundary == "complete" and name == journal_path.name and values["complete"]):
                            raise OSError("interrupted")
                        return replace_file(parent_fd, name, values, mode)

                    def write(parent_fd, name, enabled):
                        """Publish the real preceding state before interrupting the selected one."""
                        if name == f"[desktop].{boundary}.requested":
                            raise OSError("interrupted")
                        return write_state(parent_fd, name, enabled)

                    with patch.object(chrome, "replace_file", side_effect=publish), patch.object(chrome, "write_state", side_effect=write):
                        with self.assertRaises(OSError):
                            chrome.migrate()
                    target = {"complete": False, "taskbar": version >= 6, "dockbar": version < 6}
                    self.assertEqual(json.loads(journal_path.read_text()), target)
                    # Conflicting partial state must not become a new migration input.
                    (self.state / "[desktop].taskbar.requested").write_text("1\n")
                    (self.state / "[desktop].dockbar.requested").write_text("1\n")
                    for _ in range(3):
                        chrome.migrate()
                        self.assert_states(int(target["taskbar"]), int(target["dockbar"]))
                        self.assertEqual(json.loads(journal_path.read_text()), dict(target, complete=True))

    def test_pending_journal_overrides_conflicting_source_schema(self):
        """An existing journal owns target interpretation independently of source layout."""
        self.document("bar", 0)
        journal = {"complete": False, "taskbar": False, "dockbar": True}
        (self.state / "[migration].hikai-chrome-v6.json").write_text(json.dumps(journal))
        chrome.migrate()
        self.assert_states(0, 1)

    def test_completed_journal_preserves_later_edits(self):
        """Completed migrations never rewrite later settings, state or journal bytes."""
        self.document("bar", 1)
        chrome.migrate()
        self.path.write_text('user edit still in progress')
        (self.state / "[desktop].taskbar.requested").write_text("0\n")
        (self.state / "[desktop].dockbar.requested").write_text("1\n")
        snapshot = {path: path.read_bytes() for path in (self.path, *self.state.iterdir())}
        for _ in range(3):
            chrome.migrate()
            self.assertEqual({path: path.read_bytes() for path in snapshot}, snapshot)

    def test_missing_split_state_defaults_off_without_reinterpreting_taskbar(self):
        """An absent Dockbar request in a current installation is independently off."""
        self.document("dock", 1, settings.DEFAULTS["version"])
        chrome.migrate()
        self.assert_states(1, 0)

    def test_invalid_journal_and_unsupported_schema_preserve_inputs(self):
        """Invalid migration evidence cannot publish states or a successful journal."""
        self.document("dock", 1, settings.DEFAULTS["version"])
        (self.state / "[desktop].dockbar.requested").write_text("0\n")
        journal_path = self.state / "[migration].hikai-chrome-v6.json"
        for journal in ('{broken', '{"complete":0,"taskbar":true,"dockbar":false}'):
            with self.subTest(journal=journal):
                journal_path.write_text(journal)
                snapshot = {path: path.read_bytes() for path in (self.path, *self.state.iterdir())}
                with self.assertRaises(ValueError):
                    chrome.migrate()
                self.assertEqual({path: path.read_bytes() for path in snapshot}, snapshot)
        journal_path.unlink()
        values = self.schema(settings.DEFAULTS["version"])
        values["version"] += 1
        self.path.write_text(json.dumps(values))
        snapshot = self.path.read_bytes()
        with self.assertRaises(ValueError):
            chrome.migrate()
        self.assertEqual(self.path.read_bytes(), snapshot)
        self.assert_states(1, 0)
        self.assertFalse(journal_path.exists())

    def test_invalid_files_do_not_mutate_state(self):
        """Bad settings and symlinked state entries stop the upgrade safely."""
        self.document("bar", 1)
        self.path.write_text("{broken")
        with self.assertRaises(ValueError):
            chrome.migrate()
        self.assertFalse((self.state / "[migration].hikai-chrome-v6.json").exists())
        self.document("bar", 1)
        outside = self.home / "outside"
        outside.write_text("1")
        (self.state / "[desktop].taskbar.requested").unlink()
        (self.state / "[desktop].taskbar.requested").symlink_to(outside)
        with self.assertRaises(OSError):
            chrome.migrate()
        self.assertEqual(outside.read_text(), "1")

    def test_independent_controllers(self):
        """Taskbar and Dockbar toggles touch only their own requested feature."""
        self.document("bar", 1)
        chrome.migrate()
        (self.state / "[shell].backend").write_text("hikai\n")
        for name, args, expected in (("dockbar", ["--enable"], (1, 1)),
                                     ("taskbar", ["--toggle"], (0, 1)),
                                     ("dockbar", ["--toggle"], (0, 0)),
                                     ("taskbar", ["--toggle"], (1, 0))):
            result = subprocess.run([ROOT / f"src/core/facade/{name}_manager.sh", *args], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_states(*expected)

    def test_supervisor_migrates_before_shell_start(self):
        """Login and backend switching share one migration gate before spawning QML."""
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        for relative in ("lib/haku_state.sh", "lib/haku_state.py", "state/haku_state_migrate.py",
                         "backend/user/hikai_settings_ctl.py"):
            shutil.copy2(ROOT / "src/core" / relative, bin_dir)
        supervisor = bin_dir / "qs_supervisor.sh"
        supervisor.write_text((ROOT / "src/core/sys/qs_supervisor.sh").read_text())
        (bin_dir / "haku_backend_lib.sh").write_text(
            'QS_BACKEND_NAME=hikai\nhaku_runtime_dir() { echo "$HOME"; }\n'
            'haku_backend_is() { test ! -f "$HOME/stopped"; }\nhaku_qs_alive() { return 1; }\n')
        migration = bin_dir / "hikai_chrome_state_ctl.py"
        migration.write_text('#!/bin/sh\nprintf "migrate:%s\\n" "$*" >> "$HOME/order"\n')
        migration.chmod(0o755)
        (bin_dir / "wallpaper_ctl.py").write_text(
            'import os, pathlib, sys\n'
            'home = pathlib.Path(os.environ["HOME"])\n'
            'with (home / "order").open("a") as stream: stream.write("launch:" + " ".join(sys.argv[1:]) + "\\n")\n'
            '(home / "stopped").touch()\n')
        result = subprocess.run(["bash", supervisor], env={**os.environ, "PATH": str(bin_dir) + ":" + os.environ["PATH"]},
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "order").read_text(), "migrate:migrate\nlaunch:launch -c hakuspace\n")
        # A failed migration must not reach the wallpaper launcher.
        (self.home / "stopped").unlink()
        (self.home / "order").unlink()
        migration.write_text('#!/bin/sh\nexit 23\n')
        result = subprocess.run(["bash", supervisor], env={**os.environ, "PATH": str(bin_dir) + ":" + os.environ["PATH"]},
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse((self.home / "order").exists())


if __name__ == "__main__":
    unittest.main()
