import QtQuick
import "../../services"

Item {
    id: root
    property int depth: 0
    property var ancestorLast: []
    property bool isLast: false
    property real indentWidth: 14
    property color lineColor: Theme.fgMuted
    readonly property real stemX: (depth + 0.5) * indentWidth

    width: (depth + 1) * indentWidth + 4

    Repeater {
        model: root.depth
        delegate: Rectangle {
            required property int index
            visible: !root.ancestorLast[index]
            x: (index + 0.5) * root.indentWidth
            width: 1
            height: root.height
            color: root.lineColor
        }
    }
    Rectangle {
        x: root.stemX
        width: 1
        height: root.isLast ? root.height / 2 : root.height
        color: root.lineColor
    }
    Rectangle {
        x: root.stemX
        y: root.height / 2
        width: root.indentWidth / 2 + 4
        height: 1
        color: root.lineColor
    }
}
