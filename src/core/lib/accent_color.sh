#!/usr/bin/env bash

ACCENT_MIN_LUMINANCE="${ACCENT_MIN_LUMINANCE:-0.22}"

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

    awk -v r="$red" -v g="$green" -v b="$blue" -v min="$ACCENT_MIN_LUMINANCE" '
        function srgb_to_linear(c) {
            c = c / 255.0
            return (c <= 0.03928) ? (c / 12.92) : ((c + 0.055) / 1.055) ^ 2.4
        }
        function luminance(r, g, b) {
            return 0.2126 * srgb_to_linear(r) + 0.7152 * srgb_to_linear(g) + 0.0722 * srgb_to_linear(b)
        }
        BEGIN {
            t = 0
            while (t < 1 && luminance(r + (255 - r) * t, g + (255 - g) * t, b + (255 - b) * t) < min)
                t += 0.02
            printf "#%02x%02x%02x\n", r + (255 - r) * t + 0.5, g + (255 - g) * t + 0.5, b + (255 - b) * t + 0.5
        }
    '
}