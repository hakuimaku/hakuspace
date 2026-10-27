import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "services/idle"

ShellRoot {
    id: root
    // Exercise production controllers through a private IPC target and fake system commands.
    property int applications: 0
    property int resumes: 0
    readonly property bool nativeEnabled: IdleService.enabled
    IdleStage {
        id: stage
        enabled: false
        timeout: 0.2
        conditionCommand: ["sh", "-c", "exit 0"]
        onApplyRequested: root.applications += 1
        onResumeRequested: root.resumes += 1
    }
    // Preserve the same lock authority used by shell.qml across a reload.
    PersistentProperties {
        id: lockMemory
        reloadableId: "idle-hardening-lock"
        property bool locked: false
        onLoaded: if (locked) LockState.requestLock()
    }
    Connections { target: LockState; function onLockedChanged() { lockMemory.locked = LockState.locked } }
    IpcHandler {
        target: "probe"
        function status(): string {
            var state = JSON.parse(IdleService.status())
            state.token = IdleService.ownerToken
            state.queued = IdleService.jobs.length
            state.mutating = IdleService.effects.running
            state.recoveryRetry = IdleService.recoveryRetry.running
            state.recovered = IdleService.recovered
            state.cleanupRequired = IdleService.cleanupRequired
            state.checkingSuspend = IdleService.suspendCheck.running
            state.sleepAcknowledged = IdleService.sleepAcknowledged
            state.locked = LockState.locked
            state.secure = LockState.secure
            state.error = IdleService.error
            state.testStage = stage.status()
            state.applications = root.applications
            state.resumes = root.resumes
            return JSON.stringify(state)
        }
        function stagePolicy(seconds: real, respect: bool, active: bool) {
            stage.timeout = seconds
            stage.respectInhibitors = respect
            stage.enabled = active
        }
        function backend(value: string) { AppState.shellBackend = value }
        function release(): string { return IdleService.release() }
        function acquire(): string { return IdleService.acquire() }
        function force(name: string): string { return IdleService.forceStage(name) }
        function resume(name: string) { IdleService.stages[name].reset() }
        function secure(value: bool) { LockState.secure = value }
        function lockFailure(value: bool) { LockState.failRequests = value }
        function stageCondition(allowed: bool) { stage.conditionCommand = ["sh", "-c", allowed ? "exit 0" : "exit 2"] }
        function event(sleeping: bool, serial: int) { IdleService.sessionEvent(JSON.stringify({event: "prepare-sleep", sleeping: sleeping, serial: serial})) }
        function deadline(milliseconds: int) { IdleService.secureDeadline.interval = milliseconds }
        function retry(milliseconds: int) {
            IdleService.recoveryRetry.interval = milliseconds
            stage.retry.interval = milliseconds
            for (var key in IdleService.stages) IdleService.stages[key].retry.interval = milliseconds
        }
        function policy(key: string, value: bool) {
            var draft = JSON.parse(JSON.stringify(ShellSettingsStore.savedValues))
            draft.idle[key] = value
            ShellSettingsStore.savedValues = draft
        }
        function draftPolicy(key: string, value: bool) {
            var draft = JSON.parse(JSON.stringify(ShellSettingsStore.values))
            draft.idle[key] = value
            ShellSettingsStore.values = draft
        }
        function applySettings() {
            ShellSettingsStore.savedValues = JSON.parse(JSON.stringify(ShellSettingsStore.values))
        }
        function manual(value: bool) { AppState.idleInhibited = value }
        function reload() { Quickshell.reload(false) }
        function logBurst() { for (var i = 0; i < 200; ++i) IdleService.logEvent("test-event", {index: i}) }
    }
}
