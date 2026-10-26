#!/usr/bin/env python3
"""Apply Hikai's live Light palette without rewriting custom Kitty settings."""

import argparse
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

from accent_palette import derive


def render(mode, surface, accent):
    """Dark mode removes the override so Kitty reads its normal configuration."""
    if mode == "dark":
        return ""
    if not all(re.fullmatch(r"#[0-9a-fA-F]{6}", color or "") for color in (surface, accent)):
        raise ValueError("Light mode requires #RRGGBB surface and accent colors")
    colors = dict(background=surface, foreground=accent, cursor=accent, cursor_text_color=surface,
                  selection_background=accent, selection_foreground=surface,
                  active_tab_background=accent, active_tab_foreground=surface,
                  inactive_tab_background=surface, inactive_tab_foreground=accent,
                  tab_bar_background=surface)
    # Retain the existing terminal palette's hues with readable Light variants.
    ansi = ("#282828", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", accent,
            "#595959", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c", accent)
    colors.update((f"color{index}", derive(color)["light"]) for index, color in enumerate(ansi))
    colors["color7"] = colors["color15"] = accent
    colors["url_color"] = colors["color4"]
    return "".join(f"{key} {value}\n" for key, value in colors.items())


def reload_kitty():
    """Reload each reachable Kitty instance without terminating any terminal."""
    if not shutil.which("kitty"):
        return
    failed = []
    for path in Path("/tmp").glob("kitty-*"):
        try:
            if not stat.S_ISSOCK(path.stat().st_mode):
                continue
            command = ["kitty", "@", "--to", f"unix:{path}"]
            if subprocess.run(command + ["ls"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2).returncode == 0:
                subprocess.run(command + ["load-config"], check=True, capture_output=True, timeout=3)
        except (OSError, subprocess.SubprocessError) as error:
            print(f"Could not reload Kitty at {path}: {error}", file=sys.stderr)
            failed.append(str(path))
    if failed:
        raise RuntimeError("Kitty reload failed: " + ", ".join(failed))


def sync(mode, surface=None, accent=None):
    """Replace only the managed override, avoiding reloads for unchanged colors."""
    content = render(mode, surface, accent)
    path = Path.home() / ".local/state/hakuspace/theme/kitty-mode.conf"
    if path.is_file() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=".kitty-mode-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(content)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    reload_kitty()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("dark", "light"))
    parser.add_argument("surface", nargs="?")
    parser.add_argument("accent", nargs="?")
    args = parser.parse_args()
    try:
        sync(args.mode, args.surface, args.accent)
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"{error}\n")
