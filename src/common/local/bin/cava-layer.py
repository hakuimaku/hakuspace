#!/usr/bin/env python3
import os
import sys
import signal
import argparse
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
gi.require_version('Vte', '2.91')
gi.require_version('Pango', '1.0')
from gi.repository import Gtk, GLib, Gdk, GtkLayerShell, Vte, Pango


DEFAULT_CONFIG_TEMPLATE = """[general]
bar_width = 6
bar_spacing = 1

[output]
method = ncurses
orientation = top

[color]
# Uncomment & comment one of the following lines to change the bar color
foreground = black
#foreground = white # based on wallpaper, best with dark wallpaper
"""


def ensure_config_exists(config_path):
    """Create a default cava-layer config at config_path if none exists yet."""
    if os.path.exists(config_path):
        return
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, 'w') as f:
        f.write(DEFAULT_CONFIG_TEMPLATE)
    print(f"[cava-layer] No config found at '{config_path}', created a default one.")


class CavaLayerApp:
    """
    Runs `cava -p <config>` inside an embedded VTE terminal, shown as a
    transparent, always-on-top (OVERLAY layer) bar anchored to the top of
    the screen. cava itself handles bar_width, bar_spacing, colors,
    orientation, etc. exactly as it would in a normal terminal -- this
    script only positions and hosts it.
    """

    def __init__(self, config_path, window_height=80, font_size=5):
        self.config_path = os.path.expanduser(config_path)
        self.window_height = window_height
        self.font_size = font_size
        self.cava_pid = None

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
        self.window.set_title("Cava Layer")
        self.window.set_decorated(False)
        self.window.set_resizable(False)
        self.window.set_border_width(0)

        screen = self.window.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.window.set_visual(visual)
        self.window.set_app_paintable(True)

        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.RIGHT, True)

        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_margin(self.window, edge, 0)
        GtkLayerShell.set_exclusive_zone(self.window, -1)
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

        argv = ['cava', '-p', self.config_path]

        def on_spawn(terminal, pid, error, user_data):
            if error:
                print(f"[cava-layer] Failed to launch cava: {error}", file=sys.stderr)
                return
            self.cava_pid = pid
            print(f"[cava-layer] Launched 'cava -p {self.config_path}' (pid={pid})")

        self.terminal.spawn_async(
            Vte.PtyFlags.DEFAULT,
            None,
            argv,
            None,
            GLib.SpawnFlags.DEFAULT,
            None, None,
            -1,
            None,
            on_spawn,
            None,
        )
        self.terminal.connect("child-exited", self.on_cava_exited)

    def on_cava_exited(self, terminal, status):
        print(f"[cava-layer] cava exited with status {status}", file=sys.stderr)

    def cleanup(self, *args):
        if self.cava_pid:
            try:
                os.kill(self.cava_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        Gtk.main_quit()


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run cava as a transparent Wayland layer-shell bar, "
                     "the same as running `cava -p <config>` in a terminal."
    )
    parser.add_argument(
        '-p', '--config',
        dest='config_path',
        default='~/.config/cava/cava-layer',
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
        help="Terminal font size in points (default: 5). Lower this further (e.g. 3-4) for a thinner look, or raise it for bigger bars."
    )
    return parser.parse_args()


def main():
    args = parse_args()
    app = CavaLayerApp(
        config_path=args.config_path,
        window_height=args.window_height,
        font_size=args.font_size,
    )

    def signal_handler(sig, frame):
        app.cleanup()

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    Gtk.main()


if __name__ == "__main__":
    main()