#!/bin/bash

APP_CLASS="cavaunderbar"

run_cava() {
    kitty --class="cavaunderbar" \
            --config NONE \
            -o background_opacity=0 \
            -o background=#000000 \
            -o font_size=5 \
            -o window_padding_width=0 \
            -o hide_window_decorations=yes \
            -e cava -p ~/.config/cava/config_underbar &

    niri-float-sticky -ipc set_sticky -app-id "cavaunderbar"
}

if pgrep -f "$APP_CLASS" > /dev/null; then
    pkill -f "$APP_CLASS" 
else
    run_cava
fi