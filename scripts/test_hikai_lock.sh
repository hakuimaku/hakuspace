#!/usr/bin/env bash
set -euo pipefail

# 1. Pure geometry and morph keyframe verification
node scripts/test_lock_geometry.js

# 2. Isolated PAM + LockState + LockSurface runtime harness
test_root=$(mktemp -d)
trap 'if [[ $? != 0 && -f "$test_root/result.log" ]]; then cat "$test_root/result.log"; fi; rm -rf "$test_root"' EXIT
mkdir -p "$test_root/runtime" "$test_root/home" "$test_root/pam.d" \
    "$test_root/home/.config/quickshell/hakuspace" "$test_root/home/.local/bin"
chmod 700 "$test_root/runtime"

cat > "$test_root/pam.d/verify_pw.sh" <<'EOF'
#!/usr/bin/env bash
IFS= read -r -d '' pw || true
pw="${pw%$'\n'}"
if [[ "$pw" == "correct-pass" ]]; then
    exit 0
fi
exit 1
EOF
chmod +x "$test_root/pam.d/verify_pw.sh"

cat > "$test_root/pam.d/test-prompt" <<EOF
auth [success=1 default=ignore] pam_exec.so quiet expose_authtok $test_root/pam.d/verify_pw.sh
auth requisite pam_deny.so
auth required pam_permit.so
account required pam_permit.so
EOF

cat > "$test_root/pam.d/test-deny" <<'EOF'
auth required pam_deny.so
account required pam_permit.so
EOF

cat > "$test_root/pam.d/test-permit" <<'EOF'
auth required pam_permit.so
account required pam_permit.so
EOF

# Mirror installed paths so Env.binDir resolves to a harmless suspend stub.
cp -R src/home/.config/quickshell/hakuspace/{services,components} "$test_root/home/.config/quickshell/hakuspace/"
cp scripts/hikai_lock_harness.qml "$test_root/home/.config/quickshell/hakuspace/shell.qml"
cat > "$test_root/home/.local/bin/power_ctl.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HOME/suspend.calls"
sleep 0.15
EOF
chmod +x "$test_root/home/.local/bin/power_ctl.sh"

# Exercise both authored motion and direct-state accessibility behavior.
for reduced_motion in 0 1; do
    env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
        -u GDK_BACKEND HOME="$test_root/home" XDG_RUNTIME_DIR="$test_root/runtime" \
        QT_QPA_PLATFORM=offscreen HAKUSPACE_TEST_PAM_DIR="$test_root/pam.d" \
        HAKUSPACE_REDUCED_MOTION="$reduced_motion" \
        timeout 15s quickshell -p "$test_root/home/.config/quickshell/hakuspace/shell.qml" > "$test_root/result.log" 2>&1
    cat "$test_root/result.log"
    grep -q 'Hikai lock checks passed' "$test_root/result.log"
    if grep -Eq 'wrong-pass|correct-pass|TypeError|ReferenceError|Binding loop|Failed to load configuration' "$test_root/result.log"; then
        echo "Unexpected error or leaked secret in harness log" >&2
        exit 1
    fi
done
[[ "$(cat "$test_root/home/suspend.calls")" == $'suspend\nsuspend' ]]

# 3. Headless Wayland multi-output session lock + lock.sh routing & fallback verification
mkdir -p "$test_root/labwc" "$test_root/home/.config/quickshell" \
    "$test_root/home/.local/bin" "$test_root/home/.local/state/hakuspace/state" \
    "$test_root/home/hakucfg/config" "$test_root/mockbin"
printf '<labwc_config/>\n' > "$test_root/labwc/rc.xml"
cp -R src/home/.config/quickshell/hakuspace "$test_root/home/.config/quickshell/"
cp src/home/hakucfg/config/taskbar-pin-apps "$test_root/home/hakucfg/config/"

# Keep PAM test controls and a synthetic desktop confined to the copied shell.
python3 - "$test_root/home/.config/quickshell/hakuspace/shell.qml" <<'PY'
from pathlib import Path
import sys

shell = Path(sys.argv[1])
source = shell.read_text().replace('LockSession {}', 'LockSession { id: testedLockSession }', 1)
fixtures = '''
    IpcHandler {
        target: "lockTest"
        function authenticate(password: string): bool {
            LockState.pam.configDirectory = Quickshell.env("HAKUSPACE_TEST_PAM_DIR")
            LockState.pam.config = "test-prompt"
            return LockState.submit(password)
        }
        function releaseStatus(): string {
            return JSON.stringify({ active: testedLockSession.releaseActive,
                progress: testedLockSession.releaseProgress, reduced: LockState.reducedMotion })
        }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "hakuspace-lock-test-desktop"
            exclusionMode: ExclusionMode.Ignore
            color: "#246a8d"
            mask: Region {}
        }
    }
'''
head, tail = source.rsplit('}', 1)
shell.write_text(head + fixtures + '}' + tail)
PY

python3 - "$test_root/home/.local/bin" <<'PY'
from pathlib import Path
import shutil
import sys
for source in Path('src/core').rglob('*'):
    if source.is_file() and source.name != 'README.md':
        shutil.copy2(source, Path(sys.argv[1]) / source.name)
PY

cat > "$test_root/mockbin/hyprlock" <<EOF
#!/usr/bin/env bash
echo "mock-hyprlock \$*" >> "$test_root/hyprlock.calls"
exit 0
EOF
chmod +x "$test_root/mockbin/hyprlock"

# 3a. Classic mode routes to hyprlock
echo "classic" > "$test_root/home/.local/state/hakuspace/state/[shell].backend"
PATH="$test_root/mockbin:$PATH" HOME="$test_root/home" \
    XDG_STATE_HOME="$test_root/home/.local/state" XDG_RUNTIME_DIR="$test_root/runtime" \
    "$test_root/home/.local/bin/lock.sh" > "$test_root/classic_lock.log" 2>&1
grep -q '^mock-hyprlock' "$test_root/hyprlock.calls"

# 3b. Hikai mode when Quickshell is not running fails closed by falling back to hyprlock
: > "$test_root/hyprlock.calls"
echo "hikai" > "$test_root/home/.local/state/hakuspace/state/[shell].backend"
PATH="$test_root/mockbin:$PATH" HOME="$test_root/home" \
    XDG_STATE_HOME="$test_root/home/.local/state" XDG_RUNTIME_DIR="$test_root/runtime" \
    "$test_root/home/.local/bin/lock.sh" > "$test_root/fallback_lock.log" 2>&1
grep -q '^mock-hyprlock' "$test_root/hyprlock.calls"

# 3c. Hikai mode with live Quickshell in headless labwc locks natively via WlSessionLock across 2 outputs
: > "$test_root/hyprlock.calls"
cat > "$test_root/wayland_lock_probe.py" <<'PY'
import json
import os
import subprocess
import time
from pathlib import Path

# Query test-only controls without changing the production lock IPC interface.
def test_ipc(method, *arguments):
    return subprocess.check_output(
        ["qs", "-c", "hakuspace", "ipc", "call", "lockTest", method, *arguments],
        text=True, timeout=5).strip()


# Read native pixels from the isolated compositor, never from the user's desktop.
def output_pixels(output):
    image = subprocess.check_output(["grim", "-t", "ppm", "-o", output, "-"], timeout=5)
    magic, dimensions, maximum, pixels = image.split(b"\n", 3)
    assert magic == b"P6" and maximum == b"255", "unexpected grim pixel format"
    width, height = map(int, dimensions.split())
    center = ((height // 2) * width + width // 2) * 3
    return pixels[center:center + 3], pixels[:3]

subprocess.run([
    "wlr-randr",
    "--output", "HEADLESS-1", "--custom-mode", "1920x1080", "--scale", "1",
    "--output", "HEADLESS-2", "--custom-mode", "2560x1440", "--scale", "1.25",
], check=True)

runtime = subprocess.Popen(["qs", "-c", "hakuspace"])
try:
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        try:
            out = subprocess.check_output(
                ["qs", "-c", "hakuspace", "ipc", "call", "shell", "ping"],
                text=True, stderr=subprocess.DEVNULL, timeout=2).strip()
            if out == "pong":
                break
        except Exception:
            pass
        time.sleep(0.05)
    else:
        raise AssertionError("Quickshell did not become ready")

    # Invoke lock.sh in Hikai mode
    lock_sh = str(Path.home() / ".local/bin/lock.sh")
    subprocess.run([lock_sh], check=True, timeout=10)

    status = json.loads(subprocess.check_output(
        ["qs", "-c", "hakuspace", "ipc", "call", "lock", "status"],
        text=True, timeout=5).strip())
    assert status["locked"] is True and status["secure"] is True, status
    assert not json.loads(test_ipc("releaseStatus"))["active"], "entry cannot prepare a desktop reveal"
    assert status["authState"] == "WaitingInput", status

    # Verify hyprlock fallback was NOT invoked
    calls_file = Path(os.environ["TEST_ROOT"]) / "hyprlock.calls"
    assert calls_file.read_text().strip() == "", "hyprlock should not run when native lock succeeds"

    # Unauthenticated IPC quit must be ignored while locked
    subprocess.run(["qs", "-c", "hakuspace", "ipc", "call", "shell", "quit"], check=True, timeout=5)
    time.sleep(0.2)
    assert runtime.poll() is None, "shell quit must be blocked while session is locked"

    # Hotplug after the shared entry deadline must preserve secure Ready state.
    time.sleep(2.4)
    subprocess.run(["wlr-randr", "--output", "HEADLESS-2", "--off"], check=True)
    time.sleep(0.1)
    status = json.loads(subprocess.check_output(
        ["qs", "-c", "hakuspace", "ipc", "call", "lock", "status"], text=True, timeout=5).strip())
    assert status["locked"] is True and status["secure"] is True, status

    subprocess.run(["wlr-randr", "--output", "HEADLESS-2", "--on"], check=True)
    time.sleep(0.1)
    status = json.loads(subprocess.check_output(
        ["qs", "-c", "hakuspace", "ipc", "call", "lock", "status"], text=True, timeout=5).strip())
    assert status["locked"] is True and status["secure"] is True, status

    # Reload while locked must be blocked so ext-session-lock-v1 surfaces are never destroyed mid-lock
    subprocess.run(["qs", "-c", "hakuspace", "ipc", "call", "shell", "reload"], check=True, timeout=5)
    time.sleep(0.2)
    assert runtime.poll() is None, "shell reload must not crash or terminate Quickshell while locked"
    status = json.loads(subprocess.check_output(
        ["qs", "-c", "hakuspace", "ipc", "call", "lock", "status"], text=True, timeout=5).strip())
    assert status["locked"] is True and status["secure"] is True, status
    # Wrong PAM credentials must never prepare the ordinary desktop overlay.
    test_ipc("authenticate", "wrong-pass")
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        status = json.loads(subprocess.check_output(
            ["qs", "-c", "hakuspace", "ipc", "call", "lock", "status"], text=True, timeout=5))
        if status["authState"] == "Failed":
            break
        time.sleep(0.02)
    else:
        raise AssertionError("wrong password did not reach Failed")
    assert status["locked"] and status["secure"], status
    assert not json.loads(test_ipc("releaseStatus"))["active"], "wrong password cannot reveal desktop"

    # Successful PAM prepares the cover while the independent unlock timer still owns security.
    test_ipc("authenticate", "correct-pass")
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        status = json.loads(subprocess.check_output(
            ["qs", "-c", "hakuspace", "ipc", "call", "lock", "status"], text=True, timeout=5))
        if status["authState"] == "Success":
            break
        time.sleep(0.01)
    else:
        raise AssertionError("correct password did not reach Success")
    reveal = json.loads(test_ipc("releaseStatus"))
    assert status["locked"] and status["secure"], status
    assert reveal["progress"] == 0, reveal
    assert reveal["active"] == (not reveal["reduced"]), reveal

    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        status = json.loads(subprocess.check_output(
            ["qs", "-c", "hakuspace", "ipc", "call", "lock", "status"], text=True, timeout=5))
        if not status["locked"]:
            break
        time.sleep(0.01)
    else:
        raise AssertionError("independent PAM timer did not unlock")

    if not reveal["reduced"]:
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            reveal = json.loads(test_ipc("releaseStatus"))
            if reveal["progress"] >= 0.22:
                break
            time.sleep(0.01)
        assert reveal["active"] and reveal["progress"] < 0.6, reveal
        for output in ["HEADLESS-1", "HEADLESS-2"]:
            center, corner = output_pixels(output)
            assert center == bytes.fromhex("246a8d"), (output, "desktop missing inside reveal", center)
            assert corner != center, (output, "outside of reveal must remain covered")

        # An output re-enabled mid-release joins shared progress rather than replaying the wave.
        before = json.loads(test_ipc("releaseStatus"))["progress"]
        subprocess.run(["wlr-randr", "--output", "HEADLESS-2", "--off"], check=True)
        subprocess.run(["wlr-randr", "--output", "HEADLESS-2", "--on"], check=True)
        assert json.loads(test_ipc("releaseStatus"))["progress"] >= before
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            reveal = json.loads(test_ipc("releaseStatus"))
            if not reveal["active"]:
                break
            time.sleep(0.02)
        assert not reveal["active"] and reveal["progress"] == 1, reveal
    else:
        assert not json.loads(test_ipc("releaseStatus"))["active"], "reduced motion cannot show the reveal overlay"

    # Relocking during the post-authentication effect must cancel it immediately.
    subprocess.run([lock_sh], check=True, timeout=10)
    test_ipc("authenticate", "correct-pass")
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        status = json.loads(subprocess.check_output(
            ["qs", "-c", "hakuspace", "ipc", "call", "lock", "status"], text=True, timeout=5))
        if not status["locked"]:
            break
        time.sleep(0.01)
    assert not status["locked"], status
    subprocess.run([lock_sh], check=True, timeout=10)
    reveal = json.loads(test_ipc("releaseStatus"))
    assert not reveal["active"] and reveal["progress"] == 0, reveal
    print("Headless Wayland Hikai session lock, hotplug, reload guard, and lock.sh routing checks passed", flush=True)
    print("Native PAM handoff and transparent desktop reveal checks passed", flush=True)
finally:
    if runtime.poll() is None:
        runtime.terminate()
        runtime.wait(timeout=5)
PY

# Render native lock surfaces on two outputs with and without viewport motion.
for reduced_motion in 0 1; do
    env -u DISPLAY -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
        -u QT_IM_MODULE -u GTK_IM_MODULE -u XMODIFIERS \
        -u HYPRLAND_INSTANCE_SIGNATURE -u NIRI_SOCKET -u MANGO_INSTANCE_SIGNATURE \
        -u GDK_BACKEND PATH="$test_root/mockbin:$PATH" TEST_ROOT="$test_root" \
        HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config" \
        HAKUSPACE_TEST_PAM_DIR="$test_root/pam.d" \
        XDG_DATA_HOME="$test_root/home/.local/share" XDG_STATE_HOME="$test_root/home/.local/state" \
        XDG_RUNTIME_DIR="$test_root/runtime" XDG_CURRENT_DESKTOP=labwc \
        QSG_RENDER_LOOP=basic HAKUSPACE_REDUCED_MOTION="$reduced_motion" \
        WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_RENDERER=pixman QT_QPA_PLATFORM=wayland \
        timeout 45s dbus-run-session -- labwc -C "$test_root/labwc" \
        -S "python3 $test_root/wayland_lock_probe.py" > "$test_root/result.log" 2>&1
    cat "$test_root/result.log"
    grep -q 'Headless Wayland Hikai session lock, hotplug, reload guard, and lock.sh routing checks passed' "$test_root/result.log"
    if grep -Eq 'TypeError|ReferenceError|Binding loop|Failed to load configuration' "$test_root/result.log"; then
        echo "Unexpected QML error in native session-lock probe" >&2
        exit 1
    fi
done
