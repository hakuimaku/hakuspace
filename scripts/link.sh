#!/usr/bin/env bash
# HakuSpace Deep Symlink Deployment Module
# Deploys configurations using Deep Symlink semantics.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/filesystem.sh"
source "$HAKU_DIR/scripts/runtime.sh"
source "$HAKU_DIR/scripts/registry.sh"

deploy_symlink_recursive() {
    local src="${1:-}" dst="${2:-}" skip_backup="${3:-0}"
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

    # Destination parent directory must exist
    ensure_dir "$(dirname "$dst")"

    if [[ -L "$dst" ]]; then
        if [[ "$(readlink "$dst")" == "$(realpath "$src")" ]]; then
            return 0
        fi
        rm -f "$dst"
    elif [[ -e "$dst" && "$skip_backup" -ne 1 ]]; then
        backup_item "$dst"
        rm -rf "$dst"
    elif [[ -e "$dst" ]]; then
        rm -rf "$dst"
    fi

    ln -sfn "$(realpath "$src")" "$dst" || return 1
    log_symlink "$src => $dst"
}

link_module() {
    local mod="${1:-}"
    local skip_backup="${2:-0}"

    if [[ "$mod" == "core" ]]; then
        "$HAKU_DIR/scripts/core.sh" --mode symlink $([[ "$skip_backup" -eq 1 ]] && echo "--skip-backup")
        return $?
    fi

    local mappings
    mappings="$(registry_resolve_module "$mod")" || {
        log_error "Unknown module: '$mod'. Use --list to see available modules."
        return 1
    }

    log_info "Linking module: $mod"
    while IFS='|' read -r src dst; do
        [[ -z "$src" ]] && continue
        deploy_symlink_recursive "$src" "$dst" "$skip_backup" || return 1
    done <<< "$mappings"

    log_ok "Module '$mod' linked successfully."
}

link_all() {
    local skip_backup="${1:-0}"
    log_info "Linking all registered base configs..."

    while IFS='|' read -r src dst; do
        [[ -z "$src" ]] && continue
        deploy_symlink_recursive "$src" "$dst" "$skip_backup" || return 1
    done < <(registry_get_common_configs)

    # Link core scripts
    "$HAKU_DIR/scripts/core.sh" --mode symlink $([[ "$skip_backup" -eq 1 ]] && echo "--skip-backup")

    log_ok "All base configs and core scripts linked successfully."
}

# CLI Entrypoint
SKIP_BACKUP=0
TARGETS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)
            registry_list_modules | sort -u
            exit 0
            ;;
        --skip-backup)
            SKIP_BACKUP=1
            shift
            ;;
        --all)
            TARGETS+=("--all")
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--all | --list | <module1> <module2>...]"
            echo "Options:"
            echo "  --all          Link all common base configs and core scripts"
            echo "  --list         List available modules"
            echo "  --skip-backup  Do not create backups of overwritten files"
            exit 0
            ;;
        *)
            TARGETS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "Usage: $0 [--all | --list | <module1> <module2>...]" >&2
    exit 1
fi

for target in "${TARGETS[@]}"; do
    if [[ "$target" == "--all" ]]; then
        link_all "$SKIP_BACKUP"
    else
        link_module "$target" "$SKIP_BACKUP"
    fi
done
