#!/usr/bin/env python3
"""Inspect and atomically render non-destructive image editor sessions."""
import argparse
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
from xml.sax.saxutils import escape

# Only local raster formats enter ImageMagick; vector/delegate inputs are rejected.
FORMATS = {"image/png": "PNG", "image/jpeg": "JPEG", "image/webp": "WEBP"}
EXTENSIONS = {".png": "PNG", ".jpg": "JPEG", ".jpeg": "JPEG", ".webp": "WEBP"}
LIMITS = ["-limit", "memory", "256MiB", "-limit", "map", "512MiB", "-limit", "disk", "2GiB", "-limit", "thread", "2"]


def run(args, **kwargs):
    """Bound helper lifetime and propagate diagnostic failures without invoking a shell."""
    return subprocess.run(args, check=True, capture_output=True, timeout=120, **kwargs)


def fingerprint(path):
    """Detect source replacement between inspection and the final atomic commit."""
    stat = path.stat()
    return f"{stat.st_dev}:{stat.st_ino}:{stat.st_size}:{stat.st_mtime_ns}"


def local_path(value):
    """Reject remote paths, control characters and symbolic output destinations."""
    if not isinstance(value, str) or not value.startswith("/") or any(ord(c) < 32 for c in value):
        raise ValueError("An absolute local image path is required.")
    return Path(value)


def inspect(value):
    """Return dimensions after EXIF orientation without exporting intermediate pixels."""
    path = local_path(value)
    if not path.is_file() or path.is_symlink():
        raise ValueError("The source must be a readable regular image, not a symbolic link.")
    stamp = fingerprint(path)
    mime = run(["file", "-b", "--mime-type", "--", str(path)], text=True).stdout.strip()
    if mime not in FORMATS:
        raise ValueError("Supported image types: PNG, JPEG and WebP.")
    with path.open("rb") as image:
        result = run(["magick", "identify", *LIMITS, "-ping", "-format", "%w %h %[orientation]", FORMATS[mime] + ":-[0]"], stdin=image, text=True).stdout.split()
    width, height = int(result[0]), int(result[1])
    if width < 1 or height < 1 or width * height > 100_000_000:
        raise ValueError("The image exceeds the 100 megapixel editing limit.")
    if result[2] in ("LeftTop", "RightTop", "RightBottom", "LeftBottom"):
        width, height = height, width
    if stamp != fingerprint(path):
        raise ValueError("The source changed while it was being inspected.")
    return dict(path=str(path), width=width, height=height, format=FORMATS[mime], mime=mime, fingerprint=stamp)


def number(value, low, high):
    """Validate finite numeric spec fields at the process boundary."""
    if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value) or not low <= value <= high:
        raise ValueError("Invalid numeric value in image edit specification.")
    return value


def point(value, width, height):
    """Map normalized oriented-image coordinates to export pixels."""
    return number(value["x"], 0, 1) * width, number(value["y"], 0, 1) * height


def annotation_svg(items, width, height):
    """Build a trusted SVG layer from bounded strokes and editable arrow objects."""
    if not isinstance(items, list) or len(items) > 1000:
        raise ValueError("Too many annotations.")
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">']
    total = 0
    for item in items:
        color = item["color"]
        if not isinstance(color, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
            raise ValueError("Invalid annotation color.")
        stroke = number(item["width"], 0.0001, 0.2) * min(width, height)
        opacity = number(item["opacity"], 0, 1)
        if item["type"] == "arrow":
            start, end = point(item["start"], width, height), point(item["end"], width, height)
            angle = math.atan2(end[1] - start[1], end[0] - start[0])
            length = stroke * 4
            head = [(end[0] - length * math.cos(angle + offset), end[1] - length * math.sin(angle + offset)) for offset in (-0.5, 0.5)]
            parts.append(f'<g><path d="M {start[0]} {start[1]} L {end[0]} {end[1]}" fill="none" stroke="{color}" stroke-width="{stroke}" stroke-opacity="{opacity}" stroke-linecap="round"/><polygon points="{end[0]},{end[1]} {head[0][0]},{head[0][1]} {head[1][0]},{head[1][1]}" fill="{color}" fill-opacity="{opacity}"/></g>')
        elif item["type"] == "stroke":
            points = item["points"]
            if not isinstance(points, list) or not points or len(points) > 20000:
                raise ValueError("Invalid stroke path.")
            total += len(points)
            if total > 200000:
                raise ValueError("Too many stroke points.")
            coords = [point(p, width, height) for p in points]
            if len(coords) == 1:
                x, y = coords[0]
                parts.append(f'<circle cx="{x}" cy="{y}" r="{stroke / 2}" fill="{color}" opacity="{opacity}"/>')
            else:
                path = "M " + " L ".join(f"{x} {y}" for x, y in coords)
                parts.append(f'<path d="{escape(path)}" fill="none" stroke="{color}" stroke-width="{stroke}" stroke-opacity="{opacity}" stroke-linecap="round" stroke-linejoin="round"/>')
        else:
            raise ValueError("Unsupported annotation type.")
    return "".join(parts) + "</svg>"


def crop_pixels(crop, width, height):
    """Round crop boundaries identically to the preview's output dimension label."""
    x, y = number(crop["x"], 0, 1), number(crop["y"], 0, 1)
    w, h = number(crop["width"], 0.000001, 1), number(crop["height"], 0.000001, 1)
    if x + w > 1.000001 or y + h > 1.000001:
        raise ValueError("The crop lies outside the image.")
    left, top = math.floor(x * width + 0.5), math.floor(y * height + 0.5)
    right, bottom = math.floor((x + w) * width + 0.5), math.floor((y + h) * height + 0.5)
    if right <= left or bottom <= top:
        raise ValueError("The crop must contain at least one pixel.")
    return left, top, right - left, bottom - top


def render(spec):
    """Render into a sibling temporary file and commit only after every operation succeeds."""
    info = inspect(spec["sourcePath"])
    source = Path(info["path"])
    if info["fingerprint"] != spec["fingerprint"]:
        raise ValueError("The source changed. Reopen it before saving.")
    mode = spec["mode"]
    if mode not in ("avatar", "screenshot", "file"):
        raise ValueError("Invalid editor mode.")
    output = local_path(spec["outputPath"])
    if output.is_symlink():
        raise ValueError("Symbolic output destinations are not supported.")
    output = output.parent.resolve(strict=True) / output.name
    if mode == "screenshot" and output != source.resolve():
        raise ValueError("Screenshot saves must replace the captured image.")
    if mode != "screenshot" and (output.exists() or output == source.resolve()):
        raise ValueError("Save As requires a new file name.")
    encoding = EXTENSIONS.get(output.suffix.lower())
    if not encoding or (mode in ("avatar", "screenshot") and encoding != "PNG"):
        raise ValueError("Choose a PNG, JPEG or WebP output file.")
    rotation = spec.get("rotation", 0)
    if rotation not in (0, 90, 180, 270):
        raise ValueError("Rotation must be a quarter turn.")
    if any(not isinstance(spec.get(key, False), bool) for key in ("flipX", "flipY")):
        raise ValueError("Mirror flags must be boolean values.")
    width, height = info["width"], info["height"]
    if rotation % 180:
        width, height = height, width
    x, y, cw, ch = crop_pixels(spec["cropRectNormalized"], width, height)
    scale = number(spec.get("outputScale", 1), 0.01, 1)
    quality = int(number(spec.get("encodeQuality", 90), 1, 100))
    ow, oh = max(1, math.floor(cw * scale + 0.5)), max(1, math.floor(ch * scale + 0.5))
    if mode == "avatar":
        if abs(cw - ch) > 1:
            raise ValueError("Avatar crops must be square.")
        ow = oh = 512
    svg = annotation_svg(spec.get("annotations", []), width, height)
    with tempfile.TemporaryDirectory(prefix=".hikai-edit-", dir=output.parent) as temporary:
        layer, staged = Path(temporary) / "annotations.svg", Path(temporary) / ("output" + output.suffix.lower())
        layer.write_text(svg)
        args = ["magick", *LIMITS, info["format"] + ":-[0]", "-auto-orient", "-rotate", str(rotation)]
        if spec.get("flipX", False):
            args += ["-flop"]
        if spec.get("flipY", False):
            args += ["-flip"]
        if spec.get("annotations"):
            args += ["-background", "none", str(layer), "-compose", "over", "-composite"]
        args += ["-crop", f"{cw}x{ch}+{x}+{y}", "+repage", "-resize", f"{ow}x{oh}!", "-strip"]
        if encoding in ("JPEG", "WEBP"):
            args += ["-quality", str(quality)]
        args += [encoding + ":" + str(staged)]
        with source.open("rb") as image:
            run(args, stdin=image)
        staged.chmod(0o600)
        with staged.open("rb") as result:
            os.fsync(result.fileno())
        if fingerprint(source) != info["fingerprint"] or source.is_symlink():
            raise ValueError("The source changed during export; it was not replaced.")
        if mode == "screenshot":
            os.replace(staged, output)
        else:
            # Linking preserves Save As's no-overwrite guarantee even under a race.
            os.link(staged, output)
    warning = ""
    if mode == "screenshot":
        try:
            with output.open("rb") as edited:
                subprocess.run(["wl-copy", "--type", "image/png"], stdin=edited, check=True, capture_output=True, timeout=10)
        except (OSError, subprocess.SubprocessError):
            warning = "Image saved, but the clipboard could not be updated."
    return dict(path=str(output), width=ow, height=oh, warning=warning)


def terminate(signum, _frame):
    """Unwind subprocess and temporary-file contexts when Quickshell reloads."""
    raise SystemExit(128 + signum)


def main():
    """Expose small JSON responses and keep annotation specs out of command arguments."""
    signal.signal(signal.SIGTERM, terminate)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("inspect", "render"))
    parser.add_argument("path")
    args = parser.parse_args()
    try:
        if args.action == "inspect":
            result = inspect(args.path)
        else:
            path = Path(args.path)
            if path.stat().st_size > 16 * 1024 * 1024:
                raise ValueError("The image edit specification is too large.")
            result = render(json.loads(path.read_text()))
        print(json.dumps(result))
    except (OSError, ValueError, KeyError, TypeError, IndexError, subprocess.SubprocessError) as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
