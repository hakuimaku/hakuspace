#!/usr/bin/env python3
import gi
import subprocess

gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, Gdk, GtkLayerShell

# Variables for Dockbar dimensions and positioning
DOCK_HEIGHT = 200 # Dockbar zone (px)
DOCK_WIDTH_PCT = 0.8 # Width of the safe area (% of screen width)
TOP_BARRIER_HEIGHT = 150 # Height of the top barrier (px)

class TriggerWindow(Gtk.Window):
    """invisible window that acts as a trigger for showing or hiding the Dockbar"""
    def __init__(self, name, anchor_edges, width, height, margin_bottom=0):
        super().__init__()
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_namespace(self, name)
        
        for edge, state in anchor_edges.items():
            GtkLayerShell.set_anchor(self, edge, state)
        
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, margin_bottom)
        self.set_size_request(width, height)
        
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.override_background_color(Gtk.StateFlags.NORMAL, Gdk.RGBA(0, 0, 0, 0))


class DockManager:
    def __init__(self):
        self.is_dock_open = False

        display = Gdk.Display.get_default()
        monitor = display.get_primary_monitor() or (display.get_monitor(0) if display.get_n_monitors() > 0 else None)
        screen_width = monitor.get_geometry().width if monitor else 1920

        safe_width = int(screen_width * DOCK_WIDTH_PCT)
        side_width = int((screen_width - safe_width) / 2)

        self.win_show = TriggerWindow(
            "dock-show", 
            {GtkLayerShell.Edge.BOTTOM: True}, 
            safe_width, 3
        )
        self.win_show.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK)
        self.win_show.connect("enter-notify-event", self.on_show_enter)

        self.hide_barriers = [
            TriggerWindow(
                "dock-hide-top", 
                {GtkLayerShell.Edge.BOTTOM: True}, 
                screen_width, TOP_BARRIER_HEIGHT, margin_bottom=DOCK_HEIGHT
            ),
            TriggerWindow(
                "dock-hide-left", 
                {GtkLayerShell.Edge.BOTTOM: True, GtkLayerShell.Edge.LEFT: True}, 
                side_width, DOCK_HEIGHT
            ),
            TriggerWindow(
                "dock-hide-right", 
                {GtkLayerShell.Edge.BOTTOM: True, GtkLayerShell.Edge.RIGHT: True}, 
                side_width, DOCK_HEIGHT
            )
        ]

        for win in self.hide_barriers:
            win.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK)
            win.connect("enter-notify-event", self.on_hide_enter)

        self.win_show.show_all()

    def toggle_dock(self, open_dock: bool):
        """Controls the visibility of the Dockbar based on the open_dock parameter"""
        if self.is_dock_open == open_dock:
            return

        self.is_dock_open = open_dock

        if open_dock:
            self.win_show.hide()
            for win in self.hide_barriers:
                win.show_all()
        else:
            for win in self.hide_barriers:
                win.hide()
            self.win_show.show_all()

        subprocess.run(["pkill", "-USR1", "-x", "dockbar"])

    def on_show_enter(self, widget, event):
        self.toggle_dock(open_dock=True)

    def on_hide_enter(self, widget, event):
        self.toggle_dock(open_dock=False)


if __name__ == "__main__":
    manager = DockManager()
    Gtk.main()