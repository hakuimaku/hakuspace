import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

import sys

# core.sh deploys this module flat; fixtures stay outside the runtime tree.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src/core/app/icon-accent"))
import haku_icon_accent as app

FIXTURES = Path(__file__).parent / "fixtures"
KDE = (FIXTURES / "kde.svg").read_bytes()


class AccentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.icons = self.root / "icons"
        self.theme = self.icons / "Example"
        self.theme.mkdir(parents=True)
        (self.theme / "index.theme").write_text("[Icon Theme]\nName=Example\n")
        self.svg = self.theme / "user-home.svg"
        self.svg.write_bytes(KDE)
        self.scanner = app.ThemeScanner(self.icons)
        env = patch.dict(os.environ, XDG_STATE_HOME=str(self.root / "state"))
        env.start()
        self.addCleanup(env.stop)

    def cli(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            code = app.main(["--icons-dir", str(self.icons), *args])
        return code, output.getvalue()

    def test_patch_scoped_and_restore_exact_bytes_and_mode(self):
        self.svg.chmod(0o640)
        self.assertEqual(self.cli("set", "89B4FA", "--theme", "Example")[0], 0)
        expected = KDE.replace(b".ColorScheme-Highlight { color:#5294e2; }", b".ColorScheme-Highlight { color:#89b4fa; }")
        self.assertEqual(self.svg.read_bytes(), expected)
        self.assertEqual(stat.S_IMODE(self.svg.stat().st_mode), 0o640)
        self.assertEqual(self.cli("status", "Example"), (0, "#89b4fa\n"))
        self.assertEqual(self.cli("set", "cba6f7", "--theme", "Example")[0], 0)
        backup = app.BackupManager(self.theme)
        self.assertEqual((backup.directory / "backup/user-home.svg").read_bytes(), KDE)
        self.assertEqual(self.cli("restore", "Example")[0], 0)
        self.assertEqual(self.svg.read_bytes(), KDE)
        self.assertEqual(self.cli("restore", "Example")[0], 0)
        self.assertEqual(self.cli("set", "89b4fa", "--theme", "Example")[0], 0)

    def test_legacy_backup_path_and_format_remain_restorable(self):
        current = KDE.replace(b".ColorScheme-Highlight { color:#5294e2; }", b".ColorScheme-Highlight { color:#89b4fa; }")
        self.svg.write_bytes(current)
        # This is the original engine's on-disk format, not a new-engine save.
        key = "Example-" + hashlib.sha256(str(self.theme).encode()).hexdigest()[:16]
        directory = self.root / "state/icon-accent" / key
        (directory / "backup").mkdir(parents=True)
        (directory / "backup/user-home.svg").write_bytes(KDE)
        state = dict(theme="Example", location=str(self.theme), backend="kde-colorscheme",
                     original_accent=["#5294e2"], current_accent="#89b4fa",
                     files={"user-home.svg": dict(original_sha256=hashlib.sha256(KDE).hexdigest(),
                                                  current_sha256=hashlib.sha256(current).hexdigest(),
                                                  previous_sha256=hashlib.sha256(KDE).hexdigest(), mode=0o640)})
        (directory / "state.json").write_text(json.dumps(state))
        self.assertEqual(self.cli("restore", "Example")[0], 0)
        self.assertEqual(self.svg.read_bytes(), KDE)
        self.assertEqual(stat.S_IMODE(self.svg.stat().st_mode), 0o640)
        self.assertEqual(self.cli("set", "cba6f7", "--theme", "Example")[0], 0)

    def test_dry_run_creates_no_state_or_changes(self):
        code, output = self.cli("set", "89b4fa", "--theme", "Example", "--dry-run")
        self.assertEqual(code, 0)
        self.assertIn("Files requiring modification: 1", output)
        self.assertEqual(self.svg.read_bytes(), KDE)
        self.assertFalse((self.root / "state").exists())

    def test_whitespace_cdata_comments_and_stroke(self):
        for rule in (b".ColorScheme-Highlight{color:#5294e2}", b".ColorScheme-Highlight\n{\n color:\n #5294e2;\n}", b"<![CDATA[/* comment */ .ColorScheme-Highlight { color: #5294e2 !important; }]]>"):
            for paint in (b'stroke="currentColor"', b'style="fill:currentColor"'):
                with self.subTest(rule=rule, paint=paint):
                    data = b'<svg><style id="current-color-scheme">' + rule + b'</style><path class="other ColorScheme-Highlight" ' + paint + b'/></svg>'
                    edits, users = app.KDEColorSchemeBackend.detect(data, app.validate_svg(data))
                    self.assertEqual(users, 1)
                    self.assertEqual(len(edits), 1)
                    self.assertIn(b"#89b4fa", app.KDEColorSchemeBackend.patch(data, edits, "#89b4fa"))

    def test_no_matching_paint_or_scoped_css_means_no_patch(self):
        cases = [KDE.replace(b'fill="currentColor"', b'fill="#5294e2"'),
                 KDE.replace(b".ColorScheme-Highlight {", b".ColorScheme-Highlight, .ColorScheme-Text {"),
                 KDE.replace(b"color:#5294e2;", b"background-color:#5294e2;", 1),
                 KDE.replace(b".ColorScheme-Highlight { color:#5294e2; }", b"/* .ColorScheme-Highlight { color:#5294e2; } */"),
                 KDE.replace(b'<style id="current-color-scheme">', b'<!-- <style id="current-color-scheme">').replace(b'</style>', b'</style> -->')]
        for data in cases:
            with self.subTest(data=data):
                self.assertEqual(app.KDEColorSchemeBackend.detect(data, app.validate_svg(data))[0], [])

    def test_symbolic_and_gpa_are_runtime_only_even_with_kde(self):
        self.svg.unlink()
        (self.theme / "network-symbolic.svg").write_bytes(KDE)
        symbolic = self.theme / "symbolic"
        symbolic.mkdir()
        (symbolic / "network.svg").write_bytes((FIXTURES / "symbolic.svg").read_bytes())
        (self.theme / "gpa.svg").write_bytes(KDE.replace(b'<svg ', b'<svg xmlns:gpa="http://www.gtk.org/grappa" gpa:stroke="accent" ', 1))
        report, _ = self.scanner.scan("Example")
        self.assertEqual(report["gtk_symbolic"], 2)
        self.assertEqual(report["gtk_gpa_accent"], 1)
        self.assertFalse(report["editable"])
        self.assertEqual(self.cli("set", "89b4fa", "--theme", "Example")[0], 4)

    def test_static_and_variants_never_patched(self):
        static = self.theme / "folder-blue.svg"
        static.write_bytes((FIXTURES / "symbolic.svg").read_bytes())
        report, _ = self.scanner.scan("Example")
        self.assertEqual(report["folder_variants"], ["blue"])
        self.assertEqual(report["static_svg"], 1)
        before = static.read_bytes()
        self.cli("set", "89b4fa", "--all")
        self.assertEqual(static.read_bytes(), before)

    def test_symlink_dedup_and_external_target_skipped(self):
        alias = self.theme / "folder-home.svg"
        alias.symlink_to(self.svg.name)
        outside = self.root / "outside.svg"
        outside.write_bytes(KDE)
        (self.theme / "external.svg").symlink_to(outside)
        (self.theme / "broken.svg").symlink_to("missing.svg")
        (self.theme / "external-dir").symlink_to(self.root, target_is_directory=True)
        report, _ = self.scanner.scan("Example")
        self.assertEqual(report["unique_svg_files"], 1)
        self.assertEqual(report["skipped_symlinks"], 3)
        self.assertEqual(self.cli("set", "89b4fa", "--theme", "Example")[0], 0)
        self.assertTrue(alias.is_symlink())
        self.assertEqual(outside.read_bytes(), KDE)
        state = app.BackupManager(self.theme).load()
        self.assertEqual(len(state["files"]), 1)
        self.cli("restore", "Example")
        self.assertEqual(alias.read_bytes(), KDE)

    def test_symbolic_alias_prevents_patch_of_target(self):
        (self.theme / "home-symbolic.svg").symlink_to(self.svg.name)
        self.assertFalse(self.scanner.scan("Example")[0]["editable"])

    def test_invalid_xml_never_overwritten(self):
        self.svg.write_bytes(KDE[:-9])
        before = self.svg.read_bytes()
        self.assertEqual(self.cli("set", "89b4fa", "--theme", "Example")[0], 4)
        self.assertEqual(self.svg.read_bytes(), before)
        with patch.object(app.KDEColorSchemeBackend, "patch", side_effect=ValueError("invalid SVG")):
            self.svg.write_bytes(KDE)
            self.assertEqual(self.cli("set", "89b4fa", "--theme", "Example")[0], 5)
        self.assertEqual(self.svg.read_bytes(), KDE)
        self.assertFalse(app.BackupManager(self.theme).path.exists())

    def test_external_edits_and_corrupted_backup_refused(self):
        self.cli("set", "89b4fa", "--theme", "Example")
        changed = self.svg.read_bytes() + b"\n<!-- user edit -->"
        self.svg.write_bytes(changed)
        self.assertEqual(self.cli("restore", "Example")[0], 5)
        self.assertEqual(self.cli("set", "cba6f7", "--theme", "Example")[0], 5)
        self.assertEqual(self.svg.read_bytes(), changed)
        self.svg.write_bytes(KDE)
        backup = app.BackupManager(self.theme).directory / "backup/user-home.svg"
        backup.write_bytes(b"corrupted")
        self.assertEqual(self.cli("restore", "Example")[0], 5)
        self.assertEqual(self.svg.read_bytes(), KDE)

    def test_failure_during_second_set_can_restore_both_colors(self):
        second = self.theme / "second.svg"
        second.write_bytes(KDE)
        self.cli("set", "89b4fa", "--theme", "Example")
        real_write = app.atomic_write
        writes = 0

        def fail_second(path, data, mode=0o600):
            nonlocal writes
            if path.parent == self.theme:
                writes += 1
                if writes == 2:
                    raise OSError("simulated disk failure")
            real_write(path, data, mode)

        with patch.object(app, "atomic_write", side_effect=fail_second):
            self.assertEqual(self.cli("set", "cba6f7", "--theme", "Example")[0], 5)
        self.assertEqual(self.cli("restore", "Example")[0], 0)
        self.assertEqual(self.svg.read_bytes(), KDE)
        self.assertEqual(second.read_bytes(), KDE)

    def test_atomic_replace_failure_leaves_original(self):
        with patch.object(app.os, "replace", side_effect=OSError("disk failure")):
            with self.assertRaises(OSError):
                app.atomic_write(self.svg, b"new", 0o644)
        self.assertEqual(self.svg.read_bytes(), KDE)
        self.assertEqual(list(self.theme.glob(".icon-accent-*")), [])

    def test_reinstalled_alias_does_not_block_other_accent_targets(self):
        old = self.theme / "old-home.svg"
        old.write_bytes(KDE)
        self.assertEqual(self.cli("set", "89b4fa", "--theme", "Example")[0], 0)
        backups = app.BackupManager(self.theme)
        original_backup = (backups.directory / "backup/old-home.svg").read_bytes()
        # A new theme installation resets the artwork and converts an icon to an alias.
        self.svg.write_bytes(KDE)
        old.unlink()
        old.symlink_to(self.svg.name)
        code, output = self.cli("set", "cba6f7", "--theme", "Example")
        self.assertEqual(code, 0, output)
        self.assertEqual(self.cli("status", "Example"), (0, "#cba6f7\n"))
        self.assertTrue(old.is_symlink())
        self.assertEqual(old.readlink(), Path(self.svg.name))
        self.assertEqual((backups.directory / "backup/old-home.svg").read_bytes(), original_backup)
        self.assertIn("old-home.svg", json.loads(backups.path.read_text())["files"])
        # Restore still refuses to write old bytes through the newly retargeted path.
        self.assertEqual(self.cli("restore", "Example")[0], 5)
        before = self.svg.read_bytes()
        (backups.directory / "backup/old-home.svg").write_bytes(b"corrupted")
        self.assertEqual(self.cli("set", "89b4fa", "--theme", "Example")[0], 5)
        self.assertEqual(self.svg.read_bytes(), before)

    def test_unused_unsafe_backup_paths_still_block_set(self):
        self.cli("set", "89b4fa", "--theme", "Example")
        backups = app.BackupManager(self.theme)
        state = backups.load()
        state["files"]["../outside.svg"] = state["files"]["user-home.svg"]
        backups.save(state)
        before = self.svg.read_bytes()
        self.assertEqual(self.cli("set", "cba6f7", "--theme", "Example")[0], 5)
        self.assertEqual(self.svg.read_bytes(), before)

    def test_state_cannot_restore_through_retargeted_symlink(self):
        self.cli("set", "89b4fa", "--theme", "Example")
        outside = self.root / "outside.svg"
        outside.write_bytes(KDE)
        self.svg.unlink()
        self.svg.symlink_to(outside)
        self.assertEqual(self.cli("restore", "Example")[0], 5)
        self.assertEqual(outside.read_bytes(), KDE)

    def test_cli_json_list_all_and_argument_errors(self):
        self.assertIn("Example", self.cli("list")[1])
        code, output = self.cli("inspect", "Example", "--json")
        self.assertEqual(code, 0)
        report = json.loads(output)
        self.assertEqual(report["accent"], "#5294e2")
        self.assertTrue(report["editable"])
        (self.icons / "NotTheme").mkdir()
        self.assertNotIn("NotTheme", self.cli("list")[1])
        self.assertEqual(self.cli("inspect", "Missing")[0], 3)
        self.assertEqual(self.cli("inspect", "../outside")[0], 2)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            self.cli("set", "bad", "--all")
        self.assertEqual(error.exception.code, 2)
        self.assertEqual(self.cli("set", "89b4fa", "--all")[0], 0)
        self.assertEqual(self.cli("restore", "--all")[0], 0)
        self.assertEqual(self.svg.read_bytes(), KDE)

    def test_cache_failure_is_nonfatal(self):
        (self.theme / "icon-theme.cache").touch()
        with patch.object(app.shutil, "which", return_value="/bin/cache"), patch.object(app.subprocess, "run", side_effect=OSError("failed")):
            code, output = self.cli("set", "89b4fa", "--theme", "Example")
        self.assertEqual(code, 0)
        self.assertIn("cache refresh failed", output)

    def test_looping_theme_and_tampered_state_paths_are_rejected(self):
        (self.icons / "Loop").symlink_to("Loop")
        self.assertNotIn("Loop", self.scanner.themes())
        self.cli("set", "89b4fa", "--theme", "Example")
        backups = app.BackupManager(self.theme)
        state = backups.load()
        state["files"]["../outside.svg"] = state["files"].pop("user-home.svg")
        backups.save(state)
        self.assertEqual(self.cli("restore", "Example")[0], 5)
        self.assertIn(b"#89b4fa", self.svg.read_bytes())

    def test_observed_runtime_colors_do_not_hide_active_accent(self):
        (self.theme / "runtime-symbolic.svg").write_bytes(KDE)
        self.assertEqual(self.cli("set", "89b4fa", "--theme", "Example")[0], 0)
        self.assertEqual(self.cli("status", "Example"), (0, "#89b4fa\n"))
        report = json.loads(self.cli("inspect", "Example", "--json")[1])
        self.assertEqual(report["accent"], "#89b4fa")
        self.assertEqual(report["accents"], ["#5294e2", "#89b4fa"])

    def test_themes_must_stay_inside_root(self):
        (self.root / "index.theme").write_text("[Icon Theme]")
        (self.icons / "Outside").symlink_to(self.root, target_is_directory=True)
        self.assertNotIn("Outside", self.scanner.themes())
        with self.assertRaises(app.AccentError):
            app.ThemeScanner("/usr/share/icons")


if __name__ == "__main__":
    unittest.main()
