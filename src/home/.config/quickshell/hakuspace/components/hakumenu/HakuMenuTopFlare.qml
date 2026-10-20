import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"

// TopBar mode owns this trigger independently of compact Dockbar lifetime.
HakuMenuAttachedFlare {
    id: root
    readonly property real triggerHeight: 4
    readonly property real triggerWidth: screenWidth * 0.20
    readonly property var triggerRect: ({x: (screenWidth - triggerWidth) / 2,
        y: 0, width: triggerWidth, height: triggerHeight})

    PanelWindow {
        screen: root.modelData
        anchors { top: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
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
                if (hovered && !root.panelOpen)
                    UiState.openHakuMenu(root.modelData.name, "general", "edge", root.triggerRect)
                if (hovered) root.trackTrigger(point.position.x, point.position.y)
                else root.leaveTrigger()
            }
            onPointChanged: if (hovered) root.trackTrigger(point.position.x, point.position.y)
        }
    }
}
