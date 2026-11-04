#!/usr/bin/env bash
# HakuSpace Update Orchestrator
# Orchestrates modules under scripts/ without direct deployment logic.

set -e

HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# 1. Initialize Runtime Context & Helpers
source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/runtime.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/registry.sh"

# Preserve the first recoverable failure code while collecting remaining diagnostics.
UPDATE_FAILED=0
record_failure() {
    if [[ "$UPDATE_FAILED" == 0 ]]; then UPDATE_FAILED="$1"; fi
}

# Fatal preflight/deployment errors and normal completion share the same final report.
report_update() {
    local status=$?
    if [[ "$status" != 0 ]]; then UPDATE_FAILED="$status"; fi
    echo ""
    print_divider
    if [[ "$UPDATE_FAILED" == 0 ]]; then
        log_ok "Update complete! Restart session or reload WM to apply!"
    else
        log_warn "PARTIAL / BLOCKED: update failed (exit=$UPDATE_FAILED); no completion recorded for this run. Review failures and rerun."
    fi
    echo -e "${C_MAGENTA}  Backup folder for this update: $BACKUP_DIR${C_RESET}"
    print_divider
}
trap report_update EXIT

print_header ">>> CONFIG UPDATER <<<"

# 2. Update Dotfiles Repository
step_title "0 - UPDATE DOTFILES REPOSITORY"
if [[ "${HAKUSPACE_REPO_UPDATED:-0}" != 1 ]]; then
    REPO_UPDATE_STATUS=0
    "$HAKU_DIR/scripts/repo_update.sh" --target-script "$HAKU_DIR/update.sh" || REPO_UPDATE_STATUS=$?
    if [[ $REPO_UPDATE_STATUS -eq 10 ]]; then
        log_info "Re-executing updated logic..."
        export HAKUSPACE_REPO_UPDATED=1
        exec "$HAKU_DIR/update.sh" "$@"
    elif [[ $REPO_UPDATE_STATUS -ne 0 ]]; then
        log_error "Repository update failed (exit=$REPO_UPDATE_STATUS); deployment stopped."
        exit "$REPO_UPDATE_STATUS"
    fi
fi

"$HAKU_DIR/scripts/migrate.sh" --plan --to v26.11

# 3. Select Window Manager(s) & Detect Deploy Mode
step_title "1 - SELECTION & MODE DETECTION"
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
step_title "2 - UPDATE PACKAGES"
"$HAKU_DIR/scripts/packages.sh" --profile update "${SELECTED_WMS[@]}" --plan
echo ""
if command -v nixos-rebuild >/dev/null 2>&1; then
    log_skip "NixOS packages are managed by the system configuration below."
elif ask_yes_no "Install/update the package groups shown above?"; then
    "$HAKU_DIR/scripts/packages.sh" --repair-missing --profile update "${SELECTED_WMS[@]}" || record_failure $?
else
    log_skip "Skipping package update."
fi

if ! command -v nixos-rebuild >/dev/null 2>&1; then
    "$HAKU_DIR/scripts/packages.sh" --audit-runtime || record_failure $?
fi

# 5. Deploy / Update Dotfiles Configs
step_title "3 - UPDATE CONFIGURATIONS"
echo -e "${C_BOLD}CONFIGURATION UPDATE PLAN${C_RESET}"
echo "  • Deployment Mode:   $( [[ "$DEPLOY_MODE" == "copy" ]] && echo "Copy (Legacy)" || echo "Symlink (Deep Symlink)" )"
echo "  • Window Manager(s): $(registry_format_wm_list "${SELECTED_WMS[@]}")"
echo "  • Managed Scope:     Common base configs, selected WM configs, and ~/.local/bin core scripts"
echo "  • Untouched:         ONCE_CONFIGS (${ONCE_CONFIG_NAMES[*]}), ~/hakucfg custom settings"
echo ""
if ask_yes_no "Apply the configuration update plan shown above?"; then
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
    "$HAKU_DIR/scripts/migrate.sh" --apply --to v26.11 || record_failure $?
    log_ok "Configuration deployment finished."
else
    log_skip "Skipping config update; migration remains pending."
    record_failure 1
fi

# Reuse installed visuals; source refreshes remain an explicit setup.sh update operation.
step_title "VISUAL ECOSYSTEM"
"$HAKU_DIR/scripts/setup.sh" status || record_failure $?
# A failed activation resumes before any component starts another asset download.
ACTIVATION_PENDING=0
"$HAKU_DIR/scripts/setup.sh" pending || ACTIVATION_PENDING=$?
if [[ "$ACTIVATION_PENDING" == 0 ]]; then
    "$HAKU_DIR/scripts/setup.sh" update || record_failure $?
elif [[ "$ACTIVATION_PENDING" == 1 ]]; then
    for component in cursor gtk symbols; do
        if "$HAKU_DIR/scripts/setup.sh" path "$component" >/dev/null 2>&1; then
            log_skip "VISUAL STATUS: $component override, skipped; use scripts/setup.sh apply $component explicitly."
        elif "$HAKU_DIR/scripts/setup.sh" verify "$component" >/dev/null 2>&1; then
            log_skip "VISUAL STATUS: $component already installed; use scripts/setup.sh update $component explicitly to refresh assets."
        elif ask_yes_no "Install/repair visual component '$component' from its upstream source?"; then
            "$HAKU_DIR/scripts/setup.sh" apply "$component" || record_failure $?
        else
            log_skip "VISUAL STATUS: $component installation/repair skipped."
        fi
    done
else
    log_error "Unsafe visual activation state; asset updates skipped."
    record_failure "$ACTIVATION_PENDING"
fi

# 6. NixOS Update (if on NixOS)
if [[ -n "$(command -v nixos-rebuild 2>/dev/null)" ]]; then
    step_title "4 - NIXOS SYSTEM UPDATE"
    "$HAKU_DIR/scripts/nixos.sh" update || record_failure $?
fi

# 7. State & User Control Initialization
step_title "5 - STATE & CONFIGURATION SYNC"
"$HAKU_DIR/scripts/state.sh" init || record_failure $?
"$HAKU_DIR/scripts/hakucfg.sh" sync || record_failure $?

# 8. Reload Active Components
step_title "6 - RELOAD ACTIVE COMPONENTS"
if [[ "$UPDATE_FAILED" == 0 ]]; then
    "$HAKU_DIR/scripts/reload.sh" waybar || record_failure $?
else
    log_skip "Skipping reload after failed required steps; continuing diagnostics."
fi

# 9. Diagnostics Check
step_title "7 - DIAGNOSTICS & INTEGRITY"
"$HAKU_DIR/scripts/doctor.sh" || record_failure $?

if [[ "$UPDATE_FAILED" == 0 ]]; then
    "$HAKU_DIR/scripts/migrate.sh" --complete --to v26.11 || record_failure $?
fi
exit "$UPDATE_FAILED"
