import QtQuick
import "../../services"
import "ImageEditorGeometry.js" as Geometry

Item {
    id: root
    // A gesture previews locally and commits exactly once on release.
    property var draft: null
    readonly property var rect: draft || ImageEditor.cropRectNormalized
    readonly property real cropLeft: rect.x * width
    readonly property real cropTop: rect.y * height
    readonly property real cropWidth: rect.width * width
    readonly property real cropHeight: rect.height * height
    readonly property real handleReach: 22
    Rectangle { x: 0; y: 0; width: root.width; height: root.cropTop; color: "#99000000" }
    Rectangle { x: 0; y: root.cropTop + root.cropHeight; width: root.width; height: root.height - y; color: "#99000000" }
    Rectangle { x: 0; y: root.cropTop; width: root.cropLeft; height: root.cropHeight; color: "#99000000" }
    Rectangle { x: root.cropLeft + root.cropWidth; y: root.cropTop; width: root.width - x; height: root.cropHeight; color: "#99000000" }
    Rectangle {
        x: root.cropLeft; y: root.cropTop; width: root.cropWidth; height: root.cropHeight
        color: "transparent"; border.color: Theme.accent; border.width: 2
        Repeater {
            model: [{x: 0, y: 0}, {x: 0.5, y: 0}, {x: 1, y: 0}, {x: 1, y: 0.5},
                {x: 1, y: 1}, {x: 0.5, y: 1}, {x: 0, y: 1}, {x: 0, y: 0.5}]
            Rectangle {
                required property var modelData
                width: modelData.x === 0.5 ? 32 : modelData.y === 0.5 ? 8 : 14
                height: modelData.y === 0.5 ? 32 : modelData.x === 0.5 ? 8 : 14
                radius: 3; color: Theme.surface; border.width: 2; border.color: Theme.accent
                x: modelData.x * parent.width - width / 2; y: modelData.y * parent.height - height / 2
            }
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        anchors.margins: -root.handleReach
        enabled: ImageEditor.tool === "crop" && ImageEditor.ready
        preventStealing: true
        hoverEnabled: true
        // Keep raw pointer positions for handles outside the image; edits still clamp to image bounds.
        property var start: null
        property var original: null
        property string handle: ""
        readonly property string hoveredHandle: Geometry.cropHandle(point({x: mouseX, y: mouseY}), root.rect, root.width, root.height, root.handleReach)
        cursorShape: {
            var hit = pressed ? handle : hoveredHandle
            if (hit === "nw" || hit === "se") return Qt.SizeFDiagCursor
            if (hit === "ne" || hit === "sw") return Qt.SizeBDiagCursor
            if (hit === "n" || hit === "s") return Qt.SizeVerCursor
            if (hit === "w" || hit === "e") return Qt.SizeHorCursor
            return hit === "move" ? Qt.SizeAllCursor : Qt.CrossCursor
        }
        function point(mouse) { return {x: (mouse.x - root.handleReach) / root.width, y: (mouse.y - root.handleReach) / root.height} }
        onPressed: mouse => {
            var p = point(mouse)
            start = {x: Geometry.clamp(p.x, 0, 1), y: Geometry.clamp(p.y, 0, 1)}
            original = ImageEditor.cropRectNormalized
            handle = Geometry.cropHandle(p, original, root.width, root.height, root.handleReach)
        }
        onPositionChanged: mouse => {
            if (!pressed) return
            var p = point(mouse), end = {x: Geometry.clamp(p.x, 0, 1), y: Geometry.clamp(p.y, 0, 1)}
            if (handle === "move") root.draft = {x: Geometry.clamp(original.x + end.x - start.x, 0, 1 - original.width),
                y: Geometry.clamp(original.y + end.y - start.y, 0, 1 - original.height), width: original.width, height: original.height}
            else if (handle) root.draft = Geometry.resizeCrop(original, handle, end, ImageEditor.cropRatio, ImageEditor.orientedWidth, ImageEditor.orientedHeight)
            else root.draft = Geometry.dragRect(start, end, ImageEditor.cropRatio, ImageEditor.orientedWidth, ImageEditor.orientedHeight)
        }
        onReleased: { if (root.draft) ImageEditor.setCrop(root.draft); root.draft = null }
        onCanceled: root.draft = null
    }
}
