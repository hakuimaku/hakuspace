import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../flare"
import "../flare/FlareGeometry.js" as FlareGeometry
import "SafeZoneGeometry.js" as SafeZoneGeometry

PanelWindow {
    id: root
    // The Flare settled callback releases the retained close envelope.
    readonly property bool releaseReady: !panelOpen && !closing
    readonly property var horizontalBounds: ScreenGeometry.horizontalBounds(width)
    required property var modelData
    property bool panelOpen: false
    property bool closing: false
    property bool forceBottomAttached: false
    property bool openedAtBottom: forceBottomAttached || ScreenGeometry.bottomAttached
    readonly property real attachmentY: openedAtBottom
        ? (ChromeLayout.taskbarMode ? height - ScreenGeometry.taskbarHeight : height - ScreenGeometry.dockbarHeight - ScreenGeometry.bottomInset)
        : ScreenGeometry.chromeAttachmentY(height)
    function attachedBodyY(screenHeight, contentHeight, distance) {
        return openedAtBottom ? attachmentY - (distance || 0) - contentHeight : attachmentY + (distance || 0)
    }
    function attachedBodyRect(screenHeight, x, width, contentHeight, distance) {
        return {x: x, y: attachedBodyY(screenHeight, contentHeight, distance), width: width, height: contentHeight}
    }
    property var anchorRect: null
    readonly property var hostRect: ({x: 0, y: 0, width: width, height: height})
    readonly property var localAnchorRect: flare.localizedAnchorRect || ({x: 0, y: 0, width: 0, height: 0})
    property Component panelComponent: null
    property var panelProps: ({})
    property var panelKey: null
    property real maxPanelContentHeight: Math.max(0, ScreenGeometry.availableAttachedHeight(height)
        - Theme.hugRadius - 16 - Theme.pad)
    signal dismissed()
    readonly property var liveSafeZones: {
        var empty = SafeZoneGeometry.rect(0, 0, 0, 0)
        var anchorVisual = localAnchorRect
        var target = FlareGeometry.resolveSpan({ anchorStart: anchorVisual.x,
            anchorEnd: anchorVisual.x + anchorVisual.width, contentW: flare.naturalContentWidth,
            padX: flare.horizontalPadding * 2, minW: 80, maxW: flare.maxWidth,
            bounds: flare.wBounds, snap: 2 * Theme.hugRadius })
        var current = root.attachedBodyRect(height, flare.start,
            Math.max(0, flare.end - flare.start),
            Math.max(flare.currentHeight, flare.naturalContentHeight + 16) + Theme.hugRadius)
        var expected = root.attachedBodyRect(height, target.start,
            flare.naturalContentWidth > 0 ? target.end - target.start : 0, current.height)
        var bodyVisual = SafeZoneGeometry.unionBounds(current, expected)
        var retained = flare.interactionEnvelope
        if (retained.end > retained.start)
            bodyVisual = SafeZoneGeometry.unionBounds(bodyVisual, root.attachedBodyRect(height,
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

    SafeZoneController {
        id: lifetime
        active: root.panelOpen
        closing: root.closing
        containsPoint: function(x, y) { return SafeZoneGeometry.containsAny(root.safeZones, x, y) }
        onCloseRequested: root.dismissed()
    }

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
    WlrLayershell.namespace: "hakuspace-flare-panel"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: (root.forceBottomAttached || root.openedAtBottom === ScreenGeometry.bottomAttached) && (panelOpen || closing)
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
            openedAtBottom = forceBottomAttached || ScreenGeometry.bottomAttached
            closing = false
            Qt.callLater(function() { if (root && root.panelOpen) keyHandler.forceActiveFocus() })
        } else if (flare.currentHeight > 0) {
            closing = true
        }
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
        x: root.safeZone(0).x
        y: root.safeZone(0).y
        width: root.panelOpen ? root.safeZone(0).width : 0
        height: root.panelOpen ? root.safeZone(0).height : 0
        onClicked: root.dismissed()
    }

    SafeZoneDebugOverlay {
        anchors.fill: parent
        screenWidth: root.modelData.width
        screenHeight: root.modelData.height
        hostRect: root.hostRect
        anchorRect: root.anchorRect
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
        Keys.onEscapePressed: root.dismissed()
    }

    MouseArea {
        x: flare.start
        y: root.attachedBodyY(root.modelData.height, height)
        width: Math.max(0, flare.end - flare.start)
        height: Math.min(root.height, flare.currentHeight + Theme.hugRadius)
        onClicked: (mouse) => { mouse.accepted = true }
    }

    FlareHost {
        id: flare
        attach: root.openedAtBottom ? FlareHost.Bottom : FlareHost.Top
        y: root.attachmentY
        width: root.width
        height: ScreenGeometry.availableAttachedHeight(root.height)
        anchorRect: root.anchorRect
        hostRect: root.hostRect
        shown: root.panelOpen
        content: root.panelComponent
        contentProps: root.panelProps
        contentKey: root.panelKey
        maxWidth: Math.min(400, Math.max(0, root.horizontalBounds.end - root.horizontalBounds.start))
        horizontalPadding: 22
        onSettled: (isShown) => {
            if (!isShown && !root.panelOpen) root.closing = false
        }
    }
}
