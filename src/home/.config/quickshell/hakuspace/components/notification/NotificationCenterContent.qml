import QtQuick
import Quickshell
import "../../services"
import "../base"

Item {
    id: root
    property real maxHeight: 500
    property real maxWidth: 450
    readonly property var entries: NotificationStore.records.filter(function(record) {
        return !record.transient && !record.dismissed
    }).reverse()
    implicitWidth: Math.min(450, maxWidth)
    implicitHeight: Math.min(maxHeight, Math.max(180,
        header.height + Theme.gap + Math.min(entries.length, 3) * Theme.fontSize * 10))

    Row {
        id: header
        width: root.width
        height: Math.max(Theme.fontSize * 2.2, dndButton.height)
        spacing: Theme.gap * 2

        Text {
            width: Math.max(0, parent.width - dndButton.width - clearButton.width
                            - closeButton.width - parent.spacing * 3)
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications (" + NotificationStore.count + ")"
            textFormat: Text.PlainText
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            elide: Text.ElideRight
        }
        HButton {
            id: dndButton
            width: Theme.fontSize * 5.3
            hoverScaleDelta: 0
            expandedVisual: true
            hoverXScaleDelta: 0.18
            pressXScaleDelta: 0.06
            hoverFadeAmount: 0.18
            text: NotificationStore.dnd ? "DND On" : "DND Off"
            selected: NotificationStore.dnd
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Toggle Do Not Disturb"
            Keys.onReturnPressed: NotificationStore.toggleDnd()
            Keys.onSpacePressed: NotificationStore.toggleDnd()
            onClicked: NotificationStore.toggleDnd()
        }
        HButton {
            id: clearButton
            width: Theme.fontSize * 4
            hoverScaleDelta: 0
            expandedVisual: true
            hoverXScaleDelta: 0.24
            pressXScaleDelta: 0.08
            hoverFadeAmount: 0.12
            text: "Clear"
            idleColor: Theme.accent
            foregroundColor: Theme.onAccentColor
            hoverColor: Qt.darker(Theme.accent, 1.10)
            pressedColor: Qt.darker(Theme.accent, 1.18)
            hoverForegroundColor: Theme.onAccentColor
            pressedForegroundColor: Theme.onAccentColor
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Clear all notifications"
            enabled: NotificationStore.count > 0
            Keys.onReturnPressed: NotificationStore.clearAll()
            Keys.onSpacePressed: NotificationStore.clearAll()
            onClicked: NotificationStore.clearAll()
        }
        HButton {
            id: closeButton
            width: Theme.fontSize * 2
            hoverScaleDelta: 0
            expandedVisual: true
            hoverXScaleDelta: 0.30
            pressXScaleDelta: 0.10
            hoverFadeAmount: 0.20
            text: "×"
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Close Notification Center"
            Keys.onReturnPressed: UiState.closeNotifications()
            Keys.onSpacePressed: UiState.closeNotifications()
            onClicked: UiState.closeNotifications()
        }
    }

    ScriptModel {
        id: historyModel
        values: root.entries
        objectProp: "key"
        comparisonMode: ObjectComparison.Structure
    }

    ListView {
        id: list
        y: header.height + Theme.gap
        width: root.width
        height: Math.max(0, root.height - y)
        clip: true
        spacing: Theme.gap
        model: historyModel
        delegate: NotificationCard {
            required property var modelData
            record: modelData
            width: list.width
        }

        Text {
            anchors.centerIn: parent
            visible: NotificationStore.count === 0
            text: "No notifications"
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
