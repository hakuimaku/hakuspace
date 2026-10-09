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

# --------------------------------
# Color setup
# --------------------------------
if [[ -t 1 ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_BLUE='\033[34m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_RED='\033[31m'
    C_CYAN='\033[36m'
    C_MAGENTA='\033[35m'
    C_WHITE='\033[37m'
else
    C_RESET=''
    C_BOLD=''
    C_DIM=''
    C_BLUE=''
    C_GREEN=''
    C_YELLOW=''
    C_RED=''
    C_CYAN=''
    C_MAGENTA=''
    C_WHITE=''
fi

# --------------------------------
# Global paths / variables
# --------------------------------
HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
COMMON_DIR="$HAKU_DIR/common"
WM_DIR="$HAKU_DIR/wm"

NIX_DIR="$HAKU_DIR/nix"

BACKUP_TS="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$HOME/Backup_$BACKUP_TS"

# Arrays to handle multiple WMs
SELECTED_WMS=()
SELECTED_WM_DIRS=()
SELECTED_PKG_WMS=()

PKG_SERVICE="$COMMON_DIR/pkg-service.txt"
PKG_CORE="$COMMON_DIR/pkg-core.txt"
PKG_OPTIONAL="$COMMON_DIR/pkg-optional.txt"

HAKUSPACE_CONTROL_DIR="$HAKU_DIR/hakuspace-control"
DEST_CONTROL_DIR="$HOME/hakuspace-control"

# --------------------------------
# Logging helpers
# --------------------------------
log_info()   { echo -e "${C_BLUE}[INFO]${C_RESET}   $1"; }
log_ok()     { echo -e "${C_GREEN}[OK]${C_RESET}     $1"; }
log_warn()   { echo -e "${C_YELLOW}[WARN]${C_RESET}   $1"; }
log_error()  { echo -e "${C_RED}[ERROR]${C_RESET}  $1"; }
log_backup() { echo -e "${C_MAGENTA}[BACKUP]${C_RESET} $1"; }
log_copy()   { echo -e "${C_CYAN}[COPY]${C_RESET}   $1"; }
log_skip()   { echo -e "${C_WHITE}[SKIP]${C_RESET}   $1"; }

step_title() {
    echo ""
    echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BOLD}${C_BLUE}$1${C_RESET}"
    echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
}

# --------------------------------
# Utility helpers
# --------------------------------
ask_yes_no() {
    local prompt="$1"
    local answer
    read -r -p "$prompt (y/n): " answer
    [[ "$answer" =~ ^[yY]([eE][sS])?$ ]]
}

ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_ok "Created directory: $dir"
    fi
}

backup_item() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0

    local rel="${target#$HOME/}"
    local backup_target="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$backup_target")"

    mv "$target" "$backup_target"
    log_backup "$target -> $backup_target"
}

copy_dir_content() {
    local src="$1"
    local dst="$2"

    if [[ ! -d "$src" ]]; then
        log_warn "Source directory not found: $src"
        return 1
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        backup_item "$dst"
    fi

    ensure_dir "$dst"
    
    cp -rf "$src"/. "$dst"/
    log_copy "$src/. -> $dst/"
    return 0
}

copy_file() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$src" ]]; then
        log_warn "Source file not found: $src"
        return 1
    fi

    ensure_dir "$(dirname "$dst")"

    if [[ -e "$dst" || -L "$dst" ]]; then
        backup_item "$dst"
    fi

    cp -f "$src" "$dst"
    log_copy "$src -> $dst"
    return 0
}

install_pkg_file() {
    local label="$1"
    local file="$2"

    if [[ ! -f "$file" ]]; then
        log_warn "[$label] File not found: $file (skip)"
        return 1
    fi

    if sed 's/[[:space:]]*#.*$//' "$file" | grep -E '^[a-zA-Z0-9@._+-]+$' | yay -S --needed --noconfirm -; then
        log_ok "[$label] Installed successfully."
        return 0
    else
        log_error "[$label] Installation failed."
        return 1
    fi
}

print_header() {
    echo ""
    echo -e "${C_BOLD}===================================================================${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}--- HAKUSPACE - DOTFILES UPDATER ---${C_RESET}"
    echo "This script will update your dotfiles from the repository and apply them to your system."
    echo "Prefer to check release notes | commit history before updating."
    echo -e "${C_BOLD}===================================================================${C_RESET}"
    echo ""
}

select_window_manager() {
    echo "Current directory: $PWD"
    echo ""
    echo -e "${C_BOLD}[1]${C_RESET} HYPRLAND"
    echo -e "${C_BOLD}[2]${C_RESET} NIRI"
    echo -e "${C_BOLD}[3]${C_RESET} MANGOWM"
    echo -e "${C_BOLD}[4]${C_RESET} LABWC"
    echo -e "${C_BOLD}[5]${C_RESET} ALL (Niri, Mango, Hyprland, Labwc)"
    echo ""
    read -r -p ">>> Which Window Manager do you want to install?: " wm_choice

    case "$wm_choice" in
        1)
            SELECTED_WMS=("hyprland")
            SELECTED_WM_DIRS=("$WM_DIR/hyprland")
            SELECTED_PKG_WMS=("$WM_DIR/pkg-hyprland.txt")
            log_info "Selected: Hyprland"
            ;;
        2)
            SELECTED_WMS=("niri")
            SELECTED_WM_DIRS=("$WM_DIR/niri")
            SELECTED_PKG_WMS=("$WM_DIR/pkg-niri.txt")
            log_info "Selected: Niri"
            ;;
        3)
            SELECTED_WMS=("mango")
            SELECTED_WM_DIRS=("$WM_DIR/mango")
            SELECTED_PKG_WMS=("$WM_DIR/pkg-mango.txt")
            log_info "Selected: Mango"
            ;;
        4)
            SELECTED_WMS=("labwc")
            SELECTED_WM_DIRS=("$WM_DIR/labwc")
            SELECTED_PKG_WMS=("$WM_DIR/pkg-labwc.txt")
            log_info "Selected: Labwc"
            ;;
        5)
            SELECTED_WMS=("niri" "mango" "labwc" "hyprland")
            SELECTED_WM_DIRS=("$WM_DIR/niri" "$WM_DIR/mango" "$WM_DIR/labwc" "$WM_DIR/hyprland")
            SELECTED_PKG_WMS=("$WM_DIR/pkg-niri.txt" "$WM_DIR/pkg-mango.txt" "$WM_DIR/pkg-labwc.txt" "$WM_DIR/pkg-hyprland.txt")
            log_info "Selected: All Window Managers"
            ;;
        *)
            log_error "Invalid choice. Please run again and choose 1, 2, 3, 4 or 5."
            exit 1
            ;;
    esac
}

# Check ~/hakuspace-control directory:
check_control_dir() {
    if [[ ! -d "$HAKUSPACE_CONTROL_DIR" ]]; then
        log_warn "hakuspace-control directory not found. Creating..."
        mkdir -p "$HAKUSPACE_CONTROL_DIR"
    fi

    local required_files=(
        "main_setting.sh"
        "mango-custom.conf"
        "niri-custom.kdl"
        "hyprland-custom.lua"
        "dockbar_pin_apps"
        "hakumenu-general-custom.sh"
    )
    for file in "${required_files[@]}"; do
        if [[ ! -f "$DEST_CONTROL_DIR/$file" ]]; then
            log_warn "$file not found in hakuspace-control. Creating default..."
            copy_file "$HAKUSPACE_CONTROL_DIR/$file" "$DEST_CONTROL_DIR/$file"
        fi
    done

    mkdir -p "$DEST_CONTROL_DIR/waybar"
    mkdir -p "$DEST_CONTROL_DIR/rofi"
    chmod +x "$DEST_CONTROL_DIR/main_setting.sh"

    # Check HakuSpace Control version
    if [[ -f "$DEST_CONTROL_DIR/main_setting.sh" ]]; then
        local current_version
        local source_version
        chmod +x "$HAKUSPACE_CONTROL_DIR/main_setting.sh"

        source_version=$("$HAKUSPACE_CONTROL_DIR/main_setting.sh" | grep -oP 'Hakuspace Control Settings Version: \K[0-9]+\.[0-9]+\.[0-9]+')
        current_version=$("$DEST_CONTROL_DIR/main_setting.sh" | grep -oP 'Hakuspace Control Settings Version: \K[0-9]+\.[0-9]+\.[0-9]+')
        if [[ "$current_version" != "$source_version" ]]; then
            log_warn "Hakuspace Control version mismatch: $current_version (current) vs $source_version (expected). Updating..."
            log_warn "If you choose update, your custom settings in main_setting.sh will be overwritten."
            if ask_yes_no "===> Do you want to update hakuspace-control to the latest version?"; then
                copy_file "$HAKUSPACE_CONTROL_DIR/main_setting.sh" "$DEST_CONTROL_DIR/main_setting.sh"
                log_ok "Hakuspace Control updated to version $source_version."
            else
                log_warn "You chose not to update hakuspace-control. Some features may not work as expected."
            fi
        else
            log_ok "Hakuspace Control version is up-to-date: $current_version"
        fi
    else
        log_warn "main_setting.sh not found in hakuspace-control. Creating default..."
        copy_file "$HAKUSPACE_CONTROL_DIR/main_setting.sh" "$DEST_CONTROL_DIR/main_setting.sh"
    fi
}

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
    PKG_LABELS+=("CORE" "SERVICE" "OPTIONAL")
    PKG_FILES+=("$PKG_CORE" "$PKG_SERVICE" "$PKG_OPTIONAL")

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

# Block 1.1: Check NixOS offline installation mode & update NixOS configuration
if [[ -f "/etc/nixos/hakuspace-config.nix" && grep -q "./hakuspace-config.nix" "/etc/nixos/configuration.nix" ]]; then
    copy_file "$COMMON_DIR/nixos/hakuspace-config.nix" "/etc/nixos/hakuspace-config.nix"
    log_ok "NixOS hakuspace-config.nix updated finished."
fi

# ============================================================================
# BLOCK 2: BACKUP AND COPY CONFIG
# ============================================================================
step_title "2 - BACKUP AND UPDATE CONFIG IN ~/.config"

SOURCE_COMMON_CONFIG="$COMMON_DIR/config"
DEST_CONFIG="$HOME/.config"

if ask_yes_no "===> Do you want to update hakuspace configs now?"; then

    echo ">>> Deploying Common configs..."
    for folder in "$SOURCE_COMMON_CONFIG"/*/; do
        [[ -d "$folder" ]] || continue
        folder_name="$(basename "$folder")"
        if [[ "$folder_name" == "hypr" ]]; then
            continue
        fi
        copy_dir_content "$SOURCE_COMMON_CONFIG/$folder_name" "$DEST_CONFIG/$folder_name"
    done
    copy_file "$SOURCE_COMMON_CONFIG/hypr/hypridle.conf" "$DEST_CONFIG/hypr/hypridle.conf"
    copy_file "$SOURCE_COMMON_CONFIG/hypr/hyprlock.conf" "$DEST_CONFIG/hypr/hyprlock.conf"
    copy_file "$SOURCE_COMMON_CONFIG/hypr/hyprlock_tiny.conf" "$DEST_CONFIG/hypr/hyprlock_tiny.conf"

    # Loop through selected WMs
    for i in "${!SELECTED_WMS[@]}"; do
        WM_NAME="${SELECTED_WMS[$i]}"
        WM_DIR_PATH="${SELECTED_WM_DIRS[$i]}"
        SOURCE_WM_CONFIG="$WM_DIR_PATH"

        if [[ $WM_NAME == "hyprland" ]]; then
            echo ">>> Deploying Hyprland configs..."
            copy_dir_content "$SOURCE_WM_CONFIG/config" "$DEST_CONFIG/config"
            copy_file "$SOURCE_WM_CONFIG/hyprland.lua" "$DEST_CONFIG/hyprland.lua"
        elif [[ $WM_NAME == "niri" ]]; then
            echo ">>> Deploying Niri configs..."
            copy_dir_content "$SOURCE_WM_CONFIG/niri" "$DEST_CONFIG/niri"
        elif [[ $WM_NAME == "mango" ]]; then
            echo ">>> Deploying Mango configs..."
            copy_dir_content "$SOURCE_WM_CONFIG/mango" "$DEST_CONFIG/mango"
        elif [[ $WM_NAME == "labwc" ]]; then
            echo ">>> Deploying Labwc configs..."
            copy_dir_content "$SOURCE_WM_CONFIG/labwc" "$DEST_CONFIG/labwc"
        else
            log_warn "Unknown WM: $WM_NAME. Skipping WM config deployment."
        fi
    done

    echo ">>> Deploying Thunar gtk.css theme..."
    copy_file "$SOURCE_COMMON_CONFIG/gtk.css" "$DEST_CONFIG/gtk-3.0/gtk.css"

    echo ">>> Deploying .zshrc (zsh configuration)..."
    copy_file "$SOURCE_COMMON_CONFIG/.zshrc" "$HOME/.zshrc"

    echo ">>> Deploying .nanorc (nano configuration)..."
    copy_file "$SOURCE_COMMON_CONFIG/.nanorc" "$HOME/.nanorc"

    log_ok "Configurations deployed successfully."
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
        log_ok "local/bin update completed."
    else
        log_warn "Directory not found: $SOURCE_BIN"
    fi
else
    log_skip "Skipping local/bin update."
fi

# Init HakuSpace Control
check_control_dir

# NixOS configuration update
if [[ command -v nixos-rebuild >/dev/null 2>&1 ]]; then
    if ask_yes_no "===> NixOS configuration updated. Do you want to rebuild NixOS system now?"; then
        log_info "Rebuilding NixOS system..."
        sudo nixos-rebuild switch
        log_ok "NixOS system rebuilt successfully."
    else
        log_warn "You chose not to rebuild NixOS system. Please remember to run 'sudo nixos-rebuild switch' later."
    fi
fi

# Final message
echo ""
echo -e "${C_BOLD}${C_CYAN}>>>>>>>>>> Update complete! You may need to restart your session or reload WM to apply changes!${C_RESET}"
echo -e "${C_MAGENTA}Backup folder for this update: $BACKUP_DIR${C_RESET}"