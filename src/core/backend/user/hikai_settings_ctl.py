#!/usr/bin/env python3
"""Validate and atomically persist native Hikai shell preferences."""
import copy
import json
import os
import stat
import sys
import tempfile
from pathlib import Path

# Keep runtime state outside this versioned preference schema.
DEFAULTS = {
    "version": 8,
    "appearance": {"baseRadius": 12, "surfaceTone": "dark", "colorMode": "dark"},
    "roundedScreen": {"radius": 20, "borderThickness": 4},
    "dock": {"visibilityMode": "autohide", "exclusiveSpace": False, "iconSize": 36,
             "hoverLift": 14, "hoverScale": 0, "showTrash": True, "showDevices": True},
    "topbar": dict.fromkeys(("workspaces", "windowTitle", "center", "cava", "tray",
                             "quickControls", "recorder", "clock", "notifications"), True),
    "idle": {"enabled": True, "dimEnabled": True, "dimTimeout": 200, "dimPercent": 10,
             "lockEnabled": True, "lockTimeout": 230, "displayOffEnabled": True,
             "displayOffTimeout": 300, "suspendEnabled": True, "suspendTimeout": 360,
             "respectAppInhibitors": True, "inhibitOnAudio": True},
}


def validate(values, partial=False):
    """Reject unknown fields and exact-type mismatches in documents or patches."""
    if type(values) is not dict or set(values) - set(DEFAULTS):
        raise ValueError("expected a shell settings object with known fields")
    if not partial and set(values) != set(DEFAULTS):
        raise ValueError("missing shell settings fields")
    if "version" in values and (type(values["version"]) is not int or values["version"] != 8):
        raise ValueError("unsupported schema version")
    for section in ("appearance", "roundedScreen", "topbar", "dock", "idle"):
        if section not in values:
            continue
        # Validate sections before merging so an invalid patch cannot erase data.
        fields = values[section]
        if type(fields) is not dict or set(fields) - set(DEFAULTS[section]):
            raise ValueError(f"{section}: unknown fields or invalid object")
        if not partial and set(fields) != set(DEFAULTS[section]):
            raise ValueError(f"{section}: missing fields")
        for key, value in fields.items():
            if section == "idle":
                if type(DEFAULTS[section][key]) is bool:
                    valid = type(value) is bool
                else:
                    low, high = (1, 100) if key == "dimPercent" else (10, 86400)
                    valid = type(value) is int and low <= value <= high
            elif section == "dock":
                if key == "visibilityMode":
                    valid = type(value) is str and value in ("autohide", "always")
                elif key in ("exclusiveSpace", "showTrash", "showDevices"):
                    valid = type(value) is bool
                elif key == "iconSize":
                    valid = type(value) is int and 24 <= value <= 72 and value % 4 == 0
                else:
                    valid = type(value) is int and 0 <= value <= (48 if key == "hoverLift" else 100)
            elif section == "topbar":
                valid = type(value) is bool
            elif section == "roundedScreen":
                valid = type(value) is int and 0 <= value <= (24 if key == "radius" else 6)
            elif key == "baseRadius":
                valid = type(value) is int and 4 <= value <= 24
            elif key == "colorMode":
                valid = type(value) is str and value in ("dark", "light")
            else:
                valid = type(value) is str and value in ("ink", "dark", "soft")
            if not valid:
                raise ValueError(f"{section}.{key}: invalid value")
    # Cross-field ordering is checked after patches are merged with saved values.
    if not partial:
        idle = values["idle"]
        timeouts = [idle[stage + "Timeout"] for stage in ("dim", "lock", "displayOff", "suspend")
                    if idle[stage + "Enabled"]]
        if any(left >= right for left, right in zip(timeouts, timeouts[1:])):
            raise ValueError("idle: enabled timeouts must increase: dim < lock < display off < suspend")
    return values


def migrate(values):
    """Upgrade legacy preferences in memory while preserving every valid user choice."""
    original_version = values.get("version") if type(values) is dict else None
    if type(original_version) is int and original_version == 1:
        if set(values) != {"version", "appearance", "topbar"} or type(values["topbar"]) is not dict:
            raise ValueError("invalid version 1 shell settings")
        # Legacy module omissions use their original enabled defaults.
        validate({"topbar": values["topbar"]}, partial=True)
        upgraded = copy.deepcopy(values)
        upgraded.update(version=2, roundedScreen=copy.deepcopy(DEFAULTS["roundedScreen"]))
        upgraded["topbar"] = DEFAULTS["topbar"] | values["topbar"]
        values = upgraded
    if type(original_version) is int and original_version in (1, 2):
        if set(values) != {"version", "appearance", "roundedScreen", "topbar"}:
            raise ValueError("invalid version 2 shell settings")
        values = copy.deepcopy(values)
        values.update(version=6, dock=copy.deepcopy(DEFAULTS["dock"]))
        return migrate(values)[0], True
    if type(original_version) is int and original_version == 3:
        if type(values.get("dock")) is not dict or set(values["dock"]) != {"visibilityMode", "exclusiveSpace", "iconSize"}:
            raise ValueError("invalid version 3 shell settings")
        values = copy.deepcopy(values)
        values["dock"].update(hoverLift=14, hoverScale=0)
    if type(original_version) is int and original_version in (3, 4):
        if type(values.get("dock")) is not dict or set(values["dock"]) != {"visibilityMode", "exclusiveSpace", "iconSize", "hoverLift", "hoverScale"}:
            raise ValueError("invalid legacy Dock settings")
        values = copy.deepcopy(values)
        values["version"] = 6
        values["dock"].update(showTrash=True, showDevices=True)
        return migrate(values)[0], True
    if type(original_version) is int and original_version == 5:
        values = copy.deepcopy(values)
        if type(values.get("dock")) is not dict or values["dock"].pop("style", None) not in ("dock", "bar"):
            raise ValueError("invalid version 5 Dock style")
        values["version"] = 6
        return migrate(values)[0], True
    if type(original_version) is int and original_version == 6:
        if type(values.get("appearance")) is not dict or set(values["appearance"]) != {"baseRadius", "surfaceTone"}:
            raise ValueError("invalid version 6 appearance")
        values = copy.deepcopy(values)
        values["version"] = 7
        values["appearance"]["colorMode"] = "dark"
        return migrate(values)[0], True
    if type(original_version) is int and original_version == 7:
        if set(values) != set(DEFAULTS) - {"idle"}:
            raise ValueError("invalid version 7 shell settings")
        values = copy.deepcopy(values)
        values.update(version=8, idle=copy.deepcopy(DEFAULTS["idle"]))
        return validate(values), True
    return validate(values), False


def open_parent(path, create):
    """Walk directories without following symlinks, retaining a stable parent fd."""
    parent_fd = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:-1]:
            if create:
                try:
                    os.mkdir(part, mode=0o700, dir_fd=parent_fd)
                except FileExistsError:
                    pass
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent_fd)
            os.close(parent_fd)
            parent_fd = next_fd
        return parent_fd
    except BaseException:
        os.close(parent_fd)
        raise


def read_file(parent_fd, name):
    """Read regular user-owned files; absent preferences use private defaults."""
    try:
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent_fd)
    except FileNotFoundError:
        return copy.deepcopy(DEFAULTS), 0o600, False
    with os.fdopen(fd) as stream:
        metadata = os.fstat(stream.fileno())
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid():
            raise ValueError("settings must be a regular file owned by the current user")
        # Retain owner access and optional group read, dropping unsafe permission bits.
        mode = stat.S_IMODE(metadata.st_mode) & 0o640
        values, migrated = migrate(json.load(stream))
        return values, mode, migrated


def replace_file(parent_fd, name, values, mode):
    """Flush a sibling temporary file before replacing the canonical directory entry."""
    # Use the open directory fd so parent renames cannot redirect this write.
    fd, temp_path = tempfile.mkstemp(prefix=".hikai-shell-", dir=f"/proc/self/fd/{parent_fd}")
    temp_name = Path(temp_path).name
    try:
        with os.fdopen(fd, "w") as stream:
            os.fchmod(stream.fileno(), mode)
            json.dump(values, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        # Recheck target ownership and type immediately before replacement.
        try:
            metadata = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid():
                raise ValueError("unsafe settings target")
        except FileNotFoundError:
            pass
        os.replace(temp_name, name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
        os.fsync(parent_fd)
    finally:
        try:
            os.unlink(temp_name, dir_fd=parent_fd)
        except FileNotFoundError:
            pass


def run(action):
    """Persist shell edits and synchronize explicitly saved Dock icon sizes."""
    if action not in ("read", "write", "check", "reset"):
        raise ValueError("usage: hikai_settings_ctl.py read|write|check|reset")
    path = Path(os.path.abspath(os.environ.get("HAKUSPACE_HIKAI_SETTINGS_FILE")
                               or Path.home() / "hakucfg/hikai/hikai-shell.json"))
    try:
        parent_fd = open_parent(path, action in ("write", "reset"))
    except FileNotFoundError:
        return {"ok": True, "path": str(path), "values": copy.deepcopy(DEFAULTS), "needsMigration": False}
    try:
        values, mode, migrated = read_file(parent_fd, path.name)
        if action == "write":
            patch = validate(json.loads(os.environ.get("HAKUSPACE_HIKAI_SETTINGS_JSON", "")), partial=True)
            for section in ("appearance", "roundedScreen", "topbar", "dock", "idle"):
                values[section].update(patch.get(section, {}))
            validate(values)
        elif action == "reset":
            values = copy.deepcopy(DEFAULTS)
        if action in ("write", "reset"):
            if action == "reset" or "iconSize" in patch.get("dock", {}):
                # Import after initialization because pins reuse this module's safe path walker.
                from taskbar_pins_ctl import run as update_pins
                update_pins("size", [str(values["dock"]["iconSize"])])
            replace_file(parent_fd, path.name, values, mode)
        return {"ok": True, "path": str(path), "values": values,
                "needsMigration": migrated and action in ("read", "check")}
    finally:
        os.close(parent_fd)


if __name__ == "__main__":
    try:
        print(json.dumps(run(sys.argv[1] if len(sys.argv) == 2 else "")))
    except (OSError, ValueError, UnicodeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
