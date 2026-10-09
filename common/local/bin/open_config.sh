#!/usr/bin/env bash
set -euo pipefail

# Use one VS Code-compatible command
if command -v code >/dev/null 2>&1; then
    EDITOR_CMD="code"
elif command -v codium >/dev/null 2>&1; then
    EDITOR_CMD="codium"
elif command -v code-oss >/dev/null 2>&1; then
    EDITOR_CMD="code-oss"
else
    echo "No VS Code command found (code/codium/code-oss)." >&2
    exit 1
fi

paths=(
    "$HOME/.config/waybar"
    "$HOME/.config/rofi"
    "$HOME/.config/swaync"
    "$HOME/.config/kitty"
    "$HOME/.config/fastfetch"
    "$HOME/.config/cava"
    "$HOME/.zshrc"
)

# Add WM-specific configs only if running
if [[ $XDG_CURRENT_DESKTOP == "Hyprland" ]]; then
    paths+=("$HOME/.config/hypr")
fi

if [[ $XDG_CURRENT_DESKTOP == "niri" ]]; then
    paths+=("$HOME/.config/niri")
fi

if [[ $XDG_CURRENT_DESKTOP == "mango" ]]; then
    paths+=("$HOME/.config/mango")
fi

# Keep only existing paths
existing=()
for p in "${paths[@]}"; do
    [[ -e "$p" ]] && existing+=("$p")
done

if [[ ${#existing[@]} -eq 0 ]]; then
    echo "No config paths found to open." >&2
    exit 1
fi

# Open all existing config paths in the editor
exec "$EDITOR_CMD" -n "${existing[@]}"