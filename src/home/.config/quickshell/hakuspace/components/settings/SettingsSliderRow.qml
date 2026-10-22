import QtQuick
import "../../services"

Grid {
    id: row
    // Row metadata and editability come from the owning Settings page.
    required property var modelData
    property bool available: false
    property Item shortcutTarget: null
    width: parent.width
    columns: width < 540 ? 1 : 2
    columnSpacing: 16
    rowSpacing: 10
    Column {
        width: row.columns === 1 ? row.width : Math.round(row.width * 0.42)
        spacing: 3
        Text { width: parent.width; text: row.modelData.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; wrapMode: Text.Wrap }
    }
    Row {
        width: row.columns === 1 ? row.width : row.width - Math.round(row.width * 0.42) - 16
        spacing: 8
        SettingsSlider {
            shortcutTarget: row.shortcutTarget
            width: Math.max(0, parent.width - badge.width - 8)
            from: row.modelData.min
            to: row.modelData.max
            stepSize: row.modelData.step || 1
            value: ShellSettingsStore.values[row.modelData.section][row.modelData.key]
            enabled: row.available
            Accessible.name: row.modelData.accessible || row.modelData.label
            onMoved: ShellSettingsStore.setValue(row.modelData.section, row.modelData.key, Math.round(value / stepSize) * stepSize)
        }
        Rectangle {
            id: badge
            width: 64; height: 34
            radius: Theme.radius
            color: Theme.surface
            border.width: 1; border.color: Theme.hoverMuted
            Text {
                anchors.centerIn: parent
                text: ShellSettingsStore.values[row.modelData.section][row.modelData.key] + (row.modelData.unit || " px")
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 1)
            }
        }
    }
}
