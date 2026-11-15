#!/usr/bin/env bash

# Headless session-exit controller.
# Process reporting and destructive cleanup live here; user confirmation belongs
# to frontend/classic/exit_rofi.sh.

set -u

# Include EXIT_APP_LIST_USER and RAM_THRESHOLD_MB. Seed the optional user list
# so nounset mode preserves the legacy empty-array behavior when no setting is
# provided.
EXIT_APP_LIST_USER=()
[[ -f "$HOME/hakucfg/setting.sh" ]] && source "$HOME/hakucfg/setting.sh"

EXIT_APP_LIST_DEFAULT=(
    "code" "code-url-handler" "zen" "zen-bin" "firefox" "chromium" "kitty" "slurp"
    "waybar" "taskbar" "hypridle" "swaync" "sway-audio-idle-inhibit"
    "awww-daemon" "gammastep" "polkit-mate" "hyprsunset" "agy"
    "qemu" "java" "qs -c hakuspace" "quickshell" "qs_supervisor.sh"
)
APP_LIST=("${EXIT_APP_LIST_DEFAULT[@]}" "${EXIT_APP_LIST_USER[@]}")
APP_PATTERN=$(IFS='|'; printf '%s' "${APP_LIST[*]}")

PORTAL_PATTERN='xdg-desktop-portal|xdg-desktop-portal-hyprland|xdg-desktop-portal-wlr|xdg-desktop-portal-gtk|xdg-desktop-portal-gnome'
RAM_THRESHOLD_MB=${RAM_THRESHOLD_MB:-300}

usage() {
    cat <<'EOF_HELP'
Usage: session_exit_ctl.sh <COMMAND>

Commands:
    process-report   Print active processes sorted by aggregate RAM usage
    prepare-hikai    Kill session apps but keep Quickshell/compositor IPC alive
    execute          Perform the destructive Classic/headless cleanup and quit WM
    -h, --help       Show this help message

Safety:
    Running this backend without an explicit command never exits the session.
EOF_HELP
}

require_no_extra_args() {
    if [[ $# -ne 0 ]]; then
        printf 'session_exit_ctl.sh: this command does not accept extra arguments.\n' >&2
        return 2
    fi
}

process_report() {
    ps -u "$USER" -o rss,comm | awk -v limit="$RAM_THRESHOLD_MB" '
    {
        if ($1 == "RSS") next;
        rss = $1; comm = $2;

        # Aggregate RSS memory and process count per application command.
        ram_sum[comm] += rss;
        count[comm]++;
    }
    END {
        for (app in ram_sum) {
            ram_mb = ram_sum[app] / 1024;
            status = (ram_mb >= limit) ? "[HIGH RAM]" : "[Active]";
            printf "%010.2f |    • %-22s | %-3s pids | %-8.1f MB %s\n", ram_mb, app, count[app], ram_mb, status;
        }
    }' | sort -rn -k1,1 | cut -d'|' -f2-
}

# Hikai must keep the shell itself alive until it has sent the compositor quit
# request through the already-active WM backend. Killing Quickshell here would remove
# the most reliable IPC client before that request is delivered.
prepare_hikai_exit() {
    local hikai_apps=()
    local app
    local hikai_pattern

    for app in "${APP_LIST[@]}"; do
        case "$app" in
            "qs -c hakuspace"|"quickshell")
                ;;
            *)
                hikai_apps+=("$app")
                ;;
        esac
    done

    hikai_pattern=$(IFS='|'; printf '%s' "${hikai_apps[*]}")

    # Stop the supervisor so it cannot relaunch Quickshell while the compositor
    # is shutting down, but leave the running Quickshell process itself alive.
    pkill -SIGTERM -u "$USER" -f "$hikai_pattern" 2>/dev/null
    pkill -SIGTERM -u "$USER" -f "$PORTAL_PATTERN" 2>/dev/null

    sleep 2

    pkill -9 -u "$USER" -f "$hikai_pattern" 2>/dev/null

    # Only HakuSpace-owned temporary state is safe to remove here. Compositor
    # sockets, systemd graphical targets and exported WM environment remain live
    # until Quickshell has delivered quitSession().
    rm -rf /tmp/cava-layer.log /tmp/cava-layer.pid 2>/dev/null
    rm -rf "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hakuspace" 2>/dev/null
}

detect_wm() {
    local desktop="${XDG_CURRENT_DESKTOP:-}"
    desktop="${desktop,,}"

    # Use the same compositor-specific environment that Quickshell uses for its
    # WM backend. Hikai may be started before XDG_CURRENT_DESKTOP is imported.
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || "$desktop" == *hyprland* ]]; then
        printf '%s\n' hyprland
    elif [[ -n "${NIRI_SOCKET:-}" || "$desktop" == *niri* ]]; then
        printf '%s\n' niri
    elif [[ -n "${MANGO_INSTANCE_SIGNATURE:-}" || "$desktop" == *mango* ]]; then
        printf '%s\n' mango
    elif [[ -n "${LABWC_PID:-}" || "$desktop" == *labwc* ]]; then
        printf '%s\n' labwc
    else
        printf '%s\n' unknown
    fi
}

quit_wm() {
    local wm="$1"

    # Keep the existing compositor quit commands unchanged. This must happen
    # while compositor IPC and the graphical session are still alive.
    case "$wm" in
        hyprland)
            hyprctl eval 'hl.dispatch(hl.dsp.exit())'
            ;;
        niri)
            niri msg action quit --skip-confirmation
            ;;
        mango)
            mmsg dispatch quit
            mmsg -s -q
            ;;
        labwc)
            labwc --exit
            ;;
        *)
            printf 'session_exit_ctl.sh: unable to detect the active WM; refusing to tear down compositor IPC first.\n' >&2
            return 1
            ;;
    esac
}

execute_exit() {
    local wm
    local quit_status
    wm="$(detect_wm)"

    # Graceful kill.
    pkill -SIGTERM -u "$USER" -f "$APP_PATTERN" 2>/dev/null
    pkill -SIGTERM -u "$USER" -f "$PORTAL_PATTERN" 2>/dev/null

    sleep 2

    # Force kill stubborn background processes.
    pkill -9 -u "$USER" -f "$APP_PATTERN" 2>/dev/null

    # Remove HakuSpace-owned runtime state before quitting the compositor, but
    # leave compositor IPC sockets and graphical-session targets intact until
    # the quit request has been delivered.
    rm -rf /tmp/cava-layer.log /tmp/cava-layer.pid 2>/dev/null
    rm -rf "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hakuspace" 2>/dev/null

    quit_wm "$wm"
    quit_status=$?

    # Post-quit cleanup is best effort. The compositor/session manager may tear
    # this process down as soon as the quit request is accepted.
    rm -f /tmp/.X11-unix/X* 2>/dev/null
    rm -f /tmp/.X*-lock 2>/dev/null
    rm -rf /tmp/hypr /tmp/niri* /tmp/sway* /tmp/waybar* 2>/dev/null

    systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP 2>/dev/null
    systemctl --user stop graphical-session.target 2>/dev/null
    systemctl --user stop graphical-session-pre.target 2>/dev/null
    systemctl --user stop xdg-desktop-portal.service 2>/dev/null

    return "$quit_status"
}

command_name="${1:-}"
if [[ -n "$command_name" ]]; then
    shift
fi

case "$command_name" in
    process-report)
        require_no_extra_args "$@" || exit $?
        process_report
        ;;
    prepare-hikai)
        require_no_extra_args "$@" || exit $?
        prepare_hikai_exit
        ;;
    execute)
        require_no_extra_args "$@" || exit $?
        execute_exit
        ;;
    -h|--help)
        usage
        ;;
    '')
        usage >&2
        exit 2
        ;;
    *)
        printf 'session_exit_ctl.sh: unknown command: %s\n' "$command_name" >&2
        usage >&2
        exit 2
        ;;
esac
