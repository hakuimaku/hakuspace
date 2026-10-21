import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"

ShellRoot {
    id: root
    // Stages exercise both wipes, queued hold, quit, and cancellation.
    property int stage: 0
    property double coveredAt: 0
    property bool quitSeen: false
    property bool accentLed: false
    property bool blackLed: false
    property var overlays: []
    property double canceledAt: 0

    // Fail the isolated runtime immediately on a broken contract.
    function check(ok, message) {
        if (ok) return
        console.error("Shell transition failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }

    Connections {
        target: ShellTransitionState
        function onFinishedAndQuit() {
            root.check(ShellTransitionState.phase === "finished" && !ShellTransitionState.active,
                "quit follows final animation")
            root.check(ShellTransitionState.accentProgress === 2 && ShellTransitionState.blackProgress === 2,
                "both layers have left before quit")
            root.quitSeen = true
        }
    }

    // Inspect live progress rather than replacing the real animation engine.
    Timer {
        interval: 10; repeat: true; running: true
        onTriggered: {
            if (ShellTransitionState.phase === "covering"
                && ShellTransitionState.accentProgress > ShellTransitionState.blackProgress)
                root.accentLed = true
            if (ShellTransitionState.phase === "releasing"
                && ShellTransitionState.blackProgress > ShellTransitionState.accentProgress)
                root.blackLed = true
            if (root.stage === 0 && ShellTransitionState.phase === "covered") {
                root.coveredAt = Date.now()
                root.check(ShellTransitionState.accentProgress === 1 && ShellTransitionState.blackProgress === 1,
                    "covered waits for both layers")
                root.check(ShellTransitionState.release(true) === "error:mode", "quit direction validated")
                root.check(ShellTransitionState.setChrome(true) === "ok", "chrome created under cover")
                root.check(ShellTransitionState.release(false) === "ok", "release queues during hold")
                root.check(ShellTransitionState.phase === "covered", "hold blocks immediate release")
                root.stage = 1
            } else if (root.stage === 1 && ShellTransitionState.phase === "releasing") {
                root.check(Date.now() - root.coveredAt >= Theme.shellTransitionHoldDuration - 25,
                    "minimum hold elapsed")
                root.stage = 2
            } else if (root.stage === 2 && ShellTransitionState.phase === "finished") {
                root.check(root.accentLed && root.blackLed, "accent entry and trailing bands exist")
                root.check(!root.quitSeen && !ShellTransitionState.active, "normal release keeps runtime alive")
                root.check(ShellTransitionState.begin("hikai-to-classic") === "ok", "mirrored begin")
                root.check(ShellTransitionState.direction === "down", "mirrored direction")
                root.stage = 3
            } else if (root.stage === 3 && ShellTransitionState.phase === "covered") {
                root.check(ShellTransitionState.release(true) === "error:mode", "quit requires hidden chrome")
                root.check(ShellTransitionState.setChrome(false) === "ok", "chrome destroyed under cover")
                root.check(ShellTransitionState.release(true) === "ok", "quit release queued")
                root.check(!root.quitSeen, "quit cannot precede reveal")
                root.stage = 4
            } else if (root.stage === 4 && root.quitSeen) {
                ShellTransitionState.begin("classic-to-hikai")
                ShellTransitionState.cancel()
                root.check(ShellTransitionState.phase === "idle" && !ShellTransitionState.active,
                    "cancel clears animation and input")
                root.check(!ShellTransitionState.chromeEnabled, "cancel preserves chrome gate")
                root.canceledAt = Date.now()
                root.stage = 5
            } else if (root.stage === 5 && Date.now() - root.canceledAt > Theme.shellTransitionAccentDuration
                + Theme.shellTransitionBlackDelay + Theme.shellTransitionHoldDuration) {
                root.check(ShellTransitionState.phase === "idle", "canceled animation cannot publish covered")
                console.info("Shell transition checks passed")
                Qt.quit()
            }

            // The actual surfaces use local output height in both directions.
            for (var overlay of root.overlays) {
                for (var height of [720, 1080, 1440, 2160]) {
                    var sign = ShellTransitionState.direction === "up" ? 1 : -1
                    root.check(overlay.layerY(0, height) === sign * height, "entry geometry")
                    root.check(overlay.layerY(1, height) === 0, "covered geometry")
                    root.check(overlay.layerY(2, height) === -sign * height, "exit geometry")
                }
            }
        }
    }

    Component.onCompleted: {
        if (Quickshell.env("HAKUSPACE_TRANSITION_SURFACES") === "1") {
            var factory = Qt.createComponent("components/ShellTransitionOverlay.qml")
            check(factory.status === Component.Ready, factory.errorString())
            for (var screen of Quickshell.screens)
                overlays.push(factory.createObject(root, { modelData: screen }))
            check(overlays.length === 2 && overlays.every(item => item !== null), "two output surfaces")
        }
        check(ShellTransitionState.chromeEnabled ===
            (Quickshell.env("HAKUSPACE_SHELL_TRANSITION_BOOTSTRAP") !== "classic-to-hikai"), "bootstrap gate")
        check(ShellTransitionState.begin("invalid") === "error:mode", "invalid mode rejected")
        check(ShellTransitionState.release(false) === "error:phase", "idle release rejected")
        check(ShellTransitionState.setChrome(false) === "error:phase", "unguarded chrome change rejected")
        check(ShellTransitionState.begin("classic-to-hikai") === "ok", "first begin")
        check(ShellTransitionState.chromeOverlayLayer === WlrLayer.Top, "transient surfaces stay below wipe")
        check(ShellTransitionState.direction === "up", "forward direction")
        check(ShellTransitionState.begin("hikai-to-classic") === "error:busy", "second begin rejected")
        check(ShellTransitionState.release(false) === "error:phase", "early release rejected")
    }
}
