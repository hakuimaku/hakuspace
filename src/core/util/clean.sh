#!/usr/bin/env bash

echo "Cleaning cache and logs..."
echo "This will remove all files in ~/.cache and clear journal logs older than 2 weeks."

read -p "Are you sure you want to proceed? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Operation cancelled."
    exit 0
fi

rm -rf ~/.cache/*
if command -v yay &> /dev/null; then
    yay -Sc --noconfirm
elif command -v dnf &> /dev/null; then
    sudo dnf clean all
elif command -v nix-collect-garbage &> /dev/null; then
    nix-collect-garbage -d
fi
sudo journalctl --vacuum-time=2weeks
notify-send "Cache and logs cleaned!"