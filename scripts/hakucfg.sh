#!/usr/bin/env bash
# HakuSpace Custom Configuration Module (hakucfg)
# Manages ~/hakucfg templates, subdirectories, and versioning.

set -e

if [[ -z "${HAKU_DIR:-}" ]]; then
    HAKU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

source "$HAKU_DIR/scripts/variables.sh"
source "$HAKU_DIR/scripts/functions.sh"
source "$HAKU_DIR/scripts/filesystem.sh"
source "$HAKU_DIR/scripts/registry.sh"

hakucfg_check() {
    local issues=0

    if [[ ! -d "$DEST_CUSTOM_DIR" ]]; then
        log_warn "hakucfg directory not found at $(shorten_path "$DEST_CUSTOM_DIR")"
        return 1
    fi

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ ! -f "$DEST_CUSTOM_DIR/$file" ]]; then
            log_warn "Missing hakucfg file: $(shorten_path "$DEST_CUSTOM_DIR/$file")"
            issues=$((issues + 1))
        fi
    done < <(registry_get_hakucfg_files)

    # Check version of setting.sh
    if [[ -f "$DEST_CUSTOM_DIR/setting.sh" && -f "$HAKUSPACE_CUSTOM_DIR/setting.sh" ]]; then
        local current_version
        local source_version
        chmod +x "$HAKUSPACE_CUSTOM_DIR/setting.sh" "$DEST_CUSTOM_DIR/setting.sh" 2>/dev/null || true
        source_version=$("$HAKUSPACE_CUSTOM_DIR/setting.sh" --version 2>/dev/null || echo "unknown")
        current_version=$("$DEST_CUSTOM_DIR/setting.sh" --version 2>/dev/null || echo "unknown")

        if [[ "$current_version" != "$source_version" ]]; then
            log_warn "hakucfg setting.sh version mismatch: $current_version (installed) vs $source_version (source)"
            issues=$((issues + 1))
        else
            log_ok "hakucfg setting.sh is up to date ($current_version)."
        fi
    fi

    if [[ $issues -eq 0 ]]; then
        log_ok "hakucfg is healthy."
        return 0
    else
        return 1
    fi
}

hakucfg_sync() {
    local non_interactive="${1:-0}"

    log_info "Synchronizing ~/hakucfg templates..."
    ensure_dir "$DEST_CUSTOM_DIR"
    ensure_dir "$DEST_CUSTOM_DIR/wm"
    ensure_dir "$DEST_CUSTOM_DIR/config"
    ensure_dir "$DEST_CUSTOM_DIR/config/waybar"
    ensure_dir "$DEST_CUSTOM_DIR/config/rofi"

    # Move legacy shell settings without overwriting an existing Hikai document.
    if [[ -L "$DEST_CUSTOM_DIR/hikai" ]]; then
        log_error "Cannot migrate Hikai configuration into a symlinked directory."
        return 1
    fi
    ensure_dir "$DEST_CUSTOM_DIR/hikai"
    local legacy="$DEST_CUSTOM_DIR/hikai-shell.json"
    local destination="$DEST_CUSTOM_DIR/hikai/hikai-shell.json"
    if [[ -L "$destination" || ( -e "$destination" && ! -f "$destination" ) ]]; then
        log_error "Cannot use non-regular Hikai configuration: $(shorten_path "$destination")"
        return 1
    fi
    if [[ -e "$legacy" || -L "$legacy" ]]; then
        if [[ -e "$destination" || -L "$destination" ]]; then
            log_warn "Keeping existing $(shorten_path "$destination"); legacy file retained at $(shorten_path "$legacy")."
        elif [[ -L "$legacy" || ! -f "$legacy" ]]; then
            log_error "Cannot migrate non-regular Hikai configuration: $(shorten_path "$legacy")"
            return 1
        else
            mv -n -- "$legacy" "$destination"
            log_info "Moved Hikai configuration to $(shorten_path "$destination")."
        fi
    fi

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local target="$DEST_CUSTOM_DIR/$file"
        local source_file="$HAKUSPACE_CUSTOM_DIR/$file"

        if [[ ! -f "$target" ]]; then
            if [[ -f "$source_file" ]]; then
                log_info "Creating default $(shorten_path "$target")..."
                copy_file "$source_file" "$target" 1
            fi
        fi
    done < <(registry_get_hakucfg_files)

    [[ -f "$DEST_CUSTOM_DIR/setting.sh" ]] && chmod +x "$DEST_CUSTOM_DIR/setting.sh"
    [[ -f "$DEST_CUSTOM_DIR/general-menu.sh" ]] && chmod +x "$DEST_CUSTOM_DIR/general-menu.sh"

    # Version check and upgrade prompt
    if [[ -f "$DEST_CUSTOM_DIR/setting.sh" && -f "$HAKUSPACE_CUSTOM_DIR/setting.sh" ]]; then
        chmod +x "$HAKUSPACE_CUSTOM_DIR/setting.sh"
        local source_version
        local current_version
        source_version=$("$HAKUSPACE_CUSTOM_DIR/setting.sh" --version 2>/dev/null || echo "1.0")
        current_version=$("$DEST_CUSTOM_DIR/setting.sh" --version 2>/dev/null || echo "0.0")

        if [[ "$current_version" != "$source_version" ]]; then
            log_warn "Hakuspace custom settings version mismatch: $current_version (current) vs $source_version (expected)."
            local do_update=0
            if [[ "$non_interactive" -eq 1 ]]; then
                do_update=1
            elif ask_yes_no "===> Do you want to update hakucfg setting.sh to latest ($source_version)?"; then
                do_update=1
            fi

            if [[ "$do_update" -eq 1 ]]; then
                copy_file "$HAKUSPACE_CUSTOM_DIR/setting.sh" "$DEST_CUSTOM_DIR/setting.sh" 0
                log_ok "hakucfg updated to version $source_version."
            else
                log_warn "Skipped updating setting.sh."
            fi
        else
            log_ok "Hakuspace Control version is up-to-date: $current_version"
        fi
    fi
}

# CLI Entrypoint
COMMAND="${1:-sync}"
NON_INTERACTIVE=0

case "$COMMAND" in
    sync)
        shift || true
        [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && NON_INTERACTIVE=1
        hakucfg_sync "$NON_INTERACTIVE"
        ;;
    check)
        hakucfg_check
        ;;
    --help|-h)
        echo "Usage: $0 [sync [--yes] | check]"
        exit 0
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        exit 1
        ;;
esac
