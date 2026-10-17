import QtQuick
import Quickshell
import "../../services"

Item {
    id: root
    property var zones: []
    property bool closePending: false
    // Geometry guides are opt-in and never participate in pointer input.
    readonly property bool geometryDebug: Quickshell.env("QS_GEOMETRY_DEBUG") === "1"
    property real screenWidth: width
    property real screenHeight: height
    property var hostRect: ({x: 0, y: 0, width: width, height: height})
    property var anchorRect: null
    property var localizedAnchorRect: null
    property real flareStart: -1
    property real flareEnd: -1
    readonly property var guides: geometryDebug ? [
        {rect: {x: 0, y: ScreenGeometry.flareTopY, width: screenWidth, height: 1}, label: "TopBar / flareTopY"},
        {rect: {x: ScreenGeometry.leftInset, y: 0, width: 1, height: screenHeight}, label: "leftInset"},
        {rect: {x: screenWidth - ScreenGeometry.rightInset - 1, y: 0, width: 1, height: screenHeight}, label: "rightInset"},
        {rect: {x: 0, y: screenHeight - ScreenGeometry.bottomInset - 1, width: screenWidth, height: 1}, label: "bottomInset"}
    ] : []
    visible: geometryDebug || Quickshell.env("QS_SAFEZONE_DEBUG") === "1"
    enabled: false

    Repeater {
        model: root.guides
        delegate: Rectangle {
            required property var modelData
            readonly property var local: ScreenGeometry.localizeRect(modelData.rect, root.hostRect)
            x: local.x; y: local.y; width: local.width; height: local.height
            visible: width > 0 && height > 0
            color: "#ff44dd"
            Text { text: parent.modelData.label; color: "#ff44dd"; font.pixelSize: 10 }
        }
    }
    Rectangle {
        readonly property var local: ScreenGeometry.localizeRect(root.anchorRect, root.hostRect)
        visible: root.geometryDebug && root.anchorRect !== null
        x: local.x; y: local.y; width: local.width; height: local.height
        color: "transparent"; border.width: 2; border.color: "#0088ff"
    }
    Rectangle {
        visible: root.geometryDebug && root.localizedAnchorRect !== null
        x: root.localizedAnchorRect ? root.localizedAnchorRect.x : 0
        y: root.localizedAnchorRect ? root.localizedAnchorRect.y : 0
        width: root.localizedAnchorRect ? root.localizedAnchorRect.width : 0
        height: root.localizedAnchorRect ? root.localizedAnchorRect.height : 0
        color: "transparent"; border.width: 1; border.color: "#ffff00"
    }
    Rectangle {
        visible: root.geometryDebug && root.flareEnd > root.flareStart
        x: root.flareStart; y: ScreenGeometry.flareTopY - root.hostRect.y
        width: Math.max(0, root.flareEnd - root.flareStart); height: 2
        color: "#ff8800"
    }
    Text {
        visible: root.geometryDebug && root.anchorRect !== null
        y: ScreenGeometry.flareTopY - root.hostRect.y + 3
        text: "screen anchor: " + JSON.stringify(root.anchorRect) + "\nlocal anchor: " + JSON.stringify(root.localizedAnchorRect)
        color: "#ffff00"; font.pixelSize: 10
    }

    Repeater {
        model: root.visible ? root.zones : []
        delegate: Rectangle {
            required property var modelData
            x: modelData.rect.x
            y: modelData.rect.y
            width: modelData.rect.width
            height: modelData.rect.height
            color: root.closePending ? "#33ff0000"
                : modelData.kind === "anchor" ? "#330078ff"
                : modelData.kind === "corridor" ? "#33ffcc00"
                : modelData.kind === "animation" ? "#339933ff" : "#3300ff66"
            border.color: root.closePending ? "#ff0000"
                : modelData.kind === "anchor" ? "#0078ff"
                : modelData.kind === "corridor" ? "#ffcc00"
                : modelData.kind === "animation" ? "#9933ff" : "#00ff66"
        }
    }
}
