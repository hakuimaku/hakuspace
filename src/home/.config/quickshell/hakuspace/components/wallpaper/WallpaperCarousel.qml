import QtQuick
import "../../services"

PathView {
    id: root
    // Leftbar uses three still-image delegates; horizontal presentations keep five.
    property string presentation: "quick"
    readonly property bool workspace: presentation === "workspace"
    // Wait for the bounded visible delegates before revealing a cold workspace.
    readonly property bool thumbnailsSettled: !count || !!currentItem && currentItem.parent.children
        .filter(item => item.wallpaper !== undefined && item.visible).every(item => item.thumbnailSettled)
    // Vertical workspace paths keep card artwork and hit targets upright.
    property bool vertical: false
    // The Leftbar adapter owns static card bounds and curve anchors.
    property var leftLayout: null
    property real spread: 1
    property real selectedPulse: 1
    signal applyRequested()
    readonly property real contentPadding: vertical && leftLayout ? leftLayout.padding : workspace ? 8 : 0
    // Workspace cards use the bottom rail and rise gradually toward the selection.
    readonly property real selectedScale: vertical && leftLayout ? leftLayout.selectedScale : workspace ? 1.32 : 1
    readonly property real cardWidth: vertical ? (leftLayout ? leftLayout.cardWidth : 1) : workspace
        ? Math.max(80, Math.min(width / 5.2, height * 16 / 9 * 0.95, 360))
        : Math.max(80, Math.min(width * 0.56, (height - 32) * 16 / 9, 920))
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
    onCountChanged: tryIntro()
    onCurrentIndexChanged: tryIntro()
    onEnabledChanged: {
        if (!enabled) pauseIntro()
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
    onModelChanged: Qt.callLater(resetPosition)
    function resetPosition() {
        currentIndex = WallpaperLibrary.selectedIndex
        if (currentIndex >= 0) positionViewAtIndex(currentIndex, PathView.Center)
    }
    // Keep input timing separate from decorative animation progress.
    property double lastMoveAt: 0
    // Match input cadence and preserve direction instead of falling behind a held key.
    function move(step) {
        stopIntro()
        var now = Date.now()
        highlightMoveDuration = Math.min(HAnimation.effects, Math.max(16, now - lastMoveAt))
        lastMoveAt = now
        movementDirection = step === 1 ? PathView.Positive : step === -1 ? PathView.Negative : PathView.Shortest
        WallpaperLibrary.move(step)
        movementDirection = PathView.Shortest
        highlightMoveDuration = HAnimation.effects
    }
    currentIndex: WallpaperLibrary.selectedIndex
    pathItemCount: vertical ? 3 : 5
    cacheItemCount: 0
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange
    highlightMoveDuration: HAnimation.effects
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
        readonly property real orbitPhase: Math.asin(Math.max(-1, Math.min(1, slotX / Math.max(1, root.farOffset))))
            + root.introProgress * Math.PI * 2
        readonly property real orbitOffset: root.workspace || chosen || root.introProgress >= 1
            ? 0 : Math.sin(orbitPhase) * root.farOffset - slotX
        wallpaper: modelData
        width: root.cardWidth
        chosen: PathView.isCurrentItem
        outlineSelection: root.vertical
        cornerRadius: Theme.radius + 6
        revealProgress: !root.workspace && chosen ? root.introProgress : 1
        decodeScale: root.selectedScale
        pulse: !root.workspace && chosen ? root.selectedPulse : 1
        transform: Translate {
            x: root.vertical || card.chosen ? 0 : (root.spread - 1) * card.slotX + root.spread * card.orbitOffset
            y: root.vertical && !card.chosen ? (root.spread - 1) * (card.y + card.height / 2 - root.height / 2) : 0
        }
        visible: PathView.onPath
        scale: targetScale * pulse
        opacity: 1
        // Selection stays above moving neighbors throughout a vertical snap.
        z: root.vertical ? (chosen ? 2 : 1) : (PathView.cardDepth ?? 0)
        onSelected: { root.stopIntro(); WallpaperLibrary.selectIndex(index); root.forceActiveFocus() }
        onApplied: root.applyRequested()
    }
    // Dragging updates selection after snapping, without overriding a shared-state change.
    onMovementStarted: stopIntro()
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
            var delta = event.angleDelta.x || event.angleDelta.y
            if (delta) root.move(delta < 0 ? 1 : -1)
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
