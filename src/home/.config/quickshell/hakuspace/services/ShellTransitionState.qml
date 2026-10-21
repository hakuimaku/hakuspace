pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

QtObject {
    id: root

    // One lifecycle and progress clock drives every output.
    property string phase: "idle"
    property string mode: ""
    property string direction: "up"
    property bool active: false
    // Keep newly mapped transient chrome below the wipe throughout cutover.
    readonly property int chromeOverlayLayer: active ? WlrLayer.Top : WlrLayer.Overlay
    property bool chromeEnabled: Quickshell.env("HAKUSPACE_SHELL_TRANSITION_BOOTSTRAP") !== "classic-to-hikai"
    property real accentProgress: 0
    property real blackProgress: 0
    property bool releaseRequested: false
    property bool minimumHoldElapsed: false
    property bool quitAfterRelease: false
    property color accentSnapshot: Theme.accent
    signal finishedAndQuit()

    // Report lifecycle without exposing mutable animation progress over IPC.
    function status() {
        return JSON.stringify({ phase: phase, mode: mode, active: active,
            chromeEnabled: chromeEnabled, minimumHoldElapsed: minimumHoldElapsed })
    }

    // Start a validated directional wipe using a fixed accent sample.
    function begin(nextMode) {
        if (nextMode !== "classic-to-hikai" && nextMode !== "hikai-to-classic") return "error:mode"
        if (active) return "error:busy"
        mode = nextMode
        direction = mode === "classic-to-hikai" ? "up" : "down"
        accentSnapshot = Theme.accent
        accentProgress = 0
        blackProgress = 0
        releaseRequested = false
        minimumHoldElapsed = false
        quitAfterRelease = false
        active = true
        phase = "covering"
        cover.start()
        return "ok"
    }

    // Only construct or destroy chrome behind a complete black cover.
    function setChrome(enabled) {
        if (phase !== "covered") return "error:phase"
        chromeEnabled = enabled
        return "ok"
    }

    // Queue release until the QML-owned minimum hold has elapsed.
    function release(quit) {
        if (phase !== "covered") return "error:phase"
        if (quit && (mode !== "hikai-to-classic" || chromeEnabled)) return "error:mode"
        quitAfterRelease = quit
        releaseRequested = true
        tryRelease()
        return "ok"
    }

    // The backend and hold timer must both agree before revealing the shell.
    function tryRelease() {
        if (phase !== "covered" || !releaseRequested || !minimumHoldElapsed) return
        phase = "releasing"
        reveal.start()
    }

    // Clear animation and input state without changing the selected backend.
    function cancel() {
        cover.stop()
        hold.stop()
        reveal.stop()
        active = false
        phase = "idle"
        mode = ""
        accentProgress = 0
        blackProgress = 0
        releaseRequested = false
        minimumHoldElapsed = false
        quitAfterRelease = false
        return "ok"
    }

    // Finish both layers before publishing the full-coverage barrier.
    property ParallelAnimation cover: ParallelAnimation {
        NumberAnimation {
            target: root; property: "accentProgress"; from: 0; to: 1
            duration: Theme.shellTransitionAccentDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.shellTransitionCurve
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.shellTransitionBlackDelay }
            NumberAnimation {
                target: root; property: "blackProgress"; from: 0; to: 1
                duration: Theme.shellTransitionBlackDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.shellTransitionCurve
            }
        }
        onFinished: {
            root.phase = "covered"
            hold.start()
        }
    }

    // Hold begins at full coverage, independently of backend preparation time.
    property Timer hold: Timer {
        interval: Theme.shellTransitionHoldDuration
        onTriggered: {
            root.minimumHoldElapsed = true
            root.tryRelease()
        }
    }

    // Continue in the same direction and quit only after the slower accent exits.
    property ParallelAnimation reveal: ParallelAnimation {
        NumberAnimation {
            target: root; property: "accentProgress"; from: 1; to: 2
            duration: Theme.shellTransitionAccentDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.shellTransitionCurve
        }
        NumberAnimation {
            target: root; property: "blackProgress"; from: 1; to: 2
            duration: Theme.shellTransitionBlackDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.shellTransitionCurve
        }
        onFinished: {
            root.active = false
            root.phase = "finished"
            if (root.quitAfterRelease) root.finishedAndQuit()
        }
    }
}
