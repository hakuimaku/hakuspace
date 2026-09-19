#!/usr/bin/env bash

# Setup environment variables
HAKU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

echo -e "${C_BOLD}--- HakuSpace Doctor ---${C_RESET}"



echo ""
echo -e "${C_BOLD}--- Checking BASE Configs in ~/.config ---${C_RESET}"

determine_deploy_mode
if [[ "$HAKUSPACE_DEPLOY_MODE" == "copy" ]]; then
    log_info "Deployment mode is set to 'copy'. Skipping symlink integrity check."
else

broken_symlinks=0
overwritten_files=0

check_symlink_recursive() {
    local src="$1"
    local dst="$2"

    if [[ -d "$src" ]]; then
        if [[ -e "$dst" && ! -d "$dst" ]]; then
            log_warn "Expected directory but found file at: $dst"
            broken_symlinks=$((broken_symlinks + 1))
        else
            local shopt_state
            shopt_state="$(shopt -p dotglob nullglob)"
            shopt -s dotglob nullglob
            local item
            for item in "$src"/*; do
                check_symlink_recursive "$item" "$dst/${item##*/}"
            done
            eval "$shopt_state"
        fi
    else
        if [[ -L "$dst" ]]; then
            local target
            target="$(readlink "$dst")"
            if [[ ! -e "$target" ]]; then
                log_warn "Broken symlink: $dst -> $target"
                broken_symlinks=$((broken_symlinks + 1))
            elif [[ "$target" != "$(realpath "$src")" ]]; then
                log_warn "Modified symlink (not pointing to BASE): $dst"
                overwritten_files=$((overwritten_files + 1))
            fi
        elif [[ -e "$dst" ]]; then
            log_warn "BASE config overwritten as real file: $dst"
            overwritten_files=$((overwritten_files + 1))
        else
            log_warn "Missing BASE config: $dst"
            broken_symlinks=$((broken_symlinks + 1))
        fi
    fi
}

for item in "$SOURCE_CONFIG"/*; do
    [[ -e "$item" ]] || continue
    item_name="${item##*/}"
    
    is_skipped=0
    for once in "${ONCE_CONFIGS[@]}"; do
        [[ "$once" == "$item" ]] && { is_skipped=1; break; }
    done
    for skip in "${SKIP_CONFIGS[@]}"; do
        [[ "$skip" == "$item" ]] && { is_skipped=1; break; }
    done
    [[ $is_skipped -eq 1 ]] && continue

    check_symlink_recursive "$item" "$DEST_CONFIG/$item_name"
done

check_symlink_recursive "$SOURCE_CONFIG/hypr/hypridle.conf" "$DEST_CONFIG/hypr/hypridle.conf"
check_symlink_recursive "$SOURCE_CONFIG/hypr/hyprlock.conf" "$DEST_CONFIG/hypr/hyprlock.conf"
check_symlink_recursive "$SOURCE_CONFIG/hypr/hyprlock_tiny.conf" "$DEST_CONFIG/hypr/hyprlock_tiny.conf"

while IFS= read -r -d '' src_file; do
    file_name="$(basename "$src_file")"
    [[ "$file_name" == "README.md" ]] && continue
    check_symlink_recursive "$src_file" "$DEST_BIN/$file_name"
done < <(find "$SOURCE_CORE" -type f -print0)

if [[ -d "$DEST_CONFIG/hypr" ]]; then
    check_symlink_recursive "$SOURCE_CONFIG/hypr/config" "$DEST_CONFIG/hypr/config"
    check_symlink_recursive "$SOURCE_CONFIG/hypr/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua"
fi
if [[ -d "$DEST_CONFIG/niri" ]]; then
    check_symlink_recursive "$SOURCE_CONFIG/niri" "$DEST_CONFIG/niri"
fi
if [[ -d "$DEST_CONFIG/mango" ]]; then
    check_symlink_recursive "$SOURCE_CONFIG/mango" "$DEST_CONFIG/mango"
fi
if [[ -d "$DEST_CONFIG/labwc" ]]; then
    check_symlink_recursive "$SOURCE_CONFIG/labwc" "$DEST_CONFIG/labwc"
fi

check_symlink_recursive "$SOURCE_CONFIG/gtk-3.0/gtk.css" "$DEST_CONFIG/gtk-3.0/gtk.css"
check_symlink_recursive "$SOURCE_CONFIG/starship.toml" "$DEST_CONFIG/starship.toml"
check_symlink_recursive "$HOME_SRC_DIR/.nanorc" "$HOME/.nanorc"

if [[ "$broken_symlinks" -eq 0 && "$overwritten_files" -eq 0 ]]; then
    log_ok "All BASE configs are correctly symlinked."
else
    echo ""
    log_warn "Found $broken_symlinks missing/broken symlinks and $overwritten_files overwritten files."
    log_error "Detected BASE config file overwritten as a real file."
    log_error "Please move your customizations to 'hakucfg' and run 'update.sh' to restore symlinks."
fi
fi
