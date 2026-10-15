#!/usr/bin/env bash
set -euo pipefail

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/services/WM" "$test_root/bin" "$test_root/runtime"
cp src/home/.config/quickshell/hakuspace/services/WM/{WM,NullBackend}.qml "$test_root/services/WM/"
printf 'module services\nsingleton WM 1.0 WM/WM.qml\n' > "$test_root/services/qmldir"
cat > "$test_root/shell.qml" <<'EOF_QML'
import QtQuick
import "services"

Item {
    Component.onCompleted: {
        if (WM.backendName !== "none" || !WM.labwcSession || !WM.quitSession()) {
            console.error("Labwc quit request was not accepted")
        }
    }
}
EOF_QML
cat > "$test_root/bin/labwc" <<'EOF_LABWC'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$TEST_LABWC_LOG"
EOF_LABWC
chmod +x "$test_root/bin/labwc"

env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    -u GDK_BACKEND -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET \
    -u MANGO_INSTANCE_SIGNATURE -u LABWC_PID XDG_CURRENT_DESKTOP=labwc \
    XDG_RUNTIME_DIR="$test_root/runtime" QT_QPA_PLATFORM=offscreen \
    TEST_LABWC_LOG="$test_root/labwc.log" PATH="$test_root/bin:$PATH" \
    timeout 3s quickshell -p "$test_root/shell.qml" > "$test_root/quickshell.log" 2>&1 || status=$?
if [[ ${status:-0} -ne 0 && ${status:-0} -ne 124 ]] ||
   [[ "$(cat "$test_root/labwc.log" 2>/dev/null)" != "--exit" ]]; then
    cat "$test_root/quickshell.log" >&2
    exit 1
fi
