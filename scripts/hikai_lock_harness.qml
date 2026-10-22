import QtQuick
import Quickshell
import "services"
import "components/lock"

ShellRoot {
    id: root

    // Track lock milestones and actual PAM results without storing passwords in logs.
    property int stage: 0
    property int clearEvents: 0
    property int readyEvents: 0
    property double pamSuccessAt: 0
    property bool sawCapture: false
    property bool sawBloom: false
    property bool sawOpeningFade: false
    property bool sawClosingFade: false
    property bool checkedPreview: false
    property var lateSurface: null
    property string pamTestDir: Quickshell.env("HAKUSPACE_TEST_PAM_DIR") || ""

    // Fail immediately with a secret-free diagnostic.
    function check(ok, message) {
        if (ok) return
        console.error("Hikai lock check failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }

    // Start an actual isolated PAM conversation and reject concurrent attempts.
    function submitWrongPassword() {
        check(LockState.submit("wrong-pass"), "invalid password submission accepted")
        check(LockState.authState === "Authenticating", "authenticating state active")
        check(!LockState.submit("second-parallel-attempt"), "parallel PAM submission rejected")
        root.stage = 1
    }

    Connections {
        target: LockState
        function onClearInputRequested() { root.clearEvents += 1 }
    }
    Connections {
        target: surface.motionController
        function onInputReady() { root.readyEvents += 1 }
    }

    LockSurface {
        id: surface
        width: 1920
        height: 1080
    }
    LockSurface {
        id: secondSurface
        width: 2560
        height: 1440
        interactive: false
    }
    LockSurface {
        id: previewSurface
        width: 1280
        height: 720
        interactive: false
        previewPhase: "Idle"
    }
    Component {
        id: surfaceFactory
        LockSurface { width: 1280; height: 720; interactive: false }
    }
    Component {
        id: motionFactory
        LockMotionController {
            locked: true
            authState: "WaitingInput"
            failureCount: 0
            successSinceMs: 0
        }
    }

    Component.onCompleted: {
        check(pamTestDir.length > 0, "HAKUSPACE_TEST_PAM_DIR provided")
        LockState.pam.configDirectory = pamTestDir
        LockState.pam.config = "test-prompt"
        check(LockState.unlockDelayMs === (LockState.reducedMotion ? 180 : 850), "production unlock timing")

        // Every preview, including exit phases, remains unable to alter security state.
        for (var phase of ["LockIn", "Capture", "Bloom", "Idle", "Focused", "Authenticating", "Failed", "Success", "Reabsorb", "Release"]) {
            previewSurface.previewPhase = phase
            check(!LockState.locked, "preview phase " + phase + " cannot lock or unlock")
        }
        previewSurface.previewPhase = "Idle"

        // Theme changes must preserve a fully opaque cover.
        Theme.apply(JSON.stringify({
            accent: "#8cbbb3", surfaceHi: "#8cbbb3", fg: "#8cbbb3",
            fgDim: "rgba(140, 187, 179, 0.8)", fgMuted: "rgba(255, 255, 255, 0.5)",
            font: "JetBrainsMono Nerd Font", fontSize: 15, pad: 12, gap: 4
        }))
        check(surface.bgInkColor.a === 1, "opaque Theme.surface background")
        check(surface.fgPaperColor.toString() === "#8cbbb3", "orbit and pill use Theme.accent")
        check(surface.primaryTextColor.toString() === "#8cbbb3", "clock uses Theme.fg")
        check(!LockState.locked && LockState.authState === "Idle", "initial unlocked state")
        check(!LockState.submit("secret"), "submit while unlocked rejected")

        check(LockState.requestLock() === "ok", "requestLock succeeds")
        check(LockState.locked && LockState.authState === "WaitingInput", "immediate lock state")
        check(LockState.lockSessionId === 1, "lockSessionId incremented")
        check(root.clearEvents >= 1, "input cleared on lock start")
        check(!LockState.submit(""), "empty password rejected")

        // Late-created controllers join capture, bloom, or Ready using elapsed time.
        for (var elapsed of [250, 1000, 3000]) {
            var probe = motionFactory.createObject(surface, { lockedSinceMs: Date.now() - elapsed })
            check(probe.captureProgress >= (LockState.reducedMotion ? 1 : Math.min(1, elapsed / 525)) - 0.03,
                "late controller joins capture timeline")
            check(probe.entryProgress >= (LockState.reducedMotion ? 1 : Math.max(0, Math.min(1, (elapsed - 525) / 1675))) - 0.03,
                "late controller joins bloom timeline")
            check(probe.inputReadyEmitted === (LockState.reducedMotion || elapsed >= 1150), "late input readiness")
            probe.destroy()
        }
    }

    Timer {
        interval: 10
        repeat: true
        running: true
        onTriggered: {
            var elapsed = Date.now() - LockState.lockedSinceMs
            var motion = surface.motionController
            if (LockState.locked) {
                root.check(surface.bgInkColor.a === 1 && secondSurface.bgInkColor.a === 1, "cover opaque through every phase")
                root.check(surface.opacity === 1 && surface.visualOpacity >= 0 && surface.visualOpacity <= 1,
                    "fade affects ink only and stays within opacity bounds")
                if (LockState.reducedMotion) {
                    root.check(surface.visualOpacity === 1, "reduced motion skips ink fades")
                } else if (motion.captureProgress > 0 && motion.captureProgress < 0.8) {
                    root.check(surface.visualOpacity > 0 && surface.visualOpacity < 1, "capture fades in gradually")
                    root.sawOpeningFade = true
                }
                root.check(Math.abs(motion.captureProgress - secondSurface.motionController.captureProgress) < 0.15,
                    "capture synchronized across outputs")
                root.check(Math.abs(motion.releaseProgress - secondSurface.motionController.releaseProgress) < 0.15,
                    "release synchronized across outputs")
                if (!root.checkedPreview) {
                    for (var phase of ["Capture", "Bloom", "Idle", "Focused", "Authenticating", "Failed", "Reabsorb", "Release"]) {
                        previewSurface.previewPhase = phase
                        root.check(LockState.locked && LockState.authState === "WaitingInput", "locked preview cannot alter security")
                    }
                    previewSurface.previewPhase = "Idle"
                    root.checkedPreview = true
                }
            }
            if (root.stage === 0) {
                if (motion.captureProgress < 1) root.sawCapture = true
                if (motion.captureProgress === 1 && motion.entryProgress < 1) root.sawBloom = true
                if (!surface.inputReady) return
                root.check(root.readyEvents === 1, "input-ready emitted once")
                if (LockState.reducedMotion) {
                    root.check(motion.entryProgress === 1 && motion.releaseProgress === 0, "reduced motion directly Ready")
                } else {
                    root.check(elapsed >= 1080 && elapsed < 1450, "keyboard ready around 1150ms")
                    root.check(motion.entryProgress < 1, "input ready before visual settle")
                    root.check(root.sawCapture && root.sawBloom, "capture and bloom observed")
                }
                root.submitWrongPassword()
            } else if (root.stage === 1 && LockState.authState !== "Authenticating") {
                root.check(LockState.authState === "Failed", "wrong password reaches Failed")
                root.check(LockState.statusMessage === "TRY AGAIN", "failure status shown")
                root.check(LockState.locked && motion.releaseProgress === 0, "wrong password never releases")
                root.check(LockState.failureCount === 1 && root.clearEvents > 1, "failure count and input wipe")
                root.check(LockState.status().indexOf("wrong-pass") === -1, "no secret in status")
                LockState.noteUserInput()
                root.check(LockState.authState === "WaitingInput" && LockState.statusMessage === "", "typing clears failure")
                root.stage = 2
            } else if (root.stage === 2 && elapsed >= 2400) {
                root.check(motion.entryProgress === 1, "entry settles around 2200ms")
                root.check(surface.visualOpacity === 1 && (LockState.reducedMotion || root.sawOpeningFade),
                    "ink reaches full opacity after opening fade")
                root.check(root.readyEvents === 1, "settle does not emit input-ready twice")
                surface.animationsEnabled = false
                surface.animationsEnabled = true
                root.check(root.readyEvents === 1 && surface.inputReady, "surface revalidation does not repeat input-ready")
                root.lateSurface = surfaceFactory.createObject(secondSurface)
                root.check(root.lateSurface.inputReady && root.lateSurface.motionController.entryProgress === 1,
                    "hotplug after settle skips dramatic capture")
                root.check(!root.lateSurface.inputFocused, "noninteractive hotplug never steals focus")
                root.check(LockState.submit("correct-pass"), "valid password submitted")
                root.stage = 3
            } else if (root.stage === 3 && LockState.authState === "Success") {
                root.pamSuccessAt = LockState.successSinceMs
                root.check(root.pamSuccessAt > 0 && LockState.locked, "PAM success retains lock and records exit origin")
                root.check(!LockState.submit("extra"), "submit blocked during success")
                root.stage = 4
            } else if (root.stage === 4) {
                var successElapsed = Date.now() - root.pamSuccessAt
                if (LockState.locked) {
                    if (!LockState.reducedMotion && motion.successProgress > 0 && motion.successProgress < 1) {
                        root.check(surface.visualOpacity > 0.65 && surface.visualOpacity < 1, "reabsorption fades toward the handoff nucleus")
                        root.sawClosingFade = true
                    }
                    if (successElapsed < LockState.unlockDelayMs - 30)
                        root.check(LockState.authState === "Success", "session remains locked through reabsorption")
                    root.check(motion.releaseProgress === 0, "desktop reveal waits for independent unlock")
                    if (LockState.reducedMotion) root.check(motion.releaseProgress === 0, "reduced success has no viewport wave")
                    return
                }
                root.check(successElapsed >= LockState.unlockDelayMs - 30, "independent timer controls unlock")
                root.check(LockState.reducedMotion || root.sawClosingFade, "closing fade precedes desktop reveal")
                root.check(LockState.authState === "Idle" && LockState.successSinceMs === 0, "exit state resets")
                root.lateSurface.destroy()
                root.check(LockState.requestLock() === "ok" && LockState.lockSessionId === 2, "repeated lock cycle")
                root.check(motion.successProgress === 0 && motion.releaseProgress === 0, "exit channels reset on relock")
                root.check(LockState.submit("correct-pass"), "second cycle submits")
                root.stage = 5
            } else if (root.stage === 5 && LockState.authState === "Success") {
                // Stopping every visual animation cannot block or authorize the PAM timer.
                surface.animationsEnabled = false
                secondSurface.animationsEnabled = false
                root.check(LockState.locked, "stopping animation never unlocks")
                root.stage = 6
            } else if (root.stage === 6 && !LockState.locked) {
                console.info("Hikai lock checks passed (reducedMotion=" + LockState.reducedMotion + ")")
                Qt.quit()
            }
        }
    }
}
