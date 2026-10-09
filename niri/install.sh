#!/bin/bash

# Copy config, bin, .zshrc and .nanorc files will backup current config
# The backup will be created in the same location with a timestamp suffix (e.g., .config_backup_20240601_123456).
# This way, you can easily restore your previous configuration if needed.
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


echo ""
echo "================================================================================================"
echo "--- WELCOME TO HAKUSPACE - NIRI CONFIG INSTALLER ---"
echo "This script will help you set up your HakuSpace configuration"
echo "It will install necessary packages, copying config files and setting up Oh My Zsh with plugins."
echo "Please follow the prompts to complete the installation process."
echo "================================================================================================"
echo ""

HAKU_DIR="$HOME/hakuspace"
NIRI_DIR="$HAKU_DIR/niri"
COMMON_DIR="$HAKU_DIR/common"

# ============================================================================
# ========= BLOCK 1: CHECK AND INSTALL DEPENDENCIES (yay, git, curl) =========
# ============================================================================
read -p "===> Do you want to install yay now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    cd "$HOME"
    rm -rf /tmp/yay
    echo ":: yay has been installed successfully!"
else
    echo "You need to install yay to proceed with package installation."
fi

DEPENDENCIES=("yay" "git" "curl")

echo ""
echo "--- 1. Check package dependencies ---"
if ! command -v yay &> /dev/null; then
    echo "XXX [ERROR] yay is not installed. Please install yay to proceed."
    exit 1
fi
for pkg in "${DEPENDENCIES[@]}"; do
    if command -v "$pkg" &> /dev/null; then
        echo ":: [OK] $pkg DONE!"
    else
        echo "XXX [ERROR] $pkg DOES NOT EXIST!"
        
        read -p "===> Do you want to install $pkg now? (y/n): " confirm
        if [[ $confirm == [yY] ]]; then
            yay -S --noconfirm "$pkg"
        else
            echo "You need to install $pkg to install packages from pkg-niri.txt"
        fi
    fi
done

echo ""
echo ""
echo "================================================================================================"
echo "--- Everything is ready to install Config! ---"




# ============================================================================
# ============= BLOCK 2: INSTALL PACKAGES FROM pkg-niri.txt ==============
# ============================================================================

PKG_FILE="$NIRI_DIR/pkg-niri.txt"

echo ""
echo "--- 2. Ready to install packages from pkg-niri.txt ---"

echo ":: Ready to install packages..."
read -p "===> Do you want to install packages from pkg-niri.txt now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    if [[ ! -f "$PKG_FILE" ]]; then
        echo "XXX [ERROR] Not found file $PKG_FILE"
        exit 1
    fi
    yay -S --noconfirm - < "$PKG_FILE"
    
    echo "-------------------------------------------"
    echo ":: All packages from the list have been processed!"
else
    echo "Skipping package installation."
fi


# ============================================================================
# ========= BLOCK 3: CREATE NECESSARY DIRECTORIES (IF NOT EXIST) =============
# ============================================================================

echo ""
echo "--- 3. Ready to initialize system directories ---"

# List of directories to create
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
    if [ ! -d "$folder" ]; then
        mkdir -p "$folder"
        echo ":: Created directory: $folder"
    else
        echo ":: Directory already exists: $folder"
    fi
done



# ============================================================================
# ================= BLOCK 4: BACKUP AND COPY CONFIG FILE =====================
# ============================================================================

SOURCE_NIRI_CONFIG="$NIRI_DIR/config" # include folder: niri, waybar, swaylock, swayidle
SOURCE_COMMON_CONFIG="$COMMON_DIR/config" # include folder: cava, fastfetch, gtk-3.0, kitty, rofi, swaync
DEST_CONFIG="$HOME/.config"

echo ""
echo "--- 4. Ready to deploy config to ~/.config ---"

deploy_config() {
    local source_dir=$1
    local dest_dir=$2
    local timestamp=$(date +%Y%m%d_%H%M%S)

    if [[ -d "$source_dir" ]]; then
        for folder in "$source_dir"/*/; do
            [ -d "$folder" ] || continue 
            
            local folder_name=$(basename "$folder")
            local target_path="$dest_dir/$folder_name"

            if [[ -d "$target_path" ]] || [[ -L "$target_path" ]]; then
                echo "[-] Found existing $folder_name in $dest_dir. Backing up..."
                mv "$target_path" "${target_path}_backup_${timestamp}"
            fi

            echo "[+] Copying $folder_name to $dest_dir..."
            cp -r "$folder" "$dest_dir/"
        done
    else
        echo "[!] Source directory $source_dir does not exist. Skipping."
    fi
}

read -p "===> Do you want to backup and copy your current config now? (y/n): " confirm
if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    
    echo ""
    echo ">>> Deploying Common configs..."
    deploy_config "$SOURCE_COMMON_CONFIG" "$DEST_CONFIG"
    
    echo ""
    echo ">>> Deploying Niri configs..."
    deploy_config "$SOURCE_NIRI_CONFIG" "$DEST_CONFIG"
    
    echo "===> Done! Configurations deployed successfully."
else
    echo "Skipping config backup and deployment."
fi


# ============================================================================================
# ================= BLOCK 5: BACKUP AND COPY LOCAL FILES (BIN / SCRIPTS) =====================
# ============================================================================================

SOURCE_BIN="$NIRI_DIR/local/bin"
DEST_BIN="$HOME/.local/bin"

echo ""
echo "--- 5. Ready to deploy local/bin files to ~/.local ---"

read -p "===> Do you want to backup and copy your current local/bin files now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    if [ -d "$SOURCE_BIN" ]; then
        echo ":: Ready to copy local/bin files..."
        # Make backup if destination local already exists
        if [ -d "$DEST_BIN" ]; then
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            echo ":: Ready to create backup for current local/bin files..."
            mv "$DEST_BIN" "${DEST_BIN}_backup_$TIMESTAMP"
            mkdir -p "$DEST_BIN"
        fi

        # Proceed with copying local files
        cp -rf "$SOURCE_BIN"/. "$DEST_BIN/"
        
        echo ":: Copy (local/bin files) completed to $DEST_BIN"
    else
        echo "XXX [ERROR] Not found directory $SOURCE_BIN"
        echo "Please copy it manually (local/bin files) to $DEST_BIN"
    fi
else
    echo "Skipping local files backup."
fi

# ===========================================================================================
# ================= BLOCK 6: INSTALL OH MY ZSH AND PLUGINS (IF USER CONFIRM) ================
# ===========================================================================================

# Install Oh My Zsh and plugins
echo ""
echo "--- 6. Setup Oh My Zsh and Plugins ---"

if ! command -v zsh &> /dev/null; then
    echo ":: Zsh is missing. Do you want to install zsh now? (y/n): "
    read -r confirm
    if [[ $confirm == [yY] ]]; then
        yay -S --noconfirm zsh
    fi
fi

read -p "===> Do you want to install Oh My Zsh now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo ":: Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        echo ":: Oh My Zsh already installed."
    fi

    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom/plugins"

    # zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/zsh-autosuggestions" ]; then
        echo ":: Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/zsh-autosuggestions"
    fi

    # zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/zsh-syntax-highlighting" ]; then
        echo ":: Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/zsh-syntax-highlighting"
    fi

    # Change default shell to Zsh (Need to enter sudo password)
    if [ "$SHELL" != "/usr/bin/zsh" ]; then
        echo "Changing default shell to Zsh..."
        sudo chsh -s /usr/bin/zsh $USER
    fi
else
    echo "Skipping Oh My Zsh installation."
fi


# =======================================================================================
# ========= BLOCK 7: BACKUP AND COPY OTHER FILES (.zshrc, .nanorc, wallpapers) ==========
# =======================================================================================

SOURCE_OTHER="$COMMON_DIR"
SOURCE_WALLPAPER="$COMMON_DIR/Wallpapers"

DEST_OTHER="$HOME"
DEST_WALLPAPER="$HOME/Pictures/Wallpapers"


echo ""
echo "--- 7. Ready to deploy other files (like .nanorc and .zshrc) to home directory and wallpapers ---"

read -p "===> Do you want to backup and copy your other files now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    FILES_TO_COPY=(".nanorc" ".zshrc")

    for file in "${FILES_TO_COPY[@]}"; do
        if [ -f "$SOURCE_OTHER/$file" ]; then
            # Make backup if destination file already exists
            if [ -f "$DEST_OTHER/$file" ]; then
                mv "$DEST_OTHER/$file" "$DEST_OTHER/${file}.bak"
                echo ":: Did create backup for $file"
            fi
            
            # Copy file from source to destination
            cp -f "$SOURCE_OTHER/$file" "$DEST_OTHER/"
            echo ":: Did copy $file to $DEST_OTHER"
        else
            echo "!!! File not found: $file in $SOURCE_OTHER, skipping."
            echo "Please copy it manually ($file) to $DEST_OTHER"
        fi
    done
    # Copy wallpapers
    cp -rf "$SOURCE_WALLPAPER"/. "$DEST_WALLPAPER/"
    echo ":: Did copy wallpapers to $DEST_WALLPAPER"
else
    echo "Skipping other files backup."
fi



# =========================================================================
# ==================== BLOCK 8: BACKUP AND COPY ICONS =====================
# =========================================================================


# Define source and destination paths for icons
SOURCE_ICON="$COMMON_DIR/icons"
DEST_ICON="$HOME/.icons"

echo ""
echo "--- 8. Ready to deploy icons to ~/.icons ---"

read -p "===> Do you want to backup and copy your icons now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    if [ -d "$SOURCE_ICON" ]; then
        shopt -s nullglob
        ICON_ARCHIVES=("$SOURCE_ICON"/*.tar.gz)
        if [ ${#ICON_ARCHIVES[@]} -eq 0 ]; then
            echo "!!! No .tar.gz icons found in $SOURCE_ICON"
        else
            for archive in "${ICON_ARCHIVES[@]}"; do
                archive_name=$(basename "$archive")
                dest_archive="$DEST_ICON/$archive_name"
                base_name="${archive_name%.tar.gz}"

                cp -f "$archive" "$DEST_ICON/"

                if [ -d "$DEST_ICON/$base_name" ]; then
                    echo ":: Skip extract $archive_name (already exists: $DEST_ICON/$base_name)"
                    rm -f "$dest_archive"
                    continue
                fi

                tar -xzf "$dest_archive" -C "$DEST_ICON"
                if [ $? -ne 0 ]; then
                    echo "XXX [ERROR] Failed to extract $archive_name"
                else
                    echo ":: Extracted $archive_name to $DEST_ICON"
                fi

                rm -f "$dest_archive"
            done
        fi
        shopt -u nullglob
        echo ":: Copy (icons) completed to $DEST_ICON"
    else
        echo "XXX [ERROR] Not found directory $SOURCE_ICON"
        echo "Please copy it manually (icons) to $DEST_ICON"
    fi
else
    echo "Skipping icons backup."
fi



# ==========================================================================
# ==================== BLOCK 9: BACKUP AND COPY THEMES ====================
# ==========================================================================

# Define source and destination paths for themes
SOURCE_THEME="$COMMON_DIR/themes"
DEST_THEME="$HOME/.themes"

echo ""
echo "--- 9. Ready to deploy themes to ~/.themes ---"

read -p "===> Do you want to backup and copy your themes now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    if [ -d "$SOURCE_THEME" ]; then
        shopt -s nullglob
        THEME_ARCHIVES=("$SOURCE_THEME"/*.tar.gz)
        if [ ${#THEME_ARCHIVES[@]} -eq 0 ]; then
            echo "!!! No .tar.gz themes found in $SOURCE_THEME"
        else
            for archive in "${THEME_ARCHIVES[@]}"; do
                archive_name=$(basename "$archive")
                dest_archive="$DEST_THEME/$archive_name"
                base_name="${archive_name%.tar.gz}"

                cp -f "$archive" "$DEST_THEME/"

                if [ -d "$DEST_THEME/$base_name" ]; then
                    echo ":: Skip extract $archive_name (already exists: $DEST_THEME/$base_name)"
                    rm -f "$dest_archive"
                    continue
                fi

                tar -xzf "$dest_archive" -C "$DEST_THEME"
                if [ $? -ne 0 ]; then
                    echo "XXX [ERROR] Failed to extract $archive_name"
                else
                    echo ":: Extracted $archive_name to $DEST_THEME"
                fi

                rm -f "$dest_archive"
            done
        fi
        shopt -u nullglob
        echo ":: Copy (themes) completed to $DEST_THEME"
    else
        echo "XXX [ERROR] Not found directory $SOURCE_THEME"
        echo "Please copy it manually (themes) to $DEST_THEME"
    fi
else
    echo "Skipping themes backup."
fi


# ==========================================================================
# ==================== BLOCK 10: ENABLE SYSTEM SERVICES ====================
# ==========================================================================

# Enable service
echo ""
echo "--- 10. Enabling system services ---"

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable ly@tty1.service
sudo systemctl disable getty@tty1.service

gsettings set org.cinnamon.desktop.default-applications.terminal exec 'kitty'
gsettings set org.cinnamon.desktop.default-applications.terminal exec-arg ''

$HOME/.local/bin/gen-style.sh

echo "✅ All services have been processed!"

# Final message
echo ""
echo ""
echo ">>>>>>>>>> All done! Please restart your pc to apply changes!"
