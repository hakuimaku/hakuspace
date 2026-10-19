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

    readonly property real screenWidth: modelData ? modelData.width : 0
    readonly property real screenHeight: modelData ? modelData.height : 0
    readonly property bool panelOpen: !!modelData && UiState.activePanel === "hakumenu"
        && UiState.hakuMenuStyle === "topFlare"
        && UiState.hakuMenuMode !== "closed"
        && UiState.hakuMenuScreenName === modelData.name
    readonly property bool presentationAvailable: UiState.activePanel !== "hakumenu" || UiState.hakuMenuStyle === "topFlare"
    readonly property real triggerHeight: 4
    readonly property real triggerWidth: root.screenWidth * 0.20
    readonly property real maxMenuWidth: root.screenWidth * 0.42
    readonly property real targetMenuWidth: {
        if (UiState.hakuMenuMode === "general") return root.screenWidth * 0.38
        if (UiState.hakuMenuMode === "theme") return root.screenWidth * 0.42
        return root.screenWidth * 0.40
    }
    readonly property real menuHeight: root.screenHeight * 0.40
    readonly property real menuTop: ScreenGeometry.flareTopY
    readonly property real bounceHeadroom: menuHeight * HAnimation.hakuMenuBounceHeadroom
    readonly property real windowWidth: Math.max(triggerWidth, maxMenuWidth + Theme.hugRadius * 2)
    readonly property real windowHeight: menuTop + menuHeight + bounceHeadroom
    readonly property real triggerX: (root.screenWidth - triggerWidth) / 2
    readonly property bool contentReady: isFinite(menu.width) && menu.width > 0
                                         && isFinite(menu.height) && menu.height > 0
    readonly property bool safeExpanded: panelOpen || morph.mHeight > 0.01
    readonly property var safeZones: {
        var empty = SafeZoneGeometry.rect(0, 0, 0, 0)
        var trigger = SafeZoneGeometry.rect(triggerX, 0, triggerWidth, triggerHeight)
        var anchor = safeExpanded ? SafeZoneGeometry.inflate(trigger,
            Interaction.safeZoneAnchorMargin) : trigger
        var target = SafeZoneGeometry.rect((root.screenWidth - maxMenuWidth) / 2,
            menuTop, maxMenuWidth, menuHeight + bounceHeadroom)
        var current = SafeZoneGeometry.rect(morph.mStart, menuTop,
            Math.max(0, morph.mEnd - morph.mStart), morph.mHeight)
        var menuZone = safeExpanded ? SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(
            SafeZoneGeometry.unionBounds(current, target), Interaction.safeZoneMargin),
            root.screenWidth, root.screenHeight) : empty
        return [SafeZoneGeometry.clampRect(anchor, root.screenWidth, root.screenHeight),
                // The 20% wide trigger needs a vertical handoff along its full width.
                safeExpanded ? SafeZoneGeometry.clampRect(SafeZoneGeometry.rect(
                    triggerX, triggerHeight, triggerWidth, Math.max(0, menuTop - triggerHeight)),
                    root.screenWidth, root.screenHeight) : empty,
                menuZone]
    }
    function safeZone(index) { return safeZones[index] || SafeZoneGeometry.rect(0, 0, 0, 0) }

    Base.SafeZoneController {
        id: lifetime
        active: root.panelOpen
        containsPoint: function(x, y) { return SafeZoneGeometry.containsAny(root.safeZones, x, y) }
        onCloseRequested: UiState.closeHakuMenu()
    }

    width: windowWidth
    height: windowHeight


    onPanelOpenChanged: {
        if (panelOpen) {
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
        visible: !!root.modelData && root.presentationAvailable
        screen: root.modelData
        anchors { top: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-hakumenu-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        implicitWidth: root.screenWidth
        implicitHeight: root.windowHeight
        color: "transparent"
        mask: Region {}

        Flare.FlareSurface {
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
        visible: !!root.modelData && root.presentationAvailable
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hakuspace-hakumenu-content"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"

        mask: Region {
            Region {
                x: root.safeZone(0).x; y: root.safeZone(0).y
                width: root.safeZone(0).width; height: root.safeZone(0).height
            }
            Region {
                x: root.safeZone(1).x; y: root.safeZone(1).y
                width: root.safeZone(1).width; height: root.safeZone(1).height
            }
            Region {
                x: root.safeZone(2).x; y: root.safeZone(2).y
                width: root.safeZone(2).width; height: root.safeZone(2).height
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
                    : index === 1 ? "corridor"
                    : morph.mHeight > 0.01 && morph.mHeight < root.menuHeight
                        ? "animation" : "surface" }
            })
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

        Item {
            id: triggerAnchor
            x: root.triggerX
            y: 0
            width: root.triggerWidth
            height: root.triggerHeight

            HoverHandler {
                id: triggerHover
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onHoveredChanged: {
                    if (hovered && !root.panelOpen) {
                        UiState.openHakuMenu(root.modelData.name)
                    }
                }
                onPointChanged: if (root.panelOpen)
                    lifetime.pointerMoved(root.triggerX + point.position.x, point.position.y)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    if (!root.panelOpen) {
                        UiState.openHakuMenu(root.modelData.name)
                    }
                }
            }
        }

        Flare.FlareMorph {
            id: morph
            anchorItem: triggerAnchor
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
            y: root.menuTop
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
