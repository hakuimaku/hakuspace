import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "TaskManagerGridGeometry.js" as GridGeometry

PanelWindow {
    id: root
    objectName: "taskManagerOverlayMonitor"

    required property var modelData
    property string outputName: ""
    Component.onCompleted: outputName = modelData ? modelData.name : ""

    readonly property bool activeOnScreen: !!outputName && TaskManagerOverlayState.screenHasOverlayOrDrag(outputName)
    readonly property bool releaseReady: !activeOnScreen
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"

    readonly property var telemetrySnapshot: TaskManagerService.ready
        ? TaskManagerService.snapshot
        : TaskManagerOverlayState.snapshot

    readonly property var pillSpec: GridGeometry.pillDimensions(Theme.fontSize, Theme.spaceSm, Theme.spaceLg)
    readonly property var usable: GridGeometry.usableArea(width, height, { padding: 0 })

    readonly property bool capturingOverlayDrag: TaskManagerOverlayState.isDraggingFromOverlayOnScreen(outputName)

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-task-metric-overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: activeOnScreen

    // Click-through everywhere except active detached pills (or full screen only during an overlay drag)
    mask: Region {
        Region {
            x: 0; y: 0
            width: root.capturingOverlayDrag ? root.width : 0
            height: root.capturingOverlayDrag ? root.height : 0
        }
        Region {
            x: cpuOverlayItem.activeHere ? cpuOverlayItem.x : 0
            y: cpuOverlayItem.activeHere ? cpuOverlayItem.y : 0
            width: cpuOverlayItem.activeHere ? cpuOverlayItem.width : 0
            height: cpuOverlayItem.activeHere ? cpuOverlayItem.height : 0
            radius: cpuOverlayItem.height / 2
        }
        Region {
            x: gpuOverlayItem.activeHere ? gpuOverlayItem.x : 0
            y: gpuOverlayItem.activeHere ? gpuOverlayItem.y : 0
            width: gpuOverlayItem.activeHere ? gpuOverlayItem.width : 0
            height: gpuOverlayItem.activeHere ? gpuOverlayItem.height : 0
            radius: gpuOverlayItem.height / 2
        }
        Region {
            x: ramOverlayItem.activeHere ? ramOverlayItem.x : 0
            y: ramOverlayItem.activeHere ? ramOverlayItem.y : 0
            width: ramOverlayItem.activeHere ? ramOverlayItem.width : 0
            height: ramOverlayItem.activeHere ? ramOverlayItem.height : 0
            radius: ramOverlayItem.height / 2
        }
    }

    // Ghost pill while dragging out of HakuMenu onto the screen
    TaskManagerMetricPill {
        id: externalDragGhost
        objectName: "taskManagerOverlayExternalGhost"
        z: 20
        visible: TaskManagerOverlayState.isDraggingFromMenuOnScreen(root.outputName)
            && TaskManagerOverlayState.dragOutsideMenu
        metricId: TaskManagerOverlayState.dragMetricId || "cpu"
        snapshot: root.telemetrySnapshot
        inOverlay: true
        pressed: true
        reducedMotion: root.reducedMotion
        width: root.pillSpec.width
        height: root.pillSpec.height
        x: TaskManagerOverlayState.dragTargetX
        y: TaskManagerOverlayState.dragTargetY
    }

    component OverlayPillSlot: Item {
        id: pillSlot
        required property string metricId
        objectName: "taskManagerDetachedPillSlot_" + metricId

        readonly property var entry: TaskManagerOverlayState.detachedOverlays[metricId] || null
        readonly property bool activeHere: !!entry && entry.active && entry.screenName === root.outputName
        readonly property bool beingDragged: activeHere
            && TaskManagerOverlayState.isDraggingFromOverlayOnScreen(root.outputName)
            && TaskManagerOverlayState.dragMetricId === metricId

        readonly property var clampedPos: activeHere
            ? GridGeometry.clampPosition(entry.x, entry.y, root.pillSpec, root.usable)
            : ({ x: 0, y: 0 })

        property bool showUsed: false
        property bool dismissConfirm: false

        onActiveHereChanged: {
            if (!activeHere) {
                showUsed = false
                dismissConfirm = false
                dismissConfirmTimer.stop()
            }
        }

        visible: activeHere
        z: beingDragged ? 15 : 5
        width: activeHere ? root.pillSpec.width : 0
        height: activeHere ? root.pillSpec.height : 0
        x: beingDragged ? TaskManagerOverlayState.dragTargetX : clampedPos.x
        y: beingDragged ? TaskManagerOverlayState.dragTargetY : clampedPos.y

        Behavior on x {
            enabled: !pillSlot.beingDragged && !root.reducedMotion && pillSlot.activeHere
            NumberAnimation {
                duration: HAnimation.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.moduleCurve
            }
        }

        Behavior on y {
            enabled: !pillSlot.beingDragged && !root.reducedMotion && pillSlot.activeHere
            NumberAnimation {
                duration: HAnimation.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.moduleCurve
            }
        }

        function handleLeftClick() {
            if (dismissConfirm) {
                dismissConfirm = false
                dismissConfirmTimer.stop()
            }
            showUsed = !showUsed
        }

        function handleRightClick() {
            if (!dismissConfirm) {
                dismissConfirm = true
                dismissConfirmTimer.restart()
            } else {
                dismissConfirmTimer.stop()
                dismissConfirm = false
                TaskManagerOverlayState.dismissOverlay(metricId)
            }
        }

        Timer {
            id: dismissConfirmTimer
            interval: 2200
            repeat: false
            onTriggered: pillSlot.dismissConfirm = false
        }

        TaskManagerMetricPill {
            id: visualPill
            objectName: "taskManagerOverlayPill_" + pillSlot.metricId
            anchors.fill: parent
            metricId: pillSlot.metricId
            snapshot: root.telemetrySnapshot
            inOverlay: true
            showUsed: pillSlot.showUsed
            dismissConfirm: pillSlot.dismissConfirm
            hovered: pillMouse.containsMouse && !pillMouse.dragStarted
            pressed: pillMouse.pressed
            reducedMotion: root.reducedMotion
        }

        MouseArea {
            id: pillMouse
            objectName: "taskManagerOverlayPillMouse_" + pillSlot.metricId
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: dragStarted ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real pressX: 0
            property real pressY: 0
            property bool dragStarted: false

            onPressed: mouse => {
                pressX = mouse.x
                pressY = mouse.y
                dragStarted = false
            }

            onPositionChanged: mouse => {
                if (!(mouse.buttons & Qt.LeftButton) || !pillSlot.activeHere) return

                if (!dragStarted) {
                    if (Math.hypot(mouse.x - pressX, mouse.y - pressY) < 6) return
                    pillSlot.dismissConfirm = false
                    dismissConfirmTimer.stop()
                    var startPt = pillSlot.mapToItem(null, mouse.x, mouse.y)
                    dragStarted = TaskManagerOverlayState.beginOverlayDrag(
                        pillSlot.metricId,
                        root.outputName,
                        startPt.x,
                        startPt.y,
                        pillSlot.width,
                        pillSlot.height,
                        pressX,
                        pressY
                    )
                }

                if (!dragStarted) return
                var pt = pillSlot.mapToItem(null, mouse.x, mouse.y)
                var rawX = pt.x - pressX
                var rawY = pt.y - pressY
                var resolved = GridGeometry.resolveMagneticPosition(
                    rawX,
                    rawY,
                    root.pillSpec,
                    root.usable,
                    TaskManagerOverlayState.otherOverlaysForScreen(root.outputName, pillSlot.metricId, root.pillSpec),
                    { gap: Theme.spaceSm }
                )
                TaskManagerOverlayState.updateDrag(pt.x, pt.y, true, resolved, -1)
            }

            onReleased: mouse => {
                if (dragStarted) {
                    TaskManagerOverlayState.commitOverlayDrag()
                    dragStarted = false
                    return
                }

                if (mouse.x < 0 || mouse.x > width || mouse.y < 0 || mouse.y > height) return
                if (mouse.button === Qt.RightButton) pillSlot.handleRightClick()
                else if (mouse.button === Qt.LeftButton) pillSlot.handleLeftClick()
            }

            onCanceled: {
                if (dragStarted) {
                    TaskManagerOverlayState.cancelDrag()
                    dragStarted = false
                }
            }
        }
    }

    OverlayPillSlot { id: cpuOverlayItem; metricId: "cpu" }
    OverlayPillSlot { id: gpuOverlayItem; metricId: "gpu" }
    OverlayPillSlot { id: ramOverlayItem; metricId: "ram" }
}
