import QtQuick
import Quickshell.Wayland
import Quickshell.Io
import "IdlePolicy.js" as Policy

QtObject {
    id: root
    // Each stage owns one armed timeout and an activity subscription while applied.
    property bool enabled: false
    property real timeout: 200
    property bool respectInhibitors: true
    property var conditionCommand: []
    property bool pending: false
    property bool applied: false
    property int generation: 0
    property int checkedGeneration: -1
    property bool forcedIdle: false
    property bool monitorArmed: false
    property real armedTimeout: 200
    property bool armedRespectInhibitors: true
    property bool alive: true
    readonly property bool idle: forcedIdle || (monitorArmed && monitor.isIdle)
    signal applyRequested()
    signal resumeRequested()
    signal conditionChecked(bool inhibited)
    signal diagnostic(string eventName, var details)

    // Invalidate condition results and retries without discarding an applied effect.
    function cancelPending() {
        generation += 1
        retry.stop()
        pending = false
    }
    // Disconnect before copying policy, then subscribe in a later event-loop turn.
    function rearm() {
        cancelPending()
        monitorArmed = false
        armedTimeout = timeout
        armedRespectInhibitors = respectInhibitors
        var armGeneration = generation
        Qt.callLater(function() {
            if (!root || !root.alive || !root.enabled || root.generation !== armGeneration) return
            root.monitorArmed = true
            root.diagnostic("monitor-armed", {timeout: root.armedTimeout, respectInhibitors: root.armedRespectInhibitors, stageGeneration: root.generation})
            if (root.forcedIdle) root.check()
        })
    }
    // Only activity or disabling a stage releases its applied effect.
    function reset() {
        cancelPending()
        var resume = applied
        applied = false
        forcedIdle = false
        if (resume) diagnostic("activity-resume", {})
        if (resume) resumeRequested()
        rearm()
    }
    // Coalesce reads and reject completions from an earlier policy generation.
    function check() {
        if (!enabled || !monitorArmed || !idle || applied || condition.running) return
        pending = true
        checkedGeneration = generation
        diagnostic("condition-check", {stageGeneration: generation})
        condition.command = conditionCommand
        condition.running = true
    }
    // Failed actions remain pending until activity or a later condition check.
    function defer() {
        applied = false
        if (enabled && idle) { pending = true; retry.restart() }
    }
    // Expose both requested and armed policy for runtime diagnostics.
    function status() {
        return {timeout: timeout, armedTimeout: armedTimeout, enabled: enabled,
            monitorEnabled: monitor.enabled, monitorArmed: monitorArmed,
            respectInhibitors: armedRespectInhibitors, idle: idle, pending: pending, applied: applied}
    }
    onEnabledChanged: { if (enabled) rearm(); else reset() }
    onIdleChanged: {
        if (idle) { diagnostic("idle-timeout", {timeout: armedTimeout}); check() }
    }
    onTimeoutChanged: rearm()
    onRespectInhibitorsChanged: rearm()
    onForcedIdleChanged: { if (forcedIdle) check(); else if (applied) reset(); else cancelPending() }
    Component.onCompleted: rearm()
    Component.onDestruction: { alive = false; monitorArmed = false; retry.stop() }
    property IdleMonitor monitor: IdleMonitor {
        enabled: root.enabled && root.monitorArmed
        timeout: root.armedTimeout
        respectInhibitors: root.armedRespectInhibitors
        onIsIdleChanged: {
            if (!root.monitorArmed || !root.enabled) return
            if (isIdle) root.check()
            else if (root.applied) root.reset()
            else if (!root.forcedIdle) root.cancelPending()
        }
    }
    // Policy rearming cannot synthesize activity and restore an already applied dim.
    property IdleMonitor activity: IdleMonitor {
        enabled: root.enabled && root.applied
        timeout: 0
        respectInhibitors: false
        onIsIdleChanged: if (!isIdle && root.enabled && root.applied) root.reset()
    }
    property Timer retry: Timer {
        interval: 30000
        onTriggered: if (root.enabled && root.monitorArmed) root.check()
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
            root.diagnostic(code === 0 ? "condition-allowed" : "condition-blocked",
                {exitCode: code, retrySeconds: code === 0 ? 0 : retry.interval / 1000})
            if (next.action === "apply") root.applyRequested()
            else if (next.action === "retry") retry.restart()
        }
    }
}
