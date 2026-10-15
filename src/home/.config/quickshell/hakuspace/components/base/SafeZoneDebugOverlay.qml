import QtQuick
import Quickshell

Item {
    id: root
    property var zones: []
    property bool closePending: false
    visible: Quickshell.env("QS_SAFEZONE_DEBUG") === "1"
    enabled: false

    Repeater {
        model: root.visible ? root.zones : []
        delegate: Rectangle {
            required property var modelData
            x: modelData.rect.x
            y: modelData.rect.y
            width: modelData.rect.width
            height: modelData.rect.height
            color: root.closePending ? "#33ff0000"
                : modelData.kind === "anchor" ? "#330078ff"
                : modelData.kind === "corridor" ? "#33ffcc00"
                : modelData.kind === "animation" ? "#339933ff" : "#3300ff66"
            border.color: root.closePending ? "#ff0000"
                : modelData.kind === "anchor" ? "#0078ff"
                : modelData.kind === "corridor" ? "#ffcc00"
                : modelData.kind === "animation" ? "#9933ff" : "#00ff66"
        }
    }
}
