import QtQuick
import "../../services"
import "../motion" as Motion

Item {
    id: root
    // Primary domains share one tab strip across all pages.
    property string selected: "General"
    property string source: ""
    readonly property var domains: ["General", "Shell", "Config", "Info"]
    signal selectedRequested(string domain)
    signal shortcutsRequested()
    // The guide borrows the question button's geometry during its reveal.
    property alias shortcutButton: helpButton
    property bool guideOpen: false
    implicitHeight: width < 650 ? 100 : 64
    Rectangle {
        x: 20; y: 18; width: 28; height: 28
        radius: Theme.radius
        color: Theme.hoverMuted
        Text { anchors.centerIn: parent; text: "󰮯"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Math.round(Theme.fontSize * 1.35) }
    }
    Text {
        x: 58; y: 21
        text: "Settings"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        font.weight: Font.DemiBold
    }
    Item {
        id: tabs
        x: root.width < 650 ? 20 : 180
        y: root.width < 650 ? 56 : 12
        width: Math.min(354, root.width - x - 20)
        height: 38
        readonly property real slotWidth: Math.max(0, (width - 18) / 4)
        Motion.SelectionPill {
            shown: true
            targetIndex: root.domains.indexOf(root.selected)
            slotCount: 4
            slotSpacing: 6
            color: Theme.accent
            radius: Theme.radius
            duration: HAnimation.slow
            trailFactor: 1.15
        }
        Repeater {
            model: root.domains
            delegate: SettingsActionButton {
                id: tab
                settingsNavRole: "domain"
                required property string modelData
                required property int index
                x: index * (tabs.slotWidth + 6)
                width: tabs.slotWidth
                height: tabs.height
                text: modelData
                selected: root.selected === modelData
                selectedOverridesHover: true
                idleColor: "transparent"
                selectedColor: "transparent"
                hoverColor: Theme.hoverMuted
                pressedColor: selected ? "transparent" : Theme.hoverMuted
                foregroundColor: Theme.fgDim
                selectedForegroundColor: "#000000"
                hoverForegroundColor: Theme.fg
                pressedForegroundColor: selected ? "#000000" : Theme.fg
                activeFocusOnTab: true
                focused: activeFocus
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData
                Accessible.selected: selected
                Accessible.onPressAction: clicked()
                onClicked: root.selectedRequested(modelData)
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
            }
        }
    }
    Text {
        x: root.width < 650 ? 175 : tabs.x + tabs.width + 16
        y: 24
        width: Math.max(0, parent.width - x - 64)
        text: root.source
        color: Theme.fgMuted
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(10, Theme.fontSize - 3)
        elide: Text.ElideLeft
    }
    SettingsActionButton {
        id: helpButton
        settingsNavItem: false
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 14
        width: 34
        height: 34
        text: "?"
        opacity: root.guideOpen ? 0 : enabled ? 1 : disabledOpacity
        idleColor: Theme.hoverMuted
        foregroundColor: Theme.fg
        activeFocusOnTab: true
        focused: activeFocus
        Accessible.name: "Keyboard shortcuts"
        onClicked: root.shortcutsRequested()
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
        SettingsTooltip { target: parent; active: parent.hovered || parent.activeFocus; text: "Keyboard shortcuts · F1" }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hoverMuted }
}
