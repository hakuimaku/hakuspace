#!/usr/bin/env bash
# HakuSpace Core Scripts Deployment Module
# Deploys src/core flatly into ~/.local/bin

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/filesystem.sh"
source "$HAKU_DIR/scripts/runtime.sh"

deploy_core() {
    local mode="${1:-symlink}"
    local skip_backup="${2:-0}"

    if [[ ! -d "$SOURCE_CORE" ]]; then
        log_warn "Source directory not found: $SOURCE_CORE"
        return 1
    fi

    [[ "$mode" == copy || "$mode" == symlink ]] || return 2
    log_info "Deploying core scripts to $DEST_BIN (mode: $mode)..."

    if [[ -L "$DEST_BIN" ]]; then
        log_error "Refusing to replace redirected bin directory: $DEST_BIN"
        return 1
    fi
    ensure_dir "$DEST_BIN" || return 1

    # Validate the entire catalog before replacing any destination.
    local -A seen_scripts=()
    while IFS= read -r -d '' file; do
        local filename
        filename="$(basename "$file")"
        [[ "$filename" == "README.md" ]] && continue

        if [[ -n "${seen_scripts[$filename]:-}" ]]; then
            log_error "Script name collision: '$filename' found in both '${seen_scripts[$filename]}' and '$file'"
            return 1
        fi
        seen_scripts["$filename"]="$file"

    done < <(registry_core_files)

    local file dst
    while IFS='|' read -r file dst; do
        chmod +x "$file"
        # Unchanged copies need neither replacement nor another backup.
        if [[ "$mode" == copy && -f "$dst" && -x "$dst" && ! -L "$dst" ]] && cmp -s "$file" "$dst"; then
            continue
        fi
        if [[ -e "$dst" || -L "$dst" ]]; then
            if [[ -L "$dst" && "$(readlink "$dst")" == "$(realpath "$file")" && "$mode" == symlink ]]; then
                continue
            fi
            # Preserve existing content at managed names before replacing it.
            backup_item "$dst" || return 1
        fi
        if [[ "$mode" == "copy" ]]; then
            copy_file "$file" "$dst" 1 || return 1
        else
            ln -s "$(realpath "$file")" "$dst" || return 1
            log_symlink "$file => $dst"
        fi
    done < <(registry_get_core_scripts)

    log_ok "Core scripts deployed successfully to $DEST_BIN"
}

# CLI Handling
MODE="${HAKUSPACE_DEPLOY_MODE:-symlink}"
SKIP_BACKUP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --skip-backup)
            SKIP_BACKUP=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--mode symlink|copy] [--skip-backup]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_core "$MODE" "$SKIP_BACKUP"
fi
