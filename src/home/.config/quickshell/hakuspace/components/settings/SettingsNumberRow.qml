import QtQuick
import QtQuick.Controls
import "../../services"

Row {
    id: root
    // Both controls edit the same bounded numeric draft.
    required property var descriptor
    required property var value
    property Item shortcutTarget: null
    signal edited(int value)
    spacing: Theme.spaceSm
    SettingsSlider {
        width: Math.max(0, root.width - number.width - unit.width - root.spacing * 2)
        from: root.descriptor.min
        to: root.descriptor.max
        stepSize: root.descriptor.step || 1
        value: Number(root.value) || from
        shortcutTarget: root.shortcutTarget
        Accessible.name: root.descriptor.label
        onMoved: root.edited(Math.round(value))
    }
    SpinBox {
        id: number
        property bool settingsNavItem: true
        property string settingsNavRole: "control"
        readonly property bool settingsNavOwnsHorizontal: true
        readonly property bool settingsNavOwnsVertical: true
        width: Math.min(138, root.width * 0.5)
        height: Theme.comfortableControlHeight
        from: root.descriptor.min
        to: root.descriptor.max
        stepSize: root.descriptor.step || 1
        value: Number(root.value) || from
        editable: true
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        Accessible.name: root.descriptor.label + " value"
        onValueModified: root.edited(value)
        background: Rectangle { color: Theme.hoverMuted; radius: Theme.radius; border.width: number.activeFocus ? 1 : 0; border.color: Theme.accent }
        contentItem: TextInput {
            text: number.textFromValue(number.value, number.locale)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccentColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            validator: number.validator
            inputMethodHints: Qt.ImhDigitsOnly
            selectByMouse: true
            onEditingFinished: if (acceptableInput) root.edited(number.valueFromText(text, number.locale))
        }
        up.indicator: SettingsActionButton {
            x: number.width - width
            width: 30; height: number.height
            text: "+"
            idleColor: "transparent"
            selectedColor: "transparent"
            foregroundColor: Theme.fg
            Accessible.name: "Increase " + root.descriptor.label
            onClicked: root.edited(Math.min(number.to, number.value + number.stepSize))
        }
        down.indicator: SettingsActionButton {
            width: 30; height: number.height
            text: "−"
            idleColor: "transparent"
            selectedColor: "transparent"
            foregroundColor: Theme.fg
            Accessible.name: "Decrease " + root.descriptor.label
            onClicked: root.edited(Math.max(number.from, number.value - number.stepSize))
        }
        leftPadding: 30
        rightPadding: 30
        palette.button: Theme.hoverMuted
        palette.buttonText: Theme.fg
        palette.base: Theme.surface
        palette.text: Theme.fg
    }
    Text { id: unit; height: Theme.comfortableControlHeight; verticalAlignment: Text.AlignVCenter; text: root.descriptor.unit || ""; color: Theme.fgDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
}
