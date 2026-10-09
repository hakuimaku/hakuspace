#!/usr/bin/env python3
"""Small AppIndicator menu for manual Quickshell tray interaction checks.

Run from the graphical session with ``python3 scripts/tray_short_fixture.py``.
Stop with Ctrl+C (or SIGTERM) to test item disappearance. No system state is changed.
"""

import signal

import gi

gi.require_version("AyatanaAppIndicator3", "0.1")
gi.require_version("Gtk", "3.0")
from gi.repository import AyatanaAppIndicator3, GLib, GLibUnix, Gtk


def log(label):
    print(f"tray fixture: {label}", flush=True)


indicator = AyatanaAppIndicator3.Indicator.new(
    "hakuspace-p1-short-menu-fixture",
    "applications-system",
    AyatanaAppIndicator3.IndicatorCategory.APPLICATION_STATUS,
)
indicator.set_title("P1 short menu fixture")
indicator.set_status(AyatanaAppIndicator3.IndicatorStatus.ACTIVE)

menu = Gtk.Menu()
action = Gtk.MenuItem.new_with_label("Fixture action")
action.connect("activate", lambda *_: log("action triggered"))
menu.append(action)

check = Gtk.CheckMenuItem.new_with_label("Fixture check")
check.connect("toggled", lambda item: log(f"check={item.get_active()}"))
menu.append(check)

submenu_parent = Gtk.MenuItem.new_with_label("Fixture submenu")
submenu = Gtk.Menu()
nested = Gtk.MenuItem.new_with_label("Nested action")
nested.connect("activate", lambda *_: log("nested action triggered"))
submenu.append(nested)
radio_a = Gtk.RadioMenuItem.new_with_label(None, "Radio A")
radio_b = Gtk.RadioMenuItem.new_with_label_from_widget(radio_a, "Radio B")
radio_a.connect("toggled", lambda item: item.get_active() and log("radio=A"))
radio_b.connect("toggled", lambda item: item.get_active() and log("radio=B"))
submenu.append(radio_a)
submenu.append(radio_b)
submenu_parent.set_submenu(submenu)
menu.append(submenu_parent)

menu.show_all()
indicator.set_menu(menu)


def stop(*_):
    log("stopping; tray item should disappear")
    Gtk.main_quit()
    return GLib.SOURCE_REMOVE


GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, stop)
GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, stop)
log("running; right-click or left-click the system tray fixture icon")
Gtk.main()
