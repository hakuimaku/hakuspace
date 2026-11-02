import QtQuick
import "../../../services"

Rectangle {
    id: root
    property real value: 0
    property bool available: true
    property bool reducedMotion: false
    property color trackColor: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.085 : 0.075)
    property color fillColor: Qt.alpha(Theme.fg, Theme.isLight ? 0.68 : 0.72)

    implicitHeight: 3
    radius: Math.max(1.5, height / 2)
    border.width: 0
    color: root.trackColor
    clip: true

    Rectangle {
        width: root.available && Number.isFinite(root.value)
            ? Math.max(0, Math.min(root.width, Math.round(root.width * Math.max(0, Math.min(100, root.value)) / 100)))
            : 0
        height: parent.height
        radius: parent.radius
        border.width: 0
        color: root.fillColor
        Behavior on width {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: HAnimation.taskBarFillDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.moduleCurve
            }
        }
    }
}
