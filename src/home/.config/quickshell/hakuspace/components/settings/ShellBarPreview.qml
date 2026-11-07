import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../config/SettingsCatalog.js" as Catalog
import "SettingsNavigation.js" as Navigation

Column {
    id: root
    property Item shortcutTarget: null
    property bool showLayoutControl: true
    readonly property string settingsNavSection: "Top Bar"
    readonly property bool leftbar: ChromeLayout.leftBarMode
    // Search targets the preview chip instead of a duplicate preference row.
    function reveal(id) {
        var target = Navigation.collect(root).find(item => item.descriptorId === id)
        if (!target) return null
        target.forceActiveFocus()
        return target
    }
    spacing: Theme.spaceSm
    ShellLayoutControl {
        width: parent.width
        visible: root.showLayoutControl
        shortcutTarget: root.shortcutTarget
    }
    // Match the live bar order without starting its media or system services.
    Rectangle {
        id: bar
        width: parent.width; height: root.leftbar ? 310 : 52
        radius: ShellSettingsStore.baseRadius
        color: Theme.hoverMuted
        readonly property real unit: Math.min(32, (modules.width - Theme.gap * 11) / 20)
        RowLayout {
            id: modules
            visible: !root.leftbar
            anchors.fill: parent
            anchors.margins: Theme.spaceSm
            spacing: Theme.gap
            Repeater {
                model: [
                    [{key: "", label: "Logo / Navigation", icon: "󰮯", weight: 1},
                     {key: "workspaces", icon: "● ● ▰", weight: 2},
                     {key: "windowTitle", icon: " …", weight: 2}],
                    [{key: "cava", icon: "▁▃▆▂", weight: 2},
                     {key: "center", icon: " …", weight: 2}],
                    [{key: "tray", icon: " ", weight: 2},
                     {key: "quickControls", icon: "◐  ", weight: 3},
                     {key: "powerProfile", icon: "", weight: 1},
                     {key: "wallpaperWorkspace", icon: "", weight: 1},
                     {key: "recorder", icon: "", weight: 1},
                     {key: "clock", icon: "07:10", weight: 2},
                     {key: "notifications", icon: "", weight: 1}]
                ]
                delegate: RowLayout {
                    id: zone
                    required property var modelData
                    required property int index
                    Layout.fillWidth: index < 2
                    spacing: Theme.gap
                    Repeater {
                        model: zone.modelData
                        delegate: SettingsActionButton {
                            id: moduleButton
                            required property var modelData
                            readonly property string descriptorId: modelData.key ? "shell.topbar." + modelData.key : ""
                            readonly property string moduleName: descriptorId ? Catalog.descriptor(descriptorId).label : modelData.label
                            Layout.preferredWidth: bar.unit * modelData.weight
                            Layout.preferredHeight: 32
                            text: modelData.icon
                            fontSize: Math.min(Theme.fontSize - 2, bar.unit * 0.55)
                            selected: !descriptorId || SettingsCoordinator.read(descriptorId)
                            opacity: selected ? 1 : 0.45
                            idleColor: "transparent"
                            selectedColor: descriptorId ? Theme.accent : "transparent"
                            selectedForegroundColor: descriptorId ? Theme.onAccentColor : Theme.fg
                            activeFocusOnTab: true; focused: activeFocus
                            settingsNavGroup: modules
                            Accessible.role: descriptorId ? Accessible.CheckBox : Accessible.StaticText
                            Accessible.name: moduleName
                            Accessible.checked: !!descriptorId && selected
                            onClicked: { if (descriptorId) SettingsCoordinator.set(descriptorId, !selected) }
                            Keys.onReturnPressed: clicked()
                            Keys.onSpacePressed: clicked()
                            SettingsTooltip {
                                target: moduleButton
                                active: moduleButton.hovered || moduleButton.activeFocus
                                text: moduleButton.moduleName + " · " + (moduleButton.descriptorId
                                    ? (moduleButton.selected ? "On — click to turn off" : "Off — click to turn on")
                                    : "Always visible")
                            }
                        }
                    }
                    Item { Layout.fillWidth: true; visible: zone.index < 2 }
                }
            }
        }
        Flickable {
            visible: root.leftbar
            anchors.centerIn: parent
            width: 58; height: parent.height - 16
            contentWidth: width
            contentHeight: verticalModules.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: verticalModules
                width: parent.width
                spacing: 8
                Repeater {
                    model: ["", "workspaces", "windowTitle", "tray", "quickControls", "powerProfile", "wallpaperWorkspace", "recorder", "clock", "notifications"]
                    delegate: SettingsActionButton {
                        required property string modelData
                        readonly property string descriptorId: modelData ? "shell.topbar." + modelData : ""
                        readonly property var descriptor: descriptorId ? Catalog.descriptor(descriptorId) : null
                        width: parent.width
                        height: modelData === "windowTitle" ? 70 : modelData === "clock" ? 72 : 36
                        text: modelData === "clock" ? "07\n10" : ({"": "󰮯", workspaces: "●", windowTitle: "", tray: "", quickControls: "", powerProfile: "", wallpaperWorkspace: "", recorder: "", clock: "", notifications: ""})[modelData]
                        fontSize: modelData === "clock" ? Theme.fontSize + 6 : Theme.fontSize
                        selected: !descriptorId || SettingsCoordinator.read(descriptorId)
                        activeFocusOnTab: true
                        focused: activeFocus
                        Accessible.name: descriptor ? descriptor.label : "Logo / Navigation"
                        Accessible.role: descriptorId ? Accessible.CheckBox : Accessible.StaticText
                        Accessible.checked: selected
                        onClicked: if (descriptorId) SettingsCoordinator.set(descriptorId, !selected)
                        Keys.onReturnPressed: clicked()
                        Keys.onSpacePressed: clicked()
                        SettingsTooltip { target: parent; active: parent.hovered || parent.activeFocus; text: parent.Accessible.name }
                    }
                }
            }
        }

    }
}
