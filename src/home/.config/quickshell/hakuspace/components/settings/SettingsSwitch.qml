import QtQuick
import QtQuick.Controls
import "../../services"

Item {
    id: root
    property string text: ""
    property bool checked: false
    property Item shortcutTarget: null
    property string settingsNavRole: "control"
    signal toggled(bool value)
    implicitWidth: 260
    implicitHeight: Math.max(44, caption.implicitHeight)
    Text {
        id: caption
        width: Math.max(0, root.width - control.width - Theme.spaceMd)
        anchors.verticalCenter: parent.verticalCenter
        text: root.text; color: root.enabled ? Theme.fg : Theme.fgMuted
        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; wrapMode: Text.Wrap
    }
    Switch {
        id: control
        property bool settingsNavItem: true
        property string settingsNavRole: root.settingsNavRole
        x: root.text ? root.width - width : 0
        width: 64; height: root.height; padding: 0
        checked: root.checked
        focusPolicy: Qt.StrongFocus
        Accessible.name: root.Accessible.name || root.text
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        onToggled: root.toggled(checked)
        contentItem: Item {}
        indicator: Rectangle {
            anchors.centerIn: parent
            width: 60; height: 26; radius: 13
            opacity: root.enabled ? 1 : 0.4
            color: control.checked ? Theme.accent : Theme.hoverMuted
            border.width: control.activeFocus ? 2 : 0
            border.color: control.activeFocus ? Theme.fg : Theme.fgMuted
            Rectangle {
                x: control.checked ? parent.width - width - 4 : 4
                y: 4; width: 18; height: 18; radius: 9
                color: control.checked ? Theme.onAccentColor : Theme.fgDim
                Behavior on x { NumberAnimation { duration: HAnimation.fast } }
            }
        }
    }
}
