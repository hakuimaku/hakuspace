import QtQuick
import "../../services"
import "../"

Row {
    id: root
    required property string screenName
    readonly property bool hasNotifications: NotificationStore._started && NotificationStore.count > 0

    TopModule {
        id: bell
        icon: NotificationStore.dnd ? "" : ""
        text: root.hasNotifications ? "+" + NotificationStore.count : ""
        color: root.hasNotifications ? Theme.accent : hovered ? Theme.surfaceHi : Theme.surface
        foregroundColor: root.hasNotifications || hovered ? Theme.onAccentColor : Theme.fg
        muted: NotificationStore.dnd && !root.hasNotifications
        tooltip: NotificationStore._started
                 ? "Notifications\n" + NotificationStore.count + " notifications"
                   + (NotificationStore.dnd ? "\nDo Not Disturb enabled" : "")
                 : "Notifications"
        onClicked: {
            if (!NotificationStore._started) return
            var point = bell.mapToItem(null, 0, 0)
            UiState.toggleNotifications(root.screenName, point.x, bell.width)
        }
        onRightClicked: {
            if (NotificationStore._started) NotificationStore.toggleDnd()
        }
    }
}
