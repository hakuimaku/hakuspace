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
    property real r: 24
    property real rf: Theme.tipHugRadius
    property real bottomRadius: r
    property color surfaceColor: Theme.barColor
    // Cover the antialiased join at fractional body coordinates without moving the outer curve.
    readonly property real seamOverlap: 2

    // Morph the top ears geometrically from a flat edge into their final arcs.
    // Do not fade/gate the ears: that leaves a short body-only interval.
    // Do not scale a completed ear shape either: near zero that collapses into
    // the detached sharp tips visible during opening.
    property real earMorphHeightFactor: 1.5
    readonly property real earMorphProgress: {
        if (r <= 0) return 1;
        var span = Math.max(1, r * earMorphHeightFactor);
        var t = Math.max(0, Math.min(1, currentHeight / span));
        return t * t * (3 - 2 * t); // smoothstep
    }
    readonly property real earStartRadius: r * factors.kS * earMorphProgress
    readonly property real earEndRadius: r * factors.kE * earMorphProgress

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
        bottomLeftRadius: root.bottomRadius * root.factors.kS
        bottomRightRadius: root.bottomRadius * root.factors.kE
        clip: true
    }

    Shape {
        id: leftEar
        readonly property real er: root.earStartRadius
        x: root.start - er
        y: 0
        width: er + root.seamOverlap
        height: er
        preferredRendererType: Shape.CurveRenderer
        visible: er > 0.01
        ShapePath {
            fillColor: root.surfaceColor
            strokeColor: "transparent"
            PathSvg {
                path: "M 0 0 L " + (leftEar.er + root.seamOverlap) + " 0 "
                      + "L " + (leftEar.er + root.seamOverlap) + " " + leftEar.er + " "
                      + "L " + leftEar.er + " " + leftEar.er + " "
                      + "A " + leftEar.er + " " + leftEar.er + " 0 0 0 0 0 Z"
            }
        }
    }

    Shape {
        id: rightEar
        readonly property real er: root.earEndRadius
        x: root.end - root.seamOverlap
        y: 0
        width: er + root.seamOverlap
        height: er
        preferredRendererType: Shape.CurveRenderer
        visible: er > 0.01
        ShapePath {
            fillColor: root.surfaceColor
            strokeColor: "transparent"
            PathSvg {
                path: "M 0 0 L " + (rightEar.er + root.seamOverlap) + " 0 "
                      + "A " + rightEar.er + " " + rightEar.er + " 0 0 0 "
                      + root.seamOverlap + " " + rightEar.er + " "
                      + "L 0 " + rightEar.er + " Z"
            }
        }
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
