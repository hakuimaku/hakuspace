#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Resolve repository assets independently of the caller's working directory.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../../.." && pwd)"
cd -- "$REPO_ROOT"

# Keep the runtime path short enough for Hyprland's Unix-domain socket names.
test_root=$(mktemp -d /tmp/hn.XXXX)
repo_root=$PWD
parent_display=${WAYLAND_DISPLAY:-wayland-0}
[[ $parent_display == /* ]] || parent_display="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$parent_display"
compositor_pid=""
cleanup() {
    [[ -z $compositor_pid ]] || kill "$compositor_pid" 2>/dev/null || true
    [[ -z $compositor_pid ]] || wait "$compositor_pid" 2>/dev/null || true
    rm -rf "$test_root"
}
trap cleanup EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
mkdir -p "$shell_root" "$test_root/home/.local/bin" "$test_root/home/hakucfg/config" "$test_root/data" \
    "$test_root/home/.local/state/hakuspace/state" \
    "$test_root/src/core/backend/user" "$test_root/src/home/.local/state/hakuspace/state"
chmod 700 "$test_root"
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$shell_root/"
cp tests/hikai/window_navigator/harness/navigator.qml "$shell_root/shell.qml"
cp src/core/backend/user/{hikai_settings_ctl.py,taskbar_pins_ctl.py,setting_ctl.py} "$test_root/src/core/backend/user/"
cp src/home/hakucfg/config/taskbar-pin-apps "$test_root/home/hakucfg/config/"
cp src/core/facade/window_navigator.sh "$test_root/home/.local/bin/"
printf 'hikai\n' > "$test_root/home/.local/state/hakuspace/state/[shell].backend"

# Route the production facade to this private Quickshell instance only.
cat > "$test_root/home/.local/bin/haku_backend_lib.sh" <<'LIB'
haku_qs_mode() { [[ ${HAKU_NAV_BACKEND:-hikai} == hikai ]]; }
haku_qs_ipc() { qs -p "$HAKU_NAV_SHELL" ipc call "$@"; }
LIB

# Mock the compositor only for the facade's Classic command-routing assertions.
mkdir -p "$test_root/mock"
cat > "$test_root/mock/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HAKU_NAV_LOG"
MOCK
chmod +x "$test_root/mock/hyprctl"
for operation in next previous overview-toggle commit cancel; do
    PATH="$test_root/mock:$PATH" HAKU_NAV_BACKEND=classic HAKU_NAV_LOG="$test_root/classic.log" \
        bash "$test_root/home/.local/bin/window_navigator.sh" "$operation"
done
python3 - "$test_root/classic.log" <<'PY'
from pathlib import Path
import sys
lines = Path(sys.argv[1]).read_text().splitlines()
assert len(lines) == 3, lines
assert 'cycle_next({next = true})' in lines[0] and 'bring_to_top()' in lines[0]
assert 'cycle_next({next = false})' in lines[1]
assert lines[2] == 'eval hl.plugin.scrolloverview.overview("toggle all")'
print('PASS: Classic facade routing and commit/cancel no-ops')
PY

# Load the actual navigator bindings and layer rule, with no unrelated desktop config.
cat > "$test_root/hyprland.lua" <<'LUA'
hl.config({animations = {enabled = false}, misc = {disable_hyprland_logo = true, disable_splash_rendering = true},
    input = {follow_mouse = 0}})
hl.monitor({output = "", mode = "preferred", position = "auto", scale = 1})
hl.layer_rule({name = "haku-window-navigator", match = {namespace = "hakuspace-window-navigator"}, no_anim = true})
LUA
sed -n '/-- Native Hikai navigation/,/-- Window management keybindings/p' src/home/.config/hypr/config/keybinding.lua >> "$test_root/hyprland.lua"
rg 'hl.bind.*window_navigator.sh' src/home/.config/hypr/config/plugin.lua --no-filename >> "$test_root/hyprland.lua"

# A nested Wayland backend avoids taking the DRM session from the real desktop.
env -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE \
    -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_DATA_HOME="$test_root/data" \
    XDG_RUNTIME_DIR="$test_root" WAYLAND_DISPLAY="$parent_display" AQ_DRM_DEVICES=/dev/null \
    HAKU_NAV_SHELL="$shell_root/shell.qml" \
    Hyprland -c "$test_root/hyprland.lua" > "$test_root/compositor.log" 2>&1 &
compositor_pid=$!

# Bound startup waits to report a failed compositor instead of hanging indefinitely.
for attempt in {1..100}; do
    [[ ! -S "$test_root/wayland-1" ]] || break
    if ! kill -0 "$compositor_pid" 2>/dev/null; then cat "$test_root/compositor.log"; exit 1; fi
    sleep 0.1
done
[[ -S "$test_root/wayland-1" ]] || { cat "$test_root/compositor.log"; exit 1; }
signature=$(basename "$(find "$test_root/hypr" -mindepth 1 -maxdepth 1 -type d | head -1)")
export XDG_RUNTIME_DIR="$test_root" HYPRLAND_INSTANCE_SIGNATURE="$signature"
errors=$(hyprctl configerrors)
[[ -z $errors ]] || { printf '%s\n' "$errors"; exit 1; }
hyprctl output create headless NAV-2 > /dev/null
hyprctl dispatch 'hl.dsp.focus({monitor = "WAYLAND-1"})' > /dev/null

status=0
env -u DISPLAY -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_DATA_HOME="$test_root/data" \
    WAYLAND_DISPLAY=wayland-1 XDG_CURRENT_DESKTOP=Hyprland QT_QPA_PLATFORM=wayland \
    HAKUSPACE_TEST_KEYBOARD="$repo_root/tests/support/fixtures/wayland_keyboard.py" \
    HAKUSPACE_TEST_POINTER="$repo_root/tests/support/fixtures/wayland_pointer.py" \
    HAKUSPACE_TEST_POINTER_OUTPUT=WAYLAND-1 \
    HAKUSPACE_HIKAI_SETTINGS_FILE="$test_root/home/hakucfg/hikai/hikai-shell.json" \
    HAKUSPACE_TASKBAR_PINS_FILE="$test_root/home/hakucfg/config/taskbar-pin-apps" \
    timeout 55s dbus-run-session -- qs -p "$shell_root/shell.qml" > "$test_root/shell.log" 2>&1 || status=$?
rg 'INFO: Configuration|WARN.*(qml|scene|quickshell)|ERROR|PASS:' "$test_root/shell.log" || true
if [[ $status != 0 ]] || ! rg -q 'PASS: Hikai Window Navigator runtime' "$test_root/shell.log" || \
    rg -q 'TypeError|ReferenceError|is not a type|Binding loop|Cannot assign|non-existent|Failed to load configuration|Window Navigator failed' "$test_root/shell.log"; then
    exit 1
fi
