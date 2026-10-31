pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    // Subscribers own the collector only while Hikai owns the shell.
    property int subscribers: 0
    readonly property bool active: subscribers > 0 && AppState.shellBackend === "hikai"
    readonly property bool collectorRunning: monitor.running
    readonly property int collectorPid: monitor.processId || 0
    // Retain one complete snapshot and bounded graph data per live session.
    property var snapshot: ({})
    property var processes: []
    property real processTimestamp: -1
    property var history: []
    readonly property var cpu: snapshot.cpu || ({})
    readonly property var memory: snapshot.memory || ({})
    readonly property var gpus: snapshot.gpus || []
    readonly property var disks: snapshot.disks || ({})
    readonly property var network: snapshot.network || ({})
    readonly property bool ready: active && !!snapshot.seq
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
    onActiveChanged: {
        if (!active) {
            controller.running = false
            snapshot = ({}); processes = []; processTimestamp = -1; history = []
            error = ""; actionError = ""; actionStatus = ""
        }
    }

    // Validate complete JSONL frames before publishing them atomically.
    function receive(line) {
        if (!active) return
        try {
            var value = JSON.parse(line)
            if (value.schema !== 1 || !Number.isFinite(value.seq) || !Number.isFinite(value.processMonotonicMs) || !value.cpu || !value.memory
                    || !Array.isArray(value.processes) || !Array.isArray(value.gpus)
                    || !value.network || !value.disks) throw new Error("Unsupported telemetry frame")
            snapshot = value
            if (processTimestamp !== value.processMonotonicMs) {
                processes = value.processes
                processTimestamp = value.processMonotonicMs
            }
            history = history.concat([{
                cpu: cpu.usage, gpu: gpus.length ? gpus[0].usage : null, memory: memory.percent,
                rx: (network.all || {}).rxBps, tx: (network.all || {}).txBps,
                read: disks.readBps, write: disks.writeBps
            }]).slice(-120)
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
            processCount: processes.length, historyCount: history.length, error: error, actionError: actionError}
    }

    property Process monitor: Process {
        command: root.command("task_manager_monitor.py", ["--stream"])
        running: root.active
        stdout: SplitParser { onRead: line => root.receive(line) }
        stderr: SplitParser { onRead: line => { if (root.active) root.error = line.slice(0, 512) } }
        onExited: (exitCode, exitStatus) => {
            if (root.active) root.error = "Collector stopped (exit " + exitCode + ")"
        }
    }
    property Process controller: Process {
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => root.receiveAction(actionOutput.text, exitCode)
    }
}
