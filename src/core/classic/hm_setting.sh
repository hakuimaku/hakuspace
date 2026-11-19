#!/usr/bin/env bash

spawn() {
    (
        if [[ -n "${ROFI_RETV:-}" && -f "${XDG_RUNTIME_DIR:-/tmp}/rofi.pid" ]] && command -v flock >/dev/null 2>&1; then
            flock -s -w 0.5 "${XDG_RUNTIME_DIR:-/tmp}/rofi.pid" true 2>/dev/null || sleep 0.05
        fi
        "$@"
    ) >/dev/null 2>&1 &
}
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_theme.sh" || exit 1

if [[ $# -eq 0 ]]; then
    cat <<INNEREOF
  Change Shell
󱁤  Settings Folder
󱁤  HakuMenu General Config
󰖩  Wifi
󰂯  Bluetooth
󰋊  Disk Manager
󰃢  Storage Manager
  Audio Control
INNEREOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"Change Shell"*) spawn "$HAKU_BIN_DIR/shell_switcher.sh" ;;
    *"Settings Folder"*) spawn xdg-open "$HOME/hakucfg" ;;
    *"HakuMenu General Config"*) spawn code "$HOME/hakucfg/config/hakumenu-general.json" ;;
    *"Wifi"*) spawn nm-connection-editor ;;
    *"Bluetooth"*) spawn blueman-manager ;;
    *"Disk Manager"*) spawn gparted ;;
    *"Storage Manager"*) spawn kitty --class ncdu -e sudo ncdu / ;;
    *"Audio Control"*) spawn pavucontrol ;;
esac

exit 0
