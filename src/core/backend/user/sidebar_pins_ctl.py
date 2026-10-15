#!/usr/bin/env python3
"""List and launch Sidebar pins from ~/hakucfg/sidebar-pins.json."""

import json
import configparser
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile

CONFIG = Path.home() / "hakucfg/sidebar-pins.json"


def fingerprint(entry):
    return hashlib.sha256(json.dumps(entry, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


# Read a desktop entry's theme icon for app pins, including older saved pins.
def desktop_icon(path):
    if not isinstance(path, str) or not path:
        return "application-x-executable"
    desktop = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        desktop.read(path, encoding="utf-8")
        return desktop.get("Desktop Entry", "Icon", fallback="").strip() or "application-x-executable"
    except (OSError, UnicodeError, configparser.Error):
        return "application-x-executable"


# Reject incomplete entries before they reach the UI or process launcher.
def load_pins():
    if not CONFIG.exists():
        return []
    try:
        data = json.loads(CONFIG.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"sidebar-pins: {exc}", file=sys.stderr)
        return []
    if not isinstance(data, list):
        print("sidebar-pins: expected a JSON array", file=sys.stderr)
        return []
    pins = []
    skipped = 0
    for index, entry in enumerate(data):
        if not isinstance(entry, dict):
            skipped += 1
            continue
        argv = entry.get("command")
        if argv is None and isinstance(entry.get("target"), str) and entry["target"]:
            argv = ["xdg-open", entry["target"]]
        if (
            not isinstance(entry.get("label"), str)
            or not entry["label"].strip()
            or not isinstance(argv, list)
            or not argv
            or not all(isinstance(arg, str) and arg for arg in argv)
            or ("cwd" in entry and not isinstance(entry["cwd"], str))
        ):
            skipped += 1
            continue
        icon = desktop_icon(entry.get("target", "")) if entry.get("kind") == "app" \
            else entry.get("icon") if isinstance(entry.get("icon"), str) else "󰐃"
        pins.append({**entry, "icon": icon, "command": argv, "cwd": entry.get("cwd", ""),
                     "_rawIndex": index, "_rawHash": fingerprint(entry)})
    if skipped:
        print(f"sidebar-pins: skipped {skipped} invalid entries", file=sys.stderr)
    return pins


# Expand paths in individual argv elements without invoking a shell.
def launch(pin):
    argv = [os.path.expandvars(os.path.expanduser(arg)) for arg in pin["command"]]
    cwd = os.path.expandvars(os.path.expanduser(pin["cwd"])) if pin["cwd"] else None
    subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


# Keep invalid input untouched and preserve fields outside the Sidebar schema.
def add_pin(kind, target):
    path = Path(os.path.expandvars(os.path.expanduser(target))).resolve(strict=True)
    if kind == "folder" and not path.is_dir():
        raise ValueError("expected a folder")
    if kind in ("file", "app") and not path.is_file():
        raise ValueError("expected a file")
    if kind == "app" and path.suffix != ".desktop":
        raise ValueError("expected a .desktop file")
    if CONFIG.exists():
        data = json.loads(CONFIG.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            raise ValueError("expected a JSON array")
    else:
        data = []
    for entry in data:
        if not isinstance(entry, dict):
            continue
        old = entry.get("target")
        if old is None and isinstance(entry.get("command"), list) and len(entry["command"]) == 2 \
                and entry["command"][0] in ("xdg-open", "gio"):
            old = entry["command"][1]
        if isinstance(old, str) and Path(os.path.expandvars(os.path.expanduser(old))).resolve() == path:
            raise ValueError("shortcut already pinned")
    icon = {"file": "󰈙", "folder": "󰉋", "app": "application-x-executable"}[kind]
    command = ["gio", "launch", str(path)] if kind == "app" else ["xdg-open", str(path)]
    label = path.stem if kind == "app" else path.name
    if kind == "app":
        desktop = configparser.ConfigParser(interpolation=None, strict=False)
        desktop.read(path, encoding="utf-8")
        label = desktop.get("Desktop Entry", "Name", fallback=label).strip() or label
        icon = desktop.get("Desktop Entry", "Icon", fallback="").strip() or icon
    data.append({"kind": kind, "label": label,
                 "icon": icon, "target": str(path), "command": command})
    save_pins(data)


def remove_pin(index, expected_hash):
    data = json.loads(CONFIG.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("expected a JSON array")
    if index < 0 or index >= len(data) or not isinstance(data[index], dict) \
            or fingerprint(data[index]) != expected_hash:
        raise ValueError("pin list changed; reopen the sidebar")
    del data[index]
    save_pins(data)


def save_pins(data):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    temp_name = None
    try:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=CONFIG.parent,
                                         prefix=".sidebar-pins-", delete=False) as handle:
            temp_name = handle.name
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, CONFIG)
    finally:
        if temp_name and os.path.exists(temp_name):
            os.unlink(temp_name)


# Route list, launch, and validated add operations through one CLI.
def main():
    if len(sys.argv) == 2 and sys.argv[1] == "list":
        print(json.dumps(load_pins(), ensure_ascii=False))
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == "launch":
        try:
            pin = load_pins()[int(sys.argv[2])]
            launch(pin)
            return 0
        except (ValueError, IndexError, OSError) as exc:
            print(f"sidebar-pins: {exc}", file=sys.stderr)
            return 1
    if len(sys.argv) == 3 and sys.argv[1] in ("add-file", "add-folder", "add-app"):
        try:
            add_pin(sys.argv[1][4:], sys.argv[2])
            return 0
        except (OSError, ValueError, configparser.Error, UnicodeError) as exc:
            print(f"sidebar-pins: {exc}", file=sys.stderr)
            return 1
    if len(sys.argv) == 4 and sys.argv[1] == "remove":
        try:
            remove_pin(int(sys.argv[2]), sys.argv[3])
            return 0
        except (OSError, ValueError) as exc:
            print(f"sidebar-pins: {exc}", file=sys.stderr)
            return 1
    print("Usage: sidebar_pins_ctl.py list | launch INDEX | add-file|add-folder|add-app PATH | remove INDEX HASH", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
