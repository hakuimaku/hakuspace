#!/usr/bin/env bash

# Classic wallpaper frontend. Owns menu geometry and script-mode presentation;
# discovery and mutations are delegated to the headless controller.

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_state.sh" || exit 1
ROFI_THEME="wallpaper-select.rasi"
WALLPAPER_CTL="$HAKU_BIN_DIR/wallpaper_ctl.sh"

emit_records() {
    local command="$1"
    "$WALLPAPER_CTL" "$command" --json | python3 -c '
import json, sys
for item in json.load(sys.stdin):
    label = item["label"]
    icon = item["thumbnail"]
    sys.stdout.buffer.write(label.encode("utf-8") + b"\0icon\x1f" + icon.encode("utf-8") + b"\n")
'
}

script_mode() {
    local kind="$1"
    local choice="${2:-}"
    local list_command apply_command
    case "$kind" in
        static)
            list_command=list-static
            apply_command=apply-static
            ;;
        lively)
            list_command=list-lively
            apply_command=apply-lively
            ;;
        *)
            printf 'wallpaper_rofi.sh: unknown script mode: %s\n' "$kind" >&2
            return 2
            ;;
    esac

    if [[ -n "$choice" ]]; then
        ( "$WALLPAPER_CTL" "$apply_command" "$choice" ) >/dev/null 2>&1 &
        return 0
    fi
    emit_records "$list_command"
}

open_menu() {
    local -a extend=()
    if [[ "${1:-}" == "--extend" || "${1:-}" == "-e" ]]; then
        shift
        extend=("$@")
    fi

    rofi -show "Wallpaper" \
        -p "Wallpaper" \
        -i \
        "${extend[@]}" \
        -theme "$ROFI_THEME" \
        -modes "Wallpaper:$0 --static,Lively Wallpaper:$0 --lively"
}

print_help() {
    cat <<'EOF_HELP'
Usage: wallpaper_rofi.sh [OPTION]
Classic wallpaper menu and script-mode frontend.

Options:
    --static [CHOICE]       Static wallpaper script mode
    --lively [CHOICE]       Video wallpaper script mode
    -e, --extend ...        Pass placement arguments to the menu
    -h, --help              Show this help message
EOF_HELP
}

case "${1:-}" in
    --static)
        script_mode static "${2:-}"
        ;;
    --lively)
        script_mode lively "${2:-}"
        ;;
    --extend|-e)
        open_menu "$@"
        ;;
    -h|--help)
        print_help
        ;;
    '')
        open_menu
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
