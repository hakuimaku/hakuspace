import QtQuick
import "../../services"
import "../settings" as Settings

PathView {
    id: root
    // Leftbar uses three still-image delegates; horizontal presentations keep five.
    property string presentation: "quick"
    readonly property bool workspace: presentation === "workspace"
    readonly property Item selectedSlotItem: selectedCardOverlay
    readonly property Item leftActionItem: leftCornerActions
    // Wait for the bounded visible delegates before revealing a cold workspace.
    readonly property bool thumbnailsSettled: !count || !!currentItem && currentItem.parent.children
        .filter(item => item.wallpaper !== undefined && item.visible).every(item => item.thumbnailSettled)
    // Vertical workspace paths keep card artwork and hit targets upright.
    property bool vertical: false
    // The Leftbar adapter owns static card bounds and curve anchors.
    property var leftLayout: null
    property real spread: 1
    property real selectedPulse: 1
    property real workspaceMorph: 0
    signal applyRequested()
    signal editRequested(var wallpaper)
    signal layerStepRequested(string groupKey, int step)
    readonly property real contentPadding: vertical && leftLayout ? leftLayout.padding : workspace ? 8 : 0
    // Workspace cards use the bottom rail and rise gradually toward the selection.
    readonly property real selectedScale: vertical && leftLayout ? leftLayout.selectedScale : workspace ? 1.32 : 1
    readonly property real cardWidth: vertical ? (leftLayout ? leftLayout.cardWidth : 1) : workspace
        ? Math.max(80, Math.min(width / 5.2, height * 16 / 9 * 0.95, 360))
        : Math.max(80, Math.min(width * 0.56, (height - 48) * 16 / 9, 920))
    readonly property real selectedLift: workspace ? contentPadding : 0
    readonly property real cardBottom: height - contentPadding
    readonly property real cardGap: vertical && leftLayout ? leftLayout.gap : 8
    readonly property real cardStep: workspace ? cardWidth * (nearScale + selectedScale) / 2 + cardGap : cardWidth * 0.24
    readonly property real farOffset: workspace ? cardStep + cardWidth * (nearScale + farScale) / 2 + cardGap : cardStep * 2
    // Workspace tails curl below the screen instead of fading at horizontal edges.
    readonly property real edgeOffset: workspace ? farOffset + cardWidth * 0.6 : width / 2 + cardWidth
    readonly property real edgeY: workspace ? height + cardWidth * 9 / 32 * farScale + contentPadding : pathCenterY(farScale)
    readonly property real nearScale: vertical && leftLayout ? leftLayout.nearScale : workspace ? 0.8 : 0.78
    readonly property real farScale: 0.58
    // Larger cards float slightly higher instead of sharing one bottom baseline.
    function pathCenterY(scale) {
        return workspace ? cardBottom - cardWidth * 9 / 32 * scale
            - selectedLift * (scale - farScale) / (selectedScale - farScale) : height / 2
    }
    // Decorative orbit and collapse never change the shared selection or path offset.
    property real introProgress: 1
    property bool introPending: false
    readonly property bool introRunning: intro.running

    function playIntro() {
        intro.stop()
        introProgress = 1
        introPending = !workspace
        tryIntro()
    }
    function tryIntro() {
        if (!introPending || !enabled || count < 2 || currentIndex < 0) return
        introPending = false
        introProgress = 0
        resumeIntro()
    }
    function resumeIntro() {
        if (workspace || !enabled || intro.running || introProgress >= 1) return
        intro.duration = Math.round((HAnimation.slow + HAnimation.effects) * (1 - introProgress))
        intro.start()
    }
    // Freeze an interrupted orbit so close/reopen can continue without snapping.
    function pauseIntro() { intro.stop(); introPending = false }
    function stopIntro() { pauseIntro(); introProgress = 1 }
    onCountChanged: {
        offsetTrackerReady = false
        lastTrackedOffset = offset
        resetCrowdState()
        resetWheelState()
        tryIntro()
    }
    onCurrentIndexChanged: tryIntro()
    onEnabledChanged: {
        if (!enabled) {
            pauseIntro()
            resetWheelState()
            resetCrowdState()
        }
        else if (introPending) tryIntro()
        else resumeIntro()
    }
    NumberAnimation {
        id: intro
        target: root; property: "introProgress"; to: 1
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.moduleCurve
    }
    objectName: "wallpaperReel"
    model: WallpaperLibrary.filteredItems
    // Model replacement resets PathView even when the selected index stays unchanged.
    onModelChanged: {
        offsetTrackerReady = false
        resetCrowdState()
        resetWheelState()
        Qt.callLater(resetPosition)
    }
    function resetPosition() {
        currentIndex = WallpaperLibrary.selectedIndex
        if (currentIndex >= 0) positionViewAtIndex(currentIndex, PathView.Center)
        lastTrackedOffset = offset
        offsetTrackerReady = true
    }
    // Keep input timing separate from decorative animation progress.
    property double lastMoveAt: 0
    readonly property int baseMoveDuration: 220
    readonly property int minMoveDuration: 130
    // Pace mouse-wheel notches so 60Hz transitions stay continuous instead of jumping.
    property real wheelDeltaAccum: 0
    property int pendingWheelSteps: 0
    // Crowd squeeze ramps immediately via EMA during motion and releases with an overshoot Bezier.
    property real crowdFactor: 0
    property real crowdInertia: 0
    property real lastTrackedOffset: 0
    property bool offsetTrackerReady: false
    function resetCrowdState() {
        crowdSettleTimer.stop()
        crowdReleaseAnim.stop()
        inertiaReleaseAnim.stop()
        crowdFactor = 0
        crowdInertia = 0
    }
    NumberAnimation {
        id: crowdReleaseAnim
        target: root; property: "crowdFactor"; to: 0
        duration: 210
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1.44, 0.38, 1.06, 1, 1]
    }
    NumberAnimation {
        id: inertiaReleaseAnim
        target: root; property: "crowdInertia"; to: 0
        duration: 230
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1.48, 0.38, 1.06, 1, 1]
    }
    Timer {
        id: crowdSettleTimer
        interval: 40
        onTriggered: {
            crowdReleaseAnim.restart()
            inertiaReleaseAnim.restart()
        }
    }
    Timer {
        id: wheelStepTimer
        interval: 90
        repeat: true
        onTriggered: root.drainWheelStep()
    }
    Timer {
        id: wheelAccumResetTimer
        interval: 220
        onTriggered: root.wheelDeltaAccum = 0
    }
    function resetWheelState() {
        wheelDeltaAccum = 0
        pendingWheelSteps = 0
        wheelStepTimer.stop()
        wheelAccumResetTimer.stop()
    }
    function drainWheelStep() {
        if (!pendingWheelSteps || !count) {
            pendingWheelSteps = 0
            wheelStepTimer.stop()
            return
        }
        var dir = pendingWheelSteps > 0 ? 1 : -1
        pendingWheelSteps -= dir
        move(dir, minMoveDuration)
        if (!pendingWheelSteps) wheelStepTimer.stop()
    }
    // Keep held-key repeat synced 1:1 while enforcing a 60Hz-safe duration floor for wheel bursts.
    function move(step, minDuration) {
        if (!count) return
        stopIntro()
        var now = Date.now()
        var elapsed = now - lastMoveAt
        lastMoveAt = now
        var floor = minDuration !== undefined ? minDuration : 16
        highlightMoveDuration = elapsed > 0 && elapsed < baseMoveDuration
            ? Math.max(floor, Math.round(elapsed))
            : baseMoveDuration
        movementDirection = step === 1 ? PathView.Positive : step === -1 ? PathView.Negative : PathView.Shortest
        WallpaperLibrary.move(step)
        movementDirection = PathView.Shortest
        highlightMoveDuration = baseMoveDuration
    }
    onOffsetChanged: {
        if (!offsetTrackerReady || count < 2) {
            lastTrackedOffset = offset
            offsetTrackerReady = true
            return
        }
        var rawDelta = offset - lastTrackedOffset
        if (rawDelta > count / 2) rawDelta -= count
        else if (rawDelta < -count / 2) rawDelta += count
        lastTrackedOffset = offset
        var absDelta = Math.abs(rawDelta)
        if (absDelta > 0.0005) {
            if (crowdReleaseAnim.running) crowdReleaseAnim.stop()
            if (inertiaReleaseAnim.running) inertiaReleaseAnim.stop()
            var squeezeImpulse = Math.min(1, absDelta * 7.5)
            crowdFactor = crowdFactor + (squeezeImpulse - crowdFactor) * 0.48
            var inertiaImpulse = Math.max(-1, Math.min(1, rawDelta * 8.5))
            crowdInertia = crowdInertia + (inertiaImpulse - crowdInertia) * 0.45
            crowdSettleTimer.restart()
        }
    }
    currentIndex: WallpaperLibrary.selectedIndex
    pathItemCount: vertical ? 3 : 5
    cacheItemCount: vertical ? 2 : 4
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange
    highlightMoveDuration: baseMoveDuration
    flickDeceleration: 650
    maximumFlickVelocity: 1400
    dragMargin: vertical ? width / 2 : height / 2
    snapMode: PathView.SnapToItem
    clip: vertical || !workspace

    // The quick path stays horizontal; workspace entry and exit use mirrored curves.
    path: vertical ? verticalPath : horizontalPath
    // Static anchors are shared with the gallery surface, independent of PathView offset.
    readonly property var cornerCurve: leftLayout ? leftLayout.anchors : ({upper: Qt.point(0, 0), selected: Qt.point(0, 0),
        left: Qt.point(0, 0), incoming1: Qt.point(0, 0), incoming2: Qt.point(0, 0), outgoing1: Qt.point(0, 0), outgoing2: Qt.point(0, 0)})
    property Path verticalPath: Path {
        startX: root.width + root.cardWidth / 2; startY: -root.cardWidth * 9 / 16
        PathAttribute { name: "cardScale"; value: root.nearScale }
        PathAttribute { name: "cardDepth"; value: 1 }
        PathLine { x: root.cornerCurve.upper.x; y: root.cornerCurve.upper.y }
        PathPercent { value: 1 / 6 }
        PathAttribute { name: "cardScale"; value: root.nearScale }
        PathAttribute { name: "cardDepth"; value: 1 }
        PathCubic {
            control1X: root.cornerCurve.incoming1.x
            control1Y: root.cornerCurve.incoming1.y
            control2X: root.cornerCurve.incoming2.x
            control2Y: root.cornerCurve.incoming2.y
            x: root.cornerCurve.selected.x; y: root.cornerCurve.selected.y
        }
        PathPercent { value: 0.5 }
        PathAttribute { name: "cardScale"; value: root.selectedScale }
        PathAttribute { name: "cardDepth"; value: 2 }
        PathCubic {
            control1X: root.cornerCurve.outgoing1.x
            control1Y: root.cornerCurve.outgoing1.y
            control2X: root.cornerCurve.outgoing2.x
            control2Y: root.cornerCurve.outgoing2.y
            x: root.cornerCurve.left.x; y: root.cornerCurve.left.y
        }
        PathPercent { value: 5 / 6 }
        PathAttribute { name: "cardScale"; value: root.nearScale }
        PathAttribute { name: "cardDepth"; value: 1 }
        PathLine { x: -root.cardWidth / 2; y: root.height + root.cardWidth * 9 / 16 }
        PathPercent { value: 1 }
    }
    property Path horizontalPath: Path {
        startX: root.width / 2 - root.edgeOffset; startY: root.edgeY
        PathAttribute { name: "cardScale"; value: root.farScale }
        PathAttribute { name: "cardDepth"; value: 0 }
        PathCubic {
            control1X: root.width / 2 - root.edgeOffset
            control1Y: root.workspace ? root.pathCenterY(root.farScale) + root.cardWidth * 0.2 : root.edgeY
            control2X: root.width / 2 - root.farOffset - (root.workspace ? root.cardWidth * 0.2 : 0)
            control2Y: root.pathCenterY(root.farScale) + (root.workspace ? root.contentPadding * 2 : 0)
            x: root.width / 2 - root.farOffset; y: root.pathCenterY(root.farScale)
        }
        PathPercent { value: 0.1 }
        PathAttribute { name: "cardScale"; value: root.farScale }
        PathAttribute { name: "cardDepth"; value: 0 }
        PathLine { x: root.width / 2 - root.cardStep; y: root.pathCenterY(root.nearScale) }
        PathPercent { value: 0.3 }
        PathAttribute { name: "cardScale"; value: root.nearScale }
        PathAttribute { name: "cardDepth"; value: 1 }
        PathLine { x: root.width / 2; y: root.pathCenterY(root.selectedScale) }
        PathPercent { value: 0.5 }
        PathAttribute { name: "cardScale"; value: root.selectedScale }
        PathAttribute { name: "cardDepth"; value: 2 }
        PathLine { x: root.width / 2 + root.cardStep; y: root.pathCenterY(root.nearScale) }
        PathPercent { value: 0.7 }
        PathAttribute { name: "cardScale"; value: root.nearScale }
        PathAttribute { name: "cardDepth"; value: 1 }
        PathLine { x: root.width / 2 + root.farOffset; y: root.pathCenterY(root.farScale) }
        PathPercent { value: 0.9 }
        PathAttribute { name: "cardScale"; value: root.farScale }
        PathAttribute { name: "cardDepth"; value: 0 }
        PathCubic {
            control1X: root.width / 2 + root.farOffset + (root.workspace ? root.cardWidth * 0.2 : 0)
            control1Y: root.pathCenterY(root.farScale) + (root.workspace ? root.contentPadding * 2 : 0)
            control2X: root.width / 2 + root.edgeOffset
            control2Y: root.workspace ? root.pathCenterY(root.farScale) + root.cardWidth * 0.2 : root.edgeY
            x: root.width / 2 + root.edgeOffset; y: root.edgeY
        }
        PathPercent { value: 1 }
    }
    delegate: WallpaperCard {
        id: card
        required property var modelData
        required property int index
        readonly property real targetScale: PathView.cardScale ?? 1
        readonly property real slotX: x + width / 2 - root.width / 2
        readonly property real verticalCenterDx: (x + width / 2) - root.cornerCurve.selected.x
        readonly property real verticalCenterDy: (y + height / 2) - root.cornerCurve.selected.y
        readonly property real orbitPhase: Math.asin(Math.max(-1, Math.min(1, slotX / Math.max(1, root.farOffset))))
            + root.introProgress * Math.PI * 2
        readonly property real orbitOffset: root.workspace || chosen || root.introProgress >= 1
            ? 0 : Math.sin(orbitPhase) * root.farOffset - slotX
        // Squeeze side cards inward dynamically with signed scroll inertia and rebound on settle.
        readonly property real crowdHorizontalX: (chosen ? 0 : -slotX * 0.17 * root.crowdFactor)
            - root.crowdInertia * root.cardWidth * (chosen ? 0.025 : 0.075)
        readonly property real crowdVerticalX: (chosen ? 0 : -verticalCenterDx * 0.15 * root.crowdFactor)
            - root.crowdInertia * root.cardWidth * (chosen ? 0.02 : 0.05)
        readonly property real crowdVerticalY: (chosen ? 0 : -verticalCenterDy * 0.15 * root.crowdFactor)
            + root.crowdInertia * root.cardWidth * (chosen ? 0.025 : 0.06)
        readonly property real crowdScale: 1 - (chosen ? 0.022 : 0.06) * root.crowdFactor
        wallpaper: modelData
        width: root.cardWidth
        chosen: PathView.isCurrentItem
        compactCard: root.workspace
        outlineSelection: root.vertical
        cornerRadius: Theme.largeRadius
        revealProgress: !root.workspace && chosen ? root.introProgress : 1
        decodeScale: root.selectedScale
        pulse: !root.workspace && chosen ? root.selectedPulse : 1
        transform: Translate {
            x: root.vertical
                ? card.crowdVerticalX
                : (card.chosen ? 0 : (root.spread - 1) * card.slotX + root.spread * card.orbitOffset) + card.crowdHorizontalX
            y: root.vertical
                ? (card.chosen ? 0 : (root.spread - 1) * (card.y + card.height / 2 - root.height / 2)) + card.crowdVerticalY
                : 0
        }
        visible: PathView.onPath
        scale: targetScale * pulse * crowdScale
        opacity: 1
        // Selection stays above moving neighbors and Mode 2 cradle actions stay behind all cards.
        z: root.vertical ? (chosen ? 4 : 3) : ((PathView.cardDepth ?? 0) + 2)
        onSelected: { root.stopIntro(); WallpaperLibrary.selectIndex(index); root.forceActiveFocus() }
        onApplied: root.applyRequested()
    }
    // Shared selected-item action state for Mode 1 overlay and Mode 2 cradle actions.
    QtObject {
        id: actionState
        readonly property var selectedStack: WallpaperLibrary.selected
        readonly property bool baseReady: root.enabled && !!selectedStack && root.count > 0
        readonly property bool quickReady: !root.workspace && baseReady && root.introProgress >= 1
        readonly property bool workspaceReady: root.workspace && baseReady
        readonly property bool showQuickEdit: quickReady && selectedStack.kind === "static"
        readonly property bool showQuickLayers: quickReady && selectedStack.layerCount > 1
        readonly property bool showWorkspaceEdit: workspaceReady && selectedStack.kind === "static"
        readonly property bool showWorkspaceLayers: workspaceReady && selectedStack.layerCount > 1
        readonly property bool activeOnTop: !!selectedStack && WallpaperService.current.path === selectedStack.path
        readonly property bool hiddenLayerActive: !!selectedStack && selectedStack.layerCount > 1 && !activeOnTop
            && !!selectedStack.layers && selectedStack.layers.some(layer => layer.path === WallpaperService.current.path)
        readonly property string activeLayerText: (showQuickLayers || showWorkspaceLayers)
            ? ((selectedStack.layerLabel || "Edited") + " · " + (selectedStack.activeLayerIndex + 1) + "/" + selectedStack.layerCount)
            : ""
        property string displayLayerText: ""
        onActiveLayerTextChanged: if (activeLayerText) displayLayerText = activeLayerText
        Component.onCompleted: if (activeLayerText) displayLayerText = activeLayerText
    }

    // Stronger spring bounce for Mode 1 floating Edit button and Layer pill synced with navigation.
    property real quickEditBounceScale: 1
    property real quickEditBounceY: 0
    property real quickPillBounceScale: 1
    property real quickPillBounceY: 0
    function triggerQuickBounce(includeEdit) {
        if (root.workspace || !root.enabled || root.introRunning || root.introPending || root.introProgress < 1) return
        if (includeEdit) quickEditBounce.restart()
        quickPillBounce.restart()
    }
    SequentialAnimation {
        id: quickEditBounce
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "quickEditBounceScale"; to: 0.85
                duration: HAnimation.buttonPressDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.buttonPressCurve
            }
            NumberAnimation {
                target: root; property: "quickEditBounceY"; to: -5
                duration: HAnimation.buttonPressDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.buttonPressCurve
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "quickEditBounceScale"; to: 1
                duration: HAnimation.normal + 60
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.52, 0.36, 1.0, 1, 1]
            }
            NumberAnimation {
                target: root; property: "quickEditBounceY"; to: 0
                duration: HAnimation.normal + 60
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.52, 0.36, 1.0, 1, 1]
            }
        }
    }
    SequentialAnimation {
        id: quickPillBounce
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "quickPillBounceScale"; to: 0.86
                duration: HAnimation.buttonPressDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.buttonPressCurve
            }
            NumberAnimation {
                target: root; property: "quickPillBounceY"; to: 5
                duration: HAnimation.buttonPressDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.buttonPressCurve
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "quickPillBounceScale"; to: 1
                duration: HAnimation.normal + 60
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.52, 0.36, 1.0, 1, 1]
            }
            NumberAnimation {
                target: root; property: "quickPillBounceY"; to: 0
                duration: HAnimation.normal + 60
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.52, 0.36, 1.0, 1, 1]
            }
        }
    }
    Connections {
        target: WallpaperLibrary
        function onSelectedGroupKeyChanged() { root.triggerQuickBounce(true) }
        function onLayerCycled(groupKey, step) {
            if (WallpaperLibrary.selectedGroupKey === groupKey) root.triggerQuickBounce(false)
        }
    }

    // Mode 2 Topbar: sit beneath carousel cards (z: 0 < card z: 2..4) while keeping pointer priority over PathView.
    Item {
        id: topbarShoulderActions
        objectName: "wallpaper-topbar-shoulder-actions"
        z: 0
        visible: root.workspace && !root.vertical
        anchors.fill: parent
        readonly property real selectedHalfW: root.cardWidth * root.selectedScale / 2
        readonly property real selectedLeft: root.width / 2 - selectedHalfW
        readonly property real selectedRight: root.width / 2 + selectedHalfW
        readonly property real nearTop: root.pathCenterY(root.nearScale)
            - root.cardWidth * 9 / 16 * root.nearScale / 2
        readonly property real shoulderGap: Theme.spaceLg

        Item {
            id: topbarLayerHost
            property real reveal: actionState.showWorkspaceLayers ? 1 : 0
            Behavior on reveal {
                NumberAnimation {
                    duration: HAnimation.effects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.moduleCurve
                }
            }
            visible: reveal > 0.01
            opacity: reveal
            enabled: actionState.showWorkspaceLayers
            width: topbarLayerPill.width
            height: topbarLayerPill.height
            x: Math.max(Theme.panelPadding, topbarShoulderActions.selectedLeft - topbarShoulderActions.shoulderGap - width)
            y: topbarShoulderActions.nearTop - height - Theme.spaceMd
            transform: [
                Scale {
                    origin.x: topbarLayerHost.width
                    origin.y: topbarLayerHost.height / 2
                    xScale: 0.9 + 0.1 * topbarLayerHost.reveal
                    yScale: 0.9 + 0.1 * topbarLayerHost.reveal
                },
                Translate {
                    y: (1 - topbarLayerHost.reveal) * 10
                }
            ]
            WallpaperLayerPill {
                id: topbarLayerPill
                objectName: "wallpaper-topbar-layer-switcher"
                text: actionState.displayLayerText
                hiddenLayerActive: actionState.hiddenLayerActive
                compact: false
                maxPillWidth: Math.max(116, topbarShoulderActions.selectedLeft - Theme.panelPadding - topbarShoulderActions.shoulderGap)
                surfaceColor: Theme.hoverMuted
                onStepRequested: step => {
                    if (actionState.selectedStack) root.layerStepRequested(actionState.selectedStack.groupKey, step)
                }
            }
        }

        Item {
            id: topbarEditHost
            property real reveal: actionState.showWorkspaceEdit ? 1 : 0
            Behavior on reveal {
                NumberAnimation {
                    duration: HAnimation.effects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.moduleCurve
                }
            }
            visible: reveal > 0.01
            opacity: reveal
            enabled: actionState.showWorkspaceEdit
            width: 48
            height: 48
            x: Math.min(root.width - Theme.panelPadding - width, topbarShoulderActions.selectedRight + topbarShoulderActions.shoulderGap)
            y: topbarShoulderActions.nearTop - height - Theme.spaceMd
            transform: [
                Scale {
                    origin.x: topbarEditHost.width / 2
                    origin.y: topbarEditHost.height / 2
                    xScale: 0.86 + 0.14 * topbarEditHost.reveal
                    yScale: 0.86 + 0.14 * topbarEditHost.reveal
                },
                Translate {
                    y: (1 - topbarEditHost.reveal) * 10
                }
            ]
            WallpaperToolbarButton {
                id: topbarEditButton
                objectName: "wallpaper-topbar-edit"
                anchors.fill: parent
                radius: width / 2
                icon: "\uf044"
                iconSize: 22
                horizontalPadding: 0
                description: "Edit wallpaper (E)"
                showTooltip: false
                idleColor: Theme.hoverMuted
                hoverColor: Theme.hoverMuted
                pressedColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.22))
                foregroundColor: Theme.fg
                hoverForegroundColor: Theme.fg
                disabledForegroundColor: Theme.fg
                disabledOpacity: 1
                border.width: 0
                hoverScaleDelta: 0.05
                hoverXScaleDelta: 0
                pressScaleDelta: 0.03
                pressXScaleDelta: 0
                onClicked: if (actionState.selectedStack) root.editRequested(actionState.selectedStack)
                Settings.SettingsTooltip {
                    objectName: "wallpaper-topbar-edit-tooltip"
                    target: topbarEditButton
                    text: topbarEditButton.description
                    x: target ? Math.min((target.width - width) / 2, target.width - width) : 0
                    y: -height - 8
                    active: topbarEditButton.hovered && topbarEditButton.enabled && topbarEditButton.visible
                }
            }
        }
    }

    // Mode 2 Leftbar: dock Layer switcher and Edit button beneath cards in the bottom-right corner.
    Item {
        id: leftCornerActions
        objectName: "wallpaper-leftbar-corner-actions"
        z: 0
        // Drive visibility from reveal progress instead of child.visible to avoid QML parent/child visibility deadlock.
        readonly property bool editShown: leftEditHost.reveal > 0.01
        readonly property bool layerShown: leftLayerHost.reveal > 0.01
        visible: root.workspace && root.vertical && (editShown || layerShown)
        readonly property real selectedHeight: root.cardWidth * root.selectedScale * 9 / 16
        readonly property real nearWidth: root.cardWidth * root.nearScale
        readonly property real selectedBottom: root.cornerCurve.selected.y + selectedHeight / 2
        readonly property real leftCardRight: root.cornerCurve.left.x + nearWidth / 2
        readonly property real pocketLeft: leftCardRight + Theme.spaceMd
        readonly property real pocketRight: root.width - Theme.pad
        readonly property real pocketTop: selectedBottom + Theme.spaceSm
        readonly property real pocketBottom: root.height - Theme.pad
        readonly property real pocketWidth: Math.max(48, pocketRight - pocketLeft)
        readonly property real pocketHeight: Math.max(46, pocketBottom - pocketTop)
        readonly property real rowWidth: (layerShown ? leftLayerPill.width + Theme.spaceSm : 0)
            + (editShown ? leftEditHost.width : 0)
        width: Math.min(pocketWidth, Math.max(46, rowWidth))
        height: Math.min(pocketHeight, 48)
        x: pocketRight - width
        y: Math.max(pocketTop, Math.round(pocketTop + (pocketHeight - height) / 2))

        Item {
            id: leftLayerHost
            property real reveal: actionState.showWorkspaceLayers ? 1 : 0
            Behavior on reveal {
                NumberAnimation {
                    duration: HAnimation.effects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.moduleCurve
                }
            }
            visible: reveal > 0.01
            opacity: reveal
            enabled: actionState.showWorkspaceLayers
            anchors.right: leftCornerActions.editShown ? leftEditHost.left : parent.right
            anchors.rightMargin: leftCornerActions.editShown ? Theme.spaceSm : 0
            anchors.verticalCenter: parent.verticalCenter
            width: leftLayerPill.width
            height: leftLayerPill.height
            transform: [
                Scale {
                    origin.x: leftLayerHost.width
                    origin.y: leftLayerHost.height / 2
                    xScale: 0.9 + 0.1 * leftLayerHost.reveal
                    yScale: 0.9 + 0.1 * leftLayerHost.reveal
                },
                Translate {
                    y: (1 - leftLayerHost.reveal) * 8
                }
            ]
            WallpaperLayerPill {
                id: leftLayerPill
                objectName: "wallpaper-leftbar-layer-switcher"
                text: actionState.displayLayerText
                hiddenLayerActive: actionState.hiddenLayerActive
                compact: true
                maxPillWidth: Math.max(108, leftCornerActions.pocketWidth - leftEditHost.width - Theme.spaceSm)
                surfaceColor: Theme.hoverMuted
                onStepRequested: step => {
                    if (actionState.selectedStack) root.layerStepRequested(actionState.selectedStack.groupKey, step)
                }
            }
        }

        Item {
            id: leftEditHost
            property real reveal: actionState.showWorkspaceEdit ? 1 : 0
            Behavior on reveal {
                NumberAnimation {
                    duration: HAnimation.effects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.moduleCurve
                }
            }
            visible: reveal > 0.01
            opacity: reveal
            enabled: actionState.showWorkspaceEdit
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 46
            transform: [
                Scale {
                    origin.x: leftEditHost.width / 2
                    origin.y: leftEditHost.height / 2
                    xScale: 0.86 + 0.14 * leftEditHost.reveal
                    yScale: 0.86 + 0.14 * leftEditHost.reveal
                },
                Translate {
                    y: (1 - leftEditHost.reveal) * 8
                }
            ]
            WallpaperToolbarButton {
                id: leftEditButton
                objectName: "wallpaper-leftbar-edit"
                anchors.fill: parent
                radius: width / 2
                icon: "\uf044"
                iconSize: 21
                horizontalPadding: 0
                description: "Edit wallpaper (E)"
                showTooltip: false
                idleColor: Theme.hoverMuted
                hoverColor: Theme.hoverMuted
                pressedColor: Qt.tint(Theme.hoverMuted, Qt.alpha(Theme.accent, 0.22))
                foregroundColor: Theme.fg
                hoverForegroundColor: Theme.fg
                disabledForegroundColor: Theme.fg
                disabledOpacity: 1
                border.width: 0
                hoverScaleDelta: 0.05
                hoverXScaleDelta: 0
                pressScaleDelta: 0.03
                pressXScaleDelta: 0
                onClicked: if (actionState.selectedStack) root.editRequested(actionState.selectedStack)
                Settings.SettingsTooltip {
                    objectName: "wallpaper-leftbar-edit-tooltip"
                    target: leftEditButton
                    text: leftEditButton.description
                    x: target ? Math.min((target.width - width) / 2, target.width - width) : 0
                    y: -height - 8
                    active: leftEditButton.hovered && leftEditButton.enabled && leftEditButton.visible
                }
            }
        }
    }

    // Mode 1 keeps floating Edit and Layer controls anchored to the center slot with lively bounce.
    Item {
        id: selectedCardOverlay
        objectName: "wallpaper-selected-overlay"
        z: 500
        readonly property real slotWidth: root.cardWidth * root.selectedScale
        readonly property real slotHeight: slotWidth * 9 / 16
        readonly property real slotCenterX: root.vertical ? root.cornerCurve.selected.x : root.width / 2
        readonly property real slotCenterY: root.vertical ? root.cornerCurve.selected.y : root.pathCenterY(root.selectedScale)
        x: slotCenterX - slotWidth / 2
        y: slotCenterY - slotHeight / 2
        width: slotWidth
        height: slotHeight
        readonly property real morphFade: Math.max(0, 1 - root.workspaceMorph * 2.2)

        Item {
            id: editButtonHost
            property real reveal: actionState.showQuickEdit ? 1 : 0
            Behavior on reveal {
                NumberAnimation {
                    duration: HAnimation.effects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.moduleCurve
                }
            }
            visible: !root.workspace && reveal > 0.01 && selectedCardOverlay.morphFade > 0.01
            opacity: reveal * selectedCardOverlay.morphFade
            enabled: actionState.showQuickEdit && root.workspaceMorph === 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 18
            width: 56
            height: 56
            transform: [
                Scale {
                    origin.x: editButtonHost.width / 2
                    origin.y: editButtonHost.height / 2
                    xScale: (0.86 + 0.14 * editButtonHost.reveal) * root.quickEditBounceScale * (1 - root.workspaceMorph * 0.1)
                    yScale: (0.86 + 0.14 * editButtonHost.reveal) * root.quickEditBounceScale * (1 - root.workspaceMorph * 0.1)
                },
                Translate {
                    y: (1 - editButtonHost.reveal) * -8 + root.quickEditBounceY - root.workspaceMorph * 16
                }
            ]
            WallpaperToolbarButton {
                id: editButton
                objectName: "wallpaper-card-edit"
                anchors.fill: parent
                radius: width / 2
                icon: "\uf044"
                iconSize: 26
                horizontalPadding: 0
                description: "Edit wallpaper (E)"
                showTooltip: false
                idleColor: Theme.surface
                hoverColor: Theme.surface
                pressedColor: Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.18))
                foregroundColor: Theme.fg
                hoverForegroundColor: Theme.fg
                disabledForegroundColor: Theme.fg
                disabledOpacity: 1
                border.width: 0
                hoverScaleDelta: 0.05
                hoverXScaleDelta: 0
                pressScaleDelta: 0.03
                pressXScaleDelta: 0
                onClicked: if (actionState.selectedStack) root.editRequested(actionState.selectedStack)
                Settings.SettingsTooltip {
                    objectName: "wallpaper-card-edit-tooltip"
                    target: editButton
                    text: editButton.description
                    x: target ? Math.min((target.width - width) / 2, target.width - width) : 0
                    active: editButton.hovered && editButton.enabled && editButton.visible
                }
            }
        }

        Item {
            id: layerPillHost
            property real reveal: actionState.showQuickLayers ? 1 : 0
            Behavior on reveal {
                NumberAnimation {
                    duration: HAnimation.effects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.moduleCurve
                }
            }
            visible: !root.workspace && reveal > 0.01 && selectedCardOverlay.morphFade > 0.01
            opacity: reveal * selectedCardOverlay.morphFade
            enabled: actionState.showQuickLayers && root.workspaceMorph === 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 18
            height: layerSwitcher.height
            width: layerSwitcher.width
            transform: [
                Scale {
                    origin.x: layerPillHost.width / 2
                    origin.y: layerPillHost.height / 2
                    xScale: (0.9 + 0.1 * layerPillHost.reveal) * root.quickPillBounceScale * (1 - root.workspaceMorph * 0.1)
                    yScale: (0.9 + 0.1 * layerPillHost.reveal) * root.quickPillBounceScale * (1 - root.workspaceMorph * 0.1)
                },
                Translate {
                    y: (1 - layerPillHost.reveal) * 10 + root.quickPillBounceY + root.workspaceMorph * 16
                }
            ]

            WallpaperLayerPill {
                id: layerSwitcher
                objectName: "wallpaper-layer-switcher"
                text: actionState.displayLayerText
                hiddenLayerActive: actionState.hiddenLayerActive
                compact: false
                maxPillWidth: Math.max(120, selectedCardOverlay.width - 36)
                surfaceColor: Qt.alpha(Theme.surface, 0.94)
                onStepRequested: step => {
                    if (actionState.selectedStack) root.layerStepRequested(actionState.selectedStack.groupKey, step)
                }
            }
        }
    }
    // Dragging updates selection after snapping, without overriding a shared-state change.
    onMovementStarted: { stopIntro(); resetWheelState() }
    onMovementEnded: WallpaperLibrary.selectIndex(currentIndex)
    Connections {
        target: WallpaperLibrary
        function onSelectedIndexChanged() { root.currentIndex = WallpaperLibrary.selectedIndex }
    }
    MouseArea {
        anchors.fill: parent
        z: 1000
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            var ax = event.angleDelta.x
            var ay = event.angleDelta.y
            var raw = Math.abs(ax) > Math.abs(ay) ? ax : ay
            if (!raw && (event.pixelDelta.x || event.pixelDelta.y)) {
                var px = Math.abs(event.pixelDelta.x) > Math.abs(event.pixelDelta.y) ? event.pixelDelta.x : event.pixelDelta.y
                raw = px * 2
            }
            if (!raw) {
                event.accepted = true
                return
            }
            var stepDir = raw < 0 ? 1 : -1
            if ((root.wheelDeltaAccum > 0 && raw < 0) || (root.wheelDeltaAccum < 0 && raw > 0))
                root.wheelDeltaAccum = 0
            if ((root.pendingWheelSteps > 0 && stepDir < 0) || (root.pendingWheelSteps < 0 && stepDir > 0))
                root.pendingWheelSteps = 0
            root.wheelDeltaAccum += raw
            wheelAccumResetTimer.restart()
            while (Math.abs(root.wheelDeltaAccum) >= 120) {
                var unit = root.wheelDeltaAccum < 0 ? 1 : -1
                root.wheelDeltaAccum -= (root.wheelDeltaAccum < 0 ? -120 : 120)
                if (Math.abs(root.pendingWheelSteps) < 4)
                    root.pendingWheelSteps += unit
            }
            if (root.pendingWheelSteps !== 0 && !wheelStepTimer.running) {
                root.drainWheelStep()
                if (root.pendingWheelSteps !== 0) wheelStepTimer.start()
            }
            event.accepted = true
        }
    }
    Text {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: !WallpaperLibrary.filteredItems.length
        text: WallpaperLibrary.loading ? "Loading your collection…" : WallpaperLibrary.loadError || "No wallpapers found"
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
    }
}
