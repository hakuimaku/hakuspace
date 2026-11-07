import QtQuick
import QtQuick.Shapes
import "../../services"

Shape {
    id: bottomPanel
    // Preserve the horizontal shoulder path beside the Leftbar corner silhouette.
    property bool vertical: false
    property real topWidth: 1
    property real headerPadding: 0
    // Static layout points draw the rail and cradle as one continuous surface.
    property var backingCurve: null
    readonly property var curve: backingCurve || ({top: Qt.point(0, 0), topEnd: Qt.point(0, 0), start: Qt.point(0, 0), selected: Qt.point(0, 0), floor: Qt.point(0, 0),
        incoming1: Qt.point(0, 0), incoming2: Qt.point(0, 0), outgoing1: Qt.point(0, 0), outgoing2: Qt.point(0, 0)})
    readonly property real axisSpan: vertical ? height : width
    readonly property real axisDepth: vertical ? width : height
    readonly property real upperLeft: (axisSpan - topWidth) / 2
    readonly property real upperRight: (axisSpan + topWidth) / 2
    readonly property real upperCornerRadius: Math.min(Math.max(Theme.giantRadius + headerPadding, ScreenGeometry.roundedRadius), topWidth / 4, axisDepth / 3)
    readonly property real flareRadius: Math.min(ScreenGeometry.edgeHugRadius, axisDepth / 3)
    readonly property real sideRun: (axisSpan - topWidth) / 2
    readonly property real sideRise: axisDepth
    readonly property real flareTop: axisDepth - flareRadius
    readonly property real sideLength: Math.max(1, Math.sqrt(sideRun * sideRun + sideRise * sideRise))
    readonly property real slopeX: sideRun / sideLength
    readonly property real slopeY: sideRise / sideLength
    function px(u, v) { return vertical ? v : u }
    function py(u, v) { return vertical ? u : v }
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        fillColor: bottomPanel.vertical ? "transparent" : Theme.surface
        strokeColor: "transparent"
        startX: bottomPanel.px(bottomPanel.upperLeft + bottomPanel.upperCornerRadius, 0)
        startY: bottomPanel.py(bottomPanel.upperLeft + bottomPanel.upperCornerRadius, 0)
        PathLine {
            x: bottomPanel.px(bottomPanel.upperRight - bottomPanel.upperCornerRadius, 0)
            y: bottomPanel.py(bottomPanel.upperRight - bottomPanel.upperCornerRadius, 0)
        }
        PathQuad {
            controlX: bottomPanel.px(bottomPanel.upperRight, 0)
            controlY: bottomPanel.py(bottomPanel.upperRight, 0)
            x: bottomPanel.px(bottomPanel.upperRight + bottomPanel.slopeX * bottomPanel.upperCornerRadius, bottomPanel.slopeY * bottomPanel.upperCornerRadius)
            y: bottomPanel.py(bottomPanel.upperRight + bottomPanel.slopeX * bottomPanel.upperCornerRadius, bottomPanel.slopeY * bottomPanel.upperCornerRadius)
        }
        PathLine {
            x: bottomPanel.px(bottomPanel.axisSpan - bottomPanel.slopeX * bottomPanel.flareRadius, bottomPanel.sideRise - bottomPanel.slopeY * bottomPanel.flareRadius)
            y: bottomPanel.py(bottomPanel.axisSpan - bottomPanel.slopeX * bottomPanel.flareRadius, bottomPanel.sideRise - bottomPanel.slopeY * bottomPanel.flareRadius)
        }
        PathQuad {
            controlX: bottomPanel.px(bottomPanel.axisSpan, bottomPanel.axisDepth)
            controlY: bottomPanel.py(bottomPanel.axisSpan, bottomPanel.axisDepth)
            x: bottomPanel.px(bottomPanel.axisSpan, bottomPanel.flareTop)
            y: bottomPanel.py(bottomPanel.axisSpan, bottomPanel.flareTop)
        }
        PathLine { x: bottomPanel.px(bottomPanel.axisSpan, bottomPanel.axisDepth); y: bottomPanel.py(bottomPanel.axisSpan, bottomPanel.axisDepth) }
        PathLine { x: bottomPanel.px(0, bottomPanel.axisDepth); y: bottomPanel.py(0, bottomPanel.axisDepth) }
        PathLine { x: bottomPanel.px(0, bottomPanel.flareTop); y: bottomPanel.py(0, bottomPanel.flareTop) }
        PathQuad {
            controlX: bottomPanel.px(0, bottomPanel.axisDepth); controlY: bottomPanel.py(0, bottomPanel.axisDepth)
            x: bottomPanel.px(bottomPanel.slopeX * bottomPanel.flareRadius, bottomPanel.sideRise - bottomPanel.slopeY * bottomPanel.flareRadius)
            y: bottomPanel.py(bottomPanel.slopeX * bottomPanel.flareRadius, bottomPanel.sideRise - bottomPanel.slopeY * bottomPanel.flareRadius)
        }
        PathLine {
            x: bottomPanel.px(bottomPanel.upperLeft - bottomPanel.slopeX * bottomPanel.upperCornerRadius, bottomPanel.slopeY * bottomPanel.upperCornerRadius)
            y: bottomPanel.py(bottomPanel.upperLeft - bottomPanel.slopeX * bottomPanel.upperCornerRadius, bottomPanel.slopeY * bottomPanel.upperCornerRadius)
        }
        PathQuad {
            controlX: bottomPanel.px(bottomPanel.upperLeft, 0); controlY: bottomPanel.py(bottomPanel.upperLeft, 0)
            x: bottomPanel.px(bottomPanel.upperLeft + bottomPanel.upperCornerRadius, 0)
            y: bottomPanel.py(bottomPanel.upperLeft + bottomPanel.upperCornerRadius, 0)
        }
    }
    // A vertical tangent leaves the rail; two smooth cubics finish flat against the bottom edge.
    ShapePath {
        fillColor: bottomPanel.vertical ? Theme.surface : "transparent"
        strokeColor: "transparent"
        startX: bottomPanel.width
        startY: 0
        PathLine { x: bottomPanel.curve.top.x; y: bottomPanel.curve.top.y }
        PathQuad {
            controlX: bottomPanel.curve.start.x; controlY: 0
            x: bottomPanel.curve.topEnd.x; y: bottomPanel.curve.topEnd.y
        }
        PathLine { x: bottomPanel.curve.start.x; y: bottomPanel.curve.start.y }
        PathCubic {
            control1X: bottomPanel.curve.incoming1.x; control1Y: bottomPanel.curve.incoming1.y
            control2X: bottomPanel.curve.incoming2.x; control2Y: bottomPanel.curve.incoming2.y
            x: bottomPanel.curve.selected.x; y: bottomPanel.curve.selected.y
        }
        PathCubic {
            control1X: bottomPanel.curve.outgoing1.x; control1Y: bottomPanel.curve.outgoing1.y
            control2X: bottomPanel.curve.outgoing2.x; control2Y: bottomPanel.curve.outgoing2.y
            x: bottomPanel.curve.floor.x; y: bottomPanel.curve.floor.y
        }
        PathLine { x: bottomPanel.width; y: bottomPanel.height }
        PathLine { x: bottomPanel.width; y: 0 }
    }
}
