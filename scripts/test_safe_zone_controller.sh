#!/usr/bin/env bash
set -euo pipefail

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/components/base" "$test_root/services" "$test_root/runtime"
cp src/home/.config/quickshell/hakuspace/components/base/SafeZoneController.qml "$test_root/components/base/"
cp src/home/.config/quickshell/hakuspace/services/Interaction.qml "$test_root/services/"
printf 'module services\nsingleton Interaction 1.0 Interaction.qml\n' > "$test_root/services/qmldir"
cp scripts/safe_zone_controller_harness.qml "$test_root/shell.qml"

env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    -u GDK_BACKEND XDG_RUNTIME_DIR="$test_root/runtime" QT_QPA_PLATFORM=offscreen \
    timeout 8s quickshell -p "$test_root/shell.qml"
