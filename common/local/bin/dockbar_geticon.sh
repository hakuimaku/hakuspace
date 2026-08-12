#!/usr/bin/env bash

# This script retrieves the icon path for a given application using GTK's icon theme
# It caches the result to avoid repeated lookups (enhance performance).

APP="$1"
CACHE_FILE="$HOME/.cache/dockbar_icon_cache.txt"

if [ -f "$CACHE_FILE" ]; then
    PATH_FOUND=$(grep "^${APP}:" "$CACHE_FILE" | cut -d':' -f2-)
    if [ -n "$PATH_FOUND" ] && [ -f "$PATH_FOUND" ]; then
        echo "$PATH_FOUND"
        exit 0
    fi
fi

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

FALLBACK_NAMES="['application-x-executable', 'preferences-other', 'exec', 'system-run', 'image-missing']"

PYTHON_CODE="
import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk
theme = Gtk.IconTheme.get_default()

search_list = $SEARCH_NAMES
found_path = None

for name in search_list:
    icon = theme.lookup_icon(name, 24, 0)
    if icon:
        found_path = icon.get_filename()
        break

if not found_path:
    fallback_list = $FALLBACK_NAMES
    for name in fallback_list:
        icon = theme.lookup_icon(name, 24, 0)
        if icon:
            found_path = icon.get_filename()
            break

if found_path:
    print(found_path)
"

if command -v nix-shell >/dev/null 2>&1; then
    # NixOS
    PATH_FOUND=$(nix-shell -p gobject-introspection gtk3 pango "python3.withPackages (ps: with ps; [ pygobject3 ])" --run "python3 -c \"$PYTHON_CODE\"" 2>/dev/null)
else
    PATH_FOUND=$(python3 -c "$PYTHON_CODE" 2>/dev/null)
fi

if [ -n "$PATH_FOUND" ]; then
    echo "${APP}:${PATH_FOUND}" >> "$CACHE_FILE"
    echo "$PATH_FOUND"
fi