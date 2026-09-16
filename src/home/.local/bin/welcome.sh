#!/usr/bin/env bash

[ -f "$HOME/hakucfg/setting.sh" ] && source "$HOME/hakucfg/setting.sh"

if [[ "$WELCOME_MSG" == true ]]; then
    sleep 2
    notify-send "My master, $USER!" "Have a good day ✨" -i face-smile
fi

