#!/usr/bin/env bash
set -e

# This script manages the opaque theme settings for various applications like Waybar, Rofi, GTK, SwayNC, and Kitty
# It allows toggling the opaque theme on or off and ensures that the necessary configuration files are created or updated accordingly.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR"
[[ -f "$LIB_DIR/haku_theme.sh" ]] || LIB_DIR="$SCRIPT_DIR/../lib"
source "$LIB_DIR/haku_theme.sh" || exit 1

OPAQUE_DIR="$THEME_RENDER_DIR/opaque"
mkdir -p "$OPAQUE_DIR"

OPAQUE_STATE_FILE="$(haku_state_path theme.opaque.enabled)"

APPLY_STYLE="${HAKUSPACE_APPLY_STYLE:-$HOME/.local/bin/apply_style.sh}"

# Display help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<EOF
This script manages the opaque theme settings for various applications like Waybar, Rofi, GTK, SwayNC, and Kitty.
It ensures that the necessary configuration files are created or updated accordingly.

Usage: $0 [--toggle|on|off|sync classic|sync hikai]
Options:
    -h, --help     Show this help message and exit.
    -t, --toggle   Toggle the opaque theme on or off.
    -c, --check    Check the current state of the opaque theme.
    on             Enable the opaque theme.
    off            Disable the opaque theme.
    sync BACKEND   Reconcile effective overrides without changing the request.
EOF
    exit 0
fi

if [[ ! -f "$OPAQUE_STATE_FILE" ]] || ! grep -qxE '0|1' "$OPAQUE_STATE_FILE"; then
    echo "0" > "$OPAQUE_STATE_FILE"
fi

IS_OPAQUE=$(cat "$OPAQUE_STATE_FILE" 2>/dev/null || echo "0")

# Transitions pass their target before the backend preference is committed.
BACKEND=$(cat "$(haku_state_path shell.backend)" 2>/dev/null || echo classic)
if [[ "${1:-}" == sync ]]; then
    BACKEND="${2:-}"
    [[ "$BACKEND" == classic || "$BACKEND" == hikai ]] || { echo 'Expected classic or hikai.' >&2; exit 2; }
fi

render_waybar() {
    if [[ "$IS_OPAQUE" == "1" ]]; then
        cat > "$OPAQUE_DIR/waybar.css" <<'INNEREOF'
.modules-left,
.modules-center,
.modules-right {
    padding-top: 0;
    padding-bottom: 0;
}

#hworkspaces,
#musics,
#clocks,
#utilities,
#tools,
#trays,
#adjusters,
#monitors {
    padding: 0;
    margin-top: 2px;
    margin-bottom: 2px;
}

window#waybar {
    background-color: #000000;
    background: #000000;
}
tooltip {
    background-color: #000000;
    background: #000000;
}
INNEREOF
    else
        echo "" > "$OPAQUE_DIR/waybar.css"
    fi
}

render_rofi() {
    if [[ "$IS_OPAQUE" == "1" ]]; then
        cat > "$OPAQUE_DIR/rofi.rasi" <<'INNEREOF'
window {
    background-color: #000000FF;
    background-image: none;
}
mainbox {
    background-color: #000000FF;
    background-image: none;
}
INNEREOF
    else
        echo "" > "$OPAQUE_DIR/rofi.rasi"
    fi
}

render_swaync() {
    if [[ "$IS_OPAQUE" == "1" ]]; then
        cat > "$OPAQUE_DIR/swaync.css" <<'INNEREOF'
.notification {
    background-color: #000000;
    background: #000000;
}
.control-center {
    background: #000000;
}
INNEREOF
    else
        echo "" > "$OPAQUE_DIR/swaync.css"
    fi
}

render_kitty() {
    if [[ "$IS_OPAQUE" == "1" ]]; then
        cat > "$OPAQUE_DIR/kitty.conf" <<'INNEREOF'
background_opacity 1.0
INNEREOF
    else
        echo "" > "$OPAQUE_DIR/kitty.conf"
    fi
}

apply_renderers() {
    # Render effective state while retaining the user's opaque request.
    local IS_OPAQUE="$IS_OPAQUE"
    [[ "$BACKEND" == classic ]] || IS_OPAQUE=0
    RENDERERS=(waybar rofi swaync kitty compositors)
    for renderer in "${RENDERERS[@]}"; do
        "render_${renderer}"
    done
}

# Override only Kitty, including inactive opacity, after normal compositor rules.
render_compositors() {
    if [[ "$IS_OPAQUE" == 1 ]]; then
        cat > "$OPAQUE_DIR/hyprland.lua.tmp" <<'INNEREOF'
-- Classic opaque overrides both active and inactive compositor opacity.
hl.window_rule({
    name = "kitty-classic-opaque",
    match = { class = "kitty" },
    opacity = "1.0 override 1.0 override 1.0 override",
}):set_enabled(true)
INNEREOF
        cat > "$OPAQUE_DIR/niri.kdl.tmp" <<'INNEREOF'
// Classic opaque overrides the application and inactive window rules.
window-rule {
    match app-id="^kitty$"
    opacity 1.0
}
INNEREOF
    else
        : > "$OPAQUE_DIR/hyprland.lua.tmp"
        : > "$OPAQUE_DIR/niri.kdl.tmp"
    fi
    mv "$OPAQUE_DIR/hyprland.lua.tmp" "$OPAQUE_DIR/hyprland.lua"
    mv "$OPAQUE_DIR/niri.kdl.tmp" "$OPAQUE_DIR/niri.kdl"
}

# Mutations change only the request; sync changes only its effective outputs.
case "${1:-}" in
    sync) ;;
    -c|--check)
        if [[ "$IS_OPAQUE" == 1 ]]; then
            echo "Opaque theme is currently ENABLED."
        else
            echo "Opaque theme is currently DISABLED."
        fi
        exit 0
        ;;
    on) IS_OPAQUE=1 ;;
    off) IS_OPAQUE=0 ;;
    -t|--toggle) IS_OPAQUE=$((1 - IS_OPAQUE)) ;;
    *) echo "Invalid option. Use --help for usage information." >&2; exit 2 ;;
esac
if [[ "$1" != sync ]]; then
    printf '%s\n' "$IS_OPAQUE" > "$OPAQUE_STATE_FILE"
fi
apply_renderers
if [[ "$1" == sync ]]; then
    "$APPLY_STYLE" --opaque-context
else
    "$APPLY_STYLE"
fi
