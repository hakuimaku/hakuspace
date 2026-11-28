import QtQuick
import QtQuick.Window
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
    property real sideInset: ScreenGeometry.leftInset
    property real attachmentY: Theme.topBarHeight
    property bool bottomAttached: false
    property bool leftAttached: false
    property real leftSeam: ScreenGeometry.leftChromeWidth
    property string screenName: ""
    property real attachmentSeam: ScreenGeometry.chromeAttachmentY(screenHeight)
    // Keep every Dashboard child in one upright plane inside the Flare body.
    readonly property real contentOriginY: bottomAttached
        ? attachmentSeam - currentEnvelopeHeight + bottomFlareReach : 0
    function mapY(logicalY) { return contentOriginY + logicalY }
    // Store only primitive widget state outside the disposable Dashboard tree.
    property QtObject viewState: null
    property bool expanded: false
    property real morphProgress: 0.0
    property bool hasFullscreen: false
    property bool pinned: false

    // Detect active text editing inside Dashboard so SafeZone locks against accidental pointer-exit close.
    readonly property Item _focusedItem: root.Window.window ? root.Window.window.activeFocusItem : null
    readonly property bool inputActive: root.expanded && _isDescendantTextInput(_focusedItem)
    readonly property bool inputComposing: inputActive && !!_focusedItem && _focusedItem.inputMethodComposing === true

    function _isDescendantTextInput(item) {
        if (!item || typeof item.cursorPosition !== "number" || typeof item.selectedText !== "string" || item.readOnly === true) {
            return false
        }
        var curr = item
        while (curr) {
            if (curr === root) return true
            curr = curr.parent
        }
        return false
    }

    signal requestReturnToNavigation()
    signal focusRequested()
    signal pinToggled()
    signal resizeRequested(real newWidth, real newHeight)
    signal resizeResetRequested()

    property bool resizing: false
    property real targetWidth: Theme.dashboardWidth
    property real targetHeight: Theme.dashboardHeight

    onExpandedChanged: if (!expanded) resizing = false
    Component.onDestruction: resizing = false

    readonly property bool isFullyOpen: morphProgress >= 0.98

    // 20 logical px Dashboard shell inset
    readonly property real innerPadding: 24
    readonly property real railGap: 14
    readonly property real cardGap: 14
    readonly property real cornerRadius: Theme.largeRadius
    readonly property real flareRadius: Theme.giantRadius

    // Dashboard shell dimensions
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
    // Row 2 (Widget | Secondary) fills the rest down to 20px bottom padding.
    readonly property real topClusterX: contentX
    readonly property real topClusterY: innerPadding
    readonly property real row1Height: Math.max(122, Math.min(176, Math.round(dashboardHeight * 0.26)))
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

    // Card 4: Secondary slot (Row 2, Col 2)
    readonly property real secondaryCardTargetX: contentX + col1Width + cardGap
    readonly property real secondaryCardTargetY: row2Y
    readonly property real secondaryCardX: secondaryCardTargetX + (36 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real secondaryCardY: secondaryCardTargetY + (28 * Math.max(0.0, 1.0 - cardMorphProgress))
    readonly property real secondaryCardScale: Math.max(0.70, 0.70 + 0.30 * cardMorphProgress)
    readonly property real secondaryCardOpacity: isFullyOpen ? 1.0
        : Math.max(0.0, Math.min(1.0, (cardMorphProgress - 0.20) / 0.65))

    // Input mask bounds exposed for NavigationPanel overlay mask union
    readonly property real maskBodyWidth: currentBodyWidth
    readonly property real maskBodyHeight: usableBodyBottom
    readonly property real maskEarX: currentBodyEnd
    readonly property real maskEarWidth: flareRadius
    readonly property real maskEarHeight: attachmentY + flareRadius
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

    // 1. Surrogate rounded background on Overlay (no flare ears; Layer 1 Top owns flare ears).
    Rectangle {
        id: bodySurface
        x: 0
        y: root.bottomAttached ? root.contentOriginY : 0
        width: root.currentBodyWidth
        height: root.currentBodyHeight
        color: Theme.surface
        visible: width > 0.01 && height > 0.01
        readonly property real bodyCornerRadius: Math.min(root.cornerRadius + 8, width / 2, height / 2)
        topLeftRadius: 0
        topRightRadius: root.bottomAttached ? bodyCornerRadius : 0
        bottomLeftRadius: 0
        bottomRightRadius: !root.bottomAttached ? bodyCornerRadius : 0
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
            if (ImageEditor.busy || ImageEditor.sourcePath || Avatar.busy) return
            UiState.beginDashboardAvatarPicker()
        }
    }

    // 3. Cards & profile rail container clipped to active dashboard morph envelope
    Item {
        id: cardsClipper
        x: 0
        y: root.mapY(0)
        width: root.currentBodyWidth
        height: root.currentBodyHeight
        clip: true
        visible: root.morphProgress > 0.02
        z: 5

        Item {
            id: cardsContainer
            anchors.fill: parent
            opacity: root.contentRevealProgress
            enabled: root.isFullyOpen

            // Profile rail tracks currentBodyHeight inside cardsClipper so Pin stays glued to Dashboard during open/close.
            DashboardProfileRail {
                id: profileRail
                x: root.avatarX
                y: root.avatarY + root.avatarDiameter + 14
                railWidth: root.avatarDiameter
                railHeight: Math.max(0, (root.currentBodyHeight - root.bottomPadding) - (root.avatarY + root.avatarDiameter + 14))
                pinned: root.pinned
                z: 4
                onPinToggled: root.pinToggled()
            }

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

            // Row 2: Dynamic Widget Host | Secondary slot
            DashboardWidgetHost {
                id: widgetHost
                active: root.expanded
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

            DashboardAgendaCard {
                id: agendaCard
                x: root.secondaryCardX
                y: root.secondaryCardY
                width: root.col2Width
                height: root.row2Height
                scale: root.secondaryCardScale
                opacity: root.secondaryCardOpacity
                transformOrigin: Item.Center
                active: root.expanded
            }
        }
    }

    // 4. Drag-to-resize handles (Right, Bottom/Top, and Corner) active when fully open
    MouseArea {
        id: rightResizeMouse
        visible: root.isFullyOpen
        enabled: root.isFullyOpen
        x: Math.max(0, root.currentBodyWidth - width)
        y: root.bottomAttached ? (root.contentOriginY + 20) : 0
        width: 10
        height: Math.max(0, root.currentBodyHeight - 20)
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        acceptedButtons: Qt.LeftButton
        z: 30

        property point pressPos: Qt.point(0, 0)
        property real startWidth: 0
        property real startHeight: 0

        onPressed: mouse => {
            DashboardTooltip.dismiss()
            pressPos = mapToItem(root, mouse.x, mouse.y)
            startWidth = root.targetWidth
            startHeight = root.targetHeight
            root.resizing = true
        }
        onPositionChanged: mouse => {
            if (!root.resizing) return
            var pos = mapToItem(root, mouse.x, mouse.y)
            root.resizeRequested(startWidth + (pos.x - pressPos.x), startHeight)
        }
        onReleased: root.resizing = false
        onCanceled: root.resizing = false
    }

    MouseArea {
        id: verticalResizeMouse
        visible: root.isFullyOpen
        enabled: root.isFullyOpen
        x: 0
        y: root.bottomAttached ? root.contentOriginY : Math.max(0, root.currentBodyHeight - height)
        width: Math.max(0, root.currentBodyWidth - 20)
        height: 10
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        acceptedButtons: Qt.LeftButton
        z: 30

        property point pressPos: Qt.point(0, 0)
        property real startWidth: 0
        property real startHeight: 0

        onPressed: mouse => {
            DashboardTooltip.dismiss()
            pressPos = mapToItem(root, mouse.x, mouse.y)
            startWidth = root.targetWidth
            startHeight = root.targetHeight
            root.resizing = true
        }
        onPositionChanged: mouse => {
            if (!root.resizing) return
            var pos = mapToItem(root, mouse.x, mouse.y)
            var dy = pos.y - pressPos.y
            var deltaH = root.bottomAttached ? -dy : dy
            root.resizeRequested(startWidth, startHeight + deltaH)
        }
        onReleased: root.resizing = false
        onCanceled: root.resizing = false
    }

    Item {
        id: cornerResizeHandle
        visible: root.isFullyOpen
        x: Math.max(0, root.currentBodyWidth - width)
        y: root.bottomAttached ? root.contentOriginY : Math.max(0, root.currentBodyHeight - height)
        width: 20
        height: 20
        z: 31

        readonly property real gripOpacity: (cornerResizeMouse.containsMouse || root.resizing) ? 0.72 : 0.22

        Rectangle {
            width: 11
            height: 2
            radius: 1
            color: Theme.fgMuted
            opacity: cornerResizeHandle.gripOpacity
            rotation: root.bottomAttached ? 45 : -45
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 2
            anchors.verticalCenterOffset: root.bottomAttached ? -2 : 2
        }

        Rectangle {
            width: 6
            height: 2
            radius: 1
            color: Theme.fgMuted
            opacity: cornerResizeHandle.gripOpacity
            rotation: root.bottomAttached ? 45 : -45
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 5
            anchors.verticalCenterOffset: root.bottomAttached ? -5 : 5
        }

        MouseArea {
            id: cornerResizeMouse
            anchors.fill: parent
            enabled: root.isFullyOpen
            hoverEnabled: true
            cursorShape: root.bottomAttached ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
            acceptedButtons: Qt.LeftButton

            property point pressPos: Qt.point(0, 0)
            property real startWidth: 0
            property real startHeight: 0

            onEntered: if (!root.resizing) DashboardTooltip.show(cornerResizeHandle, "Drag to resize · Double-click to reset")
            onExited: DashboardTooltip.hide(cornerResizeHandle)
            onPressed: mouse => {
                DashboardTooltip.dismiss()
                pressPos = mapToItem(root, mouse.x, mouse.y)
                startWidth = root.targetWidth
                startHeight = root.targetHeight
                root.resizing = true
            }
            onPositionChanged: mouse => {
                if (!root.resizing) return
                var pos = mapToItem(root, mouse.x, mouse.y)
                var dx = pos.x - pressPos.x
                var dy = pos.y - pressPos.y
                var deltaH = root.bottomAttached ? -dy : dy
                root.resizeRequested(startWidth + dx, startHeight + deltaH)
            }
            onReleased: root.resizing = false
            onCanceled: root.resizing = false
            onDoubleClicked: {
                DashboardTooltip.dismiss()
                root.resizing = false
                root.resizeResetRequested()
            }
        }
    }

    // 5. Scoped hover tooltip layer for Dashboard elements
    DashboardTooltipLayer {
        id: tooltipLayer
    }
}
