#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Resolve repository assets independently of the caller's working directory.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../../.." && pwd)"
cd -- "$REPO_ROOT"

# Copy only wallpaper dependencies into a disposable HOME and shell tree.
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
mkdir -p "$shell_root" "$test_root/home/Pictures/Wallpapers" "$test_root/home/Videos/Wallpapers" \
    "$test_root/home/hakucfg" "$test_root/runtime" "$test_root/labwc" "$test_root/src/core" "${HAKUSPACE_WALLPAPER_ARTIFACT_DIR:-$test_root/artifacts}"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$shell_root/"
cp -R src/core/{backend,lib,theme} "$test_root/src/core/"
cp tests/support/fixtures/wayland_{keyboard,pointer}.py "$test_root/"
printf 'ACCENT_COLOR_BASED_ON_WALLPAPER=false\n' > "$test_root/home/hakucfg/setting.sh"
# Media fixtures include audio and a frame rate requiring the low-memory proxy.
ffmpeg -v error -f lavfi -i color=c=navy:s=1920x1080:r=60 -t 0.5 -c:v libx264 -preset ultrafast -threads 2 -pix_fmt yuv420p "$test_root/home/Videos/Wallpapers/clip.mp4"
cp "$test_root/home/Videos/Wallpapers/clip.mp4" "$test_root/home/Videos/Wallpapers/second.mp4"
ffmpeg -v error -f lavfi -i color=c=green:s=64x36 -frames:v 1 -threads 1 "$test_root/home/Pictures/Wallpapers/forest # one.png"
cp "$test_root/home/Pictures/Wallpapers/forest # one.png" "$test_root/home/Pictures/Wallpapers/other.png"
printf 'broken image fixture\n' > "$test_root/home/broken.png"
if [[ ${1:-} == --presentation ]]; then
    # Five items of each kind exercise every carousel depth on the same path.
    for index in 1 2 3; do
        cp "$test_root/home/Pictures/Wallpapers/other.png" "$test_root/home/Pictures/Wallpapers/extra-$index.png"
        cp "$test_root/home/Videos/Wallpapers/second.mp4" "$test_root/home/Videos/Wallpapers/extra-$index.mp4"
    done
    cp tests/hikai/wallpaper/harness/panel.qml "$shell_root/shell.qml"
    expected='Wallpaper presentation checks passed'
elif [[ ${1:-} == --flow ]]; then
    printf 'broken video fixture\n' > "$test_root/home/broken.mp4"
    cp tests/hikai/wallpaper/harness/flow.qml "$shell_root/shell.qml"
    expected='Wallpaper flow checks passed'
elif [[ ${1:-} == --surface ]]; then
    cp tests/hikai/wallpaper/harness/surface.qml "$shell_root/shell.qml"
    expected='Wallpaper surface checks passed'
else
    cp tests/hikai/wallpaper/harness/browser.qml "$shell_root/shell.qml"
    expected='Wallpaper browser reload checks passed'
fi
printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
cat > "$test_root/start.sh" <<'START'
#!/usr/bin/env bash
set -euo pipefail
wlr-randr --output HEADLESS-1 --custom-mode 1920x1080@60Hz --output HEADLESS-2 --custom-mode 3440x1440@60Hz
exec quickshell -p "$1"
START
# A private compositor exercises reload windows without reaching the user's desktop.
env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE \
        -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 -u DBUS_SESSION_BUS_ADDRESS \
        HOME="$test_root/home" XDG_CACHE_HOME="$test_root/home/.cache" XDG_CONFIG_HOME="$test_root/home/.config" \
        XDG_RUNTIME_DIR="$test_root/runtime" XDG_CURRENT_DESKTOP=labwc \
        QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software QT_FFMPEG_DECODING_HW_DEVICE_TYPES=, \
        WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman \
        HAKUSPACE_WALLPAPER_FIXTURE="$test_root/home" HAKUSPACE_WALLPAPER_TEST_NO_HANDOFF=1 \
        HAKUSPACE_WALLPAPER_ARTIFACT_DIR="${HAKUSPACE_WALLPAPER_ARTIFACT_DIR:-$test_root/artifacts}" \
        timeout 45s dbus-run-session -- labwc -C "$test_root/labwc" -S "bash $test_root/start.sh $shell_root/shell.qml" > "$test_root/test.log" 2>&1 || status=$?
cat "$test_root/test.log"
if [[ ${status:-0} -ne 0 ]] || ! rg -q "$expected" "$test_root/test.log" || \
    rg -v 'broken.png' "$test_root/test.log" | rg -q 'TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign.*undefined|Failed to load configuration|Failed to open reload popup|Wallpaper .* failed|Error decoding|libpng error'; then
    exit 1
fi
