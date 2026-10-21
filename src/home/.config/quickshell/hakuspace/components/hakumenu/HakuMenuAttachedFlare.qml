import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../base" as Base
import "../base/SafeZoneGeometry.js" as SafeZoneGeometry
import "../flare" as Flare

Item {
    id: root
    required property var modelData

    property bool bottomAttached: false
    readonly property bool available: bottomAttached ? ChromeLayout.taskbarMode : ChromeLayout.topBarMode
    readonly property string presentation: bottomAttached ? "bottomFlare" : "topFlare"
    readonly property real screenWidth: modelData ? modelData.width : 0
    readonly property real screenHeight: modelData ? modelData.height : 0
    readonly property bool panelOpen: !!modelData && available && UiState.activePanel === "hakumenu"
        && UiState.hakuMenuStyle === presentation
        && UiState.hakuMenuMode !== "closed"
        && UiState.hakuMenuScreenName === modelData.name
    // Retain the real App Menu rect while the closing morph finishes.
    property var capturedAnchor: null
    readonly property real maxMenuWidth: root.screenWidth * 0.42
    readonly property real targetMenuWidth: {
        if (UiState.hakuMenuMode === "general") return root.screenWidth * 0.38
        if (UiState.hakuMenuMode === "theme") return root.screenWidth * 0.42
        return root.screenWidth * 0.40
    }
    readonly property real menuHeight: root.screenHeight * 0.40
    readonly property real menuTop: bottomAttached ? screenHeight - ScreenGeometry.taskbarHeight : Theme.topBarHeight
    readonly property real bounceHeadroom: menuHeight * HAnimation.hakuMenuBounceHeadroom
    readonly property bool contentReady: isFinite(menu.width) && menu.width > 0
                                         && isFinite(menu.height) && menu.height > 0
    readonly property bool safeExpanded: available && (UiState.activePanel !== "hakumenu" || panelOpen) && (panelOpen || morph.mHeight > 0.01)
    readonly property var safeZones: {
        if (!safeExpanded || !capturedAnchor) return []
        var body = attachedRect(
            Math.min(morph.mStart, (screenWidth - maxMenuWidth) / 2),
            Math.max(maxMenuWidth, morph.mEnd - morph.mStart), Math.max(morph.mHeight, menuHeight + bounceHeadroom))
        var zones = [SafeZoneGeometry.inflate(capturedAnchor, Interaction.safeZoneAnchorMargin)]
            .concat(SafeZoneGeometry.orthogonalBridge(capturedAnchor, body, bottomAttached ? Interaction.safeZoneCorridorWidth : capturedAnchor.width),
                [SafeZoneGeometry.inflate(body, Interaction.safeZoneMargin)])
        return zones.map(function(zone) { return SafeZoneGeometry.clampRect(zone, screenWidth, screenHeight) })
    }
    // Each owner retains its attachment edge while another presentation takes over.
    function attachedRect(x, width, height) {
        return {x: x, y: bottomAttached ? menuTop - height : menuTop, width: width, height: height}
    }
    function safeZone(index) { return safeZones[index] || SafeZoneGeometry.rect(0, 0, 0, 0) }
    // The top trigger keeps its own input so presentation transfers cannot synthesize re-entry.
    function trackTrigger(x, y) { lifetime.pointerMoved(x, y) }
    function leaveTrigger() { lifetime.pointerExited() }

    Base.SafeZoneController {
        id: lifetime
        active: root.panelOpen
        containsPoint: function(x, y) { return SafeZoneGeometry.containsAny(root.safeZones, x, y) }
        onCloseRequested: UiState.closeHakuMenu()
    }

    width: screenWidth
    height: screenHeight

    onPanelOpenChanged: {
        if (panelOpen) {
            capturedAnchor = UiState.hakuMenuAnchorRect
            Qt.callLater(function() {
                if (root.panelOpen) menu.forceSearchFocus()
            })
        } else {
            menu.clearSearchFocus()
        }
    }

    // Top-layer visual shell. This remains a pure visual surface: it owns the
    // Flare/body silhouette but no content, focus or pointer input. Fullscreen
    // clients may cover this layer while the Overlay content layer below in
    // this component still remains visible and usable.
    PanelWindow {
        id: topVisualLayer
        visible: !!root.modelData && (root.panelOpen || root.safeExpanded)
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-hakumenu-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        implicitWidth: root.screenWidth
        color: "transparent"
        mask: Region {}

        Flare.FlareSurface {
            attach: root.bottomAttached ? Flare.FlareHost.Bottom : Flare.FlareHost.Top
            y: root.menuTop
            start: morph.mStart
            end: morph.mEnd
            currentHeight: morph.mHeight
            bounds: morph.bounds
            r: Theme.giantRadius
            rf: Theme.hugRadius
            bottomRadius: Theme.hugRadius
            surfaceColor: Theme.surface
        }
    }

    // Overlay content shell. This is the only interactive HakuMenu window and
    // therefore continues to work over fullscreen clients. It deliberately
    // draws a rounded body without Flare ears; those belong to topVisualLayer.
    PanelWindow {
        id: contentLayer
        visible: !!root.modelData && (root.panelOpen || root.safeExpanded)
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
        WlrLayershell.namespace: "hakuspace-hakumenu-content"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"

        mask: Region {
            Region {
                x: root.safeZone(0).x; y: root.safeZone(0).y
                width: root.bottomAttached ? root.safeZone(0).width : 0
                height: root.bottomAttached ? root.safeZone(0).height : 0
            }
            Region {
                x: root.safeZone(1).x; y: root.safeZone(1).y
                width: root.safeZone(1).width; height: root.safeZone(1).height
            }
            Region {
                x: root.safeZone(2).x; y: root.safeZone(2).y
                width: root.safeZone(2).width; height: root.safeZone(2).height
            }
            Region {
                x: root.safeZone(3).x; y: root.safeZone(3).y
                width: root.safeZone(3).width; height: root.safeZone(3).height
            }
        }

        HoverHandler {
            id: safeZoneHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (!hovered) lifetime.pointerExited()
                else {
                    lifetime.pointerEntered(point.position.x, point.position.y)
                    if (root.panelOpen) menu.forceSearchFocus()
                }
            }
            onPointChanged: lifetime.pointerMoved(point.position.x, point.position.y)
        }

        Base.SafeZoneDebugOverlay {
            anchors.fill: parent
            z: 999
            closePending: lifetime.closePending
            zones: root.safeZones.map(function(zone, index) {
                return { rect: zone, kind: index === 0 ? "anchor"
                    : index < root.safeZones.length - 1 ? "corridor"
                    : morph.mHeight > 0.01 && morph.mHeight < root.menuHeight
                        ? "animation" : "surface" }
            })
        }

        // Relay the owning App Menu click through the Overlay anchor mask.
        MouseArea {
            x: root.capturedAnchor ? root.capturedAnchor.x : 0
            y: root.capturedAnchor ? root.capturedAnchor.y : 0
            width: root.capturedAnchor ? root.capturedAnchor.width : 0
            height: root.capturedAnchor ? root.capturedAnchor.height : 0
            enabled: root.panelOpen && root.bottomAttached
            onClicked: UiState.closeHakuMenu()
        }

        Item {
            id: fallbackKeyHandler
            anchors.fill: parent
            focus: root.panelOpen
            Keys.onEscapePressed: event => {
                UiState.closeHakuMenu()
                event.accepted = true
            }
        }

        Flare.FlareMorph {
            id: morph
            // Center the menu physically; the captured App Menu rect owns interaction only.
            anchorRect: ({x: root.screenWidth / 2, y: root.menuTop, width: 0, height: 0})
            hostRect: ({x: 0, y: 0, width: root.screenWidth, height: root.screenHeight})
            shown: root.panelOpen && root.contentReady
            contentW: root.targetMenuWidth
            contentH: root.menuHeight
            minW: 0
            maxW: root.maxMenuWidth
            padX: 0
            padY: 0
            snap: 0
            bounds: ScreenGeometry.horizontalBounds(root.screenWidth)
            openDuration: HAnimation.hakuMenuOpenDuration
            closeDuration: HAnimation.hakuMenuCloseDuration
            retargetDuration: HAnimation.hakuMenuResizeDuration
            retargetWidthCurve: HAnimation.hakuMenuResizeCurve
            openHeightCurve: HAnimation.hakuMenuOpenCurve
            closeHeightCurve: HAnimation.hakuMenuCloseCurve
        }

        Rectangle {
            id: contentSurface
            x: morph.mStart
            y: root.bottomAttached ? root.menuTop - height : root.menuTop
            width: Math.max(0, morph.mEnd - morph.mStart)
            height: morph.mHeight
            radius: Math.min(Theme.hugRadius, width / 2, height / 2)
            color: Theme.surface
            clip: true
            visible: width > 0.01 && height > 0.01

            // Absorb clicks so clicking inside the menu body does not dismiss
            MouseArea {
                anchors.fill: parent
            }

            HoverHandler {
                id: surfaceHover
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onPointChanged: if (root.panelOpen)
                    lifetime.pointerMoved(contentSurface.x + point.position.x,
                        contentSurface.y + point.position.y)
            }

            HakuMenuContent {
                id: menu
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetMenuWidth
                height: root.menuHeight
                panelOpen: root.panelOpen
                onKeyboardActivity: lifetime.beginKeyboardLease()
                Behavior on width {
                    NumberAnimation {
                        duration: HAnimation.hakuMenuResizeDuration
                        easing.bezierCurve: HAnimation.hakuMenuResizeCurve
                    }
                }
            }
        }
    }
}
