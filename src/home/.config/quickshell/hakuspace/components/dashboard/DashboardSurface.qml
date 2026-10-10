import QtQuick
import QtQuick.Shapes
import "../../services"

Item {
    id: root

    required property real screenWidth
    required property real screenHeight
    width: screenWidth
    height: screenHeight
    required property real controllerX
    required property real controllerY
    required property real circleRadius
    required property real circleDiameter
    property real frameThickness: FlareEdges.thickness
    property real frameTop: FlareEdges.topOriginY
    property bool expanded: false

    signal requestReturnToNavigation()

    readonly property real cardGap: Math.max(10, Math.round(Theme.gap * 2.5))
    readonly property real cornerRadius: Theme.radius
    readonly property real innerCornerRadius: Theme.tipHugRadius

    // Avatar geometry: exactly matches Navigation origin and diameter
    readonly property real avatarX: controllerX
    readonly property real avatarY: controllerY
    readonly property real avatarDiameter: circleDiameter

    // Top cluster geometry (to the right of Avatar)
    readonly property real topClusterX: controllerX + circleDiameter + cardGap * 1.5
    readonly property real topClusterY: controllerY
    readonly property real col1Width: Math.max(240, Math.round(screenWidth * 0.135))
    readonly property real col2Width: Math.max(280, Math.round(screenWidth * 0.155))
    readonly property real row1Height: Math.max(90, Math.round(screenHeight * 0.095))
    readonly property real row2Height: Math.max(180, Math.round(screenHeight * 0.20))

    readonly property real topClusterWidth: col1Width + cardGap + col2Width
    readonly property real topClusterHeight: row1Height + cardGap + row2Height
    readonly property real topClusterRight: topClusterX + topClusterWidth
    readonly property real topClusterBottom: topClusterY + topClusterHeight

    // Outer shell geometry: stepped mockup silhouette
    readonly property real leftX: frameThickness
    readonly property real rightX: screenWidth - frameThickness - 8
    readonly property real bottomY: screenHeight - frameThickness - 8
    readonly property real lowerBodyTopY: Math.round(topClusterBottom + cardGap * 2.5)
    readonly property real shoulderX: Math.round(topClusterRight + cardGap * 2)
    readonly property real shoulderTopY: topClusterY

    // Input mask bounds exposed for NavigationPanel overlay mask union
    readonly property real maskClusterWidth: Math.ceil(shoulderX)
    readonly property real maskClusterHeight: Math.ceil(lowerBodyTopY)
    readonly property real maskLowerBodyY: Math.floor(lowerBodyTopY)
    readonly property real maskLowerBodyWidth: Math.ceil(rightX)
    readonly property real maskLowerBodyHeight: Math.ceil(bottomY - lowerBodyTopY)
    readonly property real maskShoulderX: Math.floor(shoulderX)
    readonly property real maskShoulderY: Math.floor(shoulderTopY)
    readonly property real maskShoulderWidth: Math.ceil(rightX - shoulderX)
    readonly property real maskShoulderHeight: Math.ceil(lowerBodyTopY - shoulderTopY)

    opacity: expanded ? 1.0 : 0.0
    visible: opacity > 0.001

    Behavior on opacity {
        NumberAnimation {
            duration: HAnimation.fast
            easing.type: Easing.OutCubic
        }
    }

    // 1. Mockup Outer Shell / Reserved Body
    // The large body and right shoulder remain intentionally empty per spec.
    Shape {
        id: outerShell
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        z: 1

        ShapePath {
            fillColor: Theme.barColor
            strokeColor: Qt.lighter(Theme.hoverMuted, 1.25)
            strokeWidth: 1

            PathSvg {
                path: "M " + (root.leftX + root.cornerRadius) + " " + root.lowerBodyTopY
                    + " L " + (root.shoulderX - root.innerCornerRadius) + " " + root.lowerBodyTopY
                    + " A " + root.innerCornerRadius + " " + root.innerCornerRadius + " 0 0 0 " + root.shoulderX + " " + (root.lowerBodyTopY - root.innerCornerRadius)
                    + " L " + root.shoulderX + " " + (root.shoulderTopY + root.cornerRadius)
                    + " A " + root.cornerRadius + " " + root.cornerRadius + " 0 0 1 " + (root.shoulderX + root.cornerRadius) + " " + root.shoulderTopY
                    + " L " + (root.rightX - root.cornerRadius) + " " + root.shoulderTopY
                    + " A " + root.cornerRadius + " " + root.cornerRadius + " 0 0 1 " + root.rightX + " " + (root.shoulderTopY + root.cornerRadius)
                    + " L " + root.rightX + " " + (root.bottomY - root.cornerRadius)
                    + " A " + root.cornerRadius + " " + root.cornerRadius + " 0 0 1 " + (root.rightX - root.cornerRadius) + " " + root.bottomY
                    + " L " + (root.leftX + root.cornerRadius) + " " + root.bottomY
                    + " A " + root.cornerRadius + " " + root.cornerRadius + " 0 0 1 " + root.leftX + " " + (root.bottomY - root.cornerRadius)
                    + " L " + root.leftX + " " + (root.lowerBodyTopY + root.cornerRadius)
                    + " A " + root.cornerRadius + " " + root.cornerRadius + " 0 0 1 " + (root.leftX + root.cornerRadius) + " " + root.lowerBodyTopY
                    + " Z"
            }
        }
    }

    // 2. Avatar Placeholder (fixed at Navigation origin)
    Rectangle {
        id: avatarContainer
        x: root.avatarX
        y: root.avatarY
        width: root.avatarDiameter
        height: root.avatarDiameter
        radius: width / 2
        color: Theme.surface
        border.width: 2
        border.color: avatarHover.hovered ? Theme.accent : Qt.lighter(Theme.hoverMuted, 1.45)
        clip: true
        z: 10

        Behavior on border.color { ColorAnimation { duration: HAnimation.fast } }

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰮯"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(30, Math.round(root.avatarDiameter * 0.26))
                font.weight: Font.Bold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Avatar"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: avatarHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    root.requestReturnToNavigation()
                }
            }
        }
    }

    // 3. Top Cluster Placeholder Cards
    // Row 1: Clock | MPRIS
    Rectangle {
        id: clockCardPlaceholder
        x: root.topClusterX
        y: root.topClusterY
        width: root.col1Width
        height: root.row1Height
        radius: root.cornerRadius
        color: Theme.surface
        border.width: 1
        border.color: Qt.lighter(Theme.hoverMuted, 1.25)
        clip: true
        z: 5

        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "  Clock"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(14, Theme.fontSize)
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "placeholder"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 3)
            }
        }
    }

    Rectangle {
        id: mprisCardPlaceholder
        x: root.topClusterX + root.col1Width + root.cardGap
        y: root.topClusterY
        width: root.col2Width
        height: root.row1Height
        radius: root.cornerRadius
        color: Theme.surface
        border.width: 1
        border.color: Qt.lighter(Theme.hoverMuted, 1.25)
        clip: true
        z: 5

        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "  Media / MPRIS"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(14, Theme.fontSize)
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "placeholder"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 3)
            }
        }
    }

    // Row 2: Calendar | Monitor
    Rectangle {
        id: calendarCardPlaceholder
        x: root.topClusterX
        y: root.topClusterY + root.row1Height + root.cardGap
        width: root.col1Width
        height: root.row2Height
        radius: root.cornerRadius
        color: Theme.surface
        border.width: 1
        border.color: Qt.lighter(Theme.hoverMuted, 1.25)
        clip: true
        z: 5

        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "  Calendar"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(14, Theme.fontSize)
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "placeholder"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 3)
            }
        }
    }

    Rectangle {
        id: monitorCardPlaceholder
        x: root.topClusterX + root.col1Width + root.cardGap
        y: root.topClusterY + root.row1Height + root.cardGap
        width: root.col2Width
        height: root.row2Height
        radius: root.cornerRadius
        color: Theme.surface
        border.width: 1
        border.color: Qt.lighter(Theme.hoverMuted, 1.25)
        clip: true
        z: 5

        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "  Monitor"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(14, Theme.fontSize)
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ROM · RAM · CPU · GPU"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 3)
            }
        }
    }
}
