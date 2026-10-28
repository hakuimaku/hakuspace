#!/usr/bin/env bash
set -euo pipefail

# Validate the Session page without loading the production shell or idle service.
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"
test_root=$(mktemp -d /tmp/haku-idle-session.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/home/.config/quickshell/hakuspace"
bin_root="$test_root/home/.local/bin"
artifact_dir="${HAKUSPACE_IDLE_ARTIFACT_DIR:-/tmp/haku-idle-artifacts}"
mkdir -p "$shell_root" "$bin_root" "$test_root/runtime" "$test_root/home/hakucfg/config" "$artifact_dir"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{services,components,config} "$shell_root/"
cp tests/hikai/idle/harness/session.qml "$shell_root/shell.qml"
cp src/core/backend/user/{hikai_settings_ctl.py,setting_ctl.py} "$bin_root/"
printf '#!/bin/sh\nprintf '\''font=monospace\\nsize=14\\n'\''\n' > "$bin_root/theme_ctl.sh"
chmod +x "$bin_root/theme_ctl.sh"
cp src/home/hakucfg/setting.sh "$test_root/home/hakucfg/setting.sh"
env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_RUNTIME_DIR="$test_root/runtime" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 15s qs -p "$shell_root/shell.qml" > "$artifact_dir/session.log" 2>&1 || status=$?
cat "$artifact_dir/session.log"
if [[ ${status:-0} != 0 ]] || ! rg -q 'PASS: Session idle settings runtime' "$artifact_dir/session.log" || \
    rg -q 'FAIL:|TypeError|ReferenceError|Binding loop|Failed to load configuration' "$artifact_dir/session.log"; then exit 1; fi
