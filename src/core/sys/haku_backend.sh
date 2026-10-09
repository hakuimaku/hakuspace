#!/usr/bin/env bash

# CLI for switching HakuSpace backends

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_backend_lib.sh"

kill_classic_stack() {
    pkill -x waybar
    pkill -x taskbar
    [[ "${QS_ALLOW_SWAYNC:-0}" == "0" ]] && pkill -x swaync
    pkill -x rofi
    pkill -f edge_trigger.py
    pkill -f rounded_screen.py
    pkill -f cava_layer.py
    pkill -f desktop_icons.py
    rm -f /tmp/cava-layer.pid
}

start_classic_stack() {
    pgrep -x swaync >/dev/null || swaync &
    ~/.local/bin/rounded_screen_manager.sh --startup
    ~/.local/bin/edge_trigger_manager.sh --startup
    ~/.local/bin/taskbar_manager.sh --startup
    ~/.local/bin/waybar_manager.sh
    ~/.local/bin/desktop_icons_manager.sh --startup
}

set_backend() {
    local target="$1"
    
    if [[ "$target" != "classic" && "$target" != $QS_BACKEND_NAME ]]; then
        echo "Invalid backend: $target"
        return 1
    fi
    
    echo "$target" > "$BACKEND_STATE_FILE"
    local runtime_dir="$(haku_runtime_dir)"
    
    if [[ "$target" == $QS_BACKEND_NAME ]]; then
        kill_quickshell
        echo "Killing classic stack..."
        kill_classic_stack
        
        # Wait for D-Bus name to be released (simple delay)
        echo "Waiting for D-Bus release..."
        sleep 0.5
        
        # Start supervisor
        if ! pgrep -f qs_supervisor.sh >/dev/null 2>&1; then
            echo "Starting qs_supervisor.sh..."
            setsid -f ~/.local/bin/qs_supervisor.sh >/dev/null 2>&1
        fi
        
        # Health check
        echo "Waiting for quickshell IPC health check..."
        local retries=5
        local success=0
        for ((i=0; i<retries; i++)); do
            echo -n "."
            sleep 1
            if qs -c hakuspace ipc call shell ping 2>/dev/null | grep -q "pong"; then
                success=1
                echo " [OK]"
                break
            fi
        done
        
        if [[ $success -eq 1 ]]; then
            notify-send -a "HakuSpace" -i "info" "Backend Switched" "Successfully switched to hikai backend."
        else
            echo "Quickshell failed to start. Rolling back to classic."
            echo "classic" > "$BACKEND_STATE_FILE"
            kill_quickshell
            
            # Wait for QS to exit
            local wait_retries=10
            for ((j=0; j<wait_retries; j++)); do
                if ! haku_qs_alive; then break; fi
                sleep 0.5
            done
            
            start_classic_stack
        fi
        
    elif [[ "$target" == "classic" ]]; then
        kill_quickshell
        rm -f /tmp/cava-layer.pid
        start_classic_stack
        notify-send -a "HakuSpace" -i "info" "Backend Switched" "Successfully switched to classic backend."
    fi
}

kill_quickshell() {
    pkill -f qs_supervisor.sh
    qs -c hakuspace kill 2>/dev/null
    sleep 0.2
    if pgrep -f '^(/[^ ]*/)?(qs|quickshell)( [^ ]+)* -c hakuspace( |$)' >/dev/null 2>&1; then
        pkill -f '^(/[^ ]*/)?(qs|quickshell)( [^ ]+)* -c hakuspace( |$)'
    fi
}

verify_backend() {
    local current="$(haku_backend_get)"
    echo "Current backend: $current"
    if [[ "$current" == $QS_BACKEND_NAME ]]; then
        local violations=""
        local procs="waybar taskbar rofi edge_trigger.py rounded_screen.py cava_layer.py desktop_icons.py"
        [[ "${QS_ALLOW_SWAYNC:-0}" == "0" ]] && procs="$procs swaync" # TEMP: swaync allowed until M3 (D-Bus activation re-spawns it)
        for proc in $procs; do
            if [[ "$proc" == *.py ]]; then
                if pgrep -f "$proc" >/dev/null 2>&1; then
                    violations="$violations $proc"
                fi
            else
                if pgrep -x "$proc" >/dev/null 2>&1; then
                    violations="$violations $proc"
                fi
            fi
        done
        if [[ -n "$violations" ]]; then
            echo "Violations found: $violations are running in hikai mode!"
            return 1
        fi
        if ! haku_qs_alive; then
            echo "Violation: quickshell is not running!"
            return 1
        fi
    fi
    echo "Verification passed."
    return 0
}

case "${1:-}" in
    set)
        set_backend "$2"
        ;;
    -t|--toggle)
        if haku_backend_is "classic"; then
            set_backend $QS_BACKEND_NAME
        else
            set_backend "classic"
        fi
        ;;
    -c|--check)
        echo "$(haku_backend_get)"
        ;;
    --verify)
        verify_backend
        ;;
    --recover)
        set_backend "classic"
        ;;
    *)
        echo "Usage: $0 {set <classic|hikai> | --toggle | --check | --verify | --recover}"
        exit 1
        ;;
esac
