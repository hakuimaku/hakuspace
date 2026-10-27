import QtQuick
import "../../services"
import "../wallpaper" as Wallpaper

Column {
    id: root
    spacing: 8
    width: 104
    enabled: ImageEditor.ready
    // Reuse the existing action-button morph while distributing all tools down the rail.
    Repeater {
        model: [{label: "Select", tool: "select"}, {label: "Crop", tool: "crop"},
            {label: "Pen", tool: "pen"}, {label: "Marker", tool: "marker"}, {label: "Arrow", tool: "arrow"}]
        Wallpaper.WallpaperActionButton {
            required property var modelData
            width: root.width
            height: Math.max(40, (root.height - root.spacing * 4) / 5)
            fontSize: Theme.fontSize
            text: modelData.label
            selected: ImageEditor.tool === modelData.tool
            onClicked: ImageEditor.tool = modelData.tool
        }
    }
}
