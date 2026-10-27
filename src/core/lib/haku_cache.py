"""Resolve disposable cache paths and publish Classic wallpaper image references."""
import json
import os
from pathlib import Path
import tempfile

from haku_state import state_root


def cache_root():
    """Resolve the shared XDG cache namespace without creating directories."""
    return Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "hakuspace"


def render_wallpaper_rasi():
    """Publish escaped absolute image URLs independently of Rofi's working directory."""
    directory = state_root() / "theme"
    directory.mkdir(parents=True, exist_ok=True)
    wallpaper = cache_root() / "wallpaper"
    fd, temporary = tempfile.mkstemp(prefix=".wallpaper-", dir=directory)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write("/* Generated wallpaper cache references. */\n* {\n")
            for shape, scale in (("wide", "width"), ("box", "height")):
                source = json.dumps(str(wallpaper / f"walpaper_{shape}_gen.jpg"), ensure_ascii=False)
                stream.write(f"    wallpaper-{shape}: url({source}, {scale});\n")
            stream.write("}\n")
        os.replace(temporary, directory / "rofi-wallpaper.rasi")
    finally:
        Path(temporary).unlink(missing_ok=True)


if __name__ == "__main__":
    render_wallpaper_rasi()
