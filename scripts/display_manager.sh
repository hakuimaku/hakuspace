#!/usr/bin/env bash
# HakuSpace Display Manager Setup Module (Ly)
# Configures ly@ttyN service and disables getty@ttyN.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

find_ly() {
    for path in /usr/bin/ly /usr/local/bin/ly /usr/sbin/ly /usr/bin/ly-dm; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

setup_ly() {
    local dry_run="${1:-0}"
    local ly_bin
    if ! ly_bin="$(find_ly)"; then
        log_warn "ly display manager not found. Skipping service configuration."
        return 0
    fi

    log_info "Detected ly at: $ly_bin"

    if [[ "$dry_run" -eq 1 ]]; then
        log_info "DRY RUN: ly detected, skipping systemctl modification."
        return 0
    fi

    ui_print ""
    ui_print "${C_BOLD}DISPLAY MANAGER SETUP (Ly)${C_RESET}"
    ui_print "  Detected binary: $ly_bin"
    ui_print "  Action:          Enable ly@ttyN.service and disable getty@ttyN.service"
    ui_print ""
    if ask_yes_no "===> Enable Ly display manager service and disable getty now?"; then
        ui_print ""
        log_warn "Do NOT choose tty1 if another display manager (SDDM, GDM, etc.) is active on tty1."
        ui_print "  Available TTY slots: [1-6]"
        local tty_choice=""
        ui_prompt "Choose TTY number for Ly [1-6] (default: 1): " tty_choice
        tty_choice="${tty_choice:-1}"

        if [[ "$tty_choice" =~ ^[1-6]$ ]]; then
            sudo systemctl enable "ly@tty${tty_choice}.service"
            sudo systemctl disable "getty@tty${tty_choice}.service"
            log_ok "ly service enabled and getty disabled at tty${tty_choice}."
        else
            log_error "Invalid tty choice: '$tty_choice'. Please choose a number between 1 and 6."
            return 1
        fi
    else
        log_skip "Skipping ly service configuration."
    fi
}

# CLI Entrypoint
case "${1:-}" in
    --check)
        if find_ly >/dev/null; then
            log_ok "ly is installed."
            exit 0
        else
            log_warn "ly is not installed."
            exit 1
        fi
        ;;
    --dry-run)
        setup_ly 1
        ;;
    --help|-h)
        echo "Usage: $0 [--check | --dry-run]"
        exit 0
        ;;
    *)
        setup_ly 0
        ;;
esac
