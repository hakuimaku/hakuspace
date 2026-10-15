#!/usr/bin/env bash
# HakuSpace Filesystem Primitives
# Policy-neutral directory and file operations with backup support.

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

# Ensure runtime context (BACKUP_DIR) is available
source "$HAKU_DIR/scripts/runtime.sh"

# Fallback logger helpers if functions.sh not yet sourced
if ! declare -F log_ok >/dev/null 2>&1; then
    log_ok()     { echo "[OK]     $1"; }
    log_warn()   { echo "[WARN]   $1"; }
    log_backup() { echo "[BACKUP] $1"; }
    log_copy()   { echo "[COPY]   $1"; }
fi

ensure_dir() {
    local dir="${1:-}"
    [[ -z "$dir" ]] && return 0
    if [[ -L "$dir" ]]; then rm -f "$dir"; fi
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || return 1
        log_ok "Created directory: $dir"
    fi
}

backup_item() {
    local target="${1:-}"
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
    local dir="${1:-}"
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
    local src="${1:-}"
    local dst="${2:-}"
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
    local src="${1:-}"
    local dst="${2:-}"
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
