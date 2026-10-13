#!/usr/bin/env bash
# HakuSpace Doctor Diagnostics Module
# Performs read-only integrity checks for HakuSpace symlinks, state, and custom configs.
# NEVER writes to the filesystem.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/registry.sh"

BROKEN_LINKS=()
OVERWRITTEN_FILES=()
MISSING_LINKS=()

check_symlink_recursive() {
    local src="$1"
    local dst="$2"

    if [[ -d "$src" ]]; then
        if [[ -e "$dst" && ! -d "$dst" ]]; then
            BROKEN_LINKS+=("Expected directory but found file at: $(shorten_path "$dst")")
        else
            local shopt_state
            shopt_state="$(shopt -p dotglob nullglob || true)"
            shopt -s dotglob nullglob
            local item
            for item in "$src"/*; do
                check_symlink_recursive "$item" "$dst/${item##*/}"
            done
            eval "$shopt_state"
        fi
    else
        if [[ -L "$dst" ]]; then
            local target
            target="$(readlink "$dst")"
            local expected
            expected="$(realpath "$src" 2>/dev/null || echo "$src")"
            if [[ ! -e "$target" ]]; then
                BROKEN_LINKS+=("Broken symlink: $(shorten_path "$dst") -> $target")
            elif [[ "$target" != "$expected" ]]; then
                OVERWRITTEN_FILES+=("Modified symlink (not pointing to BASE): $(shorten_path "$dst") -> $target")
            fi
        elif [[ -e "$dst" ]]; then
            OVERWRITTEN_FILES+=("Config overwritten as real file: $(shorten_path "$dst")")
        else
            MISSING_LINKS+=("Missing symlink: $(shorten_path "$dst")")
        fi
    fi
}

check_module() {
    local src="$1"
    local dst="$2"
    local label="$3"

    local start_issues=$(( ${#BROKEN_LINKS[@]} + ${#OVERWRITTEN_FILES[@]} + ${#MISSING_LINKS[@]} ))
    check_symlink_recursive "$src" "$dst"
    local end_issues=$(( ${#BROKEN_LINKS[@]} + ${#OVERWRITTEN_FILES[@]} + ${#MISSING_LINKS[@]} ))
    local issues=$(( end_issues - start_issues ))

    if [[ $issues -eq 0 ]]; then
        log_ok "$label"
    else
        log_warn "$label (Found $issues issue$([ $issues -gt 1 ] && echo 's'))"
    fi
}

run_doctor() {
    print_divider
    echo -e "${C_BOLD}>>> HAKUSPACE DOCTOR <<<${C_RESET}"
    echo -e "Read-only system integrity and diagnostics."
    print_divider

    step_title "Checking Deployment Integrity"

    local deploy_mode
    deploy_mode="$("$HAKU_DIR/scripts/deploy_mode.sh" detect --silent)"
    if [[ "$deploy_mode" == "copy" ]]; then
        log_info "Deployment mode is 'copy'. Skipping symlink integrity check."
    fi

    if [[ "$deploy_mode" == "symlink" ]]; then
        # 1. Check common base configs
        while IFS='|' read -r src dst; do
            [[ -z "$src" ]] && continue
            local name
            name="$(basename "$dst")"
            check_module "$src" "$dst" "$name ($(shorten_path "$dst"))"
        done < <(registry_get_common_configs)

        # 2. Check Core scripts
        local start_scripts_issues
        start_scripts_issues=$(( ${#BROKEN_LINKS[@]} + ${#OVERWRITTEN_FILES[@]} + ${#MISSING_LINKS[@]} ))
        while IFS='|' read -r src dst; do
            [[ -z "$src" ]] && continue
            check_symlink_recursive "$src" "$dst"
        done < <(registry_get_core_scripts)
        local scripts_issues
        scripts_issues=$(( (${#BROKEN_LINKS[@]} + ${#OVERWRITTEN_FILES[@]} + ${#MISSING_LINKS[@]} - start_scripts_issues) ))

        if [[ $scripts_issues -eq 0 ]]; then
            log_ok "Core Scripts ($(shorten_path "$DEST_BIN"))"
        else
            log_warn "Core Scripts ($(shorten_path "$DEST_BIN")) - Found $scripts_issues issue$([ $scripts_issues -gt 1 ] && echo 's')"
        fi

        # 3. Check installed Window Managers
        for wm in niri mango labwc; do
            if [[ -d "$DEST_CONFIG/$wm" ]]; then
                check_module "$SOURCE_CONFIG/$wm" "$DEST_CONFIG/$wm" "Window Manager: $wm"
            fi
        done
        if [[ -d "$DEST_CONFIG/hypr" ]]; then
            check_module "$SOURCE_CONFIG/hypr/config" "$DEST_CONFIG/hypr/config" "Hyprland: config"
            check_module "$SOURCE_CONFIG/hypr/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua" "Hyprland: hyprland.lua"
        fi
    fi

    # Summary of symlink diagnostics
    local total_issues
    total_issues=$(( ${#BROKEN_LINKS[@]} + ${#OVERWRITTEN_FILES[@]} + ${#MISSING_LINKS[@]} ))

    if [[ $total_issues -gt 0 ]]; then
        step_title "Issue Details"

        if [[ ${#BROKEN_LINKS[@]} -gt 0 ]]; then
            echo -e "${C_RED}Broken Symlinks:${C_RESET}"
            for issue in "${BROKEN_LINKS[@]}"; do
                echo "  - $issue"
            done
        fi

        if [[ ${#MISSING_LINKS[@]} -gt 0 ]]; then
            echo -e "${C_YELLOW}Missing Symlinks:${C_RESET}"
            for issue in "${MISSING_LINKS[@]}"; do
                echo "  - $issue"
            done
        fi

        if [[ ${#OVERWRITTEN_FILES[@]} -gt 0 ]]; then
            echo -e "${C_YELLOW}Overwritten Real Files (Should be Symlinks):${C_RESET}"
            for issue in "${OVERWRITTEN_FILES[@]}"; do
                echo "  - $issue"
            done
        fi

        echo ""
        print_divider
        log_error "Detected $total_issues issues with symlink integrity."
        echo -e "${C_BOLD}Remediation:${C_RESET}"
        echo "  To link specific missing modules: ./link.sh <module_name>"
        echo "  To restore all base links:        ./link.sh --all"
        echo "  To run full update:               ./update.sh"
        print_divider
    else
        if [[ "$deploy_mode" == "symlink" ]]; then
            echo ""
            print_divider
            log_ok "All checked configs are healthy and properly symlinked!"
            print_divider
        fi
    fi

    echo ""
    step_title "Checking HakuSpace State & Custom Configurations"

    local state_ok=1
    local hakucfg_ok=1

    if ! "$HAKU_DIR/scripts/state.sh" check; then
        state_ok=0
        log_warn "Remediation for state: scripts/state.sh init"
    fi

    if ! "$HAKU_DIR/scripts/hakucfg.sh" check; then
        hakucfg_ok=0
        log_warn "Remediation for hakucfg: scripts/hakucfg.sh sync"
    fi

    echo ""
    if [[ $total_issues -eq 0 && $state_ok -eq 1 && $hakucfg_ok -eq 1 ]]; then
        log_ok "Doctor check completed: Everything is in order!"
        return 0
    else
        log_warn "Doctor check completed with warnings/issues."
        return 0
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_doctor
fi
