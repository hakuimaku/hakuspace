import QtQuick
import QtQuick.Shapes

Item {
    id: root
    required property real bodyWidth
    required property real currentHeight
    required property real morphProgress
    required property real rf
    required property real frameThickness
    required property real topFlareY
    required property real earWidth
    required property real earRadius
    required property real cornerRadius
    required property color surfaceColor

    Item {
        id: bodyClipper
        x: 0
        y: -20
        width: root.bodyWidth + root.earWidth + 4
        height: root.currentHeight + root.rf + 20
        clip: true

        // Top extension behind circular shell to guarantee zero hairline gap
        Rectangle {
            id: topExtension
            x: 0
            y: 0
            width: root.bodyWidth
            height: 22
            color: root.surfaceColor
        }

        // 1. Vertical lobe body attached flush to the left edge
        Rectangle {
            id: body
            x: 0
            y: 20
            width: root.bodyWidth
            height: root.currentHeight
            color: root.surfaceColor
            bottomRightRadius: root.cornerRadius
            bottomLeftRadius: 0
            topRightRadius: 0
            topLeftRadius: 0
        }

        // 2. Flare foot at bottom connecting smoothly into RoundedScreen border (indented by frameThickness)
        Rectangle {
            id: flareFootBacking
            x: 0
            y: flareFoot.y
            width: root.frameThickness
            height: root.rf
            color: root.surfaceColor
            visible: flareFoot.visible
            opacity: flareFoot.opacity
        }

        Shape {
            id: flareFoot
            x: root.frameThickness
            y: Math.max(20, 20 + root.currentHeight - 1)
            width: root.rf
            height: root.rf
            preferredRendererType: Shape.CurveRenderer
            visible: root.rf > 0 && root.morphProgress > 0.10
            opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.10) / 0.90))

            ShapePath {
                fillColor: root.surfaceColor
                strokeColor: "transparent"
                PathSvg {
                    path: "M 0 0 L " + root.rf + " 0 A " + root.rf + " " + root.rf + " 0 0 0 0 " + root.rf + " Z"
                }
            }
        }

        // 3. Flare ear at top right wrapping smoothly into navigation layer
        Shape {
            id: topRightEar
            x: root.bodyWidth - 1
            y: 20 + root.topFlareY - 1
            width: root.earWidth + 1
            height: root.earRadius + 1
            preferredRendererType: Shape.CurveRenderer
            visible: root.morphProgress > 0.05
            opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.05) / 0.65))

            ShapePath {
                fillColor: root.surfaceColor
                strokeColor: "transparent"
                PathSvg {
                    path: "M 0 0 L " + (root.earWidth + 1) + " 0 A " + (root.earWidth + 1) + " " + (root.earRadius + 1) + " 0 0 0 0 " + (root.earRadius + 1) + " Z"
                }
            }
        }
    }

}
