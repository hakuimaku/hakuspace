#!/usr/bin/env bash

# Headless Waybar controller API.
# Owns mode discovery, symlink/state mutation, and Waybar process lifecycle.
# Presentation/selection UI belongs outside this backend.

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
    printf 'waybar_ctl.sh: required library not found: %s\n' "$name" >&2
    return 1
}

source_core_lib haku_theme.sh || exit 1
source_core_lib haku_backend_lib.sh || exit 1

WAYBAR_DIR="$HOME/.config/waybar"
USER_WAYBAR_DIR="$HOME/hakucfg/config/waybar"
SETTING_FILE="$HOME/hakucfg/setting.sh"
STATE_FILE="$STATE_DIR/waybar_current_mode"
STATUS_FILE="$STATE_DIR/waybar_manual_state"
DEFAULT_MODES=("top" "left" "island" "neon" "coredge" "minimal" "legacy")
WAYBAR_MODE_USER=()

if [[ -f "$SETTING_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$SETTING_FILE"
fi

WAYBAR_MODES=("${DEFAULT_MODES[@]}" "${WAYBAR_MODE_USER[@]}")
mkdir -p "$STATE_DIR"

ensure_state() {
    if [[ ! -s "$STATE_FILE" ]]; then
        printf 'top\n' > "$STATE_FILE"
    fi
    if [[ ! -f "$STATUS_FILE" ]] || ! grep -qxE '0|1' "$STATUS_FILE"; then
        printf '1\n' > "$STATUS_FILE"
    fi
}

current_mode() {
    cat "$STATE_FILE" 2>/dev/null || printf 'top\n'
}

waybar_enabled() {
    [[ "$(cat "$STATUS_FILE" 2>/dev/null || printf '1')" == "1" ]]
}

mode_known() {
    local wanted="$1" mode
    for mode in "${WAYBAR_MODES[@]}"; do
        [[ "$mode" == "$wanted" ]] && return 0
    done
    return 1
}

mode_dir() {
    local mode="$1"
    if [[ -d "$WAYBAR_DIR/$mode" ]]; then
        printf '%s\n' "$WAYBAR_DIR/$mode"
        return 0
    fi
    if [[ -d "$USER_WAYBAR_DIR/$mode" ]]; then
        printf '%s\n' "$USER_WAYBAR_DIR/$mode"
        return 0
    fi
    return 1
}

link_mode() {
    local mode="$1" target_dir
    if ! mode_known "$mode"; then
        printf 'waybar_ctl.sh: unknown Waybar mode: %s\n' "$mode" >&2
        return 2
    fi
    target_dir="$(mode_dir "$mode")" || {
        printf 'waybar_ctl.sh: mode directory not found: %s\n' "$mode" >&2
        return 1
    }

    mkdir -p "$WAYBAR_DIR"
    ln -sf "$target_dir/config" "$WAYBAR_DIR/config"
    ln -sf "$target_dir/style.css" "$WAYBAR_DIR/style.css"
    printf '%s\n' "$mode" > "$STATE_FILE"
}

ensure_links() {
    local mode
    mode="$(current_mode)"
    if [[ ! -f "$WAYBAR_DIR/config" || ! -f "$WAYBAR_DIR/style.css" ]]; then
        link_mode "$mode"
    fi
}

stop_waybar() {
    if pgrep -fx waybar >/dev/null 2>&1; then
        pkill -fx waybar
        sleep 0.2
    fi
}

start_waybar() {
    waybar &
}

reload_waybar() {
    if haku_qs_mode; then
        return 0
    fi
    waybar_enabled || return 0
    ensure_links || return 1
    stop_waybar
    start_waybar
}

startup_waybar() {
    if haku_qs_mode; then
        return 0
    fi
    ensure_links || return 1
    if waybar_enabled && ! pgrep -x waybar >/dev/null 2>&1; then
        start_waybar
    fi
}

toggle_waybar() {
    if haku_qs_mode; then
        if waybar_enabled; then
            printf '0\n' > "$STATUS_FILE"
        else
            printf '1\n' > "$STATUS_FILE"
        fi
        return 0
    fi

    if pgrep -x waybar >/dev/null 2>&1; then
        pkill -x waybar
        printf '0\n' > "$STATUS_FILE"
    else
        ensure_links || return 1
        start_waybar
        printf '1\n' > "$STATUS_FILE"
    fi
}

set_mode() {
    local mode="${1:-}"
    if [[ -z "$mode" ]]; then
        printf 'waybar_ctl.sh: set requires a mode id.\n' >&2
        return 2
    fi
    if haku_qs_mode && [[ "$mode" != "top" ]]; then
        printf 'waybar_ctl.sh: only top is supported by the Hikai backend.\n' >&2
        return 3
    fi

    local current
    current="$(current_mode)"
    if [[ "$mode" != "$current" ]]; then
        link_mode "$mode" || return $?
    else
        ensure_links || return 1
    fi

    reload_waybar
}

cycle_mode() {
    if haku_qs_mode; then
        return 0
    fi
    waybar_enabled || return 0

    local current current_idx=-1 next_idx next_mode i
    current="$(current_mode)"
    for i in "${!WAYBAR_MODES[@]}"; do
        if [[ "${WAYBAR_MODES[$i]}" == "$current" ]]; then
            current_idx="$i"
            break
        fi
    done

    next_idx=$(( (current_idx + 1) % ${#WAYBAR_MODES[@]} ))
    next_mode="${WAYBAR_MODES[$next_idx]}"
    if [[ "$next_mode" != "$current" ]]; then
        link_mode "$next_mode" || return $?
        reload_waybar
    fi
}

print_help() {
    cat <<'EOF_HELP'
Usage: waybar_ctl.sh COMMAND [ARG]
Headless Waybar control API.

Commands:
    list                Print known mode ids, one per line
    current             Print persisted current mode id
    set MODE            Select MODE explicitly and reload when applicable
    cycle               Switch to the next mode
    toggle              Toggle Waybar on/off
    reload              Reload Waybar when enabled
    startup             Restore Waybar at session startup
    status              Print enabled or disabled
    -h, --help          Show this help message
EOF_HELP
}

ensure_state

case "${1:-}" in
    list|--list)
        printf '%s\n' "${WAYBAR_MODES[@]}"
        ;;
    current|--current)
        current_mode
        ;;
    set|--set)
        set_mode "${2:-}"
        ;;
    cycle|--cycle)
        cycle_mode
        ;;
    toggle|--toggle)
        toggle_waybar
        ;;
    reload|--reload)
        reload_waybar
        ;;
    startup|--startup)
        startup_waybar
        ;;
    status|--status)
        if waybar_enabled; then printf 'enabled\n'; else printf 'disabled\n'; fi
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
