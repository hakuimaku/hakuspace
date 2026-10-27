import QtQuick
import Quickshell.Wayland
import Quickshell.Io
import "IdlePolicy.js" as Policy

QtObject {
    id: root
    // Each stage owns its monitor, condition request, and bounded retry timer.
    property bool enabled: false
    property int timeout: 200
    property bool respectInhibitors: true
    property var conditionCommand: []
    property bool pending: false
    property bool applied: false
    property int generation: 0
    property int checkedGeneration: -1
    property bool forcedIdle: false
    readonly property bool idle: monitor.isIdle || forcedIdle
    signal applyRequested()
    signal resumeRequested()
    signal conditionChecked(bool inhibited)

    // Cancel stale asynchronous decisions before releasing reversible effects.
    function reset() {
        generation += 1
        retry.stop()
        pending = false
        forcedIdle = false
        var resume = applied
        applied = false
        if (resume) resumeRequested()
    }
    // Coalesce condition reads while retaining retry semantics after failures.
    function check() {
        if (!enabled || !idle || applied || condition.running) return
        pending = true
        checkedGeneration = generation
        condition.command = conditionCommand
        condition.running = true
    }
    // Failed actions remain pending until activity or a later policy check.
    function defer() {
        applied = false
        if (enabled && idle) { pending = true; retry.restart() }
    }
    // Expose only serializable state to the service's diagnostic IPC.
    function status() {
        return {timeout: timeout, enabled: enabled, monitorEnabled: monitor.enabled, idle: idle, pending: pending, applied: applied}
    }
    onEnabledChanged: { reset(); if (enabled && idle) check() }
    onIdleChanged: { if (idle) check(); else reset() }
    onTimeoutChanged: reset()
    property IdleMonitor monitor: IdleMonitor {
        enabled: root.enabled
        timeout: root.timeout
        respectInhibitors: root.respectInhibitors
    }
    property Timer retry: Timer {
        interval: 30000
        onTriggered: root.check()
    }
    property Process condition: Process {
        stdout: StdioCollector {}
        onExited: (code, status) => {
            if (root.checkedGeneration !== root.generation) {
                if (root.enabled && root.idle && !root.applied) root.check()
                return
            }
            if (!root.enabled || !root.idle) return
            var next = Policy.transition(root.enabled, root.idle, root.applied, code === 0)
            root.pending = next.pending
            root.applied = next.applied
            root.conditionChecked(code !== 0)
            if (next.action === "apply") root.applyRequested()
            else if (next.action === "retry") retry.restart()
        }
    }
}
