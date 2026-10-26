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

print_header ">>> CONFIG UPDATER <<<"

# 2. Update Dotfiles Repository
step_title "0 - UPDATE DOTFILES REPOSITORY"
set +e
"$HAKU_DIR/scripts/repo_update.sh" --target-script "$0"
REPO_UPDATE_STATUS=$?
set -e

if [[ $REPO_UPDATE_STATUS -eq 10 ]]; then
    log_info "Re-executing $0 with updated logic..."
    exec "$0" "$@"
elif [[ $REPO_UPDATE_STATUS -ne 0 ]]; then
    log_warn "Repository update returned status $REPO_UPDATE_STATUS. Proceeding with update..."
fi

# Check visual sources only after any updater re-exec has completed.
step_title "1 - UPDATE VISUAL ECOSYSTEM"
VISUAL_UPDATE_STATUS=0
"$HAKU_DIR/scripts/setup.sh" update || VISUAL_UPDATE_STATUS=$?
if [[ "$VISUAL_UPDATE_STATUS" -ne 0 ]]; then
    log_warn "Visual ecosystem update incomplete; continuing packages and configurations."
fi

# 3. Select Window Manager(s) & Detect Deploy Mode
step_title "2 - SELECTION & MODE DETECTION"
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
step_title "3 - UPDATE PACKAGES"
"$HAKU_DIR/scripts/packages.sh" --profile update "${SELECTED_WMS[@]}" --plan
echo ""
if ask_yes_no "Install/update the package groups shown above?"; then
    "$HAKU_DIR/scripts/packages.sh" --profile update "${SELECTED_WMS[@]}"
else
    log_skip "Skipping package update."
fi

# 5. Deploy / Update Dotfiles Configs
step_title "4 - UPDATE CONFIGURATIONS"
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
        "$HAKU_DIR/scripts/core.sh" --mode symlink
    else
        log_info "Updating configurations using Legacy Copy mode..."
        "$HAKU_DIR/scripts/legacy_copy.sh" update "${SELECTED_WMS[@]}"
    fi
    log_ok "Configurations updated successfully."
else
    log_skip "Skipping config update."
fi

# 6. NixOS Update (if on NixOS)
if [[ -n "$(command -v nixos-rebuild 2>/dev/null)" ]]; then
    step_title "5 - NIXOS SYSTEM UPDATE"
    "$HAKU_DIR/scripts/nixos.sh" update
fi

# 7. State & User Control Initialization
step_title "6 - STATE & CONFIGURATION SYNC"
"$HAKU_DIR/scripts/state.sh" init
"$HAKU_DIR/scripts/hakucfg.sh" sync

# 8. Reload Active Components
step_title "7 - RELOAD ACTIVE COMPONENTS"
"$HAKU_DIR/scripts/reload.sh" waybar

# 9. Diagnostics Check
step_title "8 - DIAGNOSTICS & INTEGRITY"
"$HAKU_DIR/scripts/doctor.sh"

echo ""
print_divider
if [[ "$VISUAL_UPDATE_STATUS" -eq 0 ]]; then
    echo -e "${C_BOLD}${C_GREEN}  Update complete! Restart session or reload WM to apply!${C_RESET}"
else
    log_warn "HakuSpace update finished with an incomplete visual ecosystem update; inspect errors and retry scripts/setup.sh."
fi
echo -e "${C_MAGENTA}  Backup folder for this update: $BACKUP_DIR${C_RESET}"
print_divider

exit "$VISUAL_UPDATE_STATUS"
