import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"

// Keep the top-edge hover region available independently of menu content.
PanelWindow {
    id: root
    required property var modelData
    property var owner: null
    readonly property real triggerHeight: 4
    readonly property real screenWidth: modelData ? modelData.width : 0
    readonly property real triggerWidth: screenWidth * 0.20
    readonly property var triggerRect: ({x: (screenWidth - triggerWidth) / 2, y: 0, width: triggerWidth, height: triggerHeight})
    screen: root.modelData
    anchors { top: true; left: true; right: true }
    WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
    WlrLayershell.namespace: "hakuspace-hakumenu-trigger"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    visible: !!root.modelData && ChromeLayout.topEdgeHakuMenuEnabled
    color: "transparent"
    implicitHeight: root.triggerHeight
    mask: Region {
        x: root.triggerRect.x
        width: root.triggerWidth
        height: root.triggerHeight
    }
    HoverHandler {
        onHoveredChanged: {
            if (hovered && !(root.owner && root.owner.panelOpen))
                UiState.openHakuMenu(root.modelData.name, "general", "edge", root.triggerRect)
            if (hovered && root.owner) root.owner.trackTrigger(point.position.x, point.position.y)
            else if (root.owner) root.owner.leaveTrigger()
        }
        onPointChanged: if (hovered && root.owner) root.owner.trackTrigger(point.position.x, point.position.y)
    }
}
