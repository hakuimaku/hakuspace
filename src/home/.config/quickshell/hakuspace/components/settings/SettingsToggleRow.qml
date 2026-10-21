import QtQuick
import "../../services"

Grid {
    id: row
    // Row metadata and editability come from the owning Settings page.
    required property var modelData
    property bool available: false
    property string section: "dock"
    width: parent.width
    columns: width < 450 ? 1 : 2
    columnSpacing: 16
    rowSpacing: 10
    Column {
        width: row.columns === 1 ? row.width : Math.max(0, row.width - toggle.width - 16)
        spacing: 6
        Text { width: parent.width; text: row.modelData.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; wrapMode: Text.Wrap }
        Text {
            width: parent.width
            visible: !!row.modelData.hint
            text: row.modelData.hint || ""
            color: Qt.hsla(0, 0, Qt.darker(Theme.fgDim, 1).hslLightness, 1)
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
            wrapMode: Text.Wrap
        }
    }
    SettingsSegmentedToggle {
        id: toggle
        width: row.modelData.labels ? 186 : 126
        labels: row.modelData.labels || ["Off", "On"]
        available: row.available
        enabled: row.available
        hint: row.modelData.hint || ""
        checked: row.modelData.key === "visibilityMode" ? ShellSettingsStore.dockVisibilityMode === "always"
            : ShellSettingsStore.values[row.section][row.modelData.key]
        Accessible.role: Accessible.CheckBox
        Accessible.name: row.modelData.label
        Accessible.checked: checked
        Accessible.onToggleAction: toggled(!checked)
        onToggled: value => ShellSettingsStore.setValue(row.section, row.modelData.key,
            row.modelData.key === "visibilityMode" ? (value ? "always" : "autohide") : value)
    }
}
