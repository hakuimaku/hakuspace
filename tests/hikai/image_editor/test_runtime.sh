#!/usr/bin/env bash
# Exercise production editor surfaces on two private software-rendered Wayland outputs.
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
cd -- "$repo_root"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
mkdir -p "$shell_root" "$test_root/src/home/.local/bin" "$test_root/home/hakucfg" "$test_root/runtime" "$test_root/labwc" "$test_root/fixtures" "$test_root/bin"
chmod 700 "$test_root/runtime"
artifact_dir=${HAKUSPACE_IMAGE_EDITOR_ARTIFACT_DIR:-"$test_root/artifacts"}
mkdir -p "$artifact_dir"
cp tests/support/fixtures/wayland_{pointer,keyboard}.py "$test_root/fixtures/"
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$shell_root/"
cp tests/hikai/image_editor/harness/editor.qml "$shell_root/shell.qml"
ln -s "$repo_root/src/core/backend/media/image_edit_ctl.py" "$test_root/src/home/.local/bin/image_edit_ctl.py"
ln -s "$repo_root/src/core/backend/user/avatar_ctl.sh" "$test_root/src/home/.local/bin/avatar_ctl.sh"
magick -size 3840x2160 gradient:navy-white "$test_root/fixtures/source # with space.png"
cp "$test_root/fixtures/source # with space.png" "$test_root/fixtures/screenshot with space.png"
cp "$test_root/fixtures/source # with space.png" "$test_root/fixtures/screenshot clipboard failure.png"
source_hash=$(sha256sum "$test_root/fixtures/source # with space.png")
# Use the real clipboard provider, with one explicit failure path for the closing contract.
real_wl_copy=$(command -v wl-copy)
cat > "$test_root/bin/wl-copy" <<'COPY'
#!/bin/sh
[ ! -f "$IMAGE_EDITOR_FIXTURE/fail-clipboard" ] || exit 1
exec "$IMAGE_EDITOR_REAL_WL_COPY" "$@"
COPY
chmod +x "$test_root/bin/wl-copy"
printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
printf 'ACCENT_COLOR_BASED_ON_WALLPAPER=false\n' > "$test_root/home/hakucfg/setting.sh"
cat > "$test_root/start.sh" <<'START'
#!/usr/bin/env bash
set -euo pipefail
wlr-randr --output HEADLESS-1 --custom-mode 1280x800@60Hz --output HEADLESS-2 --custom-mode 1280x800@60Hz
exec quickshell -p "$1"
START
env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE \
    -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 -u DBUS_SESSION_BUS_ADDRESS \
    HOME="$test_root/home" XDG_CACHE_HOME="$test_root/home/.cache" XDG_CONFIG_HOME="$test_root/home/.config" \
    XDG_RUNTIME_DIR="$test_root/runtime" XDG_CURRENT_DESKTOP=labwc QT_QPA_PLATFORM=wayland \
    QT_QUICK_BACKEND=software WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman \
    IMAGE_EDITOR_REAL_WL_COPY="$real_wl_copy" IMAGE_EDITOR_FIXTURE="$test_root/fixtures" IMAGE_EDITOR_ARTIFACTS="$artifact_dir" PATH="$test_root/bin:$PATH" \
    timeout 55s dbus-run-session -- labwc -C "$test_root/labwc" -S "bash $test_root/start.sh $shell_root/shell.qml" > "$test_root/test.log" 2>&1 || status=$?
cp "$test_root/test.log" "$artifact_dir/runtime.log"
if [[ ${status:-0} -ne 0 ]] || ! rg -q 'Image editor runtime checks passed' "$test_root/test.log" || \
    rg -q 'TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration|Image editor runtime failed' "$test_root/test.log"; then
    cat "$test_root/test.log"
    exit 1
fi
[[ $(sha256sum "$test_root/fixtures/source # with space.png") == "$source_hash" ]]
[[ $(magick identify -format '%wx%h' "$test_root/fixtures/export.png") == 2160x2160 ]]
cmp "$test_root/fixtures/clipboard.png" "$test_root/fixtures/screenshot with space.png"
[[ $(magick identify -format '%wx%h' "$test_root/home/.local/share/hakuspace/user/avatar.png") == 512x512 ]]
[[ $(magick identify -format '%wx%h' "$test_root/fixtures/screenshot with space.png") == 1920x1080 ]]
[[ $(magick identify -format '%wx%h' "$test_root/fixtures/screenshot clipboard failure.png") == 2880x1620 ]]
[[ -z $(find "$test_root/runtime" -maxdepth 1 -name 'hikai-image-editor-*' -print -quit) ]]
echo 'Image editor output and cleanup checks passed'
