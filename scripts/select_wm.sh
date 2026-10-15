#!/usr/bin/env bash
# HakuSpace Window Manager Selection Module
# Owns interactive selection, validation, and canonical WM names.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

canonicalize_wm() {
    local input="${1:-}"
    case "${input,,}" in
        1|hypr|hyprland)
            echo "hyprland"
            ;;
        2|niri)
            echo "niri"
            ;;
        3|mango|mangowm)
            echo "mango"
            ;;
        4|labwc)
            echo "labwc"
            ;;
        5|all)
            echo "niri mango labwc hyprland"
            ;;
        *)
            return 1
            ;;
    esac
}

validate_wm() {
    local wms=()
    for arg in "$@"; do
        local canon
        canon="$(canonicalize_wm "$arg")" || {
            ui_print "${C_RED}[ERROR]${C_RESET}  Unknown window manager: '$arg'"
            return 1
        }
        wms+=($canon)
    done
    printf '%s\n' "${wms[*]}"
}

interactive_menu() {
    ui_print "${C_DIM}${UI_LINE}${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}WINDOW MANAGER${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[1]${C_RESET} Hyprland"
    ui_print "    ${C_DIM}Dynamic tiling compositor${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[2]${C_RESET} Niri"
    ui_print "    ${C_DIM}Scrollable tiling compositor${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[3]${C_RESET} MangoWM"
    ui_print "    ${C_DIM}Lightweight & ton of layouts compositor${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[4]${C_RESET} Labwc"
    ui_print "    ${C_DIM}Lightweight, legacy & floating window compositor${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[5]${C_RESET} All"
    ui_print "    ${C_DIM}Niri + MangoWM + Hyprland + Labwc${C_RESET}"
    ui_print ""
    ui_print "${C_DIM}${UI_LINE}${C_RESET}"

    local wm_choice=""
    ui_prompt "Choose Window Manager [1-5] (default: 5): " wm_choice
    wm_choice="${wm_choice:-5}"

    local selected
    selected="$(canonicalize_wm "$wm_choice")" || {
        ui_print "${C_RED}[ERROR]${C_RESET}  Invalid choice: '$wm_choice'. Please choose 1, 2, 3, 4, or 5."
        exit 1
    }

    printf '%s\n' "$selected"
}

# If executed as a command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --validate)
            shift
            if [[ $# -eq 0 ]]; then
                ui_print "Usage: $0 --validate <wm1> [wm2...]"
                exit 1
            fi
            validate_wm "$@"
            ;;
        --help|-h)
            ui_print "Usage: $0 [--interactive | --validate <wm>...]"
            exit 0
            ;;
        --interactive|"")
            interactive_menu
            ;;
        *)
            validate_wm "$@"
            ;;
    esac
fi
