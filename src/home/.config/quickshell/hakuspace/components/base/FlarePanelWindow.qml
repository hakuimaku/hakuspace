import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../flare"

PanelWindow {
    id: root
    required property var modelData
    property bool panelOpen: false
    property bool closing: false
    property real anchorX: 0
    property real anchorWidth: 0
    property Component panelComponent: null
    property var panelProps: ({})
    property var panelKey: null
    property real maxPanelContentHeight: Math.max(0, height - Theme.tipHugRadius - 16 - Theme.pad)
    signal dismissed()

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: FlareEdges.topOriginY
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-flare-panel"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: panelOpen || closing
    mask: Region {
        width: root.panelOpen ? root.width : 0
        height: root.panelOpen ? root.height : 0
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            closing = false
            Qt.callLater(function() { keyHandler.forceActiveFocus() })
        } else if (flare.currentHeight > 0) {
            closing = true
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.panelOpen
        Keys.onEscapePressed: root.dismissed()
    }

    Item {
        id: anchorProxy
        x: root.anchorX
        width: root.anchorWidth
        height: 1
        visible: false
    }

    MouseArea {
        x: flare.start
        y: 0
        width: Math.max(0, flare.end - flare.start)
        height: Math.min(root.height, flare.currentHeight + Theme.tipHugRadius)
        onClicked: (mouse) => { mouse.accepted = true }
    }

    FlareHost {
        id: flare
        width: root.width
        height: root.height
        anchorItem: anchorProxy
        shown: root.panelOpen
        content: root.panelComponent
        contentProps: root.panelProps
        contentKey: root.panelKey
        maxWidth: Math.min(400, Math.max(0, root.width - FlareEdges.thickness * 2))
        horizontalPadding: 22
        onSettled: (isShown) => {
            if (!isShown && !root.panelOpen) root.closing = false
        }
    }
}
