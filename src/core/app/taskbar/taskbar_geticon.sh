#!/usr/bin/env bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: taskbar_geticon.sh APPLICATION
Print the icon name for an application.

Arguments:
    APPLICATION         Application name or desktop entry identifier
    -h, --help          Show this help message
EOF
        exit 0
fi

# This script retrieves the icon path for a given application using GTK's icon theme
# It caches the result to avoid repeated lookups (enhance performance).

APP="$1"
CACHE_DIR="$HOME/.cache/taskbar_icons"
CACHE_FILE="$HOME/.cache/taskbar_icon_cache.txt"
THEME_FILE="$HOME/.config/gtk-3.0/settings.ini"
mkdir -p "$CACHE_DIR"

CURRENT_ICON_THEME="default"
CURRENT_GTK_THEME="default"
if [ -f "$THEME_FILE" ]; then
    CURRENT_ICON_THEME=$(grep "^gtk-icon-theme-name" "$THEME_FILE" | cut -d'=' -f2 | tr -d ' ' || echo "default")
    CURRENT_GTK_THEME=$(grep "^gtk-theme-name" "$THEME_FILE" | cut -d'=' -f2 | tr -d ' ' || echo "default")
fi
CURRENT_THEME="${CURRENT_ICON_THEME}:${CURRENT_GTK_THEME}"

if [ -f "$CACHE_FILE" ]; then
    CACHE_THEME=$(head -n 1 "$CACHE_FILE" | grep "^# THEME:" | cut -d':' -f2 | tr -d ' ')
    if [ "$CURRENT_THEME" != "$CACHE_THEME" ]; then
        rm -f "$CACHE_FILE"
        rm -rf "${CACHE_DIR:?}"/*
    else
        PATH_FOUND=$(grep -m 1 "^${APP}:" "$CACHE_FILE" | cut -d':' -f2-)
        if [ -n "$PATH_FOUND" ] && [ -f "$PATH_FOUND" ]; then
            echo "$PATH_FOUND"
            exit 0
        fi
    fi
fi

case "$APP" in
    "vscode")
        SEARCH_NAMES="['code-symbolic', 'code', 'visual-studio-code', 'vscode']"
        ;;
    "menu")
        SEARCH_NAMES="['view-app-grid-symbolic', 'view-app-grid', 'start-here', 'gnome-applications', 'application-x-executable']"
        ;;
    "thunar")
        SEARCH_NAMES="['org.xfce.thunar', 'org.xfce.thunar-symbolic', 'system-file-manager-symbolic', 'org.xfce.thunar', 'thunar', 'system-file-manager']"
        ;;
    *)
        SEARCH_NAMES="['$APP-symbolic', '$APP', '$APP-desktop', 'org.$APP.$APP', 'com.$APP.$APP']"
        ;;
esac

FALLBACK_NAMES="['application-x-executable-symbolic', 'application-x-executable', 'preferences-other', 'exec', 'system-run']"

PYTHON_CODE="
import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk, Gdk
theme = Gtk.IconTheme.get_default()

dummy = Gtk.Label()
dummy.show()
style = dummy.get_style_context()
fg = style.get_color(Gtk.StateFlags.NORMAL)

def find(names):
    for name in names:
        info = theme.lookup_icon(name, 24, Gtk.IconLookupFlags.FORCE_SYMBOLIC)
        if info:
            return info
    return None

info = find($SEARCH_NAMES)
if not info:
    info = find($FALLBACK_NAMES)

if info:
    if info.is_symbolic():
        pixbuf, was_symbolic = info.load_symbolic(fg, fg, fg, fg)
        out_path = '$CACHE_DIR/${APP}.png'
        pixbuf.savev(out_path, 'png', [], [])
        print(out_path)
    else:
        print(info.get_filename())
"

PATH_FOUND=$(python3 -c "$PYTHON_CODE")

if [ -n "$PATH_FOUND" ]; then
    if [ ! -f "$CACHE_FILE" ]; then
        echo "# THEME:$CURRENT_THEME" > "$CACHE_FILE"
    else
        sed -i "/^${APP}:/d" "$CACHE_FILE"
    fi
    echo "${APP}:${PATH_FOUND}" >> "$CACHE_FILE"
    echo "$PATH_FOUND"
fi