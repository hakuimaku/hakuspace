#!/usr/bin/env bash

# CLI for switching HakuSpace backends.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Complete filename migration before any state consumer starts.
if [[ -f "$SCRIPT_DIR/haku_state.sh" ]]; then
    source "$SCRIPT_DIR/haku_state.sh"
else
    source "$SCRIPT_DIR/../lib/haku_state.sh"
fi
haku_state_migrate || exit 1
if [[ -f "$SCRIPT_DIR/haku_backend_lib.sh" ]]; then
    source "$SCRIPT_DIR/haku_backend_lib.sh"
else
    source "$SCRIPT_DIR/../lib/haku_backend_lib.sh"
fi

# Stop Classic presentation and shared auxiliary processes using existing policy.
kill_classic_stack() {
    pkill -x waybar
    pkill -x taskbar
    pkill -x swaync
    pkill -x rofi
    pkill -f edge_trigger.py
    pkill -f rounded_screen.py
    if [[ -f /tmp/cava-layer.pid ]] && kill -0 "$(cat /tmp/cava-layer.pid 2>/dev/null)" 2>/dev/null; then
        echo "1" > "$(haku_state_path cava.enabled)"
    fi
    pkill -f cava_layer.py
    pkill -f desktop_icons.py
    rm -f /tmp/cava-layer.pid
}

# Restore user-enabled Classic surfaces without competing for notifications.
start_classic_visual_stack() {
    local failed=0
    ~/.local/bin/wallpaper_resume.sh 9>&- || failed=1
    ~/.local/bin/rounded_screen_manager.sh --startup 9>&- || failed=1
    ~/.local/bin/edge_trigger_manager.sh --startup 9>&- || failed=1
    ~/.local/bin/taskbar_manager.sh --startup 9>&- || failed=1
    ~/.local/bin/waybar_manager.sh 9>&- || failed=1
    ~/.local/bin/desktop_icons_manager.sh --startup 9>&- || failed=1
    ~/.local/bin/cava_manager.sh --startup 9>&- || failed=1
    return "$failed"
}

# Wait for observable readiness; this deadline is a failure watchdog only.
wait_until() {
    local deadline=$((SECONDS + 10))
    until "$@"; do
        if (( SECONDS >= deadline )); then
            echo "Timed out waiting for: $*" >&2
            return 1
        fi
        sleep 0.05
    done
}

# Match the actual notification owner rather than assuming process startup won.
notification_owned_by() {
    timeout 2s busctl --user status org.freedesktop.Notifications 2>/dev/null | grep -Eq "^Comm=($1)$"
}

# Bootstrap must wait for the previous notification server to release its name.
notification_unowned() {
    ! timeout 2s busctl --user status org.freedesktop.Notifications >/dev/null 2>&1
}

# Start SwayNC only after the HakuSpace Quickshell runtime has exited.
start_classic_notification_service() {
    haku_qs_alive && return 1
    notification_owned_by swaync || wait_until notification_unowned || return 1
    if ! pgrep -x swaync >/dev/null; then
        swaync </dev/null >/dev/null 2>&1 9>&- &
    fi
    wait_until notification_owned_by swaync
}

# Keep the combined startup path for recovery without an active overlay.
start_classic_stack() {
    local failed=0
    start_classic_notification_service || failed=1
    start_classic_visual_stack || failed=1
    return "$failed"
}

# Bound each IPC call and require the stable success response for mutations.
transition_ipc() {
    local response
    response=$(timeout 2s qs -c hakuspace ipc call shellTransition "$@" 2>>"$(haku_runtime_dir)/qs.log") || return 1
    if [[ "$1" == status ]]; then
        printf '%s\n' "$response"
    else
        [[ "$response" == ok ]]
    fi
}

# Decode a single field without depending on JSON formatting or field order.
transition_status_field() {
    transition_ipc status | python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$1" 2>/dev/null
}

# Full coverage and final reveal are IPC barriers, never guessed animation sleeps.
wait_transition_phase() {
    local wanted="$1" deadline=$((SECONDS + 10)) phase
    while (( SECONDS < deadline )); do
        phase=$(transition_status_field phase) || return 1
        [[ "$phase" == "$wanted" ]] && return 0
        [[ "$phase" == error ]] && return 1
        sleep 0.05
    done
    echo "Timed out waiting for transition phase: $wanted (last: $phase)" >&2
    return 1
}

# Require services, transition IPC, and notification ownership before entry.
quickshell_ready() {
    [[ $(timeout 2s qs -c hakuspace ipc call shell ping 2>/dev/null) == pong ]] &&
        transition_ipc status >/dev/null || return 1
    # Classic clients can reactivate SwayNC while the bootstrap server loads.
    if [[ ${1:-} == bootstrap ]] && notification_owned_by swaync; then
        pkill -x swaync 2>/dev/null || true
    fi
    notification_owned_by 'qs|quickshell'
}

# Migrate preferences before the temporary runtime starts watching them.
start_qs_transition_bootstrap() {
    ~/.local/bin/hikai_chrome_state_ctl.py migrate 9>&- || return 1
    setsid -f env HAKUSPACE_SHELL_TRANSITION_BOOTSTRAP=classic-to-hikai \
        python3 "$HOME/.local/bin/wallpaper_ctl.py" launch -c hakuspace </dev/null >>"$(haku_runtime_dir)/qs.log" 2>&1 9>&- || return 1
    wait_until quickshell_ready bootstrap
}

# The normal supervisor adopts the existing runtime without the bootstrap flag.
start_qs_supervisor() {
    if ! pgrep -f qs_supervisor.sh >/dev/null 2>&1; then
        setsid -f env -u HAKUSPACE_SHELL_TRANSITION_BOOTSTRAP \
            "$HOME/.local/bin/qs_supervisor.sh" </dev/null >/dev/null 2>&1 9>&- || return 1
    fi
    wait_until pgrep -f qs_supervisor.sh
}

# Stop the respawn owner while leaving the transition runtime alive.
stop_qs_supervisor() {
    pkill -f qs_supervisor.sh 2>/dev/null || true
    wait_until process_absent -f qs_supervisor.sh
}

# Negate pgrep for the shared bounded wait helper.
process_absent() {
    ! pgrep "$@" >/dev/null 2>&1
}

# Emergency teardown is never used during a healthy reveal.
kill_quickshell() {
    stop_qs_supervisor || return 1
    timeout 2s qs -c hakuspace kill 2>/dev/null || true
    if haku_qs_alive; then
        pkill -f '^(/[^ ]*/)?(qs|quickshell)( [^ ]+)* -c hakuspace( |$)' || true
    fi
    if ! wait_until process_absent -f '^(/[^ ]*/)?(qs|quickshell)( [^ ]+)* -c hakuspace( |$)'; then
        pkill -KILL -f '^(/[^ ]*/)?(qs|quickshell)( [^ ]+)* -c hakuspace( |$)' || true
        wait_until process_absent -f '^(/[^ ]*/)?(qs|quickshell)( [^ ]+)* -c hakuspace( |$)'
    fi
}

# Restore the existing auxiliary policy after committing Hikai under cover.
start_hikai_auxiliary_stack() {
    ~/.local/bin/desktop_icons_manager.sh --startup 9>&- &&
    ~/.local/bin/cava_manager.sh --startup 9>&-
}

# Publish mode atomically so concurrent facade readers never see an empty file.
commit_backend() {
    local next_state
    next_state=$(mktemp "${BACKEND_STATE_FILE}.XXXXXX") || return 1
    if printf '%s\n' "$1" > "$next_state" && mv -f "$next_state" "$BACKEND_STATE_FILE"; then
        return 0
    fi
    rm -f "$next_state"
    return 1
}

# Recover an unresponsive transition owner to a usable Classic desktop.
emergency_classic() {
    kill_quickshell || return 1
    commit_backend classic || return 1
    kill_classic_stack
    start_classic_stack && wait_until verify_backend
}

# Restore Classic under a reliable cover, or preserve untouched pre-cover visuals.
rollback_classic() {
    local covered="$1"
    stop_qs_supervisor || return 1
    commit_backend classic || return 1
    if [[ "$covered" == yes ]]; then
        transition_ipc hideChrome || { emergency_classic; return 1; }
        kill_classic_stack
        start_classic_visual_stack || { emergency_classic; return 1; }
        # Classic-to-Hikai rollback keeps its original upward reveal direction.
        if transition_ipc release && wait_transition_phase finished; then
            timeout 2s qs -c hakuspace ipc call shell quit 2>/dev/null || true
        fi
    fi
    kill_quickshell || return 1
    start_classic_notification_service && wait_until verify_backend
}

# Keep Quickshell alive so failed Classic preparation can reveal Hikai again.
rollback_hikai() {
    kill_classic_stack
    commit_backend "$QS_BACKEND_NAME" || return 1
    if quickshell_ready && start_hikai_auxiliary_stack && transition_ipc showChrome &&
        start_qs_supervisor && transition_ipc release && wait_transition_phase finished &&
        wait_until verify_backend; then
        return 0
    fi
    emergency_classic
}

# Prepare and commit Hikai only after every output shares the cover barrier.
switch_to_hikai() {
    pkill -x swaync 2>/dev/null || true
    if ! wait_until notification_unowned || ! start_qs_transition_bootstrap ||
        ! transition_ipc begin classic-to-hikai || ! wait_transition_phase covered; then
        rollback_classic no
        return 1
    fi
    kill_classic_stack
    if ! ~/.local/bin/desktop_icons_manager.sh --startup 9>&- || ! transition_ipc showChrome ||
        ! commit_backend "$QS_BACKEND_NAME"; then
        rollback_classic yes
        return 1
    fi
    # Cava reads the backend preference to select Hikai's existing dynamic-mode policy.
    if ! ~/.local/bin/cava_manager.sh --startup 9>&- || ! start_qs_supervisor; then
        rollback_classic yes
        return 1
    fi
    if ! transition_ipc release || ! wait_transition_phase finished || ! wait_until verify_backend; then
        emergency_classic
        return 1
    fi
}

# Keep the overlay alive through Classic construction and its complete reveal.
switch_to_classic() {
    if ! quickshell_ready; then
        emergency_classic
        return 1
    fi
    if ! transition_ipc begin hikai-to-classic || ! wait_transition_phase covered; then
        transition_ipc cancel || emergency_classic
        return 1
    fi
    if ! stop_qs_supervisor || ! transition_ipc hideChrome ||
        ! commit_backend classic || ! start_classic_visual_stack; then
        rollback_hikai
        return 1
    fi
    if ! transition_ipc releaseAndQuit ||
        ! wait_until process_absent -f '^(/[^ ]*/)?(qs|quickshell)( [^ ]+)* -c hakuspace( |$)' ||
        ! start_classic_notification_service || ! wait_until verify_backend; then
        emergency_classic
        return 1
    fi
}

# Serialize the complete operation and resolve toggles only after locking.
set_backend() (
    local target="$1" current
    exec 9>"$(haku_runtime_dir)/shell-switch.lock" || return 1
    flock -n 9 || { echo "A shell switch is already running." >&2; return 1; }
    current=$(haku_backend_get)
    if [[ "$target" == toggle ]]; then
        if [[ "$current" == classic ]]; then target="$QS_BACKEND_NAME"; else target=classic; fi
    fi
    if [[ "$target" != classic && "$target" != "$QS_BACKEND_NAME" && "$target" != recover ]]; then
        echo "Invalid backend: $target" >&2
        return 1
    fi
    trap 'emergency_classic; exit 1' HUP INT TERM
    if [[ "$target" == recover ]]; then
        emergency_classic
        return $?
    fi
    if [[ "$target" == "$current" ]]; then
        verify_backend
        return $?
    fi
    if [[ "$target" == "$QS_BACKEND_NAME" ]]; then
        switch_to_hikai || return 1
    else
        switch_to_classic || return 1
    fi
    notify-send -a "HakuSpace" -i "info" "Backend Switched" "Successfully switched to $target backend." 9>&- || true
)

# Verify notification ownership and only those Classic features enabled by the user.
verify_backend() {
    local current proc state
    current=$(haku_backend_get)
    if [[ "$current" == "$QS_BACKEND_NAME" ]]; then
        for proc in waybar taskbar rofi edge_trigger.py rounded_screen.py swaync; do
            if [[ "$proc" == *.py ]]; then
                process_absent -f "$proc" || return 1
            else
                process_absent -x "$proc" || return 1
            fi
        done
        haku_qs_alive && notification_owned_by 'qs|quickshell' || return 1
    else
        haku_qs_alive && return 1
        pgrep -x swaync >/dev/null && notification_owned_by swaync || return 1
        for state in desktop.waybar.requested:waybar desktop.taskbar.requested:taskbar \
            screen.rounded.enabled:rounded_screen.py desktop.edge-trigger.enabled:edge_trigger.py \
            desktop.icons.enabled:desktop_icons.py; do
            [[ $(cat "$(haku_state_path "${state%%:*}")" 2>/dev/null) == 1 ]] || continue
            proc=${state#*:}
            if [[ "$proc" == *.py ]]; then
                pgrep -f "$proc" >/dev/null || return 1
            else
                pgrep -x "$proc" >/dev/null || return 1
            fi
        done
    fi
    echo "Verification passed: $current."
}

case "${1:-}" in
    set) set_backend "${2:-}" ;;
    -t|--toggle) set_backend toggle ;;
    -c|--check) haku_backend_get ;;
    --verify) verify_backend ;;
    --recover) set_backend recover ;;
    *)
        echo "Usage: $0 {set <classic|hikai> | --toggle | --check | --verify | --recover}"
        exit 1
        ;;
esac
