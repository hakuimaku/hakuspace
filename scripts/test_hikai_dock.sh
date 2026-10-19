#!/usr/bin/env bash
set -euo pipefail

# Mirror shell-relative paths with private state, settings and shared pin fixtures.
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
mkdir -p "$shell_root" "$test_root/src/core/backend/user" "$test_root/runtime" "$test_root/labwc" \
    "$test_root/src/home/.local/state/hakuspace/state" "$test_root/home/hakucfg/config"
mkdir -p "$test_root/bin" "$test_root/data/applications"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{components,services} "$shell_root/"
cp src/core/backend/user/{hikai_settings_ctl.py,taskbar_pins_ctl.py,dock_app_ctl.py,dock_icon_watch.py,setting_ctl.py} "$test_root/src/core/backend/user/"
if [[ ${HAKUSPACE_HAKUMENU_TEST:-0} == 1 ]]; then
    cp scripts/hikai_hakumenu_harness.qml "$shell_root/shell.qml"
elif [[ ${HAKUSPACE_DOCK_INPUT:-0} == 1 ]]; then
    cp scripts/hikai_dock_input_harness.qml "$shell_root/shell.qml"
else
    cp scripts/hikai_dock_harness.qml "$shell_root/shell.qml"
fi
cp src/home/hakucfg/config/taskbar-pin-apps "$test_root/home/hakucfg/config/"
printf '0\n' > "$test_root/src/home/.local/state/hakuspace/state/taskbar_manual_state"
printf 'hikai\n' > "$test_root/src/home/.local/state/hakuspace/state/shell_backend"
printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
cat > "$test_root/bin/fixture-app" <<'APP'
#!/usr/bin/env bash
printf 'launched\n' >> "$HAKUSPACE_TEST_LAUNCH_LOG"
APP
cat > "$test_root/bin/gio" <<'GIO'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$HAKUSPACE_TEST_GIO_LOG"
GIO
chmod +x "$test_root/bin/fixture-app" "$test_root/bin/gio"
printf '[Desktop Entry]\nType=Application\nName=Dock Launch Fixture\nExec=%s/bin/fixture-app\nIcon=application-x-executable\n' \
    "$test_root" > "$test_root/data/applications/hikai-dock-launch.desktop"
# Exercise the UI confirmation contract without signalling the Quickshell test client.
if [[ ${HAKUSPACE_DOCK_INPUT:-0} == 1 ]]; then
    cat > "$test_root/src/core/backend/user/dock_app_ctl.py" <<'KILL_FIXTURE'
import json
import os
from pathlib import Path
import sys
roots = json.loads(sys.argv[3])
with Path(os.environ['HAKUSPACE_TEST_TERMINATION_LOG']).open('a') as log:
    log.write(json.dumps(roots) + '\n')
print(json.dumps({'status': 'terminated'} if roots else
                 {'status': 'confirmation', 'ramMb': 512, 'thresholdMb': 300,
                  'roots': [{'pid': 12345, 'startTime': 'fixture'}]}))
KILL_FIXTURE
fi
# Nested modes use the existing display solely as their parent surface.
mode=${1:---headless}
parent_display=${WAYLAND_DISPLAY:-wayland-0}
if [[ $parent_display != /* ]]; then parent_display="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$parent_display"; fi
quit_command=:
pointer_output=""
case "$mode" in
    --headless)
        if [[ ${HAKUSPACE_HAKUMENU_TEST:-0} == 1 ]]; then pointer_output=HEADLESS-1; fi
        compositor=labwc
        backend_env=(WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman)
        launch=(labwc -C "$test_root/labwc" -S "bash $test_root/start.sh")
        ;;
    --niri)
        compositor=niri
        backend_env=(WAYLAND_DISPLAY="$parent_display")
        printf 'spawn-at-startup "bash" "%s/start.sh"\n' "$test_root" > "$test_root/niri.kdl"
        quit_command='niri msg action quit --skip-confirmation'
        launch=(niri -c "$test_root/niri.kdl")
        ;;
    --mango)
        compositor=mango
        backend_env=(WAYLAND_DISPLAY="$parent_display" WLR_BACKENDS=wayland WLR_WL_OUTPUTS=1)
        : > "$test_root/mango.conf"
        quit_command='mmsg dispatch quit'
        launch=(mango -c "$test_root/mango.conf" -s "bash $test_root/start.sh")
        ;;
    --current)
        compositor=${XDG_CURRENT_DESKTOP:-unknown}
        backend_env=(WAYLAND_DISPLAY="$parent_display")
        launch=(bash "$test_root/start.sh")
        ;;
    *) printf 'Usage: %s [--headless|--niri|--mango|--current]\n' "$0" >&2; exit 2 ;;
esac
cat > "$test_root/start.sh" <<START
#!/usr/bin/env bash
status=0
if [[ \${HAKUSPACE_HAKUMENU_TEST:-0} == 1 && \${XDG_CURRENT_DESKTOP:-} == labwc ]]; then
    wlr-randr --output HEADLESS-2 --custom-mode 1024x768 --pos 1280,0 || exit 1
fi
quickshell -p "$shell_root/shell.qml" > "$test_root/shell.log" 2>&1 || status=\$?
$quit_command
exit \$status
START
# Every mode isolates preferences, manual state, pins and the D-Bus session.
env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE -u GDK_BACKEND \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_RUNTIME_DIR="$test_root/runtime" \
    XDG_CURRENT_DESKTOP="$compositor" "${backend_env[@]}" \
    PATH="$test_root/bin:$PATH" XDG_DATA_HOME="$test_root/data" \
    HAKUSPACE_TEST_TERMINATION_LOG="$test_root/termination.log" \
    HAKUSPACE_TEST_LAUNCH_LOG="$test_root/launch.log" HAKUSPACE_TEST_GIO_LOG="$test_root/gio.log" \
    QT_QPA_PLATFORM=wayland HAKUSPACE_HIKAI_SETTINGS_FILE="$test_root/home/hakucfg/hikai/hikai-shell.json" \
    HAKUSPACE_TEST_TASKBAR_CTL="$PWD/src/core/backend/desktop/taskbar_ctl.sh" \
    HAKUSPACE_TEST_POINTER="$PWD/scripts/wayland_pointer_fixture.py" \
    HAKUSPACE_TEST_POINTER_OUTPUT="$pointer_output" \
    HAKUSPACE_TEST_KEYBOARD="$PWD/scripts/wayland_keyboard_fixture.py" \
    HAKUSPACE_TASKBAR_PINS_FILE="$test_root/home/hakucfg/config/taskbar-pin-apps" \
    timeout 40s dbus-run-session -- "${launch[@]}" > "$test_root/compositor.log" 2>&1 || status=$?
cat "$test_root/compositor.log" "${test_root}/shell.log" > "$test_root/dock.log"
cat "$test_root/dock.log"
if [[ ${status:-0} -ne 0 ]] || ! grep -Eq 'Hikai (Dock|HakuMenu) checks passed' "$test_root/dock.log" || \
    grep -Eq 'TypeError|ReferenceError|is not a type|Binding loop|Cannot assign|non-existent|Failed to load configuration|Hikai (Dock|HakuMenu) failed' "$test_root/dock.log"; then
    exit 1
fi
