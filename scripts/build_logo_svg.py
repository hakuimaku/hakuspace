#!/usr/bin/env python3
"""Build deterministic HakuSpace SVG logos (white and black variants).

Outputs:
- assets/logo-white.svg (foreground: #FFFFFF)
- assets/logo-black.svg (foreground: #000000)

Usage:
    python3 scripts/build_logo_svg.py
    python3 scripts/build_logo_svg.py --check
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_ROOT / "assets"

VIEWBOX = "0 0 1024 1024"
STROKE_WIDTH = "78.4"

# Geometric model: 5 semantic components rendered as 4 minimal continuous paths.
# All paths share uniform stroke width, round linecaps, and round linejoins.
PATHS = [
    # 1. Nhánh lớn phía trên-trái đi xuống tâm (Upper-left diagonal branch to center stem)
    "M213.54 248.36L401.56 392.4L447.9 524.37",
    # 2. Capsule/ray phía trên (Top diagonal ray)
    "M485.05 280.21L645.1 122.2",
    # 3. Capsule/ray phía phải (Right diagonal ray)
    "M587.53 460.68L810.46 295.73",
    # 4 & 5. Nhánh chéo phía dưới-trái và vòng tròn mở phía dưới (Lower-left branch + bottom open arc)
    "M287.85 510.49L448.71 628.08A143.72 143.72 0 1 0 571.2 628.08",
]

VARIANTS = {
    "logo-white.svg": "#FFFFFF",
    "logo-black.svg": "#000000",
}


def render_svg(color: str) -> str:
    """Render deterministic SVG content for a given foreground color."""
    lines = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" fill="none">',
    ]
    for path_d in PATHS:
        lines.append(
            f'  <path d="{path_d}" stroke="{color}" stroke-width="{STROKE_WIDTH}" stroke-linecap="round" stroke-linejoin="round"/>'
        )
    lines.append("</svg>\n")
    return "\n".join(lines)


def validate_svg_content(content: str, expected_color: str) -> None:
    """Perform static validation on generated SVG content."""
    # 1. Parse XML
    try:
        root = ET.fromstring(content)
    except ET.ParseError as err:
        raise ValueError(f"Malformed XML: {err}") from err

    # 2. Check namespace and root tag
    if root.tag != "{http://www.w3.org/2000/svg}svg":
        raise ValueError(f"Unexpected root tag: {root.tag}")

    # 3. Check attributes
    if root.attrib.get("viewBox") != VIEWBOX:
        raise ValueError(f"Expected viewBox '{VIEWBOX}', got '{root.attrib.get('viewBox')}'")
    if root.attrib.get("fill") != "none":
        raise ValueError(f"Expected fill 'none', got '{root.attrib.get('fill')}'")

    # 4. Prohibit forbidden tags (images, filters, gradients, embedded raster)
    forbidden_local_names = {"image", "filter", "linearGradient", "radialGradient", "mask"}
    for elem in root.iter():
        tag_local = elem.tag.split("}")[-1] if "}" in elem.tag else elem.tag
        if tag_local in forbidden_local_names:
            raise ValueError(f"Forbidden element <{tag_local}> found in SVG")
        for val in elem.attrib.values():
            if "data:image" in val or "base64" in val:
                raise ValueError("Embedded raster/base64 data detected")

    # 5. Check paths
    paths = root.findall("{http://www.w3.org/2000/svg}path")
    if len(paths) != len(PATHS):
        raise ValueError(f"Expected {len(PATHS)} paths, found {len(paths)}")

    for i, path in enumerate(paths):
        d = path.attrib.get("d")
        if d != PATHS[i]:
            raise ValueError(f"Path {i} coordinate mismatch: expected '{PATHS[i]}', got '{d}'")
        stroke = path.attrib.get("stroke")
        if stroke != expected_color:
            raise ValueError(f"Path {i} stroke color mismatch: expected '{expected_color}', got '{stroke}'")
        stroke_width = path.attrib.get("stroke-width")
        if stroke_width != STROKE_WIDTH:
            raise ValueError(f"Path {i} stroke width mismatch: expected '{STROKE_WIDTH}', got '{stroke_width}'")
        if path.attrib.get("stroke-linecap") != "round":
            raise ValueError(f"Path {i} linecap is not 'round'")
        if path.attrib.get("stroke-linejoin") != "round":
            raise ValueError(f"Path {i} linejoin is not 'round'")


def build_logos(check_only: bool = False) -> int:
    """Generate or check SVG logo assets."""
    mismatches = []

    for filename, color in VARIANTS.items():
        svg_content = render_svg(color)
        validate_svg_content(svg_content, color)

        target_file = ASSETS_DIR / filename

        if check_only:
            if not target_file.exists():
                print(f"[FAIL] Missing asset: {target_file}", file=sys.stderr)
                mismatches.append(filename)
                continue
            existing_content = target_file.read_text(encoding="utf-8")
            if existing_content != svg_content:
                print(f"[FAIL] Stale or mismatched asset: {target_file}", file=sys.stderr)
                mismatches.append(filename)
            else:
                print(f"[OK] {filename} is up to date and valid.")
        else:
            ASSETS_DIR.mkdir(parents=True, exist_ok=True)
            target_file.write_text(svg_content, encoding="utf-8")
            print(f"[WRITE] {target_file}")

    if check_only:
        if mismatches:
            print(f"\nVerification failed: {len(mismatches)} asset(s) invalid or missing.", file=sys.stderr)
            return 1
        print("\nVerification passed: All SVG logo assets are clean and deterministic.")
        return 0

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Build deterministic HakuSpace SVG logos.")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify on-disk SVG assets without writing; exit non-zero if missing or stale.",
    )
    args = parser.parse_args()
    return build_logos(check_only=args.check)


if __name__ == "__main__":
    sys.exit(main())
