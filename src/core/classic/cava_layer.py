#!/usr/bin/env python3
import argparse
import os
import re
import shutil
import signal
import sys

import gi

gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
gi.require_version('Vte', '2.91')
gi.require_version('Pango', '1.0')
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell, Vte, Pango


DEFAULT_CONFIG_TEMPLATE = """[general]
bar_width = 6
bar_spacing = 1

[output]
method = ncurses
orientation = top

[color]
foreground = white
"""

CLASSIC_PALETTE_PATH = "~/.local/state/hakuspace/theme/classic/palette.css"
FALLBACK_BAR_COLOR = "#b8b8b8"
_DEFINE_COLOR_RE = re.compile(r"^\s*@define-color\s+([a-zA-Z0-9_]+)\s+(#[0-9a-fA-F]{6})\s*;")


def ensure_config_exists(config_path):
    """Create a default cava-layer config at config_path if none exists yet."""
    if os.path.exists(config_path):
        return
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, 'w', encoding='utf-8') as f:
        f.write(DEFAULT_CONFIG_TEMPLATE)
    print(f"[cava-layer] No config found at '{config_path}', created a default one.")


def parse_classic_palette(palette_path):
    """Read GTK @define-color tokens from Classic palette.css."""
    expanded = os.path.realpath(os.path.expanduser(palette_path))
    if not os.path.isfile(expanded):
        return {}
    tokens = {}
    try:
        with open(expanded, 'r', encoding='utf-8') as f:
            for line in f:
                match = _DEFINE_COLOR_RE.match(line)
                if match:
                    tokens[match.group(1)] = match.group(2)
    except OSError as e:
        print(f"[cava-layer] Could not read palette '{expanded}': {e}", file=sys.stderr)
    return tokens


def resolve_scheme_bar_color(palette_path):
    """Select the active Classic scheme foreground color for Cava bars."""
    tokens = parse_classic_palette(palette_path)
    return tokens.get("select_bg") or tokens.get("title_bg") or FALLBACK_BAR_COLOR


def apply_scheme_theme(terminal, hex_color):
    """Apply a solid scheme color across all VTE ANSI slots with a transparent background."""
    fg = Gdk.RGBA()
    if not fg.parse(hex_color):
        fg.parse(FALLBACK_BAR_COLOR)
    fg.alpha = 1.0
    bg = Gdk.RGBA(0, 0, 0, 0)
    palette = [fg] * 16

    try:
        terminal.set_colors(fg, bg, palette)
    except GLib.Error as e:
        print(f"[cava-layer] Failed applying scheme color '{hex_color}': {e}", file=sys.stderr)

    try:
        terminal.set_color_cursor(fg)
    except Exception:
        pass


class CavaLayerApp:
    """
    Runs `cava -p <config>` inside a standard VTE terminal layer-shell bar
    anchored to the top of the screen, colored directly from the active
    Classic scheme palette.
    """

    def __init__(self, config_path, window_height=80, font_size=5, app_name="cava-layer", palette_path=CLASSIC_PALETTE_PATH):
        self.config_path = os.path.expanduser(config_path)
        self.window_height = window_height
        self.font_size = font_size
        self.app_name = app_name
        self.palette_path = os.environ.get("HAKUSPACE_CLASSIC_PALETTE", palette_path)
        self.cava_pid = None

        self.bar_color = resolve_scheme_bar_color(self.palette_path)
        print(f"[cava-layer] Using Classic scheme color '{self.bar_color}' from '{os.path.expanduser(self.palette_path)}'.")

        self.setup_window()
        self.start_cava()

    def get_monitor_width(self):
        display = Gdk.Display.get_default()
        monitor = display.get_primary_monitor() or display.get_monitor(0)
        if monitor is not None:
            return monitor.get_geometry().width
        return 1920

    def setup_window(self):
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_title(self.app_name)
        self.window.set_wmclass(self.app_name, self.app_name)
        self.window.set_decorated(False)
        self.window.set_resizable(False)
        self.window.set_border_width(0)

        screen = self.window.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.window.set_visual(visual)
        self.window.set_app_paintable(True)

        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, self.app_name)
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.RIGHT, True)

        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_margin(self.window, edge, 0)

        GtkLayerShell.set_exclusive_zone(self.window, 0)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)

        self.window.set_size_request(-1, self.window_height)

        self.terminal = Vte.Terminal()
        self.terminal.set_color_background(Gdk.RGBA(0, 0, 0, 0))
        self.terminal.set_cursor_blink_mode(Vte.CursorBlinkMode.OFF)
        self.terminal.set_can_focus(False)
        self.terminal.set_scroll_on_output(False)
        self.terminal.set_hexpand(True)
        self.terminal.set_vexpand(True)

        self.terminal.set_font(Pango.FontDescription(f"Monospace {self.font_size}"))
        apply_scheme_theme(self.terminal, self.bar_color)
        if hasattr(self.terminal, "set_cell_height_scale"):
            self.terminal.set_cell_height_scale(1.0)
        if hasattr(self.terminal, "set_cell_width_scale"):
            self.terminal.set_cell_width_scale(1.0)

        char_height = self.terminal.get_char_height() or 1
        char_width = self.terminal.get_char_width() or 1
        rows = max(1, int(self.window_height // char_height))
        cols = max(1, int(self.get_monitor_width() // char_width))
        self.terminal.set_size(cols, rows)

        css = Gtk.CssProvider()
        css.load_from_data(b"window, vte-terminal { padding: 0; margin: 0; border: none; }")
        for widget in (self.window, self.terminal):
            widget.get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.window.add(self.terminal)
        self.window.connect("destroy", self.cleanup)
        self.window.show_all()

    def start_cava(self):
        ensure_config_exists(self.config_path)

        cava = shutil.which("cava")
        if not cava:
            print("[cava-layer] ERROR: 'cava' was not found in PATH.", file=sys.stderr)
            print("[cava-layer] Check with: which cava", file=sys.stderr)
            return

        argv = [cava, '-p', self.config_path]

        def on_spawn(terminal, pid, error, user_data):
            if error:
                print(f"[cava-layer] Failed to launch cava: {error}", file=sys.stderr)
                return
            self.cava_pid = pid
            print(f"[cava-layer] Launched '{cava} -p {self.config_path}' (pid={pid})")

        self.terminal.spawn_async(
            Vte.PtyFlags.DEFAULT,
            None,
            argv,
            None,
            GLib.SpawnFlags.DEFAULT,
            None,
            None,
            -1,
            None,
            on_spawn,
            None,
        )

        self.terminal.connect("child-exited", self.on_cava_exited)

    def on_cava_exited(self, terminal, status):
        print(f"[cava-layer] cava exited with status {status}", file=sys.stderr)

    def reload_scheme_theme(self):
        """Re-read Classic palette.css and update VTE colors without restarting cava."""
        color = resolve_scheme_bar_color(self.palette_path)
        self.bar_color = color
        apply_scheme_theme(self.terminal, self.bar_color)
        print(f"[cava-layer] Reloaded Classic scheme color '{self.bar_color}'.")

    def cleanup(self, *args):
        if self.cava_pid:
            try:
                os.kill(self.cava_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        Gtk.main_quit()


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run cava as a transparent Wayland layer-shell bar in a standard VTE terminal. "
                    "Send SIGUSR1 to live-reload colors from the Classic scheme palette."
    )
    parser.add_argument(
        '-p', '--config',
        dest='config_path',
        default='~/hakucfg/config/cava-layer',
        help="Path to a cava config file"
    )
    parser.add_argument(
        '-H', '--height',
        dest='window_height',
        type=int,
        default=80,
        help="Height in pixels of the layer-shell window (default: 80)."
    )
    parser.add_argument(
        '-F', '--font-size',
        dest='font_size',
        type=float,
        default=5,
        help="Terminal font size in points (default: 5)."
    )
    parser.add_argument(
        '-n', '--app-name',
        dest='app_name',
        default='cava-layer',
        help="Layer shell namespace / WM class name (default: cava-layer)."
    )
    return parser.parse_args()


def main():
    args = parse_args()
    app = CavaLayerApp(
        config_path=args.config_path,
        window_height=args.window_height,
        font_size=args.font_size,
        app_name=args.app_name,
    )

    def signal_handler(sig, frame):
        app.cleanup()

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    def on_reload_signal():
        app.reload_scheme_theme()
        return GLib.SOURCE_CONTINUE

    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, on_reload_signal)

    Gtk.main()


if __name__ == "__main__":
    main()
