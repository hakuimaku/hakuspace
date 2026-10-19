import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

Item {
    id: rootItem
    required property var modelData

    // Physical corner masks and reservations share the independent screen preferences.
    readonly property real sideInset: ScreenGeometry.borderThickness
    readonly property real cornerRadius: ScreenGeometry.roundedRadius
    readonly property color frameColor: Theme.surface

    // Render masks and three explicit rails with no top border or input region.
    PanelWindow {
        id: visualWindow
        screen: rootItem.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: rootItem.cornerRadius > 0 || rootItem.sideInset > 0

        WlrLayershell.layer: WlrLayer.Top
        exclusiveZone: 0
        // Respect TopBar while keeping the physical frame outside the Dock's zone.
        margins {
            left: -ScreenGeometry.leftInset
            right: -ScreenGeometry.rightInset
            bottom: -ScreenGeometry.bottomInset - ScreenGeometry.dockReservation(rootItem.modelData ? rootItem.modelData.name : "")
        }
        mask: Region {}

        Canvas {
            id: canvas
            anchors.fill: parent

            readonly property real t: rootItem.sideInset
            readonly property real r: ScreenGeometry.maskRadius(width, height)
            readonly property color c: rootItem.frameColor

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onTChanged: requestPaint()
            onRChanged: requestPaint()
            onCChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var h = height

                ctx.clearRect(0, 0, w, h)
                ctx.fillStyle = c

                // Corner masks follow the inner side/bottom bounds independently of rail width.
                if (r > 0) {
                    ctx.beginPath()
                    ctx.moveTo(t, 0)
                    ctx.lineTo(t + r, 0)
                    ctx.arc(t + r, r, r, -Math.PI / 2, Math.PI, true)
                    ctx.closePath()
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(w - t, 0)
                    ctx.lineTo(w - t, r)
                    ctx.arc(w - t - r, r, r, 0, -Math.PI / 2, true)
                    ctx.closePath()
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(w - t, h - t)
                    ctx.lineTo(w - t - r, h - t)
                    ctx.arc(w - t - r, h - t - r, r, Math.PI / 2, 0, true)
                    ctx.closePath()
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(t, h - t)
                    ctx.lineTo(t, h - t - r)
                    ctx.arc(t + r, h - t - r, r, Math.PI, Math.PI / 2, true)
                    ctx.closePath()
                    ctx.fill()
                }
                if (t > 0) {
                    ctx.fillRect(0, 0, t, h)
                    ctx.fillRect(w - t, 0, t, h)
                    ctx.fillRect(0, h - t, w, t)
                }
            }
        }
    }

    // Reserve physical borders before the lower-layer Dock reserves its inner space.
    // Top edge is reserved by TopBar; bottom, left, and right are reserved here.
    PanelWindow {
        id: bottomReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        anchors { bottom: true; left: true; right: true }
        exclusiveZone: ScreenGeometry.bottomInset
        implicitHeight: ScreenGeometry.bottomInset
        mask: Region {}
        visible: rootItem.sideInset > 0
    }

    PanelWindow {
        id: leftReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        anchors { top: true; bottom: true; left: true }
        exclusiveZone: ScreenGeometry.leftInset
        implicitWidth: ScreenGeometry.leftInset
        mask: Region {}
        visible: rootItem.sideInset > 0
    }

    PanelWindow {
        id: rightReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        anchors { top: true; bottom: true; right: true }
        exclusiveZone: ScreenGeometry.rightInset
        implicitWidth: ScreenGeometry.rightInset
        mask: Region {}
        visible: rootItem.sideInset > 0
    }
}
