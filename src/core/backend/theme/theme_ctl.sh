#!/usr/bin/env bash

# Headless theme mutation/controller API.
# Owns canonical theme state mutation and render/apply orchestration only.
# UI/picker code belongs in frontend/classic/theme_rofi.sh or other frontends.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source_core_lib() {
    local name="$1"
    local candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/../../lib/$name" \
        "$HOME/.local/bin/$name"; do
        if [[ -f "$candidate" ]]; then
            # shellcheck source=/dev/null
            source "$candidate"
            return 0
        fi
    done
    printf 'theme_ctl.sh: required library not found: %s\n' "$name" >&2
    return 1
}

resolve_script() {
    local name="$1" source_path="$2" override="${3:-}"
    local candidate

    if [[ -n "$override" ]]; then
        if [[ -x "$override" || -f "$override" ]]; then
            printf '%s\n' "$override"
            return 0
        fi
        printf 'theme_ctl.sh: override script not found: %s\n' "$override" >&2
        return 1
    fi

    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'theme_ctl.sh: required script not found: %s\n' "$name" >&2
    return 1
}

source_core_lib haku_theme.sh || exit 1
source_core_lib accent_color.sh || exit 1

GEN_STYLE="$(resolve_script gen_style.sh ../../theme/gen_style.sh "${HAKUSPACE_GEN_STYLE:-}")" || exit 1
APPLY_STYLE="$(resolve_script apply_style.sh ../../theme/apply_style.sh "${HAKUSPACE_APPLY_STYLE:-}")" || exit 1

render_apply() {
    "$GEN_STYLE" || return $?
    "$APPLY_STYLE"
}

validate_accent() {
    local requested="${1:-}"
    if [[ ! "$requested" =~ ^#[0-9a-fA-F]{6}$ ]]; then
        printf 'theme_ctl.sh: accent must be #RRGGBB.\n' >&2
        return 2
    fi
    accent_color_or_fallback "$requested"
}

validate_font() {
    local requested="${1:-}"
    if [[ -z "$requested" ]]; then
        printf 'theme_ctl.sh: font name must not be empty.\n' >&2
        return 2
    fi
    printf '%s\n' "$requested"
}

validate_size() {
    local requested="${1:-}"
    if [[ ! "$requested" =~ ^[0-9]+$ ]] || (( requested <= 0 )); then
        printf 'theme_ctl.sh: font size must be a positive integer.\n' >&2
        return 2
    fi
    printf '%s\n' "$requested"
}

save_and_apply() {
    theme_save_state || return 1
    render_apply
}

set_accent() {
    local validated
    validated="$(validate_accent "${1:-}")" || return $?
    ACCENT_COLOR="$validated"
    save_and_apply
}

set_font() {
    local validated
    validated="$(validate_font "${1:-}")" || return $?
    FONT_FAMILY="$validated"
    save_and_apply
}

set_size() {
    local validated
    validated="$(validate_size "${1:-}")" || return $?
    FONT_SIZE="$validated"
    save_and_apply
}

print_status() {
    printf 'accent=%s\n' "$ACCENT_COLOR"
    printf 'font=%s\n' "$FONT_FAMILY"
    printf 'size=%s\n' "$FONT_SIZE"
}

print_help() {
    cat <<'EOF_HELP'
Usage: theme_ctl.sh COMMAND [ARG]
Headless HakuSpace theme control API.

Commands:
    status                  Print accent/font/size as key=value lines
    get accent|font|size    Print one canonical theme value
    list-fonts              Print installed font families, one per line
    set-accent HEX          Persist HEX (#RRGGBB), render, and live-apply
    set-font NAME           Persist font family, render, and live-apply
    set-size PX             Persist positive integer size, render, and live-apply
    apply                   Re-render and live-apply current canonical state
    -h, --help              Show this help message
EOF_HELP
}

case "${1:-}" in
    status|--status)
        print_status
        ;;
    get|--get)
        case "${2:-}" in
            accent) theme_state_value accent ;;
            font) theme_state_value font ;;
            size) theme_state_value size ;;
            *)
                printf 'theme_ctl.sh: get requires accent, font, or size.\n' >&2
                exit 2
                ;;
        esac
        ;;
    list-fonts|--list-fonts)
        if command -v fc-list >/dev/null 2>&1; then
            fc-list : family 2>/dev/null | sed 's/,.*//' | sort -u
        fi
        ;;
    set-accent|--set-accent)
        set_accent "${2:-}"
        ;;
    set-font|--set-font)
        set_font "${2:-}"
        ;;
    set-size|--set-size)
        set_size "${2:-}"
        ;;
    apply|--apply)
        render_apply
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
