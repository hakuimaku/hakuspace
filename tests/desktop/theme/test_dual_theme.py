#!/usr/bin/env python3
"""Check accent contrast, canonical migration, and Classic-only opaque output."""
import colorsys
import importlib.util
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import unittest

# Load the deployed color primitive without importing wallpaper dependencies.
ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("accent_palette", ROOT / "src/core/theme/accent_palette.py")
palette = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(palette)


class PaletteTests(unittest.TestCase):
    """Protect contrast and hue for edge colors and a deterministic seed sample."""

    def test_contrast_on_every_surface(self):
        """Both variants remain readable, including quantized RGB boundary values."""
        seeds = ["#000000", "#010101", "#ffffff", "#fefefe", "#ff0000", "#00ff00", "#0000ff",
                 "#808080", "#a2cb8b", "#5294e2", "invalid", "#NaN000"]
        generator = random.Random(7)
        seeds += [f"#{generator.randrange(0x1000000):06x}" for _ in range(256)]
        for seed in seeds:
            result = palette.derive(seed)
            for mode, surfaces in (("dark", ("#000000", "#0b0b0b", "#171717")),
                                   ("light", ("#ffffff", "#eeeeee", "#d6d6d6"))):
                self.assertRegex(result[mode], r"^#[0-9a-f]{6}$")
                for surface in surfaces:
                    self.assertGreaterEqual(palette.contrast(result[mode], surface), 7 if mode == "light" else 4.5, (seed, result, surface))

    def test_hue_grayscale_and_unchanged_passing_seeds(self):
        """Adjustments preserve color identity while readable seeds stay exact."""
        for seed in ("#808080", "#ffffff", "#000000"):
            for color in palette.derive(seed).values():
                self.assertEqual(color[1:3], color[3:5])
                self.assertEqual(color[3:5], color[5:7])
        for seed in ("#a2cb8b", "#5294e2", "#ff0000", "#123456"):
            for mode, surface in (("dark", "#171717"), ("light", "#d6d6d6")):
                color = palette.derive(seed)[mode]
                if palette.contrast(seed, surface) >= (7 if mode == "light" else 4.5):
                    self.assertEqual(color, seed)
                original = colorsys.rgb_to_hls(*(int(seed[i:i+2], 16) / 255 for i in (1, 3, 5)))[0]
                adjusted = colorsys.rgb_to_hls(*(int(color[i:i+2], 16) / 255 for i in (1, 3, 5)))[0]
                self.assertLess(min(abs(original - adjusted), 1 - abs(original - adjusted)), 0.01)


class ThemeTests(unittest.TestCase):
    """Run production controllers against disposable state and inert reload hooks."""

    def setUp(self):
        """Flatten scripts with the same layout as the installed package."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.binary = self.home / ".local/bin"
        self.binary.mkdir(parents=True)
        for path in (ROOT / "src/core").rglob("*"):
            if path.is_file() and path.name != "README.md":
                (self.binary / path.name).symlink_to(path)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("HAKU_", "HAKUSPACE_"))}
        self.env.update(HOME=str(self.home), XDG_STATE_HOME=str(self.home / ".local/state"),
                        PATH=f"{self.binary}:/usr/bin:/bin", HAKUSPACE_APPLY_STYLE="/usr/bin/true",
                        HAKUSPACE_STRICT_ASSETS="0", PYTHONDONTWRITEBYTECODE="1")
        self.state = self.home / ".local/state/hakuspace/state"
        self.state.mkdir(parents=True)
        self.render = self.home / ".local/state/hakuspace/theme"
        self.canonical = self.state / "[theme].appearance.env"

    def run_script(self, name, *args, success=True):
        """Retain stdout and stderr when a public command fails."""
        result = subprocess.run(["bash", self.binary / name, *args], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result.stdout.strip()

    def test_seed_pair_and_global_dark_consumers(self):
        """A dark seed is preserved while Classic, icons and generated files use dark."""
        self.run_script("theme_ctl.sh", "set-accent", "#123456")
        expected = palette.derive("#123456")
        state = self.canonical.read_text()
        self.assertIn("THEME_STATE_VERSION=2", state)
        self.assertNotIn("ACCENT_COLOR=", state)
        for field, key in (("SEED", "seed"), ("DARK", "dark"), ("LIGHT", "light")):
            self.assertIn(f'ACCENT_{field}={expected[key]}', state.replace("\\", ""))
        self.assertEqual(self.run_script("theme_ctl.sh", "get", "accent"), expected["dark"])
        generated = json.loads((self.render / "quickshell.json").read_text())
        self.assertEqual(generated["accentDark"], expected["dark"])
        self.assertEqual(generated["accentLight"], expected["light"])
        for name in ("kitty-style.conf", "rofi-style.rasi", "niri-style.kdl", "colors.css", "newtab.css"):
            content = (self.render / name).read_text()
            self.assertIn(expected["dark"], content, name)
            self.assertNotIn(expected["light"], content, name)
        before = self.canonical.read_bytes()
        self.run_script("theme_ctl.sh", "set-accent", "invalid", success=False)
        self.assertEqual(self.canonical.read_bytes(), before)

    def test_symlinked_library_resolves_new_palette_before_deployment(self):
        """Existing symlink installs can find a newly added source-tree color engine."""
        (self.binary / "accent_palette.py").unlink()
        self.assertEqual(self.run_script("theme_ctl.sh", "get", "accent"), "#ffffff")

    def test_apply_refreshes_existing_light_accent_from_saved_seed(self):
        """Existing pairs gain stronger light contrast without changing seed or dark output."""
        self.canonical.write_text('THEME_STATE_VERSION=2\nACCENT_SEED="#a2cb8b"\n'
                                  'ACCENT_DARK="#a2cb8b"\nACCENT_LIGHT="#527c37"\n'
                                  'FONT_FAMILY="Fixture Mono"\nFONT_SIZE=18\n')
        self.run_script("theme_ctl.sh", "apply")
        generated = json.loads((self.render / "quickshell.json").read_text())
        self.assertEqual(generated["accentSeed"], "#a2cb8b")
        self.assertEqual(generated["accentDark"], "#a2cb8b")
        self.assertEqual(generated["font"], "Fixture Mono")
        self.assertEqual(generated["fontSize"], 18)
        self.assertGreaterEqual(palette.contrast(generated["accentLight"], "#d6d6d6"), 7)
        self.assertEqual(generated["accentLight"], palette.derive("#a2cb8b")["light"])

    def test_legacy_state_migrates_once_and_preserves_fonts(self):
        """Legacy state needs no generated-file recovery and migrates atomically."""
        self.canonical.write_text('ACCENT_COLOR="#123456"\nFONT_FAMILY="Fixture Mono"\nFONT_SIZE=18\n')
        with self.canonical.open() as old:
            self.run_script("theme_ctl.sh", "get", "accent")
            self.assertNotIn("THEME_STATE_VERSION", old.read())
        self.assertIn("FONT_FAMILY=Fixture\\ Mono", self.canonical.read_text())
        self.assertIn("FONT_SIZE=18", self.canonical.read_text())
        inode = self.canonical.stat().st_ino
        self.run_script("gen_style.sh")
        self.assertEqual(self.canonical.stat().st_ino, inode)
        self.assertEqual(list(self.state.glob("*.??????")), [])

    def test_context_reload_preserves_shell_service_owners(self):
        """Under-cover reload touches the WM and Kitty without restarting shell services."""
        log = self.home / "reload-calls"
        for name in ("reload_config.sh", "desktop_icons_manager.sh", "cava_manager.sh", "gsettings", "swaync-client", "kitty"):
            path = self.binary / name
            if path.is_symlink():
                path.unlink()
            path.write_text('#!/bin/sh\n' + ('exit 1\n' if name == "kitty" else
                            'echo "' + name + '" >> "$HOME/reload-calls"\n'))
            path.chmod(0o755)
        self.run_script("apply_style.sh", "--opaque-context")
        self.assertEqual(log.read_text().splitlines(), ["reload_config.sh"])
        (self.binary / "reload_config.sh").write_text("#!/bin/sh\nexit 1\n")
        self.run_script("apply_style.sh", "--opaque-context", success=False)

    def test_opaque_requested_effective_matrix(self):
        """Context changes clear all overrides while preserving the opaque request."""
        request = self.state / "[theme].opaque.enabled"
        backend = self.state / "[shell].backend"
        backend.write_text("classic\n")
        for enabled in (False, True):
            self.run_script("opaque_theme.sh", "on" if enabled else "off")
            for context in ("classic", "hikai", "classic"):
                self.run_script("opaque_theme.sh", "sync", context)
                effective = enabled and context == "classic"
                self.assertEqual(request.read_text().strip(), str(int(enabled)))
                self.assertEqual(backend.read_text(), "classic\n")
                for name in ("kitty.conf", "hyprland.lua", "niri.kdl", "waybar.css", "rofi.rasi", "swaync.css"):
                    content = (self.render / "opaque" / name).read_text().strip()
                    self.assertEqual(bool(content), effective, (context, name))
                if effective:
                    self.assertEqual((self.render / "opaque/kitty.conf").read_text().strip(), "background_opacity 1.0")
                    if shutil.which("luac"):
                        subprocess.run(["luac", "-p", self.render / "opaque/hyprland.lua"], check=True)
                    if shutil.which("niri"):
                        config = self.home / "niri.kdl"
                        config.write_text('window-rule {\n match is-active=false\n opacity 0.9\n}\n'
                                          'window-rule {\n match app-id="^kitty$"\n opacity 0.85\n}\n'
                                          f'include "{self.render}/opaque/niri.kdl"\n')
                        result = subprocess.run(["niri", "validate", "-c", config], capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.run_script("opaque_theme.sh", "sync", "invalid", success=False)
        kitty = (ROOT / "src/home/.config/kitty/kitty.conf").read_text()
        self.assertGreater(kitty.index("include ~/.local/state/hakuspace/theme/opaque/kitty.conf"),
                           kitty.index("include ~/hakucfg/config/kitty.conf"))


if __name__ == "__main__":
    unittest.main()
