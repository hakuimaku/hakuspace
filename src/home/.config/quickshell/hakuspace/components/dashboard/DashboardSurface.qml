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
    property real morphProgress: 0.0

    signal requestReturnToNavigation()
    signal focusRequested()

    readonly property bool isFullyOpen: morphProgress >= 0.999

    // 20 logical px Dashboard shell inset (updated per user request)
    readonly property real innerPadding: 20
    readonly property real cardGap: 10
    readonly property real cornerRadius: Theme.radius
    readonly property real flareRadius: Theme.tipRadius + 20

    // Canonical 45x45 Dashboard shell dimensions (at 1080p: 864 x 486)
    readonly property real dashboardWidth: Math.round(screenWidth * 0.45)
    readonly property real dashboardHeight: Math.round(screenHeight * 0.45)

    // Morph geometry interpolation:
    // Start envelope corresponds to the compact Navigation controller origin
    readonly property real startEnvelopeWidth: Math.round(controllerX + circleDiameter + innerPadding)
    readonly property real startEnvelopeHeight: Math.round(controllerY + circleDiameter + innerPadding)
    readonly property real currentEnvelopeWidth: startEnvelopeWidth + (dashboardWidth - startEnvelopeWidth) * morphProgress
    readonly property real currentEnvelopeHeight: startEnvelopeHeight + (dashboardHeight - startEnvelopeHeight) * morphProgress

    // Flare body bounds (ends before flare ear so final envelope stays <= 45% x 45%)
    property real bottomFlareReach: Theme.tipHugRadius
    readonly property real finalBodyEnd: Math.max(0, dashboardWidth - flareRadius)
    readonly property real currentBodyEnd: Math.max(0, currentEnvelopeWidth - flareRadius)
    readonly property real currentBodyWidth: currentBodyEnd

    readonly property real finalBodyBottom: Math.max(0, dashboardHeight - bottomFlareReach)
    readonly property real startBodyBottom: Math.max(0, startEnvelopeHeight - bottomFlareReach)
    readonly property real usableBodyBottom: startBodyBottom + (finalBodyBottom - startBodyBottom) * morphProgress
    readonly property real currentBodyHeight: usableBodyBottom

    // Avatar geometry:
    // Glides smoothly from controller origin to (10, 10)
    readonly property real finalAvatarX: innerPadding
    readonly property real finalAvatarY: innerPadding
    readonly property real avatarX: controllerX + (finalAvatarX - controllerX) * morphProgress
    readonly property real avatarY: controllerY + (finalAvatarY - controllerY) * morphProgress
    readonly property real avatarDiameter: circleDiameter
    readonly property real avatarOpacity: Math.min(1.0, morphProgress / 0.25)

    // Content area geometry (to the right of final Avatar)
    readonly property real avatarRight: innerPadding + avatarDiameter
    readonly property real contentX: avatarRight + cardGap
    readonly property real rightPadding: innerPadding
    readonly property real bottomPadding: innerPadding

    // Usable card layout columns
    readonly property real usableContentWidth: Math.max(100, finalBodyEnd - contentX - rightPadding)
    readonly property real usableColWidth: Math.max(100, usableContentWidth - cardGap)
    readonly property real col1Width: Math.round(usableColWidth * 0.46)
    readonly property real col2Width: usableColWidth - col1Width

    // Usable card layout rows
    readonly property real topClusterX: contentX
    readonly property real topClusterY: innerPadding
    readonly property real row1Height: Math.round(dashboardHeight * 0.22)
    readonly property real row2Y: topClusterY + row1Height + cardGap
    readonly property real row2Height: Math.max(100, finalBodyBottom - row2Y - bottomPadding)

    // Legacy helper aliases
    readonly property real topClusterWidth: col1Width + cardGap + col2Width
    readonly property real topClusterHeight: row1Height + cardGap + row2Height
    readonly property real topClusterRight: topClusterX + topClusterWidth
    readonly property real topClusterBottom: row2Y + row2Height

    // Content reveal progress: cards fade in and translate 8px after shell begins opening
    readonly property real contentRevealProgress: {
        if (morphProgress <= 0.35) return 0.0
        if (morphProgress >= 0.70) return 1.0
        return (morphProgress - 0.35) / (0.70 - 0.35)
    }

    // Input mask bounds exposed for NavigationPanel overlay mask union
    readonly property real maskBodyWidth: currentBodyWidth
    readonly property real maskBodyHeight: usableBodyBottom
    readonly property real maskEarX: currentBodyEnd
    readonly property real maskEarWidth: flareShell.earRadius
    readonly property real maskEarHeight: frameTop + flareShell.earRadius
    readonly property real maskFootY: usableBodyBottom
    readonly property real maskFootWidth: bottomFlareReach + frameThickness
    readonly property real maskFootHeight: bottomFlareReach

    // Legacy mask aliases for backwards compatibility
    readonly property real maskClusterWidth: maskBodyWidth
    readonly property real maskClusterHeight: maskBodyHeight
    readonly property real maskLowerBodyY: 0
    readonly property real maskLowerBodyWidth: 0
    readonly property real maskLowerBodyHeight: 0
    readonly property real maskShoulderX: 0
    readonly property real maskShoulderY: 0
    readonly property real maskShoulderWidth: 0
    readonly property real maskShoulderHeight: 0

    visible: morphProgress > 0.001 || expanded

    // 1. Dashboard Flare Surface (HakuSpace Flare visual language)
    DashboardFlareSurface {
        id: flareShell
        bodyWidth: root.currentEnvelopeWidth
        bodyHeight: root.currentEnvelopeHeight
        frameThickness: root.frameThickness
        frameTop: root.frameTop
        bottomFlareReach: root.bottomFlareReach
        flareRadius: root.flareRadius
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        surfaceColor: Theme.barColor
        cornerRadius: root.cornerRadius + 8
        z: 1
    }

    // 2. Avatar Component
    DashboardAvatar {
        id: dashboardAvatar
        x: root.avatarX
        y: root.avatarY
        diameter: root.avatarDiameter
        interactive: root.isFullyOpen
        opacity: root.avatarOpacity
        visible: opacity > 0.001
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

    // 3. Cards container (reveals gently as shell expands)
    Item {
        id: cardsContainer
        anchors.fill: parent
        opacity: root.contentRevealProgress
        visible: opacity > 0.001
        enabled: root.isFullyOpen
        transform: Translate {
            x: Math.round(-8 * (1.0 - root.contentRevealProgress))
            y: Math.round(-8 * (1.0 - root.contentRevealProgress))
        }
        z: 5

        // Row 1: Clock | MPRIS
        DashboardClockCard {
            id: clockCard
            x: root.contentX
            y: root.topClusterY
            width: root.col1Width
            height: root.row1Height
        }

        DashboardMediaCard {
            id: mediaCard
            x: root.contentX + root.col1Width + root.cardGap
            y: root.topClusterY
            width: root.col2Width
            height: root.row1Height
        }

        // Row 2: Dynamic Widget Host | Monitor
        DashboardWidgetHost {
            id: widgetHost
            x: root.contentX
            y: root.row2Y
            width: root.col1Width
            height: root.row2Height
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
}
