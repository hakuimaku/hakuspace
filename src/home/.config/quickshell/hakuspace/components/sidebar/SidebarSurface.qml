import QtQuick
import QtQuick.Shapes
import "../../services"

Item {
    id: root

    required property real controlDiameter
    required property real bodyWidth
    required property real bodyHeight
    property real rf: Math.max(Theme.tipHugRadius, AppState.roundedScreenRadius)
    property real frameThickness: FlareEdges.thickness
    property real topFlareY: 16
    property real earWidth: Math.max(32, Math.round(rf * 1.5))
    property real earRadius: Math.max(32, Math.round(rf * 1.5))
    property real cornerRadius: Theme.radius + 8
    property color surfaceColor: Theme.barColor
    property bool expanded: false

    signal pointerMoved(real x, real y)

    // Morph animation:
    property real morphProgress: 0.0

    onExpandedChanged: {
        morphAnim.stop()
        if (expanded) {
            morphAnim.to = 1.0
            morphAnim.duration = HAnimation.normal
            morphAnim.easing.bezierCurve = HAnimation.shellCurve
            morphAnim.start()
        } else {
            morphAnim.to = 0.0
            morphAnim.duration = Math.max(HAnimation.fast, 160)
            morphAnim.easing.type = Easing.InCubic
            morphAnim.start()
        }
    }

    NumberAnimation {
        id: morphAnim
        target: root
        property: "morphProgress"
    }

    // Height of the lobe grows dynamically with morphProgress:
    readonly property real currentHeight: bodyHeight * morphProgress

    visible: morphProgress > 0.001 || expanded

    // Clip wrapper so controls smoothly slide / reveal as the body expands
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

        // 4. Controls (Options: 2 circular dots + 1 circular plus button)
        Item {
            id: controlsGroup
            x: 0
            y: 20
            width: root.bodyWidth
            height: root.bodyHeight
            opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.20) / 0.80))
            transform: Translate {
                y: -20 * (1.0 - root.morphProgress)
            }

            readonly property real controlX: Math.round((root.bodyWidth - root.controlDiameter) / 2)
            readonly property real spacing: Math.max(14, Math.round(Theme.fontSize * 1.1))
            readonly property real topOffset: Math.max(20, Math.round(root.bodyHeight * 0.10))

            // Option Dot 1
            Rectangle {
                id: optionDot1
                x: controlsGroup.controlX
                y: controlsGroup.topOffset
                width: root.controlDiameter
                height: root.controlDiameter
                radius: width / 2
                color: Theme.surface
                border.width: 2
                border.color: Qt.lighter(Theme.hoverMuted, 1.75)

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(6, Math.round(parent.width * 0.22))
                    height: width
                    radius: width / 2
                    color: Qt.lighter(Theme.hoverMuted, 1.85)
                }
            }

            // Option Dot 2
            Rectangle {
                id: optionDot2
                x: controlsGroup.controlX
                y: optionDot1.y + root.controlDiameter + controlsGroup.spacing
                width: root.controlDiameter
                height: root.controlDiameter
                radius: width / 2
                color: Theme.surface
                border.width: 2
                border.color: Qt.lighter(Theme.hoverMuted, 1.75)

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(6, Math.round(parent.width * 0.22))
                    height: width
                    radius: width / 2
                    color: Qt.lighter(Theme.hoverMuted, 1.85)
                }
            }

            // Option Plus Control (+)
            Rectangle {
                id: optionPlus
                x: controlsGroup.controlX
                y: optionDot2.y + root.controlDiameter + controlsGroup.spacing
                width: root.controlDiameter
                height: root.controlDiameter
                radius: width / 2
                color: Theme.surface
                border.width: 2
                border.color: Qt.lighter(Theme.hoverMuted, 1.75)

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: Math.max(16, Math.round(parent.width * 0.52))
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // Hit test area for Sidebar pointer ownership
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onEntered: root.pointerMoved(mouseX, mouseY)
        onPositionChanged: mouse => root.pointerMoved(mouse.x, mouse.y)
    }
}
