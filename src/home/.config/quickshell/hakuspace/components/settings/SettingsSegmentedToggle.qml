import QtQuick
import "../../services"
import "../motion" as Motion

Item {
    id: root
    // Arrow targets are independent from compatibility Tab traversal.
    property bool settingsNavItem: true
    property string settingsNavRole: "control"
    property Item settingsNavGroup: null
    property bool checked: false
    property bool available: true
    property string hint: ""
    // Two-state settings may provide descriptive labels instead of Off/On.
    property var labels: ["Off", "On"]
    signal toggled(bool value)
    width: 126
    height: 36
    opacity: available ? 1 : 0.45
    enabled: available
    // Treat the whole switch as one keyboard stop; Enter flips its saved draft state.
    activeFocusOnTab: available && enabled
    Keys.enabled: available
    Keys.onReturnPressed: root.toggled(!root.checked)
    Keys.onEnterPressed: root.toggled(!root.checked)
    Keys.onSpacePressed: root.toggled(!root.checked)
    Accessible.role: Accessible.CheckBox
    Accessible.name: hint || labels.join(" / ")
    Accessible.checked: checked
    Accessible.onToggleAction: toggled(!checked)

    Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.hoverMuted; border.width: 1; border.color: Theme.hoverMuted }
    Item {
        id: lane
        anchors.fill: parent
        anchors.margins: 2
        readonly property real gap: 2
        readonly property real slotWidth: (width - gap) / 2
        // Indexed edges keep the morph continuous during toggles and resizing.
        Motion.SelectionPill {
            objectName: "settings-toggle-selection"
            z: 0
            targetIndex: root.checked ? 1 : 0
            slotCount: 2
            slotSpacing: lane.gap
            radius: lane.height / 2
        }
        Repeater {
            model: root.labels
            delegate: SettingsActionButton {
                id: segment
                settingsNavItem: false
                required property string modelData
                required property int index
                x: index * (lane.slotWidth + lane.gap)
                z: 1
                width: lane.slotWidth
                height: lane.height
                radius: height / 2
                text: modelData
                enabled: root.available
                activeFocusOnTab: false
                focused: root.activeFocus && selected
                selected: root.checked === (index === 1)
                selectedOverridesHover: true
                idleColor: "transparent"
                hoverColor: "transparent"
                pressedColor: "transparent"
                selectedColor: "transparent"
                focusColor: "transparent"
                foregroundColor: Theme.fgDim
                hoverForegroundColor: selected ? Theme.onAccentColor : Theme.fg
                pressedForegroundColor: selected ? Theme.onAccentColor : Theme.fg
                selectedForegroundColor: Theme.onAccentColor
                focusForegroundColor: selected ? Theme.onAccentColor : Theme.fg
                onClicked: root.toggled(index === 1)
                // Mark keyboard focus inside the selected half without another outline.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.gap
                    width: Math.max(0, Math.min(parent.width - Theme.pad * 2, Theme.fontSize * 2))
                    height: 1
                    color: Theme.onAccentColor
                    visible: root.activeFocus && segment.selected
                }
                SettingsTooltip {
                    target: segment
                    active: segment.hovered || (root.activeFocus && segment.selected)
                    text: root.hint + (root.activeFocus ? "\nEnter or Space toggles. Arrow keys move focus."
                        : "\nSet to " + segment.modelData + ".")
                }
            }
        }
    }
}
