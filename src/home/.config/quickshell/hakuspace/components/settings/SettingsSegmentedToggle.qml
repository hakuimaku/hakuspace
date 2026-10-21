import QtQuick
import "../../services"
import "../motion" as Motion

Item {
    id: root
    property bool checked: false
    property bool available: true
    property string hint: ""
    // Two-state settings may provide descriptive labels instead of Off/On.
    property var labels: ["Off", "On"]
    signal toggled(bool value)
    width: 126
    height: 36
    opacity: available ? 1 : 0.45

    Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.hoverMuted; border.width: 1; border.color: Theme.hoverMuted }
    Item {
        id: lane
        anchors.fill: parent
        anchors.margins: 2
        readonly property real gap: 2
        readonly property real slotWidth: (width - gap) / 2
        Motion.SelectionPill {
            z: 0
            shown: true
            duration: HAnimation.slow
            trailFactor: 1.15
            targetX: root.checked ? lane.slotWidth + lane.gap : 0
            targetY: 0
            targetWidth: lane.slotWidth
            targetHeight: lane.height
            targetRadius: Theme.radius
        }
        Repeater {
            model: root.labels
            delegate: SettingsActionButton {
                id: segment
                required property string modelData
                required property int index
                x: index * (lane.slotWidth + lane.gap)
                z: 1
                width: lane.slotWidth
                height: lane.height
                text: modelData
                enabled: root.available
                activeFocusOnTab: enabled
                focused: activeFocus
                selected: root.checked === (index === 1)
                selectedOverridesHover: true
                idleColor: "transparent"
                hoverColor: Theme.hoverMuted
                pressedColor: selected ? "transparent" : Theme.hoverMuted
                selectedColor: "transparent"
                focusColor: "transparent"
                foregroundColor: Theme.fgDim
                hoverForegroundColor: Theme.fg
                pressedForegroundColor: selected ? "#000000" : Theme.fg
                selectedForegroundColor: "#000000"
                focusForegroundColor: selected ? "#000000" : Theme.fg
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
