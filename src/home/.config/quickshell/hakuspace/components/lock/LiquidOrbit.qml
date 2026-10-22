import QtQuick
import QtQuick.Shapes
import "../../services"

Item {
    id: root

    required property var orbit
    property color inkColor: Theme.accent

    // Attached top-right capsule protrusion (.orbit:before)
    Rectangle {
        x: root.orbit.beforeBlob.x
        y: root.orbit.beforeBlob.y
        width: root.orbit.beforeBlob.width
        height: root.orbit.beforeBlob.height
        radius: root.orbit.beforeBlob.radius
        rotation: root.orbit.beforeBlob.rotation
        color: root.inkColor
        visible: root.orbit.beforeBlob.visible
        antialiasing: true
    }

    // Attached bottom-left circular protrusion (.orbit:after)
    Rectangle {
        x: root.orbit.afterBlob.x
        y: root.orbit.afterBlob.y
        width: root.orbit.afterBlob.width
        height: root.orbit.afterBlob.height
        radius: root.orbit.afterBlob.radius
        color: root.inkColor
        visible: root.orbit.afterBlob.visible
        antialiasing: true
    }

    // Primary 4-quadrant cubic Bezier asymmetric liquid ring
    Shape {
        id: orbitShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.inkColor
            strokeWidth: root.orbit.strokeWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.orbit.top.x
            startY: root.orbit.top.y

            PathCubic {
                control1X: root.orbit.c0a.x
                control1Y: root.orbit.c0a.y
                control2X: root.orbit.c0b.x
                control2Y: root.orbit.c0b.y
                x: root.orbit.right.x
                y: root.orbit.right.y
            }

            PathCubic {
                control1X: root.orbit.c1a.x
                control1Y: root.orbit.c1a.y
                control2X: root.orbit.c1b.x
                control2Y: root.orbit.c1b.y
                x: root.orbit.bottom.x
                y: root.orbit.bottom.y
            }

            PathCubic {
                control1X: root.orbit.c2a.x
                control1Y: root.orbit.c2a.y
                control2X: root.orbit.c2b.x
                control2Y: root.orbit.c2b.y
                x: root.orbit.left.x
                y: root.orbit.left.y
            }

            PathCubic {
                control1X: root.orbit.c3a.x
                control1Y: root.orbit.c3a.y
                control2X: root.orbit.c3b.x
                control2Y: root.orbit.c3b.y
                x: root.orbit.top.x
                y: root.orbit.top.y
            }
        }
    }
}
