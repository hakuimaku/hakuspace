import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
    id: root
    required property var modelData
    readonly property bool panelOpen: UiState.activePanel === "hakumenu"
        && UiState.hakuMenuMode !== "closed"
        && UiState.hakuMenuScreenName === modelData.name
    readonly property real triggerHeight: 4

    screen: modelData
    anchors { top: true; left: true }
    margins.left: (modelData.width - implicitWidth) / 2
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-hakumenu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: modelData.width * 0.20
    implicitHeight: Theme.topBarHeight + menu.height
    color: "transparent"
    mask: Region {
        Region {
            width: root.width
            height: root.panelOpen ? menu.y : root.triggerHeight
        }
        Region {
            x: menu.x
            y: menu.y
            width: root.panelOpen ? menu.width : 0
            height: root.panelOpen ? menu.height : 0
        }
    }
    Component.onDestruction: UiState.closeHakuMenuIfScreen(modelData.name)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            if (!root.panelOpen) UiState.openHakuMenu(root.modelData.name)
        }
        onExited: {
            if (root.panelOpen) UiState.closeHakuMenu()
        }
    }

    Rectangle {
        id: menu
        x: (root.width - width) / 2
        y: Theme.topBarHeight
        width: Math.min(320, root.width - Theme.pad * 2)
        height: 120
        radius: Theme.radius
        color: Theme.surface
        visible: root.panelOpen

        Text {
            anchors.centerIn: parent
            text: "HakuMenu"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

    }
}
