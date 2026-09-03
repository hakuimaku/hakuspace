#!/usr/bin/env bash
set -u

cat << 'EOF'

 _   _       _          _____                      
| | | |     | |        /  ___|                     
| |_| | __ _| | ___   _\ `--. _ __   __ _  ___ ___ 
|  _  |/ _` | |/ / | | |`--. \ '_ \ / _` |/ __/ _ \
| | | | (_| |   <| |_| /\__/ / |_) | (_| | (_|  __/
\_| |_|\__,_|_|\_\\__,_\____/| .__/ \__,_|\___\___|
                             | |                   
                             |_|                       

            >>> CONFIG UPDATER <<<

EOF

HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

chmod +x ./scripts/*
source "./scripts/variables.sh"
source "./scripts/functions.sh"

# ======================================================================================
# MAIN FLOW
# ======================================================================================

print_header

# ============================================================================
# BLOCK 0: UPDATE REPOSITORY (LATEST vs STABLE)
# ============================================================================
step_title "0 - UPDATE DOTFILES REPOSITORY"

SCRIPT_NAME=$(basename "$0")
BACKUP_SCRIPT="/tmp/${SCRIPT_NAME}.bak"

cp "$0" "$BACKUP_SCRIPT"

echo "Select update mode:"
echo -e "${C_BOLD}[1]${C_RESET} LATEST (Pull from main branch - Try the lastest changes)"
echo -e "${C_BOLD}[2]${C_RESET} STABLE (Checkout latest release tag - Recommended for stability)"
echo -e "${C_BOLD}[0]${C_RESET} SKIP (Do not update repository)"
echo ""
read -r -p ">>> Choose mode (1/2/0): " update_mode

REPO_CHANGED=0

if [[ "$update_mode" == "1" ]]; then
    log_info "Switching to main branch and pulling latest changes..."
    git -C "$HAKU_DIR" checkout main
    git -C "$HAKU_DIR" pull origin main
    log_ok "Repository updated to LATEST."
    REPO_CHANGED=1
elif [[ "$update_mode" == "2" ]]; then
    log_info "Fetching tags from remote..."
    git -C "$HAKU_DIR" fetch --tags
    LATEST_TAG=$(git -C "$HAKU_DIR" describe --tags $(git -C "$HAKU_DIR" rev-list --tags --max-count=1) 2>/dev/null)
    if [[ -z "$LATEST_TAG" ]]; then
        log_warn "No tags found in repository. Falling back to main branch."
        git -C "$HAKU_DIR" checkout main
        git -C "$HAKU_DIR" pull origin main
    else
        log_info "Latest stable tag found: $LATEST_TAG"
        git -C "$HAKU_DIR" checkout "$LATEST_TAG"
        log_ok "Repository updated to STABLE ($LATEST_TAG)."
    fi
    REPO_CHANGED=1
elif [[ "$update_mode" == "0" ]]; then
    log_skip "Skipping repository update."
else
    log_error "Invalid choice. Skipping repository update."
fi

if [[ "$REPO_CHANGED" -eq 1 && -f "$BACKUP_SCRIPT" ]]; then
    if ! cmp -s "$BACKUP_SCRIPT" "$0"; then
        echo ""
        log_warn "Detecting that '$SCRIPT_NAME' has new updates in repository!"
        log_info "Re-executing script with updated logic..."
        rm -f "$BACKUP_SCRIPT"
        exec "$0" "$@"
    fi
    rm -f "$BACKUP_SCRIPT"
fi

# Then select window manager(s) to update configs and packages
select_window_manager

# ============================================================================
# BLOCK 1: UPDATE PACKAGES
# ============================================================================
step_title "1 - UPDATE PACKAGES FROM LISTS"

PKG_LABELS=()
PKG_FILES=()

if command -v yay >/dev/null 2>&1; then
    for i in "${!SELECTED_WMS[@]}"; do
        wm_name="${SELECTED_WMS[$i]}"
        wm_upper=$(echo "$wm_name" | tr '[:lower:]' '[:upper:]')
        PKG_LABELS+=("$wm_upper")
        PKG_FILES+=("${SELECTED_PKG_WMS[$i]}")
    done

    # Add common core, service, optional packages
    PKG_LABELS+=("CORE" "SERVICE")
    PKG_FILES+=("$PKG_CORE" "$PKG_SERVICE")

    echo ">>> Package lists to be updated automatically:"
    for i in "${!PKG_LABELS[@]}"; do
        echo "  - ${PKG_LABELS[$i]}: ${PKG_FILES[$i]}"
    done
    echo ""

    if ask_yes_no "===> Do you want to install/update ALL packages now?"; then
        for i in "${!PKG_LABELS[@]}"; do
            label="${PKG_LABELS[$i]}"
            file="${PKG_FILES[$i]}"
            install_pkg_file "$label" "$file"
        done
        log_ok "All package installations/updates completed."
    else
        log_skip "Skipping package installation/update."
    fi
else
    log_error "yay is not installed. Please install yay first to run this step."
    log_error "If you're using another distro, install packages manually."
fi

# ============================================================================
# BLOCK 2: BACKUP AND COPY CONFIG
# ============================================================================
step_title "2 - BACKUP AND UPDATE CONFIG IN ~/.config"

if ask_yes_no "===> Do you want to update hakuspace configs now?"; then

    echo ">>> Deploying configs..."
    for folder in "$SOURCE_CONFIG"/*/; do
        [[ -d "$folder" ]] || continue
        folder_name="$(basename "$folder")"
        # Deloy config not in the list of ONCE_CONFIGS and SKIP_CONFIGS
        if [[ " ${ONCE_CONFIGS[*]} " == *" $folder "* || " ${SKIP_CONFIGS[*]} " == *" $folder "* ]]; then
            continue
        fi
        copy_dir_content "$SOURCE_COMMON_CONFIG/$folder_name" "$DEST_CONFIG/$folder_name"
    done
    copy_file "$SOURCE_CONFIG/hypr/hypridle.conf" "$DEST_CONFIG/hypr/hypridle.conf"
    copy_file "$SOURCE_CONFIG/hypr/hyprlock.conf" "$DEST_CONFIG/hypr/hyprlock.conf"
    copy_file "$SOURCE_CONFIG/hypr/hyprlock_tiny.conf" "$DEST_CONFIG/hypr/hyprlock_tiny.conf"

    # Loop through selected WMs
    for i in "${!SELECTED_WMS[@]}"; do
        WM_NAME="${SELECTED_WMS[$i]}"
        WM_DIR_PATH="${SELECTED_WM_DIRS[$i]}"

        case "$WM_NAME" in
            "hyprland")
                echo ">>> Deploying Hyprland configs..."
                # Hyprland will copy content in hypr/ instead of hypr dir for not overriting hyprlock and hypridle configs
                copy_dir_content "$WM_DIR_PATH/config" "$DEST_CONFIG/hypr/config"
                copy_file "$WM_DIR_PATH/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua"
                ;;
            "niri")
                echo ">>> Deploying Niri configs..."
                copy_dir_content "$WM_DIR_PATH" "$DEST_CONFIG/niri"
                ;;
            "mango")
                echo ">>> Deploying Mango configs..."
                copy_dir_content "$WM_DIR_PATH" "$DEST_CONFIG/mango"
                ;;
            "labwc")
                echo ">>> Deploying Labwc configs..."
                copy_dir_content "$WM_DIR_PATH" "$DEST_CONFIG/labwc"
                ;;
            *)
                log_warn "Unknown WM: $WM_NAME. Skipping WM config deployment."
                ;;
        esac
    done

    echo ">>> Deploying Thunar gtk.css theme..."
    copy_file "$SOURCE_CONFIG/gtk-3.0/gtk.css" "$DEST_CONFIG/gtk-3.0/gtk.css"

    echo ">>> Deploying starship.toml (starship configuration)..."
    copy_file "$SOURCE_CONFIG/starship.toml" "$DEST_CONFIG/starship.toml"

    echo ">>> Deploying .nanorc (nano configuration)..."
    copy_file "$HOME_SRC_DIR/.nanorc" "$HOME/.nanorc"

    log_ok "Configurations deployed finished."
else
    log_skip "Skipping config deployment."
fi

# ============================================================================
# BLOCK 3: BACKUP AND COPY LOCAL BIN
# ============================================================================
step_title "3 - BACKUP AND UPDATE ~/.local/bin"

SOURCE_BIN="$COMMON_DIR/local/bin"
DEST_BIN="$HOME/.local/bin"

if ask_yes_no "===> Do you want to update hakuspace local/bin scripts now?"; then
    if [[ -d "$SOURCE_BIN" ]]; then
        copy_dir_content "$SOURCE_BIN" "$DEST_BIN"
        chmod +x ~/.local/bin/*
        log_ok "local/bin update completed."
    else
        log_warn "Directory not found: $SOURCE_BIN"
    fi
else
    log_skip "Skipping local/bin update."
fi

# ============================================================================
# BLOCK 4: NIXOS CONFIGURATION UPDATE & REBUILD
# ============================================================================
if command -v nixos-rebuild >/dev/null 2>&1; then
    step_title "4 - NIXOS SYSTEM REBUILD"
    
    REBUILD_DONE=0

    # Online mode
    if [[ -f "/etc/nixos/flake.nix" ]] && grep -q "hakuspace.nixosModules.default" "/etc/nixos/flake.nix"; then
        log_info "Detected NixOS with Hakuspace Flake (Online Mode)."
        if ask_yes_no "===> Do you want to update flake inputs and rebuild NixOS now?"; then
            cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake .
            log_ok "NixOS updated and rebuilt successfully via Flake."
            REBUILD_DONE=1
        fi
    # Offline mode
    elif [[ -f "/etc/nixos/hakuspace-config.nix" ]] && grep -q "./hakuspace-config.nix" "/etc/nixos/configuration.nix"; then
        log_info "Detected NixOS with Local hakuspace-config.nix (Offline Mode)."
        if ask_yes_no "===> Do you want to update local hakuspace-config.nix and rebuild NixOS now?"; then
            copy_file "$NIX_DIR/hakuspace-config.nix" "/etc/nixos/hakuspace-config.nix"
            log_info "Rebuilding NixOS system..."
            sudo nixos-rebuild switch
            log_ok "NixOS updated and rebuilt successfully via Local Config."
            REBUILD_DONE=1
        fi
    # No Hakuspace configuration detected
    else
        log_warn "NixOS detected, but no Hakuspace configuration pattern found."
        log_warn "How it could be..."
    fi

    if [[ "$REBUILD_DONE" -eq 0 ]]; then
        log_warn "You chose not to rebuild the NixOS system. Please remember to rebuild later to apply system-level changes."
    fi
fi

# Init HakuSpace Control
check_control_dir

# Final message
echo ""
echo -e "${C_BOLD}${C_CYAN}>>>>>>>>>> Update complete! You may need to restart your session or reload WM to apply changes!${C_RESET}"
echo -e "${C_MAGENTA}Backup folder for this update: $BACKUP_DIR${C_RESET}"