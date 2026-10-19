import QtQuick
import QtQuick.Shapes
import "../../services"

Item {
    id: root
    // Small concave feet join the slanted sides to the bottom attachment edge.
    readonly property real baseFlareRadius: Math.min(Theme.radius / 2, height / 8)
    // Keep the slant and feet inside the existing horizontal safe envelope.
    readonly property real sideSlope: Math.min(Theme.hugRadius - baseFlareRadius, height / 2)
    readonly property real topInset: sideSlope + baseFlareRadius
    // Round the upper vertices without consuming the straight portions of short sides.
    readonly property real cornerRadius: Math.min(Theme.radius, height / 4, width / 4)
    // Place curve endpoints equally far along each slanted edge.
    readonly property real sideStepX: cornerRadius * sideSlope / Math.max(1, Math.hypot(sideSlope, height))
    readonly property real sideStepY: cornerRadius * height / Math.max(1, Math.hypot(sideSlope, height))
    readonly property real flareStepX: baseFlareRadius * sideSlope / Math.max(1, height)

    Shape {
        x: -root.topInset
        width: root.width + root.topInset * 2
        height: root.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.surface
            strokeColor: "transparent"
            startX: root.topInset + root.cornerRadius
            startY: 0
            PathLine { x: root.topInset + root.width - root.cornerRadius; y: 0 }
            PathQuad {
                controlX: root.topInset + root.width; controlY: 0
                x: controlX + root.sideStepX; y: root.sideStepY
            }
            PathLine {
                x: root.width + root.baseFlareRadius + root.sideSlope * 2 - root.flareStepX
                y: root.height - root.baseFlareRadius
            }
            PathQuad {
                controlX: root.width + root.baseFlareRadius + root.sideSlope * 2; controlY: root.height
                x: root.width + root.topInset * 2; y: root.height
            }
            PathLine { x: 0; y: root.height }
            PathQuad {
                controlX: root.baseFlareRadius; controlY: root.height
                x: root.baseFlareRadius + root.flareStepX; y: root.height - root.baseFlareRadius
            }
            PathLine { x: root.topInset - root.sideStepX; y: root.sideStepY }
            PathQuad {
                controlX: root.topInset; controlY: 0
                x: root.topInset + root.cornerRadius; y: 0
            }
        }
    }
}
