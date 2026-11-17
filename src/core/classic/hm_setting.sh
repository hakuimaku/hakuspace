#!/usr/bin/env bash

spawn() { ( "$@" & ) >/dev/null 2>&1; }
# shellcheck source=/dev/null
source "${HAKU_BIN_DIR:-$HOME/.local/bin}/haku_theme.sh" || exit 1

if [[ $# -eq 0 ]]; then
    CAVA_COLOR_STATUS=$(cat "$(haku_state_path cava.color-mode)" 2>/dev/null || echo "1")
    IS_COLOR=""
    [[ "$CAVA_COLOR_STATUS" == "1" ]] && IS_COLOR="(Accent)" || IS_COLOR="(Surface)"

    CAVA_DYNAMIC_STATUS=$(cat "$(haku_state_path cava.dynamic-position)" 2>/dev/null || echo "0")
    IS_CAVA_DYNAMIC=""
    [[ "$CAVA_DYNAMIC_STATUS" == "1" ]] && IS_CAVA_DYNAMIC="(ON)" || IS_CAVA_DYNAMIC="(OFF)"

    cat <<INNEREOF
  Change Shell
󰝚  Cava Color Switch $IS_COLOR
󰝚  Cava Dynamic Exclusive $IS_CAVA_DYNAMIC
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
    *"Cava Color Switch"*) spawn "$HAKU_BIN_DIR/cava_manager.sh" --color-switch ;;
    *"Cava Dynamic Exclusive"*) spawn "$HAKU_BIN_DIR/cava_manager.sh" --toggle-dynamic ;;
    *"Settings Folder"*) spawn xdg-open "$HOME/hakucfg" ;;
    *"HakuMenu General Config"*) spawn code "$HOME/hakucfg/config/hakumenu-general.json" ;;
    *"Wifi"*) spawn nm-connection-editor ;;
    *"Bluetooth"*) spawn blueman-manager ;;
    *"Disk Manager"*) spawn gparted ;;
    *"Storage Manager"*) spawn kitty --class ncdu -e sudo ncdu / ;;
    *"Audio Control"*) spawn pavucontrol ;;
esac

exit 0
