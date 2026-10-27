#!/usr/bin/env bash
set -euo pipefail

# Run real monitor/input contracts on two private outputs; every system action is fake.
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"
test_root=$(mktemp -d /tmp/haku-idle-hardening-wl.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/runtime" "$test_root/home" "$test_root/labwc"
chmod 700 "$test_root/runtime"
printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
# Exclude desktop service activation so portals cannot mount GVFS inside the fixture.
cat > "$test_root/bus.conf" <<'XML'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
XML
export HAKUSPACE_IDLE_ARTIFACT_DIR="${HAKUSPACE_IDLE_ARTIFACT_DIR:-/tmp/haku-idle-hardening/contracts}"
env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" XDG_RUNTIME_DIR="$test_root/runtime" \
    WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman QT_QUICK_BACKEND=software \
    QT_QPA_PLATFORM=wayland PYTHONDONTWRITEBYTECODE=1 \
    timeout 90s dbus-run-session --config-file "$test_root/bus.conf" -- labwc -C "$test_root/labwc" \
    -S "python3 $REPO_ROOT/tests/hikai/idle/test_hardening.py $*"
