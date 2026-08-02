#!/usr/bin/env python3
import gi
import subprocess
import os
import time

gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, Gdk, GtkLayerShell

DOCK_HEIGHT = 200 # Height of the dock in pixels
DOCK_WIDTH_PCT = 0.8 # Percentage of the screen width that the dock occupies (0.0 to 1.0)
TOP_BARRIER_HEIGHT = 150 # Height of the top barrier in pixels

MANAGER_SCRIPT = os.path.expanduser("~/.local/bin/dockbar_manager.sh") # Path to the script that manages the dock's visibility

class TriggerWindow(Gtk.Window):
    def __init__(self, name: str, anchor_edges: dict, width: int, height: int, margin_bottom: int = 0):
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
        self.last_toggle_time = 0.0
        self.lock_duration = 0.25

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
        current_time = time.time()
        
        if current_time - self.last_toggle_time < self.lock_duration:
            return

        if self.is_dock_open == open_dock:
            return

        self.is_dock_open = open_dock
        self.last_toggle_time = current_time

        if open_dock:
            self.win_show.hide()
            for win in self.hide_barriers:
                win.show_all()
            subprocess.Popen([MANAGER_SCRIPT, "--trigger-show"])
        else:
            for win in self.hide_barriers:
                win.hide()
            self.win_show.show_all()
            subprocess.Popen([MANAGER_SCRIPT, "--trigger-hide"])

    def on_show_enter(self, widget, event):
        self.toggle_dock(open_dock=True)

    def on_hide_enter(self, widget, event):
        self.toggle_dock(open_dock=False)

if __name__ == "__main__":
    manager = DockManager()
    Gtk.main()