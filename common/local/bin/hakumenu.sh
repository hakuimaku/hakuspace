#!/bin/bash
set -euo pipefail

# This script is used to show the Haku Menu
# Need script: hm-general.sh, hm-theme.sh, hm-setting.sh

# Change hakuimaku to your username if you want to access quickly in VS Code
# Access: file:///home/hakuimaku/.local/bin/hm-general.sh
# Access: file:///home/hakuimaku/.local/bin/hm-theme.sh
# Access: file:///home/hakuimaku/.local/bin/hm-setting.sh

rofi -show "󰮫 General" \
  -p "Haku Menu - Search" \
  -i \
  -modes "󰮫 General:~/.local/bin/hm-general.sh, Theme:~/.local/bin/hm-theme.sh, Setting:~/.local/bin/hm-setting.sh"