import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../../services"
import "../base"

// Card chassis container for notification popups and history entries.
Rectangle {
    id: root
    signal keyboardInteraction()
    required property var record
    property bool compact: false
    // Presentation knobs let popup cards diverge from Notification Center cards
    // without duplicating the notification body component.
    property real cardRadius: Theme.radius
    property real cardPadding: Theme.cardPadding
    property bool showBorder: record.urgency === NotificationUrgency.Critical
    property bool accentedBorder: false
    implicitWidth: 450
    implicitHeight: content.implicitHeight + cardPadding * 2
    radius: cardRadius
    color: "transparent"
    border.width: showBorder ? (record.urgency === NotificationUrgency.Critical ? 2 : 1)
                               + (accentedBorder ? 1 : 0) : 0
    border.color: accentedBorder ? Theme.accent
                                : record.urgency === NotificationUrgency.Critical ? "#ff5555" : Theme.fgMuted

    // Resolves raw notification icon paths to valid Quickshell image URIs.
    function iconSource(icon) {
        if (!icon) return ""
        if (icon.startsWith("image://") || icon.startsWith("file://")) return icon
        return icon.startsWith("/") ? "file://" + icon : "image://icon/" + icon
    }

    Column {
        id: content
        x: root.cardPadding
        y: root.cardPadding
        width: root.width - root.cardPadding * 2
        spacing: Theme.spaceSm

        Row {
            width: parent.width
            height: Math.max(Theme.fontSize * 2, dismissButton.height)
            spacing: Theme.spaceSm

            IconImage {
                id: appIcon
                width: Theme.fontSize * 1.5
                height: width
                anchors.verticalCenter: parent.verticalCenter
                source: root.iconSource(root.record.appIcon)
                visible: source !== ""
            }
            Text {
                visible: !appIcon.visible
                text: ""
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 1.5
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                width: Math.max(0, parent.width - Theme.fontSize * 1.5 - dismissButton.width - parent.spacing * 2)
                anchors.verticalCenter: parent.verticalCenter
                text: root.record.appName || "Notification"
                textFormat: Text.PlainText
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.9
                elide: Text.ElideRight
            }
            HButton {
                id: dismissButton
                width: Theme.controlHeight
                height: Theme.controlHeight
                text: "×"
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Dismiss notification"
                Keys.onReturnPressed: { root.keyboardInteraction(); NotificationStore.dismiss(root.record.key) }
                Keys.onSpacePressed: { root.keyboardInteraction(); NotificationStore.dismiss(root.record.key) }
                onClicked: NotificationStore.dismiss(root.record.key)
            }
        }

        Text {
            width: parent.width
            text: root.record.summary || "Notification"
            textFormat: Text.PlainText
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: root.record.body || ""
            textFormat: Text.PlainText
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            wrapMode: Text.Wrap
            maximumLineCount: root.compact ? 4 : 6
            elide: Text.ElideRight
        }
    }
}
