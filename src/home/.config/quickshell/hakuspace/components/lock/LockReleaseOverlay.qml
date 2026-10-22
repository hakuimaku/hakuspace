import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../../services"
import "LockMotion.js" as LM

PanelWindow {
    id: root

    // Shared progress keeps every output on the same post-unlock reveal timeline.
    required property var modelData
    required property real progress
    readonly property var metrics: LM.metrics(width, height, Theme.fontSize)
    readonly property alias sealGeometry: wave.geometry
    // Resolve theme strings to color channels before matching the handoff nucleus.
    readonly property color inkColor: Theme.accent

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-lock-release"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}

    // The outer contour covers the desktop; the inner contour is a genuine alpha hole.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.surface
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0
            startX: -1
            startY: -1
            PathLine { x: root.width + 1; y: -1 }
            PathLine { x: root.width + 1; y: root.height + 1 }
            PathLine { x: -1; y: root.height + 1 }
            PathLine { x: -1; y: -1 }
            PathMove { x: root.sealGeometry.top.x; y: root.sealGeometry.top.y }
            PathCubic {
                control1X: root.sealGeometry.c0a.x
                control1Y: root.sealGeometry.c0a.y
                control2X: root.sealGeometry.c0b.x
                control2Y: root.sealGeometry.c0b.y
                x: root.sealGeometry.right.x
                y: root.sealGeometry.right.y
            }
            PathCubic {
                control1X: root.sealGeometry.c1a.x
                control1Y: root.sealGeometry.c1a.y
                control2X: root.sealGeometry.c1b.x
                control2Y: root.sealGeometry.c1b.y
                x: root.sealGeometry.bottom.x
                y: root.sealGeometry.bottom.y
            }
            PathCubic {
                control1X: root.sealGeometry.c2a.x
                control1Y: root.sealGeometry.c2a.y
                control2X: root.sealGeometry.c2b.x
                control2Y: root.sealGeometry.c2b.y
                x: root.sealGeometry.left.x
                y: root.sealGeometry.left.y
            }
            PathCubic {
                control1X: root.sealGeometry.c3a.x
                control1Y: root.sealGeometry.c3a.y
                control2X: root.sealGeometry.c3b.x
                control2Y: root.sealGeometry.c3b.y
                x: root.sealGeometry.top.x
                y: root.sealGeometry.top.y
            }
        }
    }

    LiquidSealWave {
        id: wave
        anchors.fill: parent
        metrics: root.metrics
        mode: "release"
        progress: root.progress
        visible: true
        // Match the faded, fully opaque nucleus at the secure-surface handoff.
        inkColor: Qt.tint(Theme.surface, Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, root.inkColor.a * 0.65))
    }
}
