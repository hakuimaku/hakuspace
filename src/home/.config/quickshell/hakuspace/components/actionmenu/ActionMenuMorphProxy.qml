import QtQuick
import "../../services"

// Neutral surface beneath the masked child content during a layer morph.
Rectangle {
    id: root

    property bool active: false
    property real morphX: 0
    property real morphY: 0
    property real morphWidth: 0
    property real morphHeight: 0
    property real morphRadius: Theme.radius

    visible: active
    x: morphX
    y: morphY
    width: Math.max(1, morphWidth)
    height: Math.max(1, morphHeight)
    radius: Math.max(0, morphRadius)
    color: Theme.surface
}
