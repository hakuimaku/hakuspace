#!/usr/bin/env python3
"""Classic 8-scheme palette catalog, HSL classifier with hysteresis, and token renderer."""

import argparse
import colorsys
import json
import os
from pathlib import Path
import re
import sys
from xml.sax.saxutils import escape as _xml_escape

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


def _labwc_bevel_svg(bg, top_left, bottom_right, glyph_svg):
    """Build a 22x22 pixel-crisp 2px-bevelled SVG titlebar button."""
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 22 22" shape-rendering="crispEdges">',
        f'  <rect x="0" y="0" width="22" height="22" fill="{bg}"/>',
        f'  <rect x="0" y="0" width="22" height="2" fill="{top_left}"/>',
        f'  <rect x="0" y="0" width="2" height="22" fill="{top_left}"/>',
        f'  <rect x="1" y="20" width="21" height="2" fill="{bottom_right}"/>',
        f'  <rect x="20" y="1" width="2" height="21" fill="{bottom_right}"/>',
        f'  <rect x="20" y="0" width="1" height="1" fill="{top_left}"/>',
        f'  <rect x="0" y="20" width="1" height="1" fill="{top_left}"/>',
        f"  {glyph_svg}",
        "</svg>",
    ]
    return "\n".join(parts) + "\n"


def _labwc_glyph(button, fg):
    """Return crisp SVG glyph elements for a labwc titlebar button."""
    if button == "iconify":
        return f'<rect x="6" y="14" width="10" height="2" fill="{fg}"/>'
    if button == "max":
        return (
            f'<rect x="6" y="6" width="10" height="2" fill="{fg}"/>'
            f'<rect x="6" y="8" width="1" height="8" fill="{fg}"/>'
            f'<rect x="15" y="8" width="1" height="8" fill="{fg}"/>'
            f'<rect x="6" y="15" width="10" height="1" fill="{fg}"/>'
        )
    if button == "max_toggled":
        return (
            f'<rect x="9" y="6" width="7" height="2" fill="{fg}"/>'
            f'<rect x="9" y="8" width="1" height="1" fill="{fg}"/>'
            f'<rect x="15" y="8" width="1" height="5" fill="{fg}"/>'
            f'<rect x="13" y="12" width="3" height="1" fill="{fg}"/>'
            f'<rect x="6" y="9" width="7" height="2" fill="{fg}"/>'
            f'<rect x="6" y="11" width="1" height="5" fill="{fg}"/>'
            f'<rect x="12" y="11" width="1" height="5" fill="{fg}"/>'
            f'<rect x="6" y="15" width="7" height="1" fill="{fg}"/>'
        )
    if button == "close":
        rects = []
        for i in range(9):
            rects.append(f'<rect x="{6 + i}" y="{6 + i}" width="2" height="2" fill="{fg}"/>')
            rects.append(f'<rect x="{14 - i}" y="{6 + i}" width="2" height="2" fill="{fg}"/>')
        return "".join(rects)
    if button == "menu":
        return (
            f'<rect x="6" y="7" width="10" height="2" fill="{fg}"/>'
            f'<rect x="6" y="10" width="10" height="2" fill="{fg}"/>'
            f'<rect x="6" y="13" width="10" height="2" fill="{fg}"/>'
        )
    if button == "shade":
        return (
            f'<rect x="10" y="9" width="2" height="2" fill="{fg}"/>'
            f'<rect x="8" y="11" width="6" height="2" fill="{fg}"/>'
            f'<rect x="6" y="13" width="10" height="2" fill="{fg}"/>'
        )
    if button == "shade_toggled":
        return (
            f'<rect x="6" y="8" width="10" height="2" fill="{fg}"/>'
            f'<rect x="8" y="10" width="6" height="2" fill="{fg}"/>'
            f'<rect x="10" y="12" width="2" height="2" fill="{fg}"/>'
        )
    if button == "desk":
        return (
            f'<rect x="8" y="8" width="6" height="1" fill="{fg}"/>'
            f'<rect x="8" y="9" width="1" height="4" fill="{fg}"/>'
            f'<rect x="13" y="9" width="1" height="4" fill="{fg}"/>'
            f'<rect x="8" y="13" width="6" height="1" fill="{fg}"/>'
        )
    if button == "desk_toggled":
        return f'<rect x="8" y="8" width="6" height="6" fill="{fg}"/>'
    raise ValueError(f"Unknown labwc button: {button}")


def labwc_themerc_lines(scheme_id):
    """Return full retro labwc themerc lines for the given Classic scheme."""
    t = PALETTES[scheme_id]
    outline = f"{t['border_light']},{t['border_frame']},{t['select_bg']}"
    return [
        f"# Generated by classic_palette.py (scheme: {scheme_id})",
        "",
        "# Window frame and titlebar",
        "border.width: 2",
        "window.titlebar.padding.width: 4",
        "window.titlebar.padding.height: 3",
        f"window.active.border.color: {t['select_bg']}",
        f"window.inactive.border.color: {t['window_bg']}",
        f"window.active.indicator.toggled-keybind.color: {t['urgent_bg']}",
        "window.active.title.bg: Solid",
        f"window.active.title.bg.color: {t['title_bg']}",
        "window.inactive.title.bg: Solid",
        f"window.inactive.title.bg.color: {t['panel_bg']}",
        f"window.active.label.text.color: {t['title_fg']}",
        f"window.inactive.label.text.color: {t['text_muted']}",
        "window.label.text.justify: Left",
        "",
        "# Titlebar buttons",
        "window.button.width: 22",
        "window.button.height: 22",
        "window.button.spacing: 2",
        "window.button.hover.bg.color: #00000000",
        "window.button.hover.bg.corner-radius: 0",
        f"window.active.button.unpressed.image.color: {t['button_fg']}",
        f"window.inactive.button.unpressed.image.color: {t['text_muted']}",
        "",
        "# Shadows disabled for flat retro geometry",
        "window.active.shadow.size: 0",
        "window.inactive.shadow.size: 0",
        "window.active.shadow.color: #00000000",
        "window.inactive.shadow.color: #00000000",
        "",
        "# Menus",
        "menu.overlap.x: 0",
        "menu.overlap.y: 0",
        "menu.width.min: 160",
        "menu.width.max: 400",
        "menu.border.width: 2",
        f"menu.border.color: {t['border_light']}",
        f"menu.items.bg.color: {t['window_bg']}",
        f"menu.items.text.color: {t['text']}",
        f"menu.items.active.bg.color: {t['select_bg']}",
        f"menu.items.active.text.color: {t['select_fg']}",
        "menu.items.padding.x: 8",
        "menu.items.padding.y: 5",
        "menu.separator.width: 1",
        "menu.separator.padding.width: 6",
        "menu.separator.padding.height: 4",
        f"menu.separator.color: {t['border_dark']}",
        f"menu.title.bg.color: {t['title_bg']}",
        f"menu.title.text.color: {t['title_fg']}",
        "menu.title.text.justify: Left",
        "",
        "# On-screen display",
        f"osd.bg.color: {t['window_bg']}",
        f"osd.border.color: {t['border_light']}",
        "osd.border.width: 2",
        f"osd.label.text.color: {t['text']}",
        "osd.window-switcher.style-classic.width: 50%",
        "osd.window-switcher.style-classic.padding: 8",
        "osd.window-switcher.style-classic.item.padding.x: 10",
        "osd.window-switcher.style-classic.item.padding.y: 2",
        "osd.window-switcher.style-classic.item.active.border.width: 2",
        f"osd.window-switcher.style-classic.item.active.border.color: {t['select_bg']}",
        f"osd.window-switcher.style-classic.item.active.bg.color: {t['panel_bg']}",
        "osd.window-switcher.style-thumbnail.width.max: 80%",
        "osd.window-switcher.style-thumbnail.padding: 8",
        "osd.window-switcher.style-thumbnail.item.width: 300",
        "osd.window-switcher.style-thumbnail.item.height: 250",
        "osd.window-switcher.style-thumbnail.item.padding: 10",
        "osd.window-switcher.style-thumbnail.item.active.border.width: 2",
        f"osd.window-switcher.style-thumbnail.item.active.border.color: {t['select_bg']}",
        f"osd.window-switcher.style-thumbnail.item.active.bg.color: {t['panel_bg']}",
        "osd.window-switcher.style-thumbnail.item.icon.size: 60",
        "osd.window-switcher.preview.border.width: 2",
        f"osd.window-switcher.preview.border.color: {outline}",
        "osd.workspace-switcher.boxes.width: 20",
        "osd.workspace-switcher.boxes.height: 20",
        "osd.workspace-switcher.boxes.border.width: 2",
        "",
        "# Snapping overlays",
        f"snapping.overlay.region.bg.color: {t['title_bg']}40",
        f"snapping.overlay.edge.bg.color: {t['title_bg']}40",
        "snapping.overlay.region.border.width: 2",
        "snapping.overlay.edge.border.width: 2",
        f"snapping.overlay.region.border.color: {outline}",
        f"snapping.overlay.edge.border.color: {outline}",
    ]


def render_labwc_theme(scheme_id, out_dir):
    """Write retro labwc themerc and 2px-bevelled SVG button icons into out_dir."""
    if scheme_id not in PALETTES:
        raise ValueError(f"Unknown scheme: {scheme_id}")
    t = PALETTES[scheme_id]
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    _atomic_write(out / "themerc", "\n".join(labwc_themerc_lines(scheme_id)) + "\n")

    buttons = ("close", "iconify", "max", "max_toggled", "menu", "shade", "shade_toggled", "desk", "desk_toggled")
    for btn in buttons:
        states = {
            f"{btn}-active.svg": (t["button_bg"], t["border_light"], t["border_dark"], t["button_fg"]),
            f"{btn}_hover-active.svg": (
                t["urgent_bg"] if btn == "close" else t["button_active_bg"],
                t["border_dark"],
                t["border_light"],
                t["urgent_fg"] if btn == "close" else t["button_fg"],
            ),
            f"{btn}-inactive.svg": (t["panel_bg"], t["border_light"], t["border_dark"], t["text_muted"]),
            f"{btn}_hover-inactive.svg": (
                t["urgent_bg"] if btn == "close" else t["button_active_bg"],
                t["border_dark"],
                t["border_light"],
                t["urgent_fg"] if btn == "close" else t["text"],
            ),
        }
        for filename, (bg, tl, br, fg) in states.items():
            svg = _labwc_bevel_svg(bg, tl, br, _labwc_glyph(btn, fg))
            _atomic_write(out / filename, svg)


def render_labwc_rc(template_path, out_path, font_family, font_size):
    """Render labwc rc.xml from template with updated font family and size."""
    src = Path(template_path)
    dst = Path(out_path)
    text = src.read_text(encoding="utf-8")
    pattern = re.compile(r"([ \t]*)<!-- BEGIN GENERATED FONTS -->.*?<!-- END GENERATED FONTS -->", re.DOTALL)
    match = pattern.search(text)
    if not match:
        return False
    indent = match.group(1)
    safe_font = _xml_escape((font_family or "monospace").strip() or "monospace", {'"': "&quot;", "'": "&apos;"})
    size = max(8, int(font_size) - 2)
    places = (
        ("ActiveWindow", "bold"),
        ("InactiveWindow", "normal"),
        ("MenuHeader", "bold"),
        ("MenuItem", "normal"),
        ("OnScreenDisplay", "normal"),
    )
    block = [f"{indent}<!-- BEGIN GENERATED FONTS -->"]
    for place, weight in places:
        block.append(
            f'{indent}<font place="{place}"><name>{safe_font}</name><size>{size}</size>'
            f"<slant>normal</slant><weight>{weight}</weight></font>"
        )
    block.append(f"{indent}<!-- END GENERATED FONTS -->")
    rendered = text[:match.start()] + "\n".join(block) + text[match.end():]
    dst.parent.mkdir(parents=True, exist_ok=True)
    _atomic_write(dst, rendered)
    return True


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

    p_labwc = sub.add_parser("render-labwc", help="Render retro labwc themerc and SVG titlebar buttons")
    p_labwc.add_argument("--scheme", required=True, choices=SCHEME_IDS)
    p_labwc.add_argument("--out-dir", required=True)
    p_labwc.add_argument("--rc-template")
    p_labwc.add_argument("--rc-out")
    p_labwc.add_argument("--font-family", default="monospace")
    p_labwc.add_argument("--font-size", type=int, default=14)

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
    if args.cmd == "render-labwc":
        render_labwc_theme(args.scheme, args.out_dir)
        if args.rc_template and args.rc_out:
            render_labwc_rc(args.rc_template, args.rc_out, args.font_family, args.font_size)
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
