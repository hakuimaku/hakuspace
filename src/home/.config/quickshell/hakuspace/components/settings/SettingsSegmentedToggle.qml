import QtQuick
import "../../services"
import "../motion" as Motion

Item {
    id: root
    property bool checked: false
    property bool available: true
    property string hint: ""
    signal toggled(bool value)
    width: 126
    height: 32
    opacity: available ? 1 : 0.45

    Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.hoverMuted }
    Item {
        id: lane
        anchors.fill: parent
        anchors.margins: 2
        readonly property real gap: 2
        readonly property real slotWidth: (width - gap) / 2
        Motion.SelectionPill {
            z: 0
            shown: true
            targetX: root.checked ? lane.slotWidth + lane.gap : 0
            targetY: 0
            targetWidth: lane.slotWidth
            targetHeight: lane.height
            targetRadius: Theme.radius
        }
        Repeater {
            model: ["Off", "On"]
            delegate: Motion.MorphButton {
                id: segment
                required property string modelData
                required property int index
                x: index * (lane.slotWidth + lane.gap)
                z: 1
                width: lane.slotWidth
                height: lane.height
                radius: Theme.radius
                text: modelData
                hoverScaleDelta: 0.004
                pressScaleDelta: 0.018
                enabled: root.available
                activeFocusOnTab: enabled
                focused: activeFocus
                selected: root.checked === (index === 1)
                selectedOverridesHover: true
                idleColor: "transparent"
                hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                pressedColor: Qt.lighter(Theme.hoverMuted, 1.18)
                selectedColor: "transparent"
                focusColor: "transparent"
                foregroundColor: Theme.fgDim
                hoverForegroundColor: Theme.fg
                pressedForegroundColor: Theme.fg
                selectedForegroundColor: Theme.onAccentColor
                focusForegroundColor: selected ? Theme.onAccentColor : Theme.fg
                border.width: activeFocus ? 1 : 0
                border.color: Theme.fg
                onClicked: root.toggled(index === 1)
                Keys.onReturnPressed: root.toggled(index === 1)
                Keys.onSpacePressed: root.toggled(index === 1)
                SettingsTooltip {
                    target: segment
                    active: segment.hovered || segment.activeFocus
                    text: root.hint + "\nSet to " + segment.modelData + "."
                }
            }
        }
    }
}
