#!/usr/bin/env python3
import os
import re
import sys
import signal
import argparse
import gi
import shutil

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

# based on wallpaper, best with dark wallpaper
# foreground = white
"""

KITTY_CONFIG_PATH = "~/.config/kitty/kitty.conf"


def ensure_config_exists(config_path):
    """Create a default cava-layer config at config_path if none exists yet."""
    if os.path.exists(config_path):
        return
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, 'w') as f:
        f.write(DEFAULT_CONFIG_TEMPLATE)
    print(f"[cava-layer] No config found at '{config_path}', created a default one.")


_KITTY_COLOR_KEYS = ["foreground", "background", "cursor", "cursor_text_color",
                     "selection_foreground", "selection_background"]
_KITTY_PALETTE_KEYS = [f"color{i}" for i in range(16)]


def _read_kitty_lines(path, visited=None):
    """
    Recursively expand a kitty config file, inlining any `include <path>`
    directives in place -- matching kitty's own behaviour where later
    directives (including ones pulled in via include) override earlier ones.
    A relative include path is resolved against the directory of the file
    that references it, same as kitty does. Missing/unreadable includes are
    skipped rather than failing the whole parse. Circular includes are guarded
    against via `visited`.
    """
    if visited is None:
        visited = set()

    real_path = os.path.realpath(os.path.expanduser(path))
    if real_path in visited or not os.path.isfile(real_path):
        return []
    visited.add(real_path)

    try:
        with open(real_path, 'r') as f:
            raw_lines = f.readlines()
    except OSError as e:
        print(f"[cava-layer] Could not read kitty config '{real_path}': {e}", file=sys.stderr)
        return []

    file_dir = os.path.dirname(real_path)
    expanded = []
    for raw_line in raw_lines:
        stripped = raw_line.strip()
        if stripped.startswith('include ') or stripped.startswith('include\t'):
            inc_path = stripped.split(None, 1)[1].strip()
            expanded_inc = os.path.expanduser(inc_path)
            if not os.path.isabs(expanded_inc):
                inc_path = os.path.join(file_dir, inc_path)
            expanded.extend(_read_kitty_lines(inc_path, visited))
        else:
            expanded.append(raw_line)
    return expanded


def parse_kitty_config(config_path):
    """
    Minimal parser for kitty.conf and anything it `include`s. Returns a dict
    with any of: font_family (str), font_size (float),
    foreground/background/cursor (str hex), palette (list of up to 16 hex
    strings, colorN -> palette[N]). Unsupported directives (map, etc.) are
    ignored. Returns {} if the file (and its includes) can't be found/parsed.
    """
    result = {}
    palette = [None] * 16

    lines = _read_kitty_lines(config_path)
    if not lines:
        return result

    for raw_line in lines:
        line = raw_line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        key, value = parts[0].strip(), parts[1].strip()

        if key == "font_family":
            result["font_family"] = value
        elif key == "font_size":
            try:
                result["font_size"] = float(value)
            except ValueError:
                pass
        elif key in _KITTY_COLOR_KEYS:
            if re.match(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$', value):
                result[key] = value
        elif key in _KITTY_PALETTE_KEYS:
            if re.match(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$', value):
                idx = int(key[len("color"):])
                if 0 <= idx < 16:
                    palette[idx] = value

    if any(c is not None for c in palette):
        result["palette"] = palette

    return result


def apply_kitty_theme(terminal, kitty_config):
    """Apply parsed kitty.conf colors onto a Vte.Terminal, best-effort."""
    fg_hex = kitty_config.get("foreground")
    bg_hex = None  # background stays transparent for the overlay bar regardless of kitty
    cursor_hex = kitty_config.get("cursor")
    palette_hex = kitty_config.get("palette")

    def to_rgba(hex_str, alpha=1.0):
        rgba = Gdk.RGBA()
        rgba.parse(hex_str)
        rgba.alpha = alpha
        return rgba

    fg = to_rgba(fg_hex) if fg_hex else None
    cursor = to_rgba(cursor_hex) if cursor_hex else None
    palette = None
    if palette_hex:
        palette = [to_rgba(c) if c else None for c in palette_hex]
        # Vte requires a full 0/8/16/24/256-length palette without holes;
        # fall back to None (skip custom palette) if any slot is missing.
        if any(c is None for c in palette):
            palette = None

    try:
        terminal.set_colors(fg, Gdk.RGBA(0, 0, 0, 0), palette or [])
    except GLib.Error as e:
        print(f"[cava-layer] Failed applying kitty colors: {e}", file=sys.stderr)

    if cursor:
        try:
            terminal.set_color_cursor(cursor)
        except Exception:
            pass


class CavaLayerApp:
    """
    Runs `cava -p <config>` inside an embedded VTE terminal, shown as a
    transparent, always-on-top (OVERLAY layer) bar anchored to the top of
    the screen. cava itself handles bar_width, bar_spacing, colors,
    orientation, etc. exactly as it would in a normal terminal -- this
    script only positions and hosts it.
    """

    def __init__(self, config_path, window_height=80, font_size=5, app_name="cava-layer"):
        self.config_path = os.path.expanduser(config_path)
        self.window_height = window_height
        self.font_size = font_size
        self.app_name = app_name
        self.cava_pid = None

        # Bar colors always track ~/.config/kitty/kitty.conf (following its
        # `include`s, e.g. kitty-style.conf) -- font size and window height
        # are unaffected by kitty and stay at their own defaults/CLI values.
        kitty_path = os.path.expanduser(KITTY_CONFIG_PATH)
        self.kitty_theme = parse_kitty_config(kitty_path)
        if self.kitty_theme:
            print(f"[cava-layer] Loaded kitty colors from '{kitty_path}'.")
        else:
            print(f"[cava-layer] No usable kitty config found at '{kitty_path}', using default colors.")

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
        if self.kitty_theme:
            apply_kitty_theme(self.terminal, self.kitty_theme)
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
            print(
                "[cava-layer] ERROR: 'cava' was not found in PATH.",
                file=sys.stderr,
            )
            print(
                "[cava-layer] Check with: which cava",
                file=sys.stderr,
            )
            return

        argv = [cava, '-p', self.config_path]

        def on_spawn(terminal, pid, error, user_data):
            if error:
                print(
                    f"[cava-layer] Failed to launch cava: {error}",
                    file=sys.stderr
                )
                return

            self.cava_pid = pid
            print(
                f"[cava-layer] Launched '{cava} -p {self.config_path}' "
                f"(pid={pid})"
            )

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

    def reload_kitty_theme(self):
        """
        Re-read ~/.config/kitty/kitty.conf (following any `include`s, e.g.
        kitty-style.conf) and live-apply its colors to the embedded
        terminal, without touching cava's own process, config file, font
        size, or window height.

        This works because cava's ncurses output draws using logical
        terminal color slots (e.g. `foreground = white` means "ANSI slot
        7/15"), redrawn continuously. Once VTE's palette for that slot
        changes, the very next frame cava draws comes out in the new color --
        no restart needed. Call this (e.g. via SIGUSR1) whenever the kitty
        theme changes, such as at the end of your style-switching script.
        """
        kitty_path = os.path.expanduser(KITTY_CONFIG_PATH)
        theme = parse_kitty_config(kitty_path)
        if not theme:
            print(f"[cava-layer] Reload: no usable kitty config at '{kitty_path}', keeping current colors.")
            return

        self.kitty_theme = theme
        apply_kitty_theme(self.terminal, self.kitty_theme)
        print(f"[cava-layer] Reloaded kitty colors from '{kitty_path}'.")

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
                     "the same as running `cava -p <config>` in a terminal. "
                     "Send SIGUSR1 to this process to live-reload bar colors "
                     "from the kitty config without restarting cava."
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
        app.reload_kitty_theme()
        return GLib.SOURCE_CONTINUE  # keep listening for future reloads

    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, on_reload_signal)

    Gtk.main()


if __name__ == "__main__":
    main()