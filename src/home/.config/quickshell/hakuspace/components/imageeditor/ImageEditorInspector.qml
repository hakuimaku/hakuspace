import QtQuick
import "../../services"
import "../settings" as Settings

Column {
    id: root
    width: 170
    spacing: 10
    enabled: ImageEditor.ready
    // Selected objects keep their own style until the user explicitly edits a control.
    readonly property var selected: ImageEditor.selectedAnnotation >= 0 ? ImageEditor.annotations[ImageEditor.selectedAnnotation] : null
    readonly property real strokeWidth: selected ? selected.width : ImageEditor.inkWidth
    readonly property real opacityValue: selected ? selected.opacity : ImageEditor.inkOpacity
    readonly property string colorValue: selected ? selected.color : ImageEditor.inkColor
    function style(color, width, opacity) { ImageEditor.styleAnnotation(color, width, opacity) }

    Text { text: "Crop ratio"; color: Theme.fg; font.pixelSize: Theme.fontSize }
    Flow {
        width: parent.width; spacing: 4
        Repeater {
            model: [{label: "Free", ratio: 0}, {label: "1:1", ratio: 1}, {label: "4:3", ratio: 4/3}, {label: "16:9", ratio: 16/9}]
            Settings.SettingsActionButton {
                required property var modelData
                width: 76; height: 32; text: modelData.label
                enabled: ImageEditor.mode !== "avatar" || modelData.ratio === 1
                selected: ImageEditor.cropRatio === modelData.ratio
                activeFocusOnTab: true
                onClicked: ImageEditor.setRatio(modelData.ratio)
                Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
            }
        }
    }
    Text { text: "Color"; color: Theme.fg; font.pixelSize: Theme.fontSize }
    Flow {
        width: parent.width; spacing: 4
        Repeater {
            model: ["#ff3b30", "#ffcc00", "#34c759", "#007aff", "#ffffff", "#000000"]
            Settings.SettingsActionButton {
                required property string modelData
                width: 48; height: 32; text: root.colorValue === modelData ? "✓" : "●"
                foregroundColor: modelData
                Accessible.name: "Annotation color " + modelData
                activeFocusOnTab: true
                onClicked: root.style(modelData, root.strokeWidth, root.opacityValue)
                Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
            }
        }
    }
    Text { text: "Width " + Math.round(root.strokeWidth * 1000); color: Theme.fg; font.pixelSize: Theme.fontSize }
    Settings.SettingsSlider {
        width: parent.width; from: 0.001; to: 0.04; stepSize: 0.001
        value: root.strokeWidth
        Accessible.name: "Annotation width"
        onMoved: if (!pressed) root.style(root.colorValue, value, root.opacityValue)
        onPressedChanged: if (!pressed) root.style(root.colorValue, value, root.opacityValue)
    }
    Text { text: "Opacity " + Math.round(root.opacityValue * 100) + "%"; color: Theme.fg; font.pixelSize: Theme.fontSize }
    Settings.SettingsSlider {
        width: parent.width; from: 0.05; to: 1; stepSize: 0.05
        value: root.opacityValue
        Accessible.name: "Annotation opacity"
        onMoved: if (!pressed) root.style(root.colorValue, root.strokeWidth, value)
        onPressedChanged: if (!pressed) root.style(root.colorValue, root.strokeWidth, value)
    }
    Text { visible: ImageEditor.mode !== "avatar"; text: "Output resolution"; color: Theme.fg; font.pixelSize: Theme.fontSize }
    Row {
        visible: ImageEditor.mode !== "avatar"; spacing: 4
        Repeater {
            model: [1, 0.75, 0.5]
            Settings.SettingsActionButton {
                required property real modelData
                width: 50; height: 32; text: Math.round(modelData * 100) + "%"
                selected: ImageEditor.outputScale === modelData
                activeFocusOnTab: true
                onClicked: ImageEditor.setOutput(modelData, ImageEditor.encodeQuality)
                Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
            }
        }
    }
    Text {
        width: parent.width; visible: ImageEditor.mode === "file"
        text: "JPEG / WebP quality: " + ImageEditor.encodeQuality
        color: Theme.fg; font.pixelSize: Theme.fontSize; wrapMode: Text.Wrap
    }
    Settings.SettingsSlider {
        visible: ImageEditor.mode === "file"
        width: parent.width; from: 1; to: 100; value: ImageEditor.encodeQuality
        Accessible.name: "JPEG or WebP encode quality"
        onMoved: if (!pressed) ImageEditor.setOutput(ImageEditor.outputScale, value)
        onPressedChanged: if (!pressed) ImageEditor.setOutput(ImageEditor.outputScale, value)
    }
    Settings.SettingsActionButton {
        width: parent.width; height: 36; text: "Delete annotation"
        enabled: root.selected !== null; activeFocusOnTab: true
        onClicked: ImageEditor.deleteAnnotation()
        Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
    }
    Settings.SettingsActionButton {
        width: parent.width; height: 36; text: "Reset"; activeFocusOnTab: true
        onClicked: ImageEditor.reset()
        Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
    }
}
