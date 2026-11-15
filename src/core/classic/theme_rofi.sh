#!/usr/bin/env bash

# Classic theme frontend. Owns Rofi presentation/selection only and delegates
# all canonical theme mutation to the headless theme_ctl.sh backend.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
THEME_CTL="$HAKU_BIN_DIR/theme_ctl.sh"
STATUSBAR_MANAGER="$HAKU_BIN_DIR/statusbar_manager.sh"
ROFI_THEME_SWITCHER="$HAKU_BIN_DIR/rofi_theme_switcher.sh"
ACCENT_PICKER="$HAKU_BIN_DIR/accent_color_picker.sh"

spawn() { ( "$@" & ) >/dev/null 2>&1; }

pick_font_size() {
    local current choice size
    current="$("$THEME_CTL" get size)" || return 1
    choice="$(printf '%s\n' 10px 12px 14px 16px 18px | rofi -dmenu -p "  Current: ${current}px" -theme option-menu.rasi -i)"
    [[ -z "$choice" ]] && return 0
    size="${choice//px/}"
    [[ "$size" =~ ^[0-9]+$ ]] || return 0
    "$THEME_CTL" set-size "$size"
}

pick_font() {
    local current choice
    current="$("$THEME_CTL" get font)" || return 1
    choice="$("$THEME_CTL" list-fonts | rofi -dmenu -p "  Current: ${current}" -theme option-menu.rasi -i)"
    [[ -z "$choice" ]] && return 0
    "$THEME_CTL" set-font "$choice"
}

pick_accent() {
    local current choice picked_hex
    current="$("$THEME_CTL" get accent)" || return 1
    choice="$(cat <<'EOF_ACCENTS' | rofi -dmenu -p "  Current: ${current}" -theme option-menu.rasi -i
Pick Color   [Press Enter]
Slate Blue   #7288AE
Green        #A2CB8B
Peach        #FFB399
Yellow       #EFBF04
Pink         #F9B2D7
White        #FFFFFF
Grey         #BFC9D1
EOF_ACCENTS
)"
    [[ -z "$choice" ]] && return 0

    if [[ "$choice" == "Pick Color   [Press Enter]" ]]; then
        "$ACCENT_PICKER"
        return $?
    fi

    picked_hex="$(printf '%s\n' "$choice" | grep -oE '#[0-9a-fA-F]{6}' | head -n1 || true)"
    [[ -z "$picked_hex" ]] && return 0
    "$THEME_CTL" set-accent "$picked_hex"
}

open_menu() {
    local choice
    choice="$(cat <<'EOF_MENU' | rofi -dmenu -p "Change Theme - Choose an option:" -theme option-menu.rasi -i
  Change Waybar Theme
  Change Rofi Theme
  Change Font
  Change Font Size
  Change Accent Color
EOF_MENU
)"
    [[ -z "$choice" ]] && return 0

    case "$choice" in
        *"Change Waybar Theme"*) spawn "$STATUSBAR_MANAGER" --select ;;
        *"Change Rofi Theme"*) spawn "$ROFI_THEME_SWITCHER" ;;
        *"Change Font Size"*) pick_font_size ;;
        *"Change Font"*) pick_font ;;
        *"Change Accent Color"*) pick_accent ;;
    esac
}

print_help() {
    cat <<'EOF_HELP'
Usage: theme_rofi.sh [menu]
Classic Rofi frontend for HakuSpace theme selection.
EOF_HELP
}

case "${1:-menu}" in
    menu|--menu)
        open_menu
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
