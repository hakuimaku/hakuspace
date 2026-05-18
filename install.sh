#!/bin/bash

# At block 4, 5 and 7, copy config, bin, .zshrc and .nanorc files will backup current config and bin if they exist.
# The backup will be created in the same location with a timestamp suffix (e.g., .config_backup_20240601_123456).
# This way, you can easily restore your previous configuration if needed.
echo ""
echo "================================================================================================"
echo "--- WELCOME TO HAKUSPACE CONFIG INSTALLER ---"
echo "This script will help you set up your HakuSpace configuration"
echo "It will install necessary packages, copying config files and setting up Oh My Zsh with plugins."
echo "Please follow the prompts to complete the installation process."
echo "================================================================================================"
echo ""


# Check package dependencies
# Install yay if not found
read -p "===> Do you want to install yay now)? (y/n): " confirm
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
PKG_FILE="$HOME/hakuspace/pkg.txt"

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
            echo "You need to install $pkg."
            exit 1
        fi
    fi
done

echo ""
echo ""
echo "================================================================================================"
echo "--- Everything is ready to install Config! ---"


# Install packages from pkg.txt
echo ""
echo "--- 2. Ready to install packages from pkg.txt ---"

echo ":: Ready to install packages..."
read -p "===> Do you want to install packages from pkg.txt now? (y/n): " confirm
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




echo ""
echo "--- 3. Ready to initialize system directories ---"

# List of directories to create
FOLDERS=(
    "$HOME/Documents"
    "$HOME/.local/bin"
    "$HOME/.config"
    "$HOME/.icons"
    "$HOME/.themes"
    "$HOME/Pictures"
    "$HOME/Pictures/Wallpapers"
    "$HOME/Pictures/Screenshots"
    "$HOME/Videos"
    "$HOME/Videos/Wallpapers"
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



# Define source and destination paths for config files
SOURCE_CONFIG="$HOME/hakuspace/config"
DEST_CONFIG="$HOME/.config"

echo ""
echo "--- 4. Ready to deploy config to ~/.config ---"

# Copy config files from source to destination
read -p "===> Do you want to backup and copy your current config now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    if [ -d "$SOURCE_CONFIG" ]; then
        echo ":: Ready to copy config files..."
        # Make backup if destination config already exists
        if [ -d "$DEST_CONFIG" ]; then
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            echo ":: Ready to create backup for current config..."
            mv "$DEST_CONFIG" "${DEST_CONFIG}_backup_$TIMESTAMP"
            mkdir -p "$DEST_CONFIG"
        fi

        # Proceed with copying config files
        cp -rf "$SOURCE_CONFIG"/. "$DEST_CONFIG/"
        
        echo ":: Copy (config files) completed to $DEST_CONFIG"
    else
        echo "XXX [ERROR] Not found directory $SOURCE_CONFIG"
        echo "Please copy it manually (config files) to $DEST_CONFIG"
    fi
else
    echo "Skipping config backup."
fi


# Define source and destination paths for local bin files
SOURCE_BIN="$HOME/hakuspace/bin"
DEST_BIN="$HOME/.local/bin"

echo ""
echo "--- 5. Ready to deploy bin files to ~/.local/bin ---"

read -p "===> Do you want to backup and copy your current local bin now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    # Copy bin files from source to destination
    if [ -d "$SOURCE_BIN" ]; then
        cp -rf "$SOURCE_BIN"/. "$DEST_BIN/"
        echo ":: Copy (bin files) completed to $DEST_BIN"
        chmod +x "$DEST_BIN"/* 2>/dev/null
    else
        echo "XXX [ERROR] Not found directory $SOURCE_BIN"
        echo "Please copy it manually (bin files) to $DEST_BIN"
    fi
else
    echo "Skipping local bin backup."
fi


# Install Oh My Zsh and plugins
echo ""
echo "--- 6. Setup Oh My Zsh and Plugins ---"

if ! command -v zsh &> /dev/null; then
    echo ":: Zsh is missing. Installing now..."
    yay -S --noconfirm zsh
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo ":: Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo ":: Oh My Zsh already installed."
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom/plugins"

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/zsh-autosuggestions"
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/zsh-syntax-highlighting"
fi

# Change default shell to Zsh (Need to enter sudo password)
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    echo "Changing default shell to Zsh..."
    sudo chsh -s /usr/bin/zsh $USER
fi



# Define source and destination paths for other files
DEST_OTHER="$HOME"
SOURCE_ROOT="$HOME/hakuspace"
DEST_WALLPAPER="$HOME/Pictures/Wallpapers"
SOURCE_WALLPAPER="$HOME/hakuspace/Wallpapers"


echo ""
echo "--- 7. Ready to deploy other files (like .nanorc and .zshrc) to home directory ---"

read -p "===> Do you want to backup and copy your other files now? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
    FILES_TO_COPY=(".nanorc" ".zshrc")

    for file in "${FILES_TO_COPY[@]}"; do
        if [ -f "$SOURCE_ROOT/$file" ]; then
            # Make backup if destination file already exists
            if [ -f "$DEST_OTHER/$file" ]; then
                mv "$DEST_OTHER/$file" "$DEST_OTHER/${file}.bak"
                echo ":: Did create backup for $file"
            fi
            
            # Copy file from source to destination
            cp -f "$SOURCE_ROOT/$file" "$DEST_OTHER/"
            echo ":: Did copy $file to $DEST_OTHER"
        else
            echo "!!! File not found: $file in $SOURCE_ROOT, skipping."
            echo "Please copy it manually ($file) to $DEST_OTHER"
        fi
    done
    cp -f "$SOURCE_ROOT/fastfetch.jpg" "$HOME/Documents/"
    echo ":: Did copy fastfetch.jpg to $HOME/Documents/"
    cp -rf "$SOURCE_WALLPAPER"/. "$DEST_WALLPAPER/"
    echo ":: Did copy wallpapers to $DEST_WALLPAPER"
else
    echo "Skipping other files backup."
fi


# Define source and destination paths for icons
SOURCE_ICON="$HOME/hakuspace/icons"
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



# Define source and destination paths for themes
SOURCE_THEME="$HOME/hakuspace/themes"
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


# Enable service
echo ""
echo "--- 10. Enabling system services ---"

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl --user enable --now hypridle.service
sudo systemctl enable ly@tty1.service
sudo systemctl disable getty@tty1.service

echo "--- Configuring Nemo as default file manager ---"
xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search

SERVICES_EXTRA=("gvfsd")
for srv in "${SERVICES_EXTRA[@]}"; do
    if systemctl --user list-unit-files | grep -q "$srv"; then
        systemctl --user enable --now "$srv"
    fi
done

echo "✅ All services have been processed!"

# Final message
echo ""
echo ""
echo ">>>>>>>>>> All done! Please restart your pc to apply changes!"
