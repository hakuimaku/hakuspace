#!/usr/bin/env bash

STATE_DIR="$HOME/.local/state/haku_theme"

# Apply GTK font (best-effort)
if command -v gsettings >/dev/null 2>&1 && [[ -f "$STATE_DIR/fonts.css" ]]; then
    # Parse from fonts.css:
    #   font-family: "JetBrainsMono Nerd Font";
    #   font-size: 16px;
    font_family="$(sed -nE 's/^\s*font-family:\s*"([^"]+)".*$/\1/p' "$STATE_DIR/fonts.css" | head -n1 || true)"
    font_size="$(sed -nE 's/^\s*font-size:\s*([0-9]+)px.*$/\1/p' "$STATE_DIR/fonts.css" | head -n1 || true)"
  
    if [[ -n "${font_family:-}" && -n "${font_size:-}" ]]; then
        gtk_font="${font_family} ${font_size}"
        gsettings set org.gnome.desktop.interface font-name "$gtk_font" || true
        gsettings set org.gnome.desktop.interface monospace-font-name "$gtk_font" || true
    fi
fi

# Reload apps
# Hyprland reload
if [[ $XDG_CURRENT_DESKTOP == "Hyprland" ]]; then
    hyprctl reload
fi

# Niri reload
if [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    niri msg action load-config-file
fi

# MangoWM reload
if [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    mmsg -d reload_config
    mmsg dispatch reload_config
fi

# Labwc reload
if [[ $XDG_CURRENT_DESKTOP == "labwc" ]]; then
    labwc --reconfigure
fi

# Desktop icons reload
if [[ -f "$HOME/.local/bin/desktop_icons_manager.sh" ]]; then
    "$HOME/.local/bin/desktop_icons_manager.sh" --reload >/dev/null 2>&1 || true
fi

# Dockbar reload
if [[ -f "$HOME/.local/bin/dockbar_manager.sh" ]]; then
    "$HOME/.local/bin/dockbar_manager.sh" --reload >/dev/null 2>&1 || true
fi

# Swaync reload
swaync-client --reload-config --reload-css >/dev/null 2>&1 || true

# Kitty reload
for s in /tmp/kitty-*; do
    [[ -S "$s" ]] || continue
    kitty @ --to "unix:$s" ls >/dev/null 2>&1 || continue
    kitty @ --to "unix:$s" load-config >/dev/null 2>&1 || true
done