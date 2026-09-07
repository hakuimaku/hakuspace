#!/bin/bash

# Haku Menu - User Custom General Menu
# You can customize this script to add your own menu items and actions.

spawn() { ( "$@" & ) >/dev/null 2>&1; disown; }

if [[ $# -eq 0 ]]; then
    # Menu items displayed
    # You can customize the menu items and their corresponding actions below.
    # The format is: "Menu Item" followed by the action to be performed when selected.
    cat <<'EOF'
  App Menu
  Code Editor
  Browser
  Screen Record
  Local Send
  File Manager
  Quit
EOF
    exit 0
fi

# Handle menu actions based on the selected item
# Make sure to match the "Menu Item" text exactly as it appears in the menu.
chosen="$*"
case "$chosen" in
    *"App Menu"*) spawn rofi -show drun ;;
    *"Code Editor"*) spawn code ;;
    *"Browser"*) spawn firefox ;;
    *"Screen Record"*) spawn $HOME/.local/bin/record.sh ;;
    *"Local Send"*) spawn localsend ;;
    *"File Manager"*) spawn thunar ;;
    *"Quit"*) spawn $HOME/.local/bin/shutdown.sh ;;
esac

exit 0