import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../services"
import "sidebar" as Sidebar
import "taskmanager" as TaskManager

PanelWindow {
    id: root
    // Route this floating utility to exactly one output.
    required property var modelData
    readonly property bool panelOpen: UiState.taskManagerOpen && UiState.taskManagerScreenName === modelData.name
    // Keep a stable drawing window and animate only the inner card's opacity.
    property real reveal: 0
    readonly property bool releaseReady: !panelOpen && !fade.running && reveal === 0
    readonly property bool interactionReady: panelOpen && reveal === 1 && !fade.running
    // Clamp geometry against real outputs, including screens smaller than the minimum.
    property size cardSize: Qt.size(980, 680)
    property point position: Qt.point(80, 60)
    readonly property real cardWidth: Math.max(1, Math.min(cardSize.width, width))
    readonly property real cardHeight: Math.max(1, Math.min(cardSize.height, height))
    readonly property bool ownsKeyboard: UiState.ownsInteraction("taskManager", modelData.name)
    // Expose the inner content for focused lifecycle probes.
    readonly property alias content: content

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
    WlrLayershell.namespace: "hakuspace-task-manager"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen || reveal > 0
    mask: Region { item: root.panelOpen ? card : null; radius: card.radius }

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
    // Animate reversible close/open transitions from the current opacity.
    function syncOpen() {
        fade.stop()
        fade.to = panelOpen ? 1 : 0
        fade.duration = Math.round(160 * Math.abs(fade.to - reveal))
        fade.start()
        publishRect()
        if (panelOpen) takeFocus()
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
                fade.stop(); root.reveal = 0
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
        id: fade
        target: root
        property: "reveal"
        onFinished: if (root.panelOpen && root.ownsKeyboard) content.forceFocus()
    }

    Rectangle {
        id: card
        x: Math.max(0, Math.min(root.width - width, root.position.x))
        y: Math.max(0, Math.min(root.height - height, root.position.y))
        width: root.cardWidth
        height: root.cardHeight
        radius: Theme.largeRadius
        color: Theme.surface
        border.color: Theme.accent
        border.width: root.ownsKeyboard ? 2 : 1
        opacity: root.reveal
        enabled: root.panelOpen
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
            onPressed: mouse => { root.takeFocus(); mouse.accepted = false }
        }

        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            height: 32
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Task Manager"; color: Theme.fg; font.bold: true }
            Item {
                anchors.centerIn: parent
                width: 100
                height: parent.height
                Accessible.role: Accessible.Grip
                Accessible.name: "Move Task Manager"
                Rectangle { anchors.centerIn: parent; width: 40; height: 4; radius: 2; color: Theme.fgMuted }
                HoverHandler { cursorShape: mover.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
                DragHandler {
                    id: mover
                    target: null
                    // Freeze the drag origin for the whole gesture.
                    property point startPosition: Qt.point(0, 0)
                    onActiveChanged: if (active) startPosition = Qt.point(card.x, card.y)
                    onActiveTranslationChanged: if (active) root.position = Qt.point(
                        Math.max(0, Math.min(root.width - card.width, startPosition.x + activeTranslation.x)),
                        Math.max(0, Math.min(root.height - card.height, startPosition.y + activeTranslation.y)))
                }
            }
            Sidebar.SidebarMorphButton {
                anchors.right: parent.right
                width: 32; height: 32
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
            anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12; bottomMargin: 28 }
            onCloseRequested: UiState.closeTaskManagerIfScreen(root.modelData.name)
        }
        Item {
            anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
            width: 26; height: 26
            Accessible.role: Accessible.Grip
            Accessible.name: "Resize Task Manager"
            HoverHandler { cursorShape: Qt.SizeFDiagCursor }
            Text { anchors.centerIn: parent; text: "◢"; color: Theme.fgMuted }
            DragHandler {
                target: null
                // Preserve the upper-left corner while resizing to the remaining output area.
                property size startSize: Qt.size(0, 0)
                property point startPosition: Qt.point(0, 0)
                onActiveChanged: if (active) {
                    startSize = Qt.size(card.width, card.height)
                    startPosition = Qt.point(card.x, card.y)
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
