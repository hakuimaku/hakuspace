pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    // Subscribers own the collector only while Hikai owns the shell.
    property int subscribers: 0
    // A handoff owns one temporary subscription until its target acquires or cancels.
    property string handoffScreenName: ""
    readonly property bool active: subscribers > 0 && AppState.shellBackend === "hikai"
    readonly property bool collectorRunning: monitor.running
    readonly property int collectorPid: monitor.processId || 0
    // Wait for exit before replacing a collector or reopening a closing session.
    property bool monitorRestartPending: false
    property bool monitorStopPending: false
    property bool monitorFailed: false
    // Retain current telemetry, the latest process model and a fixed history window.
    property var snapshot: ({})
    property var processes: []
    property real processTimestamp: -1
    property var history: []
    readonly property int historyWindowMs: 60000
    readonly property var cpu: snapshot.cpu || ({})
    readonly property var memory: snapshot.memory || ({})
    readonly property var gpus: snapshot.gpus || []
    readonly property var disks: snapshot.disks || ({})
    readonly property var network: snapshot.network || ({})
    readonly property bool ready: active && !monitorFailed && !!snapshot.seq
    readonly property bool warmingUp: !ready || !!cpu.warmingUp
    // Surface collector and action failures without logging every sample.
    property string error: ""
    property string actionError: ""
    property string actionStatus: ""
    readonly property bool actionBusy: controller.running

    // Resolve helpers in both flat installations and source-tree sessions.
    function command(name, args) {
        return ["sh", "-c", 'script=$1; [ -f "$script" ] || script=$2; shift 2; exec python3 "$script" "$@"',
            "--", Env.binDir + "/" + name, Quickshell.shellPath("../../../../core/backend/system/" + name)].concat(args)
    }

    // Acquire exactly once for each loaded overlay, including its closing frames.
    function acquire() { subscribers++ }
    // Drop heavyweight data after the last visual owner finishes closing.
    function release() { subscribers = Math.max(0, subscribers - 1) }
    function beginHandoff(screenName) {
        if (!screenName) return
        if (handoffScreenName) { handoffScreenName = screenName; return }
        handoffScreenName = screenName
        acquire()
    }
    // Only the matching output may acknowledge or abandon the transfer.
    function finishHandoff(screenName) {
        if (!handoffScreenName || (screenName && handoffScreenName !== screenName)) return
        handoffScreenName = ""
        release()
    }
    onActiveChanged: {
        if (!active) {
            finishHandoff()
            monitorStopPending = monitorStopPending || monitor.running || monitorRestartPending
            monitorRestartPending = false
            controller.running = false
            snapshot = ({}); processes = []; processTimestamp = -1; history = []
            error = ""; actionError = ""; actionStatus = ""
        } else {
            monitorFailed = false
        }
    }

    // Validate complete JSONL frames before publishing them atomically.
    function receive(line) {
        if (!active || monitorFailed) return
        try {
            var value = JSON.parse(line)
            if (value.schema !== 1 || !Number.isFinite(value.seq) || !Number.isFinite(value.monotonicMs)
                    || !Number.isFinite(value.processMonotonicMs) || !value.cpu || !value.memory
                    || (value.processes != null && !Array.isArray(value.processes)) || !Array.isArray(value.gpus)
                    || !value.network || !value.disks) throw new Error("Unsupported telemetry frame")
            if (value.monotonicMs < (snapshot.monotonicMs || 0)) return
            snapshot = value
            if (Array.isArray(value.processes) && processTimestamp !== value.processMonotonicMs) {
                processes = value.processes
                processTimestamp = value.processMonotonicMs
            }
            history = history.concat([{
                t: value.monotonicMs,
                cpu: cpu.usage, gpu: gpus.length ? gpus[0].usage : null, memory: memory.percent,
                rx: (network.all || {}).rxBps, tx: (network.all || {}).txBps,
                read: disks.readBps, write: disks.writeBps
            }]).filter(sample => sample.t >= value.monotonicMs - historyWindowMs).slice(-800)
            error = ""
        } catch (exception) { error = "Invalid telemetry: " + exception.message }
    }

    // Keep each action tied to the selected PID lifetime, never its row index.
    function sendSignal(process, name) {
        if (!active || actionBusy || !process || !Number.isInteger(process.pid) || process.pid <= 0
                || !Number.isFinite(process.startTime) || (name !== "TERM" && name !== "KILL")) return false
        actionError = ""; actionStatus = ""
        controller.command = command("task_manager_ctl.py", ["signal", String(process.pid), name,
            "--start-time", String(process.startTime)])
        controller.running = true
        return true
    }

    // Decode the finite controller result separately from the telemetry stream.
    function receiveAction(text, exitCode) {
        if (!active) return
        try {
            var result = JSON.parse(text)
            actionStatus = result.status || "unavailable"
            actionError = result.ok && exitCode === 0 ? "" : (result.error || actionStatus)
        } catch (exception) { actionError = "Process action failed (exit " + exitCode + ")" }
    }

    // Expose lightweight diagnostics for IPC and lifecycle probes.
    function status() {
        return {active: active, ready: ready, subscribers: subscribers, collectorRunning: collectorRunning,
            collectorPid: collectorPid, seq: snapshot.seq || 0, monotonicMs: snapshot.monotonicMs || 0,
            intervalMs: intervalMs, restartPending: monitorRestartPending, failed: monitorFailed,
            processCount: processes.length, historyCount: history.length, handoffScreenName: handoffScreenName,
            error: error, actionError: actionError}
    }

    // Restart once with the latest requested interval after the previous child exits.
    property int intervalMs: 1000
    readonly property var monitorCommand: command("task_manager_monitor.py", ["--stream", "--interval-ms", String(intervalMs)])
    function setIntervalMs(ms) {
        if (!Number.isFinite(ms)) return
        var clamped = Math.max(100, Math.min(2000, Math.round(ms / 100) * 100))
        if (intervalMs === clamped) return
        if (monitor.running) monitorRestartPending = true
        intervalMs = clamped
    }

    property Process monitor: Process {
        command: root.monitorCommand
        running: root.active && !root.monitorRestartPending && !root.monitorStopPending && !root.monitorFailed
        stdout: SplitParser { onRead: line => root.receive(line) }
        stderr: SplitParser { onRead: line => { if (root.active) root.error = line.slice(0, 512) } }
        onExited: (exitCode, exitStatus) => {
            if (root.active && !root.monitorRestartPending && !root.monitorStopPending) {
                root.monitorFailed = true
                root.snapshot = ({})
                root.error = "Collector stopped (exit " + exitCode + ")"
            }
            root.monitorStopPending = false
            root.monitorRestartPending = false
        }
    }
    property Process controller: Process {
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => root.receiveAction(actionOutput.text, exitCode)
    }
}
