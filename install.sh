#!/bin/bash
set -u

# ======================================================================================
# HAKUSPACE INSTALLER (CLEANED - COPY MODE + COLOR LOGS)
# ======================================================================================

cat << 'EOF'


 _   _       _          _____                      
| | | |     | |        /  ___|                     
| |_| | __ _| | ___   _\ `--. _ __   __ _  ___ ___ 
|  _  |/ _` | |/ / | | |`--. \ '_ \ / _` |/ __/ _ \
| | | | (_| |   <| |_| /\__/ / |_) | (_| | (_|  __/
\_| |_/\__,_|_|\_\\__,_\____/| .__/ \__,_|\___\___|
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
HAKU_DIR="$HOME/hakuspace"
COMMON_DIR="$HAKU_DIR/common"
PKG_COMMON="$COMMON_DIR/pkg-common.txt"

BACKUP_TS="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$HOME/Backup_$BACKUP_TS"

WM=""
WM_DIR=""
PKG_WM=""

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
    else
        log_skip "Directory already exists: $dir"
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

extract_archives_if_needed() {
    local source_dir="$1"
    local dest_dir="$2"
    local kind="$3"

    if [[ ! -d "$source_dir" ]]; then
        log_error "Not found directory $source_dir"
        return 1
    fi

    ensure_dir "$dest_dir"

    shopt -s nullglob
    local archives=("$source_dir"/*.tar.gz)
    shopt -u nullglob

    if [[ ${#archives[@]} -eq 0 ]]; then
        log_warn "No .tar.gz $kind found in $source_dir"
        return 0
    fi

    for archive in "${archives[@]}"; do
        local archive_name base_name temp_archive
        archive_name="$(basename "$archive")"
        base_name="${archive_name%.tar.gz}"
        temp_archive="$dest_dir/$archive_name"

        cp -f "$archive" "$temp_archive"

        if [[ -d "$dest_dir/$base_name" ]]; then
            log_skip "Skip extract $archive_name (already exists: $dest_dir/$base_name)"
            rm -f "$temp_archive"
            continue
        fi

        if tar -xzf "$temp_archive" -C "$dest_dir"; then
            log_copy "Extracted $archive_name to $dest_dir"
        else
            log_error "Failed to extract $archive_name"
        fi

        rm -f "$temp_archive"
    done
}

print_header() {
    echo ""
    echo -e "${C_BOLD}================================================================================================${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}--- WELCOME TO HAKUSPACE - CONFIG INSTALLER ---${C_RESET}"
    echo "This script will help you set up your HakuSpace configuration"
    echo "It will install packages, copy configs with backup, and setup environment."
    echo "Please follow the prompts to complete the installation process."
    echo -e "${C_BOLD}================================================================================================${C_RESET}"
    echo ""
}

select_window_manager() {
    echo "Current directory: $PWD"
    echo ""
    echo -e "${C_BOLD}[1]${C_RESET} HYPRLAND"
    echo -e "${C_BOLD}[2]${C_RESET} NIRI"
    echo ""
    read -r -p ">>> Which Window Manager do you want to install?: " wm_choice

    case "$wm_choice" in
        1)
            WM="hyprland"
            WM_DIR="$HAKU_DIR/hyprland"
            PKG_WM="$WM_DIR/pkg-hyprland.txt"
            log_info "Selected: Hyprland"
            ;;
        2)
            WM="niri"
            WM_DIR="$HAKU_DIR/niri"
            PKG_WM="$WM_DIR/pkg-niri.txt"
            log_info "Selected: Niri"
            ;;
        *)
            log_error "Invalid choice. Please run again and choose 1 or 2."
            exit 1
            ;;
    esac
}

preflight_checks() {
    if [[ "$PWD" != "$HAKU_DIR" ]]; then
        echo ""
        log_error "Please run this script from: $HAKU_DIR"
        log_error "Current directory: $PWD"
        exit 1
    fi

    mkdir -p "$BACKUP_DIR"
    log_ok "Backup directory initialized: $BACKUP_DIR"
}

# ======================================================================================
# MAIN
# ======================================================================================

print_header
select_window_manager
preflight_checks

# ============================================================================
# BLOCK 1: CHECK AND INSTALL DEPENDENCIES
# ============================================================================
step_title "1 - CHECK AND INSTALL DEPENDENCIES (yay, git, curl)"

if ask_yes_no "===> Do you want to install yay now?"; then
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    cd "$HOME" || exit 1
    rm -rf /tmp/yay
    log_ok "yay has been installed successfully."
else
    log_warn "You need yay to proceed with package installation."
fi

if ! command -v yay >/dev/null 2>&1; then
    log_error "yay is not installed. Please install yay first to run step 2."
    log_error "If you're using another Distro, please install the packages manually."
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
echo -e "${C_BOLD}================================================================================================${C_RESET}"
echo -e "${C_GREEN}--- Everything is ready to install Config! ---${C_RESET}"

# ============================================================================
# BLOCK 2: INSTALL PACKAGES
# ============================================================================
step_title "2 - INSTALL PACKAGES FROM LIST"

echo ":: Ready to install packages from:"
echo "   - $PKG_WM"
echo "   - $PKG_COMMON"

if command -v yay >/dev/null 2>&1; then
    if ask_yes_no "===> Do you want to install packages now?"; then
        yay -S --noconfirm - < "$PKG_COMMON"
        yay -S --noconfirm - < "$PKG_WM"
        log_ok "Package installation completed."
    else
        log_skip "Skipping package installation."
    fi
else
    log_error "yay is not installed. Please install yay first to run this step. If you're using another Distro, please install the packages manually."
fi

# ============================================================================
# BLOCK 3: CREATE NECESSARY DIRECTORIES
# ============================================================================
step_title "3 - INITIALIZE SYSTEM DIRECTORIES"

FOLDERS=(
    "$HOME/.local/bin"
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

# ============================================================================
# BLOCK 4: BACKUP AND COPY CONFIG
# ============================================================================
step_title "4 - BACKUP AND COPY CONFIG TO ~/.config"

SOURCE_WM_CONFIG="$WM_DIR/config"
SOURCE_COMMON_CONFIG="$COMMON_DIR/config"
DEST_CONFIG="$HOME/.config"

if ask_yes_no "===> Do you want to backup and copy your current config now?"; then
    echo ">>> Deploying Common configs..."
    copy_config_folders_with_backup "$SOURCE_COMMON_CONFIG" "$DEST_CONFIG"

    echo ">>> Deploying $WM configs..."
    copy_config_folders_with_backup "$SOURCE_WM_CONFIG" "$DEST_CONFIG"

    echo ">>> Deploying mimeapps.list..."
    copy_file_with_backup "$SOURCE_COMMON_CONFIG/mimeapps.list" "$HOME/.config/mimeapps.list"

    log_ok "Configurations deployed successfully."
else
    log_skip "Skipping config deployment."
fi

# ============================================================================
# BLOCK 5: BACKUP AND COPY LOCAL BIN
# ============================================================================
step_title "5 - BACKUP AND COPY ~/.local/bin"

SOURCE_BIN="$COMMON_DIR/local/bin"
DEST_BIN="$HOME/.local/bin"

if ask_yes_no "===> Do you want to backup and copy your local/bin now?"; then
    if [[ -d "$SOURCE_BIN" ]]; then
        backup_item "$DEST_BIN"
        ensure_dir "$DEST_BIN"
        copy_dir_content "$SOURCE_BIN" "$DEST_BIN"
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

if command -v yay >/dev/null 2>&1; then
    if ! command -v zsh >/dev/null 2>&1; then
        if ask_yes_no ":: Zsh is missing. Install zsh now?"; then
            yay -S --noconfirm zsh
        fi
    fi
else
    log_warn "yay is not installed. Please install zsh manually if you want to use Oh My Zsh."
    log_warn "If you're using another Distro, please install zsh manually."
fi



if ask_yes_no "===> Do you want to install Oh My Zsh now?"; then
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
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
# BLOCK 7: BACKUP AND COPY DOTFILES + WALLPAPERS
# ============================================================================
step_title "7 - BACKUP AND COPY DOTFILES + WALLPAPERS"

SOURCE_OTHER="$COMMON_DIR"
SOURCE_WALLPAPER="$COMMON_DIR/Wallpapers"
DEST_OTHER="$HOME"
DEST_WALLPAPER="$HOME/Pictures/Wallpapers"

if ask_yes_no "===> Do you want to backup and copy dotfiles + wallpapers now?"; then
    FILES_TO_COPY=(".nanorc" ".zshrc")

    for file in "${FILES_TO_COPY[@]}"; do
        copy_file_with_backup "$SOURCE_OTHER/$file" "$DEST_OTHER/$file"
    done

    if [[ -d "$SOURCE_WALLPAPER" ]]; then
        copy_dir_content "$SOURCE_WALLPAPER" "$DEST_WALLPAPER"
        log_ok "Wallpapers copied."
    else
        log_warn "Wallpapers folder not found: $SOURCE_WALLPAPER"
    fi
else
    log_skip "Skipping dotfiles/wallpapers deployment."
fi

# ============================================================================
# BLOCK 8: COPY ICONS
# ============================================================================
step_title "8 - DEPLOY ICONS TO ~/.icons"

SOURCE_ICON="$COMMON_DIR/icons"
DEST_ICON="$HOME/.icons"

if ask_yes_no "===> Do you want to deploy icons now?"; then
    extract_archives_if_needed "$SOURCE_ICON" "$DEST_ICON" "icons"
    log_ok "Icons process completed."
else
    log_skip "Skipping icons deployment."
fi

# ============================================================================
# BLOCK 9: COPY THEMES
# ============================================================================
step_title "9 - DEPLOY THEMES TO ~/.themes"

SOURCE_THEME="$COMMON_DIR/themes"
DEST_THEME="$HOME/.themes"

if ask_yes_no "===> Do you want to deploy themes now?"; then
    extract_archives_if_needed "$SOURCE_THEME" "$DEST_THEME" "themes"
    log_ok "Themes process completed."
else
    log_skip "Skipping themes deployment."
fi

# ============================================================================
# BLOCK 10: ENABLE SERVICES
# ============================================================================
step_title "10 - ENABLE SYSTEM SERVICES"

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable ly@tty1.service
sudo systemctl disable getty@tty1.service

xdg-mime default thunar.desktop inode/directory

if [[ -x "$HOME/.local/bin/gen-style.sh" ]]; then
    "$HOME/.local/bin/gen-style.sh"
    log_ok "Executed gen-style.sh"
else
    log_warn "Not executable or missing: $HOME/.local/bin/gen-style.sh"
fi

echo ""
echo -e "${C_GREEN}✅ All services have been processed!${C_RESET}"
echo ""
echo -e "${C_BOLD}${C_CYAN}>>>>>>>>>> All done! Please restart your pc to apply changes!${C_RESET}"
echo -e "${C_MAGENTA}Backup folder for this run: $BACKUP_DIR${C_RESET}"