#!/usr/bin/env bash
# HakuSpace Safe Unlink Module
# Removes only symlinks belonging to registered HakuSpace targets.
# Never deletes real files, foreign links, app-generated state, or ONCE configs.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/registry.sh"

unlink_file_target() {
    local src="$1"
    local dst="$2"

    if [[ -L "$dst" ]]; then
        local target
        target="$(readlink "$dst")"
        local expected
        expected="$(realpath "$src" 2>/dev/null || echo "$src")"
        if [[ "$target" == "$expected" || "$target" == "$HAKU_DIR/src/"* ]]; then
            rm -f "$dst"
            log_ok "Removed symlink: $(shorten_path "$dst")"
            # Attempt to prune parent directory if empty
            local parent
            parent="$(dirname "$dst")"
            if [[ "$parent" != "$HOME" && "$parent" != "$DEST_CONFIG" && "$parent" != "$DEST_BIN" ]]; then
                rmdir "$parent" 2>/dev/null || true
            fi
        else
            log_skip "Skipping foreign symlink: $(shorten_path "$dst") -> $target"
        fi
    elif [[ -e "$dst" ]]; then
        log_skip "Preserving real file: $(shorten_path "$dst")"
    fi
}

unlink_recursive() {
    local src="$1"
    local dst="$2"

    if [[ -d "$src" ]]; then
        if [[ ! -d "$dst" ]]; then
            return 0
        fi
        (
            shopt -s dotglob nullglob
            for item in "$src"/*; do
                unlink_recursive "$item" "$dst/${item##*/}"
            done
        )
        # Attempt to prune directory if now empty
        if [[ "$dst" != "$HOME" && "$dst" != "$DEST_CONFIG" && "$dst" != "$DEST_BIN" ]]; then
            rmdir "$dst" 2>/dev/null || true
        fi
    else
        unlink_file_target "$src" "$dst"
    fi
}

unlink_core() {
    log_info "Unlinking core scripts from $DEST_BIN..."
    [[ -d "$SOURCE_CORE" ]] || return 0
    while IFS= read -r -d '' file; do
        local filename
        filename="$(basename "$file")"
        [[ "$filename" == "README.md" ]] && continue
        unlink_file_target "$file" "$DEST_BIN/$filename"
    done < <(find "$SOURCE_CORE" -type f -print0)
}

unlink_module() {
    local mod="${1:-}"

    if [[ "$mod" == "core" ]]; then
        unlink_core
        return 0
    fi

    local mappings
    mappings="$(registry_resolve_module "$mod")" || {
        log_error "Unknown module: '$mod'. Use --list to see available modules."
        return 1
    }

    log_info "Unlinking module: $mod"
    while IFS='|' read -r src dst; do
        [[ -z "$src" ]] && continue
        unlink_recursive "$src" "$dst"
    done <<< "$mappings"

    log_ok "Module '$mod' unlinked."
}

unlink_all() {
    log_info "Unlinking all registered base configs..."

    while IFS='|' read -r src dst; do
        [[ -z "$src" ]] && continue
        unlink_recursive "$src" "$dst"
    done < <(registry_get_common_configs)

    unlink_core
    log_ok "All registered base configs and core scripts unlinked."
}

# CLI Entrypoint
TARGETS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)
            registry_list_modules | sort -u
            exit 0
            ;;
        --all)
            TARGETS+=("--all")
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--all | --list | <module1> <module2>...]"
            echo "Options:"
            echo "  --all   Unlink all common base configs and core scripts"
            echo "  --list  List available modules"
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
        unlink_all
    else
        unlink_module "$target"
    fi
done
