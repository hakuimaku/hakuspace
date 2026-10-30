import QtQuick
import Quickshell
import "services"
import "components/lock"

ShellRoot {
    id: root
    // Synthetic visual events are independent from the separate real PAM regression test.
    property int stage: 0
    // Bound the test even if a visual milestone never arrives.
    property double startedAt: Date.now()
    // Compare counters across settled intervals rather than guessing frame completion.
    property double phaseAt: Date.now()
    // Count geometry changes on both simulated output sizes.
    property int geometryUpdates: 0
    // Retain the last stable update count for quiet/off checks.
    property int previousUpdates: 0
    // Detect real idle/auth phase changes across a short active interval.
    property real previousPhase: 0
    // Preserve the lock generation through display-off/on transitions.
    property int sessionId: 0
    // Verify failure feedback remains animated in both accessibility paths.
    property bool sawFailure: false
    // Keep the displayed timestamp stable while the logical clock advances off-screen.
    property date offDate: new Date()

    LockSurface { id: first; width: 1920; height: 1080; interactive: false }
    LockSurface { id: second; width: 1280; height: 720; interactive: false }
    // A surface powered off during entry joins elapsed time when it becomes drawable.
    LockMotionController {
        id: interruptedEntry
        locked: true; lockSessionId: 999; lockedSinceMs: root.startedAt
        authState: "WaitingInput"; failureCount: 0; successSinceMs: 0
        displayActive: false
    }
    Connections { target: first; function onOrbitGeoChanged() { ++root.geometryUpdates } }
    Connections { target: second; function onOrbitGeoChanged() { ++root.geometryUpdates } }

    // Fail without logging input or authentication secrets.
    function check(value, message) {
        if (value) return
        console.error("Lock visual lifecycle failed at " + stage + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Snapshot stable values after every intentional state transition.
    function next() {
        ++stage
        phaseAt = Date.now()
        previousUpdates = geometryUpdates
        previousPhase = first.motionController.idlePhase
    }

    Component.onCompleted: {
        Clock._clock.precision = SystemClock.Seconds
        first.motionController.ambientDuration = 150
        second.motionController.ambientDuration = 150
        LockState.requestLock()
        sessionId = LockState.lockSessionId
    }
    Timer {
        interval: 20; repeat: true; running: true
        onTriggered: {
            root.check(Date.now() - root.startedAt < 10000, "milestone timeout")
            var motion = first.motionController
            var elapsed = Date.now() - root.phaseAt
            if (motion.failureImpulse > 0) root.sawFailure = true
            switch (root.stage) {
            case 0:
                if (motion.entryProgress !== 1 || !first.inputReady || !second.inputReady) return
                root.check(motion.captureProgress === 1, "entry completes before quiet")
                root.check(!interruptedEntry.inputReadyEmitted, "powered-off entry does not publish input readiness")
                interruptedEntry.displayActive = true
                root.check(interruptedEntry.captureProgress === 1 && interruptedEntry.entryProgress === 1
                    && interruptedEntry.inputReadyEmitted, "late display-on joins Ready without replaying entry")
                if (!LockState.reducedMotion) root.check(!motion.quiescent, "entry starts finite ambient motion")
                root.next(); break
            case 1:
                if (!motion.quiescent || !second.motionController.quiescent) return
                root.next(); break
            case 2:
                if (elapsed < 120) return
                root.check(root.geometryUpdates === root.previousUpdates, "quiet geometry is stable")
                motion.pulseKeystroke()
                second.motionController.wakeAmbient()
                root.next(); break
            case 3:
                if (elapsed < 40) return
                if (!LockState.reducedMotion) root.check(!motion.quiescent && motion.idlePhase !== root.previousPhase, "interaction wakes idle motion")
                IdleService.displayOff = true
                root.offDate = first.displayedDate
                root.check(!motion.displayActive && !second.motionController.displayActive, "all output visuals freeze immediately")
                root.next(); break
            case 4:
                if (elapsed < 1200) return
                root.check(root.geometryUpdates === root.previousUpdates && motion.idlePhase === root.previousPhase, "power-off freezes geometry and idle phase")
                root.check(first.displayedDate.getTime() === root.offDate.getTime()
                    && Clock.date.getTime() > root.offDate.getTime(), "clock presentation freezes while logical time advances")
                LockState.authState = "Authenticating"
                root.next(); break
            case 5:
                if (elapsed < 120) return
                root.check(root.geometryUpdates === root.previousUpdates, "off-screen auth has no visual tween")
                LockState.authState = "WaitingInput"
                IdleService.displayOff = false
                root.check(first.displayedDate.getTime() === Clock.date.getTime(), "display-on refreshes the clock immediately")
                root.check(LockState.lockSessionId === root.sessionId && LockState.authState === "WaitingInput", "display-on preserves auth session")
                root.check(motion.entryProgress === 1 && motion.captureProgress === 1, "display-on skips old entry animation")
                LockState.authState = "Failed"
                ++LockState.failureCount
                root.next(); break
            case 6:
                if (elapsed < 650 || !motion.quiescent) return
                root.check(root.sawFailure, "failure recoil still plays and ends")
                LockState.authState = "Authenticating"
                root.previousPhase = motion.authLoopPhase
                root.stage = 7; root.phaseAt = Date.now(); break
            case 7:
                if (elapsed < 120) return
                if (!LockState.reducedMotion) root.check(motion.authLoopPhase !== root.previousPhase, "visible auth circulation runs")
                IdleService.displayOff = true
                root.next(); break
            case 8:
                if (elapsed < 120) return
                root.check(root.geometryUpdates === root.previousUpdates && LockState.authState === "Authenticating", "off freezes visual auth without cancelling authentication")
                LockState.successSinceMs = Date.now()
                LockState.authState = "Success"
                LockState.unlockTimer.interval = 180
                LockState.unlockTimer.start()
                root.next(); break
            case 9:
                if (LockState.locked) return
                root.check(LockState.authState === "Idle", "independent success timer unlocks while visuals are stopped")
                console.info("Hikai lock visual lifecycle checks passed")
                Qt.quit(); break
            }
        }
    }
}
