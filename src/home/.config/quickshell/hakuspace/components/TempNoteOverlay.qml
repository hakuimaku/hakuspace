import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../services"
import "sidebar" as Sidebar
import "flare" as Flare

PanelWindow {
    id: root
    // Release only after the surface has finished its visual close.
    readonly property bool releaseReady: !panelOpen && !morphAnim.running && morphProgress === 0
    // Bind each surface to its Quickshell output.
    required property var modelData
    // Display the shared scratch editor only on its owning output.
    readonly property bool panelOpen: UiState.tempNoteOpen && UiState.tempNoteScreenName === modelData.name
    // Keep the editor layout fixed while the visual chassis changes shape.
    readonly property real cardWidth: Math.max(1, Math.min(460, width))
    readonly property real cardHeight: Math.max(1, Math.min(330, height))
    // Keep the entire card within the current output geometry.
    readonly property real maxCardX: Math.max(0, width - cardWidth)
    readonly property real maxCardY: Math.max(0, height - cardHeight)
    // Start near the Sidebar while keeping one canonical default position.
    readonly property real defaultX: Math.min(120, maxCardX)
    readonly property real defaultY: Math.min(200, maxCardY)
    // Keep drag movement transient and clamp it through the card's bindings.
    property point dragOffset: Qt.point(0, 0)
    // Drive reversible opening and closing from one animation value.
    property real morphProgress: 0
    // Defer an explicit keyboard handoff until the editor is interactive.
    property bool focusPending: false
    // Claim keyboard input only after an explicit Sidebar handoff.
    property bool keyboardRequested: false
    // Bound overshoot from the shared Sidebar easing before computing geometry.
    readonly property real revealProgress: Math.max(0, Math.min(1, morphProgress))
    // Release the connecting flare as the card reaches its floating position.
    readonly property real neckProgress: Math.max(0, Math.min(1, (1 - revealProgress) / 0.35))
    // Show content after the chassis has expanded enough to contain it.
    readonly property real contentProgress: Math.max(0, (revealProgress - 0.55) / 0.45)
    // Accept editor input only after geometry has settled.
    readonly property bool interactionReady: panelOpen && !morphAnim.running && revealProgress === 1
    // Start the chassis as a small capsule on the rounded-screen rail.
    readonly property real seedSize: Math.min(Theme.fontSize * 3, cardWidth, cardHeight)
    readonly property real seedX: Math.min(ScreenGeometry.leftInset, Math.max(0, width - seedSize))

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
    WlrLayershell.namespace: "hakuspace-temp-note"
    WlrLayershell.keyboardFocus: !panelOpen ? WlrKeyboardFocus.None
        : UiState.ownsInteraction("tempNote", modelData.name) ? WlrKeyboardFocus.Exclusive
        : interactionReady ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen || morphProgress > 0.001
    // The opening capsule must not intercept the Sidebar button beneath it.
    mask: Region { item: root.interactionReady ? noteCard : null; radius: noteCard.radius }

    // Reset transient coordinates whenever ownership ends or a note opens.
    function resetPosition() {
        dragOffset = Qt.point(0, 0)
    }

    // Route every explicit close through the shared flush/reset lifecycle.
    function requestClose() {
        UiState.closeTempNoteIfScreen(modelData.name)
    }

    // Publish geometry as data so passive notes do not retain other surface objects.
    function publishRect() {
        if (panelOpen && interactionReady) UiState.tempNoteRect = Qt.rect(noteCard.x, noteCard.y, noteCard.width, noteCard.height)
    }
    onInteractionReadyChanged: publishRect()
    onPanelOpenChanged: {
        morphAnim.stop()
        focusPending = false
        keyboardRequested = false
        if (panelOpen && morphProgress <= 0.001) resetPosition()
        morphAnim.to = panelOpen ? 1 : 0
        morphAnim.duration = Math.round((panelOpen ? HAnimation.sidebarToolOpenDuration
            : HAnimation.sidebarToolCloseDuration) * Math.abs(morphAnim.to - morphProgress))
        morphAnim.easing.bezierCurve = panelOpen ? HAnimation.sidebarToolOpenCurve : HAnimation.sidebarToolCloseCurve
        morphAnim.start()
    }
    Component.onDestruction: UiState.closeTempNoteIfScreen(modelData.name)

    Connections {
        target: UiState
        // Reserve Escape during opening; focus the editor when its geometry settles.
        function onTempNoteFocusRequested(screenName) {
            if (!root.panelOpen || screenName !== root.modelData.name) return
            root.focusPending = true
            UiState.claimInteraction("tempNote", root.modelData.name)
            noteCard.forceActiveFocus()
            if (root.interactionReady) root.takeFocus()
        }
        // Flush composition before another visible surface takes keyboard input.
        function onInteractionReleasing(owner, screenName) {
            if (owner !== "tempNote" || screenName !== root.modelData.name) return
            noteContent.finishEditing()
            root.keyboardRequested = false
            root.focusPending = false
        }
        // Finish editing before state hides this surface or transfers ownership.
        function onTempNoteClosing(screenName) {
            if (screenName !== root.modelData.name) return
            noteContent.finishEditing()
        }
        // Drop the old visual immediately when another output takes ownership.
        function onTempNoteScreenNameChanged() {
            if (!UiState.tempNoteScreenName.length || UiState.tempNoteScreenName === root.modelData.name) return
            morphAnim.stop()
            root.morphProgress = 0
            root.resetPosition()
        }
    }

    // A passive note may receive pointer focus, then atomically takes the shared lease.
    Connections {
        target: root.contentItem.Window.window
        function onActiveChanged() {
            if (root.contentItem.Window.active && root.interactionReady
                    && !UiState.ownsInteraction("tempNote", root.modelData.name)) root.takeFocus()
        }
    }

    // Claim input only when the opening animation has completed.
    function takeFocus() {
        if (!interactionReady) return
        focusPending = false
        keyboardRequested = true
        UiState.claimInteraction("tempNote", modelData.name)
        noteContent.forceFocus()
    }

    NumberAnimation {
        id: morphAnim
        target: root
        property: "morphProgress"
        onFinished: {
            if (root.panelOpen && root.focusPending) {
                root.takeFocus()
            } else if (!root.panelOpen) root.resetPosition()
        }
    }

    // Keep the connecting flare below the Sidebar's interactive Overlay surface.
    PanelWindow {
        objectName: "tempNoteFlareLayer"
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-temp-note-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        visible: root.visible && root.revealProgress > 0.001 && root.neckProgress > 0.001
        mask: Region {}

        // Rotate the ceiling flare into a temporary connection to the left rail.
        Flare.FlareSurface {
            // Pinch the neck symmetrically around the card's vertical center.
            readonly property real span: Math.min(noteCard.height, root.seedSize + noteCard.height * root.revealProgress) * root.neckProgress
            x: root.seedX
            y: noteCard.y + noteCard.height
            rotation: -90
            transformOrigin: Item.TopLeft
            start: (noteCard.height - span) / 2
            end: start + span
            currentHeight: Math.max(0, noteCard.x - root.seedX + noteCard.radius)
            r: Math.min(Theme.hugRadius, (end - start) / 2)
            rf: 0
            bottomRadius: r
            bounds: ({start: start - r, end: end + r})
            surfaceColor: Theme.surface
        }
    }

    Rectangle {
        id: noteCard
        onXChanged: root.publishRect()
        onYChanged: root.publishRect()
        x: root.seedX + (Math.max(0, Math.min(root.maxCardX, root.defaultX + root.dragOffset.x)) - root.seedX) * root.revealProgress
        y: Math.max(0, Math.min(root.maxCardY, root.defaultY + root.dragOffset.y)) + (root.cardHeight - height) / 2
        width: root.seedSize + (root.cardWidth - root.seedSize) * root.revealProgress
        height: root.seedSize + (root.cardHeight - root.seedSize) * root.revealProgress
        radius: Math.min(width / 2, height / 2, root.seedSize / 2 + (Theme.largeRadius - root.seedSize / 2) * root.revealProgress)
        opacity: Math.min(1, root.revealProgress / 0.12)
        enabled: root.panelOpen
        TapHandler { onPressedChanged: if (pressed) root.takeFocus() }
        color: Theme.surface
        border.width: 3 * (1 - root.neckProgress)
        border.color: Theme.accent
        clip: true
        Keys.onEscapePressed: root.requestClose()

        // Reveal stable-size content without resizing the TextArea during the morph.
        Item {
            width: root.cardWidth
            height: root.cardHeight
            opacity: root.contentProgress
            enabled: root.interactionReady

            MouseArea {
                anchors.fill: parent
                onClicked: root.takeFocus()
            }

            // Only the small top-center handle can move the card.
            Item {
                id: dragHandle
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: Theme.controlHeight
                Accessible.role: Accessible.Grip
                Accessible.name: "Move Temp Note"
                HoverHandler { cursorShape: cardDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 4
                    radius: 2
                    color: Theme.fgMuted
                }
                DragHandler {
                    id: cardDrag
                    target: null
                    // Measure each gesture from the card's current visible position.
                    property point startPosition: Qt.point(0, 0)
                    acceptedButtons: Qt.LeftButton
                    maximumPointCount: 1
                    onActiveChanged: if (active) startPosition = Qt.point(noteCard.x, noteCard.y)
                    onActiveTranslationChanged: if (active) root.dragOffset = Qt.point(
                        Math.max(0, Math.min(root.maxCardX, startPosition.x + activeTranslation.x)) - root.defaultX,
                        Math.max(0, Math.min(root.maxCardY, startPosition.y + activeTranslation.y)) - root.defaultY)
                }
            }

            Sidebar.SidebarMorphButton {
                anchors { top: parent.top; right: parent.right; margins: 16 }
                width: Theme.controlHeight
                height: Theme.controlHeight
                radius: Theme.controlHeight / 2
                text: "×"
                fontSize: 16
                activeFocusOnTab: true
                focused: activeFocus
                Accessible.role: Accessible.Button
                Accessible.name: "Close Temp Note"
                onClicked: root.requestClose()
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
                Keys.onEscapePressed: root.requestClose()
            }

            Sidebar.SidebarTempNote {
                id: noteContent
                anchors { top: dragHandle.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.margins: 16
                anchors.topMargin: 16
                onInteractionRequested: root.takeFocus()
                onCloseRequested: root.requestClose()
            }
        }
    }
}
