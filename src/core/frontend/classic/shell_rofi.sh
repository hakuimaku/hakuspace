#!/usr/bin/env bash

# Classic login-shell picker frontend.
# Owns Rofi selection/password UX; shell discovery and mutation live in
# shell_ctl.sh.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AUTH_REQUIRED=77

resolve_script() {
    local name="$1" source_path="$2" candidate
    for candidate in \
        "$SCRIPT_DIR/$name" \
        "$SCRIPT_DIR/$source_path" \
        "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" || -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf 'shell_rofi.sh: required script not found: %s\n' "$name" >&2
    return 1
}

SHELL_CTL="$(resolve_script shell_ctl.sh ../../backend/system/shell_ctl.sh)" || exit 1
PRINT_ONLY=0
[[ ${1:-} == --print ]] && PRINT_ONLY=1
if [[ $# -gt 0 && ${1:-} != --print ]]; then
    printf 'shell_rofi.sh: unknown option: %s\n' "$1" >&2
    exit 2
fi

command -v rofi >/dev/null 2>&1 || { notify-send "Shell Switcher" "Missing dependency: rofi"; exit 1; }

rows=()
labels=()
while IFS=$'\t' read -r id path is_current; do
    [[ -n $id && -n $path ]] || continue
    rows+=("$id"$'\t'"$path")
    label=$id
    [[ $is_current == true ]] && label+=' (current)'
    labels+=("$label")
done < <("$SHELL_CTL" list)

if (( ${#rows[@]} == 0 )); then
    notify-send "Shell Switcher" "No supported shell found in PATH (looked for: fish zsh)."
    exit 1
fi

choice=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -i -no-custom -p "Shell" -theme option-menu.rasi) || exit 0
[[ -n $choice ]] || exit 0

selected=${choice%% *}
new=''
for row in "${rows[@]}"; do
    IFS=$'\t' read -r id path <<< "$row"
    if [[ $id == "$selected" ]]; then
        new=$path
        break
    fi
done
[[ -n $new ]] || exit 0

stderr_file=$(mktemp)
trap 'rm -f "$stderr_file"' EXIT
resolved=$("$SHELL_CTL" set "$selected" 2>"$stderr_file")
status=$?

if [[ $status -eq $AUTH_REQUIRED ]]; then
    password=$(rofi -dmenu -password -l 0 -p "sudo password" -theme option-menu.rasi </dev/null) || exit 0
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

if [[ -t 0 && -t 1 ]]; then
    exec env SHELL="$resolved" "$resolved"
fi

notify-send "Shell Switcher" "Shell changed to $selected. Log out and back in for it to take effect."
