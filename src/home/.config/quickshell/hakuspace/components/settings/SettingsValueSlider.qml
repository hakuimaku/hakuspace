import QtQuick
import QtQuick.Controls
import "../../services"

Row {
    id: root
    required property var descriptor
    property int value: 0
    property Item shortcutTarget: null
    signal edited(int value)
    signal editingFinished()
    spacing: Theme.spaceSm
    SettingsSlider {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - number.width - unit.implicitWidth - root.spacing * 2)
        from: root.descriptor.min; to: root.descriptor.max
        stepSize: root.descriptor.step || 1
        value: root.value
        shortcutTarget: root.shortcutTarget
        Accessible.name: root.descriptor.label
        onMoved: root.edited(Math.round(value))
        onPressedChanged: if (!pressed) root.editingFinished()
    }
    SpinBox {
        id: number
        property bool settingsNavItem: true
        property string settingsNavRole: "input"
        readonly property bool settingsNavOwnsHorizontal: true
        readonly property bool settingsNavOwnsVertical: true
        width: 130; height: Theme.comfortableControlHeight
        from: root.descriptor.min; to: root.descriptor.max
        stepSize: root.descriptor.step || 1
        value: root.value; editable: true
        palette.text: Theme.fg; palette.buttonText: Theme.fg; palette.base: Theme.surface; palette.button: Theme.hoverMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        leftPadding: 28; rightPadding: 28
        background: Rectangle { radius: Theme.radius; color: Theme.hoverMuted; border.width: number.activeFocus ? 1 : 0; border.color: Theme.accent }
        contentItem: TextInput {
            text: number.textFromValue(number.value, number.locale)
            color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            selectByMouse: true; validator: number.validator
            selectionColor: Theme.accent; selectedTextColor: Theme.onAccentColor
            onEditingFinished: if (acceptableInput) { root.edited(number.valueFromText(text, number.locale)); root.editingFinished() }
        }
        up.indicator: SettingsActionButton { x: number.width - width; y: 0; width: 28; height: number.height; text: "+"; idleColor: "transparent"; onClicked: { root.edited(Math.min(number.to, root.value + number.stepSize)); root.editingFinished() } }
        down.indicator: SettingsActionButton { y: 0; width: 28; height: number.height; text: "−"; idleColor: "transparent"; onClicked: { root.edited(Math.max(number.from, root.value - number.stepSize)); root.editingFinished() } }
        Accessible.name: root.descriptor.label + " value"
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        onValueModified: { root.edited(value); root.editingFinished() }
    }
    Text { id: unit; height: number.height; verticalAlignment: Text.AlignVCenter; text: root.descriptor.unit || ""; color: Theme.fgDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
}
