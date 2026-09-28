#!/usr/bin/env python3
"""Hakuspace edge trigger app."""

import os
import sys
import json
import subprocess
import gi
import cairo

gi.require_version('Gtk', '3.0')
try:
    gi.require_version('GtkLayerShell', '0.1')
except ValueError:
    print("Error: GtkLayerShell is not installed.")
    sys.exit(1)

from gi.repository import Gtk, Gdk, GtkLayerShell, GLib

EDGE_TOP = 'top'
EDGE_BOTTOM = 'bottom'
EDGE_LEFT = 'left'
EDGE_RIGHT_UP = 'right_up'
EDGE_RIGHT_DOWN = 'right_down'

def get_gtk_edge(logical_edge):
    if logical_edge == EDGE_TOP: return GtkLayerShell.Edge.TOP
    if logical_edge == EDGE_BOTTOM: return GtkLayerShell.Edge.BOTTOM
    if logical_edge == EDGE_LEFT: return GtkLayerShell.Edge.LEFT
    return GtkLayerShell.Edge.RIGHT

# Configuration Variables (Edit here)
CONFIG = {
    'dwell_ms': 200,
    'cooldown_ms': 800,
    'edge_top_enable': True,
    'edge_bottom_enable': True,
    'edge_left_enable': False,
    'edge_right_up_enable': True,
    'edge_right_down_enable': True,
    'edge_top_cmd': '~/.local/bin/wallpaper_select.sh -e -location 2 -theme-str "window { border-radius: 0 0 20px 20px; }"',
    'edge_bottom_cmd': '~/.local/bin/hakumenu.sh -e -location 6 -theme-str "window { border-radius: 20px 20px 0 0; }"',
    'edge_left_cmd': '',
    'edge_right_up_cmd': 'swaync-client -t -sw',
    'edge_right_down_cmd': '~/.local/bin/shutdown.sh -v -e -location 3 -theme-str "window { border-radius: 0 0 0 20px; }"',
    'edge_size': 2,
    'edge_top_length_percent': 20,
    'edge_bottom_length_percent': 20,
    'edge_left_length_percent': 20,
    'edge_right_up_length_percent': 20,
    'edge_right_down_length_percent': 10,
}

SAFE_ZONES = {
    EDGE_TOP: (0.0, 0.0, 1.0, 0.6),
    EDGE_BOTTOM: (0.0, 0.4, 1.0, 0.6),
    EDGE_RIGHT_UP: (0.6 , 0.0, 0.4, 1.0),
    EDGE_RIGHT_DOWN: (0.85, 0.0, 0.15, 1.0),
    EDGE_LEFT: (0.0, 0.0, 0.25, 1.0),
}

# Hyprland grabs ALL pointer input for any layer surface with exclusive
# keyboard-interactivity (rofi included), regardless of input region.
# This is a known, still-open Hyprland bug (works fine on sway/niri) — the
# guard window's enter-notify simply never fires there. As a workaround,
# only on Hyprland we poll the compositor's own cursor position via hyprctl
# instead of waiting for a pointer event on our surface.
IS_HYPRLAND = bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))

last_trigger_times = {
    EDGE_TOP: 0,
    EDGE_BOTTOM: 0,
    EDGE_LEFT: 0,
    EDGE_RIGHT_UP: 0,
    EDGE_RIGHT_DOWN: 0
}

pending_timeouts = {
    EDGE_TOP: None,
    EDGE_BOTTOM: None,
    EDGE_LEFT: None,
    EDGE_RIGHT_UP: None,
    EDGE_RIGHT_DOWN: None
}

active_guards = {
    EDGE_TOP: None,
    EDGE_BOTTOM: None,
    EDGE_LEFT: None,
    EDGE_RIGHT_UP: None,
    EDGE_RIGHT_DOWN: None
}

def get_screen_geometry():
    display = Gdk.Display.get_default()
    monitor = display.get_monitor(0)
    if monitor:
        geo = monitor.get_geometry()
        return geo.width, geo.height
    return 1920, 1080

def compute_safe_rect_px(edge, screen_w, screen_h):
    frac_x, frac_y, frac_w, frac_h = SAFE_ZONES[edge]
    return (
        int(frac_x * screen_w),
        int(frac_y * screen_h),
        int(frac_w * screen_w),
        int(frac_h * screen_h)
    )

def kill_process(edge):
    try:
        if edge == EDGE_RIGHT_UP:
            subprocess.run(['swaync-client', '-cp'], check=False)
        else:
            subprocess.run(['pkill', '-x', 'rofi'], check=False)
    except Exception as e:
        print(f"Error killing process for {edge}: {e}")

def cleanup_guard(edge):
    guard_data = active_guards[edge]
    if guard_data:
        if guard_data.get('window'):
            guard_data['window'].destroy()
        if guard_data.get('liveness_id'):
            GLib.source_remove(guard_data['liveness_id'])
        if guard_data.get('timeout_id'):
            GLib.source_remove(guard_data['timeout_id'])
        if guard_data.get('cursor_poll_id'):
            GLib.source_remove(guard_data['cursor_poll_id'])
        active_guards[edge] = None

def on_guard_triggered(widget, event, edge):
    print(f"Guard triggered for edge {edge}, killing process.")
    kill_process(edge)
    cleanup_guard(edge)
    return False

def check_cursor_hyprland(edge, safe_rect):
    guard_data = active_guards.get(edge)
    if not guard_data:
        return False

    x0, y0, w, h = safe_rect
    try:
        result = subprocess.run(
            ['hyprctl', 'cursorpos', '-j'],
            capture_output=True, text=True, check=True
        )
        pos = json.loads(result.stdout)
        cx, cy = pos.get('x'), pos.get('y')
    except Exception as e:
        print(f"Error reading cursor position via hyprctl: {e}")
        return True

    if cx is None or cy is None:
        return True

    if not (x0 <= cx < x0 + w and y0 <= cy < y0 + h):
        print(f"Cursor left safe zone for edge {edge} (Hyprland poll), killing process.")
        kill_process(edge)
        cleanup_guard(edge)
        return False

    return True

def check_alive(edge):
    guard_data = active_guards.get(edge)
    if not guard_data:
        return False
        
    try:
        if edge == EDGE_RIGHT_UP:
            result = subprocess.run(['swaync-client', '-c'], capture_output=True, text=True)
            if result.stdout.strip() == 'false':
                print(f"Swaync no longer alive for edge {edge}, cleaning up guard.")
                cleanup_guard(edge)
                return False
        else:
            result = subprocess.run(['pgrep', '-x', 'rofi'], capture_output=True)
            if result.returncode != 0:
                print(f"Rofi no longer alive for edge {edge}, cleaning up guard.")
                cleanup_guard(edge)
                return False
    except Exception as e:
        print(f"Error checking liveness: {e}")
        
    return True

def force_cleanup_guard(edge):
    print(f"Guard max timeout reached for edge {edge}, cleaning up.")
    cleanup_guard(edge)
    return False

def setup_guard(edge):
    cleanup_guard(edge)
    
    screen_w, screen_h = get_screen_geometry()
    safe_rect = compute_safe_rect_px(edge, screen_w, screen_h)

    win = None
    cursor_poll_id = None

    if IS_HYPRLAND:
        cursor_poll_id = GLib.timeout_add(120, check_cursor_hyprland, edge, safe_rect)
    else:
        win = Gtk.Window()
        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_exclusive_zone(win, -1)

        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.RIGHT, True)

        screen = win.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            win.set_visual(visual)
        win.set_app_paintable(True)
        win.connect("draw", lambda w, cr: False)

        full_rect = cairo.RectangleInt(0, 0, screen_w, screen_h)
        full_region = cairo.Region(full_rect)

        safe_x, safe_y, safe_w, safe_h = safe_rect
        safe_cairo_rect = cairo.RectangleInt(safe_x, safe_y, safe_w, safe_h)
        safe_region = cairo.Region(safe_cairo_rect)

        full_region.subtract(safe_region)
        win.input_shape_combine_region(full_region)

        win.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK)
        win.connect("enter-notify-event", on_guard_triggered, edge)

        win.show_all()

    liveness_id = GLib.timeout_add(200, check_alive, edge)
    timeout_id = GLib.timeout_add_seconds(60, force_cleanup_guard, edge)

    active_guards[edge] = {
        'window': win,
        'liveness_id': liveness_id,
        'timeout_id': timeout_id,
        'cursor_poll_id': cursor_poll_id
    }
    
    return False

def is_blocked(edge):
    if edge == EDGE_RIGHT_UP and active_guards.get(EDGE_RIGHT_DOWN):
        return True
    if edge == EDGE_RIGHT_DOWN and active_guards.get(EDGE_RIGHT_UP):
        return True
    return False

def execute_command(cmd, edge):
    pending_timeouts[edge] = None
    
    if is_blocked(edge):
        return False
        
    current_time = GLib.get_monotonic_time() / 1000 # convert to ms
    last_time = last_trigger_times[edge]
    
    if (current_time - last_time) < CONFIG['cooldown_ms']:
        return False
        
    last_trigger_times[edge] = current_time
    
    if cmd:
        print(f"Executing: {cmd}")
        import shlex
        cmd_parts = shlex.split(cmd)
        if cmd_parts:
            if cmd_parts[0].startswith('~'):
                cmd_parts[0] = os.path.expanduser(cmd_parts[0])
            
            try:
                subprocess.Popen(cmd_parts)
                GLib.timeout_add(150, setup_guard, edge)
            except Exception as e:
                print(f"Failed to execute {cmd}: {e}")
        
    return False

def on_enter_notify(widget, event, edge, cmd):
    if is_blocked(edge):
        return False
        
    if pending_timeouts[edge] is not None:
        GLib.source_remove(pending_timeouts[edge])
        
    current_time = GLib.get_monotonic_time() / 1000
    if (current_time - last_trigger_times[edge]) < CONFIG['cooldown_ms']:
        return False
        
    pending_timeouts[edge] = GLib.timeout_add(CONFIG['dwell_ms'], execute_command, cmd, edge)
    return False

def on_leave_notify(widget, event, edge):
    if pending_timeouts[edge] is not None:
        GLib.source_remove(pending_timeouts[edge])
        pending_timeouts[edge] = None
    return False

def create_edge(edge, cmd):
    size = CONFIG['edge_size']
    if size <= 0:
        return None
        
    win = Gtk.Window()
    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    
    name = f"edge-trigger-{edge}"
    GtkLayerShell.set_namespace(win, name)
    win.set_wmclass(name, name)
    
    gtk_edge = get_gtk_edge(edge)
    GtkLayerShell.set_anchor(win, gtk_edge, True)
    
    screen_w, screen_h = get_screen_geometry()
    
    percent_key = f"edge_{edge}_length_percent"
    percent = CONFIG.get(percent_key, 20)
    
    if edge == EDGE_RIGHT_UP:
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        length_px = int(screen_h * (percent / 100.0))
        win.set_size_request(size, length_px)
    elif edge == EDGE_RIGHT_DOWN:
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        margin_px = int(screen_h * (CONFIG['edge_right_up_length_percent'] / 100.0))
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, margin_px)
        length_px = int(screen_h * (percent / 100.0))
        win.set_size_request(size, length_px)
    elif edge in (EDGE_TOP, EDGE_BOTTOM):
        length_px = int(screen_w * (percent / 100.0))
        win.set_size_request(length_px, size)
    else:
        length_px = int(screen_h * (percent / 100.0))
        win.set_size_request(size, length_px)
        
    GtkLayerShell.set_exclusive_zone(win, -1)
        
    screen = win.get_screen()
    visual = screen.get_rgba_visual()
    if visual:
        win.set_visual(visual)
    win.set_app_paintable(True)
    win.connect("draw", lambda w, cr: False)
    
    win.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)
    win.connect("enter-notify-event", on_enter_notify, edge, cmd)
    win.connect("leave-notify-event", on_leave_notify, edge)
    
    win.show_all()
    return win


def main():
    GLib.set_prgname("edge-trigger")
    GLib.set_application_name("edge-trigger")
    
    windows = []
    
    if CONFIG['edge_top_enable']:
        windows.append(create_edge(EDGE_TOP, CONFIG['edge_top_cmd']))
    if CONFIG['edge_bottom_enable']:
        windows.append(create_edge(EDGE_BOTTOM, CONFIG['edge_bottom_cmd']))
    if CONFIG['edge_left_enable']:
        windows.append(create_edge(EDGE_LEFT, CONFIG['edge_left_cmd']))
    if CONFIG['edge_right_up_enable']:
        windows.append(create_edge(EDGE_RIGHT_UP, CONFIG['edge_right_up_cmd']))
    if CONFIG['edge_right_down_enable']:
        windows.append(create_edge(EDGE_RIGHT_DOWN, CONFIG['edge_right_down_cmd']))
        
    Gtk.main()

if __name__ == "__main__":
    main()