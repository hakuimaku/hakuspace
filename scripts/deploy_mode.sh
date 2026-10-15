#!/usr/bin/env bash
# HakuSpace Deployment Mode Selection & Detection
# Determines whether HakuSpace is operating in Symlink or Copy mode.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/registry.sh"

select_mode() {
    ui_print ""
    ui_print "${C_DIM}${UI_LINE}${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}DOTFILES DEPLOYMENT MODE${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[1]${C_RESET} Symlink — Recommended"
    ui_print "    ${C_DIM}HakuSpace deep-symlinks tracked files.${C_RESET}"
    ui_print "    ${C_DIM}Editing managed files in ~/.config updates the repository.${C_RESET}"
    ui_print ""
    ui_print "${C_BOLD}[2]${C_RESET} Copy — Legacy"
    ui_print "    ${C_DIM}Files are copied normally.${C_RESET}"
    ui_print "    ${C_DIM}Editing ~/.config does not update the repository.${C_RESET}"
    ui_print ""
    ui_print "${C_DIM}${UI_LINE}${C_RESET}"

    local deploy_choice=""
    ui_prompt "Choose deployment mode [1-2] (default: 1): " deploy_choice
    deploy_choice="${deploy_choice:-1}"

    local mode="symlink"
    local display_mode="Symlink"
    case "${deploy_choice,,}" in
        1|s|symlink)
            mode="symlink"
            display_mode="Symlink"
            ;;
        2|c|copy)
            mode="copy"
            display_mode="Copy"
            ;;
        *)
            ui_print "${C_YELLOW}[WARN]${C_RESET}   Unknown choice '$deploy_choice', defaulting to Symlink."
            mode="symlink"
            display_mode="Symlink"
            ;;
    esac

    ui_print "${C_GREEN}[OK]${C_RESET}     Selected deployment mode: $display_mode"

    export HAKUSPACE_DEPLOY_MODE="$mode"
    printf '%s\n' "$mode"
}

_detect_recursive() {
    local src="$1"
    local dst="$2"
    if [[ -d "$src" ]]; then
        local shopt_state
        shopt_state="$(shopt -p dotglob nullglob || true)"
        shopt -s dotglob nullglob
        local i
        for i in "$src"/*; do
            _detect_recursive "$i" "$dst/${i##*/}"
        done
        eval "$shopt_state"
    else
        if [[ -e "$dst" || -L "$dst" ]]; then
            total_checked=$((total_checked + 1))
            if [[ -L "$dst" ]]; then
                symlink_count=$((symlink_count + 1))
                symlink_list+=("$dst")
            else
                copy_count=$((copy_count + 1))
                copy_list+=("$dst")
            fi
        fi
    fi
    return 0
}

detect_mode() {
    local silent=0
    if [[ "${1:-}" == "--silent" ]]; then
        silent=1
    fi

    if [[ -n "${HAKUSPACE_DEPLOY_MODE:-}" ]]; then
        printf '%s\n' "$HAKUSPACE_DEPLOY_MODE"
        return 0
    fi

    local symlink_count=0
    local copy_count=0
    local total_checked=0
    local symlink_list=()
    local copy_list=()

    # Query common configs from registry
    while IFS='|' read -r src dst; do
        [[ -e "$src" ]] || continue
        _detect_recursive "$src" "$dst"
    done < <(registry_get_common_configs)

    # Check key core scripts
    for script in haku_theme.sh taskbar_manager.sh waybar_manager.sh; do
        local dst="$DEST_BIN/$script"
        if [[ -e "$dst" || -L "$dst" ]]; then
            total_checked=$((total_checked + 1))
            if [[ -L "$dst" ]]; then
                symlink_count=$((symlink_count + 1))
                symlink_list+=("$dst")
            else
                copy_count=$((copy_count + 1))
                copy_list+=("$dst")
            fi
        fi
    done

    local mode="symlink"
    if [[ $total_checked -eq 0 ]]; then
        mode="symlink"
    elif [[ $symlink_count -eq $total_checked ]]; then
        mode="symlink"
    elif [[ $copy_count -eq $total_checked ]]; then
        mode="copy"
    else
        # Mixed state
        if [[ $silent -eq 1 ]]; then
            if [[ $copy_count -lt $symlink_count ]]; then
                mode="symlink"
            else
                mode="copy"
            fi
        else
            ui_print ""
            ui_print "${C_YELLOW}[WARN]${C_RESET}   Mixed deployment state detected ($symlink_count symlinks, $copy_count copies)."
            if [[ $copy_count -lt $symlink_count ]]; then
                ui_print "${C_CYAN}The following files are COPIES (Real files), but the rest are symlinks:${C_RESET}"
                local limit=$(( copy_count > 20 ? 20 : copy_count ))
                for (( i=0; i<limit; i++ )); do
                    ui_print "  - $(shorten_path "${copy_list[i]}")"
                done
                [[ $copy_count -gt 20 ]] && ui_print "  ... and $((copy_count - 20)) more"
            else
                ui_print "${C_MAGENTA}The following files are SYMLINKS, but the rest are copies:${C_RESET}"
                local limit=$(( symlink_count > 20 ? 20 : symlink_count ))
                for (( i=0; i<limit; i++ )); do
                    ui_print "  - $(shorten_path "${symlink_list[i]}")"
                done
                [[ $symlink_count -gt 20 ]] && ui_print "  ... and $((symlink_count - 20)) more"
            fi
            ui_print ""
            ui_print "${C_BOLD}MIXED DEPLOYMENT MODE RESOLUTION${C_RESET}"
            ui_print "  ${C_BOLD}[1]${C_RESET} Symlink (Deep-symlink tracked files)"
            ui_print "  ${C_BOLD}[2]${C_RESET} Copy    (Copy files normally)"
            ui_print ""

            local choice=""
            while true; do
                ui_prompt "Choose deployment mode [1-2 / s/c] (default: 1): " choice
                choice="${choice:-1}"
                case "${choice,,}" in
                    1|s|symlink)
                        mode="symlink"
                        break
                        ;;
                    2|c|copy)
                        mode="copy"
                        break
                        ;;
                    *)
                        ui_print "Please answer '1' (s) or '2' (c)."
                        ;;
                esac
            done
        fi
    fi

    export HAKUSPACE_DEPLOY_MODE="$mode"
    printf '%s\n' "$mode"
}

# CLI Entrypoint
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        select)
            select_mode
            ;;
        detect)
            shift
            detect_mode "$@"
            ;;
        --help|-h)
            ui_print "Usage: $0 [select | detect [--silent]]"
            exit 0
            ;;
        *)
            detect_mode "$@"
            ;;
    esac
fi
