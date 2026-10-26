#!/usr/bin/env bash
# HakuSpace Installation Orchestrator
# Orchestrates modules under scripts/ without direct deployment logic.

set -e

HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# 1. Initialize Runtime Context & Helpers
source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/runtime.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/registry.sh"

print_header ">>> CONFIG INSTALLER <<<" "Press CTRL+C to cancel at any time."

# 2. Window Manager & Deployment Mode Selection
step_title "1 - SELECTION & PREPARATION"
WM_LIST="$("$HAKU_DIR/scripts/select_wm.sh")"
read -ra SELECTED_WMS <<< "$WM_LIST"
log_ok "Selected Window Manager(s): $(registry_format_wm_list "${SELECTED_WMS[@]}")"

DEPLOY_MODE="$("$HAKU_DIR/scripts/deploy_mode.sh" select)"
export HAKUSPACE_DEPLOY_MODE="$DEPLOY_MODE"

# 3. Check Dependencies (yay, git, curl)
step_title "2 - SYSTEM DEPENDENCIES"
"$HAKU_DIR/scripts/dependencies.sh"

# 4. Install Packages (Install Profile)
step_title "3 - INSTALL PACKAGES"
"$HAKU_DIR/scripts/packages.sh" --profile install "${SELECTED_WMS[@]}" --plan
echo ""
if ask_yes_no "Install the package groups shown above?"; then
    "$HAKU_DIR/scripts/packages.sh" --profile install "${SELECTED_WMS[@]}"
else
    log_skip "Skipping package installation."
fi

# 5. Base Directories
step_title "4 - DIRECTORIES"
"$HAKU_DIR/scripts/directories.sh"

# 6. NixOS Integration (Install phase)
if [[ -n "$(command -v nixos-rebuild 2>/dev/null)" ]]; then
    step_title "4.1 - NIXOS CONFIGURATION"
    "$HAKU_DIR/scripts/nixos.sh" install
fi

# 7. Deploy Dotfiles
step_title "5 - DEPLOY DOTFILES CONFIGURATIONS"
# Always deploy ONCE configs first
"$HAKU_DIR/scripts/once_configs.sh"

if [[ "$DEPLOY_MODE" == "symlink" ]]; then
    log_info "Deploying configurations using Symlink mode..."
    "$HAKU_DIR/scripts/link.sh" --all
    for wm in "${SELECTED_WMS[@]}"; do
        "$HAKU_DIR/scripts/link.sh" "$wm"
    done
    "$HAKU_DIR/scripts/core.sh" --mode symlink
else
    log_info "Deploying configurations using Legacy Copy mode..."
    "$HAKU_DIR/scripts/legacy_copy.sh" install "${SELECTED_WMS[@]}"
fi

# 8. Independent visual sources and optional wallpaper archive.
step_title "6 - VISUAL ECOSYSTEM & WALLPAPERS"
echo "  • Visual sources: independent HAKU_*_SOURCE paths (fallback: ~/haku-cursor, ~/hikade-gtk-theme, ~/hikaide-symbols)"
echo "  • Wallpaper archive: $(shorten_path "$ARCHIVE_DIR")"
if ask_yes_no "Install/update the HakuSpace visual ecosystem?"; then
    "$HAKU_DIR/scripts/setup.sh" setup
    if ask_yes_no "Generate a VS Code multi-root workspace?"; then
        "$HAKU_DIR/scripts/setup.sh" workspace || log_warn "Workspace generation skipped; visual installation completed."
    fi
else
    log_skip "Skipping visual ecosystem setup."
fi
if ask_yes_no "Install/update HakuSpace wallpapers?"; then
    "$HAKU_DIR/scripts/assets.sh"
else
    log_skip "Skipping wallpapers."
fi

# 9. State & User Environment Setup
step_title "7 - FINAL SYSTEM & DESKTOP SETUP"
"$HAKU_DIR/scripts/state.sh" init
"$HAKU_DIR/scripts/hakucfg.sh" sync
"$HAKU_DIR/scripts/shell_setup.sh"

# NixOS rebuild if on NixOS
if [[ -n "$(command -v nixos-rebuild 2>/dev/null)" ]]; then
    "$HAKU_DIR/scripts/nixos.sh" rebuild
fi

"$HAKU_DIR/scripts/display_manager.sh"
"$HAKU_DIR/scripts/desktop_defaults.sh"

# 10. Run Diagnostics
step_title "8 - SYSTEM DIAGNOSTICS"
"$HAKU_DIR/scripts/doctor.sh"

echo ""
print_divider
echo -e "${C_BOLD}${C_GREEN}  All done! Please restart your pc to apply changes!${C_RESET}"
echo -e "${C_MAGENTA}  Backup folder for this run: $BACKUP_DIR${C_RESET}"
print_divider
