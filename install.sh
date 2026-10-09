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

ARCHIVE_REPO_URL="https://github.com/hakuimaku/hakuspace-archive.git"
ARCHIVE_DIR="$HOME/hakuspace-archive"

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
    rel="${rel#/}"
    local backup_target="$BACKUP_DIR/$rel"
    local target_dir
    target_dir="$(dirname "$target")"

    if [[ -w "$target_dir" && ( ! -e "$target" || -w "$target" ) ]]; then
        mkdir -p "$(dirname "$backup_target")"
        mv "$target" "$backup_target"
        log_backup "$target -> $backup_target"
    else
        sudo mkdir -p "$(dirname "$backup_target")"
        sudo mv "$target" "$backup_target"
        sudo chown -R "$USER:$USER" "$(dirname "$backup_target")" 2>/dev/null
        log_backup "$target -> $backup_target (sudo)"
    fi
}

copy_file() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$src" ]]; then
        log_warn "Source file not found: $src"
        return 1
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        backup_item "$dst"
    fi

    local dest_dir
    dest_dir="$(dirname "$dst")"

    if [[ ! -d "$dest_dir" ]]; then
        if ! mkdir -p "$dest_dir" 2>/dev/null; then
            sudo mkdir -p "$dest_dir"
        fi
    fi

    if [[ -w "$dest_dir" ]]; then
        cp -f "$src" "$dst"
        log_copy "$src -> $dst"
    else
        sudo cp -f "$src" "$dst"
        log_copy "$src -> $dst (sudo)"
    fi
    
    return 0
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
    echo -e "${C_BOLD}${C_CYAN}--- WELCOME TO HAKUSPACE - CONFIG INSTALLER ---${C_RESET}"
    echo "This script will help you set up your HakuSpace configuration"
    echo "It will install packages, copy configs with backup, and setup environment."
    echo "Please follow the prompts to complete the installation process."
    echo "Press CTRL+C to cancel at any time."
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

deploy_assets_from_archive_repo() {
    if ! command -v git >/dev/null 2>&1; then
        log_error "git is required to clone $ARCHIVE_REPO_URL"
        return 1
    fi

    if [[ -d "$ARCHIVE_DIR/.git" ]]; then
        log_info "Archive repo already exists. Pulling latest changes..."
        if ! git -C "$ARCHIVE_DIR" pull --ff-only; then
            log_error "Failed to update $ARCHIVE_DIR"
            return 1
        fi
    else
        if [[ -d "$ARCHIVE_DIR" ]]; then
            log_warn "$ARCHIVE_DIR exists but is not a git repo."
            if ask_yes_no "===> Remove and re-clone hakuspace-archive?"; then
                rm -rf "$ARCHIVE_DIR"
            else
                log_warn "Cannot continue archive deployment without a valid repo."
                return 1
            fi
        fi

        log_info "Cloning archive repo..."
        if ! git clone "$ARCHIVE_REPO_URL" "$ARCHIVE_DIR"; then
            log_error "Failed to clone $ARCHIVE_REPO_URL"
            return 1
        fi
    fi

    if [[ ! -f "$ARCHIVE_DIR/setup.sh" ]]; then
        log_error "setup.sh not found in $ARCHIVE_DIR"
        return 1
    fi

    chmod +x "$ARCHIVE_DIR/setup.sh"
    log_info "Running archive setup script..."
    (cd "$ARCHIVE_DIR" && ./setup.sh)
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
# MAIN
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
log_info "You can CTRL+C to cancel installing & nano ~/hakuspace/common/pkg-core.txt to edit package list"

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
    "$HOME/Videos/Wallpapers/Preview"
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
                grep -q '\./hakuspace-config\.nix' "$CONFIG_NIX" || sudo sed -i '/\.\/hardware-configuration\.nix/a \      .\/hakuspace-config\.nix' "$CONFIG_NIX"
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

log_info "Backing up existing configs in ~/.config and copying new configs from hakuspace/common/config"
log_warn "Do NOT skip this step in the first time installation hakuspace"

SOURCE_COMMON_CONFIG="$COMMON_DIR/config"
SOURCE_ONCE_CONFIG="$COMMON_DIR/once-config"
DEST_CONFIG="$HOME/.config"

if ask_yes_no "===> Do you want to setup hakuspace config now?"; then

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

    echo ">>> Deploying Once configs..."
    for folder in "$SOURCE_ONCE_CONFIG"/*/; do
        [[ -d "$folder" ]] || continue
        folder_name="$(basename "$folder")"
        copy_dir_content "$SOURCE_ONCE_CONFIG/$folder_name" "$DEST_CONFIG/$folder_name"
    done

    # Loop through selected WMs (hyprland will always be last if "ALL" was chosen)
    for i in "${!SELECTED_WMS[@]}"; do
        WM_NAME="${SELECTED_WMS[$i]}"
        WM_DIR_PATH="${SELECTED_WM_DIRS[$i]}"
        SOURCE_WM_CONFIG="$WM_DIR_PATH"

        if [[ $WM_NAME == "hyprland" ]]; then
            echo ">>> Deploying Hyprland configs..."
            copy_dir_content "$SOURCE_WM_CONFIG/config" "$DEST_CONFIG/hypr/config"
            copy_file "$SOURCE_WM_CONFIG/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua"
        elif [[ $WM_NAME == "niri" ]]; then
            echo ">>> Deploying Niri configs..."
            copy_dir_content "$SOURCE_WM_CONFIG" "$DEST_CONFIG/niri"
        elif [[ $WM_NAME == "mango" ]]; then
            echo ">>> Deploying Mango configs..."
            copy_dir_content "$SOURCE_WM_CONFIG" "$DEST_CONFIG/mango"
        elif [[ $WM_NAME == "labwc" ]]; then
            echo ">>> Deploying Labwc configs..."
            copy_dir_content "$SOURCE_WM_CONFIG" "$DEST_CONFIG/labwc"
        else
            log_warn "Unknown WM: $WM_NAME. Skipping WM config deployment."
        fi
    done

    echo ">>> Deploying Thunar gtk.css theme..."
    copy_file "$SOURCE_COMMON_CONFIG/gtk.css" "$DEST_CONFIG/gtk-3.0/gtk.css"

    echo ">>> Deploying mimeapps.list..."
    copy_file "$SOURCE_ONCE_CONFIG/mimeapps.list" "$DEST_CONFIG/mimeapps.list"

    echo ">>> Deploying .zshrc (zsh configuration)..."
    copy_file "$SOURCE_COMMON_CONFIG/.zshrc" "$HOME/.zshrc"

    echo ">>> Deploying .nanorc (nano configuration)..."
    copy_file "$SOURCE_COMMON_CONFIG/.nanorc" "$HOME/.nanorc"

    log_ok "Configurations deployed finished."
else
    log_skip "Skipping config deployment."
fi

# ============================================================================
# BLOCK 5: BACKUP AND COPY LOCAL BIN
# ============================================================================
step_title "5 - SETUP LOCAL BIN SCRIPTS"

log_info "Backing up existing ~/.local/bin and copying new scripts from hakuspace/common/local/bin"
log_warn "Do NOT skip this step in the first time installation hakuspace"

SOURCE_BIN="$COMMON_DIR/local/bin"
DEST_BIN="$HOME/.local/bin"

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
# BLOCK 6: INSTALL OH MY ZSH + PLUGINS
# ============================================================================
step_title "6 - SETUP OH MY ZSH AND PLUGINS"

log_info "This step will install Oh My Zsh and its plugins (zsh-autosuggestions, zsh-syntax-highlighting) if not already installed."

if ask_yes_no "===> Do you want to install Oh My Zsh now?"; then
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh..."
        KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log_skip "Oh My Zsh already installed."
    fi

    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom/plugins"

    if [[ ! -d "$ZSH_CUSTOM/zsh-autosuggestions" ]]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/zsh-autosuggestions"
    else
        log_skip "zsh-autosuggestions already installed."
    fi

    if [[ ! -d "$ZSH_CUSTOM/zsh-syntax-highlighting" ]]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/zsh-syntax-highlighting"
    else
        log_skip "zsh-syntax-highlighting already installed."
    fi

    if [[ "$SHELL" != "/usr/bin/zsh" ]]; then
        log_info "Changing default shell to zsh..."
        sudo chsh -s /usr/bin/zsh "$USER"
    else
        log_skip "Default shell is already zsh."
    fi
else
    log_skip "Skipping Oh My Zsh installation."
fi

# ============================================================================
# BLOCK 7: CLONE HAKUSPACE-ARCHIVE AND RUN setup.sh
# ============================================================================
step_title "7 - DEPLOY EXTRA ASSETS FROM hakuspace-archive"

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
# BLOCK 8: ENABLE SERVICES
# ============================================================================
step_title "8 - ENABLE SYSTEM SERVICES"

# Check if ly is installed
FOUND=0
for path in /usr/bin/ly /usr/local/bin/ly /usr/sbin/ly /usr/bin/ly-dm; do
    if [ -f "$path" ]; then
        FOUND=1
        break
    fi
done

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
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
log_ok "Set GNOME color scheme to dark."

# Set Thunar as default file manager if installed
if command -v thunar >/dev/null 2>&1; then
    xdg-mime default thunar.desktop inode/directory
    log_ok "Set Thunar as default file manager."
else
    log_warn "Thunar is not installed. Skipping setting default file manager."
fi

# Gen style first time
if [[ -x "$HOME/.local/bin/gen_style.sh" ]]; then
    "$HOME/.local/bin/gen_style.sh"
    log_ok "Executed gen_style.sh"
else
    log_warn "Not executable or missing: $HOME/.local/bin/gen_style.sh"
    log_warn "Check if the script exists and has execute permissions in ~/.local/bin/"
fi

# Init HakuSpace Control
check_control_dir

# NixOS configuration update
if command -v nixos-rebuild >/dev/null 2>&1; then
    if ask_yes_no "===> NixOS configuration updated. Do you want to rebuild NixOS system now? (maybe have some conflicts)"; then
        sudo nixos-rebuild switch
    else
        log_warn "You chose not to rebuild NixOS system. Please remember to run 'sudo nixos-rebuild switch' later."
    fi
fi

echo ""
echo -e "${C_GREEN}All services have been processed!${C_RESET}"
echo ""
echo -e "${C_BOLD}${C_CYAN}>>>>>>>>>> All done! Please restart your pc to apply changes!${C_RESET}"
echo -e "${C_MAGENTA}Backup folder for this run: $BACKUP_DIR${C_RESET}"