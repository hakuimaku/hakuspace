import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../services"
import "sidebar" as Sidebar
import "flare" as Flare
import "taskmanager" as TaskManager
import "taskmanager/glassgrid/TaskManagerMotion.js" as Motion

PanelWindow {
    id: root
    // Route this floating utility to exactly one output.
    required property var modelData
    readonly property bool panelOpen: UiState.taskManagerOpen && UiState.taskManagerScreenName === modelData.name
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    // Keep a stable drawing window and morph the floating card directly from a left-rail seed capsule (no opacity fade).
    property real morphProgress: 0
    readonly property alias motionProgress: root.morphProgress
    readonly property alias reveal: root.morphProgress
    readonly property real revealProgress: Math.max(0, Math.min(1, morphProgress))
    readonly property real neckProgress: Math.max(0, Math.min(1, (1 - revealProgress) / 0.35))
    readonly property bool releaseReady: !panelOpen && !morphAnim.running && morphProgress === 0
    readonly property bool interactionReady: panelOpen && morphProgress === 1 && !morphAnim.running
    // Clamp geometry against real outputs, including screens smaller than the minimum.
    property size cardSize: Qt.size(980, 680)
    property point position: Qt.point(80, 60)
    readonly property real cardWidth: Math.max(1, Math.min(cardSize.width, width))
    readonly property real cardHeight: Math.max(1, Math.min(cardSize.height, height))
    readonly property real seedSize: Math.min(Theme.fontSize * 3, cardWidth, cardHeight)
    readonly property real seedX: Math.min(ScreenGeometry.leftInset, Math.max(0, width - seedSize))
    readonly property real targetX: Math.max(0, Math.min(width - cardWidth, position.x))
    readonly property real targetY: Math.max(0, Math.min(height - cardHeight, position.y))
    readonly property bool ownsKeyboard: UiState.ownsInteraction("taskManager", modelData.name)
    readonly property int shellMargin: (cardWidth < 760 || cardHeight < 500) ? 12 : ((cardWidth < 880 || cardHeight < 580) ? 15 : 18)
    readonly property int headerGap: (cardWidth < 760 || cardHeight < 500) ? 8 : ((cardWidth < 880 || cardHeight < 580) ? 12 : 15)
    // Expose the inner content for focused lifecycle probes.
    readonly property alias content: content

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
    WlrLayershell.namespace: "hakuspace-task-manager"
    WlrLayershell.keyboardFocus: interactionReady ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen || morphProgress > 0
    mask: Region { item: root.panelOpen ? card : null; radius: card.radius }

    // Keep the connecting flare below the Sidebar's interactive Overlay surface.
    PanelWindow {
        objectName: "taskManagerFlareLayer"
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-task-manager-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        visible: root.visible && root.revealProgress > 0.001 && root.neckProgress > 0.001
        mask: Region {}

        // Rotate the ceiling flare into a temporary connection to the left rail.
        Flare.FlareSurface {
            // Pinch the neck symmetrically around the card's vertical center.
            readonly property real span: Math.min(card.height, root.seedSize + card.height * root.revealProgress) * root.neckProgress
            x: root.seedX
            y: card.y + card.height
            rotation: -90
            transformOrigin: Item.TopLeft
            start: (card.height - span) / 2
            end: start + span
            currentHeight: Math.max(0, card.x - root.seedX + card.radius)
            r: Math.min(Theme.hugRadius, (end - start) / 2)
            rf: 0
            bottomRadius: r
            bounds: ({start: start - r, end: end + r})
            surfaceColor: Theme.surface
        }
    }

    // Publish only geometry data; other surfaces never retain this window.
    function publishRect() {
        if (panelOpen) UiState.taskManagerRect = Qt.rect(card.x, card.y, card.width, card.height)
    }
    // Claim the shared input lease without closing any other floating surface.
    function takeFocus() {
        if (!panelOpen) return
        UiState.claimInteraction("taskManager", modelData.name)
        content.forceFocus()
    }
    // Deterministically set morphProgress for testing or mid-motion inspection.
    function setMorphProgress(value) {
        morphAnim.stop()
        root.morphProgress = Motion.clamp01(value)
    }
    function setMotionProgress(value) {
        setMorphProgress(value)
    }
    // Animate reversible capsule-to-card morph transitions from the current morphProgress.
    function syncOpen() {
        morphAnim.stop()
        var target = panelOpen ? 1 : 0
        var baseMs = panelOpen ? HAnimation.sidebarToolOpenDuration : HAnimation.sidebarToolCloseDuration
        var dur = Motion.reversibleDuration(baseMs, revealProgress, target, root.reducedMotion)
        if (dur <= 0) {
            morphProgress = target
        } else {
            morphAnim.to = target
            morphAnim.duration = dur
            morphAnim.easing.type = Easing.BezierSpline
            morphAnim.easing.bezierCurve = panelOpen ? HAnimation.sidebarToolOpenCurve : HAnimation.sidebarToolCloseCurve
            morphAnim.start()
        }
        publishRect()
        if (panelOpen) {
            content.resetVisualState()
            takeFocus()
        }
    }
    onPanelOpenChanged: syncOpen()
    Component.onCompleted: { TaskManagerService.acquire(); syncOpen() }
    Component.onDestruction: {
        TaskManagerService.release()
        UiState.closeTaskManagerIfScreen(modelData.name)
    }

    Connections {
        target: UiState
        function onTaskManagerFocusRequested(screenName) {
            if (screenName === root.modelData.name) root.takeFocus()
        }
        function onTaskManagerScreenNameChanged() {
            if (UiState.taskManagerScreenName && UiState.taskManagerScreenName !== root.modelData.name) {
                morphAnim.stop(); root.morphProgress = 0
            }
        }
        function onInteractionReleasing(owner, screenName) {
            if (owner === "taskManager" && screenName === root.modelData.name) content.focus = false
        }
    }
    // Pointer focus on a passive utility restores its lease; application focus releases it.
    Connections {
        target: root.contentItem.Window.window
        function onActiveChanged() {
            if (!root.contentItem.Window.active) UiState.releaseInteraction("taskManager", root.modelData.name)
            else if (root.panelOpen && !root.ownsKeyboard) root.takeFocus()
        }
    }
    NumberAnimation {
        id: morphAnim
        target: root
        property: "morphProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.sidebarToolOpenCurve
        onFinished: if (root.panelOpen && root.ownsKeyboard) content.forceFocus()
    }

    Rectangle {
        id: card
        objectName: "taskManagerCard"
        width: root.seedSize + (root.cardWidth - root.seedSize) * root.revealProgress
        height: root.seedSize + (root.cardHeight - root.seedSize) * root.revealProgress
        x: root.seedX + (root.targetX - root.seedX) * root.revealProgress
        y: root.targetY + (root.cardHeight - height) / 2
        radius: Math.min(width / 2, height / 2, root.seedSize / 2 + (Theme.largeRadius - root.seedSize / 2) * root.revealProgress)
        color: Theme.surface
        border.width: 0
        opacity: 1
        enabled: root.interactionReady
        clip: true
        onXChanged: root.publishRect()
        onYChanged: root.publishRect()
        onWidthChanged: root.publishRect()
        onHeightChanged: root.publishRect()
        // Observe presses before controls consume them, then pass the event through.
        MouseArea {
            anchors.fill: parent
            z: 10000
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => { if (root.interactionReady) { root.takeFocus(); mouse.accepted = false } }
        }

        // Fixed-size inner chassis so internal layouts never reflow while the outer card morphs from capsule to panel.
        Item {
            id: cardSurface
            objectName: "taskManagerShellSurface"
            x: 0
            y: 0
            width: root.cardWidth
            height: root.cardHeight

            Item {
                id: header
                objectName: "taskManagerHeader"
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: root.shellMargin
                    leftMargin: root.shellMargin
                    rightMargin: root.shellMargin
                }
                height: 26

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Task Manager"
                        color: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.88 : 0.90)
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Math.max(13, Theme.fontSize - (root.cardWidth < 760 ? 1 : 0))
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 4
                        radius: 2
                        border.width: 0
                        color: TaskManagerService.error
                            ? Theme.danger
                            : (root.ownsKeyboard ? Theme.accent : Qt.alpha(Theme.fgMuted, 0.5))
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: TaskManagerService.error ? "Error" : (TaskManagerService.warmingUp ? "Warming up…" : "Live")
                        color: TaskManagerService.error ? Theme.danger : Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(11, Theme.fontSize - 3)
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: 120
                    height: parent.height
                    Accessible.role: Accessible.Grip
                    Accessible.name: "Move Task Manager"
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32
                        height: 3
                        radius: 1.5
                        border.width: 0
                        color: Qt.alpha(Theme.fgMuted, 0.45)
                    }
                    HoverHandler { cursorShape: mover.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
                    DragHandler {
                        id: mover
                        target: null
                        // Freeze the drag origin for the whole gesture.
                        property point startPosition: Qt.point(0, 0)
                        onActiveChanged: if (active) startPosition = Qt.point(root.targetX, root.targetY)
                        onActiveTranslationChanged: if (active) root.position = Qt.point(
                            Math.max(0, Math.min(root.width - root.cardWidth, startPosition.x + activeTranslation.x)),
                            Math.max(0, Math.min(root.height - root.cardHeight, startPosition.y + activeTranslation.y)))
                    }
                }

                Sidebar.SidebarMorphButton {
                    objectName: "taskManagerCloseButton"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 6
                    border.width: 0
                    hoverScaleDelta: 0
                    pressScaleDelta: 0
                    fontSize: Math.max(12, Theme.fontSize - 2)
                    idleColor: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.05 : 0.038)
                    foregroundColor: Theme.fgMuted
                    hoverColor: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.09 : 0.075)
                    hoverForegroundColor: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.92 : 0.95)
                    focusColor: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.11 : 0.095)
                    focusForegroundColor: Theme.accent
                    text: "×"
                    activeFocusOnTab: true
                    focused: activeFocus
                    Accessible.role: Accessible.Button
                    Accessible.name: "Close Task Manager"
                    onClicked: UiState.closeTaskManagerIfScreen(root.modelData.name)
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    Keys.onEscapePressed: if (root.ownsKeyboard) UiState.closeTaskManagerIfScreen(root.modelData.name)
                }
            }

            TaskManager.TaskManagerContent {
                id: content
                interactionOwned: root.ownsKeyboard
                reducedMotion: root.reducedMotion
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: root.headerGap
                    leftMargin: root.shellMargin
                    rightMargin: root.shellMargin
                    bottomMargin: Math.max(18, root.shellMargin + 4)
                }
                onCloseRequested: UiState.closeTaskManagerIfScreen(root.modelData.name)
            }

            Item {
                anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
                width: 24; height: 24
                Accessible.role: Accessible.Grip
                Accessible.name: "Resize Task Manager"
                HoverHandler { cursorShape: Qt.SizeFDiagCursor }
                Text {
                    anchors.centerIn: parent
                    text: "◢"
                    color: Qt.alpha(Theme.fgMuted, 0.55)
                    font.pixelSize: 10
                }
                DragHandler {
                    target: null
                    // Preserve the upper-left corner while resizing to the remaining output area.
                    property size startSize: Qt.size(0, 0)
                    property point startPosition: Qt.point(0, 0)
                    onActiveChanged: if (active) {
                        startSize = Qt.size(root.cardWidth, root.cardHeight)
                        startPosition = Qt.point(root.targetX, root.targetY)
                    }
                    onActiveTranslationChanged: if (active) {
                        root.cardSize = Qt.size(
                            Math.min(root.width - startPosition.x, Math.max(720, startSize.width + activeTranslation.x)),
                            Math.min(root.height - startPosition.y, Math.max(480, startSize.height + activeTranslation.y)))
                        root.position = startPosition
                    }
                }
            }
        }
    }
}
