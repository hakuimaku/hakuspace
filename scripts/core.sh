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

    # Ensure executable permissions on source shell and python scripts
    find "$SOURCE_CORE" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} +

    log_info "Deploying core scripts to $DEST_BIN (mode: $mode)..."

    if [[ "$mode" == "copy" ]]; then
        if [[ -d "$DEST_BIN" && "$skip_backup" -ne 1 ]]; then
            log_warn "Deployment mode is COPY. Backing up and refreshing $DEST_BIN..."
            backup_item "$DEST_BIN"
            rm -rf "$DEST_BIN"
        fi
    fi

    ensure_dir "$DEST_BIN" || return 1

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

        local dst="$DEST_BIN/$filename"
        if [[ "$mode" == "copy" ]]; then
            copy_file "$file" "$dst" "$skip_backup" || return 1
        else
            # Symlink mode
            if [[ -L "$dst" ]]; then
                if [[ "$(readlink "$dst")" == "$(realpath "$file")" ]]; then
                    continue
                fi
                rm -f "$dst"
            elif [[ -e "$dst" && "$skip_backup" -ne 1 ]]; then
                backup_item "$dst"
                rm -rf "$dst"
            fi
            ln -sfn "$(realpath "$file")" "$dst"
            log_symlink "$file => $dst"
        fi
    done < <(find "$SOURCE_CORE" -type f -print0)

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
