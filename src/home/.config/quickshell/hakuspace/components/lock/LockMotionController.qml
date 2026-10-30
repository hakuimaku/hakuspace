import QtQuick
import "../../services"
import "../../config" as Config
import "LockMotion.js" as LM

Item {
    id: root
    visible: false

    // Inputs from LockState and local input focus.
    property bool locked: LockState.locked
    property int lockSessionId: LockState.lockSessionId
    property double lockedSinceMs: LockState.lockedSinceMs
    property double successSinceMs: LockState.successSinceMs
    property string authState: LockState.authState
    property int failureCount: LockState.failureCount
    property bool inputFocused: false
    property bool animationsEnabled: true
    // Freeze visual work while confirmed display power or sleep state is inactive.
    property bool displayActive: true
    // Developer tests shorten this window without changing production policy.
    property int ambientDuration: Config.Motion.lockAmbientDuration
    // Resume the idle cycle from its current silhouette after a quiet interval.
    property real ambientStartPhase: 0
    property bool reducedMotion: LockState.reducedMotion

    // Optional visual-only preview state for isolated harness testing (never unlocks).
    property string previewPhase: ""

    // Normalized motion channels (0..1) consumed by LockMotion.js.
    property real captureProgress: 0
    property real releaseProgress: 0
    property bool inputReadyEmitted: false
    property int inputReadySessionId: -1
    property bool initialized: false
    property real entryProgress: 0
    property real idlePhase: 0
    property real focusProgress: 0
    property real authPressure: 0
    property real authLoopPhase: 0
    property real failureImpulse: 0
    property real keystrokeImpulse: 0
    property real successProgress: 0

    // Quiescence excludes every running visual tween, not only the idle loop.
    readonly property bool quiescent: locked && captureProgress === 1 && entryProgress === 1
        && !idleLoop.running && !authCirculationLoop.running && !failureAnim.running
        && !keystrokeAnim.running && !successAnim.running && !releaseSequence.running
        && !focusAnim.running && !pressureAnim.running

    readonly property bool isAuthenticating: (previewPhase === "Authenticating")
                                             || (previewPhase === "" && authState === "Authenticating")
    readonly property bool isSuccess: (["Success", "Reabsorb", "Release"].indexOf(previewPhase) !== -1)
                                      || (previewPhase === "" && authState === "Success")

    readonly property string visualPhase: {
        if (previewPhase !== "") return previewPhase
        if (!locked) return "SecureCover"
        if (isSuccess) return releaseProgress > 0 ? "Release" : "Reabsorb"
        if (failureAnim.running || authState === "Failed" || authState === "Error") return "Failed"
        if (isAuthenticating) return "Authenticating"
        if (captureProgress < 1) return "Capture"
        if (entryProgress < 1) return "Bloom"
        if (inputFocused) return "Focused"
        return "Idle"
    }

    readonly property var motionState: ({
        captureProgress: root.captureProgress,
        releaseProgress: root.releaseProgress,
        entryProgress: root.entryProgress,
        idlePhase: root.idlePhase,
        focusProgress: root.focusProgress,
        authPressure: root.authPressure,
        authLoopPhase: root.authLoopPhase,
        failureImpulse: root.failureImpulse,
        keystrokeImpulse: root.keystrokeImpulse,
        successProgress: root.successProgress,
        reducedMotion: root.reducedMotion
    })

    signal lockInFinished()
    signal inputReady()

    // Publish keyboard readiness once per session, independently of visual settle.
    function markInputReady() {
        if (root.inputReadySessionId === root.lockSessionId && root.previewPhase === "") return
        root.inputReadySessionId = root.lockSessionId
        root.inputReadyEmitted = true
        root.inputReady()
    }

    // Stop visual work without changing the authoritative session-lock state.
    function stopMotion() {
        ambientHold.stop()
        focusAnim.stop()
        pressureAnim.stop()
        captureAnim.stop()
        entrySequence.stop()
        releaseSequence.stop()
        successAnim.stop()
        failureAnim.stop()
        keystrokeAnim.stop()
        inputReadyTimer.stop()
    }

    // Extend a finite ambient window without restarting an active cycle or auth session.
    function wakeAmbient(duration) {
        if (!root.animationsEnabled || !root.displayActive || root.reducedMotion
                || (!root.locked && !root.previewPhase) || root.entryProgress < 1
                || root.isAuthenticating || root.isSuccess) return
        if (!idleLoop.running) root.ambientStartPhase = root.idlePhase % 1
        ambientHold.interval = duration === undefined ? root.ambientDuration : Math.max(1, duration)
        ambientHold.restart()
    }

    // Standalone tweens can stop immediately when power turns off; Behavior child jobs cannot.
    function syncAuthMotion() {
        if (root.previewPhase || root.isSuccess) return
        focusAnim.stop()
        pressureAnim.stop()
        var focus = root.inputFocused || root.isAuthenticating ? 1 : 0
        var pressure = root.isAuthenticating ? 1 : 0
        if (!root.animationsEnabled || !root.displayActive || !root.locked) {
            root.focusProgress = focus
            root.authPressure = pressure
        } else {
            if (root.focusProgress !== focus) { focusAnim.to = focus; focusAnim.start() }
            if (root.authPressure !== pressure) { pressureAnim.to = pressure; pressureAnim.start() }
        }
    }

    // Join the shared lock timeline, including surfaces created during hotplug.
    function startLockIn(elapsed) {
        stopMotion()
        root.successProgress = 0
        root.releaseProgress = 0
        root.failureImpulse = 0
        root.keystrokeImpulse = 0
        root.idlePhase = 0
        root.authLoopPhase = 0
        root.inputReadyEmitted = root.previewPhase === "" && root.inputReadySessionId === root.lockSessionId
        root.captureProgress = root.reducedMotion ? 1 : LM.clamp(elapsed / 525, 0, 1)
        root.entryProgress = root.reducedMotion ? 1 : LM.clamp((elapsed - 525) / 1675, 0, 1)
        syncAuthMotion()
        if (!root.animationsEnabled || !root.displayActive) return
        if (root.captureProgress < 1) {
            captureAnim.from = root.captureProgress
            captureAnim.duration = Math.max(1, 525 - elapsed)
            captureAnim.start()
        }
        if (root.entryProgress < 1) {
            entryDelay.duration = Math.max(0, 525 - elapsed)
            entryAnim.from = root.entryProgress
            entryAnim.duration = Math.max(1, 2200 - Math.max(525, elapsed))
            entrySequence.start()
        } else {
            root.lockInFinished()
            if (elapsed < 2200 + root.ambientDuration) root.wakeAmbient(2200 + root.ambientDuration - elapsed)
        }
        if (root.reducedMotion || elapsed >= 1150) {
            markInputReady()
        } else {
            inputReadyTimer.interval = Math.max(1, 1150 - elapsed)
            inputReadyTimer.start()
        }
        if (root.isSuccess) startSuccess()
    }

    // Reabsorb and release share the PAM-success timestamp across outputs.
    function startSuccess() {
        successAnim.stop()
        releaseSequence.stop()
        failureAnim.stop()
        keystrokeAnim.stop()
        root.failureImpulse = 0
        root.keystrokeImpulse = 0
        var elapsed = root.previewPhase === "" && root.successSinceMs > 0
            ? Math.max(0, Date.now() - root.successSinceMs) : 0
        var duration = root.reducedMotion ? 160 : 850
        root.successProgress = LM.clamp(elapsed / duration, 0, 1)
        // Secure surfaces hold the nucleus; only previews render the post-unlock phase.
        root.releaseProgress = root.reducedMotion || root.previewPhase === "" ? 0
            : LM.clamp((elapsed - 850) / 1600, 0, 1)
        if (!root.animationsEnabled || !root.displayActive) return
        if (root.successProgress < 1) {
            successAnim.from = root.successProgress
            successAnim.duration = Math.max(1, duration - elapsed)
            successAnim.start()
        }
        if (!root.reducedMotion && root.previewPhase !== "" && root.releaseProgress < 1) {
            releaseDelay.duration = Math.max(0, 850 - elapsed)
            releaseAnim.from = root.releaseProgress
            releaseAnim.duration = Math.max(1, 2450 - Math.max(850, elapsed))
            releaseSequence.start()
        }
    }

    // Apply a restrained local impulse for password edits.
    function pulseKeystroke() {
        root.wakeAmbient()
        if (!root.animationsEnabled || !root.displayActive || root.reducedMotion || root.isAuthenticating || root.isSuccess) return
        keystrokeAnim.restart()
    }

    // Recoil stays local and never restarts the layer transition.
    function triggerFailureRecoil() {
        if (!root.animationsEnabled || !root.displayActive || root.isSuccess) return
        root.wakeAmbient()
        failureAnim.stop()
        root.failureImpulse = 0
        failureAnim.duration = root.reducedMotion ? 180 : 520
        failureAnim.start()
    }

    // Preview phases exercise geometry only and cannot authorize an unlock.
    function applyPreviewPhase(phase) {
        if (!phase) return
        startLockIn(2200)
        root.focusProgress = 0
        root.authPressure = 0
        if (phase === "LockIn" || phase === "Capture") {
            startLockIn(0)
        } else if (phase === "Bloom") {
            startLockIn(625)
        } else if (phase === "Focused" || phase === "Authenticating" || phase === "Failed") {
            root.focusProgress = 1
            root.authPressure = phase === "Authenticating" ? 1 : 0
            if (phase === "Failed") triggerFailureRecoil()
        } else if (phase === "Success" || phase === "Reabsorb") {
            startSuccess()
        } else if (phase === "Release") {
            stopMotion()
            root.successProgress = 1
            root.releaseProgress = 0
            releaseDelay.duration = 0
            releaseAnim.from = 0
            releaseAnim.duration = 1600
            if (!root.reducedMotion) releaseSequence.start()
        }
    }

    onPreviewPhaseChanged: {
        if (!root.initialized) return
        if (previewPhase !== "") applyPreviewPhase(previewPhase)
        else if (locked) startLockIn(Math.max(0, Date.now() - lockedSinceMs))
    }
    onLockedChanged: {
        if (!root.initialized || root.previewPhase !== "") return
        if (root.locked) startLockIn(Math.max(0, Date.now() - root.lockedSinceMs))
        else stopMotion()
    }
    onFailureCountChanged: {
        if (root.initialized && root.previewPhase === "" && root.locked && root.failureCount > 0 && !root.isSuccess)
            triggerFailureRecoil()
    }
    onIsSuccessChanged: {
        if (root.initialized && root.previewPhase === "" && root.isSuccess) startSuccess()
    }
    onIsAuthenticatingChanged: {
        if (root.isAuthenticating) ambientHold.stop()
        else if (root.initialized) root.wakeAmbient()
        if (root.initialized) root.syncAuthMotion()
    }
    onInputFocusedChanged: if (root.initialized) root.syncAuthMotion()
    onDisplayActiveChanged: {
        if (!root.initialized) return
        if (!root.displayActive) { stopMotion(); syncAuthMotion() }
        else {
            if (root.previewPhase) applyPreviewPhase(root.previewPhase)
            else if (root.locked) startLockIn(Math.max(0, Date.now() - root.lockedSinceMs))
            root.wakeAmbient()
        }
    }
    Component.onCompleted: {
        root.initialized = true
        if (root.previewPhase !== "") applyPreviewPhase(root.previewPhase)
        else if (root.locked) startLockIn(Math.max(0, Date.now() - root.lockedSinceMs))
    }
    onAnimationsEnabledChanged: {
        if (!root.initialized) return
        if (!root.animationsEnabled) { stopMotion(); syncAuthMotion() }
        else if (root.previewPhase !== "") applyPreviewPhase(root.previewPhase)
        else if (root.locked) startLockIn(Math.max(0, Date.now() - root.lockedSinceMs))
    }
    onReducedMotionChanged: {
        if (!root.initialized) return
        if (root.previewPhase !== "") applyPreviewPhase(root.previewPhase)
        else if (root.locked) startLockIn(Math.max(0, Date.now() - root.lockedSinceMs))
    }

    Timer {
        id: ambientHold
    }

    Timer {
        id: inputReadyTimer
        onTriggered: root.markInputReady()
    }

    NumberAnimation {
        id: captureAnim
        target: root
        property: "captureProgress"
        to: 1
        easing.type: Easing.Linear
    }

    SequentialAnimation {
        id: entrySequence
        PauseAnimation { id: entryDelay }
        NumberAnimation {
            id: entryAnim
            target: root
            property: "entryProgress"
            to: 1
            easing.type: Easing.Linear
        }
        onFinished: { root.lockInFinished(); root.wakeAmbient() }
    }

    SequentialAnimation {
        id: releaseSequence
        PauseAnimation { id: releaseDelay }
        NumberAnimation {
            id: releaseAnim
            target: root
            property: "releaseProgress"
            to: 1
            easing.type: Easing.Linear
        }
    }

    NumberAnimation {
        id: idleLoop
        target: root
        property: "idlePhase"
        from: root.ambientStartPhase
        to: root.ambientStartPhase + 1
        duration: 10000
        loops: Animation.Infinite
        running: root.animationsEnabled && root.displayActive && ambientHold.running
            && (root.locked || root.previewPhase !== "") && !root.reducedMotion
        paused: running && (root.entryProgress < 0.7 || root.isSuccess)
    }

    NumberAnimation {
        id: focusAnim
        target: root
        property: "focusProgress"
        duration: root.reducedMotion ? 90 : 220
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: pressureAnim
        target: root
        property: "authPressure"
        duration: root.reducedMotion ? 100 : 260
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: authCirculationLoop
        target: root
        property: "authLoopPhase"
        from: 0
        to: 1
        duration: 1120
        loops: Animation.Infinite
        running: root.animationsEnabled && root.displayActive && (root.isAuthenticating || root.isSuccess) && !root.reducedMotion
        paused: running && (root.isSuccess || root.entryProgress < 0.3)
    }

    NumberAnimation {
        id: failureAnim
        target: root
        property: "failureImpulse"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.Linear
        onFinished: root.failureImpulse = 0
    }

    SequentialAnimation {
        id: keystrokeAnim
        NumberAnimation {
            target: root
            property: "keystrokeImpulse"
            from: 0
            to: 1
            duration: 34
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "keystrokeImpulse"
            from: 1
            to: 0
            duration: 46
            easing.type: Easing.InOutQuad
        }
    }

    NumberAnimation {
        id: successAnim
        target: root
        property: "successProgress"
        from: 0
        to: 1
        duration: 850
        easing.type: Easing.Linear
    }
}
