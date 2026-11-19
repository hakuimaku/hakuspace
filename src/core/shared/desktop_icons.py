#!/usr/bin/env python3
"""Hakuspace desktop icon manager."""

import concurrent.futures
import json
import os
import configparser
import re
import shutil
import signal
import weakref
import xml.etree.ElementTree as ET
import shlex
import fnmatch
import mimetypes

import gi
import sys
from pathlib import Path
# Support repository modules and the flattened installed bin directory.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
from haku_state import bin_dir, state_path
from haku_state_migrate import migrate_cached_state

import cairo
import subprocess
import hashlib
import urllib.parse
from math import pi
gi.require_version('Gtk', '3.0')
try:
    gi.require_version('GtkLayerShell', '0.1')
except ValueError:
    print("Error: GtkLayerShell is not installed. Please install 'gtk-layer-shell'.")
    sys.exit(1)

try:
    gi.require_version('GioUnix', '2.0')
    from gi.repository import GioUnix
    HAS_GIO_UNIX = True
except (ValueError, ImportError):
    HAS_GIO_UNIX = False

try:
    gi.require_version('GLibUnix', '2.0')
    from gi.repository import GLibUnix
except (ValueError, ImportError):
    GLibUnix = None

from gi.repository import Gtk, Gdk, GtkLayerShell, Gio, GLib, GdkPixbuf

signal.signal(signal.SIGUSR1, signal.SIG_IGN)


# Default Constants
ICON_SIZE = 70
CELL_WIDTH = 100
CELL_HEIGHT = 100
PADDING = 6

CONFIG_DIR = os.path.expanduser("~/hakucfg/config")
# Icon positions are persistent user layout, independent of generated thumbnails.
POSITIONS_FILE = str(state_path("desktop.icons.positions.json"))
CONF_FILE = os.path.join(CONFIG_DIR, "desktop-icons.conf")

# Exceed ~/.config/gtk-3.0/gtk.css (PRIORITY_USER) so startup-cached @define-color tokens cannot block hot reload.
DESKTOP_CSS_PRIORITY = Gtk.STYLE_PROVIDER_PRIORITY_USER + 1
_DEFINE_COLOR_RE = re.compile(r"^\s*@define-color\s+([a-zA-Z0-9_]+)\s+(#[0-9a-fA-F]{6})\s*;")

DEFAULT_CLASSIC_PALETTE_CSS = """
@define-color window_bg #455668;
@define-color panel_bg #394656;
@define-color inset_bg #232b34;
@define-color title_bg #3668a0;
@define-color title_fg #f5f7fa;
@define-color text #e8edf3;
@define-color text_muted #c8d4e2;
@define-color border_light #788da5;
@define-color border_dark #14191f;
@define-color border_frame #0c0f12;
@define-color button_bg #4c5f76;
@define-color button_fg #e8edf3;
@define-color button_active_bg #323f4e;
@define-color select_bg #92b5de;
@define-color select_fg #0b1119;
@define-color urgent_bg #952323;
@define-color urgent_fg #ffffff;
"""

CLASSIC_DESKTOP_CSS = """
.desktop-icon,
.desktop-icon *,
menu.desktop-context-menu,
menu.desktop-context-menu *,
.desktop-dialog,
.desktop-dialog * {
    border-radius: 0;
    box-shadow: none;
    text-shadow: none;
    background-image: none;
    transition: none;
}

.desktop-icon {
    background-color: rgba(0, 0, 0, 0);
    border: 2px solid transparent;
    padding: 4px 2px;
}

.desktop-icon.hovered {
    background-color: alpha(@panel_bg, 0.85);
    border-style: solid;
    border-width: 2px;
    border-color: @border_light @border_dark @border_dark @border_light;
}

.desktop-icon.selected,
.desktop-icon.hovered.selected {
    background-color: alpha(@window_bg, 0.90);
    border-style: solid;
    border-width: 2px;
    border-color: @border_dark @border_light @border_light @border_dark;
}

.desktop-icon label {
    color: @title_fg;
    text-shadow: 1px 1px 0 @border_frame;
    padding: 1px 3px;
}

.desktop-icon.selected label,
.desktop-icon.hovered.selected label {
    background-color: @select_bg;
    color: @select_fg;
    text-shadow: none;
}

menu.desktop-context-menu {
    background-color: @panel_bg;
    color: @text;
    border-style: solid;
    border-width: 2px;
    border-color: @border_light @border_dark @border_dark @border_light;
    padding: 3px;
}

menu.desktop-context-menu separator {
    background-color: @border_dark;
    min-height: 2px;
    margin: 3px 2px;
}

menu.desktop-context-menu menuitem {
    padding: 4px 8px;
    color: @text;
    background-color: transparent;
}

menu.desktop-context-menu menuitem:hover {
    background-color: @select_bg;
    color: @select_fg;
}

menu.desktop-context-menu menuitem:disabled label {
    color: @text_muted;
}

dialog.desktop-dialog,
window.desktop-dialog,
.desktop-dialog.background {
    background-color: @window_bg;
    color: @text;
    border: 2px solid @border_frame;
}

.desktop-dialog-frame {
    background-color: @window_bg;
    border-style: solid;
    border-width: 2px;
    border-color: @border_light @border_dark @border_dark @border_light;
    padding: 3px;
}

.desktop-dialog-titlebar {
    background-color: @title_bg;
    color: @title_fg;
    padding: 4px 6px;
}

.desktop-dialog-title {
    color: @title_fg;
    font-weight: bold;
}

.desktop-dialog-body {
    background-color: @panel_bg;
    border-style: solid;
    border-width: 2px;
    border-color: @border_dark @border_light @border_light @border_dark;
    padding: 10px;
}

.desktop-dialog-entry {
    background-color: @inset_bg;
    color: @text;
    caret-color: @select_bg;
    border-style: solid;
    border-width: 2px;
    border-color: @border_dark @border_light @border_light @border_dark;
    padding: 5px 8px;
}

.desktop-dialog-entry selection {
    background-color: @select_bg;
    color: @select_fg;
}

button.desktop-dialog-btn {
    background-color: @button_bg;
    color: @button_fg;
    border-style: solid;
    border-width: 2px;
    border-color: @border_light @border_dark @border_dark @border_light;
    padding: 4px 12px;
    min-height: 24px;
}

button.desktop-dialog-btn:hover {
    background-color: @button_active_bg;
}

button.desktop-dialog-btn.is-primary {
    background-color: @title_bg;
    color: @title_fg;
}

button.desktop-dialog-btn.is-danger {
    background-color: @urgent_bg;
    color: @urgent_fg;
}

button.desktop-dialog-close {
    background-color: @button_bg;
    color: @button_fg;
    border-style: solid;
    border-width: 2px;
    border-color: @border_light @border_dark @border_dark @border_light;
    padding: 0 5px;
    min-width: 18px;
    min-height: 18px;
    font-weight: bold;
}

button.desktop-dialog-close:hover {
    background-color: @urgent_bg;
    color: @urgent_fg;
}

.desktop-pin-badge {
    background-color: @title_bg;
    color: @title_fg;
    border: 1px solid @border_frame;
    border-radius: 0px;
    font-size: 9px;
    font-weight: bold;
    padding: 1px 4px;
    margin: 2px;
}
"""


def read_shell_backend():
    """Return active HakuSpace shell backend ('classic' or 'hikai')."""
    try:
        raw = state_path("shell.backend").read_text(encoding="utf-8").strip()
        if raw == "hikai":
            return "hikai"
    except OSError:
        pass
    return "classic"


def _hex_to_rgb_tuple(hex_color, fallback=(1.0, 1.0, 1.0)):
    val = str(hex_color or "").strip().lstrip("#")
    if len(val) == 6:
        try:
            return (
                int(val[0:2], 16) / 255.0,
                int(val[2:4], 16) / 255.0,
                int(val[4:6], 16) / 255.0,
            )
        except ValueError:
            pass
    return fallback


def _hex_to_rgba_css(hex_color, alpha):
    val = str(hex_color or "").strip().lstrip("#")
    if len(val) == 6:
        try:
            return f"rgba({int(val[0:2], 16)}, {int(val[2:4], 16)}, {int(val[4:6], 16)}, {alpha:.3f})"
        except ValueError:
            pass
    return f"rgba(255, 255, 255, {alpha:.3f})"


def _parse_classic_palette_tokens(palette_path=None):
    tokens = {}
    for line in DEFAULT_CLASSIC_PALETTE_CSS.splitlines():
        m = _DEFINE_COLOR_RE.match(line)
        if m:
            tokens[m.group(1)] = m.group(2)
    path = Path(os.path.expanduser(
        palette_path or os.environ.get("HAKUSPACE_CLASSIC_PALETTE") or "~/.local/state/hakuspace/theme/classic/palette.css"
    ))
    if path.is_file():
        try:
            for line in path.read_text(encoding="utf-8").splitlines():
                m = _DEFINE_COLOR_RE.match(line)
                if m:
                    tokens[m.group(1)] = m.group(2)
        except OSError:
            pass
    return tokens


def _load_hikai_theme_tokens():
    qs_path = Path(os.path.expanduser(
        os.environ.get("HAKUSPACE_QUICKSHELL_THEME") or "~/.local/state/hakuspace/theme/quickshell.json"
    ))
    settings_path = Path(os.path.expanduser(
        os.environ.get("HAKUSPACE_HIKAI_SETTINGS_FILE") or "~/hakucfg/hikai/hikai-shell.json"
    ))
    qs_data = {}
    if qs_path.is_file():
        try:
            qs_data = json.loads(qs_path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            qs_data = {}

    appearance = {}
    if settings_path.is_file():
        try:
            appearance = json.loads(settings_path.read_text(encoding="utf-8")).get("appearance", {})
        except (OSError, ValueError, AttributeError):
            appearance = {}

    color_mode = appearance.get("colorMode", "dark")
    if color_mode not in ("dark", "light"):
        color_mode = "dark"
    surface_tone = appearance.get("surfaceTone", "dark")
    if surface_tone not in ("ink", "dark", "soft"):
        surface_tone = "dark"
    try:
        base_radius = int(appearance.get("baseRadius", 12))
    except (TypeError, ValueError):
        base_radius = 12
    base_radius = max(0, min(base_radius, 24))

    is_light = color_mode == "light"
    accent_dark = str(qs_data.get("accentDark") or "#ffffff")
    accent_light = str(qs_data.get("accentLight") or "#414141")
    accent = accent_light if is_light else accent_dark
    on_accent = "#ffffff" if is_light else "#000000"

    surface_map = {
        ("ink", True): ("#ffffff", "#e9e9e9"),
        ("ink", False): ("#000000", "#202020"),
        ("soft", True): ("#d6d6d6", "#c0c0c0"),
        ("soft", False): ("#171717", "#333333"),
        ("dark", True): ("#eeeeee", "#d7d7d7"),
        ("dark", False): ("#0b0b0b", "#2b2b2b"),
    }
    surface, hover_muted = surface_map[(surface_tone, is_light)]
    fg_muted = "rgba(0, 0, 0, 0.60)" if is_light else "rgba(255, 255, 255, 0.55)"
    font_family = str(qs_data.get("font") or "sans-serif").replace('"', "")
    try:
        font_size = max(8, min(int(qs_data.get("fontSize", 14)), 32))
    except (TypeError, ValueError):
        font_size = 14

    return {
        "is_light": is_light,
        "accent": accent,
        "on_accent": on_accent,
        "surface": surface,
        "hover_muted": hover_muted,
        "fg_muted": fg_muted,
        "danger": "#b32020" if is_light else "#ff6b6b",
        "radius": min(base_radius, 12),
        "font_family": font_family,
        "font_size": font_size,
    }


def build_classic_css(palette_path=None, fonts_path=None, black_labels=None):
    """Build Classic retro CSS using palette.css and fonts.css."""
    if black_labels is None:
        black_labels = BLACK_LABELS
    palette = Path(os.path.expanduser(
        palette_path or os.environ.get("HAKUSPACE_CLASSIC_PALETTE") or "~/.local/state/hakuspace/theme/classic/palette.css"
    ))
    fonts = Path(os.path.expanduser(
        fonts_path or os.environ.get("HAKUSPACE_THEME_FONTS") or "~/.local/state/hakuspace/theme/fonts.css"
    ))
    parts = [DEFAULT_CLASSIC_PALETTE_CSS]
    if palette.is_file():
        try:
            parts.append(palette.read_text(encoding="utf-8"))
        except OSError:
            pass
    if fonts.is_file():
        try:
            parts.append(fonts.read_text(encoding="utf-8"))
        except OSError:
            pass
    parts.append(CLASSIC_DESKTOP_CSS)
    if black_labels:
        parts.append("""
.desktop-icon label {
    color: #111111;
    text-shadow: 1px 1px 0 rgba(255, 255, 255, 0.85);
}
.desktop-icon.selected label,
.desktop-icon.hovered.selected label {
    background-color: @select_bg;
    color: @select_fg;
    text-shadow: none;
}
""")
    return "\n".join(parts)


def build_hikai_css(black_labels=None):
    """Build Hikai adaptive CSS from quickshell.json and hikai-shell.json."""
    if black_labels is None:
        black_labels = BLACK_LABELS
    t = _load_hikai_theme_tokens()
    accent = t["accent"]
    radius = t["radius"]
    btn_radius = max(0, min(radius, 10))
    item_radius = max(0, radius - 4)
    label_font_size = max(11, t["font_size"] - 1)
    if black_labels:
        label_css = """
.desktop-icon label {
    color: #111111;
    text-shadow: 1px 1px 3px rgba(255, 255, 255, 0.78);
    opacity: 0.90;
    transition: opacity 180ms ease-in-out;
}"""
    else:
        label_css = """
.desktop-icon label {
    color: #ffffff;
    text-shadow: 2px 2px 6px rgba(0, 0, 0, 0.90);
    opacity: 0.88;
    transition: opacity 180ms ease-in-out;
}"""

    return f"""
.desktop-icon {{
    background-color: rgba(0, 0, 0, 0);
    border-radius: {radius}px;
    border: 1px solid transparent;
    padding: 4px 2px;
    transition: all 180ms ease-in-out;
}}
.desktop-icon.hovered {{
    background-color: {_hex_to_rgba_css(accent, 0.14)};
    border-color: {_hex_to_rgba_css(accent, 0.35)};
    box-shadow: 0 0 10px {_hex_to_rgba_css(accent, 0.16)};
}}
.desktop-icon.selected,
.desktop-icon.hovered.selected {{
    background-color: {_hex_to_rgba_css(accent, 0.24)};
    border-color: {_hex_to_rgba_css(accent, 0.70)};
    box-shadow: 0 0 12px {_hex_to_rgba_css(accent, 0.26)};
}}
{label_css}
.desktop-icon label {{
    font-family: "{t['font_family']}";
    font-size: {label_font_size}px;
}}
.desktop-icon.hovered label,
.desktop-icon.selected label {{
    opacity: 1.0;
}}

menu.desktop-context-menu {{
    background-color: {t['surface']};
    color: {accent};
    border: 1px solid {_hex_to_rgba_css(accent, 0.28)};
    border-radius: {radius}px;
    padding: 4px;
    font-family: "{t['font_family']}";
    font-size: {t['font_size']}px;
}}
menu.desktop-context-menu separator {{
    background-color: {t['hover_muted']};
    min-height: 1px;
    margin: 4px 6px;
}}
menu.desktop-context-menu menuitem {{
    padding: 5px 10px;
    border-radius: {item_radius}px;
    color: {accent};
    background-color: transparent;
}}
menu.desktop-context-menu menuitem:hover {{
    background-color: {accent};
    color: {t['on_accent']};
}}
menu.desktop-context-menu menuitem:disabled label {{
    color: {t['fg_muted']};
}}

dialog.desktop-dialog,
window.desktop-dialog,
.desktop-dialog.background {{
    background-color: {t['surface']};
    color: {accent};
    border: 1px solid {_hex_to_rgba_css(accent, 0.35)};
    border-radius: {radius}px;
    font-family: "{t['font_family']}";
    font-size: {t['font_size']}px;
}}
.desktop-dialog-frame {{
    background-color: {t['surface']};
    border-radius: {radius}px;
    padding: 10px;
}}
.desktop-dialog-titlebar {{
    padding: 2px 4px 8px 4px;
}}
.desktop-dialog-title {{
    color: {accent};
    font-weight: bold;
}}
.desktop-dialog-body {{
    padding: 4px 0 8px 0;
}}
.desktop-dialog-entry {{
    background-color: {t['hover_muted']};
    color: {accent};
    caret-color: {accent};
    border: 1px solid {_hex_to_rgba_css(accent, 0.35)};
    border-radius: {btn_radius}px;
    padding: 6px 10px;
}}
.desktop-dialog-entry selection {{
    background-color: {accent};
    color: {t['on_accent']};
}}
button.desktop-dialog-btn {{
    background-color: {t['hover_muted']};
    color: {accent};
    border: 1px solid {_hex_to_rgba_css(accent, 0.25)};
    border-radius: {btn_radius}px;
    padding: 5px 14px;
    min-height: 26px;
    background-image: none;
    box-shadow: none;
}}
button.desktop-dialog-btn:hover {{
    background-color: {accent};
    color: {t['on_accent']};
}}
button.desktop-dialog-btn.is-primary {{
    background-color: {accent};
    color: {t['on_accent']};
}}
button.desktop-dialog-btn.is-danger {{
    background-color: {t['danger']};
    color: #ffffff;
}}
button.desktop-dialog-close {{
    background-color: transparent;
    color: {t['fg_muted']};
    border: none;
    border-radius: {btn_radius}px;
    padding: 0 6px;
    min-width: 22px;
    min-height: 22px;
    background-image: none;
    box-shadow: none;
}}
button.desktop-dialog-close:hover {{
    background-color: {t['hover_muted']};
    color: {accent};
}}
.desktop-pin-badge {{
    background-color: {accent};
    color: {t['on_accent']};
    border: none;
    border-radius: 999px;
    font-size: 9px;
    font-weight: bold;
    padding: 1px 5px;
    margin: 2px;
}}
"""


def get_overlay_style():
    """Return Cairo overlay colors and corner radius for the active shell backend."""
    if read_shell_backend() == "classic":
        tokens = _parse_classic_palette_tokens()
        sel_rgb = _hex_to_rgb_tuple(tokens.get("select_bg"), (0.57, 0.71, 0.87))
        panel_rgb = _hex_to_rgb_tuple(tokens.get("panel_bg"), (0.22, 0.27, 0.34))
        return {
            "classic": True,
            "radius": 0,
            "rubber_fill": (*sel_rgb, 0.22),
            "rubber_stroke": (*sel_rgb, 0.90),
            "drop_fill": (*panel_rgb, 0.35),
            "drop_stroke": (*sel_rgb, 0.95),
        }
    t = _load_hikai_theme_tokens()
    acc_rgb = _hex_to_rgb_tuple(t["accent"], (1.0, 1.0, 1.0))
    return {
        "classic": False,
        "radius": min(t["radius"], 10),
        "rubber_fill": (*acc_rgb, 0.16),
        "rubber_stroke": (*acc_rgb, 0.65),
        "drop_fill": (*acc_rgb, 0.14),
        "drop_stroke": (*acc_rgb, 0.70),
    }


def build_desktop_css(backend=None, black_labels=None):
    """Build complete CSS for the active backend ('classic' or 'hikai')."""
    mode = backend or read_shell_backend()
    if mode == "classic":
        return build_classic_css(black_labels=black_labels)
    return build_hikai_css(black_labels=black_labels)


def run_prompt_dialog(title, initial_text="", confirm_label="OK", parent=None, danger=False, message=None, show_entry=True):
    """Run a dual-mode themed modal prompt or confirmation dialog."""
    is_classic = read_shell_backend() == "classic"
    dialog = Gtk.Dialog(title=title, transient_for=parent, flags=Gtk.DialogFlags.MODAL)
    dialog.set_decorated(False)
    dialog.set_resizable(False)
    dialog.set_default_size(340, -1)
    dialog.set_position(Gtk.WindowPosition.CENTER)
    dialog.get_style_context().add_class("desktop-dialog")

    action_area = dialog.get_action_area()
    if action_area is not None:
        action_area.set_no_show_all(True)
        action_area.hide()

    content = dialog.get_content_area()
    content.set_border_width(0)
    content.set_spacing(0)

    frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    frame.get_style_context().add_class("desktop-dialog-frame")

    titlebar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    titlebar.get_style_context().add_class("desktop-dialog-titlebar")
    title_lbl = Gtk.Label(label=title.upper() if is_classic else title)
    title_lbl.set_halign(Gtk.Align.START)
    title_lbl.get_style_context().add_class("desktop-dialog-title")
    titlebar.pack_start(title_lbl, True, True, 0)

    close_btn = Gtk.Button(label="X" if is_classic else "×")
    close_btn.set_relief(Gtk.ReliefStyle.NONE)
    close_btn.set_can_focus(False)
    close_btn.get_style_context().add_class("desktop-dialog-close")
    close_btn.connect("clicked", lambda _w: dialog.response(Gtk.ResponseType.CANCEL))
    titlebar.pack_end(close_btn, False, False, 0)
    frame.pack_start(titlebar, False, False, 0)

    body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    body.get_style_context().add_class("desktop-dialog-body")

    if message:
        msg_lbl = Gtk.Label(label=message)
        msg_lbl.set_line_wrap(True)
        msg_lbl.set_max_width_chars(42)
        msg_lbl.set_halign(Gtk.Align.START)
        msg_lbl.set_xalign(0.0)
        body.pack_start(msg_lbl, False, False, 0)

    entry = None
    if show_entry:
        entry = Gtk.Entry()
        entry.get_style_context().add_class("desktop-dialog-entry")
        entry.set_text(initial_text)
        entry.connect("activate", lambda _e: dialog.response(Gtk.ResponseType.OK))
        body.pack_start(entry, False, False, 0)

    frame.pack_start(body, True, True, 0)

    btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    btn_row.set_halign(Gtk.Align.END)

    cancel_btn = Gtk.Button(label="CANCEL" if is_classic else "Cancel")
    cancel_btn.set_relief(Gtk.ReliefStyle.NONE)
    cancel_btn.get_style_context().add_class("desktop-dialog-btn")
    cancel_btn.connect("clicked", lambda _w: dialog.response(Gtk.ResponseType.CANCEL))
    btn_row.pack_start(cancel_btn, False, False, 0)

    ok_btn = Gtk.Button(label=confirm_label.upper() if is_classic else confirm_label)
    ok_btn.set_relief(Gtk.ReliefStyle.NONE)
    ok_ctx = ok_btn.get_style_context()
    ok_ctx.add_class("desktop-dialog-btn")
    ok_ctx.add_class("is-danger" if danger else "is-primary")
    ok_btn.connect("clicked", lambda _w: dialog.response(Gtk.ResponseType.OK))
    btn_row.pack_start(ok_btn, False, False, 0)

    frame.pack_start(btn_row, False, False, 0)
    content.pack_start(frame, True, True, 0)

    def _on_key(_w, ev):
        if ev.keyval == Gdk.KEY_Escape:
            dialog.response(Gtk.ResponseType.CANCEL)
            return True
        return False

    dialog.connect("key-press-event", _on_key)
    dialog.show_all()
    if entry is not None:
        entry.grab_focus()
        entry.select_region(0, -1)

    response = dialog.run()
    result_text = entry.get_text() if entry is not None else ""
    dialog.destroy()
    if response != Gtk.ResponseType.OK:
        return None
    return result_text if show_entry else True

# Default action mode for each Drag & Drop case between Desktop and Thunar.
# Can be changed via the [Actions] section in the config file - no code
# changes needed. Valid values: copy, link, cut, none.
VALID_ACTION_MODES = ('copy', 'link', 'cut', 'none')
DEFAULT_ACTIONS = {
    'drop_in_folder': 'link',
    'drop_in_file': 'copy',
    'drag_out_file': 'cut',
    'drag_out_folder': 'copy',
}
ACTION_MODES = dict(DEFAULT_ACTIONS)

ACTIONS_CONFIG_BLOCK = """[Actions]
# Drag & Drop behavior between Desktop and Thunar.
# Valid values: copy, link, cut, none
#   copy = duplicate the file/folder
#   link = create a symlink (drop_in_* only)
#   cut  = move it (removes the original after the transfer)
#   none = do nothing / disable this action
#
# drop_in_folder: a FOLDER dragged from Thunar onto the Desktop.
drop_in_folder = link

# drop_in_file: a FILE dragged from Thunar onto the Desktop.
drop_in_file = copy

# drag_out_file: a FILE on the Desktop dragged out to Thunar.
drag_out_file = cut

# drag_out_folder: a FOLDER on the Desktop dragged out to Thunar.
drag_out_folder = copy
"""

DEFAULT_KEYBINDINGS = {
    'copy': '<Ctrl>c',
    'cut': '<Ctrl>x',
    'paste': '<Ctrl>v',
    'duplicate': '<Ctrl>d',
    'trash': 'Delete',
    'delete_permanent': '<Shift>Delete',
    'rename': 'F2',
    'refresh': 'F5',
    'open': 'Return',
    'select_all': '<Ctrl>a'
}
KEYBINDINGS = dict(DEFAULT_KEYBINDINGS)

KEYBINDINGS_CONFIG_BLOCK = """[Keybindings]
# Keyboard shortcuts mapping. Supports <Ctrl>, <Shift>, <Alt> + key
copy = <Ctrl>c
cut = <Ctrl>x
paste = <Ctrl>v
duplicate = <Ctrl>d
trash = Delete
delete_permanent = <Shift>Delete
rename = F2
refresh = F5
open = Return
select_all = <Ctrl>a
"""

SORT_BY = 'name'
SORT_REVERSE = False
FOLDERS_FIRST = True
SHOW_HOME = True
SHOW_TRASH = True
SHOW_COMPUTER = True
USER_DIRS_FIRST = True
SHOW_HIDDEN = False
AUTO_ARRANGE = True
SHOW_DESKTOP_ICONS = True
BLACK_LABELS = False
MONITOR_MODE = 'primary'
GRID_DIRECTION = 'column'
TOP_INSET_AUTO = True
SHOW_PINNED_BADGE = True

VALID_MONITOR_MODES = ('primary', 'all')
VALID_GRID_DIRECTIONS = ('column', 'row')

################################################################################
# CONFIGURATION & UTILITIES
# These functions handle loading/saving configs, positions, and grid math.
################################################################################

def save_setting(key, value):
    try:
        if not os.path.exists(CONF_FILE):
            return
        with open(CONF_FILE, 'r') as f:
            lines = f.readlines()
            
        found = False
        for i, line in enumerate(lines):
            if line.strip().startswith(f"{key} ") or line.strip().startswith(f"{key}="):
                lines[i] = f"{key} = {value}\n"
                found = True
                break
                
        if not found:
            lines.append(f"{key} = {value}\n")
            
        with open(CONF_FILE, 'w') as f:
            f.writelines(lines)
    except Exception as e:
        print(f"Failed to save setting {key}: {e}")

def _read_active_font_size():
    """Return active font size from Classic fonts.css or Hikai quickshell.json."""
    if read_shell_backend() == "classic":
        fonts_path = Path(os.path.expanduser(
            os.environ.get("HAKUSPACE_THEME_FONTS") or "~/.local/state/hakuspace/theme/fonts.css"
        ))
        if fonts_path.is_file():
            try:
                m = re.search(r"font-size\s*:\s*(\d+)\s*px", fonts_path.read_text(encoding="utf-8"))
                if m:
                    return max(8, min(int(m.group(1)), 32))
            except OSError:
                pass
        return 14
    return _load_hikai_theme_tokens()["font_size"]


def compute_cell_dimensions(icon_size=None, font_size=None):
    """Compute grid cell width and height from icon size and active font size."""
    isz = ICON_SIZE if icon_size is None else int(icon_size)
    fsz = _read_active_font_size() if font_size is None else int(font_size)
    width = max(96, isz + max(36, int(round(fsz * 2.2))))
    height = max(96, isz + max(34, int(round(fsz * 2.8)) + 8))
    return width, height


def get_effective_top_inset():
    """Return extra top margin when Classic Cava Underbar occupies the top edge."""
    if not TOP_INSET_AUTO or read_shell_backend() != "classic":
        return 0
    pid_path = Path(os.environ.get("HAKUSPACE_CAVA_PIDFILE") or "/tmp/cava-layer.pid")
    if not pid_path.is_file():
        return 0
    try:
        pid = int(pid_path.read_text(encoding="utf-8").strip())
        os.kill(pid, 0)
    except (OSError, ValueError):
        return 0
    try:
        return max(0, int(os.environ.get("HAKUSPACE_CAVA_HEIGHT") or 80))
    except ValueError:
        return 80


def load_config():
    global ICON_SIZE, CELL_WIDTH, CELL_HEIGHT, ACTION_MODES, KEYBINDINGS
    global SORT_BY, SORT_REVERSE, FOLDERS_FIRST, SHOW_HOME, SHOW_TRASH, SHOW_COMPUTER
    global SHOW_HIDDEN, USER_DIRS_FIRST, AUTO_ARRANGE, SHOW_DESKTOP_ICONS, BLACK_LABELS
    global MONITOR_MODE, GRID_DIRECTION, TOP_INSET_AUTO, SHOW_PINNED_BADGE

    ICON_SIZE = 70
    SORT_BY = 'name'
    SORT_REVERSE = False
    FOLDERS_FIRST = True
    SHOW_HOME = True
    SHOW_TRASH = True
    SHOW_COMPUTER = True
    USER_DIRS_FIRST = True
    SHOW_HIDDEN = False
    AUTO_ARRANGE = True
    SHOW_DESKTOP_ICONS = True
    BLACK_LABELS = False
    MONITOR_MODE = 'primary'
    GRID_DIRECTION = 'column'
    TOP_INSET_AUTO = True
    SHOW_PINNED_BADGE = True
    ACTION_MODES = dict(DEFAULT_ACTIONS)
    KEYBINDINGS = dict(DEFAULT_KEYBINDINGS)

    os.makedirs(CONFIG_DIR, exist_ok=True)
    config = configparser.ConfigParser()

    DEFAULT_SETTINGS_BLOCK = f"""[Settings]
# Desktop icon size
icon_size = {ICON_SIZE}

# Sort icons by: name, date, size, type
sort_by = {SORT_BY}

# Reverse the sorting order (True/False)
sort_reverse = {SORT_REVERSE}

# Show folders before files (True/False)
folders_first = {FOLDERS_FIRST}

# Show special user directories (Downloads, Documents, etc.) before normal folders (True/False)
user_dirs_first = {USER_DIRS_FIRST}

# Show Home icon (True/False)
show_home = {SHOW_HOME}

# Show Trash icon (True/False)
show_trash = {SHOW_TRASH}

# Show Computer/This PC icon (True/False)
show_computer = {SHOW_COMPUTER}

# Show hidden files starting with a dot (True/False)
show_hidden = {SHOW_HIDDEN}

# Auto arrange icons strictly according to sorting criteria, disabling manual positioning
auto_arrange = {AUTO_ARRANGE}

# Show all desktop icons
show_desktop_icons = {SHOW_DESKTOP_ICONS}

# Use black text color for labels
black_labels = {BLACK_LABELS}

# Monitor placement mode: primary or all
monitor_mode = {MONITOR_MODE}

# Grid fill direction: column or row
grid_direction = {GRID_DIRECTION}

# Reserve top space automatically when Classic Cava Underbar is running
top_inset_auto = {TOP_INSET_AUTO}

# Show pinned indicator badge on .desktop shortcuts pinned to AppBar/Dock
show_pinned_badge = {SHOW_PINNED_BADGE}
"""

    if not os.path.exists(CONF_FILE):
        try:
            with open(CONF_FILE, 'w') as configfile:
                configfile.write(DEFAULT_SETTINGS_BLOCK)
                configfile.write("\n")
                configfile.write(ACTIONS_CONFIG_BLOCK)
                configfile.write("\n")
                configfile.write(KEYBINDINGS_CONFIG_BLOCK)
        except OSError as e:
            print(f"Failed to create config file {CONF_FILE}: {e}")
    else:
        try:
            config.read(CONF_FILE)
            append_blocks = []

            if 'Settings' in config:
                s = config['Settings']
                if 'icon_size' in s:
                    ICON_SIZE = max(24, min(int(s['icon_size']), 256))
                if 'sort_by' in s:
                    SORT_BY = s['sort_by'].strip().lower()
                if 'sort_reverse' in s:
                    SORT_REVERSE = s.getboolean('sort_reverse')
                if 'folders_first' in s:
                    FOLDERS_FIRST = s.getboolean('folders_first')
                if 'user_dirs_first' in s:
                    USER_DIRS_FIRST = s.getboolean('user_dirs_first')
                if 'show_home' in s:
                    SHOW_HOME = s.getboolean('show_home')
                if 'show_trash' in s:
                    SHOW_TRASH = s.getboolean('show_trash')
                if 'show_computer' in s:
                    SHOW_COMPUTER = s.getboolean('show_computer')
                if 'show_hidden' in s:
                    SHOW_HIDDEN = s.getboolean('show_hidden')
                if 'auto_arrange' in s:
                    AUTO_ARRANGE = s.getboolean('auto_arrange')
                if 'show_desktop_icons' in s:
                    SHOW_DESKTOP_ICONS = s.getboolean('show_desktop_icons')
                if 'black_labels' in s:
                    BLACK_LABELS = s.getboolean('black_labels')
                if 'monitor_mode' in s:
                    val = s['monitor_mode'].strip().lower()
                    if val in VALID_MONITOR_MODES:
                        MONITOR_MODE = val
                if 'grid_direction' in s:
                    val = s['grid_direction'].strip().lower()
                    if val in VALID_GRID_DIRECTIONS:
                        GRID_DIRECTION = val
                if 'top_inset_auto' in s:
                    TOP_INSET_AUTO = s.getboolean('top_inset_auto')
                if 'show_pinned_badge' in s:
                    SHOW_PINNED_BADGE = s.getboolean('show_pinned_badge')
            else:
                append_blocks.append(DEFAULT_SETTINGS_BLOCK)

            if 'Actions' not in config:
                append_blocks.append(ACTIONS_CONFIG_BLOCK)
            else:
                for key in DEFAULT_ACTIONS:
                    if key in config['Actions']:
                        value = config['Actions'][key].strip().lower()
                        if value in VALID_ACTION_MODES:
                            ACTION_MODES[key] = value
                        else:
                            print(f"Invalid value '{value}' for '{key}' in {CONF_FILE}, "
                                  f"using default '{DEFAULT_ACTIONS[key]}'. "
                                  f"Valid values: {', '.join(VALID_ACTION_MODES)}")

            if 'Keybindings' not in config:
                append_blocks.append(KEYBINDINGS_CONFIG_BLOCK)
            else:
                for key in DEFAULT_KEYBINDINGS:
                    if key in config['Keybindings']:
                        KEYBINDINGS[key] = config['Keybindings'][key].strip()

            if append_blocks:
                try:
                    with open(CONF_FILE, 'a') as configfile:
                        for block in append_blocks:
                            configfile.write("\n" + block)
                except OSError as e:
                    print(f"Failed to upgrade config file {CONF_FILE}: {e}")
        except (ValueError, configparser.Error) as e:
            print(f"Failed to parse {CONF_FILE}, using defaults: {e}")

    CELL_WIDTH, CELL_HEIGHT = compute_cell_dimensions()

load_config()

def load_positions():
    """Read persistent layout after preserving any legacy cached positions."""
    migrate_cached_state()
    if not os.path.exists(POSITIONS_FILE):
        return {}
    try:
        with open(POSITIONS_FILE, "r") as positions_file:
            return json.load(positions_file)
    except (OSError, ValueError) as error:
        print(f"Failed to load positions from {POSITIONS_FILE}: {error}")
        return {}

def save_positions(positions):
    os.makedirs(os.path.dirname(POSITIONS_FILE), exist_ok=True)
    with open(POSITIONS_FILE, "w") as positions_file:
        json.dump(positions, positions_file, indent=4)


def get_monitor_key(monitor):
    """Return a stable connector/model identifier for a Gdk.Monitor."""
    if monitor is None:
        return "default"
    connector = monitor.get_connector() if hasattr(monitor, "get_connector") else None
    if connector:
        return str(connector)
    model = monitor.get_model() if hasattr(monitor, "get_model") else None
    if model:
        return str(model)
    return "default"


def select_active_monitors(display, mode=None):
    """Return the list of monitors that should host desktop icon windows."""
    if display is None:
        return []
    m = mode or MONITOR_MODE
    n = display.get_n_monitors()
    if n <= 0:
        return []
    if m == 'all':
        return [display.get_monitor(i) for i in range(n) if display.get_monitor(i) is not None]
    primary = display.get_primary_monitor() if hasattr(display, "get_primary_monitor") else None
    if primary is not None:
        return [primary]
    first = display.get_monitor(0)
    return [first] if first is not None else []


def extract_monitor_positions(raw_data, monitor_key):
    """Extract {filename: {'col': int, 'row': int}} from v1 or v2 positions data."""
    if not isinstance(raw_data, dict):
        return {}
    if raw_data.get("version") == 2 and isinstance(raw_data.get("monitors"), dict):
        source = raw_data["monitors"].get(monitor_key, {})
    else:
        source = raw_data
    if not isinstance(source, dict):
        return {}
    cleaned = {}
    for key, pos in source.items():
        if key and isinstance(pos, dict) and isinstance(pos.get("col"), int) and isinstance(pos.get("row"), int):
            cleaned[key] = {"col": max(0, pos["col"]), "row": max(0, pos["row"])}
    return cleaned


def merge_monitor_positions(raw_data, monitor_key, monitor_map):
    """Merge a monitor's saved icon coordinates into schema v2 positions payload."""
    monitors = {}
    if isinstance(raw_data, dict) and raw_data.get("version") == 2 and isinstance(raw_data.get("monitors"), dict):
        for k, v in raw_data["monitors"].items():
            if isinstance(v, dict):
                monitors[k] = dict(v)
    monitors[monitor_key] = dict(monitor_map)
    return {"version": 2, "monitors": monitors}


def get_grid_pos(x, y, top_margin=0):
    col = max(0, int((x - PADDING) / (CELL_WIDTH + PADDING)))
    row = max(0, int((y - PADDING - top_margin) / (CELL_HEIGHT + PADDING)))
    return col, row


def iter_grid_cells(cols, rows, direction='column'):
    """Yield (col, row) coordinates in column-major or row-major order."""
    if direction == 'row':
        for r in range(rows):
            for c in range(cols):
                yield c, r
    else:
        for c in range(cols):
            for r in range(rows):
                yield c, r


def find_nearest_free_cell(start_col, start_row, cols, rows, occupied, direction='column'):
    """Return the closest unoccupied grid cell to (start_col, start_row)."""
    sc = min(max(0, start_col), cols - 1)
    sr = min(max(0, start_row), rows - 1)
    if (sc, sr) not in occupied:
        return sc, sr
    best = None
    best_score = None
    for c, r in iter_grid_cells(cols, rows, direction):
        if (c, r) in occupied:
            continue
        dist = abs(c - sc) + abs(r - sr)
        tie = (r, c) if direction == 'row' else (c, r)
        score = (dist, tie)
        if best_score is None or score < best_score:
            best_score = score
            best = (c, r)
    return best if best is not None else (sc, sr)


SPECIAL_KEYS = ("home", "computer", "trash")


def get_special_cell_slots(cols, rows, direction='column'):
    """Return (slot_map, reserved_cells) locking the first 3 cells to Home, This PC, Trash."""
    cells = []
    for cell in iter_grid_cells(cols, rows, direction):
        cells.append(cell)
        if len(cells) >= len(SPECIAL_KEYS):
            break
    slot_map = {key: cells[idx] for idx, key in enumerate(SPECIAL_KEYS) if idx < len(cells)}
    return slot_map, set(slot_map.values())


def _take_next_sequential_cell(cell_iter, occupied, cols, rows):
    """Consume iter_grid_cells iterator for the next unoccupied cell in fill order."""
    for cell in cell_iter:
        if cell not in occupied:
            occupied.add(cell)
            return cell
    fallback = (max(0, cols - 1), max(0, rows - 1))
    occupied.add(fallback)
    return fallback


def compute_auto_grid_positions(keys, cols, rows, direction='column', reserve_special=False):
    """Assign dynamic auto-arrange coordinates without persisting to positions.json."""
    if not reserve_special:
        result = {}
        for index, key in enumerate(keys):
            if direction == 'row':
                c = index % cols
                r = index // cols
            else:
                c = index // rows
                r = index % rows
            result[key] = (min(c, cols - 1), min(r, rows - 1))
        return result

    slot_map, reserved_cells = get_special_cell_slots(cols, rows, direction)
    result = {}
    occupied = set(reserved_cells)
    for key in keys:
        if key in slot_map:
            result[key] = slot_map[key]
    cell_iter = iter_grid_cells(cols, rows, direction)
    for key in keys:
        if key in slot_map:
            continue
        result[key] = _take_next_sequential_cell(cell_iter, occupied, cols, rows)
    return result


def compute_manual_grid_layout(virtual_keys, normal_keys, saved_map, cols, rows, direction='column'):
    """Lock the first 3 grid cells exclusively to virtual special dirs and preserve saved normal positions."""
    slot_map, reserved_cells = get_special_cell_slots(cols, rows, direction)
    occupied = set(reserved_cells)
    placements = {}
    new_entries = {}
    cell_iter = iter_grid_cells(cols, rows, direction)

    for key in virtual_keys:
        if key in slot_map:
            placements[key] = slot_map[key]
        else:
            placements[key] = _take_next_sequential_cell(cell_iter, occupied, cols, rows)

    for key in normal_keys:
        if key not in saved_map:
            continue
        sc = saved_map[key]["col"]
        sr = saved_map[key]["row"]
        eff_c, eff_r = find_nearest_free_cell(sc, sr, cols, rows, occupied, direction)
        occupied.add((eff_c, eff_r))
        placements[key] = (eff_c, eff_r)

    for key in normal_keys:
        if key in placements:
            continue
        c, r = _take_next_sequential_cell(cell_iter, occupied, cols, rows)
        placements[key] = (c, r)
        new_entries[key] = {"col": c, "row": r}

    return placements, new_entries


def resolve_internal_drop(saved_map, dragged_keys, origin_key, target_col, target_row, cols, rows, direction='column', current_effective=None, reserved_cells=None):
    """Update saved_map for internal drag-and-drop while keeping reserved special cells fixed."""
    updated = {k: dict(v) for k, v in saved_map.items()}
    tc = min(max(0, target_col), cols - 1)
    tr = min(max(0, target_row), rows - 1)
    eff = current_effective or {}
    reserved = set(reserved_cells or ())

    movable_keys = [k for k in dragged_keys if k not in SPECIAL_KEYS]
    if not movable_keys:
        return updated

    if len(movable_keys) == 1:
        key = movable_keys[0]
        if (tc, tr) in reserved:
            return updated
        old_pos = updated.get(key)
        if old_pos is None and key in eff:
            old_pos = {"col": eff[key][0], "row": eff[key][1]}

        occupant = None
        if eff:
            for other_key, (oc, orow) in eff.items():
                if other_key == key or other_key in SPECIAL_KEYS:
                    continue
                if min(max(0, oc), cols - 1) == tc and min(max(0, orow), rows - 1) == tr:
                    occupant = other_key
                    break
        else:
            for other_key in updated.keys():
                if other_key == key or other_key in SPECIAL_KEYS:
                    continue
                pos = updated[other_key]
                oc, orow = pos["col"], pos["row"]
                if min(max(0, oc), cols - 1) == tc and min(max(0, orow), rows - 1) == tr:
                    occupant = other_key
                    break

        updated[key] = {"col": tc, "row": tr}
        if occupant is not None:
            if (
                old_pos is not None
                and (old_pos["col"], old_pos["row"]) != (tc, tr)
                and (min(max(0, old_pos["col"]), cols - 1), min(max(0, old_pos["row"]), rows - 1)) not in reserved
            ):
                updated[occupant] = {"col": old_pos["col"], "row": old_pos["row"]}
            else:
                occupied = set(reserved)
                for k, v in updated.items():
                    if k != occupant and k not in SPECIAL_KEYS:
                        occupied.add((min(max(0, v["col"]), cols - 1), min(max(0, v["row"]), rows - 1)))
                nc, nr = find_nearest_free_cell(tc, tr, cols, rows, occupied, direction)
                updated[occupant] = {"col": nc, "row": nr}
        if eff:
            for stale_key, pos in list(updated.items()):
                if stale_key == key or stale_key in eff or stale_key in SPECIAL_KEYS:
                    continue
                if min(max(0, pos["col"]), cols - 1) == tc and min(max(0, pos["row"]), rows - 1) == tr:
                    occupied = set(reserved)
                    for k, v in updated.items():
                        if k != stale_key and k not in SPECIAL_KEYS:
                            occupied.add((min(max(0, v["col"]), cols - 1), min(max(0, v["row"]), rows - 1)))
                    nc, nr = find_nearest_free_cell(tc, tr, cols, rows, occupied, direction)
                    updated[stale_key] = {"col": nc, "row": nr}
        return updated

    dragged_set = set(movable_keys)
    origin_pos = updated.get(origin_key)
    if origin_pos is None and origin_key in eff:
        origin_pos = {"col": eff[origin_key][0], "row": eff[origin_key][1]}
    if origin_pos is None:
        origin_pos = {"col": tc, "row": tr}

    occupied = set(reserved)
    for k, v in updated.items():
        if k not in dragged_set and k not in SPECIAL_KEYS:
            occupied.add((min(max(0, v["col"]), cols - 1), min(max(0, v["row"]), rows - 1)))
    for k, pos_tuple in eff.items():
        if k not in dragged_set and k not in updated:
            occupied.add(pos_tuple)

    for key in movable_keys:
        pos = updated.get(key)
        if pos is None and key in eff:
            pos = {"col": eff[key][0], "row": eff[key][1]}
        if pos is None:
            pos = origin_pos
        dc = tc + (pos["col"] - origin_pos["col"])
        dr = tr + (pos["row"] - origin_pos["row"])
        fc, fr = find_nearest_free_cell(dc, dr, cols, rows, occupied, direction)
        occupied.add((fc, fr))
        updated[key] = {"col": fc, "row": fr}

    return updated


################################################################################
# FILE OPERATIONS & WAYLAND CLIPBOARD
# Handles copying, pasting, cutting, and dragging files.
################################################################################

def resolve_external_drop_mode(source_path, is_folder, action_modes=None):
    """Determine external drop action mode, forcing copy instead of cut for .desktop launchers."""
    modes = ACTION_MODES if action_modes is None else action_modes
    action_key = 'drop_in_folder' if is_folder else 'drop_in_file'
    mode = modes.get(action_key, DEFAULT_ACTIONS[action_key])
    if not is_folder and source_path.endswith(".desktop") and mode == 'cut':
        return action_key, 'copy'
    return action_key, mode


def _trust_desktop_shortcut(dest_path):
    """Mark a copied .desktop shortcut executable and trusted via GIO metadata."""
    if not dest_path.endswith(".desktop") or os.path.isdir(dest_path):
        return
    try:
        current = os.stat(dest_path).st_mode
        os.chmod(dest_path, current | 0o111)
    except OSError:
        pass
    try:
        gfile = Gio.File.new_for_path(dest_path)
        gfile.set_attribute_string("metadata::trusted", "true", Gio.FileQueryInfoFlags.NONE, None)
    except GLib.Error:
        pass


def apply_drop_in_action(mode, source_path, dest_path):
    if mode == 'none':
        return False
    try:
        if mode == 'link':
            os.symlink(source_path, dest_path)
        elif mode == 'cut':
            shutil.move(source_path, dest_path)
        else:
            if os.path.isdir(source_path):
                shutil.copytree(source_path, dest_path)
            else:
                shutil.copy2(source_path, dest_path)
    except Exception as e:
        print(f"apply_drop_in_action('{mode}') failed for {source_path}: {e}")
        return False
    return os.path.exists(dest_path) or os.path.islink(dest_path)

_THUMB_EXECUTOR = concurrent.futures.ThreadPoolExecutor(max_workers=3, thread_name_prefix="desktop-thumb")
_IO_EXECUTOR = concurrent.futures.ThreadPoolExecutor(max_workers=2, thread_name_prefix="desktop-io")


def _unique_dest_path(dest_dir, basename):
    """Return a non-colliding destination path inside dest_dir."""
    candidate = os.path.join(dest_dir, basename)
    if not os.path.exists(candidate) and not os.path.islink(candidate):
        return candidate
    if os.path.isdir(candidate):
        stem, ext = basename, ""
    else:
        stem, ext = os.path.splitext(basename)
    counter = 1
    while True:
        suffix = " (copy)" if counter == 1 else f" (copy {counter})"
        alt = os.path.join(dest_dir, f"{stem}{suffix}{ext}")
        if not os.path.exists(alt) and not os.path.islink(alt):
            return alt
        counter += 1


def _transfer_paths_sync(desktop_dir, paths, action):
    """Copy or move clipboard paths into desktop_dir on a worker thread."""
    for item in paths:
        source_path = ""
        if item.startswith("file://"):
            source_path = urllib.parse.unquote(item[7:])
        elif item.startswith("/"):
            source_path = item
        else:
            continue

        if not source_path or not os.path.exists(source_path):
            continue

        basename = os.path.basename(source_path.rstrip("/")) or os.path.basename(source_path)
        if not basename:
            continue

        dest_path = os.path.join(desktop_dir, basename)
        if action == "cut":
            if os.path.abspath(source_path) == os.path.abspath(dest_path):
                continue
            if os.path.exists(dest_path) or os.path.islink(dest_path):
                dest_path = _unique_dest_path(desktop_dir, basename)
        else:
            if os.path.exists(dest_path) or os.path.islink(dest_path):
                dest_path = _unique_dest_path(desktop_dir, basename)

        try:
            if action == "cut":
                shutil.move(source_path, dest_path)
            else:
                if os.path.isdir(source_path):
                    shutil.copytree(source_path, dest_path)
                else:
                    shutil.copy2(source_path, dest_path)
        except Exception as e:
            print(f"Error pasting {source_path}: {e}")


def _duplicate_paths_sync(desktop_dir, paths):
    """Duplicate non-virtual paths inside desktop_dir with collision-safe names."""
    for source_path in paths:
        if not source_path or not (os.path.exists(source_path) or os.path.islink(source_path)):
            continue
        basename = os.path.basename(source_path.rstrip("/")) or os.path.basename(source_path)
        if not basename:
            continue
        dest_path = _unique_dest_path(desktop_dir, basename)
        try:
            if os.path.islink(source_path):
                os.symlink(os.readlink(source_path), dest_path)
            elif os.path.isdir(source_path):
                shutil.copytree(source_path, dest_path, symlinks=True)
            else:
                shutil.copy2(source_path, dest_path)
        except Exception as e:
            print(f"Error duplicating {source_path}: {e}")


def _delete_paths_sync(paths):
    """Permanently delete files, symlinks, or directories on a worker thread."""
    for target in paths:
        if not target:
            continue
        try:
            if os.path.islink(target) or os.path.isfile(target):
                os.unlink(target)
            elif os.path.isdir(target):
                shutil.rmtree(target)
        except Exception as e:
            print(f"Error permanently deleting {target}: {e}")


class ThumbnailService:
    """Shared bounded thumbnail loader and D-Bus Thumbnailer1 coordinator."""

    THUMB_DIRS = (
        ('large', os.path.expanduser('~/.cache/thumbnails/large')),
        ('normal', os.path.expanduser('~/.cache/thumbnails/normal')),
        ('large', os.path.expanduser('~/.thumbnails/large')),
        ('normal', os.path.expanduser('~/.thumbnails/normal')),
    )

    def __init__(self):
        self._pending = {}
        self._poll_timer_id = 0
        self._poll_attempts = 0
        self._dbus_conn = None
        self._sub_ready_id = 0
        self._sub_error_id = 0
        self._init_dbus_signals()

    def _init_dbus_signals(self):
        try:
            self._dbus_conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            self._sub_ready_id = self._dbus_conn.signal_subscribe(
                "org.freedesktop.thumbnails.Thumbnailer1",
                "org.freedesktop.thumbnails.Thumbnailer1",
                "Ready",
                "/org/freedesktop/thumbnails/Thumbnailer1",
                None,
                Gio.DBusSignalFlags.NONE,
                self._on_thumbnail_ready,
            )
            self._sub_error_id = self._dbus_conn.signal_subscribe(
                "org.freedesktop.thumbnails.Thumbnailer1",
                "org.freedesktop.thumbnails.Thumbnailer1",
                "Error",
                "/org/freedesktop/thumbnails/Thumbnailer1",
                None,
                Gio.DBusSignalFlags.NONE,
                self._on_thumbnail_error,
            )
        except Exception:
            self._dbus_conn = None

    def _on_thumbnail_ready(self, conn, sender, path, iface, signal_name, params):
        try:
            _, uris = params.unpack()
        except Exception:
            return
        for uri in uris:
            refs = self._pending.pop(uri, None)
            if not refs:
                continue
            for ref in refs:
                icon = ref()
                if icon is not None and not icon._destroyed:
                    self._load_cached_only(icon)
        if not self._pending and self._poll_timer_id:
            GLib.source_remove(self._poll_timer_id)
            self._poll_timer_id = 0

    def _on_thumbnail_error(self, conn, sender, path, iface, signal_name, params):
        try:
            _, failed_uris, _, _ = params.unpack()
        except Exception:
            return
        for uri in failed_uris:
            self._pending.pop(uri, None)
        if not self._pending and self._poll_timer_id:
            GLib.source_remove(self._poll_timer_id)
            self._poll_timer_id = 0

    @classmethod
    def _find_cached_pixbuf(cls, gio_file, gio_info, icon_size, allow_direct_image=True):
        files = [gio_file]
        file_path = gio_file.get_path()
        if file_path and os.path.islink(file_path):
            files.append(Gio.File.new_for_path(os.path.realpath(file_path)))

        for thumbnail_file in files:
            try:
                info_thumb = thumbnail_file.query_info(
                    "thumbnail::path,thumbnail::is-valid",
                    Gio.FileQueryInfoFlags.NONE,
                    None,
                )
                if info_thumb.has_attribute("thumbnail::path"):
                    is_valid = (
                        not info_thumb.has_attribute("thumbnail::is-valid")
                        or info_thumb.get_attribute_boolean("thumbnail::is-valid")
                    )
                    if is_valid:
                        thumb_path = info_thumb.get_attribute_byte_string("thumbnail::path")
                        if isinstance(thumb_path, bytes):
                            thumb_path = thumb_path.decode("utf-8")
                        if thumb_path and os.path.exists(thumb_path):
                            return GdkPixbuf.Pixbuf.new_from_file_at_scale(
                                thumb_path, icon_size, icon_size, True
                            )
            except Exception:
                pass

        for thumbnail_file in files:
            uri = thumbnail_file.get_uri()
            uri_md5 = hashlib.md5(uri.encode('utf-8')).hexdigest()
            for _, base_dir in cls.THUMB_DIRS:
                thumb_path = os.path.join(base_dir, f'{uri_md5}.png')
                if os.path.exists(thumb_path):
                    try:
                        return GdkPixbuf.Pixbuf.new_from_file_at_scale(
                            thumb_path, icon_size, icon_size, True
                        )
                    except Exception:
                        pass

        if allow_direct_image and file_path:
            try:
                content_type = gio_info.get_content_type()
                if content_type and content_type.startswith("image/"):
                    return GdkPixbuf.Pixbuf.new_from_file_at_scale(
                        file_path, icon_size, icon_size, True
                    )
            except Exception:
                pass
        return None

    def _load_cached_only(self, icon):
        icon_ref = weakref.ref(icon)
        gio_file = icon.gio_file
        gio_info = icon.gio_info
        icon_size = ICON_SIZE

        def _worker():
            pixbuf = self._find_cached_pixbuf(gio_file, gio_info, icon_size, allow_direct_image=False)
            if pixbuf is not None:
                GLib.idle_add(self._apply_to_ref, icon_ref, pixbuf)

        _THUMB_EXECUTOR.submit(_worker)

    @staticmethod
    def _apply_to_ref(icon_ref, pixbuf):
        icon = icon_ref()
        if icon is not None and not icon._destroyed:
            icon.apply_thumbnail_pixbuf(pixbuf)
        return GLib.SOURCE_REMOVE

    def request(self, icon):
        icon_ref = weakref.ref(icon)
        gio_file = icon.gio_file
        gio_info = icon.gio_info
        icon_size = ICON_SIZE
        is_dir = icon.is_dir_icon
        uri = gio_file.get_uri()

        def _worker():
            pixbuf = self._find_cached_pixbuf(gio_file, gio_info, icon_size, allow_direct_image=True)
            if pixbuf is not None:
                GLib.idle_add(self._apply_to_ref, icon_ref, pixbuf)
                return
            if is_dir or uri.startswith("virtual://"):
                return
            mime_type = gio_info.get_content_type()
            if mime_type and (
                mime_type.startswith("image/")
                or mime_type.startswith("video/")
                or mime_type == "application/pdf"
            ):
                GLib.idle_add(self._queue_dbus_thumbnail, icon_ref, uri, mime_type)

        _THUMB_EXECUTOR.submit(_worker)

    def _queue_dbus_thumbnail(self, icon_ref, uri, mime_type):
        icon = icon_ref()
        if icon is None or icon._destroyed or icon._dbus_thumbnail_requested:
            return GLib.SOURCE_REMOVE
        icon._dbus_thumbnail_requested = True
        self._pending.setdefault(uri, set()).add(icon_ref)

        def _dbus_call():
            try:
                bus = self._dbus_conn or Gio.bus_get_sync(Gio.BusType.SESSION, None)
                proxy = Gio.DBusProxy.new_sync(
                    bus, Gio.DBusProxyFlags.NONE, None,
                    "org.freedesktop.thumbnails.Thumbnailer1",
                    "/org/freedesktop/thumbnails/Thumbnailer1",
                    "org.freedesktop.thumbnails.Thumbnailer1",
                    None,
                )
                proxy.call_sync(
                    "Queue",
                    GLib.Variant("(asasssu)", ([uri], [mime_type], "normal", "default", 0)),
                    Gio.DBusCallFlags.NONE,
                    -1,
                    None,
                )
            except Exception:
                pass

        _THUMB_EXECUTOR.submit(_dbus_call)
        self._poll_attempts = 0
        if not self._poll_timer_id:
            self._poll_timer_id = GLib.timeout_add(1500, self._fallback_poll_tick)
        return GLib.SOURCE_REMOVE

    def _fallback_poll_tick(self):
        self._poll_attempts += 1
        # Prune destroyed icons and icons that already resolved.
        for uri in list(self._pending.keys()):
            alive = {
                ref for ref in self._pending[uri]
                if (obj := ref()) is not None and not obj._destroyed and not obj.has_thumbnail
            }
            if alive:
                self._pending[uri] = alive
            else:
                self._pending.pop(uri, None)

        if not self._pending or self._poll_attempts > 6:
            self._poll_timer_id = 0
            return GLib.SOURCE_REMOVE

        for refs in list(self._pending.values()):
            for ref in list(refs):
                icon = ref()
                if icon is not None and not icon._destroyed and not icon.has_thumbnail:
                    self._load_cached_only(icon)
        return GLib.SOURCE_CONTINUE

    def shutdown(self):
        if self._poll_timer_id:
            GLib.source_remove(self._poll_timer_id)
            self._poll_timer_id = 0
        if self._dbus_conn is not None:
            for sub_id in (self._sub_ready_id, self._sub_error_id):
                if sub_id:
                    try:
                        self._dbus_conn.signal_unsubscribe(sub_id)
                    except Exception:
                        pass
            self._sub_ready_id = 0
            self._sub_error_id = 0
        self._pending.clear()


_THUMBNAIL_SERVICE = None


def get_thumbnail_service():
    global _THUMBNAIL_SERVICE
    if _THUMBNAIL_SERVICE is None:
        _THUMBNAIL_SERVICE = ThumbnailService()
    return _THUMBNAIL_SERVICE


def wl_copy_files(uris, action):
    payload = (action + "\n" + "\n".join(uris)).encode("utf-8")
    try:
        proc = Gio.Subprocess.new(
            ["wl-copy", "--type", "x-special/gnome-copied-files"],
            Gio.SubprocessFlags.STDIN_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
        )
    except GLib.Error as e:
        print(f"Cannot run 'wl-copy': {e}")
        return False

    def _on_done(subproc, result):
        try:
            ok, _, stderr = subproc.communicate_finish(result)
            if not subproc.get_successful() and stderr:
                err = stderr.get_data()
                if err:
                    print(f"Error copying to wl-clipboard: {err.decode('utf-8', errors='ignore').strip()}")
        except GLib.Error as e:
            print(f"Error copying to wl-clipboard: {e}")

    proc.communicate_async(GLib.Bytes.new(payload), None, _on_done)
    return True



################################################################################
# THUNAR CUSTOM ACTIONS INTEGRATION
# Parses and executes custom actions defined in Thunar (uca.xml).
################################################################################

def get_thunar_uca_path():
    config_home = os.environ.get("XDG_CONFIG_HOME")
    if config_home:
        p = os.path.join(config_home, "Thunar", "uca.xml")
        if os.path.exists(p):
            return p
    user_p = os.path.expanduser("~/.config/Thunar/uca.xml")
    if os.path.exists(user_p):
        return user_p
    sys_p = "/etc/xdg/Thunar/uca.xml"
    if os.path.exists(sys_p):
        return sys_p
    return None

def load_thunar_custom_actions():
    uca_path = get_thunar_uca_path()
    if not uca_path or not os.path.exists(uca_path):
        return []

    try:
        tree = ET.parse(uca_path)
        root = tree.getroot()
    except Exception as e:
        print(f"Failed to parse Thunar uca.xml: {e}")
        return []

    actions = []
    for act in root.findall("action"):
        name = (act.findtext("name") or "").strip()
        cmd = (act.findtext("command") or "").strip()
        if not name or not cmd:
            continue

        icon = (act.findtext("icon") or "").strip()
        submenu = (act.findtext("submenu") or "").strip()
        description = (act.findtext("description") or "").strip()
        patterns_str = (act.findtext("patterns") or "*").strip()
        range_str = (act.findtext("range") or "").strip()

        has_directories = act.find("directories") is not None
        has_audio = act.find("audio-files") is not None
        has_image = act.find("image-files") is not None
        has_text = act.find("text-files") is not None
        has_video = act.find("video-files") is not None
        has_other = act.find("other-files") is not None

        patterns = [p.strip() for p in patterns_str.split(";") if p.strip()] or ["*"]

        actions.append({
            "name": name,
            "command": cmd,
            "icon": icon,
            "submenu": submenu,
            "description": description,
            "patterns": patterns,
            "range": range_str,
            "directories": has_directories,
            "audio": has_audio,
            "image": has_image,
            "text": has_text,
            "video": has_video,
            "other": has_other,
        })
    return actions

def action_matches_target(action, paths, is_directory_background=False):
    count = len(paths)
    if count == 0:
        return False

    rng = action.get("range", "")
    if rng and rng != "*":
        if rng == "1" and count != 1:
            return False
        elif rng in (">1", "1+") and count <= 1:
            return False
        elif rng == "0..1" and count > 1:
            return False

    if is_directory_background:
        if not action.get("directories", False):
            return False
        dir_name = os.path.basename(paths[0])
        return any(fnmatch.fnmatch(dir_name, p) or p == "*" for p in action.get("patterns", ["*"]))

    for p in paths:
        fname = os.path.basename(p)
        if not any(fnmatch.fnmatch(fname, pat) for pat in action.get("patterns", ["*"])):
            return False

        if os.path.isdir(p):
            if not action.get("directories", False):
                return False
        else:
            matched_type = False
            mime, _ = mimetypes.guess_type(p)
            if not mime:
                try:
                    mime = Gio.content_type_guess(p)[0] or ""
                except Exception:
                    mime = ""

            if mime.startswith("audio/") and action.get("audio", False):
                matched_type = True
            elif mime.startswith("image/") and action.get("image", False):
                matched_type = True
            elif mime.startswith("video/") and action.get("video", False):
                matched_type = True
            elif (mime.startswith("text/") or any(k in mime for k in ("script", "json", "xml", "javascript", "x-yaml", "x-sh"))) and action.get("text", False):
                matched_type = True
            elif action.get("other", False):
                matched_type = True

            if not matched_type:
                return False

    return True

def expand_thunar_command(cmd_template, paths, is_directory_background=False):
    if not paths:
        return cmd_template

    f_val = shlex.quote(paths[0])
    F_val = " ".join(shlex.quote(p) for p in paths)

    uris = [Gio.File.new_for_path(p).get_uri() for p in paths]
    u_val = shlex.quote(uris[0])
    U_val = " ".join(shlex.quote(u) for u in uris)

    n_val = shlex.quote(os.path.basename(paths[0]))
    N_val = " ".join(shlex.quote(os.path.basename(p)) for p in paths)

    if is_directory_background:
        d_val = shlex.quote(paths[0])
        D_val = " ".join(shlex.quote(paths[0]) for _ in paths)
    else:
        d_val = shlex.quote(os.path.dirname(paths[0]))
        D_val = " ".join(shlex.quote(os.path.dirname(p)) for p in paths)

    result = cmd_template.replace("%%", "\x00PERCENT\x00")
    result = result.replace("%F", F_val)
    result = result.replace("%f", f_val)
    result = result.replace("%U", U_val)
    result = result.replace("%u", u_val)
    result = result.replace("%D", D_val)
    result = result.replace("%d", d_val)
    result = result.replace("%N", N_val)
    result = result.replace("%n", n_val)
    result = result.replace("\x00PERCENT\x00", "%")

    return result

def spawn_detached(argv, cwd=None, delay_ms=0):
    """Launch an external command double-forked via GLib so no zombie processes remain."""
    cmd = [str(a) for a in argv]
    work_dir = cwd or GLib.get_home_dir()

    def _run():
        try:
            GLib.spawn_async(
                cmd,
                working_directory=work_dir,
                flags=GLib.SpawnFlags.SEARCH_PATH,
            )
        except GLib.Error as err:
            print(f"[desktop-icons] Failed to spawn {cmd}: {err}", file=sys.stderr)
        return GLib.SOURCE_REMOVE

    if delay_ms > 0:
        GLib.timeout_add(delay_ms, _run)
    else:
        GLib.idle_add(_run)


def execute_thunar_action(cmd_template, paths, cwd=None, is_directory_background=False):
    cmd = expand_thunar_command(cmd_template, paths, is_directory_background)
    spawn_detached(["sh", "-c", cmd], cwd=cwd, delay_ms=40)

def build_thunar_menu_item(action, paths, is_directory_background=False, fallback_cwd=None):
    item = Gtk.MenuItem()
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

    icon_name = action.get("icon")
    if icon_name:
        if os.path.isabs(icon_name) and os.path.exists(icon_name):
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(icon_name, 16, 16, True)
                img = Gtk.Image.new_from_pixbuf(pixbuf)
                box.pack_start(img, False, False, 0)
            except Exception:
                pass
        else:
            theme = Gtk.IconTheme.get_default()
            if theme.has_icon(icon_name):
                img = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
                box.pack_start(img, False, False, 0)

    label = Gtk.Label(label=action.get("name", ""))
    box.pack_start(label, False, False, 0)
    item.add(box)

    desc = action.get("description")
    if desc:
        item.set_tooltip_text(desc)

    cwd = fallback_cwd
    if is_directory_background:
        cwd = paths[0]
    elif paths:
        cwd = paths[0] if os.path.isdir(paths[0]) else os.path.dirname(paths[0])

    item.connect("activate", lambda w, a=action: execute_thunar_action(
        a["command"], paths, cwd=cwd, is_directory_background=is_directory_background
    ))
    return item

def populate_thunar_actions_menu(menu, paths, is_directory_background=False, fallback_cwd=None):
    actions = load_thunar_custom_actions()
    matching = [
        act for act in actions
        if action_matches_target(act, paths, is_directory_background=is_directory_background)
    ]
    if not matching:
        return 0

    submenus = {}
    for act in matching:
        item = build_thunar_menu_item(act, paths, is_directory_background, fallback_cwd)
        sub_name = act.get("submenu")
        if sub_name:
            if sub_name not in submenus:
                sub_menu_widget = Gtk.Menu()
                sub_menu_widget.get_style_context().add_class('desktop-context-menu')
                sub_item = Gtk.MenuItem(label=sub_name)
                sub_item.set_submenu(sub_menu_widget)
                menu.append(sub_item)
                submenus[sub_name] = sub_menu_widget
            submenus[sub_name].append(item)
        else:
            menu.append(item)
    return len(matching)


################################################################################
# UI COMPONENT: DESKTOP ICON
# Represents a single icon on the desktop grid.
################################################################################

class DesktopIcon(Gtk.EventBox):
    def __init__(self, gio_file, gio_info):
        super().__init__()
        self.gio_file = gio_file
        self.gio_info = gio_info
        
        self.set_visible_window(True)
        self.get_style_context().add_class('desktop-icon')
        self.is_hovered = False
        self.is_selected = False
        self._destroyed = False
        self.connect("destroy", self._on_destroy)
        
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.add(vbox)
        
        name = gio_info.get_display_name()
        raw_name = gio_info.get_name() or ""
        is_hidden = bool(gio_info and gio_info.has_attribute("standard::is-hidden") and gio_info.get_is_hidden())
        if raw_name.startswith('.') or is_hidden:
            self.set_opacity(0.6)
            
        gicon = gio_info.get_icon()
        self.is_desktop_file = name.endswith('.desktop')
        self.app_info = None

        file_path = self.gio_file.get_path()
        self.is_dir_icon = bool(file_path and os.path.isdir(file_path))
        if gio_info and gio_info.get_file_type() == Gio.FileType.SHORTCUT:
            self.is_dir_icon = True

        self.is_user_dir = False
        if self.is_dir_icon:
            dir_map = {
                GLib.UserDirectory.DIRECTORY_DOWNLOAD: 'folder-download',
                GLib.UserDirectory.DIRECTORY_DOCUMENTS: 'folder-documents',
                GLib.UserDirectory.DIRECTORY_PICTURES: 'folder-pictures',
                GLib.UserDirectory.DIRECTORY_MUSIC: 'folder-music',
                GLib.UserDirectory.DIRECTORY_VIDEOS: 'folder-videos',
                GLib.UserDirectory.DIRECTORY_TEMPLATES: 'folder-templates',
                GLib.UserDirectory.DIRECTORY_PUBLIC_SHARE: 'folder-publicshare',
            }
            real_path = os.path.realpath(file_path) if file_path else ""
            found_special = False
            for glib_dir, icon_name in dir_map.items():
                target_path = GLib.get_user_special_dir(glib_dir)
                if target_path and real_path == os.path.realpath(target_path):
                    gicon = Gio.ThemedIcon.new_from_names([icon_name, 'folder'])
                    found_special = True
                    self.is_user_dir = True
                    break
                    
            if not found_special:
                name_lower = name.lower()
                heuristics = {
                    'downloads': 'folder-download', 'tải về': 'folder-download',
                    'documents': 'folder-documents', 'tài liệu': 'folder-documents',
                    'pictures': 'folder-pictures', 'hình ảnh': 'folder-pictures',
                    'music': 'folder-music', 'âm nhạc': 'folder-music', 'nhạc': 'folder-music',
                    'videos': 'folder-videos', 'video': 'folder-videos',
                    'templates': 'folder-templates', 'mẫu': 'folder-templates',
                    'public': 'folder-publicshare', 'công khai': 'folder-publicshare',
                }
                if name_lower in heuristics:
                    gicon = Gio.ThemedIcon.new_from_names([heuristics[name_lower], 'folder'])
                    self.is_user_dir = True

        if self.is_desktop_file:
            if HAS_GIO_UNIX:
                self.app_info = GioUnix.DesktopAppInfo.new_from_filename(file_path)
            else:
                self.app_info = Gio.DesktopAppInfo.new_from_filename(file_path)
                
            if self.app_info:
                name = self.app_info.get_name()
                gicon = self.app_info.get_icon() or gicon

        self.image = Gtk.Image()
        self.fallback_gicon = gicon
        
        self._dbus_thumbnail_requested = False
        self.has_thumbnail = self._load_image(gicon, name)

        icon_overlay = Gtk.Overlay()
        icon_overlay.add(self.image)
        self.pin_badge = Gtk.Label(label="PIN")
        self.pin_badge.get_style_context().add_class('desktop-pin-badge')
        self.pin_badge.set_halign(Gtk.Align.END)
        self.pin_badge.set_valign(Gtk.Align.START)
        self.pin_badge.set_no_show_all(True)
        self.pin_badge.set_visible(False)
        icon_overlay.add_overlay(self.pin_badge)
        self._is_pinned = False

        self.label = Gtk.Label(label=name)
        self.label.set_line_wrap(True)
        self.label.set_line_wrap_mode(gi.repository.Pango.WrapMode.WORD_CHAR)
        self.label.set_max_width_chars(10)
        self.label.set_ellipsize(gi.repository.Pango.EllipsizeMode.END)
        self.label.set_lines(2)
        
        self.label.set_justify(Gtk.Justification.CENTER)
        self.label.set_halign(Gtk.Align.CENTER)

        vbox.pack_start(icon_overlay, True, True, 0)
        vbox.pack_start(self.label, False, False, 0)

        self._pending_collapse = False
        self._drag_started = False

        self.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK |
            Gdk.EventMask.BUTTON_RELEASE_MASK |
            Gdk.EventMask.ENTER_NOTIFY_MASK |
            Gdk.EventMask.LEAVE_NOTIFY_MASK
        )
        self.connect("button-press-event", self.on_button_press)
        self.connect("button-release-event", self.on_button_release)
        self.connect("enter-notify-event", self.on_enter_notify)
        self.connect("leave-notify-event", self.on_leave_notify)
        
        outbound_key = 'drag_out_folder' if self.is_dir_icon else 'drag_out_file'
        self.outbound_mode = ACTION_MODES.get(outbound_key, DEFAULT_ACTIONS[outbound_key])

        drag_action_map = {
            'copy': Gdk.DragAction.COPY,
            'cut': Gdk.DragAction.MOVE,
            'link': Gdk.DragAction.LINK,
        }
        
        is_virtual = self.gio_file.get_uri().startswith("virtual://")

        if not is_virtual and self.outbound_mode in drag_action_map:
            self.drag_source_set(Gdk.ModifierType.BUTTON1_MASK, [], drag_action_map[self.outbound_mode])
            self.drag_source_add_uri_targets()
            self.connect("drag-data-get", self.on_drag_data_get)
            self.connect("drag-begin", self.on_drag_begin)
            self.connect("drag-data-delete", self.on_drag_data_delete)
            self.connect("drag-end", self.on_drag_end)

        self.show_all()

    def position_key(self):
        path = self.gio_file.get_path()
        if path:
            return os.path.basename(path.rstrip("/") or path)
        uri = self.gio_file.get_uri().rstrip("/")
        return uri.rsplit("/", 1)[-1]

    def _on_destroy(self, *_args):
        self._destroyed = True

    def get_pin_id(self):
        if not self.is_desktop_file:
            return None
        return resolve_desktop_pin_id(self.gio_file.get_path(), self.app_info)

    def update_pin_badge(self, pinned_ids):
        if self._destroyed:
            return
        pin_id = self.get_pin_id()
        self._is_pinned = bool(pin_id and pin_id.lower() in (pinned_ids or ()))
        self.pin_badge.set_visible(bool(SHOW_PINNED_BADGE and self._is_pinned))

    def apply_thumbnail_pixbuf(self, pixbuf):
        if self._destroyed or pixbuf is None:
            return
        self.image.set_from_pixbuf(pixbuf)
        self.has_thumbnail = True

    def set_themed_icon(self, icon_name):
        if self._destroyed:
            return
        self.fallback_gicon = Gio.ThemedIcon.new_from_names([icon_name])
        if not self.has_thumbnail:
            self.image.set_from_gicon(self.fallback_gicon, Gtk.IconSize.DIALOG)
            self.image.set_pixel_size(ICON_SIZE)

    def _load_image(self, gicon, name):
        if gicon:
            self.image.set_from_gicon(gicon, Gtk.IconSize.DIALOG)
            self.image.set_pixel_size(ICON_SIZE)
        get_thumbnail_service().request(self)
        return False

    def refresh_thumbnail(self):
        self.has_thumbnail = False
        self._dbus_thumbnail_requested = False
        self.has_thumbnail = self._load_image(
            self.fallback_gicon, self.label.get_text()
        )
        return self.has_thumbnail

    def _real_path(self):
        path = self.gio_file.get_path()
        if path and os.path.islink(path):
            return os.path.realpath(path)
        return path

    def _resolve_uri(self):
        path = self._real_path()
        if path:
            return Gio.File.new_for_path(path).get_uri()
        return self.gio_file.get_uri().rstrip("/")

    def on_drag_data_get(self, widget, drag_context, data, info, time):
        parent = self.get_parent()
        if isinstance(parent, DesktopLayout) and self in parent.selected_icons and len(parent.selected_icons) > 1:
            same_type = [icon for icon in parent.selected_icons if icon.is_dir_icon == self.is_dir_icon]
            data.set_uris([icon._resolve_uri() for icon in same_type])
        else:
            data.set_uris([self._resolve_uri()])

    def on_drag_data_delete(self, widget, drag_context):
        window = self.get_toplevel()
        if getattr(window, '_internal_drop_handled', False):
            return

        parent = self.get_parent()
        if isinstance(parent, DesktopLayout) and self in parent.selected_icons and len(parent.selected_icons) > 1:
            targets = [icon for icon in parent.selected_icons if icon.is_dir_icon == self.is_dir_icon]
        else:
            targets = [self]
        for icon in targets:
            if icon.gio_file.get_uri().startswith("virtual://") or icon.outbound_mode != 'cut':
                continue
            real_path = icon._real_path()
            link_path = icon.gio_file.get_path()
            try:
                if real_path and os.path.exists(real_path):
                    if os.path.isdir(real_path):
                        shutil.rmtree(real_path)
                    else:
                        os.remove(real_path)
            except Exception as e:
                print(f"Could not delete {real_path} after Cut: {e}")
            if link_path and link_path != real_path and os.path.islink(link_path):
                try:
                    os.remove(link_path)
                except Exception as e:
                    print(f"Could not delete symlink {link_path}: {e}")

    def on_enter_notify(self, widget, event):
        self.is_hovered = True
        self.get_style_context().add_class('hovered')
        return False

    def on_leave_notify(self, widget, event):
        self.is_hovered = False
        self.get_style_context().remove_class('hovered')
        return False

    def on_drag_begin(self, widget, drag_context):
        self._drag_started = True
        window = self.get_toplevel()

        window._internal_drop_handled = False

        parent = self.get_parent()
        if isinstance(parent, DesktopLayout) and self in parent.selected_icons and len(parent.selected_icons) > 1:
            window._multi_drag_paths = [icon.position_key() for icon in parent.selected_icons]
        else:
            window._multi_drag_paths = [self.position_key()]
        window._multi_drag_origin = self.position_key()

        alloc = self.get_allocation()
        surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, alloc.width, alloc.height)
        cr = cairo.Context(surface)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)
        self.draw(cr)
        cr.set_operator(cairo.OPERATOR_DEST_IN)
        cr.set_source_rgba(0, 0, 0, 0.6)
        cr.paint()
        Gtk.drag_set_icon_surface(drag_context, surface)

    def on_drag_end(self, widget, drag_context):
        window = self.get_toplevel()
        window._multi_drag_paths = None
        window._multi_drag_origin = None
        if hasattr(window, '_internal_drop_handled'):
            window._internal_drop_handled = False

    def set_selected(self, selected):
        self.is_selected = selected
        ctx = self.get_style_context()
        if selected:
            ctx.add_class('selected')
        else:
            ctx.remove_class('selected')

    def on_button_press(self, widget, event):
        if event.button == 1 and event.type == Gdk.EventType.BUTTON_PRESS:
            # Force focus so window can capture key events
            self.get_toplevel().grab_focus()
            
            parent = self.get_parent()
            self._pending_collapse = False
            self._drag_started = False
            if isinstance(parent, DesktopLayout):
                ctrl = bool(event.state & Gdk.ModifierType.CONTROL_MASK)
                shift = bool(event.state & Gdk.ModifierType.SHIFT_MASK)
                if shift:
                    parent.select_range_to(self, ctrl=ctrl)
                elif ctrl:
                    parent.select_icon(self, ctrl=True)
                elif self in parent.selected_icons and len(parent.selected_icons) > 1:
                    self._pending_collapse = True
                else:
                    parent.select_icon(self, ctrl=False)
            return False
        if event.button == 1 and event.type == Gdk.EventType._2BUTTON_PRESS:
            self.launch()
            return True
        elif event.button == 3 and event.type == Gdk.EventType.BUTTON_PRESS:
            self.get_toplevel().grab_focus()
            parent = self.get_parent()
            if isinstance(parent, DesktopLayout):
                if not (self in parent.selected_icons and len(parent.selected_icons) > 1):
                    parent.select_icon(self, ctrl=False)
            self.show_context_menu(event)
            return True
        return False

    def on_button_release(self, widget, event):
        if event.button == 1 and self._pending_collapse and not self._drag_started:
            parent = self.get_parent()
            if isinstance(parent, DesktopLayout):
                parent.select_icon(self, ctrl=False)
        self._pending_collapse = False
        self._drag_started = False
        return False

    def launch(self, specific_app=None):
        if self.gio_info and self.gio_info.get_file_type() == Gio.FileType.SHORTCUT:
            target_uri = self.gio_info.get_attribute_string("standard::target-uri")
            if target_uri:
                try:
                    Gio.AppInfo.launch_default_for_uri(target_uri, None)
                except GLib.Error:
                    spawn_detached(['xdg-open', target_uri])
                return

        if specific_app:
            try:
                specific_app.launch([self.gio_file], None)
            except GLib.Error as e:
                print(f"Failed to launch app: {e}")
            return

        if self.app_info:
            try:
                self.app_info.launch([], None)
            except GLib.Error as e:
                print(f"Failed to launch app: {e}")
        else:
            try:
                info = self.gio_file.query_info(Gio.FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE, Gio.FileQueryInfoFlags.NONE, None)
                content_type = info.get_content_type()
                app = Gio.AppInfo.get_default_for_type(content_type, False)
                if app:
                    app.launch([self.gio_file], None)
                else:
                    spawn_detached(['xdg-open', self.gio_file.get_path()])
            except Exception as e:
                print(f"Failed to open file: {e}")

    def open_in_thunar(self, widget):
        open_path_default(self.gio_file.get_path())

    def show_context_menu(self, event):
        parent = self.get_parent()
        if isinstance(parent, DesktopLayout) and self in parent.selected_icons and len(parent.selected_icons) > 1:
            parent.show_multi_selection_context_menu(event)
            return

        menu = Gtk.Menu()
        menu.get_style_context().add_class('desktop-context-menu')

        open_item = Gtk.MenuItem(label="Open")
        open_item.connect("activate", lambda w: self.launch())
        menu.append(open_item)
        
        is_virtual = self.gio_file.get_uri().startswith("virtual://")
        is_trash = self.gio_file.get_uri() == "virtual://trash"

        if not is_virtual:
            try:
                info = self.gio_file.query_info(Gio.FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE, Gio.FileQueryInfoFlags.NONE, None)
                content_type = info.get_content_type()
                apps = Gio.AppInfo.get_all_for_type(content_type)
                if apps and not self.is_desktop_file:
                    seen_apps = set()
                    unique_apps = []
                    for app in apps:
                        key = app.get_id() or app.get_executable() or app.get_display_name()
                        if key and key not in seen_apps:
                            seen_apps.add(key)
                            unique_apps.append(app)
                    if unique_apps:
                        open_with_item = Gtk.MenuItem(label="Open With")
                        open_with_menu = Gtk.Menu()
                        open_with_menu.get_style_context().add_class('desktop-context-menu')
                        for app in unique_apps:
                            app_item = Gtk.MenuItem(label=app.get_display_name())
                            app_item.connect("activate", lambda w, a=app: self.launch(a))
                            open_with_menu.append(app_item)
                        open_with_item.set_submenu(open_with_menu)
                        menu.append(open_with_item)
            except Exception:
                pass

            file_path = self.gio_file.get_path()
            pin_id = self.get_pin_id() if file_path else None
            if pin_id and resolve_pinned_ctl() is not None:
                win = self.get_toplevel()
                app_obj = win.get_application() if isinstance(win, Gtk.Window) else None
                watcher = getattr(app_obj, '_pin_watcher', None) if app_obj is not None else None
                pinned_ids = watcher.pinned_ids if watcher is not None else load_pinned_ids()
                is_pinned = pin_id.lower() in pinned_ids
                surface_name = "AppBar" if read_shell_backend() == "classic" else "Dock"
                pin_label = f"Unpin from {surface_name}" if is_pinned else f"Pin to {surface_name}"
                pin_item = Gtk.MenuItem(label=pin_label)
                def _on_pin_toggle(_w, act=("remove" if is_pinned else "add"), pid=pin_id, wref=watcher):
                    run_pinned_ctl(
                        act,
                        pid,
                        on_done=(lambda ok: GLib.idle_add(lambda: (wref.refresh_now(), False)[1]) if ok and wref is not None else None),
                    )
                pin_item.connect("activate", _on_pin_toggle)
                menu.append(pin_item)

            menu.append(Gtk.SeparatorMenuItem())

            if file_path:
                populate_thunar_actions_menu(menu, [file_path], is_directory_background=False, fallback_cwd=os.path.dirname(file_path))
            
            menu.append(Gtk.SeparatorMenuItem())

            cut_item = Gtk.MenuItem(label="Cut")
            cut_item.connect("activate", lambda w: self.copy_to_clipboard("cut"))
            menu.append(cut_item)

            copy_item = Gtk.MenuItem(label="Copy")
            copy_item.connect("activate", lambda w: self.copy_to_clipboard("copy"))
            menu.append(copy_item)

            if file_path:
                dup_item = Gtk.MenuItem(label="Duplicate")
                dest_dir = parent.desktop_dir if isinstance(parent, DesktopLayout) else os.path.dirname(file_path)
                dup_item.connect("activate", lambda _w, d=dest_dir, p=file_path: _IO_EXECUTOR.submit(_duplicate_paths_sync, d, [p]))
                menu.append(dup_item)
            
            menu.append(Gtk.SeparatorMenuItem())

            rename_item = Gtk.MenuItem(label="Rename")
            rename_item.connect("activate", self.on_rename)
            menu.append(rename_item)

            trash_item = Gtk.MenuItem(label="Move to Trash")
            trash_item.connect("activate", self.move_to_trash)
            menu.append(trash_item)

            if file_path:
                del_item = Gtk.MenuItem(label="Delete Permanently")
                del_item.connect("activate", self.delete_permanently)
                menu.append(del_item)
            
        elif is_trash:
            menu.append(Gtk.SeparatorMenuItem())
            empty_item = Gtk.MenuItem(label="Empty Trash")
            def empty_trash(w):
                try:
                    proc = Gio.Subprocess.new(
                        ['gio', 'trash', '--empty'],
                        Gio.SubprocessFlags.STDERR_PIPE,
                    )
                except GLib.Error as err:
                    print(f"Failed to empty trash: {err}")
                    return

                def _on_empty_done(subproc, result):
                    try:
                        subproc.wait_check_finish(result)
                    except GLib.Error as err:
                        print(f"Failed to empty trash: {err}")
                        return
                    self.set_themed_icon("user-trash")

                proc.wait_check_async(None, _on_empty_done)
            empty_item.connect("activate", empty_trash)
            menu.append(empty_item)

        if not is_virtual:
            menu.append(Gtk.SeparatorMenuItem())
            prop_item = Gtk.MenuItem(label="Properties")
            prop_item.connect("activate", self.show_properties)
            menu.append(prop_item)

        def on_deactivate(m):
            self.is_hovered = False
            self.get_style_context().remove_class('hovered')

        menu.connect("deactivate", on_deactivate)
        self._context_menu = menu

        menu.show_all()
        menu.popup_at_pointer(event)

    def copy_to_clipboard(self, action):
        wl_copy_files([self.gio_file.get_uri()], action)

    def on_rename(self, widget):
        current = self.gio_info.get_display_name()
        parent = self.get_toplevel()
        new_name = run_prompt_dialog(
            "Rename File",
            initial_text=current,
            confirm_label="Rename",
            parent=parent if isinstance(parent, Gtk.Window) else None,
        )
        if new_name and new_name != current:
            try:
                self.gio_file.set_display_name(new_name, None)
            except Exception as e:
                print(f"Rename failed: {e}")

    def show_properties(self, widget):
        uri = self.gio_file.get_uri()
        cmd = [
            "dbus-send", 
            "--session", 
            "--dest=org.freedesktop.FileManager1",
            "--type=method_call", 
            "/org/freedesktop/FileManager1",
            "org.freedesktop.FileManager1.ShowItemProperties",
            f"array:string:{uri}", 
            "string:"
        ]
        spawn_detached(cmd, delay_ms=40)

    def move_to_trash(self, widget=None):
        try:
            self.gio_file.trash(None)
        except GLib.Error as e:
            print(f"Failed to trash file: {e}")

    def delete_permanently(self, widget=None):
        file_path = self.gio_file.get_path()
        if not file_path:
            return
        parent = self.get_toplevel()
        display_name = self.gio_info.get_display_name() if self.gio_info else os.path.basename(file_path)
        confirmed = run_prompt_dialog(
            "Delete Permanently",
            confirm_label="Delete",
            danger=True,
            show_entry=False,
            message=f"Permanently delete '{display_name}'? This cannot be undone.",
            parent=parent if isinstance(parent, Gtk.Window) else None,
        )
        if confirmed:
            _IO_EXECUTOR.submit(_delete_paths_sync, [file_path])


################################################################################
# UI COMPONENT: DESKTOP LAYOUT (GRID)
# Manages the layout, rubber-band selection, and drop zones.
################################################################################

def order_grid_keys(effective_positions, grid_direction="column"):
    """Sort icon position keys in visual reading order for range selection."""
    if grid_direction == "row":
        return [k for k, _ in sorted(effective_positions.items(), key=lambda kv: (kv[1][1], kv[1][0], kv[0].lower()))]
    return [k for k, _ in sorted(effective_positions.items(), key=lambda kv: (kv[1][0], kv[1][1], kv[0].lower()))]


def compute_range_keys(ordered_keys, anchor_key, target_key):
    """Return slice of ordered_keys between anchor_key and target_key inclusive."""
    if anchor_key in ordered_keys and target_key in ordered_keys:
        i0 = ordered_keys.index(anchor_key)
        i1 = ordered_keys.index(target_key)
        lo, hi = min(i0, i1), max(i0, i1)
        return ordered_keys[lo:hi + 1]
    return [target_key] if target_key else []


def find_arrow_neighbor_key(effective_positions, current_key, dx, dy):
    """Find next icon key along grid direction (dx, dy), or current_key if at edge."""
    if current_key not in effective_positions:
        ordered = order_grid_keys(effective_positions, GRID_DIRECTION)
        return ordered[0] if ordered else None
    cur_c, cur_r = effective_positions[current_key]
    best_key = None
    best_score = None
    for key, (col, row) in effective_positions.items():
        if key == current_key:
            continue
        if dx > 0 and col > cur_c:
            score = (col - cur_c, abs(row - cur_r))
        elif dx < 0 and col < cur_c:
            score = (cur_c - col, abs(row - cur_r))
        elif dy > 0 and row > cur_r:
            score = (row - cur_r, abs(col - cur_c))
        elif dy < 0 and row < cur_r:
            score = (cur_r - row, abs(col - cur_c))
        else:
            continue
        if best_score is None or score < best_score:
            best_score = score
            best_key = key
    return best_key if best_key is not None else current_key


class DesktopLayout(Gtk.Fixed):
    def __init__(self, window, monitor=None):
        super().__init__()
        self.window = window
        self.monitor = monitor
        self.monitor_key = get_monitor_key(monitor)
        self.icons = {}
        self.selected_icons = set()
        self._selection_anchor = None
        self._selection_focus = None
        self.drop_target_cell = None
        self._effective_positions = {}
        self._transient_positions = None

        self._rubber_start = None
        self._rubber_active = False
        self._rubber_ctrl = False
        self._rubber_pre_selection = set()
        self.rubber_band_rect = None
        self._icon_alloc_cache = None
        
        self.desktop_dir = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DESKTOP)
        if not self.desktop_dir:
            self.desktop_dir = os.path.join(GLib.get_home_dir(), "Desktop")
        
        self.last_alloc_width = 0
        self.last_alloc_height = 0
        
        self.set_has_window(True)
        self.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK |
            Gdk.EventMask.BUTTON_RELEASE_MASK |
            Gdk.EventMask.POINTER_MOTION_MASK |
            Gdk.EventMask.ENTER_NOTIFY_MASK |
            Gdk.EventMask.LEAVE_NOTIFY_MASK
        )
        self.connect("button-press-event", self.on_bg_click)
        self.connect("button-release-event", self.on_bg_release)
        self.connect("motion-notify-event", self.on_bg_motion)
        self.connect("leave-notify-event", self.on_bg_leave)
        self.connect("enter-notify-event", self.on_bg_enter)
        
        self.connect("size-allocate", self.on_size_allocate)
        self.connect("draw", self.on_draw_overlay)
        self.cols = 1
        self.rows = 1

    def on_bg_enter(self, widget, event):
        if event.detail != Gdk.NotifyType.INFERIOR and event.mode == Gdk.CrossingMode.NORMAL:
            try:
                GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.ON_DEMAND)
            except AttributeError:
                pass
        return False

    def on_bg_leave(self, widget, event):
        if event.detail != Gdk.NotifyType.INFERIOR and event.mode == Gdk.CrossingMode.NORMAL:
            self.clear_selection()
            self.window.set_focus(None)
            try:
                GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)
            except AttributeError:
                pass
        return False

    def on_bg_click(self, widget, event):
        if event.window != self.get_window():
            return False
        
        self.window.grab_focus()
        
        if event.button == 1:
            self._rubber_start = (event.x, event.y)
            self._rubber_active = False
            self._rubber_ctrl = bool(event.state & Gdk.ModifierType.CONTROL_MASK)
            self._rubber_pre_selection = set(self.selected_icons) if self._rubber_ctrl else set()
            
            self._icon_alloc_cache = []
            for icon in self.icons.values():
                alloc = icon.get_allocation()
                self._icon_alloc_cache.append((icon, alloc.x, alloc.y, alloc.x + alloc.width, alloc.y + alloc.height))
        elif event.button == 3:
            self.clear_selection()
            self.show_desktop_context_menu(event)
        return False

    def on_bg_motion(self, widget, event):
        if self._rubber_start is None:
            return False
        if not (event.state & Gdk.ModifierType.BUTTON1_MASK):
            return False

        sx, sy = self._rubber_start
        dx, dy = event.x - sx, event.y - sy

        if not self._rubber_active and (abs(dx) > 4 or abs(dy) > 4):
            self._rubber_active = True

        if self._rubber_active:
            x0, y0 = min(sx, event.x), min(sy, event.y)
            x1, y1 = max(sx, event.x), max(sy, event.y)
            
            old_rect = self.rubber_band_rect
            self.rubber_band_rect = (x0, y0, x1 - x0, y1 - y0)

            in_rect = self._icons_in_rect(x0, y0, x1, y1)
            self._apply_selection(self._rubber_pre_selection | in_rect)
            
            if old_rect:
                ox, oy, ow, oh = old_rect
                ux = min(x0, ox) - 2
                uy = min(y0, oy) - 2
                uw = max(x0 + (x1 - x0), ox + ow) - ux + 4
                uh = max(y0 + (y1 - y0), oy + oh) - uy + 4
                self.queue_draw_area(int(ux), int(uy), int(uw), int(uh))
            else:
                self.queue_draw_area(int(x0 - 2), int(y0 - 2), int(x1 - x0 + 4), int(y1 - y0 + 4))
        return False

    def on_bg_release(self, widget, event):
        if event.button == 1 and self._rubber_start is not None:
            if not self._rubber_active and not self._rubber_ctrl:
                self.clear_selection()
            
            old_rect = self.rubber_band_rect
            
            self._rubber_start = None
            self._rubber_active = False
            self.rubber_band_rect = None
            self._icon_alloc_cache = None
            
            if old_rect:
                ox, oy, ow, oh = old_rect
                self.queue_draw_area(int(ox - 2), int(oy - 2), int(ow + 4), int(oh + 4))
            else:
                self.queue_draw()
        return False

    def _icons_in_rect(self, x0, y0, x1, y1):
        result = set()
        if self._icon_alloc_cache is not None:
            for icon, ix0, iy0, ix1, iy1 in self._icon_alloc_cache:
                if ix0 < x1 and ix1 > x0 and iy0 < y1 and iy1 > y0:
                    result.add(icon)
        else:
            for icon in self.icons.values():
                alloc = icon.get_allocation()
                ix0, iy0 = alloc.x, alloc.y
                ix1, iy1 = ix0 + alloc.width, iy0 + alloc.height
                if ix0 < x1 and ix1 > x0 and iy0 < y1 and iy1 > y0:
                    result.add(icon)
        return result

    def _apply_selection(self, desired_set):
        for icon in list(self.selected_icons):
            if icon not in desired_set:
                icon.set_selected(False)
                self.selected_icons.discard(icon)
        for icon in desired_set:
            if icon not in self.selected_icons:
                icon.set_selected(True)
                self.selected_icons.add(icon)

    def on_key_press(self, widget, event):
        arrow_map = {
            Gdk.KEY_Left: (-1, 0),
            Gdk.KEY_Right: (1, 0),
            Gdk.KEY_Up: (0, -1),
            Gdk.KEY_Down: (0, 1),
        }
        if event.keyval in arrow_map:
            if not (event.state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK)):
                dx, dy = arrow_map[event.keyval]
                self.move_selection_arrow(dx, dy, extend=bool(event.state & Gdk.ModifierType.SHIFT_MASK))
                return True

        keyname = Gdk.keyval_name(event.keyval)
        if not keyname:
            return False
            
        mods = []
        if event.state & Gdk.ModifierType.CONTROL_MASK:
            mods.append("<Ctrl>")
        if event.state & Gdk.ModifierType.SHIFT_MASK:
            mods.append("<Shift>")
        if event.state & Gdk.ModifierType.MOD1_MASK:
            mods.append("<Alt>")
            
        combo = "".join(mods) + (keyname.lower() if len(keyname) == 1 else keyname)
        
        action = None
        for k, v in KEYBINDINGS.items():
            if v == combo:
                action = k
                break
                
        if not action:
            return False
            
        if action == 'copy':
            self.copy_selected_to_clipboard('copy')
            return True
        elif action == 'cut':
            self.copy_selected_to_clipboard('cut')
            return True
        elif action == 'paste':
            self.on_paste(None)
            return True
        elif action == 'duplicate':
            self.duplicate_selected()
            return True
        elif action == 'trash':
            self.trash_selected()
            return True
        elif action == 'delete_permanent':
            self.delete_selected_permanently()
            return True
        elif action == 'rename':
            self.rename_selected()
            return True
        elif action == 'refresh':
            self.on_reload(None)
            return True
        elif action == 'open':
            self.launch_selected()
            return True
        elif action == 'select_all':
            self.select_all_icons()
            return True
            
        return False

    def select_all_icons(self):
        for icon in self.icons.values():
            if icon not in self.selected_icons:
                icon.set_selected(True)
                self.selected_icons.add(icon)

    def rename_selected(self):
        if len(self.selected_icons) == 1:
            list(self.selected_icons)[0].on_rename(None)

    def sort_icons(self, criterion=None, reverse=None):
        global SORT_BY, SORT_REVERSE, FOLDERS_FIRST
        if criterion is not None:
            SORT_BY = criterion
        if reverse is not None:
            SORT_REVERSE = reverse
            
        save_setting('sort_by', SORT_BY)
        save_setting('sort_reverse', SORT_REVERSE)
        save_setting('folders_first', FOLDERS_FIRST)

        icon_list = []
        for filepath, icon_widget in self.icons.items():
            filename = os.path.basename(filepath)
            try:
                if filepath.startswith("virtual://"):
                    mod_time = 0
                    size = 0
                else:
                    st = os.stat(filepath)
                    mod_time = st.st_mtime
                    size = st.st_size
            except OSError:
                mod_time = 0
                size = 0
                
            is_dir = icon_widget.is_dir_icon
            ext = os.path.splitext(filename)[1].lower() if not is_dir else ""
            name_lower = filename.lower()
            type_key = (ext, name_lower)
            
            icon_list.append({
                'filepath': filepath,
                'filename': filename,
                'name': name_lower,
                'date': mod_time,
                'size': size,
                'type': type_key,
                'is_dir': is_dir,
                'is_user_dir': getattr(icon_widget, 'is_user_dir', False),
                'icon_widget': icon_widget
            })
            
        def get_sort_val(x):
            if SORT_BY == 'name':
                return x['name']
            elif SORT_BY == 'date':
                return x['date']
            elif SORT_BY == 'size':
                return x['size']
            elif SORT_BY == 'type':
                return x['type']
            return x['name']
            
        virtual_icons = [x for x in icon_list if x['filepath'].startswith("virtual://")]
        normal_icons = [x for x in icon_list if not x['filepath'].startswith("virtual://")]

        if USER_DIRS_FIRST:
            user_dirs = [x for x in normal_icons if x['is_dir'] and x.get('is_user_dir', False)]
            other_icons = [x for x in normal_icons if not (x['is_dir'] and x.get('is_user_dir', False))]
            
            user_dirs.sort(key=get_sort_val, reverse=SORT_REVERSE)

            if FOLDERS_FIRST:
                folders = [x for x in other_icons if x['is_dir']]
                files = [x for x in other_icons if not x['is_dir']]
                folders.sort(key=get_sort_val, reverse=SORT_REVERSE)
                files.sort(key=get_sort_val, reverse=SORT_REVERSE)
                other_icons = folders + files
            else:
                other_icons.sort(key=get_sort_val, reverse=SORT_REVERSE)
                
            normal_icons = user_dirs + other_icons
        else:
            if FOLDERS_FIRST:
                folders = [x for x in normal_icons if x['is_dir']]
                files = [x for x in normal_icons if not x['is_dir']]
                folders.sort(key=get_sort_val, reverse=SORT_REVERSE)
                files.sort(key=get_sort_val, reverse=SORT_REVERSE)
                normal_icons = folders + files
            else:
                normal_icons.sort(key=get_sort_val, reverse=SORT_REVERSE)
            
        order = {"virtual://home": 0, "virtual://computer": 1, "virtual://trash": 2}
        virtual_icons.sort(key=lambda x: order.get(x['filepath'], 99))
        
        final_list = virtual_icons + normal_icons

        top_margin = self.top_margin()
        self.cols = max(1, (self.last_alloc_width - PADDING) // (CELL_WIDTH + PADDING))
        self.rows = max(1, (self.last_alloc_height - top_margin - PADDING) // (CELL_HEIGHT + PADDING))

        keys = [item['icon_widget'].position_key() for item in final_list]
        auto_map = compute_auto_grid_positions(keys, self.cols, self.rows, GRID_DIRECTION, reserve_special=True)

        self._is_sorting = True
        try:
            if AUTO_ARRANGE:
                self._transient_positions = auto_map
            else:
                self._transient_positions = None
                raw_positions = load_positions()
                saved_map = extract_monitor_positions(raw_positions, self.monitor_key)
                for k, (c, r) in auto_map.items():
                    if k not in SPECIAL_KEYS:
                        saved_map[k] = {'col': c, 'row': r}
                save_positions(merge_monitor_positions(raw_positions, self.monitor_key, saved_map))
            self.reposition_icons()
        finally:
            self._is_sorting = False

    def show_desktop_context_menu(self, event):
        menu = Gtk.Menu()
        menu.get_style_context().add_class('desktop-context-menu')

        # === HAKUSPACE MENU ===
        hakumenu_item = Gtk.MenuItem(label="Menu")
        hakumenu_item.connect("activate", lambda _w: spawn_detached([str(bin_dir() / "hakumenu.sh")], delay_ms=40))
        menu.append(hakumenu_item)

        space_item = Gtk.MenuItem(label="Space")
        space_menu = Gtk.Menu()
        space_menu.get_style_context().add_class('desktop-context-menu')
        space_item.set_submenu(space_menu)

        for entry in build_workspace_menu_spec():
            kind = entry.get("kind")
            if kind == "separator":
                space_menu.append(Gtk.SeparatorMenuItem())
                continue
            cmd = entry.get("cmd") or []
            if kind == "check":
                item = Gtk.CheckMenuItem(label=entry["label"])
                item.set_active(_probe_workspace_item_active(entry.get("probe")))
            else:
                item = Gtk.MenuItem(label=entry["label"])
            if cmd:
                item.connect("activate", lambda _w, c=cmd: spawn_detached([str(bin_dir() / c[0]), *c[1:]], delay_ms=40))
            space_menu.append(item)

        menu.append(space_item)
        menu.append(Gtk.SeparatorMenuItem())
        # === END HAKUSPACE MENU ===

        refresh_item = Gtk.MenuItem(label="Refresh")
        refresh_item.connect("activate", self.on_reload)
        menu.append(refresh_item)

        menu.append(Gtk.SeparatorMenuItem())

        sort_item = Gtk.MenuItem(label="Sort By")
        sort_menu = Gtk.Menu()
        sort_menu.get_style_context().add_class('desktop-context-menu')
        
        sort_opts = [
            ("Name (A-Z)", 'name', False),
            ("Name (Z-A)", 'name', True),
            ("Date Modified (Newest)", 'date', True),
            ("Date Modified (Oldest)", 'date', False),
            ("Size (Largest)", 'size', True),
            ("Size (Smallest)", 'size', False),
            ("Type", 'type', False)
        ]
        
        first_radio = None
        for label, criterion, reverse in sort_opts:
            if first_radio is None:
                item = Gtk.RadioMenuItem.new_with_label(None, label)
                first_radio = item
            else:
                item = Gtk.RadioMenuItem.new_with_label_from_widget(first_radio, label)
            
            if SORT_BY == criterion and SORT_REVERSE == reverse:
                item.set_active(True)
                
            def make_toggled_cb(crit, rev):
                def cb(w):
                    if w.get_active():
                        self.sort_icons(crit, rev)
                return cb
                
            item.connect("toggled", make_toggled_cb(criterion, reverse))
            sort_menu.append(item)

        sort_menu.append(Gtk.SeparatorMenuItem())
        
        folders_first_item = Gtk.CheckMenuItem(label="Folders First")
        folders_first_item.set_active(FOLDERS_FIRST)
        def on_folders_first_toggled(widget):
            global FOLDERS_FIRST
            FOLDERS_FIRST = widget.get_active()
            save_setting('folders_first', FOLDERS_FIRST)
            self.sort_icons()
        folders_first_item.connect("toggled", on_folders_first_toggled)
        sort_menu.append(folders_first_item)

        user_dirs_first_item = Gtk.CheckMenuItem(label="User Dirs First")
        user_dirs_first_item.set_active(USER_DIRS_FIRST)
        def on_user_dirs_first_toggled(widget):
            global USER_DIRS_FIRST
            USER_DIRS_FIRST = widget.get_active()
            save_setting('user_dirs_first', USER_DIRS_FIRST)
            self.sort_icons()
        user_dirs_first_item.connect("toggled", on_user_dirs_first_toggled)
        sort_menu.append(user_dirs_first_item)
        
        sort_menu.append(Gtk.SeparatorMenuItem())

        dir_first_radio = None
        for dir_label, dir_val in (("Fill by Column", "column"), ("Fill by Row", "row")):
            if dir_first_radio is None:
                d_item = Gtk.RadioMenuItem.new_with_label(None, dir_label)
                dir_first_radio = d_item
            else:
                d_item = Gtk.RadioMenuItem.new_with_label_from_widget(dir_first_radio, dir_label)
            if GRID_DIRECTION == dir_val:
                d_item.set_active(True)
            def _on_dir_toggled(w, val=dir_val):
                global GRID_DIRECTION
                if w.get_active():
                    GRID_DIRECTION = val
                    save_setting('grid_direction', val)
                    self.sort_icons()
            d_item.connect("toggled", _on_dir_toggled)
            sort_menu.append(d_item)

        sort_menu.append(Gtk.SeparatorMenuItem())
        
        auto_arrange_item = Gtk.CheckMenuItem(label="Auto Arrange")
        auto_arrange_item.set_active(AUTO_ARRANGE)
        def on_auto_arrange_toggled(widget):
            global AUTO_ARRANGE
            AUTO_ARRANGE = widget.get_active()
            save_setting('auto_arrange', AUTO_ARRANGE)
            if AUTO_ARRANGE:
                self.sort_icons()
            else:
                self._transient_positions = None
                self.reposition_icons()
        auto_arrange_item.connect("toggled", on_auto_arrange_toggled)
        sort_menu.append(auto_arrange_item)

        sort_item.set_submenu(sort_menu)
        menu.append(sort_item)

        menu.append(Gtk.SeparatorMenuItem())
        
        icons_item = Gtk.MenuItem(label="Desktop Icons")
        icons_menu = Gtk.Menu()
        icons_menu.get_style_context().add_class('desktop-context-menu')
        
        def toggle_special(key, widget):
            save_setting(key, widget.get_active())
            self.on_reload(None)
            
        home_item = Gtk.CheckMenuItem(label="Home")
        home_item.set_active(SHOW_HOME)
        home_item.connect("toggled", lambda w: toggle_special('show_home', w))
        icons_menu.append(home_item)
        
        trash_item = Gtk.CheckMenuItem(label="Trash")
        trash_item.set_active(SHOW_TRASH)
        trash_item.connect("toggled", lambda w: toggle_special('show_trash', w))
        icons_menu.append(trash_item)
        
        comp_item = Gtk.CheckMenuItem(label="This PC")
        comp_item.set_active(SHOW_COMPUTER)
        comp_item.connect("toggled", lambda w: toggle_special('show_computer', w))
        icons_menu.append(comp_item)
        
        icons_menu.append(Gtk.SeparatorMenuItem())
        
        hidden_item = Gtk.CheckMenuItem(label="Show Hidden Files")
        hidden_item.set_active(SHOW_HIDDEN)
        hidden_item.connect("toggled", lambda w: toggle_special('show_hidden', w))
        icons_menu.append(hidden_item)
        
        icons_menu.append(Gtk.SeparatorMenuItem())
        
        black_labels_item = Gtk.CheckMenuItem(label="Black Text Labels")
        black_labels_item.set_active(BLACK_LABELS)
        black_labels_item.connect("toggled", lambda w: toggle_special('black_labels', w))
        icons_menu.append(black_labels_item)

        pinned_badge_item = Gtk.CheckMenuItem(label="Pinned Badges")
        pinned_badge_item.set_active(SHOW_PINNED_BADGE)
        pinned_badge_item.connect("toggled", lambda w: toggle_special('show_pinned_badge', w))
        icons_menu.append(pinned_badge_item)

        icons_menu.append(Gtk.SeparatorMenuItem())

        hide_icons_item = Gtk.MenuItem(label="Hide Desktop Icons")
        def _hide_desktop_icons(_w):
            save_setting('show_desktop_icons', True)
            manager_bin = bin_dir() / "desktop_icons_manager.sh"
            if manager_bin.is_file():
                spawn_detached([str(manager_bin), "--set", "disabled"], delay_ms=40)
            else:
                app = self.window.get_application()
                if app is not None:
                    app.quit()
        hide_icons_item.connect("activate", _hide_desktop_icons)
        icons_menu.append(hide_icons_item)
        
        icons_item.set_submenu(icons_menu)
        menu.append(icons_item)

        menu.append(Gtk.SeparatorMenuItem())

        create_folder_item = Gtk.MenuItem(label="Create Folder")
        create_folder_item.connect("activate", lambda w: self._prompt_create("Create Folder", True))
        menu.append(create_folder_item)

        create_doc_item = Gtk.MenuItem(label="Create Document")
        create_doc_item.connect("activate", lambda w: self._prompt_create("Create Empty File", False))
        menu.append(create_doc_item)
        
        add_shortcut_item = Gtk.MenuItem(label="Add Shortcut")
        add_shortcut_item.connect("activate", lambda w: spawn_detached([str(bin_dir() / "gen_shortcut.sh"), "-m"], delay_ms=40))
        menu.append(add_shortcut_item)
        
        menu.append(Gtk.SeparatorMenuItem())

        paste_item = Gtk.MenuItem(label="Paste")
        paste_item.connect("activate", self.on_paste)
        menu.append(paste_item)
        
        menu.append(Gtk.SeparatorMenuItem())

        added_actions = populate_thunar_actions_menu(
            menu, [self.desktop_dir], is_directory_background=True, fallback_cwd=self.desktop_dir
        )
        if added_actions == 0:
            term_item = Gtk.MenuItem(label="Open Terminal Here")
            term_item.connect("activate", self.on_open_terminal)
            menu.append(term_item)
        
        menu.append(Gtk.SeparatorMenuItem())

        open_folder_item = Gtk.MenuItem(label="Open Desktop Folder")
        open_folder_item.connect("activate", lambda _w: open_path_default(self.desktop_dir))
        menu.append(open_folder_item)

        menu.append(Gtk.SeparatorMenuItem())
        
        settings_item = Gtk.MenuItem(label="Settings")
        settings_menu = Gtk.Menu()
        settings_menu.get_style_context().add_class('desktop-context-menu')

        if read_shell_backend() == "hikai":
            hikai_settings_item = Gtk.MenuItem(label="Hikai Settings")
            hikai_settings_item.connect("activate", lambda _w: spawn_detached([str(bin_dir() / "settings_manager.sh"), "open"], delay_ms=40))
            settings_menu.append(hikai_settings_item)
            settings_menu.append(Gtk.SeparatorMenuItem())
        
        default_app_item = Gtk.MenuItem(label="Open Config File")
        default_app_item.connect("activate", lambda _w: open_path_default(CONF_FILE))
        settings_menu.append(default_app_item)
        
        editors = ["nano", "vim", "nvim", "vi", "micro"]
        found_editors = [ed for ed in editors if shutil.which(ed)]
        if found_editors:
            settings_menu.append(Gtk.SeparatorMenuItem())
            for ed in found_editors:
                ed_item = Gtk.MenuItem(label=f"Edit with {ed}")
                def make_editor_cb(editor_cmd):
                    def cb(_w):
                        resolved = resolve_terminal_cmd(cwd=os.path.dirname(CONF_FILE), command_args=[editor_cmd, CONF_FILE])
                        if not resolved:
                            print(f"Could not find a suitable terminal emulator to launch {editor_cmd}")
                            return
                        argv, term_cwd = resolved
                        spawn_detached(argv, cwd=term_cwd, delay_ms=40)
                    return cb
                ed_item.connect("activate", make_editor_cb(ed))
                settings_menu.append(ed_item)
        
        settings_item.set_submenu(settings_menu)
        menu.append(settings_item)

        menu.show_all()
        menu.popup_at_pointer(event)

    def on_reload(self, widget):
        app = self.window.get_application() if self.window is not None else None
        if app is not None and hasattr(app, 'hot_reload'):
            app.hot_reload()

    def _prompt_create(self, title, is_folder):
        default_name = "New Folder" if is_folder else "New Document.txt"
        name = run_prompt_dialog(
            title,
            initial_text=default_name,
            confirm_label="Create",
            parent=self.window if isinstance(self.window, Gtk.Window) else None,
        )
        if name:
            path = os.path.join(self.desktop_dir, name)
            try:
                if is_folder:
                    os.makedirs(path, exist_ok=True)
                else:
                    open(path, 'a').close()
            except Exception as e:
                print(f"Failed to create {path}: {e}")

    def on_paste(self, widget):
        try:
            proc = Gio.Subprocess.new(
                ["wl-paste", "--list-types"],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
            )
        except GLib.Error as e:
            print(f"Could not run wl-paste: {e}")
            return

        desktop_dir = self.desktop_dir

        def _dispatch_transfer(paths, action):
            if paths:
                _IO_EXECUTOR.submit(_transfer_paths_sync, desktop_dir, paths, action)

        def _read_mime_async(mime, on_data):
            try:
                sub = Gio.Subprocess.new(
                    ["wl-paste", "--type", mime, "--no-newline"],
                    Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
                )
            except GLib.Error:
                on_data(None)
                return

            def _done(p, res):
                try:
                    _, stdout, _ = p.communicate_finish(res)
                    data = stdout.get_data() if p.get_successful() and stdout else None
                    on_data(data)
                except GLib.Error:
                    on_data(None)

            sub.communicate_async(None, None, _done)

        def _try_plain_mimes(candidates):
            if not candidates:
                return
            mime = candidates[0]
            def _on_plain(raw):
                if raw:
                    text = raw.decode("utf-8", errors="ignore")
                    lines = [line.strip() for line in text.splitlines() if line.strip()]
                    if lines:
                        _dispatch_transfer(lines, "copy")
                        return
                _try_plain_mimes(candidates[1:])
            _read_mime_async(mime, _on_plain)

        def _on_list_done(p, res):
            try:
                _, stdout, _ = p.communicate_utf8_finish(res)
                if not p.get_successful() or not stdout:
                    return
            except GLib.Error as e:
                print(f"Could not read target list from wl-paste: {e}")
                return

            mime_types = [t.strip() for t in stdout.splitlines() if t.strip()]
            if "x-special/gnome-copied-files" in mime_types:
                def _on_gnome(raw):
                    if not raw:
                        return
                    text = raw.decode("utf-8", errors="ignore").replace('\x00', '\n')
                    lines = [line.strip() for line in text.splitlines() if line.strip()]
                    if lines:
                        action = "copy"
                        paths = lines
                        if lines[0] in ("copy", "cut"):
                            action = lines[0]
                            paths = lines[1:]
                        _dispatch_transfer(paths, action)
                _read_mime_async("x-special/gnome-copied-files", _on_gnome)
                return

            if "text/uri-list" in mime_types:
                def _on_uri_list(raw):
                    if not raw:
                        return
                    text = raw.decode("utf-8", errors="ignore")
                    lines = [
                        line.strip() for line in text.splitlines()
                        if line.strip() and not line.startswith('#')
                    ]
                    _dispatch_transfer(lines, "copy")
                _read_mime_async("text/uri-list", _on_uri_list)
                return

            plain_candidates = [
                m for m in ("text/plain;charset=utf-8", "UTF8_STRING", "text/plain", "STRING")
                if m in mime_types
            ]
            _try_plain_mimes(plain_candidates)

        proc.communicate_utf8_async(None, None, _on_list_done)

    def on_open_terminal(self, widget):
        resolved = resolve_terminal_cmd(cwd=self.desktop_dir)
        if not resolved:
            print("Failed to open terminal: no terminal emulator found")
            return
        argv, term_cwd = resolved
        spawn_detached(argv, cwd=term_cwd, delay_ms=40)

    def add_icon(self, filepath, gio_info):
        if filepath in self.icons:
            return
        if filepath.startswith("virtual://"):
            gio_file = Gio.File.new_for_uri(filepath)
        else:
            gio_file = Gio.File.new_for_path(filepath)
        icon_widget = DesktopIcon(gio_file, gio_info)
        app = self.window.get_application() if self.window is not None else None
        watcher = getattr(app, '_pin_watcher', None) if app is not None else None
        if watcher is not None:
            icon_widget.update_pin_badge(watcher.pinned_ids)
        self.icons[filepath] = icon_widget
        self.put(icon_widget, -1000, -1000)
        GLib.idle_add(self.reposition_icons)

    def refresh_pin_badges(self, pinned_ids):
        for icon_widget in self.icons.values():
            icon_widget.update_pin_badge(pinned_ids)

    def remove_icon(self, filepath):
        if filepath in self.icons:
            icon_widget = self.icons.pop(filepath)
            self.selected_icons.discard(icon_widget)
            self.remove(icon_widget)
            icon_widget.destroy()
            GLib.idle_add(self.reposition_icons)

    def on_size_allocate(self, widget, allocation):
        if allocation.width != self.last_alloc_width or allocation.height != self.last_alloc_height:
            self.last_alloc_width = allocation.width
            self.last_alloc_height = allocation.height
            GLib.idle_add(self.reposition_icons)

    def top_margin(self):
        return get_effective_top_inset()

    def reposition_icons(self):
        if self.last_alloc_width < 200 or self.last_alloc_height < 200:
            return False

        if getattr(self, '_is_sorting', False):
            pass
        elif AUTO_ARRANGE:
            self.sort_icons()
            return False

        top_margin = self.top_margin()
        self.cols = max(1, (self.last_alloc_width - PADDING) // (CELL_WIDTH + PADDING))
        self.rows = max(1, (self.last_alloc_height - top_margin - PADDING) // (CELL_HEIGHT + PADDING))

        order = {"virtual://home": 0, "virtual://computer": 1, "virtual://trash": 2}
        virtuals = []
        normals = []
        by_key = {}
        for filepath, icon_widget in self.icons.items():
            key = icon_widget.position_key()
            by_key[key] = icon_widget
            if filepath.startswith("virtual://"):
                virtuals.append((filepath, key, icon_widget))
            else:
                normals.append((filepath, key, icon_widget))
        virtuals.sort(key=lambda x: order.get(x[0], 99))
        virtual_keys = [item[1] for item in virtuals]
        normal_keys = [item[1] for item in normals]

        if AUTO_ARRANGE and self._transient_positions is not None:
            placements = self._transient_positions
        else:
            raw_positions = load_positions()
            saved_map = extract_monitor_positions(raw_positions, self.monitor_key)
            if not saved_map and self.icons and not AUTO_ARRANGE:
                auto_keys = virtual_keys + sorted(normal_keys, key=str.lower)
                auto_map = compute_auto_grid_positions(auto_keys, self.cols, self.rows, GRID_DIRECTION, reserve_special=True)
                placements = auto_map
                new_saved = {k: {'col': c, 'row': r} for k, (c, r) in auto_map.items() if k not in SPECIAL_KEYS}
                save_positions(merge_monitor_positions(raw_positions, self.monitor_key, new_saved))
            else:
                placements, new_entries = compute_manual_grid_layout(
                    virtual_keys, normal_keys, saved_map, self.cols, self.rows, GRID_DIRECTION
                )
                if new_entries:
                    saved_map.update(new_entries)
                    save_positions(merge_monitor_positions(raw_positions, self.monitor_key, saved_map))

        self._effective_positions = dict(placements)
        for key, icon_widget in by_key.items():
            icon_widget.set_size_request(CELL_WIDTH, CELL_HEIGHT)
            c, r = placements.get(key, (0, 0))
            x = PADDING + c * (CELL_WIDTH + PADDING)
            y = PADDING + top_margin + r * (CELL_HEIGHT + PADDING)
            alloc = icon_widget.get_allocation()
            if alloc.x != x or alloc.y != y:
                self.move(icon_widget, x, y)

        return False

    def select_icon(self, icon_widget, ctrl=False):
        if ctrl:
            if icon_widget in self.selected_icons:
                icon_widget.set_selected(False)
                self.selected_icons.discard(icon_widget)
            else:
                icon_widget.set_selected(True)
                self.selected_icons.add(icon_widget)
            self._selection_anchor = icon_widget
            self._selection_focus = icon_widget
        else:
            self.clear_selection()
            icon_widget.set_selected(True)
            self.selected_icons.add(icon_widget)
            self._selection_anchor = icon_widget
            self._selection_focus = icon_widget

    def select_range_to(self, target_icon, ctrl=False):
        anchor = self._selection_anchor
        if anchor is None or anchor not in self.icons.values():
            self.select_icon(target_icon, ctrl=ctrl)
            return
        by_key = {icon.position_key(): icon for icon in self.icons.values()}
        ordered_keys = order_grid_keys(self._effective_positions, GRID_DIRECTION)
        range_keys = compute_range_keys(ordered_keys, anchor.position_key(), target_icon.position_key())
        desired = set(self.selected_icons) if ctrl else set()
        for k in range_keys:
            if k in by_key:
                desired.add(by_key[k])
        self._apply_selection(desired)
        self._selection_focus = target_icon

    def move_selection_arrow(self, dx, dy, extend=False):
        if not self._effective_positions:
            return
        by_key = {icon.position_key(): icon for icon in self.icons.values()}
        valid_icons = set(by_key.values())
        if self._selection_focus in valid_icons:
            cur_icon = self._selection_focus
        elif self._selection_anchor in valid_icons:
            cur_icon = self._selection_anchor
        elif self.selected_icons:
            cur_icon = next(iter(self.selected_icons))
        else:
            cur_icon = None
        cur_key = cur_icon.position_key() if cur_icon is not None else None
        next_key = find_arrow_neighbor_key(self._effective_positions, cur_key, dx, dy)
        if not next_key or next_key not in by_key:
            return
        target = by_key[next_key]
        if extend:
            if self._selection_anchor not in valid_icons and cur_icon is not None:
                self._selection_anchor = cur_icon
            self.select_range_to(target, ctrl=False)
        else:
            self.select_icon(target, ctrl=False)

    def clear_selection(self):
        for icon in list(self.selected_icons):
            icon.set_selected(False)
        self.selected_icons.clear()
        self._selection_anchor = None
        self._selection_focus = None

    def show_multi_selection_context_menu(self, event):
        menu = Gtk.Menu()
        menu.get_style_context().add_class('desktop-context-menu')
        count = len(self.selected_icons)

        open_item = Gtk.MenuItem(label=f"Open ({count} items)")
        open_item.connect("activate", lambda w: self.launch_selected())
        menu.append(open_item)

        paths = [
            icon.gio_file.get_path() for icon in self.selected_icons
            if icon.gio_file.get_path() and not icon.gio_file.get_uri().startswith("virtual://")
        ]
        if paths:
            populate_thunar_actions_menu(menu, paths, is_directory_background=False, fallback_cwd=self.desktop_dir)

        menu.append(Gtk.SeparatorMenuItem())

        cut_item = Gtk.MenuItem(label=f"Cut ({count} items)")
        cut_item.connect("activate", lambda w: self.copy_selected_to_clipboard("cut"))
        menu.append(cut_item)

        copy_item = Gtk.MenuItem(label=f"Copy ({count} items)")
        copy_item.connect("activate", lambda w: self.copy_selected_to_clipboard("copy"))
        menu.append(copy_item)

        if paths:
            dup_item = Gtk.MenuItem(label=f"Duplicate ({count} items)")
            dup_item.connect("activate", lambda _w: self.duplicate_selected())
            menu.append(dup_item)

        menu.append(Gtk.SeparatorMenuItem())

        trash_item = Gtk.MenuItem(label=f"Move to Trash ({count} items)")
        trash_item.connect("activate", lambda w: self.trash_selected())
        menu.append(trash_item)

        if paths:
            del_item = Gtk.MenuItem(label=f"Delete Permanently ({count} items)")
            del_item.connect("activate", lambda _w: self.delete_selected_permanently())
            menu.append(del_item)

        def on_deactivate(m):
            for icon in self.selected_icons:
                icon.is_hovered = False
                icon.get_style_context().remove_class('hovered')

        menu.connect("deactivate", on_deactivate)
        self._context_menu = menu

        menu.show_all()
        menu.popup_at_pointer(event)

    def launch_selected(self):
        for icon in list(self.selected_icons):
            icon.launch()

    def duplicate_selected(self):
        paths = [
            icon.gio_file.get_path() for icon in self.selected_icons
            if icon.gio_file.get_path() and not icon.gio_file.get_uri().startswith("virtual://")
        ]
        if paths:
            _IO_EXECUTOR.submit(_duplicate_paths_sync, self.desktop_dir, paths)

    def trash_selected(self):
        for icon in list(self.selected_icons):
            try:
                icon.gio_file.trash(None)
            except GLib.Error as e:
                print(f"Failed to trash {icon.gio_file.get_path()}: {e}")

    def delete_selected_permanently(self):
        paths = [
            icon.gio_file.get_path() for icon in self.selected_icons
            if icon.gio_file.get_path() and not icon.gio_file.get_uri().startswith("virtual://")
        ]
        if not paths:
            return
        confirmed = run_prompt_dialog(
            "Delete Permanently",
            confirm_label="Delete",
            danger=True,
            show_entry=False,
            message=f"Permanently delete {len(paths)} selected item(s)? This cannot be undone.",
            parent=self.window if isinstance(self.window, Gtk.Window) else None,
        )
        if confirmed:
            _IO_EXECUTOR.submit(_delete_paths_sync, paths)

    def copy_selected_to_clipboard(self, action):
        icons = list(self.selected_icons)
        if not icons:
            return
        uris = [icon.gio_file.get_uri() for icon in icons]
        wl_copy_files(uris, action)

    def set_drop_target(self, col, row):
        new_target = (col, row)
        if self.drop_target_cell != new_target:
            self.drop_target_cell = new_target
            self.queue_draw()

    def clear_drop_target(self):
        if self.drop_target_cell is not None:
            self.drop_target_cell = None
            self.queue_draw()

    def on_draw_overlay(self, widget, cr):
        style = get_overlay_style()

        if self.rubber_band_rect is not None:
            x, y, w, h = self.rubber_band_rect
            cr.set_source_rgba(*style["rubber_fill"])
            cr.rectangle(x, y, w, h)
            cr.fill()
            cr.set_source_rgba(*style["rubber_stroke"])
            cr.set_line_width(2 if style["classic"] else 1)
            cr.rectangle(x + 0.5, y + 0.5, max(w - 1, 0), max(h - 1, 0))
            cr.stroke()

        if self.drop_target_cell is None:
            return False

        col, row = self.drop_target_cell
        x = PADDING + col * (CELL_WIDTH + PADDING)
        y = PADDING + self.top_margin() + row * (CELL_HEIGHT + PADDING)
        radius = style["radius"]

        cr.set_source_rgba(*style["drop_fill"])
        if radius > 0:
            self._draw_rounded_rect(cr, x, y, CELL_WIDTH, CELL_HEIGHT, radius)
        else:
            cr.rectangle(x, y, CELL_WIDTH, CELL_HEIGHT)
        cr.fill()

        cr.set_source_rgba(*style["drop_stroke"])
        cr.set_dash([6, 4])
        cr.set_line_width(2)
        if radius > 0:
            self._draw_rounded_rect(cr, x + 1, y + 1, CELL_WIDTH - 2, CELL_HEIGHT - 2, max(0, radius - 1))
        else:
            cr.rectangle(x + 1, y + 1, max(CELL_WIDTH - 2, 0), max(CELL_HEIGHT - 2, 0))
        cr.stroke()

        return False

    @staticmethod
    def _draw_rounded_rect(cr, x, y, w, h, r):
        cr.new_sub_path()
        cr.arc(x + w - r, y + r, r, -pi / 2, 0)
        cr.arc(x + w - r, y + h - r, r, 0, pi / 2)
        cr.arc(x + r, y + h - r, r, pi / 2, pi)
        cr.arc(x + r, y + r, r, pi, 3 * pi / 2)
        cr.close_path()


################################################################################
# DESKTOP MANAGER (CONTROLLER)
# Core controller that watches the file system and manages all icons.
################################################################################

class DesktopManager:
    def __init__(self, layouts):
        self.layouts = layouts
        self._debounce_timer = 0
        self._trash_timer = 0
        self._pending_changes = []
        self.desktop_dir = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DESKTOP)
        if not self.desktop_dir:
            self.desktop_dir = os.path.join(GLib.get_home_dir(), "Desktop")

        self.gfile = Gio.File.new_for_path(self.desktop_dir)

        self.load_initial_files()
        try:
            self.monitor = self.gfile.monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
        except GLib.Error:
            self.monitor = self.gfile.monitor_directory(Gio.FileMonitorFlags.NONE, None)
        self.monitor.connect("changed", self.on_file_changed)

        self.trash_monitor = None
        try:
            self.trash_gfile = Gio.File.new_for_uri("trash:///")
            self.trash_monitor = self.trash_gfile.monitor_directory(Gio.FileMonitorFlags.NONE, None)
            self.trash_monitor.connect("changed", self.on_trash_changed)
        except GLib.Error:
            self.trash_gfile = None

    def _query_trash_icon_name(self):
        try:
            trash_file = self.trash_gfile or Gio.File.new_for_uri("trash:///")
            trash_info = trash_file.query_info("trash::item-count", Gio.FileQueryInfoFlags.NONE, None)
            if trash_info and trash_info.get_attribute_uint32("trash::item-count") > 0:
                return "user-trash-full"
        except Exception:
            pass
        return "user-trash"

    def on_trash_changed(self, *_args):
        if self._trash_timer:
            GLib.source_remove(self._trash_timer)
        self._trash_timer = GLib.timeout_add(150, self._refresh_trash_icon)

    def _refresh_trash_icon(self):
        self._trash_timer = 0
        if not SHOW_TRASH or not SHOW_DESKTOP_ICONS:
            return GLib.SOURCE_REMOVE
        icon_name = self._query_trash_icon_name()
        for layout in self.layouts:
            widget = layout.icons.get("virtual://trash")
            if widget is not None:
                widget.set_themed_icon(icon_name)
        return GLib.SOURCE_REMOVE

    def reload_from_config(self):
        if self._debounce_timer:
            GLib.source_remove(self._debounce_timer)
            self._debounce_timer = 0
        self._pending_changes.clear()
        for layout in self.layouts:
            layout._transient_positions = None
            for filepath in list(layout.icons.keys()):
                layout.remove_icon(filepath)
        self.load_initial_files()
        for layout in self.layouts:
            layout.reposition_icons()

    def _make_virtual_file_info(self, name, icon_name, target_uri):
        info = Gio.FileInfo.new()
        info.set_name(name)
        info.set_display_name(name)
        info.set_is_hidden(False)
        info.set_icon(Gio.ThemedIcon.new_from_names([icon_name]))
        info.set_file_type(Gio.FileType.SHORTCUT)
        info.set_attribute_string("standard::target-uri", target_uri)
        return info

    def sync_layout(self, layout):
        """Populate a newly added monitor layout with current Desktop and virtual icons."""
        if not SHOW_DESKTOP_ICONS:
            return
        if os.path.exists(self.desktop_dir):
            enumerator = self.gfile.enumerate_children(
                "standard::*,thumbnail::path", Gio.FileQueryInfoFlags.NONE, None
            )
            for info in enumerator:
                if not SHOW_HIDDEN and info.get_name().startswith('.'):
                    continue
                filepath = os.path.join(self.desktop_dir, info.get_name())
                layout.add_icon(filepath, info)

        for uri, name, icon_name, target_uri, enabled in (
            ("virtual://home", "Home", "user-home", f"file://{GLib.get_home_dir()}", SHOW_HOME),
            ("virtual://trash", "Trash", self._query_trash_icon_name(), "trash:///", SHOW_TRASH),
            ("virtual://computer", "This PC", "computer-symbolic", "computer:///", SHOW_COMPUTER),
        ):
            if not enabled:
                continue
            info = self._make_virtual_file_info(name, icon_name, target_uri)
            layout.add_icon(uri, info)
        layout.reposition_icons()

    def load_initial_files(self):
        if not SHOW_DESKTOP_ICONS:
            return
        if not os.path.exists(self.desktop_dir):
            return

        enumerator = self.gfile.enumerate_children(
            "standard::*,thumbnail::path", Gio.FileQueryInfoFlags.NONE, None
        )

        for info in enumerator:
            if not SHOW_HIDDEN and info.get_name().startswith('.'):
                continue
            filepath = os.path.join(self.desktop_dir, info.get_name())
            for layout in self.layouts:
                layout.add_icon(filepath, info)

        def add_special(uri, name, icon_name, target_uri):
            info = self._make_virtual_file_info(name, icon_name, target_uri)
            for layout in self.layouts:
                layout.add_icon(uri, info)

        if SHOW_HOME:
            add_special("virtual://home", "Home", "user-home", f"file://{GLib.get_home_dir()}")
        if SHOW_TRASH:
            add_special("virtual://trash", "Trash", self._query_trash_icon_name(), "trash:///")
        if SHOW_COMPUTER:
            add_special("virtual://computer", "This PC", "computer-symbolic", "computer:///")

    def on_file_changed(self, monitor, file, other_file, event_type):
        filepath = file.get_path()
        if not filepath:
            return
        other_path = other_file.get_path() if other_file else None
        self._pending_changes.append((event_type, filepath, other_path))
        if self._debounce_timer:
            GLib.source_remove(self._debounce_timer)
        self._debounce_timer = GLib.timeout_add(150, self._process_file_changes)

    def _migrate_renamed_position(self, old_path, new_path):
        old_name = os.path.basename(old_path)
        new_name = os.path.basename(new_path)
        if not old_name or not new_name or old_name == new_name:
            return
        positions = load_positions()
        changed = False
        if isinstance(positions, dict) and positions.get("version") == 2 and isinstance(positions.get("monitors"), dict):
            for mon_map in positions["monitors"].values():
                if isinstance(mon_map, dict) and old_name in mon_map and new_name not in mon_map:
                    mon_map[new_name] = mon_map.pop(old_name)
                    changed = True
        elif isinstance(positions, dict) and old_name in positions and new_name not in positions:
            positions[new_name] = positions.pop(old_name)
            changed = True
        if changed:
            save_positions(positions)

    def _upsert_path(self, filepath):
        filename = os.path.basename(filepath)
        if not SHOW_HIDDEN and filename.startswith('.'):
            for layout in self.layouts:
                layout.remove_icon(filepath)
            return
        try:
            gfile = Gio.File.new_for_path(filepath)
            info = gfile.query_info("standard::*,thumbnail::path", Gio.FileQueryInfoFlags.NONE, None)
            if info:
                for layout in self.layouts:
                    if filepath in layout.icons:
                        layout.remove_icon(filepath)
                    layout.add_icon(filepath, info)
        except Exception:
            pass

    def _process_file_changes(self):
        self._debounce_timer = 0
        if not SHOW_DESKTOP_ICONS:
            self._pending_changes.clear()
            return GLib.SOURCE_REMOVE

        pending = list(self._pending_changes)
        self._pending_changes.clear()
        for event_type, filepath, other_path in pending:
            if event_type == Gio.FileMonitorEvent.RENAMED and other_path:
                self._migrate_renamed_position(filepath, other_path)
                for layout in self.layouts:
                    layout.remove_icon(filepath)
                self._upsert_path(other_path)
            elif event_type in (
                Gio.FileMonitorEvent.CREATED,
                Gio.FileMonitorEvent.CHANGES_DONE_HINT,
                Gio.FileMonitorEvent.MOVED_IN,
            ):
                self._upsert_path(filepath)
            elif event_type in (
                Gio.FileMonitorEvent.DELETED,
                Gio.FileMonitorEvent.MOVED_OUT,
            ):
                for layout in self.layouts:
                    layout.remove_icon(filepath)
        return GLib.SOURCE_REMOVE

    def shutdown(self):
        if self._debounce_timer:
            GLib.source_remove(self._debounce_timer)
            self._debounce_timer = 0
        if self._trash_timer:
            GLib.source_remove(self._trash_timer)
            self._trash_timer = 0
        if self.monitor:
            self.monitor.cancel()
        if self.trash_monitor:
            self.trash_monitor.cancel()


################################################################################
# GLOBAL DRAG & DROP HANDLERS
# Functions to handle data dropped directly onto the main window/grid.
################################################################################

def on_drag_data_received(widget, drag_context, x, y, data, info, time):
    layout = getattr(widget, 'layout_container', None)
    if layout is not None:
        layout.clear_drop_target()

    uris = data.get_uris()
    if not uris:
        Gtk.drag_finish(drag_context, False, False, time)
        return

    desktop_dir = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DESKTOP)
    if not desktop_dir:
        desktop_dir = os.path.join(GLib.get_home_dir(), "Desktop")
    desktop_file = Gio.File.new_for_path(desktop_dir)

    top_margin = layout.top_margin() if layout is not None else 0
    monitor_key = layout.monitor_key if layout is not None else "default"
    cols = layout.cols if layout is not None else 1
    rows = layout.rows if layout is not None else 1
    effective_map = layout._effective_positions if layout is not None else {}

    multi_paths = getattr(widget, '_multi_drag_paths', None)
    multi_origin = getattr(widget, '_multi_drag_origin', None)
    widget._multi_drag_paths = None
    widget._multi_drag_origin = None

    _, reserved_cells = get_special_cell_slots(cols, rows, GRID_DIRECTION)

    if multi_paths and multi_origin:
        widget._internal_drop_handled = True

        if AUTO_ARRANGE:
            Gtk.drag_finish(drag_context, False, False, time)
            return

        raw_positions = load_positions()
        saved_map = extract_monitor_positions(raw_positions, monitor_key)
        base_col, base_row = get_grid_pos(x, y, top_margin)
        dragged_keys = [os.path.basename(p) for p in multi_paths if p]
        origin_key = os.path.basename(multi_origin)
        updated_map = resolve_internal_drop(
            saved_map, dragged_keys, origin_key, base_col, base_row,
            cols, rows, GRID_DIRECTION, current_effective=effective_map, reserved_cells=reserved_cells,
        )
        save_positions(merge_monitor_positions(raw_positions, monitor_key, updated_map))
        if layout is not None:
            layout.reposition_icons()
        Gtk.drag_finish(drag_context, True, False, time)
        return

    success = False
    for uri in uris:
        if uri.startswith("virtual://"):
            widget._internal_drop_handled = True
            success = True
            continue

        if not uri.startswith("file://"):
            continue

        source_path = urllib.parse.unquote(uri[7:])
        source_file = Gio.File.new_for_path(source_path)

        if source_file.get_parent() and source_file.get_parent().get_path() == desktop_file.get_path():
            widget._internal_drop_handled = True

            if AUTO_ARRANGE:
                success = True
                continue

            filename = source_file.get_basename()
            raw_positions = load_positions()
            saved_map = extract_monitor_positions(raw_positions, monitor_key)
            col, row = get_grid_pos(x, y, top_margin)
            updated_map = resolve_internal_drop(
                saved_map, [filename], filename, col, row,
                cols, rows, GRID_DIRECTION, current_effective=effective_map, reserved_cells=reserved_cells,
            )
            save_positions(merge_monitor_positions(raw_positions, monitor_key, updated_map))
            if layout is not None:
                layout.reposition_icons()
            success = True
            continue

        dest_path = os.path.join(desktop_dir, os.path.basename(source_path))

        if os.path.exists(dest_path) or os.path.islink(dest_path):
            print(f"Skipped: {dest_path} already exists")
            continue

        is_folder = os.path.isdir(source_path)
        action_key, mode = resolve_external_drop_mode(source_path, is_folder)

        ok = apply_drop_in_action(mode, source_path, dest_path)
        if ok:
            if not is_folder and dest_path.endswith(".desktop"):
                _trust_desktop_shortcut(dest_path)
            print(f"[{action_key}={mode}] {source_path} -> {dest_path}")

            if not AUTO_ARRANGE:
                col, row = get_grid_pos(x, y, top_margin)
                if (min(max(0, col), cols - 1), min(max(0, row), rows - 1)) in reserved_cells:
                    occupied = set(reserved_cells)
                    for pos_tuple in effective_map.values():
                        occupied.add(pos_tuple)
                    col, row = find_nearest_free_cell(0, 0, cols, rows, occupied, GRID_DIRECTION)
                filename = os.path.basename(dest_path)
                raw_positions = load_positions()
                saved_map = extract_monitor_positions(raw_positions, monitor_key)
                updated_map = resolve_internal_drop(
                    saved_map, [filename], filename, col, row,
                    cols, rows, GRID_DIRECTION, current_effective=effective_map, reserved_cells=reserved_cells,
                )
                save_positions(merge_monitor_positions(raw_positions, monitor_key, updated_map))

            success = True
        elif mode == 'none':
            print(f"Skipped ({action_key}=none): {source_path}")
        else:
            print(f"Failed to apply '{mode}' for {action_key} on: {source_path}")

    Gtk.drag_finish(drag_context, success, False, time)

def on_drag_motion(widget, drag_context, x, y, time):
    if hasattr(widget, 'layout_container'):
        layout = widget.layout_container
        col, row = get_grid_pos(x, y, layout.top_margin())
        col = min(col, layout.cols - 1)
        row = min(row, layout.rows - 1)
        _, reserved_cells = get_special_cell_slots(layout.cols, layout.rows, GRID_DIRECTION)
        if (col, row) in reserved_cells:
            layout.clear_drop_target()
        else:
            layout.set_drop_target(col, row)
    return False

def on_drag_leave(widget, drag_context, time):
    if hasattr(widget, 'layout_container'):
        widget.layout_container.clear_drop_target()


################################################################################
# APPLICATION INITIALIZATION
# Setup windows for all monitors and start the main GTK application.
################################################################################

def create_desktop_window(app, monitor):
    window = Gtk.ApplicationWindow(application=app)
    window.set_title("desktop-icons")
    window.set_app_paintable(True)
    window.set_wmclass("desktop-icons", "desktop-icons")
    
    GtkLayerShell.init_for_window(window)
    GtkLayerShell.set_namespace(window, "desktop-icons")
    GtkLayerShell.set_monitor(window, monitor)
    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.BOTTOM)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.BOTTOM, True)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.LEFT, True)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.RIGHT, True)
    
    try:
        GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.ON_DEMAND)
    except AttributeError:
        GtkLayerShell.set_keyboard_interactivity(window, True)

    screen = window.get_screen()
    visual = screen.get_rgba_visual()
    if visual:
        window.set_visual(visual)
    
    css_provider_window = Gtk.CssProvider()
    css_provider_window.load_from_data(b"window { background: transparent; }")
    context = window.get_style_context()
    context.add_provider(css_provider_window, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def clear_background(widget, cr):
        cr.save()
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.restore()
        return False

    window.connect("draw", clear_background)

    window.drag_dest_set(Gtk.DestDefaults.MOTION | Gtk.DestDefaults.DROP, [], Gdk.DragAction.COPY | Gdk.DragAction.MOVE)
    window.drag_dest_add_uri_targets()
    window.connect("drag-data-received", on_drag_data_received)
    window.connect("drag-motion", on_drag_motion)
    window.connect("drag-leave", on_drag_leave)

    layout = DesktopLayout(window, monitor=monitor)
    window.layout_container = layout
    window.add(layout)
    window.connect("key-press-event", layout.on_key_press)

    app.layouts.append(layout)

    window.show_all()
    return window

def add_unix_signal(sig, callback):
    """Register a GLib mainloop signal handler without deprecation warnings."""
    if GLibUnix is not None and hasattr(GLibUnix, "signal_add"):
        return GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, sig, callback)
    return GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, callback)


def apply_desktop_css(app):
    screen = Gdk.Screen.get_default()
    if not screen:
        return
    try:
        new_provider = Gtk.CssProvider()
        new_provider.load_from_data(build_desktop_css().encode('utf-8'))
        old_provider = getattr(app, '_css_provider', None)
        if old_provider is not None:
            Gtk.StyleContext.remove_provider_for_screen(screen, old_provider)
        app._css_provider = new_provider
        Gtk.StyleContext.add_provider_for_screen(
            screen, new_provider, DESKTOP_CSS_PRIORITY
        )
        Gtk.StyleContext.reset_widgets(screen)
    except GLib.Error as err:
        print(f"[desktop-icons] Failed loading CSS: {err}", file=sys.stderr)


PIN_ID_PATTERN = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.+\-]*$")


def resolve_pinned_ctl():
    """Locate pinned_apps_ctl.py in bin_dir() or alongside this module."""
    candidates = [
        bin_dir() / "pinned_apps_ctl.py",
        Path(__file__).resolve().parent / "pinned_apps_ctl.py",
    ]
    for path in candidates:
        if path.is_file():
            return path
    return None


def resolve_pins_path():
    """Return path to the shared taskbar-pin-apps JSONC config."""
    override = os.environ.get("HAKUSPACE_PINS_FILE")
    if override:
        return Path(os.path.expanduser(override))
    return Path(os.path.expanduser("~/hakucfg/config/taskbar-pin-apps"))


def _strip_jsonc(text):
    """Strip // and /* */ comments outside JSON strings."""
    out = []
    i = 0
    n = len(text)
    in_str = False
    escaped = False
    while i < n:
        ch = text[i]
        if in_str:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            i += 2
            while i < n and text[i] not in ("\r", "\n"):
                i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def parse_pinned_ids_from_text(text):
    """Parse lowercase pinned app IDs from taskbar-pin-apps JSONC text."""
    if not text or not text.strip():
        return set()
    try:
        data = json.loads(_strip_jsonc(text))
    except Exception:
        return set()
    if not isinstance(data, list):
        return set()
    ids = set()
    for entry in data:
        if isinstance(entry, dict):
            val = entry.get("id")
            if isinstance(val, str) and val.strip():
                ids.add(val.strip().lower())
    return ids


def load_pinned_ids():
    """Load current pinned app IDs from disk or pinned_apps_ctl.py."""
    pins_file = resolve_pins_path()
    if pins_file.is_file():
        try:
            return parse_pinned_ids_from_text(pins_file.read_text(encoding="utf-8"))
        except OSError:
            pass
    ctl = resolve_pinned_ctl()
    if ctl is not None:
        try:
            res = subprocess.run(
                [sys.executable, str(ctl), "list"],
                capture_output=True,
                text=True,
                timeout=2,
            )
            if res.returncode == 0 and res.stdout:
                return parse_pinned_ids_from_text(res.stdout)
        except Exception:
            pass
    return set()


def resolve_desktop_pin_id(filepath, app_info=None):
    """Extract a valid pinned_apps_ctl ID for a .desktop file, or None."""
    candidates = []
    if filepath:
        base = os.path.basename(filepath)
        if base.endswith(".desktop"):
            candidates.append(base[:-8])
    if app_info is not None:
        try:
            app_id = app_info.get_id()
            if app_id:
                candidates.append(app_id[:-8] if app_id.endswith(".desktop") else app_id)
        except Exception:
            pass
    for cand in candidates:
        cand = cand.strip()
        if cand and PIN_ID_PATTERN.match(cand):
            return cand
    return None


def run_pinned_ctl(action, app_id, on_done=None):
    """Invoke pinned_apps_ctl.py asynchronously to add or remove a pinned app."""
    ctl = resolve_pinned_ctl()
    if ctl is None or not app_id:
        if on_done is not None:
            on_done(False)
        return
    try:
        proc = Gio.Subprocess.new(
            [sys.executable, str(ctl), action, app_id],
            Gio.SubprocessFlags.STDERR_PIPE,
        )
    except GLib.Error as err:
        print(f"[desktop-icons] Failed running pinned_apps_ctl.py: {err}", file=sys.stderr)
        if on_done is not None:
            on_done(False)
        return

    def _finished(subproc, result):
        ok = False
        try:
            subproc.wait_check_finish(result)
            ok = True
        except GLib.Error as err:
            print(f"[desktop-icons] pinned_apps_ctl {action} failed: {err}", file=sys.stderr)
        if on_done is not None:
            on_done(ok)

    proc.wait_check_async(None, _finished)


def open_path_default(target):
    """Open a local path or URI with the desktop's default handler."""
    if not target:
        return
    uri = target if "://" in target else Path(os.path.realpath(target) if os.path.islink(target) else target).as_uri()
    try:
        Gio.AppInfo.launch_default_for_uri(uri, None)
        return
    except GLib.Error:
        pass
    spawn_detached(["xdg-open", target])


def resolve_terminal_cmd(cwd=None, command_args=None, env=None, which_fn=shutil.which):
    """Resolve terminal argv and working directory respecting $TERMINAL and native terms."""
    env_map = os.environ if env is None else env
    custom = (env_map.get("TERMINAL") or "").strip()
    if custom:
        parts = shlex.split(custom)
        if parts and (which_fn(parts[0]) or os.path.isfile(parts[0])):
            term_name = os.path.basename(parts[0]).lower()
            argv = list(parts)
            if command_args:
                exec_flag = "--" if term_name in ("kitty", "foot", "gnome-terminal") else "-e"
                argv.extend([exec_flag, *command_args])
            return argv, cwd

    specs = (
        ("kitty", "--directory", "--"),
        ("foot", "--working-directory", "--"),
        ("alacritty", "--working-directory", "-e"),
        ("xfce4-terminal", "--working-directory", "-x"),
        ("gnome-terminal", "--working-directory", "--"),
        ("x-terminal-emulator", None, "-e"),
    )
    for binary, cwd_flag, exec_flag in specs:
        if which_fn(binary):
            argv = [binary]
            if cwd and cwd_flag:
                argv.extend([cwd_flag, cwd])
            if command_args:
                argv.extend([exec_flag, *command_args])
            return argv, cwd

    if which_fn("wezterm"):
        argv = ["wezterm", "start"]
        if cwd:
            argv.extend(["--cwd", cwd])
        if command_args:
            argv.extend(["--", *command_args])
        return argv, cwd

    if which_fn("exo-open"):
        if command_args:
            return ["exo-open", "--launch", "TerminalEmulator", *command_args], cwd
        if cwd:
            return ["exo-open", "--working-directory", cwd, "--launch", "TerminalEmulator"], cwd
        return ["exo-open", "--launch", "TerminalEmulator"], cwd

    return None


def build_workspace_menu_spec(backend=None):
    """Return declarative Space submenu specification for the active shell backend."""
    mode = backend or read_shell_backend()
    if mode == "classic":
        return [
            {"id": "appbar", "label": "AppBar", "kind": "check", "cmd": ["appbar_ctl.sh", "--toggle"], "probe": ("script_status", "appbar_ctl.sh")},
            {"id": "waybar", "label": "Waybar", "kind": "check", "cmd": ["statusbar_manager.sh", "--toggle"], "probe": ("waybar",)},
            {"id": "cava", "label": "Cava Underbar", "kind": "check", "cmd": ["cava_manager.sh", "toggle"], "probe": ("script_status", "cava_manager.sh")},
            {"kind": "separator"},
            {"id": "theme", "label": "Change Color Scheme", "kind": "action", "cmd": ["change_theme.sh"]},
            {"id": "wallpaper", "label": "Change Wallpaper", "kind": "action", "cmd": ["wallpaper_select.sh"]},
            {"id": "random_wallpaper", "label": "Random Wallpaper", "kind": "check", "cmd": ["random_wallpaper.sh"], "probe": ("random_wallpaper",)},
        ]
    return [
        {"id": "taskbar", "label": "Taskbar", "kind": "check", "cmd": ["taskbar_ctl.sh", "--toggle"], "probe": ("script_status", "taskbar_ctl.sh")},
        {"id": "dockbar", "label": "Dockbar", "kind": "check", "cmd": ["dockbar_ctl.sh", "--toggle"], "probe": ("script_status", "dockbar_ctl.sh")},
        {"id": "statusbar", "label": "Cycle Status Bar", "kind": "action", "cmd": ["statusbar_manager.sh", "--cycle"]},
        {"id": "cava", "label": "Cava Underbar", "kind": "check", "cmd": ["cava_manager.sh", "toggle"], "probe": ("script_status", "cava_manager.sh")},
        {"kind": "separator"},
        {"id": "theme", "label": "Appearance & Theme", "kind": "action", "cmd": ["change_theme.sh"]},
        {"id": "accent", "label": "Accent Color Picker", "kind": "action", "cmd": ["accent_color_picker.sh"]},
        {"id": "wallpaper", "label": "Change Wallpaper", "kind": "action", "cmd": ["wallpaper_select.sh"]},
        {"id": "random_wallpaper", "label": "Random Wallpaper", "kind": "check", "cmd": ["random_wallpaper.sh"], "probe": ("random_wallpaper",)},
    ]


def _probe_workspace_item_active(probe):
    """Evaluate checked state for a declarative Space submenu entry."""
    if not probe:
        return False
    kind = probe[0]
    if kind == "script_status":
        script = bin_dir() / probe[1]
        if not script.exists():
            return False
        try:
            res = subprocess.run([str(script), "--status"], capture_output=True, text=True, timeout=1.5)
            return res.returncode == 0 and res.stdout.strip().lower() == "enabled"
        except Exception:
            return False
    if kind == "waybar":
        try:
            return subprocess.run(["pgrep", "-x", "waybar"], capture_output=True, timeout=1).returncode == 0
        except Exception:
            return False
    if kind == "random_wallpaper":
        try:
            return Path("/tmp/random_wallpaper_status").read_text(encoding="utf-8").strip() == "1"
        except OSError:
            return False
    return False


class PinWatcher:
    """Watch taskbar-pin-apps so desktop pin badges stay synchronized."""

    def __init__(self, on_change):
        self._on_change = on_change
        self._timer_id = 0
        self._monitor = None
        self.pinned_ids = load_pinned_ids()
        pins_file = resolve_pins_path()
        try:
            if pins_file.parent.is_dir():
                mon = Gio.File.new_for_path(str(pins_file.parent)).monitor_directory(Gio.FileMonitorFlags.NONE, None)
                mon.connect("changed", self._handle)
                self._monitor = mon
        except GLib.Error:
            pass

    def _handle(self, _mon, file, _other, event_type):
        if file and file.get_basename() != resolve_pins_path().name:
            return
        if event_type in (
            Gio.FileMonitorEvent.CHANGED,
            Gio.FileMonitorEvent.CHANGES_DONE_HINT,
            Gio.FileMonitorEvent.CREATED,
            Gio.FileMonitorEvent.DELETED,
            Gio.FileMonitorEvent.MOVED_IN,
            Gio.FileMonitorEvent.MOVED_OUT,
        ):
            if self._timer_id:
                GLib.source_remove(self._timer_id)
            self._timer_id = GLib.timeout_add(80, self._fire)

    def _fire(self):
        self._timer_id = 0
        self.refresh_now()
        return GLib.SOURCE_REMOVE

    def refresh_now(self):
        self.pinned_ids = load_pinned_ids()
        self._on_change(self.pinned_ids)

    def shutdown(self):
        if self._timer_id:
            GLib.source_remove(self._timer_id)
            self._timer_id = 0
        if self._monitor is not None:
            self._monitor.cancel()
            self._monitor = None


class ThemeWatcher:
    """Watch Hikai/Classic theme and backend files for live CSS refresh."""

    def __init__(self, on_change):
        self._on_change = on_change
        self._timer_id = 0
        self._monitors = []
        targets = (
            Path(os.path.expanduser(os.environ.get("HAKUSPACE_QUICKSHELL_THEME") or "~/.local/state/hakuspace/theme/quickshell.json")),
            Path(os.path.expanduser(os.environ.get("HAKUSPACE_HIKAI_SETTINGS_FILE") or "~/hakucfg/hikai/hikai-shell.json")),
            Path(os.path.expanduser(os.environ.get("HAKUSPACE_CLASSIC_PALETTE") or "~/.local/state/hakuspace/theme/classic/palette.css")),
            Path(os.path.expanduser(os.environ.get("HAKUSPACE_THEME_FONTS") or "~/.local/state/hakuspace/theme/fonts.css")),
            state_path("shell.backend"),
        )
        by_dir = {}
        for path in targets:
            by_dir.setdefault(path.parent, set()).add(path.name)
        for directory, names in by_dir.items():
            if not directory.is_dir():
                continue
            try:
                mon = Gio.File.new_for_path(str(directory)).monitor_directory(Gio.FileMonitorFlags.NONE, None)
                mon.connect("changed", lambda _m, f, _o, ev, allowed=names: self._handle(f, ev, allowed))
                self._monitors.append(mon)
            except GLib.Error:
                pass
        cava_pid = os.environ.get("HAKUSPACE_CAVA_PIDFILE") or "/tmp/cava-layer.pid"
        try:
            cava_mon = Gio.File.new_for_path(cava_pid).monitor_file(Gio.FileMonitorFlags.NONE, None)
            cava_mon.connect("changed", lambda _m, _f, _o, ev: self._handle_cava(ev))
            self._monitors.append(cava_mon)
        except GLib.Error:
            pass

    def _handle_cava(self, event_type):
        if event_type in (
            Gio.FileMonitorEvent.CHANGED,
            Gio.FileMonitorEvent.CHANGES_DONE_HINT,
            Gio.FileMonitorEvent.CREATED,
            Gio.FileMonitorEvent.DELETED,
            Gio.FileMonitorEvent.MOVED_IN,
            Gio.FileMonitorEvent.MOVED_OUT,
        ):
            if self._timer_id:
                GLib.source_remove(self._timer_id)
            self._timer_id = GLib.timeout_add(80, self._fire)

    def _handle(self, file, event_type, allowed):
        if file and file.get_basename() not in allowed:
            return
        if event_type in (
            Gio.FileMonitorEvent.CHANGED,
            Gio.FileMonitorEvent.CHANGES_DONE_HINT,
            Gio.FileMonitorEvent.CREATED,
            Gio.FileMonitorEvent.MOVED_IN,
        ):
            if self._timer_id:
                GLib.source_remove(self._timer_id)
            self._timer_id = GLib.timeout_add(80, self._fire)

    def _fire(self):
        self._timer_id = 0
        self._on_change()
        return GLib.SOURCE_REMOVE

    def shutdown(self):
        if self._timer_id:
            GLib.source_remove(self._timer_id)
            self._timer_id = 0
        for mon in self._monitors:
            mon.cancel()
        self._monitors.clear()


def reconcile_monitors(app):
    """Synchronize Desktop windows with active monitors and MONITOR_MODE."""
    display = Gdk.Display.get_default()
    if display is None:
        return
    wanted = select_active_monitors(display, MONITOR_MODE)
    win_map = getattr(app, '_monitor_windows', None)
    if win_map is None:
        win_map = {}
        app._monitor_windows = win_map

    wanted_set = set(wanted)
    for monitor in list(win_map.keys()):
        if monitor not in wanted_set:
            win = win_map.pop(monitor)
            layout = getattr(win, 'layout_container', None)
            if layout is not None:
                if layout in app.layouts:
                    app.layouts.remove(layout)
            win.destroy()

    manager = getattr(app, 'manager', None)
    for monitor in wanted:
        if monitor not in win_map:
            win = create_desktop_window(app, monitor)
            win_map[monitor] = win
            if manager is not None:
                manager.sync_layout(win.layout_container)


def _refresh_all_pin_badges(app, pinned_ids=None):
    """Synchronize pin badges across every active layout."""
    watcher = getattr(app, '_pin_watcher', None)
    ids = watcher.pinned_ids if (pinned_ids is None and watcher is not None) else (pinned_ids or set())
    for layout in getattr(app, 'layouts', []):
        layout.refresh_pin_badges(ids)


def hot_reload_app(app):
    load_config()
    apply_desktop_css(app)
    reconcile_monitors(app)
    manager = getattr(app, 'manager', None)
    if manager is not None:
        manager.reload_from_config()
    watcher = getattr(app, '_pin_watcher', None)
    if watcher is not None:
        watcher.refresh_now()
    else:
        _refresh_all_pin_badges(app)
    for layout in getattr(app, 'layouts', []):
        layout.queue_draw()
    print("[desktop-icons] Hot-reloaded desktop icons", flush=True)


def _cleanup_resources(app):
    if getattr(app, '_cleaned_up', False):
        return
    app._cleaned_up = True
    theme_watcher = getattr(app, '_theme_watcher', None)
    if theme_watcher is not None:
        theme_watcher.shutdown()
    pin_watcher = getattr(app, '_pin_watcher', None)
    if pin_watcher is not None:
        pin_watcher.shutdown()
    manager = getattr(app, 'manager', None)
    if manager is not None:
        manager.shutdown()
    if _THUMBNAIL_SERVICE is not None:
        _THUMBNAIL_SERVICE.shutdown()
    _THUMB_EXECUTOR.shutdown(wait=False, cancel_futures=True)
    _IO_EXECUTOR.shutdown(wait=False, cancel_futures=True)


def shutdown_app(app):
    _cleanup_resources(app)
    app.quit()


def on_activate(app):
    if getattr(app, '_activated', False):
        return
    app._activated = True
    app._cleaned_up = False
    app.layouts = []
    app._monitor_windows = {}
    app._css_provider = None
    app.hot_reload = lambda: hot_reload_app(app)

    apply_desktop_css(app)

    display = Gdk.Display.get_default()
    reconcile_monitors(app)
    if display is not None:
        display.connect("monitor-added", lambda *_args: reconcile_monitors(app))
        display.connect("monitor-removed", lambda *_args: reconcile_monitors(app))

    app.manager = DesktopManager(app.layouts)
    app._pin_watcher = PinWatcher(lambda ids: _refresh_all_pin_badges(app, ids))
    _refresh_all_pin_badges(app, app._pin_watcher.pinned_ids)
    app._theme_watcher = ThemeWatcher(lambda: hot_reload_app(app))

    def _on_reload_signal(*_args):
        hot_reload_app(app)
        return GLib.SOURCE_CONTINUE

    def _on_exit_signal(*_args):
        shutdown_app(app)
        return GLib.SOURCE_REMOVE

    add_unix_signal(signal.SIGUSR1, _on_reload_signal)
    add_unix_signal(signal.SIGINT, _on_exit_signal)
    add_unix_signal(signal.SIGTERM, _on_exit_signal)
    app.connect("shutdown", _cleanup_resources)

    print("[desktop-icons] Desktop icons configured", flush=True)


if __name__ == '__main__':
    GLib.set_prgname('desktop-icons')
    app = Gtk.Application(application_id='org.desktop_icons.desktop')
    app.connect('activate', on_activate)
    status = app.run(sys.argv)
    sys.exit(status)