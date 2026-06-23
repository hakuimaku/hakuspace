#!/bin/bash
set -euo pipefail

# This script is used to show the Haku Menu, which is a custom menu for launching applications and performing various actions. It uses Rofi to display the menu and handle user input.
# Need script: hm-general.sh, hm-theme.sh, hm-setting.sh

rofi -show "󰮫 General" \
  -p "Haku Menu - Search" \
  -i \
  -modes "󰮫 General:~/.local/bin/hm-general.sh, Theme:~/.local/bin/hm-theme.sh, Setting:~/.local/bin/hm-setting.sh"