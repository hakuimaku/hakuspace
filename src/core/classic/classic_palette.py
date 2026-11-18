#!/usr/bin/env python3
"""Classic 8-scheme palette catalog, HSL classifier with hysteresis, and token renderer."""

import argparse
import colorsys
import json
import os
from pathlib import Path
import re
import sys

SCHEME_IDS = ("red", "orange", "yellow", "green", "blue", "indigo", "violet", "gray")
CHROMATIC_IDS = ("red", "orange", "yellow", "green", "blue", "indigo", "violet")
VALID_REQUESTS = ("auto",) + SCHEME_IDS

S_ENTER = 0.10
S_EXIT = 0.15
L_MIN = 0.05
L_MAX = 0.95
HUE_BUFFER = 5.0

HUE_RANGES = {
    "red": (345.0, 15.0),
    "orange": (15.0, 40.0),
    "yellow": (40.0, 70.0),
    "green": (70.0, 165.0),
    "blue": (165.0, 225.0),
    "indigo": (225.0, 260.0),
    "violet": (260.0, 345.0),
}

PALETTES = {
    "red": {
        "desktop_bg": "#3f2d2c", "window_bg": "#684745", "panel_bg": "#563a39", "inset_bg": "#342323",
        "title_bg": "#a03a36", "title_fg": "#faf5f5",
        "text": "#f3e8e8", "text_muted": "#e0c6c5", "text_mono": "#e9c5c4",
        "border_light": "#a57a78", "border_dark": "#1f1514", "border_frame": "#120c0c",
        "button_bg": "#764d4c", "button_fg": "#f3e8e8", "button_active_bg": "#4e3332",
        "select_bg": "#de9492", "select_fg": "#190b0b",
        "tag_bg": "#251918", "tag_fg": "#e3b7b5",
        "urgent_bg": "#952323", "urgent_fg": "#ffffff",
    },
    "orange": {
        "desktop_bg": "#3f342c", "window_bg": "#685445", "panel_bg": "#564539", "inset_bg": "#342a23",
        "title_bg": "#965c33", "title_fg": "#faf7f5",
        "text": "#f3ece8", "text_muted": "#e4d7cd", "text_mono": "#e9d5c6",
        "border_light": "#a58b78", "border_dark": "#1f1914", "border_frame": "#120f0c",
        "button_bg": "#765d4c", "button_fg": "#f3ece8", "button_active_bg": "#4e3d32",
        "select_bg": "#deb192", "select_fg": "#19110b",
        "tag_bg": "#251e18", "tag_fg": "#e3c8b5",
        "urgent_bg": "#952323", "urgent_fg": "#ffffff",
    },
    "yellow": {
        "desktop_bg": "#3f3b2c", "window_bg": "#686145", "panel_bg": "#565039", "inset_bg": "#343123",
        "title_bg": "#7a6a29", "title_fg": "#faf9f5",
        "text": "#f3f0e8", "text_muted": "#eae7d9", "text_mono": "#ede7cf",
        "border_light": "#a59c78", "border_dark": "#1f1d14", "border_frame": "#12110c",
        "button_bg": "#6e6647", "button_fg": "#f3f0e8", "button_active_bg": "#4e4832",
        "select_bg": "#dece92", "select_fg": "#19160b",
        "tag_bg": "#252218", "tag_fg": "#e3dab5",
        "urgent_bg": "#952323", "urgent_fg": "#ffffff",
    },
    "green": {
        "desktop_bg": "#2c3f2e", "window_bg": "#456848", "panel_bg": "#39563c", "inset_bg": "#233424",
        "title_bg": "#297a30", "title_fg": "#f5faf5",
        "text": "#e8f3e9", "text_muted": "#d7ead9", "text_mono": "#cfedd1",
        "border_light": "#78a57c", "border_dark": "#141f15", "border_frame": "#0c120d",
        "button_bg": "#476e4a", "button_fg": "#e8f3e9", "button_active_bg": "#324e34",
        "select_bg": "#92de98", "select_fg": "#0b190c",
        "tag_bg": "#18251a", "tag_fg": "#b5e3b9",
        "urgent_bg": "#952323", "urgent_fg": "#ffffff",
    },
    "blue": {
        "desktop_bg": "#2c353f", "window_bg": "#455668", "panel_bg": "#394656", "inset_bg": "#232b34",
        "title_bg": "#3668a0", "title_fg": "#f5f7fa",
        "text": "#e8edf3", "text_muted": "#c8d4e2", "text_mono": "#c4d5e9",
        "border_light": "#788da5", "border_dark": "#14191f", "border_frame": "#0c0f12",
        "button_bg": "#4c5f76", "button_fg": "#e8edf3", "button_active_bg": "#323f4e",
        "select_bg": "#92b5de", "select_fg": "#0b1119",
        "tag_bg": "#181e25", "tag_fg": "#b5cae3",
        "urgent_bg": "#952323", "urgent_fg": "#ffffff",
    },
    "indigo": {
        "desktop_bg": "#2d2c3f", "window_bg": "#474568", "panel_bg": "#3b3956", "inset_bg": "#242334",
        "title_bg": "#3b36a0", "title_fg": "#f5f5fa",
        "text": "#e8e8f3", "text_muted": "#c0bedc", "text_mono": "#c6c4e9",
        "border_light": "#7b78a5", "border_dark": "#15141f", "border_frame": "#0d0c12",
        "button_bg": "#4e4c76", "button_fg": "#e8e8f3", "button_active_bg": "#33324e",
        "select_bg": "#9592de", "select_fg": "#0b0b19",
        "tag_bg": "#191825", "tag_fg": "#b7b5e3",
        "urgent_bg": "#952323", "urgent_fg": "#ffffff",
    },
    "violet": {
        "desktop_bg": "#372c3f", "window_bg": "#5a4568", "panel_bg": "#4a3956", "inset_bg": "#2d2334",
        "title_bg": "#7436a0", "title_fg": "#f8f5fa",
        "text": "#eee8f3", "text_muted": "#d2c2de", "text_mono": "#d9c4e9",
        "border_light": "#9378a5", "border_dark": "#1a141f", "border_frame": "#100c12",
        "button_bg": "#644c76", "button_fg": "#eee8f3", "button_active_bg": "#42324e",
        "select_bg": "#be92de", "select_fg": "#130b19",
        "tag_bg": "#201825", "tag_fg": "#d0b5e3",
        "urgent_bg": "#952323", "urgent_fg": "#ffffff",
    },
    "gray": {
        "desktop_bg": "#363636", "window_bg": "#575757", "panel_bg": "#474747", "inset_bg": "#2b2b2b",
        "title_bg": "#6a6a6a", "title_fg": "#f7f7f7",
        "text": "#ededed", "text_muted": "#d7d7d7", "text_mono": "#d7d7d7",
        "border_light": "#8f8f8f", "border_dark": "#1a1a1a", "border_frame": "#0f0f0f",
        "button_bg": "#616161", "button_fg": "#ededed", "button_active_bg": "#404040",
        "select_bg": "#b8b8b8", "select_fg": "#121212",
        "tag_bg": "#1f1f1f", "tag_fg": "#cccccc",
        "urgent_bg": "#952323", "urgent_fg": "#ffffff",
    },
}


def hex_to_hsl(hex_color):
    """Return (hue_deg, lightness, saturation) for a #RRGGBB color."""
    r, g, b = (int(hex_color[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return (h * 360.0) % 360.0, l, s


def _angular_distance(a, b):
    diff = abs(a - b) % 360.0
    return min(diff, 360.0 - diff)


def classify_hue(hue_deg):
    """Map a hue in [0, 360) to one of the 7 chromatic scheme IDs."""
    h = hue_deg % 360.0
    if h >= 345.0 or h < 15.0:
        return "red"
    for scheme in CHROMATIC_IDS[1:]:
        start, end = HUE_RANGES[scheme]
        if start <= h < end:
            return scheme
    return "red"


def resolve_scheme(seed_hex, requested="auto", previous_effective=None):
    """Resolve the effective Classic scheme ID with saturation and hue hysteresis."""
    req = (requested or "auto").strip().lower()
    if req in SCHEME_IDS:
        return req

    seed = (seed_hex or "").strip()
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", seed):
        return "gray"

    hue_deg, lightness, saturation = hex_to_hsl(seed)
    if lightness < L_MIN or lightness > L_MAX:
        return "gray"

    prev = (previous_effective or "").strip().lower()
    if prev == "gray":
        if saturation <= S_EXIT:
            return "gray"
    elif prev in CHROMATIC_IDS:
        if saturation < S_ENTER:
            return "gray"
    else:
        if saturation < (S_ENTER + S_EXIT) / 2.0:
            return "gray"

    if prev in CHROMATIC_IDS:
        start, end = HUE_RANGES[prev]
        if _angular_distance(hue_deg, start) <= HUE_BUFFER or _angular_distance(hue_deg, end) <= HUE_BUFFER:
            return prev

    return classify_hue(hue_deg)


def _hex_to_rgb_expr(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return f"rgb({r}, {g}, {b})"


def _atomic_write(path, content):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    os.replace(tmp, path)


def kitty_palette_lines(scheme_id):
    """Return Kitty color lines for the given Classic scheme."""
    tokens = PALETTES[scheme_id]
    return [
        f"# Generated by classic_palette.py (scheme: {scheme_id})",
        f"background {tokens['inset_bg']}",
        f"foreground {tokens['text']}",
        f"cursor {tokens['select_bg']}",
        f"cursor_text_color {tokens['select_fg']}",
        f"selection_background {tokens['select_bg']}",
        f"selection_foreground {tokens['select_fg']}",
        f"url_color {tokens['select_bg']}",
        f"tab_bar_background {tokens['panel_bg']}",
        f"active_tab_background {tokens['title_bg']}",
        f"active_tab_foreground {tokens['title_fg']}",
        f"inactive_tab_background {tokens['window_bg']}",
        f"inactive_tab_foreground {tokens['text_muted']}",
        f"color0  {tokens['tag_bg']}",
        "color8  #9a9a9a",
        "color1  #e57470",
        "color9  #f0928e",
        "color2  #78b878",
        "color10 #98d498",
        "color3  #cfa84e",
        "color11 #e8c46c",
        "color4  #7aa4d4",
        "color12 #98c0ec",
        "color5  #c484c0",
        "color13 #dc9ed8",
        "color6  #68b8b8",
        "color14 #86d2d2",
        f"color7  {tokens['text_muted']}",
        f"color15 {tokens['text']}",
    ]


def render_files(scheme_id, out_dir):
    """Write palette.css, palette.rasi, hyprlock-palette.conf, and kitty-palette.conf into out_dir."""
    if scheme_id not in PALETTES:
        raise ValueError(f"Unknown scheme: {scheme_id}")
    tokens = PALETTES[scheme_id]
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    css_lines = [f"/* Generated by classic_palette.py (scheme: {scheme_id}) */"]
    rasi_lines = [f"/* Generated by classic_palette.py (scheme: {scheme_id}) */", "* {"]
    hypr_lines = [f"# Generated by classic_palette.py (scheme: {scheme_id})", f"$classic_scheme = {scheme_id}"]

    for key, value in tokens.items():
        css_lines.append(f"@define-color {key} {value};")
        rasi_lines.append(f"    {key.replace('_', '-')}: {value};")
        hypr_lines.append(f"${key} = {_hex_to_rgb_expr(value)}")

    rasi_lines.append("}")
    _atomic_write(out / "palette.css", "\n".join(css_lines) + "\n")
    _atomic_write(out / "palette.rasi", "\n".join(rasi_lines) + "\n")
    _atomic_write(out / "hyprlock-palette.conf", "\n".join(hypr_lines) + "\n")
    _atomic_write(out / "kitty-palette.conf", "\n".join(kitty_palette_lines(scheme_id)) + "\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Classic 8-scheme palette engine")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_res = sub.add_parser("resolve", help="Resolve effective scheme from seed and state")
    p_res.add_argument("--seed", required=True)
    p_res.add_argument("--requested", default="auto")
    p_res.add_argument("--previous", default="")
    p_res.add_argument("--format", choices=("id", "json"), default="id")

    p_ren = sub.add_parser("render", help="Render palette.css, palette.rasi, hyprlock-palette.conf")
    p_ren.add_argument("--scheme", required=True, choices=SCHEME_IDS)
    p_ren.add_argument("--out-dir", required=True)

    sub.add_parser("list", help="List available scheme IDs")

    args = parser.parse_args(argv)
    if args.cmd == "list":
        print("\n".join(SCHEME_IDS))
        return 0
    if args.cmd == "resolve":
        effective = resolve_scheme(args.seed, args.requested, args.previous)
        if args.format == "json":
            print(json.dumps({"requested": args.requested, "effective": effective, "tokens": PALETTES[effective]}))
        else:
            print(effective)
        return 0
    if args.cmd == "render":
        render_files(args.scheme, args.out_dir)
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
