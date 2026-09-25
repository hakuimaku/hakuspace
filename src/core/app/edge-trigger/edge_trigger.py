#!/usr/bin/env python3
"""Hakuspace edge trigger app."""

import os
import sys
import subprocess
import gi

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
    'edge_right_cmd': 'shutdown.sh -v -e -location 4 -theme-str "window { border-radius: 20px 0 0 20px; }"',
    'edge_size': 2,
    'edge_length_percent': 20
}


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
            subprocess.Popen(cmd_parts)
        
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
    
    # Calculate length in pixels based on screen geometry
    display = Gdk.Display.get_default()
    monitor = display.get_monitor(0)
    if monitor:
        geo = monitor.get_geometry()
        screen_w, screen_h = geo.width, geo.height
    else:
        screen_w, screen_h = 1920, 1080
        
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
