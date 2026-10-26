#!/usr/bin/env python3
"""Headless appearance policy and real internal engine checks in isolated HOME."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
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
        self.stub("gsettings", r'''if [[ "$1" == list-schemas ]]; then
    echo org.gnome.desktop.interface
elif [[ "$1" == get ]]; then
    case "$3" in
        gtk-theme) fallback="${HAKU_GTK_THEME:-Hikaide}" ;;
        icon-theme) fallback="${HAKU_ICON_THEME:-Hikaide-Symbols}" ;;
        *) exit 1 ;;
    esac
    if [[ -f "$HOME/selected-$3" ]]; then fallback="$(cat "$HOME/selected-$3")"; fi
    printf "'%s'\n" "$fallback"
else
    echo "gsettings $*" >> "$CALLS"
    case "$3" in gtk-theme|icon-theme) printf '%s\n' "$4" > "$HOME/selected-$3" ;; esac
fi''')
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
        self.env.update(HAKU_CURSOR_PALETTE="pink", HAKU_CURSOR_SIZE="32")
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
        self.assertFalse(any("icon-theme" in call for call in self.calls()))
        self.run_script("theme_ctl.sh", "set-accent", "#AC7994")
        self.assertEqual((theme / "user-home.svg").read_bytes(), KDE)
        self.env["HAKU_ICON_ACCENT_MODE"] = "on"
        self.assertIn("disabled", self.run_script("appearance_ctl.sh", "sync-accent").stdout)
        self.assertEqual((theme / "user-home.svg").read_bytes(), KDE)

    def test_unmanaged_default_and_off_are_never_edited(self):
        self.base_assets()
        theme = theme_fixture(self.home, managed=False)
        self.env["HAKUSPACE_STRICT_ASSETS"] = "1"
        self.assertIn("not-applicable", self.run_script("appearance_ctl.sh", "sync-accent").stdout)
        self.env["HAKU_ICON_ACCENT_MODE"] = "off"
        self.run_script("theme_ctl.sh", "set-accent", "#AC7994")
        self.assertEqual((theme / "user-home.svg").read_bytes(), KDE)
        self.assertIn("icon_accent_status=disabled", self.run_script("appearance_ctl.sh", "status").stdout)

    def test_third_party_static_theme_on_is_blocked(self):
        theme = theme_fixture(self.home, "Static", STATIC, managed=False)
        self.env.update(HAKU_ICON_THEME="Static", HAKU_ICON_ACCENT_MODE="on", HAKUSPACE_STRICT_ASSETS="1")
        self.assertIn("disabled", self.run_script("appearance_ctl.sh", "sync-accent").stdout)
        self.assertIn("icon_accent_status=disabled", self.run_script("appearance_ctl.sh", "status").stdout)
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

    def test_dark_seed_syncs_icons_to_dark_variant(self):
        """Wallpaper/manual seed polarity never leaks a dark accent into global icons."""
        self.assets()
        self.run_script("theme_ctl.sh", "set-accent", "#000000")
        dark = self.run_script("theme_ctl.sh", "get", "accent").stdout.strip()
        self.assertNotEqual(dark, "#000000")
        self.assertEqual(self.icon_accent().lower(), dark.lower())

    def test_renderer_does_not_persist(self):
        self.run_script("theme_ctl.sh", "set-font", "monospace")
        state = self.home / ".local/state/hakuspace/state/[theme].appearance.env"
        before = state.read_bytes()
        self.run_script("gen_style.sh", "#5294E2", success=False)
        self.run_script("gen_style.sh")
        self.assertEqual(state.read_bytes(), before)
        self.assertTrue((self.home / ".local/state/hakuspace/theme/quickshell.json").exists())

    def paired_icon_assets(self):
        """Create the v2 dark/light family with independent managed metadata."""
        self.base_assets()
        themes = {}
        for variant, name in (("dark", "Hikaide-Symbols"), ("light", "Hikaide-Symbols-Light")):
            directory = theme_fixture(self.home, name, managed=False)
            (directory / ".hikaide-symbols.json").write_text(json.dumps({
                "family": "Hikaide-Symbols", "version": 2, "variant": variant}))
            themes[variant] = directory
        state = self.home / ".local/state/hakuspace/state/[theme].appearance.env"
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_text("THEME_STATE_VERSION=2\nACCENT_SEED='#A2CB8B'\n"
                         "ACCENT_DARK='#A2CB8B'\nACCENT_LIGHT='#3F6E2B'\nFONT_FAMILY=monospace\nFONT_SIZE=14\n")
        return themes, state

    def test_v2_pair_uses_both_canonical_accents(self):
        """Both configured family names reconcile the same precomputed pair."""
        themes, state = self.paired_icon_assets()
        before = state.read_bytes()
        for configured in ("Hikaide-Symbols", "Hikaide-Symbols-Light"):
            self.env["HAKU_ICON_THEME"] = configured
            self.run_script("appearance_ctl.sh", "sync-accent")
            self.assertEqual(self.icon_accent(), "#a2cb8b")
            self.assertEqual(self.icon_accent("Hikaide-Symbols-Light"), "#3f6e2b")
            status = self.run_script("appearance_ctl.sh", "status").stdout
            self.assertIn("icon_accent_status=active", status)
            self.assertIn("icon_accent_dark=#A2CB8B", status)
            self.assertIn("icon_accent_light=#3F6E2B", status)
        self.assertEqual(before, state.read_bytes())
        self.assertEqual(self.calls(), [])

    def test_v2_pair_reconcile_is_idempotent(self):
        """Repeated reconcile does not rewrite already-correct SVG artwork."""
        themes, _ = self.paired_icon_assets()
        self.run_script("appearance_ctl.sh", "sync-accent")
        paths = [theme / "user-home.svg" for theme in themes.values()]
        before = [(path.read_bytes(), path.stat().st_mtime_ns) for path in paths]
        self.run_script("appearance_ctl.sh", "sync-accent")
        self.assertEqual(before, [(path.read_bytes(), path.stat().st_mtime_ns) for path in paths])

    def test_v2_pair_requires_safe_matching_metadata(self):
        """Unrecognized and symlinked sibling markers never authorize mutation."""
        themes, _ = self.paired_icon_assets()
        metadata = themes["light"] / ".hikaide-symbols.json"
        valid = metadata.read_text()
        for invalid in ('{', valid.replace('"light"', '"dark"')):
            metadata.write_text(invalid)
            self.assertIn("not-applicable", self.run_script("appearance_ctl.sh", "sync-accent").stdout)
            self.assertEqual((themes["dark"] / "user-home.svg").read_bytes(), KDE)
        outside = self.home / "marker.json"
        outside.write_text(valid)
        metadata.unlink()
        metadata.symlink_to(outside)
        self.assertIn("not-applicable", self.run_script("appearance_ctl.sh", "sync-accent").stdout)
        self.assertEqual((themes["dark"] / "user-home.svg").read_bytes(), KDE)

    def test_v2_pair_missing_light_preserves_dark(self):
        """Missing pair members warn or fail before changing the installed sibling."""
        themes, _ = self.paired_icon_assets()
        shutil.rmtree(themes["light"])
        result = self.run_script("appearance_ctl.sh", "sync-accent")
        self.assertIn("warning", result.stderr)
        self.env["HAKUSPACE_STRICT_ASSETS"] = "1"
        self.run_script("appearance_ctl.sh", "sync-accent", success=False)
        self.assertEqual((themes["dark"] / "user-home.svg").read_bytes(), KDE)
        self.assertIn("icon_accent_status=missing", self.run_script("appearance_ctl.sh", "status").stdout)

    def test_v2_pair_dry_run_failure_preserves_both(self):
        """An unsupported light tree cannot leave only the dark tree recolored."""
        themes, _ = self.paired_icon_assets()
        (themes["light"] / "user-home.svg").write_bytes(STATIC)
        self.assertIn("not-applicable", self.run_script("appearance_ctl.sh", "sync-accent").stdout)
        self.assertEqual((themes["dark"] / "user-home.svg").read_bytes(), KDE)
        self.assertEqual((themes["light"] / "user-home.svg").read_bytes(), STATIC)

    def test_v2_pair_second_update_failure_rolls_back_both(self):
        """Restore both old accents when the light engine fails after writing."""
        themes, _ = self.paired_icon_assets()
        engine = self.bin / "haku_icon_accent.py"
        real_engine = engine.resolve()
        engine.unlink()
        engine.write_text(
            'import os, subprocess, sys\n'
            f'command = [sys.executable, {str(real_engine)!r}, *sys.argv[1:]]\n'
            'result = subprocess.run(command)\n'
            'if "set" in sys.argv and "#3F6E2B" in sys.argv and "Hikaide-Symbols-Light" in sys.argv and "--dry-run" not in sys.argv:\n'
            '    sys.exit(5)\n'
            'sys.exit(result.returncode)\n')
        result = self.run_script("appearance_ctl.sh", "sync-accent", success=False)
        self.assertIn("engine failed", result.stderr)
        for theme in themes.values():
            self.assertEqual((theme / "user-home.svg").read_bytes(), KDE)


    def test_v2_pair_rollback_error_still_restores_dark(self):
        """Report a failed light restore while continuing to restore the dark tree."""
        themes, _ = self.paired_icon_assets()
        engine = self.bin / "haku_icon_accent.py"
        real_engine = engine.resolve()
        engine.unlink()
        engine.write_text(
            'import subprocess, sys\n'
            f'command = [sys.executable, {str(real_engine)!r}, *sys.argv[1:]]\n'
            'light_write = "set" in sys.argv and "Hikaide-Symbols-Light" in sys.argv and "--dry-run" not in sys.argv\n'
            'if light_write and "#5294e2" in sys.argv: sys.exit(5)\n'
            'result = subprocess.run(command)\n'
            'sys.exit(5 if light_write else result.returncode)\n')
        result = self.run_script("appearance_ctl.sh", "sync-accent", success=False)
        self.assertIn("rollback failed for Hikaide-Symbols-Light", result.stderr)
        self.assertEqual((themes["dark"] / "user-home.svg").read_bytes(), KDE)
        self.assertEqual(self.icon_accent("Hikaide-Symbols-Light"), "#3f6e2b")

    def mode_assets(self):
        """Install disposable dark/light GTK and icon families for mode selection."""
        themes, state = self.paired_icon_assets()
        for name in ("Hikaide", "Hikaide-Light"):
            root = self.home / ".themes" / name
            root.mkdir(exist_ok=True)
            (root / "index.theme").write_text("[Desktop Entry]\n")
            (root / "gtk-4.0").mkdir()
            for css in ("gtk.css", "gtk-dark.css"):
                (root / "gtk-4.0" / css).write_text("/* Fixture stylesheet. */\n")
        return themes, state

    def test_apply_mode_selects_prebuilt_pair_without_accent_mutation(self):
        """Repeated mode changes select names without extracting colors or touching SVGs."""
        themes, state = self.mode_assets()
        paths = [theme / "user-home.svg" for theme in themes.values()]
        before = [(p.read_bytes(), p.stat().st_mtime_ns) for p in paths]
        canonical = state.read_bytes()
        for mode in ("light", "dark", "light"):
            self.run_script("appearance_ctl.sh", "apply-mode", mode)
            suffix = "-Light" if mode == "light" else ""
            self.assertIn(f"gsettings set org.gnome.desktop.interface gtk-theme Hikaide{suffix}", self.calls())
            self.assertIn(f"gsettings set org.gnome.desktop.interface icon-theme Hikaide-Symbols{suffix}", self.calls())
            for version in ("3.0", "4.0"):
                settings = (self.home / f".config/gtk-{version}/settings.ini").read_text()
                self.assertIn(f"gtk-theme-name=Hikaide{suffix}\n", settings)
                self.assertIn(f"gtk-icon-theme-name=Hikaide-Symbols{suffix}\n", settings)
                self.assertIn("gtk-application-prefer-dark-theme=0\n", settings)
        self.assertEqual(before, [(p.read_bytes(), p.stat().st_mtime_ns) for p in paths])
        self.assertEqual(canonical, state.read_bytes())
        self.assertFalse(any("color-scheme" in call or "cursor-" in call for call in self.calls()))
        self.assertFalse((self.home / ".config/environment.d").exists())

    def test_apply_mode_preserves_custom_settings_and_retargets_managed_css(self):
        """Existing Hikaide CSS aliases follow mode while fonts and user CSS survive."""
        self.mode_assets()
        config = self.home / ".config/gtk-4.0"
        config.mkdir(parents=True)
        settings = config / "settings.ini"
        settings.write_text("[Settings]\n# Keep font configuration.\ngtk-font-name=Fixture Mono 18\ngtk-theme-name=Hikaide\n")
        for name in ("gtk.css", "gtk-dark.css"):
            (config / name).symlink_to(self.home / ".themes/Hikaide/gtk-4.0" / name)
        for mode in ("light", "dark"):
            self.run_script("appearance_ctl.sh", "apply-mode", mode)
            theme = "Hikaide-Light" if mode == "light" else "Hikaide"
            self.assertIn("# Keep font configuration.\ngtk-font-name=Fixture Mono 18", settings.read_text())
            for name in ("gtk.css", "gtk-dark.css"):
                self.assertEqual((config / name).readlink(), self.home / ".themes" / theme / "gtk-4.0" / name)
        (config / "gtk.css").unlink()
        (config / "gtk.css").write_text("/* User CSS. */\n")
        self.run_script("appearance_ctl.sh", "apply-mode", "light")
        self.assertEqual((config / "gtk.css").read_text(), "/* User CSS. */\n")

    def test_apply_resolves_classic_dark_and_saved_hikai_mode(self):
        """Classic ignores the saved Light choice; Hikai restores it without changing preferences."""
        self.mode_assets()
        preferences = self.home / "hakucfg/hikai/hikai-shell.json"
        self.env["HAKUSPACE_HIKAI_SETTINGS_FILE"] = str(preferences)
        self.env["HAKUSPACE_HIKAI_SETTINGS_JSON"] = json.dumps({"appearance": {"colorMode": "light"}})
        self.run_script("hikai_settings_ctl.py", "write")
        saved = preferences.read_bytes()
        backend = self.home / ".local/state/hakuspace/state/[shell].backend"
        for context, expected in (("classic", "Hikaide"), ("hikai", "Hikaide-Light"), ("classic", "Hikaide")):
            backend.write_text(context + "\n")
            self.log.unlink(missing_ok=True)
            self.run_script("appearance_ctl.sh", "apply")
            self.assertIn(f"gsettings set org.gnome.desktop.interface gtk-theme {expected}", self.calls())
            self.assertEqual(preferences.read_bytes(), saved)

    def test_apply_mode_custom_themes_and_system_icons(self):
        """Third-party selections and native settings never change during a mode switch."""
        self.mode_assets()
        self.env.update(HAKU_GTK_THEME="Example", HAKU_ICON_THEME="ExampleIcons")
        config = self.home / ".config/gtk-3.0/settings.ini"
        config.parent.mkdir(parents=True)
        original = "[Settings]\ngtk-theme-name=Example\ngtk-icon-theme-name=ExampleIcons\n"
        config.write_text(original)
        for mode in ("light", "dark"):
            self.run_script("appearance_ctl.sh", "apply-mode", mode)
            self.assertEqual(self.calls(), [])
            self.assertEqual(config.read_text(), original)
        self.env["HAKU_ICON_THEME"] = "system"
        self.run_script("appearance_ctl.sh", "apply-mode", "light")
        self.assertEqual(self.calls(), [])
        self.assertEqual(config.read_text(), original)

    def test_apply_mode_rejects_missing_assets_and_invalid_modes_before_mutation(self):
        """A bad request or incomplete pair never selects only one new theme."""
        self.mode_assets()
        self.run_script("appearance_ctl.sh", "apply-mode", "invalid", success=False)
        self.assertEqual(self.calls(), [])
        shutil.rmtree(self.home / ".icons/Hikaide-Symbols-Light")
        self.run_script("appearance_ctl.sh", "apply-mode", "light")
        self.env["HAKUSPACE_STRICT_ASSETS"] = "1"
        self.run_script("appearance_ctl.sh", "apply-mode", "light", success=False)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.home / ".config/gtk-3.0/settings.ini").exists())


    def test_removed_appearance_file_cannot_override_or_execute(self):
        """An old override file is ignored rather than sourced by the controller."""
        self.mode_assets()
        legacy = self.home / ".config/hakuspace/appearance.env"
        legacy.parent.mkdir(parents=True)
        legacy.write_text('HAKU_GTK_THEME=Unexpected\nHAKU_ICON_THEME=UnexpectedIcons\n'
                          'HAKU_CURSOR_THEME=UnexpectedCursor\nHAKU_CURSOR_SIZE=48\n'
                          'touch "$HOME/legacy-config-executed"\n')
        status = self.run_script("appearance_ctl.sh", "status").stdout
        self.assertIn("gtk_theme=Hikaide\n", status)
        self.assertIn("icon_theme=Hikaide-Symbols\n", status)
        self.assertIn("cursor_theme=Haku-Dark\n", status)
        self.assertIn("cursor_size=24\n", status)
        self.assertFalse((self.home / "legacy-config-executed").exists())
        self.run_script("appearance_ctl.sh", "apply-mode", "light")
        self.assertIn("gsettings set org.gnome.desktop.interface gtk-theme Hikaide-Light", self.calls())

    def test_active_third_party_icons_block_all_accent_writes(self):
        """The actual desktop choice blocks recoloring even with the legacy on override."""
        self.mode_assets()
        theme_fixture(self.home, "Example", managed=False)
        (self.home / "selected-icon-theme").write_text("Example")
        self.env["HAKU_ICON_ACCENT_MODE"] = "on"
        before = {str(path): path.read_bytes() for path in (self.home / ".icons").rglob("*.svg")}
        result = self.run_script("appearance_ctl.sh", "sync-accent")
        self.assertIn("icon_accent_status=disabled", result.stdout)
        self.run_script("theme_ctl.sh", "set-accent", "#7AA2F7")
        self.assertEqual(before, {str(path): path.read_bytes() for path in (self.home / ".icons").rglob("*.svg")})
        self.assertFalse((self.home / ".local/state/icon-accent").exists())

    def test_mode_switch_changes_only_the_active_managed_component(self):
        """Custom GTK and icon selections are preserved independently."""
        self.mode_assets()
        config = self.home / ".config/gtk-3.0/settings.ini"
        config.parent.mkdir(parents=True)
        for gtk, icons, changed in (("Example", "Hikaide-Symbols", "icon-theme"),
                                    ("Hikaide", "ExampleIcons", "gtk-theme")):
            with self.subTest(gtk=gtk, icons=icons):
                (self.home / "selected-gtk-theme").write_text(gtk)
                (self.home / "selected-icon-theme").write_text(icons)
                config.write_text(f"[Settings]\ngtk-theme-name={gtk}\ngtk-icon-theme-name={icons}\n")
                self.log.unlink(missing_ok=True)
                self.run_script("appearance_ctl.sh", "apply-mode", "light")
                self.assertEqual(len(self.calls()), 1)
                self.assertIn(f" {changed} ", self.calls()[0])
                settings = config.read_text()
                if gtk == "Example":
                    self.assertIn("gtk-theme-name=Example\n", settings)
                    self.assertIn("gtk-icon-theme-name=Hikaide-Symbols-Light\n", settings)
                else:
                    self.assertIn("gtk-theme-name=Hikaide-Light\n", settings)
                    self.assertIn("gtk-icon-theme-name=ExampleIcons\n", settings)



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
                    ("gsettings", """if [ "$1" = list-schemas ]; then echo org.gnome.desktop.interface; elif [ "$1" = get ]; then case "$3" in gtk-theme) echo "'Hikaide'" ;; icon-theme) echo "'Hikaide-Symbols'" ;; esac; else echo "$*" >> "$CALLS"; fi"""),
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
            self.assertEqual(json.loads(generated.read_text())["accentDark"], "#ffffff")
            manifest = home / ".local/state/hakuspace/assets/installed.env"
            self.assertNotIn("ICON_ACCENT", manifest.read_text())
            self.assertIn("HAKU_CURSOR_THEME=Haku-Dark", manifest.read_text())
            self.assertIn(f"HAKU_CURSOR_PATH={home}/.icons/Haku-Dark", manifest.read_text())
            self.assertTrue((home / ".icons/Haku-Dark/index.theme").is_file())
            self.assertFalse((home / ".icons/Haku-Light").exists())
            self.assertFalse((home / ".local/share/icons/Haku-Dark").exists())
            self.assertTrue((home / ".themes/Hikaide/index.theme").is_file())
            self.assertTrue((home / ".themes/Hikaide-Light/index.theme").is_file())
            self.assertTrue((home / ".icons/Hikaide-Symbols/index.theme").is_file())
            self.assertTrue((home / ".icons/Hikaide-Symbols-Light/index.theme").is_file())
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
            self.assertEqual(len(list((home / ".icons").glob("Hikaide-Symbols-Light"))), 1)
            self.assertEqual(len(list((home / ".themes").glob("Hikaide"))), 1)
            self.assertEqual(len(list((home / ".themes").glob("Hikaide-Light"))), 1)
            away = home / "archive.test-away"
            archive.rename(away)
            for color in ("#AC7994", "#5294E2", "#AC7994"):
                run(binary / "theme_ctl.sh", "set-accent", color)
                accent_matches(color)
            canonical = home / ".local/state/hakuspace/state/[theme].appearance.env"
            before = canonical.read_bytes()
            backup_states = list((home / ".local/state/icon-accent").glob("*/state.json"))
            self.assertEqual(len(backup_states), 2)
            backup_before = {p: p.read_bytes() for p in backup_states}
            svg = home / ".icons/Hikaide-Symbols/scalable/places/folder.svg"
            svg_before = svg.read_bytes()
            run(binary / "theme_ctl.sh", "set-accent", "#AC7994")
            self.assertEqual(canonical.read_bytes(), before)
            self.assertEqual({p: p.read_bytes() for p in backup_states}, backup_before)
            self.assertEqual(svg.read_bytes(), svg_before)
            engine("restore", "Hikaide-Symbols")
            engine("restore", "Hikaide-Symbols-Light")
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
            marker = (icons / ".hikaide-symbols.json") if (icons / ".hikaide-symbols.json").exists() else (icons / ".hikaide-symbols")
            marker.unlink()
            svg_before = svg.read_bytes()
            rejected = run("bash", sources / "hikaide-symbols/scripts/install.sh", "--replace", success=False)
            self.assertIn("unmanaged", rejected.stderr)
            self.assertEqual(svg.read_bytes(), svg_before)
            away.rename(archive)


if __name__ == "__main__":
    unittest.main()
