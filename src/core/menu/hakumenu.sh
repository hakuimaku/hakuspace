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

rofi -show "" \
  -p "Haku Menu - Search" \
  -i \
  "${EXTEND[@]}" \
  -modes ":~/.local/bin/hm_general.sh,:~/.local/bin/hm_theme.sh,:~/.local/bin/hm_setting.sh"