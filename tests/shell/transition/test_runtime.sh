#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Resolve repository assets independently of the caller's working directory.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../../.." && pwd)"
cd -- "$REPO_ROOT"

# Keep the real singleton and animation engine inside a disposable runtime.
test_root=$(mktemp -d)
trap 'if [[ $? != 0 && -f "$test_root/result.log" ]]; then cat "$test_root/result.log"; fi; rm -rf "$test_root"' EXIT
mkdir -p "$test_root/runtime" "$test_root/home"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$test_root/"
cp tests/shell/transition/harness/transition.qml "$test_root/shell.qml"

# Normal startup and bootstrap must disagree only on the initial chrome gate.
for bootstrap in '' classic-to-hikai; do
    env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
        -u GDK_BACKEND HOME="$test_root/home" XDG_RUNTIME_DIR="$test_root/runtime" \
        QT_QPA_PLATFORM=offscreen HAKUSPACE_SHELL_TRANSITION_BOOTSTRAP="$bootstrap" \
        timeout 10s quickshell -p "$test_root/shell.qml" > "$test_root/result.log" 2>&1
    cat "$test_root/result.log"
    grep -q 'Shell transition checks passed' "$test_root/result.log"
done

# A separate headless compositor exercises actual per-output layer surfaces.
if [[ ${1:-} == --headless ]]; then
    mkdir -p "$test_root/labwc"
    printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
    cat > "$test_root/start.sh" <<'START'
#!/usr/bin/env bash
set -euo pipefail
wlr-randr --output HEADLESS-1 --custom-mode 1920x1080 --scale 1 \
    --output HEADLESS-2 --custom-mode 2560x1440 --scale 1.25
exec quickshell -p "$1"
START
    env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
        -u GDK_BACKEND HOME="$test_root/home" XDG_RUNTIME_DIR="$test_root/runtime" \
        XDG_CURRENT_DESKTOP=labwc WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 \
        WLR_RENDERER=pixman QT_QPA_PLATFORM=wayland HAKUSPACE_TRANSITION_SURFACES=1 \
        timeout 15s dbus-run-session -- labwc -C "$test_root/labwc" \
        -S "bash $test_root/start.sh $test_root/shell.qml" > "$test_root/result.log" 2>&1
    cat "$test_root/result.log"
    grep -q 'Shell transition checks passed' "$test_root/result.log"

    # Deploy the real entrypoint into a private home for IPC and reload coverage.
    mkdir -p "$test_root/home/.config/quickshell" "$test_root/home/.local/bin" \
        "$test_root/home/hakucfg/config"
    cp -R src/home/.config/quickshell/hakuspace "$test_root/home/.config/quickshell/"
    cp src/home/hakucfg/config/taskbar-pin-apps "$test_root/home/hakucfg/config/"
    python3 - "$test_root/home/.local/bin" <<'PY'
"""Flatten controllers without following the user's installed script links."""
from pathlib import Path
import shutil
import sys
for source in Path('src/core').rglob('*'):
    if source.is_file() and source.name != 'README.md':
        shutil.copy2(source, Path(sys.argv[1]) / source.name)
PY
    cp tests/shell/transition/ipc_probe.py "$test_root/ipc_probe.py"
    env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
        -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE \
        -u GDK_BACKEND HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" \
        XDG_DATA_HOME="$test_root/home/.local/share" XDG_STATE_HOME="$test_root/home/.local/state" \
        XDG_RUNTIME_DIR="$test_root/runtime" XDG_CURRENT_DESKTOP=labwc \
        WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman QT_QPA_PLATFORM=wayland \
        timeout 60s dbus-run-session -- labwc -C "$test_root/labwc" \
        -S "python3 $test_root/ipc_probe.py" > "$test_root/result.log" 2>&1
    cat "$test_root/result.log"
    grep -q 'Shell transition IPC, reload, hotplug and repeated lifecycle checks passed' "$test_root/result.log"
    if grep -Eq 'TypeError|ReferenceError|Failed to load configuration|Cannot assign' "$test_root/result.log"; then
        exit 1
    fi
fi
