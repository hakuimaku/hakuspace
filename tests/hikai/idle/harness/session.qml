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
    Window {
        visible: true
        width: 900
        height: 900
        SessionSettingsPage { id: page; anchors.fill: parent }
    }
    SettingsNumberRow { id: generalNumber; descriptor: ({min: 1, max: 100, step: 1, label: "General", unit: ""}); value: 42 }
    // Inspect the instantiated controls so tests cover stepper wiring, not just store writes.
    function numberRow(item, key) {
        if (item.descriptor && item.descriptor.key === key && typeof item.showSlider === "boolean") return item
        for (var child of item.children || []) {
            var found = numberRow(child, key)
            if (found) return found
        }
        return null
    }
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
                root.check(ShellSettingsStore.valid, "valid v9 defaults")
                root.check(page.controls.length === 12, "all idle controls")
                var dim = numberRow(page, "dimTimeout")
                root.check(dim && !dim.showSlider && dim.descriptor.step === 10, "idle uses a ten-second stepper")
                root.check(generalNumber.showSlider, "General retains its existing slider")
                var stepper = dim.children.find(child => child.visible && child.plus10 !== undefined)
                root.check(!!stepper, "native numeric stepper is instantiated")
                stepper.plus10.clicked()
                root.check(ShellSettingsStore.values.idle.dimTimeout === 310, "plus edits by ten seconds")
                stepper.plus30.clicked()
                root.check(ShellSettingsStore.values.idle.dimTimeout === 340, "plus 30 edits by thirty seconds")
                stepper.minus10.clicked()
                root.check(ShellSettingsStore.values.idle.dimTimeout === 330, "minus 10 edits by ten seconds")
                stepper.minus30.clicked()
                root.check(ShellSettingsStore.values.idle.dimTimeout === 300, "minus 30 edits by thirty seconds")
                ShellSettingsStore.setValue("idle", "lockTimeout", 125)
                root.check(ShellSettingsStore.values.idle.lockTimeout === 120 && ShellSettingsStore.error.length > 0, "odd number timeout rejected")
                ShellSettingsStore.setValue("idle", "dimTimeout", 10)
                ShellSettingsStore.setValue("idle", "lockTimeout", 10)
                root.check(ShellSettingsStore.values.idle.lockTimeout === 10, "equal round timeout allowed down to 10s")
                ShellSettingsStore.setValue("idle", "dimTimeout", 300)
                ShellSettingsStore.setValue("idle", "lockTimeout", 120)
                ShellSettingsStore.setValue("idle", "dimPercent", 15)
                root.check(ShellSettingsStore.values.idle.dimPercent === 15 && ShellSettingsStore.savedValues.idle.dimPercent === 10, "saved policy isolation")
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
