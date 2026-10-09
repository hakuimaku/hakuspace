#!/usr/bin/env bash

# Headless Taskbar domain/controller API.
#
# This script owns Taskbar state/process/theme mutation only. It must not open a
# picker or depend on Rofi/haku_pick. Classic presentation lives in
# taskbar_rofi.sh; taskbar_manager.sh remains the public compatibility facade.

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
    printf 'taskbar_ctl.sh: required library not found: %s\n' "$name" >&2
    return 1
}

source_core_lib haku_theme.sh || exit 1
source_core_lib haku_backend_lib.sh || exit 1

MANUAL_STATE="$STATE_DIR/taskbar_manual_state"
TASKBAR_REAL_DIR="$HOME/.config/waybar/taskbar"
TASKBAR_LINK_DIR="$HOME/.config/waybar"
TASKBAR_CONFIG="$TASKBAR_LINK_DIR/config-taskbar"
TASKBAR_STYLE="$TASKBAR_LINK_DIR/style-taskbar.css"
TASKBAR_PIN_APPS="$HOME/hakucfg/config/taskbar-pin-apps"
THEME_FILE="$THEME_ROOT/taskbar-theme"
TASKBAR_BIN="$HOME/.local/bin/taskbar"

mkdir -p "$STATE_DIR"

ensure_manual_state() {
    if [[ ! -f "$MANUAL_STATE" ]] || ! grep -qxE '0|1' "$MANUAL_STATE"; then
        echo "0" > "$MANUAL_STATE"
    fi
}

warn_theme_file() {
    if [[ ! -f "$THEME_FILE" ]]; then
        printf 'Warning: Taskbar theme file not found.\n' >&2
    fi
}

ensure_symlink() {
    local target="$1" link="$2"
    if [[ ! -L "$link" || "$(readlink -f "$link" 2>/dev/null || true)" != "$(readlink -f "$target" 2>/dev/null || true)" ]]; then
        ln -sf "$target" "$link"
    fi
}

ensure_runtime() {
    local waybar_bin
    waybar_bin="$(command -v waybar || true)"
    if [[ -z "$waybar_bin" ]]; then
        printf 'Waybar binary not found in PATH. Please install Waybar first.\n' >&2
        return 1
    fi

    mkdir -p "$HOME/.local/bin" "$TASKBAR_LINK_DIR"
    if [[ ! -L "$TASKBAR_BIN" || "$(readlink -f "$TASKBAR_BIN" 2>/dev/null || true)" != "$(readlink -f "$waybar_bin")" ]]; then
        ln -sf "$waybar_bin" "$TASKBAR_BIN"
    fi

    ensure_symlink "$TASKBAR_REAL_DIR/config" "$TASKBAR_CONFIG"
    ensure_symlink "$TASKBAR_REAL_DIR/style.css" "$TASKBAR_STYLE"
}

launch_taskbar() {
    if haku_qs_mode; then return 0; fi
    "$TASKBAR_BIN" -c "$TASKBAR_CONFIG" -s "$TASKBAR_STYLE" >/dev/null 2>&1 &
    disown
}

is_taskbar_running() {
    if haku_qs_mode; then
        [[ "$(cat "$MANUAL_STATE")" == "1" ]]
        return $?
    fi
    pgrep -x "taskbar" >/dev/null
}

kill_taskbar() {
    if haku_qs_mode; then return 0; fi
    if pgrep -x "taskbar" >/dev/null; then
        pkill -x "taskbar"
        for _ in $(seq 1 20); do
            pgrep -x "taskbar" >/dev/null || break
            sleep 0.1
        done
        if pgrep -x "taskbar" >/dev/null; then
            pkill -9 -x "taskbar"
        fi
    fi
}

reload_taskbar() {
    ensure_runtime || return 1
    kill_taskbar
    if [[ "$(cat "$MANUAL_STATE")" == "1" ]]; then
        launch_taskbar
    fi
}

startup_taskbar() {
    ensure_runtime || return 1
    if [[ "$(cat "$MANUAL_STATE")" == "1" ]] && ! is_taskbar_running; then
        launch_taskbar
    fi
}

toggle_taskbar() {
    ensure_runtime || return 1
    if [[ "$(cat "$MANUAL_STATE")" == "0" ]]; then
        echo "1" > "$MANUAL_STATE"
        kill_taskbar
        launch_taskbar
    else
        echo "0" > "$MANUAL_STATE"
        kill_taskbar
    fi
}

get_app_name() {
    if [[ -f "$THEME_FILE" ]] && grep -qE '"format":\s*"\{icon\} \{name\}"' "$THEME_FILE"; then
        printf 'on\n'
    else
        printf 'off\n'
    fi
}

toggle_app_name() {
    warn_theme_file
    ensure_runtime || return 1
    if [[ ! -f "$THEME_FILE" ]]; then
        return 1
    fi

    if grep -qE '"format":\s*"\{icon\} \{name\}"' "$THEME_FILE"; then
        sed -i -E 's/"format":\s*"\{icon\} \{name\}"/"format": "{icon}"/' "$THEME_FILE"
        echo "Taskbar App Name disabled."
    else
        sed -i -E 's/"format":\s*"\{icon\}"/"format": "{icon} {name}"/' "$THEME_FILE"
        echo "Taskbar App Name enabled."
    fi

    reload_taskbar
}

get_icon_size() {
    local current_size=""
    if [[ -f "$THEME_FILE" ]]; then
        current_size="$(grep -oP '"icon-size":\s*\K\d+' "$THEME_FILE" | head -n 1 || true)"
    fi
    [[ -z "$current_size" ]] && current_size=40
    printf '%s\n' "$current_size"
}

set_icon_size() {
    local new_size="${1:-}"
    if [[ ! "$new_size" =~ ^[0-9]+$ ]]; then
        printf 'taskbar_ctl.sh: icon size must be a positive integer.\n' >&2
        return 2
    fi

    warn_theme_file
    ensure_runtime || return 1
    if [[ ! -f "$THEME_FILE" ]]; then
        return 1
    fi

    sed -i -E "s/\"icon-size\": *[0-9]+/\"icon-size\": $new_size/g" "$THEME_FILE"
    echo "Icon size updated to $new_size."

    if [[ -f "$TASKBAR_PIN_APPS" ]]; then
        sed -i -E "s/\"size\": *[0-9]+/\"size\": $new_size/g" "$TASKBAR_PIN_APPS"
        echo "Pinned app icon sizes updated to $new_size."
    fi

    reload_taskbar
}

print_help() {
    cat <<'EOF_HELP'
Usage: taskbar_ctl.sh COMMAND [ARG]
Headless Taskbar control API.

Commands:
    --startup               Restore previous state at boot
    --reload                Reload the taskbar
    --toggle                Toggle the taskbar on/off
    --status                Print enabled or disabled
    --get-app-name          Print on or off
    --toggle-app-name       Toggle app name format
    --get-icon-size         Print current icon size
    --set-icon-size PX      Set icon size explicitly
    -h, --help              Show this help message
EOF_HELP
}

ensure_manual_state

case "${1:-}" in
    --startup)
        startup_taskbar
        ;;
    --reload)
        reload_taskbar
        ;;
    --toggle)
        toggle_taskbar
        ;;
    --status)
        if [[ "$(cat "$MANUAL_STATE")" == "1" ]]; then
            printf 'enabled\n'
        else
            printf 'disabled\n'
        fi
        ;;
    --get-app-name)
        get_app_name
        ;;
    --toggle-app-name)
        toggle_app_name
        ;;
    --get-icon-size)
        get_icon_size
        ;;
    --set-icon-size)
        set_icon_size "${2:-}"
        ;;
    -h|--help)
        print_help
        ;;
    *)
        printf 'Invalid option. Use --help for usage information.\n' >&2
        exit 2
        ;;
esac
