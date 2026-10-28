#!/usr/bin/env python3
"""Check actual headless renders for independent corner masks and three rails."""
import sys
import math
from pathlib import Path

# The isolated compositor fixture uses an opaque, known background and surface.
BACKGROUND = bytes((74, 113, 136))
SURFACE = bytes((11, 11, 11))
CASES = ((0, 0), (0, 6), (24, 0), (24, 6), (20, 4))


def check(directory):
    """Read grim's uncompressed PPM output without adding an image dependency."""
    for index, (radius, border) in enumerate(CASES):
        magic, dimensions, maximum, pixels = (directory / f"case-{index}.ppm").read_bytes().split(b"\n", 3)
        assert magic == b"P6" and maximum == b"255", "expected grim P6 image"
        width, height = map(int, dimensions.split())
        assert len(pixels) == width * height * 3, "truncated screenshot"

        # Sample away from antialiasing boundaries and the compositor's cursor.
        def pixel(x, y):
            offset = (y * width + x) * 3
            return pixels[offset:offset + 3]

        assert pixel(width // 2, 0) == BACKGROUND, f"{radius}/{border}: unexpected top rail"
        expected = SURFACE if border else BACKGROUND
        assert pixel(0, height // 2) == expected, f"{radius}/{border}: left rail"
        assert pixel(width - 1, height // 2) == expected, f"{radius}/{border}: right rail"
        assert pixel(width // 2, height - 1) == expected, f"{radius}/{border}: bottom rail"
        assert pixel(0, 0) == (SURFACE if radius or border else BACKGROUND), f"{radius}/{border}: corner mask"
        assert pixel(width // 2, height // 2) == BACKGROUND, f"{radius}/{border}: covered desktop"

        # With TopBar visible, corners must follow its exclusive zone without doubling side/bottom insets.
        images = list(directory.glob(f"bar-case-{index}-top-*-width-*.ppm"))
        assert len(images) == 1, f"{radius}/{border}: missing TopBar screenshot"
        parts = images[0].stem.split("-")
        top, logical_width = float(parts[4]), float(parts[6])
        magic, dimensions, maximum, pixels = images[0].read_bytes().split(b"\n", 3)
        assert magic == b"P6" and maximum == b"255"
        width, height = map(int, dimensions.split())
        assert len(pixels) == width * height * 3
        scale = width / logical_width
        below_bar = round((top + 1) * scale)
        assert pixel(0, 0) == SURFACE and pixel(width - 1, 0) == SURFACE, "TopBar must cover both screen edges"
        assert pixel(width // 2, below_bar) == BACKGROUND, f"{radius}/{border}: rail below TopBar"
        expected_corner = SURFACE if radius else BACKGROUND
        assert pixel(round((border + 1) * scale), below_bar) == expected_corner, f"{radius}/{border}: corner must follow TopBar zone"
        assert pixel(round((border + radius + 2) * scale), below_bar) == BACKGROUND, f"{radius}/{border}: corner inset twice"
        expected = SURFACE if border else BACKGROUND
        assert pixel(0, height // 2) == expected, f"{radius}/{border}: left rail below TopBar"
        assert pixel(width - 1, height // 2) == expected, f"{radius}/{border}: right rail below TopBar"
        # Fractional surface origins can blend the final physical row without leaving a gap.
        assert pixel(width // 2, height - 2) == expected, f"{radius}/{border}: bottom rail below TopBar"
        assert (pixel(width // 2, height - 1) != BACKGROUND) == bool(border), f"{radius}/{border}: uncovered bottom edge"

    # Inspect the attachment pixels of real WindowTitle, Calendar and Notifications tooltips.
    baseline = next(directory.glob("bar-case-0-top-*-width-*.ppm")).stem.split("-")
    top, logical_width = float(baseline[4]), float(baseline[6])
    for owner in ("tooltip-0", "tooltip-1", "tooltip-2"):
        images = list(directory.glob(f"{owner}-start-*-end-*.ppm"))
        assert len(images) == 1, f"{owner}: missing screenshot"
        parts = images[0].stem.removeprefix(owner + "-").split("-")
        start, end = float(parts[1]), float(parts[3])
        _, dimensions, _, pixels = images[0].read_bytes().split(b"\n", 3)
        width, height = map(int, dimensions.split())
        scale = width / logical_width
        for y in range(round(top * scale) - 1, round(top * scale) + 2):
            for x in range(round((start + 2) * scale), round((end - 2) * scale)):
                assert pixel(x, y) == SURFACE, f"{owner}: attachment gap at {x}/{y}"
        if owner == "tooltip-1":
            bottom, foot = float(parts[5]), float(parts[7])
            assert foot > 0, "Calendar tooltip must exercise its right foot"
            assert pixel(round(end * scale) - 2, round((bottom + foot * 0.6) * scale)) == SURFACE, "Calendar tooltip: clipped bottom-right foot"
    # The outer end of a Dashboard ear must reveal the desktop immediately below its tangent.
    for radius in (4, 12, 24):
        images = list(directory.glob(f"dashboard-r-{radius}-edge-*-top-*-width-*.ppm"))
        assert len(images) == 1, f"Dashboard {radius}: missing screenshot"
        parts = images[0].stem.split("-")
        edge, top, logical_width = float(parts[4]), float(parts[6]), float(parts[8])
        _, dimensions, _, pixels = images[0].read_bytes().split(b"\n", 3)
        width, height = map(int, dimensions.split())
        scale = width / logical_width
        # Allow curve antialiasing, but reject an opaque bridge extending below the tangent.
        assert pixel(round(edge * scale) - 2, math.floor(top * scale))[0] > 40, f"Dashboard {radius}: flat step at the ear tip"
    # An interior left edge gets ordinary bottom rounding, while the screen-attached right foot remains.
    images = list(directory.glob("center-start-*-end-*-bottom-*-width-*.ppm"))
    assert len(images) == 1, "Notification Center: missing screenshot"
    parts = images[0].stem.split("-")
    start, end, bottom, logical_width = map(float, (parts[2], parts[4], parts[6], parts[8]))
    _, dimensions, _, pixels = images[0].read_bytes().split(b"\n", 3)
    width, height = map(int, dimensions.split())
    scale = width / logical_width
    assert pixel(round((start + 1) * scale), round((bottom + 3) * scale)) == BACKGROUND, "Notification Center: detached bottom-left foot"
    assert pixel(round((end - 1) * scale), round((bottom + 3) * scale)) == SURFACE, "Notification Center: missing screen-attached right foot"
    print("RoundedScreen pixel matrix passed")


def check_frames(directory):
    """Check every corner and rail with both bar edges and the Settings plane."""
    images = list(directory.glob("frame-*.ppm"))
    assert len(images) == len(CASES) * 5, "incomplete frame matrix"
    for image in images:
        fields = image.stem.split("-")
        radius, border = CASES[int(fields[1])]
        mode, top, bottom, logical_width = fields[2], float(fields[4]), float(fields[6]), float(fields[8])
        magic, dimensions, maximum, pixels = image.read_bytes().split(b"\n", 3)
        width, height = map(int, dimensions.split())
        assert magic == b"P6" and maximum == b"255" and len(pixels) == width * height * 3
        scale = width / logical_width
        taskbar = mode in ("taskbar", "settingsTaskbar")
        top_inset, bottom_inset = (border, 0) if taskbar else (0, border)

        def pixel(x, y):
            offset = (round(y * scale) * width + round(x * scale)) * 3
            return pixels[offset:offset + 3]

        assert pixel(logical_width / 2 + 20, (top + bottom) / 2) == BACKGROUND, image.name + ": desktop covered"
        rail = SURFACE if border else BACKGROUND
        assert pixel(0, (top + bottom) / 2) == rail, image.name + ": left rail"
        assert pixel(logical_width - 1, (top + bottom) / 2) == rail, image.name + ": right rail"
        assert pixel(logical_width / 2, top + 1) == (rail if taskbar else BACKGROUND), image.name + ": top rail"
        assert pixel(logical_width / 2, bottom - 2) == (rail if not taskbar else BACKGROUND), image.name + ": bottom rail"
        corner = SURFACE if radius else BACKGROUND
        for x in (border + 1, logical_width - border - 2):
            for y in (top + top_inset + 1, bottom - bottom_inset - 2):
                assert pixel(x, y) == corner, image.name + ": corner mask"
        assert pixel(border + radius + 3, top + top_inset + 2) == BACKGROUND, image.name + ": corner extends into desktop"
    print("RoundedScreen frame-only pixel matrix passed (25 cases)")


if __name__ == "__main__":
    if "--frame-only" in sys.argv:
        check_frames(Path(sys.argv[1]))
    else:
        check(Path(sys.argv[1]))
