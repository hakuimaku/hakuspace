import QtQuick
import QtQuick.Shapes
import "../../services"

Item {
    id: root

    required property real controlDiameter
    required property real bodyWidth
    property real bodyHeight: contentHeight
    property real rf: Math.max(Theme.hugRadius, AppState.roundedScreenRadius)
    property real frameThickness: FlareEdges.thickness
    property real topFlareY: 16
    property real earWidth: Math.max(32, Math.round(rf * 1.5))
    property real earRadius: Math.max(32, Math.round(rf * 1.5))
    property real cornerRadius: Theme.largeRadius + 8
    property color surfaceColor: Theme.surface
    property bool expanded: false
    property bool quickNoteActive: false

    readonly property real itemDiameter: root.controlDiameter
    readonly property real itemSpacing: Math.max(10, Math.round(Theme.fontSize * 0.85))
    readonly property real listTopPadding: Math.max(16, Math.round(root.controlDiameter * 0.40))
    readonly property real listBottomPadding: Math.max(16, Math.round(root.controlDiameter * 0.40))

    property var tools: [
        {
            key: "tempNote",
            icon: "󰏫",
            label: "Temp Note"
        }
    ]

    readonly property real contentHeight: Math.max(300,
        listTopPadding
        + tools.length * itemDiameter
        + Math.max(0, tools.length - 1) * itemSpacing
        + listBottomPadding)

    signal pointerMoved(real x, real y)
    signal toggleQuickNoteRequested()

    // Morph animation:
    property real morphProgress: 0.0

    onExpandedChanged: {
        morphAnim.stop()
        if (expanded) {
            morphAnim.to = 1.0
            morphAnim.duration = HAnimation.sidebarOpenDuration
            morphAnim.easing.bezierCurve = HAnimation.sidebarOpenCurve
            morphAnim.start()
        } else {
            morphAnim.to = 0.0
            morphAnim.duration = HAnimation.sidebarCloseDuration
            morphAnim.easing.bezierCurve = HAnimation.sidebarCloseCurve
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

    // Clip wrapper so background body smoothly expands with morph progress
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

    // Controls group (model-driven tools list)
    Item {
        id: controlsGroup
        x: 0
        y: 20
        width: root.bodyWidth
        height: root.bodyHeight
        opacity: Math.max(0, Math.min(1, (root.morphProgress - 0.15) / 0.70))
        transform: Translate {
            y: -24 * (1.0 - root.morphProgress)
        }
        visible: opacity > 0.001

        readonly property real controlX: Math.round((root.bodyWidth - root.controlDiameter) / 2)

        Repeater {
            model: root.tools

            delegate: Item {
                id: toolDelegate
                required property int index
                required property var modelData

                readonly property bool isTempNote: modelData.key === "tempNote"
                readonly property bool isActive: isTempNote && root.quickNoteActive
                readonly property bool isHovered: toolMouseArea.containsMouse
                readonly property bool isPressed: toolMouseArea.pressed

                x: controlsGroup.controlX
                y: root.listTopPadding + index * (root.itemDiameter + root.itemSpacing)
                width: root.itemDiameter
                height: root.itemDiameter
                z: 20

                Rectangle {
                    id: toolButton
                    anchors.fill: parent
                    radius: width / 2
                    color: toolDelegate.isPressed
                           ? Qt.darker(Theme.accent, 1.10)
                           : (toolDelegate.isHovered ? Qt.lighter(Theme.accent, 1.25) : Theme.accent)
                    border.width: 2
                    border.color: toolDelegate.isActive
                                  ? Qt.lighter(Theme.accent, 1.50)
                                  : (toolDelegate.isHovered ? Qt.lighter(Theme.accent, 1.40) : Qt.darker(Theme.accent, 1.08))
                    scale: toolDelegate.isPressed ? 0.94 : (toolDelegate.isHovered ? 1.12 : 1.0)

                    Behavior on color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }
                    Behavior on border.color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: toolDelegate.isPressed ? HAnimation.buttonPressDuration : HAnimation.buttonHoverDuration
                            easing.bezierCurve: toolDelegate.isPressed ? HAnimation.buttonPressCurve : HAnimation.buttonHoverCurve
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: Theme.onAccentColor
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: Math.max(20, Math.round(parent.width * (toolDelegate.isHovered ? 0.52 : 0.48)))
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on font.pixelSize {
                            NumberAnimation {
                                duration: toolDelegate.isPressed ? HAnimation.buttonPressDuration : HAnimation.buttonHoverDuration
                                easing.bezierCurve: toolDelegate.isPressed ? HAnimation.buttonPressCurve : HAnimation.buttonHoverCurve
                            }
                        }
                    }

                    MouseArea {
                        id: toolMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            if (toolDelegate.isTempNote) {
                                root.toggleQuickNoteRequested()
                            }
                        }
                        onPositionChanged: mouse => {
                            root.pointerMoved(controlsGroup.x + toolDelegate.x + mouse.x,
                                              controlsGroup.y + toolDelegate.y + mouse.y)
                        }
                    }
                }

                // Local tooltip on hover (shown when item is not active/open)
                Rectangle {
                    id: toolTooltip
                    visible: toolDelegate.isHovered && !toolDelegate.isActive && opacity > 0.01
                    opacity: (toolDelegate.isHovered && !toolDelegate.isActive) ? 1.0 : 0.0
                    anchors.left: parent.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: tooltipLabel.implicitWidth + 14
                    height: tooltipLabel.implicitHeight + 8
                    radius: Theme.radius
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.lighter(Theme.hoverMuted, 1.45)
                    z: 100

                    Behavior on opacity {
                        NumberAnimation {
                            duration: HAnimation.slow
                            easing.bezierCurve: HAnimation.tooltipCurve
                        }
                    }

                    Text {
                        id: tooltipLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Theme.fontSize - 3)
                        font.weight: Font.Medium
                        color: Theme.fg
                    }
                }
            }
        }
    }

    // Background hit-test tracking for Sidebar pointer ownership (NoButton so it never blocks clicks)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.pointerMoved(mouseX, mouseY)
        onPositionChanged: mouse => root.pointerMoved(mouse.x, mouse.y)
    }
}
