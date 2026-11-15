#!/usr/bin/env bash

# Public compatibility facade for wallpaper selection.
# Classic presentation lives in wallpaper_rofi.sh; explicit actions are headless.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
WALLPAPER_CTL="$HAKU_BIN_DIR/wallpaper_ctl.sh"
WALLPAPER_ROFI="$HAKU_BIN_DIR/wallpaper_rofi.sh"

print_help() {
    cat <<'EOF_HELP'
Usage: wallpaper_select.sh [OPTION]
Select and manage wallpapers.

No arguments:
    Classic                     Open the Classic wallpaper menu
    Hikai                       Toggle the quick wallpaper overlay

Hikai presentation:
    --simple                    Toggle the quick wallpaper overlay
    --shell                     Toggle the wallpaper workspace

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
    --simple|--shell)
        if haku_backend_is "classic"; then exec "$WALLPAPER_ROFI"; fi
        if [[ "$1" == --shell ]]; then haku_qs_ipc wallpaper toggleWorkspaceDefault
        else haku_qs_ipc wallpaper toggleDefault
        fi
        ;;
    --static|--lively)
        if haku_backend_is "hikai"; then
            if [[ -n "${2:-}" ]]; then
                if [[ "$1" == --static ]]; then exec "$WALLPAPER_CTL" apply-static "$2"; fi
                exec "$WALLPAPER_CTL" apply-lively "$2"
            fi
            haku_qs_ipc wallpaper openDefault
            exit $?
        fi
        exec "$WALLPAPER_ROFI" "$@"
        ;;
    --extend|-e)
        exec "$WALLPAPER_ROFI" "$@"
        ;;
    --exit)
        if haku_backend_is "hikai"; then
            haku_qs_ipc wallpaper pause
            exit $?
        fi
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
        if haku_backend_is "hikai"; then haku_qs_ipc wallpaper status; exit $?; fi
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
