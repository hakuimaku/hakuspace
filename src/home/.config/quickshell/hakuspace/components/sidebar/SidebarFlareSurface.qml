import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property bool horizontal: false
    required property real bodyWidth
    property real bodyHeight: 50
    required property real currentHeight
    required property real morphProgress
    required property real rf
    required property real sideInset
    required property real topFlareY
    required property real earWidth
    required property real earRadius
    required property real cornerRadius
    required property color surfaceColor

    // --- Vertical Sidebar (Topbar mode) ---
    Item {
        id: bodyClipper
        visible: !root.horizontal
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

        // 2. Flare foot at bottom connecting smoothly into RoundedScreen border (indented by sideInset)
        Rectangle {
            id: flareFootBacking
            x: 0
            y: flareFoot.y
            width: root.sideInset
            height: root.rf
            color: root.surfaceColor
            visible: flareFoot.visible
            opacity: flareFoot.opacity
        }

        Shape {
            id: flareFoot
            x: root.sideInset
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

    // --- Horizontal Sidebar (Leftbar mode) ---
    Item {
        id: horizontalBodyClipper
        visible: root.horizontal
        x: -24
        y: 0
        width: root.currentHeight + root.rf + 28
        height: root.bodyHeight + root.earWidth + 24
        clip: true

        // Left extension behind circular shell to guarantee zero hairline gap
        Rectangle {
            id: leftExtension
            x: 0
            y: 0
            width: 26 + root.topFlareY
            height: root.bodyHeight
            color: root.surfaceColor
        }

        // 1. Horizontal lobe body attached flush to the top edge
        Rectangle {
            id: hBody
            x: 24
            y: 0
            width: root.currentHeight
            height: root.bodyHeight
            color: root.surfaceColor
            bottomRightRadius: root.cornerRadius
            bottomLeftRadius: 0
            topRightRadius: 0
            topLeftRadius: 0
        }

        // 2. Flare foot / ear at far right end connecting smoothly into screen top border
        Rectangle {
            id: hFlareBacking
            x: hFlareTop.x
            y: 0
            width: root.rf
            height: root.sideInset
            color: root.surfaceColor
            visible: hFlareTop.visible
            opacity: hFlareTop.opacity
        }

        Shape {
            id: hFlareTop
            x: Math.max(24, 24 + root.currentHeight - 1)
            y: 0
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

        // 3. Flare ear at bottom left wrapping smoothly from circular shell into horizontal rail
        Shape {
            id: navFlareEar
            x: 24 + root.topFlareY - 1
            y: root.bodyHeight - 1
            width: root.earRadius + 1
            height: root.earWidth + 1
            preferredRendererType: Shape.CurveRenderer
            visible: root.morphProgress > 0.05
            opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.05) / 0.65))

            ShapePath {
                fillColor: root.surfaceColor
                strokeColor: "transparent"
                PathSvg {
                    path: "M 0 0 L " + (root.earRadius + 1) + " 0 A " + (root.earRadius + 1) + " " + (root.earWidth + 1) + " 0 0 0 0 " + (root.earWidth + 1) + " Z"
                }
            }
        }
    }
}
