import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "base" as Base
import "base/SafeZoneGeometry.js" as SafeZoneGeometry
import "flare"
import "flare/FlareGeometry.js" as FlareGeometry
import "notification"

Item {
    id: root
    // Release only after the surface has finished its visual close.
    readonly property bool releaseReady: !panelOpen && !closing
    readonly property var horizontalBounds: ScreenGeometry.horizontalBounds(modelData.width, hostRect)
    required property var modelData
    width: Math.max(0, Math.min(520, modelData.width - Theme.pad * 2))
    height: modelData.height
    // Partial-width windows localize the captured bell rect at one shared boundary.
    readonly property var hostRect: ({x: modelData.width - width, y: 0, width: width, height: height})
    readonly property var localAnchorRect: flare.localizedAnchorRect || ({x: 0, y: 0, width: 0, height: 0})
    readonly property var panelState: UiState.notificationPanel
    readonly property bool panelOpen: NotificationStore._started
        && UiState.activePanel === "notifications"
        && panelState !== null && panelState.screenName === modelData.name
    property bool closing: false
    property bool openedAtBottom: ScreenGeometry.bottomAttached
    readonly property var liveSafeZones: {
        var empty = SafeZoneGeometry.rect(0, 0, 0, 0)
        var anchorVisual = localAnchorRect
        var target = FlareGeometry.resolveSpan({ anchorStart: anchorVisual.x,
            anchorEnd: anchorVisual.x + anchorVisual.width, contentW: flare.naturalContentWidth,
            padX: flare.horizontalPadding * 2, minW: 80, maxW: flare.maxWidth,
            bounds: flare.wBounds, snap: 2 * Theme.hugRadius })
        var current = ScreenGeometry.attachedBodyRect(height, flare.start,
            Math.max(0, flare.end - flare.start),
            Math.max(flare.currentHeight, flare.naturalContentHeight + flare.verticalPadding * 2) + Theme.hugRadius)
        var expected = ScreenGeometry.attachedBodyRect(height, target.start,
            flare.naturalContentWidth > 0 ? target.end - target.start : 0, current.height)
        var bodyVisual = SafeZoneGeometry.unionBounds(current, expected)
        var retained = flare.interactionEnvelope
        if (retained.end > retained.start)
            bodyVisual = SafeZoneGeometry.unionBounds(bodyVisual, ScreenGeometry.attachedBodyRect(height,
                retained.start, retained.end - retained.start,
                retained.height + Theme.hugRadius))
        return [SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(anchorVisual,
                    Interaction.safeZoneAnchorMargin), width, height),
                bodyVisual.width ? SafeZoneGeometry.clampRect(SafeZoneGeometry.verticalBridge(
                    anchorVisual, bodyVisual, Interaction.safeZoneCorridorWidth), width, height) : empty,
                bodyVisual.width ? SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(bodyVisual,
                    Interaction.safeZoneMargin), width, height) : empty]
    }
    // A topology transfer invalidates every retained anchor and close envelope.
    Connections {
        target: ChromeLayout
        function onTaskbarModeChanged() {
            root.closing = false
            root.frozenSafeZones = []
        }
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

    onPanelOpenChanged: {
        if (panelOpen) {
            openedAtBottom = ScreenGeometry.bottomAttached
            closing = false
            NotificationStore.hidePopups()
            Qt.callLater(function() { if (root && root.panelOpen) keyHandler.forceActiveFocus() })
        } else if (flare.currentHeight > 0) {
            closing = true
        }
    }
    Component.onDestruction: UiState.closeNotificationsIfScreen(modelData.name)

    PanelWindow {
        id: visualLayer
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-notification-center-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        // Keep Top mapped so opening the panel does not raise it over fullscreen.
        visible: true
        mask: Region {}

        FlareSurface {
            attach: ScreenGeometry.bottomAttached ? FlareHost.Bottom : FlareHost.Top
            visible: root.openedAtBottom === ScreenGeometry.bottomAttached && (root.panelOpen || root.closing)
            y: ScreenGeometry.chromeAttachmentY(root.modelData.height)
            width: visualLayer.width
            height: visualLayer.height - y
            // Only physical screen edges may produce a hugging foot.
            start: root.hostRect.x + flare.start
            end: root.hostRect.x + flare.end
            currentHeight: flare.currentHeight
            bounds: ScreenGeometry.horizontalBounds(root.modelData.width)
            r: Theme.largeRadius + 8
            rf: Theme.hugRadius
            bottomRadius: Theme.hugRadius
            surfaceColor: Theme.surface
        }
    }

    PanelWindow {
        id: contentLayer
        screen: root.modelData
        anchors { top: true; bottom: true; right: true }
        margins.right: 0
        WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
        WlrLayershell.namespace: "hakuspace-notification-center"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: root.width
        visible: root.openedAtBottom === ScreenGeometry.bottomAttached && (root.panelOpen || root.closing)
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

        // The Overlay keeps a rounded body and owns all interaction.
        Rectangle {
            x: flare.start
            y: ScreenGeometry.attachedBodyY(root.modelData.height, height)
            width: Math.max(0, flare.end - flare.start)
            height: flare.currentHeight
            topLeftRadius: Theme.hugRadius
            bottomLeftRadius: Theme.hugRadius
            topRightRadius: 0
            bottomRightRadius: 0
            color: Theme.surface
            visible: height > 0 && width > 0
        }

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
            screenWidth: root.modelData.width
            screenHeight: root.modelData.height
            hostRect: root.hostRect
            anchorRect: root.panelState ? root.panelState.anchorRect : null
            localizedAnchorRect: root.localAnchorRect
            flareStart: flare.start
            flareEnd: flare.end
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

        FlareHost {
            id: flare
            attach: ScreenGeometry.bottomAttached ? FlareHost.Bottom : FlareHost.Top
            y: ScreenGeometry.chromeAttachmentY(root.modelData.height)
            width: root.width
            height: ScreenGeometry.availableAttachedHeight(root.height)
            surfaceColor: "transparent"
            anchorRect: root.panelState ? root.panelState.anchorRect : null
            hostRect: root.hostRect
            shown: root.panelOpen
            content: centerComponent
            contentProps: ({ maxHeight: Math.max(0, ScreenGeometry.availableAttachedHeight(root.modelData.height)
                                                  - 48 - Theme.hugRadius),
                             maxWidth: Math.max(0, root.width - 48) })
            contentKey: "notifications"
            maxWidth: Math.min(500, Math.max(0, root.horizontalBounds.end - root.horizontalBounds.start))
            wBounds: root.horizontalBounds
            horizontalPadding: 24
            verticalPadding: 24
            onSettled: (isShown) => {
                if (!isShown && !root.panelOpen) root.closing = false
            }
        }

        Component {
            id: centerComponent
            NotificationCenterContent { onKeyboardInteraction: lifetime.beginKeyboardLease() }
        }
    }
}
