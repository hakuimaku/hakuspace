import QtQuick
import "../services"
import "base"
import "notification"

FlarePanelWindow {
    id: root
    readonly property var panelState: UiState.notificationPanel
    panelOpen: NotificationStore._started && UiState.activePanel === "notifications"
               && panelState !== null && panelState.screenName === modelData.name
    anchorX: panelState ? panelState.anchorX : 0
    anchorWidth: panelState ? panelState.anchorWidth : 0
    panelComponent: centerComponent
    panelProps: ({ maxHeight: root.maxPanelContentHeight,
                   maxWidth: root.width * 0.65 })
    panelKey: "notifications"
    onDismissed: UiState.closeNotifications()
    onPanelOpenChanged: { if (panelOpen) NotificationStore.hidePopups() }
    Component.onDestruction: UiState.closeNotificationsIfScreen(modelData.name)

    Component {
        id: centerComponent
        NotificationCenterContent {}
    }
}
