#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR"
[[ -f "$LIB_DIR/haku_theme.sh" ]] || LIB_DIR="$SCRIPT_DIR/../lib"
source "$LIB_DIR/haku_theme.sh" || exit 1
source "$LIB_DIR/haku_backend_lib.sh" || exit 1

# Context synchronization must not restart shell services during backend cutover.
OPAQUE_CONTEXT=false
[[ "${1:-}" == --opaque-context ]] && OPAQUE_CONTEXT=true

# Apply GTK font (best-effort)
if ! $OPAQUE_CONTEXT && command -v gsettings >/dev/null 2>&1; then
    if [[ -n "${FONT_FAMILY:-}" && -n "${FONT_SIZE:-}" ]]; then
        gtk_font="${FONT_FAMILY} ${FONT_SIZE}"
        gsettings set org.gnome.desktop.interface font-name "$gtk_font" || true
        gsettings set org.gnome.desktop.interface monospace-font-name "$gtk_font" || true
    fi
fi

# Reload apps
if $OPAQUE_CONTEXT; then
    "$HOME/.local/bin/reload_config.sh" >/dev/null 2>&1 || exit 1
else
    "$HOME/.local/bin/reload_config.sh" >/dev/null 2>&1 || true
fi

if ! $OPAQUE_CONTEXT && [[ -f "$HOME/.local/bin/desktop_icons_manager.sh" ]]; then
    "$HOME/.local/bin/desktop_icons_manager.sh" --reload >/dev/null 2>&1 || true
fi

# if [[ -f "$HOME/.local/bin/taskbar_manager.sh" ]]; then
#     "$HOME/.local/bin/taskbar_manager.sh" --reload >/dev/null 2>&1 || true
# fi

if ! $OPAQUE_CONTEXT && haku_backend_is "classic"; then
    swaync-client --reload-config --reload-css >/dev/null 2>&1 || true
fi

for s in /tmp/kitty-*; do
    [[ -S "$s" ]] || continue
    kitty @ --to "unix:$s" ls >/dev/null 2>&1 || continue
    kitty @ --to "unix:$s" load-config >/dev/null 2>&1 || true
done

if ! $OPAQUE_CONTEXT && [[ -f "$HOME/.local/bin/cava_manager.sh" ]]; then
    "$HOME/.local/bin/cava_manager.sh" reload >/dev/null 2>&1 || true
fi
