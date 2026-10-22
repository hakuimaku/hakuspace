import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    required property var windowEntry
    required property int generation
    // A still capture starts with the source and refreshes once per navigator generation.
    ScreencopyView {
        id: preview
        anchors.centerIn: parent
        width: sourceSize.width > 0 ? Math.min(parent.width, parent.height * sourceSize.width / Math.max(1, sourceSize.height)) : parent.width
        height: sourceSize.height > 0 ? Math.min(parent.height, parent.width * sourceSize.height / Math.max(1, sourceSize.width)) : parent.height
        captureSource: root.windowEntry.waylandToplevel || null
        live: false
        paintCursor: false
    }
    onGenerationChanged: if (preview.hasContent) preview.captureFrame()
    Image {
        anchors.centerIn: parent
        width: Math.min(64, parent.width * 0.4); height: width
        source: Quickshell.iconPath(root.windowEntry.icon, "application-x-executable")
        fillMode: Image.PreserveAspectFit
        visible: !preview.hasContent
    }
}
