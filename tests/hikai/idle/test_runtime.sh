#!/usr/bin/env bash
set -euo pipefail

# Isolate monitors and all actions from the active desktop and system bus.
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"
test_root=$(mktemp -d /tmp/haku-idle-runtime.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/home/.config/quickshell/hakuspace"
bin_root="$test_root/home/.local/bin"
artifact_dir="${HAKUSPACE_IDLE_ARTIFACT_DIR:-/tmp/haku-idle-artifacts}"
mkdir -p "$shell_root" "$bin_root" "$test_root/runtime" "$test_root/labwc" "$artifact_dir" \
    "$test_root/home/.local/state/hakuspace/state"
chmod 700 "$test_root/runtime"
: > "$artifact_dir/actions.log"
mkdir -p "$shell_root/services"
cp src/home/.config/quickshell/hakuspace/services/{AppState,Env,ShellSettingsStore,IdleService}.qml "$shell_root/services/"
cp -R src/home/.config/quickshell/hakuspace/services/idle "$shell_root/services/"
for name in AppState Env ShellSettingsStore IdleService LockState; do
    printf 'singleton %s 1.0 %s.qml\n' "$name" "$name" >> "$shell_root/services/qmldir"
done
cp tests/hikai/idle/harness/idle.qml "$shell_root/shell.qml"
cp src/core/backend/user/hikai_settings_ctl.py "$bin_root/"
printf 'classic\n' > "$test_root/home/.local/state/hakuspace/state/[shell].backend"
printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
cat > "$shell_root/services/LockState.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property bool locked: false
    property bool secure: false
    function requestLock() { locked = true; return "ok" }
}
QML
# Replace action boundaries, including power, before the compositor is started.
for name in idle_actions.sh power_ctl.sh; do
    cat > "$bin_root/$name" <<'SH'
#!/bin/sh
if [ "$1" = --owner ]; then shift 2; fi
printf '%s %s\n' "${0##*/}" "$*" >> "$HAKUSPACE_IDLE_ACTION_LOG"
SH
done
printf '#!/bin/sh\nif [ "$1" = --status-json ]; then echo '\''{"manual":false,"audio":false,"inhibited":false}'\''; fi\nexit 0\n' > "$bin_root/idle_inhibit.sh"
cat > "$bin_root/idle_session_watch.py" <<'PY'
#!/usr/bin/env python3
import json
import os
import sys
print(json.dumps({"event": "ready"}), flush=True)
for line in sys.stdin:
    with open(os.environ["HAKUSPACE_IDLE_ACTION_LOG"], "a") as stream:
        stream.write("bridge " + line)
PY
chmod +x "$bin_root/"*
cat > "$test_root/start.sh" <<'SH'
#!/usr/bin/env bash
exec qs -p "$1"
SH
# Software rendering checks protocol and lifecycle behavior, not GPU performance.
env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u DBUS_SYSTEM_BUS_ADDRESS \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_RUNTIME_DIR="$test_root/runtime" \
    PATH="$bin_root:$PATH" WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman \
    QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software HAKUSPACE_IDLE_TEST=1 \
    HAKUSPACE_IDLE_ACTION_LOG="$artifact_dir/actions.log" \
    timeout 30s dbus-run-session -- labwc -C "$test_root/labwc" \
    -S "bash $test_root/start.sh $shell_root/shell.qml" > "$artifact_dir/runtime.log" 2>&1 || status=$?
cat "$artifact_dir/runtime.log"
if [[ ${status:-0} != 0 ]] || ! rg -q 'PASS: Hikai idle runtime' "$artifact_dir/runtime.log" || \
    rg -q 'FAIL:|TypeError|ReferenceError|Binding loop|Failed to load configuration' "$artifact_dir/runtime.log"; then exit 1; fi
python3 - "$artifact_dir/actions.log" <<'PY'
"""Confirm that the real service dispatched recovery and secure-only stub suspend."""
from pathlib import Path
import sys
actions = Path(sys.argv[1]).read_text().splitlines()
assert "idle_actions.sh dim 10" in actions, actions
assert "idle_actions.sh restore" in actions, actions
assert "idle_actions.sh off" in actions, actions
assert "bridge secure 1" in actions, actions
assert actions.count("power_ctl.sh suspend") == 1, actions
assert actions.count("idle_actions.sh recover") >= 2, actions
print("PASS: isolated idle action dispatch; suspend was stubbed")
PY
