import QtQuick
import "../../services"

Item {
    id: root

    required property var droplets
    property color inkColor: Theme.accent

    Repeater {
        model: root.droplets ? root.droplets.length : 0
        delegate: Rectangle {
            required property int index
            readonly property var node: root.droplets[index]
            x: node ? node.x : 0
            y: node ? node.y : 0
            width: node ? node.width : 0
            height: node ? node.height : 0
            radius: node ? node.radius : 0
            color: root.inkColor
            visible: node ? node.visible : false
            antialiasing: true
        }
    }
}
