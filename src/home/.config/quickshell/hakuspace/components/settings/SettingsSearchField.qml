import QtQuick
import "../../services"

Rectangle {
    id: root
    property alias text: input.text
    signal accepted()
    signal nextRequested()
    signal escapeRequested()
    readonly property bool inputFocused: input.activeFocus
    property Item shortcutTarget: null
    // Select the query when entering search from its shortcut.
    function focusSearch() { input.forceActiveFocus(Qt.ShortcutFocusReason); input.selectAll() }
    implicitHeight: Theme.comfortableControlHeight
    radius: height / 2
    color: Theme.surface
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.hoverMuted
    Text {
        id: icon
        anchors { left: parent.left; leftMargin: Theme.spaceLg; verticalCenter: parent.verticalCenter }
        text: "⌕"
        color: Theme.fgMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
    }
    TextInput {
        id: input
        property bool settingsNavItem: true
        property string settingsNavRole: "input"
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        anchors { left: icon.right; leftMargin: Theme.spaceSm; right: clear.visible ? clear.left : parent.right; rightMargin: Theme.spaceMd; top: parent.top; bottom: parent.bottom }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccentColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        clip: true
        selectByMouse: true
        activeFocusOnTab: true
        Accessible.name: "Search settings"
        onAccepted: root.accepted()
        Keys.onDownPressed: root.nextRequested()
        Keys.onEscapePressed: event => {
            if (text.length) root.escapeRequested()
            else event.accepted = false
        }
        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: "Search settings…"
            visible: !input.text.length
            color: Theme.fgMuted
            font: input.font
        }
    }
    SettingsActionButton {
        id: clear
        anchors { right: parent.right; rightMargin: Theme.spaceSm; verticalCenter: parent.verticalCenter }
        width: 28; height: 28
        visible: input.text.length > 0
        text: "×"
        fontSize: Theme.fontSize - 1
        idleColor: "transparent"
        selectedColor: "transparent"
        hoverColor: "transparent"
        pressedColor: "transparent"
        Accessible.name: "Clear search"
        onClicked: { input.text = ""; input.forceActiveFocus() }
    }
}
