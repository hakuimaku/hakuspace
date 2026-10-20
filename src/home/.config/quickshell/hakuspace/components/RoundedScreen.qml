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
    // Place the lower corners above each output's visible full bar.
    readonly property real taskbarInset: ScreenGeometry.taskbarReservation()

    // Render corner masks and rails opposite the status bar without intercepting input.
    PanelWindow {
        id: visualWindow
        screen: rootItem.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: rootItem.cornerRadius > 0 || rootItem.sideInset > 0

        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ChromeLayout.taskbarMode ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: 0
        // Taskbar uses physical bounds so its bottom reservation is counted once.
        margins {
            left: ChromeLayout.taskbarMode ? 0 : -ScreenGeometry.leftInset
            right: ChromeLayout.taskbarMode ? 0 : -ScreenGeometry.rightInset
            bottom: ChromeLayout.taskbarMode ? rootItem.taskbarInset
                : -ScreenGeometry.frameBottomReservation
                    - ScreenGeometry.dockbarReservation(rootItem.modelData ? rootItem.modelData.name : "")
        }
        mask: Region {}

        Canvas {
            id: canvas
            anchors.fill: parent

            readonly property real t: rootItem.sideInset
            readonly property real topInset: ScreenGeometry.topBorderThickness
            readonly property real bottomInset: ScreenGeometry.bottomInset
            readonly property real r: ScreenGeometry.maskRadius(width, height)
            readonly property color c: rootItem.frameColor

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onTChanged: requestPaint()
            onTopInsetChanged: requestPaint()
            onBottomInsetChanged: requestPaint()
            onRChanged: requestPaint()
            onCChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var h = height

                ctx.clearRect(0, 0, w, h)
                ctx.fillStyle = c

                // Corner masks follow the active rail bounds independently of rail width.
                if (r > 0) {
                    ctx.beginPath()
                    ctx.moveTo(t, topInset)
                    ctx.lineTo(t + r, topInset)
                    ctx.arc(t + r, topInset + r, r, -Math.PI / 2, Math.PI, true)
                    ctx.closePath()
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(w - t, topInset)
                    ctx.lineTo(w - t, topInset + r)
                    ctx.arc(w - t - r, topInset + r, r, 0, -Math.PI / 2, true)
                    ctx.closePath()
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(w - t, h - bottomInset)
                    ctx.lineTo(w - t - r, h - bottomInset)
                    ctx.arc(w - t - r, h - bottomInset - r, r, Math.PI / 2, 0, true)
                    ctx.closePath()
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(t, h - bottomInset)
                    ctx.lineTo(t, h - bottomInset - r)
                    ctx.arc(t + r, h - bottomInset - r, r, Math.PI, Math.PI / 2, true)
                    ctx.closePath()
                    ctx.fill()
                }
                if (t > 0) {
                    ctx.fillRect(0, 0, t, h)
                    ctx.fillRect(w - t, 0, t, h)
                    ctx.fillRect(0, 0, w, topInset)
                    ctx.fillRect(0, h - bottomInset, w, bottomInset)
                }
            }
        }
    }

    // Reserve the horizontal rail opposite the active bar and both side rails.
    PanelWindow {
        id: horizontalReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        anchors { top: ChromeLayout.taskbarMode; bottom: !ChromeLayout.taskbarMode; left: true; right: true }
        exclusiveZone: rootItem.sideInset
        implicitHeight: rootItem.sideInset
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
