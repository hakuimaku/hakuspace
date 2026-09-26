#!/usr/bin/env bash
set -u

HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"

BACKUP_PREFIX="Backup_"
BACKUP_GLOB="$HOME/.backup/${BACKUP_PREFIX}"*

# Rollback only considers backups created by HakuSpace, not unrelated folders
# that may also exist under ~/.backup.
print_rollback_header() {
    print_header ">>> CONFIG ROLLBACK <<<" "Restore files from a previous HakuSpace backup."
}

get_backup_dirs() {
    local backup_dir
    for backup_dir in $BACKUP_GLOB; do
        [[ -d "$backup_dir" ]] || continue
        basename "$backup_dir"
    done | sort -r
}

select_backup_dir() {
    local backup_names=()
    local backup_name
    local choice

    while IFS= read -r backup_name; do
        [[ -n "$backup_name" ]] && backup_names+=("$backup_name")
    done < <(get_backup_dirs)

    if [[ "${#backup_names[@]}" -eq 0 ]]; then
        log_warn "No backup directories found in $HOME."
        exit 0
    fi

    if [[ "${#backup_names[@]}" -eq 1 ]]; then
        SELECTED_BACKUP="$HOME/.backup/${backup_names[0]}"
        log_info "Using the only available backup: ${backup_names[0]}"
        return 0
    fi

    echo "Available backups (newest first):"
    for i in "${!backup_names[@]}"; do
        printf "  [%d] %s\n" "$((i + 1))" "${backup_names[$i]}"
    done
    echo ""
    read -r -p ">>> Choose backup (default: 1, newest): " choice
    choice="${choice:-1}"

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#backup_names[@]} )); then
        log_error "Invalid backup choice."
        exit 1
    fi

    SELECTED_BACKUP="$HOME/.backup/${backup_names[$((choice - 1))]}"
}

# MANAGED_DESTINATIONS contains the home paths controlled by HakuSpace.
# Rollback moves existing entries from this list into Rollback_Backup_*
# before restoring the selected backup. Paths outside this list are preserved.
add_managed_destination() {
    MANAGED_DESTINATIONS+=("$1")
}

is_once_config() {
    local config_path
    local config_name

    config_path="$1"
    config_name="$(basename "$config_path")"

    for config_path in "${ONCE_CONFIGS[@]}"; do
        if [[ "$(basename "$config_path")" == "$config_name" ]]; then
            return 0
        fi
    done

    return 1
}

build_managed_destinations() {
    local source_item
    local item_name

    # Keep this list in sync with the paths managed by the installer. Items
    # outside this list are left untouched during rollback.
    while IFS= read -r -d '' source_item; do
        item_name="$(basename "$source_item")"

        case "$item_name" in
            hypr|niri|mango|labwc)
                continue
                ;;
            gtk-3.0)
                add_managed_destination "$DEST_CONFIG/gtk-3.0"
                ;;
            *)
                is_once_config "$source_item" && continue
                add_managed_destination "$DEST_CONFIG/$item_name"
                ;;
        esac
    done < <(find "$SOURCE_CONFIG" -mindepth 1 -maxdepth 1 -print0)

    add_managed_destination "$DEST_CONFIG/hypr/config"
    add_managed_destination "$DEST_CONFIG/hypr/hyprland.lua"
    add_managed_destination "$DEST_CONFIG/hypr/hypridle.conf"
    add_managed_destination "$DEST_CONFIG/hypr/hyprlock.conf"
    add_managed_destination "$DEST_CONFIG/hypr/hyprlock_tiny.conf"
    add_managed_destination "$DEST_CONFIG/niri"
    add_managed_destination "$DEST_CONFIG/mango"
    add_managed_destination "$DEST_CONFIG/labwc"
    while IFS= read -r -d '' source_item; do
        item_name="$(basename "$source_item")"
        [[ "$item_name" == "README.md" ]] && continue
        add_managed_destination "$DEST_BIN/$item_name"
    done < <(find "$SOURCE_CORE" -type f -print0)
    
    add_managed_destination "$HOME/.nanorc"
}

clear_managed_destinations() {
    local destination

    # Move current files into a rollback backup before restoring old files so
    # the rollback itself can be undone if the selected backup is unsuitable.
    for destination in "${MANAGED_DESTINATIONS[@]}"; do
        if [[ ! -e "$destination" && ! -L "$destination" ]]; then
            continue
        fi

        if [[ -d "$destination" && ! -L "$destination" ]]; then
            # Clean inner deep symlinks first to avoid garbage rollback backups
            while IFS= read -r -d '' link; do
                local target
                target="$(readlink "$link")"
                if [[ "$target" == *"/hakuspace/src/"* ]]; then
                    rm -f "$link"
                fi
            done < <(find "$destination" -type l -print0)
            
            # If the directory is now empty, just remove it
            rmdir "$destination" 2>/dev/null && continue
        elif [[ -L "$destination" ]]; then
            local target
            target="$(readlink "$destination")"
            if [[ "$target" == *"/hakuspace/src/"* ]]; then
                rm -f "$destination"
                continue
            fi
        fi

        if [[ -e "$destination" || -L "$destination" ]]; then
            backup_item "$destination"
        fi
    done
}

restore_item() {
    local source_item
    local relative_path
    local destination

    source_item="$1"
    relative_path="${source_item#$SELECTED_BACKUP/}"
    destination="$HOME/$relative_path"

    # Prevent symlink dereferencing by removing HakuSpace symlinks first
    if [[ -L "$destination" ]]; then
        local target
        target="$(readlink "$destination")"
        if [[ "$target" == *"/hakuspace/src/"* ]]; then
            rm -f "$destination"
        fi
    fi

    if [[ -L "$source_item" ]]; then
        ensure_dir "$(dirname "$destination")"
        ln -sfn "$(readlink "$source_item")" "$destination"
    elif [[ -d "$source_item" ]]; then
        ensure_dir "$destination"
        local prev_shopt
        prev_shopt="$(shopt -p dotglob nullglob)"
        shopt -s dotglob nullglob
        for item in "$source_item"/*; do
            restore_item "$item"
        done
        eval "$prev_shopt"
    else
        ensure_dir "$(dirname "$destination")"
        # Force remove if it's still a symlink to prevent cp dereferencing
        if [[ -L "$destination" ]]; then
            rm -f "$destination"
        fi
        cp -f "$source_item" "$destination"
    fi

    ((restored_count++))
}

restore_backup() {
    # This safety backup is created by backup_item while existing destinations
    # are cleared, and is intentionally kept separate from the source backup.
    local BACKUP_DIR="$HOME/.backup/Rollback_Backup_$(date +%Y-%m-%d_%H-%M-%S)"
    local source_item
    local child_item
    local relative_path
    local restored_count=0

    build_managed_destinations
    clear_managed_destinations

    while IFS= read -r -d '' source_item; do
        relative_path="${source_item#$SELECTED_BACKUP/}"

        # Config and local backups contain multiple managed entries. Restore
        # their children so unrelated files in those directories are not
        # copied back over the user's current state.
        if [[ "$relative_path" == ".config" || "$relative_path" == ".local" ]]; then
            while IFS= read -r -d '' child_item; do
                if [[ "$relative_path" == ".config" ]] && is_once_config "$child_item"; then
                    continue
                fi
                restore_item "$child_item"
            done < <(find "$source_item" -mindepth 1 -maxdepth 1 -print0)
        else
            if [[ "$relative_path" == .config/* ]] && is_once_config "$source_item"; then
                continue
            fi
            restore_item "$source_item"
        fi
    done < <(find "$SELECTED_BACKUP" -mindepth 1 -maxdepth 1 -print0)

    if [[ "$restored_count" -gt 0 && -d "$BACKUP_DIR" ]]; then
        log_backup "Current files saved to $BACKUP_DIR"
    fi
}

print_rollback_header
select_backup_dir

log_info "Selected backup: $SELECTED_BACKUP"
if ! ask_yes_no "===> Restore this backup now?"; then
    log_skip "Rollback cancelled."
    exit 0
fi

restore_backup

echo ""
print_divider
log_ok "Rollback completed. Reload your session if necessary."
print_divider
