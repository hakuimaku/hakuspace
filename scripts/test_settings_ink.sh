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
cp src/core/backend/user/{setting_ctl.py,hikai_settings_ctl.py,hikai_wallpaper_settings_ctl.py,hakucfg_editor_ctl.py,avatar_ctl.sh,text_store_ctl.sh} "$test_root/home/.local/bin/"
cp src/core/backend/theme/theme_ctl.sh "$test_root/home/.local/bin/theme_ctl_impl.sh"
cp src/core/lib/{haku_theme.sh,haku_state.sh,accent_color.sh} "$test_root/home/.local/bin/"
# Exercise canonical font persistence while rendering only the private test theme.
cat > "$test_root/font-render.sh" <<'FONT_RENDER'
#!/usr/bin/env bash
set -euo pipefail
source "$HOME/.local/bin/haku_theme.sh"
jq -n --arg font "$FONT_FAMILY" --argjson fontSize "$FONT_SIZE" \
    '{font: $font, fontSize: $fontSize, accent: "#88c0d0"}' > "$THEME_RENDER_DIR/quickshell.json"
FONT_RENDER
cat > "$test_root/home/.local/bin/theme_ctl.sh" <<'FONT_CTL'
#!/usr/bin/env bash
if [[ $1 != status && -e $INK_TEST_ROOT/font-save-failure ]]; then
    printf 'font fixture save failure\n' >&2
    exit 1
fi
exec "$HOME/.local/bin/theme_ctl_impl.sh" "$@"
FONT_CTL
chmod +x "$test_root/font-render.sh" "$test_root/home/.local/bin/"theme_ctl*.sh
HOME="$test_root/home" bash "$test_root/font-render.sh"
mkdir -p "$test_root/src/home/.local"
ln -s "$test_root/home/.local/bin" "$test_root/src/home/.local/bin"
ln -s "$test_root/home/.local/state" "$test_root/src/home/.local/state"
python3 - "$test_root/avatar-wide.png" <<'PYIMAGE'
"""Write a small deterministic wide PNG for the real crop pipeline."""
from pathlib import Path
import struct
import sys
import zlib

def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))

width, height = 960, 480
rows = b''.join(b'\x00' + b'\x28\x80\xc0' * width for _ in range(height))
Path(sys.argv[1]).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))
PYIMAGE
# Sidebar probe helpers report an empty clipboard without starting real watchers.
cat > "$test_root/home/.local/bin/clipboard_ctl.sh" <<'CLIPBOARD'
#!/bin/sh
case "$1" in
    list) printf '[]\n' ;;
    ensure-watchers) exit 0 ;;
    *) exit 0 ;;
esac
CLIPBOARD
chmod +x "$test_root/home/.local/bin/clipboard_ctl.sh"
printf '#!/usr/bin/env python3\nprint("{}")\n' > "$test_root/home/.local/bin/quick_actions_ctl.py"
chmod +x "$test_root/home/.local/bin/quick_actions_ctl.py"
cp src/core/backend/system/hakuspace_info_ctl.py "$test_root/home/.local/bin/"
cp src/home/hakucfg/{setting.sh,config/taskbar-pin-apps} "$test_root/home/hakucfg/"
printf 'alpha\n' > "$test_root/home/hakucfg/wm/hyprland-custom.lua"
printf 'beta\n' > "$test_root/home/hakucfg/wm/niri-custom.kdl"
printf 'gamma\n' > "$test_root/home/hakucfg/config/cava-layer"
# Exercise scrolling and elision in the configuration dropdown.
for index in $(seq 1 12); do
    printf 'fixture\n' > "$test_root/home/hakucfg/config/example-configuration-with-a-long-name-that-must-stay-inside-the-dropdown-and-keep-the-filename-and-its-extension-readable-$index.conf"
done
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
export INK_SETTINGS_ONLY=${INK_SETTINGS_ONLY:-0}
export INK_SIZE=${INK_SIZE:-1920x1080}
export INK_ARTIFACT_DIR=${INK_ARTIFACT_DIR:-/tmp/ink-settings-artifacts}
mkdir -p "$INK_ARTIFACT_DIR"
export HAKUSPACE_USER_DIR="$test_root/home/.local/share/hakuspace/user"
export HAKUSPACE_SCRATCH_DIR="$test_root/scratch"
export HAKUSPACE_SETTING_FILE="$test_root/home/hakucfg/setting.sh"
export HAKUSPACE_HIKAI_SETTINGS_FILE="$test_root/home/hakucfg/hikai/hikai-shell.json"
export HAKUSPACE_HAKUCFG_ROOT="$test_root/home/hakucfg" HAKUSPACE_CODE_BIN=/usr/bin/true
export HAKUSPACE_TASKBAR_PINS_FILE="$test_root/home/hakucfg/taskbar-pin-apps"
export HAKUSPACE_GEN_STYLE="$test_root/font-render.sh" HAKUSPACE_APPLY_STYLE=/usr/bin/true
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

if [[ $INK_SETTINGS_ONLY == 1 ]]; then exit 0; fi

# Validate the saved crop dimensions and check that no staged PNG survived cleanup.
python3 - "$HAKUSPACE_USER_DIR/avatar.png" "$test_root/runtime" "$HAKUSPACE_SCRATCH_DIR/quick-note.txt" <<'PYCROP'
"""Read PNG dimensions directly without adding an imaging dependency."""
from pathlib import Path
import struct
import sys

image = Path(sys.argv[1]).read_bytes()
assert image[:8] == b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>II', image[16:24]) == (512, 512)
assert not list(Path(sys.argv[2]).glob('hikai-avatar-*.png'))
assert Path(sys.argv[3]).read_text() == 'ownership test'
PYCROP
