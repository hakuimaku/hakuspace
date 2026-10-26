#!/usr/bin/env bash

[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

if [[ "$WELCOME_MSG" == true ]]; then
    sleep 2
    # Wait for the selected shell's server without activating a competing daemon.
    gdbus wait --session --timeout 10 org.freedesktop.Notifications || exit 1
    notify-send "My master, $USER!" "Have a good day ✨" -i face-smile
fi

