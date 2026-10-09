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

# Configuration Variables (Edit here)
CONFIG = {
    'dwell_ms': 200,
    'cooldown_ms': 800,
    'edge_top_enable': True,
    'edge_bottom_enable': True,
    'edge_left_enable': False,
    'edge_right_enable': True,
    'edge_top_cmd': 'wallpaper_select.sh -e -location 2 -theme-str "window { border-radius: 0 0 20px 20px; }"',
    'edge_bottom_cmd': 'hakumenu.sh -e -location 6 -theme-str "window { border-radius: 20px 20px 0 0; }"',
    'edge_left_cmd': '',
    'edge_right_cmd': 'shutdown.sh -v -e -location 3 -theme-str "window { border-radius: 0 0 0 20px; }"',
    'edge_size': 2,
    'edge_length_percent': 20
}

SAFE_ZONES = {
    GtkLayerShell.Edge.TOP: (0.0, 0.0, 1.0, 0.75),
    GtkLayerShell.Edge.BOTTOM: (0.0, 0.25, 1.0, 0.75),
    GtkLayerShell.Edge.RIGHT: (0.8, 0.0, 0.2, 1.0),
    GtkLayerShell.Edge.LEFT: (0.0, 0.0, 0.25, 1.0),
}

# Hyprland grabs ALL pointer input for any layer surface with exclusive
# keyboard-interactivity (rofi included), regardless of input region.
# This is a known, still-open Hyprland bug (works fine on sway/niri) — the
# guard window's enter-notify simply never fires there. As a workaround,
# only on Hyprland we poll the compositor's own cursor position via hyprctl
# instead of waiting for a pointer event on our surface.
IS_HYPRLAND = bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))

last_trigger_times = {
    GtkLayerShell.Edge.TOP: 0,
    GtkLayerShell.Edge.BOTTOM: 0,
    GtkLayerShell.Edge.LEFT: 0,
    GtkLayerShell.Edge.RIGHT: 0
}

pending_timeouts = {
    GtkLayerShell.Edge.TOP: None,
    GtkLayerShell.Edge.BOTTOM: None,
    GtkLayerShell.Edge.LEFT: None,
    GtkLayerShell.Edge.RIGHT: None
}

active_guards = {
    GtkLayerShell.Edge.TOP: None,
    GtkLayerShell.Edge.BOTTOM: None,
    GtkLayerShell.Edge.LEFT: None,
    GtkLayerShell.Edge.RIGHT: None
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

def kill_rofi():
    try:
        subprocess.run(['pkill', '-x', 'rofi'], check=False)
    except Exception as e:
        print(f"Error killing rofi: {e}")

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
    print(f"Guard triggered for edge {edge}, killing rofi.")
    kill_rofi()
    cleanup_guard(edge)
    return False

def check_cursor_hyprland(edge, safe_rect):
    # Hyprland-only fallback: ask the compositor directly for the cursor
    # position instead of relying on a pointer event reaching our surface.
    guard_data = active_guards.get(edge)
    if not guard_data:
        return False  # guard already torn down elsewhere, stop polling

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
        return True  # transient error, keep polling rather than kill blindly

    if cx is None or cy is None:
        return True

    if not (x0 <= cx < x0 + w and y0 <= cy < y0 + h):
        print(f"Cursor left safe zone for edge {edge} (Hyprland poll), killing rofi.")
        kill_rofi()
        cleanup_guard(edge)
        return False

    return True

def check_rofi_alive(edge):
    guard_data = active_guards.get(edge)
    if not guard_data:
        return False
        
    try:
        result = subprocess.run(['pgrep', '-x', 'rofi'], capture_output=True)
        if result.returncode != 0:
            print(f"Rofi no longer alive for edge {edge}, cleaning up guard.")
            cleanup_guard(edge)
            return False
    except Exception as e:
        print(f"Error checking rofi liveness: {e}")
        
    return True

def force_cleanup_guard(edge):
    print(f"Guard max timeout reached for edge {edge}, cleaning up.")
    cleanup_guard(edge)
    return False

def setup_guard(edge):
    # Ensure no old guard is lingering
    cleanup_guard(edge)
    
    screen_w, screen_h = get_screen_geometry()
    safe_rect = compute_safe_rect_px(edge, screen_w, screen_h)

    win = None
    cursor_poll_id = None

    if IS_HYPRLAND:
        # Skip the layer-shell overlay entirely: on Hyprland it would never
        # receive input while rofi holds it, so it'd just be dead weight.
        # Poll the cursor position instead (see check_cursor_hyprland).
        cursor_poll_id = GLib.timeout_add(120, check_cursor_hyprland, edge, safe_rect)
    else:
        win = Gtk.Window()
        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_exclusive_zone(win, -1)

        # Anchor to all edges to be fullscreen
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.RIGHT, True)

        # Transparent background
        screen = win.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            win.set_visual(visual)
        win.set_app_paintable(True)
        win.connect("draw", lambda w, cr: False)

        # Set input shape: fullscreen minus safe zone
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

    liveness_id = GLib.timeout_add(200, check_rofi_alive, edge)
    timeout_id = GLib.timeout_add_seconds(60, force_cleanup_guard, edge)

    active_guards[edge] = {
        'window': win,
        'liveness_id': liveness_id,
        'timeout_id': timeout_id,
        'cursor_poll_id': cursor_poll_id
    }
    
    return False

def execute_command(cmd, edge):
    pending_timeouts[edge] = None
    
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
            # If it's a local script without a full path, prefix with ~/.local/bin/
            if not cmd_parts[0].startswith('/') and not cmd_parts[0].startswith('~'):
                cmd_parts[0] = os.path.join(os.path.expanduser("~/.local/bin"), cmd_parts[0])
            else:
                cmd_parts[0] = os.path.expanduser(cmd_parts[0])
            
            try:
                subprocess.Popen(cmd_parts)
                # Schedule guard setup after 150ms delay
                GLib.timeout_add(150, setup_guard, edge)
            except Exception as e:
                print(f"Failed to execute {cmd}: {e}")
        
    return False

def on_enter_notify(widget, event, edge, cmd):
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
    # We use OVERLAY layer so it sits above everything and catches events.
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    
    edge_name = "top"
    if edge == GtkLayerShell.Edge.BOTTOM:
        edge_name = "bottom"
    elif edge == GtkLayerShell.Edge.LEFT:
        edge_name = "left"
    elif edge == GtkLayerShell.Edge.RIGHT:
        edge_name = "right"
        
    name = f"edge-trigger-{edge_name}"
    GtkLayerShell.set_namespace(win, name)
    win.set_wmclass(name, name)
    
    GtkLayerShell.set_anchor(win, edge, True)
    
    if edge == GtkLayerShell.Edge.RIGHT:
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
    
    screen_w, screen_h = get_screen_geometry()
    
    if edge == GtkLayerShell.Edge.RIGHT:
        margin_px = int(screen_h * 0.1)
        GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, margin_px)
        
    if edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM):
        # Center horizontally by NOT anchoring left/right
        length_px = int(screen_w * (CONFIG['edge_length_percent'] / 100.0))
        win.set_size_request(length_px, size)
    else:
        # Center vertically by NOT anchoring top/bottom
        length_px = int(screen_h * (CONFIG['edge_length_percent'] / 100.0))
        win.set_size_request(size, length_px)
        
    # exclusive_zone=-1 so it does not push other windows AND ignores other windows' exclusive zones
    GtkLayerShell.set_exclusive_zone(win, -1)
        
    screen = win.get_screen()
    visual = screen.get_rgba_visual()
    if visual:
        win.set_visual(visual)
    win.set_app_paintable(True)
    
    # Make it transparent
    win.connect("draw", lambda w, cr: False)
    
    # Catch pointer events
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
        windows.append(create_edge(GtkLayerShell.Edge.TOP, CONFIG['edge_top_cmd']))
    if CONFIG['edge_bottom_enable']:
        windows.append(create_edge(GtkLayerShell.Edge.BOTTOM, CONFIG['edge_bottom_cmd']))
    if CONFIG['edge_left_enable']:
        windows.append(create_edge(GtkLayerShell.Edge.LEFT, CONFIG['edge_left_cmd']))
    if CONFIG['edge_right_enable']:
        windows.append(create_edge(GtkLayerShell.Edge.RIGHT, CONFIG['edge_right_cmd']))
        
    Gtk.main()

if __name__ == "__main__":
    main()