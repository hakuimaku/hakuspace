#!/usr/bin/env bash

# Global login-shell picker frontend for HakuSpace.
# Supports both Classic (Rofi) and Hikai (Quickshell) layer interfaces.
# Owns shell selection, layer password prompt, and session restart prompt.
# Shell discovery and mutation live in shell_ctl.sh.

set -u
AUTH_REQUIRED=77

# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_backend_lib.sh" || exit 1
SHELL_CTL="$HAKU_BIN_DIR/shell_ctl.sh"
HAKU_PICK="$HAKU_BIN_DIR/haku_pick.sh"
POWER_CTL="$HAKU_BIN_DIR/power_ctl.sh"
SESSION_EXIT_CTL="$HAKU_BIN_DIR/session_exit_ctl.sh"

PRINT_ONLY=0
[[ ${1:-} == --print ]] && PRINT_ONLY=1
if [[ $# -gt 0 && ${1:-} != --print ]]; then
    printf 'shell_rofi.sh: unknown option: %s\n' "$1" >&2
    exit 2
fi

layer_pick() {
    local prompt="$1"
    shift
    if haku_backend_is "classic" || ! haku_qs_alive; then
        command -v rofi >/dev/null 2>&1 || {
            notify-send "Shell Switcher" "Missing dependency: rofi"
            return 1
        }
        rofi -dmenu -sync -i -no-custom -p "$prompt" -theme styles/menu.rasi "$@"
    else
        "$HAKU_PICK" --prompt "$prompt" --no-custom "$@"
    fi
}

layer_password() {
    local prompt="$1"
    if haku_backend_is "classic" || ! haku_qs_alive; then
        command -v rofi >/dev/null 2>&1 || return 1
        rofi -dmenu -sync -password -l 0 -p "$prompt" -theme styles/menu.rasi </dev/null
    else
        echo -n | "$HAKU_PICK" --prompt "$prompt" --password --lines 0
    fi
}

rows=()
labels=()
while IFS=$'\t' read -r id path is_current; do
    [[ -n $id && -n $path ]] || continue
    rows+=("$id"$'\t'"$path"$'\t'"$is_current")
    icon=""
    [[ "$id" == "fish" ]] && icon="󰈺"
    [[ "$id" == "zsh" ]] && icon=""
    label="$icon  $id"
    [[ $is_current == true ]] && label+=' (current)'
    labels+=("$label")
done < <("$SHELL_CTL" list)

if (( ${#rows[@]} == 0 )); then
    notify-send "Shell Switcher" "No supported shell found in PATH (looked for: fish zsh)."
    exit 1
fi

choice=$(printf '%s\n' "${labels[@]}" | layer_pick "Shell") || exit 0
[[ -n $choice ]] || exit 0

selected=''
new=''
current_selected=false
for row in "${rows[@]}"; do
    IFS=$'\t' read -r id path is_current <<< "$row"
    if [[ "$choice" == *"$id"* ]]; then
        selected=$id
        new=$path
        [[ $is_current == "true" ]] && current_selected=true
        break
    fi
done

[[ -n $new ]] || exit 0

if [[ $current_selected == "true" ]]; then
    notify-send "Shell Switcher" "Login shell is already $selected."
    exit 0
fi

stderr_file=$(mktemp)
trap 'rm -f "$stderr_file"' EXIT
resolved=$("$SHELL_CTL" set "$selected" 2>"$stderr_file")
status=$?

if [[ $status -eq $AUTH_REQUIRED ]]; then
    password=$(layer_password "sudo password") || exit 0
    [[ -n $password ]] || exit 0
    resolved=$(printf '%s\n' "$password" | HAKUSPACE_SUDO_STDIN=1 "$SHELL_CTL" set "$selected" 2>"$stderr_file")
    status=$?
    unset password
fi

if [[ $status -ne 0 ]]; then
    message=$(tail -n 1 "$stderr_file" 2>/dev/null)
    [[ -n $message ]] || message="Failed to change login shell to $selected."
    notify-send "Shell Switcher" "$message"
    exit "$status"
fi

[[ -n $resolved ]] || resolved=$new

if (( PRINT_ONLY )); then
    printf '%s\n' "$resolved"
    exit 0
fi

restart_options=(
    "󰩈 Log out"
    " Reboot"
    "󰅖 Later"
)

restart_choice=$(printf '%s\n' "${restart_options[@]}" | layer_pick "Restart session to apply?") || restart_choice=""

case "$restart_choice" in
    *"Log out"*|*"Logout"*)
        notify-send "Shell Switcher" "Logging out to apply shell changes..."
        if [[ -x "$SESSION_EXIT_CTL" ]]; then
            exec "$SESSION_EXIT_CTL" execute
        elif [[ -x "$POWER_CTL" ]]; then
            exec "$POWER_CTL" logout
        fi
        ;;
    *"Reboot"*)
        notify-send "Shell Switcher" "Rebooting system to apply shell changes..."
        if [[ -x "$POWER_CTL" ]]; then
            exec "$POWER_CTL" reboot
        else
            exec systemctl reboot
        fi
        ;;
    *)
        notify-send "Shell Switcher" "Shell changed to $selected. Please restart session later to apply."
        exit 0
        ;;
esac
