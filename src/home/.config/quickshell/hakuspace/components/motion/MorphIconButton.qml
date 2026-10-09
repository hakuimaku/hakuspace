import QtQuick
import Quickshell.Widgets
import "../../services"

MorphButton {
    id: root

    property url iconSource: ""
    property real iconSize: Math.min(width, height) * 0.55

    text: ""

    IconImage {
        anchors.centerIn: parent
        width: root.iconSize
        height: width
        source: root.iconSource
        opacity: root.enabled ? 1 : 0.55

        Behavior on opacity {
            NumberAnimation {
                duration: HAnimation.buttonReleaseDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.buttonReleaseCurve
            }
        }
    }
}
