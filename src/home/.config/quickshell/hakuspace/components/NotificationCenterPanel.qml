import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare"
import "notification"

PanelWindow {
    id: root
    required property var modelData
    readonly property var panelState: UiState.notificationPanel
    readonly property bool panelOpen: NotificationStore._started
        && UiState.activePanel === "notifications"
        && panelState !== null && panelState.screenName === modelData.name
    property bool closing: false

    screen: modelData
    anchors { top: true; right: true }
    margins.top: FlareEdges.topOriginY
    margins.right: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-notification-center"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: Math.max(0, Math.min(420, modelData.width - Theme.pad * 2))
    implicitHeight: Math.min(modelData.height - FlareEdges.topOriginY - Theme.pad,
                             Math.max(220, flare.naturalContentHeight + 16 + Theme.tipHugRadius))
    visible: panelOpen || closing
    mask: Region {
        width: root.panelOpen ? root.width : 0
        height: root.panelOpen ? Math.min(root.height, flare.currentHeight + Theme.tipHugRadius) : 0
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            closing = false
            NotificationStore.hidePopups()
        } else if (flare.currentHeight > 0) {
            closing = true
        }
    }
    Component.onDestruction: UiState.closeNotificationsIfScreen(modelData.name)

    Item {
        anchors.fill: parent
        focus: root.panelOpen
        Keys.onEscapePressed: UiState.closeNotifications()
    }

    Item {
        id: anchorProxy
        x: root.panelState
           ? root.panelState.anchorX - (root.modelData.width - root.width)
           : root.width - Theme.pad
        width: root.panelState ? root.panelState.anchorWidth : 1
        height: 1
        visible: false
    }

    FlareHost {
        id: flare
        width: root.width
        height: root.height
        anchorItem: anchorProxy
        shown: root.panelOpen
        content: centerComponent
        contentProps: ({ maxHeight: Math.max(0, root.modelData.height - FlareEdges.topOriginY
                                              - Theme.pad * 2 - Theme.tipHugRadius),
                         maxWidth: Math.max(0, root.width - 50) })
        contentKey: "notifications"
        maxWidth: Math.min(400, Math.max(0, root.width - FlareEdges.thickness * 2))
        wBounds: ({ start: 0, end: root.width })
        horizontalPadding: 22
        onSettled: (isShown) => {
            if (!isShown && !root.panelOpen) root.closing = false
        }
    }

    Component {
        id: centerComponent
        NotificationCenterContent {}
    }
}
