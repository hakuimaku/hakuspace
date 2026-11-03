import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../base" as Base
import "../base/SafeZoneGeometry.js" as SafeZoneGeometry
import "../flare" as Flare
import "HakuMenuGeometry.js" as Geometry

Item {
    id: root
    // Retain the presentation until its closing morph settles.
    readonly property bool releaseReady: !panelOpen && visuallyClosed
    property bool visuallyClosed: true
    required property var modelData

    property bool bottomAttached: false
    readonly property bool available: bottomAttached ? ScreenGeometry.bottomHostAvailable : ChromeLayout.topBarMode
    readonly property string presentation: bottomAttached ? "bottomFlare" : "topFlare"
    readonly property real screenWidth: modelData ? modelData.width : 0
    readonly property real screenHeight: modelData ? modelData.height : 0
    readonly property bool panelOpen: !!modelData && available && UiState.activePanel === "hakumenu"
        && UiState.hakuMenuStyle === presentation
        && UiState.hakuMenuMode !== "closed"
        && UiState.hakuMenuScreenName === modelData.name
    // Retain the real App Menu rect while the closing morph finishes.
    property var capturedAnchor: null
    // Keep the outgoing profile until its visual close completes.
    property string renderTab: "hakumenu"
    readonly property bool taskManagerTab: renderTab === "taskManager"
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    readonly property real controlHeight: bottomAttached ? ScreenGeometry.bottomHostControlHeight : 0
    readonly property var taskSize: Geometry.attachedTaskSize(screenWidth, screenHeight,
        ScreenGeometry.leftInset, ScreenGeometry.rightInset,
        bottomAttached ? ScreenGeometry.bottomHostReservation() + controlHeight : Theme.topBarHeight,
        bottomAttached ? ScreenGeometry.bottomHostOppositeInset : ScreenGeometry.bottomInset, menu.miniHeight)
    readonly property real maxMenuWidth: taskManagerTab ? taskSize.width : root.screenWidth * 0.42
    readonly property real targetMenuWidth: Geometry.targetWidth(screenWidth, renderTab, UiState.hakuMenuMode,
        ScreenGeometry.leftInset, ScreenGeometry.rightInset)
    readonly property real menuHeight: taskManagerTab ? taskSize.height : root.screenHeight * 0.40
    readonly property real surfaceHeight: menuHeight + controlHeight
    readonly property real menuTop: bottomAttached ? ScreenGeometry.bottomHostTop(screenHeight) : Theme.topBarHeight
    readonly property real bounceHeadroom: surfaceHeight * HAnimation.hakuMenuBounceHeadroom
    readonly property bool contentReady: isFinite(menu.width) && menu.width > 0
                                         && isFinite(menu.height) && menu.height > 0
    readonly property bool safeExpanded: available && (UiState.activePanel !== "hakumenu" || panelOpen) && (panelOpen || morph.mHeight > 0.01)
    readonly property var safeZones: {
        if (!safeExpanded || !capturedAnchor) return []
        var body = attachedRect(
            Math.min(morph.mStart, (screenWidth - maxMenuWidth) / 2),
            Math.max(maxMenuWidth, morph.mEnd - morph.mStart), Math.max(morph.mHeight, surfaceHeight + bounceHeadroom))
        var zones = [SafeZoneGeometry.inflate(capturedAnchor, Interaction.safeZoneAnchorMargin)]
            .concat(SafeZoneGeometry.orthogonalBridge(capturedAnchor, body, bottomAttached ? Interaction.safeZoneCorridorWidth : capturedAnchor.width),
                [SafeZoneGeometry.inflate(body, Interaction.safeZoneMargin)])
        return zones.map(function(zone) { return SafeZoneGeometry.clampRect(zone, screenWidth, screenHeight) })
    }
    // Each owner retains its attachment edge while another presentation takes over.
    function attachedRect(x, width, height) {
        return {x: x, y: bottomAttached ? menuTop - height : menuTop, width: width, height: height}
    }
    // Closing paint keeps its geometry while pointer input returns to the host immediately.
    function safeZone(index) { return (panelOpen ? safeZones[index] : null) || SafeZoneGeometry.rect(0, 0, 0, 0) }
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
            renderTab = UiState.hakuPanelTab
            if (visuallyClosed) {
                capturedAnchor = UiState.hakuMenuAnchorRect
            }
            visuallyClosed = false
            Qt.callLater(function() {
                if (!root) return
                if (root.panelOpen) menu.forcePrimaryFocus()
            })
        } else {
            menu.clearPrimaryFocus()
        }
    }

    Connections {
        target: UiState
        function onHakuPanelTabChanged() { if (root.panelOpen) root.renderTab = UiState.hakuPanelTab }
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
        WlrLayershell.keyboardFocus: root.panelOpen && UiState.ownsInteraction("hakumenu", root.modelData.name) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
                    if (root.panelOpen) menu.forcePrimaryFocus()
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
                    : morph.mHeight > 0.01 && morph.mHeight < root.surfaceHeight
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
            onSettled: isShown => { if (!isShown && !root.panelOpen) root.visuallyClosed = true }
            // Center the menu physically; the captured App Menu rect owns interaction only.
            anchorRect: ({x: root.screenWidth / 2, y: root.menuTop, width: 0, height: 0})
            hostRect: ({x: 0, y: 0, width: root.screenWidth, height: root.screenHeight})
            shown: root.panelOpen && root.contentReady
            contentW: root.targetMenuWidth
            contentH: root.surfaceHeight
            minW: 0
            maxW: root.maxMenuWidth
            padX: 0
            padY: 0
            snap: 0
            bounds: ScreenGeometry.horizontalBounds(root.screenWidth)
            openDuration: root.reducedMotion ? 0 : HAnimation.hakuMenuOpenDuration
            closeDuration: root.reducedMotion ? 0 : HAnimation.hakuMenuCloseDuration
            retargetDuration: root.reducedMotion ? 0 : HAnimation.hakuMenuResizeDuration
            retargetHeightDuration: root.reducedMotion ? 0 : HAnimation.hakuMenuResizeDuration
            retargetHeightCurve: HAnimation.hakuMenuResizeCurve
            retargetWidthCurve: HAnimation.hakuMenuResizeCurve
            openHeightCurve: HAnimation.hakuMenuOpenCurve
            closeHeightCurve: HAnimation.hakuMenuCloseCurve
        }

        Rectangle {
            id: contentSurface
            x: morph.mStart
            y: root.bottomAttached ? root.menuTop - morph.mHeight : root.menuTop
            width: Math.max(0, morph.mEnd - morph.mStart)
            height: root.controlHeight > 0 ? Math.max(0, Math.min(root.menuHeight, morph.mHeight - root.controlHeight)) : morph.mHeight
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

            HakuMenuRoot {
                id: menu
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetMenuWidth
                height: root.menuHeight
                panelOpen: root.panelOpen
                bottomAttached: root.bottomAttached
                tab: root.renderTab
                interactionOwned: root.panelOpen && UiState.ownsInteraction("hakumenu", root.modelData.name)
                onKeyboardActivity: lifetime.beginKeyboardLease()
                onWallpaperRequested: UiState.openWallpaper(root.modelData.name)
                Behavior on width {
                    NumberAnimation {
                        duration: root.reducedMotion ? 0 : HAnimation.hakuMenuResizeDuration
                        easing.bezierCurve: HAnimation.hakuMenuResizeCurve
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: root.reducedMotion ? 0 : HAnimation.hakuMenuResizeDuration
                        easing.bezierCurve: HAnimation.hakuMenuResizeCurve
                    }
                }
            }
        }

        // Reveal the host return control inside the same clipped surface and input window.
        Loader {
            active: root.controlHeight > 0
            visible: root.panelOpen
            x: morph.mStart
            y: root.menuTop - morph.mHeight
            width: Math.max(0, morph.mEnd - morph.mStart)
            height: Math.max(0, morph.mHeight)
            clip: true
            sourceComponent: Item {
                Base.HButton {
                    id: returnButton
                    objectName: "hakumenu-return-button"
                    width: parent.width
                    height: root.controlHeight
                    y: parent.height - height
                    enabled: root.panelOpen && morph.mHeight >= root.controlHeight
                        && UiState.ownsInteraction("hakumenu", root.modelData.name)
                    disabledOpacity: 1
                    idleColor: "transparent"
                    hoverColor: "transparent"
                    pressedColor: "transparent"
                    hoverForegroundColor: Theme.fg
                    pressedForegroundColor: Theme.fg
                    hoverScaleDelta: 0
                    pressScaleDelta: 0
                    clip: true
                    // Share the cadence while easing each column along its own path.
                    property real arrowPhase: 1 / 6
                    // Expand the hover glow without changing the button's input geometry.
                    property real hoverReveal: hovered && enabled && root.panelOpen ? 1 : 0
                    Behavior on hoverReveal {
                        NumberAnimation {
                            duration: root.reducedMotion ? 0 : 650
                            easing.type: Easing.OutCubic
                        }
                    }
                    NumberAnimation on arrowPhase {
                        from: 1 / 6
                        to: 7 / 6
                        duration: 2200
                        loops: Animation.Infinite
                        running: (returnButton.hovered || returnButton.hoverReveal > 0)
                            && returnButton.enabled && root.panelOpen && !root.reducedMotion
                        onRunningChanged: if (!running) returnButton.arrowPhase = 1 / 6
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: "Close HakuMenu"
                    Accessible.onPressAction: UiState.returnFromHakuMenu()
                    onClicked: UiState.returnFromHakuMenu()
                    // Scale a fixed radial path into a soft elliptical glow behind the arrows.
                    Shape {
                        objectName: "hakumenu-return-glow"
                        width: 100
                        height: 100
                        anchors.centerIn: parent
                        opacity: returnButton.hoverReveal
                        visible: opacity > 0
                        transform: Scale {
                            origin.x: 50; origin.y: 50
                            xScale: returnButton.width / 100 * returnButton.hoverReveal
                            yScale: returnButton.height / 100 * returnButton.hoverReveal
                        }
                        ShapePath {
                            strokeWidth: -1
                            fillGradient: RadialGradient {
                                centerX: 50; centerY: 50
                                focalX: 50; focalY: 50
                                centerRadius: 50
                                GradientStop { position: 0; color: "#b3242424" }
                                GradientStop { position: 0.5; color: "#66141414" }
                                GradientStop { position: 1; color: "transparent" }
                            }
                            startX: 0; startY: 0
                            PathLine { x: 100; y: 0 }
                            PathLine { x: 100; y: 100 }
                            PathLine { x: 0; y: 100 }
                            PathLine { x: 0; y: 0 }
                        }
                    }
                    Repeater {
                        model: 3
                        delegate: Shape {
                            required property int index
                            // A sine ease slows the entry and exit of each column independently.
                            readonly property real cycle: (returnButton.arrowPhase + index / 3) % 1
                            readonly property real progress: (1 - Math.cos(cycle * Math.PI)) / 2
                            width: 28
                            height: 14
                            x: returnButton.width * (index + 0.5) / 3 - width / 2
                            y: (returnButton.height - height) / 2
                                + (root.reducedMotion ? 0 : (progress - 0.5) * returnButton.height * returnButton.hoverReveal)
                            // Blend back to the resting center arrow while the moving hint fades out.
                            opacity: (index === 1 ? 1 - returnButton.hoverReveal : 0)
                                + returnButton.hoverReveal * (root.reducedMotion ? (index === 1 ? 1 : 0.55)
                                    : Math.sin(progress * Math.PI))
                            Accessible.ignored: true
                            ShapePath {
                                strokeColor: returnButton.foreground
                                strokeWidth: 2.5
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                startX: 1.5; startY: 1.5
                                PathLine { x: 14; y: 12.5 }
                                PathLine { x: 26.5; y: 1.5 }
                            }
                        }
                    }
                }
            }
        }
    }
}
