#!/usr/bin/env python3
"""Check Taskbar paint and frame placement before and after a calendar tooltip."""
from pathlib import Path
import json
import math
import re
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


def check_handoff(directory, scale, log):
    """Reject retained app artwork under the shared arrows in the real center lane."""
    rect = json.loads(re.search(r'Taskbar handoff return rect (\{[^\n]+\})', log.read_text())[1])
    with Image.open(directory / 'taskbar-handoff-baseline.png') as source:
        before = source.convert('RGB')
    with Image.open(directory / 'taskbar-handoff-hover.png') as source:
        after = source.convert('RGB')
    # Ignore fractional boundary pixels next to the untouched status lanes.
    bounds = (math.ceil(rect['x'] * scale) + 2, math.ceil(rect['y'] * scale) + 2,
              math.floor((rect['x'] + rect['width']) * scale) - 2,
              math.floor((rect['y'] + rect['height']) * scale) - 2)
    points = [(x, y) for y in range(bounds[1], bounds[3]) for x in range(bounds[0], bounds[2])]
    baseline = [before.getpixel(point) for point in points]
    hidden = [after.getpixel(point) for point in points]
    assert sum(a != b for a, b in zip(baseline, hidden)) > 40, 'app artwork did not change'
    assert all(max(pixel) - min(pixel) <= 12 for pixel in hidden), 'colored app artwork remains under arrows'
    assert sum(min(pixel) > 100 for pixel in hidden) > 5, 'return arrows are missing'
    print('Taskbar handoff pixels passed: hidden app artwork and visible return arrows')


if __name__ == "__main__":
    if len(sys.argv) > 3 and sys.argv[3] == '--handoff':
        check_handoff(Path(sys.argv[1]), float(sys.argv[2]), Path(sys.argv[4]))
    else:
        check(Path(sys.argv[1]), float(sys.argv[2]))
