import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

Item {
    id: rootItem
    required property var modelData

    // -------------------------------------------------------------------------
    // Top-level visual inputs: obvious, named, and sourced from AppState
    // -------------------------------------------------------------------------
    readonly property real frameThickness: Math.max(0, AppState.roundedScreenThickness)
    readonly property real cornerRadius: Math.max(0, AppState.roundedScreenRadius)
    readonly property color frameColor: AppState.roundedScreenColor

    // -------------------------------------------------------------------------
    // Responsibility A & B: Visual frame / corner drawing & click-through input
    // -------------------------------------------------------------------------
    // Draws the continuous rounded corners and border frame.
    // An empty Region mask ensures complete click-through to client windows.
    PanelWindow {
        id: visualWindow
        screen: rootItem.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: true

        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        mask: Region {}

        Canvas {
            id: canvas
            anchors.fill: parent

            readonly property real t: rootItem.frameThickness
            readonly property real r: Math.min(rootItem.cornerRadius, Math.floor(width / 2), Math.floor(height / 2))
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

                var curR = r
                if (curR > 0) {
                    // Top-left inverted corner
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.lineTo(curR, 0)
                    ctx.arc(curR, curR, curR, -Math.PI / 2, Math.PI, true)
                    ctx.closePath()
                    ctx.fill()

                    // Top-right inverted corner
                    ctx.beginPath()
                    ctx.moveTo(w, 0)
                    ctx.lineTo(w, curR)
                    ctx.arc(w - curR, curR, curR, 0, -Math.PI / 2, true)
                    ctx.closePath()
                    ctx.fill()

                    // Bottom-right inverted corner
                    ctx.beginPath()
                    ctx.moveTo(w, h)
                    ctx.lineTo(w - curR, h)
                    ctx.arc(w - curR, h - curR, curR, Math.PI / 2, 0, true)
                    ctx.closePath()
                    ctx.fill()

                    // Bottom-left inverted corner
                    ctx.beginPath()
                    ctx.moveTo(0, h)
                    ctx.lineTo(0, h - curR)
                    ctx.arc(curR, h - curR, curR, Math.PI, Math.PI / 2, true)
                    ctx.closePath()
                    ctx.fill()
                }

                // Frame stroke around the screen perimeter
                if (t > 0) {
                    ctx.strokeStyle = c
                    ctx.lineWidth = t * 2

                    ctx.beginPath()
                    ctx.moveTo(curR, 0)
                    ctx.lineTo(w - curR, 0)
                    if (curR > 0) ctx.arc(w - curR, curR, curR, -Math.PI / 2, 0, false)
                    ctx.lineTo(w, h - curR)
                    if (curR > 0) ctx.arc(w - curR, h - curR, curR, 0, Math.PI / 2, false)
                    ctx.lineTo(curR, h)
                    if (curR > 0) ctx.arc(curR, h - curR, curR, Math.PI / 2, Math.PI, false)
                    ctx.lineTo(0, curR)
                    if (curR > 0) ctx.arc(curR, curR, curR, Math.PI, -Math.PI / 2, false)
                    ctx.closePath()
                    ctx.stroke()
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Responsibility C: Layout reservation edge windows (exclusive zones)
    // -------------------------------------------------------------------------
    // Reserve window borders so tiled windows respect the frame.
    // Top edge is reserved by TopBar; bottom, left, and right are reserved here.
    PanelWindow {
        id: bottomReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        exclusionMode: ExclusionMode.Normal
        anchors { bottom: true; left: true; right: true }
        implicitHeight: rootItem.frameThickness
        mask: Region {}
        visible: rootItem.frameThickness > 0
    }

    PanelWindow {
        id: leftReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        exclusionMode: ExclusionMode.Normal
        anchors { top: true; bottom: true; left: true }
        implicitWidth: rootItem.frameThickness
        mask: Region {}
        visible: rootItem.frameThickness > 0
    }

    PanelWindow {
        id: rightReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        exclusionMode: ExclusionMode.Normal
        anchors { top: true; bottom: true; right: true }
        implicitWidth: rootItem.frameThickness
        mask: Region {}
        visible: rootItem.frameThickness > 0
    }
}
