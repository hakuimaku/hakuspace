#!/bin/bash

CUSTOM_SCRIPT="$HOME/hakuspace-control/hakumenu-general-custom.sh"

# Check if a custom script exists and is executable
if [[ -f "$CUSTOM_SCRIPT" ]]; then
    # Check syntax
    if bash -n "$CUSTOM_SCRIPT" 2>/dev/null; then
        
        # Get the exit code of the custom script
        bash "$CUSTOM_SCRIPT" "$@"
        EXIT_CODE=$?
        
        # If the custom script runs successfully (returns 0), stop here (using user custom).
        # If it fails (returns something other than 0), proceed to the fallback below.
        if [[ $EXIT_CODE -eq 0 ]]; then
            exit 0
        fi
    fi
fi

# Base fallback, use my own default :)
notify-send "Haku Menu" "Your custom Haku Menu failed or is not present. Using default menu instead."
spawn() { ( "$@" & ) >/dev/null 2>&1; disown; }

if [[ $# -eq 0 ]]; then
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

chosen="$*"
case "$chosen" in
    *"App Menu"*) spawn rofi -show drun ;;
    *"Code Editor"*) spawn code ;;
    *"Browser"*) spawn zen-browser ;;
    *"Screen Record"*) spawn $HOME/.local/bin/record.sh ;;
    *"Local Send"*) spawn localsend ;;
    *"File Manager"*) spawn thunar ;;
    *"Quit"*) spawn $HOME/.local/bin/shutdown.sh ;;
esac

exit 0