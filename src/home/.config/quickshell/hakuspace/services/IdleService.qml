pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "idle"
import "idle/IdlePolicy.js" as Policy

QtObject {
    id: root
    // Sleep hooks remain resident in Hikai even when idle timeouts are disabled.
    readonly property bool owner: AppState.shellBackend === "hikai"
    readonly property var settings: ShellSettingsStore.savedValues.idle
    readonly property bool enabled: Policy.active(AppState.shellBackend,
        ShellSettingsStore.ready && recovered && logindReady, settings.enabled)
    property bool recovered: false
    property bool logindReady: false
    property bool customInhibited: false
    property bool sleepPending: false
    property int sleepSerial: 0
    property bool suspendPending: false
    property string error: ""
    // A bounded action queue preserves restore ordering during rapid activity.
    property var jobs: []
    property var currentJob: null
    property string recoveryAction: "recover"
    readonly property var stages: ({dim: dim, lock: lock, displayOff: display, suspend: suspend})
    readonly property var conditionCommand: command("idle_inhibit.sh", "sys/idle_inhibit.sh",
        ["--condition"].concat(settings.inhibitOnAudio ? [] : ["--no-audio"]))

    // Resolve installed helpers or the source tree without evaluating user text.
    function command(name, source, args) {
        return ["sh", "-c", 'if [ -x "$1" ]; then script=$1; else script=$2; fi; shift 2; exec "$script" "$@"',
            "--", Env.binDir + "/" + name,
            Quickshell.shellPath("../../../../core/" + source)].concat(args || [])
    }
    // Replace queued effects of the same kind while letting an in-flight job finish.
    function enqueue(action) {
        var family = action === "dim" || action === "restore" ? "brightness" : "display"
        if (action === "recover") jobs = [{action: action, family: "recover"}]
        else jobs = jobs.filter(job => job.family !== family).concat([{action: action, family: family}])
        runNext()
    }
    // Recheck stage ownership at dispatch so canceled timeouts cannot turn screens off.
    function runNext() {
        if (effects.running || !jobs.length) return
        var job = jobs[0]
        jobs = jobs.slice(1)
        if ((job.action === "dim" && (!enabled || !dim.applied)) ||
            (job.action === "off" && !sleepPending && (!enabled || !display.applied))) {
            runNext()
            return
        }
        currentJob = job
        effects.command = command("idle_actions.sh", "sys/idle_actions.sh",
            [job.action].concat(job.action === "dim" ? [String(settings.dimPercent)] : []))
        effects.running = true
    }
    // Restore reversible state when leaving native ownership, never unlock the session.
    function reset() {
        suspendPending = false
        secureDeadline.stop()
        for (var key in stages) stages[key].reset()
        enqueue("recover")
    }
    // A secure compositor lock is mandatory before requesting idle suspend.
    function requestSuspend() {
        suspendPending = true
        LockState.requestLock()
        secureDeadline.restart()
        checkSecure()
    }
    // Revalidate custom inhibition after asynchronous lock acquisition.
    function checkSecure() {
        if (!owner || !LockState.secure) return
        if (sleepPending) {
            enqueue("off")
        } else if (suspendPending && enabled && suspend.applied && !suspendCheck.running) {
            suspendCheck.command = conditionCommand
            suspendCheck.running = true
        }
    }
    // Stream only session events; external Unlock never bypasses native authentication.
    function sessionEvent(line) {
        try {
            var event = JSON.parse(line)
            if (!owner) return
            if (event.event === "ready") { logindReady = true; error = "" }
            else if (event.event === "lock") LockState.requestLock()
            else if (event.event === "prepare-sleep") {
                sleepPending = event.sleeping === true
                sleepSerial = event.serial
                if (sleepPending) {
                    LockState.requestLock()
                    secureDeadline.restart()
                    checkSecure()
                } else {
                    secureDeadline.stop()
                    reset()
                }
            } else if (event.event === "error") { logindReady = false; watch.running = false }
        } catch (e) { error = "Invalid logind event" }
    }
    // Expose state without changing policy or triggering system actions.
    function status() {
        return JSON.stringify({enabled: enabled, backend: AppState.shellBackend,
            ready: recovered && logindReady, configuredEnabled: settings.enabled,
            released: !enabled && !effects.running && !jobs.length && !watch.running && !power.running,
            dim: dim.status(), lock: lock.status(), displayOff: display.status(), suspend: suspend.status(),
            customInhibited: customInhibited || AppState.idleInhibited, error: error})
    }
    // Test forcing still executes the normal inhibitor and secure-lock gates.
    function forceStage(name) {
        if (Quickshell.env("HAKUSPACE_IDLE_TEST") !== "1") return "error:test-only"
        if (!enabled || !stages[name] || !stages[name].enabled) return "error:inactive-stage"
        stages[name].forcedIdle = true
        return "ok"
    }
    onOwnerChanged: {
        recovered = false
        logindReady = false
        sleepPending = false
        reset()
        if (owner) watch.running = true
        else watch.running = false
    }
    onEnabledChanged: if (!enabled) reset()
    Component.onCompleted: {
        if (owner) { enqueue("recover"); watch.running = true }
    }
    // A detached serialized recovery survives destruction of QML Process objects.
    Component.onDestruction: Quickshell.execDetached(command("idle_actions.sh", "sys/idle_actions.sh", ["recover"]))

    property IdleStage dim: IdleStage {
        enabled: root.enabled && root.settings.dimEnabled
        timeout: root.settings.dimTimeout
        respectInhibitors: root.settings.respectAppInhibitors
        conditionCommand: root.conditionCommand
        onConditionChecked: inhibited => root.customInhibited = inhibited
        onApplyRequested: root.enqueue("dim")
        onResumeRequested: root.enqueue("restore")
    }
    property IdleStage lock: IdleStage {
        enabled: root.enabled && root.settings.lockEnabled
        timeout: root.settings.lockTimeout
        respectInhibitors: root.settings.respectAppInhibitors
        conditionCommand: root.conditionCommand
        onConditionChecked: inhibited => root.customInhibited = inhibited
        onApplyRequested: LockState.requestLock()
    }
    property IdleStage display: IdleStage {
        enabled: root.enabled && root.settings.displayOffEnabled
        timeout: root.settings.displayOffTimeout
        respectInhibitors: root.settings.respectAppInhibitors
        conditionCommand: root.conditionCommand
        onConditionChecked: inhibited => root.customInhibited = inhibited
        onApplyRequested: root.enqueue("off")
        onResumeRequested: { root.enqueue("on"); root.enqueue("restore") }
    }
    property IdleStage suspend: IdleStage {
        enabled: root.enabled && root.settings.suspendEnabled
        timeout: root.settings.suspendTimeout
        respectInhibitors: root.settings.respectAppInhibitors
        conditionCommand: root.conditionCommand
        onConditionChecked: inhibited => root.customInhibited = inhibited
        onApplyRequested: root.requestSuspend()
        onResumeRequested: { root.suspendPending = false; if (!root.sleepPending) secureDeadline.stop() }
    }
    property Connections lockSignals: Connections {
        target: LockState
        function onSecureChanged() { root.checkSecure() }
    }
    property Connections inhibitSignals: Connections {
        target: AppState
        function onIdleInhibitedChanged() {
            root.customInhibited = AppState.idleInhibited
            if (AppState.idleInhibited && root.suspendPending) {
                root.suspendPending = false
                suspend.defer()
            }
            for (var key in root.stages) {
                var stage = root.stages[key]
                if (stage.pending) stage.check()
            }
        }
    }
    property Timer secureDeadline: Timer {
        interval: 4000
        onTriggered: {
            if (root.sleepPending && !LockState.secure) root.error = "External sleep lock was not secured before the deadline"
            if (root.suspendPending) {
                root.error = "Idle suspend canceled: session lock is not secure"
                root.suspendPending = false
                suspend.defer()
            }
            if (root.error) console.error(root.error)
        }
    }
    property Process suspendCheck: Process {
        onExited: code => {
            if (!root.suspendPending || !root.enabled || !suspend.applied) return
            root.customInhibited = code !== 0
            if (code !== 0 || !LockState.secure) {
                root.suspendPending = false
                suspend.defer()
                return
            }
            secureDeadline.stop()
            root.suspendPending = false
            power.command = root.command("power_ctl.sh", "backend/system/power_ctl.sh", ["suspend"])
            power.running = true
        }
    }
    property Process power: Process {
        onExited: code => {
            if (code !== 0) { root.error = "Idle suspend request failed"; suspend.defer() }
        }
    }
    property Process effects: Process {
        onExited: code => {
            var action = root.currentJob.action
            root.currentJob = null
            if (code !== 0) {
                root.error = "Idle action failed: " + action
                if (action === "dim") { dim.defer(); root.enqueue("restore") }
                else if (action === "off") { display.defer(); root.enqueue("on") }
                else { root.recoveryAction = action; recoveryRetry.restart() }
            } else if (action === "recover") root.recovered = true
            if (action === "off" && root.sleepPending && LockState.secure && watch.running) {
                secureDeadline.stop()
                watch.write("secure " + root.sleepSerial + "\n")
            }
            root.runNext()
        }
    }
    property Timer recoveryRetry: Timer {
        interval: 30000
        onTriggered: root.enqueue(root.recoveryAction)
    }
    property Process watch: Process {
        command: root.command("idle_session_watch.py", "backend/system/idle_session_watch.py", [])
        stdinEnabled: true
        stdout: SplitParser { onRead: line => root.sessionEvent(line) }
        onExited: code => {
            root.logindReady = false
            if (root.owner) { root.error = "Logind idle bridge disconnected"; watchRetry.restart() }
        }
    }
    property Timer watchRetry: Timer {
        interval: 3000
        onTriggered: if (root.owner) watch.running = true
    }
}
