#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

# Resolve repository assets independently of the caller's working directory.
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/../../.." && pwd)"
cd -- "$REPO_ROOT"

# Exercise native Theme pages without applying desktop or compositor settings.
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
mkdir -p "$shell_root" "$test_root/home/.local/bin" "$test_root/src/home/.local" "$test_root/runtime" "$test_root/labwc"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{services,components,config} "$shell_root/"
cp tests/hikai/settings/harness/theme_action_menu.qml "$shell_root/shell.qml"
cp tests/support/fixtures/wayland_{keyboard,pointer}.py "$test_root/"
cp src/core/backend/theme/theme_ctl.sh src/core/backend/user/hikai_settings_ctl.py "$test_root/home/.local/bin/"
cp src/core/theme/accent_palette.py "$test_root/home/.local/bin/"
cp src/core/lib/{haku_theme.sh,haku_state.sh,haku_state.py,haku_cache.py,accent_color.sh} "$test_root/home/.local/bin/"
ln -s "$test_root/home/.local/bin" "$test_root/src/home/.local/bin"
ln -s "$test_root/home/.local/state" "$test_root/src/home/.local/state"
cat > "$test_root/render.sh" <<'RENDER'
#!/usr/bin/env bash
set -euo pipefail
source "$HOME/.local/bin/haku_theme.sh"
jq -n --arg font "$FONT_FAMILY" --argjson fontSize "$FONT_SIZE" --arg accentSeed "$ACCENT_SEED" --arg accentDark "$ACCENT_DARK" --arg accentLight "$ACCENT_LIGHT" \
    '{font: $font, fontSize: $fontSize, accentSeed: $accentSeed, accentDark: $accentDark, accentLight: $accentLight}' > "$THEME_RENDER_DIR/quickshell.json.tmp"
mv "$THEME_RENDER_DIR/quickshell.json.tmp" "$THEME_RENDER_DIR/quickshell.json"
RENDER
# Shared-page probes can read fixtures but cannot perform session actions.
for controller in clipboard_ctl.sh session_exit_ctl.sh record_ctl.sh gen_shortcut.sh niri_animation_ctl.sh; do
    cat > "$test_root/home/.local/bin/$controller" <<'READ_ONLY'
#!/bin/sh
case "$1" in
    list|list-sources|--list-json) printf '[]\n' ;;
    ensure-watchers|process-report) exit 0 ;;
    *) printf 'Unexpected fixture action: %s\n' "$1" >&2; exit 64 ;;
esac
READ_ONLY
done
# Supply nested navigation data without invoking the Niri backend.
cat > "$test_root/home/.local/bin/niri_animation_ctl.sh" <<'ANIMATIONS'
#!/bin/sh
case "$1" in
    list) printf '[{"mode":"WindowOpen","option":"Fade","active":true},{"mode":"WindowOpen","option":"Slide","active":false},{"mode":"WindowClose","option":"Fade","active":true}]\n' ;;
    *) printf 'Unexpected fixture action: %s\n' "$1" >&2; exit 64 ;;
esac
ANIMATIONS
# Populate scrollable lists without changing the live clipboard, recording or session.
cat > "$test_root/home/.local/bin/record_ctl.sh" <<'RECORD'
#!/bin/sh
case "$1" in
    list-sources) printf '[{"id":"fixture.microphone","description":"Fixture Microphone"}]\n' ;;
    *) printf 'Unexpected fixture action: %s\n' "$1" >&2; exit 64 ;;
esac
RECORD
cat > "$test_root/home/.local/bin/clipboard_ctl.sh" <<'CLIPBOARD'
#!/bin/sh
case "$1" in
    ensure-watchers) exit 0 ;;
    list) for index in $(seq 1 30); do printf '%s\tFixture clipboard entry %s\n' "$index" "$index"; done ;;
    *) printf 'Unexpected fixture action: %s\n' "$1" >&2; exit 64 ;;
esac
CLIPBOARD
printf '#!/bin/sh\nexit 0\n' > "$test_root/home/.local/bin/appearance_ctl.sh"
chmod +x "$test_root/render.sh" "$test_root/home/.local/bin/"*.sh
HOME="$test_root/home" bash -c 'source "$HOME/.local/bin/haku_theme.sh"; theme_set_seed "#88c0d0"; theme_save_state'
HOME="$test_root/home" bash "$test_root/render.sh"
printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
export THEME_TEST_ROOT="$test_root" THEME_TEST_SIZE=${THEME_TEST_SIZE:-1920x1080}
export THEME_ARTIFACT_DIR=${THEME_ARTIFACT_DIR:-/tmp/hikai-theme-artifacts}
mkdir -p "$THEME_ARTIFACT_DIR"
export HAKUSPACE_GEN_STYLE="$test_root/render.sh" HAKUSPACE_APPLY_STYLE=/usr/bin/true HAKUSPACE_STRICT_ASSETS=0
export HAKUSPACE_HIKAI_SETTINGS_FILE="$test_root/home/hakucfg/hikai/hikai-shell.json"
cat > "$test_root/start.sh" <<'START'
#!/usr/bin/env bash
set -euo pipefail
wlr-randr --output HEADLESS-1 --custom-mode "$THEME_TEST_SIZE"
exec quickshell -p "$THEME_TEST_ROOT/src/home/.config/quickshell/hakuspace/shell.qml"
START
env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE -u GDK_BACKEND \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_RUNTIME_DIR="$test_root/runtime" \
    XDG_CURRENT_DESKTOP=labwc QT_QPA_PLATFORM=wayland WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_RENDERER=pixman \
    timeout 120s dbus-run-session -- labwc -C "$test_root/labwc" -S "bash $test_root/start.sh" > "$test_root/runtime.log" 2>&1 || status=$?
cat "$test_root/runtime.log"
[[ ${status:-0} == 0 ]]
rg -q 'Theme Action Menu checks passed' "$test_root/runtime.log"
! rg -q 'TypeError|ReferenceError|Binding loop|is not a type|Failed to load configuration|Theme Action Menu failed|Unexpected fixture action|ActionMenuSurface:.*(failed|cannot)' "$test_root/runtime.log"
