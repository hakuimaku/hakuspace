#!/usr/bin/env python3
"""Preserve legacy runtime state while upgrading to owner-prefixed filenames."""
import fcntl
import json
import os
from pathlib import Path
import stat
import sys
import tempfile

# Support both repository sources and the flattened installed bin directory.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend/user"))
from haku_state import STATE_FILES, state_root, state_path
from hikai_settings_ctl import open_parent

# Alias order gives the current Haku Space preference priority over stale names.
LEGACY_KEYS = {
    "shell_backend": "shell.backend",
    "haku_space_state": "shell.haku-space.enabled",
    "haku_shell_state": "shell.haku-space.enabled",
    "haku_space_status": "shell.haku-space.enabled",
    "waybar_manual_state": "desktop.waybar.requested",
    "waybar_current_mode": "desktop.waybar.mode",
    "taskbar_manual_state": "desktop.taskbar.requested",
    "dockbar_manual_state": "desktop.dockbar.requested",
    "desktop_icons_state": "desktop.icons.enabled",
    "edge_trigger_state": "desktop.edge-trigger.enabled",
    "rounded_screen_state": "screen.rounded.enabled",
    "rounded_screen_dynamic_state": "screen.rounded.dynamic",
    "opaque_theme_state": "theme.opaque.enabled",
    "state.env": "theme.appearance.env",
    "idle_inhibit": "system.idle-inhibit.enabled",
    "cava_layer_state": "cava.enabled",
    "cava_top_state": "cava.position",
    "cava_dynamic_state": "cava.dynamic-position",
    "cava_color_state": "cava.color-mode",
    "cava_height": "cava.height",
    "chrome-state-v6.json": "migration.hikai-chrome-v6.json",
}
# Obsolete state has no writer; retain its bytes in the migration archive only.
RETIRED_FILES = ("taskbar_autohide_state",)
# Required user preferences once stored alongside disposable generated data.
CACHED_STATE_KEYS = (("current_wallpaper", "desktop.wallpaper.current.json"),
                     ("desktop-icons-positions.json", "desktop.icons.positions.json"))


def read_entry(parent_fd, name):
    """Read optional regular user-owned bytes without following symlinks."""
    try:
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent_fd)
    except FileNotFoundError:
        return None
    with os.fdopen(fd, "rb") as stream:
        metadata = os.fstat(stream.fileno())
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid():
            raise ValueError(f"unsafe state entry: {name}")
        return stream.read()


def move_entry(source_fd, name, destination_fd, target):
    """Publish without overwriting another entry and retain bytes and permissions."""
    # A crash after linking leaves identical entries that the next run collapses.
    os.link(name, target, src_dir_fd=source_fd, dst_dir_fd=destination_fd, follow_symlinks=False)
    os.fsync(destination_fd)
    os.unlink(name, dir_fd=source_fd)
    os.fsync(source_fd)


def archive_entry(state_fd, name, data=None):
    """Keep each conflicting or obsolete preference in a private backup directory."""
    backup = state_root() / "migration-backup/state-naming-v1" / name
    backup_fd = open_parent(backup, True)
    try:
        suffix = 0
        while True:
            target = name if suffix == 0 else f"{name}.{suffix}"
            try:
                if data is None:
                    move_entry(state_fd, name, backup_fd, target)
                else:
                    # Legacy cache may be mounted separately from persistent state.
                    fd, temporary = tempfile.mkstemp(prefix=".cache-state-", dir=backup.parent)
                    try:
                        with os.fdopen(fd, "wb") as stream:
                            stream.write(data)
                            stream.flush()
                            os.fsync(stream.fileno())
                        os.link(temporary, target, dst_dir_fd=backup_fd)
                        os.fsync(backup_fd)
                        os.unlink(name, dir_fd=state_fd)
                        os.fsync(state_fd)
                    finally:
                        Path(temporary).unlink(missing_ok=True)
                break
            except FileExistsError:
                suffix += 1
        print(f"state migration: preserved {name} at {backup.parent / target}", file=sys.stderr)
    finally:
        os.close(backup_fd)


def migrate():
    """Upgrade existing state under a directory lock without manufacturing defaults."""
    migrate_cached_state()
    try:
        state_fd = open_parent(state_root() / "state/.entry", False)
    except FileNotFoundError:
        return
    try:
        fcntl.flock(state_fd, fcntl.LOCK_EX)
        for legacy, key in LEGACY_KEYS.items():
            original = read_entry(state_fd, legacy)
            if original is None:
                continue
            canonical = STATE_FILES[key]
            saved = read_entry(state_fd, canonical)
            if saved is None:
                try:
                    move_entry(state_fd, legacy, state_fd, canonical)
                    continue
                except FileExistsError:
                    saved = read_entry(state_fd, canonical)
            if saved == original:
                os.unlink(legacy, dir_fd=state_fd)
                os.fsync(state_fd)
            else:
                archive_entry(state_fd, legacy)
        for legacy in RETIRED_FILES:
            if read_entry(state_fd, legacy) is not None:
                archive_entry(state_fd, legacy)
    finally:
        os.close(state_fd)


def migrate_cached_state():
    """Move legacy preferences out of cache, retaining conflicts in the state archive."""
    legacy_root = Path.home() / ".cache"
    if not any((legacy_root / name).exists() or (legacy_root / name).is_symlink()
               for name, key in CACHED_STATE_KEYS):
        return
    cache_fd = open_parent(legacy_root / ".entry", False)
    try:
        fcntl.flock(cache_fd, fcntl.LOCK_EX)
        for name, key in CACHED_STATE_KEYS:
            original = read_entry(cache_fd, name)
            if original is None:
                continue
            lines = original.decode("utf-8").splitlines() if name == "current_wallpaper" else []
            source = lines[0] if lines else ""
            target = state_path(key)
            state_fd = open_parent(target, True)
            try:
                if read_entry(state_fd, target.name) is None:
                    if name == "desktop-icons-positions.json":
                        # Cache and state may reside on different filesystems.
                        payload = original
                    else:
                        kind = "video" if Path(source).suffix.lower() in {".mp4", ".mkv", ".webm", ".mov", ".m4v"} else "static"
                        payload = (json.dumps({"path": source, "kind": kind}) + "\n").encode()
                    fd, temporary = tempfile.mkstemp(prefix=".cache-state-", dir=target.parent)
                    try:
                        with os.fdopen(fd, "wb") as stream:
                            stream.write(payload)
                            stream.flush()
                            os.fsync(stream.fileno())
                        try:
                            os.link(temporary, target.name, dst_dir_fd=state_fd)
                            os.fsync(state_fd)
                        except FileExistsError:
                            pass
                    finally:
                        Path(temporary).unlink(missing_ok=True)
                if name == "desktop-icons-positions.json" and read_entry(state_fd, target.name) != original:
                    archive_entry(cache_fd, name, original)
                elif name == "current_wallpaper" and json.loads(read_entry(state_fd, target.name)).get("path") != source:
                    archive_entry(cache_fd, name, original)
                else:
                    os.unlink(name, dir_fd=cache_fd)
                    os.fsync(cache_fd)
            finally:
                os.close(state_fd)
    finally:
        os.close(cache_fd)


if __name__ == "__main__":
    try:
        if sys.argv[1:]:
            raise ValueError("usage: haku_state_migrate.py")
        migrate()
    except (OSError, ValueError) as error:
        print(f"state migration failed: {error}", file=sys.stderr)
        sys.exit(1)
