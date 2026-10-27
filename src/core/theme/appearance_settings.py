#!/usr/bin/env python3
"""Keep native GTK settings and existing managed CSS links aligned with the mode."""
import ast
import configparser
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile


def current_themes():
    """Read user-selected names; unavailable settings remain unmanaged."""
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    native = configparser.ConfigParser(interpolation=None)
    try:
        native.read(config / "gtk-3.0/settings.ini")
    except (OSError, configparser.Error):
        native.clear()
    result = {}
    for key, option in (("gtk", "gtk-theme-name"), ("icons", "gtk-icon-theme-name")):
        name = native.get("Settings", option, fallback="")
        try:
            output = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface",
                                     "gtk-theme" if key == "gtk" else "icon-theme"],
                                    capture_output=True, text=True, timeout=5, check=True)
            selected = ast.literal_eval(output.stdout.strip())
            if isinstance(selected, str):
                name = selected
        except (OSError, ValueError, SyntaxError, subprocess.SubprocessError):
            pass
        result[key] = name if "\n" not in name and "\r" not in name else ""
    return result


def write_settings(path, values):
    """Replace only GTK appearance keys, preserving other settings and comments."""
    if path.is_symlink():
        raise ValueError(f"Refusing symlinked GTK settings: {path}")
    original = path.read_text() if path.exists() else "[Settings]\n"
    section = re.search(r'(?ms)^\[Settings\][^\n]*\n(.*?)(?=^\[|\Z)', original)
    if section is None:
        original = original.rstrip() + "\n\n[Settings]\n"
        section = re.search(r'(?ms)^\[Settings\][^\n]*\n(.*?)(?=^\[|\Z)', original)
    body = section[1]
    for key, value in values.items():
        pattern = rf'(?m)^{re.escape(key)}\s*=.*$'
        line = f"{key}={value}"
        body = re.sub(pattern, lambda _: line, body) if re.search(pattern, body) else body.rstrip() + "\n" + line + "\n"
    updated = original[:section.start(1)] + body + original[section.end(1):]
    if updated == original and path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".appearance-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            os.fchmod(stream.fileno(), stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600)
            stream.write(updated)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def apply(gtk_theme, icon_theme, mode, gtk_directory):
    """Update native settings without creating global CSS overrides or changing cursors."""
    if mode not in ("dark", "light") or any("\n" in value or "\r" in value for value in (gtk_theme, icon_theme)):
        raise ValueError("Invalid appearance mode or theme name")
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    values = {"gtk-theme-name": gtk_theme} if gtk_theme else {}
    # Theme names carry the mode; a sticky dark preference would select Light's dark fallback.
    if gtk_theme in ("Hikaide", "Hikaide-Light"):
        values["gtk-application-prefer-dark-theme"] = "0"
    if icon_theme and icon_theme != "system":
        values["gtk-icon-theme-name"] = icon_theme
    if not values:
        return
    paths = [config / f"gtk-{version}/settings.ini" for version in ("3.0", "4.0")]
    for path in paths:
        if path.is_symlink() or path.exists() and not path.is_file():
            raise ValueError(f"Unsafe GTK settings: {path}")
    replacements = []
    # Existing Hikaide overrides must follow the selected theme, including dark fallback imports.
    roots = (Path.home() / ".themes", Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "themes")
    for name in ("gtk.css", "gtk-dark.css"):
        path = config / "gtk-4.0" / name
        if not path.is_symlink():
            continue
        target = path.resolve(strict=False)
        managed = any(target == root / theme / "gtk-4.0" / name
                      for root in roots for theme in ("Hikaide", "Hikaide-Light"))
        if not managed or not gtk_theme:
            continue
        replacement = Path(gtk_directory) / "gtk-4.0" / name
        if gtk_theme in ("Hikaide", "Hikaide-Light") and not replacement.is_file():
            raise ValueError(f"Missing GTK override target: {replacement}")
        replacements.append((path, replacement if gtk_theme in ("Hikaide", "Hikaide-Light") else None))
    for path in paths:
        write_settings(path, values)
    for path, replacement in replacements:
        if replacement is None:
            path.unlink()
        else:
            with tempfile.TemporaryDirectory(prefix=".appearance-", dir=path.parent) as directory:
                staged = Path(directory) / path.name
                staged.symlink_to(replacement)
                os.replace(staged, path)


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["current"]:
            print(json.dumps(current_themes()))
        elif len(sys.argv) == 5:
            apply(*sys.argv[1:])
        else:
            raise ValueError("usage: appearance_settings.py current | GTK_THEME ICON_THEME dark|light GTK_DIRECTORY")
    except (OSError, ValueError) as error:
        sys.exit(str(error))
