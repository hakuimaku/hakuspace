import QtQuick
import Quickshell
import "services"
import "components/settings"

ShellRoot {
    id: root
    // Load the real composed page and both stores in an offscreen private HOME.
    property int ticks: 0
    property int step: 0
    Component.onCompleted: SettingsStore.load()
    SessionSettingsPage { id: page; width: 900; height: 900 }
    // Check native drafts never become runtime policy before Apply.
    function check(condition, message) {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            root.ticks += 1
            if (root.ticks > 120) { root.check(false, "Session settings timeout"); return }
            if (!SettingsStore.ready || !ShellSettingsStore.ready) return
            if (root.step === 0) {
                root.check(ShellSettingsStore.valid, "valid v8 defaults")
                root.check(page.controls.length === 12, "all idle controls")
                ShellSettingsStore.setValue("idle", "dimPercent", 15)
                root.check(ShellSettingsStore.values.idle.dimPercent === 15 && ShellSettingsStore.savedValues.idle.dimPercent === 10, "saved policy isolation")
                ShellSettingsStore.setValue("idle", "lockTimeout", 200)
                root.check(ShellSettingsStore.values.idle.lockTimeout === 230 && ShellSettingsStore.error.length > 0, "invalid ordering rejected")
                ShellSettingsStore.setValue("idle", "dimPercent", 15)
                page.reveal("idle-dimPercent")
                page.reveal("RAM_THRESHOLD_MB")
                root.check(page.canActivate("Apply"), "combined Apply available")
                page.activateAction("Apply")
                root.step = 1
            } else if (!ShellSettingsStore.saving && !ShellSettingsStore.dirty) {
                root.check(ShellSettingsStore.savedValues.idle.dimPercent === 15, "Apply persists idle")
                root.check(!SettingsStore.dirty, "unchanged exit store stays clean")
                console.log("PASS: Session idle settings runtime")
                Qt.quit()
            }
        }
    }
}
