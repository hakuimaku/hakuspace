#!/usr/bin/env python3
"""Validate and persist the native wallpaper draft independently of shell settings."""
import copy
import fcntl
import json
import os
import sys
from pathlib import Path
from hikai_settings_ctl import open_parent, replace_file

# Playback defaults bound decoded frame sizes and release hidden players.
DEFAULTS = {
    "version": 1,
    "playback": {"profile": "screen", "hardwareDecode": "auto", "pauseWhenFullscreen": True,
                 "unloadWhenHidden": True, "unloadDelaySec": 20, "loop": True},
    "proxy": {"buildPolicy": "on-select", "maxCacheMiB": 4096},
    "browser": {"filter": "static", "sort": "name", "showMetadata": True, "motionPreview": False},
}
# Exact enum and integer constraints are shared by reads and patches.
CHOICES = {"profile": ("original", "screen", "low-memory"), "hardwareDecode": ("auto", "prefer", "software"),
           "buildPolicy": ("on-select", "background", "manual"), "filter": ("static", "video"), "sort": ("name",)}
BOUNDS = {"unloadDelaySec": (1, 600), "maxCacheMiB": (64, 65536)}


def validate(values, partial=False):
    """Reject unknown keys, missing fields and coercible but incorrectly typed values."""
    if type(values) is not dict or set(values) - set(DEFAULTS):
        raise ValueError("invalid wallpaper settings fields")
    if not partial and set(values) != set(DEFAULTS):
        raise ValueError("missing wallpaper settings fields")
    if "version" in values and (type(values["version"]) is not int or values["version"] != 1):
        raise ValueError("unsupported wallpaper settings version")
    for section in ("playback", "proxy", "browser"):
        if section not in values:
            continue
        fields = values[section]
        if type(fields) is not dict or set(fields) - set(DEFAULTS[section]):
            raise ValueError(f"{section}: invalid fields")
        if not partial and set(fields) != set(DEFAULTS[section]):
            raise ValueError(f"{section}: missing fields")
        for key, value in fields.items():
            if key in CHOICES:
                valid = type(value) is str and value in CHOICES[key]
            elif key in BOUNDS:
                valid = type(value) is int and BOUNDS[key][0] <= value <= BOUNDS[key][1]
            else:
                valid = type(value) is bool and (key != "motionPreview" or not value)
            if not valid:
                raise ValueError(f"{section}.{key}: invalid value")
    return values


def run(action):
    """Read defaults without writing; merge validated patches under an exclusive lock."""
    if action not in ("read", "write"):
        raise ValueError("usage: hikai_wallpaper_settings_ctl.py read|write")
    path = Path(os.path.abspath(os.environ.get("HAKUSPACE_WALLPAPER_SETTINGS_FILE")
                               or Path.home() / "hakucfg/hikai/hikai-wallpaper.json"))
    values = copy.deepcopy(DEFAULTS)
    try:
        parent = open_parent(path, action == "write")
    except FileNotFoundError:
        return {"ok": True, "values": values}
    try:
        with os.fdopen(os.open(".wallpaper-settings.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW,
                               0o600, dir_fd=parent), "r+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
                with os.fdopen(fd) as stream:
                    import stat
                    info = os.fstat(stream.fileno())
                    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                        raise ValueError("wallpaper settings must be a user-owned regular file")
                    values = json.load(stream)
                    # Retire the mixed library tab without resetting other saved preferences.
                    if isinstance(values, dict) and isinstance(values.get("browser"), dict) and values["browser"].get("filter") == "all":
                        values["browser"]["filter"] = "static"
                    values = validate(values)
            except FileNotFoundError:
                pass
            if action == "write":
                patch = validate(json.loads(os.environ.get("HAKUSPACE_WALLPAPER_SETTINGS_JSON", "")), partial=True)
                for section in ("playback", "proxy", "browser"):
                    values[section].update(patch.get(section, {}))
                replace_file(parent, path.name, values, 0o600)
    finally:
        os.close(parent)
    return {"ok": True, "values": values}


if __name__ == "__main__":
    try:
        print(json.dumps(run(sys.argv[1] if len(sys.argv) == 2 else "")))
    except (OSError, ValueError, UnicodeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
