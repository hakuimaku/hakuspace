#!/usr/bin/env bash

# Classic theme frontend. Owns Rofi presentation/selection only and delegates
# all canonical theme mutation to the headless theme_ctl.sh backend.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1" source_path="$2"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'theme_rofi.sh: required script not found: %s\n' "$name" >&2
    return 1
}

THEME_CTL="$(resolve_script theme_ctl.sh ../../backend/theme/theme_ctl.sh)" || exit 1
WAYBAR_MANAGER="$(resolve_script waybar_manager.sh ../../facade/waybar_manager.sh)" || exit 1
ROFI_THEME_SWITCHER="$(resolve_script rofi_theme_switcher.sh ../../facade/rofi_theme_switcher.sh)" || exit 1
ACCENT_PICKER="$(resolve_script accent_color_picker.sh accent_color_picker.sh)" || exit 1

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
        *"Change Waybar Theme"*) spawn "$WAYBAR_MANAGER" --select ;;
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
