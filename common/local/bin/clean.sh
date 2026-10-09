#!/bin/bash

echo "Cleaning cache and logs..."
echo "This will remove all files in ~/.cache and clear journal logs older than 2 weeks."

read -p "Are you sure you want to proceed? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Operation cancelled."
    exit 0
fi

rm -rf ~/.cache/*
yay -Sc
sudo journalctl --vacuum-time=2weeks
notify-send "Cache and logs cleaned!"