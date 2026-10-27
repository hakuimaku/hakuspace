#!/usr/bin/env python3
"""Exercise cache contracts and legacy state preservation in disposable homes."""
import ast
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

# Load shared production helpers without starting either desktop frontend.
ROOT = Path(__file__).resolve().parents[3]
sys.path.extend([str(ROOT / "src/core/lib"), str(ROOT / "src/core/state"), str(ROOT / "tools/checks")])
from haku_cache import cache_root, render_wallpaper_rasi
from haku_state import state_path
from haku_state_migrate import migrate_cached_state
from cache_paths import check_text


class CachePathsTests(unittest.TestCase):
    """Keep all state, cache, subprocess stubs and installed scripts private."""

    def setUp(self):
        """Create a home containing shell-sensitive characters and a flattened installation."""
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name) / "home ' test"
        self.home.mkdir()
        self.binary = self.home / ".local/bin"
        self.binary.mkdir(parents=True)
        environment = patch.dict(os.environ, HOME=str(self.home), XDG_CACHE_HOME="",
                                 XDG_CURRENT_DESKTOP="labwc", PYTHONDONTWRITEBYTECODE="1",
                                 PATH=str(self.binary) + ":" + os.environ["PATH"])
        environment.start()
        self.addCleanup(environment.stop)
        for path in (ROOT / "src/core").rglob("*"):
            if path.suffix in (".sh", ".py"):
                (self.binary / path.name).symlink_to(path)

    def stub(self, name, body):
        """Install a private executable without changing the deployed source file."""
        path = self.binary / name
        path.unlink(missing_ok=True)
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def run_script(self, name, *args):
        """Require successful execution with stdout and stderr available on failure."""
        result = subprocess.run(["bash", str(self.binary / name), *map(str, args)], capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout.strip()

    def test_shared_cache_roots(self):
        """Bash and Python agree for unset, empty and custom XDG roots without creating data."""
        for value in (None, "", str(self.home / 'custom " cache')):
            with self.subTest(value=value), patch.dict(os.environ):
                if value is None:
                    os.environ.pop("XDG_CACHE_HOME", None)
                else:
                    os.environ["XDG_CACHE_HOME"] = value
                expected = Path(value or self.home / ".cache") / "hakuspace"
                output = subprocess.check_output(["bash", "-c", 'source "$1"; printf "%s" "$HAKUSPACE_CACHE_DIR"',
                                                   "test", str(self.binary / "haku_cache.sh")], text=True)
                self.assertEqual(Path(output), expected)
                self.assertEqual(cache_root(), expected)
                self.assertFalse(expected.exists())

    def test_legacy_preferences_survive_cache_deletion(self):
        """Import required data once and retain it when disposable cache is erased."""
        legacy = self.home / ".cache"
        legacy.mkdir()
        (legacy / "unrelated-app").write_text("keep")
        source = self.home / "video.mp4"
        (legacy / "current_wallpaper").write_text(str(source) + "\n")
        positions = {"monitor": {"image.png": [1, 2]}}
        (legacy / "desktop-icons-positions.json").write_text(json.dumps(positions))
        migrate_cached_state()
        self.assertEqual(json.loads(state_path("desktop.wallpaper.current.json").read_text()),
                         {"path": str(source), "kind": "video"})
        self.assertEqual(json.loads(state_path("desktop.icons.positions.json").read_text()), positions)
        self.assertEqual({path.name for path in legacy.iterdir()}, {"unrelated-app"})
        self.assertEqual((legacy / "unrelated-app").read_text(), "keep")
        migrate_cached_state()
        cache_root().mkdir()
        shutil.rmtree(cache_root())
        self.assertEqual(json.loads(state_path("desktop.icons.positions.json").read_text()), positions)
        # Exercise the actual desktop position reader without importing GTK.
        path = ROOT / "src/core/app/desktop-icons/desktop_icons.py"
        tree = ast.parse(path.read_text())
        functions = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in ("load_positions", "save_positions")]
        namespace = dict(os=os, json=json, POSITIONS_FILE=str(state_path("desktop.icons.positions.json")), migrate_cached_state=migrate_cached_state)
        exec(compile(ast.Module(body=functions, type_ignores=[]), str(path), "exec"), namespace)
        self.assertEqual(namespace["load_positions"](), positions)
        namespace["save_positions"]({"monitor": {"image.png": [3, 4]}})
        self.assertEqual(namespace["load_positions"]()["monitor"]["image.png"], [3, 4])

    def test_canonical_preferences_win_conflicts(self):
        """Archive conflicting legacy bytes instead of overwriting a canonical selection."""
        canonical = state_path("desktop.wallpaper.current.json")
        canonical.parent.mkdir(parents=True)
        canonical.write_text('{"path":"/selected.png","kind":"static"}')
        legacy = self.home / ".cache"
        legacy.mkdir()
        (legacy / "current_wallpaper").write_text("/older.mp4\n")
        migrate_cached_state()
        self.assertEqual(json.loads(canonical.read_text())["path"], "/selected.png")
        backup = canonical.parents[1] / "migration-backup/state-naming-v1/current_wallpaper"
        self.assertEqual(backup.read_text(), "/older.mp4\n")
        self.assertFalse((legacy / "current_wallpaper").exists())

    def test_legacy_symlinks_do_not_redirect_state(self):
        """Reject redirected migration entries before publishing or removing data."""
        legacy = self.home / ".cache"
        legacy.mkdir()
        outside = self.home / "outside"
        outside.write_text("private")
        (legacy / "current_wallpaper").symlink_to(outside)
        with self.assertRaises(OSError):
            migrate_cached_state()
        self.assertEqual(outside.read_text(), "private")
        self.assertFalse(state_path("desktop.wallpaper.current.json").exists())

    def test_classic_wallpaper_cache_restore_and_previews(self):
        """Apply, erase and restore generated images using canonical state and XDG paths."""
        self.stub("awww", "exit 0")
        self.stub("awww-daemon", "exit 0")
        self.stub("pkill", "exit 0")
        self.stub("pgrep", "exit 1")
        self.stub("magick", 'touch -- "${@: -1}"')
        source = self.home / "wallpaper.png"
        # A real SVG payload also checks Classic's MIME-based extension compatibility.
        source.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>')
        for value in ("", str(self.home / 'custom " cache')):
            with self.subTest(value=value), patch.dict(os.environ, XDG_CACHE_HOME=value):
                self.run_script("wallpaper_set.sh", source)
                wallpaper = cache_root() / "wallpaper"
                for shape in ("wide", "box"):
                    self.assertTrue((wallpaper / f"walpaper_{shape}_gen.jpg").is_file())
                before = state_path("desktop.wallpaper.current.json").read_bytes()
                shutil.rmtree(cache_root())
                self.run_script("wallpaper_resume.sh")
                self.assertTrue((wallpaper / "walpaper_wide_gen.jpg").is_file())
                self.assertEqual(state_path("desktop.wallpaper.current.json").read_bytes(), before)
                rendered = (self.home / ".local/state/hakuspace/theme/rofi-wallpaper.rasi").read_text()
                for shape in ("wide", "box"):
                    self.assertIn(json.dumps(str(wallpaper / f"walpaper_{shape}_gen.jpg")), rendered)
                self.assertFalse((self.home / ".cache/current_wallpaper").exists())
        for theme, shape in (("television", "wide"), ("tablet", "box")):
            text = (ROOT / f"src/home/.config/rofi/themes/{theme}.rasi").read_text()
            self.assertIn('@import "~/.local/state/hakuspace/theme/rofi-wallpaper.rasi"', text)
            self.assertIn("@wallpaper-" + shape, text)
        self.assertEqual({path.name for path in (self.home / ".cache").iterdir()}, {"hakuspace"})

    def test_taskbar_cache_generation_and_hits(self):
        """Run actual symbolic extraction code against a tiny GTK fixture, then reuse it."""
        package = self.home / "python/gi"
        package.mkdir(parents=True)
        (package / "__init__.py").write_text('def require_version(*args): pass\n')
        (package / "repository.py").write_text('''from pathlib import Path
from types import SimpleNamespace
import os
class Icon:
    def is_symbolic(self): return True
    def load_symbolic(self, *args): return self, True
    def savev(self, path, *args): Path(path).write_bytes(b"icon")
class Theme:
    def lookup_icon(self, *args):
        with open(Path(os.environ["HOME"]) / "lookups", "a") as stream: stream.write("lookup\\n")
        return Icon()
class Label:
    def show(self): pass
    def get_style_context(self): return self
    def get_color(self, *args): return None
Gtk = SimpleNamespace(IconTheme=SimpleNamespace(get_default=Theme), Label=Label,
    IconLookupFlags=SimpleNamespace(FORCE_SYMBOLIC=1), StateFlags=SimpleNamespace(NORMAL=0))
Gdk = None
''')
        for value in ("", str(self.home / 'custom " cache')):
            with self.subTest(value=value), patch.dict(os.environ, XDG_CACHE_HOME=value, PYTHONPATH=str(package.parent)):
                icon = cache_root() / "taskbar/icons/probe.png"
                self.assertEqual(self.run_script("taskbar_geticon.sh", "probe"), str(icon))
                self.assertEqual(icon.read_bytes(), b"icon")
                lookups = (self.home / "lookups").read_bytes()
                self.assertEqual(self.run_script("taskbar_geticon.sh", "probe"), str(icon))
                self.assertEqual((self.home / "lookups").read_bytes(), lookups)
                self.assertIn("probe:" + str(icon), (cache_root() / "taskbar/icon-cache.txt").read_text())
        self.assertEqual({path.name for path in (self.home / ".cache").iterdir()}, {"hakuspace"})

    def test_classic_video_previews_stay_out_of_media_library(self):
        """Classic discovery generates and returns thumbnails inside the shared cache."""
        self.stub("magick", 'touch -- "${@: -1}"')
        directory = self.home / "Videos/Wallpapers"
        directory.mkdir(parents=True)
        (directory / "clip.mp4").touch()
        with patch.dict(os.environ, XDG_CACHE_HOME=str(self.home / "custom cache")):
            items = json.loads(self.run_script("wallpaper_ctl.sh", "list-lively", "--json"))
            thumbnail = cache_root() / "wallpaper/thumbnails/classic/clip.jpg"
            self.assertEqual(items[0]["thumbnail"], str(thumbnail))
            self.assertTrue(thumbnail.is_file())
            self.assertFalse((directory / ".thumbnails").exists())

    @unittest.skipUnless(shutil.which("rofi"), "Rofi parser unavailable")
    def test_rofi_resolves_generated_preview_urls(self):
        """Parse both real themes with custom XDG paths without opening a launcher window."""
        with patch.dict(os.environ, XDG_CACHE_HOME=str(self.home / "custom cache")):
            render_wallpaper_rasi()
            style = self.home / ".local/state/hakuspace/theme/rofi-style.rasi"
            style.write_text("* { accent: #ffffff; accent-dim: #dddddd; }\n")
            for theme, shape in (("television", "wide"), ("tablet", "box")):
                path = ROOT / f"src/home/.config/rofi/themes/{theme}.rasi"
                result = subprocess.run(["rofi", "-no-config", "-theme", str(path), "-dump-theme"],
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("Failed to parse", result.stderr)
                self.assertIn("var(wallpaper-" + shape + ")", result.stdout)
                self.assertIn("wallpaper-" + shape + ":", result.stdout)

    def test_service_opens_backend_cache(self):
        """Hikai delegates to the backend, which creates and opens the shared directory."""
        spec = importlib.util.spec_from_file_location("cache_wallpaper", ROOT / "src/core/backend/theme/wallpaper_ctl.py")
        backend = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(backend)
        with patch.object(backend, "CACHE", cache_root() / "wallpaper"), \
                patch.object(sys, "argv", ["wallpaper_ctl.py", "open-cache"]), \
                patch.object(backend.subprocess, "run") as run:
            self.assertEqual(backend.main(), {"ok": True})
            run.assert_called_once_with(["xdg-open", str(cache_root() / "wallpaper")], check=True)
            self.assertTrue((cache_root() / "wallpaper").is_dir())
        service = (ROOT / "src/home/.config/quickshell/hakuspace/services/WallpaperService.qml").read_text()
        self.assertIn('Quickshell.execDetached(command(["open-cache"]))', service)

    def test_cache_guard(self):
        """Catch new legacy paths while retaining only classified production exceptions."""
        for text in ('CACHE="$HOME/.cache/new"', 'p = Path.home() / ".cache" / "new"',
                     'img: url("../../.cache/new.jpg");', 'CACHE="${HOME}/.cache/new"',
                     'CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/new"', 'p = "~/.cache/new"',
                     '* { img: url("~/.cache/new.jpg"); }'):
            with self.subTest(text=text):
                self.assertTrue(check_text("src/example.sh", text))
        self.assertFalse(check_text("src/core/util/clean.sh", 'rm -rf ~/.cache/*'))
        self.assertTrue(check_text("src/core/util/clean.sh", 'touch ~/.cache/new'))
        self.assertFalse(check_text("docs/cache.md", 'Example: ~/.cache/hakuspace'))
        self.assertFalse(check_text("tests/fixture.py", 'XDG_CACHE_HOME="/tmp/cache"'))
        self.assertFalse(check_text("src/example.sh", 'CACHE="$HAKUSPACE_CACHE_DIR/new"'))


if __name__ == "__main__":
    unittest.main()
