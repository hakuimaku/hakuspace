#!/usr/bin/env bash
set -euo pipefail

# Keep both the compositor and every backend write in a disposable session.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd -- "$repo_root"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
artifact_dir=${HAKUSPACE_LEFTBAR_ARTIFACT_DIR:-/tmp/hikai-leftbar-evidence/runtime}
mkdir -p "$shell_root" "$test_root/src/core" "$test_root/home/hakucfg" "$test_root/runtime" "$test_root/labwc" "$artifact_dir"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{services,components,config} "$shell_root/"
cp -R src/core/{backend,lib,theme,state,sys} "$test_root/src/core/"
mkdir -p "$test_root/home/hakucfg/config"
cp src/home/hakucfg/config/{taskbar-pin-apps,hakumenu-general.json} "$test_root/home/hakucfg/config/"
# Mirror the installed helper paths inside the private source tree.
mkdir -p "$test_root/src/home/.local/bin" "$test_root/home/.local/state/hakuspace/state"
ln -s "$test_root/home/.local/state" "$test_root/src/home/.local/state"
while IFS= read -r source; do
    ln -s "$repo_root/$source" "$test_root/src/home/.local/bin/${source##*/}"
done < <(rg --files src/core -g '*.sh' -g '*.py')
cp tests/support/fixtures/wayland_keyboard.py "$test_root/keyboard.py"
cp tests/support/fixtures/wayland_pointer.py "$test_root/wayland_pointer.py"
cp "${HAKUSPACE_LEFTBAR_HARNESS:-tests/hikai/leftbar/harness/leftbar.qml}" "$shell_root/shell.qml"
cp tests/hikai/leftbar/harness/AnimationRecorder.qml "$shell_root/"
cp tests/hikai/leftbar/harness/tray_many.py "$test_root/tray_many.py"
cp tests/hikai/leftbar/harness/client.qml "$test_root/client.qml"
printf 'hikai\n' > "$test_root/home/.local/state/hakuspace/state/[shell].backend"
if [[ ${HAKUSPACE_LEFTBAR_FRAME_ONLY:-0} == 1 ]]; then
    # Maximize each native probe on its intended output, independently of focus.
    cat > "$test_root/labwc/rc.xml" <<'FRAME'
<labwc_config><windowRules>
<windowRule title="Leftbar frame primary"><action name="MoveToOutput" output="HEADLESS-1" /></windowRule>
<windowRule title="Leftbar frame secondary"><action name="MoveToOutput" output="HEADLESS-2" /></windowRule>
</windowRules></labwc_config>
FRAME
else
    printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
fi
printf 'ACCENT_COLOR_BASED_ON_WALLPAPER=false\n' > "$test_root/home/hakucfg/setting.sh"
# Choose deterministic artwork without touching the user's wallpaper library.
fixture_source=color=c=teal:s=320x180
case ${HAKUSPACE_LEFTBAR_WALLPAPER_ART:-teal} in
    white) fixture_source=color=c=white:s=320x180 ;;
    gradient) fixture_source=gradients=s=320x180:c0=crimson:c1=navy ;;
esac
ffmpeg -v error -f lavfi -i "$fixture_source" -frames:v 1 -threads 1 "$test_root/home/preview.png"
ffmpeg -v error -f lavfi -i color=c=white:s=320x180 -frames:v 1 -threads 1 "$test_root/home/white.png"
ffmpeg -v error -f lavfi -i gradients=s=320x180:c0=crimson:c1=navy -frames:v 1 -threads 1 "$test_root/home/gradient.png"
cat > "$test_root/start.sh" <<'START'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n ${HAKUSPACE_LEFTBAR_OUTPUT_SIZE:-} ]]; then
    wlr-randr --output HEADLESS-1 --custom-mode "$HAKUSPACE_LEFTBAR_OUTPUT_SIZE" --scale "${HAKUSPACE_LEFTBAR_OUTPUT_SCALE:-1}" --output HEADLESS-2 --custom-mode "$HAKUSPACE_LEFTBAR_OUTPUT_SIZE" --scale "${HAKUSPACE_LEFTBAR_OUTPUT_SCALE:-1}"
elif [[ ${HAKUSPACE_LEFTBAR_OUTPUT_PRESET:-} == v3 ]]; then
    wlr-randr --output HEADLESS-1 --custom-mode 1280x720 --output HEADLESS-2 --custom-mode 1648x928
elif [[ ${HAKUSPACE_LEFTBAR_MIXED_OUTPUTS:-0} == 1 ]]; then
    wlr-randr --output HEADLESS-1 --custom-mode 1366x768 --output HEADLESS-2 --custom-mode 1920x1080 --scale 1.25
fi
wlr-randr --json > "$HAKUSPACE_LEFTBAR_ARTIFACT_DIR/outputs.json"
quickshell -p "$2" > "$HAKUSPACE_LEFTBAR_ARTIFACT_DIR/client.log" 2>&1 &
export HAKUSPACE_LEFTBAR_CLIENT_PID=$!
trap 'kill "$HAKUSPACE_LEFTBAR_CLIENT_PID" 2>/dev/null || true' EXIT
quickshell -p "$1"
START
env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE -u GDK_BACKEND \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_CACHE_HOME="$test_root/home/.cache" \
    XDG_STATE_HOME="$test_root/home/.local/state" XDG_RUNTIME_DIR="$test_root/runtime" \
    WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman \
    QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND="${HAKUSPACE_LEFTBAR_QT_BACKEND-software}" QSG_INFO="${HAKUSPACE_LEFTBAR_QSG_INFO:-0}" GSETTINGS_BACKEND=memory \
    HAKUSPACE_WALLPAPER_TEST_NO_HANDOFF=1 HAKUSPACE_LEFTBAR_ARTIFACT_DIR="$artifact_dir" \
    HAKUSPACE_LEFTBAR_POINTER="$test_root/wayland_pointer.py" HAKUSPACE_LEFTBAR_TRAY="$test_root/tray_many.py" HAKUSPACE_LEFTBAR_FIXTURE="$test_root/home/preview.png" HAKUSPACE_LEFTBAR_KEYBOARD="$test_root/keyboard.py" \
    timeout 120s dbus-run-session -- labwc -C "$test_root/labwc" \
    -S "bash $test_root/start.sh $shell_root/shell.qml $test_root/client.qml" > "$artifact_dir/runtime.log" 2>&1 || status=$?
cat "$artifact_dir/runtime.log"
if [[ ${status:-0} -ne 0 ]] || ! rg -q 'Leftbar runtime checks passed' "$artifact_dir/runtime.log" || \
    rg -q 'TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration|Leftbar failed' "$artifact_dir/runtime.log"; then
    exit 1
fi
