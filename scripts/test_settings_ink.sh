#!/usr/bin/env bash
set -euo pipefail

# Run the actual Settings surfaces against disposable preferences and config files.
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
mkdir -p "$shell_root" "$test_root/src/core/backend/user" "$test_root/src/core/backend/system" \
    "$test_root/home/.local/bin" "$test_root/home/hakucfg/wm" "$test_root/home/hakucfg/config" "$test_root/runtime" "$test_root/labwc"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$shell_root/"
cp scripts/settings_ink_harness.qml "$test_root/harness.qml"
# Introduce the real page after startup to exercise Quickshell's warm type scanner.
cp "$shell_root/components/settings/ShellSettingsPage.qml" "$test_root/ShellSettingsPage.qml"
printf 'import QtQuick\nItem {}\n' > "$shell_root/components/settings/ShellSettingsPage.qml"
cat > "$shell_root/shell.qml" <<'QML'
import QtQuick
import Quickshell
import "components/settings" as Settings
ShellRoot {
    Item { Settings.ShellSettingsPage {} }
}
QML
cp src/core/backend/user/{setting_ctl.py,hikai_settings_ctl.py,hakucfg_editor_ctl.py} "$test_root/home/.local/bin/"
cp src/core/backend/system/hakuspace_info_ctl.py "$test_root/home/.local/bin/"
cp src/home/hakucfg/{setting.sh,config/taskbar-pin-apps} "$test_root/home/hakucfg/"
printf 'alpha\n' > "$test_root/home/hakucfg/wm/hyprland-custom.lua"
printf 'beta\n' > "$test_root/home/hakucfg/wm/niri-custom.kdl"
printf 'gamma\n' > "$test_root/home/hakucfg/config/cava-layer"
printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
# Input helpers connect only to the display selected by this runner.
cp scripts/wayland_{keyboard,pointer}_fixture.py "$test_root/"
cat > "$test_root/start.sh" <<'START'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${INK_CURRENT:-0} != 1 ]]; then
    wlr-randr --output HEADLESS-1 --custom-mode "${INK_SIZE:-1920x1080}" --pos 0,0 \
        --output HEADLESS-2 --custom-mode "${INK_SIZE:-1920x1080}" --pos "${INK_SIZE%x*},0"
fi
quickshell -p "$INK_SHELL" &
shell_pid=$!
trap 'kill "$shell_pid" 2>/dev/null || true' EXIT
# Wait for parser completion and fail immediately if a reload cannot load types.
wait_loaded() {
    local expected=$1 attempt count
    for attempt in $(seq 1 100); do
        if ! kill -0 "$shell_pid" 2>/dev/null || rg -q 'Failed to load configuration' "$INK_TEST_ROOT/runtime.log"; then return 1; fi
        count=$(rg -c 'Configuration Loaded' "$INK_TEST_ROOT/runtime.log" || true)
        if [[ ${count:-0} -ge $expected ]]; then return 0; fi
        sleep 0.05
    done
    return 1
}
wait_loaded 1
cp "$INK_TEST_ROOT/ShellSettingsPage.qml" "$(dirname "$INK_SHELL")/components/settings/ShellSettingsPage.qml"
wait_loaded 2
cp "$INK_TEST_ROOT/harness.qml" "$INK_SHELL"
wait "$shell_pid"
trap - EXIT
START
export INK_SHELL="$shell_root/shell.qml" INK_TEST_ROOT="$test_root"
export INK_SIZE=${INK_SIZE:-1920x1080}
export INK_ARTIFACT_DIR=${INK_ARTIFACT_DIR:-/tmp/ink-settings-artifacts}
mkdir -p "$INK_ARTIFACT_DIR"
export HAKUSPACE_SETTING_FILE="$test_root/home/hakucfg/setting.sh"
export HAKUSPACE_HIKAI_SETTINGS_FILE="$test_root/home/hakucfg/hikai/hikai-shell.json"
export HAKUSPACE_HAKUCFG_ROOT="$test_root/home/hakucfg" HAKUSPACE_CODE_BIN=/usr/bin/true
export HAKUSPACE_TASKBAR_PINS_FILE="$test_root/home/hakucfg/taskbar-pin-apps"
if [[ ${1:-} == --current ]]; then
    INK_CURRENT=1 HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" \
        timeout 45s bash "$test_root/start.sh" > "$test_root/runtime.log" 2>&1 || status=$?
else
    env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
        -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE -u GDK_BACKEND \
        HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_RUNTIME_DIR="$test_root/runtime" \
        XDG_CURRENT_DESKTOP=labwc QT_QPA_PLATFORM=wayland WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman \
        timeout 45s dbus-run-session -- labwc -C "$test_root/labwc" -S "bash $test_root/start.sh" > "$test_root/runtime.log" 2>&1 || status=$?
fi
cat "$test_root/runtime.log"
if [[ ${status:-0} -ne 0 ]] || ! rg -q 'Ink Settings checks passed' "$test_root/runtime.log" || \
    rg -q 'TypeError|ReferenceError|Binding loop|is not a type|Failed to load configuration|Ink Settings failed' "$test_root/runtime.log"; then
    exit 1
fi
