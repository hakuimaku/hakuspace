pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam

QtObject {
    id: root

    // Authoritative session-lock state owned by a single controller.
    property bool locked: false
    property bool secure: false
    property int lockSessionId: 0
    property double lockedSinceMs: 0
    // Shared visual exit origin; authorization still belongs to the unlock timer.
    property double successSinceMs: 0

    // Explicit PAM state machine: Idle | WaitingInput | Authenticating | Failed | Error | Success
    property string authState: "Idle"
    property string statusMessage: ""
    property int failureCount: 0
    property int clearGeneration: 0
    property int unlockDelayMs: root.reducedMotion ? 180 : 850
    property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"

    // Transient secret held only until PamContext requests its conversation response.
    property string _pendingPassword: ""
    property bool _responseSent: false

    signal clearInputRequested()
    signal refocusInputRequested()

    function _wipeSecret() {
        root._pendingPassword = ""
        root._responseSent = false
    }

    function _clearAndRefocus() {
        root._wipeSecret()
        root.clearGeneration += 1
        root.clearInputRequested()
        root.refocusInputRequested()
    }

    // IPC-safe status payload (never includes password or secret material).
    function status() {
        return JSON.stringify({
            locked: root.locked,
            secure: root.secure,
            authState: root.authState,
            statusMessage: root.statusMessage,
            lockSessionId: root.lockSessionId
        })
    }

    // Request a native Wayland session lock. Safe to call repeatedly while already locked.
    function requestLock() {
        UiState.activePanel = ""
        UiState.closeTempNote()
        TooltipManager.dismiss()

        if (root.locked) {
            if (root.authState !== "Authenticating" && root.authState !== "Success") {
                root.refocusInputRequested()
            }
            return "ok"
        }

        unlockTimer.stop()
        pamWatchdog.stop()
        if (pam.active) pam.abort()
        root._wipeSecret()

        root.lockSessionId += 1
        root.lockedSinceMs = Date.now()
        root.successSinceMs = 0
        root.authState = "WaitingInput"
        root.statusMessage = ""
        root.locked = true
        root.clearGeneration += 1
        root.clearInputRequested()
        root.refocusInputRequested()
        return "ok"
    }

    // Notify the controller when the user starts typing after a failure/error.
    function noteUserInput() {
        if (!root.locked) return
        if (root.authState === "Failed" || root.authState === "Error" || root.authState === "Idle") {
            root.authState = "WaitingInput"
            root.statusMessage = ""
        }
    }

    // Submit a non-empty password to PAM. Only one PAM attempt may run at a time.
    function submit(password) {
        if (!root.locked) return false
        if (root.authState === "Authenticating" || root.authState === "Success" || pam.active) {
            return false
        }
        var secret = String(password !== undefined && password !== null ? password : "")
        if (secret.length === 0) {
            return false
        }

        root._pendingPassword = secret
        root._responseSent = false
        secret = ""
        root.authState = "Authenticating"
        root.statusMessage = "AUTHENTICATING"
        pamWatchdog.restart()

        if (!pam.start()) {
            pamWatchdog.stop()
            root.authState = "Error"
            root.statusMessage = "AUTH ERROR"
            root.failureCount += 1
            root._clearAndRefocus()
            return false
        }
        return true
    }

    function _deliverPendingPassword() {
        if (!pam.active || !pam.responseRequired) return
        if (!root._responseSent && root._pendingPassword.length > 0) {
            var pw = root._pendingPassword
            root._pendingPassword = ""
            root._responseSent = true
            pam.respond(pw)
            pw = ""
        } else {
            // Do not hang on unexpected multi-factor prompts without input.
            pam.respond("")
        }
    }

    // Only PAM success via the independent unlock timer may call this function.
    function _completeUnlockAfterPamSuccess() {
        if (root.authState !== "Success") return
        root._wipeSecret()
        root.locked = false
        root.secure = false
        root.lockedSinceMs = 0
        root.successSinceMs = 0
        root.authState = "Idle"
        root.statusMessage = ""
    }

    property PamContext pam: PamContext {
        id: pam
        onPamMessage: {
            if (responseRequired) {
                root._deliverPendingPassword()
            }
        }
        onCompleted: result => {
            pamWatchdog.stop()
            root._wipeSecret()
            if (!root.locked) return

            if (result === PamResult.Success) {
                root.clearGeneration += 1
                root.clearInputRequested()
                root.successSinceMs = Date.now()
                root.authState = "Success"
                root.statusMessage = "UNLOCKING"
                unlockTimer.interval = Math.max(1, root.unlockDelayMs)
                unlockTimer.restart()
            } else if (result === PamResult.Failed || result === PamResult.MaxTries) {
                root.authState = "Failed"
                root.statusMessage = result === PamResult.MaxTries ? "MAX TRIES" : "TRY AGAIN"
                root.failureCount += 1
                root._clearAndRefocus()
            } else {
                root.authState = "Error"
                root.statusMessage = "AUTH ERROR"
                root.failureCount += 1
                root._clearAndRefocus()
            }
        }
        onError: err => {
            pamWatchdog.stop()
            root._wipeSecret()
            if (!root.locked) return
            root.authState = "Error"
            root.statusMessage = "AUTH ERROR"
            root.failureCount += 1
            root._clearAndRefocus()
        }
    }

    // Independent unlock timer: animation completion never gates or triggers unlock.
    property Timer unlockTimer: Timer {
        id: unlockTimer
        interval: root.unlockDelayMs
        repeat: false
        onTriggered: root._completeUnlockAfterPamSuccess()
    }

    // Guard against a stalled PAM module so the UI can recover cleanly while staying locked.
    property Timer pamWatchdog: Timer {
        id: pamWatchdog
        interval: 15000
        repeat: false
        onTriggered: {
            if (!root.locked || root.authState !== "Authenticating") return
            if (pam.active) pam.abort()
            root.authState = "Error"
            root.statusMessage = "AUTH ERROR"
            root.failureCount += 1
            root._clearAndRefocus()
        }
    }
}
