#!/usr/bin/env bash

source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1

# Apply GTK font (best-effort)
if command -v gsettings >/dev/null 2>&1; then
    if [[ -n "${FONT_FAMILY:-}" && -n "${FONT_SIZE:-}" ]]; then
        gtk_font="${FONT_FAMILY} ${FONT_SIZE}"
        gsettings set org.gnome.desktop.interface font-name "$gtk_font" || true
        gsettings set org.gnome.desktop.interface monospace-font-name "$gtk_font" || true
    fi
fi

# Reload apps
"$HAKU_BIN_DIR/reload_config.sh" >/dev/null 2>&1 || true

if [[ -f "$HAKU_BIN_DIR/desktop_icons_manager.sh" ]]; then
    "$HAKU_BIN_DIR/desktop_icons_manager.sh" --reload >/dev/null 2>&1 || true
fi

# if [[ -f "$HAKU_BIN_DIR/taskbar_manager.sh" ]]; then
#     "$HAKU_BIN_DIR/taskbar_manager.sh" --reload >/dev/null 2>&1 || true
# fi

if haku_backend_is "classic"; then
    swaync-client --reload-config --reload-css >/dev/null 2>&1 || true
    if [[ -x "$HAKU_BIN_DIR/appbar_ctl.sh" ]]; then
        "$HAKU_BIN_DIR/appbar_ctl.sh" reload-style >/dev/null 2>&1 || true
    fi
fi
theme_sync_classic_gtk3_override || true

for s in /tmp/kitty-*; do
    [[ -S "$s" ]] || continue
    kitty @ --to "unix:$s" ls >/dev/null 2>&1 || continue
    kitty @ --to "unix:$s" load-config >/dev/null 2>&1 || true
done

if [[ -f "$HAKU_BIN_DIR/cava_manager.sh" ]]; then
    "$HAKU_BIN_DIR/cava_manager.sh" reload >/dev/null 2>&1 || true
fi
