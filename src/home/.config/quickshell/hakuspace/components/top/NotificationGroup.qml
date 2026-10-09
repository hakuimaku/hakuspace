import QtQuick
import "../../services"
import "../"

Row {
    id: root
    required property string screenName

    TopModule {
        id: bell
        icon: NotificationStore.dnd ? "" : ""
        text: NotificationStore._started && NotificationStore.count > 0
              ? String(NotificationStore.count) : ""
        muted: NotificationStore.dnd
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
