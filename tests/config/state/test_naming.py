#!/usr/bin/env python3
"""Exercise state path contracts and legacy upgrades in disposable homes."""
import contextlib
import io
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

# Load the same registries and upgrade entrypoint used by startup scripts.
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "src/core/lib"))
sys.path.insert(0, str(ROOT / "src/core/state"))
sys.path.insert(0, str(ROOT / "tools/checks"))
from haku_state import STATE_FILES, state_path
import haku_state_migrate as migration
from state_schema import check_text


class StateNamingTests(unittest.TestCase):
    """Keep all file mutations inside an isolated HOME."""

    def setUp(self):
        """Prepare an empty state directory and restore HOME after each test."""
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.state = self.home / ".local/state/hakuspace/state"
        self.state.mkdir(parents=True)
        environment = patch.dict(os.environ, HOME=str(self.home))
        environment.start()
        self.addCleanup(environment.stop)

    def test_all_mappings_preserve_bytes_permissions_and_idempotence(self):
        """Every legacy spelling upgrades without changing content or permissions."""
        for legacy, key in migration.LEGACY_KEYS.items():
            with self.subTest(legacy=legacy):
                canonical = state_path(key)
                canonical.unlink(missing_ok=True)
                original = self.state / legacy
                original.write_bytes(b"0\x00\xff\ncustom value\n")
                original.chmod(0o640)
                migration.migrate()
                self.assertEqual(canonical.read_bytes(), b"0\x00\xff\ncustom value\n")
                self.assertEqual(stat.S_IMODE(canonical.stat().st_mode), 0o640)
                self.assertFalse(original.exists())
                snapshot = canonical.stat()
                migration.migrate()
                self.assertEqual(canonical.stat().st_ino, snapshot.st_ino)
                canonical.unlink()
        self.assertEqual(list(self.state.iterdir()), [])
        self.assertFalse((self.state.parent / "migration-backup").exists())

    def test_canonical_wins_and_backups_never_overwrite(self):
        """Identical copies collapse; conflicting values retain distinct backups."""
        canonical = state_path("shell.backend")
        canonical.write_bytes(b"hikai\n")
        legacy = self.state / "shell_backend"
        legacy.write_bytes(canonical.read_bytes())
        migration.migrate()
        self.assertFalse(legacy.exists())
        self.assertFalse((self.state.parent / "migration-backup").exists())
        backup = self.state.parent / "migration-backup/state-naming-v1"
        for value in (b"classic\n", b"custom\n"):
            legacy.write_bytes(value)
            legacy.chmod(0o640)
            with contextlib.redirect_stderr(io.StringIO()) as warnings:
                migration.migrate()
            self.assertIn("preserved", warnings.getvalue())
            self.assertEqual(canonical.read_bytes(), b"hikai\n")
        self.assertEqual({path.read_bytes() for path in backup.iterdir()}, {b"classic\n", b"custom\n"})
        self.assertTrue(all(stat.S_IMODE(path.stat().st_mode) == 0o640 for path in backup.iterdir()))

    def test_alias_priority_and_retired_state(self):
        """Current Haku Space wins; stale aliases and obsolete autohide are retained."""
        (self.state / "haku_space_state").write_text("1\n")
        (self.state / "haku_shell_state").write_text("0\n")
        (self.state / "haku_space_status").write_text("1\n")
        (self.state / "taskbar_autohide_state").write_text("1\n")
        with contextlib.redirect_stderr(io.StringIO()):
            migration.migrate()
        self.assertEqual(state_path("shell.haku-space.enabled").read_text(), "1\n")
        self.assertEqual({path.name for path in self.state.iterdir()}, {"[shell].haku-space.enabled"})
        backup = self.state.parent / "migration-backup/state-naming-v1"
        self.assertEqual((backup / "haku_shell_state").read_text(), "0\n")
        self.assertEqual((backup / "taskbar_autohide_state").read_text(), "1\n")

    def test_unsafe_entries_are_rejected_without_following_links(self):
        """Links, FIFOs, and foreign ownership never become canonical state."""
        outside = self.home / "outside"
        outside.write_text("private\n")
        legacy = self.state / "shell_backend"
        legacy.symlink_to(outside)
        with self.assertRaises(OSError):
            migration.migrate()
        self.assertEqual(outside.read_text(), "private\n")
        self.assertTrue(legacy.is_symlink())
        legacy.unlink()
        os.mkfifo(legacy)
        with self.assertRaises(ValueError):
            migration.migrate()
        legacy.unlink()
        legacy.write_text("hikai\n")
        metadata = list(legacy.stat())
        metadata[4] = os.getuid() + 1
        with patch.object(migration.os, "fstat", return_value=os.stat_result(metadata)):
            with self.assertRaises(ValueError):
                migration.migrate()
        self.assertFalse(state_path("shell.backend").exists())
        state_path("shell.backend").symlink_to(outside)
        with self.assertRaises(OSError):
            migration.migrate()
        self.assertEqual(legacy.read_text(), "hikai\n")
        self.assertEqual(outside.read_text(), "private\n")

    def test_symlinked_directories_and_backups_are_rejected(self):
        """Neither state nor backup parents may redirect migration writes."""
        self.state.rmdir()
        outside = self.home / "outside"
        outside.mkdir()
        self.state.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(OSError):
            migration.migrate()
        self.assertEqual(list(outside.iterdir()), [])
        self.state.unlink()
        self.state.mkdir()
        (self.state / "shell_backend").write_text("classic\n")
        state_path("shell.backend").write_text("hikai\n")
        (self.state.parent / "migration-backup").symlink_to(outside, target_is_directory=True)
        with self.assertRaises(OSError):
            migration.migrate()
        self.assertEqual((self.state / "shell_backend").read_text(), "classic\n")
        self.assertEqual(state_path("shell.backend").read_text(), "hikai\n")
        self.assertEqual(list(outside.iterdir()), [])

    def test_empty_home_and_read_only_resolvers_create_nothing(self):
        """Missing state stays absent and unknown keys cannot escape the registry."""
        shutil.rmtree(self.home / ".local")
        migration.migrate()
        self.assertEqual(state_path("cava.position").name, "[cava].position")
        with self.assertRaises(KeyError):
            state_path("../../escape")
        result = subprocess.run(["bash", "-c", 'source "$1"; haku_state_path ../../escape',
                                 "test", ROOT / "src/core/lib/haku_state.sh"], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_install_migrates_before_initializing_defaults(self):
        """Update initialization keeps legacy appearance bytes and avoids defaults."""
        original = b'ACCENT_COLOR="#123456"\nFONT_FAMILY="custom"\nFONT_SIZE=18\n'
        (self.state / "state.env").write_bytes(original)
        (self.state / "opaque_theme_state").write_text("1\n")
        binary = self.home / ".local/bin"
        binary.mkdir()
        for name in ("theme_ctl.sh", "opaque_theme.sh"):
            controller = binary / name
            controller.write_text('#!/bin/sh\necho called >> "$HOME/defaults-called"\n')
            controller.chmod(0o755)
        result = subprocess.run(["bash", ROOT / "scripts/state.sh", "init"],
                                env={**os.environ, "HAKU_DIR": str(ROOT)}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(state_path("theme.appearance.env").read_bytes(), original)
        self.assertEqual(state_path("theme.opaque.enabled").read_text(), "1\n")
        self.assertFalse((self.home / "defaults-called").exists())
        for name in ("taskbar-theme", "rofi-theme.rasi", "niri-animation.kdl"):
            self.assertTrue((self.state.parent / name).is_file())

    def test_startup_failure_prevents_default_initialization(self):
        """All startup gates stop before creating canonical defaults on failure."""
        outside = self.home / "outside"
        outside.write_text("hikai\n")
        legacy = self.state / "shell_backend"
        legacy.symlink_to(outside)
        for name in ("session_start.sh", "qs_supervisor.sh", "haku_backend.sh"):
            result = subprocess.run(["bash", ROOT / "src/core/sys" / name],
                                    capture_output=True, text=True, timeout=5)
            self.assertNotEqual(result.returncode, 0, name)
            self.assertIn("state migration failed", result.stderr)
            self.assertTrue(legacy.is_symlink())
            self.assertFalse(state_path("shell.backend").exists())
            self.assertEqual(outside.read_text(), "hikai\n")

    @unittest.skipUnless(shutil.which("quickshell"), "quickshell is not installed")
    def test_qml_watchers_follow_canonical_files_live(self):
        """Real FileViews reload renamed canonical files without a compositor."""
        shell = self.home / ".config/quickshell/hakuspace"
        services = shell / "services"
        services.mkdir(parents=True)
        for name in ("AppState.qml", "Env.qml"):
            shutil.copy2(ROOT / "src/home/.config/quickshell/hakuspace/services" / name, services)
        (services / "qmldir").write_text("module services\nsingleton Env 1.0 Env.qml\nsingleton AppState 1.0 AppState.qml\n")
        initial = {"desktop.waybar.requested": "0", "desktop.taskbar.requested": "0",
                   "desktop.dockbar.requested": "1", "theme.opaque.enabled": "0", "cava.enabled": "0",
                   "cava.position": "1", "cava.dynamic-position": "0", "cava.color-mode": "1", "cava.height": "88"}
        for key, value in initial.items():
            state_path(key).write_text(value + "\n")
        mutation = self.home / "mutate.py"
        mutation.write_text("from pathlib import Path\n" + "\n".join(
            f"p = Path({str(state_path(key))!r}); p.with_suffix('.tmp').write_text({value!r}); p.with_suffix('.tmp').replace(p)"
            for key, value in {"desktop.waybar.requested": "1", "desktop.taskbar.requested": "1",
                               "desktop.dockbar.requested": "0", "theme.opaque.enabled": "1", "cava.enabled": "1",
                               "cava.position": "0", "cava.dynamic-position": "1", "cava.color-mode": "0", "cava.height": "120"}.items()))
        (shell / "shell.qml").write_text('''
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
ShellRoot {
    property int stage: 0
    property int attempts: 0
    Process { id: mutation; command: ["python3", Quickshell.env("STATE_MUTATION")] }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (++attempts > 100) { console.error("State watcher timeout"); Qt.quit(); return }
            if (stage === 0 && !AppState.waybarManualState && !AppState.taskbarManualState
                && AppState.dockbarManualState && !AppState.opaqueThemeState && !AppState.cavaLayerState
                && AppState.cavaTopState && !AppState.cavaDynamicPosition
                && AppState.cavaColorMode === "accent" && AppState.cavaHeight === 88) {
                stage = 1; mutation.running = true
            } else if (stage === 1 && AppState.waybarManualState && AppState.taskbarManualState
                && !AppState.dockbarManualState && AppState.opaqueThemeState && AppState.cavaLayerState
                && !AppState.cavaTopState && AppState.cavaDynamicPosition
                && AppState.cavaColorMode === "surface" && AppState.cavaHeight === 120) {
                console.log("Canonical state watchers passed"); Qt.quit()
            }
        }
    }
}
''')
        runtime = self.home / "runtime"
        runtime.mkdir(mode=0o700)
        environment = {key: value for key, value in os.environ.items()
                       if key not in ("WAYLAND_DISPLAY", "DISPLAY", "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6")}
        environment.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                           XDG_RUNTIME_DIR=str(runtime), STATE_MUTATION=str(mutation))
        result = subprocess.run(["quickshell", "-p", shell / "shell.qml"], env=environment,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Canonical state watchers passed", result.stdout + result.stderr)

    def test_schema_rejects_new_legacy_and_unregistered_paths(self):
        """The static guard rejects regressions without flagging controller names."""
        for text in ('cat "$STATE_DIR/shell_backend"', 'cat "$STATE_DIR/unknown"',
                     'path: Env.stateDir + "/unknown"', 'stateDir + "/[1].unknown"', '"[other].enabled"',
                     '"[cava].unknown"', '"[BAD].enabled"', '"[1].enabled"', '"~/.local/state/hakuspace/state/unregistered"'):
            with self.subTest(text=text):
                self.assertTrue(check_text("src/example.sh", text))
        self.assertFalse(check_text("src/example.sh", '"$HOME/.local/bin/idle_inhibit.sh"'))
        self.assertFalse(check_text("src/example.qml", 'path: Env.stateCavaEnabled'))


if __name__ == "__main__":
    unittest.main()
