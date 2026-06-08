#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="$HOME/.local/state/haku_theme"

# ---------------------------------------------------
# 1) Apply GTK font (best-effort)
# ---------------------------------------------------
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

# ---------------------------------------------------
# 2) Reload apps
# ---------------------------------------------------
# hyprctl reload
hyprctl reload >/dev/null 2>&1 || true

# Waybar reload
DIR_TOP="$HOME/.config/waybar/waybartop"
STATE_FILE="/tmp/waybar_current_mode"
CURRENT_STATE=$(cat "$STATE_FILE")

killall waybar
while pgrep -x waybar >/dev/null; do sleep 0.1; done

if [ "$CURRENT_STATE" == "left" ]; then
    waybar & 
else
    waybar -c "$DIR_TOP/config" -s "$DIR_TOP/style.css" &
fi

# Swaync reload
pkill swaync >/dev/null 2>&1 || true
swaync >/dev/null 2>&1 & disown || true

# Kitty reload
for s in /tmp/kitty-*; do
    [[ -S "$s" ]] || continue
    kitty @ --to "unix:$s" ls >/dev/null 2>&1 || continue
    kitty @ --to "unix:$s" load-config >/dev/null 2>&1 || true
done