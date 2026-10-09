import QtQuick
import QtQuick.Shapes
import "../../services"
import "FlareGeometry.js" as FG

Item {
    id: root
    property real start: 0
    property real end: 0
    property real currentHeight: 0
    property var bounds: ({start: 0, end: 1920})
    property real r: 20
    property real rf: Theme.tipHugRadius
    property color surfaceColor: Theme.barColor

    default property alias content: body.data
    
    property var factors: FG.hugFactors(start, end, {bounds: bounds, rf: rf})
    property var p: FG.pieces({start: start, end: end, height: currentHeight, kS: factors.kS, kE: factors.kE}, {r: r, rf: rf})

    Rectangle {
        id: body
        x: root.start
        y: 0
        width: Math.max(0, root.end - root.start)
        height: root.currentHeight
        color: root.surfaceColor
        bottomLeftRadius: p.radiusStart
        bottomRightRadius: p.radiusEnd
        clip: true
    }

    Shape {
        x: p.earStart.u; y: p.earStart.v
        width: r; height: r
        preferredRendererType: Shape.CurveRenderer
        transformOrigin: Item.TopRight
        scale: p.earStart.scale
        visible: scale > 0
        ShapePath { fillColor: root.surfaceColor; strokeColor: "transparent"; PathSvg { path: "M 0 0 L " + r + " 0 L " + r + " " + r + " A " + r + " " + r + " 0 0 0 0 0 Z" } }
    }

    Shape {
        x: p.earEnd.u; y: p.earEnd.v
        width: r; height: r
        preferredRendererType: Shape.CurveRenderer
        transformOrigin: Item.TopLeft
        scale: p.earEnd.scale
        visible: scale > 0
        ShapePath { fillColor: root.surfaceColor; strokeColor: "transparent"; PathSvg { path: "M 0 0 L " + r + " 0 A " + r + " " + r + " 0 0 0 0 " + r + " Z" } }
    }

    Shape {
        x: p.footStart.u; y: p.footStart.v
        width: rf; height: rf
        preferredRendererType: Shape.CurveRenderer
        transformOrigin: Item.TopLeft
        scale: p.footStart.scale
        visible: scale > 0
        ShapePath { fillColor: root.surfaceColor; strokeColor: "transparent"; PathSvg { path: "M 0 0 L " + rf + " 0 A " + rf + " " + rf + " 0 0 0 0 " + rf + " Z" } }
    }

    Shape {
        x: p.footEnd.u; y: p.footEnd.v
        width: rf; height: rf
        preferredRendererType: Shape.CurveRenderer
        transformOrigin: Item.TopRight
        scale: p.footEnd.scale
        visible: scale > 0
        ShapePath { fillColor: root.surfaceColor; strokeColor: "transparent"; PathSvg { path: "M 0 0 L " + rf + " 0 L " + rf + " " + rf + " A " + rf + " " + rf + " 0 0 0 0 0 Z" } }
    }
}
