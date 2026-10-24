#!/usr/bin/env python3
"""Check Taskbar paint and frame placement before and after a calendar tooltip."""
from pathlib import Path
import sys
from PIL import Image


def check(directory, scale):
    """Inspect actual frames so valid QML geometry cannot hide a misplaced rail."""
    surface = (11, 11, 11)
    background = (74, 113, 136)
    for name in ("unified-crowded", "taskbar-calendar", "unified-navigation"):
        with Image.open(directory / (name + ".png")) as source:
            image = source.convert("RGB")
        width, height = image.size
        # The fixture starts with a 36 px icon and a 53 px bar at every tested scale.
        ghost_rail_y = round(height - (53 * 2 + 2) * scale)
        # Stay between the left Navigation and right status panels during capture.
        assert image.getpixel((width // 3, ghost_rail_y)) == background, name + ": doubled bottom frame inset"
        assert image.getpixel((width // 2, 0)) == surface, name + ": missing Taskbar-mode top rail"
        assert image.getpixel((width // 3, round(height - 53 * scale) - 1)) == background, name + ": unexpected bottom frame rail"
        painted = sum(image.getpixel((x, height - 1)) == surface for x in range(width))
        assert painted >= width * 0.99, name + ": Taskbar surface leaves the physical bottom uncovered"
    print("Taskbar frame and tooltip pixel checks passed")


if __name__ == "__main__":
    check(Path(sys.argv[1]), float(sys.argv[2]))
