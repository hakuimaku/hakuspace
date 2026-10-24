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
    property real sideInset: ScreenGeometry.leftInset
    property real attachmentY: Theme.topBarHeight
    property bool bottomAttached: false
    property real attachmentSeam: ScreenGeometry.chromeAttachmentY(screenHeight)
    // Keep every Dashboard child in one upright plane inside the Flare body.
    readonly property real contentOriginY: bottomAttached
        ? attachmentSeam - currentEnvelopeHeight + bottomFlareReach : 0
    function mapY(logicalY) { return contentOriginY + logicalY }
    // Store only primitive widget state outside the disposable Dashboard tree.
    property QtObject viewState: null
    property bool expanded: false
    property real morphProgress: 0.0

    signal requestReturnToNavigation()
    signal focusRequested()

    property real targetWidth: Math.round(screenWidth * 0.50)
    property real targetHeight: Math.round(screenHeight * 0.50)

    readonly property bool isFullyOpen: morphProgress >= 0.98

    // 20 logical px Dashboard shell inset
    readonly property real innerPadding: 24
    readonly property real railGap: 14
    readonly property real cardGap: 12
    readonly property real cornerRadius: Theme.largeRadius
    readonly property real flareRadius: Theme.giantRadius

    // Canonical 50x50 Dashboard shell dimensions
    readonly property real dashboardWidth: targetWidth
    readonly property real dashboardHeight: targetHeight

    // Morph geometry interpolation:
    // Start envelope corresponds to the compact Navigation controller origin
    readonly property real startEnvelopeWidth: Math.round(controllerX + circleDiameter + innerPadding)
    readonly property real startEnvelopeHeight: Math.round(controllerY + circleDiameter + innerPadding)
    readonly property real currentEnvelopeWidth: startEnvelopeWidth + (dashboardWidth - startEnvelopeWidth) * morphProgress
    readonly property real currentEnvelopeHeight: startEnvelopeHeight + (dashboardHeight - startEnvelopeHeight) * morphProgress

    // Flare body bounds (ends before flare ear so final envelope stays <= 50% x 50%)
    property real bottomFlareReach: Theme.hugRadius
    readonly property real finalBodyEnd: Math.max(0, dashboardWidth - flareRadius)
    readonly property real currentBodyEnd: Math.max(0, currentEnvelopeWidth - flareRadius)
    readonly property real currentBodyWidth: currentBodyEnd

    readonly property real finalBodyBottom: Math.max(0, dashboardHeight - bottomFlareReach)
    readonly property real startBodyBottom: Math.max(0, startEnvelopeHeight - bottomFlareReach)
    readonly property real usableBodyBottom: startBodyBottom + (finalBodyBottom - startBodyBottom) * morphProgress
    readonly property real currentBodyHeight: usableBodyBottom

    // Avatar column padding: 4px padding on left and right gives the column
    // extra breathing room and prevents the hovered avatar from crowding margins
    readonly property real avatarColumnPadding: 8

    // Avatar geometry:
    // Glides smoothly from controller origin to (24, 20) with 4px left/right padding
    readonly property real finalAvatarX: innerPadding + avatarColumnPadding
    readonly property real finalAvatarY: innerPadding
    readonly property real avatarX: controllerX + (finalAvatarX - controllerX) * morphProgress
    // Seed the avatar at the corner controller before moving into the upright content plane.
    readonly property real initialAvatarY: bottomAttached
        ? startEnvelopeHeight - bottomFlareReach + ScreenGeometry.chromeBarHeight - controllerY - circleDiameter
        : controllerY
    readonly property real avatarY: initialAvatarY + (finalAvatarY - initialAvatarY) * morphProgress
    readonly property real avatarDiameter: circleDiameter
    readonly property real avatarOpacity: {
        var t = Math.min(1.0, morphProgress / 0.25)
        return t * t * (3 - 2 * t)
    }

    // Profile rail & content area geometry (wider column accommodating the 4px padding)
    readonly property real profileRailWidth: avatarDiameter + (avatarColumnPadding * 2)
    readonly property real contentX: innerPadding + profileRailWidth + railGap
    readonly property real rightPadding: innerPadding
    readonly property real bottomPadding: innerPadding

    // Card cluster expands across the full dashboard width with 20px right padding
    readonly property real clusterWidth: Math.max(260, finalBodyEnd - contentX - rightPadding)

    // Two equal card columns inside cluster
    readonly property real colGap: cardGap
    readonly property real colWidth: Math.max(120, Math.floor((clusterWidth - colGap) / 2))
    readonly property real col1Width: colWidth
    readonly property real col2Width: Math.max(120, clusterWidth - col1Width - colGap)

    // Usable card layout rows:
    // Row 1 (Clock | Media) takes ~24% of dashboard height (e.g. 120-136px),
    // Row 2 (Widget | Monitor) fills the rest down to 20px bottom padding.
    readonly property real topClusterX: contentX
    readonly property real topClusterY: innerPadding
    readonly property real row1Height: Math.max(104, Math.min(136, Math.round(dashboardHeight * 0.24)))
    readonly property real row2Y: topClusterY + row1Height + cardGap
    readonly property real row2Height: Math.max(160, finalBodyBottom - row2Y - bottomPadding)

    // Helper aliases
    readonly property real topClusterWidth: col1Width + cardGap + col2Width
    readonly property real topClusterHeight: row1Height + cardGap + row2Height
    readonly property real topClusterRight: topClusterX + topClusterWidth
    readonly property real topClusterBottom: row2Y + row2Height

    // Content reveal progress: cards fade in and translate smoothly after shell begins opening
    readonly property real contentRevealProgress: {
        if (morphProgress <= 0.25) return 0.0
        if (morphProgress >= 0.75) return 1.0
        var t = (morphProgress - 0.25) / (0.75 - 0.25)
        return t * t * (3 - 2 * t)
    }

    // Dynamic widget morph properties coordinated with dashboard expansion & elastic bounce:
    readonly property real cardMorphProgress: {
        if (morphProgress <= 0.08) return 0.0
        return (morphProgress - 0.08) / 0.92
    }

    // Card 1: Clock (Row 1, Col 1)
    readonly property real clockCardTargetX: contentX
    readonly property real clockCardTargetY: topClusterY
    readonly property real clockCardX: clockCardTargetX + (-28 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real clockCardY: clockCardTargetY + (-20 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real clockCardScale: Math.max(0.70, 0.70 + 0.30 * cardMorphProgress)
    readonly property real clockCardOpacity: isFullyOpen ? 1.0
        : Math.max(0.0, Math.min(1.0, (cardMorphProgress - 0.05) / 0.65))

    // Card 2: Media (Row 1, Col 2)
    readonly property real mediaCardTargetX: contentX + col1Width + cardGap
    readonly property real mediaCardTargetY: topClusterY
    readonly property real mediaCardX: mediaCardTargetX + (36 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real mediaCardY: mediaCardTargetY + (-20 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real mediaCardScale: Math.max(0.70, 0.70 + 0.30 * cardMorphProgress)
    readonly property real mediaCardOpacity: isFullyOpen ? 1.0
        : Math.max(0.0, Math.min(1.0, (cardMorphProgress - 0.10) / 0.65))

    // Card 3: WidgetHost (Row 2, Col 1)
    readonly property real widgetHostTargetX: contentX
    readonly property real widgetHostTargetY: row2Y
    readonly property real widgetHostX: widgetHostTargetX + (-28 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real widgetHostY: widgetHostTargetY + (28 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real widgetHostScale: Math.max(0.70, 0.70 + 0.30 * cardMorphProgress)
    readonly property real widgetHostOpacity: isFullyOpen ? 1.0
        : Math.max(0.0, Math.min(1.0, (cardMorphProgress - 0.15) / 0.65))

    // Card 4: Monitor (Row 2, Col 2)
    readonly property real monitorCardTargetX: contentX + col1Width + cardGap
    readonly property real monitorCardTargetY: row2Y
    readonly property real monitorCardX: monitorCardTargetX + (36 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real monitorCardY: monitorCardTargetY + (28 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real monitorCardScale: Math.max(0.70, 0.70 + 0.30 * cardMorphProgress)
    readonly property real monitorCardOpacity: isFullyOpen ? 1.0
        : Math.max(0.0, Math.min(1.0, (cardMorphProgress - 0.20) / 0.65))

    // Input mask bounds exposed for NavigationPanel overlay mask union
    readonly property real maskBodyWidth: currentBodyWidth
    readonly property real maskBodyHeight: usableBodyBottom
    readonly property real maskEarX: currentBodyEnd
    readonly property real maskEarWidth: flareShell.earRadius
    readonly property real maskEarHeight: attachmentY + flareShell.earRadius
    readonly property real maskFootY: usableBodyBottom
    readonly property real maskFootWidth: bottomFlareReach + sideInset
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
        y: root.bottomAttached ? root.attachmentSeam : 0
        bottomAttached: root.bottomAttached
        bodyWidth: root.currentEnvelopeWidth
        bodyHeight: root.currentEnvelopeHeight
        sideInset: root.sideInset
        attachmentY: root.attachmentY
        bottomFlareReach: root.bottomFlareReach
        flareRadius: root.flareRadius
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        surfaceColor: Theme.surface
        cornerRadius: root.cornerRadius + 8
        z: 1
    }

    // 2. Avatar Component
    DashboardAvatar {
        id: dashboardAvatar
        x: root.avatarX
        y: root.mapY(root.avatarY)
        diameter: root.avatarDiameter
        interactive: root.isFullyOpen
        opacity: root.avatarOpacity
        visible: opacity > 0.001
        z: 10

        onRequestBack: {
            root.requestReturnToNavigation()
        }

        onRequestChangeAvatar: {
            avatarChooser.lease = UiState.beginNativeDialog("navigation")
            avatarChooser.open()
        }
    }

    // Profile rail (username + Hikaide identity below Avatar)
    DashboardProfileRail {
        id: profileRail
        x: root.avatarX
        y: root.mapY(root.avatarY + root.avatarDiameter + 14)
        railWidth: root.avatarDiameter
        railHeight: Math.max(0, (root.finalBodyBottom - root.bottomPadding) - (root.avatarY + root.avatarDiameter + 14))
        opacity: root.contentRevealProgress
        visible: opacity > 0.001
        z: 9
    }

    AvatarCropper {
        id: cropper
        parent: root
        onFinished: root.focusRequested()
    }

    FileDialog {
        id: avatarChooser
        title: "Select Avatar"
        property int lease: 0
        Component.onDestruction: UiState.endNativeDialog(lease)
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp)", "All files (*)"]

        onAccepted: {
            UiState.endNativeDialog(lease)
            Avatar.lastError = ""
            cropper.source = selectedFile
            cropper.open()
        }

        onRejected: {
            UiState.endNativeDialog(lease)
            root.focusRequested()
        }
    }

    // 3. Cards container clipped to active dashboard morph envelope
    Item {
        id: cardsClipper
        x: 0
        y: root.mapY(0)
        width: root.currentEnvelopeWidth
        height: root.bottomAttached ? root.currentBodyHeight : root.currentEnvelopeHeight
        clip: true
        visible: root.morphProgress > 0.02
        z: 5

        Item {
            id: cardsContainer
            anchors.fill: parent
            opacity: root.contentRevealProgress
            enabled: root.isFullyOpen

            // Row 1: Clock | MPRIS
            DashboardClockCard {
                id: clockCard
                x: root.clockCardX
                y: root.clockCardY
                width: root.col1Width
                height: root.row1Height
                scale: root.clockCardScale
                opacity: root.clockCardOpacity
                transformOrigin: Item.Center
            }

            DashboardMediaCard {
                id: mediaCard
                x: root.mediaCardX
                y: root.mediaCardY
                width: root.col2Width
                height: root.row1Height
                scale: root.mediaCardScale
                opacity: root.mediaCardOpacity
                transformOrigin: Item.Center
                active: root.expanded
            }

            // Row 2: Dynamic Widget Host | Monitor
            DashboardWidgetHost {
                id: widgetHost
                currentIndex: root.viewState ? root.viewState.widgetIndex : 0
                calendarMonthOffset: root.viewState ? root.viewState.calendarMonthOffset : 0
                onCurrentIndexChanged: if (root.viewState) root.viewState.widgetIndex = currentIndex
                onCalendarMonthOffsetChanged: if (root.viewState) root.viewState.calendarMonthOffset = calendarMonthOffset
                x: root.widgetHostX
                y: root.widgetHostY
                width: root.col1Width
                height: root.row2Height
                scale: root.widgetHostScale
                opacity: root.widgetHostOpacity
                transformOrigin: Item.Center
            }

            DashboardMonitorCard {
                id: monitorCard
                x: root.monitorCardX
                y: root.monitorCardY
                width: root.col2Width
                height: root.row2Height
                scale: root.monitorCardScale
                opacity: root.monitorCardOpacity
                transformOrigin: Item.Center
                active: root.expanded
            }
        }
    }

    // 4. Scoped hover tooltip layer for Dashboard elements
    DashboardTooltipLayer {
        id: tooltipLayer
    }
}
