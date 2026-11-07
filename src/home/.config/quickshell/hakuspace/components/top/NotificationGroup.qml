import QtQuick
import "../../services"
import "../"

Row {
    id: root
    // Compact bells keep count in the tooltip and mark pending notifications.
    property bool compact: false
    required property string screenName
    readonly property bool hasNotifications: NotificationStore._started && NotificationStore.count > 0

    TopModule {
        id: bell
        hoverAxis: root.compact ? "vertical" : "horizontal"
        width: root.compact ? implicitHeight : implicitWidth
        icon: NotificationStore.dnd ? "" : ""
        text: !root.compact && root.hasNotifications ? "+" + NotificationStore.count : ""
        color: root.hasNotifications ? Theme.accent : hovered ? Theme.surfaceHi : Theme.surface
        foregroundColor: root.hasNotifications || hovered ? Theme.onAccentColor : Theme.fg
        muted: NotificationStore.dnd && !root.hasNotifications
        tooltip: NotificationStore._started
                 ? "Notifications\n" + NotificationStore.count + " notifications"
                   + (NotificationStore.dnd ? "\nDo Not Disturb enabled" : "")
                 : "Notifications"
        Rectangle {
            parent: bell.visualItem
            anchors.right: parent.right
            anchors.top: parent.top
            width: 6; height: 6; radius: 3
            color: Theme.onAccentColor
            visible: root.compact && root.hasNotifications
        }
        onClicked: {
            if (!NotificationStore._started) return
            UiState.toggleNotifications(root.screenName, ScreenGeometry.itemRect(bell.interactionItem))
        }
        onRightClicked: {
            if (NotificationStore._started) NotificationStore.toggleDnd()
        }
    }
}
