import QtQuick
import QtQuick.Controls
import "../../services"

ScrollBar {
    id: root

    readonly property real reservedGutter: visible ? 14 : 0

    policy: ScrollBar.AsNeeded
    visible: size < 1.0 && size > 0.0
    z: 10

    width: 8
    hoverEnabled: true
    interactive: true

    contentItem: Rectangle {
        implicitWidth: 5
        radius: 2.5
        x: root.width - width - 1
        color: root.pressed ? Theme.accent : (root.hovered ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(1, 1, 1, 0.40))
        opacity: root.hovered ? 0.95 : (root.active ? 0.85 : 0.35)

        Behavior on opacity {
            NumberAnimation {
                duration: HAnimation.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.shellCurve
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    background: Rectangle {
        color: "transparent"
    }
}
