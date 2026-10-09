#!/usr/bin/env bash

# Functions for script install.sh and update.sh

# Color
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


# Logging helpers
log_info()   { echo -e "${C_BLUE}[INFO]${C_RESET}   $1"; }
log_ok()     { echo -e "${C_GREEN}[OK]${C_RESET}     $1"; }
log_warn()   { echo -e "${C_YELLOW}[WARN]${C_RESET}   $1"; }
log_error()  { echo -e "${C_RED}[ERROR]${C_RESET}  $1"; }
log_backup() { echo -e "${C_MAGENTA}[BACKUP]${C_RESET} $1"; }
log_copy()   { echo -e "${C_CYAN}[COPY]${C_RESET}   $1"; }
log_skip()   { echo -e "${C_WHITE}[SKIP]${C_RESET}   $1"; }
log_symlink(){ echo -e "${C_MAGENTA}[SYMLINK]${C_RESET} $1"; }
step_title() {
    echo ""
    echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BOLD}${C_BLUE}$1${C_RESET}"
    echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
}

# Utility helpers
ask_yes_no() {
    local prompt="$1"
    local answer
    read -r -p "$prompt (y/n): " answer
    [[ "$answer" =~ ^[yY]([eE][sS])?$ ]]
}

ensure_dir() {
    local dir="$1"
    if [[ -L "$dir" ]]; then rm -f "$dir"; fi
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || return 1
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

# Copy dir to backup dir
backup_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0

    local rel="${dir#$HOME/}"
    rel="${rel#/}"
    local backup_target="$BACKUP_DIR/$rel"
    local parent_dir
    parent_dir="$(dirname "$dir")"

    if [[ -w "$parent_dir" && ( ! -e "$dir" || -w "$dir" ) ]]; then
        mkdir -p "$(dirname "$backup_target")"
        cp -r "$dir" "$backup_target"
        log_backup "$dir -> $backup_target"
    else
        sudo mkdir -p "$(dirname "$backup_target")"
        sudo cp -r "$dir" "$backup_target"
        sudo chown -R "$USER:$USER" "$(dirname "$backup_target")" 2>/dev/null
        log_backup "$dir -> $backup_target (sudo)"
    fi
}

copy_file() {
    local src="$1"
    local dst="$2"
    local skip_backup="${3:-0}"

    if [[ ! -f "$src" ]]; then
        log_warn "Source file not found: $src"
        return 1
    fi

    if [[ "$skip_backup" -eq 1 && -L "$dst" ]]; then
        rm -f "$dst"
    fi

    if [[ "$skip_backup" -ne 1 && ( -e "$dst" || -L "$dst" ) ]]; then
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
        cp -f "$src" "$dst" || return 1
        log_copy "$src -> $dst"
    else
        sudo cp -f "$src" "$dst" || return 1
        log_copy "$src -> $dst (sudo)"
    fi
    
    return 0
}

copy_dir_content() {
    local src="$1"
    local dst="$2"
    local skip_backup="${3:-0}"

    if [[ ! -d "$src" ]]; then
        log_warn "Source directory not found: $src"
        return 1
    fi

    if [[ "$skip_backup" -ne 1 && ( -e "$dst" || -L "$dst" ) ]]; then
        backup_item "$dst"
    fi

    ensure_dir "$dst" || return 1
    
    cp -rf "$src"/. "$dst"/ || return 1
    log_copy "$src/. -> $dst/"
    return 0
}

# Recursively deploy files as symlinks (deep symlink)
deploy_symlink_recursive() {
    local src="$1" dst="$2" skip_backup="${3:-0}"
    [[ ! -e "$src" ]] && { log_warn "Source not found: $src"; return 1; }

    if [[ -d "$src" ]]; then
        ensure_dir "$dst"
        (
            shopt -s dotglob nullglob
            for item in "$src"/*; do
                deploy_symlink_recursive "$item" "$dst/${item##*/}" "$skip_backup" || exit 1
            done
        ) || return 1
        return 0
    fi

    if [[ -L "$dst" ]]; then
        [[ "$(readlink "$dst")" == "$(realpath "$src")" ]] && return 0
        rm -f "$dst"
    elif [[ -e "$dst" && "$skip_backup" -ne 1 ]]; then
        backup_item "$dst"
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then rm -rf "$dst"; fi

    ln -sfn "$(realpath "$src")" "$dst" || return 1
    log_symlink "$src => $dst"
}

determine_deploy_mode() {
    if [[ -n "${HAKUSPACE_DEPLOY_MODE:-}" ]]; then
        return 0
    fi

    local symlink_count=0
    local copy_count=0
    local total_checked=0
    
    # Check all configs that Hakuspace tracks
    for item in "$SOURCE_CONFIG"/*; do
        [[ -e "$item" ]] || continue
        
        local item_name="${item##*/}"
        local dst="$DEST_CONFIG/$item_name"
        
        if [[ -e "$dst" ]]; then
            total_checked=$((total_checked + 1))
            if [[ -L "$dst" ]]; then
                symlink_count=$((symlink_count + 1))
            else
                copy_count=$((copy_count + 1))
            fi
        fi
    done
    
    # Check a few scripts as well
    for script in haku_theme.sh dockbar_manager.sh; do
        local dst="$DEST_BIN/$script"
        if [[ -e "$dst" ]]; then
            total_checked=$((total_checked + 1))
            if [[ -L "$dst" ]]; then
                symlink_count=$((symlink_count + 1))
            else
                copy_count=$((copy_count + 1))
            fi
        fi
    done
    
    if [[ $total_checked -eq 0 ]]; then
        HAKUSPACE_DEPLOY_MODE="symlink"
        return 0
    fi
    
    if [[ $symlink_count -eq $total_checked ]]; then
        HAKUSPACE_DEPLOY_MODE="symlink"
    elif [[ $copy_count -eq $total_checked ]]; then
        HAKUSPACE_DEPLOY_MODE="copy"
    else
        echo -e "\n${C_YELLOW}[WARN]${C_RESET} Mixed deployment state detected ($symlink_count symlinks, $copy_count copies)." >&2
        local choice
        while true; do
            read -r -p ">>> Are you using [s]ymlink or [c]opy mode? (s/c): " choice </dev/tty >/dev/tty
            case "${choice,,}" in
                s|symlink)
                    HAKUSPACE_DEPLOY_MODE="symlink"
                    break
                    ;;
                c|copy)
                    HAKUSPACE_DEPLOY_MODE="copy"
                    break
                    ;;
                *)
                    echo "Please answer 's' or 'c'." >&2
                    ;;
            esac
        done
    fi
}

# Wrapper for deployment: uses symlink or copy based on state
deploy_config_item() {
    local src="$1" dst="$2" skip_backup="${3:-0}"
    determine_deploy_mode
    
    if [[ "$HAKUSPACE_DEPLOY_MODE" == "symlink" ]]; then
        deploy_symlink_recursive "$src" "$dst" "$skip_backup"
    else
        if [[ -d "$src" ]]; then
            copy_dir_content "$src" "$dst" "$skip_backup"
        else
            copy_file "$src" "$dst" "$skip_backup"
        fi
    fi
}

deploy_hakuspace_scripts() {
    if [[ ! -d "$SOURCE_CORE" ]]; then
        log_warn "Source directory not found: $SOURCE_CORE"
        return 1
    fi

    # Make all .sh and .py scripts executable in the source
    find "$SOURCE_CORE" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} +

    echo ">>> Deploying scripts to $DEST_BIN..."
    
    determine_deploy_mode
    if [[ "$HAKUSPACE_DEPLOY_MODE" == "copy" ]]; then
        if [[ -d "$DEST_BIN" ]]; then
            log_warn "Deployment mode is COPY. Backing up and clearing entire $DEST_BIN as requested..."
            backup_item "$DEST_BIN"
            rm -rf "$DEST_BIN"
        fi
    fi
    
    ensure_dir "$DEST_BIN" || return 1
    
    # We use deploy_config_item to deploy the files flatly into DEST_BIN
    # It will respect the deploy_mode (symlink or copy)
    local -A seen_scripts
    while IFS= read -r -d '' file; do
        local filename
        filename="$(basename "$file")"
        [[ "$filename" == "README.md" ]] && continue
        if [[ -n "${seen_scripts[$filename]:-}" ]]; then
            log_error "Script name collision: '$filename' found in both '${seen_scripts[$filename]}' and '$file'"
            return 1
        fi
        seen_scripts[$filename]="$file"
        deploy_config_item "$file" "$DEST_BIN/$filename" || return 1
    done < <(find "$SOURCE_CORE" -type f -print0)
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

# Window Manager selection
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
            SELECTED_WM_DIRS=("$SOURCE_CONFIG/hypr")
            SELECTED_PKG_WMS=("$PKG_HYPRLAND")
            log_info "Selected: Hyprland"
            ;;
        2)
            SELECTED_WMS=("niri")
            SELECTED_WM_DIRS=("$SOURCE_CONFIG/niri")
            SELECTED_PKG_WMS=("$PKG_NIRI")
            log_info "Selected: Niri"
            ;;
        3)
            SELECTED_WMS=("mango")
            SELECTED_WM_DIRS=("$SOURCE_CONFIG/mango")
            SELECTED_PKG_WMS=("$PKG_MANGO")
            log_info "Selected: Mango"
            ;;
        4)
            SELECTED_WMS=("labwc")
            SELECTED_WM_DIRS=("$SOURCE_CONFIG/labwc")
            SELECTED_PKG_WMS=("$PKG_LABWC")
            log_info "Selected: Labwc"
            ;;
        5)
            SELECTED_WMS=("niri" "mango" "labwc" "hyprland")
            SELECTED_WM_DIRS=("$SOURCE_CONFIG/niri" "$SOURCE_CONFIG/mango" "$SOURCE_CONFIG/labwc" "$SOURCE_CONFIG/hypr")
            SELECTED_PKG_WMS=("$PKG_NIRI" "$PKG_MANGO" "$PKG_LABWC" "$PKG_HYPRLAND")
            log_info "Selected: All Window Managers"
            ;;
        *)
            log_error "Invalid choice. Please run again and choose 1, 2, 3, 4 or 5."
            exit 1
            ;;
    esac
}

select_deploy_mode() {
    echo ""
    echo -e "${C_BOLD}--- DOTFILES DEPLOYMENT MODE ---${C_RESET}"
    echo "HakuSpace can deploy your configuration files using two methods:"
    echo -e "  ${C_BOLD}[1]${C_RESET} Symlink (Recommended) - Edits in ~/.config will directly update the repo."
    echo -e "  ${C_BOLD}[2]${C_RESET} Copy - Copies files normally. Edits in ~/.config will NOT update the repo."
    echo ""
    read -r -p ">>> Choose deployment mode (default: 1): " deploy_choice
    deploy_choice="${deploy_choice:-1}"
    
    if [[ "$deploy_choice" == "2" ]]; then
        HAKUSPACE_DEPLOY_MODE="copy"
        log_info "Selected deployment mode: COPY"
    else
        HAKUSPACE_DEPLOY_MODE="symlink"
        log_info "Selected deployment mode: SYMLINK"
    fi
}

# Deploy for hakuspace-archive repo (Wallpaper, icons, etc.)
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

# Check ~/hakucfg directory:
check_control_dir() {
    if [[ ! -d "$HAKUSPACE_CUSTOM_DIR" ]]; then
        log_warn "hakucfg directory not found. Creating..."
        mkdir -p "$HAKUSPACE_CUSTOM_DIR"
    fi

    local required_files=(
        "setting.sh"
        "wm/mango-custom.conf"
        "wm/niri-custom.kdl"
        "wm/hyprland-custom.lua"
        "config/dockbar_pin_apps"
        "config/hypridle.conf"
        "config/kitty.conf"
        "config/shell.fish"
        "general-menu.sh"
    )
    for file in "${required_files[@]}"; do
        if [[ ! -f "$DEST_CUSTOM_DIR/$file" ]]; then
            log_warn "$file not found in hakucfg. Creating default..."
            copy_file "$HAKUSPACE_CUSTOM_DIR/$file" "$DEST_CUSTOM_DIR/$file"
        fi
    done

    mkdir -p "$DEST_CUSTOM_DIR/config/waybar"
    mkdir -p "$DEST_CUSTOM_DIR/config/rofi"
    chmod +x "$DEST_CUSTOM_DIR/setting.sh"
    chmod +x "$DEST_CUSTOM_DIR/general-menu.sh"

    # Check HakuSpace custom settings version
    if [[ -f "$DEST_CUSTOM_DIR/setting.sh" ]]; then
        local current_version
        local source_version
        chmod +x "$HAKUSPACE_CUSTOM_DIR/setting.sh"

        source_version=$("$HAKUSPACE_CUSTOM_DIR/setting.sh" --version)
        current_version=$("$DEST_CUSTOM_DIR/setting.sh" --version)
        if [[ "$current_version" != "$source_version" ]]; then
            log_warn "Hakuspace custom settings version mismatch: $current_version (current) vs $source_version (expected). Updating..."
            log_warn "If you choose update, your custom settings in setting.sh will be overwritten."
            if ask_yes_no "===> Do you want to update hakucfg to the latest version?"; then
                copy_file "$HAKUSPACE_CUSTOM_DIR/setting.sh" "$DEST_CUSTOM_DIR/setting.sh"
                log_ok "Hakucfg updated to version $source_version."
            else
                log_warn "You chose not to update hakucfg. Some features may not work as expected."
            fi
        else
            log_ok "Hakuspace Control version is up-to-date: $current_version"
        fi
    else
        log_warn "setting.sh not found in hakucfg. Creating default..."
        copy_file "$HAKUSPACE_CUSTOM_DIR/setting.sh" "$DEST_CUSTOM_DIR/setting.sh"
    fi
}