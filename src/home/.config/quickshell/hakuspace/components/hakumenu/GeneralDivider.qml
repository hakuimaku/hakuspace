import QtQuick
import "../../services"
import "../settings" as Settings

Item {
    id: root
    // Keep structural actions outside the selectable menu model.
    property bool showAdd: true
    property bool showLine: true
    signal addRequested()
    implicitHeight: Math.max(32, Theme.controlHeight)

    Rectangle {
        anchors { left: parent.left; right: add.left; verticalCenter: parent.verticalCenter; rightMargin: Theme.gap }
        height: 1
        color: Qt.darker(Theme.fgMuted, 1.75)
        opacity: 0.55
        visible: root.showLine
    }
    Settings.SettingsActionButton {
        id: add
        objectName: "general-add"
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: visible ? height : 0
        height: root.height
        visible: root.showAdd
        text: ""
        idleColor: "transparent"
        hoverColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.12))
        pressedColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.2))
        hoverScaleDelta: 0.006
        activeFocusOnTab: true
        focused: activeFocus
        Accessible.name: "Add custom action"
        onClicked: root.addRequested()
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        Settings.SettingsTooltip { target: add; active: add.hovered; text: "Add custom action" }
    }
}
