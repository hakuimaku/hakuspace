import QtQuick
import QtQuick.Controls
import "../../services"
import "SettingsValueLogic.js" as Logic

Column {
    id: root
    required property var descriptor
    property int value: 0
    property Item shortcutTarget: null
    signal edited(int value)
    spacing: Theme.spaceSm
    TextField {
        id: field
        property bool settingsNavItem: true
        property string settingsNavRole: "input"
        verticalAlignment: TextInput.AlignVCenter
        leftPadding: Theme.spaceLg; rightPadding: Theme.spaceLg
        topPadding: Theme.spaceSm; bottomPadding: Theme.spaceSm
        width: Math.min(240, root.width); height: 44
        text: Logic.duration(root.value)
        color: acceptable ? Theme.fg : Theme.accent
        readonly property bool acceptable: Logic.parseDuration(text, root.descriptor) !== null
        Accessible.name: root.descriptor.label + " (minutes or seconds)"
        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; selectByMouse: true
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        background: Rectangle { radius: 8; color: Theme.hoverMuted; border.width: field.activeFocus ? 1 : 0; border.color: Theme.accent }
        onEditingFinished: { var seconds = Logic.parseDuration(text, root.descriptor); if (seconds !== null) root.edited(seconds) }
    }
    Text { visible: !field.acceptable; text: "Enter a valid duration, e.g. 5 min or 30 sec"; color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
    Flow {
        width: parent.width; spacing: Theme.spaceSm
        Repeater {
            model: [1, 2, 5, 10, 15, 30].filter(function(n) { return n * 60 >= root.descriptor.min && n * 60 <= root.descriptor.max })
            delegate: SettingsActionButton {
                id: preset
                required property int modelData
                TextMetrics { id: presetMetrics; text: preset.text; font.family: Theme.fontFamily; font.pixelSize: preset.fontSize }
                width: Math.max(84, Math.ceil(presetMetrics.width + Theme.spaceLg * 2))
                height: 36; text: modelData + " min"
                fontSize: Theme.fontSize + 1
                selected: root.value === modelData * 60
                activeFocusOnTab: true; focused: activeFocus
                onClicked: root.edited(modelData * 60)
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
            }
        }
    }
}
