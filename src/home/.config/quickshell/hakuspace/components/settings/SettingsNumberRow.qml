import QtQuick
import QtQuick.Controls
import "../../services"

Row {
    id: root
    // Both controls edit the same bounded numeric draft.
    required property var descriptor
    required property var value
    // Duration settings can use the same numeric stepper without a wide-range slider.
    property bool showSlider: true
    property Item shortcutTarget: null
    signal edited(int value)
    spacing: Theme.spaceSm

    readonly property bool isTime: (root.descriptor && root.descriptor.unit === "s" && (!root.showSlider || root.descriptor.step === 10 || (root.descriptor.key && root.descriptor.key.endsWith("Timeout")))) || false
    readonly property int minVal: root.descriptor && root.descriptor.min !== undefined ? root.descriptor.min : (root.isTime ? 10 : 0)
    readonly property int maxVal: root.descriptor && root.descriptor.max !== undefined ? root.descriptor.max : 86400
    readonly property int currentValue: {
        var n = Number(root.value)
        if (isNaN(n) || n < root.minVal) n = root.minVal
        return root.isTime ? Math.round(n / 10) * 10 : n
    }

    function applyStep(delta) {
        var next = root.currentValue + delta
        if (next < root.minVal) next = root.minVal
        if (next > root.maxVal) next = root.maxVal
        if (root.isTime) {
            next = Math.round(next / 10) * 10
            if (next < root.minVal) next = root.minVal
        }
        root.edited(next)
    }

    // Direct button aliases for external tests or automation
    property alias plus10Button: plus10Btn
    property alias plus30Button: plus30Btn
    property alias minus10Button: minus10Btn
    property alias minus30Button: minus30Btn

    SettingsSlider {
        visible: root.showSlider && !root.isTime
        width: Math.max(0, root.width - number.width - unit.width - root.spacing * 2)
        from: root.descriptor.min
        to: root.descriptor.max
        stepSize: root.descriptor.step || 1
        value: Number(root.value) || from
        shortcutTarget: root.shortcutTarget
        Accessible.name: root.descriptor.label
        onMoved: root.edited(Math.round(value))
    }

    // Standard SpinBox for non-time settings
    SpinBox {
        id: number
        visible: !root.isTime
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

    // Time stepper with two step levels (+10, +30) and no text typing
    Row {
        id: timeControls
        visible: root.isTime
        spacing: Theme.spaceSm
        height: Theme.comfortableControlHeight

        // Backward-compatibility aliases for test harnesses
        readonly property var up: ({ indicator: plus10Btn })
        readonly property var down: ({ indicator: minus10Btn })
        property alias plus10: plus10Btn
        property alias plus30: plus30Btn
        property alias minus10: minus10Btn
        property alias minus30: minus30Btn

        SettingsActionButton {
            id: minus30Btn
            width: 44
            height: Theme.comfortableControlHeight
            text: "−30"
            foregroundColor: enabled ? Theme.fg : Theme.fgDim
            idleColor: Theme.hoverMuted
            enabled: root.currentValue > root.minVal
            Accessible.name: "Decrease " + (root.descriptor.label || "") + " by 30 seconds"
            onClicked: root.applyStep(-30)
        }
        SettingsActionButton {
            id: minus10Btn
            width: 44
            height: Theme.comfortableControlHeight
            text: "−10"
            foregroundColor: enabled ? Theme.fg : Theme.fgDim
            idleColor: Theme.hoverMuted
            enabled: root.currentValue > root.minVal
            Accessible.name: "Decrease " + (root.descriptor.label || "") + " by 10 seconds"
            onClicked: root.applyStep(-10)
        }
        Rectangle {
            id: valueBox
            width: 68
            height: Theme.comfortableControlHeight
            radius: Theme.radius
            color: Theme.hoverMuted
            border.width: 0
            border.color: Theme.accent
            Text {
                anchors.centerIn: parent
                text: String(root.currentValue)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                color: Theme.fg
            }
        }
        SettingsActionButton {
            id: plus10Btn
            width: 44
            height: Theme.comfortableControlHeight
            text: "+10"
            foregroundColor: enabled ? Theme.fg : Theme.fgDim
            idleColor: Theme.hoverMuted
            enabled: root.currentValue < root.maxVal
            Accessible.name: "Increase " + (root.descriptor.label || "") + " by 10 seconds"
            onClicked: root.applyStep(10)
        }
        SettingsActionButton {
            id: plus30Btn
            width: 44
            height: Theme.comfortableControlHeight
            text: "+30"
            foregroundColor: enabled ? Theme.fg : Theme.fgDim
            idleColor: Theme.hoverMuted
            enabled: root.currentValue < root.maxVal
            Accessible.name: "Increase " + (root.descriptor.label || "") + " by 30 seconds"
            onClicked: root.applyStep(30)
        }
    }

    Text { id: unit; height: Theme.comfortableControlHeight; verticalAlignment: Text.AlignVCenter; text: root.descriptor.unit || ""; color: Theme.fgDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
}
