#!/usr/bin/env bash

echo "Probing Picker IPC..."
mkfifo /tmp/pp
cat /tmp/pp &
qs -c hakuspace ipc call picker open "/tmp/pp" '{"prompt":"Probe","items":["a","b"]}'

echo "Waiting a bit..."
sleep 2

echo "Recent QS logs:"
qs log -c hakuspace | tail -n 20

rm -f /tmp/pp
