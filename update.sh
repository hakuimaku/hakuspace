#!/bin/bash
set -u

# ======================================================================================
# HAKUSPACE UPDATER (LATEST/STABLE & COPY MODE) - REFIXED BY TENSEY
# ======================================================================================

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
HAKU_DIR="$HOME/hakuspace"
COMMON_DIR="$HAKU_DIR/common"

BACKUP_TS="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$HOME/Backup_$BACKUP_TS"

# Arrays to handle multiple WMs
SELECTED_WMS=()
SELECTED_WM_DIRS=()
SELECTED_PKG_WMS=()

PKG_SERVICE="$COMMON_DIR/pkg-service.txt"
PKG_CORE="$COMMON_DIR/pkg-core.txt"
PKG_OPTIONAL="$COMMON_DIR/pkg-optional.txt"

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
    echo -e "${C_BOLD}[4]${C_RESET} ALL (Niri, Mango, Hyprland)"
    echo ""
    read -r -p ">>> Which Window Manager config do you want to update?: " wm_choice

    case "$wm_choice" in
        1) 
            SELECTED_WMS=("hyprland")
            SELECTED_WM_DIRS=("$HAKU_DIR/hyprland")
            SELECTED_PKG_WMS=("$HAKU_DIR/hyprland/pkg-hyprland.txt")
            log_info "Selected: Hyprland" 
            ;;
        2) 
            SELECTED_WMS=("niri")
            SELECTED_WM_DIRS=("$HAKU_DIR/niri")
            SELECTED_PKG_WMS=("$HAKU_DIR/niri/pkg-niri.txt")
            log_info "Selected: Niri" 
            ;;
        3) 
            SELECTED_WMS=("mango")
            SELECTED_WM_DIRS=("$HAKU_DIR/mango")
            SELECTED_PKG_WMS=("$HAKU_DIR/mango/pkg-mango.txt")
            log_info "Selected: Mango" 
            ;;
        4)
            # Niri > Mango > Hyprland
            SELECTED_WMS=("niri" "mango" "hyprland")
            SELECTED_WM_DIRS=("$HAKU_DIR/niri" "$HAKU_DIR/mango" "$HAKU_DIR/hyprland")
            SELECTED_PKG_WMS=("$HAKU_DIR/niri/pkg-niri.txt" "$HAKU_DIR/mango/pkg-mango.txt" "$HAKU_DIR/hyprland/pkg-hyprland.txt")
            log_info "Selected: All Window Managers"
            ;;
        *) 
            log_error "Invalid choice. Exiting."
            exit 1 
            ;;
    esac
}

preflight_checks() {
    if [[ "$PWD" != "$HAKU_DIR" ]]; then
        echo ""
        log_error "Please run this script from: $HAKU_DIR"
        exit 1
    fi
}

# ======================================================================================
# MAIN FLOW
# ======================================================================================

print_header
preflight_checks

# ============================================================================
# BLOCK 0: UPDATE REPOSITORY (LATEST vs STABLE)
# ============================================================================
step_title "0 - UPDATE DOTFILES REPOSITORY"

SCRIPT_NAME=$(basename "$0")
BACKUP_SCRIPT="/tmp/${SCRIPT_NAME}.bak"

cp "$0" "$BACKUP_SCRIPT"

echo "Select update mode:"
echo -e "${C_BOLD}[1]${C_RESET} LATEST (Pull from main branch - Experimental)"
echo -e "${C_BOLD}[2]${C_RESET} STABLE (Checkout latest release tag - Recommended)"
echo -e "${C_BOLD}[0]${C_RESET} SKIP (Do not update repository)"
echo ""
read -r -p ">>> Choose mode (1/2/0): " update_mode

REPO_CHANGED=0

if [[ "$update_mode" == "1" ]]; then
    log_info "Switching to main branch and pulling latest changes..."
    git checkout main
    git pull origin main
    log_ok "Repository updated to LATEST."
    REPO_CHANGED=1
elif [[ "$update_mode" == "2" ]]; then
    log_info "Fetching tags from remote..."
    git fetch --tags
    LATEST_TAG=$(git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null)
    if [[ -z "$LATEST_TAG" ]]; then
        log_warn "No tags found in repository. Falling back to main branch."
        git checkout main
        git pull origin main
    else
        log_info "Latest stable tag found: $LATEST_TAG"
        git checkout "$LATEST_TAG"
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
        log_error "Please re-run the script to execute with new logic: ./${SCRIPT_NAME}"
        rm -f "$BACKUP_SCRIPT"
        exit 0
    fi
    rm -f "$BACKUP_SCRIPT"
fi

select_window_manager

# ============================================================================
# BLOCK 1: UPDATE PACKAGES
# ============================================================================
step_title "1 - UPDATE PACKAGES FROM LIST (AUTO)"

PKG_LABELS=()
PKG_FILES=()

# Dynamically build lists for all selected WMs
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

if command -v yay >/dev/null 2>&1; then
    if ask_yes_no "===> Do you want to install/update packages now?"; then
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
    log_error "yay is not installed. Please install yay manually."
fi

# ============================================================================
# BLOCK 2: BACKUP AND COPY CONFIG
# ============================================================================
step_title "2 - BACKUP AND UPDATE CONFIG IN ~/.config"

SOURCE_COMMON_CONFIG="$COMMON_DIR/config"
DEST_CONFIG="$HOME/.config"

echo ""
echo "[1]. FULL COPY, copy entire the config folder (if you lazy or unsure)"
echo "[2]. SELECTIVE COPY, choose which configs to update (if you know what's changed)"
echo "[0]. SKIP config update"
echo ""

read -r -p ">>> Choose config update mode (1/2/0): " config_mode
if [[ "$config_mode" == "1" ]]; then
    echo ">>> Deploying Common configs..."
    for folder in "$SOURCE_COMMON_CONFIG"/*/; do
        [[ -d "$folder" ]] || continue
        folder_name="$(basename "$folder")"
        copy_dir_content "$SOURCE_COMMON_CONFIG/$folder_name" "$DEST_CONFIG/$folder_name"
    done

    # Loop through selected WMs
    for i in "${!SELECTED_WMS[@]}"; do
        WM_NAME="${SELECTED_WMS[$i]}"
        WM_DIR_PATH="${SELECTED_WM_DIRS[$i]}"
        SOURCE_WM_CONFIG="$WM_DIR_PATH/config"

        if [[ $WM_NAME == "hyprland" ]]; then
            echo ">>> Deploying Hyprland configs..."
            copy_dir_content "$SOURCE_WM_CONFIG/hypr/config" "$DEST_CONFIG/hypr/config"
            copy_file "$SOURCE_WM_CONFIG/hypr/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua"
        elif [[ $WM_NAME == "niri" ]]; then
            echo ">>> Deploying Niri configs..."
            copy_dir_content "$SOURCE_WM_CONFIG/niri" "$DEST_CONFIG/niri"
        elif [[ $WM_NAME == "mango" ]]; then
            echo ">>> Deploying Mango configs..."
            copy_dir_content "$SOURCE_WM_CONFIG/mango" "$DEST_CONFIG/mango"
        else
            log_warn "Unknown WM: $WM_NAME. Skipping WM config deployment."
        fi
    done

    echo ">>> Deploying mimeapps.list..."
    copy_file "$SOURCE_COMMON_CONFIG/mimeapps.list" "$HOME/.config/mimeapps.list"

    echo ">>> Deploying .zshrc (zsh configuration)..."
    copy_file "$COMMON_DIR/.zshrc" "$HOME/.zshrc"

    echo ">>> Deploying .nanorc (nano configuration)..."
    copy_file "$COMMON_DIR/.nanorc" "$HOME/.nanorc"

    log_ok "Configurations deployed successfully."

elif [[ "$config_mode" == "2" ]]; then
    echo ">>> Entering Selective Mode..."
        
    # 1. Common configs (Waybar, Rofi, Fastfetch, Cava, Kitty, Swaync...)
    COMMON_APPS=("waybar" "rofi" "fastfetch" "cava" "kitty" "swaync")

    for app in "${COMMON_APPS[@]}"; do
        if [[ -d "$SOURCE_COMMON_CONFIG/$app" ]]; then
            if ask_yes_no "   -> Do you want to deploy $app configs?"; then
                copy_dir_content "$SOURCE_COMMON_CONFIG/$app" "$DEST_CONFIG/$app"
            fi
        else
            log_warn "Source app folder not found: $app. Skipping..."
        fi
    done

    # 2. Hyprlock & Hypridle
    if ask_yes_no "   -> Do you want to deploy hyprlock, hypridle configs?"; then
        echo "   >>> Deploying Hypr configs..."
        copy_file "$SOURCE_COMMON_CONFIG/hypr/hyprlock.conf" "$DEST_CONFIG/hypr/hyprlock.conf"
        copy_file "$SOURCE_COMMON_CONFIG/hypr/hyprlock_tiny.conf" "$DEST_CONFIG/hypr/hyprlock_tiny.conf"
        copy_file "$SOURCE_COMMON_CONFIG/hypr/hypridle.conf" "$DEST_CONFIG/hypr/hypridle.conf"
    fi

    # 3. .zshrc
    if ask_yes_no "   -> Do you want to deploy .zshrc (Zsh configuration)?"; then
        echo "   >>> Deploying Zshrc..."
        copy_file "$COMMON_DIR/.zshrc" "$HOME/.zshrc"
    fi
        
    # 4. WM configs
    for i in "${!SELECTED_WMS[@]}"; do
        WM_NAME="${SELECTED_WMS[$i]}"
        WM_DIR_PATH="${SELECTED_WM_DIRS[$i]}"
        SOURCE_WM_CONFIG="$WM_DIR_PATH/config"

        if [[ $WM_NAME == "hyprland" ]]; then
            if ask_yes_no "   -> Do you want to deploy Hyprland configs?"; then
                echo "   >>> Deploying Hyprland configs..."
                copy_dir_content "$SOURCE_WM_CONFIG/hypr/config" "$DEST_CONFIG/hypr/config"
                copy_file "$SOURCE_WM_CONFIG/hypr/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua"
            fi   
        elif [[ $WM_NAME == "niri" ]]; then
            if ask_yes_no "   -> Do you want to deploy Niri configs?"; then
                echo "   >>> Deploying Niri configs..."
                copy_dir_content "$SOURCE_WM_CONFIG/niri" "$DEST_CONFIG/niri"
            fi   
        elif [[ $WM_NAME == "mango" ]]; then
            if ask_yes_no "   -> Do you want to deploy Mango configs?"; then
                echo "   >>> Deploying Mango configs..."
                copy_dir_content "$SOURCE_WM_CONFIG/mango" "$DEST_CONFIG/mango"
            fi
        fi
    done

    log_ok "Configurations updated successfully."
else
    log_skip "Skipping config deployment."
fi

# ============================================================================
# BLOCK 3: BACKUP AND COPY LOCAL BIN
# ============================================================================
step_title "3 - BACKUP AND UPDATE ~/.local/bin"

SOURCE_BIN="$COMMON_DIR/local/bin"
DEST_BIN="$HOME/.local/bin"

if ask_yes_no "===> Do you want to update your local/bin scripts now?"; then
    if [[ -d "$SOURCE_BIN" ]]; then
        copy_dir_content "$SOURCE_BIN" "$DEST_BIN"
        log_ok "local/bin update completed."
    else
        log_warn "Directory not found: $SOURCE_BIN"
    fi
else
    log_skip "Skipping local/bin update."
fi

# Final message
echo ""
echo -e "${C_BOLD}${C_CYAN}>>>>>>>>>> Update complete! You may need to restart your session or reload WM to apply changes!${C_RESET}"
echo -e "${C_MAGENTA}Backup folder for this update: $BACKUP_DIR${C_RESET}"

echo ""
if [[ "$config_mode" == "1" ]]; then
    log_warn "Note: You chose FULL COPY. If your Thunar bookmarks are missing and some your personal configs, restore them from $BACKUP_DIR/.config"
fi