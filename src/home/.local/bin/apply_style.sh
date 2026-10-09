#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"

# Apply GTK font (best-effort)
if command -v gsettings >/dev/null 2>&1; then
    if [[ -n "${FONT_FAMILY:-}" && -n "${FONT_SIZE:-}" ]]; then
        gtk_font="${FONT_FAMILY} ${FONT_SIZE}"
        gsettings set org.gnome.desktop.interface font-name "$gtk_font" || true
        gsettings set org.gnome.desktop.interface monospace-font-name "$gtk_font" || true
    fi
fi

# Reload apps
if [[ $XDG_CURRENT_DESKTOP == "Hyprland" ]]; then
    hyprctl reload
fi

if [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    niri msg action load-config-file
fi

if [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    mmsg -d reload_config
    mmsg dispatch reload_config
fi

if [[ $XDG_CURRENT_DESKTOP == "labwc" ]]; then
    labwc --reconfigure
fi

if [[ -f "$HOME/.local/bin/desktop_icons_manager.sh" ]]; then
    "$HOME/.local/bin/desktop_icons_manager.sh" --reload >/dev/null 2>&1 || true
fi

if [[ -f "$HOME/.local/bin/dockbar_manager.sh" ]]; then
    "$HOME/.local/bin/dockbar_manager.sh" --reload >/dev/null 2>&1 || true
fi

swaync-client --reload-config --reload-css >/dev/null 2>&1 || true

for s in /tmp/kitty-*; do
    [[ -S "$s" ]] || continue
    kitty @ --to "unix:$s" ls >/dev/null 2>&1 || continue
    kitty @ --to "unix:$s" load-config >/dev/null 2>&1 || true
done
