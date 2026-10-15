import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "base" as Base
import "base/SafeZoneGeometry.js" as SafeZoneGeometry
import "flare"
import "flare/FlareGeometry.js" as FlareGeometry
import "notification"

PanelWindow {
    id: root
    required property var modelData
    readonly property var panelState: UiState.notificationPanel
    readonly property bool panelOpen: NotificationStore._started
        && UiState.activePanel === "notifications"
        && panelState !== null && panelState.screenName === modelData.name
    property bool closing: false
    readonly property var liveSafeZones: {
        var empty = SafeZoneGeometry.rect(0, 0, 0, 0)
        var anchorVisual = SafeZoneGeometry.rect(anchorProxy.x, 0,
            anchorProxy.width, Theme.topBarHeight)
        var target = FlareGeometry.resolveSpan({ anchorStart: anchorProxy.x,
            anchorEnd: anchorProxy.x + anchorProxy.width, contentW: flare.naturalContentWidth,
            padX: flare.horizontalPadding * 2, minW: 80, maxW: flare.maxWidth,
            bounds: flare.wBounds, snap: 2 * Theme.hugRadius })
        var current = SafeZoneGeometry.rect(flare.start, FlareEdges.topOriginY,
            Math.max(0, flare.end - flare.start),
            Math.max(flare.currentHeight, flare.naturalContentHeight + 16) + Theme.hugRadius)
        var expected = SafeZoneGeometry.rect(target.start, FlareEdges.topOriginY,
            flare.naturalContentWidth > 0 ? target.end - target.start : 0, current.height)
        var bodyVisual = SafeZoneGeometry.unionBounds(current, expected)
        var retained = flare.interactionEnvelope
        if (retained.end > retained.start)
            bodyVisual = SafeZoneGeometry.unionBounds(bodyVisual, SafeZoneGeometry.rect(
                retained.start, FlareEdges.topOriginY, retained.end - retained.start,
                retained.height + Theme.hugRadius))
        return [SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(anchorVisual,
                    Interaction.safeZoneAnchorMargin), width, height),
                bodyVisual.width ? SafeZoneGeometry.clampRect(SafeZoneGeometry.verticalBridge(
                    anchorVisual, bodyVisual, Interaction.safeZoneCorridorWidth), width, height) : empty,
                bodyVisual.width ? SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(bodyVisual,
                    Interaction.safeZoneMargin), width, height) : empty]
    }
    property var frozenSafeZones: []
    onLiveSafeZonesChanged: if (panelOpen && !closing) frozenSafeZones = liveSafeZones
    readonly property var safeZones: closing && !panelOpen ? frozenSafeZones : liveSafeZones
    function safeZone(index) { return safeZones[index] || SafeZoneGeometry.rect(0, 0, 0, 0) }

    Base.SafeZoneController {
        id: lifetime
        active: root.panelOpen
        closing: root.closing
        containsPoint: function(x, y) { return SafeZoneGeometry.containsAny(root.safeZones, x, y) }
        onCloseRequested: UiState.closeNotifications()
    }

    screen: modelData
    anchors { top: true; bottom: true; right: true }
    margins.right: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-notification-center"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: Math.max(0, Math.min(520, modelData.width - Theme.pad * 2))
    visible: panelOpen || closing
    mask: Region {
        Region {
            x: root.safeZone(0).x; y: root.safeZone(0).y
            width: root.panelOpen || root.closing ? root.safeZone(0).width : 0
            height: root.panelOpen || root.closing ? root.safeZone(0).height : 0
        }
        Region {
            x: root.safeZone(1).x; y: root.safeZone(1).y
            width: root.panelOpen || root.closing ? root.safeZone(1).width : 0
            height: root.panelOpen || root.closing ? root.safeZone(1).height : 0
        }
        Region {
            x: root.safeZone(2).x; y: root.safeZone(2).y
            width: root.panelOpen || root.closing ? root.safeZone(2).width : 0
            height: root.panelOpen || root.closing ? root.safeZone(2).height : 0
        }
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            closing = false
            NotificationStore.hidePopups()
            Qt.callLater(function() { if (root.panelOpen) keyHandler.forceActiveFocus() })
        } else if (flare.currentHeight > 0) {
            closing = true
        }
    }
    Component.onDestruction: UiState.closeNotificationsIfScreen(modelData.name)

    HoverHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onHoveredChanged: {
            if (!hovered) lifetime.pointerExited()
            else {
                lifetime.pointerEntered(point.position.x, point.position.y)
                keyHandler.forceActiveFocus()
            }
        }
        onPointChanged: lifetime.pointerMoved(point.position.x, point.position.y)
    }

    MouseArea {
        x: root.safeZone(0).x; y: root.safeZone(0).y
        width: root.panelOpen ? root.safeZone(0).width : 0
        height: root.panelOpen ? root.safeZone(0).height : 0
        onClicked: UiState.closeNotifications()
    }

    Base.SafeZoneDebugOverlay {
        anchors.fill: parent
        z: 999
        closePending: lifetime.closePending
        zones: root.safeZones.map(function(zone, index) {
            return { rect: zone, kind: index === 0 ? "anchor"
                : index === 1 ? "corridor"
                : flare.interactionEnvelope.height > flare.currentHeight + 1
                    ? "animation" : "surface" }
        })
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.panelOpen
        Keys.onPressed: lifetime.beginKeyboardLease()
        Keys.onEscapePressed: UiState.closeNotifications()
    }

    Item {
        id: anchorProxy
        x: root.panelState
           ? root.panelState.anchorX - (root.modelData.width - root.width)
           : root.width - Theme.pad
        width: root.panelState ? root.panelState.anchorWidth : 1
        height: 1
        visible: false
    }

    FlareHost {
        id: flare
        y: FlareEdges.topOriginY
        width: root.width
        height: root.height - FlareEdges.topOriginY
        anchorItem: anchorProxy
        shown: root.panelOpen
        content: centerComponent
        contentProps: ({ maxHeight: Math.max(0, root.modelData.height - FlareEdges.topOriginY
                                              - Theme.pad * 2 - Theme.hugRadius),
                         maxWidth: Math.max(0, root.width - 50) })
        contentKey: "notifications"
        maxWidth: Math.min(500, Math.max(0, root.width - FlareEdges.thickness * 2))
        wBounds: ({ start: 0, end: root.width })
        horizontalPadding: 22
        onSettled: (isShown) => {
            if (!isShown && !root.panelOpen) root.closing = false
        }
    }

    Component {
        id: centerComponent
        NotificationCenterContent { onKeyboardInteraction: lifetime.beginKeyboardLease() }
    }
}
