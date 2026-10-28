import QtQuick
import QtQuick.Controls
import "../../services"

Column {
    id: root
    property var value: []
    property string label: "Item"
    property Item shortcutTarget: null
    property string error: ""
    signal edited(var value)
    spacing: Theme.spaceSm
    Text { visible: !root.value.length; text: "No items added"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
    Flow {
        width: parent.width; spacing: Theme.spaceSm
        Repeater {
            model: root.value
            delegate: SettingsActionButton {
                required property string modelData
                required property int index
                width: Math.min(260, Math.max(80, modelData.length * Theme.fontSize * 0.65 + 32)); height: Theme.controlHeight
                text: modelData + " ×"; activeFocusOnTab: true; focused: activeFocus
                Accessible.name: "Remove " + modelData
                onClicked: { var next = root.value.slice(); next.splice(index, 1); root.edited(next) }
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
            }
        }
    }
    Row {
        width: parent.width; spacing: Theme.spaceSm
        TextField {
            id: entry
            property bool settingsNavItem: true
            property string settingsNavRole: "input"
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: Theme.spaceLg; rightPadding: Theme.spaceLg
            topPadding: Theme.spaceSm; bottomPadding: Theme.spaceSm
            width: Math.max(0, parent.width - 88); height: Theme.comfortableControlHeight
            placeholderText: root.label; color: Theme.fg; placeholderTextColor: Theme.fgMuted
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; selectByMouse: true
            Accessible.name: "Add " + root.label
            Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
            background: Rectangle { color: Theme.hoverMuted; radius: Theme.radius }
            onAccepted: root.add()
        }
        SettingsActionButton { width: 80; height: Theme.comfortableControlHeight; text: "Add"; activeFocusOnTab: true; focused: activeFocus; onClicked: root.add(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
    }
    Text { visible: !!root.error; text: root.error; color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
    // Reject duplicate or multiline entries before sending a list to the provider.
    function add() {
        var name = entry.text.trim()
        if (!name || /[\r\n\0]/.test(name)) { error = "Enter one item on a single line"; return }
        if (value.includes(name)) { error = "This item is already in the list"; return }
        edited(value.concat([name])); entry.text = ""; error = ""
    }
}
