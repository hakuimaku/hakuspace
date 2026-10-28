import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../services"
import "../../config/SettingsCatalog.js" as Catalog
import "SettingsNavigation.js" as Navigation

Column {
    id: root
    property string category: "Look"
    property string group: ""
    property var excludedIds: []
    property var onlyIds: []
    property Item shortcutTarget: null
    property string highlightedId: ""
    property var fontOptions: []
    property string fontListError: ""
    readonly property var descriptors: Catalog.descriptors.filter(function(d) { return d.category === root.category && (!root.group || d.group === root.group) && !root.excludedIds.includes(d.id) && (!root.onlyIds.length || root.onlyIds.includes(d.id)) })
    spacing: Theme.spaceLg
    // Fontconfig stays demand-driven and uses the existing theme controller.
    function refreshFonts() { if (!fontList.running) { fontListError = ""; fontList.command = SettingsStore.themeCommand("list-fonts"); fontList.running = true } }
    Component.onCompleted: if (descriptors.some(function(d) { return d.store === "theme" })) refreshFonts()
    Process {
        id: fontList
        stdout: StdioCollector { id: fontOut }
        stderr: StdioCollector { id: fontErr }
        onExited: code => {
            if (code !== 0) { root.fontListError = fontErr.text.trim() || "Could not load fonts"; return }
            root.fontOptions = fontOut.text.split("\n").map(v => v.trim()).filter((v, i, a) => v && a.indexOf(v) === i).map(v => ({label: v, value: v}))
        }
    }
    // Focus the actual control so search preserves keyboard navigation.
    function reveal(id) {
        for (var i = 0; i < rows.count; i++) {
            var row = rows.itemAt(i)
            if (row.descriptor.id === id && row.state.visible) { var targets = Navigation.collect(row.control.item); if (targets.length) targets[0].forceActiveFocus(); return row }
        }
        return null
    }
    Repeater {
        id: rows
        model: root.descriptors
        delegate: SettingsReveal {
            id: row
            required property var modelData
            readonly property var descriptor: modelData
            readonly property var state: SettingsCoordinator.state(descriptor.id)
            readonly property var value: SettingsCoordinator.read(descriptor.id)
            readonly property string settingsNavSection: descriptor.group
            property alias control: control
            expanded: state.visible
            width: root.width
            expandedHeight: body.implicitHeight + Theme.spaceMd * 2
            radius: Theme.radius
            color: root.highlightedId === descriptor.id ? Theme.hoverMuted : "transparent"
            border.width: root.highlightedId === descriptor.id ? 1 : 0
            border.color: Theme.accent
            // Sliders debounce persistence; discrete controls commit immediately.
            function set(value, deferred) { SettingsCoordinator.set(descriptor.id, value, deferred) }
            Column {
                id: body
                x: Theme.spaceMd; y: Theme.spaceMd
                width: Math.max(0, parent.width - x * 2)
                spacing: Theme.spaceSm
                Text { width: parent.width; text: row.descriptor.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
                Text { visible: !!text; width: parent.width; text: row.descriptor.summary || ""; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
                Loader {
                    id: control
                    width: parent.width
                    enabled: row.state.enabled
                    opacity: enabled ? 1 : 0.45
                    sourceComponent: row.descriptor.control === "switch" ? toggle : row.descriptor.control === "choice" ? (row.descriptor.provider !== "theme" && (row.descriptor.options || []).length <= 4 ? segmented : choice)
                        : row.descriptor.control === "number" ? number : row.descriptor.control === "duration" ? duration
                        : row.descriptor.control === "path" ? path : row.descriptor.control === "list" ? list : input
                }
                Text { visible: !!text; width: parent.width; text: row.state.reason; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2; wrapMode: Text.Wrap }
                SettingsActionButton { visible: row.state.action === "layout"; width: 190; height: 32; text: "Switch to Top Bar"; activeFocusOnTab: true; focused: activeFocus; onClicked: SettingsCoordinator.set("layout", "topbar"); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                Text { visible: row.descriptor.key === "WAYBAR_MODE_USER"; width: parent.width; text: "Used by Classic shell. Hikai shell keeps its native bars."; wrapMode: Text.Wrap; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                Text { visible: row.descriptor.key === "SCREENSHOT_DIR" && WM.backendName === "niri"; width: parent.width; text: "Niri built-in screenshot keys do not use this folder by default. Bind the HakuSpace screenshot script or edit Niri’s screenshot-path."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                SettingsActionButton { visible: row.descriptor.key === "SCREENSHOT_DIR" && WM.backendName === "niri"; width: 180; height: 32; text: "Open Niri config"; activeFocusOnTab: true; focused: activeFocus; onClicked: { ConfigEditorStore.selectFile("wm/niri-custom.kdl"); UiState.settingsGroup = "Advanced" } Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
            }
            Component { id: toggle; SettingsSwitch { checked: row.value === true; shortcutTarget: root.shortcutTarget; Accessible.name: row.descriptor.label; onToggled: value => row.set(value, false) } }
            Component {
                id: segmented
                SettingsSegmentedControl {
                    options: row.descriptor.id === "surface" ? [{value: "ink", label: Theme.isLight ? "Pure White" : "Ink"}, {value: "dark", label: Theme.isLight ? "White" : "Dark"}, {value: "soft", label: Theme.isLight ? "Gray White" : "Soft"}] : row.descriptor.options
                    value: row.value; shortcutTarget: root.shortcutTarget
                    onChosen: value => row.set(value, false)
                }
            }
            Component {
                id: choice
                SettingsChoiceRow {
                    options: row.descriptor.provider === "theme" ? root.fontOptions : row.descriptor.options || []
                    value: row.value; shortcutTarget: root.shortcutTarget
                    searchable: row.descriptor.provider === "theme"; loading: searchable && fontList.running
                    statusMessage: searchable ? root.fontListError : ""
                    Accessible.name: row.descriptor.label
                    onRefreshRequested: root.refreshFonts()
                    onChosen: value => row.set(value, false)
                }
            }
            Component { id: number; SettingsValueSlider { descriptor: row.descriptor; value: Number(row.value) || 0; shortcutTarget: root.shortcutTarget; onEdited: value => row.set(value, true); onEditingFinished: SettingsCoordinator.flush() } }
            Component { id: duration; SettingsDurationField { descriptor: row.descriptor; value: Number(row.value) || 0; shortcutTarget: root.shortcutTarget; onEdited: value => row.set(value, false) } }
            Component { id: path; SettingsPathField { value: String(row.value || ""); label: row.descriptor.label; shortcutTarget: root.shortcutTarget; onEdited: value => row.set(value, false) } }
            Component { id: list; SettingsChipList { value: row.value || []; label: row.descriptor.entryLabel || row.descriptor.label; shortcutTarget: root.shortcutTarget; onEdited: value => row.set(value, false) } }
            Component {
                id: input
                TextField {
                    property bool settingsNavItem: true
                    property string settingsNavRole: "input"
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: Theme.spaceLg; rightPadding: Theme.spaceLg
                    topPadding: Theme.spaceSm; bottomPadding: Theme.spaceSm
                    height: Theme.comfortableControlHeight
                    text: String(row.value || ""); selectByMouse: true
                    color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
                    Accessible.name: row.descriptor.label
                    Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                    background: Rectangle { radius: Theme.radius; color: Theme.hoverMuted; border.width: parent.activeFocus ? 1 : 0; border.color: Theme.accent }
                    onEditingFinished: row.set(text, false)
                }
            }
        }
    }
}
