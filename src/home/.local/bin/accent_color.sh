#!/usr/bin/env bash

accent_color_or_fallback() {
    local color="${1:-}"
    local fallback="#ffffff"

    if [[ ! "$color" =~ ^#[0-9a-fA-F]{6}$ ]]; then
        printf '%s\n' "$fallback"
        return 0
    fi

    local red=$((16#${color:1:2}))
    local green=$((16#${color:3:2}))
    local blue=$((16#${color:5:2}))

    if (( red + green + blue < 180 )); then
        printf '%s\n' "$fallback"
    else
        printf '%s\n' "${color,,}"
    fi
}