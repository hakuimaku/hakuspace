import QtQuick
import "../../services"

Item {
    id: root

    property string style: CavaService.style
    property var screen: null
    property string position: CavaService.position
    property real bloom: 1.0
    readonly property bool isVertical: position === "left" || position === "right"

    Loader {
        id: loader
        anchors.centerIn: root.isVertical ? parent : undefined
        anchors.fill: root.isVertical ? undefined : parent
        width: root.isVertical ? parent.height : undefined
        height: root.isVertical ? parent.width : undefined
        rotation: root.position === "left" ? -90 : root.position === "right" ? 90 : 0
        sourceComponent: root.style === "capsule" ? capsuleComponent : liquidComponent
    }

    Component {
        id: liquidComponent
        CavaLiquid {
            anchors.fill: parent
            isTop: root.position !== "bottom"
            bloom: root.bloom
        }
    }

    Component {
        id: capsuleComponent
        CavaCapsule {
            anchors.fill: parent
            isTop: root.position !== "bottom"
            bloom: root.bloom
        }
    }
}
