import QtQuick
import QtQuick.Shapes
import "LockMotion.js" as LM

Item {
    id: root

    // Normalized pressure front inputs; this renderer has no session-lock authority.
    required property var metrics
    required property color inkColor
    property real progress: 0
    property string mode: "capture"
    property bool reducedMotion: false
    readonly property var geometry: LM.layerSealGeometry(metrics, {
        progress: progress, mode: mode, reducedMotion: reducedMotion
    })
    visible: geometry.visible

    // Primary 4-quadrant cubic Bezier asymmetric liquid ring
    Shape {
        id: waveShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.inkColor
            strokeWidth: root.geometry.strokeWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.geometry.top.x
            startY: root.geometry.top.y

            PathCubic {
                control1X: root.geometry.c0a.x
                control1Y: root.geometry.c0a.y
                control2X: root.geometry.c0b.x
                control2Y: root.geometry.c0b.y
                x: root.geometry.right.x
                y: root.geometry.right.y
            }

            PathCubic {
                control1X: root.geometry.c1a.x
                control1Y: root.geometry.c1a.y
                control2X: root.geometry.c1b.x
                control2Y: root.geometry.c1b.y
                x: root.geometry.bottom.x
                y: root.geometry.bottom.y
            }

            PathCubic {
                control1X: root.geometry.c2a.x
                control1Y: root.geometry.c2a.y
                control2X: root.geometry.c2b.x
                control2Y: root.geometry.c2b.y
                x: root.geometry.left.x
                y: root.geometry.left.y
            }

            PathCubic {
                control1X: root.geometry.c3a.x
                control1Y: root.geometry.c3a.y
                control2X: root.geometry.c3b.x
                control2Y: root.geometry.c3b.y
                x: root.geometry.top.x
                y: root.geometry.top.y
            }
        }
    }
}
