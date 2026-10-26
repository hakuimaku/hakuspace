#!/usr/bin/env python3
"""Check Hikai Kitty palettes, atomic restoration and independent socket reloads."""
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

# Import the same renderer used by the shell and the deployed flat script directory.
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "src/core/theme"))
import kitty_theme_ctl as ctl
from accent_palette import contrast, derive


class KittyThemeTests(unittest.TestCase):
    """Keep every generated override and terminal command isolated."""

    def test_light_palette_has_readable_ansi_and_selection(self):
        """Every ANSI slot remains readable on all three Light surfaces."""
        for surface in ("#ffffff", "#eeeeee", "#d6d6d6"):
            accent = derive("#ca8f5f")["light"]
            colors = dict(line.split() for line in ctl.render("light", surface, accent).splitlines())
            self.assertEqual(colors["background"], surface)
            self.assertEqual(colors["foreground"], accent)
            self.assertEqual(colors["selection_foreground"], surface)
            self.assertEqual(colors["selection_background"], accent)
            for index in range(16):
                self.assertGreaterEqual(contrast(colors[f"color{index}"], surface), 4.5)
            self.assertNotIn("background_opacity", colors)
            self.assertNotIn("font_size", colors)

    def test_preview_dark_restore_and_unchanged_custom_settings(self):
        """Idempotent previews preserve custom files and restore Dark with an empty override."""
        with tempfile.TemporaryDirectory() as temporary, patch.object(ctl, "reload_kitty") as reload:
            home = Path(temporary)
            custom = home / "hakucfg/config/kitty.conf"
            custom.parent.mkdir(parents=True)
            original = "background #123456\nfont_size 19\nbackground_opacity 0.7\n"
            custom.write_text(original)
            with patch.object(ctl.Path, "home", return_value=home):
                ctl.sync("dark")
                override = home / ".local/state/hakuspace/theme/kitty-mode.conf"
                with override.open() as old:
                    ctl.sync("light", "#eeeeee", "#414141")
                    self.assertEqual(old.read(), "")
                self.assertIn("foreground #414141", override.read_text())
                inode = override.stat().st_ino
                ctl.sync("light", "#eeeeee", "#414141")
                self.assertEqual(override.stat().st_ino, inode)
                self.assertEqual(reload.call_count, 2)
                before = override.read_bytes()
                for color in ("invalid", "#fff", "#000000\nfont_size 99"):
                    with self.assertRaises(ValueError):
                        ctl.sync("light", color, "#414141")
                    self.assertEqual(override.read_bytes(), before)
                ctl.sync("dark")
                self.assertEqual(override.read_text(), "")
                self.assertEqual(custom.read_text(), original)
                self.assertEqual(list(override.parent.glob(".kitty-mode-*")), [])

    def test_failed_replace_preserves_the_previous_override(self):
        """A failed generated-file write leaves the last palette and removes its temporary file."""
        with tempfile.TemporaryDirectory() as temporary, patch.object(ctl, "reload_kitty") as reload:
            with patch.object(ctl.Path, "home", return_value=Path(temporary)):
                ctl.sync("light", "#eeeeee", "#414141")
                path = Path(temporary) / ".local/state/hakuspace/theme/kitty-mode.conf"
                original = path.read_bytes()
                with patch.object(ctl.os, "replace", side_effect=OSError("fixture failure")):
                    with self.assertRaises(OSError):
                        ctl.sync("dark")
                self.assertEqual(path.read_bytes(), original)
                self.assertEqual(list(path.parent.glob(".kitty-mode-*")), [])
                self.assertEqual(reload.call_count, 1)

    def test_reload_visits_other_instances_after_one_failure(self):
        """One failed socket cannot prevent the remaining terminals from reloading."""
        paths = [Path(f"/tmp/kitty-fixture-{index}") for index in range(3)]
        calls = []

        def run(command, **kwargs):
            """Record reloads and fail only the first active instance."""
            calls.append(command)
            if command[-1] == "load-config" and len(calls) == 2:
                raise subprocess.CalledProcessError(1, command)
            return SimpleNamespace(returncode=0)

        with patch.object(ctl.shutil, "which", return_value="kitty"), \
             patch.object(ctl.Path, "glob", return_value=paths), \
             patch.object(ctl.Path, "stat", return_value=SimpleNamespace(st_mode=stat.S_IFSOCK)), \
             patch.object(ctl.subprocess, "run", side_effect=run), \
             patch.object(ctl.sys, "stderr"):
            with self.assertRaises(RuntimeError):
                ctl.reload_kitty()
        self.assertEqual(sum(command[-1] == "load-config" for command in calls), 3)

    def test_include_order_restores_user_colors_outside_light(self):
        """Only managed Light colors override custom colors; Classic opaque stays last."""
        config = (ROOT / "src/home/.config/kitty/kitty.conf").read_text()
        self.assertLess(config.index("include ~/hakucfg/config/kitty.conf"),
                        config.index("include ~/.local/state/hakuspace/theme/kitty-mode.conf"))
        self.assertLess(config.index("include ~/.local/state/hakuspace/theme/kitty-mode.conf"),
                        config.index("include ~/.local/state/hakuspace/theme/opaque/kitty.conf"))


if __name__ == "__main__":
    unittest.main()
