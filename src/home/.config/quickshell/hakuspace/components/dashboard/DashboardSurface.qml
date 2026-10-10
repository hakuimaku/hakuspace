import QtQuick
import QtQuick.Shapes
import QtQuick.Dialogs
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
    signal focusRequested()

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
    readonly property real maskLowerBodyY: 0
    readonly property real maskLowerBodyWidth: 0
    readonly property real maskLowerBodyHeight: 0
    readonly property real maskShoulderX: 0
    readonly property real maskShoulderY: 0
    readonly property real maskShoulderWidth: 0
    readonly property real maskShoulderHeight: 0

    opacity: expanded ? 1.0 : 0.0
    visible: opacity > 0.001

    Behavior on opacity {
        NumberAnimation {
            duration: HAnimation.fast
            easing.type: Easing.OutCubic
        }
    }

    // 1. Dashboard Surface Body
    // Solid background enclosing the Avatar and top cluster cards; the workarea remains transparent.
    Rectangle {
        id: outerShell
        x: 0
        y: 0
        width: Math.ceil(root.shoulderX)
        height: Math.ceil(root.lowerBodyTopY)
        bottomRightRadius: root.cornerRadius
        bottomLeftRadius: root.cornerRadius
        topRightRadius: root.cornerRadius
        topLeftRadius: 0
        color: Theme.barColor
        border.width: 1
        border.color: Qt.lighter(Theme.hoverMuted, 1.25)
        z: 1
    }

    // 2. Avatar Placeholder (fixed at Navigation origin)
    // 2. Avatar Component (fixed at Navigation origin)
    DashboardAvatar {
        id: dashboardAvatar
        x: root.avatarX
        y: root.avatarY
        diameter: root.avatarDiameter
        z: 10

        onRequestBack: {
            root.requestReturnToNavigation()
        }

        onRequestChangeAvatar: {
            avatarChooser.open()
        }
    }

    FileDialog {
        id: avatarChooser
        title: "Select Avatar"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp)", "All files (*)"]

        onAccepted: {
            var localPath = new URL(selectedFile).pathname
            Avatar.setAvatar(localPath)
            root.focusRequested()
        }

        onRejected: {
            root.focusRequested()
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
