#!/usr/bin/env bash

# This script opens the default web browser or the browser set for handling HTTPS links.

browser_desktop="$(xdg-mime query default x-scheme-handler/https 2>/dev/null)"
if [[ -n "$browser_desktop" ]]; then
    gtk-launch "$browser_desktop"
else
    xdg-open https:   # fallback
fi