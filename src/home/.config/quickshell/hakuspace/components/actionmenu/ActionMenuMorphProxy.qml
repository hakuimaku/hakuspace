import QtQuick
import "../../services"

// Transient visual proxy rectangle representing the originating button during morphing transitions.
Rectangle {
    id: root

    property bool active: false

    property real morphX: 0
    property real morphY: 0
    property real morphWidth: 0
    property real morphHeight: 0
    property real morphRadius: Theme.radius
    property color morphColor: Theme.accent
    property int morphBorderWidth: 1

    property string seedIcon: ""
    property string seedLabel: ""
    property real ghostOpacity: 0.0

    visible: active

    x: morphX
    y: morphY
    width: Math.max(1, morphWidth)
    height: Math.max(1, morphHeight)
    radius: Math.max(0, morphRadius)
    color: morphColor

    border.color: Theme.accent
    border.width: morphBorderWidth

    // Brief label ghost during transition
    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.pad * 1.2
        spacing: Theme.pad
        opacity: root.ghostOpacity
        visible: opacity > 0.01

        Text {
            visible: root.seedIcon.length > 0
            text: root.seedIcon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            color: Theme.onAccentColor
        }

        Text {
            visible: root.seedLabel.length > 0
            text: root.seedLabel
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            font.weight: Font.DemiBold
            color: Theme.onAccentColor
        }
    }
}
