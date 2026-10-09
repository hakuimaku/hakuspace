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
"$HOME/.local/bin/reload_config.sh" >/dev/null 2>&1 || true

if [[ -f "$HOME/.local/bin/desktop_icons_manager.sh" ]]; then
    "$HOME/.local/bin/desktop_icons_manager.sh" --reload >/dev/null 2>&1 || true
fi

# if [[ -f "$HOME/.local/bin/taskbar_manager.sh" ]]; then
#     "$HOME/.local/bin/taskbar_manager.sh" --reload >/dev/null 2>&1 || true
# fi

swaync-client --reload-config --reload-css >/dev/null 2>&1 || true

for s in /tmp/kitty-*; do
    [[ -S "$s" ]] || continue
    kitty @ --to "unix:$s" ls >/dev/null 2>&1 || continue
    kitty @ --to "unix:$s" load-config >/dev/null 2>&1 || true
done

if [[ -f "$HOME/.local/bin/cava_manager.sh" ]]; then
    "$HOME/.local/bin/cava_manager.sh" reload >/dev/null 2>&1 || true
fi
