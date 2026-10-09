#!/usr/bin/env python3
"""Hakuspace rounded screen app."""

import os
import sys
import math
import configparser
import gi
import cairo

gi.require_version('Gtk', '3.0')
try:
    gi.require_version('GtkLayerShell', '0.1')
except ValueError:
    print("Error: GtkLayerShell is not installed.")
    sys.exit(1)

from gi.repository import Gtk, Gdk, GtkLayerShell

CONFIG_DIR = os.path.expanduser("~/hakucfg/config")
CONF_FILE = os.path.join(CONFIG_DIR, "rounded-screen.conf")

# Default Constants
BORDER_THICKNESS = 4
BORDER_RADIUS = 20
OPACITY = 1.0
ENABLE_EXCLUSIVE = True

def load_config():
    global BORDER_THICKNESS, BORDER_RADIUS
    
    os.makedirs(CONFIG_DIR, exist_ok=True)
    config = configparser.ConfigParser()
    
    DEFAULT_SETTINGS_BLOCK = f"""[Settings]
# Border thickness in pixels
border_thickness = {BORDER_THICKNESS}

# Border radius in pixels
border_radius = {BORDER_RADIUS}
"""

    if not os.path.exists(CONF_FILE):
        try:
            with open(CONF_FILE, 'w') as configfile:
                configfile.write(DEFAULT_SETTINGS_BLOCK)
        except OSError as e:
            print(f"Failed to create config file {CONF_FILE}: {e}")
    else:
        try:
            config.read(CONF_FILE)
            if 'Settings' in config:
                if 'border_thickness' in config['Settings']:
                    BORDER_THICKNESS = config['Settings'].getint('border_thickness', BORDER_THICKNESS)
                if 'border_radius' in config['Settings']:
                    BORDER_RADIUS = config['Settings'].getint('border_radius', BORDER_RADIUS)
        except Exception as e:
            print(f"Failed to parse {CONF_FILE}: {e}")

def make_click_through(win):
    """Set an empty input-shape and re-apply it on 'size-allocate' too.

    Setting it only on 'realize' is not enough: layer-shell windows get
    their real size from an async compositor configure event, which can
    happen after realize and resets the input region back to the full
    window. That's what was blocking mouse/drag interaction with
    desktop_icons.py underneath.
    """
    region = cairo.Region()
    def apply_shape(*_args):
        win.input_shape_combine_region(region)
    win.connect("realize", apply_shape)
    win.connect("size-allocate", apply_shape)

def create_invisible_edge(edge, size):
    if size <= 0:
        return None
        
    win = Gtk.Window()
    GtkLayerShell.init_for_window(win)
    # BOTTOM (not OVERLAY): gtk-layer-shell/wlroots arranges layers in the
    # order background -> bottom -> top -> overlay, and an exclusive zone
    # only pushes surfaces from layers arranged AFTER it. Waybar normally
    # sits on the TOP layer, so an exclusive zone requested from OVERLAY
    # (arranged last) never affects it. BOTTOM is arranged before TOP, so
    # it actually reserves space and pushes waybar inward.
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.BOTTOM)
    
    edge_name = "top"
    if edge == GtkLayerShell.Edge.BOTTOM:
        edge_name = "bottom"
    elif edge == GtkLayerShell.Edge.LEFT:
        edge_name = "left"
    elif edge == GtkLayerShell.Edge.RIGHT:
        edge_name = "right"
        
    name = f"rounded-corner-{edge_name}"
    GtkLayerShell.set_namespace(win, name)
    win.set_wmclass(name, name)
    
    GtkLayerShell.set_anchor(win, edge, True)
    if edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM):
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.RIGHT, True)
        win.set_size_request(-1, size)
    else:
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.BOTTOM, True)
        win.set_size_request(size, -1)
        
    GtkLayerShell.auto_exclusive_zone_enable(win)
        
    screen = win.get_screen()
    visual = screen.get_rgba_visual()
    if visual:
        win.set_visual(visual)
    win.set_app_paintable(True)
    
    win.connect("draw", lambda w, cr: False)
    
    make_click_through(win)
    
    win.show_all()
    return win

def on_draw_main(widget, cr):
    width = widget.get_allocated_width()
    height = widget.get_allocated_height()
    
    r = BORDER_RADIUS
    t = BORDER_THICKNESS
    
    # Clear background
    cr.set_operator(cairo.OPERATOR_SOURCE)
    cr.set_source_rgba(0, 0, 0, 0)
    cr.paint()
    
    # Outer rectangle (whole screen)
    cr.rectangle(0, 0, width, height)
    
    # Inner rounded rectangle
    cr.new_sub_path()
    cr.arc(width - r, r, r, -math.pi/2, 0)
    cr.arc(width - r, height - r, r, 0, math.pi/2)
    cr.arc(r, height - r, r, math.pi/2, math.pi)
    cr.arc(r, r, r, math.pi, 3*math.pi/2)
    cr.close_path()
    
    cr.set_fill_rule(cairo.FILL_RULE_EVEN_ODD)
    cr.set_source_rgba(0, 0, 0, 1.0)
    cr.fill_preserve()
    
    if t > 0:
        cr.set_line_width(t * 2)
        cr.stroke()

    return False

def main():
    import gi
    from gi.repository import GLib
    GLib.set_prgname("rounded-screen")
    GLib.set_application_name("rounded-screen")
    
    load_config()
    
    windows = []
    
    # 1. MAIN DRAWING WINDOW
    # This window spans the entire physical screen and draws the corners and border.
    # It ignores all exclusive zones (exclusive_zone = -1).
    main_win = Gtk.Window()
    main_win.set_title("Rounded Screen Main")
    GtkLayerShell.init_for_window(main_win)
    GtkLayerShell.set_layer(main_win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_namespace(main_win, "rounded-screen")
    main_win.set_wmclass("rounded-screen", "rounded-screen")
    
    GtkLayerShell.set_anchor(main_win, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_anchor(main_win, GtkLayerShell.Edge.BOTTOM, True)
    GtkLayerShell.set_anchor(main_win, GtkLayerShell.Edge.LEFT, True)
    GtkLayerShell.set_anchor(main_win, GtkLayerShell.Edge.RIGHT, True)
    
    GtkLayerShell.set_exclusive_zone(main_win, -1)
    
    screen = main_win.get_screen()
    visual = screen.get_rgba_visual()
    if visual:
        main_win.set_visual(visual)
    main_win.set_app_paintable(True)
    
    main_win.connect("draw", on_draw_main)
    make_click_through(main_win)
    
    main_win.show_all()
    windows.append(main_win)
    
    # 2. INVISIBLE DUMMY EDGES
    # These windows reserve the 4px exclusive zone so that Waybar and other apps are pushed inward.
    if BORDER_THICKNESS > 0:
        windows.append(create_invisible_edge(GtkLayerShell.Edge.TOP, BORDER_THICKNESS))
        windows.append(create_invisible_edge(GtkLayerShell.Edge.BOTTOM, BORDER_THICKNESS))
        windows.append(create_invisible_edge(GtkLayerShell.Edge.LEFT, BORDER_THICKNESS))
        windows.append(create_invisible_edge(GtkLayerShell.Edge.RIGHT, BORDER_THICKNESS))
        
    Gtk.main()

if __name__ == "__main__":
    main()