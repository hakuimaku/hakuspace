import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "cava"

Item {
    id: rootItem
    // Keep the window alive until its slide back to the screen edge completes.
    readonly property bool releaseReady: !shouldBeVisible && reveal === 0 && !slideAnimation.running
    required property var modelData

    readonly property bool isTop: CavaService.top
    readonly property bool shouldBeVisible: CavaService.enabled && CavaService.available
    // Reopening during dismissal reverses from the current visual position.
    property real reveal: 0
    // Defer the initial reveal until the loader has finished constructing its visual tree.
    function syncReveal() {
        if (rootItem) reveal = shouldBeVisible ? 1 : 0
    }
    onShouldBeVisibleChanged: Qt.callLater(syncReveal)
    Component.onCompleted: Qt.callLater(syncReveal)
    Behavior on reveal {
        NumberAnimation {
            id: slideAnimation
            duration: rootItem.shouldBeVisible ? HAnimation.normal : HAnimation.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: rootItem.shouldBeVisible ? HAnimation.moduleCurve : HAnimation.tooltipCurve
        }
    }
    // Preserve the wave's distance from the selected physical screen edge.
    readonly property int edgeInset: CavaService.edgeInset
    // Niri transforms Bottom layers with workspaces, separately from the visible status bar.
    readonly property bool needsSurface: CavaService.needsSurface
    // Carry the reserved chassis area in the same surface as the wave.
    readonly property real surfaceHeight: needsSurface ? edgeInset : 0

    PanelWindow {
        id: visualWindow
        screen: rootItem.modelData
        anchors {
            top: rootItem.isTop
            bottom: !rootItem.isTop
            left: true
            right: true
        }
        margins {
            left: 0
            right: 0
            bottom: rootItem.isTop ? 0 : rootItem.edgeInset - rootItem.surfaceHeight
            top: rootItem.isTop ? rootItem.edgeInset - rootItem.surfaceHeight : 0
        }
        implicitHeight: CavaService.height + CavaService.ceilingHeadroom + rootItem.surfaceHeight
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
                y: (rootItem.isTop ? -1 : 1) * height * (1 - rootItem.reveal)

                // Move the reserved chassis area together with the wave.
                Rectangle {
                    y: rootItem.isTop ? 0 : parent.height - height
                    width: parent.width
                    height: rootItem.surfaceHeight
                    color: CavaService.underbarColor
                }

                CavaUnderbar {
                    anchors.fill: parent
                    anchors.topMargin: rootItem.isTop ? rootItem.surfaceHeight : 0
                    anchors.bottomMargin: rootItem.isTop ? 0 : rootItem.surfaceHeight
                    screen: rootItem.modelData
                }
            }
        }
    }
}
