#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Keep controller writes, generated theme and rendered artifacts outside the checkout.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../../.." && pwd)"
cd -- "$REPO_ROOT"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/home/.config/quickshell/hakuspace"
mkdir -p "$shell_root" "$test_root/home/.local/bin" "$test_root/home/hakucfg/config" "$test_root/runtime" "$test_root/home/.local/state/hakuspace/theme"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$shell_root/"
cp "$TEST_DIR/harness/light.qml" "$shell_root/shell.qml"
# Expose the same flattened script layout as an installed session.
while IFS= read -r source; do
    ln -s "$REPO_ROOT/$source" "$test_root/home/.local/bin/${source##*/}"
done < <(rg --files src/core -g '*.sh' -g '*.py')
# Observe only the preference and theme writes made by the production mode owner.
cat > "$test_root/home/.local/bin/gsettings" <<'GSETTINGS'
#!/bin/sh
if [ "$1" = list-schemas ]; then echo org.gnome.desktop.interface; exit 0; fi
if [ "$1 $2" = "get org.gnome.desktop.interface" ]; then
    case "$3" in gtk-theme) value=Hikaide ;; icon-theme) value=Hikaide-Symbols ;; *) exit 64 ;; esac
    if [ -f "$HOME/$3" ]; then value=$(cat "$HOME/$3"); fi
    printf "'%s'\n" "$value"
    exit 0
fi
[ "$1 $2" = "set org.gnome.desktop.interface" ] || exit 64
case "$3" in
    color-scheme) case "$4" in prefer-dark|prefer-light) ;; *) exit 64 ;; esac ;;
    gtk-theme|icon-theme) ;;
    *) exit 64 ;;
esac
sleep 0.05
printf '%s\n' "$4" > "$HOME/$3"
printf '%s %s\n' "$3" "$4" >> "$HOME/color-scheme-calls"
GSETTINGS
# Mode changes consume installed assets without needing a rebuild or recolor.
for name in Hikaide Hikaide-Light; do
    mkdir -p "$test_root/home/.themes/$name"
    printf '[Desktop Entry]\n' > "$test_root/home/.themes/$name/index.theme"
done
for name in Hikaide-Symbols Hikaide-Symbols-Light; do
    mkdir -p "$test_root/home/.icons/$name"
    printf '[Icon Theme]\n' > "$test_root/home/.icons/$name/index.theme"
done
# Kitty reload probes must never connect to sockets from the user's session.
printf '#!/bin/sh\nexit 1\n' > "$test_root/home/.local/bin/kitty"
chmod +x "$test_root/home/.local/bin/gsettings" "$test_root/home/.local/bin/kitty"
cp src/home/hakucfg/setting.sh "$test_root/home/hakucfg/setting.sh"
cp src/home/hakucfg/config/taskbar-pin-apps "$test_root/home/hakucfg/config/"
printf '%s\n' '{"accentSeed":"#a2cb8b","accentDark":"#a2cb8b","accentLight":"#2e4820","font":"monospace","fontSize":14}' > "$test_root/home/.local/state/hakuspace/theme/quickshell.json"
theme_before=$(sha256sum "$test_root/home/.local/state/hakuspace/theme/quickshell.json")
export HAKUSPACE_THEME_ARTIFACT_DIR="${HAKUSPACE_THEME_ARTIFACT_DIR:-/tmp/hikai-light-artifacts}"
mkdir -p "$HAKUSPACE_THEME_ARTIFACT_DIR"
# Offscreen software rendering tests bindings and pixels without claiming hardware performance.
env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    -u GDK_BACKEND -u NIRI_SOCKET -u HYPRLAND_INSTANCE_SIGNATURE \
    PATH="$test_root/home/.local/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_STATE_HOME="$test_root/home/.local/state" \
    XDG_RUNTIME_DIR="$test_root/runtime" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    HAKUSPACE_HIKAI_SETTINGS_FILE="$test_root/home/hakucfg/hikai/hikai-shell.json" \
    HAKUSPACE_TASKBAR_PINS_FILE="$test_root/home/hakucfg/config/taskbar-pin-apps" \
    timeout 25s quickshell -p "$shell_root/shell.qml" > "$HAKUSPACE_THEME_ARTIFACT_DIR/runtime.log" 2>&1
cat "$HAKUSPACE_THEME_ARTIFACT_DIR/runtime.log"
rg -q 'Hikai Light theme checks passed' "$HAKUSPACE_THEME_ARTIFACT_DIR/runtime.log"
! rg -q 'TypeError|ReferenceError|Binding loop|is not a type|Failed to load configuration|Light theme failed' "$HAKUSPACE_THEME_ARTIFACT_DIR/runtime.log"
[[ "$theme_before" == "$(sha256sum "$test_root/home/.local/state/hakuspace/theme/quickshell.json")" ]]
python3 - "$test_root/home/hakucfg/hikai/hikai-shell.json" <<'PY'
"""Confirm that preview-only resets leave the applied light preference intact."""
import json
import sys
from pathlib import Path

values = json.loads(Path(sys.argv[1]).read_text())
assert values["version"] == 9
assert values["appearance"]["colorMode"] == "light"
PY
