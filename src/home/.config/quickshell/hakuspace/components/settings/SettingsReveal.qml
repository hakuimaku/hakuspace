import QtQuick
import "../../services"

Rectangle {
    id: root
    // Keep conditional controls in place while their space opens or closes.
    property bool expanded: true
    required property real expandedHeight
    property real progress: expanded ? 1 : 0
    property bool initialized: false
    height: expandedHeight * progress
    opacity: progress
    visible: expanded || progress > 0
    enabled: expanded
    clip: progress < 1
    color: "transparent"
    Component.onCompleted: initialized = true
    Behavior on progress {
        enabled: root.initialized
        NumberAnimation {
            duration: HAnimation.normal
            easing.bezierCurve: HAnimation.moduleCurve
        }
    }
}
