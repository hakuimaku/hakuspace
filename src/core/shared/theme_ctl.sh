#!/usr/bin/env bash

# Headless theme mutation/controller API.
# Owns canonical theme state mutation and render/apply orchestration only.
# UI/picker code belongs in frontend/classic/theme_rofi.sh or other frontends.

source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_theme.sh" || exit 1
source "$HAKU_BIN_DIR/accent_color.sh" || exit 1

GEN_STYLE="${HAKUSPACE_GEN_STYLE:-$HAKU_BIN_DIR/gen_style.sh}"
APPLY_STYLE="${HAKUSPACE_APPLY_STYLE:-$HAKU_BIN_DIR/apply_style.sh}"

render_apply() {
    "$GEN_STYLE" || return $?
    "$APPLY_STYLE"
}

sync_icon_accent() {
    if [[ -x "$HAKU_BIN_DIR/appearance_ctl.sh" || -f "$HAKU_BIN_DIR/appearance_ctl.sh" ]] && "$HAKU_BIN_DIR/appearance_ctl.sh" sync-accent; then
        return 0
    fi
    printf 'theme_ctl.sh: warning: icon accent sync unavailable; core theme preserved.\n' >&2
    [[ "${HAKUSPACE_STRICT_ASSETS:-0}" != 1 ]]
}

apply_and_reconcile() {
    "$GEN_STYLE" || return $?
    # Preserve sync errors while still applying the core theme after icon updates.
    local icon_status=0
    sync_icon_accent || icon_status=$?
    "$APPLY_STYLE" || return $?
    return "$icon_status"
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

classic_palette_available() {
    [[ -f "$HAKU_BIN_DIR/classic_palette.py" ]]
}

classic_palette_sync() {
    classic_palette_available || return 0
    local req_file eff_file requested previous effective tmp
    req_file="$(haku_state_path theme.classic.palette)" || return 1
    eff_file="$(haku_state_path theme.classic.palette.effective)" || return 1
    requested="$(cat "$req_file" 2>/dev/null || printf 'auto')"
    previous="$(cat "$eff_file" 2>/dev/null || printf '')"
    effective="$(python3 "$HAKU_BIN_DIR/classic_palette.py" resolve \
        --seed "$ACCENT_SEED" --requested "$requested" --previous "$previous")" || return 1
    tmp="$(mktemp "${eff_file}.XXXXXX")" || return 1
    if printf '%s\n' "$effective" > "$tmp" && mv "$tmp" "$eff_file"; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}

set_palette() {
    local requested="${1:-}"
    case "$requested" in
        auto|red|orange|yellow|green|blue|indigo|violet|gray) ;;
        *)
            printf 'theme_ctl.sh: palette must be auto or one of red, orange, yellow, green, blue, indigo, violet, gray.\n' >&2
            return 2
            ;;
    esac
    local req_file tmp
    req_file="$(haku_state_path theme.classic.palette)" || return 1
    tmp="$(mktemp "${req_file}.XXXXXX")" || return 1
    if printf '%s\n' "$requested" > "$tmp" && mv "$tmp" "$req_file"; then
        classic_palette_sync || return 1
        render_apply
        return $?
    fi
    rm -f "$tmp"
    return 1
}

get_palette() {
    local eff_file
    eff_file="$(haku_state_path theme.classic.palette.effective)" || return 1
    if [[ ! -s "$eff_file" ]] && classic_palette_available; then
        classic_palette_sync || return 1
    fi
    cat "$eff_file" 2>/dev/null || printf 'gray\n'
}

set_accent() {
    local validated
    validated="$(validate_accent "${1:-}")" || return $?
    theme_set_seed "$validated" || return 1
    theme_save_state || return 1
    classic_palette_sync || return 1
    apply_and_reconcile
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
    get accent|font|size|palette
                            Print one canonical theme value
    palette                 Print effective Classic palette scheme id
    list-fonts              Print installed font families, one per line
    set-accent HEX          Persist HEX (#RRGGBB), render, and live-apply
    set-palette ID          Persist Classic palette (auto|red|orange|yellow|green|blue|indigo|violet|gray), render, and live-apply
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
            palette) get_palette ;;
            *)
                printf 'theme_ctl.sh: get requires accent, font, size, or palette.\n' >&2
                exit 2
                ;;
        esac
        ;;
    palette|--palette)
        get_palette
        ;;
    list-fonts|--list-fonts)
        if command -v fc-list >/dev/null 2>&1; then
            fc-list ':spacing=100' -f '%{family[0]}\n' 2>/dev/null | grep -v '^[[:space:]]*$' | sort -fu
        fi
        ;;
    set-accent|--set-accent)
        set_accent "${2:-}"
        ;;
    set-palette|--set-palette)
        set_palette "${2:-}"
        ;;
    set-font|--set-font)
        set_font "${2:-}"
        ;;
    set-size|--set-size)
        set_size "${2:-}"
        ;;
    apply|--apply)
        # Refresh saved variants when palette contrast rules change.
        theme_set_seed "$ACCENT_SEED" && theme_save_state || exit 1
        classic_palette_sync || exit 1
        apply_and_reconcile
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
