#!/usr/bin/env bash
set -u

HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$HAKU_DIR/scripts/functions.sh"

BACKUP_PREFIX="Backup_"
BACKUP_GLOB="$HOME/${BACKUP_PREFIX}"*

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
        SELECTED_BACKUP="$HOME/${backup_names[0]}"
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

    SELECTED_BACKUP="$HOME/${backup_names[$((choice - 1))]}"
}

backup_current_state() {
    local source_item
    local relative_path
    local destination
    local safety_path

    ROLLBACK_BACKUP_DIR="$HOME/Rollback_Backup_$(date +%Y-%m-%d_%H-%M-%S)"
    mkdir -p "$ROLLBACK_BACKUP_DIR"

    while IFS= read -r -d '' source_item; do
        relative_path="${source_item#$SELECTED_BACKUP/}"
        destination="$HOME/$relative_path"
        [[ -e "$destination" || -L "$destination" ]] || continue

        safety_path="$ROLLBACK_BACKUP_DIR/$relative_path"
        mkdir -p "$(dirname "$safety_path")"
        cp -a "$destination" "$safety_path"
    done < <(find "$SELECTED_BACKUP" -mindepth 1 -maxdepth 1 -print0)

    log_ok "Current state saved to $ROLLBACK_BACKUP_DIR"
}

restore_backup() {
    local source_item
    local relative_path
    local destination

    while IFS= read -r -d '' source_item; do
        relative_path="${source_item#$SELECTED_BACKUP/}"
        destination="$HOME/$relative_path"

        if [[ -d "$source_item" && ! -L "$source_item" ]]; then
            mkdir -p "$destination"
            cp -a "$source_item"/. "$destination"/
        else
            mkdir -p "$(dirname "$destination")"
            rm -rf "$destination"
            cp -a "$source_item" "$destination"
        fi

        log_copy "$source_item -> $destination"
    done < <(find "$SELECTED_BACKUP" -mindepth 1 -maxdepth 1 -print0)
}

print_rollback_header
select_backup_dir

log_info "Selected backup: $SELECTED_BACKUP"
if ! ask_yes_no "===> Restore this backup now?"; then
    log_skip "Rollback cancelled."
    exit 0
fi

backup_current_state
restore_backup

log_ok "Rollback completed. Reload your session or restart affected applications if necessary."
log_info "Safety backup: $ROLLBACK_BACKUP_DIR"
