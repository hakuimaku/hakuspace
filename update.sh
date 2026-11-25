#!/usr/bin/env bash
# HakuSpace Update Orchestrator
# Orchestrates modules under scripts/ without direct deployment logic.

set -e

HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

source "$HAKU_DIR/scripts/run_log.sh"
start_run_log update "$@"

# 1. Initialize Runtime Context & Helpers
source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/runtime.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/registry.sh"

# Preserve the first recoverable failure code while collecting remaining diagnostics.
UPDATE_FAILED=0
UPDATE_NORMAL_EXIT=0
CURRENT_BLOCK="INITIALIZATION"
FAILED_BLOCKS=()

begin_block() {
    CURRENT_BLOCK="${1:-UNKNOWN}"
    step_title "$CURRENT_BLOCK"
}

record_failure() {
    local code="${1:-1}"
    local block="${2:-$CURRENT_BLOCK}"
    if [[ "$UPDATE_FAILED" == 0 ]]; then UPDATE_FAILED="$code"; fi
    local entry="${block} (exit=${code})"
    local existing
    for existing in "${FAILED_BLOCKS[@]}"; do
        if [[ "$existing" == "$entry" ]]; then
            return 0
        fi
    done
    FAILED_BLOCKS+=("$entry")
}

# Fatal preflight/deployment errors and normal completion share the same final report.
report_update() {
    local status=$?
    if [[ "$status" != 0 && "${UPDATE_NORMAL_EXIT:-0}" != 1 ]]; then
        record_failure "$status" "$CURRENT_BLOCK"
    fi
    echo ""
    print_divider
    if [[ "$UPDATE_FAILED" == 0 ]]; then
        log_ok "Update complete! Restart session or reload WM to apply!"
    else
        log_warn "PARTIAL / BLOCKED: update failed (exit=$UPDATE_FAILED); no completion recorded for this run. Review failures and rerun."
        if [[ ${#FAILED_BLOCKS[@]} -gt 0 ]]; then
            log_error "Failed block(s):"
            local block_entry
            for block_entry in "${FAILED_BLOCKS[@]}"; do
                echo -e "${C_RED}    • ${block_entry}${C_RESET}"
            done
        fi
    fi
    echo -e "${C_MAGENTA}  Backup folder for this update: $BACKUP_DIR${C_RESET}"
    if [[ -n "${HAKUSPACE_LOG_FILE:-}" ]]; then
        echo -e "${C_DIM}  Log file for this update: $HAKUSPACE_LOG_FILE${C_RESET}"
    fi
    print_divider
}
trap report_update EXIT

print_header ">>> CONFIG UPDATER <<<"

# 2. Update Dotfiles Repository
begin_block "0 - UPDATE DOTFILES REPOSITORY"
if [[ "${HAKUSPACE_REPO_UPDATED:-0}" != 1 ]]; then
    REPO_UPDATE_STATUS=0
    "$HAKU_DIR/scripts/repo_update.sh" --target-script "$HAKU_DIR/update.sh" || REPO_UPDATE_STATUS=$?
    if [[ $REPO_UPDATE_STATUS -ne 0 && $REPO_UPDATE_STATUS -ne 10 ]]; then
        if ask_yes_no "Repository update failed (exit=$REPO_UPDATE_STATUS). Perform a safe reclone of the repository?"; then
            REPO_UPDATE_STATUS=0
            "$HAKU_DIR/scripts/repo_update.sh" --reclone || REPO_UPDATE_STATUS=$?
        fi
    fi
    if [[ $REPO_UPDATE_STATUS -eq 10 ]]; then
        log_info "Re-executing updated logic..."
        log_info "Backup folder for this update: $BACKUP_DIR"
        export HAKUSPACE_REPO_UPDATED=1
        exec "$HAKU_DIR/update.sh" "$@"
    elif [[ $REPO_UPDATE_STATUS -ne 0 ]]; then
        log_error "Repository update failed (exit=$REPO_UPDATE_STATUS); deployment stopped."
        exit "$REPO_UPDATE_STATUS"
    fi
fi

"$HAKU_DIR/scripts/migrate.sh" --plan --to v26.12
export HAKUSPACE_MIGRATION_PLAN_SHOWN=1

# 3. Select Window Manager(s) & Detect Deploy Mode
begin_block "1 - SELECTION & MODE DETECTION"
WM_LIST="$("$HAKU_DIR/scripts/select_wm.sh")"
read -ra SELECTED_WMS <<< "$WM_LIST"
log_ok "Selected Window Manager(s): $(registry_format_wm_list "${SELECTED_WMS[@]}")"

DEPLOY_MODE="$("$HAKU_DIR/scripts/deploy_mode.sh" detect)"
export HAKUSPACE_DEPLOY_MODE="$DEPLOY_MODE"
if [[ "$DEPLOY_MODE" == "copy" ]]; then
    log_ok "Detected deployment mode: Copy"
else
    log_ok "Detected deployment mode: Symlink"
fi

# 4. Update Packages (Update Profile)
begin_block "2 - UPDATE PACKAGES"
"$HAKU_DIR/scripts/packages.sh" --profile update "${SELECTED_WMS[@]}" --plan
echo ""
if command -v nixos-rebuild >/dev/null 2>&1; then
    log_skip "NixOS packages are managed by the system configuration below."
elif ask_yes_no "Install/update the package groups shown above?"; then
    "$HAKU_DIR/scripts/packages.sh" --repair-missing --profile update "${SELECTED_WMS[@]}" || record_failure $?
else
    log_skip "Skipping package update."
fi

# 5. Deploy / Update Dotfiles Configs
begin_block "3 - UPDATE CONFIGURATIONS"
echo -e "${C_BOLD}CONFIGURATION UPDATE PLAN${C_RESET}"
echo "  • Deployment Mode:   $( [[ "$DEPLOY_MODE" == "copy" ]] && echo "Copy (Legacy)" || echo "Symlink (Deep Symlink)" )"
echo "  • Window Manager(s): $(registry_format_wm_list "${SELECTED_WMS[@]}")"
echo "  • Managed Scope:     Common base configs, selected WM configs, and ~/.local/bin core scripts"
echo "  • Untouched:         ONCE_CONFIGS (${ONCE_CONFIG_NAMES[*]}), ~/hakucfg custom settings"
echo ""
if ask_yes_no "Apply the configuration update plan shown above?" y; then
    if [[ "$DEPLOY_MODE" == "symlink" ]]; then
        log_info "Updating configurations using Symlink mode..."
        "$HAKU_DIR/scripts/link.sh" --all
        for wm in "${SELECTED_WMS[@]}"; do
            "$HAKU_DIR/scripts/link.sh" "$wm"
        done
    else
        log_info "Updating configurations using Legacy Copy mode..."
        "$HAKU_DIR/scripts/legacy_copy.sh" update "${SELECTED_WMS[@]}"
    fi
    MIGRATION_STATUS=0
    "$HAKU_DIR/scripts/migrate.sh" --apply --to v26.12 || MIGRATION_STATUS=$?
    if [[ "$MIGRATION_STATUS" == 0 ]]; then
        log_ok "Configuration deployment and migration steps applied; final checks pending."
    else
        record_failure "$MIGRATION_STATUS"
        log_error "Configuration deployed, but migration failed (exit=$MIGRATION_STATUS); review the backup and rerun after repair."
    fi
else
    log_skip "Skipping config update; migration remains pending."
    record_failure 1
fi

# Reuse installed visuals; source refreshes remain an explicit setup.sh update operation.
begin_block "VISUAL ECOSYSTEM - GTK THEME, ICONS, CURSOR SETUP"
"$HAKU_DIR/scripts/setup.sh" status >/dev/null || record_failure $?
# A failed activation resumes before any component starts another asset download.
ACTIVATION_PENDING=0
"$HAKU_DIR/scripts/setup.sh" pending || ACTIVATION_PENDING=$?
if [[ "$ACTIVATION_PENDING" == 0 ]]; then
    "$HAKU_DIR/scripts/setup.sh" update || record_failure $?
elif [[ "$ACTIVATION_PENDING" == 1 ]]; then
    _vs_has_missing=0
    _vs_missing_components=()
    for component in cursor cassettsor gtk cassettk symbols cassetton; do
        case "$component" in
            gtk)        _vs_label="Theme (Hikaide)" ;;
            cassettk)   _vs_label="Theme (Cassettk)" ;;
            symbols)    _vs_label="Icons (Hikaide-Symbols)" ;;
            cassetton)  _vs_label="Icons (Cassetton)" ;;
            cursor)     _vs_label="Cursor (Haku)" ;;
            cassettsor) _vs_label="Cursor (Cassettsor)" ;;
            *)          _vs_label="$component" ;;
        esac
        if "$HAKU_DIR/scripts/setup.sh" verify "$component" >/dev/null 2>&1; then
            log_skip "VISUAL STATUS: $_vs_label already installed."
        elif "$HAKU_DIR/scripts/setup.sh" path "$component" >/dev/null 2>&1; then
            _vs_has_missing=1
            _vs_missing_components+=("$component")
            log_skip "VISUAL STATUS: $_vs_label missing."
        elif ask_yes_no "Install/repair $_vs_label from its upstream source?" y; then
            "$HAKU_DIR/scripts/setup.sh" apply "$component" || record_failure $?
        else
            _vs_has_missing=1
            log_skip "VISUAL STATUS: $_vs_label installation/repair skipped."
        fi
    done
    _vs_update_prompt="Check for updates and rebuild/replace visual ecosystem components?"
    if [[ "$_vs_has_missing" == 1 ]]; then
        _vs_update_prompt="Something is missing, setup again?"
    fi
    if ask_yes_no "$_vs_update_prompt"; then
        log_info "Updating visual ecosystem components..."
        _vs_update_log="$(mktemp)"
        _vs_update_ok=1
        for _vs_comp in "${_vs_missing_components[@]}"; do
            if ! "$HAKU_DIR/scripts/setup.sh" apply "$_vs_comp" >>"$_vs_update_log" 2>&1; then
                _vs_rc=$?
                _vs_update_ok=0
            fi
        done
        if [[ "$_vs_update_ok" == 1 && "$_vs_has_missing" == 0 ]]; then
            if ! "$HAKU_DIR/scripts/setup.sh" update >>"$_vs_update_log" 2>&1; then
                _vs_rc=$?
                _vs_update_ok=0
            fi
        fi
        if [[ "$_vs_update_ok" == 1 ]]; then
            log_ok "Visual ecosystem updated."
        else
            cat "$_vs_update_log"
            record_failure "$_vs_rc"
        fi
        rm -f "$_vs_update_log"
    else
        log_skip "Visual ecosystem update check skipped."
    fi
else
    log_error "Unsafe visual activation state; asset updates skipped."
    record_failure "$ACTIVATION_PENDING"
fi

begin_block "WALLPAPERS"
if ask_yes_no "Update HakuSpace wallpapers from archive (adds missing wallpapers without overwriting existing ones)?"; then
    "$HAKU_DIR/scripts/assets.sh" || record_failure $?
else
    log_skip "Wallpaper update skipped."
fi

# 6. NixOS Update (if on NixOS)
if [[ -n "$(command -v nixos-rebuild 2>/dev/null)" ]]; then
    begin_block "4 - NIXOS SYSTEM UPDATE"
    "$HAKU_DIR/scripts/nixos.sh" update || record_failure $?
fi

# 7. State & User Control Initialization
begin_block "5 - STATE & CONFIGURATION SYNC"
"$HAKU_DIR/scripts/state.sh" init || record_failure $?
"$HAKU_DIR/scripts/hakucfg.sh" sync || record_failure $?

# 8. Reload Active Components
begin_block "6 - RELOAD ACTIVE COMPONENTS"
if [[ "$UPDATE_FAILED" == 0 ]]; then
    "$HAKU_DIR/scripts/reload.sh" all || record_failure $?
else
    log_skip "Skipping reload after failed required steps; continuing diagnostics."
fi

# 9. Diagnostics Check
begin_block "7 - DIAGNOSTICS & INTEGRITY"
if [[ "$UPDATE_FAILED" == 0 ]]; then
    HAKUSPACE_UPDATE_PRE_COMPLETE=1 "$HAKU_DIR/scripts/doctor.sh" || record_failure $?
else
    "$HAKU_DIR/scripts/doctor.sh" || record_failure $?
fi

if [[ "$UPDATE_FAILED" == 0 ]]; then
    "$HAKU_DIR/scripts/migrate.sh" --complete --to v26.12 || record_failure $?
fi
UPDATE_NORMAL_EXIT=1
exit "$UPDATE_FAILED"
