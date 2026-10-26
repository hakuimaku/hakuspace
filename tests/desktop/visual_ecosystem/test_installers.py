"""Migrated upstream installer guards, isolated from real desktop state."""
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]


class InstallGuards(unittest.TestCase):
    def setUp(self):
        """Use disposable HOME and source fixtures for the migrated install functions."""
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.home = Path(self.work.name)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(('HAKU_', 'HAKUSPACE_'))}
        self.env.update(HOME=str(self.home), HAKU_DIR=str(ROOT),
                        XDG_CONFIG_HOME=str(self.home / 'config'), XDG_DATA_HOME=str(self.home / 'data'),
                        XDG_STATE_HOME=str(self.home / 'state'), TMPDIR=str(self.home),
                        PYTHONDONTWRITEBYTECODE='1')

    def run_shell(self, code):
        """Load the same HakuSpace-owned installer functions used by the CLI."""
        return subprocess.run(['bash', '-euc',
                               f'source "{ROOT}/scripts/setup.sh"; resolve_component cursor; {code}'],
                              env=self.env, text=True, capture_output=True)

    def test_unmanaged_cursor_is_preserved(self):
        target = self.home / ".icons/Haku-Dark"
        target.mkdir(parents=True)
        (target / "custom").write_text("keep")
        result = self.run_shell("install_cursor")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unmanaged cursor", result.stderr)
        self.assertEqual((target / "custom").read_text(), "keep")

    def cursor_source(self):
        upstream = Path(os.environ.get("HAKUSPACE_TEST_CURSOR_SOURCE", Path(os.environ.get("HAKU_CURSOR_SOURCE", str(Path.home() / "haku-cursor")))))
        if not (upstream / "scripts/install.sh").is_file():
            self.skipTest("set HAKUSPACE_TEST_CURSOR_SOURCE to test the real upstream installer")
        source = self.home / "cursor-source"
        (source / "scripts").mkdir(parents=True)
        shutil.copy2(upstream / "scripts/install.sh", source / "scripts/install.sh")
        # Build fixtures cheaply; installation uses the current upstream script unchanged.
        (source / "Makefile").write_text("""STYLE ?= both
ANIM ?= all
.PHONY: dark light blue verify install
dark light blue:
\tpython3 build_fixture.py $@ $(STYLE) $(ANIM)
verify:
\t@echo verify >> calls
install:
\t@echo install $(THEME) >> calls
\t./scripts/install.sh $(THEME)
""")
        (source / "build_fixture.py").write_text("""from pathlib import Path
import os, sys
target, style, animation = sys.argv[1:]
with Path('calls').open('a') as out:
    out.write(f'build {target} {style} {animation}\\n')
styles = [target] if target in ('dark', 'light') else (['dark', 'light'] if style == 'both' else [style])
for variant in styles:
    name = 'Haku-' + target.capitalize() + ('-Light' if target not in ('dark', 'light') and variant == 'light' else '')
    name = os.environ.get('CURSOR_FIXTURE_NAME', name)
    directory = Path('dist') / name
    (directory / 'cursors').mkdir(parents=True, exist_ok=True)
    (directory / 'index.theme').write_text('[Icon Theme]\\n')
    (directory / 'cursors/left_ptr').write_bytes(b'new cursor')
""")
        self.env["HAKU_CURSOR_SOURCE"] = str(source)
        return source

    def install_cursor(self):
        return self.run_shell("install_cursor")

    def assert_selected_cursor(self, theme, target, style):
        source = self.cursor_source()
        result = self.install_cursor()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        selected = self.home / ".icons" / theme
        self.assertTrue((selected / "index.theme").is_file())
        self.assertTrue((selected / ".hakuspace-cursor").is_file())
        self.assertEqual({p.name for p in (self.home / ".icons").iterdir()}, {theme})
        self.assertFalse((self.home / "data/icons").exists())
        self.assertEqual((source / "calls").read_text().splitlines(),
                         [f"build {target} {style} all", "verify", f"install {theme}"])
        return source

    def test_default_cursor_is_dark(self):
        self.assert_selected_cursor("Haku-Dark", "dark", "dark")

    def test_light_cursor_is_exact(self):
        self.env["HAKU_CURSOR_THEME"] = "Haku-Light"
        self.assert_selected_cursor("Haku-Light", "light", "light")

    def test_blue_cursor_is_dark_only(self):
        self.env["HAKU_CURSOR_THEME"] = "Haku-Blue"
        self.assert_selected_cursor("Haku-Blue", "blue", "dark")

    def test_legacy_palette_installs_only_dark_theme(self):
        self.env["HAKU_CURSOR_PALETTE"] = "blue"
        self.assert_selected_cursor("Haku-Blue", "blue", "dark")

    def test_blue_light_cursor_is_light_only(self):
        self.env["HAKU_CURSOR_THEME"] = "Haku-Blue-Light"
        self.assert_selected_cursor("Haku-Blue-Light", "blue", "light")

    def assert_sibling_preserved(self, selected, sibling):
        self.env["HAKU_CURSOR_THEME"] = selected
        source = self.cursor_source()
        # A prior build may leave the unselected variant in dist as well.
        built_sibling = source / "dist" / sibling
        (built_sibling / "cursors").mkdir(parents=True)
        (built_sibling / "index.theme").write_text("upstream sibling")
        (built_sibling / "cursors/left_ptr").write_bytes(b"must not install")
        managed = self.home / ".icons" / selected
        managed.mkdir(parents=True)
        (managed / ".hakuspace-cursor").write_text("HakuSpace managed cursor v1\n")
        other = self.home / ".icons" / sibling
        (other / "cursors").mkdir(parents=True)
        (other / "index.theme").write_text("custom theme")
        (other / "cursors/left_ptr").write_bytes(b"user cursor")
        (other / "cursors/default").symlink_to("left_ptr")
        before = {p.relative_to(other): p.read_bytes() for p in other.rglob("*") if p.is_file()}
        result = self.install_cursor()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual({p.relative_to(other): p.read_bytes() for p in other.rglob("*") if p.is_file()}, before)
        self.assertTrue((other / "cursors/default").is_symlink())
        self.assertFalse((other / ".hakuspace-cursor").exists())

    def test_dark_update_preserves_unmanaged_light_sibling(self):
        self.assert_sibling_preserved("Haku-Blue", "Haku-Blue-Light")

    def test_light_update_preserves_unmanaged_dark_sibling(self):
        self.assert_sibling_preserved("Haku-Blue-Light", "Haku-Blue")

    def test_managed_cursor_rerun(self):
        self.assert_selected_cursor("Haku-Dark", "dark", "dark")
        result = self.install_cursor()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual({p.name for p in (self.home / ".icons").iterdir()}, {"Haku-Dark"})

    def test_legacy_palettes_and_explicit_theme_precedence(self):
        for palette in ("blue", "cyan", "green", "purple", "pink", "red", "orange", "yellow"):
            with self.subTest(palette=palette):
                self.env["HAKU_CURSOR_PALETTE"] = palette
                result = self.run_shell('resolve_cursor_theme; printf "%s %s %s" "$HAKU_CURSOR_THEME" "$CURSOR_BUILD_TARGET" "$CURSOR_STYLE"')
                self.assertEqual(result.stdout, f"Haku-{palette.capitalize()} {palette} dark", result.stderr)
        self.env.update(HAKU_CURSOR_THEME="Haku-Blue-Light", HAKU_CURSOR_PALETTE="pink")
        result = self.run_shell('resolve_cursor_theme; printf "%s %s %s" "$HAKU_CURSOR_THEME" "$CURSOR_BUILD_TARGET" "$CURSOR_STYLE"')
        self.assertEqual(result.stdout, "Haku-Blue-Light blue light", result.stderr)

    def test_missing_exact_build_is_refused_before_install(self):
        source = self.cursor_source()
        self.env["CURSOR_FIXTURE_NAME"] = "Haku-Unrelated"
        result = self.install_cursor()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Selected cursor was not built", result.stderr)
        self.assertNotIn("install", (source / "calls").read_text())
        self.assertFalse((self.home / ".icons").exists())

    def test_live_verification_uses_home_icons_without_a_manifest(self):
        """Installed pairs are checked on disk without cached revision metadata."""
        self.assert_selected_cursor("Haku-Dark", "dark", "dark")
        for relative in (".themes/Hikaide", ".themes/Hikaide-Light",
                         ".icons/Hikaide-Symbols", ".icons/Hikaide-Symbols-Light"):
            directory = self.home / relative
            directory.mkdir(parents=True)
            (directory / "index.theme").touch()
        result = self.run_shell('for component in cursor gtk symbols; do verify_component "$component"; done')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / ".local/state/hakuspace/assets/installed.env").exists())

    def test_verify_assets_missing_light_gtk_theme(self):
        self.assert_selected_cursor("Haku-Dark", "dark", "dark")
        for relative in (".themes/Hikaide", ".icons/Hikaide-Symbols", ".icons/Hikaide-Symbols-Light"):
            directory = self.home / relative
            directory.mkdir(parents=True)
            (directory / "index.theme").touch()
        result = self.run_shell('verify_component gtk')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Hikaide-Light installation missing", result.stderr)

    def test_verify_assets_missing_light_icon_theme(self):
        self.assert_selected_cursor("Haku-Dark", "dark", "dark")
        for relative in (".themes/Hikaide", ".themes/Hikaide-Light", ".icons/Hikaide-Symbols"):
            directory = self.home / relative
            directory.mkdir(parents=True)
            (directory / "index.theme").touch()
        result = self.run_shell('verify_component symbols')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Hikaide-Symbols-Light installation missing", result.stderr)

    def test_install_icons_detects_light_theme_for_replace(self):
        source = self.home / "icons-source"
        (source / "scripts").mkdir(parents=True)
        (source / "scripts/build.py").touch()
        (source / "scripts/validate.py").touch()
        script = source / "scripts/install.sh"
        script.write_text('#!/bin/sh\nprintf "%s\\n" "$*"\n')
        script.chmod(0o755)
        self.env["HAKU_ICON_THEME_SOURCE"] = str(source)

        # Fresh install (neither variant exists)
        result = self.run_shell('resolve_component symbols; install_component symbols')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "")

        # Only light theme exists
        (self.home / ".icons/Hikaide-Symbols-Light").mkdir(parents=True)
        result = self.run_shell('resolve_component symbols; install_component symbols')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "--replace")

    def legacy_files(self):
        target = self.home / ".local/bin"
        target.mkdir(parents=True)
        files = [target / "icon-accent", target / "icon_accent.py"]
        for file in files:
            file.write_text("legacy file")
        state = self.home / ".local/state/hakuspace/assets"
        state.mkdir(parents=True)
        receipt = state / "icon-accent.sha256"
        receipt.write_bytes(subprocess.check_output(["sha256sum", *map(str, files)]))
        return files, receipt

    def cleanup_legacy(self):
        return self.run_shell("cleanup_legacy_icon_accent")

    def test_verified_legacy_cleanup_and_idempotence(self):
        files, receipt = self.legacy_files()
        result = self.cleanup_legacy()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(file.exists() for file in [*files, receipt]))
        self.assertEqual(self.cleanup_legacy().returncode, 0)

    def test_modified_legacy_files_are_preserved(self):
        files, receipt = self.legacy_files()
        files[1].write_text("user edit")
        result = self.cleanup_legacy()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("warning", result.stderr)
        self.assertTrue(all(file.exists() for file in [*files, receipt]))
        self.assertEqual(files[1].read_text(), "user edit")

    def test_unmanaged_files_and_forged_receipts_are_preserved(self):
        files, receipt = self.legacy_files()
        receipt.unlink()
        self.cleanup_legacy()
        self.assertTrue(all(file.exists() for file in files))
        unrelated = self.home / "unrelated"
        unrelated.write_text("keep")
        receipt.write_bytes(subprocess.check_output(["sha256sum", str(unrelated)]))
        self.cleanup_legacy()
        self.assertTrue(all(file.exists() for file in [*files, receipt, unrelated]))

    def test_failed_checksum_read_preserves_both_files(self):
        files, receipt = self.legacy_files()
        receipt.write_bytes(subprocess.check_output(["sha256sum", str(files[0])]))
        wrapper = self.home / "bin"
        wrapper.mkdir()
        checksum = wrapper / "sha256sum"
        # Simulate a read error on the second file after emitting the first hash.
        checksum.write_text('#!/bin/sh\nhead -n1 "$TEST_RECEIPT"\nexit 1\n')
        checksum.chmod(0o755)
        self.env.update(PATH=f"{wrapper}:{self.env['PATH']}", TEST_RECEIPT=str(receipt))
        result = self.cleanup_legacy()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("cannot verify", result.stderr)
        self.assertTrue(all(file.exists() for file in [*files, receipt]))

    def test_symlinked_legacy_file_is_preserved(self):
        files, receipt = self.legacy_files()
        outside = self.home / "outside"
        outside.write_bytes(files[0].read_bytes())
        files[0].unlink()
        files[0].symlink_to(outside)
        self.cleanup_legacy()
        self.assertTrue(files[0].is_symlink())
        self.assertTrue(receipt.exists())
        self.assertEqual(outside.read_text(), "legacy file")


if __name__ == "__main__":
    unittest.main()
