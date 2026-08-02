#!/bin/bash

spawn() { ( "$@" & ) >/dev/null 2>&1; disown; }

if [[ $# -eq 0 ]]; then
    cat <<'EOF'
  App Menu
󰨞  Visual Studio Code
  Browser
  Screen Record
  Local Send
  File Manager
  Show Desktop Icons
  Quit
EOF
    exit 0
fi

chosen="$*"
case "$chosen" in
    *"App Menu"*) spawn rofi -show drun ;;
    *"Visual Studio Code"*) spawn code ;;
    *"Browser"*) spawn zen-browser ;;
    *"Screen Record"*) spawn $HOME/.local/bin/record.sh ;;
    *"Local Send"*) spawn localsend ;;
    *"File Manager"*) spawn thunar ;;
    *"Show Desktop Icons"*) spawn $HOME/.local/bin/desktop_icons_manager.sh --toggle ;;
    *"Quit"*) spawn $HOME/.local/bin/shutdown.sh ;;
esac

exit 0