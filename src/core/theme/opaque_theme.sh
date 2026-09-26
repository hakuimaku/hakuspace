#!/usr/bin/env bash

# This script manages the opaque theme settings for various applications like Waybar, Rofi, GTK, SwayNC, and Kitty
# It allows toggling the opaque theme on or off and ensures that the necessary configuration files are created or updated accordingly.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_theme.sh"

OPAQUE_DIR="$THEME_RENDER_DIR/opaque"
mkdir -p "$OPAQUE_DIR"

OPAQUE_STATE_FILE="$STATE_DIR/opaque_theme_state"

APPLY_STYLE="$HOME/.local/bin/apply_style.sh"

# Display help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<EOF
This script manages the opaque theme settings for various applications like Waybar, Rofi, GTK, SwayNC, and Kitty.
It ensures that the necessary configuration files are created or updated accordingly.

Usage: $0 [--toggle|on|off]
Options:
    -h, --help     Show this help message and exit.
    -t, --toggle   Toggle the opaque theme on or off.
    -c, --check    Check the current state of the opaque theme.
    on             Enable the opaque theme.
    off            Disable the opaque theme.
EOF
    exit 0
fi

if [[ ! -f "$OPAQUE_STATE_FILE" ]] || ! grep -qxE '0|1' "$OPAQUE_STATE_FILE"; then
    echo "0" > "$OPAQUE_STATE_FILE"
fi

IS_OPAQUE=$(cat "$OPAQUE_STATE_FILE" 2>/dev/null || echo "0")

render_waybar() {
    if [[ "$IS_OPAQUE" == "1" ]]; then
        cat > "$OPAQUE_DIR/waybar.css" <<'INNEREOF'
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

render_gtk() {
    if [[ "$IS_OPAQUE" == "1" ]]; then
        cat > "$OPAQUE_DIR/gtk.css" <<'INNEREOF'
.thunar {
    background-color: #000000;
    background: #000000;
}
INNEREOF
    else
        echo "" > "$OPAQUE_DIR/gtk.css"
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
    # Kitty and GTK are disabled temporarily
    RENDERERS=(waybar rofi swaync)
    for renderer in "${RENDERERS[@]}"; do
        "render_${renderer}"
    done
}

# SAFETY MECHANISM: Always ensure files exist so that includes/imports don't crash the applications
if [[ ! -f "$OPAQUE_DIR/waybar.css" || ! -f "$OPAQUE_DIR/rofi.rasi" ]]; then
    apply_renderers
fi

toggle() {
    if [[ "$IS_OPAQUE" == "1" ]]; then
        echo "0" > "$OPAQUE_STATE_FILE"
        IS_OPAQUE="0"
        apply_renderers
        $APPLY_STYLE
        echo "Opaque theme disabled."
    else
        echo "1" > "$OPAQUE_STATE_FILE"
        IS_OPAQUE="1"
        apply_renderers
        $APPLY_STYLE
        echo "Opaque theme enabled."
    fi
}

case "${1:-}" in
    -t|--toggle)
        toggle
        ;;
    -c|--check)
        if [[ "$IS_OPAQUE" == "1" ]]; then
            echo "Opaque theme is currently ENABLED."
        else
            echo "Opaque theme is currently DISABLED."
        fi
        ;;
    on)
        if [[ "$IS_OPAQUE" == "0" ]]; then
            echo "1" > "$OPAQUE_STATE_FILE"
            IS_OPAQUE="1"
            apply_renderers
            $APPLY_STYLE
            echo "Opaque theme enabled."
        else
            echo "Opaque theme is already enabled."
        fi
        ;;
    off)
        if [[ "$IS_OPAQUE" == "1" ]]; then  
            echo "0" > "$OPAQUE_STATE_FILE"
            IS_OPAQUE="0"
            apply_renderers
            $APPLY_STYLE
            echo "Opaque theme disabled."
        else
            echo "Opaque theme is already disabled."
        fi
        ;;
    *)
        echo "Invalid option. Use --help for usage information."
        exit 1
        ;;
esac
