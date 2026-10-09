#!/usr/bin/env python3
"""Exercise the native notification model on a private session bus.

Run from a graphical session with: python3 scripts/notification_probe.py
The probe creates a temporary service-only QML file beside shell.qml and
removes it afterward. It never stops the desktop's notification daemon.
"""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/home/.config/quickshell/hakuspace"
QML = '''import QtQuick
import Quickshell
import Quickshell.Io
import "services"
ShellRoot {
    PersistentProperties {
        id: notificationMemory
        reloadableId: "hakuspace-notification-records"
        property string recordsJson: "[]"
        property int nextKey: 1
        onLoaded: {
            if (startDelay.interval > 0) startDelay.start()
            else NotificationStore.start(notificationMemory)
        }
    }
    Timer {
        id: startDelay
        interval: Number(Quickshell.env("HAKU_P2_PROBE_DELAY_MS") || 0)
        onTriggered: NotificationStore.start(notificationMemory)
    }
    Variants {
        model: Quickshell.screens
        QtObject { required property var modelData }
    }
    IpcHandler {
        target: "notificationprobe"
        function state(): string {
            return JSON.stringify({screens: Quickshell.screens.length,
                                   started: NotificationStore._started,
                                   serverActive: NotificationStore.server.active,
                                   dnd: NotificationStore.dnd,
                                   popupCount: NotificationStore.popupForScreen(Quickshell.screens[0].name).length,
                                   count: NotificationStore.count,
                                   records: NotificationStore.records})
        }
        function dismiss(key: int) { NotificationStore.dismiss(key) }
        function expire(key: int) { NotificationStore.expire(key) }
        function toggleDnd() { NotificationStore.toggleDnd() }
        function clearAll() { NotificationStore.clearAll() }
        function reload() { Quickshell.reload(false) }
    }
}
'''


def command(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()


def wait_for(predicate, label, seconds=5):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        try:
            result = predicate()
            if result:
                return result
        except (subprocess.CalledProcessError, ValueError):
            pass
        time.sleep(0.1)
    raise AssertionError(f"Timed out waiting for {label}")


def run_inner():
    with tempfile.NamedTemporaryFile(
        mode="w", prefix="p2_probe_", suffix=".qml", dir=CONFIG, delete=False
    ) as source:
        source.write(QML)
        path = Path(source.name)
    with tempfile.TemporaryFile(mode="w+t") as log:
        qs = subprocess.Popen(
            ["qs", "-p", str(path), "--no-color"], stdout=log, stderr=log,
            env={**os.environ, "QT_QPA_PLATFORM": "wayland"},
        )
        try:
            def ipc(method, *args):
                return command("qs", "-p", str(path), "ipc", "call",
                               "notificationprobe", method, *map(str, args))

            def state():
                return json.loads(ipc("state"))

            if int(os.environ.get("HAKU_P2_PROBE_DELAY_MS", "0")) > 0:
                pending = wait_for(lambda: state() if not state()["started"] else None,
                                   "uninitialized singleton")
                assert not pending["serverActive"] and pending["records"] == []
                assert subprocess.run(
                    ["busctl", "--user", "status", "org.freedesktop.Notifications"],
                    capture_output=True, check=False,
                ).returncode != 0
                print("PASS server inactive before state restore")

            wait_for(lambda: str(qs.pid) in command(
                "busctl", "--user", "status", "org.freedesktop.Notifications"
            ), "Quickshell notification ownership")
            initial = state()
            assert initial["started"] and initial["serverActive"]
            assert initial["count"] == 0 and initial["records"] == []
            assert initial["screens"] >= int(os.environ.get("HAKU_P2_EXPECT_SCREENS", "1"))
            print(f"PASS ownership and empty model on {initial['screens']} screen(s)")

            first = int(command("notify-send", "-p", "-t", "0", "P2 first", "one"))
            second = int(command("notify-send", "-p", "-t", "0", "P2 second", "two"))
            wait_for(lambda: state()["count"] == 2, "two notifications")
            print("PASS one event per send")

            replaced = int(command("notify-send", "-p", "-r", str(first),
                                   "-t", "0", "P2 replaced", "updated"))
            assert replaced == first
            wait_for(lambda: len([r for r in state()["records"]
                                  if r["id"] == first and r["summary"] == "P2 replaced"]) == 1,
                     "replacement update")
            assert state()["count"] == 2
            print("PASS replacement updates one logical record")

            command("gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                    "--object-path", "/org/freedesktop/Notifications", "--method",
                    "org.freedesktop.Notifications.CloseNotification", str(first))
            wait_for(lambda: not next(r for r in state()["records"] if r["id"] == first)["live"],
                     "remote close")
            assert next(r for r in state()["records"] if r["id"] == first)["closeReason"] == "CloseRequested"
            print("PASS remote close keeps a snapshot without a live handle")

            second_key = next(r["key"] for r in state()["records"] if r["id"] == second)
            ipc("dismiss", second_key)
            wait_for(lambda: state()["count"] == 1, "local dismiss")
            assert next(r for r in state()["records"] if r["id"] == second)["closeReason"] == "Dismissed"
            print("PASS local dismiss")

            expiring = int(command("notify-send", "-p", "-t", "1000", "P2 expiry", "short"))
            expiry_record = wait_for(lambda: next((r for r in state()["records"]
                                                   if r["id"] == expiring), None),
                                     "short timeout reception")
            print(f"Local expireTimeout value for notify-send -t 1000: {expiry_record['expireTimeout']}")
            wait_for(lambda: any(r["id"] == expiring and r["closeReason"] == "Expired"
                                 for r in state()["records"]), "timeout expiry", 4)
            print("PASS short timeout expires")

            normal_default = int(command("notify-send", "-p", "--expire-time=-1",
                                         "P2 default timeout"))
            critical_default = int(command("notify-send", "-p", "-u", "critical",
                                           "--expire-time=-1", "P2 critical default"))
            wait_for(lambda: any(r["id"] == normal_default and r["closeReason"] == "Expired"
                                 for r in state()["records"]), "default timeout expiry", 7)
            assert next(r for r in state()["records"] if r["id"] == critical_default)["live"]
            wait_for(lambda: any(r["id"] == critical_default and r["closeReason"] == "Expired"
                                 for r in state()["records"]), "critical default expiry", 7)
            print("PASS default and critical timeout policies")

            manual = int(command("notify-send", "-p", "-t", "0", "P2 manual expiry"))
            manual_record = wait_for(lambda: next((r for r in state()["records"]
                                                    if r["id"] == manual), None),
                                     "manual expiry reception")
            ipc("expire", manual_record["key"])
            wait_for(lambda: any(r["id"] == manual and r["closeReason"] == "Expired"
                                 for r in state()["records"]), "manual expiry")
            print("PASS explicit expire differs from dismiss")

            critical = int(command("notify-send", "-p", "-u", "critical", "-t", "0",
                                   "P2 critical"))
            critical_record = wait_for(lambda: next((r for r in state()["records"]
                                                      if r["id"] == critical), None),
                                       "critical reception")
            assert critical_record["urgency"] == 2 and critical_record["live"]
            print("PASS critical urgency metadata")

            transient = int(command("notify-send", "-p", "-e", "-t", "0", "P2 transient"))
            wait_for(lambda: any(r["id"] == transient for r in state()["records"]), "transient reception")
            command("gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                    "--object-path", "/org/freedesktop/Notifications", "--method",
                    "org.freedesktop.Notifications.CloseNotification", str(transient))
            wait_for(lambda: all(r["id"] != transient for r in state()["records"]),
                     "transient removal")
            print("PASS transient has no durable history")

            active = int(command("notify-send", "-p", "-t", "0", "P2 reload", "retained"))
            wait_for(lambda: any(r["id"] == active for r in state()["records"]), "pre-reload item")
            before_reload = state()
            try:
                ipc("reload")
            except subprocess.CalledProcessError:
                pass  # IPC connection may close while Quickshell reloads.
            if int(os.environ.get("HAKU_P2_PROBE_DELAY_MS", "0")) > 0:
                pending = wait_for(lambda: state() if not state()["started"] else None,
                                   "reload waiting for restore")
                assert not pending["serverActive"]
                print("PASS reload server waits for restored state")
            wait_for(lambda: str(qs.pid) in command(
                "busctl", "--user", "status", "org.freedesktop.Notifications"
            ), "ownership after reload")
            restored = wait_for(lambda: next((r for r in state()["records"]
                                              if r["id"] == active and state()["started"]), None),
                                "retained item")
            assert restored["live"] and not restored["popupEligible"]
            assert len([r for r in state()["records"] if r["id"] == active]) == 1
            print(f"Reload count: {before_reload['count']} -> {state()['count']}")
            print(f"Reload keys: {[r['key'] for r in before_reload['records']]} -> {[r['key'] for r in state()['records']]}")
            assert state()["count"] == before_reload["count"]
            assert {r["key"] for r in state()["records"]} == {r["key"] for r in before_reload["records"]}
            print("PASS reload rebinds live item without a new popup")

            ipc("toggleDnd")
            suppressed = int(command("notify-send", "-p", "-t", "0", "P2 DND"))
            wait_for(lambda: any(r["id"] == suppressed for r in state()["records"]), "DND history")
            assert state()["dnd"] and not next(r for r in state()["records"]
                                                 if r["id"] == suppressed)["popupEligible"]
            ipc("toggleDnd")
            assert not next(r for r in state()["records"]
                            if r["id"] == suppressed)["popupEligible"]
            for index in range(4):
                command("notify-send", "-p", "-t", "0", f"P2 stack {index}")
            wait_for(lambda: state()["popupCount"] == 3, "three visible popups")
            print("PASS DND history, no replay, and newest-three popup cap")

            ipc("clearAll")
            wait_for(lambda: state()["count"] == 0 and state()["records"] == [],
                     "clear all")
            ipc("clearAll")
            print("PASS clear all is idempotent")
        except Exception:
            log.seek(0)
            print(log.read()[-4000:], file=sys.stderr)
            raise
        finally:
            qs.terminate()
            try:
                qs.wait(timeout=3)
            except subprocess.TimeoutExpired:
                qs.kill()
                qs.wait()
            path.unlink(missing_ok=True)


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--inner":
        run_inner()
    else:
        result = subprocess.run(["dbus-run-session", "--", sys.executable,
                                 str(Path(__file__).resolve()), "--inner"],
                                text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        for line in re.findall(r"PASS[^\n]*|Local expireTimeout[^\n]*|Reload count[^\n]*|Reload keys[^\n]*",
                               result.stdout):
            print(line)
        if result.returncode:
            print(result.stderr[-5000:], file=sys.stderr)
        sys.exit(result.returncode)
