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

    local is_dark
    is_dark=$(awk -v r="$red" -v g="$green" -v b="$blue" '
        function srgb_to_linear(c) {
            c = c / 255.0
            return (c <= 0.03928) ? (c / 12.92) : ((c + 0.055) / 1.055) ^ 2.4
        }
        BEGIN {
            R = srgb_to_linear(r)
            G = srgb_to_linear(g)
            B = srgb_to_linear(b)
            # WCAG relative luminance
            L = 0.2126 * R + 0.7152 * G + 0.0722 * B
            
            # If L is low, the color is dark. A common threshold for contrast 
            # against white vs black is 0.179 (or around there).
            # We use 0.179 to determine if we should fallback to a lighter color.
            print (L < 0.179) ? 1 : 0
        }
    ')

    if [[ "$is_dark" == "1" ]]; then
        printf '%s\n' "$fallback"
    else
        printf '%s\n' "${color,,}"
    fi
}