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

EOF

HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

chmod +x ./scripts/*
source "./scripts/variables.sh"
source "./scripts/functions.sh"

# ======================================================================================
# MAIN FLOW
# ======================================================================================

print_header
select_window_manager

# ============================================================================
# BLOCK 1: CHECK AND INSTALL DEPENDENCIES
# ============================================================================
step_title "1 - CHECK AND INSTALL DEPENDENCIES (yay, git, curl)"

# Check if pacman is available (Arch Linux or Arch-based distros)
if command -v pacman >/dev/null 2>&1; then
    if command -v yay >/dev/null 2>&1; then
        log_ok "yay is installed."
    else
        if ask_yes_no "===> Do you want to install yay now?"; then
            git clone https://aur.archlinux.org/yay-bin.git /tmp/yay
            (cd /tmp/yay && makepkg -si --noconfirm)
            cd "$HOME" || exit 1
            rm -rf /tmp/yay
            log_ok "yay has been installed successfully."
        else
            log_warn "You need yay to proceed with package installation automatically."
        fi
    fi
else
    log_error "You're not on an Arch-based distro."
    log_error "Please install the required packages manually."
fi


if ! command -v yay >/dev/null 2>&1; then
    log_error "yay is not installed. Please install yay first to run step 2."
fi

DEPENDENCIES=("git" "curl")
for pkg in "${DEPENDENCIES[@]}"; do
    if command -v "$pkg" >/dev/null 2>&1; then
        log_ok "$pkg exists."
    else
        log_warn "$pkg not found."
        if ask_yes_no "===> Install $pkg by yay now?"; then
            yay -S --noconfirm "$pkg"
        else
            log_warn "You need $pkg for full installer flow."
        fi
    fi
done

echo ""
echo -e "${C_BOLD}===================================================================${C_RESET}"
echo -e "${C_GREEN}--- Everything is ready to install Config! ---${C_RESET}"

# ============================================================================
# BLOCK 2: INSTALL PACKAGES
# ============================================================================
step_title "2 - INSTALL PACKAGES FROM LIST"

PKG_LABELS=()
PKG_FILES=()

log_info "You need to install pkg-core.txt & pkg-<WM_NAME>.txt for hakuspace to work properly"
log_info "You can CTRL+C to cancel installing & nano ~/hakuspace/src/packages/pkg-core.txt to edit package list"

if command -v yay >/dev/null 2>&1; then
    for i in "${!SELECTED_WMS[@]}"; do
        wm_name="${SELECTED_WMS[$i]}"
        wm_upper=$(echo "$wm_name" | tr '[:lower:]' '[:upper:]')
        PKG_LABELS+=("$wm_upper")
        PKG_FILES+=("${SELECTED_PKG_WMS[$i]}")
    done

    # Add common core, service, optional packages
    PKG_LABELS+=("CORE" "SERVICE" "OPTIONAL")
    PKG_FILES+=("$PKG_CORE" "$PKG_SERVICE" "$PKG_OPTIONAL")

    INSTALL_FLAGS=()
    for i in "${!PKG_LABELS[@]}"; do
        INSTALL_FLAGS+=(0)
    done

    echo ":: Package lists:"
    for i in "${!PKG_LABELS[@]}"; do
        echo "   [$i] ${PKG_LABELS[$i]} : Package list from ${PKG_FILES[$i]}"
    done
    echo ""

    for i in "${!PKG_LABELS[@]}"; do
        if ask_yes_no "===> Mark ${PKG_LABELS[$i]} for installation?"; then
            INSTALL_FLAGS[$i]=1
        else
            INSTALL_FLAGS[$i]=0
        fi
    done

    echo ""
    echo ":: Install plan (1=install, 0=skip): [${INSTALL_FLAGS[*]}]"
    echo ""

    selected_count=0
    for i in "${!PKG_LABELS[@]}"; do
        if [[ "${INSTALL_FLAGS[$i]}" -eq 1 ]]; then
            ((selected_count++))
        fi
    done

    if [[ "$selected_count" -eq 0 ]]; then
        log_skip "No package group selected. Skipping Block 2."
    else
        for i in "${!PKG_LABELS[@]}"; do
            if [[ "${INSTALL_FLAGS[$i]}" -eq 1 ]]; then
                install_pkg_file "${PKG_LABELS[$i]}" "${PKG_FILES[$i]}"
            else
                log_skip "[${PKG_LABELS[$i]}] Not selected."
            fi
        done
        log_ok "Block 2 package processing finished."
    fi
else
    log_error "yay is not installed. Please install yay first to run this step."
    log_error "If you're using another distro, install packages manually."
fi

# ============================================================================
# BLOCK 3: CREATE NECESSARY DIRECTORIES
# ============================================================================
step_title "3 - CREATE NECESSARY DIRECTORIES"

FOLDERS=(
    "$HOME/.config"
    "$HOME/.icons"
    "$HOME/.themes"
    "$HOME/Pictures/Wallpapers"
    "$HOME/Pictures/Screenshots"
)

for folder in "${FOLDERS[@]}"; do
    ensure_dir "$folder"
done

log_ok "All necessary directories have been created."

# BLOCK 3.1: NixOS Setup
# =======================================================
# NixOS specific deployment (Online Remote / Offline)
# =======================================================
if command -v nixos-rebuild >/dev/null 2>&1; then
    echo ""
    log_info "NixOS detected. Choose configuration mode for HakuSpace Dotfiles:"
    echo -e "  ${C_BOLD}[1]${C_RESET} Offline (Copy hakuspace-config.nix and edit configuration.nix)"
    echo -e "  ${C_BOLD}[2]${C_RESET} Online Remote (Deploy flake.nix from template)"
    echo -e "  ${C_BOLD}[0]${C_RESET} Skip NixOS deployment"
    read -r -p ">>> Choose mode (1/2/0): " nixos_mode

    NIXOS_ETC="/etc/nixos"
    SOURCE_HAKU_NIX="$NIX_DIR/hakuspace-config.nix"
    SOURCE_FLAKE_EXAMPLE="$NIX_DIR/flake.nix.example"

    if [[ "$nixos_mode" == "1" ]]; then
        log_info "Deploying NixOS Offline Config..."
        copy_file "$SOURCE_HAKU_NIX" "$NIXOS_ETC/hakuspace-config.nix"
            
        CONFIG_NIX="$NIXOS_ETC/configuration.nix"
        if [[ -f "$CONFIG_NIX" ]]; then
            # Check if hakuspace-config.nix is already imported
            if grep -q "./hakuspace-config.nix" "$CONFIG_NIX"; then
                log_skip "./hakuspace-config.nix is already imported in $CONFIG_NIX."
            else
                log_info "Injecting ./hakuspace-config.nix into imports of configuration.nix..."
                grep -q '\./hakuspace-config\.nix' "$CONFIG_NIX" || sudo sed -i '/^[[:space:]]*imports[[:space:]]*=/,/^[[:space:]]*];[[:space:]]*$/ { /^[[:space:]]*];[[:space:]]*$/i\      ./hakuspace-config.nix
}' "$CONFIG_NIX"
                log_ok "Updated imports in $CONFIG_NIX."
            fi
        else
            log_warn "$CONFIG_NIX not found! Please import hakuspace-config.nix manually."
        fi

    elif [[ "$nixos_mode" == "2" ]]; then
        log_info "Deploying NixOS Online Remote Config (Flake)..."
        DEST_FLAKE="$NIXOS_ETC/flake.nix"
            
        if [[ -f "$DEST_FLAKE" ]]; then
            log_warn "$DEST_FLAKE already exists."
            log_warn "Hakuspace flake.nix will overwrite your existing flake.nix (backup your own first)."
            log_warn "Hakuspace flake.nix is a template and may not include your custom configurations."
            if ask_yes_no "===> Do you want to use hakuspace flake.nix?"; then
                copy_file "$SOURCE_FLAKE_EXAMPLE" "$DEST_FLAKE"
                log_ok "flake.nix overwritten successfully."
            else
                log_skip "Kept existing flake.nix."
            fi
        else
            copy_file "$SOURCE_FLAKE_EXAMPLE" "$DEST_FLAKE"
            log_ok "flake.nix deployed successfully."
        fi
    else
        log_skip "Skipping NixOS specific deployment."
    fi
fi

# ============================================================================
# BLOCK 4: BACKUP AND COPY CONFIG
# ============================================================================
step_title "4 - SETUP HAKUSPACE CONFIG"

log_info "Backing up existing configs in ~/.config and copying new configs from hakuspace/src/home/.config"
log_info "Do NOT skip this step in the first time installation hakuspace"

if ask_yes_no "===> Do you want to setup hakuspace config now?"; then

    echo ">>> Deploying configs..."
    for folder in "$SOURCE_CONFIG"/*/; do
        [[ -d "$folder" ]] || continue
        folder_name="$(basename "$folder")"
        # Deloy config with skip config in the list of ONCE_CONFIGS and SKIP_CONFIGS
        if [[ " ${ONCE_CONFIGS[*]} " == *"$folder_name"* || " ${SKIP_CONFIGS[*]} " == *"$folder_name"* ]]; then
            continue
        fi
        copy_dir_content "$SOURCE_CONFIG/$folder_name" "$DEST_CONFIG/$folder_name"
    done
    copy_file "$SOURCE_CONFIG/hypr/hypridle.conf" "$DEST_CONFIG/hypr/hypridle.conf"
    copy_file "$SOURCE_CONFIG/hypr/hyprlock.conf" "$DEST_CONFIG/hypr/hyprlock.conf"
    copy_file "$SOURCE_CONFIG/hypr/hyprlock_tiny.conf" "$DEST_CONFIG/hypr/hyprlock_tiny.conf"

    # Once configs (Thunar, gtk-3.0, xfce4, mpv, btop)
    # Which will be deployed only once and not overwritten in future runs (update.sh)
    echo ">>> Deploying Once configs..."
    for folder in "${ONCE_CONFIGS[@]}"; do
        [[ -d "$folder" ]] || continue
        folder_name="$(basename "$folder")"
        copy_dir_content "$folder" "$DEST_CONFIG/$folder_name"
    done

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
    backup_dir "$DEST_CONFIG/gtk-3.0"
    copy_file "$SOURCE_CONFIG/gtk-3.0/gtk.css" "$DEST_CONFIG/gtk-3.0/gtk.css" 1

    echo ">>> Deploying starship.toml (starship configuration)..."
    copy_file "$SOURCE_CONFIG/starship.toml" "$DEST_CONFIG/starship.toml"

    echo ">>> Deploying .nanorc (nano configuration)..."
    copy_file "$HOME_SRC_DIR/.nanorc" "$HOME/.nanorc"

    # mimeapps.list only deployed once, update.sh do not deploy it again
    echo ">>> Deploying mimeapps.list..."
    copy_file "$SOURCE_CONFIG/mimeapps.list" "$DEST_CONFIG/mimeapps.list"


    log_ok "Configurations deployed finished."
else
    log_skip "Skipping config deployment."
fi

# ============================================================================
# BLOCK 5: BACKUP AND COPY LOCAL BIN
# ============================================================================
step_title "5 - SETUP LOCAL BIN SCRIPTS"

log_info "Backing up existing ~/.local/bin and copying new scripts from hakuspace/src/home/.local/bin"
log_info "Do NOT skip this step in the first time installation hakuspace"

if ask_yes_no "===> Do you want to setup hakuspace scripts now?"; then
    if [[ -d "$SOURCE_BIN" ]]; then
        copy_dir_content "$SOURCE_BIN" "$DEST_BIN"
        chmod +x ~/.local/bin/*
        log_ok "local/bin deployment completed."
    else
        log_error "Not found directory: $SOURCE_BIN"
    fi
else
    log_skip "Skipping local/bin deployment."
fi

# ============================================================================
# BLOCK 6: CLONE HAKUSPACE-ARCHIVE AND RUN setup.sh
# ============================================================================
step_title "6 - DEPLOY EXTRA ASSETS FROM hakuspace-archive"

log_info "Clone hakuspace-archive to setup icons, themes, and wallpapers. You can skip this step if you don't want to install them."

if ask_yes_no "===> Do you want to setup hakuspace assets: Icons, Themes and Wallpapers?"; then
    if deploy_assets_from_archive_repo; then
        log_ok "hakuspace-archive setup completed."
    else
        log_error "hakuspace-archive setup failed."
    fi
else
    log_skip "Skipping hakuspace-archive assets setup."
fi

# ============================================================================
# BLOCK 7: FINAL SETUP: MAKE SOMETHING WORK
# ============================================================================
step_title "7 - FINAL SETUP: MAKE SOMETHING WORK"

# Gen style first time
echo ""
if [[ -x "$HOME/.local/bin/gen_style.sh" ]]; then
    "$HOME/.local/bin/gen_style.sh" --font "JetBrainsMono Nerd Font"
    log_ok "Executed gen_style.sh"
else
    log_warn "Not executable or missing: $HOME/.local/bin/gen_style.sh"
    log_warn "Check if the script exists and has execute permissions in ~/.local/bin/"
fi

# Change default shell to fish
echo ""
if command -v fish >/dev/null 2>&1; then
    FISH_PATH="$(command -v fish)"
    
    if ! grep -q "$FISH_PATH" /etc/shells; then
        echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
    
    if [[ "$SHELL" != "$FISH_PATH" ]]; then
        chsh -s "$FISH_PATH" "$USER"
        log_ok "Changed default shell to fish ($FISH_PATH)."
    else
        log_skip "Fish is already your default shell."
    fi
else
    log_warn "Fish shell is not installed. Skipping shell change."
fi

# Init HakuSpace Control
echo ""
check_control_dir

# NixOS configuration update
echo ""
if command -v nixos-rebuild >/dev/null 2>&1; then
    if ask_yes_no "===> NixOS configuration updated. Do you want to rebuild NixOS system now? (maybe have some conflicts)"; then
        sudo nixos-rebuild switch
    else
        log_warn "You chose not to rebuild NixOS system. Please remember to run 'sudo nixos-rebuild switch' later."
    fi
fi

# Check if ly is installed
FOUND=0
for path in /usr/bin/ly /usr/local/bin/ly /usr/sbin/ly /usr/bin/ly-dm; do
    if [ -f "$path" ]; then
        FOUND=1
        break
    fi
done

echo ""
if [ $FOUND -eq 1 ]; then
    if ask_yes_no "===> Do you want to enable ly service and disable getty now?"; then
        log_warn "Do NOT choose tty1 if you are using a display manager (SDDM, LightDM, etc.) in tty1."
        read -r -p "===> Please choose what number of tty (default: 1): " tty_choice
        tty_choice="${tty_choice:-1}"
        if [[ "$tty_choice" =~ ^[1-6]$ ]]; then
            sudo systemctl enable ly@tty${tty_choice}.service
            sudo systemctl disable "getty@tty${tty_choice}.service"
            log_ok "ly service enabled and getty disabled at tty${tty_choice}."
        else
            log_error "Invalid tty choice. Please choose a number between 1 and 6. Skipping..."
        fi
    else
        log_skip "Skipping service enable/disable."
    fi
else
    log_warn "ly service not found. Skipping service enable/disable."
fi

# Set GNOME color scheme to dark and set Thunar as default file manager
echo ""
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
log_ok "Set GNOME color scheme to dark."

# Set Thunar as default file manager if installed
echo ""
if command -v thunar >/dev/null 2>&1; then
    xdg-mime default thunar.desktop inode/directory
    log_ok "Set Thunar as default file manager."
else
    log_warn "Thunar is not installed. Skipping setting default file manager."
fi

echo ""
echo -e "${C_GREEN}All services have been processed!${C_RESET}"
echo ""
echo -e "${C_BOLD}${C_CYAN}>>>>>>>>>> All done! Please restart your pc to apply changes!${C_RESET}"
echo -e "${C_MAGENTA}Backup folder for this run: $BACKUP_DIR${C_RESET}"