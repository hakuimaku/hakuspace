#!/usr/bin/env bash

# Public compatibility facade for wallpaper selection.
# Classic presentation lives in wallpaper_rofi.sh; explicit actions are headless.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

resolve_script() {
    local name="$1" source_path="$2"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'wallpaper_select.sh: required script not found: %s\n' "$name" >&2
    return 1
}

WALLPAPER_CTL="$(resolve_script wallpaper_ctl.sh ../backend/theme/wallpaper_ctl.sh)" || exit 1
WALLPAPER_ROFI="$(resolve_script wallpaper_rofi.sh ../frontend/classic/wallpaper_rofi.sh)" || exit 1
HAKU_BACKEND_LIB="$(resolve_script haku_backend_lib.sh ../lib/haku_backend_lib.sh)" || exit 1

# shellcheck source=/dev/null
source "$HAKU_BACKEND_LIB"

print_help() {
    cat <<'EOF_HELP'
Usage: wallpaper_select.sh [OPTION]
Select and manage wallpapers.

No arguments:
    Classic                     Open the Classic wallpaper menu
    Hikai                       Toggle the native centered wallpaper layer

Classic compatibility:
    --static [CHOICE]           Static wallpaper script mode
    --lively [CHOICE]           Video wallpaper script mode
    --exit                      Stop the running video wallpaper
    -e, --extend ...            Set position of the Classic menu

Headless API:
    --list-static [--json]      List static wallpapers
    --list-lively [--json]      List video wallpapers
    --apply-static ID_OR_PATH   Apply an explicit static wallpaper
    --apply-lively ID_OR_PATH   Apply an explicit video wallpaper
    --current [--json]          Print current wallpaper
    --status [--json]           Print wallpaper subsystem state
    --ensure-thumbnails         Generate missing video previews
    -h, --help                  Show this help message
EOF_HELP
}

case "${1:-}" in
    '')
        if haku_backend_is "classic"; then
            exec "$WALLPAPER_ROFI"
        fi
        haku_qs_ipc wallpaper toggleDefault
        ;;
    --static|--lively)
        exec "$WALLPAPER_ROFI" "$@"
        ;;
    --extend|-e)
        exec "$WALLPAPER_ROFI" "$@"
        ;;
    --exit)
        "$WALLPAPER_CTL" stop-lively
        rc=$?
        if [[ $rc -ne 0 ]]; then
            if [[ $rc -eq 3 ]] && command -v notify-send >/dev/null 2>&1; then
                notify-send "Lively Wallpaper is not running"
            fi
            exit "$rc"
        fi
        ;;
    --list-static)
        exec "$WALLPAPER_CTL" list-static "${2:-}"
        ;;
    --list-lively)
        exec "$WALLPAPER_CTL" list-lively "${2:-}"
        ;;
    --apply-static)
        exec "$WALLPAPER_CTL" apply-static "${2:-}"
        ;;
    --apply-lively)
        exec "$WALLPAPER_CTL" apply-lively "${2:-}"
        ;;
    --current)
        exec "$WALLPAPER_CTL" current "${2:-}"
        ;;
    --status)
        exec "$WALLPAPER_CTL" status "${2:-}"
        ;;
    --ensure-thumbnails)
        exec "$WALLPAPER_CTL" ensure-thumbnails
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
