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

    // Canonical 45x45 Dashboard shell dimensions
    readonly property real dashboardWidth: Math.round(screenWidth * 0.45)
    readonly property real dashboardHeight: Math.round(screenHeight * 0.45)

    // Avatar geometry: exactly matches Navigation origin and diameter
    readonly property real avatarX: controllerX
    readonly property real avatarY: controllerY
    readonly property real avatarDiameter: circleDiameter

    // Content area geometry (to the right of Avatar)
    readonly property real contentX: Math.round(avatarX + avatarDiameter + cardGap * 1.5)
    readonly property real rightPadding: Math.max(12, Math.round(Theme.pad * 1.2))
    readonly property real bottomPadding: Math.max(12, Math.round(Theme.pad * 1.2))

    readonly property real usableContentWidth: Math.max(100, dashboardWidth - contentX - rightPadding)
    readonly property real usableColWidth: Math.max(100, usableContentWidth - cardGap)
    readonly property real col1Width: Math.round(usableColWidth * 0.46)
    readonly property real col2Width: usableColWidth - col1Width

    readonly property real topClusterX: contentX
    readonly property real topClusterY: controllerY
    readonly property real row1Height: Math.round(dashboardHeight * 0.22)
    readonly property real row2Y: topClusterY + row1Height + cardGap
    readonly property real row2Height: Math.max(100, dashboardHeight - row2Y - bottomPadding)

    // Legacy helper aliases
    readonly property real topClusterWidth: col1Width + cardGap + col2Width
    readonly property real topClusterHeight: row1Height + cardGap + row2Height
    readonly property real topClusterRight: topClusterX + topClusterWidth
    readonly property real topClusterBottom: row2Y + row2Height

    // Input mask bounds exposed for NavigationPanel overlay mask union
    readonly property real maskClusterWidth: dashboardWidth
    readonly property real maskClusterHeight: dashboardHeight
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
    // Compact 45x45 shell enclosing Avatar and cards; workarea remains transparent.
    Rectangle {
        id: outerShell
        x: 0
        y: 0
        width: root.dashboardWidth
        height: root.dashboardHeight
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

    Image {
        id: decodeProbe
        visible: false
        asynchronous: false
        property string pendingLocalPath: ""

        onStatusChanged: {
            if (pendingLocalPath.length === 0) return
            if (status === Image.Ready) {
                var validPath = pendingLocalPath
                pendingLocalPath = ""
                source = ""
                Avatar.setAvatar(validPath)
                root.focusRequested()
            } else if (status === Image.Error) {
                pendingLocalPath = ""
                source = ""
                Avatar.reportDecodeError("Selected image cannot be decoded by Qt runtime")
                root.focusRequested()
            }
        }
    }

    FileDialog {
        id: avatarChooser
        title: "Select Avatar"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp)", "All files (*)"]

        onAccepted: {
            var localPath = new URL(selectedFile).pathname
            decodeProbe.pendingLocalPath = localPath
            decodeProbe.source = ""
            decodeProbe.source = selectedFile
        }

        onRejected: {
            root.focusRequested()
        }
    }

    // 3. Cards
    // Row 1: Clock | MPRIS
    DashboardClockCard {
        id: clockCard
        x: root.contentX
        y: root.topClusterY
        width: root.col1Width
        height: root.row1Height
        z: 5
    }

    DashboardMediaCard {
        id: mediaCard
        x: root.contentX + root.col1Width + root.cardGap
        y: root.topClusterY
        width: root.col2Width
        height: root.row1Height
        z: 5
    }

    // Row 2: Dynamic Widget Host | Monitor
    DashboardWidgetHost {
        id: widgetHost
        x: root.contentX
        y: root.row2Y
        width: root.col1Width
        height: root.row2Height
        z: 5
    }

    Rectangle {
        id: monitorCardPlaceholder
        x: root.contentX + root.col1Width + root.cardGap
        y: root.row2Y
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
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                font.family: Theme.fontFamily
                font.pixelSize: 28
                color: Theme.fgDim
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Monitor"
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
