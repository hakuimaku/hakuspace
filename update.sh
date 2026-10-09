#!/bin/bash
set -u

# ======================================================================================
# HAKUSPACE UPDATER (LATEST/STABLE & COPY MODE)
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

WM=""
WM_DIR=""
PKG_WM=""

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
    echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BOLD}${C_BLUE}$1${C_RESET}"
    echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
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

copy_file_with_backup() {
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

copy_config_folders_with_backup() {
    local source_dir="$1"
    local dest_dir="$2"

    if [[ ! -d "$source_dir" ]]; then
        log_warn "Source directory does not exist: $source_dir"
        return 1
    fi

    ensure_dir "$dest_dir"

    for folder in "$source_dir"/*/; do
        [[ -d "$folder" ]] || continue

        local folder_name
        folder_name="$(basename "$folder")"
        local target_path="$dest_dir/$folder_name"

        if [[ -e "$target_path" || -L "$target_path" ]]; then
            backup_item "$target_path"
        fi

        cp -r "$folder" "$dest_dir/"
        log_copy "$folder -> $dest_dir/"
    done
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
    echo -e "${C_BOLD}================================================================================================${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}--- HAKUSPACE - DOTFILES UPDATER ---${C_RESET}"
    echo "This script will update your dotfiles from the repository and apply them to your system."
    echo "Prefer to check release notes | commit history before updating."
    echo -e "${C_BOLD}================================================================================================${C_RESET}"
    echo ""
}

select_window_manager() {
    echo "Current directory: $PWD"
    echo ""
    echo -e "${C_BOLD}[1]${C_RESET} HYPRLAND"
    echo -e "${C_BOLD}[2]${C_RESET} NIRI"
    echo -e "${C_BOLD}[3]${C_RESET} MANGOWM"
    echo ""
    read -r -p ">>> Which Window Manager config do you want to update?: " wm_choice

    case "$wm_choice" in
        1) WM="hyprland"; WM_DIR="$HAKU_DIR/hyprland"; PKG_WM="$WM_DIR/pkg-hyprland.txt"; log_info "Selected: Hyprland" ;;
        2) WM="niri"; WM_DIR="$HAKU_DIR/niri"; PKG_WM="$WM_DIR/pkg-niri.txt"; log_info "Selected: Niri" ;;
        3) WM="mango"; WM_DIR="$HAKU_DIR/mango"; PKG_WM="$WM_DIR/pkg-mango.txt"; log_info "Selected: Mango" ;;
        *) log_error "Invalid choice. Exiting."; exit 1 ;;
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

echo "Select update mode:"
echo -e "${C_BOLD}[1]${C_RESET} LATEST (Pull from main branch - Experimental)"
echo -e "${C_BOLD}[2]${C_RESET} STABLE (Checkout latest release tag - Recommended)"
echo ""
read -r -p ">>> Choose mode (1/2): " update_mode

if [[ "$update_mode" == "1" ]]; then
    log_info "Switching to main branch and pulling latest changes..."
    git checkout main
    git pull origin main
    log_ok "Repository updated to LATEST."
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
else
    log_error "Invalid choice. Skipping repository update."
fi

select_window_manager

# ============================================================================
# BLOCK 1: UPDATE PACKAGES
# ============================================================================
step_title "1 - UPDATE PACKAGES FROM LIST"

PKG_LABELS=("$WM" "CORE" "SERVICE" "OPTIONAL")
PKG_FILES=("$PKG_WM" "$PKG_CORE" "$PKG_SERVICE" "$PKG_OPTIONAL")
INSTALL_FLAGS=(0 0 0 0)

echo ">>> Package lists:"
for i in "${!PKG_LABELS[@]}"; do
    echo "  - ${PKG_LABELS[$i]}: ${PKG_FILES[$i]}"
done

echo ":: Package lists to update:"
for i in "${!PKG_LABELS[@]}"; do
    if ask_yes_no "===> Update packages for ${PKG_LABELS[$i]}?"; then
        INSTALL_FLAGS[$i]=1
    else
        INSTALL_FLAGS[$i]=0
    fi
done

if command -v yay >/dev/null 2>&1; then
    for i in "${!PKG_LABELS[@]}"; do
        if [[ "${INSTALL_FLAGS[$i]}" -eq 1 ]]; then
            install_pkg_file "${PKG_LABELS[$i]}" "${PKG_FILES[$i]}"
        fi
    done
    log_ok "Package update processing finished."
else
    log_error "yay is not installed. Please install yay manually."
fi

# ============================================================================
# BLOCK 2: BACKUP AND COPY CONFIG
# ============================================================================
step_title "2 - BACKUP AND UPDATE CONFIG IN ~/.config"

SOURCE_WM_CONFIG="$WM_DIR/config"
SOURCE_COMMON_CONFIG="$COMMON_DIR/config"
DEST_CONFIG="$HOME/.config"

if ask_yes_no "===> Do you want to backup and apply new configs now?"; then

    if ask_yes_no "===> Do you want to FULL copy everything (WM, Common, Zsh)?"; then
        echo ">>> Deploying Common configs..."
        copy_config_folders_with_backup "$SOURCE_COMMON_CONFIG" "$DEST_CONFIG"

        if [[ $WM == "hyprland" ]]; then
            echo ">>> Deploying Hyprland configs..."
            copy_config_folders_with_backup "$SOURCE_WM_CONFIG/hypr" "$DEST_CONFIG/hypr"
            copy_file_with_backup "$SOURCE_WM_CONFIG/hypr/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua"
        elif [[ $WM == "niri" ]]; then
            echo ">>> Deploying Niri configs..."
            copy_config_folders_with_backup "$SOURCE_WM_CONFIG" "$DEST_CONFIG"
        elif [[ $WM == "mango" ]]; then
            echo ">>> Deploying Mango configs..."
            copy_config_folders_with_backup "$SOURCE_WM_CONFIG" "$DEST_CONFIG"
        else
            log_warn "Unknown WM: $WM. Skipping WM config deployment."
        fi

        echo ">>> Deploying mimeapps.list..."
        copy_file_with_backup "$SOURCE_COMMON_CONFIG/mimeapps.list" "$HOME/.config/mimeapps.list"

        echo ">>> Deploying .zshrc (zsh configuration)..."
        copy_file_with_backup "$COMMON_DIR/.zshrc" "$HOME/.zshrc"

        echo ">>> Deploying .nanorc (nano configuration)..."
        copy_file_with_backup "$COMMON_DIR/.nanorc" "$HOME/.nanorc"

        log_ok "Configurations deployed successfully."

    else
        # ------------------------------------------------------------------
        # Copy SELECTIVE
        # ------------------------------------------------------------------
        echo ">>> Entering Selective Mode..."
        
        # 1. Common configs (Waybar, Rofi, Fastfetch, Cava, Kitty, Swaync...)
        COMMON_APPS=("waybar" "rofi" "fastfetch" "cava" "kitty" "swaync")

        for app in "${COMMON_APPS[@]}"; do
            if ask_yes_no "   -> Do you want to deploy $app configs?"; then
                echo "   >>> Deployed $app configs."
                copy_dir_content "$SOURCE_COMMON_CONFIG/$app" "$DEST_CONFIG/$app"
                copy_config_folders_with_backup "$SOURCE_COMMON_CONFIG/$app" "$DEST_CONFIG/$app"
            fi
        done

        # 2. Hyprlock & Hypridle
        if ask_yes_no "   -> Deploy hyprlock, hypridle configs?"; then
            echo "   >>> Deploying Hypr configs..."
            copy_file_with_backup "$SOURCE_COMMON_CONFIG/hypr/hyprlock.conf" "$DEST_CONFIG/hypr/hyprlock.conf"
            copy_file_with_backup "$SOURCE_COMMON_CONFIG/hypr/hyprlock_tiny.conf" "$DEST_CONFIG/hypr/hyprlock_tiny.conf"
            copy_file_with_backup "$SOURCE_COMMON_CONFIG/hypr/hypridle.conf" "$DEST_CONFIG/hypr/hypridle.conf"
        fi

        # 3. .zshrc
        if ask_yes_no "   -> Deploy .zshrc (Zsh configuration)?"; then
            echo "   >>> Deploying Zshrc..."
            copy_file_with_backup "$COMMON_DIR/.zshrc" "$HOME/.zshrc"
        fi
        
        # 4. WM configs
        if [[ $WM == "hyprland" ]]; then
            if ask_yes_no "   -> [Detected: Hyprland] Deploy Hyprland configs?"; then
                echo "   >>> Deploying Hyprland configs..."
                copy_dir_content "$SOURCE_WM_CONFIG/hyprland" "$DEST_CONFIG/hyprland"
            fi
            
        elif [[ $WM == "niri" ]]; then
            if ask_yes_no "   -> [Detected: Niri] Deploy Niri configs?"; then
                echo "   >>> Deploying Niri configs..."
                copy_dir_content "$SOURCE_WM_CONFIG/niri" "$DEST_CONFIG/niri"
            fi
            
        elif [[ $WM == "mango" ]]; then
            if ask_yes_no "   -> [Detected: Mango] Deploy Mango configs?"; then
                echo "   >>> Deploying Mango configs..."
                copy_dir_content "$SOURCE_WM_CONFIG/mango" "$DEST_CONFIG/mango"
            fi
        fi
    fi

    log_ok "Configurations updated successfully."
else
    log_skip "Skipping config deployment."
fi

# ============================================================================
# BLOCK 3: BACKUP AND COPY LOCAL BIN (Old Block 5)
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
echo -e "${C_BOLD}${C_YELLOW}   ! Note${C_RESET}"
echo -e "${C_YELLOW}After the update, your file manager (thunar) might reset to defaults and delete your bookmarks. please copy your old configuration file back from the backup folder in your home directory at ~/Backup_.../.config/gtk-3.0${C_RESET}"