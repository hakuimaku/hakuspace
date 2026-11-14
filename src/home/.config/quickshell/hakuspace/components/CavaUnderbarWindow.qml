import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "cava"

Item {
    id: rootItem
    // Keep the window alive until its curtain collapse back to the screen edge completes.
    readonly property bool releaseReady: !shouldBeVisible && !barHidden && !switchingPosition && reveal === 0 && !slideAnimation.running
    required property var modelData

    property string activePosition: "top"
    property int activeEdgeInset: 0
    property bool activeNeedsSurface: false
    property bool switchingPosition: false
    readonly property bool dynamicBarSync: CavaService.dynamicPosition
    readonly property bool barHidden: CavaService.barHidden

    readonly property string position: activePosition
    readonly property bool isVertical: position === "left" || position === "right"
    readonly property bool isLeft: position === "left"
    readonly property bool isRight: position === "right"
    readonly property bool isTop: position === "top"
    readonly property bool isBottom: position === "bottom"
    readonly property bool shouldBeVisible: CavaService.enabled && CavaService.available
    // Reopening during dismissal reverses from the current visual position.
    property real reveal: 0

    function syncTargetEdge() {
        if (!rootItem) return
        if (CavaService.position !== activePosition) {
            if (!shouldBeVisible || (reveal === 0 && !slideAnimation.running)) {
                activePosition = CavaService.position
                activeEdgeInset = CavaService.edgeInset
                activeNeedsSurface = CavaService.needsSurface
                switchingPosition = false
            } else {
                switchingPosition = true
                reveal = 0
            }
            return
        }
        activeEdgeInset = CavaService.edgeInset
        activeNeedsSurface = CavaService.needsSurface
        if (switchingPosition) {
            switchingPosition = false
            Qt.callLater(syncReveal)
        }
    }

    // Defer the initial reveal until the loader has finished constructing its visual tree.
    function syncReveal() {
        if (!rootItem) return
        if (!shouldBeVisible) {
            switchingPosition = false
            reveal = 0
            return
        }
        if (barHidden || switchingPosition) {
            reveal = 0
            return
        }
        reveal = 1
    }

    onRevealChanged: {
        if (switchingPosition && reveal === 0) {
            activePosition = CavaService.position
            activeEdgeInset = CavaService.edgeInset
            activeNeedsSurface = CavaService.needsSurface
            switchingPosition = false
            if (shouldBeVisible) Qt.callLater(syncReveal)
        }
    }

    Connections {
        target: CavaService
        function onPositionChanged() { Qt.callLater(rootItem.syncTargetEdge) }
        function onEdgeInsetChanged() { Qt.callLater(rootItem.syncTargetEdge) }
        function onNeedsSurfaceChanged() { Qt.callLater(rootItem.syncTargetEdge) }
        function onBarHiddenChanged() {
            Qt.callLater(rootItem.syncTargetEdge)
            Qt.callLater(rootItem.syncReveal)
        }
    }

    onShouldBeVisibleChanged: {
        syncTargetEdge()
        Qt.callLater(syncReveal)
    }
    Component.onCompleted: {
        syncTargetEdge()
        Qt.callLater(syncReveal)
    }

    Behavior on reveal {
        NumberAnimation {
            id: slideAnimation
            duration: rootItem.dynamicBarSync ? 500
                : ((rootItem.shouldBeVisible && !rootItem.switchingPosition) ? HAnimation.normal : HAnimation.fast)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: (rootItem.shouldBeVisible && !rootItem.barHidden && !rootItem.switchingPosition) ? HAnimation.moduleCurve : HAnimation.tooltipCurve
        }
    }

    // Preserve the wave's distance from the selected physical screen edge.
    readonly property int edgeInset: activeEdgeInset
    // Niri transforms Bottom layers with workspaces, separately from the visible status bar.
    readonly property bool needsSurface: activeNeedsSurface
    // Carry the reserved chassis area in the same surface as the wave.
    readonly property real surfaceThickness: needsSurface ? edgeInset : 0
    readonly property real surfaceHeight: isVertical ? 0 : surfaceThickness
    readonly property real surfaceWidth: isVertical ? surfaceThickness : 0

    PanelWindow {
        id: visualWindow
        screen: rootItem.modelData
        anchors {
            top: !rootItem.isBottom
            bottom: !rootItem.isTop
            left: !rootItem.isRight
            right: !rootItem.isLeft
        }
        margins {
            left: rootItem.isLeft ? rootItem.edgeInset - rootItem.surfaceWidth : 0
            right: rootItem.isRight ? rootItem.edgeInset - rootItem.surfaceWidth : 0
            bottom: rootItem.isBottom ? rootItem.edgeInset - rootItem.surfaceHeight : 0
            top: rootItem.isTop ? rootItem.edgeInset - rootItem.surfaceHeight : 0
        }
        implicitHeight: rootItem.isVertical ? (visualWindow.screen ? visualWindow.screen.height : 0) : (CavaService.height + CavaService.ceilingHeadroom + rootItem.surfaceHeight)
        implicitWidth: rootItem.isVertical ? (CavaService.height + CavaService.ceilingHeadroom + rootItem.surfaceWidth) : (visualWindow.screen ? visualWindow.screen.width : 0)
        color: "transparent"
        visible: !rootItem.releaseReady

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "hakuspace-cava-underbar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        // Completely pass-through input clicks to desktop or windows
        mask: Region {}

        // Clip the moving contents while keeping Wayland geometry and reservations fixed.
        Item {
            anchors.fill: parent
            clip: true
            Item {
                width: parent.width
                height: parent.height
                x: rootItem.isVertical ? ((rootItem.isLeft ? -1 : 1) * width * (1 - rootItem.reveal)) : 0
                y: !rootItem.isVertical ? ((rootItem.isTop ? -1 : 1) * height * (1 - rootItem.reveal)) : 0

                // Move the reserved chassis area together with the wave.
                Rectangle {
                    visible: rootItem.needsSurface && rootItem.surfaceThickness > 0
                    x: rootItem.isVertical ? (rootItem.isLeft ? 0 : parent.width - width) : 0
                    y: !rootItem.isVertical ? (rootItem.isTop ? 0 : parent.height - height) : 0
                    width: rootItem.isVertical ? rootItem.surfaceWidth : parent.width
                    height: rootItem.isVertical ? parent.height : rootItem.surfaceHeight
                    color: CavaService.underbarColor
                }

                CavaUnderbar {
                    anchors.fill: parent
                    anchors.leftMargin: rootItem.isLeft ? rootItem.surfaceWidth : 0
                    anchors.rightMargin: rootItem.isRight ? rootItem.surfaceWidth : 0
                    anchors.topMargin: rootItem.isTop ? rootItem.surfaceHeight : 0
                    anchors.bottomMargin: rootItem.isBottom ? rootItem.surfaceHeight : 0
                    position: rootItem.position
                    bloom: rootItem.dynamicBarSync ? 1.0 : rootItem.reveal
                    screen: rootItem.modelData
                }
            }
        }
    }
}
