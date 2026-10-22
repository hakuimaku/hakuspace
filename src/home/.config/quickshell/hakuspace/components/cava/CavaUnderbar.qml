import QtQuick
import "../../services"

Item {
    id: root

    property string style: CavaService.style
    property var screen: null

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: root.style === "capsule" ? capsuleComponent : liquidComponent
    }

    Component {
        id: liquidComponent
        CavaLiquid {
            anchors.fill: parent
        }
    }

    Component {
        id: capsuleComponent
        CavaCapsule {
            anchors.fill: parent
        }
    }
}
