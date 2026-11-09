import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../flare"
import "../flare/FlareGeometry.js" as FlareGeometry
import "SafeZoneGeometry.js" as SafeZoneGeometry

Item {
    id: root
    // The Flare settled callback releases the retained close envelope.
    readonly property bool releaseReady: !panelOpen && !closing
    readonly property bool hasFullscreen: ToplevelManager.toplevels.values.some(w =>
        w.fullscreen && (w.activated || ToplevelManager.activeToplevel === w)
        && (!root.modelData || w.screens.length === 0 || w.screens.includes(root.modelData) || w.screens.some(s => s.name === root.modelData.name)))
    required property var modelData
    width: modelData ? modelData.width : 0
    height: modelData ? modelData.height : 0
    readonly property var horizontalBounds: ScreenGeometry.horizontalBounds(width)
    property bool panelOpen: false
    property bool closing: false
    property bool forceBottomAttached: false
    property bool openedAtLeft: !forceBottomAttached && ChromeLayout.leftBarMode
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
        if (root.openedAtLeft) {
            // Keep hover corridors and the retained close mask above an exclusive Dock.
            var usableHeight = Math.min(height, root.modelData.height - ScreenGeometry.bottomReservation(root.modelData.name))
            var sideBody = {x: ScreenGeometry.contentLeftEdge, y: flare.start,
                width: Math.max(flare.currentHeight, flare.naturalContentWidth + flare.horizontalPadding * 2),
                height: Math.max(0, flare.end - flare.start)}
            var retainedSide = flare.interactionEnvelope
            if (retainedSide.end > retainedSide.start)
                sideBody = SafeZoneGeometry.unionBounds(sideBody, {x: sideBody.x, y: retainedSide.start,
                    width: retainedSide.height, height: retainedSide.end - retainedSide.start})
            return [SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(anchorVisual, Interaction.safeZoneAnchorMargin), width, usableHeight),
                SafeZoneGeometry.clampRect(SafeZoneGeometry.horizontalBridge(anchorVisual, sideBody, Interaction.safeZoneCorridorWidth), width, usableHeight),
                SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(sideBody, Interaction.safeZoneMargin), width, usableHeight)]
        }
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
        function onStatusEdgeChanged() {
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

    onPanelOpenChanged: {
        if (panelOpen) {
            openedAtLeft = !forceBottomAttached && ChromeLayout.leftBarMode
            openedAtBottom = forceBottomAttached || ScreenGeometry.bottomAttached
            closing = false
            Qt.callLater(function() { if (root && root.panelOpen) keyHandler.forceActiveFocus() })
        } else if (flare.currentHeight > 0) {
            closing = true
        }
    }

    // 1. Top-layer visual shell.
    // Pure visual surface: owns the FlareSurface with hugging ears that connect to RoundedScreen.
    // Keep Top mapped so opening the panel does not raise it over fullscreen.
    PanelWindow {
        id: visualLayer
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-flare-panel-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        visible: true
        mask: Region {}

        FlareSurface {
            id: visualSurface
            visible: !root.hasFullscreen && !!root.modelData
                && (root.forceBottomAttached || root.openedAtBottom === ScreenGeometry.bottomAttached && root.openedAtLeft === ChromeLayout.leftBarMode)
                && (root.panelOpen || root.closing)
            attach: root.openedAtLeft ? FlareHost.Left : root.openedAtBottom ? FlareHost.Bottom : FlareHost.Top
            x: root.openedAtLeft ? ScreenGeometry.contentLeftEdge : 0
            y: root.openedAtLeft ? 0 : root.attachmentY
            width: visualLayer.width - x
            height: root.openedAtLeft ? visualLayer.height : ScreenGeometry.availableAttachedHeight(visualLayer.height)
            transform: Matrix4x4 {
                matrix: root.openedAtLeft ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    : Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
            start: flare.start
            end: flare.end
            currentHeight: flare.currentHeight
            bounds: flare.wBounds
            r: Theme.largeRadius + 8
            rf: Theme.hugRadius
            bottomRadius: Theme.hugRadius
            surfaceColor: Theme.surface
        }
    }

    // 2. Overlay content shell.
    // Interactive window: owns content, rounded body (WITHOUT flare ears), focus, and pointer input.
    // Floats cleanly over fullscreen clients without displaying any orphaned flare ears.
    PanelWindow {
        id: contentLayer
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
        WlrLayershell.namespace: "hakuspace-flare-panel"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        visible: !!root.modelData && (root.forceBottomAttached || root.openedAtBottom === ScreenGeometry.bottomAttached && root.openedAtLeft === ChromeLayout.leftBarMode)
            && (root.panelOpen || root.closing)
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

        // Clean rounded body without flare ears.
        // Overlays visualLayer seamlessly in tiled mode; floats cleanly over fullscreen clients.
        Rectangle {
            id: contentSurface
            x: root.openedAtLeft ? ScreenGeometry.contentLeftEdge : flare.start
            y: root.openedAtLeft ? flare.start : root.openedAtBottom ? root.attachmentY - flare.currentHeight : root.attachmentY
            width: root.openedAtLeft ? flare.currentHeight : Math.max(0, flare.end - flare.start)
            height: root.openedAtLeft ? Math.max(0, flare.end - flare.start) : flare.currentHeight
            radius: Theme.hugRadius
            color: Theme.surface
            visible: width > 0.01 && height > 0.01

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => { mouse.accepted = true }
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
            screenWidth: root.modelData ? root.modelData.width : 0
            screenHeight: root.modelData ? root.modelData.height : 0
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

        FlareHost {
            id: flare
            surfaceColor: "transparent"
            attach: root.openedAtLeft ? FlareHost.Left : root.openedAtBottom ? FlareHost.Bottom : FlareHost.Top
            x: root.openedAtLeft ? ScreenGeometry.contentLeftEdge : 0
            y: root.openedAtLeft ? 0 : root.attachmentY
            width: contentLayer.width - x
            height: root.openedAtLeft ? contentLayer.height : ScreenGeometry.availableAttachedHeight(contentLayer.height)
            anchorRect: root.anchorRect
            hostRect: root.hostRect
            // Cold side panels measure content only after their native output plane is configured.
            shown: root.panelOpen && (!root.openedAtLeft || (contentLayer.width === (root.modelData ? root.modelData.width : 0) && contentLayer.height === (root.modelData ? root.modelData.height : 0)))
            content: root.panelComponent
            contentProps: root.openedAtLeft ? Object.assign({}, root.panelProps, {
                maxWidth: Math.max(1, Math.min(root.panelProps.maxWidth || contentLayer.width,
                    contentLayer.width - ScreenGeometry.contentLeftEdge - horizontalPadding * 2 - ScreenGeometry.rightInset)),
                maxHeight: Math.max(1, Math.min(root.panelProps.maxHeight || contentLayer.height,
                    contentLayer.height - ScreenGeometry.topBorderThickness - ScreenGeometry.bottomReservation(root.modelData ? root.modelData.name : "") - verticalPadding * 2))
            }) : root.panelProps
            contentKey: root.panelKey
            maxWidth: Math.min(400, Math.max(0, root.horizontalBounds.end - root.horizontalBounds.start))
            horizontalPadding: 22
            wBounds: root.openedAtLeft ? ({start: ScreenGeometry.topBorderThickness,
                end: Math.max(ScreenGeometry.topBorderThickness, contentLayer.height - ScreenGeometry.bottomReservation(root.modelData ? root.modelData.name : ""))})
                : ScreenGeometry.horizontalBounds(contentLayer.width)
            onSettled: (isShown) => {
                if (!isShown && !root.panelOpen) root.closing = false
            }
        }
    }
}
