import QtQuick
import "../../services"
import "../motion" as Motion

Rectangle {
    id: root
    required property var options
    property var value
    property Item shortcutTarget: null
    signal chosen(var value)
    height: implicitHeight
    implicitHeight: Theme.comfortableControlHeight + Theme.spaceXs * 2
    radius: 12
    color: Qt.tint(Theme.surface, Qt.alpha(Theme.overlayInk, 0.05))
    Item {
        id: lane
        anchors.fill: parent; anchors.margins: Theme.spaceXs
        // Indexed edges preserve the morph through rapid changes and resizing.
        Motion.SelectionPill {
            objectName: "settings-segment-selection"
            targetIndex: root.options.findIndex(option => option.value === root.value)
            slotCount: root.options.length
            slotSpacing: segments.spacing
            shown: targetIndex >= 0 && slotCount > 0
            radius: 8
        }
        Row {
            id: segments
            anchors.fill: parent
            spacing: Theme.spaceXs
            Repeater {
                model: root.options
                delegate: SettingsActionButton {
                    required property var modelData
                    settingsNavGroup: root
                    width: Math.max(0, (segments.width - segments.spacing * (root.options.length - 1)) / root.options.length)
                    height: Theme.comfortableControlHeight
                    text: modelData.label
                    selected: root.value === modelData.value
                    radius: 8
                    idleColor: "transparent"
                    // The shared pill owns selection; buttons keep only text and input.
                    selectedColor: "transparent"
                    hoverColor: "transparent"
                    pressedColor: "transparent"
                    focusColor: "transparent"
                    selectedOverridesHover: true
                    selectedForegroundColor: Theme.onAccentColor
                    hoverForegroundColor: selected ? Theme.onAccentColor : Theme.fg
                    pressedForegroundColor: hoverForegroundColor
                    focusForegroundColor: hoverForegroundColor
                    activeFocusOnTab: true; focused: activeFocus
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: selected
                    Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                    onClicked: root.chosen(modelData.value)
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                }
            }
        }
    }
}
