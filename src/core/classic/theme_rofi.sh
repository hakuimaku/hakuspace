#!/usr/bin/env bash

# Classic theme frontend. Owns Rofi presentation/selection only and delegates
# all canonical theme mutation to the headless theme_ctl.sh backend.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
THEME_CTL="$HAKU_BIN_DIR/theme_ctl.sh"

pick_font_size() {
    local current choice size
    current="$("$THEME_CTL" get size)" || return 1
    choice="$(printf '%s\n' 10px 12px 14px 16px 18px | rofi -dmenu -sync -p "Font Size (Current: ${current}px)" -theme styles/menu.rasi -i)"
    [[ -z "$choice" ]] && return 0
    size="${choice//px/}"
    [[ "$size" =~ ^[0-9]+$ ]] || return 0
    "$THEME_CTL" set-size "$size"
}

pick_font() {
    local current choice
    current="$("$THEME_CTL" get font)" || return 1
    choice="$("$THEME_CTL" list-fonts | rofi -dmenu -sync -p "Font (Current: ${current})" -theme styles/menu.rasi -i)"
    [[ -z "$choice" ]] && return 0
    "$THEME_CTL" set-font "$choice"
}

pick_palette() {
    local req_file requested effective current_label selected_idx=0 i chosen_index
    req_file="$(haku_state_path theme.classic.palette)" || return 1
    requested="$(cat "$req_file" 2>/dev/null || printf 'auto')"
    effective="$("$THEME_CTL" palette)" || return 1
    if [[ "$requested" == "auto" || -z "$requested" ]]; then
        current_label="Auto -> ${effective}"
    else
        current_label="$effective"
    fi

    local -a PALETTE_IDS=(auto red orange yellow green blue indigo violet gray)
    local -a PALETTE_LABELS=(
        "<span foreground='#b8b8b8'>◐</span>  Auto (Follow Wallpaper)"
        "<span foreground='#de9492'>██</span>  Red"
        "<span foreground='#deb192'>██</span>  Orange"
        "<span foreground='#dece92'>██</span>  Yellow"
        "<span foreground='#92de98'>██</span>  Green"
        "<span foreground='#92b5de'>██</span>  Blue"
        "<span foreground='#9592de'>██</span>  Indigo"
        "<span foreground='#be92de'>██</span>  Violet"
        "<span foreground='#b8b8b8'>██</span>  Gray"
    )
    for i in "${!PALETTE_IDS[@]}"; do
        if [[ "${PALETTE_IDS[$i]}" == "$requested" ]]; then
            selected_idx="$i"
            break
        fi
    done

    chosen_index="$(printf '%s\n' "${PALETTE_LABELS[@]}" | rofi \
        -dmenu \
        -sync \
        -i \
        -markup-rows \
        -format i \
        -selected-row "$selected_idx" \
        -p "Color Scheme (${current_label})" \
        -theme styles/theme.rasi)" || return 0
    [[ -n "$chosen_index" ]] || return 0

    if [[ "$chosen_index" =~ ^[0-9]+$ ]] && (( chosen_index >= 0 && chosen_index < ${#PALETTE_IDS[@]} )); then
        "$THEME_CTL" set-palette "${PALETTE_IDS[$chosen_index]}"
    fi
}

open_menu() {
    local choice
    choice="$(cat <<'EOF_MENU' | rofi -dmenu -sync -p "Change Theme" -theme styles/theme.rasi -i
  Change Color Scheme
  Change Font
  Change Font Size
EOF_MENU
)"
    [[ -z "$choice" ]] && return 0

    case "$choice" in
        *"Change Color Scheme"*) pick_palette ;;
        *"Change Font Size"*) pick_font_size ;;
        *"Change Font"*) pick_font ;;
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
