import QtQuick
import "../../services"

Item {
    id: root
    // Present one optional telemetry sample without converting missing values to zero.
    required property string label
    required property string value
    property string secondary: ""
    property real usage: NaN
    property bool reducedMotion: false
    property bool compact: false
    implicitHeight: title.implicitHeight + number.implicitHeight + details.implicitHeight + 8
    Accessible.role: Accessible.Grouping
    Accessible.name: label + " " + value + (secondary ? ", " + secondary : "")

    Text {
        id: title
        anchors { top: parent.top; left: parent.left; right: parent.right }
        text: root.label
        color: Theme.fgMuted
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
    }
    Text {
        id: number
        anchors { top: title.bottom; left: parent.left; right: parent.right }
        text: root.value
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: root.value === "Unavailable" ? Theme.fontSize : Theme.fontSize + (root.compact ? 6 : 8)
        elide: Text.ElideRight
    }
    Text {
        id: details
        anchors { top: number.bottom; left: parent.left; right: parent.right; topMargin: 2 }
        text: root.secondary
        color: Theme.fgMuted
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(10, Theme.fontSize - 3)
        elide: Text.ElideRight
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 2
        color: Theme.surfaceSubtle(1.4)
        Rectangle {
            width: Number.isFinite(root.usage) ? parent.width * Math.max(0, Math.min(100, root.usage)) / 100 : 0
            height: parent.height
            color: Theme.accent
            Behavior on width {
                enabled: root.visible && !root.reducedMotion
                NumberAnimation { duration: HAnimation.taskBarFillDuration; easing.bezierCurve: HAnimation.moduleCurve }
            }
        }
    }
}
