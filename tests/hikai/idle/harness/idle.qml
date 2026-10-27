import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"
import "services/idle"

ShellRoot {
    id: root
    // Drive the production service while every external action remains a stub.
    property int step: 0
    property int ticks: 0
    property bool nativeIdleFired: false
    property bool inhibitTest: false
    readonly property bool active: IdleService.enabled
    // Continue the lifecycle assertion after an actual Quickshell reload.
    PersistentProperties {
        id: memory
        reloadableId: "haku-idle-test-lifecycle"
        property int resumeStep: 0
        onLoaded: root.step = resumeStep
    }

    // Fail immediately with the production state attached to the assertion.
    function check(condition, message) {
        if (!condition) { console.error("FAIL: " + message + " " + IdleService.status()); Qt.exit(1) }
    }
    // Publish backend commits through the same watched file used in production.
    function backend(value) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$2" > "$1"', "--", Env.stateShellBackend, value])
    }
    // Bound asynchronous test steps so missing signals fail deterministically.
    function next() { step += 1; ticks = 0 }

    IdleMonitor {
        timeout: 1
        enabled: true
        onIsIdleChanged: if (isIdle) root.nativeIdleFired = true
    }
    PanelWindow {
        id: inhibitorWindow
        visible: root.inhibitTest
        anchors { top: true; left: true }
        implicitWidth: 80
        implicitHeight: 40
        color: "#222222"
        exclusionMode: ExclusionMode.Ignore
    }
    IdleInhibitor { window: inhibitorWindow; enabled: root.inhibitTest }
    IdleMonitor { id: inhibitedMonitor; timeout: 1; enabled: root.inhibitTest; respectInhibitors: true }
    IdleMonitor { id: uninhibitedMonitor; timeout: 1; enabled: root.inhibitTest; respectInhibitors: false }
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            root.ticks += 1
            if (root.ticks > 160) { root.check(false, "timeout at step " + root.step); return }
            if (root.step === 0) {
                if (!ShellSettingsStore.ready) return
                root.check(!IdleService.enabled, "Classic bootstrap must be inactive")
                root.check(IdleService.forceStage("dim") === "error:inactive-stage", "Classic cannot force idle")
                root.backend("hikai")
                root.next()
            } else if (root.step === 1) {
                if (!IdleService.enabled || !root.nativeIdleFired) return
                root.check(JSON.parse(IdleService.status()).dim.monitorEnabled, "Wayland monitor registered")
                root.check(IdleService.forceStage("dim") === "ok", "force dim")
                root.next()
            } else if (root.step === 2) {
                if (!IdleService.dim.applied || IdleService.effects.running) return
                root.check(!LockState.locked, "dim does not lock")
                IdleService.dim.forcedIdle = false
                root.next()
            } else if (root.step === 3) {
                if (IdleService.dim.applied || IdleService.effects.running || IdleService.jobs.length) return
                root.check(IdleService.forceStage("suspend") === "ok", "force stub suspend")
                IdleService.secureDeadline.interval = 150
                root.next()
            } else if (root.step === 4) {
                if (root.ticks < 6) return
                root.check(LockState.locked && !LockState.secure, "lock requested before suspend")
                root.check(!IdleService.power.running && !IdleService.suspendPending, "insecure lock cancels suspend")
                IdleService.suspend.reset()
                LockState.secure = true
                IdleService.secureDeadline.interval = 4000
                IdleService.forceStage("suspend")
                root.next()
            } else if (root.step === 5) {
                if (!IdleService.suspend.applied || IdleService.suspendPending || IdleService.suspendCheck.running || root.ticks < 5) return
                root.check(LockState.secure, "stub suspend requires secure lock")
                IdleService.suspend.reset()
                IdleService.forceStage("displayOff")
                root.next()
            } else if (root.step === 6) {
                if (!IdleService.display.applied || IdleService.effects.running) return
                IdleService.sessionEvent(JSON.stringify({event: "prepare-sleep", sleeping: true, serial: 1}))
                root.next()
            } else if (root.step === 7) {
                if (IdleService.effects.running || root.ticks < 3) return
                root.check(IdleService.sleepPending && LockState.secure, "external sleep locks")
                IdleService.sessionEvent(JSON.stringify({event: "unlock"}))
                root.check(LockState.locked, "external Unlock cannot authenticate")
                IdleService.sessionEvent(JSON.stringify({event: "prepare-sleep", sleeping: false, serial: 1}))
                root.next()
            } else if (root.step === 8) {
                if (IdleService.effects.running || IdleService.jobs.length) return
                root.check(!IdleService.dim.applied && !IdleService.display.applied, "wake restores effects")
                IdleService.forceStage("dim")
                IdleService.release()
                root.next()
            } else if (root.step === 9) {
                if (!JSON.parse(IdleService.status()).released) return
                if (AppState.shellBackend !== "classic") { root.backend("classic"); return }
                root.check(!IdleService.dim.applied && !IdleService.suspendPending, "handoff cancels pending stages")
                root.backend("hikai")
                root.next()
            } else if (root.step === 10) {
                if (!IdleService.enabled) return
                IdleService.dim.conditionCommand = ["sh", "-c", "exit 1"]
                IdleService.dim.retry.interval = 100
                IdleService.forceStage("dim")
                root.next()
            } else if (root.step === 11) {
                if (root.ticks < 5) return
                root.check(IdleService.dim.pending && !IdleService.dim.applied, "inhibitor leaves a retry pending")
                IdleService.dim.conditionCommand = ["sh", "-c", "exit 0"]
                root.next()
            } else if (root.step === 12) {
                if (!IdleService.dim.applied || IdleService.effects.running) return
                root.check(!IdleService.dim.pending, "retry applies without user activity")
                IdleService.dim.reset()
                IdleService.dim.conditionCommand = ["sh", "-c", "sleep 0.2; exit 0"]
                IdleService.forceStage("dim")
                root.next()
            } else if (root.step === 13) {
                if (!IdleService.dim.condition.running) return
                IdleService.dim.forcedIdle = false
                root.next()
            } else if (root.step === 14) {
                if (root.ticks < 6) return
                root.check(!IdleService.dim.applied && !IdleService.dim.pending, "late condition result cannot dim after activity")
                root.check(IdleService.forceStage("unknown") === "error:inactive-stage", "reject unknown stage")
                IdleService.dim.conditionCommand = ["sh", "-c", "exit 0"]
                IdleService.forceStage("dim")
                root.next()
            } else if (root.step === 15) {
                if (!IdleService.dim.applied || IdleService.effects.running) return
                memory.resumeStep = 16
                Quickshell.reload(false)
                root.next()
            } else if (root.step === 16) {
                if (!IdleService.enabled || IdleService.effects.running || root.ticks < 6) return
                root.check(!IdleService.dim.applied && !IdleService.display.applied, "reload releases reversible effects")
                root.inhibitTest = true
                root.next()
            } else if (root.step === 17) {
                if (root.ticks < 30) return
                root.check(!inhibitedMonitor.isIdle && uninhibitedMonitor.isIdle, "Wayland application inhibitor respected")
                root.inhibitTest = false
                console.log("PASS: Hikai idle runtime")
                Qt.quit()
            }
        }
    }
}
