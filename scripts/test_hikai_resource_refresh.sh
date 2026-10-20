#!/usr/bin/env bash
set -euo pipefail

# Use private settings, icon themes and wallpaper files with the actual QML components.
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
shell_root="$test_root/src/home/.config/quickshell/hakuspace"
bin_root="$test_root/src/home/.local/bin"
mkdir -p "$shell_root" "$bin_root" "$test_root/src/core/backend/user" "$test_root/runtime" \
    "$test_root/src/home/.local/state/hakuspace/state" "$test_root/home/.config/gtk-3.0" \
    "$test_root/home/hakucfg/config" "$test_root/home/.local/share/applications"
chmod 700 "$test_root/runtime"
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$shell_root/"
cp scripts/hikai_resource_refresh_harness.qml "$shell_root/shell.qml"
cp src/core/backend/user/{dock_icon_watch.py,hikai_settings_ctl.py,taskbar_pins_ctl.py} "$test_root/src/core/backend/user/"
printf '#!/usr/bin/env bash\nexec bash %q "$@"\n' "$PWD/src/core/backend/theme/wallpaper_ctl.sh" > "$bin_root/wallpaper_ctl.sh"
chmod +x "$bin_root/wallpaper_ctl.sh"
printf '%s\n' '{"group/pin":{"modules":["image#probe"]},"image#probe":{"on-click":"true"}}' > "$test_root/home/hakucfg/config/taskbar-pin-apps"
printf '[Desktop Entry]\nType=Application\nName=Probe\nExec=true\nIcon=probe\n' > "$test_root/home/.local/share/applications/probe.desktop"
printf '1\n' > "$test_root/src/home/.local/state/hakuspace/state/dockbar_manual_state"
cat > "$test_root/mutate.py" <<'PY'
import io
from PIL import Image
from pathlib import Path
import sys
root = Path(__file__).parent
home = root / 'home'
walls = home / 'Pictures/Wallpapers'
videos = home / 'Videos/Wallpapers'
config = home / '.config/gtk-3.0/settings.ini'
# Tiny valid PNG previews keep the fixture independent of external imaging programs.
preview = io.BytesIO()
Image.new('RGB', (2, 2), 'red').save(preview, format='PNG')
png = preview.getvalue()
def icon(theme, color):
    folder = home / '.local/share/icons' / theme
    (folder / '48x48/apps').mkdir(parents=True, exist_ok=True)
    (folder / 'index.theme').write_text('[Icon Theme]\nName=' + theme + '\nDirectories=48x48/apps\n\n[48x48/apps]\nSize=48\nType=Fixed\nContext=Applications\n')
    (folder / '48x48/apps/probe.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48"><rect width="48" height="48" fill="' + color + '"/></svg>')
action = sys.argv[1]
if action == 'init':
    walls.mkdir(parents=True)
    (videos / '.thumbnails').mkdir(parents=True)
    (walls / 'initial.png').write_bytes(png)
    icon('Fixture', 'red')
    config.write_text('[Settings]\ngtk-icon-theme-name=Fixture\n')
elif action == 'add':
    (walls / 'fresh # image.png').write_bytes(png)
    (walls / 'initial.png').write_bytes(png)
    (videos / 'new.mp4').touch()
    (videos / '.thumbnails/new.png').write_bytes(png)
elif action == 'remove':
    (walls / 'initial.png').unlink()
    (videos / 'new.mp4').unlink()
elif action == 'icon-blue':
    icon('Fixture', 'blue')
elif action == 'theme':
    icon('Other', 'lime')
    config.write_text('[Settings]\ngtk-icon-theme-name=Other\n')
PY
python3 "$test_root/mutate.py" init
# Offscreen rendering exercises file monitors without touching the compositor or user theme.
env -u WAYLAND_DISPLAY -u DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" \
    XDG_DATA_HOME="$test_root/home/.local/share" XDG_RUNTIME_DIR="$test_root/runtime" \
    GSETTINGS_BACKEND=memory QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    HAKUSPACE_RESOURCE_FIXTURE="$test_root" HAKUSPACE_HIKAI_SETTINGS_FILE="$test_root/settings.json" \
    timeout 25s quickshell -p "$shell_root/shell.qml" > "$test_root/test.log" 2>&1 || status=$?
cat "$test_root/test.log"
if [[ ${status:-0} -ne 0 ]] || ! rg -q 'Hikai resource refresh checks passed' "$test_root/test.log" || \
    rg -q 'TypeError|ReferenceError|Binding loop|Cannot assign|Failed to load configuration|resource refresh failed|Error decoding|libpng error' "$test_root/test.log"; then
    exit 1
fi
python3 - "$test_root" <<'PY'
from pathlib import Path
import sys
from PIL import Image
root = Path(sys.argv[1])
for name, color in (('red', (255, 0, 0)), ('blue', (0, 0, 255)), ('green', (0, 255, 0))):
    pixel = Image.open(root / ('icon-' + name + '.png')).convert('RGB').getpixel((32, 31))
    assert pixel == color, (name, pixel)
print('Rendered icon pixels update after file edits and theme changes')
PY
