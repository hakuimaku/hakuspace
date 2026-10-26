#!/usr/bin/env bash

# Validate seeds without changing their brightness before pair derivation.
accent_color_or_fallback() {
    local color="${1:-}"
    if [[ "$color" =~ ^#[0-9a-fA-F]{6}$ ]]; then
        printf '%s\n' "${color,,}"
    else
        printf '%s\n' '#ffffff'
    fi
}
