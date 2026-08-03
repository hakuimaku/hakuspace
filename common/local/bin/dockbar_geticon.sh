#!/bin/bash
APP="$1"
CACHE_FILE="/tmp/dockbar_icon_cache.txt"

# This script retrieves the icon path for a given application using GTK's icon theme
# It caches the result to avoid repeated lookups (enhance performance).
# For Dockbar pin apps

if [ -f "$CACHE_FILE" ]; then
    PATH_FOUND=$(grep "^${APP}:" "$CACHE_FILE" | cut -d':' -f2-)
    if [ -n "$PATH_FOUND" ] && [ -f "$PATH_FOUND" ]; then
        echo "$PATH_FOUND"
        exit 0
    fi
fi

# Fallback search names for specific applications
case "$APP" in
    "vscode")
        SEARCH_NAMES="['code', 'visual-studio-code', 'vscode']"
        ;;
    "menu")
        SEARCH_NAMES="['view-app-grid', 'start-here', 'gnome-applications', 'application-x-executable']"
        ;;
    *)
        SEARCH_NAMES="['$APP', '$APP-desktop', 'org.$APP.$APP', 'com.$APP.$APP']"
        ;;
esac

# Use Python with GTK to find the icon path
PATH_FOUND=$(python3 -c "
import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk
theme = Gtk.IconTheme.get_default()
search_list = $SEARCH_NAMES

for name in search_list:
    icon = theme.lookup_icon(name, 24, 0)
    if icon:
        print(icon.get_filename())
        break
")

if [ -n "$PATH_FOUND" ]; then
    echo "${APP}:${PATH_FOUND}" >> "$CACHE_FILE"
    echo "$PATH_FOUND"
fi