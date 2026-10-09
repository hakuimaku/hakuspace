#!/usr/bin/env bash

# CLI for switching HakuSpace backends

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/haku_backend_lib.sh"

kill_classic_stack() {
    pkill -x waybar
    pkill -x taskbar
    pkill -x swaync
    pkill -x rofi
    pkill -f edge_trigger.py
    pkill -f rounded_screen.py
    pkill -f cava_layer.py
    pkill -f desktop_icons.py
    rm -f /tmp/cava-layer.pid
}

start_classic_stack() {
    swaync &
    ~/.local/bin/rounded_screen_manager.sh --startup
    ~/.local/bin/edge_trigger_manager.sh --startup
    ~/.local/bin/taskbar_manager.sh --startup
    ~/.local/bin/waybar_manager.sh
    ~/.local/bin/desktop_icons_manager.sh --startup
}

set_backend() {
    local target="$1"
    
    if [[ "$target" != "classic" && "$target" != "hikai" ]]; then
        echo "Invalid backend: $target"
        return 1
    fi
    
    echo "$target" > "$BACKEND_STATE_FILE"
    local runtime_dir="$(haku_runtime_dir)"
    
    if [[ "$target" == "hikai" ]]; then
        kill_classic_stack
        
        # Wait for D-Bus name to be released (simple delay)
        sleep 0.5
        
        # Start supervisor
        setsid -f ~/.local/bin/qs_supervisor.sh >/dev/null 2>&1
        
        # Health check
        local retries=5
        local success=0
        for ((i=0; i<retries; i++)); do
            sleep 1
            if qs -c hakuspace ipc call shell ping 2>/dev/null | grep -q "pong"; then
                success=1
                break
            fi
        done
        
        if [[ $success -eq 1 ]]; then
            notify-send -a "HakuSpace" -i "info" "Backend Switched" "Successfully switched to hikai backend."
        else
            echo "Hikai failed to start. Rolling back to classic."
            echo "classic" > "$BACKEND_STATE_FILE"
            kill_quickshell
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
    qs -c hakuspace quit 2>/dev/null || pkill -x qs || pkill -x quickshell
}

verify_backend() {
    local current="$(haku_backend_get)"
    echo "Current backend: $current"
    if [[ "$current" == "hikai" ]]; then
        local violations=""
        for proc in waybar taskbar swaync rofi edge_trigger.py rounded_screen.py cava_layer.py desktop_icons.py; do
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
            set_backend "hikai"
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
