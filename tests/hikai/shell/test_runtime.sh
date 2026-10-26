#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Resolve repository assets independently of the caller's working directory.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../../.." && pwd)"
cd -- "$REPO_ROOT"

# Preserve shell-relative paths while keeping preferences and runtime files disposable.
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
mkdir -p "$shell_root" "$test_root/src/core/backend/user" "$test_root/runtime"
chmod 700 "$test_root/runtime"
artifact_dir=${HAKUSPACE_TEST_ARTIFACT_DIR:-"$test_root/artifacts"}
mkdir -p "$artifact_dir"
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$shell_root/"
cp src/core/backend/user/{hikai_settings_ctl.py,taskbar_pins_ctl.py} "$test_root/src/core/backend/user/"
cp src/home/hakucfg/config/taskbar-pin-apps "$test_root/taskbar-pin-apps"
if [[ ${1:-} == --headless ]]; then
    cp tests/hikai/shell/harness/topbar.qml "$shell_root/shell.qml"
    mkdir -p "$test_root/labwc" "$test_root/home"
    printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
    cat > "$test_root/start.sh" <<'START'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${HAKUSPACE_TEST_SCALE:-1} == 1.25 ]]; then
    wlr-randr --output HEADLESS-1 --scale 1.25 --output HEADLESS-2 --scale 1.25
    wlr-randr
fi
exec quickshell -p "$1"
START
    # A separate compositor and D-Bus session cannot take over the user's shell.
    env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
        -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE \
        -u GDK_BACKEND HOME="$test_root/home" XDG_CURRENT_DESKTOP=labwc \
        XDG_CONFIG_HOME="$test_root/home/.config" XDG_RUNTIME_DIR="$test_root/runtime" \
        WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman \
        QT_QPA_PLATFORM=wayland HAKUSPACE_GEOMETRY_ARTIFACT_DIR="$artifact_dir" HAKUSPACE_HIKAI_SETTINGS_FILE="$test_root/hakucfg/hikai/hikai-shell.json" \
        HAKUSPACE_TASKBAR_PINS_FILE="$test_root/taskbar-pin-apps" \
        timeout 60s dbus-run-session -- labwc -C "$test_root/labwc" \
        -S "bash $test_root/start.sh $shell_root/shell.qml" > "$test_root/quickshell.log" 2>&1 || status=$?
else
    cp tests/hikai/settings/harness/settings.qml "$shell_root/shell.qml"
    # Exercise both missing-file startup and a read-only legacy migration in QML.
    for scenario in missing v1 v3 v4; do
        cp src/home/hakucfg/config/taskbar-pin-apps "$test_root/taskbar-pin-apps"
        if [[ $scenario == v1 ]]; then
            printf '%s\n' '{"version":1,"appearance":{"baseRadius":12,"surfaceTone":"dark"},"topbar":{}}' > "$test_root/hakucfg/hikai/hikai-shell.json"
        elif [[ $scenario == v3 || $scenario == v4 ]]; then
            python3 - "$test_root/hakucfg/hikai/hikai-shell.json" "$scenario" <<'PY'
"""Remove new fields to exercise legacy Dock schemas."""
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
values = json.loads(path.read_text())
values["version"] = int(sys.argv[2][1:])
values["appearance"].pop("colorMode")
for key in ("style", "showTrash", "showDevices"):
    values["dock"].pop(key, None)
if values["version"] == 3:
    values["dock"].pop("hoverLift")
    values["dock"].pop("hoverScale")
path.write_text(json.dumps(values))
PY
        fi
        env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
            -u GDK_BACKEND XDG_RUNTIME_DIR="$test_root/runtime" QT_QPA_PLATFORM=offscreen \
            HAKUSPACE_HIKAI_SETTINGS_FILE="$test_root/hakucfg/hikai/hikai-shell.json" \
            HAKUSPACE_TASKBAR_PINS_FILE="$test_root/taskbar-pin-apps" \
            timeout 10s quickshell -p "$shell_root/shell.qml" > "$test_root/$scenario.log" 2>&1 || status=$?
        cat "$test_root/$scenario.log" >> "$test_root/quickshell.log"
        if [[ ${status:-0} -ne 0 ]]; then break; fi
    done
fi
cat "$test_root/quickshell.log"
if [[ ${status:-0} -ne 0 ]] || ! grep -Eq 'Hikai (settings|runtime) checks passed' "$test_root/quickshell.log" ||
    grep -Eq 'TypeError|ReferenceError|is not a type|Binding loop|Hikai (settings|runtime) failed|Failed to load configuration' "$test_root/quickshell.log"; then
    exit 1
fi
python3 - "$test_root/hakucfg/hikai/hikai-shell.json" "$test_root/taskbar-pin-apps" <<'PY'
"""Confirm that Reset followed by Apply reached disk in the isolated runtime."""
import json
import sys
from pathlib import Path
import re

values = json.loads(Path(sys.argv[1]).read_text())
assert values["version"] == 7
assert values["roundedScreen"] == {"radius": 20, "borderThickness": 4}
assert values["appearance"] == {"baseRadius": 12, "surfaceTone": "dark", "colorMode": "dark"}
assert all(values["topbar"].values())
assert values["dock"] == {"visibilityMode": "autohide", "exclusiveSpace": False, "iconSize": 36,
                          "hoverLift": 14, "hoverScale": 0, "showTrash": True, "showDevices": True}
assert set(re.findall(r'"size"\s*:\s*(\d+)', Path(sys.argv[2]).read_text())) == {"36"}
PY

if [[ ${1:-} == --headless ]]; then
    python3 tests/geometry/screen/test_pixels.py "$artifact_dir"
fi
