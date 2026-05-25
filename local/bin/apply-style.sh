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
hyprctl reload >/dev/null 2>&1 || true

pkill waybar >/dev/null 2>&1 || true
waybar >/dev/null 2>&1 & disown || true

pkill swaync >/dev/null 2>&1 || true
swaync >/dev/null 2>&1 & disown || true

kitty @ load-config >/dev/null 2>&1 || true