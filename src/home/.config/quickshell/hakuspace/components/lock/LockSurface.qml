import QtQuick
import Quickshell.Io
import "../../services"
import "../base" as Base
import "LockMotion.js" as LM

Item {
    id: root
    clip: true

    property bool interactive: true
    property bool animationsEnabled: true
    property string previewPhase: ""
    // Expose visual milestones for lock-specific runtime probes.
    readonly property alias motionController: motion
    readonly property alias inputReady: motion.inputReadyEmitted
    readonly property bool inputFocused: authPill.inputFocused

    // Suspend only after the compositor confirms the session is securely covered.
    readonly property bool canSuspend: root.interactive && root.animationsEnabled && root.inputReady
        && root.previewPhase === "" && LockState.locked && LockState.secure
        && LockState.authState !== "Authenticating" && LockState.authState !== "Success"
        && !suspendProcess.running

    // All colors and typography tokens sourced directly from Hikai's reactive Theme singleton.
    readonly property color bgInkColor: Theme.surface
    readonly property color fgPaperColor: Theme.accent
    readonly property color primaryTextColor: Theme.fg
    readonly property color mutedLabelColor: Theme.fgDim

    readonly property var layoutMetrics: LM.metrics(width, height, Theme.fontSize)
    readonly property var orbitGeo: LM.orbitGeometry(layoutMetrics, motion.motionState)
    readonly property var dropletsGeo: LM.dropletsGeometry(layoutMetrics, orbitGeo, motion.motionState)
    readonly property var pillGeo: LM.authPillGeometry(layoutMetrics, motion.motionState)

    // Fade the ink independently of the permanent opaque security cover.
    readonly property real visualOpacity: motion.reducedMotion ? 1
        : LM.smoothstep(LM.remap(motion.captureProgress, 0, 0.8))
          * (1 - 0.35 * LM.smoothstep(motion.successProgress))
          * (1 - LM.smoothstep(motion.releaseProgress))

    // Refocus only once the local secure surface is ready for keyboard input.
    function focusInput() {
        if (!root.inputReady || !root.interactive || LockState.authState === "Success") return
        authPill.focusInput()
    }

    // Clear the transient local password buffer.
    function clearInput() {
        authPill.clearInput()
    }

    // Use the same power action as the shell's power menu without releasing the lock.
    function suspendSession() {
        // Process starts before its running notification updates the button binding.
        if (!root.canSuspend || suspendProcess.running) return false
        root.clearInput()
        suspendProcess.running = true
        return true
    }

    Process {
        id: suspendProcess
        command: [Env.binDir + "/power_ctl.sh", "suspend"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) console.warn("Lock screen suspend failed:", exitCode)
            root.focusInput()
        }
    }

    // Frame-0 opaque security cover: never animated, never translucent.
    Rectangle {
        id: opaqueCover
        anchors.fill: parent
        color: root.bgInkColor
        opacity: 1.0
    }

    // Clicking anywhere on the background restores input focus and never unlocks.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            root.focusInput()
            mouse.accepted = true
        }
        onWheel: wheel => {
            wheel.accepted = true
        }
    }

    LockMotionController {
        id: motion
        inputFocused: authPill.inputFocused
        animationsEnabled: root.animationsEnabled
        previewPhase: root.previewPhase
        onInputReady: {
            if (root.interactive && (!root.Window.window || root.Window.window.active)) {
                root.focusInput()
            }
        }
    }

    LockLayerTransition {
        anchors.fill: parent
        metrics: root.layoutMetrics
        motionState: motion.motionState
        inkColor: root.fgPaperColor
    }

    // Orbit container centered on the output
    Item {
        id: orbitBox
        width: root.layoutMetrics.orbitSize
        height: root.layoutMetrics.orbitSize
        anchors.centerIn: parent

        LiquidOrbit {
            anchors.fill: parent
            visible: motion.captureProgress >= 1 && motion.releaseProgress === 0
            orbit: root.orbitGeo
            inkColor: root.fgPaperColor
        }

        InkDropletField {
            anchors.fill: parent
            droplets: root.dropletsGeo
            inkColor: root.fgPaperColor
        }

        // Central AuthCore inside the orbit
        Item {
            id: coreBox
            width: root.layoutMetrics.coreWidth
            height: coreColumn.implicitHeight
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -(authPill.y + authPill.height * 0.5 - height * 0.5) * root.pillGeo.mergeProgress

            Column {
                id: coreColumn
                width: parent.width
                spacing: 0

                // Eyebrow: HIKAI / LOCK
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "HIKAI / LOCK"
                    color: root.mutedLabelColor
                    font.family: Theme.fontFamily
                    font.pixelSize: root.layoutMetrics.eyebrowPixelSize
                    font.weight: Font.Bold
                    font.letterSpacing: root.layoutMetrics.eyebrowPixelSize * 0.2
                    opacity: root.pillGeo.contentOpacity
                }

                Item { width: 1; height: root.layoutMetrics.compact ? Theme.pad : Theme.pad + Theme.gap * 2 }

                // Large responsive clock
                Text {
                    id: clockLabel
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDateTime(Clock.date, "hh:mm")
                    color: root.primaryTextColor
                    font.family: Theme.fontFamily
                    font.pixelSize: root.layoutMetrics.clockPixelSize
                    font.weight: Font.Normal
                    font.letterSpacing: -root.layoutMetrics.clockPixelSize * 0.06
                    lineHeight: 0.84
                    scale: root.pillGeo.clockScale
                    opacity: root.pillGeo.contentOpacity
                }

                Item { width: 1; height: root.layoutMetrics.compact ? Theme.pad : Theme.pad + Theme.gap * 2 }

                // Date label: THU · 22 OCT
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDateTime(Clock.date, "ddd · dd MMM").toUpperCase()
                    color: root.mutedLabelColor
                    font.family: Theme.fontFamily
                    font.pixelSize: root.layoutMetrics.eyebrowPixelSize
                    font.weight: Font.Bold
                    font.letterSpacing: root.layoutMetrics.eyebrowPixelSize * 0.2
                    opacity: root.pillGeo.contentOpacity
                }

                Item { width: 1; height: root.layoutMetrics.compact ? Theme.pad * 2 : Theme.pad * 3 + Theme.gap }

                // Liquid Auth Capsule
                LockAuthPill {
                    id: authPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    pillGeo: root.pillGeo
                    pillColor: root.fgPaperColor
                    pillTextColor: Theme.onAccentColor
                    submitBgColor: Theme.onAccentColor
                    submitFgColor: root.fgPaperColor
                    interactive: root.interactive && root.animationsEnabled && root.inputReady && root.previewPhase === ""
                    onKeystrokeTyped: motion.pulseKeystroke()
                }

                Item { width: 1; height: Theme.pad + Theme.gap }

                // Restrained auth feedback (TRY AGAIN / AUTHENTICATING / etc.)
                Text {
                    width: parent.width
                    height: Theme.fontSize
                    horizontalAlignment: Text.AlignHCenter
                    text: LockState.statusMessage
                    color: (LockState.authState === "Failed" || LockState.authState === "Error")
                           ? root.fgPaperColor : root.mutedLabelColor
                    font.family: Theme.fontFamily
                    font.pixelSize: root.layoutMetrics.eyebrowPixelSize
                    font.weight: Font.Bold
                    font.letterSpacing: root.layoutMetrics.eyebrowPixelSize * 0.2
                    opacity: LockState.statusMessage.length > 0 ? root.pillGeo.contentOpacity : 0
                }
            }
        }
    }

    // Keep the sleep action inside the secure surface and the existing lock fade.
    Base.HButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.pad * 2
        width: Math.max(52, Theme.fontSize * 4)
        height: Math.max(44, Theme.fontSize * 3)
        radius: height * 0.5
        text: "󰒲"
        fontSize: Theme.fontSize + 2
        enabled: root.canSuspend
        activeFocusOnTab: enabled
        focused: activeFocus
        Accessible.role: Accessible.Button
        Accessible.name: "Suspend"
        Accessible.onPressAction: root.suspendSession()
        Keys.onSpacePressed: event => { root.suspendSession(); event.accepted = true }
        Keys.onReturnPressed: event => { root.suspendSession(); event.accepted = true }
        Keys.onEnterPressed: event => { root.suspendSession(); event.accepted = true }
        onClicked: root.suspendSession()
    }

    // Blend the composed ink uniformly so merged shapes retain one solid silhouette.
    Rectangle {
        anchors.fill: parent
        color: root.bgInkColor
        opacity: 1 - root.visualOpacity
    }
}
