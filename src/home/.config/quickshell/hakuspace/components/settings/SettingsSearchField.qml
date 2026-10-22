import QtQuick
import "../../services"

Rectangle {
    id: root
    // Filtering stays local to the page and never changes stored values.
    property alias text: input.text
    readonly property bool inputFocused: input.activeFocus
    // Keep shortcuts out of the editable query.
    property Item shortcutTarget: null
    // Select the current filter when entering search from its shortcut.
    function focusSearch() { input.forceActiveFocus(Qt.ShortcutFocusReason); input.selectAll() }
    implicitHeight: 38
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.hoverMuted
    Text {
        anchors.fill: parent
        anchors.leftMargin: 12
        verticalAlignment: Text.AlignVCenter
        visible: !input.text && !input.activeFocus
        text: "Search settings…"
        color: Theme.fgMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }
    TextInput {
        id: input
        property bool settingsNavItem: true
        property string settingsNavRole: "input"
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        anchors.fill: parent
        anchors.margins: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccentColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        clip: true
        activeFocusOnTab: true
        Accessible.name: "Search settings"
    }
}
