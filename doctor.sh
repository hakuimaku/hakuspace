#!/usr/bin/env bash

# Setup environment variables
HAKU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

print_header ">>> HAKUSPACE DOCTOR <<<"
step_title "Checking BASE Configs"

determine_deploy_mode --silent
if [[ "$HAKUSPACE_DEPLOY_MODE" == "copy" ]]; then
    log_info "Deployment mode is set to 'copy'. Skipping symlink integrity check."
    exit 0
fi

BROKEN_LINKS=()
OVERWRITTEN_FILES=()

# Recursive checking function
check_symlink_recursive() {
    local src="$1"
    local dst="$2"
    local current_issues=0

    if [[ -d "$src" ]]; then
        if [[ -e "$dst" && ! -d "$dst" ]]; then
            BROKEN_LINKS+=("Expected directory but found file at: $dst")
            current_issues=$((current_issues + 1))
        else
            local shopt_state
            shopt_state="$(shopt -p dotglob nullglob)"
            shopt -s dotglob nullglob
            local item
            for item in "$src"/*; do
                local sub_issues
                check_symlink_recursive "$item" "$dst/${item##*/}"
                sub_issues=$?
                current_issues=$((current_issues + sub_issues))
            done
            eval "$shopt_state"
        fi
    else
        if [[ -L "$dst" ]]; then
            local target
            target="$(readlink "$dst")"
            if [[ ! -e "$target" ]]; then
                BROKEN_LINKS+=("Broken symlink: $dst -> $target")
                current_issues=$((current_issues + 1))
            elif [[ "$target" != "$(realpath "$src")" ]]; then
                OVERWRITTEN_FILES+=("Modified symlink (not pointing to BASE): $dst")
                current_issues=$((current_issues + 1))
            fi
        elif [[ -e "$dst" ]]; then
            OVERWRITTEN_FILES+=("BASE config overwritten as real file: $dst")
            current_issues=$((current_issues + 1))
        else
            BROKEN_LINKS+=("Missing BASE config: $dst")
            current_issues=$((current_issues + 1))
        fi
    fi
    return $current_issues
}

check_module() {
    local src="$1"
    local dst="$2"
    local module_name="$3"
    
    check_symlink_recursive "$src" "$dst"
    local issues=$?
    
    if [[ $issues -eq 0 ]]; then
        log_ok "$module_name"
    else
        log_warn "$module_name (Found $issues issues)"
    fi
    return $issues
}

total_broken=0

# Check source configs
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

    check_module "$item" "$DEST_CONFIG/$item_name" "$DEST_CONFIG/$item_name"
    total_broken=$((total_broken + $?))
done

# Check hypr files individually or as part of directory
check_module "$SOURCE_CONFIG/hypr/hypridle.conf" "$DEST_CONFIG/hypr/hypridle.conf" "$DEST_CONFIG/hypr/hypridle.conf"
total_broken=$((total_broken + $?))
check_module "$SOURCE_CONFIG/hypr/hyprlock.conf" "$DEST_CONFIG/hypr/hyprlock.conf" "$DEST_CONFIG/hypr/hyprlock.conf"
total_broken=$((total_broken + $?))
check_module "$SOURCE_CONFIG/hypr/hyprlock_tiny.conf" "$DEST_CONFIG/hypr/hyprlock_tiny.conf" "$DEST_CONFIG/hypr/hyprlock_tiny.conf"
total_broken=$((total_broken + $?))

# Check Scripts (src/core)
scripts_issues=0
while IFS= read -r -d '' src_file; do
    file_name="$(basename "$src_file")"
    [[ "$file_name" == "README.md" ]] && continue
    check_symlink_recursive "$src_file" "$DEST_BIN/$file_name"
    scripts_issues=$((scripts_issues + $?))
done < <(find "$SOURCE_CORE" -type f -print0)

if [[ $scripts_issues -eq 0 ]]; then
    log_ok "Core Scripts ($DEST_BIN)"
else
    log_warn "Core Scripts ($DEST_BIN) - Found $scripts_issues issues"
fi
total_broken=$((total_broken + scripts_issues))


if [[ -d "$DEST_CONFIG/hypr" ]]; then
    check_module "$SOURCE_CONFIG/hypr/config" "$DEST_CONFIG/hypr/config" "$DEST_CONFIG/hypr/config"
    total_broken=$((total_broken + $?))
    check_module "$SOURCE_CONFIG/hypr/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua" "$DEST_CONFIG/hypr/hyprland.lua"
    total_broken=$((total_broken + $?))
fi
if [[ -d "$DEST_CONFIG/niri" ]]; then
    check_module "$SOURCE_CONFIG/niri" "$DEST_CONFIG/niri" "$DEST_CONFIG/niri"
    total_broken=$((total_broken + $?))
fi
if [[ -d "$DEST_CONFIG/mango" ]]; then
    check_module "$SOURCE_CONFIG/mango" "$DEST_CONFIG/mango" "$DEST_CONFIG/mango"
    total_broken=$((total_broken + $?))
fi
if [[ -d "$DEST_CONFIG/labwc" ]]; then
    check_module "$SOURCE_CONFIG/labwc" "$DEST_CONFIG/labwc" "$DEST_CONFIG/labwc"
    total_broken=$((total_broken + $?))
fi

check_module "$SOURCE_CONFIG/gtk-3.0/gtk.css" "$DEST_CONFIG/gtk-3.0/gtk.css" "$DEST_CONFIG/gtk-3.0/gtk.css"
total_broken=$((total_broken + $?))
check_module "$HOME_SRC_DIR/.nanorc" "$HOME/.nanorc" "$HOME/.nanorc"
total_broken=$((total_broken + $?))

# Print issues
if [[ ${#BROKEN_LINKS[@]} -gt 0 || ${#OVERWRITTEN_FILES[@]} -gt 0 ]]; then
    step_title "Issue Details"
    
    if [[ ${#BROKEN_LINKS[@]} -gt 0 ]]; then
        echo -e "${C_RED}Broken or Missing Symlinks:${C_RESET}"
        for issue in "${BROKEN_LINKS[@]}"; do
            echo "  - $issue"
        done
    fi
    
    if [[ ${#OVERWRITTEN_FILES[@]} -gt 0 ]]; then
        echo -e "${C_YELLOW}Overwritten Files (Should be Symlinks):${C_RESET}"
        for issue in "${OVERWRITTEN_FILES[@]}"; do
            echo "  - $issue"
        done
    fi

    echo ""
    print_divider
    log_error "Detected $total_broken issues with symlink integrity."
    echo -e "${C_BOLD}Please run '${C_GREEN}./update.sh${C_RESET}${C_BOLD}' to automatically restore and fix these symlinks.${C_RESET}"
    print_divider
else
    echo ""
    print_divider
    log_ok "All BASE configs are perfectly symlinked!"
    print_divider
fi

echo ""
step_title "Checking for Missing Directories"

# Check if local/state/hakuspace exists, if not, deploy it
check_state_dir

# Check ~/hakucfg directory
check_control_dir

echo ""
echo "Doctor check completed!"