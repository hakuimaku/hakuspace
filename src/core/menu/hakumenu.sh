#!/usr/bin/env bash

# This script is used to show the Haku Menu
# Need script: hm-general.sh, hm-theme.sh, hm-setting.sh

# argument --extend to set position of rofi window
if [[ "$1" == "--extend" || "$1" == "-e" ]]; then
  shift
  EXTEND=("$@")
else
  EXTEND=()
fi

rofi -show " General" \
  -p "Haku Menu - Search" \
  -i \
  "${EXTEND[@]}" \
  -modes " General:~/.local/bin/hm_general.sh, Theme:~/.local/bin/hm_theme.sh, Setting:~/.local/bin/hm_setting.sh"