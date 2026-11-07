#!/usr/bin/env python3
"""Keep six native tray entries alive on the private test session bus."""
import gi

gi.require_version("AyatanaAppIndicator3", "0.1")
gi.require_version("Gtk", "3.0")
from gi.repository import AyatanaAppIndicator3, Gtk

# Retain both indicator and menu ownership until the fixture process exits.
indicators = []
for index in range(6):
    indicator = AyatanaAppIndicator3.Indicator.new(
        f"leftbar-tray-{index}", "applications-system", AyatanaAppIndicator3.IndicatorCategory.APPLICATION_STATUS)
    indicator.set_title(f"Leftbar tray fixture {index + 1}")
    indicator.set_status(AyatanaAppIndicator3.IndicatorStatus.ACTIVE)
    menu = Gtk.Menu()
    menu.append(Gtk.MenuItem.new_with_label(f"Fixture action {index + 1}"))
    menu.show_all()
    indicator.set_menu(menu)
    indicators.append((indicator, menu))
Gtk.main()
