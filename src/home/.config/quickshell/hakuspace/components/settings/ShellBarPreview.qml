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
    readonly property string activeLayout: ChromeLayout.taskbarMode ? "taskbar" : ChromeLayout.leftBarMode ? "leftbar" : "topbar"
    readonly property var previewZones: Catalog.barPreviewZones(activeLayout)
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
        width: parent.width; height: 52
        radius: ShellSettingsStore.baseRadius
        color: Theme.hoverMuted
        readonly property real unit: Math.min(32, (modules.width - Theme.gap * 11) / 20)
        RowLayout {
            id: modules
            anchors.fill: parent
            anchors.margins: Theme.spaceSm
            spacing: Theme.gap
            Repeater {
                model: root.previewZones
                delegate: RowLayout {
                    id: zone
                    required property var modelData
                    required property int index
                    readonly property bool hasTrailingSpacer: index < root.previewZones.length - 1
                    Layout.fillWidth: hasTrailingSpacer
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
                            fontSize: Math.min(Theme.fontSize, bar.unit * 0.55)
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
                    Item { Layout.fillWidth: true; visible: zone.hasTrailingSpacer }
                }
            }
        }
    }
}
