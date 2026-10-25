#!/usr/bin/env bash
set -euo pipefail

# Run the real workspace component in a private software offscreen window.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd -- "$repo_root"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
mkdir -p "$shell_root" "$test_root/src/core" "$test_root/home/hakucfg" "$test_root/runtime"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$shell_root/"
cp -R src/core/{backend,lib,theme} "$test_root/src/core/"
cp tests/hikai/wallpaper/harness/workspace.qml "$shell_root/shell.qml"
printf 'ACCENT_COLOR_BASED_ON_WALLPAPER=false\n' > "$test_root/home/hakucfg/setting.sh"
ffmpeg -v error -f lavfi -i color=c=teal:s=64x36 -frames:v 1 -threads 1 "$test_root/home/preview.png"
mkdir -p "${HAKUSPACE_WALLPAPER_ARTIFACT_DIR:-$test_root/artifacts}"
env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    -u DBUS_SESSION_BUS_ADDRESS -u NIRI_SOCKET -u HYPRLAND_INSTANCE_SIGNATURE -u MANGO_INSTANCE_SIGNATURE \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_CACHE_HOME="$test_root/home/.cache" \
    XDG_RUNTIME_DIR="$test_root/runtime" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    GSETTINGS_BACKEND=memory HAKUSPACE_WALLPAPER_TEST_NO_HANDOFF=1 HAKUSPACE_WALLPAPER_FIXTURE="$test_root/home" \
    HAKUSPACE_WALLPAPER_ARTIFACT_DIR="${HAKUSPACE_WALLPAPER_ARTIFACT_DIR:-$test_root/artifacts}" \
    timeout 30s quickshell -p "$shell_root/shell.qml" > "$test_root/test.log" 2>&1 || status=$?
cat "$test_root/test.log"
if [[ ${status:-0} -ne 0 ]] || ! rg -q 'Wallpaper workspace checks passed' "$test_root/test.log" || \
    rg -q 'TypeError|ReferenceError|Binding loop|Cannot assign|Failed to load configuration|Wallpaper workspace failed' "$test_root/test.log"; then
    exit 1
fi
