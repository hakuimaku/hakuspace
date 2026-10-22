#!/usr/bin/env python3
"""Headless appearance policy and real internal engine checks in isolated HOME."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/icon_accent/fixtures"
KDE = (FIXTURES / "kde.svg").read_bytes()
STATIC = (FIXTURES / "symbolic.svg").read_bytes()


def isolated_env(home):
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("HAKU_", "HAKUSPACE_"))
           and key not in ("HYPRLAND_INSTANCE_SIGNATURE", "NIRI_SOCKET")}
    env.update(HOME=str(home), PATH=f"{home}/.local/bin:/usr/bin:/bin",
               XDG_DATA_HOME=str(home / ".local/share"), XDG_STATE_HOME=str(home / ".local/state"),
               XDG_CACHE_HOME=str(home / ".cache"), XDG_CONFIG_HOME=str(home / ".config"),
               PYTHONDONTWRITEBYTECODE="1", HAKUSPACE_STRICT_ASSETS="0")
    return env


def theme_fixture(home, name="Hikaide-Symbols", data=KDE, managed=True):
    directory = home / ".icons" / name
    directory.mkdir(parents=True)
    (directory / "index.theme").write_text(f"[Icon Theme]\nName={name}\n")
    (directory / "user-home.svg").write_bytes(data)
    if managed:
        (directory / ".hikaide-symbols").write_text("Hikaide-Symbols managed theme v1\n")
    return directory


class AppearanceTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.home = Path(self.work.name)
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        for path in (ROOT / "src/core").rglob("*"):
            if path.is_file() and path.name != "README.md":
                (self.bin / path.name).symlink_to(path)
        self.log = self.home / "calls"
        self.env = isolated_env(self.home)
        self.env["CALLS"] = str(self.log)
        for key, name in (("HAKUSPACE_GEN_STYLE", "render"), ("HAKUSPACE_APPLY_STYLE", "apply")):
            path = self.home / name
            path.write_text(f'#!/bin/bash\necho {name} >> "$CALLS"\n')
            path.chmod(0o755)
            self.env[key] = str(path)
        self.stub("gsettings", 'if [[ "$1" == list-schemas ]]; then echo org.gnome.desktop.interface; else echo "gsettings $*" >> "$CALLS"; fi')
        self.stub("hyprctl", 'echo "hyprctl $*" >> "$CALLS"')

    def stub(self, name, code):
        path = self.bin / name
        if path.is_symlink():
            path.unlink()
        path.write_text(f"#!/bin/bash\n{code}\n")
        path.chmod(0o755)

    def run_script(self, name, *args, success=True):
        interpreter = "python3" if name.endswith(".py") else "bash"
        result = subprocess.run([interpreter, str(self.bin / name), *args], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def base_assets(self):
        for relative in (".themes/Hikaide", ".icons/Haku-Dark"):
            directory = self.home / relative
            directory.mkdir(parents=True)
            (directory / "index.theme").write_text("[Icon Theme]\n")

    def assets(self):
        self.base_assets()
        return theme_fixture(self.home)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def icon_accent(self, name="Hikaide-Symbols"):
        return self.run_script("haku_icon_accent.py", "--icons-dir", str(self.home / ".icons"), "status", name).stdout.strip()

    def test_verify_is_read_only(self):
        before = sorted(self.home.rglob("*"))
        self.run_script("appearance_ctl.sh", "verify", success=False)
        self.assertEqual(sorted(self.home.rglob("*")), before)
        self.assets()
        self.run_script("appearance_ctl.sh", "verify")

    def test_apply_only_installed_assets_and_cursor_environment(self):
        self.run_script("appearance_ctl.sh", "apply")
        self.assertEqual(self.calls(), [])
        self.assets()
        self.env["HYPRLAND_INSTANCE_SIGNATURE"] = "test"
        self.run_script("appearance_ctl.sh", "apply")
        self.assertEqual(len(self.calls()), 5)
        self.assertIn("hyprctl setcursor Haku-Dark 24", self.calls())
        self.assertIn("gsettings set org.gnome.desktop.interface cursor-theme Haku-Dark", self.calls())
        self.assertIn("cursor_theme=Haku-Dark", self.run_script("appearance_ctl.sh", "status").stdout)
        environment = self.home / ".config/environment.d/90-hakuspace-cursor.conf"
        self.assertEqual(environment.read_text(), "XCURSOR_THEME=Haku-Dark\nXCURSOR_SIZE=24\n")
        self.assertNotIn("GTK_THEME", environment.read_text())

    def test_exact_light_variant_overrides_legacy_palette(self):
        self.assets()
        self.env.update(HAKU_CURSOR_THEME="Haku-Blue-Light", HAKU_CURSOR_PALETTE="pink",
                        HYPRLAND_INSTANCE_SIGNATURE="test")
        cursor = self.home / ".icons/Haku-Blue-Light"
        cursor.mkdir()
        (cursor / "index.theme").touch()
        self.run_script("appearance_ctl.sh", "verify")
        self.run_script("appearance_ctl.sh", "apply")
        self.assertIn("cursor_theme=Haku-Blue-Light", self.run_script("appearance_ctl.sh", "status").stdout)
        self.assertIn("gsettings set org.gnome.desktop.interface cursor-theme Haku-Blue-Light", self.calls())
        self.assertIn("hyprctl setcursor Haku-Blue-Light 24", self.calls())
        environment = self.home / ".config/environment.d/90-hakuspace-cursor.conf"
        self.assertEqual(environment.read_text(), "XCURSOR_THEME=Haku-Blue-Light\nXCURSOR_SIZE=24\n")

    def test_legacy_palette_resolution_retains_dark_variants(self):
        for palette in ("blue", "cyan", "green", "purple", "pink", "red", "orange", "yellow"):
            with self.subTest(palette=palette):
                self.env["HAKU_CURSOR_PALETTE"] = palette
                status = self.run_script("appearance_ctl.sh", "status").stdout
                self.assertIn(f"cursor_theme=Haku-{palette.capitalize()}\n", status)
                self.assertNotIn(f"cursor_theme=Haku-{palette.capitalize()}-Light", status)

    def test_cursor_overrides_and_no_schema(self):
        self.assets()
        config = self.home / ".config/hakuspace"
        config.mkdir(parents=True)
        (config / "appearance.env").write_text("HAKU_CURSOR_PALETTE=pink\nHAKU_CURSOR_SIZE=32\n")
        cursor = self.home / ".icons/Haku-Pink"
        cursor.mkdir()
        (cursor / "index.theme").touch()
        self.stub("gsettings", "exit 1")
        self.run_script("appearance_ctl.sh", "apply")
        environment = self.home / ".config/environment.d/90-hakuspace-cursor.conf"
        self.assertEqual(environment.read_text(), "XCURSOR_THEME=Haku-Pink\nXCURSOR_SIZE=32\n")
        self.env["HAKUSPACE_STRICT_ASSETS"] = "1"
        self.run_script("appearance_ctl.sh", "apply", success=False)

    def test_canonical_mutations_and_sync_scope(self):
        theme = self.assets()
        self.run_script("theme_ctl.sh", "set-accent", "#AC7994")
        self.assertEqual(self.calls(), ["render", "apply"])
        self.assertEqual(self.icon_accent(), "#ac7994")
        # A reset icon install must stay reset on font/size-only changes.
        (theme / "user-home.svg").write_bytes(KDE)
        self.run_script("theme_ctl.sh", "set-font", "monospace")
        self.run_script("theme_ctl.sh", "set-size", "16")
        self.assertEqual(self.icon_accent(), "#5294e2")
        self.run_script("theme_ctl.sh", "apply")
        self.assertEqual(self.icon_accent(), "#ac7994")

    def test_invalid_accent_does_not_mutate(self):
        self.run_script("theme_ctl.sh", "set-accent", "invalid", success=False)
        self.assertFalse((self.home / ".local/state/hakuspace/state/[theme].appearance.env").exists())
        self.assertEqual(self.calls(), [])

    def test_icon_accent_is_synced_before_live_apply(self):
        """Live reload must read the updated icon artwork."""
        self.assets()
        Path(self.env["HAKUSPACE_APPLY_STYLE"]).write_text(
            '#!/bin/bash\n'
            'python3 "$HOME/.local/bin/haku_icon_accent.py" --icons-dir "$HOME/.icons" '
            'status Hikaide-Symbols >> "$CALLS"\n'
            'echo apply >> "$CALLS"\n'
        )
        self.run_script("theme_ctl.sh", "set-accent", "#AC7994")
        self.assertEqual(self.calls(), ["render", "#ac7994", "apply"])
        self.log.unlink()
        (self.home / ".icons/Hikaide-Symbols/user-home.svg").write_bytes(KDE)
        self.run_script("theme_ctl.sh", "apply")
        self.assertEqual(self.calls(), ["render", "#ac7994", "apply"])

    def test_missing_configured_icons_and_strict_mode(self):
        self.base_assets()
        result = self.run_script("theme_ctl.sh", "set-accent", "#AC7994")
        self.assertIn("warning", result.stderr)
        self.assertEqual(self.run_script("theme_ctl.sh", "get", "accent").stdout.strip(), "#ac7994")
        self.run_script("appearance_ctl.sh", "verify", success=False)
        self.env["HAKUSPACE_STRICT_ASSETS"] = "1"
        self.run_script("theme_ctl.sh", "set-accent", "#5294E2", success=False)
        self.assertEqual(self.run_script("theme_ctl.sh", "get", "accent").stdout.strip(), "#5294e2")
        self.assertEqual(self.calls()[-2:], ["render", "apply"])

    def test_system_mode_without_icon_install_is_valid(self):
        self.base_assets()
        self.env.update(HAKU_ICON_THEME="system", HAKUSPACE_STRICT_ASSETS="1")
        self.run_script("appearance_ctl.sh", "verify")
        self.run_script("appearance_ctl.sh", "apply")
        self.assertFalse(any("icon-theme" in call for call in self.calls()))
        self.assertIn("disabled", self.run_script("appearance_ctl.sh", "sync-accent").stdout)
        status = self.run_script("appearance_ctl.sh", "status").stdout
        self.assertIn("icon_theme_mode=external", status)
        self.assertIn("icon_accent_status=disabled", status)
        self.assertNotIn("icon_accent_available", status)
        self.assertFalse((self.home / ".local/state/icon-accent").exists())

    def test_other_theme_auto_and_explicit_on(self):
        self.base_assets()
        theme = theme_fixture(self.home, "Example", managed=False)
        self.env.update(HAKU_ICON_THEME="Example", HAKUSPACE_STRICT_ASSETS="1")
        self.run_script("appearance_ctl.sh", "verify")
        self.run_script("appearance_ctl.sh", "apply")
        self.assertIn("gsettings set org.gnome.desktop.interface icon-theme Example", self.calls())
        self.run_script("theme_ctl.sh", "set-accent", "#AC7994")
        self.assertEqual((theme / "user-home.svg").read_bytes(), KDE)
        self.env["HAKU_ICON_ACCENT_MODE"] = "on"
        self.run_script("appearance_ctl.sh", "sync-accent")
        self.assertEqual(self.icon_accent("Example"), "#ac7994")

    def test_unmanaged_default_and_off_are_never_edited(self):
        self.base_assets()
        theme = theme_fixture(self.home, managed=False)
        self.env["HAKUSPACE_STRICT_ASSETS"] = "1"
        self.assertIn("not-applicable", self.run_script("appearance_ctl.sh", "sync-accent").stdout)
        self.env["HAKU_ICON_ACCENT_MODE"] = "off"
        self.run_script("theme_ctl.sh", "set-accent", "#AC7994")
        self.assertEqual((theme / "user-home.svg").read_bytes(), KDE)
        self.assertIn("icon_accent_status=disabled", self.run_script("appearance_ctl.sh", "status").stdout)

    def test_static_theme_on_is_not_applicable(self):
        theme = theme_fixture(self.home, "Static", STATIC, managed=False)
        self.env.update(HAKU_ICON_THEME="Static", HAKU_ICON_ACCENT_MODE="on", HAKUSPACE_STRICT_ASSETS="1")
        self.assertIn("not-applicable", self.run_script("appearance_ctl.sh", "sync-accent").stdout)
        self.assertIn("icon_accent_status=not-applicable", self.run_script("appearance_ctl.sh", "status").stdout)
        self.assertEqual((theme / "user-home.svg").read_bytes(), STATIC)

    def test_unsafe_engine_error_preserves_artwork_and_core_state(self):
        theme = self.assets()
        self.run_script("theme_ctl.sh", "set-accent", "#AC7994")
        svg = theme / "user-home.svg"
        edited = svg.read_bytes() + b"\n<!-- user edit -->"
        svg.write_bytes(edited)
        self.run_script("appearance_ctl.sh", "sync-accent")  # already the same accent
        result = self.run_script("theme_ctl.sh", "set-accent", "#5294E2")
        self.assertIn("warning", result.stderr)
        self.run_script("appearance_ctl.sh", "sync-accent", success=False)
        self.assertEqual(svg.read_bytes(), edited)
        self.assertEqual(self.run_script("theme_ctl.sh", "get", "accent").stdout.strip(), "#5294e2")
        self.env["HAKUSPACE_STRICT_ASSETS"] = "1"
        self.run_script("theme_ctl.sh", "apply", success=False)

    def test_corrupted_backup_is_an_actual_error(self):
        theme = self.assets()
        self.run_script("theme_ctl.sh", "set-accent", "#AC7994")
        before = (theme / "user-home.svg").read_bytes()
        backup = next((self.home / ".local/state/icon-accent").glob("*/backup/user-home.svg"))
        backup.write_bytes(b"corrupted")
        self.run_script("theme_ctl.sh", "set-accent", "#5294E2")
        self.run_script("appearance_ctl.sh", "sync-accent", success=False)
        self.assertEqual((theme / "user-home.svg").read_bytes(), before)

    def test_source_tree_resolves_internal_engine(self):
        self.assets()
        (self.bin / "haku_icon_accent.py").unlink()
        result = subprocess.run(["bash", str(ROOT / "src/core/backend/theme/appearance_ctl.sh"), "sync-accent"],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(b"#ffffff", (self.home / ".icons/Hikaide-Symbols/user-home.svg").read_bytes())

    def test_missing_internal_engine_is_a_broken_deployment(self):
        self.assets()
        (self.bin / "haku_icon_accent.py").unlink()
        result = self.run_script("appearance_ctl.sh", "sync-accent", success=False)
        self.assertIn("broken HakuSpace deployment", result.stderr)
        self.run_script("appearance_ctl.sh", "verify", success=False)

    def test_invalid_policy_is_rejected(self):
        self.env["HAKU_ICON_ACCENT_MODE"] = "typo"
        self.run_script("appearance_ctl.sh", "apply", success=False)
        self.assertEqual(self.calls(), [])

    def test_wallpaper_and_classic_share_controller(self):
        self.assets()
        self.stub("wallpaper_set.sh", 'echo wallpaper >> "$CALLS"')
        extractor = self.bin / "get_accent_color.py"
        extractor.unlink()
        extractor.write_text('print("#AC7994")\n')
        wall = self.home / "wall.png"
        wall.write_bytes(b"fixture")
        self.run_script("wallpaper_ctl.sh", "apply-static", str(wall))
        self.assertEqual(self.icon_accent(), "#ac7994")
        self.stub("rofi", 'cat >/dev/null; if [[ "$*" == *"Choose an option"* ]]; then echo "Change Accent Color"; else echo "Blue #5294E2"; fi')
        self.run_script("theme_rofi.sh")
        self.assertEqual(self.icon_accent(), "#5294e2")

    def test_renderer_does_not_persist(self):
        self.run_script("theme_ctl.sh", "set-font", "monospace")
        state = self.home / ".local/state/hakuspace/state/[theme].appearance.env"
        before = state.read_bytes()
        self.run_script("gen_style.sh", "#5294E2", success=False)
        self.run_script("gen_style.sh")
        self.assertEqual(state.read_bytes(), before)
        self.assertTrue((self.home / ".local/state/hakuspace/theme/quickshell.json").exists())


class DeploymentTests(unittest.TestCase):
    def test_copy_and_deep_symlink_modes(self):
        for mode in ("symlink", "copy"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                home = Path(temporary)
                source = home / "hakuspace"
                shutil.copytree(ROOT / "scripts", source / "scripts")
                shutil.copytree(ROOT / "src/core", source / "src/core")
                env = isolated_env(home)
                env["HAKU_DIR"] = str(source)
                result = subprocess.run(["bash", str(source / "scripts/core.sh"), "--mode", mode, "--skip-backup"],
                                        env=env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                engine = home / ".local/bin/haku_icon_accent.py"
                self.assertEqual(engine.is_symlink(), mode == "symlink")
                self.assertTrue(engine.is_file())
                self.assertFalse((home / ".local/bin/kde.svg").exists())
                theme_fixture(home)
                for relative in (".themes/Hikaide", ".icons/Haku-Dark"):
                    directory = home / relative
                    directory.mkdir(parents=True)
                    (directory / "index.theme").touch()
                calls = home / "cursor-calls"
                env.update(CALLS=str(calls), HYPRLAND_INSTANCE_SIGNATURE="test")
                for name, code in (
                    ("gsettings", 'if [ "$1" = list-schemas ]; then echo org.gnome.desktop.interface; else echo "$*" >> "$CALLS"; fi'),
                    ("hyprctl", 'echo "$*" >> "$CALLS"'),
                ):
                    command = home / ".local/bin" / name
                    command.write_text(f"#!/bin/sh\n{code}\n")
                    command.chmod(0o755)
                apply = home / "apply"
                apply.write_text("#!/bin/sh\nexit 0\n")
                apply.chmod(0o755)
                env["HAKUSPACE_APPLY_STYLE"] = str(apply)
                if mode == "copy":
                    shutil.rmtree(source)
                for action in ("status", "verify", "apply"):
                    result = subprocess.run([str(home / ".local/bin/appearance_ctl.sh"), action],
                                            env=env, text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    if action == "status":
                        self.assertIn("cursor_theme=Haku-Dark", result.stdout)
                self.assertIn("cursor-theme Haku-Dark", calls.read_text())
                self.assertIn("setcursor Haku-Dark 24", calls.read_text())
                environment = home / ".config/environment.d/90-hakuspace-cursor.conf"
                self.assertEqual(environment.read_text(), "XCURSOR_THEME=Haku-Dark\nXCURSOR_SIZE=24\n")
                result = subprocess.run([str(home / ".local/bin/theme_ctl.sh"), "set-accent", "#AC7994"],
                                        env=env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                result = subprocess.run(["python3", str(engine), "--icons-dir", str(home / ".icons"),
                                         "status", "Hikaide-Symbols"], env=env, text=True, capture_output=True)
                self.assertEqual(result.stdout.strip(), "#ac7994", result.stderr)


@unittest.skipUnless(os.environ.get("HAKUSPACE_TEST_ASSET_REPOS"), "set HAKUSPACE_TEST_ASSET_REPOS for real asset installation")
class InstalledAssetsTests(unittest.TestCase):
    def test_install_update_reconcile_and_archive_independence(self):
        sources = Path(os.environ["HAKUSPACE_TEST_ASSET_REPOS"]).resolve()
        with tempfile.TemporaryDirectory(prefix="haku-installed-") as temporary:
            home = Path(temporary)
            archive = home / "hakuspace-archive"
            shutil.copytree(sources / "hakuspace-archive", archive,
                            ignore=shutil.ignore_patterns(".git", "__pycache__"))
            binary = home / ".local/bin"
            binary.mkdir(parents=True)
            for path in (ROOT / "src/core").rglob("*"):
                if path.is_file() and path.name != "README.md":
                    (binary / path.name).symlink_to(path)
            env = isolated_env(home)
            env.update(HAKUSPACE_STRICT_ASSETS="1", HAKUSPACE_ARCHIVE_SOURCE=str(archive))
            for key, name in (("CURSOR", "haku-cursor"), ("GTK_THEME", "hikade-gtk-theme"), ("ICON_THEME", "hikaide-symbols")):
                env[f"HAKU_{key}_SOURCE"] = str(sources / name)
            apply = home / "apply"
            apply.write_text("#!/bin/sh\nexit 0\n")
            apply.chmod(0o755)
            env["HAKUSPACE_APPLY_STYLE"] = str(apply)
            settings = binary / "gsettings"
            settings.write_text('#!/bin/sh\nif [ "$1" = list-schemas ]; then echo org.gnome.desktop.interface; fi\n')
            settings.chmod(0o755)

            def run(*args, success=True):
                result = subprocess.run(list(map(str, args)), env=env, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
                return result

            def engine(*args):
                return run("python3", binary / "haku_icon_accent.py", "--icons-dir", home / ".icons", *args)

            def accent_matches(color):
                self.assertEqual(run(binary / "theme_ctl.sh", "get", "accent").stdout.strip().lower(), color.lower())
                report = json.loads(engine("status", "Hikaide-Symbols", "--json").stdout)
                self.assertEqual([c.lower() for c in report["editable_accents"]], [color.lower()])

            run("bash", ROOT / "scripts/assets.sh")
            run(binary / "appearance_ctl.sh", "verify")
            generated = home / ".local/state/hakuspace/theme/quickshell.json"
            self.assertEqual(json.loads(generated.read_text())["accent"], "#ffffff")
            manifest = home / ".local/state/hakuspace/assets/installed.env"
            self.assertNotIn("ICON_ACCENT", manifest.read_text())
            self.assertIn("HAKU_CURSOR_THEME=Haku-Dark", manifest.read_text())
            self.assertIn(f"HAKU_CURSOR_PATH={home}/.icons/Haku-Dark", manifest.read_text())
            self.assertTrue((home / ".icons/Haku-Dark/index.theme").is_file())
            self.assertFalse((home / ".icons/Haku-Light").exists())
            self.assertFalse((home / ".local/share/icons/Haku-Dark").exists())
            self.assertFalse((binary / "icon-accent").exists())
            self.assertFalse((binary / "icon_accent.py").exists())
            self.assertTrue(any((home / "Pictures/Wallpapers").iterdir()))
            # Simulate the previous archive's managed installation and receipt.
            legacy = [binary / "icon-accent", binary / "icon_accent.py"]
            for file in legacy:
                file.write_text("legacy installed file")
            receipt = home / ".local/state/hakuspace/assets/icon-accent.sha256"
            receipt.write_bytes(subprocess.check_output(["sha256sum", *map(str, legacy)]))
            run("bash", ROOT / "scripts/assets.sh")
            self.assertFalse(any(file.exists() for file in [*legacy, receipt]))
            self.assertNotIn("ICON_ACCENT", manifest.read_text())
            self.assertEqual(len(list((home / ".icons").glob("Hikaide-Symbols"))), 1)
            away = home / "archive.test-away"
            archive.rename(away)
            for color in ("#AC7994", "#5294E2", "#AC7994"):
                run(binary / "theme_ctl.sh", "set-accent", color)
                accent_matches(color)
            canonical = home / ".local/state/hakuspace/state/[theme].appearance.env"
            before = canonical.read_bytes()
            backup_states = list((home / ".local/state/icon-accent").glob("*/state.json"))
            self.assertEqual(len(backup_states), 1)
            backup_before = backup_states[0].read_bytes()
            svg = home / ".icons/Hikaide-Symbols/scalable/places/folder.svg"
            svg_before = svg.read_bytes()
            run(binary / "theme_ctl.sh", "set-accent", "#AC7994")
            self.assertEqual(canonical.read_bytes(), before)
            self.assertEqual(backup_states[0].read_bytes(), backup_before)
            self.assertEqual(svg.read_bytes(), svg_before)
            engine("restore", "Hikaide-Symbols")
            run(binary / "theme_ctl.sh", "apply")
            accent_matches("#AC7994")
            run("bash", sources / "hikaide-symbols/scripts/install.sh", "--replace")
            self.assertNotEqual(engine("status", "Hikaide-Symbols").stdout.strip().lower(), "#ac7994")
            run(binary / "theme_ctl.sh", "apply")
            accent_matches("#AC7994")
            setter = binary / "wallpaper_set.sh"
            setter.unlink()
            setter.write_text("#!/bin/sh\nexit 0\n")
            setter.chmod(0o755)
            env["ACCENT_COLOR_BASED_ON_WALLPAPER"] = "true"
            wallpaper = next((home / "Pictures/Wallpapers").glob("*.jpg"))
            run(binary / "wallpaper_ctl.sh", "apply-static", wallpaper)
            wallpaper_accent = run(binary / "theme_ctl.sh", "get", "accent").stdout.strip()
            accent_matches(wallpaper_accent)
            icons = home / ".icons/Hikaide-Symbols"
            (icons / ".hikaide-symbols").unlink()
            svg_before = svg.read_bytes()
            rejected = run("bash", sources / "hikaide-symbols/scripts/install.sh", "--replace", success=False)
            self.assertIn("unmanaged", rejected.stderr)
            self.assertEqual(svg.read_bytes(), svg_before)
            away.rename(archive)


if __name__ == "__main__":
    unittest.main()
