import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../base" as Base
import "../base/SafeZoneGeometry.js" as Safe
import "HakuMenuGeometry.js" as Geometry

PanelWindow {
    id: root
    required property var modelData
    readonly property bool panelOpen: !!modelData && UiState.activePanel === "hakumenu"
        && UiState.hakuMenuStyle === "dockFloating" && UiState.hakuMenuScreenName === modelData.name
    // Snapshot seed and content so closing survives the transient state's reset.
    property var capturedAnchor: null
    property string renderMode: "drun"
    property string renderQuery: ""
    property real morphProgress: 0
    // Retain a loaded content tree so deferred list callbacks survive close/reopen.
    property bool contentLoaded: false
    readonly property real revealProgress: Math.max(0, Math.min(1, morphProgress))
    readonly property real contentProgress: Math.max(0, (revealProgress - 0.55) / 0.45)
    readonly property bool interactionReady: panelOpen && revealProgress === 1
    readonly property real floatingGap: Theme.pad * 2
    readonly property real dockBottomInset: AppState.taskbarManualState && ShellSettingsStore.dockStyle === "bar" ? 0 : ScreenGeometry.bottomInset
    readonly property var finalRect: Geometry.finalRect(width, height, ScreenGeometry.leftInset,
        (AppState.waybarManualState ? ScreenGeometry.flareTopY : 0) + floatingGap,
        dockBottomInset, AppState.taskbarManualState ? ScreenGeometry.dockHeight : 0, floatingGap)
    readonly property var seedRect: Geometry.seedRect(capturedAnchor, width, height, ShellSettingsStore.dockIconSize,
        dockBottomInset, floatingGap, finalRect)
    readonly property var currentRect: Geometry.mixRect(seedRect, finalRect, revealProgress)
    // The anchor relay leaves the rest of the Top-layer Dock available to the desktop.
    readonly property var safeZones: {
        if (!visible) return []
        var zones = [Safe.clampRect(Safe.inflate(currentRect, Interaction.safeZoneMargin), width, height),
            Safe.clampRect(Safe.inflate(finalRect, Interaction.safeZoneMargin), width, height)]
        if (capturedAnchor) zones = zones.concat([Safe.clampRect(Safe.inflate(capturedAnchor,
            Interaction.safeZoneAnchorMargin), width, height)], Safe.orthogonalBridge(finalRect, capturedAnchor, seedRect.width))
        return zones
    }
    // Missing regions stay empty when the menu uses fallback geometry.
    function zone(index) { return safeZones[index] || Safe.rect(0, 0, 0, 0) }
    // Release visual ownership immediately when another style/output opens.
    function syncOwnership() {
        if (UiState.activePanel !== "hakumenu" || panelOpen) return
        morphAnim.stop()
        morphProgress = 0
        capturedAnchor = null
    }
    // Reverse the existing scalar using the remaining distance, as Temp Note does.
    function animate() {
        morphAnim.stop()
        if (panelOpen) {
            if (morphProgress <= 0.001) capturedAnchor = UiState.hakuMenuAnchorRect
            renderMode = UiState.hakuMenuMode
            renderQuery = UiState.hakuMenuQuery
        } else if (content.item) content.item.clearSearchFocus()
        morphAnim.to = panelOpen ? 1 : 0
        morphAnim.duration = Math.round((panelOpen ? HAnimation.floatingPanelOpenDuration
            : HAnimation.floatingPanelCloseDuration) * Math.abs(morphAnim.to - morphProgress))
        morphAnim.easing.bezierCurve = panelOpen ? HAnimation.floatingPanelOpenCurve : HAnimation.floatingPanelCloseCurve
        morphAnim.start()
    }

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-hakumenu-floating"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: panelOpen || morphProgress > 0.001
    onPanelOpenChanged: {
        if (panelOpen) contentLoaded = true
        Qt.callLater(animate)
    }
    onInteractionReadyChanged: if (interactionReady && content.item) content.item.forceSearchFocus()
    Component.onDestruction: if (modelData && panelOpen) UiState.closeHakuMenuIfScreen(modelData.name)
    mask: Region {
        Region { x: root.zone(0).x; y: root.zone(0).y; width: root.zone(0).width; height: root.zone(0).height }
        Region { x: root.zone(1).x; y: root.zone(1).y; width: root.zone(1).width; height: root.zone(1).height }
        Region { x: root.zone(2).x; y: root.zone(2).y; width: root.zone(2).width; height: root.zone(2).height }
        Region { x: root.zone(3).x; y: root.zone(3).y; width: root.zone(3).width; height: root.zone(3).height }
        Region { x: root.zone(4).x; y: root.zone(4).y; width: root.zone(4).width; height: root.zone(4).height }
    }
    Connections {
        target: UiState
        function onHakuMenuScreenNameChanged() { root.syncOwnership() }
        function onHakuMenuStyleChanged() { root.syncOwnership() }
        function onActivePanelChanged() { root.syncOwnership() }
        function onHakuMenuModeChanged() { if (root.panelOpen) root.renderMode = UiState.hakuMenuMode }
        function onHakuMenuQueryChanged() { if (root.panelOpen) root.renderQuery = UiState.hakuMenuQuery }
    }
    Base.SafeZoneController {
        id: lifetime
        active: root.panelOpen
        containsPoint: function(x, y) { return Safe.containsAny(root.safeZones, x, y) }
        onCloseRequested: UiState.closeHakuMenu()
    }
    NumberAnimation {
        id: morphAnim
        target: root
        property: "morphProgress"
        onRunningChanged: {
            if (running && root.panelOpen) lifetime.beginAnimationLease()
            else lifetime.endAnimationLease()
        }
        onFinished: if (!root.panelOpen) root.capturedAnchor = null
    }
    HoverHandler {
        onHoveredChanged: {
            if (hovered) lifetime.pointerEntered(point.position.x, point.position.y)
            else lifetime.pointerExited()
        }
        onPointChanged: lifetime.pointerMoved(point.position.x, point.position.y)
    }
    Base.SafeZoneDebugOverlay {
        anchors.fill: parent
        z: 99
        closePending: lifetime.closePending
        anchorRect: root.capturedAnchor
        localizedAnchorRect: root.capturedAnchor
        zones: root.safeZones.map(function(rect) { return {rect: rect, kind: "surface"} })
    }
    Rectangle {
        id: card
        objectName: "hakumenu-floating-card"
        x: root.currentRect.x; y: root.currentRect.y
        width: root.currentRect.width; height: root.currentRect.height
        radius: Math.min(width / 2, height / 2, root.seedRect.width / 2
            + (Theme.largeRadius - root.seedRect.width / 2) * root.revealProgress)
        opacity: Math.min(1, root.revealProgress / 0.12)
        color: Theme.surface
        clip: true
        focus: root.panelOpen
        Keys.onEscapePressed: UiState.closeHakuMenu()
        MouseArea { anchors.fill: parent }
        Loader {
            id: content
            active: root.contentLoaded
            width: root.finalRect.width; height: root.finalRect.height
            opacity: root.contentProgress
            onLoaded: if (root.interactionReady) item.forceSearchFocus()
            sourceComponent: HakuMenuContent {
                panelOpen: root.panelOpen
                focusOnOpen: false
                controlsAtBottom: true
                mode: root.renderMode
                query: root.renderQuery
                onKeyboardActivity: lifetime.beginKeyboardLease()
            }
        }
        // Gate input without triggering disabled visuals in the content tree.
        MouseArea {
            anchors.fill: parent
            enabled: !root.interactionReady
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onWheel: wheel => { wheel.accepted = true }
        }
    }
    // Overlay input at the captured anchor must relay repeated App Menu clicks to Top.
    MouseArea {
        x: root.zone(2).x
        y: root.zone(2).y
        width: root.zone(2).width
        height: root.zone(2).height
        enabled: root.visible && !!root.capturedAnchor
        onClicked: UiState.toggleHakuMenu(root.modelData.name, "drun", "dockFloating", root.capturedAnchor)
    }
}
