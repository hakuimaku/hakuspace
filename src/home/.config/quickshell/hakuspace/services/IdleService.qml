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
    readonly property bool owner: AppState.shellBackend === "hikai" && !relinquished
    property bool releasing: false
    property bool recovering: false
    property bool relinquished: false
    property bool resetting: false
    property int generation: 0
    // Tokens fence detached cleanup against a newer QML instance under the helper lock.
    readonly property string ownerToken: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    property bool brightnessOwned: false
    property bool displayOwned: false
    // Confirm power-off only after the compositor action succeeds.
    // shortcut: observes native idle actions; add compositor events for external DPMS changes.
    property bool displayOff: false
    readonly property bool cleanupRequired: brightnessOwned || displayOwned
    readonly property var settings: ShellSettingsStore.savedValues.idle
    readonly property bool enabled: Policy.active(AppState.shellBackend,
        owner && !releasing && !recovering && ShellSettingsStore.ready && recovered && logindReady, settings.enabled)
    property bool recovered: false
    property bool logindReady: false
    // Common policy owns diagnostics; individual stage results cannot overwrite it.
    property bool audioInhibited: false
    property bool inhibitKnown: false
    property string inhibitError: ""
    property int inhibitGeneration: -1
    property double inhibitCheckedAtMs: 0
    readonly property var customInhibit: ({manual: AppState.idleInhibited,
        audioPolicyEnabled: settings.inhibitOnAudio,
        audio: audioInhibited, effective: AppState.idleInhibited || (settings.inhibitOnAudio && audioInhibited) || !!inhibitError,
        known: inhibitKnown, refreshing: inhibitRead.running, checkedAtMs: inhibitCheckedAtMs, error: inhibitError})
    readonly property bool customInhibited: customInhibit.effective
    property bool sleepPending: false
    property int sleepSerial: 0
    property bool suspendPending: false
    property string error: ""
    // Keep a bounded diagnostic history while the normal Quickshell log remains streamable.
    property var runtimeEvents: []
    property string lastInhibitLog: ""
    // A bounded action queue preserves restore ordering during rapid activity.
    property var jobs: []
    property var currentJob: null
    property string recoveryAction: "recover"
    property int recoveryGeneration: -1
    property int suspendGeneration: -1
    property int suspendCheckGeneration: -1
    property int suspendCheckStageGeneration: -1
    property int powerGeneration: -1
    property int powerStageGeneration: -1
    property int sleepAcknowledged: -1
    readonly property var stages: ({dim: dim, lock: lock, displayOff: display, suspend: suspend})
    readonly property var conditionCommand: command("idle_inhibit.sh", "sys/idle_inhibit.sh",
        ["--condition"].concat(settings.inhibitOnAudio ? [] : ["--no-audio"]))

    // Record transitions only, without polling or logging application metadata.
    function logEvent(eventName, details) {
        var entry = Object.assign({time: new Date().toISOString(), event: eventName,
            backend: AppState.shellBackend, generation: generation}, details || {})
        runtimeEvents = runtimeEvents.slice(-127).concat([entry])
        console.info("[idle] " + JSON.stringify(entry))
    }
    // IPC consumers can inspect recent events without opening or creating another log file.
    function logs() { return JSON.stringify(runtimeEvents) }
    // Log only policy changes; status polling must not flood the runtime log.
    function logInhibit() {
        var state = {manual: AppState.idleInhibited, audioPolicyEnabled: settings.inhibitOnAudio, audio: audioInhibited,
            effective: customInhibited, known: inhibitKnown, error: inhibitError}
        var serialized = JSON.stringify(state)
        if (serialized === lastInhibitLog) return
        lastInhibitLog = serialized
        logEvent("inhibitors", state)
    }

    // Resolve installed helpers or the source tree without evaluating user text.
    function command(name, source, args) {
        return ["sh", "-c", 'if [ -x "$1" ]; then script=$1; else script=$2; fi; shift 2; exec "$script" "$@"',
            "--", Env.binDir + "/" + name,
            Quickshell.shellPath("../../../../core/" + source)].concat(args || [])
    }
    // Refresh only on demand and coalesce overlapping diagnostic reads.
    function refreshInhibit() {
        if (!owner || releasing || inhibitRead.running) return
        inhibitGeneration = generation
        inhibitRead.command = command("idle_inhibit.sh", "sys/idle_inhibit.sh",
            ["--status-json"].concat(settings.inhibitOnAudio ? [] : ["--no-audio"]))
        inhibitRead.running = true
    }
    // Replace queued effects of the same kind and capture their ownership generation.
    function enqueue(action) {
        if (!owner || resetting || (releasing && action !== "recover" && action !== "claim")) return
        if (action === "claim" && currentJob && currentJob.action === "claim" && currentJob.generation === generation) return
        var family = action === "dim" || action === "restore" ? "brightness" : "display"
        var job = {action: action, family: family, generation: generation}
        if (action === "recover" || action === "claim") jobs = [job]
        else jobs = jobs.filter(entry => entry.family !== family).concat([job])
        runNext()
    }
    // Recheck ownership at dispatch; a queued old-generation action is never started.
    function runNext() {
        if (!owner || currentJob || effects.running || !jobs.length) { finishRelease(); return }
        var job = jobs[0]
        jobs = jobs.slice(1)
        if (job.generation !== generation ||
            (job.action === "dim" && (!enabled || !dim.applied)) ||
            (job.action === "off" && !sleepPending && (!enabled || !display.applied))) {
            runNext()
            return
        }
        currentJob = job
        logEvent("action-start", {action: job.action})
        if (job.action === "dim") brightnessOwned = true
        if (job.action === "off") displayOwned = true
        effects.command = command("idle_actions.sh", "sys/idle_actions.sh",
            ["--owner", ownerToken, job.action].concat(job.action === "dim" ? [String(settings.dimPercent)] : []))
        effects.running = true
    }
    // Cancel delayed work before restoring effects while native ownership is still held.
    function reset() {
        generation += 1
        recoveryRetry.stop()
        watchRetry.stop()
        secureDeadline.stop()
        suspendPending = false
        jobs = []
        resetting = true
        recovering = owner
        for (var key in stages) stages[key].reset()
        resetting = false
        if (owner) enqueue(recovered ? "recover" : "claim")
    }
    // Complete cleanup before publishing a Classic backend commit.
    function release() {
        if (!owner || releasing) return "ok"
        logEvent("release-requested", {})
        releasing = true
        sleepPending = false
        watch.running = false
        reset()
        finishRelease()
        return "ok"
    }
    // Rollback may reacquire this same instance after a failed Classic preparation.
    function acquire() {
        if (AppState.shellBackend !== "hikai") return "error:backend"
        releasing = false
        relinquished = false
        if (!recovered && !effects.running) enqueue("claim")
        if (!watch.running) watch.running = true
        return "ok"
    }
    // A required recovery or retry keeps release pending, including after process failure.
    function finishRelease() {
        if (!releasing || !owner || recovering || effects.running || currentJob || power.running || jobs.length ||
            cleanupRequired || !recovered || recoveryRetry.running || watch.running) return
        relinquished = true
    }
    // A secure compositor lock is mandatory before requesting idle suspend.
    function requestSuspend() {
        if (!enabled || releasing) return
        suspendPending = true
        suspendGeneration = generation
        LockState.requestLock()
        secureDeadline.restart()
        checkSecure()
    }
    // Revalidate custom inhibition after asynchronous lock acquisition.
    function checkSecure() {
        if (!owner || releasing || !LockState.secure) return
        if (sleepPending && sleepAcknowledged !== sleepSerial && watch.running) {
            // Secure lock releases logind; DPMS is a separate best-effort action.
            watch.write("secure " + sleepSerial + "\n")
            logEvent("sleep-ack", {serial: sleepSerial, secure: LockState.secure})
            sleepAcknowledged = sleepSerial
            secureDeadline.stop()
            enqueue("off")
        } else if (suspendPending && enabled && suspend.applied && !suspendCheck.running) {
            suspendCheckGeneration = generation
            suspendCheckStageGeneration = suspend.generation
            suspendCheck.command = conditionCommand
            suspendCheck.running = true
        }
    }
    // Stream only session events; external Unlock never bypasses native authentication.
    function sessionEvent(line) {
        try {
            var event = JSON.parse(line)
            if (!owner || releasing) return
            logEvent("logind", {type: event.event, sleeping: event.sleeping, serial: event.serial})
            if (event.event === "ready") { logindReady = true; error = "" }
            else if (event.event === "lock") LockState.requestLock()
            else if (event.event === "prepare-sleep") {
                if ((event.sleeping === true) === sleepPending && event.serial === sleepSerial) return
                sleepPending = event.sleeping === true
                sleepSerial = event.serial
                if (sleepPending) {
                    LockState.requestLock()
                    secureDeadline.restart()
                    checkSecure()
                } else {
                    secureDeadline.stop()
                    sleepAcknowledged = -1
                    reset()
                }
            } else if (event.event === "error") { logindReady = false; watch.running = false }
        } catch (e) { error = "Invalid logind event" }
    }
    // Expose state without changing policy or triggering system actions.
    function status() {
        refreshInhibit()
        return JSON.stringify({enabled: enabled, owner: owner, generation: generation, releasing: releasing,
            backend: AppState.shellBackend,
            ready: recovered && logindReady && !recovering, configuredEnabled: settings.enabled,
            released: !owner && !effects.running && !currentJob && !jobs.length && !watch.running && !power.running
                && !recoveryRetry.running && !watchRetry.running && !secureDeadline.running && !cleanupRequired
                && Object.keys(stages).every(key => !stages[key].pending && !stages[key].retry.running),
            dim: dim.status(), lock: lock.status(), displayOff: display.status(), suspend: suspend.status(),
            displayPoweredOff: displayOff,
            customInhibit: customInhibit, customInhibited: customInhibited, error: error})
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
        inhibitKnown = false
        audioInhibited = false
        inhibitError = ""
        inhibitCheckedAtMs = 0
        sleepPending = false
        reset()
        if (owner && !releasing) watch.running = true
        else watch.running = false
    }
    onEnabledChanged: {
        logEvent("service-state", {enabled: enabled, owner: owner, recovering: recovering, logindReady: logindReady})
        if (owner && !enabled && !releasing && !recovering) reset()
    }
    onErrorChanged: if (error) logEvent("error", {message: error})
    onSettingsChanged: { inhibitKnown = false; refreshInhibit() }
    Component.onCompleted: {
        logEvent("startup", {enabled: enabled, configured: settings.enabled, timeouts: {
            dim: settings.dimTimeout, lock: settings.lockTimeout, displayOff: settings.displayOffTimeout, suspend: settings.suspendTimeout}})
        if (owner) { enqueue("claim"); watch.running = true; refreshInhibit() }
    }
    // The helper rejects cleanup if a newer QML instance has already claimed its token.
    Component.onDestruction: {
        recoveryRetry.stop()
        watchRetry.stop()
        if (owner) Quickshell.execDetached(command("idle_actions.sh", "sys/idle_actions.sh", ["--owner", ownerToken, "recover"]))
    }

    // Timers are chained cumulatively: dim -> lock -> displayOff -> suspend
    readonly property int effectiveDimTimeout: settings.dimEnabled ? settings.dimTimeout : 0
    readonly property int effectiveLockTimeout: effectiveDimTimeout + (settings.lockEnabled ? settings.lockTimeout : 0)
    readonly property int effectiveDisplayTimeout: effectiveLockTimeout + (settings.displayOffEnabled ? settings.displayOffTimeout : 0)
    readonly property int effectiveSuspendTimeout: effectiveDisplayTimeout + (settings.suspendEnabled ? settings.suspendTimeout : 0)

    property IdleStage dim: IdleStage {
        enabled: root.enabled && root.settings.dimEnabled
        timeout: root.effectiveDimTimeout
        respectInhibitors: root.settings.respectAppInhibitors
        conditionCommand: root.conditionCommand
        onConditionChecked: inhibited => root.refreshInhibit()
        onDiagnostic: (eventName, details) => root.logEvent(eventName, Object.assign({stage: "dim"}, details))
        onApplyRequested: root.enqueue("dim")
        onResumeRequested: root.enqueue("restore")
    }
    property IdleStage lock: IdleStage {
        enabled: root.enabled && root.settings.lockEnabled
        timeout: root.effectiveLockTimeout
        respectInhibitors: root.settings.respectAppInhibitors
        conditionCommand: root.conditionCommand
        onConditionChecked: inhibited => root.refreshInhibit()
        onDiagnostic: (eventName, details) => root.logEvent(eventName, Object.assign({stage: "lock"}, details))
        onApplyRequested: if (root.enabled) LockState.requestLock()
    }
    property IdleStage display: IdleStage {
        enabled: root.enabled && root.settings.displayOffEnabled
        timeout: root.effectiveDisplayTimeout
        respectInhibitors: root.settings.respectAppInhibitors
        conditionCommand: root.conditionCommand
        onConditionChecked: inhibited => root.refreshInhibit()
        onDiagnostic: (eventName, details) => root.logEvent(eventName, Object.assign({stage: "displayOff"}, details))
        onApplyRequested: root.enqueue("off")
        onResumeRequested: { root.enqueue("on"); root.enqueue("restore") }
    }
    property IdleStage suspend: IdleStage {
        enabled: root.enabled && root.settings.suspendEnabled
        timeout: root.effectiveSuspendTimeout
        respectInhibitors: root.settings.respectAppInhibitors
        conditionCommand: root.conditionCommand
        onConditionChecked: inhibited => root.refreshInhibit()
        onDiagnostic: (eventName, details) => root.logEvent(eventName, Object.assign({stage: "suspend"}, details))
        onApplyRequested: root.requestSuspend()
        onResumeRequested: { root.suspendPending = false; if (!root.sleepPending) secureDeadline.stop() }
    }
    property Connections lockSignals: Connections {
        target: LockState
        function onSecureChanged() { root.checkSecure() }
    }
    property Connections inhibitSignals: Connections {
        target: AppState
        function onShellBackendChanged() {
            if (AppState.shellBackend === "hikai") root.acquire()
        }
        function onIdleInhibitedChanged() {
            root.logEvent("manual-inhibit", {enabled: AppState.idleInhibited})
            root.refreshInhibit()
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
            if (!root.owner || root.releasing) return
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
            if (root.suspendCheckGeneration !== root.generation || root.suspendCheckStageGeneration !== suspend.generation) {
                root.checkSecure()
                return
            }
            if (root.suspendGeneration !== root.generation || !root.suspendPending || !root.enabled || !suspend.applied) return
            root.refreshInhibit()
            if (code !== 0 || !LockState.secure) {
                root.suspendPending = false
                suspend.defer()
                return
            }
            secureDeadline.stop()
            root.suspendPending = false
            root.powerGeneration = root.generation
            root.powerStageGeneration = suspend.generation
            power.command = root.command("power_ctl.sh", "backend/system/power_ctl.sh", ["suspend"])
            power.running = true
        }
    }
    property Process power: Process {
        onExited: code => {
            if (root.powerGeneration === root.generation && root.powerStageGeneration === suspend.generation && root.owner && code !== 0) {
                root.error = "Idle suspend request failed"
                suspend.defer()
            }
            root.finishRelease()
        }
    }
    property Process effects: Process {
        onExited: code => {
            var job = root.currentJob
            root.currentJob = null
            if (job) root.logEvent("action-exit", {action: job.action, exitCode: code, stale: job.generation !== root.generation})
            if (!job || job.generation !== root.generation || !root.owner) {
                root.runNext()
                return
            }
            var action = job.action
            if (code !== 0) {
                root.error = "Idle action failed: " + action
                console.error(root.error)
                if (action === "dim") { dim.defer(); root.enqueue("restore") }
                else if (action === "off" && !root.sleepPending) { display.defer(); root.enqueue("on") }
                else if (action !== "off") {
                    root.recovering = true
                    root.recoveryAction = action
                    root.recoveryGeneration = root.generation
                    recoveryRetry.restart()
                }
            } else {
                if (action === "off") root.displayOff = true
                if (action === "on" || action === "recover" || action === "claim") root.displayOff = false
                if (action === "restore" || action === "recover" || action === "claim") root.brightnessOwned = false
                if (action === "on" || action === "recover" || action === "claim") root.displayOwned = false
                if (action === "recover" || action === "claim") root.recovered = true
                if (!root.cleanupRequired && !recoveryRetry.running) root.recovering = false
            }
            root.runNext()
        }
    }
    property Timer recoveryRetry: Timer {
        interval: 30000
        onTriggered: {
            if (!root.owner || root.recoveryGeneration !== root.generation) return
            root.enqueue(root.recoveryAction)
        }
    }
    property Process inhibitRead: Process {
        stdout: StdioCollector { id: inhibitOut }
        onExited: code => {
            if (!root.owner || root.inhibitGeneration !== root.generation) return
            try {
                if (code !== 0) throw new Error("Inhibit helper failed")
                var data = JSON.parse(inhibitOut.text)
                if (typeof data.manual !== "boolean" || typeof data.audio !== "boolean" || typeof data.inhibited !== "boolean")
                    throw new Error("Invalid inhibit response")
                root.audioInhibited = data.audio
                root.inhibitKnown = true
                root.inhibitCheckedAtMs = Date.now()
                root.inhibitError = ""
            } catch (e) {
                root.inhibitKnown = false
                root.inhibitError = String(e)
            }
            root.logInhibit()
        }
    }
    property Process watch: Process {
        command: root.command("idle_session_watch.py", "backend/system/idle_session_watch.py", [])
        stdinEnabled: true
        stdout: SplitParser { onRead: line => root.sessionEvent(line) }
        onExited: code => {
            root.logindReady = false
            if (root.owner && !root.releasing) { root.error = "Logind idle bridge disconnected"; watchRetry.restart() }
            root.finishRelease()
        }
    }
    property Timer watchRetry: Timer {
        interval: 3000
        onTriggered: if (root.owner && !root.releasing) watch.running = true
    }
}
