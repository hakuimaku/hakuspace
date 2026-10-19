import QtQuick
import "../../services"

Item {
    id: root
    // Animate only the visual envelope; item slots retain their target dimensions.
    property bool shown: false
    property real targetWidth: 0
    property real targetHeight: 0
    readonly property bool moving: widthMotion.running || heightMotion.running
    readonly property string phase: height < 0.1 ? "hidden" : moving ? (shown ? "opening" : "closing") : "shown"
    width: shown ? targetWidth : Math.min(28, targetWidth)
    height: shown ? targetHeight : 0
    Behavior on width {
        NumberAnimation {
            id: widthMotion
            duration: root.shown ? (root.height >= root.targetHeight - 1 ? HAnimation.dockResizeDuration : HAnimation.dockOpenDuration)
                : HAnimation.dockCloseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shown ? HAnimation.dockOpenCurve : HAnimation.dockCloseCurve
        }
    }
    Behavior on height {
        NumberAnimation {
            id: heightMotion
            duration: root.shown ? HAnimation.dockOpenDuration : HAnimation.dockCloseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shown ? HAnimation.dockOpenCurve : HAnimation.dockCloseCurve
        }
    }
}
