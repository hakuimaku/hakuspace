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
    echo ""
    echo -e "${C_BOLD}${C_CYAN}--- HAKUSPACE ROLLBACK ---${C_RESET}"
    echo "Restore files from a previous HakuSpace installer or updater backup."
    echo ""
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
    add_managed_destination "$DEST_BIN"
    add_managed_destination "$HOME/.nanorc"
}

clear_managed_destinations() {
    local destination

    # Move current files into a rollback backup before restoring old files so
    # the rollback itself can be undone if the selected backup is unsuitable.
    for destination in "${MANAGED_DESTINATIONS[@]}"; do
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

    if [[ -d "$source_item" && ! -L "$source_item" ]]; then
        copy_dir_content "$source_item" "$destination" 1
    else
        copy_file "$source_item" "$destination" 1
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

log_ok "Rollback completed. Reload your session or restart affected applications if necessary."
